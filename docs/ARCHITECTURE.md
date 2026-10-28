# System Architecture: Delivery Location Marker System

> **Tài liệu của bản có máy chủ. Bản này (submit-app-only) không còn backend. Xem tag v1.0-full.**  
> **Lưu ý:** Xem [docs/BRAIN.md](docs/BRAIN.md) để nắm cấu trúc kiến trúc Local-First của bản nộp hiện tại.

---

## 1. Tổng Quan Kiến Trúc (Architecture Overview)

Hệ thống được thiết kế theo mô hình **Client-Server 3 tầng phân tán (Three-Tier Client-Server Architecture)** kết hợp lưu trữ không gian địa lý:

```
+-------------------------------------------------------------------------+
|                              CLIENT TIER                                |
|                                                                         |
|   +---------------------------------+  +----------------------------+   |
|   |       Flutter Mobile App        |  |     React Vite Admin Web   |   |
|   |  - Flutter Map (OSM/Google)     |  |  - React Leaflet Map       |   |
|   |  - Geolocator (GPS ±m)          |  |  - Esri Satellite Hybrid   |   |
|   |  - SQLite (Offline Queue/Cache) |  |  - Tailwind CSS Dashboard  |   |
|   +---------------------------------+  +----------------------------+   |
+-------------------------------------------------------------------------+
                                    |
                   RESTful API (JSON / Bearer JWT)
                                    v
+-------------------------------------------------------------------------+
|                            APPLICATION TIER                             |
|                                                                         |
|   +-----------------------------------------------------------------+   |
|   |                      Backend API (Express + TS)                 |   |
|   |  - Auth Middleware: JWT Verification & Role-Based Access Control|   |
|   |  - Scope Middleware: Check Customer Area Assignment             |   |
|   |  - Controllers: Auth, Orders, Locations, Admin Management       |   |
|   |  - OpenAPI / Swagger UI: /api/docs                              |   |
|   +-----------------------------------------------------------------+   |
+-------------------------------------------------------------------------+
                                    |
                        PostgreSQL Connection Pool (pg)
                                    v
+-------------------------------------------------------------------------+
|                               DATA TIER                                 |
|                                                                         |
|   +-----------------------------------------------------------------+   |
|   |                  PostgreSQL 16 + PostGIS 3.4                    |   |
|   |  - Geometric Spatial Engine: ST_MakePoint, ST_SetSRID (SRID 4326)|  |
|   |  - Spatial Indexing: GIST on Point geometries                   |   |
|   |  - PL/pgSQL Trigger: trg_saved_locations_history (Audit Trail)  |   |
|   |  - Audit Log Tracking: audit_logs (JSONB payload)               |   |
|   +-----------------------------------------------------------------+   |
+-------------------------------------------------------------------------+
```

---

## 2. Cấu Trúc Thư Mục & Module (Codebase Directory Layout)

```text
/ (Project Root)
├── README.md                 # Tài liệu hướng dẫn sử dụng nhanh
├── docker-compose.yml        # Điều phối các container: postgres, backend, admin_web
├── init-db/
│   ├── 01-init-db.sql        # Script tạo extension, bảng, trigger, index và nạp seed data
│   └── 02-add-photo-and-fix-history.sql # Migration bổ sung ảnh mặt tiền và sửa cascade delete
├── backend/                  # RESTful API Service (Express + TypeScript)
│   ├── Dockerfile            # Container build cho Node.js backend
│   ├── package.json          # Cấu hình dependency & npm scripts
│   ├── tsconfig.json         # Cấu hình biên dịch TypeScript
│   ├── jest.config.js        # Cấu hình Jest test runner
│   ├── .env                  # Biến môi trường cục bộ
│   ├── uploads/photos/       # Thư mục lưu trữ ảnh mặt tiền/cổng nhà bền vững
│   ├── src/
│   │   ├── index.ts          # Server entry point (app.listen)
│   │   ├── app.ts            # Khởi tạo Express, gán middleware và router (13 endpoints)
│   │   ├── db.ts             # Khởi tạo PostgreSQL connection pool (pg.Pool)
│   │   ├── swagger.ts        # Cấu hình Swagger UI OpenAPI document
│   │   ├── middlewares/
│   │   │   ├── auth.middleware.ts   # Xác thực Bearer JWT & phân quyền Role
│   │   │   └── area.middleware.ts   # Kiểm tra quyền truy cập theo khu vực (Area Scope)
│   │   └── controllers/
│   │       ├── auth.controller.ts      # Đăng nhập & sinh JWT token (Bcrypt chuẩn)
│   │       ├── orders.controller.ts    # Lấy danh sách đơn trong ca của shipper (kèm ảnh)
│   │       ├── locations.controller.ts # Lưu/cập nhật vị trí, lưu ảnh base64, tra cứu SĐT, phục vụ ảnh
│   │       └── admin.controller.ts     # Thống kê coverage, quản lý user, area, xóa vị trí an toàn
│   └── test/
│       ├── auth.spec.ts      # Kiểm thử đăng nhập bảo mật và chống password bypass
│       └── location.spec.ts  # Kiểm thử Haversine, Area Scope, chuẩn hóa SĐT và an toàn tên file ảnh
├── admin_web/                # Ứng dụng Web Quản trị (React + Vite + Tailwind CSS)
│   ├── Dockerfile            # Multi-stage build (Node build -> Nginx Alpine)
│   ├── nginx.conf            # Cấu hình Nginx try_files cho SPA HTML5 History
│   ├── package.json          # Dependency frontend
│   ├── vite.config.ts        # Cấu hình Vite bundler
│   ├── index.html            # Single Page HTML entry
│   └── src/
│       ├── main.tsx          # React DOM entry point
│       ├── App.tsx           # Router chính & ProtectedLayout kiểm tra token
│       ├── api/
│       │   └── client.ts     # Cấu hình Axios instance + VITE_API_BASE_URL động
│       ├── components/
│       │   └── Sidebar.tsx   # Thanh điều hướng trái
│       └── pages/
│           ├── Login.tsx     # Giao diện đăng nhập quản trị
│           ├── Dashboard.tsx # Thống kê tổng quan & bảng tỷ lệ phủ theo khu vực
│           ├── Locations.tsx # Bản đồ Leaflet xem vị trí khách hàng + ảnh mặt tiền
│           ├── Users.tsx     # Danh sách nhân viên, modal bàn giao khu vực & modal tạo user mới
│           ├── Areas.tsx     # Danh mục khu vực & modal tạo khu vực mới
│           └── AuditLogs.tsx # Bảng nhật ký thao tác hệ thống
└── mobile_app/               # Ứng dụng di động Shipper (Flutter)
    ├── pubspec.yaml          # Flutter dependencies (flutter_map, geolocator, image_picker, sqflite, ...)
    ├── android/              # Native Android wrapper (ACCESS_FINE_LOCATION, CAMERA, INTERNET)
    ├── ios/                  # Native iOS wrapper (NSLocation, NSCamera, NSPhotoLibrary usage descriptions)
    ├── test/
    │   └── widget_test.dart  # Test AuthSplashScreen, LoginView validation, OrderModel & SavedLocationModel
    └── lib/
        ├── main.dart         # Entry point chính thức: DeliveryLocationMarkerApp (AuthSplashScreen)
        ├── models/
        │   ├── user_model.dart       # Model UserModel (id, fullName, role, assignedAreaIds, token)
        │   ├── order_model.dart      # Model OrderModel (chi tiết đơn, khách, trạng thái vị trí)
        │   └── location_model.dart   # Model SavedLocationModel (lat, lng, accuracy, notes, imageUrl)
        ├── services/
        │   ├── api_service.dart      # HTTP Client, phát hiện host động, tra cứu SĐT, đồng bộ queue
        │   └── offline_storage_service.dart # SQLite Database v2 (cached_orders, queue kèm ảnh & retry)
        └── views/
            ├── prototype_map_marker_view.dart # Bản prototype cũ độc lập được bảo tồn an toàn
            ├── login_view.dart          # Màn hình đăng nhập tài khoản Shipper (validation form chuẩn)
            ├── order_list_view.dart     # Danh sách đơn hàng trong ca, hiển thị badge vị trí & sync queue
            ├── order_detail_view.dart   # Chi tiết đơn, hiển thị ảnh nhà, tra cứu SĐT & dẫn đường
            └── save_location_view.dart  # Chụp ảnh mặt tiền, cảnh báo sai số GPS, ghim bản đồ & xác nhận
```

---

## 3. Điểm Vào Hệ Thống (Entry Points)

| Phân hệ | Tệp Entry Point | Hành Vi Khởi Tạo |
| :--- | :--- | :--- |
| **Database** | [01-init-db.sql](file:///d:/flutter create delivery_marker_app/init-db/01-init-db.sql) | Nạp qua Docker entrypoint khi container Postgres khởi chạy lần đầu |
| **Backend** | [backend/src/index.ts](file:///d:/flutter create delivery_marker_app/backend/src/index.ts) | Nạp dotenv, khởi tạo `createApp()`, lắng nghe cổng `process.env.PORT || 3000` |
| **Admin Web** | [admin_web/src/main.tsx](file:///d:/flutter create delivery_marker_app/admin_web/src/main.tsx) | Render `<App />` vào DOM node `#root`, bọc trong `React.StrictMode` |
| **Mobile App** | [mobile_app/lib/main.dart](file:///d:/flutter create delivery_marker_app/mobile_app/lib/main.dart) | Khởi động `DeliveryLocationMarkerApp` -> `AuthSplashScreen` kiểm tra token SharedPreferences -> `LoginView` (chưa đăng nhập) hoặc `HomeShellView` (có phiên hợp lệ, mở thẳng Bản đồ chính làm trung tâm) |

---

## 4. Luồng Xử Lý & Giao Tiếp Thành Phần (Component Interactions & Flows)

### 4.1. Luồng Xác thực & Phân quyền (Authentication & Authorization Flow)
1. Client gửi `POST /api/v1/auth/login` với `{ phoneNumber, password }`.
2. [auth.controller.ts](file:///d:/flutter create delivery_marker_app/backend/src/controllers/auth.controller.ts) tìm user trong DB, kiểm tra mật khẩu.
3. Controller truy vấn bảng `user_areas` để lấy danh sách `assignedAreaIds` mà người dùng phụ trách.
4. Sinh JWT token ký bởi `JWT_SECRET`, payload chứa `{ userId, fullName, phoneNumber, roleName, assignedAreaIds }`.
5. Khi gọi các endpoint bảo vệ:
   - [auth.middleware.ts](file:///d:/flutter create delivery_marker_app/backend/src/middlewares/auth.middleware.ts) giải mã token, gắn `req.user`.
   - `requireRoles('ADMIN', ...)` chặn các vai trò không phù hợp bằng mã HTTP `403`.
   - [area.middleware.ts](file:///d:/flutter create delivery_marker_app/backend/src/middlewares/area.middleware.ts) kiểm tra quyền thao tác trên khách hàng: nếu `roleName !== 'ADMIN'`, middleware đối chiếu `customer.area_id` với `assignedAreaIds`. Nếu không trùng khớp, trả về `403 Forbidden`.

### 4.2. Luồng Shipper Lưu Vị Trí Thực Tế (Shipper 3-Step Pinning Flow)
```
[Shipper App: SaveLocationView]
   |
   |-- Bước 1: Geolocator.getCurrentPosition(desiredAccuracy: high)
   |           -> Hiển thị sai số GPS: ±gpsAccuracy (m)
   |-- Bước 2: FlutterMap tương tác -> Shipper chạm/kéo ghim trên màn hình
   |           -> Cập nhật _selectedLatLng
   |-- Bước 3: Nhập ghi chú nhận diện (identificationNotes)
   |           -> Nhấn "XÁC NHẬN LƯU VỊ TRÍ"
   v
[ApiService.saveCustomerLocation]
   |
   +---[Có mạng (Online)]---------> Gọi POST /api/v1/customers/:customerId/location
   |                                     |
   |                                     v
   |                                [Backend API]
   |                                     |-- checkCustomerAreaScope -> OK
   |                                     |-- Query: INSERT/UPDATE saved_locations
   |                                     |   (geom = ST_SetSRID(ST_MakePoint(lng, lat), 4326))
   |                                     |-- Trigger fn_log_location_history()
   |                                     |   tự động ghi bản ghi cũ vào location_history
   |                                     `-- Ghi audit_logs (action: UPDATE_LOCATION)
   |
   `---[Mất mạng (Offline)]-------> Lưu vào SQLite: offline_sync_queue
                                         |
                                         v
                                    [OfflineStorageService]
                                    Lưu cục bộ: {customerId, lat, lng, accuracy, notes}
```

### 4.3. Luồng Quản trị Theo dõi & Tìm kiếm Vị trí (Admin Overview Flow)
1. **Thống kê Coverage:** Admin truy cập `/dashboard` -> Gọi `GET /api/v1/admin/stats/coverage` -> CSDL tính tỷ lệ phần trăm `(COUNT(saved_locations) / COUNT(customers)) * 100` gom nhóm theo từng khu vực -> Admin Web hiển thị thanh tiến trình trực quan.
2. **Bản đồ Vị trí:** Admin truy cập `/locations` -> Gọi `GET /api/v1/admin/locations?search=...` -> CSDL trả về danh sách vị trí kèm thông tin khách hàng -> React-Leaflet render các Marker ghim đỏ, hỗ trợ chuyển đổi lớp gạch bản đồ vệ tinh Esri World Imagery.

---

## 5. Tích Hợp Bên Ngoài (External Integrations)

| Dịch Vụ Bên Ngoài | Giao Thức / URL | Mục Đích Sử Dụng | Vị Trí Mã Nguồn |
| :--- | :--- | :--- | :--- |
| **OpenStreetMap Standard** | `https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png` | Bản đồ đường phố mặc định trên Admin Web & Mobile | [Locations.tsx:L114](file:///d:/flutter create delivery_marker_app/admin_web/src/pages/Locations.tsx#L114) |
| **Esri World Imagery** | `https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}` | Lớp ảnh vệ tinh độ phân giải cao trên Admin Web | [Locations.tsx:L112](file:///d:/flutter create delivery_marker_app/admin_web/src/pages/Locations.tsx#L112) |
| **Google Maps Tiles** | `https://mt1.google.com/vt/lyrs={m|y}&x={x}&y={y}&z={z}` | Bản đồ hiển thị trên Flutter Map của Mobile App | [order_detail_view.dart:L97](file:///d:/flutter create delivery_marker_app/mobile_app/lib/views/order_detail_view.dart#L97) |
| **Google Maps Navigation** | `https://www.google.com/maps/search/?api=1&query={lat},{lng}` | Deep-link điều hướng mở ứng dụng dẫn đường ngoài | [api_service.dart:L128](file:///d:/flutter create delivery_marker_app/mobile_app/lib/services/api_service.dart#L128) |
| **Leaflet Marker CDN** | `https://raw.githubusercontent.com/pointhi/leaflet-color-markers/...` | Icon ghim màu đỏ cho bản đồ Leaflet | [Locations.tsx:L9](file:///d:/flutter create delivery_marker_app/admin_web/src/pages/Locations.tsx#L9) |

---

## 6. Điểm Lệch Chuẩn Kiến Trúc Cần Lưu Ý (Architectural Discrepancies)

1. **Sự ngắt kết nối của Mobile Entry Point:**
   - [mobile_app/lib/main.dart](file:///d:/flutter create delivery_marker_app/mobile_app/lib/main.dart) đang tự định nghĩa widget `MapMarkerCloneApp` (564 dòng code) lưu dữ liệu vào `SharedPreferences`, hoàn toàn không kết nối tới REST API.
   - Các module kiến trúc chuẩn của Delivery Marker (`models/`, `services/`, `views/`) đã được lập trình sẵn sàng nhưng chưa được gắn vào hàm `main()`.
2. **Quy ước Tọa độ Không gian PostGIS:**
   - Trong toán học và PostGIS: `ST_MakePoint(X, Y)` tương ứng `ST_MakePoint(longitude, latitude)`.
   - Trong [locations.controller.ts:L82](file:///d:/flutter create delivery_marker_app/backend/src/controllers/locations.controller.ts#L82), tham số `$3` là longitude và `$2` là latitude: `ST_MakePoint($3, $2)` -> Đúng chuẩn PostGIS. Cần đảm bảo mọi module mới tuân thủ đúng quy ước `(lng, lat)` khi thao tác với SQL hình học.
