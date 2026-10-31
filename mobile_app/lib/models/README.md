# Data Models

Chứa các lớp thực thể dữ liệu (Data Models) trong hệ thống Local-First:

- `address_search_result.dart`: Kết quả geocoding tìm kiếm địa chỉ từ Nominatim/OSM.
- `customer_model.dart`: Thực thể khách hàng và khu vực phụ trách.
- `customer_photo_model.dart`: Ảnh mốc nhà khách hàng lưu trữ cục bộ.
- `local_share_models.dart`: Cấu trúc gói dữ liệu chia sẻ ngang hàng P2P (`.dshare`), mã QR phân mảnh và điểm được chia sẻ (`SharedLocationPointModel`).
- `location_model.dart`: Tọa độ mốc giao hàng WGS 84, mô tả chi tiết vị trí.
- `shift_model.dart`: Ca giao hàng và chi tiết các điểm giao trong ca.
- `user_profile.dart`: Thông tin hồ sơ người dùng cục bộ.
