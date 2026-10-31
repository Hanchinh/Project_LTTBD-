# data/shifts
Quản lý ca làm việc, thứ tự điểm giao và nhập SĐT hàng loạt vào ca.

- `shift_repository.dart`: Repository điều phối ca (tạo, đổi tên, xóa, chốt trạng thái).
- `shift_queries.dart`: Câu truy vấn SQLite cho ca giao hàng và danh sách ca.
- `shift_point_ops.dart`: Thao tác thêm/bớt mốc giao, cập nhật thứ tự và gán vị trí điểm.
- `shift_bulk_helpers.dart`: Logic phân loại SĐT và nạp mốc giao hàng loạt vào ca.
