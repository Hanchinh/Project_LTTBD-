# HỆ THỐNG GHI NHỚ VỊ TRÍ GIAO HÀNG THỰC TẾ (DELIVERY LOCATION MARKER MVP)

Hệ thống MVP hỗ trợ Nhân viên Giao hàng (Shipper) ghi nhớ vị trí thực tế sau mỗi lần giao hàng thành công bằng tọa độ PostGIS, ghi chú nhận diện (hẻm, nhà, đặc điểm cổng...) và hỗ trợ Quản lý vận hành (Admin) quản lý khu vực, theo dõi tỷ lệ phủ vị trí.

---

## 🏗️ KIẾN TRÚC HỆ THỐNG

- **Database**: PostgreSQL 16 + PostGIS 3.4 (Chỉ mục không gian GIST, Trigger lưu vết lịch sử vị trí).
- **Backend API**: Node.js (Express/NestJS pattern + TypeScript + JWT + RBAC + Swagger UI).
- **Mobile App**: Flutter (Bản đồ OpenStreetMap / Esri Satellite, SQLite Offline Cache & Sync Queue, Deep-link Google Maps/Apple Maps, 3-step pin adjustment).
- **Admin Web**: React + Vite + TypeScript + Tailwind CSS + React-Leaflet Map.
- **Đóng gói**: Docker & Docker Compose.

---

## 🚀 HƯỚNG DẪN CÀI ĐẶT VÀ CHẠY DỰ ÁN (QUICK START)

### CÁCH 1: KHỞI CHẠY BẰNG DOCKER COMPOSE (KHUYÊN DÙNG)

Chỉ với **1 lệnh duy nhất**, toàn bộ CSDL PostGIS, Backend API và Admin Web sẽ được đóng gói và khởi chạy:

```powershell
docker-compose up -d --build
```

Sau khi khởi chạy thành công:
1. **Admin Web Portal**: [http://localhost:5173](http://localhost:5173)
2. **Backend REST API**: [http://localhost:3000/api/v1](http://localhost:3000/api/v1)
3. **Swagger API Documentation**: [http://localhost:3000/api/docs](http://localhost:3000/api/docs)
4. **PostgreSQL PostGIS DB**: `localhost:5432` (User: `postgres`, Password: `postgres`, DB: `delivery_db`)

---

### CÁCH 2: CHẠY THỦ CÔNG TỪNG THÀNH PHẦN (DEVELOPMENT MODE)

#### 1. Khởi chạy CSDL PostGIS Database:
```powershell
docker-compose up -d postgres
```

#### 2. Khởi chạy Backend API:
```powershell
cd backend
npm install
npm run dev
```

#### 3. Khởi chạy Website Admin:
```powershell
cd admin_web
npm install
npm run dev
```

#### 4. Khởi chạy Mobile App (Flutter):
```powershell
cd mobile_app
flutter pub get
flutter run
```

---

## 🔑 TÀI KHOẢN MẪU DÙNG THỬ (SEED ACCOUNTS)

Tất cả tài khoản mẫu có Mật khẩu mặc định là: `password123`

| Vai trò | Số điện thoại | Mật khẩu | Khu vực phụ trách |
| :--- | :--- | :--- | :--- |
| **Quản trị viên (Admin)** | `0900000001` | `password123` | Toàn hệ thống |
| **Shipper A** | `0901111111` | `password123` | Area Q.9 - Long Thạnh Mỹ |
| **Shipper B** | `0902222222` | `password123` | Area Q.9 - Tân Phú |

---

## 🧪 CHẠY UNIT TESTS

Chạy bộ kiểm thử lõi (Đo khoảng cách GPS Haversine < 20m & Kiểm tra phân quyền RBAC khu vực):

```powershell
cd backend
npm test
```

---

## 📱 QUY TRÌNH THAO TÁC SỬ DỤNG

### 1. Dành cho Nhân viên giao hàng (Mobile App):
1. **Đăng nhập**: Dùng tài khoản Shipper A (`0901111111` / `password123`).
2. **Xem đơn trong ca**: Danh sách đơn thuộc khu vực phụ trách hiển thị rõ đơn nào đã/chưa có vị trí lưu.
3. **Xem vị trí & Dẫn đường**: Mở chi tiết đơn đã lưu vị trí -> xem ghim bản đồ + ghi chú -> bấm **"Dẫn đường"** để mở Google Maps.
4. **Lưu vị trí 3 bước**: 
   - Đo vị trí GPS + hiển thị độ chính xác (±m).
   - Kéo ghim chỉnh thủ công trên bản đồ.
   - Nhập ghi chú (VD: "nhà cổng xanh da trời, hẻm 124") -> Bấm **"Lưu vị trí"**.
5. **Hỗ trợ Offline**: Khi mạng yếu/mất mạng, ứng dụng tự động lưu vào SQLite local và đẩy lên CSDL khi có kết nối lại.

### 2. Dành cho Quản lý vận hành (Admin Web):
1. **Đăng nhập**: Mở `http://localhost:5173`, đăng nhập `0900000001` / `password123`.
2. **Dashboard**: Xem tổng số vị trí đã lưu, tiến độ phủ % theo từng khu vực.
3. **Bản đồ Vị trí Khách**: Tìm kiếm theo tên/SĐT khách, bật tắt lớp **Ảnh vệ tinh**, xem ghi chú & tọa độ.
4. **Nhân viên & Khu vực**: Phân công / bàn giao khu vực cho từng shipper.
5. **Nhật ký Hệ thống**: Kiểm tra log thao tác (Audit logs).
