# Carely System Architecture Document

## 1. Architectural Philosophy

### 1.1 "Server is Authoritative, Mobile is Opportunistic"
In safety-critical or dead man's switch applications, relying on a mobile phone to calculate deadlines or trigger distress signals is fundamentally flawed. Modern mobile operating systems actively terminate or freeze background processes to maximize battery life:
* **Android**: Doze mode disables network access and restricts `JobScheduler` and `WorkManager` execution to maintenance windows. OEM variations (MIUI, Samsung OneUI, ColorOS) implement aggressive background task killers.
* **iOS**: `BGAppRefreshTask` and `BGProcessingTask` provide zero guarantees on frequency or timing. Execution windows are strictly capped at 30 seconds.

**Carely's Axiom**:
The **Carely Backend Server is the sole authority**. The server maintains the state machine, evaluates elapsed time against configured schedules, schedules check-in requests, and triggers escalation trees. Mobile devices communicate opportunistically when active; their silence does not halt server evaluations.

```
+------------------------------------------------------------------------+
|                          CARELY SERVER (AUTHORITATIVE)                 |
|                                                                        |
|   +-------------------+    +--------------------+    +-------------+   |
|   | Monitoring Worker | -> | Monitoring State   | -> | Incident &  |   |
|   | (Cron Evaluation) |    | Machine Engine     |    | Escalation  |   |
|   +-------------------+    +--------------------+    +-------------+   |
|            ^                         ^                      |          |
|            | Time & Thresholds       | Transitions          v          |
|   +--------+-------------------------+--------+      +-------------+   |
|   |          PostgreSQL 16 Storage            |      | FCM / SMS   |   |
|   |        (Authoritative Audit Trail)        |      | Dispatcher  |   |
|   +-------------------------------------------+      +------+------+   |
+--------------------------^----------------------------------|----------+
                           |                                  |
            Ingests Events | (Opportunistic)                  | Push / Alerts
                           |                                  v
+--------------------------+---------------------------------------------+
|                          MOBILE CLIENT (OPPORTUNISTIC)                 |
|                                                                        |
|   +--------------------+  +--------------------+  +----------------+   |
|   | Passive Activity   |  | Periodic Heartbeat |  | Manual Check-in|   |
|   | Tracker (Open/Chg) |  | (Reachability Ping)|  | ("Tôi vẫn ổn")|   |
|   +--------------------+  +--------------------+  +----------------+   |
+------------------------------------------------------------------------+
```

---

## 2. Strict Separation: Heartbeat vs Activity vs Check-in

| Dimension | Heartbeat | Activity | Check-in ("Tôi vẫn ổn") |
| :--- | :--- | :--- | :--- |
| **Endpoint** | `POST /api/v1/activities/heartbeat` | `POST /api/v1/activities` | `POST /api/v1/check-ins` |
| **Calculated Weight**| **0.0 (Zero)** | **0.2 – 0.8** (Weighted) | **1.0 (Maximum)** |
| **Meaning** | Device is powered on & reachable | Passive user signal (app foreground, charger) | Explicit conscious intent of safety |
| **Resets Inactivity Clock?** | **NO (Never)** | **YES** (If confidence >= threshold) | **YES** (Immediately) |
| **Affects Monitoring State?** | Updates device `lastHeartbeatAt` only | Keeps state in `ACTIVE` | Resets to `ACTIVE`, auto-resolves incidents |

---

## 3. Concurrency & High Availability Design

### 3.1 Distributed Locking (Redlock)
Worker instances and concurrent event ingesters protect shared resources using distributed locking:
```typescript
const lockAcquired = await this.redisService.acquireLock(
  `lock:monitoring_eval:${config.id}`,
  30000 // 30s TTL
);
```
Locks are released using atomic Lua scripts to prevent accidental release of locks acquired by other processes after TTL expiration:
```lua
if redis.call("get", KEYS[1]) == ARGV[1] then
  return redis.call("del", KEYS[1])
else
  return 0
end
```

### 3.2 Database Row-Level Concurrency (`FOR UPDATE SKIP LOCKED`)
The distributed monitoring worker scans records due for evaluation without blocking or duplicate processing across replicas:
```sql
SELECT config.*
FROM monitoring_configs config
INNER JOIN relationships rel ON rel.id = config.relationship_id
WHERE config.is_paused = FALSE
  AND config.next_evaluation_at <= NOW()
ORDER BY config.next_evaluation_at ASC
LIMIT 50
FOR UPDATE OF config SKIP LOCKED;
```
* **Deadlock Avoidance Pattern**: The worker uses a *deferred action pattern*. In-database state updates are committed immediately within the locked transaction. Subsequent external side effects (FCM push notification dispatches, incident event logging) execute outside the database transaction.

### 3.3 Graceful Degradation & Redis Fallback
If the Redis cluster experiences an outage, `RedisService` automatically degrades into fallback mode:
* `acquireLock`: returns `true` (fail-open) while logging degraded alerts, letting database row-level locks maintain ACID integrity.
* `rateLimit`: permits requests with warning metrics.
* When Redis restores, connections re-establish with exponential backoff and jitter without requiring application restart.

---

## 4. End-to-End Idempotency

Network disruptions frequently cause clients to retry requests. Carely guarantees end-to-end idempotency at every stage:
1. **Client Event UUID**: The client generates a unique `eventId` (UUIDv4) and injects it both into the request payload and the `X-Event-ID` HTTP header.
2. **Database Unique Constraints**:
   * `activities` table enforces `UNIQUE (event_id)`.
   * Duplicate submissions return the existing recorded entity with `HTTP 200/201` without duplicate state changes.
3. **Check-In Duplication Guard**:
   * Duplicate check-ins submitted within a short window return the original check-in record without corrupting incident audit trails.

---

## 5. Security & Authentication Model

* **JWT Architecture**:
  * Access Tokens: Short-lived (15 minutes), containing user ID and email.
  * Refresh Tokens: Long-lived (7 days), hashed with SHA-256 and stored in PostgreSQL for immediate revocation capability.
* **Server-Enforced Ownership**:
  * All controller endpoints extract identity exclusively from the validated `@CurrentUser()` decorator populated by `JwtAuthGuard`. Client requests cannot pass arbitrary `userId` parameters to manipulate foreign data.
* **Audit Trail**:
  * Every state transition and incident event records an immutable `audit_log` with actor identity, timestamp, and metadata.
