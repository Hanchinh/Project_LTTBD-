# Feature: Profile

Phân hệ quản lý hồ sơ cá nhân và an toàn dữ liệu trên thiết bị:

- **View**:
  - `account_profile_view.dart`: Màn hình tab Cá nhân hiển thị tên người dùng, các chỉ số thống kê (số mốc đã lưu, số ca đã chạy, số ảnh chụp), các tùy chọn cài đặt PIN, sao lưu & khôi phục, nhận gói chia sẻ và thông tin ứng dụng.
- **Widgets (`widgets/`)**:
  - `backup_restore_bottom_sheet.dart`: Bảng điều khiển sao lưu CSDL ra file ZIP và khôi phục từ file ZIP.
  - `pin_settings_bottom_sheet.dart`: Bảng thiết lập, đổi hoặc tắt mã PIN bảo mật kèm cấu hình thời gian tự động khóa màn hình.
  - `profile_dialogs.dart`: Các hộp thoại xác nhận đổi tên và các cảnh báo thao tác an toàn.
  - `profile_header_card.dart`: Thẻ header cá nhân với avatar và tên hiển thị.
  - `profile_local_actions_section.dart`: Danh sách các mục cài đặt mã PIN, sao lưu dữ liệu và nhận gói chia sẻ.
  - `profile_server_config_dialog.dart`: Hộp thoại xem/sửa cấu hình địa chỉ máy chủ khi cần kết nối server.
  - `profile_stats_card.dart` & `profile_stats_section.dart`: Khối hiển thị thống kê tổng quan hoạt động cá nhân.
  - `receive_share_modal.dart`: Hộp thoại hướng dẫn và kích hoạt nhận gói chia sẻ (qua file hoặc qua mã QR).

