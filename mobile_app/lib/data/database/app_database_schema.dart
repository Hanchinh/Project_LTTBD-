/// Lược đồ cơ sở dữ liệu SQLite cục bộ (Local-First Schema)
/// Chứa các hằng số DDL tạo bảng và chỉ mục tối ưu hóa hiệu năng truy vấn.
class AppDatabaseSchema {
  // 1. customers: Hồ sơ khách hàng độc lập của shipper
  static const String createCustomersTable = '''
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
  ''';
  static const List<String> customersIndexes = [
    'CREATE INDEX IF NOT EXISTS idx_customers_phone ON customers(phone_number);',
    'CREATE INDEX IF NOT EXISTS idx_customers_search ON customers(search_text);',
    'CREATE INDEX IF NOT EXISTS idx_customers_deleted ON customers(deleted_at);',
  ];

  // 2. saved_locations: Mốc tọa độ chuẩn của từng khách hàng (1-1)
  static const String createSavedLocationsTable = '''
    CREATE TABLE IF NOT EXISTS saved_locations (
      id TEXT PRIMARY KEY,
      customer_id TEXT NOT NULL UNIQUE,
      latitude REAL NOT NULL,
      longitude REAL NOT NULL,
      gps_accuracy REAL,
      identification_notes TEXT,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      FOREIGN KEY (customer_id) REFERENCES customers(id) ON DELETE CASCADE
    );
  ''';
  static const List<String> savedLocationsIndexes = [
    'CREATE INDEX IF NOT EXISTS idx_saved_locations_customer ON saved_locations(customer_id);',
    'CREATE INDEX IF NOT EXISTS idx_saved_locations_lat_lng ON saved_locations(latitude, longitude);',
  ];

  // 3. customer_photos: Ảnh thực tế của mốc nhà
  static const String createCustomerPhotosTable = '''
    CREATE TABLE IF NOT EXISTS customer_photos (
      id TEXT PRIMARY KEY,
      customer_id TEXT NOT NULL,
      file_path TEXT NOT NULL,
      file_size_bytes INTEGER,
      taken_at TEXT,
      caption TEXT,
      created_at TEXT NOT NULL,
      deleted_at TEXT,
      FOREIGN KEY (customer_id) REFERENCES customers(id) ON DELETE CASCADE
    );
  ''';
  static const List<String> customerPhotosIndexes = [
    'CREATE INDEX IF NOT EXISTS idx_customer_photos_customer ON customer_photos(customer_id);',
    'CREATE INDEX IF NOT EXISTS idx_customer_photos_deleted ON customer_photos(deleted_at);',
  ];

  // 4. location_history: Nhật ký lưu vết thay đổi tọa độ
  static const String createLocationHistoryTable = '''
    CREATE TABLE IF NOT EXISTS location_history (
      id TEXT PRIMARY KEY,
      customer_id TEXT NOT NULL,
      latitude REAL NOT NULL,
      longitude REAL NOT NULL,
      gps_accuracy REAL,
      identification_notes TEXT,
      source TEXT NOT NULL,
      created_at TEXT NOT NULL
    );
  ''';
  static const List<String> locationHistoryIndexes = [
    'CREATE INDEX IF NOT EXISTS idx_location_history_customer ON location_history(customer_id);',
    'CREATE INDEX IF NOT EXISTS idx_location_history_created ON location_history(created_at);',
  ];

  // 5. shifts: Ca giao hàng
  static const String createShiftsTable = '''
    CREATE TABLE IF NOT EXISTS shifts (
      id TEXT PRIMARY KEY,
      shift_code TEXT NOT NULL UNIQUE,
      shift_name TEXT,
      work_date TEXT NOT NULL,
      status TEXT NOT NULL DEFAULT 'PREPARING',
      started_at TEXT,
      completed_at TEXT,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    );
  ''';
  static const List<String> shiftsIndexes = [
    'CREATE INDEX IF NOT EXISTS idx_shifts_date ON shifts(work_date);',
    'CREATE INDEX IF NOT EXISTS idx_shifts_status ON shifts(status);',
  ];

  // 6. shift_delivery_points: Danh sách điểm dừng trong ca
  static const String createShiftDeliveryPointsTable = '''
    CREATE TABLE IF NOT EXISTS shift_delivery_points (
      id TEXT PRIMARY KEY,
      shift_id TEXT NOT NULL,
      customer_id TEXT NOT NULL,
      delivery_order_index INTEGER NOT NULL DEFAULT 0,
      delivery_status TEXT NOT NULL DEFAULT 'PENDING',
      location_status TEXT NOT NULL DEFAULT 'NO_LOCATION',
      latitude REAL,
      longitude REAL,
      gps_accuracy REAL,
      identification_notes TEXT,
      delivered_at TEXT,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      FOREIGN KEY (shift_id) REFERENCES shifts(id) ON DELETE CASCADE,
      FOREIGN KEY (customer_id) REFERENCES customers(id)
    );
  ''';
  static const List<String> shiftDeliveryPointsIndexes = [
    'CREATE INDEX IF NOT EXISTS idx_shift_points_shift ON shift_delivery_points(shift_id);',
    'CREATE INDEX IF NOT EXISTS idx_shift_points_customer ON shift_delivery_points(customer_id);',
    'CREATE INDEX IF NOT EXISTS idx_shift_points_order ON shift_delivery_points(shift_id, delivery_order_index);',
  ];

  // 7. app_profile: Hồ sơ người dùng máy đơn
  static const String createAppProfileTable = '''
    CREATE TABLE IF NOT EXISTS app_profile (
      id INTEGER PRIMARY KEY CHECK (id = 1),
      display_name TEXT NOT NULL DEFAULT 'Người giao hàng',
      pin_hash TEXT,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    );
  ''';

  // 8. activity_log: Nhật ký hoạt động kiểm toán
  static const String createActivityLogTable = '''
    CREATE TABLE IF NOT EXISTS activity_log (
      id TEXT PRIMARY KEY,
      action TEXT NOT NULL,
      entity TEXT NOT NULL,
      entity_id TEXT,
      details_json TEXT,
      created_at TEXT NOT NULL
    );
  ''';
  static const List<String> activityLogIndexes = [
    'CREATE INDEX IF NOT EXISTS idx_activity_log_action ON activity_log(action);',
    'CREATE INDEX IF NOT EXISTS idx_activity_log_created ON activity_log(created_at);',
  ];

  // 9. app_meta: Lưu cấu hình key-value nội bộ
  static const String createAppMetaTable = '''
    CREATE TABLE IF NOT EXISTS app_meta (
      key TEXT PRIMARY KEY,
      value TEXT NOT NULL
    );
  ''';
}
