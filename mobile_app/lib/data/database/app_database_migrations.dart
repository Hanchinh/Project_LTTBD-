// Quản lý tiến trình nâng cấp cấu trúc cơ sở dữ liệu SQLite (Database Migrations).
// Thực thi các kịch bản chuyển đổi schema an toàn khi ứng dụng cập nhật phiên bản.
import 'package:sqflite/sqflite.dart';

/// Quản lý việc thực thi tạo bảng (v1) và nâng cấp phiên bản lược đồ CSDL (v2+)
class AppDatabaseMigrations {
  /// Lược đồ cơ sở dữ liệu phiên bản 1 (v1)
  static Future<void> migrationV1(DatabaseExecutor db) async {
    // 1. customers: Hồ sơ khách hàng độc lập của shipper
    await db.execute('''
      CREATE TABLE IF NOT EXISTS customers (
        id TEXT PRIMARY KEY,
        customer_code TEXT,
        full_name TEXT NOT NULL,
        phone_number TEXT NOT NULL UNIQUE,
        address_text TEXT,
        notes TEXT,
        search_text TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        deleted_at TEXT
      );
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_customers_phone ON customers(phone_number);');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_customers_search_text ON customers(search_text);');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_customers_deleted_at ON customers(deleted_at);');

    // 2. saved_locations: Tọa độ cổng nhà đã xác minh (VERIFIED) của khách
    await db.execute('''
      CREATE TABLE IF NOT EXISTS saved_locations (
        id TEXT PRIMARY KEY,
        customer_id TEXT NOT NULL UNIQUE,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        gps_accuracy REAL,
        identification_notes TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (customer_id) REFERENCES customers(id)
      );
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_saved_locations_coords ON saved_locations(latitude, longitude);');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_saved_locations_customer_id ON saved_locations(customer_id);');

    // 3. location_history: Lịch sử thay đổi tọa độ khách hàng (bảo toàn đối soát)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS location_history (
        id TEXT PRIMARY KEY,
        saved_location_id TEXT,
        customer_id TEXT NOT NULL,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        gps_accuracy REAL,
        identification_notes TEXT,
        change_reason TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (saved_location_id) REFERENCES saved_locations(id) ON DELETE SET NULL,
        FOREIGN KEY (customer_id) REFERENCES customers(id)
      );
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_location_history_customer_id ON location_history(customer_id);');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_location_history_saved_location_id ON location_history(saved_location_id);');

    // 4. Trigger SQLite: Tự động ghi nhận lịch sử khi cập nhật tọa độ hoặc ghi chú
    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS trg_saved_locations_history
      AFTER UPDATE ON saved_locations
      FOR EACH ROW
      WHEN (
        OLD.latitude IS NOT NEW.latitude OR
        OLD.longitude IS NOT NEW.longitude OR
        OLD.identification_notes IS NOT NEW.identification_notes
      )
      BEGIN
        INSERT INTO location_history (
          id,
          saved_location_id,
          customer_id,
          latitude,
          longitude,
          gps_accuracy,
          identification_notes,
          change_reason,
          created_at
        ) VALUES (
          lower(hex(randomblob(4))) || '-' || lower(hex(randomblob(2))) || '-4' || substr(lower(hex(randomblob(2))), 2) || '-a' || substr(lower(hex(randomblob(2))), 2) || '-' || lower(hex(randomblob(6))),
          OLD.id,
          OLD.customer_id,
          OLD.latitude,
          OLD.longitude,
          OLD.gps_accuracy,
          OLD.identification_notes,
          'Cập nhật thông tin vị trí cũ sang vị trí mới',
          strftime('%Y-%m-%dT%H:%M:%fZ', 'now')
        );
      END;
    ''');

    // 5. customer_photos: Metadata ảnh mặt tiền nhà (lưu file trong bộ nhớ thiết bị)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS customer_photos (
        id TEXT PRIMARY KEY,
        customer_id TEXT NOT NULL,
        file_name TEXT NOT NULL,
        thumb_file_name TEXT,
        created_at TEXT NOT NULL,
        deleted_at TEXT,
        FOREIGN KEY (customer_id) REFERENCES customers(id)
      );
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_customer_photos_customer_id ON customer_photos(customer_id);');

    // 6. shifts: Ca làm việc của người dùng
    await db.execute('''
      CREATE TABLE IF NOT EXISTS shifts (
        id TEXT PRIMARY KEY,
        shift_code TEXT NOT NULL,
        shift_name TEXT,
        work_date TEXT NOT NULL,
        status TEXT NOT NULL CHECK(status IN ('PREPARING', 'IN_PROGRESS', 'COMPLETED')),
        started_at TEXT,
        completed_at TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_shifts_work_date ON shifts(work_date);');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_shifts_status ON shifts(status);');

    // 7. shift_delivery_points: Điểm giao hàng trong ca (chứa tọa độ TEMPORARY riêng của ca)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS shift_delivery_points (
        id TEXT PRIMARY KEY,
        shift_id TEXT NOT NULL,
        customer_id TEXT NOT NULL,
        delivery_order_index INTEGER NOT NULL DEFAULT 0,
        location_status TEXT NOT NULL CHECK(location_status IN ('NO_LOCATION', 'TEMPORARY', 'VERIFIED')),
        latitude REAL,
        longitude REAL,
        gps_accuracy REAL,
        identification_notes TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (shift_id) REFERENCES shifts(id) ON DELETE CASCADE,
        FOREIGN KEY (customer_id) REFERENCES customers(id),
        UNIQUE(shift_id, customer_id)
      );
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_shift_points_shift_id ON shift_delivery_points(shift_id);');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_shift_points_customer_id ON shift_delivery_points(customer_id);');

    // 8. app_profile: Hồ sơ người dùng cục bộ (duy nhất 1 dòng id=1)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS app_profile (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        display_name TEXT NOT NULL,
        pin_hash TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );
    ''');

    // 9. app_meta: Cài đặt và metadata hệ thống
    await db.execute('''
      CREATE TABLE IF NOT EXISTS app_meta (
        key TEXT PRIMARY KEY,
        value TEXT
      );
    ''');

    // 10. activity_log: Nhật ký hoạt động cục bộ (thay cho audit_logs, không ghi dữ liệu nhạy cảm)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS activity_log (
        id TEXT PRIMARY KEY,
        action TEXT NOT NULL,
        entity TEXT NOT NULL,
        entity_id TEXT,
        details_json TEXT,
        created_at TEXT NOT NULL
      );
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_activity_log_created_at ON activity_log(created_at);');
  }

  /// Lược đồ cơ sở dữ liệu phiên bản 2 (v2) - Tối ưu hóa chỉ mục hiệu năng
  static Future<void> migrationV2(DatabaseExecutor db) async {
    await db.execute('CREATE INDEX IF NOT EXISTS idx_customers_deleted_updated ON customers(deleted_at, updated_at DESC);');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_shift_points_status ON shift_delivery_points(location_status);');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_customer_photos_active ON customer_photos(customer_id, deleted_at, created_at DESC);');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_customer_photos_deleted_at ON customer_photos(deleted_at);');
  }
}
