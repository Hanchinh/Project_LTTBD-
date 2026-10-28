# Data Models

Chứa toàn bộ các lớp thực thể dữ liệu (Data Models) và serialization trong hệ thống:

- `address_search_result.dart`: Kết quả geocoding tìm kiếm địa chỉ từ Nominatim/OSM.
- `customer_model.dart`: Thực thể khách hàng và khu vực phụ trách.
- `customer_photo_model.dart`: Ảnh mốc nhà khách hàng (đường dẫn cục bộ hoặc URL từ xa).
- `data_share_model.dart`: Mô hình chia sẻ điểm qua máy chủ API cũ.
- `local_share_models.dart`: Cấu trúc gói dữ liệu chia sẻ ngang hàng P2P (`.dshare`) và chia sẻ qua mã QR phân mảnh.
- `location_model.dart`: Tọa độ mốc giao hàng WGS 84, mô tả chi tiết vị trí và bán kính phục vụ.
- `order_model.dart`: Đơn hàng giao hàng của phiên bản luồng đơn hàng máy chủ cũ.
- `shift_model.dart`: Ca giao hàng và chi tiết các điểm giao trong ca.
- `user_model.dart`: Thông tin tài khoản người dùng và hồ sơ cá nhân.

