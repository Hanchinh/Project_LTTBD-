# Feature: Shifts

Phân hệ quản lý ca giao hàng và lộ trình:

- **Views**:
  - `shift_list_view.dart`: Màn hình danh sách ca giao hàng phân loại theo trạng thái (Đang giao, Đã kết thúc, Đã hủy).
  - `shift_preparation_view.dart`: Màn hình chuẩn bị ca, thêm các điểm giao vào ca từ danh bạ hoặc dán hàng loạt số điện thoại.
  - `shift_map_view.dart`: Màn hình bản đồ lộ trình ca giao hiển thị các điểm cần giao, trạng thái giao (thành công, hoãn, thất bại).
- **Widgets (`widgets/`)**:
  - `create_shift_dialog.dart`: Hộp thoại tạo mới ca giao hàng.
  - `shift_picker_bottom_sheet.dart`: Bảng chọn ca đang hoạt động để thêm mốc nhanh.
  - `shift_bulk_banner.dart`: Banner thông báo kết quả sau khi dán hàng loạt vào ca.
  - `shift_card.dart`: Thẻ ca giao hàng nổi bật hiển thị tiến độ và trạng thái.
  - `shift_list_row.dart`: Dòng hiển thị ca trong lịch sử ca làm việc.
  - `shift_map_controls.dart`: Các nút điều khiển riêng trên bản đồ ca giao.
  - `shift_map_header.dart`: Thanh tiêu đề bản đồ ca kèm thống kê tiến độ giao.
  - `shift_map_markers_builder.dart`: Bộ tạo marker biểu diễn các mốc giao trong ca.
  - `shift_map_tile_config.dart`: Cấu hình lớp bản đồ và hiển thị tile trong ca.
  - `shift_point_card.dart`: Thẻ hiển thị điểm giao trong danh sách chuẩn bị ca.
  - `shift_point_detail_card.dart`: Thẻ tóm tắt thông tin mốc đang chọn trên bản đồ ca.
  - `shift_point_selector_sheet.dart`: Bảng chọn khách hàng đưa vào ca từ danh bạ.
  - `shift_prep_filter_bar.dart`: Thanh lọc điểm giao theo khu vực trong khâu chuẩn bị ca.

