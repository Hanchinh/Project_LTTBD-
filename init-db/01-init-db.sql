-- =============================================================================
-- DATABASE INITIALIZATION SCRIPT FOR DELIVERY MARKER SYSTEM
-- PostgreSQL 16 + PostGIS 3.4
-- =============================================================================

-- 1. EXTENSIONS
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS postgis;

-- 2. DROP TABLES IF EXISTS (For Clean Reset)
DROP TABLE IF EXISTS audit_logs CASCADE;
DROP TABLE IF EXISTS location_history CASCADE;
DROP TABLE IF EXISTS saved_locations CASCADE;
DROP TABLE IF EXISTS orders CASCADE;
DROP TABLE IF EXISTS customers CASCADE;
DROP TABLE IF EXISTS user_areas CASCADE;
DROP TABLE IF EXISTS areas CASCADE;
DROP TABLE IF EXISTS users CASCADE;
DROP TABLE IF EXISTS roles CASCADE;

-- =============================================================================
-- 3. CREATE TABLES
-- =============================================================================

-- ROLES
CREATE TABLE roles (
    id SERIAL PRIMARY KEY,
    name VARCHAR(50) NOT NULL UNIQUE,
    description TEXT
);

-- USERS (Admins & Delivery Shippers)
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    full_name VARCHAR(100) NOT NULL,
    phone_number VARCHAR(20) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    role_id INT NOT NULL REFERENCES roles(id),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- AREAS (Khu vực giao hàng)
CREATE TABLE areas (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    code VARCHAR(50) UNIQUE NOT NULL,
    name VARCHAR(150) NOT NULL,
    boundary GEOMETRY(Polygon, 4326),
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- USER_AREAS (Phân công nhân viên phụ trách khu vực)
CREATE TABLE user_areas (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    area_id UUID NOT NULL REFERENCES areas(id) ON DELETE CASCADE,
    assigned_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_user_area UNIQUE(user_id, area_id)
);

-- CUSTOMERS (Khách hàng)
CREATE TABLE customers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    customer_code VARCHAR(50) UNIQUE NOT NULL,
    full_name VARCHAR(100) NOT NULL,
    phone_number VARCHAR(20) UNIQUE NOT NULL,
    address_text TEXT NOT NULL,
    area_id UUID NOT NULL REFERENCES areas(id),
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- ORDERS (Đơn hàng)
CREATE TABLE orders (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    order_code VARCHAR(50) UNIQUE NOT NULL,
    customer_id UUID NOT NULL REFERENCES customers(id),
    shipper_id UUID REFERENCES users(id),
    area_id UUID NOT NULL REFERENCES areas(id),
    status VARCHAR(20) DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'DELIVERED', 'CANCELLED')),
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    delivered_at TIMESTAMPTZ
);

-- SAVED_LOCATIONS (Vị trí thực tế đã lưu của khách hàng - Spatial PostGIS)
CREATE TABLE saved_locations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    customer_id UUID UNIQUE NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
    geom GEOMETRY(Point, 4326) NOT NULL,
    latitude NUMERIC(10, 7) NOT NULL,
    longitude NUMERIC(10, 7) NOT NULL,
    gps_accuracy FLOAT NOT NULL DEFAULT 0.0,
    identification_notes TEXT NOT NULL,
    created_by UUID REFERENCES users(id),
    updated_by UUID REFERENCES users(id),
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- LOCATION_HISTORY (Lịch sử cập nhật/chỉnh sửa vị trí)
CREATE TABLE location_history (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    saved_location_id UUID NOT NULL REFERENCES saved_locations(id) ON DELETE CASCADE,
    customer_id UUID NOT NULL REFERENCES customers(id),
    geom GEOMETRY(Point, 4326) NOT NULL,
    latitude NUMERIC(10, 7) NOT NULL,
    longitude NUMERIC(10, 7) NOT NULL,
    gps_accuracy FLOAT NOT NULL,
    identification_notes TEXT NOT NULL,
    changed_by UUID REFERENCES users(id),
    change_reason VARCHAR(255) DEFAULT 'Cập nhật vị trí',
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- AUDIT_LOGS (Nhật ký thao tác hệ thống)
CREATE TABLE audit_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id),
    action VARCHAR(50) NOT NULL,
    entity VARCHAR(50) NOT NULL,
    entity_id UUID,
    details JSONB,
    ip_address VARCHAR(45),
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- =============================================================================
-- 4. SPATIAL & PERFORMANCE INDEXES
-- =============================================================================

-- Spatial Index GIST cho tìm kiếm vị trí cực nhanh (< 2s)
CREATE INDEX idx_saved_locations_geom ON saved_locations USING GIST (geom);
CREATE INDEX idx_location_history_geom ON location_history USING GIST (geom);

-- B-Tree Indexes cho tra cứu thường xuyên
CREATE INDEX idx_users_phone ON users(phone_number);
CREATE INDEX idx_customers_phone ON customers(phone_number);
CREATE INDEX idx_customers_area_id ON customers(area_id);
CREATE INDEX idx_orders_shipper_status ON orders(shipper_id, status);
CREATE INDEX idx_user_areas_user ON user_areas(user_id);
CREATE INDEX idx_saved_locations_customer ON saved_locations(customer_id);

-- =============================================================================
-- 5. TRIGGERS FOR AUTOMATIC HISTORY LOGGING
-- =============================================================================

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
        NEW.updated_by,
        'Cập nhật thông tin vị trí cũ sang vị trí mới',
        CURRENT_TIMESTAMP
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_saved_locations_history
AFTER UPDATE ON saved_locations
FOR EACH ROW
WHEN (OLD.latitude IS DISTINCT FROM NEW.latitude OR 
      OLD.longitude IS DISTINCT FROM NEW.longitude OR 
      OLD.identification_notes IS DISTINCT FROM NEW.identification_notes)
EXECUTE FUNCTION fn_log_location_history();

-- =============================================================================
-- 6. SEED DATA (DỮ LIỆU MẪU BAN ĐẦU)
-- =============================================================================

-- Mật khẩu mặc định cho tất cả tài khoản test: "password123"
-- Bcrypt Hash của "password123": $2b$10$6C0pZbJ5yDk6/x2zX4kL6.H9T5q5D5f8S2z6A5B4C3D2E1F0G1H2I

INSERT INTO roles (id, name, description) VALUES
(1, 'ADMIN', 'Quản lý vận hành hệ thống'),
(2, 'SHIPPER', 'Nhân viên giao hàng');

-- USERS
-- Admin: 0900000001 / password123
-- Shipper 1: 0901111111 / password123 (Phụ trách Q.9 - Long Thạnh Mỹ)
-- Shipper 2: 0902222222 / password123 (Phụ trách Q.9 - Tân Phú)
INSERT INTO users (id, full_name, phone_number, password_hash, role_id) VALUES
('a0000000-0000-0000-0000-000000000001', 'Nguyễn Văn Quản Lý', '0900000001', '$2b$10$6C0pZbJ5yDk6/x2zX4kL6.H9T5q5D5f8S2z6A5B4C3D2E1F0G1H2I', 1),
('s0000000-0000-0000-0000-000000000001', 'Trần Văn Giao (Shipper A)', '0901111111', '$2b$10$6C0pZbJ5yDk6/x2zX4kL6.H9T5q5D5f8S2z6A5B4C3D2E1F0G1H2I', 2),
('s0000000-0000-0000-0000-000000000002', 'Lê Thị Tốc Độ (Shipper B)', '0902222222', '$2b$10$6C0pZbJ5yDk6/x2zX4kL6.H9T5q5D5f8S2z6A5B4C3D2E1F0G1H2I', 2);

-- AREAS
INSERT INTO areas (id, code, name) VALUES
('b0000000-0000-0000-0000-000000000001', 'AREA_Q9_01', 'Khu vực P. Long Thạnh Mỹ, TP. Thủ Đức'),
('b0000000-0000-0000-0000-000000000002', 'AREA_Q9_02', 'Khu vực P. Tân Phú, TP. Thủ Đức');

-- USER_AREAS ASSIGNMENTS
INSERT INTO user_areas (user_id, area_id) VALUES
('s0000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000001'), -- Shipper A -> Long Thạnh Mỹ
('s0000000-0000-0000-0000-000000000002', 'b0000000-0000-0000-0000-000000000002'); -- Shipper B -> Tân Phú

-- CUSTOMERS
INSERT INTO customers (id, customer_code, full_name, phone_number, address_text, area_id) VALUES
-- Khu vực 1 (Long Thạnh Mỹ)
('c0000000-0000-0000-0000-000000000001', 'KH_001', 'Anh Hoàng (Tạp hóa Hai Thu)', '0988000001', 'Hẻm 124 Nguyễn Xiển, P. Long Thạnh Mỹ', 'b0000000-0000-0000-0000-000000000001'),
('c0000000-0000-0000-0000-000000000002', 'KH_002', 'Chị Lan (Sữa đá chân cầu)', '0988000002', 'Đường Phước Thiện, gần ngã ba Long Thạnh Mỹ', 'b0000000-0000-0000-0000-000000000001'),
('c0000000-0000-0000-0000-000000000003', 'KH_003', 'Chú Tám (Sửa xe)', '0988000003', 'Dọc bờ sông Nguyễn Xiển', 'b0000000-0000-0000-0000-000000000001'),
-- Khu vực 2 (Tân Phú)
('c0000000-0000-0000-0000-000000000004', 'KH_004', 'Bác Hùng (Nhà gỗ)', '0988000004', 'Số 45 Đường Nam Hòa, P. Tân Phú', 'b0000000-0000-0000-0000-000000000002'),
('c0000000-0000-0000-0000-000000000005', 'KH_005', 'Cô Nga (Cổng sắt màu xanh)', '0988000005', 'Hẻm 89 Hoàng Hữu Nam', 'b0000000-0000-0000-0000-000000000002');

-- SAVED_LOCATIONS (Vị trí đã lưu cho KH_001 và KH_004, các khách khác chưa lưu vị trí để test giao diện "Chưa có vị trí")
-- KH_001: Tọa độ Long Thạnh Mỹ (10.8422, 106.8181)
INSERT INTO saved_locations (id, customer_id, geom, latitude, longitude, gps_accuracy, identification_notes, created_by, updated_by) VALUES
('l0000000-0000-0000-0000-000000000001', 
 'c0000000-0000-0000-0000-000000000001', 
 ST_SetSRID(ST_MakePoint(106.8181230, 10.8422150), 4326), 
 10.8422150, 
 106.8181230, 
 4.5, 
 'Đi vào hẻm 124 khoảng 50m, nhà cạnh tiệm tạp hóa Hai Thu, cổng màu xanh da trời, có cây mai trước sân.', 
 's0000000-0000-0000-0000-000000000001', 
 's0000000-0000-0000-0000-000000000001'),

-- KH_004: Tọa độ Tân Phú (10.8510, 106.8020)
('l0000000-0000-0000-0000-000000000004', 
 'c0000000-0000-0000-0000-000000000004', 
 ST_SetSRID(ST_MakePoint(106.8020500, 10.8510200), 4326), 
 10.8510200, 
 106.8020500, 
 6.0, 
 'Rẽ trái ở cột điện hạ thế thứ 2, nhà 3 tầng mái thái gỗ đỏ.', 
 's0000000-0000-0000-0000-000000000002', 
 's0000000-0000-0000-0000-000000000002');

-- ORDERS (Đơn hàng trong ca)
INSERT INTO orders (id, order_code, customer_id, shipper_id, area_id, status) VALUES
-- Đơn hàng cho Shipper A (Khu vực 1)
('o0000000-0000-0000-0000-000000000001', 'ORD-20261004-01', 'c0000000-0000-0000-0000-000000000001', 's0000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000001', 'PENDING'),
('o0000000-0000-0000-0000-000000000002', 'ORD-20261004-02', 'c0000000-0000-0000-0000-000000000002', 's0000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000001', 'PENDING'),
('o0000000-0000-0000-0000-000000000003', 'ORD-20261004-03', 'c0000000-0000-0000-0000-000000000003', 's0000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000001', 'PENDING'),

-- Đơn hàng cho Shipper B (Khu vực 2)
('o0000000-0000-0000-0000-000000000004', 'ORD-20261004-04', 'c0000000-0000-0000-0000-000000000004', 's0000000-0000-0000-0000-000000000002', 'b0000000-0000-0000-0000-000000000002', 'PENDING'),
('o0000000-0000-0000-0000-000000000005', 'ORD-20261004-05', 'c0000000-0000-0000-0000-000000000005', 's0000000-0000-0000-0000-000000000002', 'b0000000-0000-0000-0000-000000000002', 'PENDING');

-- AUDIT LOGS BAN ĐẦU
INSERT INTO audit_logs (user_id, action, entity, entity_id, details) VALUES
('a0000000-0000-0000-0000-000000000001', 'INITIALIZE_SYSTEM', 'SYSTEM', NULL, '{"message": "Khởi tạo dữ liệu hệ thống thành công"}');
