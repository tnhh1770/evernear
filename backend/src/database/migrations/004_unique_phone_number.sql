-- Migration 004: Ensure phone number uniqueness

-- Partial unique index on users.phone_number:
-- Allows multiple NULLs or empty strings for users who register without a phone number,
-- while guaranteeing that any provided phone number is strictly unique.
CREATE UNIQUE INDEX IF NOT EXISTS idx_users_phone_number_unique
ON users(phone_number)
WHERE phone_number IS NOT NULL AND phone_number != '';
