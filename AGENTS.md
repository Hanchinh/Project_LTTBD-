# AGENTS.md: Collaboration Guidelines for AI Agents

> **Tài liệu quy định các nguyên tắc bắt buộc dành cho AI Web (Project Architect) và IDE Agent (Software Engineer) khi làm việc trong dự án Delivery Location Marker System.**

---

## 1. Phân Định Vai Trò & Cơ Chế Phối Hợp (Role Division)

1. **AI Web (Project Architect):**
   - Chịu trách nhiệm về định hướng hệ thống, phân tích yêu cầu nghiệp vụ, cập nhật tài liệu kỹ thuật (`docs/PROJECT_BRIEF.md`, `docs/ARCHITECTURE.md`, `docs/DATABASE.md`, `docs/DECISIONS.md`).
   - Quyết định các mẫu thiết kế (Design Patterns), API Contracts, schema CSDL và đánh giá rủi ro kỹ thuật.
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
  - **ĐÃ CODE:** Mã nguồn đã tồn tại nhưng chưa có automated test bao phủ.
  - **ĐÃ TEST:** Đã chạy lệnh kiểm thử thực tế và đạt kết quả mong muốn.
  - **LỖI / CHƯA GẮN:** Mã nguồn có vấn đề logic, cú pháp hoặc bị tách rời khỏi luồng chính.
  - **CHƯA TRIỂN KHAI:** Chưa có bất kỳ dòng code hoặc UI nào.
- Khi thiếu bằng chứng, Agent **phải** ghi rõ nhãn `UNKNOWN` hoặc `NEEDS_VERIFICATION`. Nghiêm cấm bịa đặt thông tin.

### 2.3. Quy Chuẩn Không Gian PostGIS (Spatial Conventions)
- Mọi thao tác lưu tọa độ không gian PostGIS phải tuân thủ nghiêm ngặt thứ tự tham số:
  - `ST_MakePoint(longitude, latitude)` tương ứng với `(X, Y)`.
  - Hệ tọa độ chuẩn: **SRID 4326 (WGS 84)**.
  - Hàm bọc chuẩn: `ST_SetSRID(ST_MakePoint(longitude, latitude), 4326)`.
- Sai lệch thứ tự kinh độ / vĩ độ sẽ làm tọa độ bị trôi ra ngoài đại dương hoặc sang quốc gia khác.

### 2.4. Bảo Mật & Quản Lý Bí Mật (Secrets & Credentials)
- **Nghiêm cấm** ghi trực tiếp (hardcode) mật khẩu, chuỗi kết nối CSDL, JWT secret key, API key vào mã nguồn hoặc tài liệu Markdown.
- Mọi bí mật cấu hình phải thông qua biến môi trường (`.env`, `dotenv`, `process.env`, `import.meta.env`).
- Tuyệt đối không tạo lại các đoạn mã bypass cửa hậu (như `if (password === 'password123')`) trong môi trường phát triển chính thức.

### 2.5. An Toàn Dữ Liệu & Toàn Vẹn Kiểm Toán (Audit Integrity)
- Không bao giờ chạy các lệnh xóa bảng (`DROP TABLE`) hoặc xóa cascade tùy tiện khi chưa có sao lưu hoặc chỉ định rõ ràng từ người dùng.
- Thao tác xóa vị trí phải đảm bảo không làm mất dấu vết trong `location_history` và `audit_logs`.

### 2.6. Đồng Bộ Tài Liệu (Documentation Synchronization)
- Bất kỳ khi nào thực hiện sửa đổi kiến trúc, thêm bảng CSDL hoặc phát hiện lỗi mới, Agent có nhiệm vụ cập nhật ngay vào các tệp tương ứng trong thư mục `docs/`:
  - Thêm / đổi schema -> cập nhật [docs/DATABASE.md](file:///d:/flutter create delivery_marker_app/docs/DATABASE.md).
  - Thay đổi kiến trúc / entry point -> cập nhật [docs/ARCHITECTURE.md](file:///d:/flutter create delivery_marker_app/docs/ARCHITECTURE.md).
  - Hoàn thành task / sửa bug -> cập nhật [docs/CURRENT_STATE.md](file:///d:/flutter create delivery_marker_app/docs/CURRENT_STATE.md).
  - Chạy test mới -> cập nhật [docs/TESTING.md](file:///d:/flutter create delivery_marker_app/docs/TESTING.md).

### 2.7. Quy Tắc Định Dạng Đường Dẫn (Markdown File Links)
- Khi nhắc đến bất kỳ tệp nào trong báo cáo hoặc tài liệu, Agent **bắt buộc** tạo đường dẫn Markdown có thể nhấp chuột (`clickable link`) sử dụng lược đồ `file:///` với dấu gạch chéo xuôi `/`, ví dụ:
  `[app.ts](file:///d:/flutter create delivery_marker_app/backend/src/app.ts)`.
