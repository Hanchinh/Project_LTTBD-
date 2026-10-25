-- =============================================================================
-- MIGRATION: ADD SHIFT_NAME COLUMN TO SHIFTS TABLE (TASK: SHIFT-FROM-MAP-AND-BULK-PASTE-015B)
-- PostgreSQL 16 + PostGIS 3.4
-- Idempotent and safe migration with IF NOT EXISTS
-- =============================================================================

ALTER TABLE shifts ADD COLUMN IF NOT EXISTS shift_name VARCHAR(100) NULL;

-- Index for searching shifts by name if needed
CREATE INDEX IF NOT EXISTS idx_shifts_shift_name ON shifts(shift_name);
