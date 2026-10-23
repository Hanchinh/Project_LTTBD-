# Current State & Technical Debt: Delivery Location Marker System

> **Tài liệu theo dõi trạng thái thực tế của mã nguồn và các khoản nợ kỹ thuật (Technical Debt).**  
> **Cập nhật:** Hoàn thiện tích hợp luồng nghiệp vụ Mobile App, Camera/GPS, Tra cứu theo SĐT, Backend Photo Storage, Bảo toàn lịch sử và Admin Web.

---

## 1. Tóm Tắt Trạng Thái Hệ Thống (Health Snapshot)

| Thành Phần | Trạng Thái Biên Dịch | Trạng Thái Kiểm Thử (Unit Test) | Trạng Thái Tích Hợp |
| :--- | :--- | :--- | :--- |
| **Database (PostGIS)** | Đạt ([01-init-db.sql](file:///d:/flutter create delivery_marker_app/init-db/01-init-db.sql), [02-add-photo-and-fix-history.sql](file:///d:/flutter create delivery_marker_app/init-db/02-add-photo-and-fix-history.sql), [04-create-shifts-and-delivery-points.sql](file:///d:/flutter create delivery_marker_app/init-db/04-create-shifts-and-delivery-points.sql)) | Đạt (Schema PostGIS, Trigger ảnh, Quản lý Ca làm việc & Điểm giao) | Đã bổ sung bảng `shifts` và `shift_delivery_points`, hỗ trợ 3 trạng thái vị trí `VERIFIED`, `TEMPORARY`, `NO_LOCATION`, kích hoạt extension `unaccent` |
| **Backend API** | Đạt ([app.ts](file:///d:/flutter create delivery_marker_app/backend/src/app.ts), TypeScript 5.4.5) | **Đạt** (66/66 tests: [shifts.spec.ts](file:///d:/flutter create delivery_marker_app/backend/test/shifts.spec.ts), [orders.spec.ts](file:///d:/flutter create delivery_marker_app/backend/test/orders.spec.ts), [location.spec.ts](file:///d:/flutter create delivery_marker_app/backend/test/location.spec.ts), [auth.spec.ts](file:///d:/flutter create delivery_marker_app/backend/test/auth.spec.ts)) | Hoạt động 23 endpoints (bao gồm Geocoding Search, Tạo nhanh khách hàng & thêm vào ca, 8 API Ca làm việc, ghim tạm, xác minh cổng nhà) |
| **Admin Web** | Đạt ([client.ts](file:///d:/flutter create delivery_marker_app/admin_web/src/api/client.ts), TypeScript 5.2.2) | Đã cập nhật UI hỗ trợ ảnh và tạo tài khoản mới | Hoạt động 5 trang giao diện chính, đã cấu hình [nginx.conf](file:///d:/flutter create delivery_marker_app/admin_web/nginx.conf) |
| **Mobile App (Flutter)** | Đạt chuẩn Flutter/Dart SDK `>=3.0.0 <4.0.0` | **Đạt** (Kiểm thử tự động: [shift_test.dart](file:///d:/flutter create delivery_marker_app/mobile_app/test/shift_test.dart), [widget_test.dart](file:///d:/flutter create delivery_marker_app/mobile_app/test/widget_test.dart), [sqlite_migration_test.dart](file:///d:/flutter create delivery_marker_app/mobile_app/test/sqlite_migration_test.dart)) | **Đã kích hoạt:** Tạo nhanh khách hàng chưa có hồ sơ, Tìm kiếm địa chỉ bằng Geocoding trong bộ chọn tâm ngắm, Bản đồ ca làm thật, loại bỏ marker demo |

---

## 2. Bảng Phân Định Hiện Trạng Tính Năng (Feature Status Matrix)

> **Quy ước phân loại:**
> - **[XÁC MINH - ĐÃ TEST]**: Tính năng đã có mã nguồn và đã có automated test bao phủ.
> - **[XÁC MINH - ĐÃ CODE]**: Đã có mã nguồn hoàn chỉnh trong repo sẵn sàng kiểm thử tích hợp.
> - **[XÁC MINH - LỖI/CHƯA GẮN]**: Mã nguồn bị lỗi hoặc thiếu liên kết.
> - **[CHƯA TRIỂN KHAI]**: Chưa có mã nguồn hoặc giao diện.

| Phân Hệ | Chức Năng | Phân Loại | Bằng Chứng Mã Nguồn |
| :--- | :--- | :--- | :--- |
| **Backend** | Quản lý Ca làm việc (`shifts`): Tạo ca, liệt kê ca, đổi trạng thái | [XÁC MINH - ĐÃ TEST] | [shifts.controller.ts:L31-L157](file:///d:/flutter create delivery_marker_app/backend/src/controllers/shifts.controller.ts#L31-L157), [shifts.spec.ts](file:///d:/flutter create delivery_marker_app/backend/test/shifts.spec.ts) |
| **Backend** | Thêm điểm giao vào ca bằng SĐT, gộp trùng (Idempotent) | [XÁC MINH - ĐÃ TEST] | [shifts.controller.ts:L159-L270](file:///d:/flutter create delivery_marker_app/backend/src/controllers/shifts.controller.ts#L159-L270), [shifts.spec.ts](file:///d:/flutter create delivery_marker_app/backend/test/shifts.spec.ts) |
| **Backend** | Ghim vị trí tạm thời (`TEMPORARY`) cho điểm giao trước khi đi | [XÁC MINH - ĐÃ TEST] | [shifts.controller.ts:L316-L368](file:///d:/flutter create delivery_marker_app/backend/src/controllers/shifts.controller.ts#L316-L368), [shifts.spec.ts](file:///d:/flutter create delivery_marker_app/backend/test/shifts.spec.ts) |
| **Backend** | Xác minh cổng nhà tại hiện trường (`VERIFIED`), lưu ảnh & lịch sử | [XÁC MINH - ĐÃ TEST] | [shifts.controller.ts:L370-L465](file:///d:/flutter create delivery_marker_app/backend/src/controllers/shifts.controller.ts#L370-L465), [shifts.spec.ts](file:///d:/flutter create delivery_marker_app/backend/test/shifts.spec.ts) |
| **Backend** | Xóa điểm giao khỏi ca làm việc an toàn | [XÁC MINH - ĐÃ TEST] | [shifts.controller.ts:L272-L314](file:///d:/flutter create delivery_marker_app/backend/src/controllers/shifts.controller.ts#L272-L314), [shifts.spec.ts](file:///d:/flutter create delivery_marker_app/backend/test/shifts.spec.ts) |
| **Backend** | Sinh mã ca làm việc chuẩn nhất quán (`SHF-YYYYMMDD-XXX`) | [XÁC MINH - ĐÃ TEST] | [shifts.controller.ts:L18-L29](file:///d:/flutter create delivery_marker_app/backend/src/controllers/shifts.controller.ts#L18-L29), [shifts.spec.ts](file:///d:/flutter create delivery_marker_app/backend/test/shifts.spec.ts) |
| **Backend** | Công thức Haversine đo độ lệch GPS (<20m) | [XÁC MINH - ĐÃ TEST] | [location.spec.ts:L36-L53](file:///d:/flutter create delivery_marker_app/backend/test/location.spec.ts#L36-L53) |
| **Backend** | Chuẩn hóa số điện thoại tra cứu khách hàng | [XÁC MINH - ĐÃ TEST] | [location.spec.ts:L72-L87](file:///d:/flutter create delivery_marker_app/backend/test/location.spec.ts#L72-L87) |
| **Backend** | Kiểm tra an toàn tên tệp ảnh & chống Path Traversal | [XÁC MINH - ĐÃ TEST] | [location.spec.ts:L89-L109](file:///d:/flutter create delivery_marker_app/backend/test/location.spec.ts#L89-L109) |
| **Backend** | Bảo toàn dữ liệu lịch sử vị trí khi hủy liên kết | [XÁC MINH - ĐÃ TEST] | [location.spec.ts:L111-L129](file:///d:/flutter create delivery_marker_app/backend/test/location.spec.ts#L111-L129) |
| **Backend** | Kiểm tra quyền truy cập theo khu vực (Area Scope) | [XÁC MINH - ĐÃ TEST] | [location.spec.ts:L55-L70](file:///d:/flutter create delivery_marker_app/backend/test/location.spec.ts#L55-L70) |
| **Backend** | Đăng nhập, bảo mật mật khẩu & cấp JWT token | [XÁC MINH - ĐÃ TEST] | [auth.controller.ts](file:///d:/flutter create delivery_marker_app/backend/src/controllers/auth.controller.ts), [auth.spec.ts](file:///d:/flutter create delivery_marker_app/backend/test/auth.spec.ts) |
| **Backend** | Tra cứu hồ sơ vị trí khách hàng bằng số điện thoại | [XÁC MINH - ĐÃ CODE] | [locations.controller.ts:L204-L288](file:///d:/flutter create delivery_marker_app/backend/src/controllers/locations.controller.ts#L204-L288) |
| **Backend** | Lưu ảnh mặt tiền nhà từ client (Base64 -> File -> DB) | [XÁC MINH - ĐÃ CODE] | [locations.controller.ts:L66-L113](file:///d:/flutter create delivery_marker_app/backend/src/controllers/locations.controller.ts#L66-L113) |
| **Backend** | Phục vụ ảnh an toàn chống rò rỉ dữ liệu | [XÁC MINH - ĐÃ CODE] | [locations.controller.ts:L293-L318](file:///d:/flutter create delivery_marker_app/backend/src/controllers/locations.controller.ts#L293-L318) |
| **Backend** | Lấy danh sách đơn trong ca của Shipper kèm ảnh | [XÁC MINH - ĐÃ CODE] | [orders.controller.ts:L5-L74](file:///d:/flutter create delivery_marker_app/backend/src/controllers/orders.controller.ts#L5-L74) |
| **Backend** | Thêm điểm giao vào ca (`POST /orders/my-shift`) kèm RBAC, Scope khu vực, Audit logs & Idempotency | [XÁC MINH - ĐÃ TEST] | [orders.controller.ts:L78-L235](file:///d:/flutter create delivery_marker_app/backend/src/controllers/orders.controller.ts#L78-L235), [orders.spec.ts](file:///d:/flutter create delivery_marker_app/backend/test/orders.spec.ts) |
| **Backend** | Sinh mã đơn hàng chuẩn nhất quán (`ORD-YYYYMMDD-XXXXX`) | [XÁC MINH - ĐÃ TEST] | [orders.controller.ts:L175-L188](file:///d:/flutter create delivery_marker_app/backend/src/controllers/orders.controller.ts#L175-L188), [orders.spec.ts:L190-L215](file:///d:/flutter create delivery_marker_app/backend/test/orders.spec.ts#L190-L215) |
| **Backend** | Chuẩn hóa số điện thoại VN (10 số, đầu 84, thiếu 0, khoảng trắng) | [XÁC MINH - ĐÃ TEST] | [orders.spec.ts:L4-L28](file:///d:/flutter create delivery_marker_app/backend/test/orders.spec.ts#L4-L28), [location.spec.ts:L19-L26](file:///d:/flutter create delivery_marker_app/backend/test/location.spec.ts#L19-L26) |
| **Backend** | Lưu mới/Cập nhật tọa độ PostGIS, ảnh & ghi chú | [XÁC MINH - ĐÃ CODE] | [locations.controller.ts:L58-L202](file:///d:/flutter create delivery_marker_app/backend/src/controllers/locations.controller.ts#L58-L202) |
| **Backend** | Xem lịch sử cập nhật vị trí khách hàng kèm ảnh | [XÁC MINH - ĐÃ CODE] | [locations.controller.ts:L320-L358](file:///d:/flutter create delivery_marker_app/backend/src/controllers/locations.controller.ts#L320-L358) |
| **Backend** | Quản lý khu vực & gán khu vực cho shipper | [XÁC MINH - ĐÃ CODE] | [admin.controller.ts:L7-L104](file:///d:/flutter create delivery_marker_app/backend/src/controllers/admin.controller.ts#L7-L104) |
| **Backend** | Xóa vị trí an toàn bảo toàn lịch sử đối soát | [XÁC MINH - ĐÃ CODE] | [admin.controller.ts:L180-L196](file:///d:/flutter create delivery_marker_app/backend/src/controllers/admin.controller.ts#L180-L196) |
| **Admin Web** | Đăng nhập Admin & Bảo vệ router bằng Token | [XÁC MINH - ĐÃ CODE] | [Login.tsx](file:///d:/flutter create delivery_marker_app/admin_web/src/pages/Login.tsx), [App.tsx:L11-L32](file:///d:/flutter create delivery_marker_app/admin_web/src/App.tsx#L11-L32) |
| **Admin Web** | Dashboard tỷ lệ phủ vị trí (% Coverage) | [XÁC MINH - ĐÃ CODE] | [Dashboard.tsx](file:///d:/flutter create delivery_marker_app/admin_web/src/pages/Dashboard.tsx) |
| **Admin Web** | Bản đồ Leaflet xem vị trí & hiển thị ảnh mặt tiền | [XÁC MINH - ĐÃ CODE] | [Locations.tsx:L125-L175](file:///d:/flutter create delivery_marker_app/admin_web/src/pages/Locations.tsx#L125-L175) |
| **Admin Web** | Danh sách nhân viên & Modal bàn giao khu vực | [XÁC MINH - ĐÃ CODE] | [Users.tsx:L134-L184](file:///d:/flutter create delivery_marker_app/admin_web/src/pages/Users.tsx#L134-L184) |
| **Admin Web** | Giao diện tạo tài khoản nhân viên / admin mới | [XÁC MINH - ĐÃ CODE] | [Users.tsx:L186-L270](file:///d:/flutter create delivery_marker_app/admin_web/src/pages/Users.tsx#L186-L270) |
| **Mobile App** | Quản lý danh sách Ca làm việc (`ShiftListView`) & Tạo ca mới | [XÁC MINH - ĐÃ TEST] | [shift_list_view.dart](file:///d:/flutter create delivery_marker_app/mobile_app/lib/views/shift_list_view.dart), [shift_test.dart](file:///d:/flutter create delivery_marker_app/mobile_app/test/shift_test.dart) |
| **Mobile App** | Chuẩn bị ca bằng SĐT tại kho (`ShiftPreparationView`) | [XÁC MINH - ĐÃ TEST] | [shift_preparation_view.dart](file:///d:/flutter create delivery_marker_app/mobile_app/lib/views/shift_preparation_view.dart), [shift_test.dart](file:///d:/flutter create delivery_marker_app/mobile_app/test/shift_test.dart) |
| **Mobile App** | Bản đồ riêng cho từng ca làm việc (`ShiftMapView`) | [XÁC MINH - ĐÃ TEST] | [shift_map_view.dart](file:///d:/flutter create delivery_marker_app/mobile_app/lib/views/shift_map_view.dart), [shift_test.dart](file:///d:/flutter create delivery_marker_app/mobile_app/test/shift_test.dart) |
| **Mobile App** | Nút ghim đỏ nổi bật góc dưới bên phải (`CHỌN VỊ TRÍ` >= 58px) | [XÁC MINH - ĐÃ TEST] | [shift_map_view.dart:L440-L495](file:///d:/flutter create delivery_marker_app/mobile_app/lib/views/shift_map_view.dart#L440-L495) |
| **Mobile App** | Bộ chọn vị trí bằng tâm ngắm cố định (`CrosshairLocationPickerView`) | [XÁC MINH - ĐÃ TEST] | [crosshair_location_picker_view.dart](file:///d:/flutter create delivery_marker_app/mobile_app/lib/views/crosshair_location_picker_view.dart), [shift_test.dart](file:///d:/flutter create delivery_marker_app/mobile_app/test/shift_test.dart) |
| **Mobile App** | Hiển thị 3 màu marker chuẩn: Xanh lá (`VERIFIED`), Cam (`TEMPORARY`), Không ghim (`NO_LOCATION`) | [XÁC MINH - ĐÃ TEST] | [shift_map_view.dart:L180-L245](file:///d:/flutter create delivery_marker_app/mobile_app/lib/views/shift_map_view.dart#L180-L245) |
| **Mobile App** | Thẻ chi tiết điểm giao trên bản đồ ca (Chạm marker mở thẻ, có SĐT, Đ/C, Tọa độ, nút Gọi, Chỉ đường, Tâm ngắm) | [XÁC MINH - ĐÃ TEST] | [shift_map_view.dart:L498-L640](file:///d:/flutter create delivery_marker_app/mobile_app/lib/views/shift_map_view.dart#L498-L640) |
| **Mobile App** | Entry point khởi động ứng dụng giao hàng | [XÁC MINH - ĐÃ TEST] | [main.dart](file:///d:/flutter create delivery_marker_app/mobile_app/lib/main.dart) (Khởi động AuthSplashScreen -> ShiftListView/LoginView) |
| **Mobile App** | Màn hình bản đồ giao hàng tổng hợp (FEATURE-MAP-001) | [XÁC MINH - ĐÃ TEST] | [delivery_map_view.dart](file:///d:/flutter create delivery_marker_app/mobile_app/lib/views/delivery_map_view.dart), [widget_test.dart:L87-L135](file:///d:/flutter create delivery_marker_app/mobile_app/test/widget_test.dart#L87-L135) |
| **Mobile App** | Định vị GPS Shipper & Xử lý quyền vị trí (3 trạng thái) | [XÁC MINH - ĐÃ TEST] | [delivery_map_view.dart:L69-L138](file:///d:/flutter create delivery_marker_app/mobile_app/lib/views/delivery_map_view.dart#L69-L138) |
| **Mobile App** | Thiết kế cho người lớn tuổi (Touch target >= 48px, chữ to, tương phản) | [XÁC MINH - ĐÃ TEST] | [shift_list_view.dart](file:///d:/flutter create delivery_marker_app/mobile_app/lib/views/shift_list_view.dart), [shift_preparation_view.dart](file:///d:/flutter create delivery_marker_app/mobile_app/lib/views/shift_preparation_view.dart), [shift_map_view.dart](file:///d:/flutter create delivery_marker_app/mobile_app/lib/views/shift_map_view.dart), [crosshair_location_picker_view.dart](file:///d:/flutter create delivery_marker_app/mobile_app/lib/views/crosshair_location_picker_view.dart) |
| **Mobile App** | Chụp ảnh mặt tiền/cổng nhà, xem trước & chụp lại | [XÁC MINH - ĐÃ CODE] | [save_location_view.dart:L116-L195](file:///d:/flutter create delivery_marker_app/mobile_app/lib/views/save_location_view.dart#L116-L195) |
| **Mobile App** | Cảnh báo sai số GPS (>20m) & Kéo thả ghim thủ công | [XÁC MINH - ĐÃ CODE] | [save_location_view.dart:L197-L290](file:///d:/flutter create delivery_marker_app/mobile_app/lib/views/save_location_view.dart#L197-L290) |
| **Mobile App** | Lưu SQLite offline (`cached_orders`, `sync_queue` v2) | [XÁC MINH - ĐÃ TEST] | [offline_storage_service.dart](file:///d:/flutter create delivery_marker_app/mobile_app/lib/services/offline_storage_service.dart), [sqlite_migration_test.dart](file:///d:/flutter create delivery_marker_app/mobile_app/test/sqlite_migration_test.dart) |

---

## 3. Danh Mục Lỗi & Nợ Kỹ Thuật Đã Xử Lý (Resolved Technical Debt)

1. **[ĐÃ GIẢI QUYẾT] Mobile App Entry Point bị lệch:**
   - Đã tách prototype cũ sang [prototype_map_marker_view.dart](file:///d:/flutter create delivery_marker_app/mobile_app/lib/views/prototype_map_marker_view.dart).
   - [main.dart](file:///d:/flutter create delivery_marker_app/mobile_app/lib/main.dart) được viết lại hoàn toàn thành `DeliveryLocationMarkerApp`, tự động kiểm tra phiên đăng nhập và định tuyến chính xác.
2. **[ĐÃ GIẢI QUYẾT] Cửa hậu kiểm tra mật khẩu (Password Bypass) trong Backend:**
   - Đã loại bỏ hoàn toàn cơ chế bypass trong [auth.controller.ts](file:///d:/flutter create delivery_marker_app/backend/src/controllers/auth.controller.ts).
3. **[ĐÃ GIẢI QUYẾT] Thiếu quyền vị trí & camera trên iOS và Android:**
   - [Info.plist](file:///d:/flutter create delivery_marker_app/mobile_app/ios/Runner/Info.plist) đã được bổ sung đầy đủ: `NSLocationWhenInUseUsageDescription`, `NSLocationAlwaysAndWhenInUseUsageDescription`, `NSCameraUsageDescription`, `NSPhotoLibraryUsageDescription`.
   - [AndroidManifest.xml](file:///d:/flutter create delivery_marker_app/mobile_app/android/app/src/main/AndroidManifest.xml) đã được bổ sung quyền `android.permission.CAMERA`.
4. **[ĐÃ GIẢI QUYẾT] Hardcode Địa chỉ mạng của Backend:**
   - Admin Web sử dụng `import.meta.env.VITE_API_BASE_URL` trong [client.ts](file:///d:/flutter create delivery_marker_app/admin_web/src/api/client.ts).
   - Mobile App tự động phát hiện `Platform.isAndroid` (dùng `10.0.2.2`) hoặc iOS/Desktop (dùng `localhost`), đồng thời cho phép cấu hình linh hoạt qua `SharedPreferences` trong [api_service.dart](file:///d:/flutter create delivery_marker_app/mobile_app/lib/services/api_service.dart).
5. **[ĐÃ GIẢI QUYẾT] Lỗi xóa vị trí làm mất lịch sử đối soát:**
   - CSDL cập nhật ràng buộc `ON DELETE SET NULL` trong [01-init-db.sql](file:///d:/flutter create delivery_marker_app/init-db/01-init-db.sql) và script migration [02-add-photo-and-fix-history.sql](file:///d:/flutter create delivery_marker_app/init-db/02-add-photo-and-fix-history.sql).
   - Controller [admin.controller.ts](file:///d:/flutter create delivery_marker_app/backend/src/controllers/admin.controller.ts) chủ động tách gỡ `saved_location_id` trước khi xóa để bảo toàn 100% dữ liệu lịch sử đối soát.
6. **[ĐÃ GIẢI QUYẾT] Nginx SPA 404 trong Docker:**
   - Đã tạo cấu hình [admin_web/nginx.conf](file:///d:/flutter create delivery_marker_app/admin_web/nginx.conf) hỗ trợ `try_files $uri $uri/ /index.html;` và liên kết trong [admin_web/Dockerfile](file:///d:/flutter create delivery_marker_app/admin_web/Dockerfile).
7. **[ĐÃ GIẢI QUYẾT] Giao diện tạo tài khoản người dùng mới:**
   - Đã bổ sung modal "Thêm Nhân Viên Mới" trực tiếp trên giao diện [Users.tsx](file:///d:/flutter create delivery_marker_app/admin_web/src/pages/Users.tsx).
8. **[ĐÃ GIẢI QUYẾT] Lỗi Widget Test mẫu:**
   - Thay thế test bộ đếm bị fail bằng bộ kiểm thử hoàn chỉnh cho `AuthSplashScreen`, `LoginView` validation, `OrderModel` và `SavedLocationModel` trong [widget_test.dart](file:///d:/flutter create delivery_marker_app/mobile_app/test/widget_test.dart).
9. **[ĐÃ GIẢI QUYẾT - AUDIT-004A] Mất ảnh khi khởi động lại container (Persistent Volume):**
   - Đã bổ sung named volume `backend_uploads:/app/uploads` trong [docker-compose.yml](file:///d:/flutter create delivery_marker_app/docker-compose.yml) bảo toàn 100% ảnh hiện trường.
10. **[ĐÃ GIẢI QUYẾT - AUDIT-004A] Lỗ hổng API tải ảnh công khai & Phân quyền vùng:**
   - Route `GET /api/v1/photos/:filename` trong [app.ts](file:///d:/flutter create delivery_marker_app/backend/src/app.ts) đã được gắn middleware `authenticateJwt`.
   - Controller [locations.controller.ts](file:///d:/flutter create delivery_marker_app/backend/src/controllers/locations.controller.ts) thực thi kiểm tra quan hệ ảnh với khách hàng/khu vực trên CSDL, bảo vệ dữ liệu theo phạm vi shipper phụ trách và chặn path traversal.
11. **[ĐÃ GIẢI QUYẾT - AUDIT-004A] Thiếu Database Transaction & Tệp ảnh mồ côi (Orphaned Files):**
   - Đã bọc `saveOrUpdateCustomerLocation` và `deleteLocation` trong các giao dịch PostgreSQL Client nghiêm ngặt (`BEGIN` ... `COMMIT` / `ROLLBACK`).
   - Tự động xóa tệp ảnh mới tạo trên đĩa (`fs.unlink`) nếu transaction CSDL thất bại, đồng thời bảo toàn ảnh cũ khi cập nhật hoặc xóa vị trí.
12. **[ĐÃ GIẢI QUYẾT - AUDIT-004A] Hiển thị ảnh an toàn có xác thực trên Admin Web & Mobile App:**
   - Admin Web sử dụng [AuthenticatedImage.tsx](file:///d:/flutter create delivery_marker_app/admin_web/src/components/AuthenticatedImage.tsx) tải ảnh bằng Blob URL kèm Bearer token và tự động giải phóng bộ nhớ (`URL.revokeObjectURL`).
   - Mobile App hỗ trợ `ApiService.getPhotoAuthInfo` truyền Authorization header khi tải ảnh trong [order_detail_view.dart](file:///d:/flutter create delivery_marker_app/mobile_app/lib/views/order_detail_view.dart).
   - [admin_web/nginx.conf](file:///d:/flutter create delivery_marker_app/admin_web/nginx.conf) được bổ sung proxy ngược chuyển tiếp `/api/` tới container `backend:3000`.
13. **[ĐÃ GIẢI QUYẾT - AUDIT-004B] Tương thích và bảo toàn dữ liệu SQLite v1 -> v2:**
   - Khảo sát chính xác schema v1 từ Git commit `96f1ff5` trong [offline_storage_service.dart](file:///d:/flutter create delivery_marker_app/mobile_app/lib/services/offline_storage_service.dart).
   - Thiết lập hàm di chuyển `migrateFromV1IfNeeded`: mở database v1 ở chế độ `readOnly: true` (không sửa đổi/không xóa v1), thực thi nạp dữ liệu vào v2 trong SQLite transaction nguyên tử, kiểm tra trùng lặp chống ghi đè/nhân bản (`isDuplicateSyncRecord`), bảo toàn mọi bản ghi offline với trạng thái `PENDING`.
   - Bổ sung 5 bài kiểm thử unit tests trong [sqlite_migration_test.dart](file:///d:/flutter create delivery_marker_app/mobile_app/test/sqlite_migration_test.dart) bao phủ chuyển đổi dữ liệu, chống duplicate, rollback khi crash và xử lý database không tồn tại.
14. **[ĐÃ GIẢI QUYẾT - AUDIT-004B] Rà soát và siết chặt chính sách Cache ảnh riêng tư:**
   - Cập nhật header phản hồi của route `GET /api/v1/photos/:filename` trong [locations.controller.ts](file:///d:/flutter create delivery_marker_app/backend/src/controllers/locations.controller.ts) thành `Cache-Control: private, no-store, no-cache, must-revalidate` và `Pragma: no-cache`.
   - Triệt tiêu nguy cơ lưu trữ ảnh cổng nhà/nhà riêng của khách hàng vào disk cache trên thiết bị dùng chung (shared shipper device), trong khi vẫn duy trì trọn vẹn xác thực JWT và kiểm tra quyền khu vực.
15. **[ĐÃ GIẢI QUYẾT - AUDIT-004C] Xác minh và hoàn thiện tính toàn vẹn của SQLite Migration:**
   - Phát hiện và khắc phục điểm nghẽn chống trùng lặp: loại bỏ việc chỉ so sánh `customerId + createdAt` (gây nguy cơ drop các bản ghi hợp lệ khác nhau của cùng khách hàng), thay thế bằng bảng định danh nguồn `_v1_migration_tracking(v1_source_id, v2_queue_id, migrated_at)`.
   - Bổ sung cơ chế đối soát và cập nhật nội dung cho `cached_orders` khi orderId đã tồn tại, ưu tiên bản ghi có thông tin vị trí đã lưu phong phú hơn.
   - Viết bộ 6 kịch bản kiểm thử tích hợp thực tế với SQLite độc lập trong [sqlite_migration_test.dart](file:///d:/flutter create delivery_marker_app/mobile_app/test/sqlite_migration_test.dart), xác minh thành công 100% các tình huống: cùng timestamp, tọa độ âm/dương, Unicode, pre-existing v2 data, rollback khi lỗi và crash sau commit trước khi lưu cờ.
16. **[ĐÃ GIẢI QUYẾT - AUDIT-004C.1] Xử lý cách ly bản ghi SQLite cũ không thể chuyển đổi:**
   - Khắc phục triệt để nguy cơ âm thầm bỏ qua bản ghi v1 lỗi và đánh dấu migration hoàn tất: bổ sung bảng `_v1_quarantine_records(id, source_table, v1_source_id, raw_data, error_reason, quarantined_at)` để cách ly an toàn dữ liệu hỏng/thiếu `customerId`/sai tọa độ.
   - Không tự ý gửi bản ghi lỗi lên backend và không tự bịa đặt giá trị `customerId`. Cung cấp các API truy xuất và quản lý cách ly: `getQuarantinedRecords()`, `getQuarantinedCount()`, `deleteQuarantinedRecord()`.
   - Phân biệt rõ ràng 3 trạng thái di chuyển: `MigrationStatus.success`, `MigrationStatus.hasQuarantinedRecords` (không đánh dấu `sqlite_v1_migrated = true`), và `MigrationStatus.failed`.
   - Bổ sung cảnh báo log rõ ràng và mở rộng trọn vẹn 11 kịch bản kiểm thử tích hợp trong [sqlite_migration_test.dart](file:///d:/flutter create delivery_marker_app/mobile_app/test/sqlite_migration_test.dart) bao phủ toàn bộ các trường hợp cách ly, lỗi ghi bảng cách ly, rerun idempotency và gián đoạn trước khi lưu cờ SharedPreferences.
17. **[ĐÃ GIẢI QUYẾT - AUDIT-004C.2] Hoàn thiện quy trình xử lý và đối soát bản ghi SQLite bị cách ly:**
   - Khắc phục rủi ro mất dữ liệu khi xóa bản ghi cách ly: chuyển từ xóa vật lý sang mô hình quản trị vòng đời và kiểm toán đối soát trên bảng `_v1_quarantine_records` bằng cách bổ sung các trường: `status` (`QUARANTINED`, `RESOLVED`, `DISCARDED`), `v2_queue_id`, `resolved_at`, `resolution_notes`, `resolved_data`.
   - Triển khai API `resolveQuarantinedRecord(...)`:
     - Xác thực dữ liệu đầu vào: `customerId` không được để trống, tọa độ phải nằm trong dải chuẩn WGS 84 (`[-90, 90]`, `[-180, 180]`), `gpsAccuracy >= 0`.
     - Đảm bảo tính nguyên tử: thực hiện trong SQLite transaction đơn nhất — tạo bản ghi trong `offline_sync_queue`, cập nhật `v2_queue_id` trong `_v1_migration_tracking`, và cập nhật trạng thái `status = 'RESOLVED'` kèm toàn bộ dữ liệu sửa chữa và ghi chú đối soát.
     - Chống trùng lặp tuyệt đối (Idempotency): gọi lại resolve nhiều lần trên cùng một bản ghi không sinh thêm queue item trùng lặp.
     - Tự động đồng bộ cờ migration: khi số lượng bản ghi pending (`status = 'QUARANTINED'`) về 0, hệ thống tự động cập nhật SharedPreferences sang `sqlite_v1_migrated = true` và `sqlite_v1_migration_status = 'COMPLETED'`.
   - Triển khai API `discardQuarantinedRecord(...)`: cho phép shipper/admin chủ động loại bỏ bản ghi thử nghiệm rác với lý do rõ ràng mà vẫn lưu vết vĩnh viễn (không xóa vật lý).
   - Khắc phục lỗ hổng "ghost tracking": `deleteQuarantinedRecord(...)` được nâng cấp để xóa luôn dòng tracking mồ côi (`v2_queue_id IS NULL`), ngăn ngừa việc bản ghi v1 bị khóa vĩnh viễn không thể nạp lại.
   - Bảo toàn 100% CSDL SQLite v1: `delivery_offline.db` luôn được mở ở chế độ `readOnly: true`, xác minh byte-level không suy suyển qua kiểm thử.
   - Bổ sung toàn diện 9 kịch bản kiểm thử tích hợp mới (nâng tổng số lên 20 kịch bản trong [sqlite_migration_test.dart](file:///d:/flutter create delivery_marker_app/mobile_app/test/sqlite_migration_test.dart)). Đạt 100% qua lệnh kiểm thử thực tế (24/24 Flutter tests pass, flutter analyze sạch 0 lỗi).
18. **[ĐÃ GIẢI QUYẾT - FIX-DOCKER-001] Khắc phục lỗi bcrypt native module và ổn định môi trường Backend Docker:**
   - Khắc phục nguyên nhân gốc: Thư mục `backend` thiếu file `.dockerignore`, khiến lệnh `COPY . .` trong `backend/Dockerfile` sao chép đè toàn bộ thư mục `node_modules` (chứa các binary PE / x64 của Windows) lên thư mục `/app/node_modules` trong container Linux Alpine, gây lỗi `Exec format error` khi nạp file `bcrypt_lib.node`.
   - Đã tạo [backend/.dockerignore](file:///d:/flutter create delivery_marker_app/backend/.dockerignore) và [.dockerignore](file:///d:/flutter create delivery_marker_app/.dockerignore) loại trừ nghiêm ngặt `node_modules`, `dist`, `.env`, `uploads`.
   - Cập nhật [backend/Dockerfile](file:///d:/flutter create delivery_marker_app/backend/Dockerfile): cài đặt `python3 make g++` trên Alpine musl, sử dụng `npm ci` theo đúng `package-lock.json`, biên dịch lại TypeScript và tự động chuẩn bị thư mục `/app/uploads`.
   - Build lại riêng image `fluttercreatedelivery_marker_app-backend:latest` và tái tạo riêng container `delivery_backend_api` với `docker compose up -d --no-deps backend` mà không ảnh hưởng tới PostgreSQL container hoặc volume dữ liệu.
   - Xác minh thực tế: Container `delivery_backend_api` hoạt động liên tục ổn định (Up, không còn restart vòng lặp), `require('bcrypt')` hash/compare pass 100%, endpoint Swagger `/api/docs/` trả mã 200, toàn bộ 24/24 unit test và `npx tsc --noEmit` đạt 100%.

19. **[ĐÃ GIẢI QUYẾT - FIX-SEED-001] Sửa lỗi UUID cú pháp trong seed demo và khôi phục tài khoản đăng nhập:**
   - Phát hiện nguyên nhân gốc khiến database PostgreSQL chỉ có 2 roles mà 0 users: Trong [init-db/01-init-db.sql](file:///d:/flutter create delivery_marker_app/init-db/01-init-db.sql), các ID cứng dùng ký tự phi-hexadecimal làm tiền tố gợi nhớ (`s` cho shipper, `l` cho location, `o` cho order, ví dụ: `'s0000000-0000-0000-0000-000000000001'`). Kiểu dữ liệu PostgreSQL `UUID` chỉ chấp nhận các ký tự hex `[0-9a-fA-F]`, dẫn tới lỗi `invalid input syntax for type uuid` tại câu lệnh `INSERT INTO users`, làm toàn bộ transaction khởi tạo sau `roles` bị hủy bỏ.
   - Đã sửa [init-db/01-init-db.sql](file:///d:/flutter create delivery_marker_app/init-db/01-init-db.sql) chuẩn hóa các UUID về chuẩn hex (`d0000000-...` cho shipper, `e0000000-...` cho saved_locations, `f0000000-...` cho orders). Đồng bộ mock UUID trong [backend/test/auth.spec.ts](file:///d:/flutter create delivery_marker_app/backend/test/auth.spec.ts).
   - Tạo script riêng [init-db/03-seed-demo-data.sql](file:///d:/flutter create delivery_marker_app/init-db/03-seed-demo-data.sql) hoàn toàn độc lập, an toàn và lũy kế (idempotent, `ON CONFLICT DO NOTHING`), tra cứu khóa ngoại động theo mã nghiệp vụ (`phone_number`, `code`, `customer_code`), bảo toàn dữ liệu người dùng hiện có, không ghi đè mật khẩu đã đổi.
   - Sử dụng bcrypt hash hợp lệ (`$2b$10$gtZVjpsj7RCMMyj2TbODL.RvTuTF/cO0BCsFhSLiCZkt/jCJdqMC.`) cho mật khẩu `password123` cho các tài khoản: Admin (`0900000001`), Shipper A (`0901111111`), Shipper B (`0902222222`).
   - Đã xác minh trên database thử nghiệm riêng biệt (`test_isolated_seed_db`): Chạy lần 1 thành công 100%, chạy lần 2 không sinh bản ghi trùng (`INSERT 0 0`), bcrypt so khớp chính xác mật khẩu demo `password123`, 24/24 backend test pass. CSDL thật (`delivery_db`) được giữ nguyên vẹn tuyệt đối.

20. **[ĐÃ GIẢI QUYẾT - FEATURE-MAP-001] Triển khai giao diện bản đồ giao hàng làm màn hình chính:**
   - Đã chuyển đổi màn hình chính sau đăng nhập từ danh sách đơn truyền thống thành trải nghiệm Map-First thông minh [delivery_map_view.dart](file:///d:/flutter create delivery_marker_app/mobile_app/lib/views/delivery_map_view.dart).
   - Sử dụng `flutter_map` với lớp tile OpenStreetMap / CARTO mượt mà, không phát sinh chi phí hoặc yêu cầu API key trả phí.
   - Phân biệt rõ ràng marker vị trí GPS của Shipper (chấm tròn xanh viền trắng với vòng tỏa sáng) và marker điểm giao (ghim đỏ mang số thứ tự `#1, #2...`, chuyển xanh lá khi được chọn).
   - Bottom sheet danh sách đơn (`DraggableScrollableSheet`) kéo vuốt linh hoạt; tích hợp thanh tiêu đề "Chạm xem" cho phép mở rộng / thu gọn tức thì chỉ với một chạm. Trạng thái thu gọn hiển thị tổng số đơn trong ca và số lượng đơn chưa có tọa độ.
   - Thẻ chi tiết điểm giao trên bản đồ (Selected Order Card) xuất hiện ngay khi chạm marker hoặc chạm đơn từ bottom sheet: hiển thị tên khách, địa chỉ, số điện thoại, ghi chú giao hàng, sai số GPS và ảnh cổng/mặt tiền nhà có gắn header Bearer token an toàn.
   - Tối ưu trải nghiệm cho tài xế lớn tuổi: Nút lớn toàn chiều ngang `DẪN ĐƯỜNG ĐẾN CỔNG NHÀ` (chiều cao 48px), 2 nút phụ `GỌI KHÁCH` và `CHI TIẾT ĐƠN` chia đôi 50/50, khoảng cách chạm thông thoáng, chữ 15–18sp, 100% tiếng Việt, tương phản cao.
   - Xử lý 3 trạng thái GPS: GPS thiết bị đang tắt (`isLocationServiceEnabled`), quyền vị trí bị từ chối (`requestPermission`), và quyền bị từ chối vĩnh viễn (`openAppSettings`).
   - Tái sử dụng liền mạch các luồng hiện có: lưu tọa độ/chụp ảnh qua [save_location_view.dart](file:///d:/flutter create delivery_marker_app/mobile_app/lib/views/save_location_view.dart), xem chi tiết qua [order_detail_view.dart](file:///d:/flutter create delivery_marker_app/mobile_app/lib/views/order_detail_view.dart), chuyển đổi giao diện danh sách qua [order_list_view.dart](file:///d:/flutter create delivery_marker_app/mobile_app/lib/views/order_list_view.dart).
   - Kiểm thử toàn diện: 26/26 automated tests pass (20 SQLite migration + 6 Widget/App tests), `flutter analyze` sạch 0 cảnh báo.
   - Đã build `flutter build apk --debug`, nạp và kiểm thử thành công trực tiếp trên thiết bị vật lý Android `AE9260424A4001007` (Android 14/15, Impeller).

21. **[ĐÃ GIẢI QUYẾT - FEATURE-ORDER-ENTRY-001] Nhập điểm giao mới bằng số điện thoại khách hàng trên bản đồ:**
   - **Backend Endpoint:** Thiết lập route an toàn `POST /api/v1/orders/my-shift` trong [orders.controller.ts](file:///d:/flutter create delivery_marker_app/backend/src/controllers/orders.controller.ts).
     - Xác thực JWT (`authenticateJwt`), kiểm tra vai trò `SHIPPER` / `ADMIN`.
     - Phân quyền khu vực (Scope check): kiểm tra khách hàng có thuộc `assignedAreaIds` của shipper hay không; trả về 403 Forbidden với thông báo rõ ràng nếu trái tuyến.
     - Chống tạo đơn trùng (Idempotency & Business Deduplication): kiểm tra xem khách hàng đã có đơn `PENDING` trong ca của shipper hay chưa; nếu đã có thì trả về mã đơn hiện có (`isExisting: true`) và mã HTTP 200. Hỗ trợ trường `idempotencyKey` trong body request để chống double-click.
     - Sinh mã đơn chuẩn nhất quán: quy tắc `ORD-YYYYMMDD-XXXXX` tăng dần theo ngày trong database transaction nguyên tử (`pool.connect()`, `BEGIN`, `COMMIT`, `ROLLBACK`).
     - Ghi nhận `audit_logs` đầy đủ với hành động `ORDER_CREATED_BY_SHIPPER`.
   - **Chuẩn hóa Số Điện Thoại Việt Nam:**
     - Loại bỏ toàn bộ khoảng trắng, dấu ngoặc, dấu chấm, dấu gạch ngang (`.replace(/\D/g, '')`).
     - Hỗ trợ định dạng quốc tế `+84` / `84` thành `0...`.
     - Hỗ trợ người dùng nhập 9 chữ số thiếu đầu 0 (tự động bổ sung `0` đầu số: `988000001` -> `0988000001`).
   - **Giao diện Flutter Map-First ([delivery_map_view.dart](file:///d:/flutter create delivery_marker_app/mobile_app/lib/views/delivery_map_view.dart)):**
     - Thanh tìm kiếm SĐT nổi bật tích hợp ngay trong thẻ đầu trang, đi kèm nút bấm lớn `TÌM KHÁCH` (chiều cao 48px, icon kính lúp, trạng thái loading xoay tròn).
     - Khách hàng đã có đơn trong ca: Tự động di chuyển camera đến vị trí đơn, chọn đơn và hiển thị thẻ `Selected Order Card` cùng thông báo `Khách hàng đã có Đơn ... trong ca!`.
     - Khách hàng tồn tại & ĐÃ CÓ vị trí: Hiển thị marker tím nổi bật, di chuyển bản đồ đến nhà khách và mở thẻ thông tin chi tiết với đầy đủ ảnh, ghi chú, nút `THÊM ĐIỂM GIAO VÀO CA`.
     - Khách hàng tồn tại nhưng CHƯA CÓ vị trí: Không ghim tọa độ giả; hiển thị trạng thái "Chưa có vị trí nhà"; cho phép bấm `THÊM ĐIỂM GIAO VÀO CA` và hỗ trợ nút `XÁC ĐỊNH VỊ TRÍ` mở luồng [save_location_view.dart](file:///d:/flutter create delivery_marker_app/mobile_app/lib/views/save_location_view.dart) để chụp ảnh, lấy GPS, ghim thủ công.
     - Khách hàng không tồn tại (404): Mở hộp thoại thân thiện giải thích rõ ràng tài khoản chưa có trong hệ thống và hướng dẫn liên hệ Admin/Điều phối viên (tuân thủ nguyên tắc không cho shipper tự ý tạo khách hàng trái schema).
     - Khách hàng ngoài khu vực (403): Hiển thị SnackBar đỏ cảnh báo rõ "Khách hàng này thuộc khu vực bạn không được phân công phụ trách".
     - Tối ưu Scaffold: bổ sung `resizeToAvoidBottomInset: false` giúp giữ vững 100% bố cục bản đồ, camera và bottom sheet khi mở bàn phím ảo.
   - **Kiểm thử nghiệm thu:**
     - Backend Unit Tests: 50/50 tests pass ([orders.spec.ts](file:///d:/flutter create delivery_marker_app/backend/test/orders.spec.ts), [location.spec.ts](file:///d:/flutter create delivery_marker_app/backend/test/location.spec.ts), [auth.spec.ts](file:///d:/flutter create delivery_marker_app/backend/test/auth.spec.ts)).
     - TypeScript compilation: `npx tsc --noEmit` đạt 0 lỗi.
     - Flutter Tests: 29/29 tests pass ([widget_test.dart](file:///d:/flutter create delivery_marker_app/mobile_app/test/widget_test.dart)).
     - Flutter Analyze: `flutter analyze` 0 issues.
     - Physical Device Testing: Cài đặt và nghiệm thu toàn diện trên điện thoại Android thật `AE9260424A4001007`.


22. **[ĐÃ GIẢI QUYẾT - BUG-MAP-002] Khắc phục bản đồ nền trắng trong Bản đồ Ca Làm (ShiftMapView):**
    - **Nguyên nhân gốc đã xác minh:** ShiftMapView và CrosshairLocationPickerView trước đó sử dụng tile OpenStreetMap (https://tile.openstreetmap.org). Tại mạng Việt Nam, kết nối SSL/TLS tới máy chủ OSM bị ngắt giữa chừng (Recv failure: Connection was reset / schannel: failed to receive handshake), dẫn đến TileLayer không thể tải tile ảnh và làm bản đồ xuất hiện nền xám/trắng xóa dù các marker vẫn hiển thị.
    - **Giải pháp xử lý:**
      - Chuyển TileLayer sang nguồn tile Google Maps đường phố chuẩn của dự án (`https://mt1.google.com/vt/lyrs=m&x={x}&y={y}&z={z}`), đồng thời cấu hình `fallbackUrl` trỏ sang CartoDB Voyager (`https://a.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png`).
      - Chuẩn hóa `userAgentPackageName` thành `com.example.delivery_marker_mobile` đồng bộ với [pubspec.yaml](file:///d:/flutter create delivery_marker_app/mobile_app/pubspec.yaml) và các view khác.
      - Thêm nút đổi loại bản đồ (`Icons.layers_rounded`) ở góc phải trên của [ShiftMapView](file:///d:/flutter create delivery_marker_app/mobile_app/lib/views/shift_map_view.dart) (Đường phố / Ảnh vệ tinh / CartoDB).
      - Bọc FlutterMap bên trong `Positioned.fill` để cố định layout constraints trong Stack và bọc `_fitMapBounds()` trong `WidgetsBinding.instance.addPostFrameCallback`.
      - Bổ sung banner cảnh báo trực quan khi thiết bị mất mạng (`_hasTileError`), giúp người dùng nhận diện ngay tình trạng kết nối.
      - Đồng bộ cấu hình tile này sang CrosshairLocationPickerView ([crosshair_location_picker_view.dart](file:///d:/flutter create delivery_marker_app/mobile_app/lib/views/crosshair_location_picker_view.dart)).
    - **Kiểm thử nghiệm thu:** Đạt 36/36 Flutter tests, phân tích tĩnh 0 errors/warnings, build APK Debug thành công.

23. **[ĐÃ HOÀN TẤT - UI-REDESIGN-001] Hiện đại hóa toàn diện giao diện Mobile App theo Design System mới:**
    - **Triết lý thiết kế:** Loại bỏ cảm giác component mặc định của AI, đưa về phong cách chuyên nghiệp (tương tự GrabDriver/Be/Ahamove) phù hợp tài xế shipper sử dụng ngoài trời dưới ánh sáng mạnh.
    - **Bảng màu & Design System:**
      - Nền ứng dụng `#F8FAFC`, Surface `#FFFFFF`, Viền mỏng 1px `#E2E8F0`, Text chính `#0F172A`, Text phụ `#64748B`.
      - Primary màu Navy `#0F172A` / Xanh hiện đại `#2563EB`.
      - 3 Trạng thái vị trí chuẩn hóa: `VERIFIED` xanh lá `#10B981`, `TEMPORARY` cam `#F59E0B`, `NO_LOCATION` xám `#64748B`.
      - Badge trạng thái ca `PREPARING` nền `#FEF3C7` chữ `#D97706`; `COMPLETED` nền `#DCFCE7` chữ `#15803D`.
    - **Danh Sách Ca Làm Việc ([shift_list_view.dart](file:///d:/flutter create delivery_marker_app/mobile_app/lib/views/shift_list_view.dart)):**
      - AppBar tối giản, tiêu đề gọn `Ca làm việc` màu `#0F172A`.
      - Loại bỏ banner hướng dẫn dài, thay bằng thanh tóm tắt thông tin nhanh (Ví dụ: `Hôm nay, 23/10 · 5 ca làm việc`).
      - Nút `+ Tạo ca làm mới` thiết kế chuẩn 48px, bo góc 12px, nền Navy `#0F172A`.
      - Card ca làm việc: Toàn bộ card là vùng bấm được (`InkWell`), có icon Chevron bên phải; tích hợp 3 mini status chip (chấm tròn màu + số lượng) trực quan, loại bỏ viền cam dày và shadow nặng.
    - **Chuẩn Bị Ca ([shift_preparation_view.dart](file:///d:/flutter create delivery_marker_app/mobile_app/lib/views/shift_preparation_view.dart)):**
      - Header gọn gàng hiển thị mã ca và ngày làm việc.
      - Cụm nhập SĐT bo góc 10px kèm nút `Thêm` vững chắc, chống tràn bàn phím.
      - Bộ lọc Filter Chips phẳng, hiển thị trực quan số lượng từng nhóm: `Tất cả`, `Đã xác minh`, `Vị trí tạm`, `Chưa có`.
      - Thẻ điểm giao nền trắng phẳng, tên khách nổi bật, phân cấp rõ ràng SĐT và địa chỉ; nút ghim/sửa vị trí Outlined hiện đại.
      - Nút `XEM BẢN ĐỒ CA LÀM NÀY` cố định ở chân trang (cao 48px, màu `#2563EB`, bo góc 12px).
    - **Bản Đồ Ca Làm ([shift_map_view.dart](file:///d:/flutter create delivery_marker_app/mobile_app/lib/views/shift_map_view.dart)):**
      - Header nổi bo góc 14px nền trắng mờ 96% chứa nút Back, mã ca, số điểm ghim và nút Refresh; loại bỏ panel chiếm 1/4 màn hình.
      - Cột nút công cụ chuẩn 44×44px (GPS, Đổi Layer Bản Đồ, Fit Bounds) nền trắng mờ viền xám nhạt.
      - Nút hành động nổi bật `CHỌN VỊ TRÍ` ở góc dưới bên phải (cao 52px, bo tròn 26px, icon `add_location_alt_rounded`, nền Navy `#0F172A`).
      - Thẻ chi tiết khách hàng khi chạm marker bo góc 16px, shadow mờ nhẹ, hiển thị đầy đủ tên, SĐT, địa chỉ, khoảng cách, ghi chú và 3 nút thao tác (Gọi điện, Chỉ đường, Tâm ngắm).
      - Giải quyết triệt để lỗi Stack constraints co cụm bằng `StackFit.expand` và `Positioned(top: 0, left: 0, right: 0)`.
    - **Bộ Chọn Vị Trí Bằng Tâm Ngắm ([crosshair_location_picker_view.dart](file:///d:/flutter create delivery_marker_app/mobile_app/lib/views/crosshair_location_picker_view.dart)):**
      - Banner hướng dẫn kéo bản đồ bo góc 10px viền mỏng.
      - Tâm ngắm cố định thiết kế hiện đại, vòng tròn tỏa sáng và ghim định vị chuẩn xác.
      - Cột nút GPS và Zoom chuẩn hóa 44×44px.
      - Card tọa độ chân trang hiển thị Live kinh độ/vĩ độ, nút `Hủy` và `Xác nhận vị trí` chuẩn touch target.
      - Modal xác nhận phân định rõ ràng 2 luồng: `LƯU VỊ TRÍ TẠM` (nền cam `#F59E0B`) và `XÁC MINH CỔNG NHÀ` (nền xanh `#10B981`).
    - **Kiểm thử nghiệm thu:**
      - Phân tích tĩnh: `flutter analyze` đạt **0 issues**.
      - Kiểm thử tự động: `flutter test` đạt **36/36 tests passed (100%)**.
      - Biên dịch APK Debug: `flutter build apk --debug` thành công.
      - Kiểm thử thực tế trên thiết bị thật: Đã cài đặt và kiểm thử trực tiếp trên điện thoại Android `AE9260424A4001007`, chụp ảnh đối soát 9 màn hình thành công.

24. **[ĐÃ HOÀN TẤT - APP-AUDIT-AND-FIX-002] Khảo sát toàn bộ ứng dụng, sửa logic thêm khách hàng mới, tìm kiếm địa chỉ trong bộ chọn tâm ngắm, và loại bỏ marker demo khỏi luồng thật:**
    - **Vấn đề 1 — Tạo nhanh khách hàng chưa có hồ sơ:**
      - *Nguyên nhân:* Trước đây khi shipper tra cứu số điện thoại không tồn tại, [shift_preparation_view.dart](file:///d:/flutter create delivery_marker_app/mobile_app/lib/views/shift_preparation_view.dart) chỉ hiện dialog "Không tìm thấy hồ sơ" và nút "ĐÓNG", không cho phép shipper tạo khách tại chỗ.
      - *Giải pháp:* Thiết kế Bottom Sheet "Chưa có hồ sơ khách hàng" trên [shift_preparation_view.dart](file:///d:/flutter create delivery_marker_app/mobile_app/lib/views/shift_preparation_view.dart) điền sẵn số điện thoại, cho phép nhập Tên, Địa chỉ, Ghi chú.
      - *Backend:* Nâng cấp `addPointToShift` trong [shifts.controller.ts](file:///d:/flutter create delivery_marker_app/backend/src/controllers/shifts.controller.ts) hỗ trợ `createIfNotFound: true`. Tự động tạo hồ sơ khách hàng trong bảng `customers` (ràng buộc khu vực của shipper, xử lý race condition `ON CONFLICT (phone_number)`), và tự động thêm điểm giao vào ca làm với trạng thái `NO_LOCATION`, cập nhật UI & Summary tức thì.
    - **Vấn đề 2 — Tìm kiếm địa chỉ bằng Geocoding trong bộ chọn tâm ngắm:**
      - *Nguyên nhân:* [crosshair_location_picker_view.dart](file:///d:/flutter create delivery_marker_app/mobile_app/lib/views/crosshair_location_picker_view.dart) thiếu ô tìm kiếm địa chỉ nhanh tương tự Google Maps để định hướng trước khi chỉnh tâm ngắm.
      - *Backend:* Xây dựng controller [geocoding.controller.ts](file:///d:/flutter create delivery_marker_app/backend/src/controllers/geocoding.controller.ts) phục vụ endpoint `GET /api/v1/geocoding/search?q=...`. Kết hợp tìm kiếm trong CSDL cục bộ bằng extension PostgreSQL `unaccent` (tìm kiếm địa chỉ tiếng Việt không dấu/có dấu trên `customers`, `saved_locations`, `shift_delivery_points`) và dịch vụ Geocoding OpenStreetMap Nominatim/Photon.
      - *Flutter:* Tích hợp thanh tìm kiếm Google Maps style ở trên cùng của [crosshair_location_picker_view.dart](file:///d:/flutter create delivery_marker_app/mobile_app/lib/views/crosshair_location_picker_view.dart). Tự động debounce 350ms, dropdown hiển thị kết quả gợi ý, khi bấm chọn thì bản đồ di chuyển mượt mà tới tọa độ, tâm ngắm giữ cố định ở giữa, shipper tiếp tục kéo tinh chỉnh cổng nhà.
    - **Vấn đề 3 — Bản đồ đơn hàng và marker demo:**
      - *Nguyên nhân:* Nút bản đồ trên AppBar của [shift_list_view.dart](file:///d:/flutter create delivery_marker_app/mobile_app/lib/views/shift_list_view.dart) trước đây điều hướng sang [delivery_map_view.dart](file:///d:/flutter create delivery_marker_app/mobile_app/lib/views/delivery_map_view.dart), một view cũ gọi `GET /api/v1/orders/my-shift` hiển thị 3 đơn hàng demo seed sẵn của Anh Hoàng (Long Thạnh Mỹ), tách rời khỏi ca làm việc thật.
      - *Giải pháp:* Cập nhật nút bản đồ trên AppBar của [shift_list_view.dart](file:///d:/flutter create delivery_marker_app/mobile_app/lib/views/shift_list_view.dart) để mở trực tiếp [shift_map_view.dart](file:///d:/flutter create delivery_marker_app/mobile_app/lib/views/shift_map_view.dart) của ca làm việc hiện tại đang chuẩn bị/đang chạy. Triệt tiêu hoàn toàn dữ liệu demo trong luồng vận hành thực tế của shipper.
    - **Kết quả kiểm thử:**
      - Backend: 66/66 test passed (`npm test` in [backend/test/shifts.spec.ts](file:///d:/flutter create delivery_marker_app/backend/test/shifts.spec.ts)).
      - Flutter: `flutter analyze` 0 issues, `flutter test` 20/20 passed, `flutter build apk --debug` thành công.
      - Thiết bị thật: Kiểm thử và chụp ảnh màn hình xác minh trực tiếp trên điện thoại Android `AE9260424A4001007`.

25. **[ĐÃ HOÀN TẤT - FINAL-VERIFICATION-003] Hoàn tất tìm kiếm địa chỉ và loại bỏ hoàn toàn đường dẫn bản đồ demo còn sót:**
    - **1. Phân định rõ ràng hai cơ chế tìm kiếm địa chỉ:**
      - *Tìm kiếm CSDL nội bộ (Local Database):* Sử dụng extension PostgreSQL `unaccent` để tìm kiếm địa chỉ tiếng Việt không dấu/có dấu trên các bảng `customers`, `saved_locations`, và `shift_delivery_points`. Thích hợp cho khách hàng/điểm giao đã có trong hệ thống nội bộ của công ty.
      - *Tìm kiếm địa chỉ công cộng bên ngoài (External Geocoding):* Tích hợp dịch vụ Geocoding dựa trên OpenStreetMap Photon (`photon.komoot.io`) chuyên dụng cho search-as-you-type autocomplete, miễn phí, hỗ trợ tiếng Việt có dấu/không dấu, phản hồi < 500ms, không bị lỗi chặn kết nối/TLS như Nominatim CDN.
      - *Hỗ trợ cấu hình nâng cao:* Adapter [geocoding.controller.ts](file:///d:/flutter create delivery_marker_app/backend/src/controllers/geocoding.controller.ts) tự động nhận diện biến môi trường `GEOCODING_API_KEY` và `GEOCODING_PROVIDER` (Google Maps Geocoding API hoặc Goong Maps). Nếu có API key sẽ ưu tiên gọi provider thương mại; nếu không có sẽ tự động fallback sang OSM Photon và CSDL PostgreSQL nội bộ.
      - *Kiểm thử thực tế API:*
        - Truy vấn nội bộ `q=Long Thanh`: Trả về 5 kết quả từ `LOCAL_DATABASE` và kết quả từ `OSM_PHOTON`.
        - Truy vấn công cộng ngoài CSDL `q=Cho Ben Thanh`: Trả về kết quả chính xác từ `OSM_PHOTON` (`Chợ Bến Thành, Công trường Quách Thị Trang, Bến Thành, Thành phố Hồ Chí Minh`, Lat: `10.7725301`, Lon: `106.6980365`).
    - **2. Rà soát và cô lập toàn bộ đường dẫn đến bản đồ đơn hàng demo cũ (`DeliveryMapView`):**
      - Đã kiểm tra toàn bộ cây điều hướng của ứng dụng Flutter: `AuthSplashScreen` -> `ShiftListView` -> `ShiftPreparationView` -> `ShiftMapView` -> `CrosshairLocationPickerView`.
      - Khẳng định 100%: Không còn bất kỳ nút bấm, menu hay route nào trong luồng vận hành thực của shipper có thể dẫn sang `DeliveryMapView` hay `OrderListView`.
      - Icon bản đồ trên AppBar của [shift_list_view.dart](file:///d:/flutter create delivery_marker_app/mobile_app/lib/views/shift_list_view.dart) và nút chân trang của [shift_preparation_view.dart](file:///d:/flutter create delivery_marker_app/mobile_app/lib/views/shift_preparation_view.dart) đều trỏ trực tiếp đến [shift_map_view.dart](file:///d:/flutter create delivery_marker_app/mobile_app/lib/views/shift_map_view.dart) của ca làm việc thực tế (`widget.shiftId`).
      - Bản đồ ca làm việc [shift_map_view.dart](file:///d:/flutter create delivery_marker_app/mobile_app/lib/views/shift_map_view.dart) chỉ hiển thị marker khi `hasValidCoordinates == true`. Khách chưa có tọa độ (`NO_LOCATION`) tuyệt đối không bị gán tọa độ giả hay hiển thị marker bừa bãi trên bản đồ; thay vào đó hiển thị badge "Chưa có vị trí" trong danh sách kèm nút "Định vị ngay".
      - Không xóa `DeliveryMapView`, [orders.controller.ts](file:///d:/flutter create delivery_marker_app/backend/src/controllers/orders.controller.ts), bảng `orders` để bảo toàn kiến trúc và dữ liệu lịch sử theo đúng quy tắc bảo vệ dự án.
    - **3. Rà soát dữ liệu kiểm thử trong CSDL PostgreSQL:**
      - Đã kiểm kê và phân loại toàn bộ dữ liệu:
        - Khách hàng test mới tạo: `0977889911` (UUID: `49235e23-dd86-4681-8133-8be7ad28c9c8`, tên "Khách hàng Anh Tuấn Test").
        - Các ca làm test mới tạo ngày 2026-10-23: `SHF-20261023-001` đến `SHF-20261023-008`.
        - Không có đơn hàng test nào trong bảng `orders` (chỉ có 5 đơn seed ban đầu `ORD-20261004-01..05`).
      - Tuân thủ nguyên tắc AGENTS.md: Không tự ý xóa bất kỳ bản ghi nào, lập danh sách báo cáo đầy đủ cho người vận hành xử lý.
    - **4. Kiểm thử hồi quy toàn diện:**
      - Backend: `npm test` đạt **66/66 test passed (100%)**, `npm run build` biên dịch sạch sẽ không lỗi TypeScript.
      - Flutter: `flutter analyze` đạt **0 issues found**, `flutter test` chạy toàn bộ test suite đạt **40/40 test passed (100%)**, `flutter build apk --debug` thành công.
      - Thiết bị Android thật: Kiểm chứng trực tiếp trên điện thoại Android `AE9260424A4001007` (API 33).

26. **[ĐÃ HOÀN TẤT - MAP-FIRST-ARCHITECTURE-005] Tái cấu trúc trải nghiệm ứng dụng theo mô hình Bản đồ làm trung tâm (Map-First) & Chuẩn hóa giao diện hiện đại (chống AI slop):**
    - **1. Kiến trúc điều hướng mới (Map-First & HomeShellView):**
      - Sau khi đăng nhập thành công (`LoginView`), người dùng được chuyển thẳng vào màn hình làm việc chính [home_shell_view.dart](file:///d:/flutter create delivery_marker_app/mobile_app/lib/views/home_shell_view.dart) với Bản đồ [main_map_view.dart](file:///d:/flutter create delivery_marker_app/mobile_app/lib/views/main_map_view.dart) là tab mặc định đầu tiên.
      - Hệ thống gồm 3 tab độc lập duy trì trạng thái bằng `IndexedStack`:
        1. **[Bản đồ]:** Bản đồ toàn màn hình (full-bleed) hiển thị điểm giao theo ca.
        2. **[Danh bạ]:** Danh bạ vị trí độc lập [customer_directory_view.dart](file:///d:/flutter create delivery_marker_app/mobile_app/lib/views/customer_directory_view.dart) quản lý toàn bộ khách hàng và vị trí.
        3. **[Ca làm việc]:** Quản lý danh sách ca, tạo ca mới, chuẩn bị ca [shift_list_view.dart](file:///d:/flutter create delivery_marker_app/mobile_app/lib/views/shift_list_view.dart).
      - Bottom Navigation Bar hiện đại: Tone màu Slate xám lạnh và xanh Indigo (`#2563EB`), bo góc mềm mại, độ cao chuẩn 72px tránh triệt để lỗi tràn pixel.
    - **2. Bộ chọn ca trực tiếp trên Bản đồ chính (Top Floating Bar):**
      - Thiết kế thanh nổi tinh tế trên nền bản đồ: Hiển thị mã ca hiện tại, số điểm đã ghim / chưa vị trí kèm nút `[+]` tạo ca/thêm điểm nhanh.
      - Chạm vào mở Bottom Sheet danh sách các ca với badge trạng thái (`PREPARING`, `IN_PROGRESS`, `COMPLETED`), số lượng điểm phân loại vị trí.
      - Cơ chế chọn ca thông minh: Ưu tiên ca lưu gần nhất -> ca `IN_PROGRESS` -> ca `PREPARING` mới nhất -> bản đồ trống thông báo gọn.
      - Chống race-condition khi đổi ca: Biến đếm thứ tự request `_loadSequence` loại bỏ các phản hồi cũ trả về trễ, lập tức dọn sạch marker của ca cũ và nạp dữ liệu ca mới.
    - **3. Marker hiển thị ảnh thực tế và chi tiết vị trí:**
      - Chạm vào marker nhà trên bản đồ mở thẻ chi tiết với ảnh thực tế vị trí cổng nhà nổi bật (cao 160px, bo góc 12px, `BoxFit.cover`).
      - Hỗ trợ xem ảnh lớn toàn màn hình kèm zoom pinch-to-zoom (`0.8x` đến `5.0x`) qua widget [fullscreen_image_viewer.dart](file:///d:/flutter create delivery_marker_app/mobile_app/lib/widgets/fullscreen_image_viewer.dart).
      - Xử lý cache-busting triệt để: Sử dụng timestamp query param `?v=...` trên endpoint tải ảnh giúp giao diện cập nhật ngay lập tức sau khi chụp/thay ảnh mới.
      - Placeholder sạch sẽ khi chưa có ảnh kèm nút "Chụp / Thêm ảnh ngay". Box ghi chú nhận diện nổi bật dễ đọc cho tài xế. Hàng nút nhanh: `[Gọi điện]`, `[Chỉ đường]`, `[Sửa vị trí / Ảnh]`.
    - **4. Danh bạ vị trí độc lập (Full CRUD):**
      - Tìm kiếm tức thì debounce theo SĐT, tên, địa chỉ, ghi chú.
      - Bộ lọc Filter Chips: `Tất cả`, `Đã xác minh (🟢)`, `Vị trí tạm (🟠)`, `Chưa có vị trí (⚪)`, `Có ảnh`, `Chưa có ảnh`.
      - Màn hình [customer_detail_edit_view.dart](file:///d:/flutter create delivery_marker_app/mobile_app/lib/views/customer_directory_view.dart): Cho phép sửa toàn diện Tên, SĐT (chống trùng lặp), Địa chỉ, Ghi chú, ghim lại vị trí qua bộ chọn tâm ngắm, chụp/chọn ảnh mới từ Camera/Thư viện hoặc xóa ảnh.
      - Nút thao tác nhanh "Thêm vào ca đang chọn" đưa ngay khách vào ca làm việc hiện tại trên bản đồ.
    - **5. Backend & Database Migration:**
      - Thêm migration [init-db/05-add-customers-updated-at.sql](file:///d:/flutter create delivery_marker_app/init-db/05-add-customers-updated-at.sql) bổ sung an toàn cột `updated_at` cho bảng `customers`.
      - Thêm controller [customers.controller.ts](file:///d:/flutter create delivery_marker_app/backend/src/controllers/customers.controller.ts) với đầy đủ CRUD, chuẩn hóa SĐT, kiểm tra scope khu vực `allowed_districts`, hỗ trợ lưu vị trí và upload ảnh base64.
      - Nâng cấp [locations.controller.ts](file:///d:/flutter create delivery_marker_app/backend/src/controllers/locations.controller.ts) hỗ trợ `deletePhoto: true` và chính sách phân quyền truy cập ảnh an toàn.
    - **6. Kiểm thử kỹ thuật & Xác minh thiết bị:**
      - Backend: 73/73 test passed (100%) qua 5 test suites (`location.spec.ts`, `orders.spec.ts`, `shifts.spec.ts`, `customers.spec.ts`).
      - Flutter: `flutter analyze` 0 issues found, `flutter test` 51/51 unit/widget tests passed (100%), `flutter build apk --debug` thành công.
      - Thiết bị thật: Cài đặt và xác minh trên điện thoại Android `AE9260424A4001007` (Android 13) với đầy đủ các luồng hiển thị bản đồ, chọn ca, thẻ marker kèm ảnh thực tế, và Danh bạ độc lập.

27. **[ĐÃ HOÀN TẤT - MAP-PIN-FLOW-SIMPLIFICATION-006] Đơn giản hóa quy trình ghim vị trí trực tiếp trên Bản đồ chính:**
    - **1. Thay thế luồng cũ 8 bước rườm rà bằng luồng 3 bước trực tiếp:**
      - *Luồng cũ:* Bấm Chọn Vị Trí -> Chọn SĐT -> Chuyển sang màn hình riêng `CrosshairLocationPickerView` -> Kéo tâm ngắm -> Bấm Xác nhận -> Hộp thoại 2 lựa chọn ("Lưu tạm trước khi giao" vs "Xác minh cổng nhà tại chỗ") -> Nếu chọn xác minh lại mở màn hình `SaveLocationView` để chụp ảnh, nhập ghi chú -> Xác nhận lần 2.
      - *Luồng mới (3 bước):*
        1. **Bước 1 — Chọn khách hàng:** Bấm `CHỌN VỊ TRÍ` trên bản đồ chính -> Mở compact Bottom Sheet hiển thị danh sách khách hàng thuộc ca đang chọn, có thanh tìm kiếm nhanh (tên, SĐT, địa chỉ), huy hiệu trạng thái vị trí (`Đã xác minh`, `Vị trí tạm`, `Chưa có vị trí`). Chọn khách sẽ lập tức chuyển bản đồ chính sang Chế độ Ghim.
        2. **Bước 2 — Ghim vị trí ngay trên Bản đồ chính (`MainMapView`):** Bản đồ giữ nguyên chế độ hiển thị toàn màn hình, không mở màn hình mới; tâm ngắm cố định ngay chính giữa bản đồ (`_buildCrosshairReticle()`); kéo bản đồ bên dưới cập nhật tọa độ thời gian thực (live coordinates); thanh tiêu đề nổi phía trên hiển thị tên khách, SĐT và tọa độ live; nút GPS tiện lợi đưa tâm ngắm về tọa độ thực tế của shipper; hai nút rõ ràng `[Hủy]` và `[XÁC NHẬN VỊ TRÍ]`.
        3. **Bước 3 — Một lần xác nhận duy nhất:** Bấm `XÁC NHẬN VỊ TRÍ` gửi API `PUT /api/v1/shifts/:id/points/:pointId/temporary-location` 1 lần duy nhất; hiển thị vòng tròn tiến trình (loading) trên nút ngăn chặn double-click; cập nhật tức thì trạng thái điểm giao thành `TEMPORARY`, đồng bộ các ca đang chạy khác của cùng khách hàng; tự động chọn điểm vừa ghim để hiển thị chi tiết trên bản đồ chính.
    - **2. Loại bỏ hoàn toàn quy trình xác minh cổng nhà khỏi luồng ghim nhanh:**
      - Xóa hộp thoại 2 nút `LƯU VỊ TRÍ TẠM TRƯỚC KHI GIAO` và `XÁC MINH CỔNG NHÀ TẠI CHỖ`.
      - Tuyệt đối không chuyển sang `SaveLocationView` trong luồng ghim nhanh này.
      - Giữ nguyên `SaveLocationView` và chức năng chụp ảnh cổng nhà trong tab Danh bạ và chi tiết điểm giao khi người dùng chủ động chụp ảnh xác thực.
    - **3. Quy tắc trạng thái dữ liệu:**
      - Khách `NO_LOCATION` -> ghim vị trí mới -> trạng thái `TEMPORARY`.
      - Khách `TEMPORARY` -> chỉnh lại tọa độ -> giữ nguyên `TEMPORARY`.
      - Khách `VERIFIED` -> thay đổi tọa độ nhanh -> chuyển về `TEMPORARY` (không tự động giữ `VERIFIED` khi chưa có kiểm chứng ảnh cổng thực địa).
      - Bấm `Hủy` -> thoát chế độ ghim, không làm thay đổi dữ liệu.
      - Đồng bộ vị trí mới cho tất cả các ca chưa hoàn thành (`PREPARING`, `IN_PROGRESS`) của khách hàng theo PostGIS chuẩn SRID 4326 `ST_SetSRID(ST_MakePoint(lng, lat), 4326)` và ghi audit log `PIN_TEMPORARY_LOCATION`.
    - **4. Kiểm thử tự động & Thiết bị thực tế:**
      - Backend: 73/73 tests passed (100%), build TypeScript thành công.
      - Flutter: `flutter analyze` 0 issues, `flutter test` 51/51 tests passed (100%) bao gồm 5 kịch bản kiểm thử chuyển đổi trạng thái và logic ghim nhanh trong [map_pin_flow_simplification_test.dart](file:///d:/flutter create delivery_marker_app/mobile_app/test/map_pin_flow_simplification_test.dart).
      - Build APK Debug: `mobile_app/build/app/outputs/flutter-apk/app-debug.apk` thành công.
      - Thiết bị thực tế: Đã cài đặt lên điện thoại Android `AE9260424A4001007` (Android 13), xác minh trực quan qua các ảnh chụp màn hình thực tế: Chế độ chọn khách, ghim tâm ngắm trực tiếp, kéo bản đồ cập nhật tọa độ, hủy không phát sinh dữ liệu, xác nhận 1 lần thành công chuyển điểm thành `Vị trí tạm` và bảo toàn sau khi tắt mở lại app.
  - **PIN-FLOW-DATA-INTEGRITY-AUDIT-007 (Rà soát tính toàn vẹn dữ liệu sau đơn giản hóa ghim bản đồ):**
    - **1. Bảo vệ ghi chú và ảnh nhận diện (Note & Photo Preservation):**
      - Loại bỏ triệt để chuỗi mặc định tự sinh (`Ghim trực tiếp từ bản đồ chính`, `Ghim tạm từ bộ chọn tâm ngắm bản đồ`) gửi từ [main_map_view.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/views/main_map_view.dart) và [crosshair_location_picker_view.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/views/crosshair_location_picker_view.dart).
      - Tại backend [shifts.controller.ts](file:///d:/flutter%20create%20delivery_marker_app/backend/src/controllers/shifts.controller.ts), thêm logic loại trừ chuỗi mặc định: `const isDefaultString = incomingNotes === 'Ghim trực tiếp từ bản đồ chính' || incomingNotes === 'Ghim tạm từ bộ chọn tâm ngắm bản đồ'; const customNotes = (!isDefaultString && incomingNotes) ? incomingNotes : null;`.
      - Chỉ cập nhật `identification_notes` khi có giá trị chuỗi hợp lệ do người dùng chủ động nhập vào. Nếu ghim nhanh tọa độ trên bản đồ mà không nhập ghi chú, ghi chú cũ và ảnh cổng nhà (`image_url`) được giữ nguyên 100%.
    - **2. Đồng bộ nhất quán giữa Danh bạ và Điểm giao ca (saved_locations vs shift_delivery_points):**
      - Xác minh nguồn dữ liệu: `saved_locations` là nguồn vị trí canonical đã xác minh thực địa (`VERIFIED`) kèm ảnh chụp cổng nhà; `shift_delivery_points` lưu vị trí và trạng thái giao hàng riêng theo từng ca.
      - Tại [customers.controller.ts](file:///d:/flutter%20create%20delivery_marker_app/backend/src/controllers/customers.controller.ts):
        - `listCustomers`: Bổ sung `latest_sdp.updated_at`. So sánh timestamp `sdpDate > slDate`: Nếu điểm giao trong ca được ghim tạm thời (`TEMPORARY`) mới hơn thời điểm xác minh trong `saved_locations`, Danh bạ phản ánh `TEMPORARY` với tọa độ ghim mới nhất nhưng vẫn giữ nguyên ảnh cổng nhà và ghi chú nhận diện từ `saved_locations`.
        - `getCustomerDetail`: Truy vấn cả `saved_locations` và `shift_delivery_points`. Trả về `locationStatus` chính xác (`VERIFIED`, `TEMPORARY`, `NO_LOCATION`) và `savedLocation` đại diện cho vị trí đang hoạt động, giúp màn hình chi tiết khách hàng không bị hiển thị sai thành "Chưa có vị trí" khi khách mới chỉ có vị trí tạm.
      - Tại [api_service.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/services/api_service.dart): `getCustomerDetail` đọc `locationStatus` từ API trả về, hỗ trợ cả `temporary` và `verified`.
    - **3. Phạm vi đồng bộ an toàn giữa các ca (Cross-shift Sync Scope):**
      - Giới hạn cập nhật điểm giao của cùng khách hàng trong các ca `PREPARING` hoặc ca `IN_PROGRESS` của chính shipper đang thao tác (`(s.status = 'PREPARING' OR (s.status = 'IN_PROGRESS' AND s.shipper_id = shipperId))`).
      - Tuyệt đối không thay đổi các ca đã `COMPLETED` và không can thiệp vào các ca `IN_PROGRESS` của shipper khác.
      - Ghi audit log `PIN_TEMPORARY_LOCATION` bảo đảm toàn vẹn kiểm toán (AGENTS.md rule 2.5).
      - Tuân thủ quy chuẩn không gian PostGIS SRID 4326: `ST_SetSRID(ST_MakePoint(longitude, latitude), 4326)`.
    - **4. Kết quả kiểm thử thực tế:**
      - Backend: 79/79 unit tests passed (100%), build TypeScript thành công.
      - Flutter: `flutter analyze` 0 issues (100%), `flutter test` 54/54 tests passed (100%).

28. **[ĐÃ HOÀN TẤT - BUG-MAP-PHOTO-008] Khắc phục lỗi ảnh không hiển thị trong thông tin dấu chấm trên bản đồ:**
    - **1. Nguyên nhân gốc đã xác minh:**
      - *Lỗi Header xác thực JWT:* Trong `main_map_view.dart`, khi tải ảnh qua `FutureBuilder<Map<String, String>>`, widget đã truyền trực tiếp `headers: authInfo` (chứa các key `{url: '...', token: '...'}`) vào `Image.network` thay vì chuẩn `headers: {'Authorization': 'Bearer $token'}`. Backend yêu cầu header `Authorization: Bearer <token>`, không nhận được nên trả về mã 401 Unauthorized, kích hoạt `errorBuilder` fallback hiển thị placeholder "Chưa có ảnh vị trí".
      - *Hạn chế xác thực Token trên Web / Chrome:* Khi Flutter chạy trên Chrome (HTML render), thẻ `<img>` không gửi được custom header `Authorization`. Backend [auth.middleware.ts](file:///d:/flutter create delivery_marker_app/backend/src/middlewares/auth.middleware.ts) trước đó chỉ đọc `req.headers.authorization`.
      - *Thiếu fallback ảnh khi điểm giao ca có `image_url` NULL:* Trong PostgreSQL, ảnh khách hàng được lưu ở `saved_locations.image_url`. Điểm giao trong `shift_delivery_points` khi thêm vào hoặc ghim tạm có thể có `sdp.image_url` NULL. API chi tiết ca trước đó chỉ SELECT trực tiếp `p.image_url` mà không fallback sang `saved_locations.image_url` hoặc `location_history.image_url`.
      - *Lỗi tái sử dụng FutureBuilder khi đổi điểm:* Thiếu `ValueKey` định danh duy nhất theo điểm và URL ảnh khiến khi chạm sang khách hàng khác, snapshot cũ có thể tồn tại trong tích tắc.
    - **2. Các giải pháp đã triển khai:**
      - **Backend ([auth.middleware.ts](file:///d:/flutter create delivery_marker_app/backend/src/middlewares/auth.middleware.ts)):** Cập nhật `authenticateJwt` hỗ trợ token từ cả `Authorization: Bearer <token>` và URL query param `req.query.token`.
      - **Backend ([shifts.controller.ts](file:///d:/flutter create delivery_marker_app/backend/src/controllers/shifts.controller.ts)):**
        * Trong `getShiftDetail`: LEFT JOIN `saved_locations` và LEFT JOIN LATERAL `location_history`, giải quyết fallback 3 cấp `resolvedImg = pImg || sImg || hImg || null`.
        * Trong `updateTemporaryLocation`: Ghim vị trí tạm tự động fallback `image_url = COALESCE(image_url, saved_locations.image_url, location_history.image_url)`, đồng bộ sang các ca khác của shipper và trả về `imageUrl` trong response `data`.
      - **Backend ([locations.controller.ts](file:///d:/flutter create delivery_marker_app/backend/src/controllers/locations.controller.ts)):** Đồng bộ ngay lập tức sang `shift_delivery_points.image_url` khi chụp/lưu ảnh mới hoặc xóa ảnh trong `saveOrUpdateCustomerLocation`.
      - **Mobile ([api_service.dart](file:///d:/flutter create delivery_marker_app/mobile_app/lib/services/api_service.dart)):** Cập nhật `getPhotoAuthInfo` tự động gắn `&token=$token` vào URL ảnh, bảo đảm 100% tương thích với trình duyệt Web (Chrome) và Flutter Mobile/Desktop.
      - **Mobile ([main_map_view.dart](file:///d:/flutter create delivery_marker_app/mobile_app/lib/views/main_map_view.dart) & [shift_map_view.dart](file:///d:/flutter create delivery_marker_app/mobile_app/lib/views/shift_map_view.dart)):**
        * Sửa `headers` thành `headers: { if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token' }`.
        * Thêm `ValueKey('main_photo_${point.id}_${point.photoUrl}_$_photoCacheVersion')` cho `FutureBuilder` và `Image.network` chống hiển thị nhầm ảnh của khách trước khi chạm đổi điểm.
        * Truyền `cacheVersion: _photoCacheVersion` vào `FullscreenImageViewer.show` cho phép chạm ảnh để xem phóng to toàn màn hình.
      - **Mobile ([home_shell_view.dart](file:///d:/flutter create delivery_marker_app/mobile_app/lib/views/home_shell_view.dart)):** Tự động tải lại ca làm việc (`reloadActiveShift(preserveSelected: true)`) khi người dùng chuyển từ Tab Danh bạ về Tab Bản đồ.
    - **3. Kết quả kiểm thử:**
      - Backend: **86/86 unit tests passed (100%)** qua 5 test suites.
      - Flutter: `flutter analyze` 0 issues (100%), `flutter test` **56/56 tests passed (100%)**.
      - Kiểm thử API sống trên container: `HTTP 200` với Bearer header, `HTTP 200` với `?token=`, `HTTP 401` khi thiếu token. Điểm `VERIFIED` và `TEMPORARY` đều trả về URL ảnh chính xác.

29. **[ĐÃ HOÀN TẤT - BUG-MAP-SYNC-009] Đồng bộ hoàn toàn ảnh, tọa độ, ghi chú và trạng thái vị trí giữa Bản đồ và Danh bạ:**
    - **1. BUG-01 — Xóa ảnh trong Hồ Sơ & Vị trí khách hàng nhưng Bản đồ vẫn còn ảnh:**
      - *Nguyên nhân:* Backend `getShiftDetail` và `updateTemporaryLocation` trong [shifts.controller.ts](file:///d:/flutter create delivery_marker_app/backend/src/controllers/shifts.controller.ts) trước đó chứa mệnh đề `LEFT JOIN LATERAL location_history` fallback (`hImg`), tự động "hồi sinh" ảnh cũ từ bảng lịch sử ngay cả khi ảnh trong `saved_locations` và `shift_delivery_points` đã bị người dùng xóa hoàn toàn. Đồng thời trên frontend, `PaintingBinding.instance.imageCache` chưa được dọn dẹp khiến widget Flutter tiếp tục render ảnh cache trong bộ nhớ.
      - *Giải pháp:* Loại bỏ hoàn toàn fallback `location_history` (`hImg`) trong [shifts.controller.ts](file:///d:/flutter create delivery_marker_app/backend/src/controllers/shifts.controller.ts), chuẩn hóa nguồn ảnh chính thức từ `saved_locations` và `shift_delivery_points`. Thêm hàm xóa tệp ảnh vật lý an toàn `safeDeletePhotoFile` trong [locations.controller.ts](file:///d:/flutter create delivery_marker_app/backend/src/controllers/locations.controller.ts), chỉ xóa tệp vật lý khi không còn bản ghi nào khác trong CSDL tham chiếu đến tệp đó. Trên Flutter [customer_directory_view.dart](file:///d:/flutter create delivery_marker_app/mobile_app/lib/views/customer_directory_view.dart) và [main_map_view.dart](file:///d:/flutter create delivery_marker_app/mobile_app/lib/views/main_map_view.dart), dọn sạch `PaintingBinding.instance.imageCache` và cập nhật state tức thời.
    - **2. BUG-02 & BUG-05 — Thay đổi tọa độ / ghi chú trong Danh bạ nhưng Bản đồ không cập nhật:**
      - *Nguyên nhân:* Khi người dùng chỉnh sửa tọa độ hoặc ghi chú trong Danh bạ ([save_location_view.dart](file:///d:/flutter create delivery_marker_app/mobile_app/lib/views/save_location_view.dart)), API `saveOrUpdateCustomerLocation` chỉ cập nhật vào bảng `saved_locations` mà không đồng bộ sang `shift_delivery_points` của các ca làm việc đang diễn ra (`PREPARING` hoặc `IN_PROGRESS` của shipper). Đồng thời, khi quay lại tab Bản đồ, `activeShift` không được làm mới lại tự động.
      - *Giải pháp:* Trong [locations.controller.ts](file:///d:/flutter create delivery_marker_app/backend/src/controllers/locations.controller.ts), bổ sung logic đồng bộ tự động từ `saved_locations` sang `shift_delivery_points` cho các ca `PREPARING` hoặc `IN_PROGRESS` của chính shipper: cập nhật `latitude`, `longitude`, PostGIS `geom` (`ST_SetSRID(ST_MakePoint(lng, lat), 4326)`), `identification_notes` và `location_status = 'VERIFIED'`. Tách riêng tham số kiểu dữ liệu giữa cột numeric và float của PostGIS để tránh lỗi `42P08`. Trên Mobile [customer_directory_view.dart](file:///d:/flutter create delivery_marker_app/mobile_app/lib/views/customer_directory_view.dart), khi cập nhật khách hàng thành công sẽ tự động gọi API `getShiftDetail` và kích hoạt callback `onShiftUpdated` để [main_map_view.dart](file:///d:/flutter create delivery_marker_app/mobile_app/lib/views/main_map_view.dart) làm mới ngay lập tức vị trí marker và thông tin chi tiết.
    - **3. BUG-03 — Chức năng Sửa vị trí / Ảnh trên Bản đồ không xóa được ảnh:**
      - *Nguyên nhân:* Khi bấm xóa ảnh từ menu "Sửa vị trí / Ảnh" trên bản đồ, hàm `_deletePhotoForPoint` gọi API `saveOrUpdateCustomerLocation` với `identificationNotes: ''`. Backend kiểm tra `if (!identificationNotes) return res.status(400)` nên request bị từ chối `400 Bad Request`, khiến thao tác xóa ảnh thất bại trong database.
      - *Giải pháp:* Tại [locations.controller.ts](file:///d:/flutter create delivery_marker_app/backend/src/controllers/locations.controller.ts), cho phép `identificationNotes` fallback lấy ghi chú hiện có trong CSDL nếu người dùng không nhập mới, hoặc mặc định `'Vị trí đã lưu'`. Phân biệt rành mạch 3 trạng thái: giữ nguyên ảnh, đổi ảnh mới và xóa ảnh (`deletePhoto === true`).
    - **4. BUG-04 — Chọn ảnh mới từ thư viện trong Sửa vị trí / Ảnh không hoạt động:**
      - *Nguyên nhân:* Mã nguồn cũ sử dụng `dart:io` `File(picked.path).readAsBytes()`, lớp `File` của `dart:io` ném ra ngoại lệ `UnsupportedError` khi chạy trên môi trường Flutter Web / Chrome. Ngoài ra, việc upload ngay lập tức mà không có hộp thoại xem trước (preview) khiến người dùng không thể kiểm tra lại ảnh trước khi lưu.
      - *Giải pháp:* Chuyển sang sử dụng `await picked.readAsBytes()` (hỗ trợ 100% cross-platform cả Chrome Web và Android Mobile). Bổ sung hộp thoại xem trước ảnh `_showImagePreviewDialog` với 2 nút `[HỦY]` và `[LƯU ẢNH]` trước khi tiến hành mã hóa base64 và gửi lên backend.
    - **5. BUG-06 — Danh sách vị trí khi bấm CHỌN VỊ TRÍ hiển thị trạng thái sai:**
      - *Nguyên nhân:* Huy hiệu trạng thái trên bottom sheet chọn khách hàng hiển thị chuỗi cứng `'Vị trí tạm'` cho mọi điểm chưa xác minh hoặc hiển thị mặc định mà không phân biệt đúng 3 trạng thái chuẩn của mô hình.
      - *Giải pháp:* Bổ sung getter `pickerDisplayName` vào enum `LocationStatus` trong [shift_model.dart](file:///d:/flutter create delivery_marker_app/mobile_app/lib/models/shift_model.dart):
        - `LocationStatus.verified` -> `'Đã xác minh'`
        - `LocationStatus.temporary` -> `'Đã ghim vị trí · Chờ xác minh'`
        - `LocationStatus.noLocation` -> `'Chưa ghim vị trí'`
        Ánh xạ chính xác vào chip hiển thị trong `_buildPointPickerListItem` tại [main_map_view.dart](file:///d:/flutter create delivery_marker_app/mobile_app/lib/views/main_map_view.dart).
    - **6. Kết quả kiểm thử tự động & Nghiệm thu sống:**
      - Backend: **86/86 unit tests passed (100%)** qua 5 test suites.
      - Flutter: `flutter analyze` **0 issues**, `flutter test` **61/61 tests passed (100%)** bao gồm 5 kịch bản chuyên biệt trong [bug_map_sync_009_test.dart](file:///d:/flutter create delivery_marker_app/mobile_app/test/bug_map_sync_009_test.dart).
      - Live Integration Verification: Xóa ảnh, đổi tọa độ, đổi ghi chú, upload ảnh mới từ bản đồ, đồng bộ 2 chiều giữa Bản đồ và Danh bạ thành công trên backend container và database PostGIS.


