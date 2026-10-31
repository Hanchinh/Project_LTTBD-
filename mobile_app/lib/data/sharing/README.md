# data/sharing
Chia sẻ dữ liệu điểm giao P2P qua file mã hóa .dshare hoặc mã QR.

- `sharing_repository.dart`: Repository điều phối luồng tạo gói và tiếp nhận gói chia sẻ.
- `sharing_export_ops.dart`: Đóng gói dữ liệu điểm giao, mã hóa AES-GCM kèm mật khẩu.
- `sharing_import_ops.dart`: Giải mã, kiểm tra trùng lặp và lưu điểm giao nhận được vào DB.

