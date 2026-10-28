# Product

<!-- impeccable:product-schema 1 -->

## Platform

android

## Users
Shipper / Tài xế giao hàng chặng cuối (Last-mile) tại Việt Nam:
- Thao tác thực địa trên xe máy, sử dụng một tay ở vùng ngón cái (bottom sheets, floating buttons).
- Vận hành dưới ánh nắng gắt, thời tiết mưa gió, rung lắc hoặc mạng di động (4G/3G) chập chờn/mất sóng.
- Công việc: Tìm đúng cổng nhà khách hàng trong các ngõ ngách, số nhà phức tạp hoặc trùng lặp bằng số điện thoại, ảnh nhận diện mặt tiền thực tế và tọa độ GPS ghim chính xác.

## Product Purpose
Hệ thống đánh dấu và định vị điểm giao hàng cục bộ (Local-First Delivery Location Marker System):
- Giúp shipper lưu trữ và tra cứu ngay tức thì vị trí cổng nhà khách hàng theo số điện thoại mà không phụ thuộc vào kết nối Internet hay máy chủ trung tâm.
- Thành công là khi shipper đến điểm giao chỉ cần 1 chạm để gọi điện, mở dẫn đường ngoài (Google Maps/Apple Maps) hoặc xem ảnh cổng nhà để giao đúng địa chỉ trong vòng vài giây.

## Positioning
Khác biệt cốt lõi:
- **Local-First & Offline-First hoàn toàn:** Dữ liệu lưu trong máy (SQLite), không cần tài khoản, không cần đăng nhập, không có máy chủ theo dõi hay thu thập dữ liệu cá nhân.
- **Gắn tọa độ thực địa chuẩn xác theo SĐT:** Bản đồ không chỉ tìm địa chỉ hành chính mà gắn chính xác điểm đứng trước cửa nhà theo số điện thoại khách.
- **Chia sẻ P2P ngoại tuyến:** Xuất/nhập file `.dshare` hoặc quét mã QR chunking nén dữ liệu trực tiếp giữa 2 thiết bị mà không qua đám mây hay máy chủ trung gian.

## Operating Context
- Môi trường di động: Điện thoại Android gắn trên giá đỡ xe máy hoặc cầm một tay.
- Công cụ tương tác: Ứng dụng bản đồ ngoài (Google Maps / Apple Maps qua Intent), camera chụp ảnh cổng nhà, cuộc gọi điện thoại trực tiếp (`tel:`).
- Thao tác nhanh: Dán hàng loạt SĐT từ tin nhắn/zalo vào ca làm việc hoặc danh bạ, ghim tâm ngắm cố định (crosshair picker) thay vì kéo thả vụng về.

## Capabilities and Constraints
- **Khả năng:**
  - Bản đồ tương tác ngoại tuyến, hiển thị điểm đã lưu trên nền lưới khi mất mạng.
  - Quản lý danh bạ khách hàng tìm kiếm không dấu tốc độ cao (<50ms).
  - Quản lý ca làm việc (chuẩn bị danh sách tại kho, tối ưu lộ trình, phân biệt điểm Ghim tạm vs Xác minh).
  - Quản lý đến 10 ảnh mốc nhà/cổng nhà cho mỗi khách, tự động nén <= 1600px.
  - Khóa bảo mật bằng mã PIN 4-6 số (băm PBKDF2/SHA-256 + Salt trong Isolate riêng).
  - Sao lưu toàn bộ CSDL và ảnh thành file ZIP có mật khẩu AES-GCM; khôi phục an toàn chống path traversal.
  - Chia sẻ dữ liệu offline qua gói `.dshare` và QR code chia mảnh.
- **Ràng buộc:**
  - Cực kỳ an toàn dữ liệu: Xóa ca không xóa khách/vị trí; xóa vị trí phải lưu lại lịch sử đối soát (`location_history`).
  - Không hardcode bí mật, không ghi SĐT/thông tin cá nhân ra log hệ thống.
  - Mọi thao tác UI phải tối ưu cho ngón cái: touch target $\ge 48\text{px}$ (các nút hành động chính $\ge 56\text{px}$), cỡ chữ to, độ tương phản cao ngoài nắng.

## Brand Commitments
- Tên ứng dụng: Delivery Location Marker System (Bộ Đánh Dấu Vị Trí Giao Hàng).
- Màu sắc nhận diện: Tone Navy/Đen sang trọng, tương phản cao (`#0F172A`, `#1E293B`), điểm nhấn Xanh biển (`#2563EB`, `#1D4ED8`), Trạng thái Xanh lá (`#15803D`, `#DCFCE7`), Cảnh báo Cam (`#D97706`).

## Evidence on Hand
- Toàn bộ mã nguồn bản nộp độc lập trong thư mục `mobile_app/`.
- 182/182 bài kiểm thử tự động (Unit & Widget tests) vượt qua 100% trong `mobile_app/test/`.
- Phân tích cú pháp tĩnh `flutter analyze` sạch 100% (0 issues).
- Tài liệu kiến trúc và nghiệp vụ chi tiết tại `docs/BRAIN.md`, `docs/ARCHITECTURE.md`, `docs/DATABASE.md`, `docs/CODE_STRUCTURE.md`.

## Product Principles
1. **Offline & Autonomous First:** Mọi tính năng cốt lõi (tìm kiếm, bản đồ, ca làm việc, ảnh, danh bạ) phải hoạt động trơn tru khi không có mạng Internet.
2. **One-Handed Ergonomics:** Giao diện bám đáy màn hình, nút bấm to bản $\ge 48-56\text{px}$, chữ to rõ ràng, dễ bấm chính xác ngay cả khi đeo găng tay hoặc đang dừng xe ngoài nắng.
3. **Data Integrity & Privacy:** Dữ liệu là của tài xế và khách hàng; không rò rỉ lên máy chủ, không bypass bảo mật, bảo toàn lịch sử vị trí.
4. **Resilient Simplicity:** Thiết kế tinh gọn, trực quan, loại bỏ các bước nhập liệu rườm rà; dùng tâm ngắm cố định và dán tự động thay vì gõ tay từng ký tự.

## Accessibility & Inclusion
- Hỗ trợ tốt cho tài xế lớn tuổi hoặc mắt kém: kích thước font chữ $\ge 15-18\text{sp}$, độ tương phản WCAG AA cao, hỗ trợ TextScaler lên tới 1.5x không bị lỗi tràn giao diện (RenderFlex overflow).
- Semantics và Tooltip đầy đủ cho tất cả nút bấm và icon trên bản đồ.

