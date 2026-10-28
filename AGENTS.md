# AGENTS.md: Collaboration Guidelines for AI Agents

> **Tài liệu quy định các nguyên tắc bắt buộc dành cho AI Web (Project Architect) và IDE Agent (Software Engineer) khi làm việc trong dự án Delivery Location Marker System.**

---

## 1. Phân Định Vai Trò & Cơ Chế Phối Hợp (Role Division)

1. **AI Web (Project Architect):**
   - Chịu trách nhiệm về định hướng hệ thống, phân tích yêu cầu nghiệp vụ, cập nhật tài liệu kỹ thuật (`docs/BRAIN.md`, `docs/ARCHITECTURE.md`, `docs/DATABASE.md`, `docs/DECISIONS.md`).
   - Quyết định các mẫu thiết kế (Design Patterns), cấu trúc dữ liệu, và đánh giá rủi ro kỹ thuật.
   - **Không** trực tiếp thực thi mã nguồn trên máy của người dùng khi chưa có sự thống nhất về kiến trúc.
2. **IDE Agent (Software Engineer):**
   - Chịu trách nhiệm thực thi mã nguồn cụ thể, sửa lỗi, viết kiểm thử và cập nhật `docs/CURRENT_STATE.md` cùng `docs/TESTING.md`.
   - Chạy các lệnh kiểm tra an toàn (typecheck, lint, unit test), ghi lại chính xác kết quả thực tế.
   - Phản hồi lại Architect nếu phát hiện điểm nghẽn, xung đột trong thiết kế hoặc điểm bất khả thi khi cài đặt.

---

## 2. Các Nguyên Tắc Bắt Buộc (Mandatory Principles)

### 2.1. Khảo Sát Trước Khi Sửa Đổi (Read-Before-Write)
- Trước khi thực hiện bất kỳ thay đổi nào, Agent **phải** đọc kỹ cấu trúc thư mục, các tệp liên quan và tài liệu trong `docs/`.
- Không được giả định rằng một chức năng đã hoàn chỉnh chỉ vì có tệp hoặc giao diện của nó trong thư mục. Phải kiểm tra xem tệp đó có đang được import và gọi thực thi tại entry point hay không.

### 2.2. Phân Biệt Thực Tế Đã Xác Minh Với Suy Đoán (Evidence-Based)
- **Không bao giờ tuyên bố kiểm thử thành công nếu chưa thực sự chạy lệnh.**
- Phân định rõ ràng giữa:
  - **[ĐÃ CODE]:** Mã nguồn đã tồn tại nhưng chưa có automated test bao phủ.
  - **[ĐÃ TEST]:** Đã chạy lệnh kiểm thử thực tế và đạt kết quả mong muốn.
  - **[LỖI / CHƯA GẮN]:** Mã nguồn có vấn đề logic, cú pháp hoặc bị tách rời khỏi luồng chính.
  - **[CHƯA TRIỂN KHAI]:** Chưa có bất kỳ dòng code hoặc UI nào.
  - **[CHƯA THỬ TRÊN ĐIỆN THOẠI THẬT]:** Đã vượt qua automated unit/widget test trên máy tính nhưng chưa kiểm thử thao tác phần cứng thực tế (GPS, camera, intent mở file, quét QR).
- Khi thiếu bằng chứng, Agent **phải** ghi rõ nhãn `UNKNOWN` hoặc `NEEDS_VERIFICATION`. Nghiêm cấm bịa đặt thông tin.

### 2.3. Quy Chuẩn Riêng Cho Bản App Local-First (Nhánh `submit-app-only`)
- **Kiểm thử cách ly (Test Isolation):** Mọi automated test trên app phải sử dụng CSDL in-memory (`sqflite_common_ffi` với `:memory:`) hoặc file database tạm được dọn dẹp sau khi chạy test. Tuyệt đối không can thiệp vào cơ sở dữ liệu thật của thiết bị.
- **Tiến hóa Schema SQLite (Database Migrations):** Mọi thay đổi cấu trúc bảng, thêm cột hoặc chỉ mục SQLite bắt buộc phải tăng `user_version` trong `app_database.dart`, viết script migration tương ứng và bổ sung unit test kiểm tra nâng cấp phiên bản schema.
- **Tối ưu hình ảnh & dọn rác:** Ảnh chụp luôn phải được nén cạnh dài tối đa 1600px trước khi lưu vào thư mục riêng (`app_photos/`). Tiến trình mở app tự động dọn ảnh đã xóa mềm quá 30 ngày và các file tạm trong bộ nhớ đệm chia sẻ/sao lưu.

### 2.4. Bảo Mật & Quản Lý Bí Mật (Secrets & Credentials)
- **Nghiêm cấm** ghi trực tiếp (hardcode) mật khẩu, mã PIN, API key hoặc chuỗi bí mật vào mã nguồn hoặc tài liệu Markdown.
- Mã PIN phải luôn được băm một chiều (PBKDF2/SHA-256 kèm salt ngẫu nhiên) trong Isolate riêng; không lưu hoặc in mã PIN thô ra log.
- Không in số điện thoại, tên khách hàng hoặc dữ liệu cá nhân vào log hệ thống.
- Tuyệt đối không tạo lại các đoạn mã bypass cửa hậu (như `if (pin === '1234')`) trong môi trường phát triển chính thức.

### 2.5. An Toàn Dữ Liệu & Toàn Vẹn Lịch Sử (Data Integrity)
- Không bao giờ chạy các lệnh xóa bảng tùy tiện (`DROP TABLE`) khi chưa có sao lưu hoặc chỉ định rõ ràng từ người dùng.
- Thao tác xóa vị trí hoặc xóa khách hàng phải đảm bảo bảo toàn lịch sử vị trí (`location_history`) và nhật ký hoạt động (`activity_logs`).
- Xóa ca làm việc không được xóa khách hàng hay vị trí đã lưu.

### 2.6. Đồng Bộ Tài Liệu (Documentation Synchronization)
- Bất kỳ khi nào thực hiện sửa đổi kiến trúc, thêm bảng CSDL hoặc phát hiện lỗi mới, Agent có nhiệm vụ cập nhật ngay vào các tệp tương ứng trong thư mục `docs/`:
  - Cập nhật định hướng / quy tắc cốt lõi -> [docs/BRAIN.md](docs/BRAIN.md).
  - Thêm / đổi schema CSDL -> [docs/DATABASE.md](docs/DATABASE.md).
  - Thay đổi cấu trúc file / refactor -> [docs/CODE_STRUCTURE.md](docs/CODE_STRUCTURE.md).
  - Hoàn thành task / sửa bug -> [docs/CURRENT_STATE.md](docs/CURRENT_STATE.md).
  - Chạy test mới -> [docs/TESTING.md](docs/TESTING.md).

### 2.7. Quy Tắc Định Dạng Đường Dẫn (Markdown File Links)
- Khi nhắc đến bất kỳ tệp nào trong tài liệu dự án, Agent sử dụng đường dẫn Markdown tương đối chuẩn, ví dụ: `[app_database.dart](mobile_app/lib/data/local/app_database.dart)`.
- Không sử dụng đường dẫn tuyệt đối gắn cứng vào ổ đĩa máy tính cá nhân (như `d:\...`).

---

## 3. Quy Chuẩn Dành Cho Bản Có Máy Chủ (Chỉ áp dụng tại tag `v1.0-full`)

Khi làm việc trên phiên bản có máy chủ (Node.js/Express, PostgreSQL/PostGIS, Admin Web React tại tag `v1.0-full`):
- **Quy chuẩn không gian PostGIS:** Thứ tự tham số chuẩn là `ST_MakePoint(longitude, latitude)` tương ứng `(X, Y)` với hệ tọa độ WGS 84 (SRID 4326), bọc qua `ST_SetSRID(ST_MakePoint(lng, lat), 4326)`.
- **Cấu hình môi trường:** Quản lý cấu hình qua `.env` (không commit `.env` lên git; luôn duy trì `.env.example`).
- **Kiểm soát truy cập:** Xác thực JWT, phân quyền vai trò người dùng (Admin vs Shipper), kiểm toán qua `audit_logs`.
