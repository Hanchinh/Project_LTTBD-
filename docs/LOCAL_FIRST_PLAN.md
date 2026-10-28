# Kế Hoạch Chuyển Đổi Mô Hình Dữ Liệu Local-First (Local-First Transition Plan)

> **Dự án:** Delivery Location Marker System (`mobile_app`)  
> **Mục tiêu:** Chuyển đổi ứng dụng từ mô hình Client-Server tập trung sang mô hình **Local-First** (mỗi người dùng tự quản lý dữ liệu trực tiếp trên thiết bị, hoạt động độc lập không phụ thuộc kết nối mạng hay bắt buộc đăng nhập tài khoản/quản trị).  
> **Nguyên tắc bảo toàn:** Giữ nguyên toàn bộ mã nguồn Backend (`backend/`) và Admin Web (`admin_web/`) trong kho lưu trữ để sẵn sàng kết nối lại hoặc đồng bộ P2P/Cloud trong tương lai.  
> **Quy chuẩn thực thi:** Tuân thủ [AGENTS.md](file:///d:/flutter%20create%20delivery_marker_app/AGENTS.md), không làm thay đổi giao diện, luồng nghiệp vụ hoặc mô hình dữ liệu hiện tại khi tách lớp.

---

## 1. Khảo Sát Hiện Trạng Gọi Dữ Liệu (`ApiService` Call Mapping)

Tổng số vị trí gọi `ApiService` trong `mobile_app/lib`: **101 vị trí**.

| Màn Hình / Widget | Hàm `ApiService` Đang Dùng | Nhóm Chức Năng | Phân Loại Xử Lý |
| :--- | :--- | :--- | :--- |
| [main.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/main.dart) | `getToken()` | Khác (Khởi tạo phiên) | Còn dùng `ApiService` trực tiếp |
| [login_view.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/views/login_view.dart) | `getSavedLoginPhone()` | Tài khoản / Đăng nhập | `ProfileRepository` |
| [login_view.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/views/login_view.dart) | `login()` | Tài khoản / Đăng nhập | `ProfileRepository` |
| [login_view.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/views/login_view.dart) | `getBaseUrl()`, `resetCustomBaseUrl()`, `setCustomBaseUrl()` | Cấu hình máy chủ | Còn dùng `ApiService` trực tiếp |
| [account_profile_view.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/views/account_profile_view.dart) | `getCurrentUser()` | Tài khoản / Hồ sơ | `ProfileRepository` |
| [account_profile_view.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/views/account_profile_view.dart) | `getMyAreas()` | Tài khoản / Khu vực | `ProfileRepository` |
| [account_profile_view.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/views/account_profile_view.dart) | `getMyStats()` | Tài khoản / Thống kê | `ProfileRepository` |
| [account_profile_view.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/views/account_profile_view.dart) | `logout()` | Tài khoản / Đăng nhập | `ProfileRepository` |
| [account_profile_view.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/views/account_profile_view.dart) | `getBaseUrl()`, `resetCustomBaseUrl()`, `setCustomBaseUrl()` | Cấu hình máy chủ | Còn dùng `ApiService` trực tiếp |
| [change_password_view.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/views/change_password_view.dart) | `changePassword()` | Tài khoản / Đổi mật khẩu | `ProfileRepository` |
| [customer_directory_view.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/views/customer_directory_view.dart) | `getCustomersResponse()` | Khách hàng (Danh bạ phân trang) | `CustomerRepository` |
| [customer_directory_view.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/views/customer_directory_view.dart) | `getCustomerDetail()` | Khách hàng (Chi tiết hồ sơ) | `CustomerRepository` |
| [customer_directory_view.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/views/customer_directory_view.dart) | `updateCustomer()` | Khách hàng (Cập nhật thông tin) | `CustomerRepository` |
| [customer_directory_view.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/views/customer_directory_view.dart) | `getShifts()`, `getShiftDetail()` | Ca làm việc | `ShiftRepository` |
| [customer_directory_view.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/views/customer_directory_view.dart) | `addPointToShift()`, `removePointFromShift()` | Điểm trong ca | `ShiftRepository` |
| [customer_directory_view.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/views/customer_directory_view.dart) | `deleteCustomerLocation()` | Vị trí (Xóa vị trí) | `LocationRepository` |
| [customer_directory_view.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/views/customer_directory_view.dart) | `updateCustomerLocationAndPhoto()` | Vị trí (Lưu tọa độ & ghi chú) | `LocationRepository` |
| [data_sharing_view.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/views/data_sharing_view.dart) | `getOutgoingShares()`, `getIncomingShares()` | Chia sẻ dữ liệu | `SharingRepository` |
| [data_sharing_view.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/views/data_sharing_view.dart) | `getShifts()` | Ca làm việc (Chọn ca chia sẻ) | `ShiftRepository` |
| [data_sharing_view.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/views/data_sharing_view.dart) | `createShare()`, `revokeShare()`, `acceptShare()`, `declineShare()`, `importSharedLocations()` | Chia sẻ dữ liệu | `SharingRepository` |
| [shift_list_view.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/views/shift_list_view.dart) | `getShifts()`, `updateShiftName()`, `deleteShift()` | Ca làm việc | `ShiftRepository` |
| [shift_list_view.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/views/shift_list_view.dart) | `logout()` | Tài khoản / Đăng nhập | `ProfileRepository` |
| [shift_preparation_view.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/views/shift_preparation_view.dart) | `getShiftDetail()`, `updateShiftStatus()` | Ca làm việc | `ShiftRepository` |
| [shift_preparation_view.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/views/shift_preparation_view.dart) | `lookupCustomerLocationByPhone()` | Khách hàng (Tra cứu SĐT) | `CustomerRepository` |
| [shift_preparation_view.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/views/shift_preparation_view.dart) | `addPointToShift()`, `removePointFromShift()` | Điểm trong ca | `ShiftRepository` |
| [shift_map_view.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/views/shift_map_view.dart) | `getShiftDetail()` | Ca làm việc | `ShiftRepository` |
| [shift_map_view.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/views/shift_map_view.dart) | `openExternalNavigation()` | Tiện ích mở Google Maps | Còn dùng `ApiService` trực tiếp |
| [crosshair_location_picker_view.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/views/crosshair_location_picker_view.dart) | `searchAddress()` | Geocoding (OSM Nominatim) | Còn dùng `ApiService` trực tiếp |
| [crosshair_location_picker_view.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/views/crosshair_location_picker_view.dart) | `updateTemporaryLocation()` | Vị trí / Điểm trong ca | `LocationRepository` |
| [main_map_view.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/views/main_map_view.dart) | `getMySavedLocations()` | Vị trí (Tọa độ đã lưu) | `LocationRepository` |
| [main_map_view.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/views/main_map_view.dart) | `getCustomers()`, `createCustomer()`, `lookupCustomerLocationByPhone()` | Khách hàng | `CustomerRepository` |
| [main_map_view.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/views/main_map_view.dart) | `getSharedLocations()`, `importSharedLocations()` | Chia sẻ dữ liệu | `SharingRepository` |
| [main_map_view.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/views/main_map_view.dart) | `getPreferredAreaId()` | Tài khoản / Khu vực | `ProfileRepository` |
| [main_map_view.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/views/main_map_view.dart) | `updateCustomerLocationAndPhoto()` | Vị trí | `LocationRepository` |
| [main_map_view.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/views/main_map_view.dart) | `searchAddress()` | Geocoding | Còn dùng `ApiService` trực tiếp |
| [main_map_view.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/views/main_map_view.dart) | `openExternalNavigation()` | Tiện ích ngoài | Còn dùng `ApiService` trực tiếp |
| [save_location_view.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/views/save_location_view.dart) | `saveCustomerLocation()` | Vị trí | `LocationRepository` |
| [delivery_map_view.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/views/delivery_map_view.dart) *(Legacy)* | `getMyShiftOrders()`, `addOrderToShift()` | Ca làm việc / Đơn hàng | `ShiftRepository` |
| [delivery_map_view.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/views/delivery_map_view.dart) *(Legacy)* | `getPendingSyncCount()`, `syncOfflineQueue()` | Vị trí / Hàng đợi offline | `LocationRepository` |
| [delivery_map_view.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/views/delivery_map_view.dart) *(Legacy)* | `lookupCustomerLocationByPhone()` | Khách hàng | `CustomerRepository` |
| [delivery_map_view.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/views/delivery_map_view.dart) *(Legacy)* | `logout()` | Tài khoản / Đăng nhập | `ProfileRepository` |
| [delivery_map_view.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/views/delivery_map_view.dart) *(Legacy)* | `getPhotoAuthInfo()`, `openExternalNavigation()` | Ảnh / Tiện ích ngoài | `PhotoRepository` / `ApiService` |
| [order_list_view.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/views/order_list_view.dart) *(Legacy)* | `getMyShiftOrders()` | Ca làm việc / Đơn hàng | `ShiftRepository` |
| [order_list_view.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/views/order_list_view.dart) *(Legacy)* | `getPendingSyncCount()`, `syncOfflineQueue()` | Vị trí / Hàng đợi offline | `LocationRepository` |
| [order_list_view.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/views/order_list_view.dart) *(Legacy)* | `logout()` | Tài khoản / Đăng nhập | `ProfileRepository` |
| [order_detail_view.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/views/order_detail_view.dart) *(Legacy)* | `lookupCustomerLocationByPhone()` | Khách hàng | `CustomerRepository` |
| [order_detail_view.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/views/order_detail_view.dart) *(Legacy)* | `getPhotoAuthInfo()`, `openExternalNavigation()` | Ảnh / Tiện ích ngoài | `PhotoRepository` / `ApiService` |
| [bulk_paste_phone_sheet.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/widgets/bulk_paste_phone_sheet.dart) | `getMyAreas()` | Tài khoản / Khu vực | `ProfileRepository` |
| [bulk_paste_phone_sheet.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/widgets/bulk_paste_phone_sheet.dart) | `createBulkCustomers()` | Khách hàng (Dán hàng loạt) | `CustomerRepository` |
| [bulk_paste_phone_sheet.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/widgets/bulk_paste_phone_sheet.dart) | `getShifts()`, `addBulkPointsToShift()` | Ca làm việc (Dán vào ca) | `ShiftRepository` |
| [quick_add_customer_sheet.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/widgets/quick_add_customer_sheet.dart) | `getMyAreas()`, `getPreferredAreaId()`, `setPreferredAreaId()`, `clearPreferredAreaId()` | Tài khoản / Khu vực | `ProfileRepository` |
| [quick_add_customer_sheet.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/widgets/quick_add_customer_sheet.dart) | `createCustomer()` | Khách hàng (Tạo nhanh) | `CustomerRepository` |
| [create_shift_dialog.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/widgets/create_shift_dialog.dart) | `getShifts()`, `createShift()` | Ca làm việc | `ShiftRepository` |
| [shift_picker_bottom_sheet.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/widgets/shift_picker_bottom_sheet.dart) | `getShifts()`, `updateShiftName()`, `deleteShift()` | Ca làm việc | `ShiftRepository` |
| [customer_photos_strip_widget.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/widgets/customer_photos_strip_widget.dart) | `getCustomerPhotos()`, `addCustomerPhoto()`, `deleteCustomerPhoto()` | Ảnh khách hàng | `PhotoRepository` |
| [authenticated_image.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/widgets/authenticated_image.dart) | `getPhotoAuthInfo()` | Ảnh (Auth headers) | `PhotoRepository` |
| [fullscreen_image_viewer.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/widgets/fullscreen_image_viewer.dart) | `getPhotoAuthInfo()` | Ảnh (Auth headers) | `PhotoRepository` |
| [point_detail_bottom_sheet.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/widgets/point_detail_bottom_sheet.dart) | `openExternalNavigation()` | Tiện ích ngoài | Còn dùng `ApiService` trực tiếp |

---

## 2. Thiết Kế Các Nhóm Repository Trừu Tượng

Cấu trúc thư mục mới: `mobile_app/lib/repositories/`:
```
lib/repositories/
├── customer_repository.dart
├── location_repository.dart
├── photo_repository.dart
├── shift_repository.dart
├── sharing_repository.dart
├── profile_repository.dart
├── remote/
│   ├── remote_customer_repository.dart
│   ├── remote_location_repository.dart
│   ├── remote_photo_repository.dart
│   ├── remote_shift_repository.dart
│   ├── remote_sharing_repository.dart
│   └── remote_profile_repository.dart
└── repository_provider.dart
```

### 2.1. CustomerRepository
Quản lý dữ liệu danh bạ khách hàng, tìm kiếm, tra cứu SĐT và tạo hàng loạt:
- `getCustomers({String? areaId}) -> Future<List<CustomerDirectoryModel>>`
- `getCustomersResponse({int page, int limit, String? search, String? areaId, String? locationStatus}) -> Future<CustomerDirectoryResponse>`
- `getCustomerDetail(String customerId) -> Future<CustomerDirectoryModel>`
- `createCustomer({required String fullName, required String phoneNumber, String? addressText, String? areaId, double? latitude, double? longitude, String? identificationNotes, String? base64Photo}) -> Future<CustomerDirectoryModel>`
- `createBulkCustomers({required List<String> phoneNumbers, String? areaId}) -> Future<BulkCreateCustomerResult>`
- `updateCustomer({required String customerId, required String fullName, required String phoneNumber, String? addressText, String? areaId}) -> Future<void>`
- `lookupCustomerLocationByPhone(String phone) -> Future<CustomerLookupResult>`

### 2.2. LocationRepository
Quản lý tọa độ vị trí ghim cổng, điểm tạm, xác minh và đồng bộ offline:
- `getMySavedLocations() -> Future<List<LocationModel>>`
- `saveCustomerLocation({required String customerId, required double latitude, required double longitude, required String identificationNotes, String? base64Photo, double? gpsAccuracy}) -> Future<bool>`
- `updateCustomerLocationAndPhoto({required String customerId, required double latitude, required double longitude, required String identificationNotes, String? base64Photo}) -> Future<void>`
- `deleteCustomerLocation(String customerId) -> Future<void>`
- `updateTemporaryLocation({required String shiftId, required String pointId, required double latitude, required double longitude, String? notes}) -> Future<ShiftDeliveryPointModel>`
- `verifyPointLocation({required String shiftId, required String pointId, required double latitude, required double longitude, required double gpsAccuracy, required String identificationNotes, String? base64Photo}) -> Future<ShiftDeliveryPointModel>`
- `getPendingSyncCount() -> Future<int>`
- `syncOfflineQueue() -> Future<void>`

### 2.3. PhotoRepository
Quản lý tải, nén, lưu và xóa ảnh mặt tiền nhà:
- `getCustomerPhotos(String customerId) -> Future<List<CustomerPhotoModel>>`
- `addCustomerPhoto(String customerId, String base64Image) -> Future<CustomerPhotoModel>`
- `deleteCustomerPhoto(String customerId, String photoId) -> Future<void>`
- `getPhotoAuthInfo(String url) -> Future<Map<String, String>>`

### 2.4. ShiftRepository
Quản lý ca làm việc, thêm/xóa điểm giao trong ca, dán hàng loạt vào ca:
- `getShifts({String? status}) -> Future<List<ShiftModel>>`
- `createShift({String? shiftName}) -> Future<ShiftModel>`
- `getShiftDetail(String shiftId) -> Future<ShiftModel>`
- `updateShiftName(String shiftId, String shiftName) -> Future<ShiftModel>`
- `updateShiftStatus(String shiftId, String status) -> Future<ShiftModel>`
- `deleteShift(String shiftId) -> Future<void>`
- `addPointToShift({required String shiftId, required String customerPhone, String? customerName, String? customerAddress, double? latitude, double? longitude, String? locationNotes}) -> Future<AddShiftPointResult>`
- `addBulkPointsToShift({required String shiftId, required List<String> phoneNumbers, String? areaId}) -> Future<BulkAddPointsResult>`
- `removePointFromShift(String shiftId, String pointId) -> Future<void>`
- `getMyShiftOrders() -> Future<List<OrderModel>>`
- `addOrderToShift({required String customerId}) -> Future<Map<String, dynamic>>`

### 2.5. SharingRepository
Quản lý yêu cầu chia sẻ dữ liệu vị trí giữa các shipper:
- `getOutgoingShares() -> Future<List<DataShareModel>>`
- `getIncomingShares() -> Future<List<DataShareModel>>`
- `getSharedLocations() -> Future<List<SharedLocationItem>>`
- `createShare({required String recipientPhone, required String shareScope, String? shiftId, int? durationHours, String? notes}) -> Future<DataShareModel>`
- `acceptShare(String shareId) -> Future<DataShareModel>`
- `declineShare(String shareId) -> Future<DataShareModel>`
- `revokeShare(String shareId) -> Future<DataShareModel>`
- `importSharedLocations({required String shareId, List<String>? customerIds}) -> Future<ImportShareResult>`

### 2.6. ProfileRepository
Quản lý hồ sơ người dùng, phân quyền khu vực ưa thích và thông tin tài khoản:
- `login(String phone, String password) -> Future<UserModel>`
- `logout() -> Future<void>`
- `getCurrentUser() -> Future<UserModel?>`
- `getMyStats() -> Future<UserStatsModel>`
- `getMyAreas() -> Future<List<Map<String, dynamic>>>`
- `getPreferredAreaId() -> Future<String?>`
- `setPreferredAreaId(String areaId) -> Future<void>`
- `clearPreferredAreaId() -> Future<void>`
- `changePassword({required String currentPassword, required String newPassword}) -> Future<Map<String, dynamic>>`
- `getSavedLoginPhone() -> Future<String?>`

---

## 3. Quản Lý Phụ Thuộc (RepositoryProvider / ServiceLocator)

Tạo lớp `RepositoryProvider` đơn giản, không phụ thuộc thư viện nặng:
- Giữ instance singleton hoặc cho phép ghi đè (override) trong kiểm thử widget test (`RepositoryProvider.override(...)` hoặc `RepositoryProvider.reset()`).
- Mặc định: Trỏ về các `RemoteRepository` tương ứng bọc `ApiService`.
- Mở rộng tương lai: Thay thế bằng `LocalCustomerRepository`, `LocalLocationRepository`,... kết nối CSDL SQLite `OfflineStorageService` khi người dùng kích hoạt chế độ thuần Local-First.

---

## 4. Danh Sách Các Lời Gọi Còn Dùng `ApiService` Trực Tiếp

Các lời gọi sau đây không thuộc 6 nhóm nghiệp vụ quản lý dữ liệu đối tượng khách/vị trí/ca/chia sẻ/hồ sơ, mà là các tiện ích giao tiếp hạ tầng mạng / phần cứng hệ thống:
1. **Quản lý Token phiên hệ thống:**
   - `ApiService.getToken()` tại [main.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/main.dart).
2. **Cấu hình địa chỉ mạng nội bộ:**
   - `ApiService.getBaseUrl()`, `ApiService.setCustomBaseUrl()`, `ApiService.resetCustomBaseUrl()` tại [login_view.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/views/login_view.dart) và [account_profile_view.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/views/account_profile_view.dart).
3. **Geocoding tìm kiếm địa chỉ OpenStreetMap / Nominatim:**
   - `ApiService.searchAddress(query)` tại [crosshair_location_picker_view.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/views/crosshair_location_picker_view.dart) và [main_map_view.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/views/main_map_view.dart).
4. **Tiện ích mở ứng dụng dẫn đường ngoài (Google Maps):**
   - `ApiService.openExternalNavigation(lat, lng)` tại [point_detail_bottom_sheet.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/widgets/point_detail_bottom_sheet.dart), [shift_map_view.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/views/shift_map_view.dart), [main_map_view.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/views/main_map_view.dart), [delivery_map_view.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/views/delivery_map_view.dart), [order_detail_view.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/views/order_detail_view.dart).

---

## 5. Sơ Đồ Cơ Sở Dữ Liệu SQLite Cục Bộ (Local SQLite Schema - `local_data_v1.db`)

> **Quyết định kiến trúc (TASK: LOCAL-FIRST-02-SQLITE-SCHEMA):**
> - **Tách biệt hoàn toàn:** Tạo tệp cơ sở dữ liệu mới `local_data_v1.db` do [app_database.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/local/app_database.dart) quản lý.
> - **Bảo toàn:** Giữ nguyên tệp `delivery_offline_v2.db` cùng [offline_storage_service.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/services/offline_storage_service.dart) để tránh làm ảnh hưởng đến hàng đợi đồng bộ cũ và các bài test đã có.
> - **Cấu hình động cơ SQLite:**
>   - Bắt buộc bật `PRAGMA foreign_keys = ON;` qua hook `onConfigure`.
>   - Kích hoạt chế độ `PRAGMA journal_mode = WAL;` (Write-Ahead Logging) cho hiệu năng đọc/ghi đồng thời tối ưu.
>   - Cơ chế migration theo phiên bản (`user_version`, `onCreate`, `onUpgrade` chạy tuần tự trong transaction).
>   - Định danh `id` dạng TEXT UUID v4 sinh trực tiếp tại app qua [uuid_utils.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/utils/uuid_utils.dart).
>   - Thời gian lưu trữ theo định dạng chuẩn ISO-8601 UTC (`YYYY-MM-DDTHH:mm:ss.sssZ`).

```mermaid
erDiagram
    customers ||--o| saved_locations : "has verified gate"
    customers ||--o{ location_history : "tracks changes"
    saved_locations ||--o{ location_history : "on delete set null"
    customers ||--o{ customer_photos : "owns photos"
    shifts ||--o{ shift_delivery_points : "contains delivery points (cascade)"
    customers ||--o{ shift_delivery_points : "delivered to"

    customers {
        TEXT id PK "UUID"
        TEXT customer_code "Mã khách"
        TEXT full_name "Họ và tên"
        TEXT phone_number UK "Đã chuẩn hóa 10 số"
        TEXT address_text "Địa chỉ văn bản"
        TEXT notes "Ghi chú"
        TEXT search_text "Cột phụ không dấu unaccent"
        TEXT created_at "ISO-8601 UTC"
        TEXT updated_at "ISO-8601 UTC"
        TEXT deleted_at "Xóa mềm (NULL nếu active)"
    }

    saved_locations {
        TEXT id PK "UUID"
        TEXT customer_id UK, FK "Chỉ 1 vị trí chuẩn / khách"
        REAL latitude "Vĩ độ WGS84"
        REAL longitude "Kinh độ WGS84"
        REAL gps_accuracy "Độ chính xác GPS (mét)"
        TEXT identification_notes "Mô tả đặc điểm cổng/nhà"
        TEXT created_at "ISO-8601 UTC"
        TEXT updated_at "ISO-8601 UTC"
    }

    location_history {
        TEXT id PK "UUID"
        TEXT saved_location_id FK "NULL khi vị trí gốc bị xóa"
        TEXT customer_id FK "Liên kết khách hàng"
        REAL latitude "Vĩ độ cũ"
        REAL longitude "Kinh độ cũ"
        REAL gps_accuracy "Độ chính xác cũ"
        TEXT identification_notes "Mô tả cũ"
        TEXT change_reason "Lý do thay đổi"
        TEXT created_at "Thời điểm thay đổi"
    }

    customer_photos {
        TEXT id PK "UUID"
        TEXT customer_id FK "Khách hàng sở hữu"
        TEXT file_name "Tên tệp ảnh trong app storage"
        TEXT thumb_file_name "Tên tệp ảnh thu nhỏ"
        TEXT created_at "ISO-8601 UTC"
        TEXT deleted_at "Xóa mềm"
    }

    shifts {
        TEXT id PK "UUID"
        TEXT shift_code "Mã ca SHF-YYYYMMDD-XXX"
        TEXT shift_name "Tên ca (gợi ý tự động)"
        TEXT work_date "Ngày làm việc YYYY-MM-DD"
        TEXT status "CHECK: PREPARING/IN_PROGRESS/COMPLETED"
        TEXT started_at "Bắt đầu ca"
        TEXT completed_at "Hoàn thành ca"
        TEXT created_at "ISO-8601 UTC"
        TEXT updated_at "ISO-8601 UTC"
    }

    shift_delivery_points {
        TEXT id PK "UUID"
        TEXT shift_id FK "Ca làm việc (ON DELETE CASCADE)"
        TEXT customer_id FK "Khách hàng"
        INTEGER delivery_order_index "Thứ tự giao trong ca"
        TEXT location_status "CHECK: NO_LOCATION/TEMPORARY/VERIFIED"
        REAL latitude "Tọa độ ghim tạm riêng trong ca"
        REAL longitude "Tọa độ ghim tạm riêng trong ca"
        REAL gps_accuracy "Độ chính xác GPS"
        TEXT identification_notes "Ghi chú giao điểm này"
        TEXT created_at "ISO-8601 UTC"
        TEXT updated_at "ISO-8601 UTC"
    }

    app_profile {
        INTEGER id PK "CHECK: id = 1"
        TEXT display_name "Tên hiển thị người dùng"
        TEXT pin_hash "Mã PIN bảo mật cục bộ"
        TEXT created_at "ISO-8601 UTC"
        TEXT updated_at "ISO-8601 UTC"
    }

    app_meta {
        TEXT key PK "Khóa cấu hình"
        TEXT value "Giá trị cài đặt"
    }

    activity_log {
        TEXT id PK "UUID"
        TEXT action "Hành động thực hiện"
        TEXT entity "Đối tượng tác động"
        TEXT entity_id "ID đối tượng"
        TEXT details_json "Chi tiết (lọc bỏ dữ liệu nhạy cảm)"
        TEXT created_at "ISO-8601 UTC"
    }
```

### 5.1. Quy Tắc Nghiệp Vụ Cốt Lõi Được Đảm Bảo Bằng Ràng Buộc CSDL

1. **Vị Trí Đã Xác Minh vs. Vị Trí Ghim Tạm:**
   - `saved_locations` chỉ chứa vị trí cổng nhà đã được xác minh (`VERIFIED`) chính thức của khách hàng.
   - Vị trí ghim tạm (`TEMPORARY`) trước khi đi giao chỉ tồn tại cục bộ trong ca làm việc tại bảng `shift_delivery_points` (`location_status = 'TEMPORARY'`), không ghi đè vào `saved_locations`.
2. **Bảo Toàn Khách Hàng Khi Xóa Ca:**
   - `shift_delivery_points` có khóa ngoại `FOREIGN KEY (shift_id) REFERENCES shifts(id) ON DELETE CASCADE`.
   - Bảng `customers` và `saved_locations` **không** bị phụ thuộc khóa ngoại cascade từ `shifts`. Khi xóa ca làm việc, toàn bộ khách hàng và vị trí đã lưu hoàn toàn nguyên vẹn.
3. **Bảo Toàn Lịch Sử Đối Soát Khi Xóa Vị Trí:**
   - `location_history` có khóa ngoại `FOREIGN KEY (saved_location_id) REFERENCES saved_locations(id) ON DELETE SET NULL`.
   - Trigger SQLite `trg_saved_locations_history` tự động sinh bản ghi lưu lại tọa độ và ghi chú cũ mỗi khi có thao tác `UPDATE` thay đổi tọa độ/ghi chú.
   - Khi xóa dòng trong `saved_locations`, các bản ghi lịch sử tương ứng vẫn tồn tại nguyên vẹn, chỉ có trường `saved_location_id` tự động chuyển về `NULL`.
4. **Ngăn Ngừa Trùng Lặp Trong Ca:**
   - Khóa duy nhất tổ hợp `UNIQUE(shift_id, customer_id)` chặn tuyệt đối hành vi thêm một khách hàng nhiều lần vào cùng một ca.
5. **Tìm Kiếm Thông Minh Không Dấu (Vietnamese Unaccent):**
   - Cột phụ `search_text` trong bảng `customers` được tự động sinh đồng bộ qua [vietnamese_utils.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/utils/vietnamese_utils.dart).
   - Cho phép người dùng tìm kiếm theo `"Nguyen Xien"` khớp chính xác `"Nguyễn Xiển"`, tìm theo SĐT có khoảng cách/dấu chấm (`"0909 112 233"`) khớp `"0909112233"`.
6. **Chuẩn Hóa Số Điện Thoại Dùng Chung:**
   - Hàm `normalizeCustomerPhone` được tách ra [phone_utils.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/utils/phone_utils.dart) đảm bảo mọi số điện thoại nhập từ giao diện (Thêm nhanh khách, dán SĐT, tra cứu) đều được chuẩn hóa về 10 chữ số bắt đầu bằng `0` trước khi lưu.

---

## 6. Triển Khai Local Repositories: Customer & Location (TASK: LOCAL-FIRST-03)

### 6.1. Bảng Đối Chiếu Phương Thức: Interface -> SQLite -> Khác Biệt So Với Remote

#### A. CustomerRepository ([customer_repository.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/repositories/customer_repository.dart))

| Phương Thức Interface | Triển Khai SQLite Cục Bộ ([LocalCustomerRepository](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/repositories/local/local_customer_repository.dart)) | Khác Biệt So Với Remote ([RemoteCustomerRepository](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/repositories/remote/remote_customer_repository.dart)) |
| :--- | :--- | :--- |
| `getCustomers(...)` | Gọi `getCustomersResponse` và trích xuất danh sách `items`. | Truy vấn trực tiếp từ bảng `customers`, không có độ trễ mạng. |
| `getCustomersResponse(...)` | Lọc `deleted_at IS NULL`, tìm kiếm không dấu qua `search_text LIKE ?`, xác định `locationState` (VERIFIED / TEMPORARY / NO_LOCATION), tính `counts` và phân trang (`limit`, `offset`). | Xử lý ngay trong thiết bị. Không phân biệt quyền hạn/khu vực khác nhau giữa các shipper. |
| `getCustomerDetail(id)` | Truy vấn `customers` theo ID, LEFT JOIN `saved_locations` và điểm ghim tạm ca đang mở. | Trả về `CustomerDirectoryModel` nguyên vẹn cho UI. |
| `createCustomer(...)` | Chuẩn hóa SĐT, kiểm tra tồn tại trong transaction. Nếu đã có trả về với `isExisting = true`. Nếu chưa có tự gán `"Khách [SĐT]"`, `"Chưa cập nhật địa chỉ"`. Nếu có tọa độ, lưu đồng thời vào `saved_locations`. | Thực thi trong 1 transaction khép kín, tuyệt đối không để lại khách mồ côi nếu tọa độ lỗi. |
| `createBulkCustomers(...)` | Sử dụng `parseAndNormalizeBulkPhones` tách dấu xuống dòng/phẩy/chấm phẩy, giữ khoảng trắng/chấm trong số, lọc trùng, giới hạn 200 số. Chạy 1 transaction phân 3 nhóm `created`, `alreadyExists`, `rejected`. | Ghi nhận nhật ký vào `activity_log` thay vì `audit_logs` trên máy chủ. |
| `updateCustomer(...)` | Chuẩn hóa SĐT, kiểm tra trùng lặp với khách khác, cập nhật họ tên/địa chỉ/SĐT và tái sinh `search_text`. | Kiểm tra trùng lặp cục bộ tức thì. |
| `lookupCustomerLocationByPhone(...)` | Tìm khách theo SĐT đã chuẩn hóa, lấy vị trí VERIFIED hoặc TEMPORARY trong ca đang mở, trả về Map định dạng chuẩn. | Thay thế hoàn toàn request `GET /locations/customer?phone=...`. |
| `deleteCustomer(id)` | Kiểm tra ràng buộc: từ chối xóa nếu khách đang có điểm giao trong ca `PREPARING` hoặc `IN_PROGRESS`. Xóa mềm bằng `deleted_at = currentIsoUtc()`. | Remote chưa hỗ trợ xóa khách hàng; Local hỗ trợ xóa mềm an toàn. |

#### B. LocationRepository ([location_repository.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/repositories/location_repository.dart))

| Phương Thức Interface | Triển Khai SQLite Cục Bộ ([LocalLocationRepository](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/repositories/local/local_location_repository.dart)) | Khác Biệt So Với Remote ([RemoteLocationRepository](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/repositories/remote/remote_location_repository.dart)) |
| :--- | :--- | :--- |
| `getMySavedLocations()` | Truy vấn `saved_locations` JOIN `customers` (`deleted_at IS NULL`), map sang `MasterSavedLocationModel`. | Dữ liệu tức thì cho bản đồ chính, tạm thời `photoCount = 0`, `photos = []` (chờ bước Photo). |
| `getSavedLocationsInBounds(...)` | Lọc theo khung nhìn tọa độ `BETWEEN minLat AND maxLat` và `BETWEEN minLng AND maxLng` bằng index không gian SQLite. | Tối ưu hóa hiệu năng render marker theo khung nhìn bản đồ. |
| `saveCustomerLocation(...)` | Kiểm tra tọa độ (-90..90, -180..180), upsert `saved_locations` trong transaction, tự động đồng bộ điểm giao trong ca sang `VERIFIED` (LOCATION-RULES-012). | Không cần hàng đợi offline vì dữ liệu lưu thẳng vào SQLite chính. |
| `updateCustomerLocationAndPhoto(...)` | Hỗ trợ gán cho cả customerId hoặc số điện thoại mới toanh (tự sinh khách + lưu vị trí trong 1 transaction). Đồng bộ điểm trong ca. | Trả về `updatedShiftPointsCount` chính xác và ghi `activity_log`. |
| `deleteCustomerLocation(id)` | Xóa `saved_locations`, bảo toàn `location_history` (`saved_location_id = NULL`), chuyển điểm giao `VERIFIED` trong ca về `NO_LOCATION`, giữ nguyên điểm `TEMPORARY`. | Ghi nhận nhật ký vào `activity_log`. |
| `updateTemporaryLocation(...)` | Cập nhật `shift_delivery_points` với `location_status = 'TEMPORARY'` riêng cho ca đó. | Tọa độ tạm thời không bao giờ làm ô nhiễm bảng `saved_locations`. |
| `getPendingSyncCount()` | Trả về `0` (dữ liệu Local-First luôn sẵn sàng và nhất quán). | Không dùng hàng đợi đồng bộ v2 khi ở chế độ Local. |
| `syncOfflineQueue()` | Hoàn thành ngay lập tức (không gọi mạng). | Chờ module P2P/Cloud Sync ở các bước sau. |
| `getLocationHistory(customerId)` | Truy vấn `location_history` theo `customer_id` sắp xếp mới nhất trước. | Phục vụ xem lịch sử cổng nhà của khách hàng. |

---

### 6.2. Chính Sách Khu Vực (areaId): Tạm Giữ Khu Vực Ảo Để Dọn Ở Bước 6

- Trong mô hình Local-First, mỗi thiết bị là một không gian dữ liệu độc lập của shipper, không còn nhu cầu phân chia khu vực bảo mật giữa các nhân viên.
- Nhằm tránh làm vỡ giao diện Flutter hiện có (các bộ lọc khu vực, badge hiển thị), các phương thức cục bộ trả về một khu vực ảo mặc định:
  * `areaId = 'local-area-default'`
  * `areaName = 'Của tôi'`
- **Kế hoạch dọn dẹp:** Toàn bộ các tham số và UI chọn khu vực sẽ được dọn dẹp triệt để trong **Bước 6 (Local-First Cleanup & Hardening)**.

---

### 6.3. Hướng Dẫn Bật Chế Độ Thử Nghiệm Local-First

1. **Bật qua Mã Nguồn (Code Switch):**
   ```dart
   RepositoryProvider.useLocalData = true;
   ```
2. **Bật qua Cờ Biên Dịch (Compile Flag):**
   ```bash
   flutter run --dart-define=LOCAL_DATA=true
   flutter build apk --debug --dart-define=LOCAL_DATA=true
   ```
3. **Bỏ Qua Màn Hình Đăng Nhập:**
   Khi `RepositoryProvider.useLocalData = true`, [main.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/main.dart) tự động chuyển hướng thẳng vào [HomeShellView](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/views/home_shell_view.dart) mà không cần kiểm tra JWT token hay bắt shipper đăng nhập.

---

## 7. Triển Khai Local Repositories: Shifts & Bulk Operations (TASK: LOCAL-FIRST-04)

### 7.1. Bảng Đối Chiếu Phương Thức: Interface -> SQLite -> Khác Biệt So Với Remote

#### ShiftRepository ([shift_repository.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/repositories/shift_repository.dart))

| Phương Thức Interface | Triển Khai SQLite Cục Bộ ([LocalShiftRepository](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/repositories/local/local_shift_repository.dart)) | Khác Biệt So Với Remote ([RemoteShiftRepository](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/repositories/remote/remote_shift_repository.dart)) |
| :--- | :--- | :--- |
| `getShifts()` | Truy vấn `shifts` sắp xếp `work_date DESC, created_at DESC`, tính `summary` (`totalPoints`, `verifiedCount`, `temporaryCount`, `noLocationCount`) qua `GROUP BY shift_id` từ `shift_delivery_points`. | Đọc trực tiếp từ SQLite thiết bị, tốc độ tức thì, không phụ thuộc kết nối mạng. |
| `createShift(...)` | Sinh `shift_code` dạng `SHF-YYYYMMDD-XXX` theo giờ VN (UTC+7), `XXX` tăng dần và tự động reset về `001` khi sang ngày mới; `shift_name` cắt khoảng trắng, tối đa 100 ký tự; nếu không đặt tên thì tự động gợi ý `"Ca sáng/chiều/tối dd/MM"` và thêm `" (2)"`, `" (3)"` khi trùng tên trong ngày; trạng thái ban đầu `PREPARING`. | Mã ca và tên ca được tính toán trực tiếp trên SQLite cục bộ. |
| `getShiftDetail(id)` | Truy vấn `shifts` theo ID, JOIN `shift_delivery_points` với `customers` và `saved_locations`, tính `summary` thực tế. | Trả về `ShiftModel` kèm danh sách `deliveryPoints` hoàn chỉnh cho UI bản đồ ca và danh sách điểm. |
| `updateShiftName(id, name)` | Cắt khoảng trắng, từ chối tên rỗng, giới hạn 100 ký tự, cập nhật `shift_name` và ghi `activity_log`. | Cập nhật tức thì. |
| `updateShiftStatus(id, status)` | Chuyển đổi trạng thái tuần tự `PREPARING -> IN_PROGRESS -> COMPLETED`: gán `started_at = now` khi bắt đầu, gán `completed_at = now` khi hoàn thành. Chặn tuyệt đối chuyển sai thứ tự hoặc đổi trạng thái khi ca đã hoàn thành. | Ràng buộc logic chặt chẽ ngay tại client. |
| `deleteShift(id)` | Xóa ca trong transaction: Cascade xóa các điểm giao của ca trong `shift_delivery_points`. TUYỆT ĐỐI KHÔNG xóa khách hàng, vị trí đã lưu hay lịch sử vị trí. Ca đang `IN_PROGRESS` vẫn xóa được bình thường. Ghi `activity_log`. | Đảm bảo tính toàn vẹn kiểm toán và an toàn dữ liệu khách hàng. |
| `addPointToShift(...)` | Thêm điểm bằng `customerId` hoặc `phoneNumber` (chuẩn hóa). Nếu SĐT chưa có thì tạo khách nhanh (`"Khách [SĐT]"`, `"Chưa cập nhật địa chỉ"`). Kiểm tra vị trí đã lưu (`VERIFIED` kèm tọa độ nếu có, `NO_LOCATION` nếu chưa có). Chống trùng lặp trả `isExisting: true`. Tự động tăng `delivery_order_index`. | Hoạt động khép kín trong 1 transaction an toàn. |
| `addBulkPointsToShift(...)` | Dùng hàm tách số chung `parseAndNormalizeBulkPhones` (xuống dòng, phẩy, chấm phẩy, khoảng trắng/chấm trong số), chặn > 200 số. Chạy trong ĐÚNG 1 transaction cho cả lô. Trả 4 nhóm: `added`, `alreadyInShift`, `rejected`, và `summary`. Ghi ĐÚNG 1 dòng `activity_log` cho cả lô. | Không tạo khách mồ côi hay dữ liệu nửa vời nếu phát sinh lỗi giữa lô. |
| `removePointFromShift(sId, pId)` | Xóa điểm khỏi `shift_delivery_points`. Phục vụ tính năng HOÀN TÁC khi thêm điểm từ Danh bạ. | Xóa chính xác điểm vừa thêm và cập nhật lại summary. |
| `verifyPointLocation(...)` | Ném `UnsupportedError`: Giữ nguyên trạng thái ngừng hoạt động theo chuẩn `LOCATION-RULES-012`, vị trí chuẩn chỉ xác nhận qua luồng Danh bạ. | Khớp 100% với mã phản hồi 410 Gone của Remote. |
| `getMyShiftOrders()` & `addOrderToShift(...)` | Ánh xạ mượt mà từ các điểm giao trong ca đang mở (`IN_PROGRESS` / `PREPARING`) sang danh sách `OrderModel` phục vụ tương thích ngược các màn hình cũ. | Đảm bảo các widget cũ không bị crash. |

---

### 7.2. Báo Cáo Khảo Sát Các Màn Hình Nghiệp Vụ Sử Dụng Ca
Rà soát toàn bộ các màn hình và widget liên quan đến ca làm việc:
- [shift_list_view.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/views/shift_list_view.dart): Sử dụng `RepositoryProvider.shift.getShifts()`, `createShift`, `deleteShift`. **100% không còn gọi ApiService trực tiếp**.
- [shift_preparation_view.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/views/shift_preparation_view.dart): Sử dụng `RepositoryProvider.shift.addPointToShift`, `RepositoryProvider.customer.lookupCustomerLocationByPhone`. **100% không còn gọi ApiService trực tiếp**.
- [shift_map_view.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/views/shift_map_view.dart): Sử dụng `RepositoryProvider.shift.getShiftDetail`, `updateShiftStatus`. (Chỉ còn tiện ích `ApiService.openExternalNavigation` để mở ứng dụng Google Maps ngoài thiết bị).
- [create_shift_dialog.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/widgets/create_shift_dialog.dart): Sử dụng `RepositoryProvider.shift.createShift`. **100% không gọi ApiService**.
- [bulk_paste_phone_sheet.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/widgets/bulk_paste_phone_sheet.dart): Sử dụng `RepositoryProvider.shift.addBulkPointsToShift`. **100% không gọi ApiService**.
- [shift_picker_bottom_sheet.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/widgets/shift_picker_bottom_sheet.dart): Sử dụng `RepositoryProvider.shift.getShifts`. **100% không gọi ApiService**.
- [customer_directory_view.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/views/customer_directory_view.dart): Nút `+` thêm khách vào ca dùng `RepositoryProvider.shift.addPointToShift` và nút `HOÀN TÁC` dùng `RepositoryProvider.shift.removePointFromShift`. **100% không gọi ApiService**.

---

### 7.3. Mở Rộng Công Tắc `RepositoryProvider.useLocalData`

Khi kích hoạt `RepositoryProvider.useLocalData = true`:
- `customer`: Trỏ về [LocalCustomerRepository](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/repositories/local/local_customer_repository.dart).
- `location`: Trỏ về [LocalLocationRepository](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/repositories/local/local_location_repository.dart).
- `shift`: Trỏ về [LocalShiftRepository](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/repositories/local/local_shift_repository.dart).
- `photo`: Trỏ về [LocalPhotoRepository](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/repositories/local/local_photo_repository.dart) (từ TASK: LOCAL-FIRST-05).
- `sharing`, `profile`: Vẫn trỏ về Remote tương ứng (chờ các bước tiếp theo).
- **Mặc định:** `useLocalData = false` (ứng dụng chạy hoàn toàn như cũ trừ khi được bật rõ ràng).

---

## 8. Triển Khai Local Repositories: Photos & Quản Lý Tệp Ảnh Cục Bộ (TASK: LOCAL-FIRST-05)

### 8.1. Bảng Đối Chiếu Phương Thức: Interface -> Local Storage -> Khác Biệt So Với Remote

#### PhotoRepository ([photo_repository.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/repositories/photo_repository.dart))

| Phương Thức Interface | Triển Khai Cục Bộ ([LocalPhotoRepository](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/repositories/local/local_photo_repository.dart)) | Khác Biệt So Với Remote ([RemotePhotoRepository](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/repositories/remote/remote_photo_repository.dart)) |
| :--- | :--- | :--- |
| `addCustomerPhoto(customerId, imageBase64)` | 1. Nhận chuỗi base64 / Data URI, kiểm tra Magic Bytes (JPEG: `FF D8 FF`, PNG: `89 50 4E 47...`, WebP: `RIFF...WEBP`). Từ chối các tệp sai định dạng.<br>2. Chặn file vượt quá 5MB.<br>3. Kiểm tra số lượng ảnh hiện có của khách (tối đa 10 ảnh mặt tiền chưa xóa mềm, thêm ảnh thứ 11 ném `StateError`).<br>4. Sinh tên file ngẫu nhiên UUID (`<uuid>.jpg` và `<uuid>_thumb.jpg`) không chứa SĐT hay tên khách.<br>5. Nén ảnh cạnh dài <= 1600px quality ~80 và tạo thumbnail ~300px.<br>6. Ghi file vào thư mục riêng của app (`<docDir>/photos` và `<docDir>/photos/thumbs`).<br>7. Lưu vào bảng SQLite `customer_photos` và ghi `activity_log` (`ADD_CUSTOMER_PHOTO`). Nếu DB lỗi, tự động xóa ngay file vừa tạo để chống file mồ côi. | Xử lý nén và lưu hoàn toàn trên thiết bị, không cần mạng, tốc độ tức thì. Đảm bảo tính toàn vẹn tuyệt đối (atomic rollback không để lại file rác). |
| `getCustomerPhotos(customerId)` | Truy vấn `customer_photos` WHERE `customer_id = ? AND deleted_at IS NULL` sắp xếp `created_at DESC`. Ghép đường dẫn cục bộ tuyệt đối vào `imageUrl` của `CustomerPhotoModel`. | Trả về danh sách ảnh với đường dẫn file cục bộ sẵn sàng hiển thị, không cần chờ tải mạng. |
| `deleteCustomerPhoto(customerId, photoId)` | Xóa mềm: Gán `deleted_at = now` trong bảng `customer_photos`, ghi `activity_log` (`DELETE_CUSTOMER_PHOTO`). File trên đĩa được giữ nguyên tạm thời để phục vụ hoàn tác hoặc đối soát. | Xóa mềm an toàn, không xóa file vật lý ngay lập tức. |
| `getPhotoAuthInfo(photoUrl, ...)` | Kiểm tra nếu URL là đường dẫn file cục bộ hoặc bắt đầu bằng `file://`: Trả về `{'url': photoUrl, 'filePath': path, 'isLocal': 'true', 'token': ''}` mà không yêu cầu JWT token. | Trả thẳng đường dẫn tệp thiết bị để widget sử dụng `Image.file` trực tiếp, không phụ thuộc phiên đăng nhập. |
| `purgeDeletedPhotosOlderThan(...)` *(Mở rộng)* | Quét các ảnh có `deleted_at` cũ hơn 30 ngày: Xóa file ảnh gốc và thumbnail trên đĩa, xóa dòng bản ghi trong `customer_photos`, ghi `activity_log` (`PURGE_EXPIRED_PHOTOS`). Tự động kích hoạt khi mở ứng dụng. | Cơ chế dọn dẹp bộ nhớ tự động, ngăn tràn dung lượng máy của shipper. |
| `getCustomerPhotoSummary(id)` & `getBatchPhotoSummaries(ids)` *(Mở rộng)* | Truy vấn nhóm ảnh theo danh sách `customerId`, trả về `photoCount`, danh sách tối đa 3 ảnh thumbnail đầu tiên và `firstThumbnailUrl`. | Dùng để enrich đồng loạt cho `CustomerDirectoryModel`, `MasterSavedLocationModel` và `ShiftDeliveryPointModel`. |

---

### 8.2. Quy Chuẩn Lưu Trữ File & Bảo Mật Quyền Riêng Tư (Privacy & Storage)
1. **Thư Mục Lưu Trữ Riêng:**
   - Ảnh gốc: `getApplicationDocumentsDirectory() / photos / <uuid>.jpg`.
   - Thumbnail: `getApplicationDocumentsDirectory() / photos / thumbs / <uuid>_thumb.jpg`.
   - **Tuyệt đối KHÔNG** lưu vào thư mục công khai (`DCIM`, `Pictures`, `Downloads`) hoặc thư viện ảnh chung của hệ điều hành.
2. **Quy Tắc Đặt Tên File:**
   - Tên file sử dụng UUID v4 ngẫu nhiên (`UuidUtils.generate()`), ví dụ: `d9e03d42-2b63-4a0b-93df-f1261a8ef1c2.jpg`.
   - **Nghiêm cấm** đưa số điện thoại, họ tên, hoặc địa chỉ của khách hàng vào tên file hoặc tên thư mục nhằm triệt để bảo vệ quyền riêng tư theo tiêu chuẩn bảo mật dữ liệu.
3. **Lưu Đường Dẫn Tương Đối Trong SQLite:**
   - Cột `file_name` và `thumb_file_name` trong bảng `customer_photos` chỉ lưu tên file tương đối (`<uuid>.jpg`).
   - Đường dẫn tuyệt đối được ghép động qua `p.join(photosDir.path, fileName)` khi truy vấn. Điều này giúp tránh hỏng đường dẫn khi hệ điều hành Android/iOS thay đổi đường dẫn sandbox nội bộ sau các bản cập nhật ứng dụng.

> [!WARNING]
> **THÔNG BÁO QUYỀN RIÊNG TƯ & AN TOÀN DỮ LIỆU (PRIVACY NOTICE):**
> Toàn bộ ảnh chụp mặt tiền nhà khách hàng được lưu trữ trong không gian riêng biệt (internal sandbox storage) của ứng dụng `Delivery Marker`. 
> Do đó, **nếu người dùng gỡ cài đặt (uninstall) ứng dụng, toàn bộ ảnh chụp này sẽ bị hệ điều hành xóa sạch cùng ứng dụng** trừ khi đã thực hiện tính năng sao lưu (Backup / Export).
> Cơ chế sao lưu và phục hồi dữ liệu hoàn chỉnh sẽ được triển khai tại **Bước 7: Local Backup & Export**.

---

### 8.3. Thích Ứng Các Widget Hiển Thị & Chụp Ảnh
1. **[CustomerPhotosStripWidget](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/widgets/customer_photos_strip_widget.dart):**
   - **Thao tác 1 chạm (1-touch camera):** Bấm trực tiếp vào nút `+ THÊM ẢNH` (kích thước chuẩn `>= 56px`) sẽ mở ngay Camera để chụp ảnh mặt tiền nhanh chóng cho shipper.
   - **Thao tác nâng cao:** Nhấn giữ nút `+ THÊM ẢNH` sẽ mở Action Sheet để cho phép chọn ảnh từ Thư viện (Gallery) khi cần.
   - **Xem ảnh phóng to:** Bấm vào bất kỳ ảnh nào trong dải ảnh sẽ mở [FullscreenImageViewer](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/widgets/fullscreen_image_viewer.dart) ở chế độ Gallery vuốt qua lại giữa các ảnh.
   - **Xóa ảnh:** Nhấn giữ vào ảnh hiện hộp thoại xác nhận xóa ảnh an toàn.
2. **[AuthenticatedImage](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/widgets/authenticated_image.dart):**
   - Tự động nhận diện `photoInfo['isLocal'] == 'true'` hoặc URL file cục bộ (`file://` hoặc đường dẫn tệp trên đĩa).
   - Render bằng `Image.file(File(filePath))` kèm cấu hình bộ nhớ đệm `cacheWidth` và `cacheHeight` tương ứng với kích thước hiển thị để tối ưu hóa RAM, ngăn giật lag cuộn danh sách.
   - Giữ nguyên `Image.network` khi chạy ở chế độ Remote.
3. **[FullscreenImageViewer](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/widgets/fullscreen_image_viewer.dart):**
   - Hỗ trợ chế độ xem đơn lẻ và xem Gallery nhiều ảnh qua `PageView.builder` và `InteractiveViewer`.
   - Render ảnh cục bộ bằng `Image.file` với độ phân giải đầy đủ, hỗ trợ thu phóng cảm ứng mượt mà (zoom từ 0.8x đến 5.0x).

---

## 9. Triển Khai Local Profile, Mã PIN Bảo Mật & Sao Lưu / Phục Hồi Dữ Liệu (TASK: LOCAL-FIRST-06-PROFILE-PIN-BACKUP)

### 9.1. Hồ Sơ Cục Bộ & Cơ Chế Khởi Động Không Cần Đăng Nhập
1. **LocalProfileRepository ([local_profile_repository.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/repositories/local/local_profile_repository.dart)):**
   - Hồ sơ người dùng lưu trữ trong bảng SQLite `app_profile` (`id = 1`): `display_name` (mặc định "Người giao hàng"), `pin_hash` (chuỗi PBKDF2).
   - Thống kê người dùng `getMyStats()` tính toán trực tiếp từ dữ liệu thực tế trong SQLite: số vị trí đã lưu (`saved_locations`), số ca đã tạo (`shifts`), số ảnh đã tải (`customer_photos WHERE deleted_at IS NULL`), số khách hàng (`customers WHERE deleted_at IS NULL`).
   - Mọi hoạt động cập nhật tên, đặt/đổi/tắt PIN, xóa trắng khôi phục được ghi vào `activity_log` (TUYỆT ĐỐI không ghi mã PIN hay dữ liệu khách hàng).
2. **Khởi Động Không Cần Đăng Nhập (No Login / First-Run Onboarding):**
   - **Mặc định nhánh `local-first`:** Bỏ cờ bắt buộc `--dart-define=LOCAL_DATA=true`. Biến cờ `RepositoryProvider.useLocalData` mặc định `true` cho toàn bộ nhánh này. Toàn bộ các kho `Customer`, `Location`, `Shift`, `Photo`, `Profile` đều khởi tạo chế độ `Local`.
   - Lần đầu mở ứng dụng: Màn hình chào mừng [WelcomeOnboardingView](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/views/welcome_onboarding_view.dart) xuất hiện ngắn gọn với tiêu đề "CHÀO MỪNG BẠN!", cho phép nhập tên hiển thị (hoặc bỏ qua) rồi bấm "BẮT ĐẦU SỬ DỤNG" vào thẳng ứng dụng chính [HomeShellView](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/views/home_shell_view.dart). Cờ `onboarding_completed` lưu vào `app_meta` để không hiện lại.
3. **Chuyển Đổi Tab "Tài Khoản" Thành Tab "Cá Nhân":**
   - Giao diện [AccountProfileView](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/views/account_profile_view.dart) thích ứng động theo `RepositoryProvider.useLocalData`:
     - Tiêu đề AppBar hiển thị "Cá nhân", nhãn chế độ "Chế độ Local-First (Dữ liệu trên máy)".
     - Có nút bút chì cạnh tên để mở hộp thoại đổi tên hiển thị bất kỳ lúc nào.
     - Khối "Thống kê của tôi": hiển thị 3 chỉ số từ SQLite (Vị trí đã lưu, Ca đã tạo, Ảnh đã tải).
     - Khối "Bảo mật & Mã PIN khóa app" mở [PinSettingsBottomSheet](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/widgets/pin_settings_bottom_sheet.dart).
     - Khối "Sao lưu & Khôi phục dữ liệu" mở [BackupRestoreBottomSheet](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/widgets/backup_restore_bottom_sheet.dart).
     - Khối "Phiên bản ứng dụng": hiển thị `v1.0.0 (Local-First)`.
     - **Ẩn hoàn toàn trong chế độ Local:** Khối "Khu vực phụ trách", mục "Đổi mật khẩu", mục "Địa chỉ máy chủ", nút "ĐĂNG XUẤT", và mục "Chia sẻ dữ liệu" (tạm ẩn cho đến Bước 8).
4. **Bảo Tồn Các Tệp Giao Diện Máy Chủ:**
   - Các tệp [login_view.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/views/login_view.dart), [change_password_view.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/views/change_password_view.dart), [data_sharing_view.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/views/data_sharing_view.dart) **KHÔNG BỊ XÓA**, được giữ nguyên 100% trong mã nguồn để phục vụ việc chuyển đổi lại khi người dùng kết nối máy chủ tập trung (`useLocalData = false`).

---

### 9.2. Mã PIN Khóa Ứng Dụng Tùy Chọn (PIN Security & Lock Screen)
1. **Thuật Toán Băm Mật Mã PBKDF2/SHA-256 ([PinCryptoUtils](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/utils/pin_crypto_utils.dart)):**
   - Mã PIN gồm 4 đến 6 chữ số (`^\d{4,6}$`).
   - Sử dụng chuẩn HMAC-SHA256 kết hợp 10,000 vòng lặp PBKDF2 (RFC 8018) và Salt ngẫu nhiên 16 bytes tạo từ `Random.secure()`.
   - Định dạng lưu trữ: `pbkdf2:sha256:10000:<saltHex>:<hashHex>`.
   - Xác thực so sánh chuỗi bằng thời gian hằng số (`_constantTimeEquals`) để triệt tiêu hoàn toàn nguy cơ tấn công kênh kề phân tích thời gian (timing attacks).
   - **Bảo mật tuyệt đối:** TUYỆT ĐỐI không lưu trữ PIN thô ở bất kỳ đâu; không in hay ghi PIN vào log hệ thống.
2. **Cơ Chế Khóa Tự Động & Chống Brute-Force Tăng Dần:**
   - **Tự động khóa theo thời gian chờ nền:** Lắng nghe vòng đời ứng dụng `AppLifecycleState` trong [HomeShellView](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/views/home_shell_view.dart). Khi app tạm dừng (paused/inactive), ghi nhận thời điểm. Khi quay lại (resumed), kiểm tra chênh lệch thời gian với cấu hình tự động khóa trong `app_meta` (hỗ trợ 3 mức: Ngay lập tức / 1 phút / 5 phút). Nếu quá hạn, tự động kích hoạt màn hình khóa.
   - **Khóa lũy tiến khi nhập sai:**
     - 1 đến 4 lần sai: Báo lỗi và đếm ngược số lần thử còn lại.
     - Lần thứ 5 sai: Khóa tạm thời 30 giây, hiển thị bộ đếm ngược thời gian thực trên màn hình khóa.
     - Mỗi lần sai tiếp theo cộng thêm 15 giây.
3. **Màn Hình Khóa PIN ([PinLockScreen](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/views/pin_lock_screen.dart)):**
   - Giao diện tối hiện đại, bàn phím số tròn lớn (chiều cao 72px) dễ thao tác bằng một tay.
   - Dãy 6 chấm tròn biểu thị số chữ số trực quan.
   - Nút "Quên mã PIN?": Cảnh báo nghiêm ngặt và minh bạch *"Quên mã PIN sẽ phải xóa toàn bộ dữ liệu ứng dụng để bảo vệ quyền riêng tư. Bạn có thể khôi phục lại dữ liệu sau đó nếu đã tạo file sao lưu."* Nút "XÁC NHẬN ĐẶT LẠI" yêu cầu gõ chữ `XOA HET` để tránh bấm nhầm. Triệt để không có cửa sau (no backdoor).

---

### 9.3. Sao Lưu & Phục Hồi Dữ Liệu Ngoại Tuyến (Backup & Restore Service)
1. **Dịch Vụ [BackupService](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/services/backup_service.dart):**
   - **Tạo bản sao lưu nhất quán:**
     - Thực hiện `PRAGMA wal_checkpoint(TRUNCATE);` để đảm bảo toàn bộ nhật ký WAL được commit trọn vẹn vào file CSDL chính `local_data_v1.db`.
     - Đóng gói thành **MỘT** file `.zip` duy nhất đặt tên `delivery-backup-YYYYMMDD-HHmm.zip` (theo giờ địa phương).
     - Cấu trúc file zip gồm: `database.db`, thư mục `photos/`, và `manifest.json`.
     - Tùy chọn sao lưu linh hoạt: "Có kèm toàn bộ ảnh" hoặc "Chỉ sao lưu dữ liệu văn bản".
     - Trong `manifest.json`: Lưu thông tin `formatVersion: 1`, `schemaVersion`, `appVersion`, `createdAt`, thống kê số lượng (`customersCount`, `savedLocationsCount`, `shiftsCount`, `photosCount`), và mã băm SHA-256 đối soát cho từng file bên trong.
   - **Chia sẻ hệ thống:** Sử dụng thư viện `share_plus` để mở Share Sheet của hệ điều hành (cho phép lưu vào máy, gửi qua Zalo, Telegram, Google Drive,...).
2. **Khôi Phục Toàn Vẹn & An Toàn Tuyệt Đối (Restore Service):**
   - Chọn file `.zip` qua `file_picker`.
   - Kiểm tra tính toàn vẹn: Giải nén kiểm tra cấu trúc, đối soát SHA-256 từng file (từ chối ngay lập tức nếu file bị hỏng hoặc có dấu hiệu giả mạo/chỉnh sửa trái phép), kiểm tra phiên bản schema (từ chối file có phiên bản mới hơn phiên bản app hỗ trợ).
   - **Chống tấn công Path Traversal:** Kiểm duyệt tên file trong zip, từ chối mọi file chứa `../` hoặc ghi đè ra ngoài thư mục ứng dụng.
   - Hiển thị màn hình xem trước (Preview) chi tiết số lượng khách hàng, vị trí, ca, ảnh trước khi tiến hành.
   - **2 chế độ khôi phục:**
     - **"Gộp vào dữ liệu hiện có" (Merge):** Dữ liệu khách hàng trùng SĐT được giữ nguyên phiên bản hiện tại, chỉ bổ sung khách mới, vị trí và ảnh tương ứng. Báo cáo minh bạch số lượng khách đã thêm và số lượng bỏ qua.
     - **"Thay toàn bộ dữ liệu" (Full Replace):** Tự động tạo bản sao lưu an toàn (`pre_restore_backup_*.zip`) trước khi ghi đè để có thể hoàn nguyên nếu cần; yêu cầu shipper xác nhận rõ ràng; thực thi toàn bộ trong một Transaction an toàn.
3. **Nhắc Nhở Sao Lưu Định Kỳ (Backup Reminder):**
   - Lưu thời điểm sao lưu thành công gần nhất vào `app_meta` (`last_backup_at`).
   - Nếu đã quá 14 ngày kể từ lần sao lưu gần nhất (và trong SQLite đã có dữ liệu khách hoặc vị trí), hiển thị thẻ nhắc nhở màu vàng nhẹ nhàng ở đầu tab "Cá nhân" kèm nút "Sao lưu ngay", hoàn toàn không làm phiền ở các màn hình tác nghiệp khác.

---

## 11. Tái Cấu Trúc Toàn Diện & Phân Lập Chế Độ Máy Chủ (TASK: LOCAL-FIRST-08-REFACTOR-AND-CLEANUP)

### 11.1. Mục Tiêu & Kết Quả Tái Cấu Trúc

1. **Chuẩn Hóa Kích Thước Tệp & Hàm Build:**
   - Đạt tiêu chuẩn cấu trúc: không có màn hình hoạt động nào vượt quá 500 dòng (ngoại lệ duy nhất là các tệp SQL schema / queries lớn hoặc DTO serialization).
   - Không còn phương thức `build()` nào vượt quá 150 dòng; tất cả logic dựng giao diện phức tạp đã được chia nhỏ thành các `StatelessWidget` độc lập.
   - Toàn bộ 222 bài kiểm thử tự động tiếp tục duy trì trạng thái **PASS 100%**, `flutter analyze` báo cáo **0 cảnh báo / 0 lỗi**.
   - Chi tiết phân tích số dòng mã trước và sau xem tại [docs/CODE_STRUCTURE.md](file:///d:/flutter%20create%20delivery_marker_app/docs/CODE_STRUCTURE.md).

2. **Cấu Trúc Thư Mục Feature-First:**
   - `lib/core/`: Các cấu hình chung, nút bấm `AppButtons`, và bộ tiện ích mật mã/chuẩn hóa.
   - `lib/data/`:
     - `local/`: SQLite CSDL cục bộ, sao lưu phục hồi, cache tile bản đồ và các repository cục bộ.
     - `remote/`: Trình HTTP `ApiClient`, 7 module API chuyên biệt (`auth_api`, `customer_api`, `location_api`, `photo_api`, `shift_api`, `sharing_api`, `geocoding_api`), facade `ApiService`, các repository từ xa và dịch vụ đệm `OfflineStorageService`.
     - `repositories/`: Các interfaces trừu tượng và DI Provider.
   - `lib/models/`: Mô hình dữ liệu thực thể DTOs.
   - `lib/features/`: Các mô-đun nghiệp vụ độc lập (`map/`, `directory/`, `shifts/`, `photos/`, `sharing/`, `profile/`, `onboarding_lock/`, `server_mode/`).
   - `lib/shared_widgets/`: Các widget dùng chung giữa các phân hệ.

---

### 11.2. Hướng Dẫn Tái Kích Hoạt Chế Độ Kết Nối Máy Chủ (Re-enabling Server Mode)

Toàn bộ mã nguồn phục vụ kết nối hệ thống máy chủ trung tâm (`backend/`) được **bảo toàn nguyên vẹn 100%**, không bị xóa bỏ, và được cô lập tại:
- Giao diện người dùng Server Mode: `lib/features/server_mode/` ([login_view.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/features/server_mode/login_view.dart), [change_password_view.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/features/server_mode/change_password_view.dart), [data_sharing_view.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/features/server_mode/data_sharing_view.dart), [delivery_map_view.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/features/server_mode/delivery_map_view.dart), [order_list_view.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/features/server_mode/order_list_view.dart), [order_detail_view.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/features/server_mode/order_detail_view.dart), [save_location_view.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/features/server_mode/save_location_view.dart)).
- Tầng giao tiếp từ xa Server Mode: `lib/data/remote/` ([api_client.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/data/remote/api_client.dart), [api_service.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/data/remote/api_service.dart), các `*_api.dart`, `remote_*_repository.dart`, [offline_storage_service.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/data/remote/offline_storage_service.dart)).

Để chuyển đổi ứng dụng chạy sang chế độ Server Mode:

1. **Chuyển cờ RepositoryProvider sang Remote:**
   Trong [lib/data/repositories/repository_provider.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/data/repositories/repository_provider.dart):
   ```dart
   // Chuyển useLocalData thành false để kích hoạt các Remote*Repository
   static bool useLocalData = false;
   ```
   Hoặc cấu hình qua biến môi trường `--dart-define=LOCAL_DATA=false`.

2. **Kích hoạt màn hình Đăng nhập máy chủ:**
   Trong [lib/main.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/main.dart), tại lớp `AuthSplashScreen`, chuyển hướng người dùng chưa đăng nhập về màn hình [LoginView](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/features/server_mode/login_view.dart) thay vì vào thẳng [WelcomeOnboardingView](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/features/onboarding_lock/welcome_onboarding_view.dart).

3. **Cấu hình địa chỉ máy chủ Backend:**
   Sử dụng [ApiClient.setCustomBaseUrl()](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/data/remote/api_client.dart) hoặc màn hình cấu hình máy chủ trong [profile_server_config_dialog.dart](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/features/profile/widgets/profile_server_config_dialog.dart) để trỏ ứng dụng tới IP máy chủ backend nội bộ hoặc trên đám mây.


### 10.1. Mô Hình Chia Sẻ Ngang Hàng (P2P Data Sharing Model)
1. **Quyền Riêng Tư & Cảnh Báo Không Thể Thu Hồi (Irrevocable Disclosure):**
   - Không qua máy chủ trung gian, dữ liệu được truyền thẳng giữa các thiết bị người dùng.
   - Hiển thị dòng cảnh báo cố định và nổi bật trên giao diện gửi:
     > *"Dữ liệu chứa số điện thoại và địa chỉ khách. Đã gửi thì không thu hồi được. Chỉ gửi cho người bạn tin tưởng."*
2. **Phạm Vi Chia Sẻ Linh Hoạt (Export Scopes):**
   - **Tất cả điểm đã lưu:** Toàn bộ điểm trong bảng `saved_locations`.
   - **Một ca làm việc:** Các điểm thuộc ca giao hàng được lựa chọn từ danh sách ca.
   - **Các điểm tôi chọn:** Cho phép tích chọn các điểm cụ thể.
   - **Chia sẻ nhanh 1 điểm:** Nút bấm tiện lợi trên [PointDetailBottomSheet](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/widgets/point_detail_bottom_sheet.dart) và [CustomerDetailEditView](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/views/customer_directory_view.dart).
3. **Công Tắc Kiểm Soát Dữ Liệu (Privacy Toggles):**
   - **"Kèm ảnh nhà":** Mặc định TẮT khi tạo mã QR (do giới hạn dung lượng QR), có thể BẬT khi xuất file `.dshare`. Sử dụng ảnh nén tối ưu (1600px).
   - **"Kèm tên và địa chỉ khách":** Mặc định BẬT; cho phép người dùng TẮT để giảm thiểu thông tin cá nhân được chia sẻ theo nguyên tắc bảo vệ quyền riêng tư.
4. **Cấu Trúc Điểm Chia Sẻ ([SharedPointPayload](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/models/local_share_models.dart)):**
   - Chuẩn hóa số điện thoại theo chuẩn Việt Nam (`PhoneUtils.normalizeCustomerPhone`).
   - Tên khách hàng, địa chỉ, tọa độ (vĩ độ, kinh độ, độ chính xác GPS), ghi chú giao hàng.
   - Thông tin người gửi (`senderName` lấy từ `app_profile.display_name`), thời điểm tạo, phiên bản schema.
   - **Bảo mật:** Triệt để KHÔNG xuất ID nội bộ SQLite, không chứa `activity_log`, không chứa `location_history`.

---

### 10.2. Định Dạng Gói Tin `.dshare` & Bảo Vệ Mật Mã
1. **Định Dạng Gói Tin `.dshare`:**
   - Bản chất là tệp nén ZIP gồm:
     - `manifest.json`: Chứa metadata, số lượng điểm, số ảnh, cờ mã hóa, checksum SHA-256 của từng tệp.
     - `points.json` (hoặc `points.enc` nếu được mã hóa): Danh sách các điểm chia sẻ.
     - Thư mục `photos/`: Chứa các ảnh mặt tiền nhà đi kèm tương ứng.
   - Chia sẻ qua Share Sheet hệ thống (`share_plus`) tới Zalo, Telegram, Google Drive, hoặc lưu vào bộ nhớ máy.
2. **Mã Hóa Bằng Mật Khẩu Tùy Chọn ([ShareCryptoUtils](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/utils/share_crypto_utils.dart)):**
   - Thuật toán chuẩn bảo mật AES-GCM 256-bit kết hợp Salt ngẫu nhiên 16 bytes.
   - Dẫn xuất khóa mật mã từ mật khẩu qua PBKDF2 HMAC-SHA256 (10,000 vòng lặp).
   - Cảnh báo người dùng minh bạch: *"Mất mật khẩu sẽ không thể mở và khôi phục nội dung gói chia sẻ."*

---

### 10.3. Chia Sẻ Bằng Chuỗi Mã QR Đa Mảnh (Multi-Chunk QR Codes)
1. **Giới Hạn & Tối Ưu Nén Dữ Liệu:**
   - Dành riêng cho gói dữ liệu nhỏ không kèm ảnh.
   - Nén luồng dữ liệu bằng GZip + Base64Url để tối đa dung lượng tải trọng (payload density).
   - Tự động chia nhỏ thành các mảnh (chunk) an toàn kích thước tối đa 1.2KB cho mỗi mã QR.
   - Định dạng giao thức mảnh: `DSHARE:<chunk_index>:<total_chunks>:<checksum8>:<chunk_data>`.
2. **Hiển Thị & Điều Hướng Mã QR ([DataShareQrView](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/widgets/data_share_qr_view.dart)):**
   - Render mã QR cỡ lớn độ tương phản cao bằng thư viện `qr_flutter`.
   - Hiển thị thanh tiến trình mảnh ("Mã 1/N") kèm nút điều hướng chuyển mã kế tiếp/trước đó.
   - Nhắc nhở người dùng tăng độ sáng màn hình điện thoại để bên nhận quét dễ dàng.
3. **Quét & Tích Lũy Mảnh QR ([DataShareQrScannerView](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/widgets/data_share_qr_scanner_view.dart)):**
   - Sử dụng `mobile_scanner` với khung quét máy ảnh và yêu cầu quyền truy cập Camera rõ ràng.
   - Bộ gom mảnh `QrChunkCollector` kiểm tra tính hợp lệ và checksum từng mảnh.
   - Hiển thị số lượng mảnh đã quét và thông báo trực quan nếu còn thiếu mảnh. Tự động hoàn tất và chuyển sang màn hình xem trước ngay khi thu thập đủ 100% các mảnh.

---

### 10.4. Kiểm Duyệt An Toàn & Tiếp Nhận Dữ Liệu (Import & Preview)
1. **Kiểm Soát An Toàn Tuyệt Đối (Security Checks):**
   - **Giới hạn kích thước:** Từ chối tệp vượt quá 50MB hoặc danh sách vượt quá 2000 điểm.
   - **Chống Path Traversal:** Tuyệt đối ngăn chặn giải nén tệp chứa `../` hoặc đường dẫn tuyệt đối ghi đè ra ngoài thư mục ứng dụng.
   - **Kiểm tra phiên bản & đối soát checksum:** Kiểm tra phiên bản schema (từ chối tệp có phiên bản mới hơn app) và mã băm SHA-256.
   - **Validate từng điểm:** Kiểm tra số điện thoại hợp lệ, tọa độ không gian nằm trong dải chuẩn `[-90..90, -180..180]`, độ dài chuỗi ký tự. Điểm lỗi bị cô lập và báo cáo chi tiết lý do, không làm gián đoạn toàn bộ gói.
2. **Màn Hình Xem Trước Minh Bạch ([DataShareImportPreviewSheet](file:///d:/flutter%20create%20delivery_marker_app/mobile_app/lib/widgets/data_share_import_preview_sheet.dart)):**
   - Tiêu đề thông tin: *"Từ [tên người gửi], N điểm, M ảnh"*.
   - Phân loại trực quan từng điểm nhận được:
     - 🟢 **MỚI:** Khách hàng chưa có trong danh bạ trên máy.
     - 🟡 **TRÙNG SĐT (Chưa có vị trí):** Khách hàng đã có nhưng chưa lưu tọa độ định vị.
     - 🟠 **TRÙNG SĐT (Đã có vị trí):** Khách hàng đã có tọa độ trên máy; tính và hiển thị khoảng cách địa lý chính xác giữa 2 tọa độ (ví dụ: `Cách vị trí hiện tại: 120m`).
   - Cho phép người dùng tích chọn lọc từng điểm muốn nhận hoặc bỏ qua.
3. **Chế Độ Tiếp Nhận Dữ Liệu:**
   - **"Chỉ thêm điểm mới" (Mặc định):** Bỏ qua các điểm trùng SĐT đã có vị trí để tránh ghi đè âm thầm.
   - **"Thay vị trí cũ bằng vị trí nhận được":** Có cảnh báo xác nhận. Tọa độ cũ tự động lưu vết vào `location_history` thông qua Trigger SQLite của CSDL, đảm bảo toàn vẹn kiểm toán.
   - **Tùy chọn "Nhập thành một ca mới":** Tự động tạo ca mới mang tên `Từ [Người gửi] dd/MM` và gắn các điểm đã nhận vào ca ở trạng thái `VERIFIED`.
4. **An Toàn Giao Dịch & Kiểm Toán:**
   - Thực thi toàn bộ quá trình nhập trong một Transaction SQLite duy nhất; nếu lỗi giữa chừng, toàn bộ giao dịch được hoàn nguyên (Rollback) và dọn sạch các file ảnh vừa giải nén tạm.
   - Ghi hoạt động vào `activity_log` với số lượng bản ghi đã thêm / thay thế / bỏ qua (TUYỆT ĐỐI không ghi số điện thoại hay địa chỉ khách).
5. **Giao Diện & Tích Hợp Hệ Điều Hành:**
   - Khối "Chia sẻ dữ liệu" trong Tab "Cá nhân" với 2 nút lớn: "GỬI DỮ LIỆU" và "NHẬN DỮ LIỆU".
   - Khai báo `<intent-filter>` trong `AndroidManifest.xml` hỗ trợ mở trực tiếp tệp `.dshare`.





