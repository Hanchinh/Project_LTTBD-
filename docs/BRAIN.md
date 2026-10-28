# BRAIN: Delivery Location Marker System (Bản nộp App-Only)

> **Tài liệu tóm lược kiến trúc, quy tắc nghiệp vụ và quy ước vận hành dành cho Developer & AI Agent.**

---

## 1. Mục Tiêu Ứng Dụng
Ứng dụng di động Flutter/Android (Local-First) hỗ trợ shipper ghim chính xác vị trí cổng nhà khách hàng theo số điện thoại, kèm ảnh thực tế và ghi chú dẫn đường. Ứng dụng chạy hoàn toàn độc lập, lưu trữ dữ liệu cục bộ trong SQLite, không cần tài khoản, không cần máy chủ backend.

---

## 2. Kiến Trúc Mã Nguồn (`mobile_app/lib/`)
- `core/`: Hằng số (`app_constants.dart`), cấu hình tile bản đồ (`map_config.dart`), tiện ích chuẩn hóa SĐT, tính khoảng cách, xử lý lỗi.
- `data/local/`: Cơ sở dữ liệu SQLite (`app_database.dart`), bộ quản lý migration, và các Local Repositories (`customer`, `location`, `shift`, `photo`, `profile`, `sharing`).
- `data/remote/`: API client và Remote Repositories lưu trữ dự phòng (phục vụ bản máy chủ tại tag `v1.0-full`).
- `features/`: Các module tính năng độc lập (main_map, shifts, customers, photos, profile, sharing, server_mode).
- `shared_widgets/`: Các widget dùng chung (bản đồ, thanh tìm kiếm, bottom sheet, ảnh đại diện).

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

