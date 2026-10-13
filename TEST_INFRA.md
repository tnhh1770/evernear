# Carely E2E Test Infrastructure & Verification Guide (`TEST_INFRA.md`)

## 1. Overview & Testing Philosophy

Carely is a life-safety critical Inactivity Monitor & Dead Man's Switch system. Test verification must adhere to **opaque-box, requirement-driven, progressive testability**:
- **Axiom 1**: Server is Authoritative Clock & State Machine; client is opportunistic reachability reporter.
- **Axiom 2**: Strict separation of Heartbeat (`weight: 0.0`), Meaningful Activity (`weight: 0.2 - 0.8`), and Check-in (`weight: 1.0`).
- **Axiom 3**: Calm Vietnamese UX, privacy-by-default (no continuous GPS tracking, single-shot consent-based location only).
- **Adversarial Integrity**: Tests must exercise adversarial boundaries, clock skew, rate limits, overnight calendar shifts, and concurrent race conditions.

---

## 2. Infrastructure & Harness Setup

### 2.1 Technology Stack
- **Test Runner**: Vitest 5.x (`vitest run`) with native TypeScript and ESM execution.
- **Application Harness**: NestJS 12 `Test.createTestingModule` compiling `AppModule` with real TypeORM PostgreSQL and Redis connections.
- **HTTP Client**: Supertest 7.x communicating over in-memory HTTP server (`app.getHttpServer()`) against real database entities.
- **Database Engine**: PostgreSQL 16 (14 relational tables with UUIDv4 primary keys and row-level locking).
- **Cache & Distributed Lock**: Redis 7.x (ioredis client with Redlock pattern and fail-open degraded mode).

### 2.2 Environment Configuration
Tests inherit configuration from `.env` or default test environments:
```bash
NODE_ENV=test
DB_HOST=localhost
DB_PORT=5432
DB_USERNAME=carely
DB_PASSWORD=carely_secret
DB_DATABASE=carely
REDIS_HOST=localhost
REDIS_PORT=6379
JWT_SECRET=carely_jwt_secret_key_change_in_production
PORT=3000
```

---

## 3. Test Taxonomy & Tier Architecture

The test suite is structured into 4 strict progressive tiers:

```
+-------------------------------------------------------------------------------+
| Tier 4: Real-World Lifecycle Simulation                                       |
| (Heartbeat -> Inactivity -> Check-in Alert -> Missed -> Incident -> Ack/Res)  |
+-------------------------------------------------------------------------------+
| Tier 3: Cross-Feature Pairwise Combinations                                   |
| (Heartbeat during Inactivity, Check-in during Warning, Redis Failover, etc.)  |
+-------------------------------------------------------------------------------+
| Tier 2: Boundary & Corner Cases                                               |
| (>=5 tests per feature: clock skew, rate limits, overnight windows, limits)   |
+-------------------------------------------------------------------------------+
| Tier 1: Functional Feature Coverage                                           |
| (>=5 tests per feature: Auth, Devices, Heartbeat, Activities, Check-ins, etc.)|
+-------------------------------------------------------------------------------+
```

### 3.1 Tier 1: Functional Feature Coverage (`>=5` per feature)
Covers all 14 core backend features defined in `PROJECT.md § Feature Inventory`:
1. **Auth & JWT Tokens**: Registration, Login, Token Refresh, Duplicate Email Rejection, Invalid Credentials.
2. **Device Management**: Device Registration, Device Listing, Device Details, Token Update, Device Revocation.
3. **Heartbeat Ingestion (Weight 0.0)**: Successful Heartbeat, Device LastSeen Update, Battery Reporting, Zero Weight Invariant, Online Operational State.
4. **Meaningful Activity Ingestion**: App Foreground, Charger Connected, Screen Interaction, Confidence Filtering, Clock Advancement.
5. **One-Touch Check-in ("Tôi vẫn ổn")**: Valid Check-in, Weight 1.0 Assignment, Location Capture, Note Preservation, State Reset to ACTIVE.
6. **Idempotency & Concurrency**: Duplicate eventId returns original, Duplicate Check-in returns original, Header X-Event-ID fallback, No duplicate row creation, Distinct eventIds create separate records.
7. **Timezone Calendar Windows**: Active Window Match, Inactive Window Rescheduling, Day-of-Week Boundary, IANA Timezone Resolution, 24/7 Default Fallback.
8. **Inactivity Worker & Row Locking**: Inactivity Detection, State Transition to CHECK_IN_REQUIRED, Grace Period Expiry to WARNING, Skip Locked Row Batching, Batch Limit Adherence.
9. **Monitoring State Machine**: ACTIVE to CHECK_IN_REQUIRED, CHECK_IN_REQUIRED to WARNING, Any Alert State to ACTIVE via Check-in, Pause to SUSPENDED, Resume to ACTIVE.
10. **Redis Degradation & Fallback**: Lock Acquisition, Lock Release, Degraded Ingestion without Redis Crash, Health Check Status Reporting, Cache Bypass.
11. **Incident Creation & Risk Scoring**: Missed Check-in Incident Creation, Base Score Calculation, Low Battery Penalty Addition, Offline Device Penalty Addition, Clamped Risk Score (0-100).
12. **Multi-Channel Escalation Engine**: Calm Check-in Push Dispatch, Warning Escalation Push Dispatch, Guardian Incident Dispatch, Delivery Audit Logging, Missing Token Graceful Failure.
13. **Incident Acknowledgment & Resolution**: Guardian Acknowledgment, Non-Guardian Rejection (403), Resolution with Note, Monitored User Self-Resolution, Unrelated User Rejection (403).
14. **Route Aliases & Contract Compatibility**: POST `/heartbeat` reachability, POST `/activities/heartbeat` alias reachability, GET `/users/me` profile retrieval, PATCH `/users/me` profile update, Pause/Resume monitoring config.

### 3.2 Tier 2: Boundary & Corner Cases (`>=5` per feature)
Covers extreme inputs, edge values, and operational anomalies:
- Clock skew: Client timestamp in future clamped to server time; timestamps from far past.
- Battery levels: Boundary 0% and 100%, negative or >100% rejection.
- Overnight schedule windows: `22:00 -> 06:00` spanning midnight in target timezone.
- Rate limits: Rapid burst heartbeats within 30 seconds.
- Confidence thresholds: Below minimum confidence stored for audit but zero clock advancement.
- Large payload handling, unicode and Vietnamese special characters in notes and names.
- Zero-length inputs, missing optional parameters, UUID validation failures.

### 3.3 Tier 3: Cross-Feature Pairwise Combinations
Evaluates interactions between orthogonal subsystems:
1. Heartbeat received during Inactivity (Reachability updated, but timer NOT reset).
2. Meaningful Activity received during `CHECK_IN_REQUIRED` (resets evaluation timer).
3. Check-in received during active `WARNING` with open `Incident` (state reverts to `ACTIVE`, incident auto-resolves).
4. Redis failure during Inactivity Worker batch evaluation (database row lock maintains exclusivity).
5. Rapid concurrent duplicate check-ins during incident resolution (idempotency prevents double state mutations).
6. Device revoked while monitoring is active (revoked device blocked from sending events).
7. Pause monitoring while near inactivity threshold, then resume (clock freeze and resumption).
8. Timezone modification on user profile dynamically altering schedule window evaluation.
9. Guardian acknowledges incident, followed by Monitored User check-in (recovers to `ACTIVE`).
10. Batch ingestion containing mixture of valid, zero-weight, and duplicate events.

### 3.4 Tier 4: Real-World End-to-End Lifecycles
Full 10-phase automated simulation of a complete incident lifecycle:
1. Identity & Device Setup (Guardian & Monitored User with devices and FCM tokens).
2. Pairing & Schedule Setup (Invite code exchange, custom threshold, location consent).
3. Normal Routine Simulation (Periodic Heartbeats confirming reachability without resetting inactivity).
4. Passive Activity Ingestion (Screen interaction, App Foreground resetting inactivity clock).
5. Inactivity Window Timeout (Elapsed time triggers `CHECK_IN_REQUIRED` + Calm Check-in Push).
6. Missed Check-in Expiry (Grace period expires -> `WARNING` state + Risk Score heuristic calculation + Incident creation).
7. Incident Escalation (Worker escalates incident to `ESCALATED`).
8. Guardian Acknowledgment (Guardian reviews incident and acknowledges receipt).
9. Monitored User Recovery (User sends "Tôi vẫn ổn" check-in with GPS location -> State resets to `ACTIVE`, Incident auto-resolves).
10. System Health & Audit Inspection (Audit trail intact, incident history updated, state verified).

---

## 4. Test Suite Directory Layout

```
backend/
├── test/
│   ├── e2e/
│   │   ├── tier1-features.spec.ts   # Tier 1: Functional Feature Coverage (>=5/feature)
│   │   ├── tier2-boundaries.spec.ts # Tier 2: Boundary & Corner Cases (>=5/feature)
│   │   ├── tier3-pairwise.spec.ts   # Tier 3: Cross-Feature Pairwise Interactions
│   │   └── tier4-lifecycle.spec.ts  # Tier 4: End-to-End Real-World Incident Lifecycle
│   ├── carely-integration.spec.ts   # Core integration test suite
│   └── vitest.config.ts             # Vitest test configuration
```

---

## 5. Execution Commands & Verification Guide

### 5.1 Run Full Test Suite
```bash
cd /home/tnuc/project/Carely/backend
npm test
```

### 5.2 Run Dedicated E2E Test Tiers
```bash
cd /home/tnuc/project/Carely/backend

# Run Tier 1 only
npx vitest run test/e2e/tier1-features.spec.ts

# Run Tier 2 only
npx vitest run test/e2e/tier2-boundaries.spec.ts

# Run Tier 3 only
npx vitest run test/e2e/tier3-pairwise.spec.ts

# Run Tier 4 only
npx vitest run test/e2e/tier4-lifecycle.spec.ts

# Run All E2E Suites
npx vitest run test/e2e
```

### 5.3 Mobile Verification
```bash
cd /home/tnuc/project/Carely/mobile
flutter analyze
flutter test
```

---

## 6. Expected Output Derivation Matrix

| Feature / Behavior | Authoritative Spec Source | Expected Observable Output |
|---|---|---|
| Heartbeat Ingestion | `PROJECT.md` §1, `ARCHITECTURE.md` §2 | HTTP 200, `operationalState: 'ONLINE'`, `lastMeaningfulActivityAt` unchanged |
| Meaningful Activity | `PROJECT.md` §1, `DATABASE.md` §2.7 | HTTP 201, `weight > 0`, `lastMeaningfulActivityAt` updated |
| Idempotency Deduplication | `PROJECT.md` §1, `DATABASE.md` §2.8 | HTTP 200/201 on repeat, exact same record ID, no duplicate rows |
| Check-in Recovery | `MONITORING_STATE_MACHINE.md` §4 | HTTP 201, state resets to `ACTIVE`, pending incident status `RESOLVED` |
| Risk Scoring Clamping | `MONITORING_STATE_MACHINE.md` §5 | Clamped `0 <= riskScore <= 100`, non-diagnostic disclaimer present |
| Overnight Schedule | `MONITORING_STATE_MACHINE.md` §3 | `isWithinActiveWindow` returns true between 22:00 and 06:00 in IANA timezone |
| Incident Acknowledgment | `API.md` §7.2, `incidents.service.ts` | HTTP 200, status `ACKNOWLEDGED`, `acknowledgedBy` set, 403 for non-guardians |
