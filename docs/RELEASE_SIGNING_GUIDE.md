# Hướng Dẫn Ký Khóa Bản Phát Hành (Release Keystore Signing Guide)

> **Tài liệu hướng dẫn kỹ sư/người quản trị tạo chứng chỉ số Keystore bảo mật và đóng gói APK release đã ký số cho ứng dụng Ghim Điểm Giao Hàng.**
> **Quy tắc bảo mật bắt buộc:** Keystore (`*.jks`) và tệp `key.properties` chứa mật khẩu bí mật. **TUYỆT ĐỐI KHÔNG commit vào Git repo hoặc chia sẻ công khai.**

---

## 1. Bước 1: Tạo Khóa Ký Số Phát Hành (Keystore)

Sử dụng công cụ `keytool` (có sẵn trong JDK hoặc Android Studio JBR) trên máy tính cá nhân của bạn:

### Trên Windows (PowerShell / Command Prompt):
```powershell
keytool -genkey -v -keystore D:\keystores\delivery_marker_upload.jks -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 -alias delivery_marker_release
```

### Trên macOS / Linux (Terminal):
```bash
keytool -genkey -v -keystore ~/keystores/delivery_marker_upload.jks -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 -alias delivery_marker_release
```

**Các thông số cần lưu ý:**
- Nhập mật khẩu Keystore mạnh (ví dụ: tối thiểu 12 ký tự gồm chữ hoa, chữ thường, số và ký tự đặc biệt).
- Ghi nhớ chính xác:
  - Đường dẫn tệp keystore: ví dụ `D:\keystores\delivery_marker_upload.jks`
  - Alias: `delivery_marker_release`
  - Mật khẩu Keystore (`storePassword`)
  - Mật khẩu Alias (`keyPassword`)
- **Lưu ý:** Hãy sao lưu tệp `delivery_marker_upload.jks` và mật khẩu vào một nơi an toàn (như 1Password, Bitwarden hoặc ổ cứng gắn ngoài). Nếu mất keystore này, bạn sẽ **không thể cập nhật** ứng dụng trên Google Play Store trong tương lai.

---

## 2. Bước 2: Cấu Hình Tệp `key.properties`

1. Trong thư mục `mobile_app/android/`, sao chép tệp `key.properties.example` thành `key.properties`:
   ```powershell
   cd mobile_app\android
   Copy-Item key.properties.example key.properties
   ```
2. Mở tệp `mobile_app/android/key.properties` và điền thông tin thực tế:
   ```properties
   storePassword=mat_khau_keystore_cua_ban
   keyPassword=mat_khau_alias_cua_ban
   keyAlias=delivery_marker_release
   storeFile=D:\\keystores\\delivery_marker_upload.jks
   ```
   *(Lưu ý trên Windows: dùng 2 dấu gạch chéo ngược `\\` trong đường dẫn storeFile).*

> [!NOTE]
> Tệp `key.properties` và `*.jks` đã được thêm vào `.gitignore` để ngăn chặn vô tình commit lên Git.
> Ngoài ra, hệ thống hỗ trợ đọc từ Biến môi trường hệ thống (Environment Variables):
> `KEYSTORE_PATH`, `STORE_PASSWORD`, `KEY_ALIAS`, `KEY_PASSWORD`.

---

## 3. Bước 3: Đóng Gói APK Bản Phát Hành Đã Ký (Build Signed APK)

Từ thư mục `mobile_app/`, chạy lệnh:
```bash
flutter build apk --release
```

Hệ thống Gradle sẽ:
1. Đọc thông tin từ `mobile_app/android/key.properties`.
2. Kích hoạt trình tối ưu hóa R8 và ProGuard (`isMinifyEnabled = true`, `isShrinkResources = true`).
3. Loại bỏ mã nguồn thừa, thu nhỏ dung lượng asset và icon.
4. Ký số APK bằng release keystore được chỉ định.

Tệp APK đầu ra sẽ nằm tại:
`mobile_app/build/app/outputs/flutter-apk/app-release.apk`

---

## 4. Bước 4: Kiểm Tra Chữ Ký APK (Verify Signing)

Bạn có thể kiểm tra APK đã được ký đúng chữ ký phát hành bằng `apksigner`:
```powershell
apksigner verify --verbose mobile_app\build\app\outputs\flutter-apk\app-release.apk
```
Kết quả hiển thị:
- `Verified using v1 scheme (JAR signing): true`
- `Verified using v2 scheme (APK Signature Scheme v2): true`
- `Signer #1 certificate DN: ...`

---

## 5. Bước 5: Đóng Gói Bản App Bundle (Nếu Phát Hành Google Play Store)

Nếu chuẩn bị đưa lên Google Play Console, chạy lệnh:
```bash
flutter build appbundle --release
```
Tệp AAB đầu ra sẽ nằm tại:
`mobile_app/build/app/outputs/bundle/release/app-release.aab`
Google Play sẽ tự động phân tách và tối ưu APK cho từng dòng máy Android của shipper, giúp giảm dung lượng tải xuống còn khoảng 15-20 MB.

