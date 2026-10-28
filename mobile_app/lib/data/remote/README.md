# Remote Data (Server Mode)

Tầng giao tiếp mạng dành riêng cho chế độ kết nối với máy chủ trung tâm (Server Mode):

- **`api_client.dart`**: Trình quản lý HTTP Client chung, lưu trữ base URL, JWT token, cấu hình timeout (15s), và xử lý chuẩn hóa ngoại lệ mạng.
- **`*_api.dart`**: Các mô-đun API REST tách biệt theo từng cụm tính năng:
  - `auth_api.dart`: Đăng nhập, đổi mật khẩu, quản lý token.
  - `customer_api.dart`: Đồng bộ danh bạ khách hàng.
  - `location_api.dart`: Lưu và truy vấn vị trí mốc giao hàng.
  - `photo_api.dart`: Tải lên và lấy URL ảnh mốc giao hàng.
  - `shift_api.dart`: Đồng bộ và quản lý ca giao hàng.
  - `sharing_api.dart`: Chia sẻ điểm qua API máy chủ.
  - `geocoding_api.dart`: Tìm kiếm địa chỉ qua Nominatim / OSM.
- **`api_service.dart`**: Lớp bao facade mỏng gom các API con, duy trì tương thích 100% cho mã nguồn cũ.
- **`remote_*_repository.dart`**: Các triển khai của `*Repository` kết nối tới API REST của máy chủ.
- **`offline_storage_service.dart`**: Dịch vụ đệm ngoại tuyến cũ của phiên bản có máy chủ.

