# Feature: Map

Phân hệ bản đồ chính và ghim mốc vị trí:

- **Views**:
  - `main_map_view.dart`: Màn hình bản đồ trung tâm hiển thị các mốc giao hàng đã lưu, gom cụm marker thông minh, hỗ trợ chế độ ghim nhanh và kiểm soát lệch khu vực hoạt động.
  - `crosshair_location_picker_view.dart`: Màn hình chọn vị trí chính xác bằng tâm ngắm cố định kèm tích hợp tìm kiếm địa chỉ geocoding.
- **Widgets (`widgets/`)**:
  - `assign_phone_dialog.dart`: Hộp thoại gán số điện thoại nhanh khi ghim mốc trực tiếp.
  - `control_column.dart`: Cột nút bấm điều khiển bản đồ (vị trí hiện tại, lớp bản đồ, la bàn).
  - `crosshair_bottom_panel.dart` & `crosshair_map_controls.dart` & `crosshair_search_panel.dart` & `fixed_crosshair_target.dart`: Các thành phần con phục vụ màn hình tâm ngắm.
  - `main_map_top_bar.dart`: Thanh tìm kiếm và bộ lọc trên bản đồ.
  - `map_legend.dart`: Bảng chú giải trạng thái màu sắc mốc giao hàng.
  - `map_markers_builder.dart`: Bộ dựng Marker hiển thị trên bản đồ.
  - `marker_cluster_helper.dart`: Thuật toán gom cụm điểm giao theo tọa độ và mức zoom.
  - `out_of_area_banner.dart`: Banner cảnh báo khi tọa độ nằm ngoài khu vực đăng ký.
  - `pin_mode_overlay.dart`: Giao diện hướng dẫn tương tác trong chế độ ghim mốc.
  - `saved_location_detail_card.dart`: Thẻ tóm tắt thông tin mốc khi bấm chọn.
  - `save_location_processor.dart`: Xử lý lưu mốc vào cơ sở dữ liệu.
  - `shared_point_detail_sheet.dart`: Thẻ chi tiết khi chọn mốc được người khác chia sẻ.

