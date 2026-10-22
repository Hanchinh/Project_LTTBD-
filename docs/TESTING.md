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

### 3.2. Backend TypeScript Compilation
- **Lệnh thực thi:** `npx tsc --noEmit` trong thư mục `backend`
- **Trạng thái:** **PASSED (Exit Code: 0)**
- **Kết quả:** Không phát hiện bất kỳ lỗi cú pháp hoặc sai lệch kiểu dữ liệu nào.

### 3.3. Admin Web TypeScript Compilation
- **Lệnh thực thi:** `npx tsc --noEmit` trong thư mục `admin_web`
- **Trạng thái:** **PASSED (Exit Code: 0)**
- **Kết quả:** Không có lỗi kiểu dữ liệu trong toàn bộ component React, Page và Axios API layer.

### 3.4. Mobile App Flutter Analyze
- **Lệnh thực thi:** `flutter analyze` trong thư mục `mobile_app`
- **Trạng thái:** **EXIT CODE 1 (15 Issues phát hiện, không có lỗi cú pháp chặn)**
- **Tóm tắt vấn đề phát hiện:**
  - `5 issues`: Sử dụng thuộc tính deprecated `Color.value` trong [main.dart:L64, L219, L250, L258](file:///d:/flutter create delivery_marker_app/mobile_app/lib/main.dart).
  - `4 issues`: Thiếu từ khóa `const` với constructor trong [main.dart:L510-L519](file:///d:/flutter create delivery_marker_app/mobile_app/lib/main.dart).
  - `1 issue`: Sử dụng `print()` thay vì logging framework trong [api_service.dart:L121](file:///d:/flutter create delivery_marker_app/mobile_app/lib/services/api_service.dart#L121).
  - `4 issues`: Sử dụng `key` truyền thống thay vì `super.key` trong các view ([login_view.dart](file:///d:/flutter create delivery_marker_app/mobile_app/lib/views/login_view.dart), [order_detail_view.dart](file:///d:/flutter create delivery_marker_app/mobile_app/lib/views/order_detail_view.dart), [order_list_view.dart](file:///d:/flutter create delivery_marker_app/mobile_app/lib/views/order_list_view.dart), [save_location_view.dart](file:///d:/flutter create delivery_marker_app/mobile_app/lib/views/save_location_view.dart)).
  - `1 issue`: Tham số deprecated `desiredAccuracy` trong [save_location_view.dart:L54](file:///d:/flutter create delivery_marker_app/mobile_app/lib/views/save_location_view.dart#L54).

### 3.5. Mobile App Flutter Test
- **Lệnh thực thi:** `flutter test` trong thư mục `mobile_app`
- **Trạng thái:** **FAILED (Exit Code: 1)**
- **Nguyên nhân chi tiết:**
  - File [mobile_app/test/widget_test.dart:L14-L29](file:///d:/flutter create delivery_marker_app/mobile_app/test/widget_test.dart#L14-L29) là file kiểm thử mẫu của Flutter (kiểm tra nút cộng bộ đếm `0` -> `1`).
  - Giao diện được kiểm thử là `MapMarkerCloneApp`, không có widget text `"0"` và không có icon `Icons.add`.
  - Kết quả ném ngoại lệ `TestFailure: Expected: exactly one matching candidate, Actual: Found 0 widgets with text "0"`.

---

## 4. Lỗ Hổng Kiểm Thử Hiện Tại & Đề Xuất Bổ Sung (Testing Gaps)

1. **Thiếu Integration Test giữa Backend & CSDL PostGIS thực tế:**
   - Bộ test [location.spec.ts](file:///d:/flutter create delivery_marker_app/backend/test/location.spec.ts) hiện chỉ kiểm tra logic toán học thuần túy (Haversine) và logic mảng JavaScript (`includes`). Chưa có kiểm thử tự động gọi trực tiếp vào cơ sở dữ liệu để xác minh câu lệnh SQL không gian `ST_MakePoint`, `ST_Distance` và trigger sao lưu lịch sử.
2. **Thiếu Unit Test cho Admin Web:**
   - Thư mục `admin_web` chưa được cấu hình Jest hoặc Vitest / React Testing Library để kiểm thử logic tính toán tỷ lệ phủ hoặc hành vi bộ lọc tìm kiếm.
3. **Cần viết lại Widget Test cho Mobile App:**
   - Cần thay thế file [widget_test.dart](file:///d:/flutter create delivery_marker_app/mobile_app/test/widget_test.dart) bằng các kịch bản test thực tế:
     - Test hiển thị form đăng nhập với 2 ô text field và nút bấm.
     - Test hiển thị danh sách đơn hàng có badge "Đã có vị trí" và "Chưa có vị trí".
     - Test kiểm tra validation khi người dùng bỏ trống ghi chú nhận diện ở màn hình lưu vị trí.
