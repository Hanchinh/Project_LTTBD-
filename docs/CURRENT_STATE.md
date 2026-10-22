# Current State & Technical Debt: Delivery Location Marker System

> **Tài liệu theo dõi trạng thái thực tế của mã nguồn và các khoản nợ kỹ thuật (Technical Debt).**  
> **Cập nhật:** Hoàn thiện tích hợp luồng nghiệp vụ Mobile App, Camera/GPS, Tra cứu theo SĐT, Backend Photo Storage, Bảo toàn lịch sử và Admin Web.

---

## 1. Tóm Tắt Trạng Thái Hệ Thống (Health Snapshot)

| Thành Phần | Trạng Thái Biên Dịch | Trạng Thái Kiểm Thử (Unit Test) | Trạng Thái Tích Hợp |
| :--- | :--- | :--- | :--- |
| **Database (PostGIS)** | Đạt ([01-init-db.sql](file:///d:/flutter create delivery_marker_app/init-db/01-init-db.sql) + [02-add-photo-and-fix-history.sql](file:///d:/flutter create delivery_marker_app/init-db/02-add-photo-and-fix-history.sql)) | Đạt (Schema PostGIS, Trigger ghi nhận ảnh & `ON DELETE SET NULL`) | Đã bổ sung cột `image_url`, sửa ràng buộc cascade bảo toàn lịch sử |
| **Backend API** | Đạt ([app.ts](file:///d:/flutter create delivery_marker_app/backend/src/app.ts), TypeScript 5.4.5) | **Đạt** ([location.spec.ts](file:///d:/flutter create delivery_marker_app/backend/test/location.spec.ts), [auth.spec.ts](file:///d:/flutter create delivery_marker_app/backend/test/auth.spec.ts)) | Hoạt động 13 endpoints (bao gồm tra cứu SĐT và phục vụ ảnh) |
| **Admin Web** | Đạt ([client.ts](file:///d:/flutter create delivery_marker_app/admin_web/src/api/client.ts), TypeScript 5.2.2) | Đã cập nhật UI hỗ trợ ảnh và tạo tài khoản mới | Hoạt động 5 trang giao diện chính, đã cấu hình [nginx.conf](file:///d:/flutter create delivery_marker_app/admin_web/nginx.conf) |
| **Mobile App (Flutter)** | Đạt chuẩn Flutter/Dart SDK `>=3.0.0 <4.0.0` | Đã viết lại [widget_test.dart](file:///d:/flutter create delivery_marker_app/mobile_app/test/widget_test.dart) bao phủ Auth, Form, Model | **Đã kết nối:** [main.dart](file:///d:/flutter create delivery_marker_app/mobile_app/lib/main.dart) điều hướng Login -> OrderList -> OrderDetail |

---

## 2. Bảng Phân Định Hiện Trạng Tính Năng (Feature Status Matrix)

> **Quy ước phân loại:**
> - **[XÁC MINH - ĐÃ TEST]**: Tính năng đã có mã nguồn và đã có automated test bao phủ.
> - **[XÁC MINH - ĐÃ CODE]**: Đã có mã nguồn hoàn chỉnh trong repo sẵn sàng kiểm thử tích hợp.
> - **[XÁC MINH - LỖI/CHƯA GẮN]**: Mã nguồn bị lỗi hoặc thiếu liên kết.
> - **[CHƯA TRIỂN KHAI]**: Chưa có mã nguồn hoặc giao diện.

| Phân Hệ | Chức Năng | Phân Loại | Bằng Chứng Mã Nguồn |
| :--- | :--- | :--- | :--- |
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
| **Backend** | Lưu mới/Cập nhật tọa độ PostGIS, ảnh & ghi chú | [XÁC MINH - ĐÃ CODE] | [locations.controller.ts:L58-L202](file:///d:/flutter create delivery_marker_app/backend/src/controllers/locations.controller.ts#L58-L202) |
| **Backend** | Xem lịch sử cập nhật vị trí khách hàng kèm ảnh | [XÁC MINH - ĐÃ CODE] | [locations.controller.ts:L320-L358](file:///d:/flutter create delivery_marker_app/backend/src/controllers/locations.controller.ts#L320-L358) |
| **Backend** | Quản lý khu vực & gán khu vực cho shipper | [XÁC MINH - ĐÃ CODE] | [admin.controller.ts:L7-L104](file:///d:/flutter create delivery_marker_app/backend/src/controllers/admin.controller.ts#L7-L104) |
| **Backend** | Xóa vị trí an toàn bảo toàn lịch sử đối soát | [XÁC MINH - ĐÃ CODE] | [admin.controller.ts:L180-L196](file:///d:/flutter create delivery_marker_app/backend/src/controllers/admin.controller.ts#L180-L196) |
| **Admin Web** | Đăng nhập Admin & Bảo vệ router bằng Token | [XÁC MINH - ĐÃ CODE] | [Login.tsx](file:///d:/flutter create delivery_marker_app/admin_web/src/pages/Login.tsx), [App.tsx:L11-L32](file:///d:/flutter create delivery_marker_app/admin_web/src/App.tsx#L11-L32) |
| **Admin Web** | Dashboard tỷ lệ phủ vị trí (% Coverage) | [XÁC MINH - ĐÃ CODE] | [Dashboard.tsx](file:///d:/flutter create delivery_marker_app/admin_web/src/pages/Dashboard.tsx) |
| **Admin Web** | Bản đồ Leaflet xem vị trí & hiển thị ảnh mặt tiền | [XÁC MINH - ĐÃ CODE] | [Locations.tsx:L125-L175](file:///d:/flutter create delivery_marker_app/admin_web/src/pages/Locations.tsx#L125-L175) |
| **Admin Web** | Danh sách nhân viên & Modal bàn giao khu vực | [XÁC MINH - ĐÃ CODE] | [Users.tsx:L134-L184](file:///d:/flutter create delivery_marker_app/admin_web/src/pages/Users.tsx#L134-L184) |
| **Admin Web** | Giao diện tạo tài khoản nhân viên / admin mới | [XÁC MINH - ĐÃ CODE] | [Users.tsx:L186-L270](file:///d:/flutter create delivery_marker_app/admin_web/src/pages/Users.tsx#L186-L270) |
| **Mobile App** | Entry point khởi động ứng dụng giao hàng | [XÁC MINH - ĐÃ CODE] | [main.dart:L1-L76](file:///d:/flutter create delivery_marker_app/mobile_app/lib/main.dart#L1-L76) (Khởi động AuthSplashScreen -> LoginView/OrderListView) |
| **Mobile App** | Bảo tồn prototype độc lập cũ | [XÁC MINH - ĐÃ CODE] | [prototype_map_marker_view.dart](file:///d:/flutter create delivery_marker_app/mobile_app/lib/views/prototype_map_marker_view.dart) |
| **Mobile App** | Giao diện Đăng nhập Shipper chuẩn hóa | [XÁC MINH - ĐÃ CODE] | [login_view.dart](file:///d:/flutter create delivery_marker_app/mobile_app/lib/views/login_view.dart) (Validation form, gỡ mật khẩu mặc định) |
| **Mobile App** | Danh sách đơn hàng trong ca & Badge chờ đồng bộ | [XÁC MINH - ĐÃ CODE] | [order_list_view.dart](file:///d:/flutter create delivery_marker_app/mobile_app/lib/views/order_list_view.dart) |
| **Mobile App** | Chi tiết đơn, hiển thị ảnh nhà & Tra cứu qua SĐT | [XÁC MINH - ĐÃ CODE] | [order_detail_view.dart:L34-L80](file:///d:/flutter create delivery_marker_app/mobile_app/lib/views/order_detail_view.dart#L34-L80) |
| **Mobile App** | Dẫn đường Deep-link Google Maps | [XÁC MINH - ĐÃ CODE] | [order_detail_view.dart:L196-L212](file:///d:/flutter create delivery_marker_app/mobile_app/lib/views/order_detail_view.dart#L196-L212) |
| **Mobile App** | Chụp ảnh mặt tiền/cổng nhà, xem trước & chụp lại | [XÁC MINH - ĐÃ CODE] | [save_location_view.dart:L116-L195](file:///d:/flutter create delivery_marker_app/mobile_app/lib/views/save_location_view.dart#L116-L195) |
| **Mobile App** | Cảnh báo sai số GPS (>20m) & Kéo thả ghim thủ công | [XÁC MINH - ĐÃ CODE] | [save_location_view.dart:L197-L290](file:///d:/flutter create delivery_marker_app/mobile_app/lib/views/save_location_view.dart#L197-L290) |
| **Mobile App** | Lưu SQLite offline (`cached_orders`, `sync_queue` v2) | [XÁC MINH - ĐÃ CODE] | [offline_storage_service.dart](file:///d:/flutter create delivery_marker_app/mobile_app/lib/services/offline_storage_service.dart) |
| **Mobile App** | Bộ kiểm thử Widget & Unit tests mới | [XÁC MINH - ĐÃ CODE] | [widget_test.dart:L1-L85](file:///d:/flutter create delivery_marker_app/mobile_app/test/widget_test.dart#L1-L85) |

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
