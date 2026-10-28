# Project History & Legacy Technical Debt Log

> **Tài liệu lưu trữ lịch sử phát triển, các giai đoạn kiểm toán (Audit) và các task phiên bản có máy chủ.**  
> **Trạng thái hiện tại của bản nộp app-only:** Xem [docs/CURRENT_STATE.md](docs/CURRENT_STATE.md).

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

30. **[ĐÃ HOÀN TẤT - TASK: SHIFT-DELETE-AND-FIELD-FIX-011] Bổ sung API Xóa Ca Làm Việc & Thống Nhất Tên Trường Dữ Liệu:**
    - **1. Chức năng Xóa Ca Làm Việc (`DELETE /api/v1/shifts/:id`):**
      - *Phân quyền an toàn:* Shipper chỉ được xóa ca do chính mình phụ trách (`shift.shipper_id === shipperId`), mọi hành vi xóa ca của shipper khác đều bị từ chối `403 Forbidden`. Tài khoản `ADMIN` có toàn quyền xóa bất kỳ ca làm việc nào.
      - *Phạm vi dữ liệu cách ly tuyệt đối:* Xóa ca (`shifts`) và toàn bộ điểm giao trong ca (`shift_delivery_points`). **TUYỆT ĐỐI KHÔNG** đụng chạm hay làm mất bất kỳ bản ghi nào trong `customers`, `saved_locations` và `location_history`. Vị trí khách hàng đã xác minh luôn được bảo tồn vĩnh viễn.
      - *Toàn vẹn kiểm toán:* Tự động ghi nhật ký `audit_logs` với `action: 'DELETE_SHIFT'`, `entity: 'shifts'`, kèm metadata `{ shiftCode, status, deletedPointsCount }`.
      - *Giao diện Mobile ([shift_list_view.dart](file:///d:/flutter create delivery_marker_app/mobile_app/lib/views/shift_list_view.dart)):* Thêm nút icon thùng rác màu đỏ (`Icons.delete_outline_rounded`) trên mỗi thẻ ca. Khi bấm, mở hộp thoại cảnh báo: 'Xóa ca [mã ca]? Các điểm giao trong ca sẽ bị hủy, vị trí khách đã lưu không bị mất.' Sau khi người dùng xác nhận, gọi [ApiService.deleteShift](file:///d:/flutter create delivery_marker_app/mobile_app/lib/services/api_service.dart), hiển thị SnackBar thông báo và tự động tải lại danh sách ca.
    - **2. Thống nhất tên trường dữ liệu giữa Flutter và Backend (Field Name Unification):**
      - *createShift:* Backend [shifts.controller.ts](file:///d:/flutter create delivery_marker_app/backend/src/controllers/shifts.controller.ts) và Flutter [api_service.dart](file:///d:/flutter create delivery_marker_app/mobile_app/lib/services/api_service.dart) chấp nhận cả `shiftDate` và `workDate` hoán đổi mềm dẻo. Response trả về cả `shiftDate` và `workDate`.
      - *addPointToShift:* Backend bổ sung tính toán và trả về đối tượng `summary: { totalPoints, verifiedCount, temporaryCount, noLocationCount }` ở cả trường hợp thêm mới điểm (201) và trường hợp khách đã có trong ca (200), khớp hoàn hảo với `ShiftSummaryModel.fromJson(body['summary'])` của Flutter.
      - *updateTemporaryLocation & verifyPointLocation:* Backend và Flutter đồng bộ nhận cả `locationNotes` lẫn `identificationNotes`, và nhận cả `photoUrl`, `imageUrl`, lẫn `imageBase64`. Response trả về đầy đủ các trường alias giúp hai phía luôn đồng bộ.
    - **3. Kết quả kiểm thử thực tế (Evidence-Based):**
      - Backend Unit Tests: **96/96 tests passed (100%)** qua 5 test suites (bổ sung 10 unit test mới trong [shifts.spec.ts](file:///d:/flutter create delivery_marker_app/backend/test/shifts.spec.ts)).
      - Backend Build: `npm run build` (`tsc`) biên dịch thành công 100% (**Exit Code: 0**).
      - Flutter Analyze: `flutter analyze` báo cáo: **No issues found!** (0 warning, 0 error).
      - Flutter Unit & Widget Tests: **65/65 tests passed (100%)** (bổ sung 4 unit test trong [shift_delete_and_field_fix_011_test.dart](file:///d:/flutter create delivery_marker_app/mobile_app/test/shift_delete_and_field_fix_011_test.dart)).
      - Live API Integration: Xác minh trực tiếp trên container `delivery_backend_api` và database PostGIS `delivery_postgis_db`: Xóa ca thành công, điểm giao bị hủy, bản ghi audit log `DELETE_SHIFT` được lưu. (Lưu ý: Sự cố thay đổi vị trí KH_001 trong ca test đã được xử lý khôi phục trong Task FIX-TEST-DATA-011B).

31. **[ĐÃ HOÀN TẤT - TASK: FIX-TEST-DATA-011B] Khôi phục dữ liệu gốc KH_001 trên delivery_db & Quy tắc cách ly kiểm thử:**
    - **1. Sự cố phát hiện:**
      - Trong đợt nghiệm thu sống API của Task 011, thao tác gọi `verify-location` đã chạy trực tiếp trên database chính `delivery_db`. Thao tác này đã thay đổi bản ghi `saved_locations` của khách hàng `0988000001` (`KH_001`, `c0000000-0000-0000-0000-000000000001`) sang tọa độ test `(10.8422500, 106.8181500)`, ghi chú `'Cổng sắt hoa văn đã xác minh'` và đường dẫn ảnh không tồn tại `/api/v1/photos/test_verified.jpg`.
    - **2. Khôi phục hoàn toàn dữ liệu gốc KH_001 (Restoration):**
      - Thực hiện lệnh SQL `UPDATE` tiêu chuẩn trên bảng `saved_locations` đưa các trường về đúng giá trị gốc trong [init-db/01-init-db.sql](file:///d:/flutter create delivery_marker_app/init-db/01-init-db.sql):
        * `latitude`: `10.8422150`
        * `longitude`: `106.8181230`
        * `geom`: `ST_SetSRID(ST_MakePoint(106.8181230, 10.8422150), 4326)`
        * `gps_accuracy`: `4.5`
        * `identification_notes`: `'Đi vào hẻm 124 khoảng 50m, nhà cạnh tiệm tạp hóa Hai Thu, cổng màu xanh da trời, có cây mai trước sân.'`
        * `image_url`: `NULL`
      - Trigger `trg_saved_locations_history` tự động ghi nhận một dòng lịch sử mới trong `location_history` (id: `48f3cbc1-9c5d-49a8-87fc-c3ec64fa319e`) lưu giữ trạng thái trước khi khôi phục.
      - **Bảo toàn 100%:** Tuyệt đối không xóa bất kỳ dòng nào trong bảng `location_history`.
    - **3. Quy chuẩn cách ly môi trường kiểm thử (Strict Policy):**
      - Mọi test tích hợp có ghi/sửa/xóa dữ liệu bắt buộc phải chạy trên database kiểm thử riêng biệt (như `test_isolated_seed_db` hoặc database test tạm thời), tuyệt đối **NGHIÊM CẤM** chạy các test làm thay đổi dữ liệu trên `delivery_db`.

32. **[ĐÃ HOÀN TẤT - TASK: FIX-TEST-DATA-011C] Khôi phục điểm giao ca SHF-20261025-001, Chốt chặn bảo vệ CSDL chính & Báo cáo cơ chế đồng bộ đa ca:**
    - **1. Đồng bộ điểm giao `d4e38099-e8de-4b1d-9006-b3481cd35b21` (Ca `SHF-20261025-001`, KH_001):**
      - Cập nhật điểm giao và `saved_locations` về đúng dữ liệu gốc: tọa độ `(10.8422150, 106.8181230)`, ghi chú gốc `'Đi vào hẻm 124 khoảng 50m, nhà cạnh tiệm tạp hóa Hai Thu, cổng màu xanh da trời, có cây mai trước sân.'` và khôi phục ảnh thực tế trên ổ cứng `6ffc3833-1f78-48c8-8624-3041f25449f9.jpg` (thay vì ảnh giả không tồn tại `test_verified.jpg`).
      - Bảo toàn 100% `location_history` và `audit_logs` (không xóa dòng nào).
    - **2. Báo cáo cơ chế đồng bộ đa ca làm điểm ca khác bị đổi:**
      - Phát hiện tại [shifts.controller.ts:L928-L946](file:///d:/flutter create delivery_marker_app/backend/src/controllers/shifts.controller.ts#L928-L946), câu lệnh UPDATE đồng bộ tự động `shift_delivery_points` sang các ca khác đang ở trạng thái `PREPARING` hoặc `IN_PROGRESS` của shipper khi một ca gọi `verifyPointLocation`. (Chỉ báo cáo, giữ nguyên chưa sửa mã nguồn theo đúng chỉ đạo).
    - **3. Chốt chặn bảo vệ CSDL chính & CSDL test riêng (`test_isolated_seed_db`):**
      - Tạo script [setup-test-db.ts](file:///d:/flutter create delivery_marker_app/backend/scripts/setup-test-db.ts) nạp schema PostGIS và seed dữ liệu sạch vào `test_isolated_seed_db`.
      - Bổ sung hàm chốt chặn `assertSafeDatabaseForTests` trong [db.ts](file:///d:/flutter create delivery_marker_app/backend/src/db.ts): nếu phát hiện môi trường test (`NODE_ENV=test` hoặc `IS_INTEGRATION_TEST=true`) kết nối tới `delivery_db`, hệ thống lập tức từ chối và ném lỗi `[CRITICAL GUARDRAIL BLOCKED]`.
      - Bổ sung bộ kiểm thử [database-guard.spec.ts](file:///d:/flutter create delivery_marker_app/backend/test/database-guard.spec.ts) và scripts `test:setup-db`, `test:integration` trong `package.json`.

33. **[ĐÃ HOÀN TẤT - TASK: LOCATION-RULES-012] Quy Chuẩn Vị Trí Mới, Tách Biệt Ca - Danh Bạ & Quyền Xóa Vị Trí Cho Shipper:**
    - **1. Quy tắc 1 & 2 — Phân định rạch ròi trạng thái vị trí:**
      - Bảng `saved_locations` đại diện cho vị trí đã xác nhận (`ĐÃ XÁC NHẬN`), **không** thêm cột trạng thái mới vào `saved_locations`.
      - Vị trí `TEMPORARY` chỉ tồn tại cục bộ trong ca làm việc (`shift_delivery_points.location_status = 'TEMPORARY'`), tuyệt đối không ghi vào `saved_locations`.
    - **2. Quy tắc 3 & Bổ sung bắt buộc 1 — Tinh gọn màn hình ca và gỡ đồng bộ chéo giữa các ca:**
      - Trong [crosshair_location_picker_view.dart](file:///d:/flutter create delivery_marker_app/mobile_app/lib/views/crosshair_location_picker_view.dart): Khi mở từ luồng ca (`shiftId.isNotEmpty`), bỏ nút "XÁC MINH CỔNG NHÀ", chỉ hiển thị nút duy nhất "LƯU VỊ TRÍ TẠM". Luồng ca không còn gọi `verifyPointLocation`.
      - Trong [shifts.controller.ts](file:///d:/flutter create delivery_marker_app/backend/src/controllers/shifts.controller.ts): Gỡ bỏ đoạn code "Synchronize other active shift delivery points" khỏi `verifyPointLocation` để không tự động ghi đè điểm giao của cùng khách hàng ở các ca khác.
    - **3. Quy tắc 4 — Luồng xác nhận chuẩn từ Danh bạ sang CSDL:**
      - Luồng chuẩn: `Danh bạ -> Hồ sơ khách -> Bấm chọn trên bản đồ -> Tâm ngắm -> Xác nhận vị trí` => gọi [saveOrUpdateCustomerLocation](file:///d:/flutter create delivery_marker_app/backend/src/controllers/locations.controller.ts) ghi `saved_locations`.
      - Điểm giao trong các ca đang chạy (`PREPARING`, `IN_PROGRESS`) của khách đó tự động chuyển sang `VERIFIED` theo tọa độ, ghi chú và ảnh mới.
      - Ghi lại số lượng điểm giao được đồng bộ (`updatedShiftPointsCount`) vào trường `details` của `audit_logs` (`VERIFY_LOCATION_FROM_DIRECTORY`).
    - **4. Quy tắc 5 — Quyền Shipper xóa vị trí đã lưu của chính mình:**
      - Bổ sung API `DELETE /api/v1/customers/:customerId/location` trong [locations.controller.ts](file:///d:/flutter create delivery_marker_app/backend/src/controllers/locations.controller.ts) và [app.ts](file:///d:/flutter create delivery_marker_app/backend/src/app.ts).
      - Kiểm soát quyền chặt chẽ (RBAC + Area Scope): Shipper chỉ được xóa vị trí do chính mình tạo/cập nhật (`created_by === shipperId || updated_by === shipperId`) và khách hàng phải thuộc khu vực shipper phụ trách (`user_areas`). Tài khoản `ADMIN` có quyền xóa mọi vị trí.
      - Bảo toàn lịch sử kiểm toán: Tách `saved_location_id = NULL` trong `location_history` trước khi xóa `saved_locations` để tránh phá vỡ ràng buộc khóa ngoại và bảo tồn 100% lịch sử. Ghi nhật ký `audit_logs` hành động `DELETE_LOCATION` kèm `{ revertedShiftPointsCount }`.
      - Điểm giao trong các ca đang chuẩn bị / đang chạy của khách đó tự động quay về `NO_LOCATION` và xóa tọa độ/ghi chú/ảnh trong ca.
      - Mobile [customer_directory_view.dart](file:///d:/flutter create delivery_marker_app/mobile_app/lib/views/customer_directory_view.dart) & [api_service.dart](file:///d:/flutter create delivery_marker_app/mobile_app/lib/services/api_service.dart): Hiển thị nút "Xóa vị trí" nổi bật khi khách có tọa độ. Bấm vào hiển thị hộp thoại xác nhận cảnh báo trước khi gọi API xóa và cập nhật giao diện thời gian thực.
    - **5. Quy tắc 6, Bổ sung 2 & 3 — Cách ly kiểm thử nghiêm ngặt & Automated Tests:**
      - Mọi test tích hợp ghi dữ liệu chạy 100% trên `test_isolated_seed_db` qua [setup-test-db.ts](file:///d:/flutter create delivery_marker_app/backend/scripts/setup-test-db.ts). Chốt chặn `assertSafeDatabaseForTests` bảo vệ tuyệt đối CSDL `delivery_db`.
      - Viết test tích hợp toàn diện [location-rules-012.integration.spec.ts](file:///d:/flutter create delivery_marker_app/backend/test/location-rules-012.integration.spec.ts) và test giao diện [location_rules_012_test.dart](file:///d:/flutter create delivery_marker_app/mobile_app/test/location_rules_012_test.dart).
      - Backend: **105/105 tests passed (100%)** qua 7 test suites.
      - Flutter: `flutter analyze` **0 issues**, `flutter test` **69/69 tests passed (100%)**.
      - Live Database `delivery_db` được giữ nguyên vẹn 100%.

34. **[ĐÃ HOÀN TẤT - TASK: LOCATION-RULES-012B] Khóa Chặt Đường verify-location Trong Ca, Cô Lập Tuyệt Đối Điểm Giao Ca & Bảo Vệ Vị Trí TEMPORARY:**
    - **1. Tắt hẳn luồng `verify-location` từ ca:**
      - Trong [shifts.controller.ts](file:///d:/flutter create delivery_marker_app/backend/src/controllers/shifts.controller.ts): Hàm `verifyPointLocation` được cấu hình trả về **HTTP 410 Gone** kèm thông báo hướng dẫn rõ ràng: *"Endpoint xác minh vị trí trong ca đã ngừng hoạt động (410 Gone). Theo quy chuẩn LOCATION-RULES-012, vị trí chuẩn chỉ được xác nhận qua luồng Danh bạ -> Hồ sơ khách -> Xác nhận vị trí."* Tuyệt đối không còn bất kỳ khả năng nào ghi đè hay cập nhật `saved_locations` từ ca.
      - Trong Mobile App [api_service.dart](file:///d:/flutter create delivery_marker_app/mobile_app/lib/services/api_service.dart): Xóa bỏ hoàn toàn hàm `ApiService.verifyShiftLocation`.
    - **2. Sửa và chuẩn hóa `deleteCustomerLocation` ([locations.controller.ts](file:///d:/flutter create delivery_marker_app/backend/src/controllers/locations.controller.ts)):**
      - *Bảo vệ ghim TEMPORARY:* Thêm điều kiện `AND sdp.location_status = 'VERIFIED'`. Khi xóa vị trí đã lưu, các điểm giao có trạng thái `TEMPORARY` (ghim tạm thời của shipper) được **GIỮ NGUYÊN 100%** tọa độ và ghi chú.
      - *Giới hạn ca shipper xóa:* Thêm điều kiện `AND s.shipper_id = $2 AND (s.status = 'PREPARING' OR s.status = 'IN_PROGRESS')` (đối với SHIPPER). Chỉ cập nhật điểm giao thuộc ca của chính shipper đó, không ảnh hưởng tới ca của shipper khác.
    - **3. Chuẩn hóa câu UPDATE đồng bộ trong `saveOrUpdateCustomerLocation` ([locations.controller.ts](file:///d:/flutter create delivery_marker_app/backend/src/controllers/locations.controller.ts)):**
      - Sửa điều kiện WHERE: Thay thế `(s.status = 'PREPARING' OR (s.status = 'IN_PROGRESS' AND s.shipper_id = $9))` bằng `s.shipper_id = $9 AND (s.status = 'PREPARING' OR s.status = 'IN_PROGRESS')`. Khi Shipper A xác nhận vị trí cho khách hàng, các ca của Shipper B (kể cả đang ở `PREPARING` hay `IN_PROGRESS`) **hoàn toàn KHÔNG bị đụng chạm**.
    - **4. Kiểm thử tích hợp thật & Coverage ([location-rules-012.integration.spec.ts](file:///d:/flutter create delivery_marker_app/backend/test/location-rules-012.integration.spec.ts)):**
      - Toàn bộ các bài test đều gọi trực tiếp hàm controller thật (`saveOrUpdateCustomerLocation`, `deleteCustomerLocation`, `verifyPointLocation`), không tự viết SQL thay thế logic nghiệp vụ.
      - Bổ sung kiểm thử: Xóa vị trí giữ nguyên điểm giao `TEMPORARY`.
      - Bổ sung kiểm thử: Shipper A bị từ chối `403 Forbidden` khi xóa vị trí ngoài khu vực phụ trách.
      - Bổ sung kiểm thử: Shipper A xác nhận vị trí không làm thay đổi điểm giao trong ca của Shipper B.
      - Bổ sung kiểm thử: Gọi `verifyPointLocation` trả về đúng 410 Gone.
      - Backend: **108/108 tests passed (100%)** qua 7 test suites trên `test_isolated_seed_db`.
      - Flutter: `flutter analyze` **0 issues**, `flutter test` **69/69 tests passed (100%)**.
    - **5. Dựng lại container Backend & Build APK Debug:**
      - Rebuild container: `docker compose up -d --build backend` thành công (`delivery_backend_api` Started, `delivery_postgis_db` giữ nguyên).
      - Kiểm tra API sống bằng GET: `Invoke-WebRequest -Uri 'http://localhost:3000/api/docs/' -Method Get` trả về **200 OK**.
      - Build APK Debug: `flutter build apk --debug` thành công: `build\app\outputs\flutter-apk\app-debug.apk` (136.5s).
      - CSDL `delivery_db` được bảo toàn nguyên vẹn 100%, 0 request ghi dữ liệu nào vào API sống hay DB sống.

35. **[ĐÃ HOÀN TẤT - TASK: QUICK-ADD-CUSTOMER-013] Tinh Gọn Luồng Thêm Nhanh Khách Hàng (Quick Add Customer), Chuẩn Hóa SĐT & Chống Trùng Lặp:**
    - **1. Thiết kế Giao diện Thêm Nhanh Chuẩn ([quick_add_customer_sheet.dart](file:///d:/flutter create delivery_marker_app/mobile_app/lib/widgets/quick_add_customer_sheet.dart)):**
      - **Chỉ bắt buộc 1 ô duy nhất:** Trường SĐT khách hàng (`phoneNumber`).
      - **Tương tác mượt mà:** Tự động focus (`autofocus: true`), bàn phím số điện thoại (`keyboardType: TextInputType.phone`), phím Enter/Done trên bàn phím hoặc nút bấm `"TẠO"` lập tức kích hoạt luồng tạo.
      - **Chuẩn hóa SĐT & Hiển thị trực tiếp:** Tự động chuẩn hóa số điện thoại theo định dạng chuẩn Việt Nam 10 chữ số (xóa khoảng trắng, dấu ngoặc, chuyển đầu 84 thành 0, thêm số 0 đầu nếu nhập 9 số). Hiển thị số đã chuẩn hóa live bên dưới ô nhập (`Số đã chuẩn hóa: XXXXXXXXXX (10 số)`).
      - **Cảnh báo chống tạo khách rác do gõ nhầm:** Trước khi tạo, nếu số đã chuẩn hóa có số lượng chữ số khác 10 (`length != 10`), hiển thị AlertDialog xác nhận: `"Số này có X chữ số ($cleanPhone), bạn có chắc?"` với 2 nút `"HỦY"` và `"TIẾP TỤC"`.
      - **Thông tin tùy chọn mặc định ẩn:** Các trường Tên khách hàng, Địa chỉ giao hàng và Ghi chú vị trí được thu gọn vào mục `"Thêm thông tin (Tên, địa chỉ, ghi chú)"`. Bấm vào sẽ mở rộng để người dùng nhập nếu muốn.
      - **Giá trị mặc định chuẩn:** Nếu để trống Tên, tự động nhận `"Khách [SĐT]"`. Nếu để trống Địa chỉ, tự động nhận `"Chưa cập nhật địa chỉ"`.
      - **Chống tạo trùng & Tự mở hồ sơ:** Nếu số điện thoại đã tồn tại trong hệ thống, backend trả về `200 OK` kèm `isExisting: true`, Flutter không báo lỗi Conflict mà lập tức hiển thị thông báo và mở ngay hồ sơ khách hàng đó (`CustomerDetailEditView`).
      - **Quản lý khu vực theo shipper phụ trách:** Tự động lấy khu vực phân công của shipper qua API `GET /api/v1/areas/my-areas`. Nếu shipper phụ trách nhiều khu vực (>1) và chưa có khu vực ưa thích, hệ thống mở hộp thoại hỏi chọn 1 lần duy nhất và lưu vào `SharedPreferences` (`preferred_customer_area_id`).
    - **2. Đồng bộ toàn bộ các điểm thêm khách trong ứng dụng:**
      - Áp dụng trên Danh bạ khách hàng [customer_directory_view.dart](file:///d:/flutter create delivery_marker_app/mobile_app/lib/views/customer_directory_view.dart) qua hàm `_openCreateCustomerSheet()`.
      - Áp dụng trên Màn hình chuẩn bị ca [shift_preparation_view.dart](file:///d:/flutter create delivery_marker_app/mobile_app/lib/views/shift_preparation_view.dart) qua hàm `_showQuickCreateCustomerBottomSheet()`.
    - **3. Cập nhật Backend & API ([customers.controller.ts](file:///d:/flutter create delivery_marker_app/backend/src/controllers/customers.controller.ts), [admin.controller.ts](file:///d:/flutter create delivery_marker_app/backend/src/controllers/admin.controller.ts), [shifts.controller.ts](file:///d:/flutter create delivery_marker_app/backend/src/controllers/shifts.controller.ts), [app.ts](file:///d:/flutter create delivery_marker_app/backend/src/app.ts)):**
      - Bổ sung endpoint `GET /api/v1/areas/my-areas` cho phép `SHIPPER` và `ADMIN` truy vấn các khu vực được phân công.
      - `createCustomer`: Xử lý khi SĐT đã tồn tại -> trả về `200 OK` kèm `{ success: true, isExisting: true, data: existingCustomer }`; đồng thời áp dụng mặc định `"Khách [SĐT]"` và `"Chưa cập nhật địa chỉ"`.
      - `addPointToShift`: Đồng bộ giá trị mặc định cho khách mới tạo qua ca làm.
    - **4. Kiểm thử tự động & Tuân thủ quy tắc an toàn:**
      - **Backend Integration Tests:** Viết bộ test [quick-add-customer-013.integration.spec.ts](file:///d:/flutter create delivery_marker_app/backend/test/quick-add-customer-013.integration.spec.ts) chạy trên CSDL cô lập `test_isolated_seed_db`, gọi trực tiếp controller thật: **4/4 passed (100%)**.
      - **Backend Total Tests:** `npm test` đạt **112/112 tests passed (100%)** qua 8 test suites. TypeScript biên dịch 0 lỗi (`tsc`).
      - **Flutter Widget/Unit Tests:** Viết bộ test [quick_add_customer_013_test.dart](file:///d:/flutter create delivery_marker_app/mobile_app/test/quick_add_customer_013_test.dart) kiểm thử toàn diện: chuẩn hóa SĐT, autofocus, bàn phím, ẩn/hiện thông tin tùy chọn, live preview SĐT, cảnh báo số khác 10 chữ số: **6/6 passed (100%)**.
      - **Flutter Total Tests:** `flutter test` đạt **75/75 tests passed (100%)**. `flutter analyze` đạt **0 issues found**.
      - **Rebuild Backend Container:** `docker compose up -d --build backend` thành công (`delivery_backend_api` Started, `delivery_postgis_db` giữ nguyên).
      - **Kiểm tra API sống:** `GET http://localhost:3000/api/docs/` trả về **200 OK**. Tuyệt đối không gửi request ghi (POST/PUT/PATCH/DELETE) vào API sống hay `delivery_db`.
      - **Build APK Debug:** `flutter build apk --debug` thành công.

36. **[ĐÃ HOÀN TẤT - TASK: QUICK-ADD-013B] Siết Quyền Khu Vực (403 Forbidden), Tự Động Làm Sạch Preferred Area & Chuẩn Hóa Khu Vực Ca:**
    - **1. Backend `createCustomer` & `addPointToShift` — Cấm âm thầm đổi khu vực (403 Forbidden):**
      - Trong [customers.controller.ts](file:///d:/flutter create delivery_marker_app/backend/src/controllers/customers.controller.ts) và [shifts.controller.ts](file:///d:/flutter create delivery_marker_app/backend/src/controllers/shifts.controller.ts): Khi `areaId` được gửi lên trong payload yêu cầu, hệ thống kiểm tra ngay lập tức quyền phân công khu vực của shipper (`assignedAreaIds.includes(areaId)`).
      - Nếu `areaId` không thuộc khu vực shipper được phân công (và không phải `ADMIN`), backend lập tức trả về **HTTP 403 Forbidden** kèm thông báo rõ ràng: *"Khu vực được chỉ định không thuộc khu vực bạn được phân công phụ trách"*.
      - Tuyệt đối **không âm thầm đổi** sang khu vực khác (`assignedAreaIds[0]`) như phiên bản trước.
    - **2. Flutter — Tự động làm sạch và hỏi chọn lại khi `preferred_customer_area_id` hết hiệu lực:**
      - Trong [api_service.dart](file:///d:/flutter create delivery_marker_app/mobile_app/lib/services/api_service.dart): Bổ sung hàm `clearPreferredAreaId()` xóa khóa `preferred_customer_area_id` khỏi `SharedPreferences`.
      - Trong [quick_add_customer_sheet.dart](file:///d:/flutter create delivery_marker_app/mobile_app/lib/widgets/quick_add_customer_sheet.dart): Trong `_loadAreas()`, khi đọc `preferred_customer_area_id`, đối chiếu với danh sách khu vực thực tế trả về từ `getMyAreas()`. Nếu khu vực đã lưu không còn tồn tại trong danh sách được phân công của shipper, hệ thống tự động:
        1. Gọi `ApiService.clearPreferredAreaId()` để xóa giá trị cũ không còn hợp lệ.
        2. Nếu shipper có duy nhất 1 khu vực, tự động nhận khu vực đó và cập nhật lại.
        3. Nếu shipper có >1 khu vực được phân công, tự động mở ngay hộp thoại `_promptSelectArea()` hỏi shipper chọn lại khu vực phụ trách.
    - **3. Báo cáo & Sửa trường `areaId` của `ShiftModel` & Màn hình chuẩn bị ca:**
      - **Báo cáo cấu trúc:** `ShiftModel` (và bảng CSDL `shifts`) **HOÀN TOÀN KHÔNG CÓ trường `areaId`**. Bảng `shifts` chỉ gồm: `id`, `shift_code`, `work_date`, `shipper_id`, `status`. Do đó, `_currentShift.areaId` luôn là `null`.
      - **Báo cáo khu vực thực tế trước đây:** Khi tạo khách từ màn chuẩn bị ca, trước đây code truyền `prefilledAreaId: _currentShift.deliveryPoints.isNotEmpty ? _currentShift.deliveryPoints.first.areaId : null`. Nghĩa là nếu ca đã có điểm giao, nó lấy khu vực của *điểm giao đầu tiên* (có thể lệch với khu vực shipper chọn hôm nay); nếu ca chưa có điểm giao, nó rơi về `preferred_customer_area_id`.
      - **Sửa triệt để:** Trong [shift_preparation_view.dart](file:///d:/flutter create delivery_marker_app/mobile_app/lib/views/shift_preparation_view.dart), loại bỏ hoàn toàn `prefilledAreaId` (để `null`). `QuickAddCustomerSheet` sẽ tự động giải quyết theo đúng khu vực shipper đã chọn / mặc định thông qua `preferred_customer_area_id` đã được xác thực với `getMyAreas()`.
    - **4. Báo cáo & Kiểm thử số điện thoại đã tồn tại nhập ở màn chuẩn bị ca:**
      - **Báo cáo luồng hoạt động:** Số điện thoại đã tồn tại khi nhập ở màn chuẩn bị ca **ĐƯỢC THÊM VÀO CA ĐẦY ĐỦ**:
        - *Qua ô tìm kiếm:* `_lookupAndAddCustomer()` tra cứu SĐT qua `lookupCustomerLocationByPhone()`, tìm thấy hồ sơ khách và gọi `ApiService.addPointToShift()` thêm vào ca làm, cập nhật thống kê ca.
        - *Qua BottomSheet:* `QuickAddCustomerSheet` gọi `createCustomer()` nhận về `200 OK` (`isExisting: true`), sau đó `_showQuickCreateCustomerBottomSheet()` tự động gọi `ApiService.addPointToShift()` đưa khách vào ca.
        - *Kiểm soát khu vực:* Nếu SĐT đã tồn tại nhưng thuộc khu vực shipper không được phân công phụ trách, backend trả về `403 Forbidden` (`Khách hàng này thuộc khu vực bạn không được phân công phụ trách`), ngăn ngừa nhầm lẫn ca làm ngoài khu vực.
    - **5. Kiểm thử tự động, Dựng lại Backend & Build APK Debug:**
      - **Backend Integration Tests:** [quick-add-customer-013.integration.spec.ts](file:///d:/flutter create delivery_marker_app/backend/test/quick-add-customer-013.integration.spec.ts) mở rộng thêm 4 test cases cho Task 013B chạy trên `test_isolated_seed_db`: **8/8 passed (100%)**.
      - **Backend Full Suite:** `npm test` đạt **116/116 tests passed (100%)** qua 8 test suites. `tsc` 0 lỗi.
      - **Flutter Tests:** [quick_add_customer_013_test.dart](file:///d:/flutter create delivery_marker_app/mobile_app/test/quick_add_customer_013_test.dart) bổ sung 2 test cases kiểm thử làm sạch `preferred_customer_area_id`: **8/8 passed (100%)**.
      - **Flutter Full Suite:** `flutter test` đạt **77/77 tests passed (100%)**. `flutter analyze` đạt **0 issues found** (No issues found, ran in 60.5s).
      - **Rebuild Backend Container:** `docker compose up -d --build backend` thành công.
      - **Kiểm tra API sống:** `GET http://localhost:3000/api/docs/` trả về **200 OK**. Không có bất kỳ truy vấn ghi nào tác động vào API sống hay `delivery_db`.
      - **Build APK Debug:** `flutter build apk --debug` thành công.
      - **Phân định thực tế kiểm thử:**
        - **[ĐÃ TEST]:** Automated unit tests và integration tests chạy thành công 100% trên môi trường cô lập `test_isolated_seed_db` và Flutter test engine.
        - **[CHƯA THỬ TRÊN ĐIỆN THOẠI]:** Chưa chạy thử nghiệm trên thiết bị vật lý thật.

37. **[ĐÃ HOÀN TẤT - TASK: MASTER-MAP-014] Bản Đồ Chính Độc Lập Ca (Master Map), Gom Cụm Marker (Clustering), Ghim Tâm Ngắm & Tự Động Tạo Khách / Cập Nhật Bảo Toàn Lịch Sử:**
    - **1. Khảo sát hiện trạng kết nối luồng thật (Pre-edit Verification):**
      - [main.dart](file:///d:/flutter create delivery_marker_app/mobile_app/lib/main.dart): **ĐÃ GẮN VÀO LUỒNG THẬT**. `AuthSplashScreen` khởi chạy kiểm tra token xác thực qua `ApiService.getToken()`; nếu hợp lệ điều hướng thẳng vào [home_shell_view.dart](file:///d:/flutter create delivery_marker_app/mobile_app/lib/views/home_shell_view.dart), nếu chưa đăng nhập điều hướng vào `LoginView`.
      - [home_shell_view.dart](file:///d:/flutter create delivery_marker_app/mobile_app/lib/views/home_shell_view.dart): **ĐÃ GẮN VÀO LUỒNG THẬT**. Đóng vai trò vỏ bọc chính điều hướng 3 tab qua `IndexedStack`: Tab 0 là Bản đồ ([main_map_view.dart](file:///d:/flutter create delivery_marker_app/mobile_app/lib/views/main_map_view.dart)), Tab 1 là Danh bạ ([customer_directory_view.dart](file:///d:/flutter create delivery_marker_app/mobile_app/lib/views/customer_directory_view.dart)), Tab 2 là Ca làm việc ([shift_list_view.dart](file:///d:/flutter create delivery_marker_app/mobile_app/lib/views/shift_list_view.dart)).
      - [customer_directory_view.dart](file:///d:/flutter create delivery_marker_app/mobile_app/lib/views/customer_directory_view.dart): **ĐÃ GẮN VÀO LUỒNG THẬT**. Tab 1 của ứng dụng, kết nối trực tiếp các API CRUD khách hàng thật, tìm kiếm tức thì và bộ chọn ghim vị trí.
      - [main_map_view.dart](file:///d:/flutter create delivery_marker_app/mobile_app/lib/views/main_map_view.dart): **ĐÃ GẮN VÀO LUỒNG THẬT** (Tab 0 mặc định khi mở app). Trước task này, view bị gắn chặt với `ShiftModel` (chỉ hiển thị điểm giao của ca được chọn). Đã được tái cấu trúc thành Bản đồ chính (Master Map) hoàn toàn độc lập với ca làm việc.
    - **2. Bản đồ chính độc lập với ca & API lấy vị trí cá nhân:**
      - **Backend ([locations.controller.ts](file:///d:/flutter create delivery_marker_app/backend/src/controllers/locations.controller.ts), [app.ts](file:///d:/flutter create delivery_marker_app/backend/src/app.ts)):** Bổ sung endpoint `GET /api/v1/locations/my-saved-locations` phục vụ hàm `getMySavedLocations`.
      - **Phạm vi truy vấn:** Trả về toàn bộ bản ghi trong `saved_locations` do chính shipper đang đăng nhập tạo hoặc cập nhật (`sl.created_by = $shipperId OR sl.updated_by = $shipperId`) (đối với tài khoản `ADMIN` trả về toàn bộ).
      - **Dữ liệu trả về đầy đủ:** Tên khách hàng (`customer_name`), SĐT (`customer_phone`), địa chỉ (`address_text`), tọa độ (`latitude`, `longitude`), độ chính xác GPS (`gps_accuracy`), ghi chú nhận diện (`identification_notes`), URL ảnh thực tế (`image_url`), thời điểm tạo/cập nhật.
      - **Mobile ([api_service.dart](file:///d:/flutter create delivery_marker_app/mobile_app/lib/services/api_service.dart), [location_model.dart](file:///d:/flutter create delivery_marker_app/mobile_app/lib/models/location_model.dart)):** Bổ sung model `MasterSavedLocationModel` và hàm `ApiService.getMySavedLocations()`. Mở app là tự động tải và hiển thị ngay tất cả các điểm đã lưu của shipper.
    - **3. Thuật toán gom cụm Marker thông minh (Marker Clustering):**
      - Tích hợp thuật toán nhóm cụm marker địa lý theo cấp độ thu phóng bản đồ (`_clusterLocations`):
        * Ngưỡng gom cụm tính toán theo zoom level (`threshold = 0.08 / 2^(zoom - 10)`).
        * Ở mức zoom xa / trung bình (< 16.5): Các điểm gần nhau tự động gộp thành marker cụm tròn màu xanh dương Navy với badge số lượng điểm (`count`). Chạm vào cụm marker sẽ kích hoạt hiệu ứng di chuyển mượt mà phóng to bản đồ đến tâm cụm (`_mapController.move(cluster.center, zoom + 2.5)`).
        * Ở mức zoom gần (>= 16.5): Tách thành các marker đơn lẻ màu xanh lá đặc trưng cho trạng thái `ĐÃ XÁC NHẬN` (`Icons.check_circle_rounded`). Chạm vào marker đơn lẻ mở thẻ chi tiết vị trí chân trang với đầy đủ tên khách, SĐT (gọi trực tiếp `tel:`), ghi chú, xem ảnh phóng to pinch-to-zoom và nút chỉ đường Google Maps ngoài.
    - **4. Nút nổi "Ghim vị trí mới" & Chế độ tâm ngắm trên Bản đồ chính:**
      - Thêm nút nổi `FloatingActionButton.extended` màu xanh `#2563EB` ở góc dưới bên phải màn hình: icon `Icons.add_location_alt_rounded` nhãn `"Ghim vị trí mới"`.
      - Bấm nút kích hoạt Chế độ tâm ngắm trực tiếp trên bản đồ:
        * Tâm ngắm chuẩn xác giữ cố định ở chính giữa màn hình. Shipper tùy ý kéo/di chuyển/phóng to bản đồ đến bất kỳ đâu.
        * Tích hợp thanh tìm kiếm địa chỉ Geocoding OpenStreetMap Photon trên cùng: gõ địa chỉ, chọn gợi ý sẽ lập tức bay bản đồ đến khu vực đó.
        * Hai nút chân trang: `"HỦY"` (thoát chế độ tâm ngắm, bảo toàn bản đồ) và `"XÁC NHẬN VỊ TRÍ NÀY"`.
    - **5. Hộp thoại "Gán cho số điện thoại nào?" & Tự động tạo khách mới:**
      - Bấm `"XÁC NHẬN VỊ TRÍ NÀY"` mở Modal Bottom Sheet bo góc 24px:
        * Ô nhập SĐT tự động focus (`autofocus: true`), bàn phím số (`TextInputType.phone`).
        * Chuẩn hóa SĐT live bên dưới ô nhập, cảnh báo nếu khác 10 số.
        * Gợi ý trực quan danh sách khách hàng đã có trong danh bạ khớp với số đang gõ; chạm vào gợi ý điền ngay SĐT và Tên.
        * Hỗ trợ gõ số điện thoại hoàn toàn mới bất kỳ (VD: `0908911111`).
        * Mục mở rộng tùy chọn cho phép nhập thêm Tên khách và Ghi chú nhận diện.
      - Bấm `"LƯU VỊ TRÍ NÀY"`:
        * Nếu số điện thoại mới: Tự động gọi `ApiService.createCustomer` tạo hồ sơ khách hàng mới (chỉ cần SĐT, tên mặc định `"Khách [SĐT]"`, khu vực phụ trách của shipper).
        * Ghi tọa độ tâm ngắm vào `saved_locations` qua `ApiService.updateCustomerLocationAndPhoto`. Mọi điểm lưu vào `saved_locations` đều có trạng thái canonical là **ĐÃ XÁC NHẬN** (`VERIFIED`).
        * Tự động làm mới danh sách và hiển thị marker ngay lập tức trên bản đồ chính, di chuyển khung nhìn tới vị trí vừa ghim.
    - **6. Hỏi xác nhận thay thế vị trí cũ & Bảo toàn 100% lịch sử kiểm toán:**
      - Nếu số điện thoại đã tồn tại và đã có vị trí lưu từ trước: Hệ thống mở hộp thoại AlertDialog xác nhận:
        *"Khách hàng [Tên khách] đã có vị trí đã lưu từ trước. Bạn có chắc chắn muốn thay thế bằng vị trí mới này? (Lịch sử vị trí cũ vẫn được lưu trữ đầy đủ trong hệ thống)"* với 2 nút `"HỦY"` và `"THAY VỊ TRÍ CŨ"`.
      - Khi shipper bấm `"THAY VỊ TRÍ CŨ"`: Cập nhật `saved_locations`. Trigger PostgreSQL `trg_log_location_history` trong CSDL tự động lưu trữ bản ghi vị trí cũ vào bảng `location_history`, bảo tồn 100% lịch sử và dấu vết kiểm toán (AGENTS.md rule 2.5).
    - **7. Kết quả kiểm thử tự động & Nghiệm thu:**
      - **Backend Integration Tests ([master-map-014.integration.spec.ts](file:///d:/flutter create delivery_marker_app/backend/test/master-map-014.integration.spec.ts)):** Viết 4 kịch bản kiểm thử tích hợp trên `test_isolated_seed_db` gọi trực tiếp code controller thật:
        * Shipper A đăng nhập chỉ thấy các điểm do chính Shipper A lưu (`KH_001`), không thấy điểm của Shipper B (`KH_004`).
        * Shipper B đăng nhập chỉ thấy điểm do Shipper B lưu (`KH_004`).
        * Luồng ghim vị trí mới số `0908911111`: Tự tạo khách và lưu vị trí `VERIFIED`, `getMySavedLocations` trả về điểm mới.
        * Thay vị trí cũ: Cập nhật `saved_locations` và trigger tự động lưu bản ghi vào `location_history`.
        * Kết quả: **4/4 passed (100%)**.
      - **Backend Full Test Suite:** `npm test` đạt **120/120 tests passed (100%)** qua 9 test suites. TypeScript biên dịch 0 lỗi (`tsc`).
      - **Flutter Tests ([master_map_014_test.dart](file:///d:/flutter create delivery_marker_app/mobile_app/test/master_map_014_test.dart)):** Viết 3 tests kiểm thử parser `MasterSavedLocationModel`, giao diện bản đồ không phụ thuộc ca, nút Ghim vị trí mới và chế độ tâm ngắm.
      - **Flutter Full Test Suite:** `flutter test` đạt **80/80 tests passed (100%)**. `flutter analyze` đạt **0 issues found** (No issues found!).
      - **Dựng lại Container Backend:** `docker compose up -d --build backend` thành công.
      - **Kiểm tra API sống:** `GET http://localhost:3000/api/docs/` trả về **200 OK**. Không gửi bất kỳ request ghi nào lên API sống hay `delivery_db`.
      - **Phân định thực tế kiểm thử:**
        * **[ĐÃ TEST]:** Toàn bộ automated unit & integration tests trên `test_isolated_seed_db` và Flutter test engine (120 backend tests, 80 Flutter tests).
        * **[CHƯA THỬ TRÊN ĐIỆN THOẠI]:** Chưa cài đặt và kiểm thử trực tiếp trên điện thoại vật lý thật.

38. **[ĐÃ HOÀN TẤT - TASK: MASTER-MAP-014B] Khôi Phục Test Gốc Map-First, Cảnh Báo Lỗi Kèm Nút Thử Lại & Báo Cáo Cơ Chế Hiển Thị Đa Shipper:**
    - **1. Báo cáo & Khôi phục kiểm thử [map_first_architecture_test.dart](file:///d:/flutter create delivery_marker_app/mobile_app/test/map_first_architecture_test.dart):**
      - *Hiện tượng:* Trong Task 014 trước đó, khi viết thanh tiêu đề nổi của `MainMapView`, icon `Icons.map_rounded` được thêm vào thanh tiêu đề. Khi widget test chạy `HomeShellView(initialTab: 0)`, cây widget tồn tại đồng thời 2 widget `Icons.map_rounded` (1 trong `NavigationBar`, 1 trong header `MainMapView`), khiến lệnh `expect(find.byIcon(Icons.map_rounded), findsOneWidget)` bị fail do tìm thấy 2 widget.
      - *Sửa đổi cũ:* Trước đó test assertion đã được thu hẹp phạm vi tìm kiếm thành `expect(find.descendant(of: find.byType(NavigationBar), matching: find.byIcon(Icons.map_rounded)), findsOneWidget)`.
      - *Khôi phục chuẩn xác:* Đã khôi phục 100% assertion gốc: `expect(find.byIcon(Icons.map_rounded), findsOneWidget);` trong [map_first_architecture_test.dart](file:///d:/flutter create delivery_marker_app/mobile_app/test/map_first_architecture_test.dart) (không có bất kỳ sửa đổi hay nới lỏng nào trong test).
      - *Khắc phục xung đột tận gốc tại mã nguồn:* Đổi icon thanh tiêu đề của [main_map_view.dart](file:///d:/flutter create delivery_marker_app/mobile_app/lib/views/main_map_view.dart) từ `Icons.map_rounded` sang `Icons.pin_drop_rounded` (biểu tượng ghim vị trí chuẩn xác hơn cho bản đồ điểm đã lưu), loại bỏ hoàn toàn việc trùng lặp icon trên giao diện.
    - **2. Xử lý lỗi ghim vị trí cho số mới & Nút "THỬ LẠI":**
      - Trong [main_map_view.dart](file:///d:/flutter create delivery_marker_app/mobile_app/lib/views/main_map_view.dart), cập nhật hàm `_processSaveLocation`:
        * Thêm biến cờ `isNewlyCreated` và tham số `String? knownCustomerId`.
        * Khi tạo hồ sơ khách hàng mới thành công nhưng bước lưu tọa độ vào `saved_locations` gặp sự cố (mạng yếu, timeout, lỗi kết nối...):
          1. Hiển thị thông báo rõ ràng: `"Đã tạo khách $phone nhưng chưa lưu được vị trí, thử lại"` qua SnackBar thời lượng dài (12s) có nút action `"THỬ LẠI"`.
          2. Đồng thời mở hộp thoại `AlertDialog` cảnh báo chi tiết kèm 2 nút: `"ĐÓNG"` và `"THỬ LẠI"`, tuyệt đối không để im lặng.
          3. Khi bấm `"THỬ LẠI"`, hệ thống tự động truyền `knownCustomerId = customerId` đã tạo trước đó để thực hiện lưu vị trí trực tiếp, không tạo khách hàng trùng lặp lần 2.
    - **3. Báo cáo cơ chế hiển thị điểm trên Bản đồ chính khi Shipper A lưu và Shipper B cập nhật:**
      - *Phân tích truy vấn Backend:* Endpoint `GET /api/v1/locations/my-saved-locations` lọc theo điều kiện:
        `WHERE sl.created_by = $userId OR sl.updated_by = $userId`.
      - *Phân tích thao tác CSDL:*
        * Khi Shipper A tạo mới: `created_by = Shipper A`, `updated_by = Shipper A`.
        * Khi Shipper B cập nhật vị trí: CSDL thực thi câu `UPDATE saved_locations SET updated_by = Shipper B, updated_at = NOW() WHERE customer_id = ...`. Lúc này `created_by` vẫn giữ nguyên là **Shipper A**, còn `updated_by` được gán thành **Shipper B**.
      - *Kết luận:* Điểm đó sẽ hiện trên bản đồ chính của **CẢ HAI (Shipper A VÀ Shipper B)**:
        * Shipper A thấy vì thỏa mãn điều kiện `sl.created_by = Shipper A`.
        * Shipper B thấy vì thỏa mãn điều kiện `sl.updated_by = Shipper B`.
        *(Nếu sau đó Shipper C cập nhật đè lên, thì C trở thành `updated_by`: lúc đó chỉ có A và C thấy, còn B không còn là người tạo lẫn người cập nhật mới nhất nên sẽ không còn thấy)*.
    - **4. Kết quả kiểm thử tự động & Nghiệm thu:**
      - **Backend Integration Tests:** `npm run test:integration` đạt **25/25 tests passed (100%)** trên CSDL `test_isolated_seed_db` qua 4 test suites.
      - **Backend Unit Tests:** `npm test` đạt **120/120 tests passed (100%)** qua 9 test suites.
      - **Flutter Tests:** `flutter test` đạt **82/82 tests passed (100%)** (gồm toàn bộ các test phục hồi và test retry mới).
      - **Flutter Analyze:** `flutter analyze` đạt **No issues found!** (0 warning, 0 error).
      - **Dựng lại Container Backend:** `docker compose up -d --build backend` thành công (`delivery_backend_api` Recreated & Started, `delivery_postgis_db` Healthy).
      - **Kiểm tra API sống:** `GET http://localhost:3000/api/docs/` trả về **200 OK**. CSDL `delivery_db` được giữ nguyên vẹn 100%.
      - **Phân định thực tế kiểm thử:**
        * **[ĐÃ TEST]:** Automated unit & integration tests trên `test_isolated_seed_db` và Flutter test engine (120 backend tests, 82 mobile tests), xác minh liveness GET 200 OK.
        * **[CHƯA THỬ TRÊN ĐIỆN THOẠI]:** Chưa cài đặt và kiểm thử trực tiếp trên điện thoại Android vật lý thật.

39. **[ĐÃ HOÀN TẤT - TASK: MULTI-PHOTO-AND-THUMB-UI-015A] Hệ Thống Đa Ảnh Điểm Giao, Thẻ Chi Tiết Dành Cho Shipper Đi Xe Một Tay & Bảo Toàn Dữ Liệu:**
    - **1. Mục tiêu & Cơ sở dữ liệu Idempotent ([06-create-customer-photos.sql](file:///d:/flutter create delivery_marker_app/init-db/06-create-customer-photos.sql)):**
      - Mọi điểm vị trí trên bản đồ chính và bản đồ ca khi bấm vào LUÔN có khu vực ảnh do shipper chụp thêm, mỗi khách hàng có thể lưu trữ NHIỀU ảnh thực tế.
      - Tạo bảng `customer_photos` (`id UUID PRIMARY KEY`, `customer_id UUID FK customers`, `image_url VARCHAR(500)`, `created_by UUID FK users`, `created_at TIMESTAMPTZ`, `deleted_at TIMESTAMPTZ` hỗ trợ xóa mềm). Ảnh gắn theo `customer_id`, do đó điểm ở trạng thái `TEMPORARY`, `VERIFIED`, hay chưa có vị trí `NO_LOCATION` đều lưu ảnh được.
      - Migration chuyển toàn bộ ảnh cũ từ `saved_locations.image_url` và `shift_delivery_points.image_url` sang `customer_photos` bằng mệnh đề `WHERE NOT EXISTS` chống trùng lặp tuyệt đối khi chạy lại nhiều lần (idempotent). Giữ nguyên các cột cũ để tương thích ngược.
      - Ràng buộc: Tối đa 10 ảnh hoạt động / khách, <= 5MB/ảnh, kiểm tra MIME magic bytes đầu tệp (`image/jpeg`, `image/png`, `image/webp`).
    - **2. Backend Endpoints & Phục vụ ảnh có kiểm soát:**
      - `GET /api/v1/customers/:customerId/photos`: Lấy danh sách ảnh mới nhất trước (`deleted_at IS NULL`), kiểm tra khu vực `checkCustomerAreaScope`.
      - `POST /api/v1/customers/:customerId/photos`: Tải 1 ảnh lên (Base64), kiểm tra MIME magic bytes, kiểm tra giới hạn 10 ảnh, tạo tên file ngẫu nhiên UUID (`cust-photo-uuid.jpg`), lưu đĩa `/uploads`, ghi `audit_logs` action `ADD_PHOTO`.
      - `DELETE /api/v1/customers/:customerId/photos/:photoId`: Xóa mềm (`deleted_at = NOW()`), chỉ shipper tải ảnh hoặc ADMIN mới có quyền, KHÔNG xóa file vật lý trên đĩa để bảo toàn chứng từ, ghi `audit_logs` action `DELETE_PHOTO`.
      - Cập nhật `servePhoto`: Cho phép phục vụ ảnh từ `customer_photos` có `deleted_at IS NULL` với xác thực Bearer JWT + kiểm tra quyền khu vực. Chống path traversal, giữ header `Cache-Control: private, no-store`.
      - Cập nhật các API trả điểm: `getMySavedLocations`, `getShiftDetail`, `lookupCustomerByPhone` trả thêm `photoCount` và mảng `photos` (tối đa 3 ảnh đầu để client render thumbnail nhanh).
    - **3. Flutter: Thẻ Chi Tiết Điểm Cho Shipper Đi Xe Một Tay ([point_detail_bottom_sheet.dart](file:///d:/flutter create delivery_marker_app/mobile_app/lib/widgets/point_detail_bottom_sheet.dart)):**
      - Thẻ là bottom sheet bám đáy màn hình (vùng ngón cái), vuốt lên để xem thêm, vuốt xuống để đóng. Không đặt nút quan trọng ở góc trên.
      - Trên cùng của thẻ: Dải ảnh cuộn ngang. Điểm chưa có ảnh vẫn luôn hiển thị ô "Chưa có ảnh - Thêm ảnh" lớn nổi bật, không bao giờ ẩn khu vực ảnh.
      - Nút "+ Thêm ảnh" lớn (cao >= 56px) ngay trong dải ảnh: một chạm mở thẳng camera, chụp xong tự tải lên, có nút phụ chọn từ thư viện. Hỗ trợ chụp liên tiếp nhiều ảnh. Tự động nén ảnh trên client (cạnh dài <= 1600px, chất lượng 80) trước khi gửi. Hiển thị tiến trình tải và báo lỗi SnackBar rõ ràng nếu mất mạng.
      - Nhấn giữ vào ảnh: Mở hộp thoại xác nhận xóa mềm.
      - Dưới dải ảnh: Tên khách (20sp bold) + SĐT (18sp bold).
      - Hàng 3 nút bấm lớn chia đều chiều ngang: `GỌI` (xanh lá) | `CHỈ ĐƯỜNG` (xanh dương) | `GHIM LẠI` (vàng hổ phách). Cỡ chạm tối thiểu 56px, khoảng cách giữa các nút >= 12px, cỡ chữ >= 16sp, độ tương phản cao dùng tốt ngoài trời nắng gắt.
      - Ảnh tải bằng [authenticated_image.dart](file:///d:/flutter create delivery_marker_app/mobile_app/lib/widgets/authenticated_image.dart) có Bearer token. Trình xem ảnh toàn màn hình [fullscreen_image_viewer.dart](file:///d:/flutter create delivery_marker_app/mobile_app/lib/widgets/fullscreen_image_viewer.dart) hỗ trợ vuốt lướt giữa các ảnh (Gallery PageView).
      - Tích hợp đồng bộ vào cả [main_map_view.dart](file:///d:/flutter create delivery_marker_app/mobile_app/lib/views/main_map_view.dart) và [shift_map_view.dart](file:///d:/flutter create delivery_marker_app/mobile_app/lib/views/shift_map_view.dart).
    - **4. Kết quả kiểm thử tự động & Nghiệm thu:**
      - **Backend Integration Tests ([multi-photo-015.integration.spec.ts](file:///d:/flutter create delivery_marker_app/backend/test/multi-photo-015.integration.spec.ts)):** Đạt **17/17 tests passed (100%)** trên CSDL `test_isolated_seed_db` gọi controller thật:
        * Thêm ảnh hợp lệ (JPG, PNG, WEBP), kiểm tra magic bytes.
        * Chặn file sai định dạng (PDF/TXT), chặn file vượt quá 5MB.
        * Kiểm tra giới hạn tối đa 10 ảnh / khách hàng.
        * Xóa mềm: `deleted_at` được gán thời gian, file đĩa được giữ nguyên.
        * Phân quyền xóa: Shipper khác không xóa được ảnh của Shipper A (403), Admin xóa được.
        * Phân quyền khu vực: Shipper ngoài khu vực bị 403.
        * `servePhoto`: Trả 200 cho ảnh hợp lệ; 404 cho ảnh đã xóa mềm hoặc không tồn tại; 403 cho người ngoài khu vực; chặn path traversal.
        * Idempotent migration: Chạy lại migration không nhân đôi bản ghi.
        * `audit_logs`: Ghi nhận đầy đủ `ADD_PHOTO` và `DELETE_PHOTO`.
        * Các endpoint danh sách điểm trả đúng `photoCount` và mảng `photos` (tối đa 3 ảnh).
      - **Backend Full Test Suite:** `npm run test:integration` đạt **42/42 tests passed (100%)** qua 5 test suites. `npm test` đạt **120/120 unit tests passed**. TypeScript `npm run build` biên dịch 0 lỗi.
      - **Flutter Tests ([multi_photo_015_test.dart](file:///d:/flutter create delivery_marker_app/mobile_app/test/multi_photo_015_test.dart)):** Viết 2 widget tests kiểm tra kích thước nút >= 56px, khoảng cách >= 12px, font >= 16sp, khu vực ảnh luôn hiển thị kể cả khi 0 ảnh, nút Thêm ảnh hiện đủ, tương tác callback đầy đủ.
      - **Flutter Full Test Suite:** `flutter test` đạt **84/84 tests passed (100%)**. `flutter analyze` đạt **0 issues found** (No issues found!).
      - **Dựng lại Container Backend:** `docker compose up -d --build backend` thành công (`delivery_backend_api` Recreated & Started, `delivery_postgis_db` Healthy).
      - **Kiểm tra API sống:** `GET http://localhost:3000/api/docs/` trả về **200 OK**. Tuyệt đối không gửi request ghi nào lên API sống hay `delivery_db`.
      - **Build Debug APK:** Thành công sinh tệp `app-debug.apk`.
      - **Phân định thực tế kiểm thử:**
        * **[ĐÃ TEST]:** Toàn bộ automated unit & integration tests trên `test_isolated_seed_db` và Flutter test engine (120 backend unit tests, 42 backend integration tests, 84 Flutter mobile tests), xác minh liveness GET 200 OK.
        * **[CHƯA THỬ TRÊN ĐIỆN THOẠI THẬT]:** Chưa cài đặt và kiểm thử trực tiếp trên thiết bị di động vật lý ngoài thực địa.

40. **[ĐÃ HOÀN TẤT - TASK: SHIFT-FROM-MAP-AND-BULK-PASTE-015B] Tạo Ca Từ Bản Đồ Chính, Dán Hàng Loạt Số Điện Thoại & Giao Diện Thao Tác Một Tay:**
    - **1. Mục tiêu & Cơ sở dữ liệu Idempotent ([07-add-shift-name.sql](file:///d:/flutter create delivery_marker_app/init-db/07-add-shift-name.sql)):**
      - Cho phép shipper tạo ca trực tiếp từ bản đồ chính, đặt tên ca linh hoạt, dán hàng loạt số điện thoại từ bộ nhớ tạm vào ca; bản đồ ca tự động hiển thị các điểm đã có vị trí và đưa các số chưa có vị trí vào danh sách "Cần xác nhận vị trí".
      - Bổ sung an toàn cột `shift_name VARCHAR(100) NULL` vào bảng `shifts` bằng cú pháp `ALTER TABLE shifts ADD COLUMN IF NOT EXISTS shift_name VARCHAR(100) NULL;`.
      - Giữ nguyên cột mã ca `shift_code` (`SHF-YYYYMMDD-XXX`). Ca cũ không có tên hiển thị `shift_code`.
      - Tạo chỉ mục `idx_shifts_shift_name` tra cứu nhanh.
    - **2. Backend Endpoints & Xử lý Transaction Hàng Loạt:**
      - `POST /api/v1/shifts`: Nhận thêm `shiftName` (tùy chọn, tối đa 100 ký tự, trimmed). Trả `shiftName` trong tất cả các API ca (`listShifts`, `createShift`, `getShiftDetail`, `updateShiftStatus`).
      - `PATCH /api/v1/shifts/:id/name`: Đổi tên ca làm việc, kiểm tra quyền sở hữu (chỉ chủ ca hoặc ADMIN), ghi vết `audit_logs` `UPDATE_SHIFT_NAME`.
      - `POST /api/v1/shifts/:id/points/bulk`:
        * Nhận `phones: string[]` hoặc `rawText: string`, `areaId?: string`.
        * Tách số theo xuống dòng, dấu phẩy, dấu chấm phẩy. Giữ khoảng trắng và dấu chấm bên trong số (`0908 911 111`, `+84 908 911 111`, `0908.911.111`) rồi chuẩn hóa về 10 chữ số. Lọc trùng lặp (deduplicate).
        * Giới hạn tối đa 200 số / lần (vượt quá trả 400 Bad Request).
        * Xử lý nguyên tử trong một transaction: Số đã có khách và có vị trí lưu thêm vào ca dạng `VERIFIED`; số có khách nhưng chưa có vị trí thêm dạng `NO_LOCATION`; số chưa có khách tự tạo nhanh (`Khách [SĐT]`, `Chưa cập nhật địa chỉ`) gắn khu vực mặc định của shipper.
        * Nếu shipper có nhiều khu vực mà chưa chọn `areaId`, transaction rollback và trả lỗi 400 yêu cầu chọn khu vực trước, tuyệt đối không tự lấy khu vực đầu.
        * Số ngoài khu vực phụ trách: Từ chối riêng số đó vào nhóm `rejected` (`OUT_OF_AREA`), các số khác trong lô vẫn được tiếp tục xử lý thành công.
        * Response trả 4 nhóm: `added`, `alreadyInShift`, `rejected`, `summary`.
        * Ghi 1 dòng `audit_logs` `BULK_ADD_POINTS` cho cả lô lưu tổng kết số lượng.
        * Giới hạn UPDATE/INSERT theo ca của chính shipper (shipper khác bị 403 Forbidden).
    - **3. Flutter: Giao diện Thao Tác Một Tay Ở Vùng Ngón Cái:**
      - Bản đồ chính ([main_map_view.dart](file:///d:/flutter create delivery_marker_app/mobile_app/lib/views/main_map_view.dart)): Bổ sung nút "Tạo ca" lớn (chiều cao 56px) đặt song song cạnh nút "Ghim vị trí mới" (chiều cao 56px) ở vùng ngón cái sát đáy màn hình.
      - Hộp tạo ca ([create_shift_dialog.dart](file:///d:/flutter create delivery_marker_app/mobile_app/lib/widgets/create_shift_dialog.dart)): Ô nhập duy nhất "Tên ca", tự focus, gợi ý sẵn "Ca sáng/chiều dd/MM", nút "TẠO CA VÀ MỞ BẢN ĐỒ" >= 56px. Tạo xong tự động chuyển hướng mở bản đồ ca trống.
      - Bản đồ ca ([shift_map_view.dart](file:///d:/flutter create delivery_marker_app/mobile_app/lib/views/shift_map_view.dart)): Nút lớn "DÁN DANH SÁCH SĐT" (cao 56px) ở đáy màn hình.
      - Bottom sheet dán số ([bulk_paste_phone_sheet.dart](file:///d:/flutter create delivery_marker_app/mobile_app/lib/widgets/bulk_paste_phone_sheet.dart)):
        * Nút "DÁN TỪ BỘ NHỚ TẠM" một chạm lấy clipboard.
        * Ô văn bản lớn đa dòng, tự động xem trước số đã chuẩn hóa, đếm số hợp lệ và cảnh báo số sai định dạng bằng Wrap badges.
        * Nút "THÊM VÀO CA" >= 56px.
        * Sau khi thêm: hiển thị 2 nhóm rõ ràng "Đã có vị trí" (marker hiện ngay trên bản đồ ca, auto-fit bounds) và "Chưa có vị trí - cần xác nhận" (mỗi dòng có nút lớn "GHIM TÂM NGẮM" >= 56px để ghim tạm `TEMPORARY`), kèm nhóm "Bị từ chối" ghi rõ lý do.
      - Tích hợp liền mạch thẻ chi tiết nhiều ảnh của Task 015A cho mọi điểm trên bản đồ ca.
    - **4. Kết quả kiểm thử tự động & Nghiệm thu:**
      - **Backend Integration Tests ([shift-bulk-015b.integration.spec.ts](file:///d:/flutter create delivery_marker_app/backend/test/shift-bulk-015b.integration.spec.ts)):** Đạt **12/12 tests passed (100%)** trên CSDL `test_isolated_seed_db` gọi controller thật:
        * Tách số và chuẩn hóa theo xuống dòng, phẩy, chấm phẩy, `+84`, khoảng trắng, dấu chấm.
        * Lọc trùng lặp chính xác.
        * Từ chối nếu trên 200 số (400 Bad Request).
        * Shipper khác không thể thêm điểm vào ca (403 Forbidden).
        * Xử lý lô hỗn hợp: VERIFIED, NO_LOCATION, tạo khách mới, sai định dạng, ngoài khu vực.
        * Dán lại số đã có trong ca được phân vào nhóm `alreadyInShift`.
        * Shipper có nhiều khu vực chưa chọn `areaId` bị trả lỗi 400 yêu cầu chọn.
        * Tạo ca có và không có tên (`shiftName`).
        * Đổi tên ca bởi chủ ca, Admin và chặn shipper khác (403).
      - **Backend Full Test Suite:** `npm run test:integration` đạt **54/54 tests passed (100%)** qua 6 test suites. `npm test` đạt **149/149 unit & integration tests passed**. TypeScript `npm run build` biên dịch 0 lỗi.
      - **Flutter Tests ([shift_bulk_015b_test.dart](file:///d:/flutter create delivery_marker_app/mobile_app/test/shift_bulk_015b_test.dart)):** Đạt **3/3 widget tests passed** kiểm tra hộp tên ca, bottom sheet dán số, hai nhóm kết quả, nút GHIM TÂM NGẮM >= 56px.
      - **Flutter Full Test Suite:** `flutter test` đạt **87/87 tests passed (100%)** qua 13 test files. `flutter analyze` đạt **0 issues found** (No issues found!).
      - **Dựng lại Container Backend:** `docker compose up -d --build backend` thành công (`delivery_backend_api` Recreated & Started, `delivery_postgis_db` Healthy).
      - **Kiểm tra API sống:** `GET http://localhost:3000/api/docs/` trả về **200 OK**. Tuyệt đối không gửi request ghi nào lên API sống hay `delivery_db`.
      - **Build Debug APK:** Thành công sinh tệp `app-debug.apk`.
      - **Phân định thực tế kiểm thử:**
        * **[ĐÃ TEST]:** Toàn bộ automated unit & integration tests trên `test_isolated_seed_db` và Flutter test engine (149 backend tests, 87 mobile tests), xác minh liveness GET 200 OK.
        * **[CHƯA THỬ TRÊN ĐIỆN THOẠI THẬT]:** Chưa cài đặt và kiểm thử trực tiếp trên thiết bị di động vật lý ngoài thực địa.

41. **[ĐÃ HOÀN TẤT - TASK: LIVE-DB-MIGRATE-AND-MERGE-CHECK-015C] Áp Dụng Migration 06 & 07 Lên CSDL Thật (`delivery_db`), Kiểm Tra Hợp Nhất & Kiểm Thử Toàn Diện:**
    - **1. Trạng Thái Áp Dụng Migration Lên CSDL Thật:**
      * **ĐÃ ÁP DỤNG LÊN DB THẬT:** Có. Thực hiện lúc **15:15:00 ngày 25/10/2026** theo ngoại lệ được phê duyệt.
      * **Sao lưu trước (pg_dump):** Đặt tại `D:\db_backups\delivery_db_backup_20261025_151305.sql` (dung lượng: **172,388 bytes**, ~172 KB), nằm ngoài thư mục git repository.
    - **2. Kết quả thực thi Migration trên `delivery_db`:**
      * **Migration 06 ([06-create-customer-photos.sql](file:///d:/flutter create delivery_marker_app/init-db/06-create-customer-photos.sql)):**
        - Tạo bảng `customer_photos` và 3 chỉ mục (`idx_customer_photos_customer_id`, `idx_customer_photos_deleted_at`, `idx_customer_photos_created_at`).
        - Nạp dữ liệu ảnh cũ: Chuyển 3 ảnh từ `saved_locations` và 1 ảnh duy nhất còn lại từ `shift_delivery_points` (6 dòng ảnh khác trong `shift_delivery_points` là liên kết trùng URL của cùng khách hàng nên được bỏ qua bởi `NOT EXISTS`).
        - Tổng số dòng `customer_photos` được tạo: **4 dòng**.
        - Toàn bộ ảnh cũ đều có `created_by` hợp lệ (`d0000000-0000-0000-0000-000000000001` - Trần Văn Giao Shipper A), không có bản ghi nào bị bỏ sót hay vi phạm khóa ngoại.
        - Chạy lại lần 2: Trả về `INSERT 0 0`, chứng minh 100% idempotent không nhân đôi dữ liệu.
      * **Migration 07 ([07-add-shift-name.sql](file:///d:/flutter create delivery_marker_app/init-db/07-add-shift-name.sql)):**
        - Thêm cột `shift_name VARCHAR(100) NULL` vào bảng `shifts` và tạo chỉ mục `idx_shifts_shift_name`.
        - 7 ca làm việc hiện hữu giữ nguyên `shift_code`, trường `shift_name` là `NULL`.
        - Chạy lại lần 2: Thông báo cột và chỉ mục đã tồn tại, bỏ qua an toàn.
      * **Đối soát dữ liệu khách Anh Hoàng (`c0000000-0000-0000-0000-000000000001`):**
        - Hồ sơ khách hàng, mã `KH_001`, SĐT `0988000001`, địa chỉ `Hẻm 124 Nguyễn Xiển` giữ nguyên 100%.
        - Vị trí `e0000000-0000-0000-0000-000000000001` (10.8422150, 106.8181230), ghi chú mặt tiền nhà giữ nguyên 100%.
        - Bảng `customer_photos` gắn đúng 2 ảnh cho Anh Hoàng: `/api/v1/photos/6ffc3833-1f78-48c8-8624-3041f25449f9.jpg` và `/api/v1/photos/test_verified.jpg`.
    - **3. Kiểm tra Mã Nguồn Hợp Nhất & Phục Vụ Ảnh (`servePhoto`):**
      * [main_map_view.dart](file:///d:/flutter create delivery_marker_app/mobile_app/lib/views/main_map_view.dart) và [shift_map_view.dart](file:///d:/flutter create delivery_marker_app/mobile_app/lib/views/shift_map_view.dart) đều tích hợp đầy đủ thẻ chi tiết nhiều ảnh `PointDetailBottomSheet` (015A) VÀ cụm nút hành động ngón cái "Tạo ca" / "DÁN DANH SÁCH SĐT" (015B).
      * Ảnh của `customer_photos` được lưu tại `/app/uploads/photos` trong container, nằm trọn vẹn trong volume `backend_uploads` được mount vào `/app/uploads`.
      * Cập nhật regex trong `servePhoto` ([locations.controller.ts](file:///d:/flutter create delivery_marker_app/backend/src/controllers/locations.controller.ts)) thành `/^(cust-photo-)?[0-9a-fA-F-]{36}\.(jpg|jpeg|png|webp)$/` để chấp nhận cả UUID thuần và tiền tố `cust-photo-`. Bổ sung unit test trong [location.spec.ts](file:///d:/flutter create delivery_marker_app/backend/test/location.spec.ts) và integration test trong [multi-photo-015.integration.spec.ts](file:///d:/flutter create delivery_marker_app/backend/test/multi-photo-015.integration.spec.ts).
    - **4. Kết quả kiểm thử toàn bộ hệ thống:**
      * `npm --prefix backend run build`: Biên dịch TypeScript ra `dist/` **0 lỗi**.
      * `npm --prefix backend test`: **11 test suites passed, 152/152 tests passed (100%)**.
      * `npm --prefix backend run test:integration`: **6 test suites passed, 55/55 tests passed (100%)**.
      * `flutter analyze`: **0 issues found** (No issues found!).
      * `flutter test`: **13 test suites passed, 87/87 tests passed (100%)**.
      * Test suites thất bại: **0**.
    - **5. Dựng lại Backend & Build APK:**
      * Backend container: `docker compose up -d --build backend` hoàn thành, API phản hồi `GET http://localhost:3000/api/docs/` mã **200 OK**.
      * Build APK: `flutter build apk --debug` hoàn thành lúc **15:21:50 ngày 25/10/2026** tại `mobile_app/build/app/outputs/flutter-apk/app-debug.apk` (dung lượng: **184,718,791 bytes**, ~184.7 MB).
    - **6. Phân định thực tế kiểm thử:**
      * **[ĐÃ TEST]:** Toàn bộ automated tests (152 backend tests, 87 mobile tests), xác minh liveness GET 200 OK, kiểm tra truy vấn đọc trên `delivery_db`.
      * **[CHƯA THỬ TRÊN ĐIỆN THOẠI THẬT]:** Chưa nạp APK lên thiết bị di động vật lý ngoài thực địa.
42. **[ĐÃ HOÀN TẤT - TASK: PHOTO-SYNC-SHIFT-PICKER-BULK-016] Đồng Bộ Ảnh Khách Hàng Toàn Diện, Bộ Chọn Ca Từ Bản Đồ Chính & Nhập Hàng Loạt SĐT Trong Chuẩn Bị Ca:**
    - **1. Trạng Thái Áp Dụng Migration Lên CSDL Thật (`delivery_db`):**
      * **Đã áp migration lên DB thật chưa:** Không có file migration mới trong Task 016. Cả 7 file migration (`01` đến `07`) đã được áp đầy đủ lên `delivery_db` và `test_isolated_seed_db` từ Task 015C.
      * Bảng `customer_photos` và cột `shifts.shift_name` đã hiện hữu và hoạt động ổn định trên `delivery_db`.
    - **2. Báo Cáo Điều Tra Nguyên Nhân Gốc (Phần A.1 - Chỉ GET/SELECT kiểm tra sống):**
      * *(a) Bảng `customer_photos` trên `delivery_db`:* Đã tồn tại với đầy đủ các cột (`id`, `customer_id`, `image_url`, `created_by`, `created_at`, `deleted_at`).
      * *(b) Vị trí lưu ảnh tải từ thẻ điểm của bản đồ ca:* Khi chụp ảnh từ `PointDetailBottomSheet`, client gọi `POST /api/v1/customers/:customerId/photos`. Controller `customer-photos.controller.ts` ghi tệp vật lý vào thư mục `/app/uploads/photos/<uuid>.<ext>` (nằm trọn vẹn trong Docker volume `backend_uploads`) và tạo một dòng bản ghi mới trong bảng `customer_photos`.
      * *(c) Nguồn đọc ảnh của `customer_directory_view.dart` và hồ sơ khách:* Trước Task 016, API `GET /api/v1/customers` trong `customers.controller.ts` chỉ thực hiện `LEFT JOIN` với bảng `saved_locations` (`sl.image_url`) và `shift_delivery_points` (`sdp.image_url`), hoàn toàn chưa kết nối bảng `customer_photos`. Do đó, bất kỳ ảnh chụp nào gắn với điểm ca chưa có vị trí cố định (`NO_LOCATION`) hoặc chỉ lưu trong `customer_photos` đều không thể xuất hiện trong Danh bạ hoặc Hồ sơ khách.
    - **3. Chi Tiết Thay Đổi & Giải Pháp Kỹ Thuật:**
      * **A. Đồng bộ ảnh khách hàng toàn diện (MỌI màn hình dùng chung `customer_photos`):**
        - **Backend ([customers.controller.ts](file:///d:/flutter create delivery_marker_app/backend/src/controllers/customers.controller.ts)):**
          * Bổ sung `LEFT JOIN LATERAL` tổng hợp dữ liệu từ `customer_photos cp` (`WHERE cp.customer_id = c.id AND cp.deleted_at IS NULL`): đếm `photo_count`, lấy `latest_photo_url`, gom danh sách mảng JSON `photos_json`.
          * Cập nhật bộ lọc `hasPhoto` để tìm kiếm trên cả `customer_photos` lẫn trường ảnh cũ.
          * Trả về `photoCount`, mảng `photos` và ưu tiên `latest_photo_url` làm `imageUrl` đại diện.
          * Cập nhật `getCustomerDetail` truy vấn trực tiếp bảng `customer_photos` kèm `photoCount` và `photos`.
        - **Mobile Shared Widget ([customer_photos_strip_widget.dart](file:///d:/flutter create delivery_marker_app/mobile_app/lib/widgets/customer_photos_strip_widget.dart)):**
          * Tạo widget dải nhiều ảnh dùng chung cho Danh bạ, Hồ sơ khách, Bản đồ chính, Bản đồ ca và Thẻ điểm.
          * Hỗ trợ nút lớn "+ THÊM ẢNH" (chiều cao >= 56px), chụp trực tiếp hoặc chọn thư viện, nén ảnh tự động trước khi gửi.
          * Xử lý lỗi tải ảnh: Khi API trả lỗi (kể cả lỗi HTTP 500), hiển thị SnackBar cảnh báo người dùng rõ ràng kèm thông điệp chi tiết, tuyệt đối không im lặng nuốt lỗi.
          * Nhấn giữ hoặc bấm nút xóa ảnh: Hiển thị hộp thoại xác nhận xóa mềm, gọi `ApiService.deleteCustomerPhoto`.
          * Vô hiệu hóa cache cũ ngay sau khi thêm/xóa: Gọi `PaintingBinding.instance.imageCache.clear()` và `clearLiveImages()`, kích hoạt callback `onPhotosUpdated()` để làm mới dữ liệu tức thì cho tất cả các màn hình liên quan khi quay lại.
        - **Cập nhật Màn hình & Thẻ điểm:**
          * [customer_directory_view.dart](file:///d:/flutter create delivery_marker_app/mobile_app/lib/views/customer_directory_view.dart): Thẻ khách hàng hiển thị badge số lượng ảnh nếu có nhiều hơn 1 ảnh; màn hình Hồ sơ khách (`CustomerDetailEditView`) nhúng `CustomerPhotosStripWidget` cho phép xem, thêm và xóa ảnh độc lập không cần ghim lại GPS.
          * [point_detail_bottom_sheet.dart](file:///d:/flutter create delivery_marker_app/mobile_app/lib/widgets/point_detail_bottom_sheet.dart): Tích hợp `CustomerPhotosStripWidget` thay thế toàn bộ khối xử lý ảnh đơn lẻ cũ.
      * **B. Chọn ca từ bản đồ chính ([main_map_view.dart](file:///d:/flutter create delivery_marker_app/mobile_app/lib/views/main_map_view.dart), [shift_picker_bottom_sheet.dart](file:///d:/flutter create delivery_marker_app/mobile_app/lib/widgets/shift_picker_bottom_sheet.dart)):**
        - Thêm nút "Ca làm việc" lớn (cao >= 56px, `btn_open_shift_picker`) vào vùng ngón cái sát đáy bản đồ chính. Thiết kế bố cục 2 tầng: tầng trên gồm "Ca làm việc" (flex 1) song song với "Tạo ca" (flex 1), tầng dưới là nút "Ghim vị trí mới" (chiều rộng tối đa), tuyệt đối không chồng lấn hay che khuất nhau.
        - Chạm "Ca làm việc" mở `ShiftPickerBottomSheet` liệt kê các ca của shipper: hiển thị `shiftName` (nếu rỗng lấy `shift_code`), ngày tạo, badge trạng thái, số điểm đã có vị trí vs chưa có vị trí, sắp xếp mới nhất trước.
        - Mục đầu danh sách: Thẻ bấm nhanh "+ Tạo ca làm việc mới".
        - Mỗi dòng ca có menu tác vụ (PopupMenuButton) hỗ trợ "Đổi tên ca" (`PATCH /api/v1/shifts/:id/name`) và "Xóa ca" (`DELETE /api/v1/shifts/:id`) với hộp thoại xác nhận.
        - Khi chưa có ca nào: Hiển thị hướng dẫn ngắn gọn và nút lớn "+ TẠO CA MỚI".
        - Chạm vào một ca: Chuyển hướng trực tiếp vào bản đồ ca `ShiftMapView(shiftId: shift.id)`.
      * **C. Nhập hàng loạt SĐT trong màn Chuẩn bị ca ([shift_preparation_view.dart](file:///d:/flutter create delivery_marker_app/mobile_app/lib/views/shift_preparation_view.dart)):**
        - Bổ sung nút lớn "NHẬP HÀNG LOẠT SĐT" (chiều cao 56px, `btn_bulk_paste_phones`) cạnh ô nhập một số.
        - Tái sử dụng trực tiếp bottom sheet `BulkPastePhoneSheet.show` (không code lại logic trùng lặp).
        - Sau khi dán danh sách SĐT thành công: Tự động tải lại danh sách điểm của ca ngay lập tức, hiển thị bảng banner tổng kết phân tách rõ 2 nhóm: "Đã có vị trí" và "Chưa có vị trí - cần xác nhận", cùng danh sách các số bị từ chối kèm lý do cụ thể.
        - Giữ nguyên ô nhập một số điện thoại để hỗ trợ thao tác thêm nhanh từng số đơn lẻ.
    - **4. Kết quả kiểm thử tự động & Nghiệm thu:**
      * **Backend Integration Tests ([photo-sync-016.integration.spec.ts](file:///d:/flutter create delivery_marker_app/backend/test/photo-sync-016.integration.spec.ts)):** Đạt **4/4 tests passed (100%)** trên CSDL `test_isolated_seed_db` gọi controller thật:
        - Kiểm tra khách hàng ban đầu 0 ảnh: API danh bạ và chi tiết trả đúng `photoCount = 0`, `photos = []`.
        - Thêm ảnh qua `addCustomerPhoto`: Xuất hiện ngay lập tức trong `listCustomers` và `getCustomerDetail`, đếm đúng `photoCount = 1`, `imageUrl` cập nhật trỏ về ảnh vừa tải.
        - Thêm ảnh thứ hai: `photoCount = 2`, `imageUrl` ưu tiên ảnh mới nhất theo thứ tự thời gian.
        - Xóa mềm ảnh (`deleteCustomerPhoto`): Biến mất hoàn toàn khỏi danh bạ và chi tiết khách hàng, các ảnh chưa xóa còn lại vẫn hiển thị nguyên vẹn, đảm bảo tính toàn vẹn kiểm toán `audit_logs`.
      * **Backend Full Test Suite:** `npm test` đạt **12 test suites passed, 156/156 tests passed (100%)**. TypeScript `npm run build` biên dịch 0 lỗi.
      * **Flutter Tests ([photo_sync_and_shift_picker_016_test.dart](file:///d:/flutter create delivery_marker_app/mobile_app/test/photo_sync_and_shift_picker_016_test.dart)):** Viết 4 widget tests kiểm tra toàn diện:
        - `CustomerPhotosStripWidget`: Hiển thị danh sách ảnh, nút `empty_photo_slot` >= 56px, gọi callback cập nhật ảnh.
        - `MainMapView`: Kiểm tra vùng ngón cái có đủ 3 nút hành động (`btn_open_shift_picker`, `btn_create_shift_map`, `btn_pin_new_location`), tất cả đều đạt kích thước >= 56px và không bị chồng đè.
        - `ShiftPreparationView`: Kiểm tra có đủ nút "NHẬP HÀNG LOẠT SĐT" (>= 56px) và ô nhập một số `btn_add_single_phone`.
        - `CustomerModel`: Kiểm tra parsing JSON `photoCount`, `photos`, và logic getter `hasPhoto`.
      * **Flutter Full Test Suite:** `flutter test` đạt **14 test files passed, 91/91 tests passed (100%)**. `flutter analyze lib/` đạt **0 issues found** (No issues found!).
      * **Dựng lại Container Backend:** `docker compose up -d --build backend` hoàn thành MỘT LẦN duy nhất (`delivery_backend_api` Recreated & Started, `delivery_postgis_db` Healthy giữ nguyên không đụng chạm).
      * **Kiểm tra API sống:** `GET http://localhost:3000/api/docs/` phản hồi **200 OK**. Tuyệt đối không gửi request ghi (POST/PUT/PATCH/DELETE) nào lên API sống hay `delivery_db`.
      * **Build Debug APK:** Tiến hành chạy `flutter build apk --debug` MỘT LẦN duy nhất.
    - **5. Phân định thực tế kiểm thử (Evidence-Based):**
      * **[ĐÃ TEST]:** Toàn bộ automated unit & integration tests trên `test_isolated_seed_db` và Flutter test runner (156 backend tests, 91 Flutter tests), xác minh liveness GET 200 OK trên backend container sống.
      * **[CHƯA THỬ TRÊN ĐIỆN THOẠI THẬT]:** Chưa nạp file APK lên thiết bị di động vật lý ngoài thực địa.

43. **[ĐÃ HOÀN TẤT - TASK: MAP-COMPACT-CONTROLS-AND-SHEET-CLOSE-017] Thu Gọn Cụm Nút Bản Đồ Thành Cột Icon & Bổ Sung Cơ Chế Đóng Thẻ Chi Tiết Điểm:**
    - **1. Mục Tiêu & Phạm Vi (Frontend UI Only):**
      * Thay đổi hoàn toàn ở tầng giao diện Flutter, không thay đổi backend và không thay đổi cấu trúc dữ liệu.
      * Không dựng lại container backend do backend giữ nguyên 100%.
    - **2. Chi Tiết Thực Hiện & Giải Pháp Kỹ Thuật:**
      * **A. Bản đồ chính ([main_map_view.dart](file:///d:/flutter create delivery_marker_app/mobile_app/lib/views/main_map_view.dart)):**
        - Bỏ 3 nút chữ to chiếm nhiều không gian dưới đáy.
        - Thay bằng 1 cột icon dọc gọn ở mép PHẢI phía dưới (vùng ngón cái, ngay trên thanh điều hướng):
          * **Ghim vị trí mới:** Nút tròn chính dưới cùng, to nhất (đường kính 60px), màu xanh `#2563EB`, icon `Icons.add_location_alt_rounded`.
          * **Tạo ca:** Nút tròn ở giữa (đường kính 52px), nền Navy `#0F172A`, icon `Icons.add_task_rounded`.
          * **Ca làm việc:** Nút tròn trên cùng (đường kính 52px), nền trắng viền xám `#CBD5E1`, icon `Icons.work_history_rounded`.
          * Khoảng cách giữa các nút >= 12px. Icon-only nhưng có Tooltip và Semantics label đầy đủ tên chức năng. Chạm nút hoạt động chính xác theo luồng nghiệp vụ hiện tại.
        - Giữ nguyên các nút GPS và "vừa khít điểm" ở góc trên bên phải, không bị chồng lấn.
        - Thu thanh tiêu đề trên cùng "Bản đồ vị trí đã lưu" thành thanh mảnh (cao 48px <= 52px), giữ nguyên nút đổi lớp bản đồ và làm mới.
        - Tự động ẩn cột icon khi bật chế độ tâm ngắm ghim vị trí mới (hiện lại khi thoát).
        - Tự động ẩn cột icon khi thẻ chi tiết điểm mở ra, hoàn toàn không bị thẻ che khuất.
      * **B. Thẻ chi tiết điểm ([point_detail_bottom_sheet.dart](file:///d:/flutter create delivery_marker_app/mobile_app/lib/widgets/point_detail_bottom_sheet.dart)):**
        - Thêm nút tắt X (vùng chạm >= 48px, `btn_close_point_detail`) ở góc phải trên cùng của thẻ, màu sắc tương phản cao ngoài nắng.
        - Đa dạng cơ chế tắt thẻ đồng bộ cho cả Bản đồ chính và Bản đồ ca:
          * Bấm nút tắt X.
          * Vuốt thẻ xuống (drag handle / swipe gesture).
          * Chạm vào vùng bản đồ trống bên ngoài thẻ (`MapOptions.onTap`).
          * Bấm nút Back của hệ thống/trình duyệt (`PopScope`).
        - Khi thẻ đóng, gán `_selectedLocation = null` / `_selectedPoint = null`, lập tức bỏ trạng thái "đang chọn" (không còn highlight) của chấm trên bản đồ.
        - Chiều cao ban đầu của thẻ ~45-46% màn hình (365px - 480px) để shipper vừa xem thẻ vừa quan sát được bản đồ; hỗ trợ vuốt lên để mở rộng lên 85% xem hết ảnh, địa chỉ và ghi chú.
        - Đóng thẻ không làm mất ảnh vừa tải lên hay dữ liệu đang xem.
      * **C. Bản đồ ca ([shift_map_view.dart](file:///d:/flutter create delivery_marker_app/mobile_app/lib/views/shift_map_view.dart)):**
        - Áp dụng đầy đủ cơ chế đóng thẻ như Mục B (nút X, vuốt xuống, chạm nền bản đồ, nút Back qua `PopScope`).
        - Thay cụm nút chữ to dưới đáy thành cột icon tròn 56px ở mép phải dưới gồm "Dán danh sách SĐT" (xanh `#2563EB`, `btn_bulk_paste_phones`) và "Chọn vị trí" (Navy `#0F172A`, `btn_choose_location`) kèm Tooltip và Semantics label.
    - **3. Kết Quả Kiểm Thử Tự Động & Nghiệm Thu:**
      * **Flutter Widget Tests Mới ([compact_controls_and_sheet_close_017_test.dart](file:///d:/flutter create delivery_marker_app/mobile_app/test/compact_controls_and_sheet_close_017_test.dart)):** Đạt **3/3 widget tests passed (100%)**:
        - Kiểm tra cột icon 3 nút ở góc phải dưới của `MainMapView`, mỗi nút vùng chạm >= 52px (Ghim 60px, Tạo ca 52px, Ca làm việc 52px), có Tooltip, khoảng cách >= 12px; chế độ tâm ngắm tự động ẩn cột icon.
        - Kiểm tra `PointDetailBottomSheet` có nút tắt X vùng chạm >= 48px, bấm X kích hoạt callback `onClose()`.
        - Kiểm tra `ShiftMapView` có cột icon tròn 56px có Tooltip.
      * **Flutter Full Test Suite:** `flutter test` đạt **15 test files passed, 94/94 tests passed (100%)**.
      * **Flutter Static Analysis:** `flutter analyze` đạt **No issues found!** (0 cảnh báo, 0 lỗi).
      * **Backend Test Suite & Build:** TypeScript `npm run build` 0 lỗi, `npm test` đạt **12 test suites passed, 156/156 tests passed (100%)**.
      * **Build Debug APK:** Tiến hành chạy `flutter build apk --debug` MỘT LẦN duy nhất.
    - **4. Phân Định Thực Tế Kiểm Thử (Evidence-Based):**
      * **[ĐÃ TEST]:** Toàn bộ automated tests (156 backend tests, 94 Flutter tests), kiểm tra tĩnh `flutter analyze` 0 issues.
      * **[CHƯA THỬ TRÊN ĐIỆN THOẠI THẬT]:** Chưa nạp và thử nghiệm APK trực tiếp trên thiết bị di động vật lý ngoài thực địa.

44. **[ĐÃ HOÀN TẤT - TASK: MAP-SMOOTH-AND-REPIN-FIX-019] Sửa Lỗi "Ghim Lại" Bắt Nhập Lại SĐT & Tối Ưu Kéo/Zoom Bản Đồ Mượt Hơn:**
    - **1. Mục Tiêu & Phạm Vi (Frontend Mobile Only):**
      * Sửa triệt để lỗi khi bấm "Ghim lại" từ thẻ chi tiết điểm bắt shipper phải gõ lại số điện thoại khách hàng.
      * Tăng tốc độ và độ mượt khi kéo (pan) và phóng to/thu nhỏ (zoom) bản đồ trên cả Bản đồ chính (`MainMapView`), Bản đồ ca (`ShiftMapView`) và Bộ chọn tâm ngắm (`CrosshairLocationPickerView`).
      * Giữ nguyên 100% giao diện, nghiệp vụ và dữ liệu: Tuyệt đối KHÔNG thêm Lite Mode, KHÔNG lưu dữ liệu khách hàng cục bộ, KHÔNG thay đổi backend hay CSDL.
    - **2. Chi Tiết Kỹ Thuật Đã Triển Khai:**
      * **A. Sửa lỗi luồng "Ghim lại" không bắt nhập lại số điện thoại:**
        - **Bản đồ chính ([main_map_view.dart](file:///d:/flutter create delivery_marker_app/mobile_app/lib/views/main_map_view.dart)):**
          * Khi bấm "Ghim lại" trên thẻ chi tiết điểm (`PointDetailBottomSheet`), lưu thông tin khách hàng đang chọn vào `_repinTarget = loc` trước khi mở chế độ tâm ngắm.
          * Khi bấm "XÁC NHẬN VỊ TRÍ NÀY" ở tâm ngắm, hộp thoại gán SĐT tự động điền sẵn SĐT (`phoneCtrl.text = _repinTarget!.customerPhone`), tên (`nameCtrl.text = _repinTarget!.customerName ?? ''`) và ghi chú (`notesCtrl.text = _repinTarget!.identificationNotes ?? ''`).
          * Hiển thị banner nổi bật `repin_customer_banner`: `"Đang ghim lại cho: [tên] - [SĐT]"` kèm nút nhỏ `"Đổi số"` (`btn_change_repin_phone`). Bấm "Đổi số" sẽ xóa form và chuyển sang gán cho số khác.
          * Nút "LƯU VỊ TRÍ NÀY" (`btn_confirm_save_location`) bấm được ngay lập tức mà không cần gõ lại gì.
          * Giữ nguyên quy trình: Nếu khách đã có vị trí, hệ thống vẫn hiển thị hộp thoại xác nhận thay thế vị trí cũ, bảo toàn toàn bộ lịch sử trong `location_history`.
        - **Bản đồ ca ([shift_map_view.dart](file:///d:/flutter create delivery_marker_app/mobile_app/lib/views/shift_map_view.dart)):**
          * Bấm "Ghim lại" gọi `_openCrosshairPickerForPoint(point)`, truyền nguyên vẹn `ShiftDeliveryPointModel` (`customerId`, SĐT, tên, địa chỉ, trạng thái) sang `CrosshairLocationPickerView`.
          * Trong ca, bấm "Lưu vị trí tạm" chỉ gọi `ApiService.updateTemporaryLocation`, cập nhật tọa độ tạm cho điểm giao trong ca (`shift_delivery_points`), tuyệt đối không làm biến đổi hay đụng chạm `saved_locations` của hệ thống.
        - **Bộ chọn tâm ngắm ([crosshair_location_picker_view.dart](file:///d:/flutter create delivery_marker_app/mobile_app/lib/views/crosshair_location_picker_view.dart)):**
          * Hiển thị banner trực quan `repin_customer_banner`: `"Đang ghim lại cho: ${widget.point.customerName} - ${widget.point.customerPhone}"`.
          * Nút "Lưu vị trí tạm" được kích hoạt sẵn sàng bấm ngay lập tức.
        - **Luồng "Ghim vị trí mới":** Giữ nguyên form trống, autofocus vào ô SĐT, không hiển thị banner ghim lại, ngăn chặn lưu khi SĐT chưa được nhập.
      * **B. Tối ưu kéo/zoom bản đồ mượt hơn (Map Smoothness):**
        - **Cache tile trên đĩa ([map_tile_cache_service.dart](file:///d:/flutter create delivery_marker_app/mobile_app/lib/services/map_tile_cache_service.dart)):**
          * Xây dựng `MapTileCacheService` quản lý bộ nhớ đệm mảnh bản đồ trên đĩa với dung lượng tối đa **200MB** (`maxCacheSizeBytes = 200 * 1024 * 1024`), tự động dọn dẹp (LRU/Prune) về 150MB khi đạt ngưỡng.
          * Cơ chế lọc nghiêm ngặt `isMapTileUrl` và `containsCustomerPhoto`: **Chỉ cho phép cache tile bản đồ (OpenStreetMap, Google Maps, CartoDB); tuyệt đối CẤM cache bất kỳ ảnh hiện trường hay ảnh khách hàng nào** (`/photos/`, `/uploads/`, `/avatar/`).
        - **Đệm tile trước khung nhìn (Pre-buffering):** Cấu hình `TileLayer` với `panBuffer: 1`, `keepBuffer: 2`, giữ lại tile cũ ở zoom thấp trong thời gian nạp mảnh mới, loại bỏ hoàn toàn hiện tượng ô trắng khi lướt bản đồ.
        - **Cancellable Tile Provider & Giới hạn Concurrency:**
          * Triển khai `CancellableDiskCachedTileProvider` (kế thừa `TileProvider`) và `CancellableTileImageProvider`.
          * Giới hạn tối đa **10 yêu cầu HTTP đồng thời** (`maxConcurrentRequests = 10`) qua hàng đợi semaphore, tự động hủy bỏ (abort/cancel) các yêu cầu tile trôi ra ngoài khung nhìn khi shipper lướt nhanh.
        - **Tối ưu gom cụm Marker (Viewport Clustering & Debounce):**
          * Trong `MainMapView`, hàm `_recomputeClusters` chỉ tính toán các điểm nằm trong khung nhìn hiển thị (visible bounds mở rộng 15% biên).
          * Thêm cơ chế Debounce **150ms** khi shipper đang kéo bản đồ (`hasGesture == true`), tránh tính toán lại cụm liên tục trên từng frame cử chỉ.
          * Lưu cache kết quả gom cụm theo zoom và viewport (`_clusterCache`).
        - **Cô lập Render Pipeline với `RepaintBoundary`:**
          * Bao bọc `RepaintBoundary` quanh `FlutterMap`, Header nổi, Cột icon hành động và Thẻ chi tiết điểm `PointDetailBottomSheet` trên cả 3 màn hình (`MainMapView`, `ShiftMapView`, `CrosshairLocationPickerView`).
          * Cắt đứt hoàn toàn việc Rasterization của lớp bản đồ lan sang các thành phần giao diện tĩnh phía trên, giảm tải render pipeline cho GPU thiết bị.
    - **3. Kết Quả Kiểm Thử Tự Động & Nghiệm Thu:**
      * **Automated Tests Mới ([map_smooth_and_repin_019_test.dart](file:///d:/flutter create delivery_marker_app/mobile_app/test/map_smooth_and_repin_019_test.dart)):** Đạt **6/6 tests passed (100%)**:
        - `B.1 & B.7`: Cache tile trên đĩa tối đa 200MB, kiểm tra các URL tile hợp lệ và xác nhận tuyệt đối từ chối cache ảnh khách hàng (`isMapTileUrl` / `containsCustomerPhoto`).
        - `B.3`: Giới hạn tối đa 10 yêu cầu HTTP đồng thời của `CancellableDiskCachedTileProvider`.
        - `B.5`: Cô lập render bản đồ bằng `RepaintBoundary`.
        - `A.3`: Luồng "Ghim vị trí mới" giữ hộp thoại trống và nút lưu từ chối khi chưa có SĐT.
        - `A.1, A.2`: Thẻ chi tiết kích hoạt callback `onRepin` và nút "Đổi số".
        - `A.1, A.2, A.4`: Bộ chọn tâm ngắm hiển thị banner "Đang ghim lại cho..." và cho phép lưu vị trí tạm trong ca ngay lập tức.
45. **[ĐÃ HOÀN TẤT - TASK: UI-REDESIGN-DIRECTORY-AND-SHIFTS-021] Thiết Kế Lại Giao Diện Danh Bạ & Danh Sách Ca Làm Việc Theo Thiết Kế Chuẩn:**
    - **1. Mục Tiêu & Phạm Vi (Frontend Mobile & Backend Optimization):**
      * Cải tiến toàn diện giao diện màn hình **Danh bạ** ([customer_directory_view.dart](file:///d:/flutter create delivery_marker_app/mobile_app/lib/views/customer_directory_view.dart)) và **Danh sách ca** ([shift_list_view.dart](file:///d:/flutter create delivery_marker_app/mobile_app/lib/views/shift_list_view.dart)) bám sát ảnh thiết kế mẫu `docs/design/danh-ba.png` và `docs/design/ca-lam-viec.png`.
      * Bảo toàn 100% quy tắc nghiệp vụ đã chốt: `LOCATION-RULES-012`, quy trình xóa ca an toàn, dải nhiều ảnh khách hàng, bảo toàn thanh điều hướng 3 tab (`Bản đồ` / `Danh bạ` / `Ca làm việc`).
      * Tuân thủ triệt để Design System: Màu nền `#F8FAFC`, chữ/navy `#0F172A`, phụ lục `#64748B`, viền `#E2E8F0`, màu trạng thái (xanh dương `#2563EB`, xanh lục `#10B981`, cam `#F59E0B`). Vùng chạm tối thiểu >= 48px cho toàn bộ các nút bấm và icon tương tác. Cỡ chữ chính >= 14sp, ghi chú >= 12sp. Tiếng Việt hoàn chỉnh không lỗi phông.
    - **2. Chi Tiết Kỹ Thuật Đã Triển Khai:**
      * **A. Tối ưu Backend Controller ([customers.controller.ts](file:///d:/flutter create delivery_marker_app/backend/src/controllers/customers.controller.ts)):**
        - Cập nhật API `GET /api/customers` tính toán chuẩn xác `locationState` cho từng khách hàng theo 3 trạng thái:
          * `VERIFIED`: Khách hàng có bản ghi trong `saved_locations` (`sl.id IS NOT NULL`), kể cả khi khách hàng đó đồng thời đang có điểm tạm trong ca làm việc.
          * `TEMPORARY`: Khách hàng chưa có vị trí đã lưu (`sl.id IS NULL`), nhưng có bản ghi `shift_delivery_points` mang trạng thái `TEMPORARY` trong ca đang hoạt động (`PREPARING` hoặc `IN_PROGRESS`) của chính shipper đang truy vấn. Tuyệt đối không tính điểm tạm thuộc ca của shipper khác.
          * `NO_LOCATION`: Các trường hợp còn lại.
        - Bổ sung trường `firstThumbnailUrl` trỏ tới ảnh đầu tiên (ưu tiên ảnh từ `customer_photos`, kế tiếp là ảnh từ `shift_delivery_points`).
        - Trả về đối tượng `counts: { total, verified, temporary, noLocation }` phản ánh chính xác số lượng khách theo từng nhóm trạng thái tương ứng với từ khóa tìm kiếm.
        - Trả về đối tượng `pagination: { total, limit, offset, hasMore }` kết hợp phân trang SQL `LIMIT / OFFSET`.
        - Hỗ trợ tìm kiếm thông minh: Không phân biệt dấu tiếng Việt (`unaccent`) và không phân biệt khoảng trắng (cho phép tìm SĐT dạng có khoảng cách như `"0908 333 166"`).
        - Sửa lỗi câu truy vấn đếm (`countSql`): Bổ sung `sdp.image_url` vào mệnh đề `LEFT JOIN LATERAL`, giúp bộ lọc `hasPhoto=true` vận hành chuẩn xác mà không gây lỗi 500.
      * **B. Mở rộng Model & Service Mobile App:**
        - [customer_model.dart](file:///d:/flutter create delivery_marker_app/mobile_app/lib/models/customer_model.dart): Bổ sung `locationState`, `firstThumbnailUrl`, các class `CustomerTabCounts`, `CustomerPagination`, `CustomerDirectoryResponse`. Bổ sung getter `formattedPhoneNumber` định dạng hiển thị số điện thoại cách 4-3-3 (ví dụ `0908 333 166`).
        - [api_service.dart](file:///d:/flutter create delivery_marker_app/mobile_app/lib/services/api_service.dart): Mở rộng `getCustomers` hỗ trợ phân trang `limit` & `offset`, bổ sung hàm `getCustomersResponse` nhận đầy đủ cấu trúc response chứa `counts` và `pagination`.
      * **C. Thiết kế lại Màn hình Danh bạ ([customer_directory_view.dart](file:///d:/flutter create delivery_marker_app/mobile_app/lib/views/customer_directory_view.dart)):**
        - Tiêu đề "Danh bạ" kèm badge hiển thị tổng số khách hàng. Góc phải có nút chữ "+ Thêm số" mở hộp thoại thêm khách nhanh `showQuickAddCustomerBottomSheet` (chỉ cần SĐT).
        - Ô tìm kiếm bo tròn với gợi ý: "Tìm số điện thoại, tên, địa chỉ...".
        - Thanh tab cuộn ngang lọc nhanh hiển thị số đếm động từ backend: `Tất cả` | `Đã xác minh` (chấm xanh lục) | `Vị trí tạm` (chấm cam) | `Chưa có vị trí` (chấm xám).
        - Danh sách khách hàng với từng hàng trực quan:
          * Hộp ảnh vuông bo góc kích thước 48x48px (placeholder icon máy ảnh khi chưa có ảnh), góc dưới phải gắn chấm tròn trạng thái vị trí (xanh lục / cam / xám).
          * Dòng 1: Số điện thoại định dạng chuẩn cách 4-3-3 in đậm kết hợp tên khách hàng (`0908 333 166 · Tên`).
          * Dòng 2: Địa chỉ rút gọn 1 dòng với hiệu ứng cắt ngắn nếu dài.
          * Mép phải: Nút tròn "+" với vùng chạm chuẩn >= 48px.
        - Tương tác chạm hàng: Mở màn hình chi tiết khách hàng [CustomerDetailEditView](file:///d:/flutter create delivery_marker_app/mobile_app/lib/views/customer_detail_edit_view.dart) (giữ nguyên đầy đủ tính năng sửa thông tin, xem/thêm/xóa nhiều ảnh, tra cứu lịch sử vị trí).
        - Tương tác nút "+":
          * Nếu có đúng 1 ca khả dụng: Thêm trực tiếp điểm giao vào ca và hiển thị SnackBar xác nhận kèm nút "HOÀN TÁC".
          * Nếu có nhiều ca: Mở bottom sheet chọn ca nhận điểm.
          * Nếu chưa có ca nào: Hiển thị dialog hỏi tạo ca mới, điều hướng tới `CreateShiftBottomSheet`, sau khi tạo tự động gán khách vào ca.
          * Nếu khách đã có sẵn trong ca: Hiển thị SnackBar "Đã có trong ca".
        - Phân trang cuộn vô tận (`ListView.builder`, nạp 30 khách/trang), hiển thị loading indicator khi tải thêm, empty state "Chưa có khách nào" và error state kèm nút "Thử lại".
      * **D. Thiết kế lại Màn hình Ca làm việc ([shift_list_view.dart](file:///d:/flutter create delivery_marker_app/mobile_app/lib/views/shift_list_view.dart)):**
        - Tiêu đề "Ca làm việc" cùng nút bấm màu Navy "+ Tạo ca mới" (vùng chạm >= 48px) mở `CreateShiftBottomSheet`.
        - Phần "ĐANG THỰC HIỆN" (tự động ẩn khi không có ca `IN_PROGRESS`):
          * Thẻ nổi bật viền xanh bo góc hiển thị: Tiêu đề ca, mã ca, ngày tạo, số lượng điểm giao, thanh tiến độ % hoàn thành, dòng thống kê phân loại ("X Đã xác minh · Y Tạm · Z Chưa có").
          * Nút 3 chấm "..." cung cấp menu Đổi tên ca và Xóa ca (kèm cảnh báo an toàn dữ liệu).
          * 2 nút hành động lớn dưới đáy thẻ (chiều cao >= 48px): Nút "Dán SĐT" (trắng viền xám) mở form dán danh sách hàng loạt, và nút "Mở bản đồ" (Navy `#0F172A`) chuyển thẳng tới `ShiftMapView`.
        - Phần "DANH SÁCH CA (n)":
          * Hiển thị danh sách các ca còn lại sắp xếp thời gian mới nhất lên đầu.
          * Mỗi hàng hiển thị tiêu đề, chip trạng thái (Chuẩn bị = Vàng, Đang giao = Xanh dương, Hoàn thành = Xanh lục), số điểm và thời gian, icon thùng rác (vùng chạm >= 48px, có hộp thoại xác nhận an toàn).
        - Tài liệu hóa luồng chuyển trạng thái ca (State Transitions):
          * Ca `PREPARING` $\rightarrow$ `IN_PROGRESS`: Được kích hoạt qua nút "BẮT ĐẦU CA" trong màn hình [ShiftPreparationView](file:///d:/flutter create delivery_marker_app/mobile_app/lib/views/shift_preparation_view.dart).
          * Ca `IN_PROGRESS` $\rightarrow$ `COMPLETED`: Được kích hoạt qua nút "KẾT THÚC CA" / "HOÀN THÀNH CA" trong màn hình [ShiftMapView](file:///d:/flutter create delivery_marker_app/mobile_app/lib/views/shift_map_view.dart).
          * Chạm vào ca `PREPARING` trong danh sách sẽ điều hướng tới `ShiftPreparationView`; chạm vào ca `IN_PROGRESS` hoặc `COMPLETED` sẽ điều hướng tới `ShiftMapView`.
    - **3. Kết Quả Kiểm Thử Tự Động & Nghiệm Thu:**
      * **Backend Integration Tests ([ui-redesign-021.integration.spec.ts](file:///d:/flutter create delivery_marker_app/backend/test/ui-redesign-021.integration.spec.ts)):** Đạt **4/4 tests passed (100%)** trên CSDL `test_isolated_seed_db` gọi controller thật:
        - Kiểm tra tính toán `locationState` cho khách hàng theo đúng 3 trạng thái (`VERIFIED`, `TEMPORARY`, `NO_LOCATION`).
        - Kiểm tra trả về đối tượng `counts` phân loại số lượng chính xác theo từng trạng thái.
        - Kiểm tra phân trang `limit` & `offset` hoạt động chính xác kèm `pagination.hasMore`.
        - Kiểm tra tìm kiếm SĐT không phân biệt khoảng trắng (ví dụ `"0908 333 166"` tìm ra `"0908333166"`).
      * **Backend Full Test Suite:** `npm test` đạt **13 test suites passed, 160/160 tests passed (100%)**. TypeScript `npm run build` biên dịch 0 lỗi.
      * **Flutter Widget Tests Mới ([ui_redesign_021_test.dart](file:///d:/flutter create delivery_marker_app/mobile_app/test/ui_redesign_021_test.dart)):** Đạt **7/7 tests passed (100%)**:
        - `CustomerModel.formattedPhoneNumber`: Định dạng số điện thoại chuẩn 4-3-3.
        - `CustomerDirectoryResponse`: Parse chính xác `counts`, `pagination`, `customers`.
        - `CustomerDirectoryView`: Hiển thị tiêu đề, badge đếm, ô tìm kiếm, nút thêm số.
        - `CustomerDirectoryView`: Hiển thị đúng 4 tab lọc trạng thái kèm số lượng đếm động từ backend.
        - `CustomerDirectoryView`: Render danh sách khách hàng gồm hộp ảnh 48x48, SĐT in đậm, địa chỉ rút gọn và nút "+" có vùng chạm >= 48px.
        - `ShiftListView`: Hiển thị tiêu đề "Ca làm việc", nút tạo ca mới và phần "ĐANG THỰC HIỆN" với đầy đủ 2 nút "Dán SĐT" và "Mở bản đồ".
        - `ShiftListView`: Hiển thị "DANH SÁCH CA", chip trạng thái và icon thùng rác vùng chạm >= 48px.
      * **Flutter Full Test Suite:** `flutter test` đạt **16 test files passed, 107/107 tests passed (100%)**.
      * **Flutter Static Analysis:** `flutter analyze` đạt **No issues found!** (0 cảnh báo, 0 lỗi trên toàn bộ dự án).
      * **Dựng Lại Container Backend:** `docker compose up -d --build backend` hoàn thành MỘT LẦN duy nhất (`delivery_backend_api` Recreated & Started, `delivery_postgis_db` Healthy giữ nguyên không đụng chạm).
      * **Kiểm Tra API Sống:** `GET http://localhost:3000/api/docs/` phản hồi **200 OK**. Tuyệt đối không gửi request ghi nào lên API sống hay `delivery_db`.
      * **Build Release APK:** Thực thi lệnh `flutter build apk --release` MỘT LẦN duy nhất.
    - **4. Phân Định Thực Tế Kiểm Thử (Evidence-Based):**
      * **[ĐÃ TEST]:** 160/160 backend tests passed trên `test_isolated_seed_db`, 107/107 Flutter tests passed, `flutter analyze` 0 issues, container backend live 200 OK.
      * **[CHƯA THỬ TRÊN ĐIỆN THOẠI THẬT]:** Chưa nạp file release APK lên thiết bị di động vật lý ngoài thực địa.

46. **[ĐÃ HOÀN TẤT - TASK: WEB-TILE-CACHE-FIX-021B] Khắc Phục Lỗi Crash Bản Đồ Khi Chạy Web (Unsupported operation: _Namespace):**
    - **1. Mục Tiêu & Nguyên Nhân Gốc (Root Cause):**
      * **Hiện tượng:** Khi chạy ứng dụng trên trình duyệt web (`flutter run -d chrome`), lớp bản đồ tại màn hình chính `MainMapView` bị crash đỏ với thông báo lỗi: `DartError: Unsupported operation: _Namespace`.
      * **Nguyên nhân gốc:** `MapTileCacheService` và `CancellableDiskCachedTileProvider` (được bổ sung từ TASK 019 để tối ưu mượt trên điện thoại) sử dụng trực tiếp các API hệ thống tệp đĩa `Directory.systemTemp`, `File`, `FileImage` thuộc thư viện `dart:io`. Trên runtime JavaScript của Flutter Web (DDC/dart2js), các lớp native này không có thực thi tương ứng và lập tức ném ngoại lệ khi truy cập `_Namespace`.
      * **Ràng buộc:** Giữ nguyên backend 100%, không đổi CSDL, không ghi dữ liệu lên `delivery_db`, giữ nguyên quy tắc không cache ảnh khách hàng, duy trì toàn vẹn bộ nhớ đệm đĩa 200MB trên Android/iOS.
    - **2. Chi Tiết Kỹ Thuật Đã Triển Khai:**
      * **A. Khởi tạo TileProvider Đa Nền Tảng ([map_tile_cache_service.dart](file:///d:/flutter create delivery_marker_app/mobile_app/lib/services/map_tile_cache_service.dart)):**
        - Xây dựng hàm factory `createPlatformTileProvider()`:
          * Khi `kIsWeb == true`: Tự động trả về [NetworkTileProvider] tích hợp sẵn của `flutter_map`, tải mảnh bản đồ thuần mạng qua cơ chế web image, tuyệt đối KHÔNG đụng chạm `dart:io`.
          * Khi `kIsWeb == false` (Android, iOS, Desktop): Sử dụng [CancellableDiskCachedTileProvider] hỗ trợ disk cache tối đa 200MB, giới hạn 10 HTTP requests đồng thời và hủy yêu cầu trôi khỏi khung nhìn.
      * **B. Phòng Vệ Đa Tầng (Defensive Layering):**
        - Trong `CancellableDiskCachedTileProvider.getImage()`: Bổ sung guard `if (kIsWeb) return NetworkImage(url, headers: headers);` phòng ngừa việc vô tình khởi tạo trực tiếp lớp này trên Web.
        - Trong `MapTileCacheService`: Các phương thức `cacheDirectory`, `getCachedTileFile`, `cacheTileBytes`, `getCacheSizeBytes`, `_checkAndPruneCache`, `clearCache` đều được bọc bảo vệ `if (kIsWeb) return ...;` ngăn ngừa hoàn toàn việc gọi native file system trên Web.
        - Bảo toàn 100% quy tắc lọc URL: `isMapTileUrl` và `containsCustomerPhoto` chặn tuyệt đối việc lưu trữ ảnh hiện trường, avatar hay ảnh khách hàng.
      * **C. Áp Dụng Đồng Bộ Trên Cả 3 Màn Hình Bản Đồ:**
        - [main_map_view.dart](file:///d:/flutter create delivery_marker_app/mobile_app/lib/views/main_map_view.dart): Sử dụng `final TileProvider _tileProvider = createPlatformTileProvider();`.
        - [shift_map_view.dart](file:///d:/flutter create delivery_marker_app/mobile_app/lib/views/shift_map_view.dart): Sử dụng `final TileProvider _tileProvider = createPlatformTileProvider();`.
        - [crosshair_location_picker_view.dart](file:///d:/flutter create delivery_marker_app/mobile_app/lib/views/crosshair_location_picker_view.dart): Sử dụng `final TileProvider _tileProvider = createPlatformTileProvider();`.
      * **D. Rà Soát Toàn Diện Các Vị Trí Dùng `dart:io` Khác Trong Dự Án:**
        - [api_service.dart](file:///d:/flutter create delivery_marker_app/mobile_app/lib/services/api_service.dart): `Platform.isAndroid` đã được bảo vệ sẵn bằng `if (!kIsWeb && Platform.isAndroid)`.
        - [save_location_view.dart](file:///d:/flutter create delivery_marker_app/mobile_app/lib/views/save_location_view.dart): Đoạn code preview ảnh chụp hiện trường trước đây dùng `File(_capturedImage!.path)` -> Đã bọc an toàn: `kIsWeb ? Image.network(_capturedImage!.path) : Image.file(File(_capturedImage!.path))`.
        - [offline_storage_service.dart](file:///d:/flutter create delivery_marker_app/mobile_app/lib/services/offline_storage_service.dart): Hàm `migrateFromV1IfNeeded` dùng `File(v1Path)` kiểm tra file CSDL v1 -> Đã bọc `if (kIsWeb) return const MigrationResult(...)` vì Web không dùng SQLite v1 file cục bộ.
    - **3. Kết Quả Kiểm Thử Tự Động & Nghiệm Thu:**
      * **Flutter Widget & Unit Tests Mới ([web_tile_cache_fix_021b_test.dart](file:///d:/flutter create delivery_marker_app/mobile_app/test/web_tile_cache_fix_021b_test.dart)):** Đạt **6/6 tests passed (100%)**:
        - `1. createPlatformTileProvider`: Trả về đúng provider tương ứng cho từng nền tảng (`NetworkTileProvider` trên web, `CancellableDiskCachedTileProvider` trên native).
        - `2. Quy tắc lọc URL`: Giữ nguyên 100% chặn ảnh khách hàng và cho phép URL tile OSM/Google/CartoDB.
        - `3. Phòng vệ đa tầng`: `CancellableDiskCachedTileProvider.getImage()` trả về an toàn theo nền tảng.
        - `4. MainMapView`: Khởi tạo và render TileProvider an toàn.
        - `5. ShiftMapView`: Khởi tạo và hiển thị an toàn.
        - `6. CrosshairLocationPickerView`: Khởi tạo và render TileProvider an toàn.
      * **Flutter Full Test Suite:** `flutter test` đạt **17 test files passed, 113/113 tests passed (100%)**.
      * **Flutter Static Analysis:** `flutter analyze` đạt **No issues found!** (0 cảnh báo, 0 lỗi trên toàn bộ dự án).
      * **Biên Dịch Flutter Web:** Thực thi `flutter build web` hoàn thành thành công 100% (`√ Built build\web`).
      * **Xác Minh Thực Tế Trên Chrome:** Khởi chạy `flutter run -d chrome --web-port 8088`, kết nối thành công DevTools (`Starting application from main method in: org-dartlang-app:///web_entrypoint.dart`), không còn phát sinh bất kỳ lỗi `_Namespace` hay lỗi đỏ trên console.
      * **Build Release APK:** Thực thi `flutter build apk --release` MỘT LẦN duy nhất.
    - **4. Phân Định Thực Tế Kiểm Thử (Evidence-Based):**
      * **[ĐÃ TEST]:** 113/113 automated Flutter tests passed, `flutter analyze` 0 issues, `flutter build web` thành công, kiểm thử runtime thực tế trên Chrome xác nhận bản đồ tải ổn định không crash.
      * **[CHƯA THỬ TRÊN ĐIỆN THOẠI THẬT]:** Chưa nạp file release APK lên thiết bị di động vật lý ngoài thực địa.

47. **[ĐÃ HOÀN TẤT - TASK: DIRECTORY-BULK-SHIFT-NAME-BLACK-BUTTONS-022A] Danh Bạ Thêm Số Hàng Loạt, Tên Ca Nhất Quán & Nút Hành Động Xanh Đen/Đen:**
    - **1. Mục Tiêu & Nguyên Tắc Tuân Thủ:**
      * Tuân thủ [AGENTS.md](file:///d:/flutter%20create%20delivery_marker_app/AGENTS.md) và QUY TẮC CHUNG.
      * Không gửi POST/PUT/PATCH/DELETE vào API sống hay SQL ghi lên `delivery_db`. Chỉ dùng GET để kiểm tra sống (`GET http://localhost:3000/api-docs` / container health).
      * Toàn bộ kiểm thử ghi dữ liệu tích hợp backend thực hiện độc lập trên CSDL `test_isolated_seed_db` gọi controller thật.
      * Không có migration CSDL (sử dụng schema hiện có của bảng `customers`, `shifts`, `shift_delivery_points`, `audit_logs`).
    - **2. Chi Tiết Kỹ Thuật Đã Triển Khai:**
      * **A. Danh Bạ: Thêm Số Hàng Loạt ([customer_directory_view.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/views/customer_directory_view.dart)):**
        - Cạnh nút "+ Thêm số", bổ sung nút "Dán nhiều số" (vùng chạm $\ge 48$px, style [AppButtons.secondary](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/theme/app_buttons.dart)) mở lại [BulkPastePhoneSheet](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/widgets/bulk_paste_phone_sheet.dart) đã có ở chế độ "thêm vào danh bạ" (`isDirectoryMode: true`), không gắn ca.
        - Tách helper dùng chung [phone.helper.ts](file:///d:/flutter%20create%20delivery_marker_app/backend/src/utils/phone.helper.ts): `parseAndNormalizeBulkPhones` dùng chung giữa bulk ca và bulk danh bạ. Giới hạn tối đa 200 số/lần.
        - Backend: `POST /api/v1/customers/bulk` trong [customers.controller.ts](file:///d:/flutter%20create%20delivery_marker_app/backend/src/controllers/customers.controller.ts) tiếp nhận body `{ rawText | phones[], areaId? }`, thực thi trong 1 transaction duy nhất cho cả lô:
          * Tên mặc định: `"Khách [SĐT]"`, địa chỉ mặc định: `"Chưa cập nhật địa chỉ"`.
          * Kiểm tra khu vực: nếu shipper phụ trách nhiều khu vực mà không truyền `areaId` -> từ chối với `requireAreaSelection: true`.
          * Phân loại phản hồi rõ ràng 3 nhóm: `created` (mới tạo), `alreadyExists` (đã có, kèm `locationState`: `VERIFIED`, `TEMPORARY`, `NO_LOCATION`), `rejected` (bị từ chối, kèm `reason`).
          * Ghi 1 bản ghi duy nhất vào `audit_logs` cho cả lô với `action = 'CUSTOMER_BULK_CREATE'`.
        - Mobile App tích hợp kết quả:
          * Hiển thị bảng tổng kết 3 nhóm sau khi dán SĐT.
          * Tự động làm mới danh bạ (`_fetchCustomers(reset: true)`).
          * Cung cấp nút hành động "THÊM TẤT CẢ VÀO CA": tự động chọn ca khả dụng hoặc mở dialog tạo ca mới, sau đó gọi `addBulkPointsToShift`.
      * **B. Tên Ca Làm Việc Nhất Quán ([shift_model.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/models/shift_model.dart)):**
        - Tất cả màn hình ([shift_preparation_view.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/views/shift_preparation_view.dart), [shift_map_view.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/views/shift_map_view.dart), [shift_list_view.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/views/shift_list_view.dart), dialog, bottom sheet, SnackBar) chuyển sang sử dụng `displayTitle`. Mã ca `SHF-...` chỉ hiển thị chữ nhỏ màu xám bên dưới hoặc cạnh bên. Loại bỏ hoàn toàn nhãn `"Ca: SHF-..."`.
        - Ca chưa có tên: tự động suy diễn tên qua `ShiftModel.inferShiftName` dựa trên giờ Việt Nam (GMT+7) từ `createdAt` / `startedAt`:
          * Sáng (< 12h): `"Ca sáng dd/MM"`.
          * Chiều (12h - 18h): `"Ca chiều dd/MM"`.
          * Tối ($\ge$ 18h): `"Ca tối dd/MM"`.
          * Chỉ phục vụ hiển thị (display-only), tuyệt đối không mutate dữ liệu cũ trong CSDL.
        - Tạo ca mới ([create_shift_dialog.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/widgets/create_shift_dialog.dart)): tự động gợi ý & điền sẵn `"Ca sáng/chiều/tối dd/MM"`. Kiểm tra danh sách ca trong ngày của shipper, nếu trùng lặp tự động thêm đuôi `" (2)"`, `" (3)"` qua `ShiftModel.suggestShiftName`. Nếu người dùng xóa trống ô tên khi tạo, tự động lưu bằng tên gợi ý.
        - Định dạng ngày: hàm `ShiftModel.formatVnDate` trả về `dd/MM` trong năm hiện tại, và tự động thêm năm `dd/MM/yyyy` nếu khác năm hiện tại.
      * **C. Nút Hành Động Chuyển Sang Tông Xanh Đen/Đen ([app_buttons.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/theme/app_buttons.dart)):**
        - Toàn bộ nút hành động chính (Primary) và phụ (Secondary) chuyển về tông xanh đen/đen:
          * Primary: Nền `#0F172A`, chữ trắng.
          * Secondary: Nền trắng, viền `#0F172A`, chữ `#0F172A`.
        - Tập trung tại lớp [app_buttons.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/theme/app_buttons.dart): `AppButtons.primary`, `AppButtons.primaryLarge`, `AppButtons.secondary`, `AppButtons.secondaryLarge`.
        - Áp dụng trên toàn bộ app: Tạo ca, Mở bản đồ, Dán SĐT, GỌI, CHỈ ĐƯỜNG, GHIM LẠI, LƯU, THÊM, XÁC NHẬN, nút nổi trên bản đồ chính, nút ghim crosshair...
        - Kích thước vùng chạm chuẩn: tối thiểu $\ge 48$px, các thao tác chính tại bottom sheet đạt $\ge 56$px.
        - Giữ nguyên: Chấm/marker trạng thái (xanh lá/cam/xám), chip trạng thái ca, nút Xóa màu đỏ trong dialog xác nhận. GỌI, CHỈ ĐƯỜNG, GHIM LẠI phân biệt rõ bằng icon và text.
    - **3. Kết Quả Kiểm Thử Tự Động & Nghiệm Thu:**
      * **Backend Integration Tests ([customers-bulk-022a.integration.spec.ts](file:///d:/flutter%20create%20delivery_marker_app/backend/test/customers-bulk-022a.integration.spec.ts)):** Đạt **4/4 tests passed (100%)** trên CSDL `test_isolated_seed_db` gọi controller thật:
        - Tạo mới hàng loạt khách hàng với định dạng hỗn hợp, chuẩn hóa và kiểm tra 1 dòng audit log duy nhất.
        - Xử lý khách hàng đã tồn tại (phân loại đúng vào nhóm `alreadyExists` kèm `locationState`).
        - Từ chối yêu cầu khi shipper có nhiều khu vực mà không truyền `areaId` (`requireAreaSelection: true`).
        - Phân loại số sai định dạng vào nhóm `rejected` kèm lý do.
      * **Backend Full Test Suite:** `npm test` đạt **14 test suites passed, 164/164 tests passed (100%)**. TypeScript `npm run build` biên dịch 0 lỗi.
      * **Flutter Widget & Unit Tests Mới ([directory_bulk_shift_name_black_buttons_022a_test.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/test/directory_bulk_shift_name_black_buttons_022a_test.dart)):** Đạt **8/8 tests passed (100%)**:
        - `B1`: Format ngày `dd/MM` và `dd/MM/yyyy`.
        - `B2`: Suy diễn tên ca sáng/chiều/tối theo GMT+7.
        - `B3`: Gợi ý tên ca và chống trùng lặp đuôi `(2)`, `(3)`.
        - `B4`: `displayTitle` ưu tiên tên thật, rỗng thì suy diễn theo giờ tạo.
        - `C1`: `AppButtons` chuẩn `#0F172A`, vùng chạm $\ge 48$px và $\ge 56$px.
        - `C2`: 3 nút GỌI, CHỈ ĐƯỜNG, GHIM LẠI trong `PointDetailBottomSheet` chuẩn `#0F172A`, icon/text rõ ràng, chiều cao $\ge 56$px.
        - `A1`: `BulkPastePhoneSheet` chế độ danh bạ có tiêu đề, nút hành động $\ge 56$px màu `#0F172A`.
        - `A2`: `CustomerDirectoryView` có nút "Dán nhiều số" ($\ge 48$px) cạnh nút "Thêm số" ($\ge 48$px).
      * **Flutter Full Test Suite:** `flutter test` đạt **18 test files passed, 121/121 tests passed (100%)**.
      * **Flutter Static Analysis:** `flutter analyze` đạt **No issues found!** (0 cảnh báo, 0 lỗi trên toàn bộ dự án).
      * **Dựng Lại Container Backend:** `docker compose up -d --build backend` hoàn thành MỘT LẦN duy nhất (`delivery_backend_api` Recreated & Started, `delivery_postgis_db` Healthy giữ nguyên không đụng chạm).
      * **Kiểm Tra API Sống:** `GET http://localhost:3000/api-docs` phản hồi **200 OK**. Tuyệt đối không gửi request ghi nào lên API sống hay `delivery_db`.
      * **Build Release APK:** Thực thi lệnh `flutter build apk --release` MỘT LẦN duy nhất.
    - **4. Phân Định Thực Tế Kiểm Thử (Evidence-Based):**
      * **[ĐÃ TEST]:** 164/164 backend tests passed trên `test_isolated_seed_db`, 121/121 Flutter tests passed, `flutter analyze` 0 issues, container backend live 200 OK, release APK build thành công.
      * **[CHƯA THỬ TRÊN ĐIỆN THOẠI THẬT]:** Chưa nạp file release APK lên thiết bị di động vật lý ngoài thực địa.

---

### 48. TASK: ACCOUNT-PROFILE-AND-LOGIN-REDESIGN-022B - Hồ Sơ Tài Khoản Cá Nhân, Thống Kê Riêng, Đổi Mật Khẩu An Toàn & Thiết Kế Lại Màn Hình Đăng Nhập
- **Mã Task:** `ACCOUNT-PROFILE-AND-LOGIN-REDESIGN-022B`
- **Mục Tiêu Nghiệp Vụ:**
  * Bổ sung Tab thứ 4 "Tài khoản" trên thanh điều hướng dưới với đầy đủ thông tin cá nhân của shipper/quản trị viên, khu vực phụ trách, thống kê riêng (vị trí đã lưu, ca đã tạo, ảnh đã tải), màn hình đổi mật khẩu riêng với cơ chế kiểm soát rate limiting và audit log bảo mật.
  * Thiết kế lại toàn diện màn hình Đăng nhập theo phong cách hiện đại, thanh thoát, nút hành động đen rộng $\ge 56$px đồng bộ với 022A, hiển thị lỗi tiếng Việt trực quan kèm nút "Thử lại", ghi nhớ số điện thoại phiên trước và cung cấp lối tắt cấu hình máy chủ ở chân trang.
  * Tuyệt đối không hardcode mật khẩu, bí mật, API key; loại bỏ hoàn toàn các chip demo account hay tài khoản điền sẵn trên giao diện đăng nhập.
- **Chi Tiết Kỹ Thuật Đã Triển Khai:**
  * **A. Tab "Tài Khoản" ([account_profile_view.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/views/account_profile_view.dart), [home_shell_view.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/views/home_shell_view.dart)):**
    - Mở rộng thanh `NavigationBar` tại [home_shell_view.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/views/home_shell_view.dart) từ 3 tab lên 4 tab: Tab 0: Bản đồ, Tab 1: Danh bạ, Tab 2: Ca làm việc, Tab 3: Tài khoản (icon `Icons.person_outline_rounded`, active `Icons.person_rounded`).
    - **Đầu trang (Header):** Circle avatar chữ cái viết tắt họ tên (ví dụ: "TG" cho "Trần Văn Giao"), hiển thị họ tên đầy đủ, SĐT định dạng chuẩn `09xx xxx xxx`, badge vai trò tiếng Việt (`"Nhân viên giao hàng"` cho `SHIPPER`, `"Quản trị viên"` cho `ADMIN`).
    - **Khu vực phụ trách:** Tích hợp API `GET /api/v1/areas/my-areas`, render dạng tag/chip xanh dương trực quan.
    - **Thống kê của tôi:** Tích hợp API mới `GET /api/v1/auth/me/stats` tại [auth.controller.ts](file:///d:/flutter%20create%20delivery_marker_app/backend/src/controllers/auth.controller.ts), đếm chính xác dữ liệu của chính người dùng đăng nhập:
      * Vị trí đã lưu (`saved_locations` do user tạo hoặc cập nhật).
      * Ca đã tạo (`shifts` do user phụ trách).
      * Ảnh đã tải (`customer_photos` do user đăng tải).
    - **Bảo mật & Đổi mật khẩu ([change_password_view.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/views/change_password_view.dart)):** Màn hình riêng biệt với 3 trường nhập: Mật khẩu hiện tại, Mật khẩu mới ($\ge 8$ ký tự), Xác nhận mật khẩu mới; đều có nút ẩn/hiện mật khẩu.
      * Backend `POST /api/v1/auth/change-password` xác thực mật khẩu hiện tại bằng `bcrypt.compare`, yêu cầu mật khẩu mới $\ge 8$ ký tự và khác mật khẩu cũ, băm bằng `bcrypt.hash(..., 10)`.
      * Cơ chế Rate Limiting: giới hạn tối đa 5 lần thử sai trong vòng 15 phút (trả về HTTP 429 Too Many Requests kèm thông báo tiếng Việt).
      * Ghi nhận kiểm toán: Ghi `audit_logs` với `action = 'PASSWORD_CHANGE'`, TUYỆT ĐỐI không ghi mật khẩu gốc hoặc chuỗi hash.
    - **Cài đặt & Thông tin hệ thống:** Hiển thị địa chỉ API máy chủ hiện hành (mở dialog cho phép shipper hiệu chỉnh `custom_api_base_url` hoặc khôi phục mặc định qua `ApiService.resetCustomBaseUrl`), hiển thị phiên bản app `v1.0.0 (Build 1)`.
    - **Nút Đăng xuất:** Nút viền đỏ vùng chạm $\ge 48$px, mở hộp thoại xác nhận trước khi đăng xuất (`"Xác nhận đăng xuất"`). Khi xác nhận, xóa token và phiên làm việc, chuyển hướng về `LoginView`.
  * **B. Thiết Kế Lại Màn Hình Đăng Nhập ([login_view.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/views/login_view.dart)):**
    - Thiết kế hiện đại, thanh lịch: biểu tượng xe giao hàng navy trên nền bo tròn, tiêu đề `"Định Vị Giao Hàng"`, phụ đề mô tả hệ thống.
    - Nền `#F8FAFC`, thẻ đăng nhập màu trắng bo góc 16px, viền mảnh `#E2E8F0`, loại bỏ hoàn toàn đổ bóng nặng.
    - Ô SĐT: bàn phím số `TextInputType.phone`, tự động chuẩn hóa loại bỏ khoảng trắng dư thừa, prefill số điện thoại từ phiên trước (`saved_login_phone`), TUYỆT ĐỐI không lưu hay điền sẵn mật khẩu.
    - Ô Mật khẩu: biểu tượng khóa, nút ẩn/hiện mật khẩu (toggle visibility), hỗ trợ phím Enter để thực hiện đăng nhập ngay.
    - Nút `ĐĂNG NHẬP`: Nền đen/navy `#0F172A` chuẩn 022A, chiều cao $\ge 56$px ([AppButtons.primaryLarge](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/theme/app_buttons.dart)), hiển thị vòng xoay `CircularProgressIndicator` và khóa vô hiệu hóa các ô nhập khi đang gửi request.
    - Trạng thái lỗi: Hộp thông báo màu đỏ nhạt `#FEF2F2` xuất hiện ngay dưới form với thông điệp tiếng Việt thân thiện (sai thông tin, mất kết nối, quá thời gian) kèm nút hành động `"Thử lại"`.
    - Lối tắt chân trang: Link `"Cấu hình máy chủ"` cho phép shipper đổi địa chỉ IP/máy chủ backend trực tiếp ngay tại màn đăng nhập khi gặp sự cố mạng.
    - Khắc phục giao diện màn hình nhỏ: Bọc toàn bộ trong `SingleChildScrollView` tránh lỗi tràn viền bàn phím (`RenderFlex overflowed`).
- **Kết Quả Kiểm Thử Tự Động & Nghiệm Thu:**
  * **Backend Integration Tests ([auth-profile-022b.integration.spec.ts](file:///d:/flutter%20create%20delivery_marker_app/backend/test/auth-profile-022b.integration.spec.ts)):** Đạt **9/9 tests passed (100%)** trên CSDL `test_isolated_seed_db`:
    - `1.1`: `GET /api/v1/auth/me/stats` chỉ đếm chính xác số lượng vị trí, ca và ảnh của shipper yêu cầu.
    - `1.2`: Từ chối 401 khi không có JWT token.
    - `2.1`: Từ chối 400 khi thiếu thông tin mật khẩu.
    - `2.2`: Từ chối 400 khi mật khẩu mới dưới 8 ký tự.
    - `2.3`: Từ chối 400 khi xác nhận mật khẩu không khớp.
    - `2.4`: Từ chối 400 khi nhập sai mật khẩu cũ và đếm lùi số lần thử.
    - `2.5`: Kích hoạt HTTP 429 Rate Limiting sau 5 lần nhập sai trong 15 phút.
    - `2.6`: Từ chối 400 khi mật khẩu mới trùng với mật khẩu cũ.
    - `2.7`: Đổi mật khẩu thành công: bcrypt hash cập nhật trong DB, đăng nhập được bằng mật khẩu mới, từ chối mật khẩu cũ, và xác minh `audit_logs` hoàn toàn không lộ mật khẩu.
  * **Backend Full Test Suite:** `npm test` đạt **15/15 test suites passed, 173/173 tests passed (100%)**. TypeScript `npm run build` biên dịch 0 lỗi.
  * **Flutter Widget Tests Mới ([account_profile_and_login_022b_test.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/test/account_profile_and_login_022b_test.dart)):** Đạt **11/11 tests passed (100%)**:
    - `A1`: `AccountProfileView` hiển thị avatar initials, họ tên, SĐT, vai trò tiếng Việt.
    - `A2`: Hiển thị đầy đủ các khối khu vực, thống kê, đổi mật khẩu, cài đặt máy chủ.
    - `A3`: Hộp thoại đăng xuất có xác nhận hủy/đồng ý trước khi xóa token.
    - `A4`: `HomeShellView` chứa tab thứ 4 "Tài khoản" với icon người.
    - `B1`: `ChangePasswordView` kiểm tra validate mật khẩu trống, ngắn < 8 ký tự, trùng mật khẩu cũ.
    - `B2`: Nút ẩn/hiện mật khẩu hoạt động chuẩn xác trên cả 3 trường.
    - `C1`: `LoginView` hiện đại, nút `ĐĂNG NHẬP` rộng đầy chiều ngang có chiều cao $\ge 56$px.
    - `C2`: Tự động nhớ SĐT lần trước nhưng KHÔNG nhớ mật khẩu.
    - `C3`: Nút ẩn/hiện mật khẩu trên màn đăng nhập hoạt động chuẩn xác.
    - `C4`: Hộp lỗi tiếng Việt trực quan dưới ô nhập kèm nút "Thử lại".
    - `C5`: Link "Cấu hình máy chủ" mở dialog cấu hình base URL.
  * **Flutter Full Test Suite:** `flutter test` đạt **19/19 test files passed, 132/132 tests passed (100%)**.
  * **Flutter Static Analysis:** `flutter analyze` đạt **No issues found!** (0 cảnh báo, 0 lỗi).
  * **Dựng Lại Container Backend:** `docker compose up -d --build backend` hoàn thành MỘT LẦN duy nhất (`delivery_backend_api` Recreated & Started, `delivery_postgis_db` Healthy). Kiểm tra API sống `curl.exe http://localhost:3000/api/docs/` trả về **200 OK**.
  * **Build Release APK:** Thực thi `flutter build apk --release` MỘT LẦN duy nhất thành công: `build\app\outputs\flutter-apk\app-release.apk` (53.0MB, 55,608,756 bytes).
- **Phân Định Thực Tế Kiểm Thử (Evidence-Based):**
  * **[ĐÃ TEST]:** 173/173 backend tests passed trên `test_isolated_seed_db`, 132/132 Flutter widget/unit tests passed, `flutter analyze` 0 issues, container backend live 200 OK, release APK build thành công.
  * **[CHƯA THỬ TRÊN ĐIỆN THOẠI THẬT]:** Chưa nạp file release APK lên thiết bị di động vật lý ngoài thực địa.

---

## 49. Chia Sẻ Dữ Liệu Vị Trí Giữa Các Shipper (TASK: DATA-SHARING-BETWEEN-SHIPPERS-023)

- **Mục Tiêu:**
  - Cho phép các shipper chia sẻ an toàn dữ liệu vị trí khách hàng ngang hàng (peer-to-peer) mà không cần can thiệp của Quản trị viên (Admin).
  - Hỗ trợ 2 phạm vi: Toàn bộ điểm đã lưu (`ALL_POINTS`) hoặc Theo một ca làm việc cụ thể (`SHIFT`).
  - Tùy chọn cho phép hoặc không cho phép xem ảnh định vị nhà (`include_photos`).
  - Kiểm soát khu vực nghiêm ngặt: Người nhận chỉ xem và nhập được các điểm nằm trong khu vực được phân công của mình (`assignedAreaIds`). Các điểm ngoài khu vực tự động bị lọc và đếm số lượng bỏ qua.
  - Bảo vệ dữ liệu gốc tuyệt đối: Người nhận không thể chỉnh sửa, xóa hay ghi đè lên dữ liệu vị trí gốc của người chia sẻ. Khi nhập điểm (`import`), hệ thống ghi nhận vào `saved_locations` của người nhận và lưu vết lịch sử qua trigger `trg_saved_locations_history`.
- **Thiết Kế Cơ Sở Dữ Liệu & Di Trú Idempotent:**
  * **Tệp di trú [init-db/08-create-data-shares.sql](file:///d:/flutter%20create%20delivery_marker_app/init-db/08-create-data-shares.sql):**
    - Bảng `data_shares`: `id UUID PK`, `owner_id UUID FK`, `recipient_id UUID FK`, `scope VARCHAR(20)`, `shift_id UUID FK NULL`, `include_photos BOOLEAN`, `status VARCHAR(20)`, `created_at`, `accepted_at`, `revoked_at`, `expires_at`.
    - Ràng buộc toàn vẹn:
      + `chk_data_shares_owner_recipient`: Cấm tự chia sẻ cho chính mình (`owner_id <> recipient_id`).
      + `chk_data_shares_scope_shift`: Bắt buộc `shift_id` có giá trị khi `scope = 'SHIFT'` và phải là `NULL` khi `scope = 'ALL_POINTS'`.
    - Chỉ mục Partial Unique Index:
      + `uq_active_pending_data_share` trên `(owner_id, recipient_id, scope, COALESCE(shift_id, ...))` với điều kiện `WHERE status IN ('PENDING', 'ACTIVE')` đảm bảo không thể tạo trùng lặp 2 lời mời đang chờ hoặc đang hiệu lực giữa cùng 2 người.
    - 4 chỉ mục hiệu năng: `idx_data_shares_owner`, `idx_data_shares_recipient`, `idx_data_shares_shift`, `idx_data_shares_expires_at`.
    - Cập nhật kịch bản nạp kiểm thử cách ly [backend/scripts/setup-test-db.ts](file:///d:/flutter%20create%20delivery_marker_app/backend/scripts/setup-test-db.ts) nạp tệp `08-create-data-shares.sql`.
    - **Trạng thái áp dụng lên CSDL môi trường chính (`delivery_db`): CHƯA ÁP DỤNG.**
- **Backend API & Phân Quyền ([shares.controller.ts](file:///d:/flutter%20create%20delivery_marker_app/backend/src/controllers/shares.controller.ts)):**
  * `POST /api/v1/shares`: Tạo lời mời chia sẻ.
    - Validate SĐT người nhận: Nếu SĐT không tồn tại, trả về thông báo lỗi chung `"Không gửi được lời mời, kiểm tra số điện thoại"` để tránh rò rỉ thông tin người dùng (User Enumeration).
    - Ngăn chặn chia sẻ cho chính mình (`HTTP 400`).
    - Giới hạn tần suất (Rate Limiting): Sliding window tối đa 10 lời mời / giờ / shipper (`HTTP 429`).
    - Ghi nhận `audit_logs` với `action = 'SHARE_CREATED'`.
  * `GET /api/v1/shares/outgoing`: Danh sách lời mời do tôi gửi đi (kèm trạng thái, số điểm, phạm vi, thời hạn).
  * `GET /api/v1/shares/incoming`: Danh sách lời mời gửi tới tôi.
  * `POST /api/v1/shares/:id/accept`: Người nhận chấp nhận lời mời (`status = 'ACTIVE'`, cập nhật `accepted_at`). Ghi `audit_logs` `SHARE_ACCEPTED`.
  * `POST /api/v1/shares/:id/decline`: Người nhận từ chối lời mời (`status = 'DECLINED'`). Ghi `audit_logs` `SHARE_DECLINED`.
  * `POST /api/v1/shares/:id/revoke`: Người gửi dừng chia sẻ (`status = 'REVOKED'`, cập nhật `revoked_at`). Không bao giờ xóa cứng dòng trong DB. Ghi `audit_logs` `SHARE_REVOKED`.
  * `GET /api/v1/shares/shared-locations`: Lấy tất cả các điểm được chia sẻ còn hiệu lực (`ACTIVE`, chưa hết hạn).
    - Tự động lọc chỉ trả về các điểm nằm trong khu vực được phân công của người nhận (`assignedAreaIds`).
    - Trả về `skippedOutOfAreaCount` thông báo số điểm bị bỏ qua do ngoài khu vực.
    - Dữ liệu hoàn toàn read-only, không đưa vào danh sách vị trí đã lưu của người nhận.
  * `POST /api/v1/shares/:id/import`: Nhập các điểm được chia sẻ vào danh bạ `saved_locations` của người nhận.
    - Hỗ trợ nhập tất cả hoặc chọn theo danh sách `customerIds`.
    - Mặc định bỏ qua khách hàng đã có vị trí trong danh bạ trừ khi chọn `replaceExisting = true`.
    - Không copy ảnh nếu chia sẻ có `includePhotos = false`.
    - Không bao giờ thay đổi dữ liệu của người chia sẻ gốc. Ghi nhận `audit_logs` `SHARE_IMPORT` với số lượng import/skip.
  * **Cập nhật phục vụ ảnh ([locations.controller.ts](file:///d:/flutter%20create%20delivery_marker_app/backend/src/controllers/locations.controller.ts)):**
    - Phương thức `servePhoto` kiểm tra quyền sở hữu ảnh gốc thông qua `customer_photos.created_by`, `shift_delivery_points`, hoặc `saved_locations.created_by`.
    - Nếu shipper yêu cầu không phải chủ sở hữu ảnh, hệ thống bắt buộc phải tìm thấy một chia sẻ `ACTIVE` còn hạn có `include_photos = true` và khách hàng nằm trong khu vực phụ trách của shipper đó. Nếu không thỏa mãn, trả về `HTTP 403 Forbidden` (hoặc `404`).
- **Giao Diện Ứng Dụng Di Động (Flutter Mobile App):**
  * **Mô Hình Dữ Liệu & Dịch Vụ API:**
    - [data_share_model.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/models/data_share_model.dart): `DataShareModel`, `SharedLocationPointModel` với JSON parsing đầy đủ.
    - [api_service.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/services/api_service.dart): 8 phương thức tích hợp API chia sẻ dữ liệu.
  * **Màn Hình Quản Lý Chia Sẻ Dữ Liệu ([data_sharing_view.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/views/data_sharing_view.dart)):**
    - Đặt trong tab Tài khoản (`AccountProfileView` -> mục "Chia sẻ dữ liệu").
    - Giao diện 2 tab: `"Tôi chia sẻ"` (danh sách chia sẻ đi kèm nút Dừng chia sẻ có xác nhận) và `"Chia sẻ cho tôi"` (danh sách nhận kèm nút Chấp nhận, Từ chối, Nhập vào danh bạ).
    - BottomSheet `"Tạo lời mời chia sẻ dữ liệu"`: Nhập SĐT người nhận, chọn phạm vi (`Tất cả điểm đã lưu` / `Một ca làm việc`), công tắc kèm ảnh nhà, lựa chọn thời hạn (7 ngày, 30 ngày, Không thời hạn). Nút bấm màu Navy `#0F172A` chuẩn 022A, chiều cao $\ge 48$px.
    - Hộp thoại nhập dữ liệu (`Import Dialog`): Có công tắc `Ghi đè nếu khách hàng đã có vị trí`.
  * **Bản Đồ Chính ([main_map_view.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/views/main_map_view.dart)):**
    - Nút bật/tắt `"Điểm được chia sẻ"` (`Key('toggle_shared_locations')`) trên thanh điều hướng trên cùng, mặc định **TẮT**.
    - Khi BẬT: Hiển thị các marker màu tím `#7C3AED` có icon chia sẻ (hoặc cụm marker màu tím nếu gom cụm).
    - Gom cụm tính riêng biệt: Cụm điểm của tôi (màu xanh lá `#10B981`) và cụm điểm được chia sẻ (màu tím `#7C3AED`) độc lập, không trộn lẫn.
    - Legend phân biệt màu sắc: Viên thuốc nổi gọn gàng hiển thị `Xanh: Của tôi`, `Tím: Được chia sẻ`.
    - Banner cảnh báo ngoài khu vực (`Key('banner_out_of_area_warning')`): Hiển thị khi `skippedOutOfAreaCount > 0` (`"X điểm không hiển thị vì ngoài khu vực của bạn"`) kèm nút đóng banner.
    - Bottom sheet chi tiết điểm chia sẻ:
      + Header: Badge tím `"Chia sẻ từ [tên shipper]"`.
      + Thông tin: Tên khách, SĐT, Địa chỉ, Ghi chú định danh.
      + Dải ảnh: Hiển thị ảnh nếu có quyền xem (`CustomerPhotosStripWidget` ở chế độ read-only).
      + Các nút hành động: `"GỌI"` (`btn_call_shared_point`), `"CHỈ ĐƯỜNG"` (`btn_directions_shared_point`), `"NHẬP VÀO CỦA TÔI"` (`btn_import_shared_point_to_mine`).
      + **TUYỆT ĐỐI KHÔNG có nút "Ghim lại" và KHÔNG có nút "Xóa".**
      + Ẩn các nút nổi FAB khi bottom sheet đang mở.
- **Kết Quả Kiểm Thử Tự Động & Nghiệm Thu:**
  * **Backend Integration Tests ([data-sharing-023.integration.spec.ts](file:///d:/flutter%20create%20delivery_marker_app/backend/test/data-sharing-023.integration.spec.ts)):** Đạt **23/23 tests passed (100%)** trên CSDL cách ly `test_isolated_seed_db`:
    - `1.1`: Bắt buộc đăng nhập (`401`).
    - `1.2`: Chỉ chấp nhận vai trò SHIPPER hoặc ADMIN.
    - `1.3`: Từ chối khi SĐT người nhận không tồn tại (thông báo lỗi chung bảo vệ quyền riêng tư).
    - `1.4`: Từ chối khi tự chia sẻ cho chính mình (`400`).
    - `1.5`: Từ chối khi scope=SHIFT nhưng thiếu shiftId (`400`).
    - `1.6`: Giới hạn tần suất (Rate Limiting) tối đa 10 lời mời / giờ (`429`).
    - `1.7`: Tạo thành công lời mời scope=ALL_POINTS.
    - `1.8`: Tạo thành công lời mời scope=SHIFT.
    - `1.9`: Chống trùng lặp lời mời ACTIVE/PENDING bằng partial unique index.
    - `2.1`: `GET /outgoing` trả về danh sách kèm điểm đếm chính xác.
    - `2.2`: `GET /incoming` trả về danh sách lời mời gửi tới.
    - `3.1`: `POST /:id/accept` kích hoạt trạng thái `ACTIVE` và cập nhật `accepted_at`.
    - `4.1`: `POST /:id/decline` chuyển trạng thái sang `DECLINED`.
    - `5.1`: `POST /:id/revoke` dừng chia sẻ `REVOKED`, không xóa bản ghi trong DB.
    - `6.1`: `GET /shared-locations` chỉ trả về các điểm còn hiệu lực.
    - `6.2`: Tự động lọc điểm ngoài khu vực của người nhận và đếm `skippedOutOfAreaCount`.
    - `6.3`: Điểm chia sẻ không xuất hiện trong `my-saved-locations`.
    - `7.1`: Cho phép xem ảnh khi includePhotos=true và chia sẻ còn ACTIVE.
    - `7.2`: Từ chối 403 khi lời mời đã bị REVOKED.
    - `7.3`: Từ chối 403 khi includePhotos=false.
    - `8.1`: `POST /:id/import` nhập thành công điểm chia sẻ vào danh bạ người nhận.
    - `8.2`: Bỏ qua điểm đã tồn tại khi `replaceExisting=false`.
    - `8.3`: Ghi đè và bảo toàn lịch sử thay đổi qua trigger `trg_saved_locations_history` khi `replaceExisting=true`.
    - `8.4`: Xác minh không làm thay đổi hay đột biến điểm gốc của người chia sẻ.
    - `9.1`: Xác minh nhật ký kiểm toán `audit_logs` đầy đủ 5 hành động không chứa PII.
  * **Backend Full Test Suite:** `npm test` đạt **16/16 test suites passed, 196/196 tests passed (100%)**. TypeScript `npm run build` biên dịch 0 lỗi.
  * **Flutter Widget Tests Mới ([data_sharing_023_test.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/test/data_sharing_023_test.dart)):** Đạt **11/11 tests passed (100%)**:
    - `1.1`: `DataSharingView` hiển thị 2 tab "Tôi chia sẻ" và "Chia sẻ cho tôi" cùng nút tạo lời mời.
    - `1.2`: Mở BottomSheet tạo lời mời với đầy đủ các trường (SĐT, scope chips, expiration chips, include photos switch, submit button).
    - `1.3`: Validation bắt buộc SĐT người nhận.
    - `2.1`: `AccountProfileView` có mục "Chia sẻ dữ liệu" và mở `DataSharingView`.
    - `3.1`: `MainMapView` có nút bật/tắt "Điểm được chia sẻ", mặc định tắt.
    - `3.2`: Bật nút chia sẻ hiển thị Legend màu sắc (Xanh: Của tôi, Tím: Được chia sẻ).
    - `3.3`: Banner cảnh báo ngoài khu vực hiển thị khi có điểm bị lọc và đóng được.
    - `3.4`: Bottom sheet chi tiết điểm chia sẻ hiển thị badge tím, thông tin, các nút và KHÔNG có Ghim lại/Xóa.
    - `3.5`: Bấm "NHẬP VÀO CỦA TÔI" mở hộp thoại xác nhận kèm công tắc ghi đè.
    - `4.1`: `DataShareModel` JSON parsing và helper getters.
    - `4.2`: `SharedLocationPointModel` JSON parsing đầy đủ thông tin.
  * **Flutter Full Test Suite:** `flutter test` đạt **20/20 test files passed, 143/143 tests passed (100%)**.
  * **Flutter Static Analysis:** `flutter analyze` đạt **No issues found!** (0 cảnh báo, 0 lỗi).
- **Phân Định Thực Tế Kiểm Thử (Evidence-Based):**
  * **[ĐÃ TEST]:** 196/196 backend unit & integration tests passed trên `test_isolated_seed_db`, 143/143 Flutter tests passed, `flutter analyze` 0 issues.
  * **[CHƯA THỬ TRÊN ĐIỆN THOẠI THẬT]:** Chưa nạp file APK lên thiết bị di động vật lý ngoài thực địa.
  * **[ĐÃ ÁP DỤNG LÊN DB THẬT CHƯA]: ĐÃ ÁP DỤNG** (Xem chi tiết Mục 50).

---

## 50. Thực Thi Di Trú Lên Cơ Sở Dữ Liệu Thực Tế (TASK: LIVE-DB-MIGRATE-08-023C)

- **Mục Tiêu & Quyền Hạn:**
  - Thực thi ngoại lệ duy nhất được cấp phép: Chạy migration `08-create-data-shares.sql` lên CSDL thực tế `delivery_db`.
  - Nghiêm ngặt tuân thủ: Chỉ thêm bảng/chỉ mục mới, không xóa hay sửa dữ liệu cũ. Tuyệt đối không gửi `POST`/`PUT`/`PATCH`/`DELETE` vào API đang chạy.
- **Bước 1: Sao Lưu CSDL Trước Khi Chạy:**
  - Tệp sao lưu `pg_dump`: `D:\db_backups\delivery_db_backup_20261026_125921.sql`.
  - Dung lượng: **115,867 bytes (~115.8 KB)**.
  - Vị trí: Đặt NGOÀI thư mục git (`D:\db_backups\`).
  - Tệp `.gitignore` gốc đã bổ sung và chặn toàn diện: `*.sql` (ngoại trừ `!init-db/*.sql`), `*.dump`, `*.zip`, `backup_*`, `backups/`.
- **Bước 2: Khảo Sát Hiện Trạng Bằng SELECT Trước Di Trú:**
  - `01-init-db.sql`: ĐÃ CÓ (`roles`, `users`, `areas`, `user_areas`, `customers`, `orders`, `saved_locations`, `location_history`, `audit_logs`).
  - `02-add-photo-and-fix-history.sql`: ĐÃ CÓ (cột `saved_locations.image_url`).
  - `03-seed-demo-data.sql`: ĐÃ CÓ (dữ liệu mẫu Tạp hóa Hai Thu).
  - `04-create-shifts-and-delivery-points.sql`: ĐÃ CÓ (`shifts`, `shift_delivery_points`).
  - `05-add-customers-updated-at.sql`: ĐÃ CÓ (cột `customers.updated_at`).
  - `06-create-customer-photos.sql`: ĐÃ CÓ (`customer_photos` áp dụng 25/10/2026).
  - `07-add-shift-name.sql`: ĐÃ CÓ (cột `shifts.shift_name` áp dụng 25/10/2026).
  - `08-create-data-shares.sql`: **CHƯA CÓ** (Bảng `data_shares` chưa tồn tại trong `delivery_db`).
- **Bước 3: Thực Thi Di Trú Trong Transaction & Chứng Minh Idempotent:**
  - **Lần 1 (Thực thi tạo mới):**
    ```bash
    docker exec delivery_postgis_db psql -U postgres -d delivery_db -v ON_ERROR_STOP=1 --single-transaction -f /docker-entrypoint-initdb.d/08-create-data-shares.sql
    ```
    - Kết quả: `CREATE TABLE`, `CREATE INDEX` (x4), exit code `0`.
  - **Lần 2 (Chứng minh tính idempotent):**
    ```bash
    docker exec delivery_postgis_db psql -U postgres -d delivery_db -v ON_ERROR_STOP=1 --single-transaction -f /docker-entrypoint-initdb.d/08-create-data-shares.sql
    ```
    - Kết quả: `NOTICE: relation "data_shares" already exists, skipping`, `NOTICE: relation "uq_active_pending_data_share" already exists, skipping`, exit code `0` (không gây lỗi, không làm trùng lặp).
- **Bước 4: Đối Soát Toàn Vẹn Dữ Liệu Bằng SELECT Sau Di Trú:**
  - **Cấu trúc bảng `data_shares`:** Đầy đủ 11 cột, khóa chính UUID, các ràng buộc `chk_data_shares_owner_recipient`, `chk_data_shares_scope_shift`.
  - **Chỉ mục:** 5 chỉ mục gồm `data_shares_pkey`, Partial Unique Index `uq_active_pending_data_share`, `idx_data_shares_owner`, `idx_data_shares_recipient`, `idx_data_shares_expires_at`.
  - **So sánh số dòng dữ liệu (Trước vs Sau di trú):**
    * `customers`: **32** $\rightarrow$ **32** (Không đổi).
    * `saved_locations`: **10** $\rightarrow$ **10** (Không đổi).
    * `location_history`: **31** $\rightarrow$ **31** (Không mất dòng nào).
    * `audit_logs`: **229** $\rightarrow$ **229** (Không mất dòng nào).
    * `customer_photos`: **9** $\rightarrow$ **9** (Không đổi).
    * `shifts`: **3** $\rightarrow$ **3** (Không đổi).
    * `shift_delivery_points`: **0** $\rightarrow$ **0** (Không đổi).
    * `data_shares`: **0** (Bảng mới tạo sẵn sàng).
  - **Dữ liệu khách hàng Anh Hoàng (`c0000000-0000-0000-0000-000000000001`):**
    * Tọa độ `10.8422150, 106.8181230`, `gps_accuracy = 4.5`.
    * Ghi chú: `"Đi vào hẻm 124 khoảng 50m, nhà cạnh tiệm tạp hóa Hai Thu, cổng màu xanh da trời, có cây mai trước sân."`.
    * Ảnh: `"/api/v1/photos/6ffc3833-1f78-48c8-8624-3041f25449f9.jpg"`.
    * Toàn bộ trường dữ liệu của Anh Hoàng được giữ nguyên tuyệt đối 100%.
- **Bước 5: Đồng Bộ Trạng Thái Tài Liệu:**
  - Cập nhật [docs/DATABASE.md](file:///d:/flutter%20create%20delivery_marker_app/docs/DATABASE.md): Đổi trạng thái của `08-create-data-shares.sql` thành **ĐÃ ÁP DỤNG** vào lúc **26/10/2026 13:00:16**.

---

## 14. TASK: UI-OVERFLOW-FIX-024 - Khắc Phục Lỗi Tràn Giao Diện & Co Đè Ô Nhập SĐT Khi Mở Bàn Phím

> **Thời điểm cập nhật:** 26/10/2026 16:22  
> **Phạm vi tác động:** Chỉ sửa giao diện Flutter (`mobile_app`), tuyệt đối không sửa backend, không ghi dữ liệu lên API sống hay `delivery_db`.

### 14.1. Khảo Sát & Báo Cáo Hiện Trạng Trước Khi Sửa Đổi (Read-Before-Write)

- **Lỗi 1 (Tràn ngang thẻ TỌA ĐỘ & GHI CHÚ VỊ TRÍ):**
  - File: [customer_directory_view.dart:L1150-L1190](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/views/customer_directory_view.dart#L1150-L1190).
  - Nguyên nhân: Tiêu đề `"TỌA ĐỘ & GHI CHÚ VỊ TRÍ"` và hai nút `"Xóa vị trí"`, `"Chọn trên bản đồ"` cùng nằm trong một `Row` cố định không có khả năng co giãn hay xuống dòng, dẫn đến tràn phải 109px khi hiển thị trên các màn hình có chiều rộng tiêu chuẩn hoặc chữ lớn.
  - Ngoài ra, các thẻ trong hồ sơ và danh sách ảnh (`customer_photos_strip_widget.dart`), sheet tạo khách hàng (`quick_add_customer_sheet.dart`) và thẻ chia sẻ (`data_sharing_view.dart`) có các `Row` chứa Text không được bọc `Expanded`/`Flexible`, có nguy cơ tràn cao ở cỡ chữ lớn hoặc màn hình 320dp.
- **Lỗi 2 (Ô nhập SĐT bị co/đè khi bàn phím mở):**
  - File: [bulk_paste_phone_sheet.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/widgets/bulk_paste_phone_sheet.dart).
  - Nguyên nhân: Khung nhập liệu TextField được bọc trong `Container(height: 180)` cố định, không nằm trong bộ cuộn; khi bàn phím mềm mở lên chiếm 300dp, chiều cao viewport bị thu hẹp đột ngột khiến TextField bị bóp méo, chữ tràn viền và con trỏ đè sát vào nút `"DÁN TỪ BỘ NHỚ TẠM"`.
  - Sheet tạo ca [create_shift_dialog.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/widgets/create_shift_dialog.dart) cũng dùng chiều cao cố định tương tự cần được bổ sung cuộn an toàn.

### 14.2. Các Giải Pháp Kỹ Thuật Đã Triển Khai

1. **Khắc phục Lỗi 1 (Thẻ tọa độ & hồ sơ khách hàng):**
   - **Tách hàng tiêu đề & nút bấm:** Tiêu đề `"TỌA ĐỘ & GHI CHÚ VỊ TRÍ"` được tách riêng một dòng độc lập.
   - **Bọc nút trong `Wrap`:** Nút `"Xóa vị trí"` và `"Chọn trên bản đồ"` được đặt trong `Wrap(spacing: 8, runSpacing: 8)` để tự động xuống hàng khi màn hình hẹp mà không bao giờ bị cắt chữ hay gây lỗi RenderFlex overflow.
   - **Kích thước vùng chạm & bảng màu 022A:** Cả 2 nút đều đạt vùng chạm `>= 48px` (`minHeight: 48`). Nút `"Xóa vị trí"` dùng kiểu viền đen trung tính `AppButtons.secondary(color: #0F172A)`, màu đỏ cảnh báo chỉ xuất hiện trong hộp thoại `AlertDialog` khi shipper thực sự xác nhận xóa.
   - **Bảo toàn hiển thị 320dp + textScale 1.5:** Thêm `Flexible`/`Expanded` cho nhãn `"Tối đa 10 ảnh"`, `"Tọa độ: ..."` trong [customer_directory_view.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/views/customer_directory_view.dart).
   - **Rà soát các màn hình liên quan:**
     * [customer_photos_strip_widget.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/widgets/customer_photos_strip_widget.dart): Bọc `Flexible` với `TextOverflow.ellipsis` cho text trong ô trống và nút `"+ THÊM ẢNH"`.
     * [quick_add_customer_sheet.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/widgets/quick_add_customer_sheet.dart): Bọc `Expanded` cho tiêu đề `"Thêm nhanh khách hàng"` và nút mở rộng thông tin địa chỉ/ghi chú.
     * [data_sharing_view.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/views/data_sharing_view.dart): Bọc `Expanded` cho thông tin ca và phạm vi chia sẻ trên các thẻ đi và thẻ đến.

2. **Khắc phục Lỗi 2 (Ô nhập SĐT khi bàn phím mở):**
   - **Bỏ chiều cao cố định cho TextField:** Chuyển sang dùng `minLines: 4, maxLines: 8`, tự động co giãn theo số lượng dòng và nội dung.
   - **Cấu hình BottomSheet chống đè bàn phím:** 
     * `isScrollControlled: true` và bọc trong `ConstrainedBox(constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85))`.
     * Padding dưới theo `MediaQuery.of(context).viewInsets.bottom`.
     * Phần thân được bọc trong `Flexible(child: SingleChildScrollView(physics: BouncingScrollPhysics(), ...))`, đảm bảo bàn phím mở vẫn cuộn mượt mà.
   - **Bố cục & Khoảng cách an toàn:** `contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14)` (dọc >= 12px), khoảng cách giữa TextField và nút dán là 12px.
   - **Nút hành động chính ghim chắc chắn:** Nút `"THÊM VÀO CA LÀM VIỆC"` (cao 56px) luôn ghim vững ở đáy sheet phía trên bàn phím, không bao giờ bị che khuất.
   - **Giữ nguyên chức năng & auto-focus:** `autofocus: true`, hỗ trợ tự động đếm số SĐT hợp lệ (`Regex r'0\d{9}'`).
   - **Đồng bộ hóa sang các dialog/sheet khác:** Bọc cuộn và giới hạn chiều cao tối đa cho [create_shift_dialog.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/widgets/create_shift_dialog.dart).

### 14.3. Kết Quả Kiểm Thử Thực Tế (Evidence-Based Testing)

- **Widget Tests Tự Động ([ui_overflow_fix_024_test.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/test/ui_overflow_fix_024_test.dart)):**
  * `1.1 CustomerDetailEditView (320dp, textScale 1.5, có vị trí)`: **ĐÃ TEST** $\rightarrow$ `tester.takeException() == null`, không còn sọc vàng đen hay RenderFlex overflow.
  * `1.2 CustomerDetailEditView (320dp, textScale 1.5, chưa có vị trí)`: **ĐÃ TEST** $\rightarrow$ `tester.takeException() == null`.
  * `2.1 BulkPastePhoneSheet (viewInsets.bottom = 300, mở bàn phím)`: **ĐÃ TEST** $\rightarrow$ Không overflow, chiều cao ô nhập 112px `>= 100px`, không đè nút `"DÁN TỪ BỘ NHỚ TẠM"`, nút chính hiển thị đầy đủ.
  * `2.2 QuickAddCustomerSheet (viewInsets.bottom = 300)`: **ĐÃ TEST** $\rightarrow$ Không overflow, cuộn mượt mà.
  * `2.3 CreateShiftBottomSheet (viewInsets.bottom = 300)`: **ĐÃ TEST** $\rightarrow$ Không overflow, các trường nhập liệu nguyên vẹn.
- **Phân Tích Cú Pháp & Quy Chuẩn (Lint / Typecheck):**
  * `flutter analyze`: **0 issues found** (hoàn toàn sạch lỗi).
- **Hệ Thống Test Toàn Dự Án:**
  * `flutter test`: **148/148 tests passed** (100% đạt).
- **Trạng Thái Kiểm Thử Thiết Bị Thực Tế:**
  * **ĐÃ TEST trên widget test tự động / CHƯA thử trên điện thoại thật.**

---

