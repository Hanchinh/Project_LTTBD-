# Shared Widgets

Thư viện các widget dùng chung giữa các phân hệ:

- **`quick_add_customer_sheet.dart`**: Bảng thêm nhanh khách hàng mới và mốc tọa độ, được gọi từ bản đồ chính, danh bạ và ca giao hàng.
  - `quick_add/quick_add_area_selector.dart`: Bộ chọn khu vực phụ trách.
  - `quick_add/quick_add_optional_fields.dart`: Các trường nhập liệu bổ sung (địa chỉ, ghi chú).
- **`point_detail_bottom_sheet.dart`**: Bảng xem chi tiết mốc tọa độ khi bấm vào marker trên bản đồ.
  - `point_detail/point_detail_action_buttons.dart`: Cụm nút hành động nhanh (gọi điện thoại, chỉ đường ngoại vi, sao chép).
- **`bulk_paste_phone_sheet.dart`**: Bộ trích xuất và phân tích hàng loạt số điện thoại từ văn bản tự do:
  - `bulk_paste/bulk_paste_input_view.dart`: Ô nhập và dán văn bản thô.
  - `bulk_paste/bulk_paste_section_header.dart`: Thanh phân loại và đếm số lượng SĐT trích xuất được.
  - `bulk_paste/bulk_paste_directory_result_view.dart`: Danh sách kết quả phân tích trong màn hình danh bạ.
  - `bulk_paste/bulk_paste_shift_result_view.dart`: Danh sách kết quả phân tích trong màn hình chuẩn bị ca.
- **`authenticated_image.dart`**: Widget hiển thị hình ảnh hỗ trợ cả file trên bộ nhớ máy (chế độ local) và URL mạng có kèm header xác thực (chế độ máy chủ).

