-- Migration 002: Add preferred_language column to users table
ALTER TABLE users ADD COLUMN IF NOT EXISTS preferred_language VARCHAR(10) DEFAULT 'vi' NOT NULL;
COMMENT ON COLUMN users.preferred_language IS 'ISO 639-1 language code for user localization and notifications (default: vi)';
