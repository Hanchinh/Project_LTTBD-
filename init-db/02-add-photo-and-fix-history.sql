-- =============================================================================
-- MIGRATION: ADD IMAGE_URL AND FIX AUDIT HISTORY RETENTION
-- =============================================================================

-- 1. Add image_url to saved_locations if not exists
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'saved_locations' AND column_name = 'image_url'
    ) THEN
        ALTER TABLE saved_locations ADD COLUMN image_url TEXT;
    END IF;
END $$;

-- 2. Add image_url to location_history if not exists
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'location_history' AND column_name = 'image_url'
    ) THEN
        ALTER TABLE location_history ADD COLUMN image_url TEXT;
    END IF;
END $$;

-- 3. Modify foreign key constraint on location_history to ON DELETE SET NULL
DO $$
BEGIN
    -- Drop existing foreign key constraint if it exists
    ALTER TABLE location_history
        DROP CONSTRAINT IF EXISTS location_history_saved_location_id_fkey;

    -- Re-add with ON DELETE SET NULL to preserve audit history when a location is deleted
    ALTER TABLE location_history
        ADD CONSTRAINT location_history_saved_location_id_fkey
        FOREIGN KEY (saved_location_id) REFERENCES saved_locations(id) ON DELETE SET NULL;
END $$;

-- 4. Update trigger function fn_log_location_history
CREATE OR REPLACE FUNCTION fn_log_location_history()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO location_history (
        saved_location_id,
        customer_id,
        geom,
        latitude,
        longitude,
        gps_accuracy,
        identification_notes,
        image_url,
        changed_by,
        change_reason,
        created_at
    ) VALUES (
        OLD.id,
        OLD.customer_id,
        OLD.geom,
        OLD.latitude,
        OLD.longitude,
        OLD.gps_accuracy,
        OLD.identification_notes,
        OLD.image_url,
        NEW.updated_by,
        'Cập nhật thông tin vị trí cũ sang vị trí mới',
        CURRENT_TIMESTAMP
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 5. Recreate trigger with updated condition
DROP TRIGGER IF EXISTS trg_saved_locations_history ON saved_locations;

CREATE TRIGGER trg_saved_locations_history
AFTER UPDATE ON saved_locations
FOR EACH ROW
WHEN (OLD.latitude IS DISTINCT FROM NEW.latitude OR
      OLD.longitude IS DISTINCT FROM NEW.longitude OR
      OLD.identification_notes IS DISTINCT FROM NEW.identification_notes OR
      OLD.image_url IS DISTINCT FROM NEW.image_url)
EXECUTE FUNCTION fn_log_location_history();
