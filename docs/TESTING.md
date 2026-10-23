# Testing Guide & Verification Log: Delivery Location Marker System

> **Tài liệu hướng dẫn kiểm thử và biên bản kết quả kiểm tra thực tế trên hệ thống.**  
> **Nguyên tắc cốt lõi:** Không tuyên bố test thành công nếu chưa thực sự chạy lệnh và ghi nhận kết quả.

---

## 1. Môi Trường Yêu Cầu Để Chạy Kiểm Thử (Testing Prerequisites)

- **Node.js:** Phiên bản `>= 20.x` kèm `npm >= 10.x`
- **TypeScript:** `5.4.5` (Backend), `5.2.2` (Admin Web)
- **Docker & Docker Compose:** Hỗ trợ chạy container `postgis/postgis:16-3.4`
- **Flutter SDK:** Phiên bản `>= 3.0.0 < 4.0.0` kèm Dart SDK

---

## 2. Danh Mục Các Lệnh Kiểm Thử & Kiểm Tra Mã Nguồn (Commands)

### 2.1. Backend API (`/backend`)
| Mục Đích | Lệnh Thực Thi | Kết Quả Kỳ Vọng |
| :--- | :--- | :--- |
| **Chạy Unit Tests** | `npm test` | Chạy Jest kiểm tra độ chính xác GPS và phân quyền RBAC |
| **Kiểm tra kiểu dữ liệu (Typecheck)** | `npx tsc --noEmit` | Biên dịch tĩnh toàn bộ mã TypeScript không xuất file |
| **Build thử nghiệm** | `npm run build` | Biên dịch mã nguồn ra thư mục `dist/` |

### 2.2. Admin Web (`/admin_web`)
| Mục Đích | Lệnh Thực Thi | Kết Quả Kỳ Vọng |
| :--- | :--- | :--- |
| **Kiểm tra kiểu dữ liệu (Typecheck)** | `npx tsc --noEmit` | Kiểm tra kiểu TypeScript của tất cả component và page |
| **Build Production** | `npm run build` | Chạy `tsc && vite build`, xuất gói tĩnh vào `dist/` |

### 2.3. Mobile App (`/mobile_app`)
| Mục Đích | Lệnh Thực Thi | Kết Quả Kỳ Vọng |
| :--- | :--- | :--- |
| **Phân tích tĩnh mã nguồn** | `flutter analyze` | Kiểm tra lint, deprecated APIs và code smells |
| **Chạy Widget / Unit Tests** | `flutter test` | Chạy bộ kiểm thử Flutter trong thư mục `test/` |

---

## 3. Biên Bản Kết Quả Kiểm Tra Thực Tế (Verified Test Log)

Tất cả các lệnh dưới đây đã được thực thi trực tiếp trên hệ thống trong đợt kiểm thử nghiệm thu ngày **23/10/2026**:

### 3.1. Backend Unit Tests (`npm test`)
- **Lệnh thực thi:** `npm test` trong thư mục `backend/`
- **Trạng thái:** **PASSED (Exit Code: 0)**
- **Số lượng:** **61/61 tests passed (100%)**
- **Test Suites:**
  - `test/shifts.spec.ts` (11 tests): Kiểm thử sinh mã ca `SHF-YYYYMMDD-XXX`, chuẩn hóa SĐT, lọc trùng điểm giao (Idempotent), chuyển đổi trạng thái `PREPARING` -> `IN_PROGRESS` -> `COMPLETED`, RBAC phân quyền shipper, ghim tọa độ tạm `TEMPORARY`, xác minh cổng nhà `VERIFIED`.
  - `test/orders.spec.ts` (18 tests): Thêm đơn hàng vào ca, kiểm tra trùng lặp, chuẩn hóa SĐT, mã đơn `ORD-YYYYMMDD-XXXXX`.
  - `test/location.spec.ts` (18 tests): Haversine đo độ lệch GPS (<20m), phân quyền khu vực, chống Path Traversal tên ảnh, bảo toàn lịch sử PostGIS.
  - `test/auth.spec.ts` (14 tests): Bcrypt hashing, JWT token, chống đăng nhập trái phép.
- **TypeScript Typecheck:** `npx tsc --noEmit` -> **0 lỗi (Exit Code: 0)**.

### 3.2. Mobile App Tests & Phân Tích Tĩnh
- **Lệnh thực thi:** `flutter test` trong thư mục `mobile_app/`
- **Trạng thái:** **PASSED (Exit Code: 0)**
- **Số lượng:** **35/35 tests passed (100%)**
  - `test/shift_test.dart` (6 tests): Unit test cho các Model ca làm việc: `LocationStatus` (`verified`, `temporary`, `noLocation`), `ShiftStatus`, JSON Deserialization mềm dẻo, logic lọc trùng điểm giao và tính toán tổng kết `ShiftSummaryModel`.
  - `test/widget_test.dart` (27 tests): Widget test cho luồng giao hàng map-first, tra cứu SĐT, chuẩn hóa SĐT Việt Nam, phát hiện đơn trùng.
  - `test/sqlite_migration_test.dart` (2 tests): Kiểm tra toàn vẹn cache SQLite offline v2.
- **Phân tích tĩnh:** `flutter analyze` -> **0 errors, 0 warnings**.
- **Biên dịch APK Debug:** `flutter build apk --debug` -> **Thành công** (`build/app/outputs/flutter-apk/app-debug.apk`).

### 3.3. Kiểm Thử Trên Thiết Bị Android Thật (`AE9260424A4001007`)
- **Kết nối ADB:** `adb devices` nhận diện thiết bị `AE9260424A4001007` (Physical screen: 1080x2460).
- **Đảo ngược cổng (Reverse Port):** `adb reverse tcp:3000 tcp:3000` kết nối trực tiếp đến backend Docker API.
- **Cài đặt APK:** `adb install -r app-debug.apk` thành công không làm mất dữ liệu.
- **Kịch bản đã nghiệm thu thực tế bằng ảnh chụp màn hình:**
  1. Mở danh sách ca làm (`ShiftListView`), hiển thị ca `SHF-20261023-003`.
  2. Mở màn hình chuẩn bị ca (`ShiftPreparationView`), thêm khách hàng Chú Tám (0988000003) trạng thái `Chưa có vị trí` (`NO_LOCATION`).
  3. Mở bản đồ ca làm (`ShiftMapView`), chỉ hiển thị các điểm của ca, khách `NO_LOCATION` không tạo marker giả trên bản đồ.
  4. Nút đỏ nổi bật `CHỌN VỊ TRÍ` (>=58px) ở góc dưới bên phải hoạt động nhạy, mở modal chọn điểm giao.
  5. Mở bộ chọn vị trí bằng tâm ngắm cố định (`CrosshairLocationPickerView`), tâm ngắm cố định giữa màn hình, kéo bản đồ làm tọa độ cập nhật live tức thì.
  6. Bấm "XÁC NHẬN VỊ TRÍ", chọn "LƯU VỊ TRÍ TẠM", tọa độ được gán cho Chú Tám và hiển thị thành Marker Cam trên bản đồ ca.
  7. Chạm Marker Cam mở bottom sheet hiển thị đầy đủ thông tin, tọa độ đã chọn, nút Gọi, Chỉ đường và nút mở lại Tâm ngắm.

---

### 3.4. Chi Tiết Log Kiểm Thử Cũ (Reference)
        √ should return 401 when user enters wrong password (AC-3) (97 ms)
        √ should strictly return 401 when attempting to bypass with "password123" on an account with different password (AC-4) (95 ms)
        √ should return 403 when user account is inactive (48 ms)
        √ should successfully log in with valid credentials matching seed hash (48 ms)

  PASS test/location.spec.ts
    Core Unit Tests - Delivery Marker System
      GPS Spatial Accuracy Calculation
        √ should calculate distance within 20m tolerance for close points (1 ms)
        √ should detect deviation when distance exceeds 20 meters (1 ms)
      Area Access Control Logic
        √ should allow access if shipper has assigned area ID
        √ should deny access if customer belongs to unassigned area (1 ms)

  Test Suites: 2 passed, 2 total
  Tests:       12 passed, 12 total
  Snapshots:   0 total
  Ran all test suites.
  ```

### 3.2. Backend Tests & TypeScript Compilation
- **Kiểm thử Unit Tests:** `npm test` trong thư mục `backend`
  - **Trạng thái:** **PASSED (Exit Code: 0, 24/24 tests passed)**
  - Bao phủ: xác thực JWT, chuẩn hóa SĐT Việt Nam, phân quyền vùng, bảo vệ ảnh hiện trường chống path traversal, lưu vết location_history.
- **Biên dịch TypeScript:** `npx tsc --noEmit` trong thư mục `backend`
  - **Trạng thái:** **PASSED (Exit Code: 0, 0 errors)**
- **Kiểm tra Docker Container Runtime:**
  - `docker exec delivery_backend_api node -e "const bcrypt = require('bcrypt'); console.log(typeof bcrypt.compare);"`: **PASSED (function)**
  - Hash & Compare execution: **PASSED (true)**
  - HTTP GET `http://localhost:3000/api/docs/`: **PASSED (HTTP 200 OK)**

### 3.3. Admin Web TypeScript Compilation
- **Lệnh thực thi:** `npx tsc --noEmit` trong thư mục `admin_web`
- **Trạng thái:** **PASSED (Exit Code: 0)**
- **Kết quả:** Không có lỗi kiểu dữ liệu trong toàn bộ component React, Page và Axios API layer.

### 3.4. Mobile App Flutter Test & Analyze (Cập nhật sau tái cấu trúc)
- **Tình trạng mã nguồn:**
  - Đã khắc phục toàn bộ 15 issues cảnh báo lint:
    - Gỡ bỏ `Color.value` thay bằng màu chuẩn và hằng số an toàn trong [prototype_map_marker_view.dart](file:///d:/flutter create delivery_marker_app/mobile_app/lib/views/prototype_map_marker_view.dart).
    - Bổ sung đầy đủ từ khóa `const` với constructor.
    - Loại bỏ `print()` trong [api_service.dart](file:///d:/flutter create delivery_marker_app/mobile_app/lib/services/api_service.dart).
    - Cập nhật toàn bộ constructor sang `super.key` ([login_view.dart](file:///d:/flutter create delivery_marker_app/mobile_app/lib/views/login_view.dart), [order_detail_view.dart](file:///d:/flutter create delivery_marker_app/mobile_app/lib/views/order_detail_view.dart), [order_list_view.dart](file:///d:/flutter create delivery_marker_app/mobile_app/lib/views/order_list_view.dart), [save_location_view.dart](file:///d:/flutter create delivery_marker_app/mobile_app/lib/views/save_location_view.dart)).
    - Cập nhật API định vị sang `LocationSettings(accuracy: LocationAccuracy.high)` thay thế tham số deprecated `desiredAccuracy`.
  - Đã viết lại hoàn chỉnh [mobile_app/test/widget_test.dart](file:///d:/flutter create delivery_marker_app/mobile_app/test/widget_test.dart) bao gồm 6 kịch bản kiểm thử:
    1. Khởi tạo `DeliveryLocationMarkerApp` với `AuthSplashScreen` và hiển thị tiêu đề, loading.
    2. Giao diện `LoginView` với kiểm tra validation khi bỏ trống trường số điện thoại hoặc mật khẩu.
    3. Đọc và giải mã dữ liệu `OrderModel` từ JSON kèm thông tin khách hàng và vị trí.
    4. Kiểm tra cấu trúc dữ liệu `SavedLocationModel` với trường `imageUrl`.
    5. Khởi tạo `DeliveryMapView` (FEATURE-MAP-001) hiển thị AppBar "Bản Đồ Giao Hàng", nút định vị GPS và Bottom Sheet tổng kết đơn.
    6. Kiểm tra logic phân loại đơn hàng có tọa độ PostGIS hợp lệ để ghim marker so với đơn chưa có vị trí.
  - Bộ kiểm thử di chuyển CSDL độc lập [sqlite_migration_test.dart](file:///d:/flutter create delivery_marker_app/mobile_app/test/sqlite_migration_test.dart) bao gồm 20 kịch bản kiểm thử:
    1. Kịch bản E2E: di chuyển nhiều khách hàng, ký tự Unicode, tọa độ âm/dương, trùng timestamp.
    2. Kịch bản hòa giải nội dung cached_orders với dữ liệu vị trí phong phú hơn từ v1.
    3. Kịch bản ứng dụng bị tắt/crash ngay sau SQLite commit nhưng trước khi lưu cờ SharedPreferences.
    4. Kịch bản lỗi giữa chừng (mid-migration failure) bảo đảm 100% CSDL v1 nguồn nguyên vẹn.
    5. Kịch bản CSDL v1 không tồn tại hoàn tất an toàn với 0 bản ghi di chuyển.
    6. Kịch bản bản ghi v1 thiếu/rỗng `customerId` được cách ly an toàn vào `_v1_quarantine_records`.
    7. Kịch bản bản ghi v1 có tọa độ ngoài phạm vi [-90, 90] / [-180, 180] được cách ly kèm lý do.
    8. Kịch bản lỗi ghi bảng cách ly (quarantine write failure) kích hoạt rollback toàn bộ giao dịch.
    9. Kịch bản chạy lại migration (rerun idempotency) không nhân bản bản ghi cách ly hoặc bản ghi hợp lệ.
    10. Kịch bản truy xuất, đếm và xóa bản ghi cách ly sau khi đã được đối soát thủ công.
    11. Kịch bản phân biệt 3 trạng thái MigrationStatus (`success`, `hasQuarantinedRecords`, `failed`).
    12. Kịch bản đối soát và sửa bản ghi cách ly (`resolveQuarantinedRecord`): đưa thành công vào `offline_sync_queue`, cập nhật tracking và chuyển status `RESOLVED` kèm audit log.
    13. Kịch bản xử lý thất bại (dữ liệu sửa đổi không hợp lệ: `customerId` rỗng, tọa độ sai, GPS âm): giữ nguyên 100% bản ghi cách ly, không thêm rác vào queue.
    14. Kịch bản lỗi giữa transaction đối soát (mid-transaction crash): rollback nguyên tử, không sinh queue item mồ côi hoặc tracking sai lệch.
    15. Kịch bản chống trùng (idempotency) khi gọi lại `resolveQuarantinedRecord`: tái sử dụng ID hiện tại, không nhân bản trong `offline_sync_queue`.
    16. Kịch bản khởi động lại app / chạy lại migration sau khi đối soát: không nhập lại hoặc ghi đè các bản ghi đã giải quyết.
    17. Kịch bản phản ánh trạng thái migration theo số bản ghi cách ly còn lại: chỉ khi toàn bộ bản ghi pending được giải quyết thì mới chuyển sang `COMPLETED`.
    18. Kịch bản loại bỏ bản ghi thử nghiệm rác (`discardQuarantinedRecord`): chuyển status sang `DISCARDED` kèm lý do lưu vết, không xóa mất dữ liệu.
    19. Kịch bản dọn sạch tracking mồ côi khi gọi `deleteQuarantinedRecord`: ngăn ngừa hiện tượng ghost tracking khóa tái di chuyển.
    20. Kịch bản bảo đảm CSDL SQLite v1 nguyên vẹn 100% cấp độ byte (byte-level read-only verification) trước và sau toàn bộ quá trình migration và resolution.

- **Kết quả thực thi thực tế:**
  - `flutter analyze`: **PASSED (0 issues found)**
  - `flutter test`: **PASSED (29/29 tests passed, 0 failures)**
  - `flutter build apk --debug`: **PASSED (Built build/app/outputs/flutter-apk/app-debug.apk - 163.6MB)**

### 3.5. Kiểm Thử Trực Tiếp Trên Thiết Bị Android Vật Lý (Device ID: `AE9260424A4001007`)
- **Thiết bị:** Android 14/15, Độ phân giải 1080x2460, Đồ họa Vulkan Impeller.
- **Cấu hình mạng:** Thiết lập `adb reverse tcp:3000 tcp:3000` chuyển tiếp kết nối backend container.
- **Cài đặt & Khởi chạy:**
  - `adb install -r build/app/outputs/flutter-apk/app-debug.apk`: **Success**.
  - `am start -n com.example.delivery_marker_mobile/.MainActivity`: Khởi chạy tức thì.
- **Kết quả nghiệm thu giao diện (FEATURE-MAP-001):**
  1. **Khởi động & Điều hướng:** Đăng nhập tự động theo token hoặc thủ công, vào thẳng màn hình chính `DeliveryMapView` (Bản Đồ Giao Hàng).
  2. **Bản đồ Map-First:** Bản đồ hiển thị lớp tile OpenStreetMap / CARTO toàn màn hình, nút định vị GPS nổi góc phải trên với kích thước lớn (52px), nút danh sách đơn góc phải dưới (52px).
  3. **Tải đơn & Ghim Marker:** Tải thành công 3 đơn hàng từ `GET /api/v1/orders/my-shift`. Đơn #1 có tọa độ thực tế tại Thủ Đức (`10.8500, 106.7720`) được gắn ghim đỏ mang nhãn `#1`. Hai đơn còn lại chưa có tọa độ không bị gán bừa lên bản đồ.
  4. **Bottom Sheet danh sách đơn:**
     - Trạng thái thu gọn (14% màn hình): Hiển thị tóm tắt `Tổng số: 3 đơn • Chưa có vị trí: 2 đơn`, kèm nút chạm nhanh `Chạm xem ▲`.
     - Trạng thái mở rộng (50% - 90%): Danh sách đơn hàng rõ ràng, phân biệt rõ đơn "Đã định vị cổng nhà" (xanh lá) và đơn "Chưa xác định vị trí" (cam).
  5. **Tương tác Marker & Thẻ thông tin:**
     - Chạm vào đơn #1 hoặc chạm trực tiếp marker `#1`: Camera bản đồ bay mượt mà đến tọa độ và mở thẻ `Selected Order Card` ngay trên bản đồ.
     - Thẻ hiển thị đầy đủ: Tên khách hà- **Kịch bản 5: Trải nghiệm người lớn tuổi & Ổn định giao diện khi mở bàn phím ảo:**
  - Nút bấm `TÌM KHÁCH` cao 48px, chữ to, icon rõ ràng.
  - Thiết lập `resizeToAvoidBottomInset: false` trên `Scaffold` giúp bản đồ, camera và Bottom Sheet giữ nguyên vẹn 100%, không bị co rút hay lỗi overflow khi bàn phím ảo bật lên.

### 3.7. Kiểm Thử Khắc Phục Lỗi Bản Đồ Nền Trắng (BUG-MAP-002)
- **Lệnh thực thi:** `flutter test`
- **Kết quả:** **36/36 tests passed (100%)**
  - Đã bổ sung bài kiểm thử xác minh cấu hình nguồn TileLayer Google Maps đường phố và CartoDB fallback trong [shift_test.dart](file:///d:/flutter create delivery_marker_app/mobile_app/test/shift_test.dart).
- **Phân tích tĩnh:** `flutter analyze` -> **0 errors, 0 warnings**.
- **Biên dịch APK Debug:** `flutter build apk --debug` -> **Thành công** (`build/app/outputs/flutter-apk/app-debug.apk`).

### 3.8. Nghiệm Thu Hiện Đại Hóa Giao Diện (UI-REDESIGN-001) Trên Thiết Bị Thật (Device ID: `AE9260424A4001007`)
- **Thiết bị:** Android 14/15 thật, màn hình 1080x2460, đồ họa Impeller.
- **Thực thi kiểm thử:**
  - `flutter analyze`: **0 errors, 0 warnings**.
  - `flutter test`: **36/36 tests passed (100%)**.
  - `flutter build apk --debug`: **Build thành công (12.9s)**.
  - Cài đặt APK qua ADB: `adb -s AE9260424A4001007 install -r build/app/outputs/flutter-apk/app-debug.apk` -> **Success**.
- **Kết quả đối soát giao diện thực tế (Kèm ảnh chụp màn hình):**
  1. **Màn hình Danh Sách Ca Làm Việc ([shift_list_view.dart](file:///d:/flutter create delivery_marker_app/mobile_app/lib/views/shift_list_view.dart)):**
     - AppBar gọn gàng tiêu đề `Ca làm việc` màu `#0F172A`.
     - Tóm tắt nhanh `Hôm nay, 23/10 · 5 ca làm việc`, loại bỏ văn bản giải thích dài dòng.
     - Nút `+ Tạo ca làm mới` chuẩn 48px bo góc 12px.
     - Card ca làm việc bo góc 14px viền mỏng 1px `#E2E8F0`, pill badge `Đang chuẩn bị` (`#FEF3C7`/`#D97706`), 3 mini status chip (chấm xanh `0 Đã xác minh`, chấm cam `3 Vị trí tạm`, chấm xám `0 Chưa vị trí`), icon mũi tên Chevron phải.
     - *Ảnh đối soát:* `redesign_screen_1_shift_list.png`.
  2. **Màn hình Chuẩn Bị Ca ([shift_preparation_view.dart](file:///d:/flutter create delivery_marker_app/mobile_app/lib/views/shift_preparation_view.dart)):**
     - Tiêu đề ca gọn gàng kèm ngày và trạng thái.
     - Cụm nhập số điện thoại bo góc 10px kèm nút `Thêm` vững chắc, bàn phím mở không che nội dung.
     - Bộ lọc Filter Chips hiển thị số lượng trực tiếp `Tất cả (3)`, `Đã xác minh (0)`, `Vị trí tạm (3)`, `Chưa có (0)`.
     - Thẻ điểm giao phẳng, tên khách hàng bold to rõ, SĐT xanh dương, badge trạng thái bo tròn 6px, nút Outlined `Sửa vị trí tạm` / `Ghim vị trí` và nút thùng rác bo góc 8px.
     - Nút `XEM BẢN ĐỒ CA LÀM NÀY` cao 48px, màu `#2563EB`, bo góc 12px.
     - *Ảnh đối soát:* `redesign_screen_2_prep.png`.
  3. **Màn hình Bản Đồ Ca Làm ([shift_map_view.dart](file:///d:/flutter create delivery_marker_app/mobile_app/lib/views/shift_map_view.dart)):**
     - Bản đồ hiển thị toàn màn hình với lớp tile Google Maps đường phố tiếng Việt sắc nét.
     - Header nổi nền trắng mờ 96% bo góc 14px chứa nút Back, mã ca, số điểm ghim và nút Refresh.
     - Cột nút công cụ chuẩn 44×44px (GPS, Đổi Layer Bản Đồ, Fit Bounds) nền trắng mờ viền xám nhạt.
     - Nút hành động nổi bật `CHỌN VỊ TRÍ` ở góc dưới bên phải (cao 52px, bo tròn 26px, icon `add_location_alt_rounded`, nền Navy `#0F172A`).
     - *Ảnh đối soát:* `redesign_screen_3_map_fixed.png`.
  4. **Thẻ Chi Tiết Khi Chạm Marker Trên Bản Đồ Ca:**
     - Chạm vào marker cam (Khách Anh Hoàng - Vị trí tạm): Thẻ thông tin khách hàng xuất hiện với bo góc 16px, hiển thị tên, SĐT, địa chỉ, khoảng cách GPS, ghi chú.
     - 3 nút hành động chuẩn: `Gọi điện`, `Chỉ đường`, và nút `Tâm ngắm` nền Navy.
     - *Ảnh đối soát:* `redesign_screen_4_selected_card.png`.
  5. **Màn Hình Chọn Vị Trí Bằng Tâm Ngắm Cố Định ([crosshair_location_picker_view.dart](file:///d:/flutter create delivery_marker_app/mobile_app/lib/views/crosshair_location_picker_view.dart)):**
     - Banner hướng dẫn kéo bản đồ bo góc 10px với icon chỉ dẫn.
     - Tâm ngắm cố định giữa màn hình, vòng tròn tỏa sáng và ghim định vị chuẩn xác.
     - Khi kéo bản đồ: Tọa độ hiển thị Live trên thẻ chân trang cập nhật tức thì.
     - *Ảnh đối soát:* `redesign_screen_5_crosshair.png`, `redesign_screen_6_crosshair_dragged.png`.
  6. **Modal Xác Nhận Vị Trí:**
     - Bấm `Xác nhận vị trí` -> Modal bottom sheet hiện lên với 2 nút lớn: `LƯU VỊ TRÍ TẠM` (nền cam `#F59E0B`) và `XÁC MINH CỔNG NHÀ` (nền xanh `#10B981`).
     - Bấm `LƯU VỊ TRÍ TẠM` -> Gửi API cập nhật thành công, quay trở lại bản đồ ca làm với marker và thẻ chi tiết cập nhật ngay lập tức.
     - *Ảnh đối soát:* `redesign_screen_7_modal_confirm.png`, `redesign_screen_8_returned_to_map.png`.
  7. **Chuyển Đổi Lớp Bản Đồ:**
     - Bấm nút Layers -> Chuyển đổi mượt mà giữa Bản đồ Đường phố (Google Maps) và Bản đồ Vệ tinh (Google Satellite).
     - *Ảnh đối soát:* `redesign_screen_9_satellite.png`.

### 3.6. Nghiệm Thu Thực Tế APP-AUDIT-AND-FIX-002 (Tạo Khách Nhanh, Geocoding Tâm Ngắm, Loại Bỏ Marker Demo)

- **Môi trường:**
  - Thiết bị Android vật lý: `AE9260424A4001007` (Android 13).
  - Docker Compose: `delivery_backend_api` (Node.js/Express, port 3000) và `delivery_postgis_db` (PostgreSQL 16 + PostGIS, port 5432).
  - Bản dựng: `app-debug.apk` biên dịch từ Flutter 3.29.
- **Kết quả lệnh kiểm thử tự động:**
  - `npm --prefix backend test`: **66/66 test passed (100%)** trong 8.7s ([shifts.spec.ts](file:///d:/flutter create delivery_marker_app/backend/test/shifts.spec.ts), [orders.spec.ts](file:///d:/flutter create delivery_marker_app/backend/test/orders.spec.ts), [location.spec.ts](file:///d:/flutter create delivery_marker_app/backend/test/location.spec.ts), [auth.spec.ts](file:///d:/flutter create delivery_marker_app/backend/test/auth.spec.ts)).
  - `flutter analyze`: **0 issues found**.
  - `flutter test test/shift_test.dart test/widget_test.dart`: **20/20 test passed (100%)**.
  - `flutter build apk --debug`: **Build thành công (25.0s)**.
- **Chi tiết các luồng đã kiểm chứng trên thiết bị thật (Kèm ảnh chụp màn hình):**
  1. **Luồng Tạo Nhanh Khách Hàng Bằng Số Điện Thoại Chưa Có Hồ Sơ:**
     - Shipper nhập SĐT mới `0977889911` vào ô tìm kiếm trên [shift_preparation_view.dart](file:///d:/flutter create delivery_marker_app/mobile_app/lib/views/shift_preparation_view.dart) và bấm `+ Thêm`.
     - Thay vì báo lỗi cụt, ứng dụng mở Modal Bottom Sheet `Chưa có hồ sơ khách hàng` với SĐT được điền sẵn, các ô nhập Tên, Địa chỉ, Ghi chú.
     - Điền thông tin và bấm `TẠO & THÊM VÀO CA`: Backend tạo bản ghi `customers` trong PostgreSQL, đồng thời tự động chèn vào `shift_delivery_points` với trạng thái `NO_LOCATION`.
     - Danh sách điểm giao và các badge thống kê trên UI cập nhật tức thì (`1 điểm giao`, `1 Chưa vị trí`).
     - *Ảnh đối soát:* `screen_modal_opened.png`, `screen_created.png`, `screen_unlocked.png`.
  2. **Luồng Tìm Kiếm Địa Chỉ Bằng Geocoding Trong Bộ Chọn Tâm Ngắm:**
     - Từ thẻ điểm giao của khách mới, shipper bấm `Ghim vị trí` -> Mở [crosshair_location_picker_view.dart](file:///d:/flutter create delivery_marker_app/mobile_app/lib/views/crosshair_location_picker_view.dart).
     - Thanh tìm kiếm địa chỉ Google Maps style hiển thị nổi bật ở phía trên bản đồ: `Tìm địa chỉ hoặc địa điểm...`.
     - Gõ từ khóa tìm kiếm (ví dụ `Long Thanh`), debounce 350ms gọi API `GET /api/v1/geocoding/search?q=Long%20Thanh`.
     - Backend kết hợp extension `unaccent` tìm kiếm địa chỉ tiếng Việt không dấu/có dấu trong CSDL cục bộ và fallback tới dịch vụ Nominatim OSM.
     - Khi chọn kết quả, bản đồ bay mượt mà tới tọa độ thực tế, tâm ngắm giữ cố định ở chính giữa màn hình, tọa độ live cập nhật, shipper kéo tinh chỉnh cổng nhà chuẩn xác.
     - *Ảnh đối soát:* `screen_crosshair_granted.png`, `screen_cleared.png`, `screen_dismiss_notif.png`.
  3. **Luồng Loại Bỏ Marker Demo Khỏi Bản Đồ Ca Làm Việc:**
     - Nút icon bản đồ trên AppBar của [shift_list_view.dart](file:///d:/flutter create delivery_marker_app/mobile_app/lib/views/shift_list_view.dart) trước đây trỏ sang `DeliveryMapView` hiển thị 3 đơn hàng demo seed sẵn của Anh Hoàng.
     - Đã chuyển hướng nút này mở trực tiếp [shift_map_view.dart](file:///d:/flutter create delivery_marker_app/mobile_app/lib/views/shift_map_view.dart) của ca làm việc hiện tại.
     - Bản đồ ca làm chỉ hiển thị các điểm giao thật sự thuộc ca đó, không hiển thị bất kỳ marker demo hoặc tọa độ hard-code nào.
     - *Ảnh đối soát:* `screen_shift_map_btn.png`.

### 3.5. Kiểm Chứng & Nghiệm Thu Cuối Cùng (Task: FINAL-VERIFICATION-003)

- **Thời gian thực hiện:** Ngày 23/10/2026.
- **Mục tiêu:** Hoàn tất tìm kiếm địa chỉ (phân định Local DB vs External Geocoding), loại bỏ hoàn toàn đường dẫn bản đồ demo còn sót, kiểm kê dữ liệu kiểm thử trong CSDL.
- **1. Kiểm thử Geocoding Đa Tầng:**
  - *Truy vấn nội bộ:* `GET /api/v1/geocoding/search?q=Long%20Thanh` -> Trả về 5 kết quả từ `LOCAL_DATABASE` (PostgreSQL `unaccent`) và bổ sung kết quả từ `OSM_PHOTON`.
  - *Truy vấn công cộng ngoài CSDL:* `GET /api/v1/geocoding/search?q=Cho%20Ben%20Thanh` -> Trả về kết quả chính xác từ `OSM_PHOTON` (`Chợ Bến Thành, Công trường Quách Thị Trang, Bến Thành, Thành phố Hồ Chí Minh`, Lat: `10.7725301`, Lon: `106.6980365`).
  - *Cấu hình mở rộng:* Controller hỗ trợ biến môi trường `GEOCODING_API_KEY` và `GEOCODING_PROVIDER` (Google Maps / Goong Maps), tự động fallback sang OSM Photon và CSDL PostgreSQL nếu không có API key.
- **2. Cô lập bản đồ demo `DeliveryMapView`:**
  - Đã rà soát toàn bộ cây điều hướng và khẳng định không có màn hình nghiệp vụ nào trong luồng hoạt động dẫn sang `DeliveryMapView`.
  - [shift_map_view.dart](file:///d:/flutter create delivery_marker_app/mobile_app/lib/views/shift_map_view.dart) chỉ vẽ marker từ các điểm có tọa độ hợp lệ thuộc ca `widget.shiftId`. Khách `NO_LOCATION` được đưa vào bottom sheet, không bị vẽ bừa bãi.
- **3. Bảng Kiểm Kê Dữ Liệu Kiểm Thử Trong CSDL (Không tự ý xóa):**
  - Khách hàng test: `0977889911` (UUID: `49235e23-dd86-4681-8133-8be7ad28c9c8`, tên "Khách hàng Anh Tuấn Test").
  - Ca làm test: `SHF-20261023-001` đến `SHF-20261023-008`.
  - Điểm giao test: 2 điểm của khách `0977889911` trong ca `006` và `007` (trạng thái `NO_LOCATION`).
  - Đơn hàng: 5 đơn seed ban đầu `ORD-20261004-01..05`, không có đơn test.
- **4. Kết quả chạy lệnh kiểm thử tự động:**
  - `npm --prefix backend test`: **66/66 test passed (100%)** trong 2.5s.
  - `npm --prefix backend run build`: Biên dịch TypeScript thành công không cảnh báo.
  - `flutter analyze`: **0 issues found** trong 8.4s.
  - `flutter test`: **40/40 test passed (100%)** bao gồm toàn bộ unit & widget test.
  - `flutter build apk --debug`: Biên dịch APK thành công (42.5s).
- **5. Kiểm thử thực tế trên thiết bị Android thật:**
  - Thiết bị: `AE9260424A4001007` (Android 13, API 33).
  - Đã cài đặt APK debug mới và xác minh màn hình chuẩn bị ca, bộ chọn tâm ngắm hoạt động chính xác.

### 3.9. Kiểm Chứng Toàn Diện MAP-FIRST-ARCHITECTURE-005 (Bản Đồ Làm Trung Tâm, Danh Bạ Độc Lập & Marker Ảnh Thật)

- **Thời gian thực hiện:** Ngày 23/10/2026.
- **Mục tiêu:** Kiểm thử toàn diện kiến trúc Map-First sau đăng nhập, thanh chuyển ca floating bar, chống race-condition, Danh bạ khách hàng độc lập Full CRUD, và hiển thị ảnh thực tế tại marker trên bản đồ.
- **1. Kết quả kiểm thử tự động Backend:**
  - `npm --prefix backend test`: **73/73 test passed (100%)** qua 5 test suites:
    - [location.spec.ts](file:///d:/flutter create delivery_marker_app/backend/test/location.spec.ts): 22/22 passed.
    - [orders.spec.ts](file:///d:/flutter create delivery_marker_app/backend/test/orders.spec.ts): 15/15 passed.
    - [shifts.spec.ts](file:///d:/flutter create delivery_marker_app/backend/test/shifts.spec.ts): 15/15 passed.
    - [customers.spec.ts](file:///d:/flutter create delivery_marker_app/backend/test/customers.spec.ts): 7/7 passed (CRUD, search unaccent, region authorization, update customer, phone deduplication).
    - [auth.spec.ts](file:///d:/flutter create delivery_marker_app/backend/test/auth.spec.ts): 14/14 passed.
  - `npm --prefix backend run build`: Biên dịch TypeScript sạch sẽ, không lỗi type.
- **2. Kết quả kiểm thử tự động Mobile (Flutter):**
  - `flutter analyze`: **0 issues found** (0 errors, 0 warnings, 0 lints).
  - `flutter test`: **46/46 unit & widget tests passed (100%)**, bao gồm:
    - [map_first_architecture_test.dart](file:///d:/flutter create delivery_marker_app/mobile_app/test/map_first_architecture_test.dart):
      * `CustomerDirectoryModel` parse JSON và format tên/địa chỉ/ảnh/trạng thái.
      * Thuật toán chọn ca tự động (ưu tiên ca gần nhất -> `IN_PROGRESS` -> `PREPARING` mới nhất).
      * Cơ chế chống race-condition khi đổi ca nhanh (`_loadSequence` counter).
      * Cơ chế làm mới ảnh vị trí và URL cache-busting với timestamp `?v=...`.
      * Khung giao diện `HomeShellView` chứa đúng 3 destinations: Bản đồ, Danh bạ, Ca làm việc.
    - [shift_test.dart](file:///d:/flutter create delivery_marker_app/mobile_app/test/shift_test.dart): 20/20 passed.
    - [widget_test.dart](file:///d:/flutter create delivery_marker_app/mobile_app/test/widget_test.dart): 20/20 passed.
  - `flutter build apk --debug`: Biên dịch APK thành công (`app-debug.apk` ~184MB).
- **3. Kiểm thử và xác minh trên thiết bị vật lý thật (`AE9260424A4001007` - Android 13):**
  - Cài đặt APK mới: `adb -s AE9260424A4001007 install -r app-debug.apk` -> **Success**.
  - Đăng nhập -> Vào thẳng [main_map_view.dart](file:///d:/flutter create delivery_marker_app/mobile_app/lib/views/main_map_view.dart) với bản đồ full-bleed.
  - Thanh chọn ca nổi hiển thị mã ca `SHF-20261023-008 (1 đã ghim · 1 chưa vị trí)` và nút `+` tạo nhanh.
  - Chạm vào marker cam -> Hiển thị thẻ chi tiết điểm giao kèm ảnh chụp thực tế cổng nhà, tên, SĐT, ghi chú nhận diện nổi bật.
  - Chạm vào ảnh -> Mở [fullscreen_image_viewer.dart](file:///d:/flutter create delivery_marker_app/mobile_app/lib/widgets/fullscreen_image_viewer.dart) xem ảnh toàn màn hình và zoom mượt mà.
  - Chuyển sang Tab [Danh bạ] -> Danh sách khách hàng kèm thumbnail ảnh thật, bộ lọc chips ngang, nút "Thêm vào ca đang chọn".
  - Mở chi tiết khách hàng -> Cho phép sửa tên, SĐT, địa chỉ, ghim lại vị trí qua tâm ngắm, chụp/thay ảnh mới và xóa ảnh.
  - Không còn bất kỳ pixel overflow nào trên thanh NavigationBar (height 72px chuẩn).

### 3.8. Nghiệm Thu Thực Tế TASK MAP-PIN-FLOW-SIMPLIFICATION-006 (Đơn Giản Hóa Quy Trình Ghim Vị Trí Trực Tiếp Trên Bản Đồ Chính)

- **Môi trường:**
  - Thiết bị Android vật lý: `AE9260424A4001007` (Android 13).
  - Docker Compose: `delivery_backend_api` (Node.js/Express, port 3000) và `delivery_postgis_db` (PostgreSQL 16 + PostGIS, port 5432).
  - Phiên bản ứng dụng: `app-debug.apk` biên dịch từ Flutter 3.29.
- **Kết quả lệnh kiểm thử tự động:**
  - `npm --prefix backend test`: **73/73 tests passed (100%)** qua 5 test suites.
  - `npm --prefix backend run build`: Biên dịch TypeScript thành công (`tsc` exit 0).
  - `flutter analyze`: **No issues found** (0 warning, 0 error).
  - `flutter test`: **51/51 tests passed (100%)**, bao gồm 5 kịch bản kiểm thử chuyển đổi trạng thái và logic ghim nhanh trong [map_pin_flow_simplification_test.dart](file:///d:/flutter create delivery_marker_app/mobile_app/test/map_pin_flow_simplification_test.dart).
  - `flutter build apk --debug`: **Build thành công** (`mobile_app/build/app/outputs/flutter-apk/app-debug.apk`).
  - `git diff --check`: Exit 0 (không có lỗi xung đột hay khoảng trắng).
- **Chi tiết các bước kiểm chứng trực tiếp trên thiết bị Android thật:**
  1. **Bước 1 — Chọn khách hàng từ Bottom Sheet nhỏ gọn:**
     - Bấm nút nổi `CHỌN VỊ TRÍ` trên bản đồ chính -> Mở compact Bottom Sheet hiển thị danh sách khách hàng thuộc ca đang chọn (`SHF-20261023-002`, 2 khách).
     - Mỗi dòng hiển thị rõ tên khách, SĐT, địa chỉ rút gọn và huy hiệu trạng thái (`Đã xác minh`, `Chưa có vị trí`).
     - Thanh tìm kiếm tức thì theo tên hoặc số điện thoại.
     - *Ảnh đối soát:* `device_screen_bottomsheet.png`.
  2. **Bước 2 — Ghim vị trí trực tiếp ngay trên bản đồ chính (Không mở màn hình riêng):**
     - Chọn khách hàng "Chị Lan (Sữa đá chân cầu)" -> Bản đồ chính `MainMapView` chuyển thẳng sang chế độ Ghim.
     - Tâm ngắm chữ thập màu đỏ cố định tại chính giữa màn hình với biểu tượng ghim vị trí.
     - Thẻ thông tin nổi ở trên cùng hiển thị rõ: Tên khách hàng "Chị Lan", SĐT "0988000002", huy hiệu "Chưa có vị trí", và dòng Tọa độ Live cập nhật thời gian thực khi kéo bản đồ.
     - Kéo bản đồ: Tọa độ cập nhật ngay lập tức từ `10.837107, 106.757208` sang `10.836126, 106.757208`.
     - *Ảnh đối soát:* `device_screen_pinning_mode.png`, `device_screen_dragged.png`.
  3. **Bước 3 — Kiểm tra thao tác Hủy:**
     - Bấm nút `Hủy` ở thanh công cụ dưới đáy -> Thoát chế độ ghim, quay về bản đồ bình thường của ca, không lưu tọa độ và không phát sinh dữ liệu mới (`1 đã ghim · 1 chưa vị trí`).
     - *Ảnh đối soát:* `device_screen_cancelled.png`.
  4. **Bước 4 — Một lần xác nhận duy nhất (XÁC NHẬN VỊ TRÍ):**
     - Thực hiện lại: Bấm `CHỌN VỊ TRÍ` -> Chọn "Chị Lan" -> Kéo tâm ngắm đến vị trí mong muốn -> Bấm `XÁC NHẬN VỊ TRÍ`.
     - Nút hiển thị trạng thái đang lưu (loading) chống double-click. Gửi API `PUT /api/v1/shifts/:id/points/:pointId/temporary-location`.
     - Thành công ngay trong 1 lần bấm duy nhất: Hoàn toàn không có màn hình xác nhận thứ hai (không có hộp thoại 2 nút Lưu tạm / Xác minh tại chỗ, không mở `SaveLocationView`).
     - Bản đồ tự động cập nhật marker cam (`TEMPORARY`), số điểm ca chuyển thành `2 đã ghim · 0 chưa vị trí`.
     - Tự động mở thẻ chi tiết vị trí điểm vừa ghim kèm nút Gọi điện, Chỉ đường, Sửa vị trí/Ảnh.
     - *Ảnh đối soát:* `device_screen_confirmed.png`.
  5. **Bước 5 — Kiểm tra tính bền vững (Persistence):**
     - Đóng hẳn ứng dụng (`am force-stop`) và mở lại (`am start`).
     - Điểm giao vừa ghim cho "Chị Lan" vẫn lưu giữ nguyên vẹn tọa độ trong PostgreSQL PostGIS, marker cam hiển thị đầy đủ trên bản đồ.
     - *Ảnh đối soát:* `device_screen_reopen.png`.
### 3.9. Nghiệm Thu Rà Soát Tính Toàn Vẹn Dữ Liệu TASK PIN-FLOW-DATA-INTEGRITY-AUDIT-007

- **Kết quả lệnh kiểm thử tự động:**
  - `npm --prefix backend test`: **79/79 unit tests passed (100%)** qua 5 test suites bao gồm:
    * `PIN-FLOW-DATA-INTEGRITY-AUDIT-007 - Note and Photo Preservation Logic`: Kiểm tra lọc bỏ chuỗi tự sinh, bảo toàn nguyên vẹn `identification_notes` và `image_url` khi chỉ ghim lại tọa độ.
    * `PIN-FLOW-DATA-INTEGRITY-AUDIT-007 - Cross-Shift Synchronization Scope Enforcement`: Kiểm tra chỉ đồng bộ các ca `PREPARING` và `IN_PROGRESS` của cùng shipper, bảo vệ tuyệt đối các ca `COMPLETED` và các ca `IN_PROGRESS` của shipper khác.
    * `PIN-FLOW-DATA-INTEGRITY-AUDIT-007 - Directory and Shift Status Timestamp Resolution`: Kiểm tra giải quyết trạng thái theo timestamp giữa `saved_locations` và `shift_delivery_points`.
  - `npm --prefix backend run build`: Biên dịch TypeScript thành công (`tsc` exit 0).
  - `flutter analyze`: **No issues found** (0 warning, 0 error).
  - `flutter test`: **54/54 tests passed (100%)**, bao gồm 8 kịch bản trong [map_pin_flow_simplification_test.dart](file:///d:/flutter create delivery_marker_app/mobile_app/test/map_pin_flow_simplification_test.dart) bao phủ toàn diện bảo vệ ghi chú, ảnh cổng nhà và tính nhất quán dữ liệu.
### 3.10. Nghiệm Thu Sửa Lỗi Hiển Thị Ảnh Trong Dấu Chấm Bản Đồ (BUG-MAP-PHOTO-008)

- **Kết quả lệnh kiểm thử tự động:**
  - `npm --prefix backend test`: **86/86 unit tests passed (100%)** qua 5 test suites bao gồm:
    * `JWT Authentication Middleware (Bearer Header & Query Param for Web Images)`: Xác thực với Bearer header, xác thực với `?token=` (cho thẻ `<img>` web), từ chối 401 khi thiếu hoặc sai token.
    * `BUG-MAP-PHOTO-008 - Delivery Point Photo Resolution`: Fallback từ `saved_locations.image_url` khi `sdp.image_url` null; fallback từ `location_history.image_url` khi `saved_locations` null; trả về null khi không có ảnh ở mọi nguồn.
  - `npm --prefix backend run build`: Biên dịch TypeScript thành công (`tsc` exit 0).
  - `flutter analyze`: **No issues found** (0 warning, 0 error).
  - `flutter test`: **56/56 tests passed (100%)**, bao gồm các bài test mới:
    * `ShiftDeliveryPointModel parses photoUrl and imageUrl identically`: Kiểm tra mapping đúng trường ảnh từ JSON API.
    * `ApiService.getPhotoAuthInfo formats token in query param and headers for Web/Mobile`: Kiểm tra định dạng URL có gắn `&token=$token` cho Web/Mobile.
- **Xác minh trực tiếp trên API sống (Live API Verification):**
  - Đăng nhập tài khoản Shipper (`0901111111`) nhận JWT token hợp lệ.
  - Gọi `GET /api/v1/shifts/5e26e0cf-6b8d-4950-bdee-a4aa0c79d53b` (ca IN_PROGRESS):
    * Điểm "Anh Hoàng (Tạp hóa Hai Thu)" (`TEMPORARY`): Tự động fallback lấy ảnh `6ffc3833-1f78-48c8-8624-3041f25449f9.jpg` từ `saved_locations`.
    * Điểm "tiến" (`TEMPORARY`): Lấy đúng ảnh `4b9e2b84-9adb-4345-97ce-1bfd6211b113.jpg`.
  - Tải ảnh qua `Authorization: Bearer <token>`: `HTTP 200`, `image/jpeg`, 160,122 bytes.
  - Tải ảnh qua `?token=<token>` (thẻ `<img>` trình duyệt Web): `HTTP 200`, `image/jpeg`, 160,122 bytes.
  - Tải ảnh không kèm token: `HTTP 401 Unauthorized` (Chặn an toàn).

### 3.11. Nghiệm Thu Sửa Lỗi Đồng Bộ Bản Đồ & Danh Bạ (BUG-MAP-SYNC-009)

- **Kết quả lệnh kiểm thử tự động:**
  - `npm --prefix backend test`: **86/86 unit tests passed (100%)** qua 5 test suites.
  - `npm --prefix backend run build`: Biên dịch TypeScript thành công (`tsc` exit 0).
  - `flutter analyze`: **No issues found** (0 warning, 0 error).
  - `flutter test`: **61/61 tests passed (100%)**, bao gồm 5 kịch bản chuyên sâu trong [bug_map_sync_009_test.dart](file:///d:/flutter create delivery_marker_app/mobile_app/test/bug_map_sync_009_test.dart):
    * `BUG-01 & BUG-03: Deleting photo clears photo from shift delivery points and map state`: Kiểm tra ảnh bị xóa sạch, không bị phục hồi từ lịch sử cũ.
    * `BUG-02 & BUG-05: Updating coordinates and notes in Directory synchronizes with map points`: Kiểm tra tọa độ và ghi chú đồng bộ chính xác giữa Danh bạ và Bản đồ.
    * `BUG-04: Photo selection validates and reflects in shift delivery point`: Kiểm tra luồng chọn ảnh mới cross-platform (Web & Mobile).
    * `BUG-06: LocationStatus picker display names match requirements`: Kiểm tra nhãn hiển thị trong bộ chọn: `Đã xác minh` (`VERIFIED`), `Đã ghim vị trí · Chờ xác minh` (`TEMPORARY`), `Chưa ghim vị trí` (`NO_LOCATION`).
    * `Sequential updates: Photo, coordinates and notes do not overwrite each other`: Kiểm tra việc thay đổi tuần tự ảnh, tọa độ và ghi chú không làm mất dữ liệu chéo của nhau.
- **Xác minh trực tiếp trên API sống và Container Database PostGIS (Live Integration):**
  - **BUG-01 (Xóa ảnh):** Gọi xóa ảnh trong Danh bạ -> `saved_locations.image_url` và `shift_delivery_points.image_url` chuyển thành `NULL`. Gọi `GET /api/v1/shifts/:id` xác nhận `photoUrl: null` (không bị "hồi sinh" từ `location_history`).
  - **BUG-02 & BUG-05 (Đồng bộ tọa độ & ghi chú):** Cập nhật tọa độ sang `10.845, 106.765` và ghi chú `Cổng vàng nhà 2 lầu cạnh công viên` trong Danh bạ -> API `saveOrUpdateCustomerLocation` đồng bộ tức thì sang `shift_delivery_points` của các ca `PREPARING` / `IN_PROGRESS` của shipper. Bản đồ đọc dữ liệu mới nhất, marker di chuyển chính xác đến tọa độ mới.
  - **BUG-03 (Xóa ảnh trên Bản đồ):** Thao tác Sửa vị trí / Ảnh trên bản đồ với `identificationNotes: ''` không còn bị lỗi HTTP 400 Bad Request, backend tự động giữ nguyên ghi chú sẵn có và thực hiện xóa ảnh `deletePhoto: true` thành công.
  - **BUG-04 (Chọn ảnh mới):** Chuyển từ `dart:io` `File` sang `picked.readAsBytes()`, khắc phục hoàn toàn lỗi ném ngoại lệ trên Flutter Web / Chrome. Bổ sung hộp thoại xem trước (preview) trước khi lưu.
  - **BUG-06 (Bộ chọn vị trí):** Bottom Sheet ghim vị trí hiển thị đúng 3 trạng thái:
    - Điểm đã có tọa độ và xác minh: `"Đã xác minh"`.
    - Điểm ghim tọa độ tạm: `"Đã ghim vị trí · Chờ xác minh"`.
    - Điểm chưa có tọa độ: `"Chưa ghim vị trí"`.

---

## 4. Lỗ Hổng Kiểm Thử Hiện Tại & Đề Xuất Bổ Sung (Testing Gaps)

1. **Bộ test Backend đã mở rộng:**
   - [backend/test/location.spec.ts](file:///d:/flutter create delivery_marker_app/backend/test/location.spec.ts) đã được bổ sung kiểm thử cho:
     - Chuẩn hóa số điện thoại khách hàng Việt Nam (`0988000001`, `+84988000001`, `0988-000-001`).
     - Kiểm tra an toàn tên file ảnh và ngăn chặn tấn công Path Traversal (`../`).
     - Từ chối các định dạng file thực thi độc hại (`.exe`, `.sh`, `.svg`).
     - Kiểm tra logic bảo toàn bản ghi lịch sử `location_history` khi gỡ liên kết với vị trí gốc.
2. **Integration Test với CSDL PostGIS sống:**
   - Cần cấu hình test runner kết nối trực tiếp container PostgreSQL PostGIS để kiểm tra các hàm SQL không gian `ST_MakePoint`, `ST_Distance` và trigger `trg_saved_locations_history` trên dữ liệu thực tế.
