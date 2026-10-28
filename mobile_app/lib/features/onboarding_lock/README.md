# Feature: Onboarding & App Lock

Phân hệ khởi động ứng dụng lần đầu và bảo mật khóa ứng dụng:

- `welcome_onboarding_view.dart`: Màn hình chào mừng người dùng lần đầu tiên mở ứng dụng, cho phép nhập nhanh tên hiển thị (hoặc bỏ qua) để vào thẳng bản đồ làm việc mà không cần tài khoản hay kết nối mạng.
- `pin_lock_screen.dart`: Màn hình khóa mã PIN bảo mật hiển thị khi mở app hoặc khi quay lại ứng dụng từ chạy nền sau thời gian chờ (ngay lập tức, 1 phút, 5 phút). Tự động khóa tạm thời khi nhập sai quá 5 lần.

