-- =============================================================================
-- SEED DEMO DATA SCRIPT FOR DELIVERY MARKER SYSTEM (IDEMPOTENT & SAFE)
-- Dùng để bổ sung dữ liệu demo mẫu vào CSDL PostgreSQL hiện hữu một cách an toàn
-- =============================================================================

-- 1. ĐẢM BẢO ROLES TỒN TẠI (Tái sử dụng các role hiện có)
INSERT INTO roles (id, name, description) VALUES
(1, 'ADMIN', 'Quản lý vận hành hệ thống'),
(2, 'SHIPPER', 'Nhân viên giao hàng')
ON CONFLICT (id) DO UPDATE SET
    name = EXCLUDED.name,
    description = COALESCE(roles.description, EXCLUDED.description);

-- 2. TẠO TÀI KHOẢN NGƯỜI DÙNG DEMO
-- Mật khẩu mặc định: "password123" (Hash bcrypt rounds 10)
-- ON CONFLICT (phone_number) DO NOTHING: Không ghi đè mật khẩu nếu người dùng đã đổi
INSERT INTO users (id, full_name, phone_number, password_hash, role_id, is_active)
SELECT
    'a0000000-0000-0000-0000-000000000001'::uuid,
    'Nguyễn Văn Quản Lý',
    '0900000001',
    '$2b$10$gtZVjpsj7RCMMyj2TbODL.RvTuTF/cO0BCsFhSLiCZkt/jCJdqMC.',
    r.id,
    true
FROM roles r WHERE r.name = 'ADMIN'
ON CONFLICT (phone_number) DO NOTHING;

INSERT INTO users (id, full_name, phone_number, password_hash, role_id, is_active)
SELECT
    'd0000000-0000-0000-0000-000000000001'::uuid,
    'Trần Văn Giao (Shipper A)',
    '0901111111',
    '$2b$10$gtZVjpsj7RCMMyj2TbODL.RvTuTF/cO0BCsFhSLiCZkt/jCJdqMC.',
    r.id,
    true
FROM roles r WHERE r.name = 'SHIPPER'
ON CONFLICT (phone_number) DO NOTHING;

INSERT INTO users (id, full_name, phone_number, password_hash, role_id, is_active)
SELECT
    'd0000000-0000-0000-0000-000000000002'::uuid,
    'Lê Thị Tốc Độ (Shipper B)',
    '0902222222',
    '$2b$10$gtZVjpsj7RCMMyj2TbODL.RvTuTF/cO0BCsFhSLiCZkt/jCJdqMC.',
    r.id,
    true
FROM roles r WHERE r.name = 'SHIPPER'
ON CONFLICT (phone_number) DO NOTHING;

-- 3. KHU VỰC GIAO HÀNG (AREAS)
INSERT INTO areas (id, code, name) VALUES
('b0000000-0000-0000-0000-000000000001'::uuid, 'AREA_Q9_01', 'Khu vực P. Long Thạnh Mỹ, TP. Thủ Đức'),
('b0000000-0000-0000-0000-000000000002'::uuid, 'AREA_Q9_02', 'Khu vực P. Tân Phú, TP. Thủ Đức')
ON CONFLICT (code) DO NOTHING;

-- 4. PHÂN CÔNG KHU VỰC CHO SHIPPER (USER_AREAS)
-- Shipper A (0901111111) -> AREA_Q9_01
INSERT INTO user_areas (user_id, area_id)
SELECT u.id, a.id
FROM users u, areas a
WHERE u.phone_number = '0901111111' AND a.code = 'AREA_Q9_01'
ON CONFLICT (user_id, area_id) DO NOTHING;

-- Shipper B (0902222222) -> AREA_Q9_02
INSERT INTO user_areas (user_id, area_id)
SELECT u.id, a.id
FROM users u, areas a
WHERE u.phone_number = '0902222222' AND a.code = 'AREA_Q9_02'
ON CONFLICT (user_id, area_id) DO NOTHING;

-- 5. KHÁCH HÀNG (CUSTOMERS)
-- Khu vực 1: Long Thạnh Mỹ
INSERT INTO customers (id, customer_code, full_name, phone_number, address_text, area_id)
SELECT
    'c0000000-0000-0000-0000-000000000001'::uuid, 'KH_001', 'Anh Hoàng (Tạp hóa Hai Thu)', '0988000001', 'Hẻm 124 Nguyễn Xiển, P. Long Thạnh Mỹ', a.id
FROM areas a WHERE a.code = 'AREA_Q9_01'
ON CONFLICT (phone_number) DO NOTHING;

INSERT INTO customers (id, customer_code, full_name, phone_number, address_text, area_id)
SELECT
    'c0000000-0000-0000-0000-000000000002'::uuid, 'KH_002', 'Chị Lan (Sữa đá chân cầu)', '0988000002', 'Đường Phước Thiện, gần ngã ba Long Thạnh Mỹ', a.id
FROM areas a WHERE a.code = 'AREA_Q9_01'
ON CONFLICT (phone_number) DO NOTHING;

INSERT INTO customers (id, customer_code, full_name, phone_number, address_text, area_id)
SELECT
    'c0000000-0000-0000-0000-000000000003'::uuid, 'KH_003', 'Chú Tám (Sửa xe)', '0988000003', 'Dọc bờ sông Nguyễn Xiển', a.id
FROM areas a WHERE a.code = 'AREA_Q9_01'
ON CONFLICT (phone_number) DO NOTHING;

-- Khu vực 2: Tân Phú
INSERT INTO customers (id, customer_code, full_name, phone_number, address_text, area_id)
SELECT
    'c0000000-0000-0000-0000-000000000004'::uuid, 'KH_004', 'Bác Hùng (Nhà gỗ)', '0988000004', 'Số 45 Đường Nam Hòa, P. Tân Phú', a.id
FROM areas a WHERE a.code = 'AREA_Q9_02'
ON CONFLICT (phone_number) DO NOTHING;

INSERT INTO customers (id, customer_code, full_name, phone_number, address_text, area_id)
SELECT
    'c0000000-0000-0000-0000-000000000005'::uuid, 'KH_005', 'Cô Nga (Cổng sắt màu xanh)', '0988000005', 'Hẻm 89 Hoàng Hữu Nam', a.id
FROM areas a WHERE a.code = 'AREA_Q9_02'
ON CONFLICT (phone_number) DO NOTHING;

-- 6. VỊ TRÍ ĐÃ LƯU (SAVED_LOCATIONS - PostGIS SRID 4326)
-- Lưu vị trí cho KH_001 (Khu vực 1) và KH_004 (Khu vực 2), các khách hàng khác chưa lưu vị trí để kiểm thử flow đánh dấu vị trí mới
INSERT INTO saved_locations (id, customer_id, geom, latitude, longitude, gps_accuracy, identification_notes, created_by, updated_by, image_url)
SELECT
    'e0000000-0000-0000-0000-000000000001'::uuid,
    c.id,
    ST_SetSRID(ST_MakePoint(106.8181230, 10.8422150), 4326),
    10.8422150,
    106.8181230,
    4.5,
    'Đi vào hẻm 124 khoảng 50m, nhà cạnh tiệm tạp hóa Hai Thu, cổng màu xanh da trời, có cây mai trước sân.',
    u.id,
    u.id,
    '/api/v1/photos/00000000-0000-0000-0000-000000000001.jpg'
FROM customers c, users u
WHERE c.customer_code = 'KH_001' AND u.phone_number = '0901111111'
ON CONFLICT (customer_id) DO NOTHING;

INSERT INTO saved_locations (id, customer_id, geom, latitude, longitude, gps_accuracy, identification_notes, created_by, updated_by)
SELECT
    'e0000000-0000-0000-0000-000000000004'::uuid,
    c.id,
    ST_SetSRID(ST_MakePoint(106.8020500, 10.8510200), 4326),
    10.8510200,
    106.8020500,
    6.0,
    'Rẽ trái ở cột điện hạ thế thứ 2, nhà 3 tầng mái thái gỗ đỏ.',
    u.id,
    u.id
FROM customers c, users u
WHERE c.customer_code = 'KH_004' AND u.phone_number = '0902222222'
ON CONFLICT (customer_id) DO NOTHING;

-- 7. ĐƠN HÀNG (ORDERS)
-- Ca của Shipper A (Khu vực 1 - Long Thạnh Mỹ)
INSERT INTO orders (id, order_code, customer_id, shipper_id, area_id, status)
SELECT
    'f0000000-0000-0000-0000-000000000001'::uuid,
    'ORD-20261004-01',
    c.id,
    u.id,
    a.id,
    'PENDING'
FROM customers c, users u, areas a
WHERE c.customer_code = 'KH_001' AND u.phone_number = '0901111111' AND a.code = 'AREA_Q9_01'
ON CONFLICT (order_code) DO NOTHING;

INSERT INTO orders (id, order_code, customer_id, shipper_id, area_id, status)
SELECT
    'f0000000-0000-0000-0000-000000000002'::uuid,
    'ORD-20261004-02',
    c.id,
    u.id,
    a.id,
    'PENDING'
FROM customers c, users u, areas a
WHERE c.customer_code = 'KH_002' AND u.phone_number = '0901111111' AND a.code = 'AREA_Q9_01'
ON CONFLICT (order_code) DO NOTHING;

INSERT INTO orders (id, order_code, customer_id, shipper_id, area_id, status)
SELECT
    'f0000000-0000-0000-0000-000000000003'::uuid,
    'ORD-20261004-03',
    c.id,
    u.id,
    a.id,
    'PENDING'
FROM customers c, users u, areas a
WHERE c.customer_code = 'KH_003' AND u.phone_number = '0901111111' AND a.code = 'AREA_Q9_01'
ON CONFLICT (order_code) DO NOTHING;

-- Ca của Shipper B (Khu vực 2 - Tân Phú)
INSERT INTO orders (id, order_code, customer_id, shipper_id, area_id, status)
SELECT
    'f0000000-0000-0000-0000-000000000004'::uuid,
    'ORD-20261004-04',
    c.id,
    u.id,
    a.id,
    'PENDING'
FROM customers c, users u, areas a
WHERE c.customer_code = 'KH_004' AND u.phone_number = '0902222222' AND a.code = 'AREA_Q9_02'
ON CONFLICT (order_code) DO NOTHING;

INSERT INTO orders (id, order_code, customer_id, shipper_id, area_id, status)
SELECT
    'f0000000-0000-0000-0000-000000000005'::uuid,
    'ORD-20261004-05',
    c.id,
    u.id,
    a.id,
    'PENDING'
FROM customers c, users u, areas a
WHERE c.customer_code = 'KH_005' AND u.phone_number = '0902222222' AND a.code = 'AREA_Q9_02'
ON CONFLICT (order_code) DO NOTHING;

-- 8. NHẬT KÝ KIỂM TOÁN (AUDIT_LOGS)
INSERT INTO audit_logs (id, user_id, action, entity, entity_id, details)
SELECT
    '00000000-0000-0000-0000-000000000001'::uuid,
    u.id,
    'SEED_DEMO_DATA',
    'SYSTEM',
    NULL,
    '{"message": "Khởi tạo dữ liệu mẫu thành công cho môi trường demo"}'::jsonb
FROM users u
WHERE u.phone_number = '0900000001'
ON CONFLICT (id) DO NOTHING;
