# Data Layer

Tầng quản lý dữ liệu toàn diện của ứng dụng di động:

- **`local/`**: Lưu trữ cục bộ SQLite (`AppDatabase`), các repository cục bộ (`Local*Repository`), dịch vụ sao lưu (`BackupService`) và bộ nhớ đệm tile bản đồ OSM (`MapTileCacheService`).
- **`remote/`**: Tầng giao tiếp mạng dành cho chế độ kết nối máy chủ backend (`ApiClient`, `*Api`, `ApiService`), lưu trữ đệm máy chủ cũ (`OfflineStorageService`) và các repository từ xa (`Remote*Repository`).
- **`repositories/`**: Các giao diện trừu tượng (`*Repository`) định nghĩa hợp đồng nghiệp vụ và bộ cung cấp phụ thuộc (`RepositoryProvider`).

