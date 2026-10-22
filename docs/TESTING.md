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

Tất cả các lệnh dưới đây đã được thực thi trực tiếp trên máy chủ trong đợt khảo sát ngày **22/10/2026**:

### 3.1. Backend Unit Tests
- **Lệnh thực thi:** `npm test -- --verbose` trong thư mục `backend`
- **Trạng thái:** **PASSED (Exit Code: 0)**
- **Thời gian thực thi:** 1.875 s
- **Log chi tiết:**
  ```text
  > delivery-marker-backend@1.0.0 test
  > jest --detectOpenHandles --verbose

  PASS test/auth.spec.ts
    Authentication & Password Verification Security Tests
      1. Bcrypt Cryptographic Verification Logic
        √ should successfully verify when password matches valid bcrypt hash (103 ms)
        √ should reject verification when password does not match bcrypt hash (95 ms)
        √ should strictly reject "password123" when user has a different password hash (95 ms)
        √ should verify that seed data hash correctly resolves default test password (231 ms)
      2. Auth Controller Login Endpoint Security & Regression
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
  - Đã viết lại hoàn chỉnh [mobile_app/test/widget_test.dart](file:///d:/flutter create delivery_marker_app/mobile_app/test/widget_test.dart) bao gồm 4 kịch bản kiểm thử:
    1. Khởi tạo `DeliveryLocationMarkerApp` với `AuthSplashScreen` và hiển thị tiêu đề, loading.
    2. Giao diện `LoginView` với kiểm tra validation khi bỏ trống trường số điện thoại hoặc mật khẩu.
    3. Đọc và giải mã dữ liệu `OrderModel` từ JSON kèm thông tin khách hàng và vị trí.
    4. Kiểm tra cấu trúc dữ liệu `SavedLocationModel` với trường `imageUrl`.
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
  - `flutter test`: **PASSED (24/24 tests passed, 0 failures)**

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
