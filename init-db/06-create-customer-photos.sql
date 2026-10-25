-- =============================================================================
-- MIGRATION: 06-create-customer-photos.sql
-- Multi-Photo support per customer with soft delete (TASK: MULTI-PHOTO-AND-THUMB-UI-015A)
-- Idempotent, safe migration: No DROP TABLE, preserves all existing data.
-- =============================================================================

-- 1. Create table customer_photos if it does not exist
CREATE TABLE IF NOT EXISTS customer_photos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id UUID NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
    image_url TEXT NOT NULL,
    created_by UUID REFERENCES users(id) ON DELETE SET NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP WITH TIME ZONE NULL
);

-- 2. Create indexes for fast lookup and filtering active photos
CREATE INDEX IF NOT EXISTS idx_customer_photos_customer_id ON customer_photos(customer_id);
CREATE INDEX IF NOT EXISTS idx_customer_photos_deleted_at ON customer_photos(deleted_at);
CREATE INDEX IF NOT EXISTS idx_customer_photos_created_at ON customer_photos(created_at DESC);

-- 3. Data migration: Copy existing photos from saved_locations into customer_photos
-- Idempotent: Skips if the combination of (customer_id, image_url) already exists
INSERT INTO customer_photos (customer_id, image_url, created_by, created_at)
SELECT
    sl.customer_id,
    sl.image_url,
    sl.created_by,
    COALESCE(sl.updated_at, sl.created_at, CURRENT_TIMESTAMP)
FROM saved_locations sl
WHERE sl.image_url IS NOT NULL
  AND TRIM(sl.image_url) <> ''
  AND NOT EXISTS (
      SELECT 1 FROM customer_photos cp
      WHERE cp.customer_id = sl.customer_id
        AND cp.image_url = sl.image_url
  );

-- 4. Data migration: Copy existing photos from shift_delivery_points into customer_photos
-- Idempotent: Skips if the combination of (customer_id, image_url) already exists
INSERT INTO customer_photos (customer_id, image_url, created_by, created_at)
SELECT DISTINCT
    sdp.customer_id,
    sdp.image_url,
    s.shipper_id,
    COALESCE(sdp.updated_at, sdp.created_at, CURRENT_TIMESTAMP)
FROM shift_delivery_points sdp
JOIN shifts s ON s.id = sdp.shift_id
WHERE sdp.image_url IS NOT NULL
  AND TRIM(sdp.image_url) <> ''
  AND NOT EXISTS (
      SELECT 1 FROM customer_photos cp
      WHERE cp.customer_id = sdp.customer_id
        AND cp.image_url = sdp.image_url
  );
