# Feature: Server Mode (Legacy / Server Connected)

> **Lưu ý:** Đây là bản cài đặt giao tiếp máy chủ, giữ lại để tương thích với bản có máy chủ ở tag `v1.0-full`. Trong bản nộp `submit-app-only`, app chạy mặc định ở chế độ Local-First và không gọi các file này.

---

Mô-đun bảo lưu toàn bộ các màn hình và chức năng dành riêng cho chế độ kết nối máy chủ tập trung (Centralized Server Architecture). Các màn hình này không chạy trong luồng mặc định Local-First nhưng được bảo tồn nguyên vẹn để sẵn sàng tái kích hoạt:

- `login_view.dart`: Màn hình đăng nhập tài khoản hệ thống tập trung qua REST API.
- `change_password_view.dart`: Màn hình đổi mật khẩu người dùng trên máy chủ.
- `data_sharing_view.dart`: Màn hình chia sẻ điểm qua máy chủ API phiên bản cũ.
- `delivery_map_view.dart`: Bản đồ phân phối và chỉ định đơn hàng theo thời gian thực luồng máy chủ.
- `order_list_view.dart` & `order_detail_view.dart`: Danh sách và chi tiết các đơn hàng máy chủ.
- `save_location_view.dart`: Màn hình lưu tọa độ mốc kết nối API.
- `prototype_map_marker_view.dart`: Bản mẫu thử nghiệm cơ chế đánh dấu mốc ban đầu của dự án.
