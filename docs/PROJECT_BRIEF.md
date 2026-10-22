# Project Brief: Delivery Location Marker System (MVP)

> **Tài liệu phục vụ phối hợp giữa Project Architect và Software Engineer.**  
> **Trạng thái:** Hoàn tất khảo sát ban đầu. Không chứa thông tin suy diễn chưa xác minh.

---

## 1. Mục Đích Dự Án (Purpose)

Hệ thống **Ghi nhớ Vị trí Giao hàng Thực tế (Delivery Location Marker System)** là một giải pháp MVP nhằm giải quyết bài toán giao hàng chặng cuối (last-mile delivery) tại Việt Nam:
- **Vấn đề cốt lõi:** Địa chỉ hiển thị trên hóa đơn/đơn hàng thường không đầy đủ hoặc gây nhầm lẫn (hẻm ngoằn ngoèo, số nhà phụ/nhảy số, địa chỉ không có trên bản đồ số công cộng). Shipper thường xuyên phải gọi điện nhiều lần và mất nhiều thời gian tìm đường cho mỗi lần giao.
- **Giải pháp:** Cung cấp cơ chế cho phép Shipper sau khi giao hàng thành công tại địa chỉ thực tế sẽ ghi nhận lại tọa độ chuẩn xác (thông qua GPS kết hợp kéo thả ghim thủ công) cùng các ghi chú nhận diện thực địa (màu cổng, ngã rẽ, cột mốc). Các lần giao sau cho cùng khách hàng đó, Shipper sẽ thấy ngay vị trí chính xác và bấm dẫn đường trực tiếp. Quản lý vận hành (Admin) có công cụ trực quan để theo dõi tỷ lệ phủ vị trí theo từng khu vực.

---

## 2. Đối Tượng Người Dùng (Target Users & Personas)

1. **Nhân viên Giao hàng (Shipper / Delivery Staff):**
   - Sử dụng ứng dụng di động (Flutter Mobile App).
   - Nhu cầu: Xem danh sách đơn trong ca, phân biệt đơn đã/chưa có vị trí lưu, mở điều hướng ngoài (Google Maps) tới tọa độ đã lưu, thực hiện quy trình lưu vị trí 3 bước (GPS, ghim, ghi chú), thao tác ổn định ngay cả khi mạng yếu/mất mạng (Offline-first).
2. **Quản lý Vận hành Hệ thống (Admin / Operations Manager):**
   - Sử dụng cổng thông tin quản trị web (React Admin Portal).
   - Nhu cầu: Xem dashboard tỷ lệ phủ vị trí (% coverage) theo từng khu vực, xem và tìm kiếm vị trí thực tế của khách hàng trên bản đồ số/ảnh vệ tinh, quản lý danh mục khu vực, phân công/bàn giao khu vực phụ trách cho từng shipper, kiểm tra nhật ký thao tác (Audit Logs).

---

## 3. Phạm Vi Dự Án (Scope & Non-Goals)

### 3.1. Trong phạm vi (In-Scope - MVP)
- **Cơ sở dữ liệu không gian:** PostgreSQL 16 + PostGIS 3.4 với chỉ mục không gian GIST và trigger sao lưu lịch sử vị trí tự động.
- **Backend API:** Node.js Express + TypeScript cung cấp RESTful API, tài liệu Swagger OpenAPI, xác thực JWT và kiểm soát truy cập theo vai trò (RBAC) kết hợp phạm vi khu vực phụ trách (`checkCustomerAreaScope`).
- **Admin Web Portal:** React + Vite + Tailwind CSS + Leaflet hiển thị bản đồ đa lớp (OpenStreetMap & Esri Satellite), dashboard tiến độ phủ, phân công khu vực và tra cứu vị trí.
- **Mobile App:** Flutter hỗ trợ đăng nhập, danh sách đơn trong ca, chi tiết đơn hàng, quy trình lưu vị trí 3 bước (đo GPS sai số ±m, chỉnh ghim, nhập ghi chú), lưu tạm SQLite offline và đồng bộ khi có mạng.
- **Đóng gói phát triển:** Docker Compose điều phối CSDL PostGIS, Backend API và Admin Web.

### 3.2. Ngoài phạm vi (Out-of-Scope / Non-Goals cho MVP)
- Ứng dụng dành cho người nhận hàng (Customer-facing app) tra cứu đơn.
- Thuật toán tối ưu hóa lộ trình giao hàng tự động (Vehicle Routing Problem / TSP).
- Định vị hành trình xe di chuyển thời gian thực (Real-time fleet tracking qua WebSockets/MQTT).
- Tích hợp cổng thanh toán trực tuyến hoặc quản lý COD chuyên sâu.

---

## 4. Yêu Cầu Nghiệp Vụ Cốt Lõi (Key Business Requirements)

| Mã Yêu Cầu | Tên Yêu Cầu | Mô Tả & Tiêu Chí Nghiệp Vụ | Trạng Thái Code |
| :--- | :--- | :--- | :--- |
| **BR-01** | Quy trình lưu vị trí 3 bước | 1) Đo GPS + hiển thị sai số ±m; 2) Cho phép shipper chạm/kéo ghim trên bản đồ để bù trừ sai số GPS; 3) Bắt buộc nhập ghi chú nhận diện (hẻm, màu cửa, đặc điểm). | Đã có view code, chưa kích hoạt ở entry point |
| **BR-02** | Phân quyền theo khu vực (Area Scope) | Shipper chỉ được quyền xem đơn hàng và đọc/ghi vị trí của khách hàng thuộc khu vực được phân công phụ trách. Admin có toàn quyền. | Đã triển khai & unit test pass |
| **BR-03** | Lưu vết lịch sử thay đổi vị trí | Mỗi khi vị trí hiện hành của khách hàng được cập nhật, dữ liệu cũ phải được tự động sao lưu vào bảng lịch sử vị trí để đối soát. | Đã triển khai bằng trigger DB |
| **BR-04** | Hoạt động Offline | Khi thiết bị mất kết nối mạng, cho phép shipper xem đơn đã cache và lưu tạm vị trí vào hàng đợi cục bộ; tự động đẩy lên server khi có mạng lại. | Đã triển khai code SQLite & Queue |
| **BR-05** | Thống kê tỷ lệ phủ vị trí | Tính toán phần trăm khách hàng đã có vị trí thực tế trên tổng số khách theo từng khu vực quản lý. | Đã triển khai API & Dashboard |

---

## 5. Các Điểm Chưa Xác Định (Unknowns & Needs Verification)

- `[UNKNOWN]` **Nguồn cấp dữ liệu đơn hàng & khách hàng:** Hiện tại dữ liệu đơn và khách được nạp từ seed script ([01-init-db.sql](file:///d:/flutter create delivery_marker_app/init-db/01-init-db.sql)). Chưa có tài liệu về API tích hợp đồng bộ từ hệ thống ERP/OMS/WMS bên ngoài.
- `[UNKNOWN]` **Môi trường triển khai thực tế (Production Infrastructure):** Chưa có tài liệu về hạ tầng đích (Kubernetes, AWS, VPS riêng, Reverse Proxy SSL).
- `[NEEDS_VERIFICATION]` **Chính sách phân quyền mở rộng:** Hiện tại chỉ có 2 vai trò `ADMIN` và `SHIPPER`. Cần xác nhận trong tương lai có thêm vai trò Điều phối viên (Dispatcher) hoặc Trưởng bưu cục (Station Lead) hay không.
