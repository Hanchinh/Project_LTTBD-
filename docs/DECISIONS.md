# Architecture Decision Records (ADR): Delivery Location Marker System

> **Tài liệu của bản có máy chủ. Bản này (submit-app-only) không còn backend. Xem tag v1.0-full.**  
> **Lưu ý:** Các quyết định ADR-001 đến ADR-003 bên dưới áp dụng cho kiến trúc Client-Server tại tag `v1.0-full`. Bản nộp `submit-app-only` vận hành theo mô hình Local-First độc lập (xem [docs/BRAIN.md](docs/BRAIN.md)).

---

## 1. Các Quyết Định Kỹ Thuật Đã Xác Minh (Accepted Decisions)

### ADR-001: Sử Dụng PostgreSQL 16 + PostGIS 3.4 Làm Động Cơ Không Gian
- **Trạng thái:** `ACCEPTED`
- **Bối cảnh:** Ứng dụng cần lưu trữ tọa độ chính xác cao, tính toán khoảng cách và tra cứu vị trí địa lý với hiệu năng dưới 2 giây.
- **Quyết định:** Sử dụng PostgreSQL 16 kết hợp tiện ích PostGIS 3.4, kiểu dữ liệu `GEOMETRY(Point, 4326)` và chỉ mục không gian `GIST` trên cột `geom`.
- **Hệ quả:**
  - Tra cứu không gian cực nhanh qua chỉ mục GIST.
  - Tọa độ tuân theo quy chuẩn PostGIS: `ST_MakePoint(longitude, latitude)`.
  - Toàn bộ đội ngũ phát triển phải chạy qua Docker image `postgis/postgis:16-3.4` để đồng nhất môi trường.

### ADR-002: Áp Dụng Ngôn Ngữ TypeScript Cho Cả Backend & Admin Web
- **Trạng thái:** `ACCEPTED`
- **Bối cảnh:** Cần giảm thiểu lỗi runtime, tăng tốc độ phối hợp và đảm bảo tính nhất quán kiểu dữ liệu giữa API và Web UI.
- **Quyết định:** Sử dụng TypeScript 5.x trên cả dịch vụ Backend (Node.js/Express) và Admin Web (React/Vite).
- **Hệ quả:** Codebase được kiểm tra kiểu tĩnh (typecheck) đầy đủ, cấu trúc interface rõ ràng (`UserPayload`, `AuthenticatedRequest`, `CoverageStat`, `SavedLocationItem`).

### ADR-003: Xác Thực Không Trạng Thái Bằng JWT Kèm Phạm Vi Khu Vực (Area Scoped RBAC)
- **Trạng thái:** `ACCEPTED`
- **Bối cảnh:** Hệ thống cần phân định rõ quyền của Admin (toàn quyền) và Shipper (chỉ được truy cập khách hàng thuộc khu vực được phân công), đồng thời giảm tải truy vấn DB ở mỗi request.
- **Quyết định:** Mã hóa `roleName` và mảng `assignedAreaIds` trực tiếp vào payload của JWT token. Middleware [area.middleware.ts](file:///d:/flutter create delivery_marker_app/backend/src/middlewares/area.middleware.ts) đối chiếu `customer.area_id` với mảng `assignedAreaIds` từ token.
- **Hệ quả:**
  - Giảm thiểu truy vấn join bảng quyền hạn ở các request đọc đơn.
  - Khi thay đổi phân công khu vực của Shipper trong phiên làm việc, token cũ vẫn giữ danh sách khu vực cũ cho đến khi đăng nhập lại hoặc hết hạn.

### ADR-004: Quy Trình Lưu Vị Trí 3 Bước Trên Ứng Dụng Di Động
- **Trạng thái:** `ACCEPTED`
- **Bối cảnh:** GPS trên điện thoại tại các hẻm sâu, khuất tòa nhà ở đô thị thường có sai số từ 5m đến 30m; chỉ lấy tọa độ GPS tự động sẽ khiến vị trí bị lệch sang nóc nhà khác hoặc ngõ song song.
- **Quyết định:** Thiết kế quy trình bắt buộc 3 bước trên mobile:
  1. Đo tọa độ GPS máy + hiển thị rõ chỉ số sai số `±m`.
  2. Hiển thị bản đồ để shipper tự tay kéo/chạm ghim vào đúng vị trí cổng nhà.
  3. Bắt buộc nhập ghi chú nhận diện thực tế (màu cửa, cột mốc, số nhà phụ).
- **Hệ quả:** Đảm bảo dữ liệu vị trí thu thập được có độ tin cậy thực địa cao nhất.

### ADR-005: Lưu Vết Lịch Sử Thay Đổi Vị Trí Bằng Trigger Cơ Sở Dữ Liệu
- **Trạng thái:** `ACCEPTED`
- **Bối cảnh:** Cần đảm bảo 100% các thay đổi vị trí đều được lưu vết phục vụ đối soát, không bị bỏ sót nếu tầng ứng dụng gặp lỗi hoặc có nhiều kênh cập nhật khác nhau.
- **Quyết định:** Cài đặt Trigger mức cơ sở dữ liệu `trg_saved_locations_history` trên bảng `saved_locations`, tự động đẩy dữ liệu cũ sang `location_history` khi có sự thay đổi tọa độ hoặc ghi chú.
- **Hệ quả:** Hoạt động độc lập với tầng ứng dụng, đảm bảo tính toàn vẹn dữ liệu kiểm toán cao.

### ADR-006: Kiến Trúc Lưu Trữ Offline & Hàng Đợi Đồng Bộ Cục Bộ (SQLite)
- **Trạng thái:** `ACCEPTED`
- **Bối cảnh:** Shipper thường xuyên đi vào vùng sóng yếu (tầng hầm, hẻm cụt sâu). Thao tác lưu vị trí không được phép gián đoạn.
- **Quyết định:** Sử dụng thư viện `sqflite` lưu bảng `cached_orders` và `offline_sync_queue`. Khi mất mạng, lưu vị trí vào hàng đợi cục bộ; khi có mạng lại, hệ thống sẽ đẩy đồng bộ lên server.
- **Hệ quả:** Ứng dụng hoạt động mượt mà trong điều kiện mạng chập chờn.

### ADR-007: Loại Bỏ Cơ Chế Bypass Mật Khẩu Tĩnh & Chuẩn Hóa Bcrypt Hash
- **Trạng thái:** `ACCEPTED` (Thực thi theo [TASK-002](file:///d:/flutter create delivery_marker_app/docs/tasks/TASK-002.md))
- **Bối cảnh:** Đoạn mã fallback `if (!isMatch && password === 'password123') { isMatch = true; }` trong [auth.controller.ts](file:///d:/flutter create delivery_marker_app/backend/src/controllers/auth.controller.ts) tạo ra backdoor cho phép truy cập trái phép bất kỳ tài khoản nào nếu biết số điện thoại. Nguyên nhân gốc là chuỗi seed hash trong [01-init-db.sql](file:///d:/flutter create delivery_marker_app/init-db/01-init-db.sql) trước đây là chuỗi giả lập khiến `bcrypt.compare` thất bại.
- **Quyết định:**
  1. Loại bỏ 100% logic so sánh chuỗi tĩnh `password === 'password123'` trong Backend.
  2. Bắt buộc mọi lượt xác thực mật khẩu phải thông qua `await bcrypt.compare(password, user.password_hash)`.
  3. Cập nhật hash seed data trong `01-init-db.sql` thành chuỗi Bcrypt chuẩn (salt rounds 10) tương thích với mật khẩu mặc định `password123`.
  4. Bổ sung bộ kiểm thử hồi quy tự động [auth.spec.ts](file:///d:/flutter create delivery_marker_app/backend/test/auth.spec.ts) ngăn chặn mọi hình thức bypass trong tương lai.
- **Hệ quả:**
  - Bịt kín lỗ hổng bảo mật nghiêm trọng của hệ thống.
  - Các tài khoản thử nghiệm seed sẵn vẫn đăng nhập bình thường qua cơ chế Bcrypt tiêu chuẩn.

---

## 2. Các Đề Xuất Kỹ Thuật Đang Chờ Duyệt (Pending Decisions)

### PENDING-001: Kế Hoạch Chuyển Đổi Entry Point Của Mobile App
- **Vấn đề:** [mobile_app/lib/main.dart](file:///d:/flutter create delivery_marker_app/mobile_app/lib/main.dart) đang chứa mã nguồn prototype độc lập "Map Marker Clone" thay vì luồng đăng nhập của nhân viên giao hàng.
- **Phương án đề xuất:**
  - Thay thế nội dung `main.dart` bằng widget kiểm tra token trong `SharedPreferences`:
    - Nếu chưa có token -> Điều hướng vào [LoginView](file:///d:/flutter create delivery_marker_app/mobile_app/lib/views/login_view.dart).
    - Nếu đã có token -> Điều hướng thẳng vào [OrderListView](file:///d:/flutter create delivery_marker_app/mobile_app/lib/views/order_list_view.dart).
  - Di chuyển mã nguồn cũ của "Map Marker Clone" vào thư mục lưu trữ mẫu hoặc xóa bỏ nếu không còn sử dụng.
- **Trạng thái:** `NEEDS_VERIFICATION` (Chờ người dùng xác nhận).

### PENDING-003: Chuyển Đổi Sang Cơ Chế Xóa Mềm (Soft Delete) Cho `saved_locations`
- **Vấn đề:** Ràng buộc `ON DELETE CASCADE` làm mất sạch lịch sử vị trí trong `location_history` khi gọi `DELETE /admin/locations/:id`.
- **Phương án đề xuất:**
  - Thêm cột `deleted_at TIMESTAMPTZ DEFAULT NULL` vào bảng `saved_locations`.
  - Thay vì chạy lệnh `DELETE FROM saved_locations`, API sẽ chạy `UPDATE saved_locations SET deleted_at = CURRENT_TIMESTAMP`.
  - Cập nhật các truy vấn `SELECT` bổ sung điều kiện `WHERE deleted_at IS NULL`.
- **Trạng thái:** `NEEDS_VERIFICATION` (Chờ người dùng xác nhận).

### PENDING-004: Chiến Lược Cấu Hình Địa Chỉ API Động Cho Mobile App
- **Vấn đề:** Địa chỉ `http://10.0.2.2:3000/api/v1` bị hardcode trong `api_service.dart`.
- **Phương án đề xuất:**
  - Cho phép cấu hình qua tham số dòng lệnh `--dart-define=API_URL=...` hoặc tự động chọn IP theo môi trường:
    - Nếu chạy trên Android Emulator: dùng `http://10.0.2.2:3000/api/v1`
    - Nếu chạy trên iOS Simulator / macOS: dùng `http://localhost:3000/api/v1`
    - Cung cấp màn hình cài đặt cấu hình IP trên giao diện đăng nhập cho thiết bị thật.
- **Trạng thái:** `NEEDS_VERIFICATION` (Chờ người dùng xác nhận).
