import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:delivery_marker_mobile/core/utils/uuid_utils.dart';
import 'package:delivery_marker_mobile/core/utils/phone_utils.dart';
import 'package:delivery_marker_mobile/core/utils/vietnamese_utils.dart';
import 'package:delivery_marker_mobile/data/local/app_database_migrations.dart';

part 'app_database_customer_ops.dart';
part 'app_database_shift_ops.dart';

/// Quản lý kết nối cơ sở dữ liệu SQLite cục bộ cho kiến trúc Local-First.
/// Tách biệt hoàn toàn với máy chủ và hàng đợi đồng bộ cũ.
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

  // ===========================================================================
  // MIGRATIONS THEO PHIÊN BẢN
  // ===========================================================================

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
}
