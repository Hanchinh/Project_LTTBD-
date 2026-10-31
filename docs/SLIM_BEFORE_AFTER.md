# BẢNG THEO DÕI THỰC HIỆN SLIM-AND-RESTRUCTURE-011

Nhánh: `testrutgoncode`

## 1. Mốc Đo Lường Trước / Sau (Baseline & Progress)

| Chỉ số | GĐ0 (Mốc ban đầu) | GĐ1 (Gỡ server code) | GĐ2 (Gọn tầng data) | GĐ3 (Gộp widget) | GĐ4 (Sắp xếp thư mục) | GĐ5 (Dễ đọc & Docs) | GĐ6 (Hoàn thành) |
|---|---|---|---|---|---|---|---|
| **Tổng số file .dart (lib/)** | 130 | 128 | 120 | 110 | 114 | - | - |
| **Tổng số dòng code (lib/)** | 19,104 | 18,862 | 19,226 | 19,122 | 19,133 | - | - |
| **File dài nhất (dòng)** | 316 | 316 | 350 | 379 | 379 | - | - |
| **Số test vượt qua (passed)** | 182 | 178 | 178 | 178 | 178 | - | - |
| **Số test bị xóa (lý do)** | 0 | 4 (mã server cũ) | 0 | 0 | 0 | - | - |
| **Kết quả flutter analyze** | No issues found | No issues found | No issues found | No issues found | No issues found | - | - |
| **Kích thước APK release** | (Đo tại GĐ6) | (Đo tại GĐ6) | (Đo tại GĐ6) | (Đo tại GĐ6) | (Đo tại GĐ6) | - | - |

---

## 2. Top 15 File Dài Nhất Tại GĐ0

1. `mobile_app/lib/shared_widgets/point_detail_bottom_sheet.dart`: 316 dòng
2. `mobile_app/lib/data/local/local_customer_repository.dart`: 313 dòng
3. `mobile_app/lib/features/shifts/shift_map_view.dart`: 304 dòng
4. `mobile_app/lib/features/directory/customer_detail_edit_view.dart`: 302 dòng
5. `mobile_app/lib/shared_widgets/bulk_paste_phone_sheet.dart`: 295 dòng
6. `mobile_app/lib/features/map/main_map_view.dart`: 292 dòng
7. `mobile_app/lib/features/sharing/data_share_send_sheet.dart`: 288 dòng
8. `mobile_app/lib/features/directory/customer_directory_view.dart`: 273 dòng
9. `mobile_app/lib/features/sharing/data_share_import_preview_sheet.dart`: 266 dòng
10. `mobile_app/lib/features/shifts/shift_preparation_view.dart`: 263 dòng
11. `mobile_app/lib/shared_widgets/bulk_paste/bulk_paste_input_view.dart`: 262 dòng
12. `mobile_app/lib/features/map/crosshair_location_picker_view.dart`: 255 dòng
13. `mobile_app/lib/shared_widgets/bulk_paste/bulk_paste_shift_result_view.dart`: 253 dòng
14. `mobile_app/lib/features/shifts/shift_list_view.dart`: 251 dòng
15. `mobile_app/lib/features/shifts/widgets/shift_picker_bottom_sheet.dart`: 248 dòng

---

## 3. Nhật Ký Tiến Độ Theo Từng Giai Đoạn

### GĐ0: Thiết Lập Mốc Ban Đầu
- **Nhánh hiện tại:** `testrutgoncode`
- **Git status:** Sạch (clean)
- **Kiểm tra server folders (`backend`, `admin_web`, `init-db`):** Đã sạch trong repo.
- **Flutter analyze:** `No issues found! (ran in 11.7s)`
- **Flutter test:** `182 passed`
- **Tổng dòng lib:** `19,104`
- **Số file .dart:** `130`

### GĐ1: Gỡ Mã Bản Máy Chủ Trong mobile_app
- **Các file và model đã gỡ:**
  - `mobile_app/lib/models/order_model.dart`: Gỡ bỏ hoàn toàn.
  - `mobile_app/lib/models/data_share_model.dart`: Gỡ bỏ (`SharedLocationPointModel` chuyển sang `local_share_models.dart`).
  - `mobile_app/lib/models/user_model.dart`: Gỡ bỏ, thay thế bằng `user_profile.dart` gọn nhẹ cho local-first.
  - `mobile_app/lib/core/utils/map_navigation_helper.dart`: Chuyển sang `mobile_app/lib/core/services/map_navigation_service.dart`.
  - Gỡ các phương thức server cũ không dùng trong `ProfileRepository` (`login`, `logout`, `changePassword`, `getSavedLoginPhone`) và `SharingRepository` (`getOutgoingShares`, `getIncomingShares`, `createShare`, `acceptShare`, `declineShare`, `revokeShare`) và `ShiftRepository` (`getMyShiftOrders`, `addOrderToShift`).
- **Danh sách 4 automated test bị gỡ (thuộc mã server cũ):**
  1. `widget_test.dart`: `OrderModel deserializes correctly with customer and location data` (Kiểm thử serialization của OrderModel máy chủ cũ)
  2. `widget_test.dart`: `Order filtering correctly separates verified location vs unlocated orders` (Kiểm thử logic lọc OrderModel máy chủ)
  3. `widget_test.dart`: `Shift Order Deduplication logic detects existing customer order` (Kiểm thử trùng lặp OrderModel máy chủ)
  4. `local_first_shift_bulk_04_test.dart`: `15. Compatibility: getMyShiftOrders và addOrderToShift ánh xạ mượt mà từ SQLite sang OrderModel` (Kiểm thử 2 hàm adapter tương thích máy chủ)
- **Kết quả sau GĐ1:**
  - **Flutter analyze:** `No issues found! (ran in 2.2s)`
  - **Flutter test:** `178 passed` (182 - 4 = 178, đúng 100%)
  - **Tổng dòng lib:** `18,862` (giảm 242 dòng)
  - **Số file .dart:** `128` (giảm 2 file)

### GĐ2: Tầng Dữ Liệu Gọn (Domain-Driven Structure)
- **Tổ chức lại thư mục theo miền nghiệp vụ:**
  - `data/database/`: `app_database.dart`, `app_database_schema.dart`, `app_database_migrations.dart`.
  - `data/customers/`: `customer_repository.dart` (hợp nhất interface + local implementation), `customer_queries.dart` (gộp customer ops, customer query helpers, customer bulk helpers).
  - `data/locations/`: `location_repository.dart` (hợp nhất interface + local implementation), `location_queries.dart`.
  - `data/shifts/`: `shift_repository.dart` (giữ interface cho Fake trong test), `shift_queries.dart` (thao tác CSDL AppDatabase), `shift_point_ops.dart`, `shift_bulk_helpers.dart`.
  - `data/photos/`: `photo_repository.dart` (hợp nhất interface + local implementation).
  - `data/backup/`: `backup_service.dart` (gộp backup_service và backup_zip_helpers), `app_storage_service.dart`.
  - `data/sharing/`: `sharing_repository.dart`, `sharing_export_ops.dart`, `sharing_import_ops.dart`.
  - `data/profile/`: `profile_repository.dart`.
  - `data/repository_provider.dart`: Cung cấp quyền truy cập toàn cục tới các repository, giữ tương thích `useLocalData`.
  - `core/services/map_tile_cache_service.dart`: Chuyển dịch vụ cache bản đồ về core services.
- **Xóa bỏ các thư mục cũ:** Đã xóa hoàn toàn `data/local/` và `data/repositories/` (loại bỏ 30 file cũ phân tán).
- **Rà soát giới hạn độ dài:** Không có bất kỳ file nào > 400 dòng (file dài nhất là `customer_repository.dart` với 350 dòng).
- **Kết quả sau GĐ2:**
  - **Flutter analyze:** `No issues found! (ran in 2.3s)`
  - **Flutter test:** `178 passed` (100% passed)
  - **Tổng dòng lib:** `19,226`
  - **Số file .dart:** `120` (giảm 8 file so với GĐ1, giảm 10 file so với GĐ0)

### GĐ3: Gộp Widget Lặp / Nhỏ (Widget Consolidation)
- **Các thành phần widget đã gộp và xóa gọn:**
  1. `profile_about_section.dart` (78 dòng) -> Gộp trực tiếp vào `features/profile/account_profile_view.dart`. Xóa file rời.
  2. `profile_stats_card.dart` (83 dòng) -> Đã kiểm tra qua `git grep` chứng minh không còn nơi nào sử dụng (dead code) -> Xóa bỏ an toàn.
  3. `directory_state_views.dart` (76 dòng) -> Gộp trực tiếp vào `features/directory/customer_directory_view.dart`. Xóa file rời.
  4. `fixed_crosshair_target.dart` (49 dòng) -> Gộp trực tiếp vào `features/map/crosshair_location_picker_view.dart`. Xóa file rời.
  5. `saved_location_detail_card.dart`, `out_of_area_banner.dart`, `map_legend.dart` (tổng 150 dòng) -> Gộp thành `features/map/widgets/map_overlay_widgets.dart`. Xóa 3 file cũ.
  6. `share_password_dialog.dart` (61 dòng) -> Gộp trực tiếp vào `features/sharing/data_share_import_preview_sheet.dart` (duy nhất một nơi sử dụng). Xóa file rời.
  7. `shift_delete_dialog.dart` và `shift_rename_dialog.dart` (tổng 110 dòng) -> Gộp thành `features/shifts/widgets/shift_dialogs.dart`. Xóa 2 file cũ.
  8. `shift_point_detail_card.dart` và `shift_map_markers_builder.dart` (tổng 151 dòng) -> Gộp thành `features/shifts/widgets/shift_map_overlay_widgets.dart`. Xóa 2 file cũ.
  9. `bulk_paste_section_header.dart` (39 dòng) -> Đưa về `core/widgets/bulk_section_header.dart` (dùng chung cho danh bạ & ca). Xóa file cũ trong shared_widgets.
  10. `quick_add_area_selector.dart` và `quick_add_optional_fields.dart` (tổng 193 dòng) -> Gộp thành `shared_widgets/quick_add/quick_add_form_fields.dart`. Xóa 2 file cũ.
- **Rà soát độ dài & tính toàn vẹn:**
  - Không có file nào vượt quá 400 dòng (file dài nhất hiện tại là `customer_repository.dart` với 379 dòng, `customer_directory_view.dart` với 376 dòng).
  - Không đổi Key widget, không sửa assert.
- **Kết quả sau GĐ3:**
  - **Flutter analyze:** `No issues found! (ran in 2.7s)`
  - **Flutter test:** `178 passed` (100% passed)
  - **Tổng dòng lib:** `19,122`
  - **Số file .dart:** `110` (giảm 10 file so với GĐ2, giảm 20 file so với GĐ0)

### GĐ4: Sắp Xếp Thư Mục (Folder Cleanliness & Restructure)
- **Tổ chức lại gốc thư mục `lib/` thành chuẩn sạch:**
  - `lib/main.dart`: Chỉ còn là entry point gọi `runApp(const DeliveryLocationMarkerApp())` và export ứng dụng.
  - `lib/app/`: Khung 3 tab (`home_shell_view.dart`), màn hình khởi động (`auth_splash_view.dart`), ứng dụng gốc (`app.dart`), và theme (`theme/app_theme.dart`, `theme/app_buttons.dart`).
  - `lib/core/widgets/`: Di chuyển toàn bộ các widget dùng chung từ `shared_widgets/` về `core/widgets/` (`bulk_paste_phone_sheet.dart`, `point_detail_bottom_sheet.dart`, `quick_add_customer_sheet.dart`, `authenticated_image.dart`, và các thư mục con). Xóa bỏ hoàn toàn thư mục `shared_widgets/`.
  - Cập nhật tự động đường dẫn import từ `package:delivery_marker_mobile/shared_widgets/` sang `package:delivery_marker_mobile/core/widgets/` trên toàn bộ lib và test mà không thay đổi bất kỳ logic hay assert nào.
  - `lib/features/onboarding_lock/`: Đổi tên `pin_lock_screen.dart` -> `pin_lock_view.dart` (kèm typedef tương thích) đồng bộ với chuẩn hậu tố `_view`.
  - Giữ tên thư mục `directory` cho tính năng Danh bạ khách hàng (Customer Directory) để đồng nhất với domain model `CustomerDirectoryModel` và giữ ổn định mã nguồn.
- **Kết quả sau GĐ4:**
  - **Flutter analyze:** `No issues found! (ran in 2.8s)`
  - **Flutter test:** `178 passed` (100% passed)
  - **Tổng dòng lib:** `19,133`
  - **Số file .dart:** `114`


