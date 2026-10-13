-- Migration 005: Performance Optimization Indexes & Redundancy Removal

-- 1. Drop redundant duplicate indexes that mirror UNIQUE constraints
DROP INDEX IF EXISTS idx_activities_event_id;
DROP INDEX IF EXISTS idx_monitoring_relationships_pair;
DROP INDEX IF EXISTS idx_pairing_invitations_code;
DROP INDEX IF EXISTS idx_users_email;

-- 2. Composite indexes for high-throughput query optimization
CREATE INDEX IF NOT EXISTS idx_incidents_rel_status_detected 
ON incidents(relationship_id, status, detected_at DESC);

CREATE INDEX IF NOT EXISTS idx_devices_user_active_seen 
ON devices(user_id, is_active, last_seen_at DESC);

CREATE INDEX IF NOT EXISTS idx_devices_user_heartbeat 
ON devices(user_id, last_heartbeat_at DESC);

CREATE INDEX IF NOT EXISTS idx_notification_deliveries_failed_retry 
ON notification_deliveries(status, failed_at ASC) 
WHERE status = 'FAILED';

-- 3. Foreign key indexes to eliminate full table scans on cascading deletes and joins
CREATE INDEX IF NOT EXISTS idx_activities_device_id 
ON activities(device_id);

CREATE INDEX IF NOT EXISTS idx_check_ins_device_id 
ON check_ins(device_id);

CREATE INDEX IF NOT EXISTS idx_check_ins_relationship_id 
ON check_ins(relationship_id);

CREATE INDEX IF NOT EXISTS idx_locations_device_id 
ON locations(device_id);

CREATE INDEX IF NOT EXISTS idx_incidents_relationship_id 
ON incidents(relationship_id);

CREATE INDEX IF NOT EXISTS idx_notification_deliveries_recipient 
ON notification_deliveries(recipient_user_id);

CREATE INDEX IF NOT EXISTS idx_notification_deliveries_incident 
ON notification_deliveries(incident_id);

-- 4. Clean up any duplicate phone numbers in development/legacy data before index creation
UPDATE users u
SET phone_number = NULL
WHERE u.id IN (
  SELECT id FROM (
    SELECT id, ROW_NUMBER() OVER (PARTITION BY phone_number ORDER BY created_at ASC) as rn
    FROM users
    WHERE phone_number IS NOT NULL AND phone_number != ''
  ) dupes
  WHERE dupes.rn > 1
);

-- 5. Apply phone number unique partial index from migration 004 if not present
CREATE UNIQUE INDEX IF NOT EXISTS idx_users_phone_number_unique 
ON users(phone_number) 
WHERE phone_number IS NOT NULL AND phone_number != '';
