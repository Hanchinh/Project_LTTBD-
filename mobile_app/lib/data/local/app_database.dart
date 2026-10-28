import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:delivery_marker_mobile/core/utils/uuid_utils.dart';
import 'package:delivery_marker_mobile/core/utils/phone_utils.dart';
import 'package:delivery_marker_mobile/core/utils/vietnamese_utils.dart';

/// Quản lý cơ sở dữ liệu SQLite cục bộ cho kiến trúc Local-First
/// Tách biệt hoàn toàn với delivery_offline_v2.db và hàng đợi đồng bộ cũ.
class AppDatabase {
  static const String databaseFileName = 'local_data_v1.db';
  static const int currentVersion = 1;

  static AppDatabase? _instance;
  static AppDatabase get instance => _instance ??= AppDatabase();

  Database? _db;
  final String? _customPath;
  final DatabaseFactory? _factory;

  AppDatabase({String? customPath, DatabaseFactory? factory})
      : _customPath = customPath,
        _factory = factory;

  /// Getter factory CSDL (nếu được truyền khi khởi tạo)
  DatabaseFactory? get factory => _factory;

  /// Lấy instance kết nối SQLite
  Future<Database> get database async {
    if (_db != null && _db!.isOpen) {
      return _db!;
    }
    _db = await _open();
    return _db!;
  }

  /// Mở CSDL trong bộ nhớ phục vụ kiểm thử đơn vị
  static Future<AppDatabase> openInMemory({DatabaseFactory? factory}) async {
    final appDb = AppDatabase(
      customPath: inMemoryDatabasePath,
      factory: factory,
    );
    await appDb.database;
    return appDb;
  }

  /// Mở CSDL tại đường dẫn chỉ định
  static Future<AppDatabase> openAtPath(String path, {DatabaseFactory? factory}) async {
    final appDb = AppDatabase(
      customPath: path,
      factory: factory,
    );
    await appDb.database;
    return appDb;
  }

  /// Đóng kết nối CSDL
  Future<void> close() async {
    if (_db != null && _db!.isOpen) {
      await _db!.close();
      _db = null;
    }
  }

  /// Reset singleton
  static void reset() {
    _instance = null;
  }

  /// Helper sinh chuỗi thời gian ISO-8601 UTC
  static String currentIsoUtc() => DateTime.now().toUtc().toIso8601String();

  /// Helper sinh UUID v4
  static String generateId() => UuidUtils.generate();

  /// Mở file SQLite với các cấu hình PRAGMA và migration
  Future<Database> _open() async {
    final effectiveFactory = _factory ?? databaseFactory;
    final String path;
    if (_customPath != null) {
      path = _customPath!;
    } else {
      final dbFolder = await effectiveFactory.getDatabasesPath();
      path = p.join(dbFolder, databaseFileName);
    }

    return await effectiveFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: currentVersion,
        onConfigure: (db) async {
          // Bắt buộc bật Foreign Keys trong SQLite theo từng kết nối
          await db.execute('PRAGMA foreign_keys = ON;');
        },
        onCreate: (db, version) async {
          // Chạy tuần tự các bước di chuyển từ 1 đến version
          for (int v = 1; v <= version; v++) {
            final migration = _migrations[v];
            if (migration != null) {
              await migration(db);
            }
          }
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          // Chạy tuần tự các bước di chuyển từ oldVersion + 1 đến newVersion
          for (int v = oldVersion + 1; v <= newVersion; v++) {
            final migration = _migrations[v];
            if (migration != null) {
              await migration(db);
            }
          }
        },
        onOpen: (db) async {
          // Kích hoạt WAL mode nếu là database dạng file
          try {
            await db.rawQuery('PRAGMA journal_mode = WAL;');
          } catch (_) {
            // In-memory có thể không hỗ trợ WAL, bỏ qua an toàn
          }
        },
      ),
    );
  }

  // ===========================================================================
  // HỆ THỐNG MIGRATION THEO PHIÊN BẢN (MIGRATIONS)
  // ===========================================================================

  static final Map<int, Future<void> Function(DatabaseExecutor db)> _migrations = {
    1: migrationV1,
  };

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

  // ===========================================================================
  // LỚP TRUY XUẤT DỮ LIỆU MỨC THẤP (LOW-LEVEL DATA ACCESS LAYER)
  // ===========================================================================

  /// Thực thi giao dịch (Transaction)
  Future<T> transaction<T>(Future<T> Function(Transaction txn) action) async {
    final db = await database;
    return await db.transaction(action);
  }

  // --- Khách hàng (Customers) ---

  /// Thêm khách hàng mới kèm đồng bộ trường tìm kiếm không dấu
  Future<String> insertCustomer({
    String? id,
    String? customerCode,
    required String fullName,
    required String phoneNumber,
    String? addressText,
    String? notes,
  }) async {
    final db = await database;
    final customerId = id ?? generateId();
    final cleanPhone = normalizeCustomerPhone(phoneNumber);
    final now = currentIsoUtc();
    final searchText = buildCustomerSearchText(
      fullName: fullName,
      phoneNumber: cleanPhone,
      addressText: addressText,
      notes: notes,
    );

    await db.insert('customers', {
      'id': customerId,
      'customer_code': customerCode ?? 'CUST-${cleanPhone.length >= 4 ? cleanPhone.substring(cleanPhone.length - 4) : cleanPhone}',
      'full_name': fullName,
      'phone_number': cleanPhone,
      'address_text': addressText,
      'notes': notes,
      'search_text': searchText,
      'created_at': now,
      'updated_at': now,
      'deleted_at': null,
    });

    return customerId;
  }

  /// Cập nhật khách hàng kèm đồng bộ trường tìm kiếm
  Future<int> updateCustomer(
    String id, {
    String? fullName,
    String? phoneNumber,
    String? addressText,
    String? notes,
  }) async {
    final db = await database;
    final current = await getCustomerById(id);
    if (current == null) return 0;

    final newFullName = fullName ?? (current['full_name'] as String);
    final newPhone = phoneNumber != null ? normalizeCustomerPhone(phoneNumber) : (current['phone_number'] as String);
    final newAddress = addressText ?? (current['address_text'] as String?);
    final newNotes = notes ?? (current['notes'] as String?);
    final now = currentIsoUtc();

    final searchText = buildCustomerSearchText(
      fullName: newFullName,
      phoneNumber: newPhone,
      addressText: newAddress,
      notes: newNotes,
    );

    return await db.update(
      'customers',
      {
        'full_name': newFullName,
        'phone_number': newPhone,
        'address_text': newAddress,
        'notes': newNotes,
        'search_text': searchText,
        'updated_at': now,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Lấy khách hàng theo ID
  Future<Map<String, dynamic>?> getCustomerById(String id) async {
    final db = await database;
    final rows = await db.query(
      'customers',
      where: 'id = ? AND deleted_at IS NULL',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isNotEmpty ? rows.first : null;
  }

  /// Lấy khách hàng theo số điện thoại (tự động chuẩn hóa)
  Future<Map<String, dynamic>?> getCustomerByPhone(String phoneNumber) async {
    final db = await database;
    final clean = normalizeCustomerPhone(phoneNumber);
    final rows = await db.query(
      'customers',
      where: 'phone_number = ? AND deleted_at IS NULL',
      whereArgs: [clean],
      limit: 1,
    );
    return rows.isNotEmpty ? rows.first : null;
  }

  /// Tìm kiếm khách hàng theo từ khóa (hỗ trợ không dấu unaccent 2 chiều)
  Future<List<Map<String, dynamic>>> searchCustomers(String query, {int limit = 50, int offset = 0}) async {
    final db = await database;
    final cleanQuery = normalizeSearchQuery(query);

    if (cleanQuery.isEmpty) {
      return await db.query(
        'customers',
        where: 'deleted_at IS NULL',
        orderBy: 'updated_at DESC',
        limit: limit,
        offset: offset,
      );
    }

    final digitsOnly = query.replaceAll(RegExp(r'\D'), '');
    final hasDigits = digitsOnly.length >= 3;

    final whereClause = StringBuffer('deleted_at IS NULL AND (search_text LIKE ?');
    final whereArgs = <dynamic>['%$cleanQuery%'];

    if (hasDigits && digitsOnly != cleanQuery) {
      whereClause.write(' OR search_text LIKE ?');
      whereArgs.add('%$digitsOnly%');
    }
    whereClause.write(')');

    return await db.query(
      'customers',
      where: whereClause.toString(),
      whereArgs: whereArgs,
      orderBy: 'updated_at DESC',
      limit: limit,
      offset: offset,
    );
  }

  /// Xóa mềm khách hàng (đặt deleted_at)
  Future<int> softDeleteCustomer(String id) async {
    final db = await database;
    return await db.update(
      'customers',
      {'deleted_at': currentIsoUtc()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // --- Vị trí đã lưu (Saved Locations) ---

  /// Lưu hoặc cập nhật vị trí đã xác minh (VERIFIED) của khách
  Future<String> setSavedLocation({
    String? id,
    required String customerId,
    required double latitude,
    required double longitude,
    double? gpsAccuracy,
    String? identificationNotes,
  }) async {
    final db = await database;
    final locationId = id ?? generateId();
    final now = currentIsoUtc();

    await db.rawInsert('''
      INSERT INTO saved_locations (id, customer_id, latitude, longitude, gps_accuracy, identification_notes, created_at, updated_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(customer_id) DO UPDATE SET
        latitude = excluded.latitude,
        longitude = excluded.longitude,
        gps_accuracy = excluded.gps_accuracy,
        identification_notes = excluded.identification_notes,
        updated_at = excluded.updated_at
    ''', [
      locationId,
      customerId,
      latitude,
      longitude,
      gpsAccuracy,
      identificationNotes,
      now,
      now,
    ]);

    return locationId;
  }

  /// Lấy vị trí đã lưu theo ID khách hàng
  Future<Map<String, dynamic>?> getSavedLocationByCustomerId(String customerId) async {
    final db = await database;
    final rows = await db.query(
      'saved_locations',
      where: 'customer_id = ?',
      whereArgs: [customerId],
      limit: 1,
    );
    return rows.isNotEmpty ? rows.first : null;
  }

  /// Xóa vị trí đã lưu (kích hoạt ON DELETE SET NULL để bảo toàn lịch sử)
  Future<int> deleteSavedLocation(String id) async {
    final db = await database;
    return await db.delete(
      'saved_locations',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Lấy danh sách vị trí đã lưu trong khung nhìn bản đồ (Bounding Box)
  Future<List<Map<String, dynamic>>> getSavedLocationsInBounds({
    required double minLat,
    required double maxLat,
    required double minLng,
    required double maxLng,
  }) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT sl.*, c.full_name, c.phone_number, c.address_text
      FROM saved_locations sl
      JOIN customers c ON sl.customer_id = c.id
      WHERE sl.latitude BETWEEN ? AND ?
        AND sl.longitude BETWEEN ? AND ?
        AND c.deleted_at IS NULL
    ''', [minLat, maxLat, minLng, maxLng]);
  }

  /// Lấy lịch sử thay đổi vị trí của một khách hàng
  Future<List<Map<String, dynamic>>> getLocationHistory(String customerId) async {
    final db = await database;
    return await db.query(
      'location_history',
      where: 'customer_id = ?',
      whereArgs: [customerId],
      orderBy: 'created_at DESC',
    );
  }

  // --- Ca làm việc (Shifts & Points) ---

  /// Tạo ca làm việc mới
  Future<String> createShift({
    String? id,
    required String shiftCode,
    String? shiftName,
    required String workDate,
    String status = 'PREPARING',
  }) async {
    final db = await database;
    final shiftId = id ?? generateId();
    final now = currentIsoUtc();

    await db.insert('shifts', {
      'id': shiftId,
      'shift_code': shiftCode,
      'shift_name': shiftName,
      'work_date': workDate,
      'status': status,
      'started_at': null,
      'completed_at': null,
      'created_at': now,
      'updated_at': now,
    });

    return shiftId;
  }

  /// Cập nhật trạng thái ca
  Future<int> updateShiftStatus(String shiftId, String status) async {
    final db = await database;
    final now = currentIsoUtc();
    final Map<String, dynamic> updates = {
      'status': status,
      'updated_at': now,
    };
    if (status == 'IN_PROGRESS') {
      updates['started_at'] = now;
    } else if (status == 'COMPLETED') {
      updates['completed_at'] = now;
    }

    return await db.update(
      'shifts',
      updates,
      where: 'id = ?',
      whereArgs: [shiftId],
    );
  }

  /// Xóa ca làm việc (Chỉ cascade xóa điểm giao trong ca, không xóa khách hay vị trí)
  Future<int> deleteShift(String shiftId) async {
    final db = await database;
    return await db.delete(
      'shifts',
      where: 'id = ?',
      whereArgs: [shiftId],
    );
  }

  /// Thêm điểm giao vào ca
  Future<String> addShiftDeliveryPoint({
    String? id,
    required String shiftId,
    required String customerId,
    int deliveryOrderIndex = 0,
    String locationStatus = 'NO_LOCATION',
    double? latitude,
    double? longitude,
    double? gpsAccuracy,
    String? identificationNotes,
  }) async {
    final db = await database;
    final pointId = id ?? generateId();
    final now = currentIsoUtc();

    await db.insert('shift_delivery_points', {
      'id': pointId,
      'shift_id': shiftId,
      'customer_id': customerId,
      'delivery_order_index': deliveryOrderIndex,
      'location_status': locationStatus,
      'latitude': latitude,
      'longitude': longitude,
      'gps_accuracy': gpsAccuracy,
      'identification_notes': identificationNotes,
      'created_at': now,
      'updated_at': now,
    });

    return pointId;
  }

  /// Lấy danh sách điểm giao trong một ca kèm thông tin khách hàng
  Future<List<Map<String, dynamic>>> getShiftDeliveryPoints(String shiftId) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT sdp.*, c.full_name, c.phone_number, c.address_text,
             sl.latitude AS saved_latitude, sl.longitude AS saved_longitude
      FROM shift_delivery_points sdp
      JOIN customers c ON sdp.customer_id = c.id
      LEFT JOIN saved_locations sl ON c.id = sl.customer_id
      WHERE sdp.shift_id = ?
      ORDER BY sdp.delivery_order_index ASC
    ''', [shiftId]);
  }

  // --- Hồ sơ ứng dụng & Meta (App Profile & Meta) ---

  /// Cập nhật hồ sơ ứng dụng (duy nhất id = 1)
  Future<void> setAppProfile({
    required String displayName,
    String? pinHash,
  }) async {
    final db = await database;
    final now = currentIsoUtc();
    await db.rawInsert('''
      INSERT INTO app_profile (id, display_name, pin_hash, created_at, updated_at)
      VALUES (1, ?, ?, ?, ?)
      ON CONFLICT(id) DO UPDATE SET
        display_name = excluded.display_name,
        pin_hash = excluded.pin_hash,
        updated_at = excluded.updated_at
    ''', [displayName, pinHash, now, now]);
  }

  /// Lấy hồ sơ ứng dụng
  Future<Map<String, dynamic>?> getAppProfile() async {
    final db = await database;
    final rows = await db.query('app_profile', where: 'id = 1', limit: 1);
    return rows.isNotEmpty ? rows.first : null;
  }

  /// Lấy đường dẫn file CSDL thực tế trên đĩa
  Future<String> getDatabasePath() async {
    if (_customPath != null) return _customPath!;
    final effectiveFactory = _factory ?? databaseFactory;
    final dbFolder = await effectiveFactory.getDatabasesPath();
    return p.join(dbFolder, databaseFileName);
  }

  /// Cập nhật riêng tên hiển thị mà không ảnh hưởng mã PIN
  Future<void> updateDisplayName(String displayName) async {
    final db = await database;
    final now = currentIsoUtc();
    final current = await getAppProfile();
    if (current == null) {
      await db.insert('app_profile', {
        'id': 1,
        'display_name': displayName.trim(),
        'pin_hash': null,
        'created_at': now,
        'updated_at': now,
      });
    } else {
      await db.update(
        'app_profile',
        {'display_name': displayName.trim(), 'updated_at': now},
        where: 'id = 1',
      );
    }
  }

  /// Cập nhật mã PIN băm (truyền null để tắt PIN)
  Future<void> updatePinHash(String? pinHash) async {
    final db = await database;
    final now = currentIsoUtc();
    final current = await getAppProfile();
    if (current == null) {
      await db.insert('app_profile', {
        'id': 1,
        'display_name': 'Người giao hàng',
        'pin_hash': pinHash,
        'created_at': now,
        'updated_at': now,
      });
    } else {
      await db.update(
        'app_profile',
        {'pin_hash': pinHash, 'updated_at': now},
        where: 'id = 1',
      );
    }
  }

  /// Lấy thống kê tổng quan (số vị trí, số ca, số ảnh, số khách)
  Future<Map<String, int>> getStats() async {
    final db = await database;
    final savedLocationsResult = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM saved_locations'),
    ) ?? 0;
    final shiftsResult = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM shifts'),
    ) ?? 0;
    final photosResult = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM customer_photos WHERE deleted_at IS NULL'),
    ) ?? 0;
    final customersResult = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM customers WHERE deleted_at IS NULL'),
    ) ?? 0;

    return {
      'savedLocationsCount': savedLocationsResult,
      'createdShiftsCount': shiftsResult,
      'uploadedPhotosCount': photosResult,
      'customersCount': customersResult,
    };
  }

  /// Thực hiện WAL checkpoint để đồng bộ dữ liệu vào file CSDL chính trước khi sao lưu
  Future<void> checkpoint() async {
    final db = await database;
    try {
      await db.rawQuery('PRAGMA wal_checkpoint(TRUNCATE);');
    } catch (_) {}
  }

  /// Ghi cài đặt meta
  Future<void> setMeta(String key, String value) async {
    final db = await database;
    await db.insert(
      'app_meta',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Đọc cài đặt meta
  Future<String?> getMeta(String key) async {
    final db = await database;
    final rows = await db.query('app_meta', where: 'key = ?', whereArgs: [key], limit: 1);
    return rows.isNotEmpty ? rows.first['value'] as String? : null;
  }

  // --- Nhật ký hoạt động (Activity Log) ---

  /// Ghi nhật ký hoạt động (không ghi mật khẩu hay thông tin nhạy cảm)
  Future<String> logActivity({
    DatabaseExecutor? executor,
    required String action,
    required String entity,
    String? entityId,
    Map<String, dynamic>? details,
  }) async {
    final db = executor ?? (await database);
    final logId = generateId();
    final now = currentIsoUtc();

    // Lọc bỏ các trường nhạy cảm nếu có
    final safeDetails = details != null ? Map<String, dynamic>.from(details) : null;
    if (safeDetails != null) {
      safeDetails.remove('password');
      safeDetails.remove('pin');
      safeDetails.remove('token');
      safeDetails.remove('jwt');
      safeDetails.remove('pin_hash');
    }

    await db.insert('activity_log', {
      'id': logId,
      'action': action,
      'entity': entity,
      'entity_id': entityId,
      'details_json': safeDetails != null ? jsonEncode(safeDetails) : null,
      'created_at': now,
    });

    return logId;
  }
}
