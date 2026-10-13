# Carely Database Schema & Data Dictionary

## 1. Database Overview
* **RDBMS**: PostgreSQL 16 (Port `5435`)
* **Default Database**: `carely_db`
* **Default User**: `carely_user`
* **Migration Path**: `backend/src/database/migrations/001_init_schema.sql`

---

## 2. Table Specifications & Data Dictionary

### 2.1 `users`
Stores user profile information, authentication credentials, and timezone preferences.

| Column | Type | Constraints | Description |
| :--- | :--- | :--- | :--- |
| `id` | UUID | PRIMARY KEY, DEFAULT `gen_random_uuid()` | Unique user identifier |
| `email` | VARCHAR(255) | UNIQUE, NOT NULL | Account email address |
| `password_hash` | VARCHAR(255) | NOT NULL | Bcrypt hash with cost factor 12 |
| `full_name` | VARCHAR(255) | NOT NULL | Display name |
| `phone` | VARCHAR(50) | NULL | Emergency SMS contact number |
| `timezone` | VARCHAR(64) | NOT NULL, DEFAULT `'Asia/Ho_Chi_Minh'` | IANA timezone for schedule evaluation |
| `is_active` | BOOLEAN | NOT NULL, DEFAULT `TRUE` | Soft-delete flag for GDPR compliance |
| `created_at` | TIMESTAMPTZ | NOT NULL, DEFAULT `NOW()` | Record creation timestamp |
| `updated_at` | TIMESTAMPTZ | NOT NULL, DEFAULT `NOW()` | Record modification timestamp |

---

### 2.2 `refresh_tokens`
Tracks active refresh tokens for session rotation and revocation.

| Column | Type | Constraints | Description |
| :--- | :--- | :--- | :--- |
| `id` | UUID | PRIMARY KEY, DEFAULT `gen_random_uuid()` | Unique identifier |
| `user_id` | UUID | NOT NULL, REFERENCES `users(id)` ON DELETE CASCADE | Token owner |
| `token_hash` | VARCHAR(255) | NOT NULL | SHA-256 hash of the refresh token |
| `device_id` | VARCHAR(255) | NULL | Associated device ID |
| `expires_at` | TIMESTAMPTZ | NOT NULL | Token expiration boundary |
| `revoked_at` | TIMESTAMPTZ | NULL | Revocation timestamp if invalidated |
| `created_at` | TIMESTAMPTZ | NOT NULL, DEFAULT `NOW()` | Token issuance time |

---

### 2.3 `devices`
Tracks user mobile hardware, push notification tokens, and operational heartbeats.

| Column | Type | Constraints | Description |
| :--- | :--- | :--- | :--- |
| `id` | UUID | PRIMARY KEY, DEFAULT `gen_random_uuid()` | Unique device identifier |
| `user_id` | UUID | NOT NULL, REFERENCES `users(id)` ON DELETE CASCADE | Associated user |
| `platform` | VARCHAR(32) | NOT NULL | `ANDROID`, `IOS`, or `WEB` |
| `device_model` | VARCHAR(128) | NULL | Hardware model description |
| `os_version` | VARCHAR(64) | NULL | Operating system version |
| `app_version` | VARCHAR(32) | NULL | Installed Carely build version |
| `fcm_token` | TEXT | NULL | Firebase Cloud Messaging push token |
| `battery_level` | SMALLINT | NULL | Current battery percentage (0-100) |
| `is_charging` | BOOLEAN | NULL | Power connection status |
| `last_heartbeat_at`| TIMESTAMPTZ | NULL | Last reachability ping time |
| `is_active` | BOOLEAN | NOT NULL, DEFAULT `TRUE` | Device authorization status |
| `created_at` | TIMESTAMPTZ | NOT NULL, DEFAULT `NOW()` | Device registration time |

---

### 2.4 `relationships`
Defines pairing between a Monitored individual and a Guardian (Monitor).

| Column | Type | Constraints | Description |
| :--- | :--- | :--- | :--- |
| `id` | UUID | PRIMARY KEY, DEFAULT `gen_random_uuid()` | Relationship identifier |
| `monitored_user_id`| UUID | NOT NULL, REFERENCES `users(id)` | Person being monitored |
| `monitor_user_id` | UUID | NOT NULL, REFERENCES `users(id)` | Guardian / family member |
| `status` | VARCHAR(32) | NOT NULL, DEFAULT `'PENDING'` | `PENDING`, `ACCEPTED`, `REJECTED`, `REVOKED` |
| `invite_code` | VARCHAR(64) | NULL | Human-shareable join code |
| `invite_expires_at`| TIMESTAMPTZ | NULL | Join code expiration |
| `label` | VARCHAR(128) | NULL | Friendly relationship name (e.g., "Mẹ") |
| `created_at` | TIMESTAMPTZ | NOT NULL, DEFAULT `NOW()` | Creation timestamp |

---

### 2.5 `monitoring_configs`
The central authoritative monitoring configuration and state machine registry per relationship.

| Column | Type | Constraints | Description |
| :--- | :--- | :--- | :--- |
| `id` | UUID | PRIMARY KEY, DEFAULT `gen_random_uuid()` | Configuration identifier |
| `relationship_id` | UUID | NOT NULL, UNIQUE, REFERENCES `relationships(id)` | Associated relationship |
| `current_state` | VARCHAR(32) | NOT NULL, DEFAULT `'ACTIVE'` | Current state machine position |
| `inactivity_threshold_minutes` | INT | NOT NULL, DEFAULT `180` | Allowable silence window (e.g. 3 hours) |
| `check_in_grace_period_minutes` | INT | NOT NULL, DEFAULT `30` | Time permitted for user check-in |
| `escalation_grace_period_minutes`| INT | NOT NULL, DEFAULT `30` | Time before escalating to guardians |
| `location_enabled` | BOOLEAN | NOT NULL, DEFAULT `TRUE` | Privacy gate for single-shot location |
| `is_paused` | BOOLEAN | NOT NULL, DEFAULT `FALSE` | Manual privacy pause toggle |
| `paused_until` | TIMESTAMPTZ | NULL | Scheduled resume timestamp |
| `last_meaningful_activity_at` | TIMESTAMPTZ | NULL | Last qualified user activity |
| `check_in_requested_at` | TIMESTAMPTZ | NULL | When `CHECK_IN_REQUIRED` was triggered |
| `grace_period_started_at` | TIMESTAMPTZ | NULL | When `GRACE_PERIOD` began |
| `alert_triggered_at` | TIMESTAMPTZ | NULL | When `ALERT_TRIGGERED` occurred |
| `next_evaluation_at` | TIMESTAMPTZ | NOT NULL, DEFAULT `NOW()` | Indexable worker evaluation clock |

---

### 2.6 `monitoring_schedule_windows`
Defines active monitoring time intervals per day of week (supports overnight shifts).

| Column | Type | Constraints | Description |
| :--- | :--- | :--- | :--- |
| `id` | UUID | PRIMARY KEY, DEFAULT `gen_random_uuid()` | Window identifier |
| `monitoring_config_id` | UUID | NOT NULL, REFERENCES `monitoring_configs(id)` | Parent config |
| `day_of_week` | SMALLINT | NOT NULL | 0 (Sun) to 6 (Sat) |
| `start_time` | TIME | NOT NULL | Window start (e.g., `07:00:00`) |
| `end_time` | TIME | NOT NULL | Window end (e.g., `22:00:00`) |
| `is_active` | BOOLEAN | NOT NULL, DEFAULT `TRUE` | Enable/disable window |

---

### 2.7 `activity_policies`
Authoritative weights and confidence thresholds for incoming activity types.

| Column | Type | Constraints | Description |
| :--- | :--- | :--- | :--- |
| `id` | UUID | PRIMARY KEY, DEFAULT `gen_random_uuid()` | Policy identifier |
| `activity_type` | VARCHAR(64) | UNIQUE, NOT NULL | Activity enum key |
| `weight` | NUMERIC(3,2) | NOT NULL, CHECK `weight BETWEEN 0.0 AND 1.0` | Algorithmic weight |
| `min_confidence` | NUMERIC(3,2) | NOT NULL, DEFAULT `0.50` | Threshold required to qualify as meaningful |
| `description` | TEXT | NULL | Documentation of activity source |

---

### 2.8 `activities`
Immutable log of all user activities and reachability heartbeats.

| Column | Type | Constraints | Description |
| :--- | :--- | :--- | :--- |
| `id` | UUID | PRIMARY KEY, DEFAULT `gen_random_uuid()` | Record identifier |
| `event_id` | UUID | UNIQUE, NOT NULL | Client-generated idempotency UUID |
| `user_id` | UUID | NOT NULL, REFERENCES `users(id)` | Emitting user |
| `device_id` | UUID | NULL, REFERENCES `devices(id)` | Emitting hardware |
| `activity_type` | VARCHAR(64) | NOT NULL | Event classification |
| `confidence_score`| NUMERIC(3,2) | NOT NULL, DEFAULT `1.00` | Client/sensor reported confidence |
| `occurred_at` | TIMESTAMPTZ | NOT NULL | Client-reported event timestamp |
| `received_at` | TIMESTAMPTZ | NOT NULL, DEFAULT `NOW()` | Server receipt timestamp |
| `metadata` | JSONB | NULL | Sensor or context payloads |

---

### 2.9 `check_ins`
Explicit "Tôi vẫn ổn" confirmations.

| Column | Type | Constraints | Description |
| :--- | :--- | :--- | :--- |
| `id` | UUID | PRIMARY KEY, DEFAULT `gen_random_uuid()` | Check-in identifier |
| `user_id` | UUID | NOT NULL, REFERENCES `users(id)` | User confirming safety |
| `relationship_id` | UUID | NULL, REFERENCES `relationships(id)` | Optional target relationship |
| `device_id` | UUID | NULL, REFERENCES `devices(id)` | Originating device |
| `occurred_at` | TIMESTAMPTZ | NOT NULL, DEFAULT `NOW()` | Confirmation timestamp |
| `battery_level` | SMALLINT | NULL | Battery percentage at confirmation |
| `note` | TEXT | NULL | Optional reassurance note from user |
| `location_id` | UUID | NULL, REFERENCES `locations(id)` | Linked single-shot location |

---

### 2.10 `incidents`
Safety incident records created when check-in deadlines lapse.

| Column | Type | Constraints | Description |
| :--- | :--- | :--- | :--- |
| `id` | UUID | PRIMARY KEY, DEFAULT `gen_random_uuid()` | Incident identifier |
| `relationship_id` | UUID | NOT NULL, REFERENCES `relationships(id)` | Affected relationship |
| `monitored_user_id`| UUID | NOT NULL, REFERENCES `users(id)` | At-risk user |
| `status` | VARCHAR(32) | NOT NULL, DEFAULT `'TRIGGERED'` | `TRIGGERED`, `ESCALATED`, `ACKNOWLEDGED`, `RESOLVED`, `FALSE_ALARM` |
| `reason` | VARCHAR(64) | NOT NULL | Root cause of trigger |
| `risk_score` | SMALLINT | NOT NULL, CHECK `risk_score BETWEEN 0 AND 100` | Composite risk score |
| `triggered_at` | TIMESTAMPTZ | NOT NULL, DEFAULT `NOW()` | Creation time |
| `escalated_at` | TIMESTAMPTZ | NULL | When notifications escalated |
| `acknowledged_at`| TIMESTAMPTZ | NULL | When guardian acknowledged |
| `acknowledged_by_user_id` | UUID | NULL, REFERENCES `users(id)` | Acknowledging guardian |
| `resolved_at` | TIMESTAMPTZ | NULL | Resolution time |
| `resolved_by_user_id` | UUID | NULL, REFERENCES `users(id)` | Resolving user |
| `resolution_note`| TEXT | NULL | Resolution rationale |

---

### 2.11 `incident_events`
Immutable step-by-step audit trail for each incident.

| Column | Type | Constraints | Description |
| :--- | :--- | :--- | :--- |
| `id` | UUID | PRIMARY KEY, DEFAULT `gen_random_uuid()` | Event identifier |
| `incident_id` | UUID | NOT NULL, REFERENCES `incidents(id)` | Parent incident |
| `event_type` | VARCHAR(64) | NOT NULL | Event categorization |
| `description` | TEXT | NOT NULL | Human-readable event description |
| `metadata` | JSONB | NULL | Contextual data |
| `created_at` | TIMESTAMPTZ | NOT NULL, DEFAULT `NOW()` | Event timestamp |

---

### 2.12 `locations`
Privacy-gated single-shot location coordinates.

| Column | Type | Constraints | Description |
| :--- | :--- | :--- | :--- |
| `id` | UUID | PRIMARY KEY, DEFAULT `gen_random_uuid()` | Record identifier |
| `user_id` | UUID | NOT NULL, REFERENCES `users(id)` | Location owner |
| `latitude` | NUMERIC(10,7) | NOT NULL | Latitude coordinate |
| `longitude` | NUMERIC(10,7) | NOT NULL | Longitude coordinate |
| `accuracy_meters` | NUMERIC(8,2) | NULL | GPS accuracy circle |
| `recorded_at` | TIMESTAMPTZ | NOT NULL | Timestamp when captured |
| `created_at` | TIMESTAMPTZ | NOT NULL, DEFAULT `NOW()` | Database write timestamp |

---

### 2.13 `notification_deliveries`
Tracks delivery status and retries across push notification and SMS channels.

| Column | Type | Constraints | Description |
| :--- | :--- | :--- | :--- |
| `id` | UUID | PRIMARY KEY, DEFAULT `gen_random_uuid()` | Delivery identifier |
| `recipient_user_id` | UUID | NOT NULL, REFERENCES `users(id)` | Recipient |
| `channel_type` | VARCHAR(32) | NOT NULL | `FCM_PUSH`, `SMS`, `TELEGRAM` |
| `title` | VARCHAR(255) | NOT NULL | Notification title |
| `body` | TEXT | NOT NULL | Calm, neutral notification copy |
| `status` | VARCHAR(32) | NOT NULL, DEFAULT `'PENDING'` | `PENDING`, `SENT`, `DELIVERED`, `FAILED` |
| `attempts` | SMALLINT | NOT NULL, DEFAULT `0` | Retry attempt counter |
| `last_attempt_at`| TIMESTAMPTZ | NULL | Timestamp of most recent dispatch |

---

### 2.14 `audit_logs`
System-wide security and compliance audit log.

| Column | Type | Constraints | Description |
| :--- | :--- | :--- | :--- |
| `id` | UUID | PRIMARY KEY, DEFAULT `gen_random_uuid()` | Log entry ID |
| `user_id` | UUID | NULL, REFERENCES `users(id)` | Actor ID |
| `action` | VARCHAR(128) | NOT NULL | Action key |
| `entity_type` | VARCHAR(64) | NOT NULL | Affected entity |
| `entity_id` | UUID | NULL | Affected entity primary key |
| `metadata` | JSONB | NULL | Pre- and post-action state |
| `created_at` | TIMESTAMPTZ | NOT NULL, DEFAULT `NOW()` | Timestamp |

---

## 3. High-Performance Indexing Strategy

1. **`idx_monitoring_configs_eval`**:
   `CREATE INDEX idx_monitoring_configs_eval ON monitoring_configs (next_evaluation_at) WHERE is_paused = FALSE;`
   Enables lightning-fast index scans for the background worker to fetch due evaluations.
2. **`idx_activities_user_occurred`**:
   `CREATE INDEX idx_activities_user_occurred ON activities (user_id, occurred_at DESC);`
   Accelerates inspection of a user's recent activities without sequential table scans.
3. **`idx_incidents_active`**:
   `CREATE INDEX idx_incidents_active ON incidents (relationship_id, status) WHERE status IN ('TRIGGERED', 'ESCALATED');`
   Guarantees instant check for existing open incidents before escalation.
4. **`idx_devices_user_heartbeat`**:
   `CREATE INDEX idx_devices_user_heartbeat ON devices (user_id, last_heartbeat_at DESC);`
   Speeds up device battery and connectivity checks during risk evaluation.
