-- =============================================================================
-- MIGRATION: 08-create-data-shares.sql
-- Peer-to-peer data sharing between shippers (TASK: DATA-SHARING-BETWEEN-SHIPPERS-023)
-- Idempotent, safe migration: No DROP TABLE, preserves all existing data.
-- =============================================================================

-- 1. Create table data_shares if it does not exist
CREATE TABLE IF NOT EXISTS data_shares (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    owner_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    recipient_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    scope VARCHAR(20) NOT NULL CHECK (scope IN ('ALL_POINTS', 'SHIFT')),
    shift_id UUID REFERENCES shifts(id) ON DELETE CASCADE,
    include_photos BOOLEAN NOT NULL DEFAULT false,
    status VARCHAR(20) NOT NULL DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'ACTIVE', 'DECLINED', 'REVOKED')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    accepted_at TIMESTAMPTZ NULL,
    revoked_at TIMESTAMPTZ NULL,
    expires_at TIMESTAMPTZ NULL,
    CONSTRAINT chk_data_shares_owner_recipient CHECK (owner_id <> recipient_id),
    CONSTRAINT chk_data_shares_scope_shift CHECK (
        (scope = 'SHIFT' AND shift_id IS NOT NULL) OR
        (scope = 'ALL_POINTS' AND shift_id IS NULL)
    )
);

-- 2. Partial unique index: No duplicate PENDING or ACTIVE shares for the same pair and scope
CREATE UNIQUE INDEX IF NOT EXISTS uq_active_pending_data_share
ON data_shares (
    owner_id,
    recipient_id,
    scope,
    COALESCE(shift_id, '00000000-0000-0000-0000-000000000000'::uuid)
)
WHERE status IN ('PENDING', 'ACTIVE');

-- 3. Performance indexes for fast querying of incoming/outgoing shares and expiration
CREATE INDEX IF NOT EXISTS idx_data_shares_owner ON data_shares(owner_id, status);
CREATE INDEX IF NOT EXISTS idx_data_shares_recipient ON data_shares(recipient_id, status);
CREATE INDEX IF NOT EXISTS idx_data_shares_expires_at ON data_shares(expires_at);
