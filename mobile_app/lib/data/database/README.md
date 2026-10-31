# data/database
Quản lý kết nối SQLite, schema và migration phiên bản CSDL.

- `app_database.dart`: Quản lý mở CSDL SQLite, cấu hình WAL và transaction an toàn.
- `app_database_schema.dart`: Định nghĩa DDL các bảng dữ liệu, chỉ mục và trigger lịch sử.
- `app_database_migrations.dart`: Xử lý nâng cấp schema (`migrationV1`, ...) khi cập nhật app.
