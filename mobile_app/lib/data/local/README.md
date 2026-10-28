# Local Data

Tầng dữ liệu cục bộ hoạt động hoàn toàn ngoại tuyến (offline) trên thiết bị:

- **`app_database.dart`**: Trình bao bọc SQLite quản lý cơ sở dữ liệu `local_data_v1.db` với 6 bảng chuẩn:
  - `app_profile`: Hồ sơ cá nhân người dùng cục bộ, cấu hình băm mã PIN.
  - `customers`: Danh bạ khách hàng, số điện thoại chuẩn hóa, khu vực phụ trách.
  - `customer_locations`: Tọa độ mốc giao hàng WGS 84, ghi chú và độ chính xác GPS.
  - `customer_photos`: Đường dẫn lưu trữ ảnh mốc nhà trên bộ nhớ thiết bị.
  - `work_shifts`: Ca giao hàng và trạng thái ca (in_progress, completed, cancelled).
  - `shift_points`: Điểm giao trong ca và trạng thái giao hàng của điểm.
  - `app_meta`: Siêu dữ liệu phiên bản schema và cài đặt hệ thống.
- **`backup_service.dart`**: Dịch vụ sao lưu và khôi phục toàn bộ CSDL và ảnh sang file `.zip` nén nhất quán, có kiểm tra mã SHA-256 manifest và hỗ trợ mã hóa bảo mật AES-GCM.
- **`map_tile_cache_service.dart`**: Bộ nhớ đệm các mảnh bản đồ (tiles) OpenStreetMap trên thiết bị giúp xem bản đồ không cần internet.
- **`local_*_repository.dart`**: Các triển khai cụ thể của `*Repository` đọc/ghi trực tiếp vào SQLite cục bộ (`LocalCustomerRepository`, `LocalLocationRepository`, `LocalPhotoRepository`, `LocalProfileRepository`, `LocalSharingRepository`, `LocalShiftRepository`).

