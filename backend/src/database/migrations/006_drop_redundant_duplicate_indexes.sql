-- Migration 006: Drop Redundant Duplicate Prefix Indexes
-- Dropping redundant duplicate prefix indexes identified in F-07:
-- 1. idx_devices_user_active on devices(user_id, is_active) is a strict prefix of idx_devices_user_active_seen on (user_id, is_active, last_seen_at DESC).
-- 2. idx_incidents_relationship_id on incidents(relationship_id) is a strict prefix of idx_incidents_rel_status_detected on (relationship_id, status, detected_at DESC).

DROP INDEX IF EXISTS idx_devices_user_active;
DROP INDEX IF EXISTS idx_incidents_relationship_id;
