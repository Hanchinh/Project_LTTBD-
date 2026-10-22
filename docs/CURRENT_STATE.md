# Current State & Technical Debt: Delivery Location Marker System

> **Tài liệu theo dõi trạng thái thực tế của mã nguồn và các khoản nợ kỹ thuật (Technical Debt).**  
> **Cập nhật:** Dựa trên kết quả khảo sát thực tế và kiểm tra an toàn tại thời điểm bàn giao.

---

## 1. Tóm Tắt Trạng Thái Hệ Thống (Health Snapshot)

| Thành Phần | Trạng Thái Biên Dịch | Trạng Thái Kiểm Thử (Unit Test) | Trạng Thái Tích Hợp |
| :--- | :--- | :--- | :--- |
| **Database (PostGIS)** | Đạt (`01-init-db.sql`) | Đạt (Kiểm tra qua Docker Compose script) | Đã nạp Schema, Trigger, Index & Seed Data |
| **Backend API** | Đạt (`tsc --noEmit`: 0 lỗi) | **Đạt** (`npm test`: 4/4 passed) | Hoạt động đầy đủ 11 endpoints nghiệp vụ |
| **Admin Web** | Đạt (`tsc --noEmit`: 0 lỗi) | Chưa có bộ unit test tự động | Hoạt động 5 trang giao diện chính |
| **Mobile App (Flutter)** | Đạt cú pháp (15 warnings/info) | **Không đạt** (`flutter test`: 1 fail) | **Ngắt kết nối:** Entry point chưa gắn view giao hàng |

---

## 2. Bảng Phân Định Hiện Trạng Tính Năng (Feature Status Matrix)

> **Quy ước phân loại:**
> - **[XÁC MINH - ĐÃ TEST]**: Tính năng đã có mã nguồn và đã chạy kiểm thử tự động thành công.
> - **[XÁC MINH - ĐÃ CODE]**: Đã có mã nguồn hoàn chỉnh trong repo nhưng chưa có automated test bao phủ.
> - **[XÁC MINH - LỖI/CHƯA GẮN]**: Mã nguồn bị lỗi, thiếu liên kết hoặc không thể thực thi đúng thiết kế.
> - **[CHƯA TRIỂN KHAI]**: Chưa có mã nguồn hoặc giao diện.

| Phân Hệ | Chức Năng | Phân Loại | Bằng Chứng Mã Nguồn |
| :--- | :--- | :--- | :--- |
| **Backend** | Công thức Haversine đo độ lệch GPS (<20m) | [XÁC MINH - ĐÃ TEST] | [location.spec.ts:L21-L32](file:///d:/flutter create delivery_marker_app/backend/test/location.spec.ts#L21-L32) |
| **Backend** | Kiểm tra quyền truy cập theo khu vực (Area Scope) | [XÁC MINH - ĐÃ TEST] | [location.spec.ts:L35-L51](file:///d:/flutter create delivery_marker_app/backend/test/location.spec.ts#L35-L51) |
| **Backend** | Đăng nhập & cấp JWT token | [XÁC MINH - ĐÃ CODE] | [auth.controller.ts:L6-L85](file:///d:/flutter create delivery_marker_app/backend/src/controllers/auth.controller.ts#L6-L85) |
| **Backend** | Lấy danh sách đơn trong ca của Shipper | [XÁC MINH - ĐÃ CODE] | [orders.controller.ts:L5-L73](file:///d:/flutter create delivery_marker_app/backend/src/controllers/orders.controller.ts#L5-L73) |
| **Backend** | Lưu mới/Cập nhật tọa độ PostGIS & ghi chú | [XÁC MINH - ĐÃ CODE] | [locations.controller.ts:L58-L132](file:///d:/flutter create delivery_marker_app/backend/src/controllers/locations.controller.ts#L58-L132) |
| **Backend** | Xem lịch sử cập nhật vị trí khách hàng | [XÁC MINH - ĐÃ CODE] | [locations.controller.ts:L134-L171](file:///d:/flutter create delivery_marker_app/backend/src/controllers/locations.controller.ts#L134-L171) |
| **Backend** | Tính tỷ lệ phần trăm phủ vị trí theo khu vực | [XÁC MINH - ĐÃ CODE] | [admin.controller.ts:L197-L233](file:///d:/flutter create delivery_marker_app/backend/src/controllers/admin.controller.ts#L197-L233) |
| **Backend** | Quản lý khu vực & gán khu vực cho shipper | [XÁC MINH - ĐÃ CODE] | [admin.controller.ts:L7-L104](file:///d:/flutter create delivery_marker_app/backend/src/controllers/admin.controller.ts#L7-L104) |
| **Backend** | Tra cứu danh sách vị trí & Audit Logs | [XÁC MINH - ĐÃ CODE] | [admin.controller.ts:L107-L259](file:///d:/flutter create delivery_marker_app/backend/src/controllers/admin.controller.ts#L107-L259) |
| **Admin Web** | Đăng nhập Admin & Bảo vệ router bằng Token | [XÁC MINH - ĐÃ CODE] | [Login.tsx](file:///d:/flutter create delivery_marker_app/admin_web/src/pages/Login.tsx), [App.tsx:L11-L32](file:///d:/flutter create delivery_marker_app/admin_web/src/App.tsx#L11-L32) |
| **Admin Web** | Dashboard tỷ lệ phủ vị trí (% Coverage) | [XÁC MINH - ĐÃ CODE] | [Dashboard.tsx](file:///d:/flutter create delivery_marker_app/admin_web/src/pages/Dashboard.tsx) |
| **Admin Web** | Bản đồ Leaflet xem vị trí & Lớp ảnh vệ tinh Esri | [XÁC MINH - ĐÃ CODE] | [Locations.tsx](file:///d:/flutter create delivery_marker_app/admin_web/src/pages/Locations.tsx) |
| **Admin Web** | Danh sách nhân viên & Modal bàn giao khu vực | [XÁC MINH - ĐÃ CODE] | [Users.tsx](file:///d:/flutter create delivery_marker_app/admin_web/src/pages/Users.tsx) |
| **Admin Web** | Danh mục khu vực & Modal tạo mới khu vực | [XÁC MINH - ĐÃ CODE] | [Areas.tsx](file:///d:/flutter create delivery_marker_app/admin_web/src/pages/Areas.tsx) |
| **Admin Web** | Xem lịch sử thao tác hệ thống (Audit Logs) | [XÁC MINH - ĐÃ CODE] | [AuditLogs.tsx](file:///d:/flutter create delivery_marker_app/admin_web/src/pages/AuditLogs.tsx) |
| **Admin Web** | Giao diện tạo tài khoản người dùng mới | [CHƯA TRIỂN KHAI] | Backend đã có `POST /admin/users` nhưng web chưa có UI |
| **Admin Web** | Công cụ vẽ ranh giới đa giác khu vực (Polygon) | [CHƯA TRIỂN KHAI] | Bảng `areas.boundary` có sẵn nhưng chưa có UI vẽ/import |
| **Mobile App** | Giao diện Đăng nhập Shipper | [XÁC MINH - ĐÃ CODE] | [login_view.dart](file:///d:/flutter create delivery_marker_app/mobile_app/lib/views/login_view.dart) (Chưa được nối vào `main.dart`) |
| **Mobile App** | Danh sách đơn hàng trong ca & Badge vị trí | [XÁC MINH - ĐÃ CODE] | [order_list_view.dart](file:///d:/flutter create delivery_marker_app/mobile_app/lib/views/order_list_view.dart) |
| **Mobile App** | Chi tiết đơn, xem ghim & Deep-link Google Maps | [XÁC MINH - ĐÃ CODE] | [order_detail_view.dart](file:///d:/flutter create delivery_marker_app/mobile_app/lib/views/order_detail_view.dart) |
| **Mobile App** | Quy trình lưu vị trí 3 bước (GPS, Ghim, Note) | [XÁC MINH - ĐÃ CODE] | [save_location_view.dart](file:///d:/flutter create delivery_marker_app/mobile_app/lib/views/save_location_view.dart) |
| **Mobile App** | Lưu SQLite offline (`cached_orders`, `sync_queue`) | [XÁC MINH - ĐÃ CODE] | [offline_storage_service.dart](file:///d:/flutter create delivery_marker_app/mobile_app/lib/services/offline_storage_service.dart) |
| **Mobile App** | Entry point khởi động ứng dụng giao hàng | [XÁC MINH - LỖI/CHƯA GẮN]| [main.dart:L11](file:///d:/flutter create delivery_marker_app/mobile_app/lib/main.dart#L11) chạy prototype `MapMarkerCloneApp` |
| **Mobile App** | Unit / Widget Test của màn hình giao hàng | [XÁC MINH - LỖI/CHƯA GẮN]| [widget_test.dart](file:///d:/flutter create delivery_marker_app/mobile_app/test/widget_test.dart) chạy test bộ đếm bị fail |

---

## 3. Danh Mục Lỗi & Nợ Kỹ Thuật Đã Xác Minh (Technical Debt & Defects)

### 3.1. Mức độ Nghiêm Trọng: CAO (High Severity)
1. **Mobile App Entry Point bị lệch:**
   - [mobile_app/lib/main.dart](file:///d:/flutter create delivery_marker_app/mobile_app/lib/main.dart) không khởi động `LoginView()` hay `OrderListView()`. Chạy `flutter run` sẽ ra một ứng dụng prototype lưu mốc cục bộ không liên quan đến backend.
2. **Cửa hậu kiểm tra mật khẩu (Password Bypass) trong Backend:**
   - [auth.controller.ts:L33-L36](file:///d:/flutter create delivery_marker_app/backend/src/controllers/auth.controller.ts#L33-L36) chấp nhận chuỗi mật khẩu `password123` cho mọi tài khoản bất kể giá trị băm trong CSDL.
3. **Thiếu quyền vị trí trên nền tảng iOS:**
   - [Info.plist](file:///d:/flutter create delivery_marker_app/mobile_app/ios/Runner/Info.plist) thiếu `NSLocationWhenInUseUsageDescription` và `NSLocationAlwaysAndWhenInUseUsageDescription`. Ứng dụng sẽ crash lập tức khi chạy trên thiết bị iOS thật.
4. **Hardcode Địa chỉ mạng của Backend:**
   - Admin Web hardcode `http://localhost:3000/api/v1` ([client.ts:L4](file:///d:/flutter create delivery_marker_app/admin_web/src/api/client.ts#L4)).
   - Mobile App hardcode `http://10.0.2.2:3000/api/v1` ([api_service.dart:L13](file:///d:/flutter create delivery_marker_app/mobile_app/lib/services/api_service.dart#L13)). Chỉ dùng được cho Android Emulator, không chạy được trên iOS Simulator hay máy thật.

### 3.2. Mức độ Nghiêm Trọng: TRUNG BÌNH (Medium Severity)
1. **Lỗi xóa vị trí làm mất toàn bộ lịch sử:**
   - Khóa ngoại `saved_location_id` trong `location_history` có ràng buộc `ON DELETE CASCADE` ([01-init-db.sql:L102](file:///d:/flutter create delivery_marker_app/init-db/01-init-db.sql#L102)). Thao tác xóa vị trí tại [admin.controller.ts:L184](file:///d:/flutter create delivery_marker_app/backend/src/controllers/admin.controller.ts#L184) sẽ xóa luôn toàn bộ dữ liệu lịch sử đối soát.
2. **Nginx SPA 404 trong Docker Compose:**
   - [admin_web/Dockerfile](file:///d:/flutter create delivery_marker_app/admin_web/Dockerfile) chưa cấu hình `try_files` chuyển tiếp về `index.html`. Người dùng F5 lại trang trên trình duyệt sẽ nhận mã lỗi 404.
3. **Chưa khởi tạo Version Control (Git):**
   - Cả thư mục gốc và các thư mục con đều chưa có kho lưu trữ Git (`.git`).

---

## 4. Kế Hoạch Phát Triển Đề Xuất Tiếp Theo (Immediate Implementation Roadmap)

```
[Sprint 1: Kỹ thuật cốt lõi & Khắc phục lỗi chặn]
  ├── Task 1.1: Tái cấu trúc mobile_app/lib/main.dart kết nối LoginView & OrderListView
  ├── Task 1.2: Bổ sung NSLocation descriptions vào mobile_app/ios/Runner/Info.plist
  ├── Task 1.3: Cập nhật mobile_app/test/widget_test.dart test đúng view nghiệp vụ
  └── Task 1.4: Khởi tạo Git repository toàn dự án (git init + .gitignore)

[Sprint 2: Bảo mật & Chuẩn hóa môi trường]
  ├── Task 2.1: Gỡ bỏ bypass password123 trong auth.controller.ts
  ├── Task 2.2: Chuyển baseURL trong Admin Web sang biến môi trường VITE_API_BASE_URL
  ├── Task 2.3: Xây dựng cơ chế phát hiện môi trường động cho baseURL của Mobile App
  └── Task 2.4: Bổ sung nginx.conf hỗ trợ SPA routing cho Docker Admin Web

[Sprint 3: Bổ sung tính năng Quản trị & Hoàn thiện CSDL]
  ├── Task 3.1: Thêm modal Tạo Người Dùng mới trong Admin Web (Users.tsx)
  ├── Task 3.2: Chuyển cơ chế xóa vị trí sang Soft Delete hoặc tách độc lập location_history
  └── Task 3.3: Mở rộng Swagger UI bao phủ toàn bộ 11 endpoints của Backend
```
