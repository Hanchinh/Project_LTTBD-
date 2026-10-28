# Feature: Sharing (P2P File & QR)

Phân hệ chia sẻ mốc giao hàng ngang hàng P2P không cần kết nối máy chủ:

- `data_share_send_sheet.dart`: Bảng xuất và gửi gói chia sẻ dữ liệu `.dshare` (chọn phạm vi: tất cả / theo ca / theo danh sách chọn, tùy chọn kèm ảnh, mã hóa bằng mật khẩu AES-GCM).
- `data_share_qr_view.dart`: Màn hình tạo mã QR chia sẻ (tự động nén dữ liệu gzip và phân mảnh nhiều mã QR kèm checksum khi dữ liệu lớn).
- `data_share_qr_scanner_view.dart`: Màn hình camera quét mã QR, theo dõi tiến độ quét các mảnh và tự động ráp lại khi đủ các phần.
- `data_share_import_preview_sheet.dart`: Bảng đối soát và xem trước gói dữ liệu chia sẻ trước khi ghi vào CSDL (phân loại điểm mới, trùng SĐT, hoặc khác vị trí).

