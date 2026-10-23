-- =============================================================================
-- MIGRATION: ADD UPDATED_AT TO CUSTOMERS TABLE (MAP-FIRST-ARCHITECTURE-005)
-- Safe & idempotent migration
-- =============================================================================

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'customers' AND column_name = 'updated_at'
    ) THEN
        ALTER TABLE customers ADD COLUMN updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP;
    END IF;
END $$;
