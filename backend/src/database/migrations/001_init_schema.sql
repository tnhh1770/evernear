-- Extension for UUID generation
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- USERS TABLE
CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    display_name VARCHAR(255) NOT NULL,
    phone_number VARCHAR(50),
    avatar_url TEXT,
    timezone VARCHAR(100) DEFAULT 'Asia/Ho_Chi_Minh' NOT NULL,
    preferred_language VARCHAR(10) DEFAULT 'vi' NOT NULL,
    google_id VARCHAR(255),
    apple_id VARCHAR(255),
    auth_provider VARCHAR(50) DEFAULT 'LOCAL' NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    deleted_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_users_google_id ON users(google_id);
CREATE INDEX IF NOT EXISTS idx_users_apple_id ON users(apple_id);

-- DEVICES TABLE
CREATE TABLE IF NOT EXISTS devices (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    device_uid VARCHAR(255) NOT NULL,
    platform VARCHAR(20) NOT NULL, -- ANDROID, IOS, WEB
    device_name VARCHAR(255) NOT NULL,
    push_token TEXT,
    app_version VARCHAR(50),
    os_version VARCHAR(50),
    last_seen_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    last_heartbeat_at TIMESTAMPTZ,
    battery_level INT,
    is_charging BOOLEAN DEFAULT FALSE,
    is_active BOOLEAN DEFAULT TRUE NOT NULL,
    revoked_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    CONSTRAINT uq_user_device_uid UNIQUE (user_id, device_uid)
);

CREATE INDEX IF NOT EXISTS idx_devices_user_active ON devices(user_id, is_active);

-- MONITORING RELATIONSHIPS TABLE
CREATE TABLE IF NOT EXISTS monitoring_relationships (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    monitor_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    monitored_user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    status VARCHAR(50) DEFAULT 'PENDING' NOT NULL, -- PENDING, ACCEPTED, REJECTED, SUSPENDED
    invitation_code VARCHAR(32),
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    CONSTRAINT uq_monitor_monitored UNIQUE (monitor_id, monitored_user_id),
    CONSTRAINT chk_not_self_monitoring CHECK (monitor_id != monitored_user_id)
);

CREATE INDEX IF NOT EXISTS idx_monitoring_relationships_pair ON monitoring_relationships(monitor_id, monitored_user_id);
CREATE INDEX IF NOT EXISTS idx_monitoring_relationships_monitored ON monitoring_relationships(monitored_user_id, status);

-- PAIRING INVITATIONS TABLE
CREATE TABLE IF NOT EXISTS pairing_invitations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    inviter_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    invitation_code VARCHAR(32) UNIQUE NOT NULL,
    role VARCHAR(20) DEFAULT 'MONITORED' NOT NULL,
    label VARCHAR(100),
    status VARCHAR(20) DEFAULT 'ACTIVE' NOT NULL,
    expires_at TIMESTAMPTZ NOT NULL,
    accepted_by UUID REFERENCES users(id) ON DELETE SET NULL,
    accepted_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_pairing_invitations_code ON pairing_invitations(invitation_code);
CREATE INDEX IF NOT EXISTS idx_pairing_invitations_inviter ON pairing_invitations(inviter_id);
CREATE INDEX IF NOT EXISTS idx_pairing_invitations_status ON pairing_invitations(status);

-- MONITORING CONFIGS TABLE
CREATE TABLE IF NOT EXISTS monitoring_configs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    relationship_id UUID NOT NULL UNIQUE REFERENCES monitoring_relationships(id) ON DELETE CASCADE,
    enabled BOOLEAN DEFAULT TRUE NOT NULL,
    timezone VARCHAR(100) DEFAULT 'Asia/Ho_Chi_Minh' NOT NULL,
    inactivity_threshold_minutes INT DEFAULT 480 NOT NULL, -- e.g. 8 hours
    check_in_grace_minutes INT DEFAULT 30 NOT NULL,        -- e.g. 30 mins
    warning_escalation_minutes INT DEFAULT 15 NOT NULL,    -- e.g. 15 mins
    require_check_in BOOLEAN DEFAULT TRUE NOT NULL,
    location_enabled BOOLEAN DEFAULT FALSE NOT NULL,
    activity_types JSONB DEFAULT '["APP_OPEN", "APP_FOREGROUND", "CHECK_IN", "STEP_DETECTED", "SCREEN_INTERACTION"]'::jsonb NOT NULL,
    escalation_policy JSONB DEFAULT '{"stages": [{"delayMinutes": 0, "action": "CHECK_IN_PUSH"}, {"delayMinutes": 15, "action": "REMINDER_PUSH"}, {"delayMinutes": 30, "action": "NOTIFY_MONITOR"}]}'::jsonb NOT NULL,
    current_state VARCHAR(50) DEFAULT 'ACTIVE' NOT NULL,
    last_meaningful_activity_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    next_evaluation_at TIMESTAMPTZ DEFAULT (NOW() + INTERVAL '480 minutes') NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_monitoring_configs_next_eval ON monitoring_configs(next_evaluation_at) WHERE enabled = TRUE;

-- MONITORING SCHEDULE WINDOWS TABLE
CREATE TABLE IF NOT EXISTS monitoring_schedule_windows (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    config_id UUID NOT NULL REFERENCES monitoring_configs(id) ON DELETE CASCADE,
    day_of_week INT NOT NULL, -- 0 = Sunday, 1 = Monday, ... 6 = Saturday
    start_time VARCHAR(5) NOT NULL, -- HH:mm e.g. '07:00'
    end_time VARCHAR(5) NOT NULL,   -- HH:mm e.g. '22:00'
    is_enabled BOOLEAN DEFAULT TRUE NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_schedule_windows_config_day ON monitoring_schedule_windows(config_id, day_of_week);

-- ACTIVITY POLICIES TABLE
CREATE TABLE IF NOT EXISTS activity_policies (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    relationship_id UUID REFERENCES monitoring_relationships(id) ON DELETE CASCADE, -- NULL means system default
    activity_type VARCHAR(50) NOT NULL,
    weight NUMERIC(3,2) NOT NULL DEFAULT 0.5,
    min_confidence NUMERIC(3,2) NOT NULL DEFAULT 0.5,
    cooldown_seconds INT NOT NULL DEFAULT 60,
    is_meaningful BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_activity_policies_rel_type ON activity_policies(relationship_id, activity_type);

-- ACTIVITIES TABLE
CREATE TABLE IF NOT EXISTS activities (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    event_id UUID UNIQUE NOT NULL, -- For idempotency
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    device_id UUID NOT NULL REFERENCES devices(id) ON DELETE CASCADE,
    type VARCHAR(50) NOT NULL,
    weight NUMERIC(3,2) NOT NULL DEFAULT 0.0,
    confidence NUMERIC(3,2) NOT NULL DEFAULT 1.0,
    occurred_at TIMESTAMPTZ NOT NULL,
    received_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    source VARCHAR(50) DEFAULT 'MOBILE' NOT NULL,
    metadata JSONB DEFAULT '{}'::jsonb NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_activities_user_occurred ON activities(user_id, occurred_at DESC);
CREATE INDEX IF NOT EXISTS idx_activities_event_id ON activities(event_id);

-- CHECK-INS TABLE
CREATE TABLE IF NOT EXISTS check_ins (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    event_id UUID UNIQUE NOT NULL,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    device_id UUID NOT NULL REFERENCES devices(id) ON DELETE CASCADE,
    relationship_id UUID REFERENCES monitoring_relationships(id) ON DELETE SET NULL,
    occurred_at TIMESTAMPTZ NOT NULL,
    received_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    battery_level INT,
    note TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_check_ins_user_occurred ON check_ins(user_id, occurred_at DESC);

-- LOCATIONS TABLE
CREATE TABLE IF NOT EXISTS locations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    device_id UUID NOT NULL REFERENCES devices(id) ON DELETE CASCADE,
    latitude NUMERIC(10, 7) NOT NULL,
    longitude NUMERIC(10, 7) NOT NULL,
    accuracy NUMERIC(8, 2),
    captured_at TIMESTAMPTZ NOT NULL,
    source VARCHAR(50) DEFAULT 'CHECK_IN' NOT NULL, -- CHECK_IN, INCIDENT, MANUAL, ACTIVITY
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_locations_user_captured ON locations(user_id, captured_at DESC);

-- INCIDENTS TABLE
CREATE TABLE IF NOT EXISTS incidents (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    relationship_id UUID NOT NULL REFERENCES monitoring_relationships(id) ON DELETE CASCADE,
    status VARCHAR(50) DEFAULT 'OPEN' NOT NULL, -- OPEN, ESCALATED, ACKNOWLEDGED, RESOLVED, CANCELLED
    reason VARCHAR(50) NOT NULL, -- INACTIVITY, MISSED_CHECK_IN, DEVICE_OFFLINE
    risk_score INT DEFAULT 0 NOT NULL,
    detected_at TIMESTAMPTZ NOT NULL,
    last_activity_at TIMESTAMPTZ,
    last_heartbeat_at TIMESTAMPTZ,
    last_location_id UUID REFERENCES locations(id) ON DELETE SET NULL,
    check_in_deadline TIMESTAMPTZ,
    escalated_at TIMESTAMPTZ,
    acknowledged_at TIMESTAMPTZ,
    acknowledged_by UUID REFERENCES users(id) ON DELETE SET NULL,
    resolved_at TIMESTAMPTZ,
    resolved_by UUID REFERENCES users(id) ON DELETE SET NULL,
    next_action_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_incidents_user_status ON incidents(user_id, status);
CREATE INDEX IF NOT EXISTS idx_incidents_status_next_action ON incidents(status, next_action_at);

-- INCIDENT EVENTS TABLE
CREATE TABLE IF NOT EXISTS incident_events (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    incident_id UUID NOT NULL REFERENCES incidents(id) ON DELETE CASCADE,
    type VARCHAR(50) NOT NULL, -- INCIDENT_CREATED, CHECK_IN_REQUESTED, PUSH_SENT, PUSH_FAILED, REMINDER_SENT, WARNING_TRIGGERED, ESCALATION_TRIGGERED, MONITOR_NOTIFIED, MONITOR_ACKNOWLEDGED, INCIDENT_RESOLVED
    timestamp TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    metadata JSONB DEFAULT '{}'::jsonb NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_incident_events_incident ON incident_events(incident_id, timestamp);

-- NOTIFICATION CHANNELS TABLE
CREATE TABLE IF NOT EXISTS notification_channels (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(50) NOT NULL UNIQUE, -- FCM, SMS, TELEGRAM, CALL
    is_active BOOLEAN DEFAULT TRUE NOT NULL,
    config JSONB DEFAULT '{}'::jsonb NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- NOTIFICATION DELIVERIES TABLE
CREATE TABLE IF NOT EXISTS notification_deliveries (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    incident_id UUID REFERENCES incidents(id) ON DELETE SET NULL,
    recipient_user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    channel VARCHAR(50) NOT NULL,
    template_name VARCHAR(100) NOT NULL,
    recipient_target TEXT NOT NULL,
    payload JSONB DEFAULT '{}'::jsonb NOT NULL,
    status VARCHAR(50) DEFAULT 'PENDING' NOT NULL, -- PENDING, SENDING, SENT, DELIVERED, FAILED, CANCELLED
    attempt_count INT DEFAULT 0 NOT NULL,
    max_attempts INT DEFAULT 3 NOT NULL,
    sent_at TIMESTAMPTZ,
    delivered_at TIMESTAMPTZ,
    failed_at TIMESTAMPTZ,
    last_error TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_notification_deliveries_status ON notification_deliveries(status, created_at);

-- AUDIT LOGS TABLE
CREATE TABLE IF NOT EXISTS audit_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    action VARCHAR(100) NOT NULL,
    resource_type VARCHAR(100) NOT NULL,
    resource_id VARCHAR(255),
    ip_address VARCHAR(50),
    user_agent TEXT,
    details JSONB DEFAULT '{}'::jsonb NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_audit_logs_user_action ON audit_logs(user_id, action, created_at DESC);

-- SEED SYSTEM DEFAULT ACTIVITY POLICIES
INSERT INTO activity_policies (relationship_id, activity_type, weight, min_confidence, cooldown_seconds, is_meaningful)
VALUES
    (NULL, 'CHECK_IN', 1.0, 0.9, 0, TRUE),
    (NULL, 'APP_FOREGROUND', 0.8, 0.8, 60, TRUE),
    (NULL, 'APP_OPEN', 0.8, 0.8, 60, TRUE),
    (NULL, 'SCREEN_INTERACTION', 0.7, 0.7, 60, TRUE),
    (NULL, 'STEP_DETECTED', 0.6, 0.5, 300, TRUE),
    (NULL, 'DEVICE_MOTION', 0.4, 0.5, 300, TRUE),
    (NULL, 'CHARGER_CONNECTED', 0.2, 0.8, 300, TRUE),
    (NULL, 'CHARGER_DISCONNECTED', 0.2, 0.8, 300, TRUE),
    (NULL, 'LOCATION_UPDATE', 0.3, 0.7, 300, TRUE),
    (NULL, 'HEARTBEAT', 0.0, 1.0, 60, FALSE)
ON CONFLICT DO NOTHING;
