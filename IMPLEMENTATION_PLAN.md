# IMPLEMENTATION PLAN: CARELY - INACTIVITY MONITOR / DEAD MAN'S SWITCH

## 1. Current Architecture
- **Repository state**: Empty workspace (`/home/tnuc/project/Carely`), no prior files or git history.
- **Host environment**:
  - OS: Linux x86_64
  - Node.js: `v22.22.3` / npm `9.2.0`
  - Flutter: `3.47.4` / Dart `3.13.3`
  - Docker & Docker Compose: Docker `29.1.3` / Docker Compose `v5.1.2`
  - Active listening ports on host: 5432, 5433, 5434 (existing Postgres containers), 3000, 8080.
  - Available ports for Carely: 5435 (PostgreSQL), 6379 (Redis), 4000 (Backend API).

## 2. Problems & Core Challenges Addressed
- **The Heartbeat vs. Activity Trap**: Systems often mistakenly equate device ping/heartbeat with human presence. An automated background heartbeat does not prove human well-being.
- **OS Background Execution Limits**: Modern Android (Doze mode, battery restrictions) and iOS (BackgroundTasks throttling, suspended state) prevent continuous timers (`Timer.periodic` fails when app is backgrounded/killed).
- **Alarmist / Panic UX**: False alarms cause extreme emotional distress to family members. Wording like "user may be dead" is harmful and clinically unfounded.
- **Worker Concurrency & Reliability**: Uncoordinated workers can trigger duplicate incident alerts; worker crashes can leave evaluations in limbo; Redis failure must not stop monitoring.
- **Privacy Violations**: Unrestricted GPS tracking and intrusive sensor monitoring violate user trust and drain battery.

## 3. Target Architecture
A decoupled, resilient event-driven architecture based on the core axiom:
> **"Server is Authoritative, Mobile is Opportunistic."**

```
Mobile Device (Flutter)
  ├── Lifecycle Observer (APP_OPEN, APP_FOREGROUND)
  ├── Battery / Charging state change
  ├── Opportunistic WorkManager Heartbeat (15-30m)
  └── Manual "Tôi vẫn ổn" Check-in Button
         │
         ▼ (HTTPS / REST API)
Backend (NestJS + TypeScript)
  ├── Auth Guard & Device Ownership Verifier
  ├── Ingestion & Idempotency Filter (eventId)
  ├── Activity Engine & Policy Evaluator (weights 0.0 - 1.0)
  ├── Monitoring State Machine
  └── Incident & Alert Engine (FCM + Stubs)
         │
         ▼
Database: PostgreSQL 16 (Source of Truth)
Cache/Lock: Redis 7 (Distributed lock, rate limit, worker coordination, fallback to DB lock)
         ▲
         │
Worker Service (Monitoring Engine & Inactivity Evaluator)
  ├── Skip-locked evaluation queue (`WHERE next_evaluation_at <= NOW()`)
  ├── Timezone-aware active window scheduler
  └── Risk evaluation engine (composite score without medical assertions)
```

## 4. Database Changes (PostgreSQL Schema)
PostgreSQL is the single Source of Truth. The following relational structure will be migrated:

1. **`users`**:
   - `id` (UUID PK), `email`, `password_hash`, `display_name`, `phone_number`, `timezone`, `created_at`, `updated_at`, `deleted_at`.
2. **`devices`**:
   - `id` (UUID PK), `user_id` (FK), `device_uid`, `platform` (ANDROID, IOS), `device_name`, `push_token`, `app_version`, `os_version`, `last_seen_at`, `last_heartbeat_at`, `battery_level`, `is_charging`, `is_active`, `revoked_at`, `created_at`, `updated_at`.
3. **`monitoring_relationships`**:
   - `id` (UUID PK), `monitor_id` (FK users), `monitored_user_id` (FK users), `status` (`PENDING`, `ACCEPTED`, `REJECTED`, `SUSPENDED`), `invitation_code`, `created_at`, `updated_at`.
4. **`monitoring_configs`**:
   - `id` (UUID PK), `relationship_id` (FK unique), `enabled`, `timezone`, `inactivity_threshold_minutes`, `check_in_grace_minutes`, `warning_escalation_minutes`, `require_check_in`, `location_enabled`, `activity_types` (JSONB), `escalation_policy` (JSONB), `current_state` (enum), `last_meaningful_activity_at`, `next_evaluation_at`, `created_at`, `updated_at`.
5. **`monitoring_schedule_windows`**:
   - `id` (UUID PK), `config_id` (FK), `day_of_week` (0-6), `start_time` (HH:mm), `end_time` (HH:mm), `is_enabled`, `created_at`, `updated_at`.
6. **`activity_policies`**:
   - `id` (UUID PK), `relationship_id` (FK nullable), `activity_type`, `weight`, `min_confidence`, `cooldown_seconds`, `is_meaningful`, `created_at`, `updated_at`.
7. **`activities`**:
   - `id` (UUID PK), `event_id` (UUID unique), `user_id` (FK), `device_id` (FK), `type` (`APP_OPEN`, `APP_FOREGROUND`, `CHECK_IN`, `SCREEN_INTERACTION`, `STEP_DETECTED`, `DEVICE_MOTION`, `CHARGER_CONNECTED`, `CHARGER_DISCONNECTED`, `LOCATION_UPDATE`, `HEARTBEAT`), `weight`, `confidence`, `occurred_at`, `received_at`, `source`, `metadata` (JSONB), `created_at`.
8. **`check_ins`**:
   - `id` (UUID PK), `event_id` (UUID unique), `user_id` (FK), `device_id` (FK), `relationship_id` (FK nullable), `occurred_at`, `received_at`, `battery_level`, `note`, `created_at`.
9. **`incidents`**:
   - `id` (UUID PK), `user_id` (FK), `relationship_id` (FK), `status` (`OPEN`, `ESCALATED`, `ACKNOWLEDGED`, `RESOLVED`, `CANCELLED`), `reason` (`INACTIVITY`, `MISSED_CHECK_IN`, `DEVICE_OFFLINE`), `risk_score`, `detected_at`, `last_activity_at`, `last_heartbeat_at`, `last_location_id`, `check_in_deadline`, `escalated_at`, `acknowledged_at`, `acknowledged_by`, `resolved_at`, `resolved_by`, `next_action_at`, `created_at`, `updated_at`.
10. **`incident_events`**:
    - `id` (UUID PK), `incident_id` (FK), `type` (`INCIDENT_CREATED`, `CHECK_IN_REQUESTED`, `PUSH_SENT`, `PUSH_FAILED`, `REMINDER_SENT`, `WARNING_TRIGGERED`, `ESCALATION_TRIGGERED`, `MONITOR_NOTIFIED`, `MONITOR_ACKNOWLEDGED`, `INCIDENT_RESOLVED`), `timestamp`, `metadata` (JSONB), `created_at`.
11. **`locations`**:
    - `id` (UUID PK), `user_id` (FK), `device_id` (FK), `latitude`, `longitude`, `accuracy`, `captured_at`, `source` (`CHECK_IN`, `INCIDENT`, `MANUAL`, `ACTIVITY`), `created_at`.
12. **`notification_channels` & `notification_deliveries`**:
    - For delivery tracking, exponential backoff retries, and multi-channel notification dispatch.
13. **`audit_logs`**:
    - Complete action and security tracking.

Indexes planned:
- `activities(user_id, occurred_at DESC)`
- `activities(event_id)` UNIQUE
- `incidents(user_id, status)`
- `incidents(status, next_action_at)`
- `devices(user_id, is_active)`
- `monitoring_relationships(monitor_id, monitored_user_id)`
- `monitoring_configs(next_evaluation_at)` WHERE enabled = true

## 5. API Changes (REST v1)
- **Auth**:
  - `POST /api/v1/auth/register`
  - `POST /api/v1/auth/login`
  - `POST /api/v1/auth/refresh`
  - `POST /api/v1/auth/logout`
- **Devices**:
  - `POST /api/v1/devices` (register / update FCM token)
  - `GET /api/v1/devices`
  - `POST /api/v1/devices/:id/revoke`
  - `DELETE /api/v1/devices/:id`
- **Monitoring**:
  - `POST /api/v1/monitoring/relationships` (invite)
  - `GET /api/v1/monitoring/relationships` (list monitoring & monitored relationships)
  - `GET /api/v1/monitoring/relationships/:id`
  - `POST /api/v1/monitoring/relationships/accept`
  - `PATCH /api/v1/monitoring/relationships/:id`
  - `GET /api/v1/monitoring/:id/config`
  - `PATCH /api/v1/monitoring/:id/config`
- **Activity & Heartbeat**:
  - `POST /api/v1/heartbeat` (updates device lastSeenAt, battery, charging; weight = 0.0)
  - `POST /api/v1/activities` (ingests activities with eventId deduplication and weight evaluation)
- **Check-in**:
  - `POST /api/v1/check-ins` ("Tôi vẫn ổn" - weight 1.0, reverts to ACTIVE, closes open incidents)
  - `GET /api/v1/check-ins`
- **Incidents**:
  - `GET /api/v1/incidents`
  - `GET /api/v1/incidents/:id`
  - `POST /api/v1/incidents/:id/acknowledge` (Monitor only)
  - `POST /api/v1/incidents/:id/resolve`
- **Location**:
  - `POST /api/v1/locations` (opportunistic single-shot)
  - `GET /api/v1/locations/latest` (authorized by relationship policy)

## 6. Mobile Changes (Flutter Clean Architecture)
- Feature-first structure:
  - `features/auth`: Login, Register, Session restore.
  - `features/dashboard`: Dual-perspective (Monitor view & Monitored view), status indicators, battery and last activity display.
  - `features/check_in`: Clean, calm, one-tap "Tôi vẫn ổn" reassurance screen.
  - `features/monitoring`: Schedule windows config, inactivity threshold settings, location consent toggle.
  - `features/incidents`: Incident timeline, acknowledge button for Monitor.
  - `features/devices`: Device list, status, revoke controls.
  - `features/settings`: Privacy controls, pause/resume monitoring, delete activity data.
- Background & Sensors Services:
  - `WorkManager` (Android) / `BackgroundTasks` (iOS) opportunistic periodic task (15-30 min) for heartbeat.
  - `WidgetsBindingObserver` for `APP_OPEN` and `APP_FOREGROUND`.
  - `BatteryService` for `CHARGER_CONNECTED` / `CHARGER_DISCONNECTED`.
  - Graceful degradation: never crash on permission denial; display clear status "Thiết bị ngoại tuyến" instead of false emergency alarms.

## 7. Worker Changes (Monitoring Engine)
- **Worker Execution Loop**:
  - Polls `monitoring_configs WHERE enabled = true AND next_evaluation_at <= NOW() LIMIT 50` using `FOR UPDATE SKIP LOCKED`.
  - Uses Redis distributed lock (`monitoring:lock:{relationshipId}`) with fallback to database row locks if Redis fails.
- **Evaluation Logic**:
  - Checks current time against active schedule windows in user's timezone.
  - Outside window: reschedules `next_evaluation_at` to the start of the next window.
  - Inside window:
    - If `now - last_meaningful_activity_at >= inactivityThresholdMinutes`:
      - Transitions state to `CHECK_IN_REQUIRED`.
      - Dispatches Check-in push notification to Monitored User.
      - Sets `next_evaluation_at = NOW() + checkInGraceMinutes`.
    - If state is `CHECK_IN_REQUIRED` and grace period expired:
      - Computes composite `riskScore` (inactivity + missed check-in + device offline + battery level).
      - Creates `Incident` record and logs `incident_events`.
      - Transitions state to `WARNING` / `ESCALATED`.
      - Dispatches alert notification to Monitor.
      - Sets `next_evaluation_at = NOW() + warningEscalationMinutes`.

## 8. Testing Plan
- **Unit Tests**:
  - `ActivityPolicyService` weight calculations and qualification.
  - `ScheduleEngine` active window checks across timezones and overnight boundaries.
  - `MonitoringStateMachine` transition invariants.
  - `RiskEvaluation` scoring formula.
- **Integration Tests**:
  - Full flow: Heartbeat -> Activity -> Inactivity -> Check-in -> Revert to ACTIVE.
  - Escalation flow: Inactivity -> Missed check-in -> Incident creation -> Notification -> Acknowledge -> Resolve.
- **Concurrency & Idempotency Tests**:
  - 2 concurrent workers attempting to process the same relationship concurrently: only 1 acquires lock, exactly 1 incident created.
  - Duplicate `eventId` submitted twice: returns duplicate response without duplicating activities.
- **Redis Crash Recovery Test**:
  - Simulates Redis disconnect; verifies that worker and API continue via PostgreSQL transactions without crashing.

## 9. Migration Plan
- Since repository is clean, migrations will be initialized as clean, reproducible TypeORM / SQL migration scripts:
  - `001_initial_schema.sql` (Creates all 14 tables, UUID extensions, and indexes).
  - Seed script for system default activity policies.
- Docker compose handles bringing up PostgreSQL 16 (port 5435), Redis 7 (port 6379), Backend API (port 4000), and Worker service.
