// Lớp khởi tạo và quản lý phiên kết nối cơ sở dữ liệu SQLite của ứng dụng.
// Thiết lập chế độ WAL, xử lý khóa luồng và thực thi transaction an toàn.
import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:delivery_marker_mobile/core/utils/uuid_utils.dart';
import 'package:delivery_marker_mobile/data/database/app_database_migrations.dart';

export 'package:delivery_marker_mobile/data/database/app_database_schema.dart';
export 'package:delivery_marker_mobile/data/database/app_database_migrations.dart';
export 'package:delivery_marker_mobile/data/customers/customer_queries.dart';
export 'package:delivery_marker_mobile/data/locations/location_queries.dart';
export 'package:delivery_marker_mobile/data/shifts/shift_queries.dart';

/// Quản lý kết nối cơ sở dữ liệu SQLite cục bộ cho kiến trúc Local-First.
class AppDatabase {
  static const String databaseFileName = 'local_data_v1.db';
  static const int currentVersion = 2;

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
          await db.execute('PRAGMA foreign_keys = ON;');
        },
        onCreate: (db, version) async {
          for (int v = 1; v <= version; v++) {
            final migration = _migrations[v];
            if (migration != null) {
              await migration(db);
            }
          }
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          for (int v = oldVersion + 1; v <= newVersion; v++) {
            final migration = _migrations[v];
            if (migration != null) {
              await migration(db);
            }
          }
        },
        onOpen: (db) async {
          try {
            await db.rawQuery('PRAGMA journal_mode = WAL;');
          } catch (_) {}
        },
      ),
    );
  }

  static final Map<int, Future<void> Function(DatabaseExecutor db)> _migrations = {
    1: migrationV1,
    2: migrationV2,
  };

  /// Lược đồ CSDL v1
  static Future<void> migrationV1(DatabaseExecutor db) =>
      AppDatabaseMigrations.migrationV1(db);

  /// Lược đồ CSDL v2
  static Future<void> migrationV2(DatabaseExecutor db) =>
      AppDatabaseMigrations.migrationV2(db);

  /// Thực thi giao dịch (Transaction)
  Future<T> transaction<T>(Future<T> Function(Transaction txn) action) async {
    final db = await database;
    return await db.transaction(action);
  }

  // ===========================================================================
  // HỒ SƠ ỨNG DỤNG & CÀI ĐẶT META (App Profile & Meta)
  // ===========================================================================

  /// Cập nhật hồ sơ ứng dụng (duy nhất id = 1)
  Future<void> setAppProfile({
    required String displayName,
    String? pinHash,
  }) async {
    final db = await database;
    final now = AppDatabase.currentIsoUtc();
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
    return p.join(dbFolder, AppDatabase.databaseFileName);
  }

  /// Cập nhật riêng tên hiển thị mà không ảnh hưởng mã PIN
  Future<void> updateDisplayName(String displayName) async {
    final db = await database;
    final now = AppDatabase.currentIsoUtc();
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
    final now = AppDatabase.currentIsoUtc();
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

  // ===========================================================================
  // NHẬT KÝ HOẠT ĐỘNG (Activity Log)
  // ===========================================================================

  /// Ghi nhật ký hoạt động (không ghi mật khẩu hay thông tin nhạy cảm)
  Future<String> logActivity({
    DatabaseExecutor? executor,
    required String action,
    required String entity,
    String? entityId,
    Map<String, dynamic>? details,
  }) async {
    final db = executor ?? (await database);
    final logId = AppDatabase.generateId();
    final now = AppDatabase.currentIsoUtc();

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
