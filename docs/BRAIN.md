# BRAIN: Delivery Location Marker System (Bản nộp App-Only)

> **Tài liệu tóm lược kiến trúc, quy tắc nghiệp vụ và quy ước vận hành dành cho Developer & AI Agent.**

---

## 1. Mục Tiêu Ứng Dụng
Ứng dụng di động Flutter/Android (Local-First) hỗ trợ shipper ghim chính xác vị trí cổng nhà khách hàng theo số điện thoại, kèm ảnh thực tế và ghi chú dẫn đường. Ứng dụng chạy hoàn toàn độc lập, lưu trữ dữ liệu cục bộ trong SQLite, không cần tài khoản, không cần máy chủ backend.

---

## 2. Kiến Trúc Mã Nguồn (`mobile_app/lib/`)
- `main.dart`: Điểm khởi chạy ứng dụng Flutter.
- `app/`: Khung ứng dụng chính (`app.dart`), điều hướng 4 tab (`home_shell_view.dart`), màn khởi động (`auth_splash_view.dart`), và chủ đề (`theme/app_theme.dart`, `theme/app_buttons.dart`).
- `core/`: Nền tảng dùng chung không phụ thuộc nghiệp vụ:
  - `services/`: Dịch vụ bản đồ (`map_navigation_service.dart`, `map_tile_cache_service.dart`).
  - `utils/`: Tiện ích SĐT, mã hóa một chiều PIN, mã hóa AES-GCM gói chia sẻ, chuỗi tiếng Việt.
  - `widgets/`: Các widget dùng chung (`point_detail_bottom_sheet`, `quick_add_customer_sheet`, `bulk_paste_phone_sheet`, `authenticated_image`).
- `data/`: Tầng dữ liệu phân chia theo từng miền nghiệp vụ (Domain-Driven):
  - `repository_provider.dart`: Cung cấp Singleton các repository truy cập toàn cục.
  - `database/`: Quản lý SQLite WAL (`app_database.dart`), schema DDL và database migrations.
  - `customers/`, `locations/`, `shifts/`, `photos/`, `backup/`, `sharing/`, `profile/`: Mỗi miền một repository và câu truy vấn tương ứng.
- `features/`: Các module tính năng giao diện độc lập (`map`, `directory`, `shifts`, `photos`, `profile`, `sharing`, `onboarding_lock`).
- `models/`: Các lớp mô hình dữ liệu (Customer, Location, Shift, Photo, LocalShare, UserProfile).






---

## 3. Các Quy Tắc Nghiệp Vụ Đã Chốt
1. **Vị trí đã xác nhận (`saved_locations`):** Là tọa độ cổng nhà chính thức gắn với khách hàng (`customers`).
2. **Ghim tạm:** Chỉ tồn tại trong các điểm giao của ca làm việc (`shift_items`), không tự ý ghi đè vào `saved_locations` trừ khi shipper chủ động xác nhận.
3. **Toàn vẹn quan hệ ca - khách:** Xóa ca làm việc (`shifts`) không xóa khách hàng hoặc vị trí đã lưu.
4. **Bảo toàn lịch sử:** Xóa vị trí chỉ đổi trạng thái / ghi nhận vào `location_history` và `activity_logs`.
5. **Hệ tọa độ:** Bản Local lưu tọa độ `REAL` (vĩ độ `latitude`, kinh độ `longitude`) trong SQLite theo chuẩn WGS 84. Ghi chú PostGIS `ST_SetSRID(ST_MakePoint(lng,lat),4326)` chỉ dành cho bản máy chủ (tag `v1.0-full`).
6. **Bảo mật & Bí mật:** Tuyệt đối không hardcode mật khẩu, PIN, API key. Không ghi SĐT hay thông tin khách hàng vào log.
7. **Lưu trữ ảnh:** Ảnh chụp lưu trong thư mục riêng của app (`app_photos/`), tự động nén cạnh dài tối đa 1600px, dọn dẹp ảnh rác quá 30 ngày.
8. **Khóa PIN:** Tùy chọn khóa ứng dụng bằng PIN (4-6 số). Băm bằng PBKDF2/SHA-256 kèm salt ngẫu nhiên chạy trong Isolate, không lưu PIN thô.
9. **Sao lưu & Phục hồi:** Xuất gói ZIP chứa `manifest.json`, `database.sqlite` và thư mục ảnh; hỗ trợ đặt mật khẩu mã hóa AES-GCM.
10. **Chia sẻ dữ liệu:** Xuất file `.dshare` (zip) hoặc mã QR (gói nhỏ không kèm ảnh). Dữ liệu đã gửi trực tiếp giữa 2 máy là **KHÔNG THỂ THU HỒI**.

---

## 4. Lệnh Thao Tác Chuẩn (CLI Commands)
Mọi lệnh thực thi tại thư mục `mobile_app/`:
- **Cài đặt thư viện:** `flutter pub get`
- **Chạy ứng dụng debug:** `flutter run`
- **Chạy toàn bộ automated tests:** `flutter test`
- **Kiểm tra cú pháp & static analysis:** `flutter analyze`
- **Đóng gói file cài đặt APK Release:** `flutter build apk --release`

---

## 5. Quy Ước Phối Hợp Của AI Agent
1. **Evidence-Based (Bằng chứng thực tế):** Báo cáo kết quả bằng output lệnh thật; không suy đoán.
2. **Phân định trạng thái rõ ràng:**
   - `[ĐÃ CODE]`: Code đã tồn tại nhưng chưa có test tự động bao phủ.
   - `[ĐÃ TEST]`: Đã vượt qua automated unit/widget test.
   - `[LỖI/CHƯA GẮN]`: Mã nguồn có vấn đề logic hoặc bị tách rời luồng chính.
   - `[CHƯA TRIỂN KHAI]`: Chưa có mã nguồn hoặc giao diện.
   - `[CHƯA THỬ TRÊN ĐIỆN THOẠI THẬT]`: Đã test trên máy ảo/unit test nhưng cần kiểm chứng cảm ứng, camera, GPS, intent trên thiết bị phần cứng thật.
3. **An toàn bản nộp:** Không sửa đổi logic ứng dụng trong `mobile_app`. Mọi thay đổi tài liệu phải đồng bộ.

