# Báo Cáo & Đề Xuất Nhà Cung Cấp Mảnh Bản Đồ (Tile Providers)

> **Tài liệu phân tích các nhà cung cấp Tile bản đồ trực tuyến cho ứng dụng Ghim Điểm Giao Hàng (Delivery Marker Mobile).**
> **Mục tiêu:** Đảm bảo tính hợp pháp về bản quyền, điều khoản dịch vụ (Terms of Service - ToS) khi phát hành ứng dụng ra thị trường, tránh vi phạm ToS của Google Maps Tile scraping (`mt1.google.com`).

---

## 1. Hiện Trạng & Rủi Ro Bản Quyền

- **Nguồn hiện tại:** `https://mt1.google.com/vt/lyrs=m&x={x}&y={y}&z={z}` (Google Maps Raster Tiles không chính thức).
- **Rủi ro:** Google cấm việc trích xuất (scraping) trực tiếp các mảnh tile raster từ subdomain `mt*.google.com` mà không thông qua Google Maps SDK / Maps Static API / Maps Tile API chính thức. Việc dùng trực tiếp trên bản phát hành có thể dẫn đến việc ứng dụng bị từ chối duyệt trên Google Play Store hoặc bị Google chặn IP máy chủ/người dùng.
- **Biện pháp xử lý kiến trúc:**
  - Toàn bộ URL cấu hình tile đã được gom tập trung vào [`lib/core/constants/map_config.dart`](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/core/constants/map_config.dart).
  - Giữ nguồn Google Tile làm **mặc định tạm thời** trong quá trình thử nghiệm nội bộ, sẵn sàng chuyển đổi nguồn chính thức bằng 1 dòng cấu hình duy nhất khi có quyết định.

---

## 2. Phân Tích & Đề Xuất 3 Nhà Cung Cấp Mảnh Bản Đồ Thay Thế

| Tiêu chí | 1. OpenStreetMap (OSM) Standard | 2. CARTO Basemaps (Voyager / Positron) | 3. Stadia Maps / MapTiler |
| :--- | :--- | :--- | :--- |
| **URL Tile** | `https://tile.openstreetmap.org/{z}/{x}/{y}.png` | `https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png` | `https://tiles.stadiamaps.com/tiles/osm_bright/{z}/{x}/{y}.png?api_key=...` |
| **Giấy phép (License)** | Open Database License (ODbL), CC-BY-SA 2.0 | Tự do phi thương mại / Giấy phép thoáng theo OSM | Thương mại có gói miễn phí chuẩn SLA |
| **Yêu cầu API Key** | **Không cần API key** | **Không bắt buộc** cho gói cơ bản / URL công khai | **Bắt buộc API Key** (Đăng ký tài khoản miễn phí) |
| **Hạn mức miễn phí (Free Tier)** | Tuân thủ chính sách sử dụng hợp lý (Tile Usage Policy): không cào dữ liệu hàng loạt | Hào phóng cho ứng dụng nhẹ, không thu phí đối với lưu lượng phát triển | **200,000 requests/tháng** (Stadia) / **100,000 requests/tháng** (MapTiler) |
| **Chuỗi ghi nguồn (Attribution)** | `© OpenStreetMap contributors` | `© OpenStreetMap contributors, © CARTO` | `© Stadia Maps, © OpenStreetMap contributors` |
| **Ưu điểm** | - Hoàn toàn miễn phí, mã nguồn mở.<br>- Không cần tài khoản hoặc thẻ tín dụng.<br>- Dữ liệu đường phố Việt Nam rất chi tiết nhờ cộng đồng OSM VN. | - Thiết kế giao diện cực đẹp, chữ số và tên đường rõ ràng, tương phản tốt cho shipper.<br>- CDN toàn cầu nhanh, ổn định.<br>- Hiện đã được tích hợp làm lớp dự phòng (fallback) trong app. | - Hạ tầng máy chủ CDN chuyên nghiệp, tốc độ tải tile cực cao.<br>- Hỗ trợ cả lớp ảnh vệ tinh độ phân giải cao và bản đồ vector.<br>- Có bảng quản trị lưu lượng rõ ràng. |
| **Nhược điểm** | - Không có cam kết chất lượng dịch vụ (SLA).<br>- Tại Việt Nam đôi khi mạng một số nhà mạng bị chập chờn khi kết nối trực tiếp đến cụm máy chủ OSM châu Âu.<br>- Không có lớp ảnh vệ tinh. | - Gói miễn phí không công bố SLA chính thức.<br>- Không có lớp ảnh vệ tinh hybrid. | - Cần tạo tài khoản và quản lý API key bảo mật.<br>- Vượt hạn mức 200k lượt/tháng sẽ tính phí. |

---

## 3. Kiến Nghị Lựa Chọn

1. **Khuyến nghị giai đoạn đầu (v1.0.0 phát hành Google Play):**
   - Sử dụng **CARTO Basemaps (Voyager)** làm nguồn bản đồ đường phố chính thức.
   - Thêm dòng ghi nguồn rõ ràng tại màn hình **Cá nhân**: `Dữ liệu bản đồ: © OpenStreetMap contributors, © CARTO`.
2. **Khuyến nghị khi mở rộng quy mô (> 500 shipper hoạt động đồng thời):**
   - Đăng ký tài khoản doanh nghiệp **Stadia Maps** hoặc **MapTiler** để có API key riêng, kiểm soát băng thông và bổ sung ảnh vệ tinh độ nét cao.

---

## 4. Điểm Ghi Nhận Bản Quyền Trong Ứng Dụng (Attribution)

- **Vị trí hiển thị:** Tab "Cá nhân" -> Mục "Về ứng dụng & Bản quyền" -> Dòng ghi công:
  `Nguồn bản đồ: Google Maps (Mặc định) / CARTO / OpenStreetMap contributors`
- **Mã nguồn:** [`lib/core/constants/map_config.dart`](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/core/constants/map_config.dart)

