# Core Module

Mô-đun nền tảng chứa các tiện ích, định dạng, thuật toán mã hóa và cấu hình giao diện dùng chung trong toàn bộ ứng dụng:

- **`theme/`**: Cấu hình nút bấm giao diện (`app_buttons.dart`) tuân thủ quy chuẩn thiết kế.
- **`utils/`**:
  - `phone_utils.dart`: Tiện ích chuẩn hóa số điện thoại Việt Nam (84/0, nhận diện đầu số).
  - `pin_crypto_utils.dart`: Tiện ích băm mã PIN bằng PBKDF2/SHA-256 với salt ngẫu nhiên bảo vệ ứng dụng.
  - `share_crypto_utils.dart`: Tiện ích mã hóa đối xứng gói chia sẻ dữ liệu bằng AES-GCM và dẫn xuất khóa PBKDF2.
  - `uuid_utils.dart`: Trình tạo mã định danh duy nhất UUID v4.
  - `vietnamese_utils.dart`: Tiện ích loại bỏ dấu tiếng Việt phục vụ tìm kiếm không dấu.

