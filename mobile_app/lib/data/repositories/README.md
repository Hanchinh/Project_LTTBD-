# Repositories & Provider

Tầng trừu tượng hóa truy cập dữ liệu (Repository Pattern):

- **Interfaces**:
  - `customer_repository.dart`: Quản lý khách hàng, khu vực, tìm kiếm danh bạ.
  - `location_repository.dart`: Quản lý mốc tọa độ, ghim mốc và truy vấn theo bán kính.
  - `photo_repository.dart`: Quản lý ảnh mốc nhà chụp và lưu trữ.
  - `profile_repository.dart`: Quản lý hồ sơ người dùng, mã PIN, thống kê.
  - `sharing_repository.dart`: Quản lý xuất/nhập gói chia sẻ mốc giao hàng.
  - `shift_repository.dart`: Quản lý ca giao hàng và lộ trình các điểm giao.
- **`repository_provider.dart`**: Cơ chế Dependency Injection (DI) cấp phát repo cục bộ (`Local*Repository`) làm mặc định, có khả năng cấu hình chuyển sang chế độ máy chủ (`Remote*Repository`).

