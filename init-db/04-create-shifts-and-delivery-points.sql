-- =============================================================================
-- MIGRATION: CREATE SHIFTS AND SHIFT_DELIVERY_POINTS TABLES (FEATURE-SHIFT-001)
-- PostgreSQL 16 + PostGIS 3.4
-- Idempotent and safe migration with IF NOT EXISTS
-- =============================================================================

-- 1. SHIFTS (Ca làm việc của Shipper)
CREATE TABLE IF NOT EXISTS shifts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    shift_code VARCHAR(50) UNIQUE NOT NULL,
    work_date DATE NOT NULL DEFAULT CURRENT_DATE,
    shipper_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    status VARCHAR(20) NOT NULL DEFAULT 'PREPARING' CHECK (status IN ('PREPARING', 'IN_PROGRESS', 'COMPLETED')),
    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_shifts_shipper_date ON shifts(shipper_id, work_date);
CREATE INDEX IF NOT EXISTS idx_shifts_status ON shifts(status);

-- 2. SHIFT_DELIVERY_POINTS (Các điểm giao trong ca)
CREATE TABLE IF NOT EXISTS shift_delivery_points (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    shift_id UUID NOT NULL REFERENCES shifts(id) ON DELETE CASCADE,
    customer_id UUID NOT NULL REFERENCES customers(id) ON DELETE RESTRICT,
    order_id UUID REFERENCES orders(id) ON DELETE SET NULL,
    delivery_order_index INT NOT NULL DEFAULT 1,
    location_status VARCHAR(20) NOT NULL DEFAULT 'NO_LOCATION' CHECK (location_status IN ('NO_LOCATION', 'TEMPORARY', 'VERIFIED')),
    geom GEOMETRY(Point, 4326),
    latitude NUMERIC(10, 7),
    longitude NUMERIC(10, 7),
    gps_accuracy FLOAT DEFAULT 0.0,
    identification_notes TEXT,
    image_url TEXT,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_shift_customer UNIQUE(shift_id, customer_id)
);

CREATE INDEX IF NOT EXISTS idx_shift_points_shift ON shift_delivery_points(shift_id);
CREATE INDEX IF NOT EXISTS idx_shift_points_customer ON shift_delivery_points(customer_id);
CREATE INDEX IF NOT EXISTS idx_shift_points_status ON shift_delivery_points(location_status);

-- Spatial index for spatial queries
CREATE INDEX IF NOT EXISTS idx_shift_points_geom ON shift_delivery_points USING GIST(geom);
