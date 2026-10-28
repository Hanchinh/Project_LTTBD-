# Ghim Điểm Giao Hàng (Delivery Location Marker)

> **Ứng dụng di động hỗ trợ nhân viên giao hàng (Shipper) ghim chính xác vị trí cổng nhà khách hàng theo số điện thoại, lưu kèm hình ảnh thực tế và ghi chú dẫn đường, hoạt động hoàn toàn cục bộ (Local-First) trên thiết bị.**

---

## 📌 Giới Thiệu Chung
Trong thực tế giao hàng tại Việt Nam, địa chỉ trên bưu phẩm thường phức tạp (số nhà trùng, hẻm ngoằn ngoèo, khu đô thị mới chưa cập nhật số nhà). **Ghim Điểm Giao Hàng** giải quyết vấn đề này bằng cách giúp shipper ghi nhớ chính xác tọa độ cổng nhà gắn với số điện thoại của khách hàng ngay sau lần giao đầu tiên.

Ứng dụng hoạt động theo triết lý **Local-First**: toàn bộ dữ liệu khách hàng, tọa độ ghim, ảnh chụp và ca giao hàng được lưu trữ an toàn trong máy người dùng (SQLite). Ứng dụng không yêu cầu đăng nhập tài khoản, không cần kết nối máy chủ trung tâm và hoạt động mượt mà ngay cả khi mất mạng.

---

## ✨ Tính Năng Nổi Bật

- 🗺️ **Bản đồ trực quan & Gom cụm (Clustering):** Hiển thị toàn bộ điểm giao trên nền bản đồ với tính năng gom cụm thông minh, giúp bản đồ mượt mà ngay cả khi có hàng nghìn điểm.
- 🎯 **Ghim tâm chữ thập (Crosshair Pinning):** Cho phép kéo bản đồ và định vị chính xác vị trí cổng nhà với độ phóng to cao, bổ sung bán kính sai số GPS.
- 📒 **Danh bạ khách hàng thông minh:** Tìm kiếm khách hàng theo tên hoặc số điện thoại với thuật toán tìm kiếm tiếng Việt không dấu. Hỗ trợ tính năng dán nhanh danh sách hàng loạt SĐT từ tin nhắn / ứng dụng giao hàng.
- 📦 **Quản lý ca giao hàng (Delivery Shifts):** Tạo ca giao hàng, gom các điểm cần giao, tự động phát hiện khách quen đã có tọa độ và sắp xếp lộ trình thuận tiện.
- 📸 **Hình ảnh cổng nhà thực tế:** Chụp và đính kèm nhiều ảnh cổng nhà/đặc điểm nhận diện, tự động nén kích thước tối đa 1600px để tiết kiệm dung lượng bộ nhớ.
- 🔒 **Khóa bảo vệ bằng mã PIN:** Tùy chọn đặt mã PIN (4–6 chữ số) bảo vệ ứng dụng, tự động khóa khi rời ứng dụng. Mã PIN được băm một chiều an toàn bằng PBKDF2/SHA-256 kèm chuỗi muối (salt).
- 💾 **Sao lưu & Khôi phục (Backup & Restore):** Đóng gói toàn bộ cơ sở dữ liệu và hình ảnh thành file nén `.zip`, hỗ trợ mã hóa bảo vệ bằng mật khẩu (AES-GCM).
- 🔄 **Chia sẻ ngoại tuyến (.dshare & QR Code):** Chia sẻ các điểm giao hàng cho đồng nghiệp thông qua file gói `.dshare` hoặc quét mã QR trực tiếp giữa 2 thiết bị mà không cần máy chủ trung gian.

---

## 🛠️ Công Nghệ Sử Dụng

- **Framework:** Flutter / Dart (SDK `>=3.0.0 <4.0.0`)
- **Cơ sở dữ liệu cục bộ:** SQLite thông qua thư viện `sqflite` (hỗ trợ migration phiên bản schema và WAL mode)
- **Bản đồ & Không gian:** `flutter_map`, `latlong2`, `flutter_map_marker_cluster`, `geolocator`
- **Xử lý hình ảnh:** `image_picker`, `image` (nén ảnh đa luồng)
- **Bảo mật & Mã hóa:** `crypto` (PBKDF2, SHA-256), `encrypt` (AES-GCM)
- **Sao lưu & Chia sẻ:** `archive` (xử lý file zip), `share_plus`, `file_picker`, `mobile_scanner`, `qr_flutter`

---

## 📂 Cấu Trúc Mã Nguồn (`mobile_app/lib/`)

```text
mobile_app/lib/
├── core/                  # Tiện ích dùng chung, hằng số, cấu hình bản đồ, chuẩn hóa dữ liệu
├── data/
│   ├── local/             # SQLite database (app_database.dart), migrations, Local Repositories
│   └── remote/            # API client dự phòng (cho phiên bản máy chủ tại tag v1.0-full)
├── features/              # Các phân hệ tính năng độc lập
│   ├── main_map/          # Bản đồ chính, hiển thị marker, cụm ghim, lọc điểm
│   ├── shifts/            # Quản lý ca giao hàng, chuẩn bị ca, bản đồ ca
│   ├── customers/         # Danh bạ khách hàng, chi tiết khách, dán SĐT hàng loạt
│   ├── photos/            # Quản lý ảnh cổng nhà, thư viện ảnh, xem ảnh phóng to
│   ├── profile/           # Thông tin cá nhân, cài đặt khóa PIN, sao lưu & khôi phục dữ liệu
│   ├── sharing/           # Xuất/nhập file .dshare, quét & tạo mã QR chia sẻ
│   └── server_mode/       # Giao diện kết nối máy chủ (dành cho bản máy chủ)
├── models/                # Data models (Customer, Location, Shift, ShiftItem, Photo, ...)
├── shared_widgets/        # Các widget tái sử dụng (CrosshairPicker, SearchBar, Sheets, ...)
└── main.dart              # Khởi tạo ứng dụng Local-First
```

---

## 🚀 Hướng Dẫn Cài Đặt & Chạy Ứng Dụng

Yêu cầu môi trường: **Flutter SDK >= 3.0.0** và **Android Studio / Android SDK**.

### 1. Cài đặt các thư viện phụ thuộc
```bash
cd mobile_app
flutter pub get
```

### 2. Kiểm tra chất lượng mã nguồn (Static Analysis)
```bash
flutter analyze
```
*(Yêu cầu kết quả: `No issues found!`)*

### 3. Chạy toàn bộ Unit & Widget Tests
```bash
flutter test
```
*(Dự án đi kèm bộ hơn 230 bài kiểm thử tự động kiểm tra toàn diện database, repository, logic băm PIN, mã hóa sao lưu và giao diện).*

### 4. Chạy ứng dụng trên thiết bị / Máy ảo (Debug Mode)
```bash
flutter run
```

### 5. Đóng gói ứng dụng thành file APK Release
```bash
flutter build apk --release
```
File APK thành phẩm sẽ nằm tại: `mobile_app/build/app/outputs/flutter-apk/app-release.apk`.  
*(Chi tiết về cấu hình ký số bảo mật được trình bày tại [docs/ANDROID_RELEASE_SIGNING.md](docs/ANDROID_RELEASE_SIGNING.md)).*

---

## 🏷️ Các Phiên Bản Của Dự Án

Dự án được xây dựng với 2 kiến trúc phục vụ cho các mục đích triển khai khác nhau:

1. **Bản Nộp Độc Lập - Local-First (Nhánh `submit-app-only` - Hiện tại):**
   - Ứng dụng Flutter độc lập, không backend, không tài khoản máy chủ.
   - Toàn bộ dữ liệu nằm trên điện thoại của shipper, ưu tiên quyền riêng tư và tốc độ xử lý tức thời khi mất mạng.
2. **Bản Đầy Đủ Có Máy Chủ (Tag `v1.0-full`):**
   - Hệ thống Client-Server hoàn chỉnh gồm: Backend API (Node.js/Express + TypeScript), CSDL không gian (PostgreSQL + PostGIS 3.4), Web Admin Quản trị (React + Vite + Tailwind CSS) và Flutter Mobile App có cơ chế đồng bộ trực tuyến.
   - Để xem hoặc chạy bản đầy đủ có máy chủ, sử dụng lệnh:
     ```bash
     git checkout v1.0-full
     ```

---

## ⚠️ Giới Hạn Đã Biết (Known Limitations)

- **Nguồn Tile Bản Đồ:** Mặc định đang sử dụng nguồn tile thử nghiệm từ Google/OSM. Khi phát hành thương mại cần chuyển sang nhà cung cấp có API key chính thức (tham khảo chi tiết tại [docs/TILE_PROVIDERS.md](docs/TILE_PROVIDERS.md)).
- **Tìm kiếm địa chỉ:** Tính năng tìm kiếm địa chỉ dạng chuỗi văn bản sử dụng dịch vụ OpenStreetMap Nominatim, do đó yêu cầu kết nối mạng Internet. Tuy nhiên, các điểm và khách hàng đã lưu trong máy luôn tìm kiếm được hoàn toàn offline.
- **Tính bất biến của gói chia sẻ:** Điểm giao đã chia sẻ qua file `.dshare` hoặc mã QR là chia sẻ trực tiếp điểm-điểm (P2P), không thể thu hồi từ xa sau khi người nhận đã nhập vào máy.
- **Bảo toàn dữ liệu:** Do dữ liệu lưu cục bộ trên máy, người dùng cần chủ động sử dụng tính năng **Sao lưu dữ liệu** ra file ZIP để bảo vệ dữ liệu khi đổi thiết bị.
- **Nền tảng:** Hiện tại ứng dụng được tối ưu và kiểm thử cho hệ điều hành **Android**. Phiên bản iOS chưa được đóng gói chính thức.
- **Dịch vụ đám mây:** Phiên bản Local-First độc lập này không tích hợp dịch vụ Firebase hoặc đồng bộ đám mây bên thứ ba.
