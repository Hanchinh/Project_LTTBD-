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
    'CREATE INDEX IF NOT EXISTS idx_customers_search_text ON customers(search_text);',
    'CREATE INDEX IF NOT EXISTS idx_customers_deleted_at ON customers(deleted_at);',
  ];

  // 2. saved_locations: Tọa độ cổng nhà đã xác minh (VERIFIED) của khách
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
      FOREIGN KEY (customer_id) REFERENCES customers(id)
    );
  ''';
  static const List<String> savedLocationsIndexes = [
    'CREATE INDEX IF NOT EXISTS idx_saved_locations_coords ON saved_locations(latitude, longitude);',
    'CREATE INDEX IF NOT EXISTS idx_saved_locations_customer ON saved_locations(customer_id);',
  ];

  // 3. customer_photos: Ảnh chụp định vị nhà khách hàng
  static const String createCustomerPhotosTable = '''
    CREATE TABLE IF NOT EXISTS customer_photos (
      id TEXT PRIMARY KEY,
      customer_id TEXT NOT NULL,
      file_path TEXT NOT NULL,
      file_size INTEGER NOT NULL,
      is_primary INTEGER NOT NULL DEFAULT 0,
      caption TEXT,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      deleted_at TEXT,
      FOREIGN KEY (customer_id) REFERENCES customers(id)
    );
  ''';
  static const List<String> customerPhotosIndexes = [
    'CREATE INDEX IF NOT EXISTS idx_customer_photos_customer ON customer_photos(customer_id);',
    'CREATE INDEX IF NOT EXISTS idx_customer_photos_deleted ON customer_photos(deleted_at);',
  ];

  // 4. shifts: Ca làm việc của shipper
  static const String createShiftsTable = '''
    CREATE TABLE IF NOT EXISTS shifts (
      id TEXT PRIMARY KEY,
      shift_code TEXT NOT NULL UNIQUE,
      work_date TEXT NOT NULL,
      status TEXT NOT NULL DEFAULT 'CREATED',
      notes TEXT,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      deleted_at TEXT
    );
  ''';
  static const List<String> shiftsIndexes = [
    'CREATE INDEX IF NOT EXISTS idx_shifts_date ON shifts(work_date);',
    'CREATE INDEX IF NOT EXISTS idx_shifts_status ON shifts(status);',
  ];

  // 5. shift_delivery_points: Điểm giao hàng thuộc ca
  static const String createShiftDeliveryPointsTable = '''
    CREATE TABLE IF NOT EXISTS shift_delivery_points (
      id TEXT PRIMARY KEY,
      shift_id TEXT NOT NULL,
      customer_id TEXT NOT NULL,
      sequence_number INTEGER NOT NULL,
      location_status TEXT NOT NULL,
      latitude REAL,
      longitude REAL,
      location_notes TEXT,
      delivery_status TEXT NOT NULL DEFAULT 'PENDING',
      delivery_notes TEXT,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      FOREIGN KEY (shift_id) REFERENCES shifts(id) ON DELETE CASCADE,
      FOREIGN KEY (customer_id) REFERENCES customers(id)
    );
  ''';
  static const List<String> shiftDeliveryPointsIndexes = [
    'CREATE INDEX IF NOT EXISTS idx_shift_points_shift ON shift_delivery_points(shift_id);',
    'CREATE INDEX IF NOT EXISTS idx_shift_points_customer ON shift_delivery_points(customer_id);',
    'CREATE INDEX IF NOT EXISTS idx_shift_points_coords ON shift_delivery_points(latitude, longitude);',
  ];

  // 6. location_history: Lịch sử thay đổi tọa độ của khách
  static const String createLocationHistoryTable = '''
    CREATE TABLE IF NOT EXISTS location_history (
      id TEXT PRIMARY KEY,
      customer_id TEXT NOT NULL,
      latitude REAL NOT NULL,
      longitude REAL NOT NULL,
      change_type TEXT NOT NULL,
      actor TEXT,
      created_at TEXT NOT NULL,
      FOREIGN KEY (customer_id) REFERENCES customers(id)
    );
  ''';
  static const List<String> locationHistoryIndexes = [
    'CREATE INDEX IF NOT EXISTS idx_location_history_customer ON location_history(customer_id);',
  ];

  // 7. app_profile: Hồ sơ người dùng cục bộ (duy nhất id = 1)
  static const String createAppProfileTable = '''
    CREATE TABLE IF NOT EXISTS app_profile (
      id INTEGER PRIMARY KEY CHECK (id = 1),
      display_name TEXT NOT NULL DEFAULT 'Người giao hàng',
      pin_hash TEXT,
      pin_timeout_seconds INTEGER NOT NULL DEFAULT 300,
      last_active_at TEXT,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    );
  ''';

  // 8. app_meta: Cài đặt và cờ ứng dụng dạng key-value
  static const String createAppMetaTable = '''
    CREATE TABLE IF NOT EXISTS app_meta (
      key TEXT PRIMARY KEY,
      value TEXT NOT NULL,
      updated_at TEXT NOT NULL
    );
  ''';

  // 9. activity_logs: Nhật ký hoạt động cục bộ
  static const String createActivityLogsTable = '''
    CREATE TABLE IF NOT EXISTS activity_logs (
      id TEXT PRIMARY KEY,
      action TEXT NOT NULL,
      entity_type TEXT NOT NULL,
      entity_id TEXT,
      details TEXT,
      created_at TEXT NOT NULL
    );
  ''';
  static const List<String> activityLogsIndexes = [
    'CREATE INDEX IF NOT EXISTS idx_activity_logs_created ON activity_logs(created_at);',
  ];

  // Migration v2: Các chỉ mục bổ sung tối ưu hiệu năng
  static const List<String> v2Indexes = [
    'CREATE INDEX IF NOT EXISTS idx_customers_deleted_updated ON customers(deleted_at, updated_at DESC);',
    'CREATE INDEX IF NOT EXISTS idx_shift_points_status ON shift_delivery_points(location_status);',
    'CREATE INDEX IF NOT EXISTS idx_customer_photos_active ON customer_photos(customer_id, deleted_at, created_at DESC);',
    'CREATE INDEX IF NOT EXISTS idx_customer_photos_deleted_at ON customer_photos(deleted_at);',
  ];
}
