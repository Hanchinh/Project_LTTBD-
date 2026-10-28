# Features Module

Tập hợp toàn bộ các phân hệ chức năng người dùng, được tổ chức theo kiến trúc Feature-First:

- **`map/`**: Phân hệ bản đồ chính, tìm kiếm địa chỉ, chọn tọa độ tâm ngắm, ghim mốc và hiển thị thông tin mốc giao hàng.
- **`directory/`**: Phân hệ danh bạ khách hàng, tìm kiếm nhanh, phân loại theo khu vực và quản lý chi tiết khách hàng.
- **`shifts/`**: Phân hệ quản lý ca giao hàng, chuẩn bị ca, dán danh sách số điện thoại hàng loạt và bản đồ lộ trình ca giao.
- **`photos/`**: Phân hệ chụp, quản lý dải ảnh và trình xem ảnh mốc nhà toàn màn hình.
- **`sharing/`**: Phân hệ chia sẻ dữ liệu ngang hàng P2P không qua máy chủ (gói file `.dshare` và mã QR nén phân mảnh).
- **`profile/`**: Phân hệ cá nhân, thống kê số liệu, thiết lập mã PIN bảo vệ và sao lưu/khôi phục dữ liệu SQLite.
- **`onboarding_lock/`**: Màn hình chào mừng lần mở app đầu tiên và màn hình khóa mã PIN bảo mật.
- **`server_mode/`**: Các giao diện và tính năng kết nối với máy chủ trung tâm (được bảo lưu nguyên vẹn để sẵn sàng tái kích hoạt).

