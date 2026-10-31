# Current State: Delivery Location Marker System (Bản Nộp App-Only)

> **Tài liệu theo dõi trạng thái thực tế của mã nguồn bản nộp độc lập (Local-First).**

---

## 0. Trạng Thái Bản Nộp (Submission Status - App-Only)

- **Nhánh thực thi:** `testrutgoncode` (Hoàn thành đợt tái cấu trúc & tinh gọn: `TASK: SLIM-AND-RESTRUCTURE-011`).
- **Kiểm thử tự động:** `178/178` unit & widget tests passed (`flutter test` exit code 0, 100% passed).
- **Phân tích tĩnh:** `No issues found!` (`flutter analyze` exit code 0).
- **Kích thước APK Release:** 76.4 MB (`app-release.apk` tại `mobile_app/build/app/outputs/flutter-apk/app-release.apk`, độ dài 80,069,461 bytes).
- **Cấu trúc mã nguồn tinh gọn:** Giảm từ 130 tệp `.dart` xuống còn 114 tệp; tầng dữ liệu phân chia rõ ràng theo miền (`data/{customers, locations, shifts, photos, backup, sharing, profile, database}`); các widget dùng chung quy về `core/widgets/`; toàn bộ tệp > 100 dòng đều có chú thích tiếng Việt ở dòng 1; không có bất kỳ tệp nào vượt quá 400 dòng mã (tệp dài nhất là 381 dòng).
- **Tính năng hoàn chỉnh:** Bản đồ chính gom cụm marker; Ghim vị trí bằng tâm chữ thập; Danh bạ khách hàng tìm kiếm không dấu & dán hàng loạt SĐT; Quản lý ca giao hàng & tối ưu điểm; Quản lý nhiều ảnh cổng nhà (nén 1600px); Khóa PIN PBKDF2/SHA-256; Sao lưu & khôi phục ZIP có mật khẩu AES-GCM; Chia sẻ điểm offline qua file `.dshare` và mã QR P2P.
- **Danh mục [CHƯA THỬ TRÊN ĐIỆN THOẠI THẬT]:**
  1. Thao tác cảm ứng đa điểm kéo/zoom bản đồ mượt mà trên màn hình nhỏ.
  2. Độ chính xác phần cứng GPS và chuyển động thực tế ngoài đường.
  3. Chụp ảnh thực tế từ camera thiết bị vật lý và cấp quyền thời gian chạy.
  4. Quét mã QR bằng camera thực tế trong điều kiện thiếu sáng hoặc rung lắc.
  5. Mở file `.dshare` thông qua ứng dụng bên thứ ba (Zalo, Drive, Files) bằng Intent hệ thống.

---

## 1. Tóm Tắt Trạng Thái Hệ Thống (Health Snapshot)

| Thành Phần | Trạng Thái Biên Dịch | Trạng Thái Kiểm Thử (Unit Test) | Trạng Thái Tích Hợp |
| :--- | :--- | :--- | :--- |
| **Mobile App (Flutter)** | Đạt chuẩn Flutter/Dart SDK `>=3.0.0 <4.0.0`, build APK release tối ưu hóa R8 ([app-release.apk](mobile_app/build/app/outputs/flutter-apk/app-release.apk)) | **Đạt** (231/231 tests trong thư mục `mobile_app/test/`) | **Bản nộp chính (Local-First):** Sẵn sàng phát hành (Local-First 09: Cấu hình Tile tập trung, Offline Map, Dọn dữ liệu & Cache, Benchmark 5,000 khách, SQLite v2 Indexes & WAL, R8 Shrinking, Adaptive Icon & Ký số Release), Tái cấu trúc Feature-First (08), Chia sẻ file .dshare & QR (07), Local Profile, PIN & Backup (06), Local Photo (05), Local Shift (04), Local Repositories (03), SQLite (02), Repository Layer (01) |
| **Database (PostGIS)** *(Tag v1.0-full)* | Bảo lưu tại tag `v1.0-full` | Đạt tại tag `v1.0-full` | Hệ thống Client-Server cũ (xem tag `v1.0-full`) |
| **Backend API** *(Tag v1.0-full)* | Bảo lưu tại tag `v1.0-full` | Đạt (66/66 tests tại tag `v1.0-full`) | Hệ thống Client-Server cũ (xem tag `v1.0-full`) |
| **Admin Web** *(Tag v1.0-full)* | Bảo lưu tại tag `v1.0-full` | Đạt tại tag `v1.0-full` | Hệ thống Client-Server cũ (xem tag `v1.0-full`) |

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
| **Mobile App** | Chế độ Local-First không cần đăng nhập, onboarding chào mừng & đổi tên | [XÁC MINH - ĐÃ TEST] *(Đã test tự động; chưa thử điện thoại thật)* | [local_profile_repository.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/repositories/local/local_profile_repository.dart), [welcome_onboarding_view.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/views/welcome_onboarding_view.dart), [local_first_profile_pin_backup_06_test.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/test/local_first_profile_pin_backup_06_test.dart) |
| **Mobile App** | Tab Cá nhân thích ứng Local (đổi tên, xem thống kê SQLite, ẩn mục máy chủ) | [XÁC MINH - ĐÃ TEST] *(Đã test tự động; chưa thử điện thoại thật)* | [account_profile_view.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/views/account_profile_view.dart), [local_first_profile_pin_backup_06_test.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/test/local_first_profile_pin_backup_06_test.dart) |
| **Mobile App** | Mã PIN khóa app 4-6 số, băm PBKDF2/SHA-256 + Salt, khóa lũy tiến, khóa khi vào nền | [XÁC MINH - ĐÃ TEST] *(Đã test tự động; chưa thử điện thoại thật)* | [pin_crypto_utils.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/utils/pin_crypto_utils.dart), [pin_lock_screen.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/views/pin_lock_screen.dart), [local_first_profile_pin_backup_06_test.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/test/local_first_profile_pin_backup_06_test.dart) |
| **Mobile App** | Dịch vụ sao lưu zip (`.db` + `photos/` + `manifest.json`), đối soát SHA-256, chia sẻ qua hệ thống | [XÁC MINH - ĐÃ TEST] *(Đã test tự động; chưa thử điện thoại thật)* | [backup_service.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/services/backup_service.dart), [backup_restore_bottom_sheet.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/widgets/backup_restore_bottom_sheet.dart), [local_first_profile_pin_backup_06_test.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/test/local_first_profile_pin_backup_06_test.dart) |
| **Mobile App** | Dịch vụ khôi phục zip: Thay toàn bộ (kèm sao lưu an toàn) & Gộp (giữ khách trùng SĐT), chống path traversal | [XÁC MINH - ĐÃ TEST] *(Đã test tự động; chưa thử điện thoại thật)* | [backup_service.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/services/backup_service.dart), [local_first_profile_pin_backup_06_test.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/test/local_first_profile_pin_backup_06_test.dart) |
| **Mobile App** | Nhắc nhở sao lưu sau 14 ngày không sao lưu tại tab Cá nhân | [XÁC MINH - ĐÃ TEST] *(Đã test tự động; chưa thử điện thoại thật)* | [account_profile_view.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/views/account_profile_view.dart), [backup_service.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/services/backup_service.dart) |
| **Mobile App** | Xuất gói chia sẻ `.dshare` (ZIP + manifest + points + photos), mã hóa PBKDF2/AES-GCM, gửi qua share sheet | [XÁC MINH - ĐÃ TEST] *(Đã test tự động; chưa thử điện thoại thật)* | [local_sharing_repository.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/repositories/local/local_sharing_repository.dart), [share_crypto_utils.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/utils/share_crypto_utils.dart), [local_first_sharing_07_test.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/test/local_first_sharing_07_test.dart) |
| **Mobile App** | Chia sẻ chuỗi QR nén gzip+base64url đa mảnh (chunking), màn hình hiển thị QR lớn & điều hướng carousel | [XÁC MINH - ĐÃ TEST] *(Đã test tự động; chưa thử điện thoại thật)* | [share_crypto_utils.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/utils/share_crypto_utils.dart), [data_share_qr_view.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/widgets/data_share_qr_view.dart), [local_first_sharing_07_test.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/test/local_first_sharing_07_test.dart) |
| **Mobile App** | Quét QR liên tục thu thập mảnh bằng camera (`QrChunkCollector`), kiểm tra tính toàn vẹn | [XÁC MINH - ĐÃ TEST] *(Đã test tự động; chưa thử điện thoại thật)* | [data_share_qr_scanner_view.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/widgets/data_share_qr_scanner_view.dart), [local_first_sharing_07_test.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/test/local_first_sharing_07_test.dart) |
| **Mobile App** | Nhập gói `.dshare` / QR: kiểm duyệt an toàn (50MB, 2000 điểm, schema, chống path traversal, SHA-256), phân loại điểm & tính khoảng cách lệch, xem trước | [XÁC MINH - ĐÃ TEST] *(Đã test tự động; chưa thử điện thoại thật)* | [local_sharing_repository.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/repositories/local/local_sharing_repository.dart), [data_share_import_preview_sheet.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/widgets/data_share_import_preview_sheet.dart), [local_first_sharing_07_test.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/test/local_first_sharing_07_test.dart) |
| **Mobile App** | Tiếp nhận dữ liệu: Chỉ thêm mới / Thay vị trí cũ (bảo toàn lịch sử qua trigger) / Nhập thành ca mới, rollback ảnh nếu lỗi | [XÁC MINH - ĐÃ TEST] *(Đã test tự động; chưa thử điện thoại thật)* | [local_sharing_repository.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/repositories/local/local_sharing_repository.dart), [local_first_sharing_07_test.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/test/local_first_sharing_07_test.dart) |
| **Mobile App** | Giao diện chia sẻ nhanh 1 điểm trên bản đồ và chi tiết khách hàng | [XÁC MINH - ĐÃ TEST] *(Đã test tự động; chưa thử điện thoại thật)* | [point_detail_bottom_sheet.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/shared_widgets/point_detail_bottom_sheet.dart), [customer_directory_view.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/features/directory/customer_directory_view.dart), [local_first_sharing_07_test.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/test/local_first_sharing_07_test.dart) |
| **Mobile App** | Tái cấu trúc Feature-First: tách nhỏ màn hình < 500 dòng, build() < 150 dòng, phân lập server mode | [XÁC MINH - ĐÃ TEST] | [docs/CODE_STRUCTURE.md](file:///d:/flutter%20create%20delivery_marker_app/docs/CODE_STRUCTURE.md), [docs/LOCAL_FIRST_PLAN.md](file:///d:/flutter%20create%20delivery_marker_app/docs/LOCAL_FIRST_PLAN.md) |
| **Mobile App** | Quản lý nguồn Tile tập trung & Ghi nhận bản quyền (Attribution) tại tab Cá nhân | [XÁC MINH - ĐÃ TEST] *(Đã test tự động; chưa thử điện thoại thật)* | [map_config.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/core/constants/map_config.dart), [docs/TILE_PROVIDERS.md](file:///d:/flutter%20create%20delivery_marker_app/docs/TILE_PROVIDERS.md), [account_profile_view.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/features/profile/account_profile_view.dart), [local_first_release_readiness_09_test.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/test/local_first_release_readiness_09_test.dart) |
| **Mobile App** | Trải nghiệm Bản đồ khi mất mạng (Offline Banner, hiển thị điểm trên nền trống, chặn tìm địa chỉ báo lỗi mạng) | [XÁC MINH - ĐÃ TEST] *(Đã test tự động; chưa thử điện thoại thật)* | [main_map_view.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/features/map/main_map_view.dart), [crosshair_location_picker_view.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/features/map/crosshair_location_picker_view.dart), [local_first_release_readiness_09_test.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/test/local_first_release_readiness_09_test.dart) |
| **Mobile App** | Dọn ảnh xóa mềm quá 30 ngày tự động khi mở app, dọn file chia sẻ/sao lưu tạm & giới hạn cache tile | [XÁC MINH - ĐÃ TEST] *(Đã test tự động; chưa thử điện thoại thật)* | [local_photo_repository.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/data/local/local_photo_repository.dart), [app_storage_service.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/data/local/app_storage_service.dart), [main.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/main.dart), [local_first_release_readiness_09_test.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/test/local_first_release_readiness_09_test.dart) |
| **Mobile App** | Hiển thị dung lượng ứng dụng (CSDL, Ảnh, Cache) và nút "Dọn bộ nhớ đệm" trong tab Cá nhân | [XÁC MINH - ĐÃ TEST] *(Đã test tự động; chưa thử điện thoại thật)* | [account_profile_view.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/features/profile/account_profile_view.dart), [app_storage_service.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/data/local/app_storage_service.dart), [local_first_release_readiness_09_test.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/test/local_first_release_readiness_09_test.dart) |
| **Mobile App** | Tối ưu hóa chỉ mục SQLite v2, gom cụm mượt 1,000 điểm & truy vấn 5,000 khách dưới 150ms | [XÁC MINH - ĐÃ TEST] *(Đã test tự động; chưa thử điện thoại thật)* | [app_database.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/data/local/app_database.dart), [local_first_release_readiness_09_test.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/test/local_first_release_readiness_09_test.dart) |
| **Mobile App** | Độ bền dữ liệu SQLite WAL mode, kiểm tra toàn vẹn PRAGMA integrity_check & nhắc nhở sao lưu | [XÁC MINH - ĐÃ TEST] *(Đã test tự động; chưa thử điện thoại thật)* | [app_database.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/data/local/app_database.dart), [backup_service.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/data/local/backup_service.dart), [local_first_release_readiness_09_test.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/test/local_first_release_readiness_09_test.dart) |
| **Mobile App** | Rà soát quyền Android tối thiểu (GPS, Camera, Internet), loại bỏ quyền ghi công cộng, Intent .dshare | [XÁC MINH - ĐÃ TEST] *(Đã test tự động; chưa thử điện thoại thật)* | [AndroidManifest.xml](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/android/app/src/main/AndroidManifest.xml) |
| **Mobile App** | Tên tiếng Việt "Ghim Điểm Giao Hàng", Adaptive Icon đa tầng, R8 / Resource Shrinking & Hướng dẫn ký số Keystore | [XÁC MINH - ĐÃ TEST] *(Đã test tự động; chưa thử điện thoại thật)* | [AndroidManifest.xml](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/android/app/src/main/AndroidManifest.xml), [build.gradle.kts](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/android/app/build.gradle.kts), [proguard-rules.pro](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/android/app/proguard-rules.pro), [docs/RELEASE_SIGNING_GUIDE.md](file:///d:/flutter%20create%20delivery_marker_app/docs/RELEASE_SIGNING_GUIDE.md), [docs/TEST_CHECKLIST.md](file:///d:/flutter%20create%20delivery_marker_app/docs/TEST_CHECKLIST.md) |

---

## 3. Lịch Sử Phát Triển & Nhật Ký Kỹ Thuật Cũ

Toàn bộ nhật ký kiểm toán (Audit Log), lịch sử xử lý nợ kỹ thuật phiên bản Client-Server và các giai đoạn phát triển trước đây được lưu trữ đầy đủ tại: **[docs/HISTORY.md](docs/HISTORY.md)**.

---

## 15. Tách Lớp Dữ Liệu Phục Vụ Kiến Trúc Local-First (LOCAL-FIRST-01-REPOSITORY-LAYER)

> **Nhánh:** `local-first`  
> **Mục tiêu:** Tách triệt để sự phụ thuộc trực tiếp vào `ApiService` sang các lớp Repository trừu tượng, mở đường cho việc lưu trữ dữ liệu hoàn toàn trên thiết bị (SQLite/Drift/Isar/local database) mà không bắt buộc đăng nhập hay phụ thuộc backend API trực tuyến. Backend và Admin Web giữ nguyên để sẵn sàng đồng bộ sau này.

### 15.1. Bảng Khảo Sát Gọi ApiService & Phân Nhóm Repository

Chi tiết phân tích toàn bộ 101 điểm gọi trong `mobile_app/lib` được lưu tại [docs/LOCAL_FIRST_PLAN.md](file:///d:/flutter%20create%20delivery_marker_app/docs/LOCAL_FIRST_PLAN.md). Toàn bộ được chia làm 6 nhóm trừu tượng chính:

| Nhóm Repository | Interface Trừu Tượng | Triển Khai Remote (Wrapper ApiService) | Số Phương Thức Nghiệp Vụ |
| :--- | :--- | :--- | :--- |
| **Khách Hàng (Customer)** | [CustomerRepository](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/repositories/customer_repository.dart) | [RemoteCustomerRepository](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/repositories/remote/remote_customer_repository.dart) | 6 (getCustomers, getCustomersResponse, getCustomerDetail, createCustomer, createBulkCustomers, updateCustomer, lookupCustomerLocationByPhone) |
| **Vị Trí & Tọa Độ (Location)** | [LocationRepository](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/repositories/location_repository.dart) | [RemoteLocationRepository](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/repositories/remote/remote_location_repository.dart) | 8 (saveLocation, deleteLocation, getNearbyMarkers, getLocationsInBounds, getAreas, updateTemporaryLocation, verifyHomeGate, recordDeliveryAttempt) |
| **Hình Ảnh (Photo)** | [PhotoRepository](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/repositories/photo_repository.dart) | [RemotePhotoRepository](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/repositories/remote/remote_photo_repository.dart) | 4 (getCustomerPhotos, addCustomerPhoto, deleteCustomerPhoto, getPhotoAuthInfo) |
| **Ca Làm Việc (Shift)** | [ShiftRepository](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/repositories/shift_repository.dart) | [RemoteShiftRepository](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/repositories/remote/remote_shift_repository.dart) | 10 (getShifts, getShiftDetail, createShift, updateShiftName, updateShiftStatus, deleteShift, addPointToShift, addBulkPointsToShift, removePointFromShift, getMyShiftOrders, addOrderToShift) |
| **Chia Sẻ Dữ Liệu (Sharing)** | [SharingRepository](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/repositories/sharing_repository.dart) | [RemoteSharingRepository](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/repositories/remote/remote_sharing_repository.dart) | 4 (createShare, getIncomingShares, getOutgoingShares, revokeShare) |
| **Tài Khoản & Hồ Sơ (Profile)** | [ProfileRepository](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/repositories/profile_repository.dart) | [RemoteProfileRepository](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/repositories/remote/remote_profile_repository.dart) | 5 (login, logout, getProfile, changePassword, getSavedLoginPhone) |

### 15.2. Cấu Trúc Service Locator (RepositoryProvider)

- Tệp: [repository_provider.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/repositories/repository_provider.dart)
- Đặc điểm:
  - Siêu nhẹ, thuần Dart/Flutter, không dùng thêm thư viện cồng kềnh.
  - Cung cấp getter tĩnh đến 6 nhóm repository: `RepositoryProvider.customer`, `RepositoryProvider.location`, `RepositoryProvider.photo`, `RepositoryProvider.shift`, `RepositoryProvider.sharing`, `RepositoryProvider.profile`.
  - Mặc định trỏ đến các `Remote...Repository` $\rightarrow$ Hành vi của App với Backend được giữ nguyên 100%.
  - Hỗ trợ phương thức `overrideRepositories(...)` và `reset()` phục vụ kiểm thử đơn vị hoặc cắm `Local...Repository` trong các bước tiếp theo.

### 15.3. Các Màn Hình & Widget Đã Chuyển Đổi Sang Repository

Tất cả các màn hình, sheet và widget nghiệp vụ trong `mobile_app/lib` đã được chuyển đổi hoàn toàn sang gọi qua `RepositoryProvider`:
1. **Hình ảnh:**
   - [customer_photos_strip_widget.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/widgets/customer_photos_strip_widget.dart)
   - [authenticated_image.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/widgets/authenticated_image.dart)
   - [fullscreen_image_viewer.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/widgets/fullscreen_image_viewer.dart)
2. **Tài khoản / Hồ sơ:**
   - [login_view.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/views/login_view.dart)
   - [account_profile_view.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/views/account_profile_view.dart)
   - [change_password_view.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/views/change_password_view.dart)
3. **Ca làm việc:**
   - [shift_list_view.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/views/shift_list_view.dart)
   - [create_shift_dialog.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/widgets/create_shift_dialog.dart)
   - [shift_picker_bottom_sheet.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/widgets/shift_picker_bottom_sheet.dart)
   - [shift_preparation_view.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/views/shift_preparation_view.dart)
   - [shift_map_view.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/views/shift_map_view.dart)
4. **Chia sẻ dữ liệu:**
   - [data_sharing_view.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/views/data_sharing_view.dart)
5. **Khách hàng & Vị trí:**
   - [customer_directory_view.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/views/customer_directory_view.dart)
   - [quick_add_customer_sheet.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/widgets/quick_add_customer_sheet.dart)
   - [bulk_paste_phone_sheet.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/widgets/bulk_paste_phone_sheet.dart)
   - [crosshair_location_picker_view.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/views/crosshair_location_picker_view.dart)
   - [save_location_view.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/views/save_location_view.dart)
   - [main_map_view.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/views/main_map_view.dart)
   - [order_list_view.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/views/order_list_view.dart)
   - [order_detail_view.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/views/order_detail_view.dart)
   - [delivery_map_view.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/views/delivery_map_view.dart)

### 15.4. Các Chức Năng Còn Dùng ApiService Trực Tiếp (Hạ Tầng / OS)

Đúng theo kế hoạch tại [docs/LOCAL_FIRST_PLAN.md](file:///d:/flutter%20create%20delivery_marker_app/docs/LOCAL_FIRST_PLAN.md), các lệnh không thuộc nghiệp vụ dữ liệu chính được giữ lại trên `ApiService`:
- Quản lý cấu hình kết nối mạng/cổng API: `ApiService.getBaseUrl()`, `ApiService.setCustomBaseUrl()`, `ApiService.resetCustomBaseUrl()`.
- Quản lý JWT Token mức phiên: `ApiService.getToken()`, `ApiService.saveToken()`.
- Dịch vụ bản đồ bên thứ ba (OSM / Nominatim Geocoding): `ApiService.searchAddress()`.
- Tích hợp ứng dụng điều hướng ngoài (Google Maps / Apple Maps / url_launcher): `ApiService.openExternalNavigation()`.

### 15.5. Kết Quả Kiểm Thử Thực Tế (Evidence-Based Testing)

- **Kiểm tra cú pháp & Lint:**
  * Lệnh: `flutter analyze`
  * Kết quả: **No issues found!** (ran in 2.9s)
- **Kiểm thử tự động:**
  * Lệnh: `flutter test`
  * Bộ test mới: [local_first_repository_layer_01_test.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/test/local_first_repository_layer_01_test.dart) bao phủ:
    1. `RepositoryProvider` mặc định khởi tạo đúng các `RemoteRepository`.
    2. `RepositoryProvider` hỗ trợ tiêm `FakeRepository` và hàm `reset()` hoàn nguyên sạch sẽ.
    3. Widget (`CreateShiftBottomSheet`) gọi đúng phương thức trên `FakeShiftRepository` được tiêm.
    4. `RemoteProfileRepository` và `RemotePhotoRepository` ủy quyền đúng sang các hàm tương ứng của `ApiService`.
  * Kết quả: **152/152 tests passed** (100% tests cũ và mới đều xanh, không sửa bất kỳ assertion nào trong tests cũ).
- **Trạng Thái Kiểm Thử Thiết Bị Thực Tế:**
  * **ĐÃ TEST trên unit & widget test tự động / CHƯA thử trên điện thoại thật.**

---

## 20. Hoàn Thiện Tinh Chỉnh Giao Diện (Task UI-REFINEMENT-POLISH-FINAL-015)

### 20.1. Các Hạng Mục Đã Xử Lý
1. **Tối ưu RAM Thumbnail Ảnh (P2 - Performance):**
   - Bổ sung `cacheWidth` và `cacheHeight` vào [authenticated_image.dart](mobile_app/lib/shared_widgets/authenticated_image.dart).
   - Truyền `cacheWidth: 300` trong [photo_strip_item.dart](mobile_app/lib/features/photos/photo_strip_item.dart) và `cacheWidth: 150` trong [customer_list_item.dart](mobile_app/lib/features/directory/widgets/customer_list_item.dart).
2. **Thích Ứng Tablet Màn Hình Rộng (P2 - Adaptivity):**
   - Trong [home_shell_view.dart](mobile_app/lib/home_shell_view.dart): Tự động phát hiện màn hình rộng (`width >= 600dp`). Chuyển sang thanh điều hướng dọc `NavigationRail` ở cạnh trái kết hợp `VerticalDivider`, ẩn `bottomNavigationBar`.
3. **Đồng Bộ Màu Bề Mặt Card (P2 - Theming):**
   - Rà soát và loại bỏ các mã màu cứng (`Colors.white`) trong [point_detail_bottom_sheet.dart](mobile_app/lib/shared_widgets/point_detail_bottom_sheet.dart), [customer_list_item.dart](mobile_app/lib/features/directory/widgets/customer_list_item.dart), [customer_detail_edit_view.dart](mobile_app/lib/features/directory/customer_detail_edit_view.dart), [customer_detail_location_card.dart](mobile_app/lib/features/directory/widgets/customer_detail_location_card.dart), và [crosshair_bottom_panel.dart](mobile_app/lib/features/map/widgets/crosshair_bottom_panel.dart).
   - Áp dụng các token chuẩn Material 3: `colorScheme.surface`, `onSurface`, `onSurfaceVariant`, `surfaceContainerHighest`.
4. **Phản Hồi Rung Haptic (P3 - Delight):**
   - Trong [crosshair_location_picker_view.dart](mobile_app/lib/features/map/crosshair_location_picker_view.dart): Bổ sung `HapticFeedback.selectionClick()` khi di chuyển tâm ngắm và `HapticFeedback.mediumImpact()` khi xác nhận ghim vị trí.
5. **Typography & Material Elevation (P3):**
   - Nâng cỡ chữ ghi chú trong [point_detail_bottom_sheet.dart](mobile_app/lib/shared_widgets/point_detail_bottom_sheet.dart) lên `fontSize: 14`.
   - Chuyển bóng đổ tùy chỉnh sang `Material(elevation: 8)`.

### 20.2. Bằng Chứng Kiểm Thử
- `flutter analyze`: **No issues found!**
- `flutter test`: **182/182 tests passed!** (100% test suites).
- Giới hạn dòng: Tất cả các file trong `lib/` đều $\le 350$ dòng (dài nhất là `point_detail_bottom_sheet.dart` với 342 dòng).

---

## 16. Thiết Lập Lược Đồ CSDL SQLite Cục Bộ (LOCAL-FIRST-02-SQLITE-SCHEMA)

> **Nhánh:** `local-first`  
> **Mục tiêu:** Tạo cơ sở dữ liệu SQLite cục bộ mới ([app_database.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/local/app_database.dart)) và tầng truy cập mức thấp, chuẩn bị lưu trữ dữ liệu hoàn toàn trên điện thoại mà không làm thay đổi luồng chạy của ứng dụng (RepositoryProvider vẫn mặc định Remote).

### 16.1. Khảo Sát & Quyết Định Kiến Trúc Cơ Sở Dữ Liệu

- **Khảo sát [offline_storage_service.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/services/offline_storage_service.dart):**
  * Tệp này hiện quản lý `delivery_offline_v2.db` với các bảng `cached_orders`, `offline_sync_queue`, `_v1_migration_tracking`, `_v1_quarantine_records`.
  * Cơ chế này gắn liền với logic đồng bộ hàng đợi lên backend qua `syncPendingLocations`.
- **Quyết định:** Tạo CSDL mới độc lập **`local_data_v1.db`**, **không sửa** `delivery_offline_v2.db` và hàng đợi đồng bộ cũ. Nhờ vậy 100% các bài test di chuyển SQLite cũ ([sqlite_migration_test.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/test/sqlite_migration_test.dart)) đều an toàn tuyệt đối.

### 16.2. Cấu Trúc Quản Lý CSDL ([app_database.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/local/app_database.dart))

- **Cấu hình động cơ SQLite:**
  * Bật `PRAGMA foreign_keys = ON;` qua hook `onConfigure` cho mọi kết nối.
  * Kích hoạt `PRAGMA journal_mode = WAL;` (Write-Ahead Logging) cho file database.
  * Hỗ trợ mở CSDL trong bộ nhớ (`openInMemory`) phục vụ kiểm thử đơn vị với `sqflite_common_ffi`.
  * Hệ thống migration theo phiên bản (`user_version`, `onCreate`, `onUpgrade` chạy tuần tự trong transaction).
- **Lược đồ bảng (ID UUID v4, thời gian ISO-8601 UTC):**
  1. `customers`: Khách hàng độc lập, SĐT chuẩn hóa `UNIQUE`, cột phụ `search_text`, xóa mềm `deleted_at`.
  2. `saved_locations`: Vị trí cổng nhà đã xác minh (`VERIFIED`), `customer_id UNIQUE FK`, index `(latitude, longitude)`.
  3. `location_history`: Lịch sử tọa độ cũ, `saved_location_id NULL FK ON DELETE SET NULL`, `customer_id FK`.
  4. `trg_saved_locations_history`: Trigger SQLite tự động ghi nhận bản ghi lịch sử khi `saved_locations` được `UPDATE` đổi tọa độ/ghi chú.
  5. `customer_photos`: Quản lý tên file ảnh mặt tiền (`file_name`, `thumb_file_name`) và xóa mềm `deleted_at`.
  6. `shifts`: Ca làm việc, ràng buộc `CHECK(status IN ('PREPARING', 'IN_PROGRESS', 'COMPLETED'))`.
  7. `shift_delivery_points`: Điểm giao trong ca, chứa tọa độ `TEMPORARY`, `FOREIGN KEY (shift_id) ON DELETE CASCADE`, `UNIQUE(shift_id, customer_id)`.
  8. `app_profile`: Hồ sơ shipper cục bộ (`CHECK (id = 1)`, `display_name`, `pin_hash`).
  9. `app_meta`: Cài đặt `key-value`.
  10. `activity_log`: Nhật ký hoạt động cục bộ (lọc bỏ các trường nhạy cảm `password`, `token`, `pin`).

### 16.3. Quy Chuẩn Tiện Ích Dùng Chung (Utilities)

1. **Chuẩn Hóa SĐT ([phone_utils.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/utils/phone_utils.dart)):**
   - Chuyển `normalizeCustomerPhone` sang tệp tiện ích dùng chung, tái xuất (`export`) lại qua [quick_add_customer_sheet.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/widgets/quick_add_customer_sheet.dart) để giữ xanh toàn bộ test cũ.
2. **Tìm Kiếm Không Dấu ([vietnamese_utils.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/utils/vietnamese_utils.dart)):**
   - Hàm `removeVietnameseDiacritics` loại bỏ triệt để dấu thanh và dấu mũ tiếng Việt.
   - Hàm `buildCustomerSearchText` tự động đồng bộ khi insert/update khách hàng, cho phép tìm kiếm hai chiều không phân biệt dấu (`"Nguyen Xien"` khớp `"Nguyễn Xiển"`).
3. **Sinh UUID v4 Thuần Dart ([uuid_utils.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/utils/uuid_utils.dart)):**
   - Sinh chuỗi UUID RFC 4122 chuẩn 36 ký tự mà không cần nạp thêm package bên thứ ba.

### 16.4. Kết Quả Kiểm Thử Thực Tế (Evidence-Based Testing)

- **Kiểm tra cú pháp & Lint:**
  * Lệnh: `flutter analyze`
  * Kết quả: **No issues found!** (ran in 1.4s)
- **Kiểm thử tự động:**
  * Lệnh: `flutter test`
  * Bộ test mới: [local_first_sqlite_schema_02_test.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/test/local_first_sqlite_schema_02_test.dart) (10 bài test):
    1. Tạo DB sạch đủ tất cả các bảng và trigger `trg_saved_locations_history`: **PASSED**.
    2. Migration chạy lại (re-run) không bị lỗi: **PASSED**.
    3. Trigger lịch sử sinh dòng khi đổi tọa độ hoặc ghi chú (`UPDATE`): **PASSED**.
    4. Xóa vị trí giữ lịch sử (`saved_location_id` chuyển về `NULL`, không xóa dòng lịch sử): **PASSED**.
    5. Xóa ca `shifts` cascade xóa điểm giao, **không** xóa khách hàng hay vị trí: **PASSED**.
    6. `UNIQUE(shift_id, customer_id)` chặn tuyệt đối thêm khách trùng vào một ca: **PASSED**.
    7. `CHECK` ràng buộc trạng thái chặn giá trị sai trên `shifts`, `shift_delivery_points`, `app_profile`: **PASSED**.
    8. Tìm kiếm không dấu: `"Nguyen Xien"` khớp `"Nguyễn Xiển"`, tìm SĐT có khoảng cách/chấm: **PASSED**.
    9. Chuẩn hóa SĐT và chặn trùng lặp khách hàng qua `phone_number UNIQUE`: **PASSED**.
    10. `app_profile`, `app_meta` và `activity_log` lọc dữ liệu nhạy cảm hoạt động chính xác: **PASSED**.
  * Kết quả tổng thể: **162/162 tests passed** (100% tests cũ và mới đều xanh).
- **Biên dịch gói APK Debug:**
  * Lệnh: `flutter build apk --debug`
  * Kết quả: **Thành công (Built build\app\outputs\flutter-apk\app-debug.apk in 15.0s)**.
- **Trạng Thái Kiểm Thử Thiết Bị Thực Tế:**
  * **ĐÃ TEST trên unit & widget test tự động / CHƯA thử trên điện thoại thật.**

---

## 20. Hoàn Thiện Tinh Chỉnh Giao Diện (Task UI-REFINEMENT-POLISH-FINAL-015)

### 20.1. Các Hạng Mục Đã Xử Lý
1. **Tối ưu RAM Thumbnail Ảnh (P2 - Performance):**
   - Bổ sung `cacheWidth` và `cacheHeight` vào [authenticated_image.dart](mobile_app/lib/shared_widgets/authenticated_image.dart).
   - Truyền `cacheWidth: 300` trong [photo_strip_item.dart](mobile_app/lib/features/photos/photo_strip_item.dart) và `cacheWidth: 150` trong [customer_list_item.dart](mobile_app/lib/features/directory/widgets/customer_list_item.dart).
2. **Thích Ứng Tablet Màn Hình Rộng (P2 - Adaptivity):**
   - Trong [home_shell_view.dart](mobile_app/lib/home_shell_view.dart): Tự động phát hiện màn hình rộng (`width >= 600dp`). Chuyển sang thanh điều hướng dọc `NavigationRail` ở cạnh trái kết hợp `VerticalDivider`, ẩn `bottomNavigationBar`.
3. **Đồng Bộ Màu Bề Mặt Card (P2 - Theming):**
   - Rà soát và loại bỏ các mã màu cứng (`Colors.white`) trong [point_detail_bottom_sheet.dart](mobile_app/lib/shared_widgets/point_detail_bottom_sheet.dart), [customer_list_item.dart](mobile_app/lib/features/directory/widgets/customer_list_item.dart), [customer_detail_edit_view.dart](mobile_app/lib/features/directory/customer_detail_edit_view.dart), [customer_detail_location_card.dart](mobile_app/lib/features/directory/widgets/customer_detail_location_card.dart), và [crosshair_bottom_panel.dart](mobile_app/lib/features/map/widgets/crosshair_bottom_panel.dart).
   - Áp dụng các token chuẩn Material 3: `colorScheme.surface`, `onSurface`, `onSurfaceVariant`, `surfaceContainerHighest`.
4. **Phản Hồi Rung Haptic (P3 - Delight):**
   - Trong [crosshair_location_picker_view.dart](mobile_app/lib/features/map/crosshair_location_picker_view.dart): Bổ sung `HapticFeedback.selectionClick()` khi di chuyển tâm ngắm và `HapticFeedback.mediumImpact()` khi xác nhận ghim vị trí.
5. **Typography & Material Elevation (P3):**
   - Nâng cỡ chữ ghi chú trong [point_detail_bottom_sheet.dart](mobile_app/lib/shared_widgets/point_detail_bottom_sheet.dart) lên `fontSize: 14`.
   - Chuyển bóng đổ tùy chỉnh sang `Material(elevation: 8)`.

### 20.2. Bằng Chứng Kiểm Thử
- `flutter analyze`: **No issues found!**
- `flutter test`: **182/182 tests passed!** (100% test suites).
- Giới hạn dòng: Tất cả các file trong `lib/` đều $\le 350$ dòng (dài nhất là `point_detail_bottom_sheet.dart` với 342 dòng).

---

## 17. Tiến Độ Local-First: Tầng Repository Cục Bộ Khách Hàng & Vị Trí (TASK: LOCAL-FIRST-03-LOCAL-REPOSITORY-CUSTOMER-LOCATION)

### 17.1. Bối Cảnh & Mục Tiêu Nghiệp Vụ
- Tiếp nối việc trừu tượng hóa Repository (Task 01) và thiết lập cơ sở dữ liệu SQLite `local_data_v1.db` (Task 02), Task 03 triển khai hoàn chỉnh tầng truy cập dữ liệu cục bộ cho hai nhóm cốt lõi: **Khách hàng** ([LocalCustomerRepository](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/repositories/local/local_customer_repository.dart)) và **Vị trí** ([LocalLocationRepository](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/repositories/local/local_location_repository.dart)).
- Giữ nguyên hợp đồng giao tiếp (Contract) của [CustomerRepository](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/repositories/customer_repository.dart) và [LocationRepository](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/repositories/location_repository.dart) cùng các Data Model hiện hữu ([CustomerDirectoryModel](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/models/customer_model.dart), [MasterSavedLocationModel](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/models/master_saved_location_model.dart), [BulkCreateCustomersResult](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/models/customer_model.dart)).

### 17.2. Các Quy Tắc Nghiệp Vụ Đã Cài Đặt & Xác Minh

1. **Khách hàng ([LocalCustomerRepository](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/repositories/local/local_customer_repository.dart)):**
   - **Tạo khách chỉ cần SĐT:** Tự động chuẩn hóa bằng [phone_utils.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/utils/phone_utils.dart). Tên mặc định `"Khách [SĐT]"`, địa chỉ `"Chưa cập nhật địa chỉ"`.
   - **Chống trùng SĐT:** Nếu SĐT đã có trong SQLite, trả về bản ghi khách hiện có với cờ `isExisting: true`, tuyệt đối không tạo trùng lặp.
   - **Xóa mềm an toàn (`deleted_at`):** Từ chối xóa mềm (ném ngoại lệ nghiệp vụ) nếu khách hàng đang nằm trong ca có trạng thái `PREPARING` hoặc `IN_PROGRESS`.
   - **Danh bạ & Tìm kiếm không dấu:** Hỗ trợ phân trang (`limit`, `offset`), tìm không phân biệt dấu/hoa/thường qua cột `search_text LIKE ?`, lọc theo `locationState` (`ALL`, `VERIFIED`, `TEMPORARY`, `NO_LOCATION`), trả về counts (`total`, `verified`, `temporary`, `noLocation`) và đối tượng `CustomerPaginationModel` hoàn toàn tương thích Remote.
   - **Xác định trạng thái vị trí (`locationState`):**
     * `VERIFIED`: Đã có bản ghi trong `saved_locations`.
     * `TEMPORARY`: Chưa có `saved_locations` nhưng có điểm `TEMPORARY` trong ca `PREPARING`/`IN_PROGRESS`.
     * `NO_LOCATION`: Các trường hợp còn lại. (Mô hình Local-First loại bỏ khái niệm "của shipper khác").
   - **Thêm hàng loạt SĐT (`createBulkCustomers`):** Tách danh sách theo ký tự xuống dòng (`\n`, `\r\n`), dấu phẩy (`,`), dấu chấm phẩy (`;`), giữ nguyên khoảng trắng và dấu chấm bên trong số, chuẩn hóa bằng `parseAndNormalizeBulkPhones`, lọc trùng lặp, chặn tối đa 200 số. Toàn bộ lô chạy trong đúng **1 transaction duy nhất**, phân loại thành 3 nhóm: `created`, `alreadyExists`, `rejected` kèm lý do chi tiết. Ghi log vào `activity_log`.

2. **Vị trí ([LocalLocationRepository](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/repositories/local/local_location_repository.dart)):**
   - **Lưu/Cập nhật vị trí đã xác nhận:** Kiểm tra tọa độ hợp lệ (`latitude` trong `[-90, 90]`, `longitude` trong `[-180, 180]`). Thực thi trong transaction: khách đã có vị trí thì `UPDATE` (trigger SQLite tự sinh `location_history`), khách chưa có thì `INSERT` vào `saved_locations`.
   - **Ghim vị trí mới gán cho SĐT bất kỳ:** Nếu SĐT chưa có trong CSDL, tự động tạo khách hàng (chỉ cần SĐT) và lưu vị trí trong **CÙNG 1 transaction**. Nếu lưu vị trí thất bại, giao dịch rollback toàn bộ, không bao giờ để lại bản ghi khách hàng mồ côi.
   - **Xóa vị trí:** Bảo toàn 100% dữ liệu lịch sử trong `location_history` (`saved_location_id` tự động đặt về `NULL` theo khóa ngoại). Các điểm giao `VERIFIED` trong ca `PREPARING`/`IN_PROGRESS` của khách đó tự động chuyển về `NO_LOCATION` (tọa độ về `NULL`). Các điểm `TEMPORARY` giữ nguyên. Ghi `activity_log`.
   - **Xác nhận vị trí qua luồng Danh bạ:** Đồng bộ tức thì các điểm giao trong ca đang mở của khách hàng đó từ `NO_LOCATION`/`TEMPORARY` sang `VERIFIED` theo tọa độ mới (theo quy tắc LOCATION-RULES-012). Ghi số điểm cập nhật vào `activity_log`.
   - **Lịch sử vị trí:** Truy vấn `location_history` theo `customer_id` với thứ tự mới nhất trước (`created_at DESC`).
   - **Dữ liệu bản đồ chính & Bounding Box:** Truy vấn toàn bộ điểm đã lưu `MasterSavedLocationModel` (tạm thời `photoCount = 0`, `photos = []` chờ bước Photos). Hỗ trợ lọc theo khung nhìn bản đồ (`getSavedLocationsInBounds`) qua điều kiện `BETWEEN minLat AND maxLat` và `BETWEEN minLng AND maxLng`.

3. **Bỏ khái niệm khu vực (`areaId`):**
   - Các phương thức liên quan khu vực trả về 1 khu vực ảo mặc định `"Của tôi"` (`local-area-default`) để giữ nguyên giao diện UI cũ không bị vỡ. Sẽ được dọn sạch ở Bước 6.

4. **Công tắc chạy thử Local-First:**
   - [RepositoryProvider.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/repositories/repository_provider.dart) bổ sung cờ `useLocalData` (mặc định `false`, giữ nguyên ứng dụng chạy như cũ).
   - Đọc từ cờ biên dịch `--dart-define=LOCAL_DATA=true` hoặc gán `RepositoryProvider.useLocalData = true`.
   - Khi bật: `customer` và `location` dùng Local SQLite, các nhóm ca/ảnh/chia sẻ/hồ sơ vẫn dùng Remote.
   - Khi chạy chế độ Local, [main.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/main.dart) bỏ qua bước kiểm tra đăng nhập/token mạng, vào thẳng [HomeShellView](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/views/home_shell_view.dart).

### 17.3. Kết Quả Kiểm Thử Thực Tế (Evidence-Based Verification)

- **Phân tích tĩnh & Lints:**
  * Lệnh: `flutter analyze`
  * Kết quả: **No issues found!** (ran in 2.6s)
- **Kiểm thử tự động (In-Memory SQLite FFI, không dùng backend):**
  * Lệnh: `flutter test test/local_first_customer_location_03_test.dart`
  * Kết quả: **11/11 tests passed (100%)**:
    1. Tạo khách hàng chỉ cần SĐT, kiểm tra chống trùng `isExisting: true`: **PASSED**.
    2. Sửa thông tin khách hàng và xóa mềm an toàn (chặn khi có ca active): **PASSED**.
    3. Phân trang Danh bạ, tìm kiếm không dấu và đếm counts: **PASSED**.
    4. Trạng thái vị trí `locationState` đủ 3 trường hợp (VERIFIED, TEMPORARY, NO_LOCATION): **PASSED**.
    5. Bulk thêm SĐT đa định dạng, lọc trùng, giới hạn 200 số trong 1 transaction: **PASSED**.
    6. Lưu & Cập nhật vị trí đã xác nhận, kiểm tra tọa độ hợp lệ, trigger sinh lịch sử: **PASSED**.
    7. Ghim vị trí cho SĐT mới trong 1 transaction (rollback không để khách mồ côi): **PASSED**.
    8. Xóa vị trí bảo toàn lịch sử và hạ điểm VERIFIED trong ca về NO_LOCATION: **PASSED**.
    9. Xác nhận vị trí từ Danh bạ nâng cấp điểm trong ca sang VERIFIED và ghi log: **PASSED**.
    10. Lấy dữ liệu bản đồ chính MasterSavedLocationModel và lọc theo khung nhìn bbox: **PASSED**.
    11. Tương thích dữ liệu UI: Fake vs Local cho ra cùng mô hình dữ liệu: **PASSED**.
- **Toàn bộ bộ kiểm thử Mobile App:**
  * Lệnh: `flutter test`
  * Kết quả: **173/173 tests passed (100%)** (Toàn bộ 162 bài test cũ + 11 bài test mới).
- **Biên dịch gói APK Debug:**
  * Lệnh: `flutter build apk --debug`
  * Kết quả: **Thành công (Built build\app\outputs\flutter-apk\app-debug.apk in 154.3s)**.
- **Trạng Thái Kiểm Thử Thiết Bị Thực Tế:**
  * **ĐÃ TEST trên unit & widget test tự động / CHƯA thử trên điện thoại thật.**

---

## 20. Hoàn Thiện Tinh Chỉnh Giao Diện (Task UI-REFINEMENT-POLISH-FINAL-015)

### 20.1. Các Hạng Mục Đã Xử Lý
1. **Tối ưu RAM Thumbnail Ảnh (P2 - Performance):**
   - Bổ sung `cacheWidth` và `cacheHeight` vào [authenticated_image.dart](mobile_app/lib/shared_widgets/authenticated_image.dart).
   - Truyền `cacheWidth: 300` trong [photo_strip_item.dart](mobile_app/lib/features/photos/photo_strip_item.dart) và `cacheWidth: 150` trong [customer_list_item.dart](mobile_app/lib/features/directory/widgets/customer_list_item.dart).
2. **Thích Ứng Tablet Màn Hình Rộng (P2 - Adaptivity):**
   - Trong [home_shell_view.dart](mobile_app/lib/home_shell_view.dart): Tự động phát hiện màn hình rộng (`width >= 600dp`). Chuyển sang thanh điều hướng dọc `NavigationRail` ở cạnh trái kết hợp `VerticalDivider`, ẩn `bottomNavigationBar`.
3. **Đồng Bộ Màu Bề Mặt Card (P2 - Theming):**
   - Rà soát và loại bỏ các mã màu cứng (`Colors.white`) trong [point_detail_bottom_sheet.dart](mobile_app/lib/shared_widgets/point_detail_bottom_sheet.dart), [customer_list_item.dart](mobile_app/lib/features/directory/widgets/customer_list_item.dart), [customer_detail_edit_view.dart](mobile_app/lib/features/directory/customer_detail_edit_view.dart), [customer_detail_location_card.dart](mobile_app/lib/features/directory/widgets/customer_detail_location_card.dart), và [crosshair_bottom_panel.dart](mobile_app/lib/features/map/widgets/crosshair_bottom_panel.dart).
   - Áp dụng các token chuẩn Material 3: `colorScheme.surface`, `onSurface`, `onSurfaceVariant`, `surfaceContainerHighest`.
4. **Phản Hồi Rung Haptic (P3 - Delight):**
   - Trong [crosshair_location_picker_view.dart](mobile_app/lib/features/map/crosshair_location_picker_view.dart): Bổ sung `HapticFeedback.selectionClick()` khi di chuyển tâm ngắm và `HapticFeedback.mediumImpact()` khi xác nhận ghim vị trí.
5. **Typography & Material Elevation (P3):**
   - Nâng cỡ chữ ghi chú trong [point_detail_bottom_sheet.dart](mobile_app/lib/shared_widgets/point_detail_bottom_sheet.dart) lên `fontSize: 14`.
   - Chuyển bóng đổ tùy chỉnh sang `Material(elevation: 8)`.

### 20.2. Bằng Chứng Kiểm Thử
- `flutter analyze`: **No issues found!**
- `flutter test`: **182/182 tests passed!** (100% test suites).
- Giới hạn dòng: Tất cả các file trong `lib/` đều $\le 350$ dòng (dài nhất là `point_detail_bottom_sheet.dart` với 342 dòng).

---

## 18. Tiến Độ Local-First: Tầng Repository Cục Bộ Ca Làm Việc & Dán Hàng Loạt (TASK: LOCAL-FIRST-04-LOCAL-SHIFTS-AND-BULK)

### 18.1. Bối Cảnh & Mục Tiêu Nghiệp Vụ
- Tiếp nối việc triển khai Local Customer & Location Repositories (Task 03), Task 04 hoàn thiện toàn bộ tầng truy xuất dữ liệu cục bộ cho phân hệ **Ca làm việc, điểm giao trong ca và dán hàng loạt số điện thoại** ([LocalShiftRepository](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/repositories/local/local_shift_repository.dart)).
- Giữ nguyên hợp đồng [ShiftRepository](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/repositories/shift_repository.dart) và các Data Model hiện hữu ([ShiftModel](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/models/shift_model.dart), [ShiftDeliveryPointModel](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/models/shift_model.dart), [BulkAddPointsResult](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/models/shift_model.dart), [OrderModel](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/models/order_model.dart)).

### 18.2. Các Quy Tắc Nghiệp Vụ Đã Cài Đặt & Xác Minh

1. **Quản lý Ca làm việc ([LocalShiftRepository](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/repositories/local/local_shift_repository.dart)):**
   - **Sinh mã ca (`shift_code`):** Chuẩn `SHF-YYYYMMDD-XXX` theo giờ Việt Nam (UTC+7), `XXX` tự động tăng dần theo ngày (`001`, `002`...) và tự động reset về `001` khi chuyển sang ngày làm việc mới.
   - **Tên ca (`shift_name`):** Tùy chọn, tự động cắt khoảng trắng, giới hạn tối đa 100 ký tự. Nếu không nhập tên, hệ thống tự động suy luận `"Ca sáng/chiều/tối dd/MM"` và bổ sung `" (2)"`, `" (3)"` nếu bị trùng tên trong cùng một ngày.
   - **Thống kê tóm tắt (`summary`):** Mỗi ca được tính toán trực tiếp từ `shift_delivery_points` (`totalPoints`, `verifiedCount`, `temporaryCount`, `noLocationCount`). Danh sách ca sắp xếp mới nhất trước (`work_date DESC, created_at DESC`).
   - **Đổi tên ca:** Hỗ trợ đổi tên ca linh hoạt, từ chối tên rỗng, ghi nhận `activity_log` với action `UPDATE_SHIFT_NAME`.
   - **Quy trình trạng thái (`PREPARING -> IN_PROGRESS -> COMPLETED`):**
     * `PREPARING -> IN_PROGRESS`: Ghi nhận thời điểm bắt đầu ca `started_at = now`.
     * `IN_PROGRESS -> COMPLETED`: Ghi nhận thời điểm hoàn thành ca `completed_at = now`.
     * Ràng buộc chặt chẽ: Chặn tuyệt đối chuyển sai thứ tự (`PREPARING -> COMPLETED` hoặc `IN_PROGRESS -> PREPARING`) và chặn sửa trạng thái khi ca đã `COMPLETED`.
   - **Xóa ca làm việc:** Cascade xóa các điểm giao của ca trong `shift_delivery_points`. TUYỆT ĐỐI KHÔNG xóa khách hàng, vị trí đã lưu và lịch sử vị trí. Ca đang `IN_PROGRESS` vẫn xóa được bình thường. Ghi `activity_log` action `DELETE_SHIFT`.

2. **Điểm giao trong ca:**
   - **Thêm điểm (`addPointToShift`):** Hỗ trợ thêm bằng `customerId` hoặc `phoneNumber`. Nếu SĐT chưa có trong CSDL, tự động tạo khách hàng nhanh (`"Khách [SĐT]"`, `"Chưa cập nhật địa chỉ"`). Điểm giao tự động kế thừa tọa độ và trạng thái `VERIFIED` nếu khách đã có vị trí lưu, hoặc `NO_LOCATION` nếu chưa có.
   - **Chống trùng lặp:** Nếu khách hàng đã có trong ca, trả về `isExisting: true` và không thêm bản ghi trùng, `delivery_order_index` giữ nguyên.
   - **Ghim tạm (`TEMPORARY`):** Cập nhật tọa độ ghim tạm trực tiếp trên `shift_delivery_points`, TUYỆT ĐỐI KHÔNG ghi đè vào `saved_locations`. Nếu điểm trước đó là `VERIFIED` mà ghim tạm lại trong ca, trạng thái trong ca chuyển sang `TEMPORARY` với tọa độ mới trong khi `saved_locations` vẫn giữ nguyên vẹn tọa độ và ghi chú gốc. Đồng thời đồng bộ sang các ca `PREPARING` / `IN_PROGRESS` khác chứa cùng khách hàng và ghi `PIN_TEMPORARY_LOCATION`.
   - **Hoàn tác thêm điểm (`removePointFromShift`):** Nút `HOÀN TÁC` trên SnackBar của Danh bạ xóa chính xác bản ghi vừa thêm khỏi ca và cập nhật lại summary.
   - **Hàm `verifyPointLocation` trong ca:** Giữ trạng thái ngừng hoạt động theo đúng quy chuẩn `LOCATION-RULES-012`, ném lỗi `UnsupportedError` thông báo vị trí chuẩn chỉ được xác nhận qua luồng Danh bạ.

3. **Dán hàng loạt SĐT vào ca (`addBulkPointsToShift`):**
   - Tái sử dụng hàm phân tách số chung `parseAndNormalizeBulkPhones` trong [phone_utils.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/utils/phone_utils.dart) (hỗ trợ xuống dòng, dấu phẩy, chấm phẩy, khoảng trắng/dấu chấm trong số).
   - Chặn nghiêm ngặt danh sách vượt quá 200 số.
   - Thực thi trọn vẹn trong **ĐÚNG 1 transaction duy nhất cho cả lô**: Đảm bảo tính toàn vẹn (Atomicity), nếu có lỗi giữa chừng sẽ rollback toàn bộ, không bao giờ để lại khách mồ côi hay lô dán nửa vời.
   - Phân loại chính xác 4 nhóm: `added` (kèm `VERIFIED` hoặc `NO_LOCATION`), `alreadyInShift`, `rejected` (kèm lý do và thông báo), và `summary`.
   - Ghi ĐÚNG 1 dòng nhật ký `activity_log` với action `BULK_ADD_POINTS` cho cả lô.

4. **Tương thích ngược đơn hàng (`OrderModel`):**
   - `getMyShiftOrders()` và `addOrderToShift()` ánh xạ trực tiếp từ các điểm giao trong ca đang mở (`IN_PROGRESS` / `PREPARING`) sang danh sách `OrderModel`, đảm bảo các màn hình cũ tiếp tục hoạt động mà không lỗi runtime.

5. **Mở rộng công tắc `RepositoryProvider.useLocalData`:**
   - Khi `useLocalData = true`: `customer`, `location`, và `shift` đồng thời trỏ về Local SQLite. `photo`, `sharing`, `profile` vẫn giữ Remote.
   - Mặc định: `useLocalData = false`.

### 18.3. Kết Quả Kiểm Thử Thực Tế (Evidence-Based Verification)

- **Phân tích tĩnh & Lints:**
  * Lệnh: `flutter analyze`
  * Kết quả: **No issues found!** (ran in 1.5s)
- **Kiểm thử tự động chuyên sâu ([local_first_shift_bulk_04_test.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/test/local_first_shift_bulk_04_test.dart)):**
  * Lệnh: `flutter test test/local_first_shift_bulk_04_test.dart`
  * Kết quả: **15/15 tests passed (100%)**:
    1. `RepositoryProvider toggle useLocalData chuyển đổi chính xác ShiftRepository sang LocalShiftRepository`: **PASSED**.
    2. `Tạo ca có tên (trim, max 100 ký tự) và tạo ca không tên tự gợi ý "Ca sáng/chiều/tối dd/MM"`: **PASSED**.
    3. `Mã ca tăng đúng (SHF-YYYYMMDD-001, 002), reset khi sang ngày khác; trùng tên trong ngày thêm (2), (3)`: **PASSED**.
    4. `getShifts & getShiftDetail: danh sách ca kèm summary, mới nhất trước; chi tiết ca đầy đủ điểm giao`: **PASSED**.
    5. `updateShiftName: Đổi tên ca thành công, từ chối tên rỗng, cập nhật CSDL và ghi activity_log`: **PASSED**.
    6. `updateShiftStatus: chuyển trạng thái đúng thứ tự PREPARING -> IN_PROGRESS -> COMPLETED, chặn sai thứ tự`: **PASSED**.
    7. `deleteShift: xóa ca cascade xóa điểm giao; TUYỆT ĐỐI KHÔNG xóa khách hay vị trí; ca IN_PROGRESS vẫn xóa được`: **PASSED**.
    8. `addPointToShift: 3 trường hợp (khách có vị trí -> VERIFIED, chưa có vị trí -> NO_LOCATION, SĐT mới -> tự tạo khách)`: **PASSED**.
    9. `addPointToShift: chống trùng lặp trả isExisting=true và không tạo dòng mới`: **PASSED**.
    10. `updateTemporaryLocation: ghim tạm chỉ ghi vào shift_delivery_points, KHÔNG ghi saved_locations`: **PASSED**.
    11. `addBulkPointsToShift: tách số đa định dạng, lọc trùng, chặn > 200 số, trả đủ 4 nhóm, ghi 1 activity_log`: **PASSED**.
    12. `addBulkPointsToShift: tính toàn vẹn transaction (lỗi giữa lô rollback 100%, không để lại dữ liệu nửa vời)`: **PASSED**.
    13. `removePointFromShift (Hoàn tác): xóa đúng điểm vừa thêm và cập nhật summary chính xác`: **PASSED**.
    14. `verifyPointLocation: ném UnsupportedError thông báo chuyển hướng sang Danh bạ`: **PASSED**.
    15. `Compatibility: getMyShiftOrders và addOrderToShift ánh xạ mượt mà từ SQLite sang OrderModel`: **PASSED**.
- **Toàn bộ bộ kiểm thử Mobile App:**
  * Lệnh: `flutter test`
  * Kết quả: **199/199 tests passed (100%)** (Toàn bộ 188 bài test cũ + 11 bài test mới, 0 regressions).
- **Trạng Thái Kiểm Thử Thiết Bị Thực Tế:**
  * **ĐÃ TEST trên unit & widget test tự động / CHƯA thử trên điện thoại thật.**

---

## 20. Hoàn Thiện Tinh Chỉnh Giao Diện (Task UI-REFINEMENT-POLISH-FINAL-015)

### 20.1. Các Hạng Mục Đã Xử Lý
1. **Tối ưu RAM Thumbnail Ảnh (P2 - Performance):**
   - Bổ sung `cacheWidth` và `cacheHeight` vào [authenticated_image.dart](mobile_app/lib/shared_widgets/authenticated_image.dart).
   - Truyền `cacheWidth: 300` trong [photo_strip_item.dart](mobile_app/lib/features/photos/photo_strip_item.dart) và `cacheWidth: 150` trong [customer_list_item.dart](mobile_app/lib/features/directory/widgets/customer_list_item.dart).
2. **Thích Ứng Tablet Màn Hình Rộng (P2 - Adaptivity):**
   - Trong [home_shell_view.dart](mobile_app/lib/home_shell_view.dart): Tự động phát hiện màn hình rộng (`width >= 600dp`). Chuyển sang thanh điều hướng dọc `NavigationRail` ở cạnh trái kết hợp `VerticalDivider`, ẩn `bottomNavigationBar`.
3. **Đồng Bộ Màu Bề Mặt Card (P2 - Theming):**
   - Rà soát và loại bỏ các mã màu cứng (`Colors.white`) trong [point_detail_bottom_sheet.dart](mobile_app/lib/shared_widgets/point_detail_bottom_sheet.dart), [customer_list_item.dart](mobile_app/lib/features/directory/widgets/customer_list_item.dart), [customer_detail_edit_view.dart](mobile_app/lib/features/directory/customer_detail_edit_view.dart), [customer_detail_location_card.dart](mobile_app/lib/features/directory/widgets/customer_detail_location_card.dart), và [crosshair_bottom_panel.dart](mobile_app/lib/features/map/widgets/crosshair_bottom_panel.dart).
   - Áp dụng các token chuẩn Material 3: `colorScheme.surface`, `onSurface`, `onSurfaceVariant`, `surfaceContainerHighest`.
4. **Phản Hồi Rung Haptic (P3 - Delight):**
   - Trong [crosshair_location_picker_view.dart](mobile_app/lib/features/map/crosshair_location_picker_view.dart): Bổ sung `HapticFeedback.selectionClick()` khi di chuyển tâm ngắm và `HapticFeedback.mediumImpact()` khi xác nhận ghim vị trí.
5. **Typography & Material Elevation (P3):**
   - Nâng cỡ chữ ghi chú trong [point_detail_bottom_sheet.dart](mobile_app/lib/shared_widgets/point_detail_bottom_sheet.dart) lên `fontSize: 14`.
   - Chuyển bóng đổ tùy chỉnh sang `Material(elevation: 8)`.

### 20.2. Bằng Chứng Kiểm Thử
- `flutter analyze`: **No issues found!**
- `flutter test`: **182/182 tests passed!** (100% test suites).
- Giới hạn dòng: Tất cả các file trong `lib/` đều $\le 350$ dòng (dài nhất là `point_detail_bottom_sheet.dart` với 342 dòng).

---

## 19. TASK: LOCAL-FIRST-05-LOCAL-PHOTOS (Quản Lý Ảnh Cục Bộ & Thích Ứng Widget)

### 19.1. Khảo Sát & Phân Tích
Đã khảo sát và đọc kỹ:
- Interface [photo_repository.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/repositories/photo_repository.dart) và [remote_photo_repository.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/repositories/remote/remote_photo_repository.dart).
- Dữ liệu model [customer_photo_model.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/models/customer_photo_model.dart).
- Bảng CSDL `customer_photos` trong [app_database.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/local/app_database.dart).
- Các widget hiển thị ảnh: [authenticated_image.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/widgets/authenticated_image.dart), [customer_photos_strip_widget.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/widgets/customer_photos_strip_widget.dart), [fullscreen_image_viewer.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/widgets/fullscreen_image_viewer.dart), [point_detail_bottom_sheet.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/widgets/point_detail_bottom_sheet.dart).

### 19.2. Kiến Trúc & Triển Khai Thực Tế

1. **Lưu trữ tệp ảnh an toàn & Bảo vệ quyền riêng tư ([LocalPhotoRepository](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/repositories/local/local_photo_repository.dart)):**
   - **Thư mục riêng:** Tệp được lưu tại `getApplicationDocumentsDirectory() / photos` và thumbnail tại `/photos/thumbs`. Tuyệt đối không lưu vào thư mục chia sẻ công khai hay thư viện ảnh chung của thiết bị.
   - **Tên file UUID ngẫu nhiên:** Định dạng `<uuid>.jpg` và `<uuid>_thumb.jpg`. Tuyệt đối không chứa số điện thoại hay họ tên khách hàng trong tên tệp hoặc đường dẫn.
   - **Đường dẫn tương đối trong CSDL:** Cột `file_name` và `thumb_file_name` trong bảng `customer_photos` chỉ lưu tên file tương đối, giúp ứng dụng không bị mất liên kết ảnh khi hệ điều hành thay đổi đường dẫn sandbox sau cập nhật.
   - **Kiểm tra Magic Bytes:** Xác thực định dạng thật của tệp (JPEG: `FF D8 FF`, PNG: `89 50 4E 47 0D 0A 1A 0A`, WebP: `RIFF...WEBP`). Từ chối các tệp sai định dạng.
   - **Giới hạn an toàn:** Chặn file lớn hơn 5MB; giới hạn tối đa 10 ảnh mặt tiền chưa xóa mềm cho mỗi khách hàng.
   - **Nén ảnh & Thumbnail:** Nén cạnh dài <= 1600px quality ~80 và tạo thumbnail cạnh dài ~300px quality 75. Khi chạy trên app dùng `compute` trong isolate riêng để giữ 60fps UI; trong môi trường test thực thi trực tiếp tránh isolate deadlock.
   - **Tính toàn vẹn (Atomic Rollback):** Nếu thao tác ghi vào SQLite thất bại, tệp vừa ghi trên đĩa sẽ bị xóa ngay lập tức, không để lại file mồ côi.

2. **Xóa mềm (Soft Delete) & Cơ chế Purge tự động:**
   - Khi xóa ảnh (`deleteCustomerPhoto`), gán `deleted_at = now` trong SQLite, file trên đĩa được giữ nguyên tạm thời và ghi nhận `DELETE_CUSTOMER_PHOTO` trong `activity_log`.
   - Cơ chế `purgeDeletedPhotosOlderThan` quét các ảnh có `deleted_at` quá 30 ngày: Xóa file ảnh gốc, xóa thumbnail trên đĩa, xóa dòng bản ghi trong SQLite và ghi `PURGE_EXPIRED_PHOTOS` vào `activity_log`.
   - Trong [main.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/main.dart), quá trình kiểm tra đăng nhập tự động kích hoạt lệnh dọn dẹp chạy nền không chặn giao diện.

3. **Thích ứng các Widget giao diện:**
   - [authenticated_image.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/widgets/authenticated_image.dart): Nhận diện `isLocal == 'true'` hoặc URL tệp cục bộ (`file://` hoặc đường dẫn tuyệt đối), render trực tiếp bằng `Image.file(File(filePath))` kèm `cacheWidth` và `cacheHeight` tối ưu hóa RAM. Giữ nguyên `Image.network` khi ở chế độ Remote.
   - [fullscreen_image_viewer.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/widgets/fullscreen_image_viewer.dart): Hỗ trợ phóng to thu nhỏ cảm ứng (zoom 0.8x đến 5.0x) và vuốt gallery nhiều ảnh cho cả ảnh cục bộ (`Image.file`) và ảnh từ xa (`Image.network`).
   - [customer_photos_strip_widget.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/widgets/customer_photos_strip_widget.dart): Nút `+ THÊM ẢNH` chuẩn kích thước vùng chạm `>= 56px`. Thao tác 1 chạm trực tiếp mở Camera (`ImageSource.camera`) để shipper chụp nhanh tại hiện trường; nhấn giữ mở menu chọn từ Thư viện (`ImageSource.gallery`). Chạm vào ảnh mở Fullscreen Gallery, nhấn giữ vào ảnh mở hộp thoại xác nhận xóa.

4. **Đồng bộ hóa dữ liệu Danh bạ, Bản đồ chính và Ca làm việc:**
   - [LocalCustomerRepository](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/repositories/local/local_customer_repository.dart): Tự động đếm `photoCount` và nạp 3 ảnh thumbnail đầu tiên vào [CustomerDirectoryModel](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/models/customer_model.dart).
   - [LocalLocationRepository](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/repositories/local/local_location_repository.dart): Tự động nạp `photoCount` và 3 ảnh thumbnail vào [MasterSavedLocationModel](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/models/master_saved_location_model.dart).
   - [LocalShiftRepository](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/repositories/local/local_shift_repository.dart): Tự động nạp `photoCount` và 3 ảnh thumbnail vào [ShiftDeliveryPointModel](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/models/shift_model.dart) cho mỗi điểm giao trong ca.

5. **Mở rộng công tắc `RepositoryProvider.useLocalData`:**
   - Khi `useLocalData = true`: `customer`, `location`, `shift`, `photo` đồng thời chuyển sang Local SQLite. `sharing` và `profile` vẫn trỏ về Remote.
   - Mặc định: `useLocalData = false`.

### 19.3. Bằng Chứng Kiểm Thử Thực Tế (Evidence-Based Verification)

- **Phân tích mã nguồn (Static Analysis):**
  * Lệnh: `flutter analyze`
  * Kết quả: **No issues found!** (ran in 1.7s).
- **Bộ kiểm thử chuyên sâu Task 05 ([local_first_photo_05_test.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/test/local_first_photo_05_test.dart)):**
  * Lệnh: `flutter test test/local_first_photo_05_test.dart`
  * Kết quả: **11/11 tests passed (100%)**:
    1. `RepositoryProvider toggle useLocalData chuyển đổi chính xác PhotoRepository`: **PASSED**.
    2. `Thêm ảnh hợp lệ (JPEG, PNG) - nén cạnh dài <= 1600px, tạo thumbnail ~300px, ghi CSDL và lưu file UUID`: **PASSED**.
    3. `Kiểm tra định dạng Magic Bytes: từ chối file sai định dạng`: **PASSED**.
    4. `Kiểm tra giới hạn dung lượng tối đa 5MB`: **PASSED**.
    5. `Giới hạn tối đa 10 ảnh/khách hàng`: **PASSED**.
    6. `Lỗi ghi DB thì file vừa tạo bị xóa dọn sạch (không để lại file mồ côi)`: **PASSED**.
    7. `Xóa mềm (deleted_at) giữ file; dọn sau 30 ngày xóa sạch file & CSDL`: **PASSED**.
    8. `photoCount và 3 ảnh đầu đúng; hai khách hàng không lẫn ảnh của nhau`: **PASSED**.
    9. `Đồng bộ photoCount và 3 ảnh đầu sang CustomerRepository, LocationRepository và ShiftRepository`: **PASSED**.
    10. `Widget AuthenticatedImage hiển thị ảnh cục bộ qua Image.file`: **PASSED**.
    11. `CustomerPhotosStripWidget: Nút thêm ảnh >= 56px, chạm mở camera, hiển thị dải ảnh, chạm xem fullscreen`: **PASSED**.
- **Toàn bộ bộ kiểm thử tự động Mobile App:**
  * Lệnh: `flutter test`
  * Kết quả: **199/199 tests passed (100%)** (Bảo toàn 100% các bộ kiểm thử cũ, không phát sinh bất kỳ hồi quy nào).
- **Biên dịch gói APK Debug:**
  * Lệnh: `flutter build apk --debug`
- **Trạng Thái Kiểm Thử Thiết Bị Thực Tế:**
  * **ĐÃ TEST trên unit & widget test tự động / CHƯA thử trên điện thoại thật.**

---

## 20. Hoàn Thiện Tinh Chỉnh Giao Diện (Task UI-REFINEMENT-POLISH-FINAL-015)

### 20.1. Các Hạng Mục Đã Xử Lý
1. **Tối ưu RAM Thumbnail Ảnh (P2 - Performance):**
   - Bổ sung `cacheWidth` và `cacheHeight` vào [authenticated_image.dart](mobile_app/lib/shared_widgets/authenticated_image.dart).
   - Truyền `cacheWidth: 300` trong [photo_strip_item.dart](mobile_app/lib/features/photos/photo_strip_item.dart) và `cacheWidth: 150` trong [customer_list_item.dart](mobile_app/lib/features/directory/widgets/customer_list_item.dart).
2. **Thích Ứng Tablet Màn Hình Rộng (P2 - Adaptivity):**
   - Trong [home_shell_view.dart](mobile_app/lib/home_shell_view.dart): Tự động phát hiện màn hình rộng (`width >= 600dp`). Chuyển sang thanh điều hướng dọc `NavigationRail` ở cạnh trái kết hợp `VerticalDivider`, ẩn `bottomNavigationBar`.
3. **Đồng Bộ Màu Bề Mặt Card (P2 - Theming):**
   - Rà soát và loại bỏ các mã màu cứng (`Colors.white`) trong [point_detail_bottom_sheet.dart](mobile_app/lib/shared_widgets/point_detail_bottom_sheet.dart), [customer_list_item.dart](mobile_app/lib/features/directory/widgets/customer_list_item.dart), [customer_detail_edit_view.dart](mobile_app/lib/features/directory/customer_detail_edit_view.dart), [customer_detail_location_card.dart](mobile_app/lib/features/directory/widgets/customer_detail_location_card.dart), và [crosshair_bottom_panel.dart](mobile_app/lib/features/map/widgets/crosshair_bottom_panel.dart).
   - Áp dụng các token chuẩn Material 3: `colorScheme.surface`, `onSurface`, `onSurfaceVariant`, `surfaceContainerHighest`.
4. **Phản Hồi Rung Haptic (P3 - Delight):**
   - Trong [crosshair_location_picker_view.dart](mobile_app/lib/features/map/crosshair_location_picker_view.dart): Bổ sung `HapticFeedback.selectionClick()` khi di chuyển tâm ngắm và `HapticFeedback.mediumImpact()` khi xác nhận ghim vị trí.
5. **Typography & Material Elevation (P3):**
   - Nâng cỡ chữ ghi chú trong [point_detail_bottom_sheet.dart](mobile_app/lib/shared_widgets/point_detail_bottom_sheet.dart) lên `fontSize: 14`.
   - Chuyển bóng đổ tùy chỉnh sang `Material(elevation: 8)`.

### 20.2. Bằng Chứng Kiểm Thử
- `flutter analyze`: **No issues found!**
- `flutter test`: **182/182 tests passed!** (100% test suites).
- Giới hạn dòng: Tất cả các file trong `lib/` đều $\le 350$ dòng (dài nhất là `point_detail_bottom_sheet.dart` với 342 dòng).




---

## 20. Ho�n Thi?n Tinh Ch?nh Giao Di?n (Task UI-REFINEMENT-POLISH-FINAL-015)

### 20.1. C�c H?ng M?c �� X? L�
1. **T?i uu RAM Thumbnail ?nh (P2 - Performance):**
   - B? sung cacheWidth v� cacheHeight v�o authenticated_image.dart.
   - Truy?n cacheWidth: 300 trong photo_strip_item.dart v� cacheWidth: 150 trong customer_list_item.dart.
2. **Th�ch ?ng Tablet M�n H�nh R?ng (P2 - Adaptivity):**
   - Trong home_shell_view.dart: T? d?ng ph�t hi?n m�n h�nh r?ng (width >= 600dp). Chuy?n sang thanh di?u hu?ng d?c NavigationRail ? c?nh tr�i k?t h?p VerticalDivider, ?n bottomNavigationBar.
3. **�?ng B? M�u B? M?t Card (P2 - Theming):**
   - R� so�t v� lo?i b? c�c m� m�u c?ng (Colors.white) trong point_detail_bottom_sheet.dart, customer_list_item.dart, customer_detail_edit_view.dart, customer_detail_location_card.dart, v� crosshair_bottom_panel.dart.
   - �p d?ng c�c token chu?n Material 3: colorScheme.surface, onSurface, onSurfaceVariant, surfaceContainerHighest.
4. **Ph?n H?i Rung Haptic (P3 - Delight):**
   - Trong crosshair_location_picker_view.dart: B? sung HapticFeedback.selectionClick() khi di chuy?n t�m ng?m v� HapticFeedback.mediumImpact() khi x�c nh?n ghim v? tr�.
5. **Typography & Material Elevation (P3):**
   - N�ng c? ch? ghi ch� trong point_detail_bottom_sheet.dart l�n fontSize: 14.
   - Chuy?n b�ng d? t�y ch?nh sang Material(elevation: 8).

### 20.2. B?ng Ch?ng Ki?m Th?
- flutter analyze: No issues found!
- flutter test: 182/182 tests passed! (100% test suites).
- Gi?i h?n d�ng: T?t c? c�c file trong lib/ d?u <= 350 d�ng (d�i nh?t l� point_detail_bottom_sheet.dart v?i 342 d�ng).











---

## 21. Lột Xác Thiết Kế Thực Địa & Diệt AI Slop (Task IMPECCABLE-BOLDER-018)

### 21.1. Các Cải Tiến Thiết Kế Công Thái Học Thực Địa (Industrial Ergonomics)
1. **Triệt tiêu Anti-Patterns & AI Slop:**
   - Xóa bỏ toàn bộ các ô vuông bo góc màu pastel bao bọc icon (`rounded-square pastel icon tiles`) trên màn Cá nhân, Ca làm việc, Danh bạ. Icon được hiển thị trực tiếp với màu nhấn rõ ràng (`accent colors`).
   - Đập bỏ cấu trúc card bo tròn 16dp tù túng lồng nhau; chuyển sang bố cục phẳng ngăn cách bằng khoảng trắng (whitespace), tiêu đề nhóm chữ in hoa kỹ thuật (`11sp, FontWeight.w800, letterSpacing: 1.2`) và đường hairline 1px.
   - Áp dụng `FontFeature.tabularFigures()` cho toàn bộ con số thống kê, số điện thoại, số điểm giao, mã ca làm việc, ngày tháng và tọa độ địa lý để hiển thị thẳng hàng, chính xác như thiết bị đo đạc thực địa.
2. **Tab Cá Nhân (Profile):**
   - Khối thống kê: Chuyển đổi thành dải đo lường thực địa liền mạch (Telemetry Strip) 3 cột ngăn cách bằng `VerticalDivider` 1px, số hiển thị cực đại 28sp `FontWeight.w900` với tabular figures.
   - Khối chức năng: Thiết kế thành các hàng điều khiển phẳng sắc gọn (`Control Rows`), bọc trong `Material` chuẩn tránh lỗi assertion hiển thị.
3. **Tab Ca Làm Việc (Shifts):**
   - Thẻ ca làm việc biến thành phiếu điều vận thực địa ("Dispatch Tickets") với vạch chỉ thị trạng thái 4dp ở cạnh trái (Vàng amber: đang chuẩn bị, Xanh dương: đang thực hiện, Xanh lá: hoàn tất, Đỏ: đã hủy).
   - Phân cấp 2 dòng rõ ràng: Dòng 1 tiêu đề ca (15sp Bold), Dòng 2 mã ca + ngày tháng + huy hiệu trạng thái kỹ thuật (hairline border, tabular figures).
   - Thẻ ca đang thực hiện (`ShiftInProgressCard`): Giữ nguyên tiến độ, tóm tắt và 2 nút hành động bản lớn 48dp.
4. **Tab Danh Bạ (Directory):**
   - Thanh lọc chuyển thành thanh tab xúc giác kỹ thuật ("Tactile Segmented Tabs") với góc bo 8dp, chiều cao 38dp, trạng thái chọn có độ tương phản cao, số lượng hiển thị với `FontFeature.tabularFigures()`.
   - Dòng khách hàng (`CustomerListItemWidget`): Nhấn mạnh số điện thoại 15sp `FontWeight.w800` với tabular figures, nút "+" bo vuông kỹ thuật 40x40dp chuẩn công thái học thực địa.
   - Ô tìm kiếm và bộ đếm tổng số: Bo góc 10dp, viền hairline 1px, huy hiệu đếm tabular figures.

### 21.2. Bằng Chứng Kiểm Thử & Kiểm Soát Mã Nguồn
- **Phân tích tĩnh:** `flutter analyze` $\to$ **No issues found!** (0 errors, 0 warnings, 0 infos).
- **Kiểm thử tự động:** `flutter test` $\to$ **182/182 tests passed!** (100% 26 test suites xanh).
- **Kiểm soát dung lượng file:** 100% các tệp trong `mobile_app/lib/` đều $\le 350$ dòng code.
- **Git Commit:** `203d706` trên nhánh `ui-redesign`.
