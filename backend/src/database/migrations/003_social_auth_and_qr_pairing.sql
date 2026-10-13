-- Migration 003: Social Authentication and QR Code Pairing Invitations

-- 1. Add social authentication columns to users table
ALTER TABLE users ADD COLUMN IF NOT EXISTS google_id VARCHAR(255);
ALTER TABLE users ADD COLUMN IF NOT EXISTS apple_id VARCHAR(255);
ALTER TABLE users ADD COLUMN IF NOT EXISTS auth_provider VARCHAR(50) DEFAULT 'LOCAL' NOT NULL;

-- 2. Indices for fast lookup by social provider identifiers
CREATE INDEX IF NOT EXISTS idx_users_google_id ON users(google_id);
CREATE INDEX IF NOT EXISTS idx_users_apple_id ON users(apple_id);

-- 3. Pairing invitations table for family QR code pairing
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
