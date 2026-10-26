import 'dart:io' show File;
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/order_model.dart';
import '../models/location_model.dart';

/// Ba trạng thái chuẩn xác của quá trình di chuyển SQLite v1 -> v2
enum MigrationStatus {
  /// Di chuyển thành công 100% tất cả các bản ghi, không có bản ghi nào bị cách ly
  success,

  /// Di chuyển hoàn tất một phần, có bản ghi bị cách ly cần quản trị viên/shipper đối soát
  hasQuarantinedRecords,

  /// Quá trình di chuyển thất bại do lỗi hệ thống (đã rollback giao dịch)
  failed,
}

/// Kết quả chi tiết của quá trình di chuyển SQLite v1 -> v2
class MigrationResult {
  final MigrationStatus status;
  final int migratedCount;
  final int quarantinedCount;
  final int newlyQuarantinedCount;
  final String? errorMessage;
  final String message;

  const MigrationResult({
    required this.status,
    required this.migratedCount,
    required this.quarantinedCount,
    this.newlyQuarantinedCount = 0,
    this.errorMessage,
    required this.message,
  });

  bool get isSuccess => status == MigrationStatus.success;
  bool get hasQuarantine => status == MigrationStatus.hasQuarantinedRecords;
  bool get isFailed => status == MigrationStatus.failed;

  @override
  String toString() {
    return 'MigrationResult(status: $status, migrated: $migratedCount, quarantined: $quarantinedCount (new: $newlyQuarantinedCount), message: $message)';
  }
}

/// Kết quả của thao tác đối soát và sửa chữa bản ghi cách ly
class QuarantineResolutionResult {
  final bool success;
  final int? v2QueueId;
  final String message;
  final String? errorMessage;

  const QuarantineResolutionResult({
    required this.success,
    this.v2QueueId,
    required this.message,
    this.errorMessage,
  });

  @override
  String toString() {
    return 'QuarantineResolutionResult(success: $success, v2QueueId: $v2QueueId, message: $message)';
  }
}

class OfflineStorageService {
  static Database? _db;

  static Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  static Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'delivery_offline_v2.db');

    final db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE cached_orders (
            orderId TEXT PRIMARY KEY,
            jsonData TEXT
          )
        ''');

        await db.execute('''
          CREATE TABLE offline_sync_queue (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            customerId TEXT NOT NULL,
            latitude REAL NOT NULL,
            longitude REAL NOT NULL,
            gpsAccuracy REAL NOT NULL,
            identificationNotes TEXT NOT NULL,
            imageUrl TEXT,
            imageBase64 TEXT,
            syncStatus TEXT DEFAULT 'PENDING',
            retryCount INTEGER DEFAULT 0,
            createdAt TEXT NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE IF NOT EXISTS _v1_migration_tracking (
            v1_source_id INTEGER PRIMARY KEY,
            v2_queue_id INTEGER,
            migrated_at TEXT NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE IF NOT EXISTS _v1_quarantine_records (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            source_table TEXT NOT NULL DEFAULT 'offline_sync_queue',
            v1_source_id INTEGER,
            raw_data TEXT NOT NULL,
            error_reason TEXT NOT NULL,
            quarantined_at TEXT NOT NULL,
            status TEXT NOT NULL DEFAULT 'QUARANTINED',
            v2_queue_id INTEGER,
            resolved_at TEXT,
            resolution_notes TEXT,
            resolved_data TEXT
          )
        ''');
      },
    );

    // Đảm bảo schema cách ly luôn đầy đủ các cột đối soát
    await _ensureQuarantineSchema(db);

    // Tự động kiểm tra và di chuyển dữ liệu v1 sang v2 nếu tồn tại
    try {
      await migrateFromV1IfNeeded(db, catchErrors: true);
    } catch (_) {
      // Tránh việc lỗi di chuyển làm cản trở khởi động ứng dụng
    }

    return db;
  }

  /// Chuẩn hóa dữ liệu gốc thành chuỗi JSON an toàn
  static String serializeRawData(Map<String, dynamic> row) {
    try {
      return jsonEncode(row);
    } catch (_) {
      return row.toString();
    }
  }

  /// Xác thực tính toàn vẹn và kiểu dữ liệu của bản ghi hàng đợi v1
  static String? validateV1QueueRecord(Map<String, dynamic> row) {
    // 1. Kiểm tra customerId: không được null, rỗng hoặc toàn khoảng trắng
    final customerIdRaw = row['customerId'];
    if (customerIdRaw == null) {
      return 'Thiếu trường customerId (customerId is null)';
    }
    final customerId = customerIdRaw.toString().trim();
    if (customerId.isEmpty) {
      return 'Trường customerId rỗng (customerId is empty)';
    }

    // 2. Kiểm tra vĩ độ (latitude): bắt buộc là số hữu hạn trong phạm vi WGS84 [-90, 90]
    final latRaw = row['latitude'];
    if (latRaw == null) {
      return 'Thiếu tọa độ vĩ độ (latitude is null)';
    }
    double? lat;
    if (latRaw is num) {
      lat = latRaw.toDouble();
    } else if (latRaw is String) {
      lat = double.tryParse(latRaw);
    }
    if (lat == null || lat.isNaN || lat.isInfinite) {
      return 'Tọa độ vĩ độ không phải số hợp lệ (latitude is not a finite number: $latRaw)';
    }
    if (lat < -90.0 || lat > 90.0) {
      return 'Tọa độ vĩ độ ngoài phạm vi [-90, 90] (latitude out of range: $lat)';
    }

    // 3. Kiểm tra kinh độ (longitude): bắt buộc là số hữu hạn trong phạm vi WGS84 [-180, 180]
    final lngRaw = row['longitude'];
    if (lngRaw == null) {
      return 'Thiếu tọa độ kinh độ (longitude is null)';
    }
    double? lng;
    if (lngRaw is num) {
      lng = lngRaw.toDouble();
    } else if (lngRaw is String) {
      lng = double.tryParse(lngRaw);
    }
    if (lng == null || lng.isNaN || lng.isInfinite) {
      return 'Tọa độ kinh độ không phải số hợp lệ (longitude is not a finite number: $lngRaw)';
    }
    if (lng < -180.0 || lng > 180.0) {
      return 'Tọa độ kinh độ ngoài phạm vi [-180, 180] (longitude out of range: $lng)';
    }

    // 4. Kiểm tra gpsAccuracy: nếu có thì phải là số hợp lệ
    final gpsRaw = row['gpsAccuracy'];
    if (gpsRaw != null) {
      double? gps;
      if (gpsRaw is num) {
        gps = gpsRaw.toDouble();
      } else if (gpsRaw is String) {
        gps = double.tryParse(gpsRaw);
      }
      if (gps == null || gps.isNaN || gps.isInfinite) {
        return 'Độ chính xác GPS không phải số hợp lệ (gpsAccuracy is invalid: $gpsRaw)';
      }
    }

    return null; // Bản ghi hoàn toàn hợp lệ
  }

  /// Chuyển đổi bản ghi hàng đợi v1 (từ delivery_offline.db) sang schema v2
  static Map<String, dynamic>? transformV1QueueRecordToV2(Map<String, dynamic> v1Row) {
    if (validateV1QueueRecord(v1Row) != null) return null;

    final customerId = v1Row['customerId']!.toString().trim();
    final createdAt = v1Row['createdAt']?.toString();

    double lat = 0.0;
    final latRaw = v1Row['latitude'];
    if (latRaw is num) {
      lat = latRaw.toDouble();
    } else if (latRaw is String) {
      lat = double.tryParse(latRaw) ?? 0.0;
    }

    double lng = 0.0;
    final lngRaw = v1Row['longitude'];
    if (lngRaw is num) {
      lng = lngRaw.toDouble();
    } else if (lngRaw is String) {
      lng = double.tryParse(lngRaw) ?? 0.0;
    }

    double accuracy = 0.0;
    final gpsRaw = v1Row['gpsAccuracy'];
    if (gpsRaw is num) {
      accuracy = gpsRaw.toDouble();
    } else if (gpsRaw is String) {
      accuracy = double.tryParse(gpsRaw) ?? 0.0;
    }

    return {
      'customerId': customerId,
      'latitude': lat,
      'longitude': lng,
      'gpsAccuracy': accuracy,
      'identificationNotes': v1Row['identificationNotes']?.toString() ?? '',
      'imageUrl': null,
      'imageBase64': null,
      'syncStatus': 'PENDING',
      'retryCount': 0,
      'createdAt': (createdAt != null && createdAt.isNotEmpty)
          ? createdAt
          : DateTime.now().toIso8601String(),
    };
  }

  /// Kiểm tra bản ghi ứng viên có bị trùng với bản ghi v2 đã tồn tại hay không
  static bool isDuplicateSyncRecord(
    Map<String, dynamic> candidateRecord,
    Iterable<Map<String, dynamic>> existingV2Records,
  ) {
    final candCustId = candidateRecord['customerId']?.toString();
    final candCreatedAt = candidateRecord['createdAt']?.toString();

    return existingV2Records.any((rec) =>
        rec['customerId']?.toString() == candCustId &&
        rec['createdAt']?.toString() == candCreatedAt);
  }

  /// Đảm bảo bảng và các cột audit của _v1_quarantine_records tồn tại đầy đủ
  static Future<void> _ensureQuarantineSchema(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS _v1_quarantine_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        source_table TEXT NOT NULL DEFAULT 'offline_sync_queue',
        v1_source_id INTEGER,
        raw_data TEXT NOT NULL,
        error_reason TEXT NOT NULL,
        quarantined_at TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'QUARANTINED',
        v2_queue_id INTEGER,
        resolved_at TEXT,
        resolution_notes TEXT,
        resolved_data TEXT
      )
    ''');

    try {
      final columns = await db.rawQuery('PRAGMA table_info(_v1_quarantine_records)');
      final colNames = columns.map((c) => c['name'] as String).toSet();

      if (!colNames.contains('status')) {
        await db.execute("ALTER TABLE _v1_quarantine_records ADD COLUMN status TEXT NOT NULL DEFAULT 'QUARANTINED'");
      }
      if (!colNames.contains('v2_queue_id')) {
        await db.execute("ALTER TABLE _v1_quarantine_records ADD COLUMN v2_queue_id INTEGER");
      }
      if (!colNames.contains('resolved_at')) {
        await db.execute("ALTER TABLE _v1_quarantine_records ADD COLUMN resolved_at TEXT");
      }
      if (!colNames.contains('resolution_notes')) {
        await db.execute("ALTER TABLE _v1_quarantine_records ADD COLUMN resolution_notes TEXT");
      }
      if (!colNames.contains('resolved_data')) {
        await db.execute("ALTER TABLE _v1_quarantine_records ADD COLUMN resolved_data TEXT");
      }
    } catch (_) {}
  }

  /// Lấy danh sách bản ghi v1 bị cách ly để đối soát hoặc sửa chữa
  /// Hỗ trợ lọc theo trạng thái: 'QUARANTINED', 'RESOLVED', 'DISCARDED' (null để lấy tất cả)
  static Future<List<Map<String, dynamic>>> getQuarantinedRecords({
    Database? targetDb,
    String? statusFilter,
  }) async {
    final db = targetDb ?? await database;
    await _ensureQuarantineSchema(db);
    try {
      if (statusFilter != null) {
        return await db.query(
          '_v1_quarantine_records',
          where: 'status = ?',
          whereArgs: [statusFilter],
          orderBy: 'id ASC',
        );
      }
      return await db.query(
        '_v1_quarantine_records',
        orderBy: 'id ASC',
      );
    } catch (_) {
      return [];
    }
  }

  /// Đếm tổng số bản ghi bị cách ly trong database v2
  /// Nếu [onlyPending] là true (mặc định), chỉ đếm các bản ghi có trạng thái 'QUARANTINED' đang chờ xử lý
  static Future<int> getQuarantinedCount({Database? targetDb, bool onlyPending = true}) async {
    final db = targetDb ?? await database;
    await _ensureQuarantineSchema(db);
    try {
      final sql = onlyPending
          ? "SELECT COUNT(*) as count FROM _v1_quarantine_records WHERE status = 'QUARANTINED'"
          : "SELECT COUNT(*) as count FROM _v1_quarantine_records";
      final res = await db.rawQuery(sql);
      if (res.isNotEmpty) {
        return (res.first['count'] as num?)?.toInt() ?? 0;
      }
    } catch (_) {}
    return 0;
  }

  /// Đối soát, sửa chữa và đưa bản ghi cách ly trở lại hàng đợi đồng bộ (offline_sync_queue)
  /// - Xác thực tính hợp lệ của [correctedCustomerId], tọa độ và độ chính xác GPS.
  /// - Thực hiện trong một Transaction nguyên tử: tạo queue item, cập nhật tracking, chuyển status sang 'RESOLVED'.
  /// - Bảo toàn 100% dữ liệu gốc và lịch sử đối soát trong bảng _v1_quarantine_records.
  /// - Đảm bảo Idempotent: chạy lại không nhân bản dữ liệu trong offline_sync_queue.
  /// - Tự động cập nhật cờ migration SharedPreferences nếu toàn bộ bản ghi cách ly đã được xử lý.
  static Future<QuarantineResolutionResult> resolveQuarantinedRecord({
    required int quarantineId,
    required String correctedCustomerId,
    double? correctedLatitude,
    double? correctedLongitude,
    double? correctedGpsAccuracy,
    String? correctedIdentificationNotes,
    String? resolutionNotes,
    Database? targetDb,
  }) async {
    final db = targetDb ?? await database;
    await _ensureQuarantineSchema(db);

    // 1. Kiểm tra customerId hợp lệ
    final cleanCustId = correctedCustomerId.trim();
    if (cleanCustId.isEmpty) {
      return const QuarantineResolutionResult(
        success: false,
        message: 'Mã khách hàng (customerId) không được để trống khi sửa dữ liệu cách ly',
        errorMessage: 'Empty customerId',
      );
    }

    // 2. Tra cứu bản ghi cách ly
    final existingList = await db.query(
      '_v1_quarantine_records',
      where: 'id = ?',
      whereArgs: [quarantineId],
    );

    if (existingList.isEmpty) {
      return QuarantineResolutionResult(
        success: false,
        message: 'Không tìm thấy bản ghi cách ly với ID: $quarantineId',
        errorMessage: 'Quarantine record not found',
      );
    }

    final qRecord = existingList.first;
    final currentStatus = qRecord['status']?.toString() ?? 'QUARANTINED';

    // 3. Đảm bảo tính Idempotent
    if (currentStatus == 'RESOLVED') {
      final existingV2QueueId = qRecord['v2_queue_id'] as int?;
      return QuarantineResolutionResult(
        success: true,
        v2QueueId: existingV2QueueId,
        message: 'Bản ghi cách ly đã được xử lý thành công trước đó (v2QueueId: $existingV2QueueId)',
      );
    }

    if (currentStatus == 'DISCARDED') {
      return const QuarantineResolutionResult(
        success: false,
        message: 'Bản ghi cách ly đã bị loại bỏ (DISCARDED), không thể phục hồi',
        errorMessage: 'Record was discarded',
      );
    }

    // 4. Giải mã dữ liệu gốc raw_data
    Map<String, dynamic> rawMap = {};
    try {
      final rawStr = qRecord['raw_data'] as String;
      rawMap = jsonDecode(rawStr) as Map<String, dynamic>;
    } catch (_) {}

    // Xác định tọa độ và kiểm tra phạm vi WGS84
    double lat = 0.0;
    if (correctedLatitude != null) {
      lat = correctedLatitude;
    } else {
      final rawLat = rawMap['latitude'];
      if (rawLat is num) {
        lat = rawLat.toDouble();
      } else if (rawLat is String) {
        lat = double.tryParse(rawLat) ?? 0.0;
      }
    }
    if (lat.isNaN || lat.isInfinite || lat < -90.0 || lat > 90.0) {
      return QuarantineResolutionResult(
        success: false,
        message: 'Tọa độ vĩ độ không hợp lệ: $lat (phải thuộc [-90, 90])',
        errorMessage: 'Invalid latitude range',
      );
    }

    double lng = 0.0;
    if (correctedLongitude != null) {
      lng = correctedLongitude;
    } else {
      final rawLng = rawMap['longitude'];
      if (rawLng is num) {
        lng = rawLng.toDouble();
      } else if (rawLng is String) {
        lng = double.tryParse(rawLng) ?? 0.0;
      }
    }
    if (lng.isNaN || lng.isInfinite || lng < -180.0 || lng > 180.0) {
      return QuarantineResolutionResult(
        success: false,
        message: 'Tọa độ kinh độ không hợp lệ: $lng (phải thuộc [-180, 180])',
        errorMessage: 'Invalid longitude range',
      );
    }

    double accuracy = 0.0;
    if (correctedGpsAccuracy != null) {
      accuracy = correctedGpsAccuracy;
    } else {
      final rawAcc = rawMap['gpsAccuracy'];
      if (rawAcc is num) {
        accuracy = rawAcc.toDouble();
      } else if (rawAcc is String) {
        accuracy = double.tryParse(rawAcc) ?? 0.0;
      }
    }
    if (accuracy.isNaN || accuracy.isInfinite || accuracy < 0.0) {
      return QuarantineResolutionResult(
        success: false,
        message: 'Độ chính xác GPS không hợp lệ: $accuracy (phải >= 0)',
        errorMessage: 'Invalid gpsAccuracy',
      );
    }

    final notes = correctedIdentificationNotes ?? rawMap['identificationNotes']?.toString() ?? '';
    final createdAt = rawMap['createdAt']?.toString() ?? DateTime.now().toIso8601String();
    final v1SourceId = qRecord['v1_source_id'] as int?;
    final imageUrl = rawMap['imageUrl']?.toString();
    final imageBase64 = rawMap['imageBase64']?.toString();

    // 5. Thực thi trong giao dịch SQLite nguyên tử
    int newV2QueueId = 0;
    try {
      await db.transaction((txn) async {
        // Kiểm tra lại trạng thái bên trong giao dịch (race condition guard)
        final checkInTxn = await txn.query(
          '_v1_quarantine_records',
          where: 'id = ?',
          whereArgs: [quarantineId],
        );
        if (checkInTxn.isNotEmpty && checkInTxn.first['status'] == 'RESOLVED') {
          newV2QueueId = (checkInTxn.first['v2_queue_id'] as num?)?.toInt() ?? 0;
          return;
        }

        // Kiểm tra trùng lặp trong offline_sync_queue
        final existingInQueue = await txn.query(
          'offline_sync_queue',
          where: 'customerId = ? AND createdAt = ?',
          whereArgs: [cleanCustId, createdAt],
        );

        if (existingInQueue.isNotEmpty) {
          newV2QueueId = existingInQueue.first['id'] as int;
        } else {
          newV2QueueId = await txn.insert('offline_sync_queue', {
            'customerId': cleanCustId,
            'latitude': lat,
            'longitude': lng,
            'gpsAccuracy': accuracy,
            'identificationNotes': notes,
            'imageUrl': imageUrl,
            'imageBase64': imageBase64,
            'syncStatus': 'PENDING',
            'retryCount': 0,
            'createdAt': createdAt,
          });
        }

        // Cập nhật _v1_migration_tracking
        if (v1SourceId != null) {
          final existingTracking = await txn.query(
            '_v1_migration_tracking',
            where: 'v1_source_id = ?',
            whereArgs: [v1SourceId],
          );
          if (existingTracking.isNotEmpty) {
            await txn.update(
              '_v1_migration_tracking',
              {
                'v2_queue_id': newV2QueueId,
                'migrated_at': DateTime.now().toIso8601String(),
              },
              where: 'v1_source_id = ?',
              whereArgs: [v1SourceId],
            );
          } else {
            await txn.insert(
              '_v1_migration_tracking',
              {
                'v1_source_id': v1SourceId,
                'v2_queue_id': newV2QueueId,
                'migrated_at': DateTime.now().toIso8601String(),
              },
            );
          }
        }

        // Cập nhật trạng thái bản ghi cách ly sang RESOLVED và lưu vết dữ liệu đã sửa
        final resolvedDataJson = jsonEncode({
          'customerId': cleanCustId,
          'latitude': lat,
          'longitude': lng,
          'gpsAccuracy': accuracy,
          'identificationNotes': notes,
        });

        await txn.update(
          '_v1_quarantine_records',
          {
            'status': 'RESOLVED',
            'v2_queue_id': newV2QueueId,
            'resolved_at': DateTime.now().toIso8601String(),
            'resolution_notes': resolutionNotes ?? 'Đã bổ sung customerId và sửa dữ liệu hợp lệ',
            'resolved_data': resolvedDataJson,
          },
          where: 'id = ?',
          whereArgs: [quarantineId],
        );
      });

      // 6. Kiểm tra lại toàn bộ bản ghi cách ly đang chờ
      final remaining = await getQuarantinedCount(targetDb: db, onlyPending: true);
      final prefs = await SharedPreferences.getInstance();
      if (remaining == 0) {
        await prefs.setBool('sqlite_v1_migrated', true);
        await prefs.setString('sqlite_v1_migration_status', 'COMPLETED');
        await prefs.setInt('sqlite_v1_quarantined_count', 0);

        // ignore: avoid_print
        print('[SQLITE MIGRATION] Toàn bộ bản ghi cách ly đã được xử lý thành công. CSDL v1 đã được bảo toàn trọn vẹn.');
      } else {
        await prefs.setInt('sqlite_v1_quarantined_count', remaining);
      }

      return QuarantineResolutionResult(
        success: true,
        v2QueueId: newV2QueueId,
        message: 'Đã xử lý và đưa bản ghi cách ly trở lại hàng đợi đồng bộ thành công (v2QueueId: $newV2QueueId)',
      );
    } catch (e) {
      return QuarantineResolutionResult(
        success: false,
        message: 'Lỗi trong giao dịch xử lý bản ghi cách ly: $e',
        errorMessage: e.toString(),
      );
    }
  }

  /// Đánh dấu loại bỏ bản ghi cách ly với lý do đối soát rõ ràng (không xóa vĩnh viễn)
  static Future<bool> discardQuarantinedRecord({
    required int quarantineId,
    required String reason,
    Database? targetDb,
  }) async {
    final cleanReason = reason.trim();
    if (cleanReason.isEmpty) return false;

    final db = targetDb ?? await database;
    await _ensureQuarantineSchema(db);

    final success = await db.transaction((txn) async {
      final records = await txn.query(
        '_v1_quarantine_records',
        where: 'id = ?',
        whereArgs: [quarantineId],
      );
      if (records.isEmpty) return false;

      final current = records.first;
      if (current['status'] == 'RESOLVED') {
        // Không được loại bỏ bản ghi đã xử lý thành công
        return false;
      }

      await txn.update(
        '_v1_quarantine_records',
        {
          'status': 'DISCARDED',
          'resolved_at': DateTime.now().toIso8601String(),
          'resolution_notes': cleanReason,
        },
        where: 'id = ?',
        whereArgs: [quarantineId],
      );

      return true;
    });

    if (success) {
      final remaining = await getQuarantinedCount(targetDb: db, onlyPending: true);
      final prefs = await SharedPreferences.getInstance();
      if (remaining == 0) {
        await prefs.setBool('sqlite_v1_migrated', true);
        await prefs.setString('sqlite_v1_migration_status', 'COMPLETED');
        await prefs.setInt('sqlite_v1_quarantined_count', 0);
      } else {
        await prefs.setInt('sqlite_v1_quarantined_count', remaining);
      }
    }

    return success;
  }

  /// Xóa vĩnh viễn bản ghi cách ly
  /// Lưu ý: Khuyến khích sử dụng [resolveQuarantinedRecord] hoặc [discardQuarantinedRecord]
  /// để bảo toàn lịch sử đối soát thay vì xóa vĩnh viễn.
  /// Nếu xóa bản ghi chưa được resolve, hàm sẽ dọn sạch tracking chưa hoàn tất (v2_queue_id IS NULL)
  /// để tránh để lại ghost tracking chặn re-migration trong tương lai.
  static Future<int> deleteQuarantinedRecord(int id, {Database? targetDb}) async {
    final db = targetDb ?? await database;
    await _ensureQuarantineSchema(db);

    // Tra cứu thông tin v1_source_id và status trước khi xóa
    final existing = await db.query(
      '_v1_quarantine_records',
      where: 'id = ?',
      whereArgs: [id],
    );
    final v1SourceId = existing.isNotEmpty ? (existing.first['v1_source_id'] as int?) : null;

    final deletedCount = await db.delete(
      '_v1_quarantine_records',
      where: 'id = ?',
      whereArgs: [id],
    );

    // Nếu xóa bản ghi cách ly chưa được resolve, dọn tracking dở dang để không tạo ghost lock
    if (deletedCount > 0 && v1SourceId != null) {
      await db.delete(
        '_v1_migration_tracking',
        where: 'v1_source_id = ? AND v2_queue_id IS NULL',
        whereArgs: [v1SourceId],
      );
    }

    // Cập nhật lại số lượng bản ghi cách ly đang chờ trong SharedPreferences
    final remaining = await getQuarantinedCount(targetDb: db, onlyPending: true);
    try {
      final prefs = await SharedPreferences.getInstance();
      if (remaining == 0) {
        await prefs.setBool('sqlite_v1_migrated', true);
        await prefs.setString('sqlite_v1_migration_status', 'COMPLETED');
        await prefs.setInt('sqlite_v1_quarantined_count', 0);
      } else {
        await prefs.setInt('sqlite_v1_quarantined_count', remaining);
      }
    } catch (_) {}

    return deletedCount;
  }

  /// Di chuyển dữ liệu từ delivery_offline.db (v1) sang v2 trong giao dịch an toàn
  /// Phân biệt 3 trạng thái rõ ràng:
  /// - MigrationStatus.success: Di chuyển 100% thành công không có bản ghi lỗi.
  /// - MigrationStatus.hasQuarantinedRecords: Di chuyển một phần, có bản ghi bị cách ly cần xử lý.
  /// - MigrationStatus.failed: Lỗi hệ thống trong giao dịch (đã rollback).
  static Future<MigrationResult> migrateFromV1IfNeeded(
    Database v2Db, {
    String? customV1Path,
    bool forceRun = false,
    bool catchErrors = false,
    bool updatePrefs = true,
  }) async {
    if (kIsWeb) {
      return const MigrationResult(
        status: MigrationStatus.success,
        migratedCount: 0,
        quarantinedCount: 0,
        message: 'Nền tảng Web không sử dụng SQLite v1 file cục bộ.',
      );
    }

    final prefs = await SharedPreferences.getInstance();
    final isMigrated = prefs.getBool('sqlite_v1_migrated') ?? false;
    final migrationStatus = prefs.getString('sqlite_v1_migration_status');

    if (isMigrated && (migrationStatus == null || migrationStatus == 'COMPLETED') && !forceRun && customV1Path == null) {
      return const MigrationResult(
        status: MigrationStatus.success,
        migratedCount: 0,
        quarantinedCount: 0,
        message: 'Migration đã hoàn tất thành công trước đó.',
      );
    }

    final String v1Path;
    if (customV1Path != null) {
      v1Path = customV1Path;
    } else {
      final dbPath = await getDatabasesPath();
      v1Path = join(dbPath, 'delivery_offline.db');
    }

    final v1File = File(v1Path);
    if (!await v1File.exists()) {
      if (updatePrefs) {
        await prefs.setBool('sqlite_v1_migrated', true);
        await prefs.setString('sqlite_v1_migration_status', 'COMPLETED');
        await prefs.setInt('sqlite_v1_quarantined_count', 0);
      }
      return const MigrationResult(
        status: MigrationStatus.success,
        migratedCount: 0,
        quarantinedCount: 0,
        message: 'Không tìm thấy file SQLite v1. Bỏ qua migration.',
      );
    }

    // Đảm bảo bảng theo dõi định danh di chuyển nguồn v1 tồn tại trên v2
    await v2Db.execute('''
      CREATE TABLE IF NOT EXISTS _v1_migration_tracking (
        v1_source_id INTEGER PRIMARY KEY,
        v2_queue_id INTEGER,
        migrated_at TEXT NOT NULL
      )
    ''');

    // Đảm bảo bảng cách ly bản ghi lỗi v1 tồn tại trên v2 kèm đầy đủ cột đối soát
    await _ensureQuarantineSchema(v2Db);

    Database? v1Db;
    int migratedCount = 0;
    int newlyQuarantinedCount = 0;
    try {
      // Mở database v1 ở chế độ readOnly để bảo vệ toàn vẹn tuyệt đối dữ liệu gốc
      v1Db = await openDatabase(v1Path, readOnly: true);

      List<Map<String, dynamic>> v1Orders = [];
      try {
        v1Orders = await v1Db.query('cached_orders');
      } catch (_) {}

      List<Map<String, dynamic>> v1Queue = [];
      try {
        v1Queue = await v1Db.query('offline_sync_queue');
      } catch (_) {}

      // Thực thi việc nạp dữ liệu vào v2 trong một SQLite Transaction nguyên tử
      await v2Db.transaction((txn) async {
        // 1. Nhập và đối soát cached_orders từ v1
        for (final row in v1Orders) {
          final orderId = row['orderId']?.toString();
          final v1JsonData = row['jsonData']?.toString();

          if (orderId == null || orderId.trim().isEmpty) {
            final raw = serializeRawData(row);
            final existing = await txn.query(
              '_v1_quarantine_records',
              where: 'source_table = ? AND raw_data = ?',
              whereArgs: ['cached_orders', raw],
            );
            if (existing.isEmpty) {
              await txn.insert('_v1_quarantine_records', {
                'source_table': 'cached_orders',
                'v1_source_id': null,
                'raw_data': raw,
                'error_reason': 'Thiếu hoặc rỗng orderId trong cached_orders',
                'quarantined_at': DateTime.now().toIso8601String(),
              });
              newlyQuarantinedCount++;
            }
            continue;
          }

          if (v1JsonData == null || v1JsonData.trim().isEmpty) {
            final raw = serializeRawData(row);
            final existing = await txn.query(
              '_v1_quarantine_records',
              where: 'source_table = ? AND raw_data = ?',
              whereArgs: ['cached_orders', raw],
            );
            if (existing.isEmpty) {
              await txn.insert('_v1_quarantine_records', {
                'source_table': 'cached_orders',
                'v1_source_id': null,
                'raw_data': raw,
                'error_reason': 'Dữ liệu jsonData rỗng trong cached_orders',
                'quarantined_at': DateTime.now().toIso8601String(),
              });
              newlyQuarantinedCount++;
            }
            continue;
          }

          final existingOrders = await txn.query(
            'cached_orders',
            where: 'orderId = ?',
            whereArgs: [orderId],
          );

          if (existingOrders.isEmpty) {
            await txn.insert('cached_orders', {
              'orderId': orderId,
              'jsonData': v1JsonData,
            });
          } else {
            // Đối soát nội dung: nếu v1 có vị trí đã lưu mà v2 chưa có, cập nhật dữ liệu v2
            final v2JsonData = existingOrders.first['jsonData'] as String?;
            if (v2JsonData != v1JsonData && v2JsonData != null) {
              try {
                final v1Map = jsonDecode(v1JsonData) as Map<String, dynamic>;
                final v2Map = jsonDecode(v2JsonData) as Map<String, dynamic>;
                final v1HasLoc = v1Map['hasSavedLocation'] == true || v1Map['savedLocation'] != null;
                final v2HasLoc = v2Map['hasSavedLocation'] == true || v2Map['savedLocation'] != null;
                if (v1HasLoc && !v2HasLoc) {
                  await txn.update(
                    'cached_orders',
                    {'jsonData': v1JsonData},
                    where: 'orderId = ?',
                    whereArgs: [orderId],
                  );
                }
              } catch (_) {}
            }
          }
        }

        // 2. Nhập offline_sync_queue từ v1 có kiểm tra định danh khóa chính v1_source_id
        for (final row in v1Queue) {
          final v1Id = row['id'] as int?;

          // Kiểm tra định danh ID nguồn v1: nếu đã di chuyển thành công hoặc đã xử lý trong đợt trước
          if (v1Id != null) {
            final trackingCheck = await txn.query(
              '_v1_migration_tracking',
              where: 'v1_source_id = ?',
              whereArgs: [v1Id],
            );
            if (trackingCheck.isNotEmpty) {
              continue;
            }
          }

          // Xác thực tính toàn vẹn và kiểu dữ liệu của bản ghi v1
          final validationError = validateV1QueueRecord(row);
          if (validationError != null) {
            // BẢN GHI LỖI: Không âm thầm bỏ qua! Cách ly vào bảng _v1_quarantine_records
            final rawJson = serializeRawData(row);
            bool alreadyQuarantined = false;

            if (v1Id != null) {
              final existingQ = await txn.query(
                '_v1_quarantine_records',
                where: 'source_table = ? AND v1_source_id = ?',
                whereArgs: ['offline_sync_queue', v1Id],
              );
              alreadyQuarantined = existingQ.isNotEmpty;
            } else {
              final existingQ = await txn.query(
                '_v1_quarantine_records',
                where: 'source_table = ? AND raw_data = ?',
                whereArgs: ['offline_sync_queue', rawJson],
              );
              alreadyQuarantined = existingQ.isNotEmpty;
            }

            if (!alreadyQuarantined) {
              await txn.insert('_v1_quarantine_records', {
                'source_table': 'offline_sync_queue',
                'v1_source_id': v1Id,
                'raw_data': rawJson,
                'error_reason': validationError,
                'quarantined_at': DateTime.now().toIso8601String(),
              });
              newlyQuarantinedCount++;
            }

            if (v1Id != null) {
              // Ghi vào tracking với v2_queue_id = null để đánh dấu bản ghi đã xử lý cách ly
              await txn.insert(
                '_v1_migration_tracking',
                {
                  'v1_source_id': v1Id,
                  'v2_queue_id': null,
                  'migrated_at': DateTime.now().toIso8601String(),
                },
                conflictAlgorithm: ConflictAlgorithm.ignore,
              );
            }
            continue;
          }

          // Bản ghi hợp lệ: chuyển đổi an toàn sang schema v2
          final transformed = transformV1QueueRecordToV2(row);
          if (transformed != null) {
            final newV2Id = await txn.insert('offline_sync_queue', transformed);
            if (v1Id != null) {
              await txn.insert('_v1_migration_tracking', {
                'v1_source_id': v1Id,
                'v2_queue_id': newV2Id,
                'migrated_at': DateTime.now().toIso8601String(),
              });
            }
            migratedCount++;
          }
        }
      });

      // Truy vấn tổng số lượng bản ghi bị cách ly ĐANG CHỜ XỬ LÝ (status = 'QUARANTINED') trong database v2
      final totalQuarantinedRes = await v2Db.rawQuery(
        "SELECT COUNT(*) as count FROM _v1_quarantine_records WHERE status = 'QUARANTINED'",
      );
      final totalQuarantined = (totalQuarantinedRes.first['count'] as num?)?.toInt() ?? 0;

      if (totalQuarantined > 0) {
        // Có bản ghi bị cách ly: KHÔNG đánh dấu hoàn tất toàn bộ dữ liệu
        if (updatePrefs) {
          await prefs.setBool('sqlite_v1_migrated', false);
          await prefs.setString('sqlite_v1_migration_status', 'QUARANTINED');
          await prefs.setInt('sqlite_v1_quarantined_count', totalQuarantined);
        }

        // ignore: avoid_print
        print(
          '[SQLITE MIGRATION WARNING] Phát hiện $newlyQuarantinedCount bản ghi mới bị cách ly '
          '(tổng cộng $totalQuarantined bản ghi trong "_v1_quarantine_records") do dữ liệu v1 không thể chuyển đổi. '
          'Dữ liệu nguồn v1 được giữ nguyên tuyệt đối. Vui lòng đối soát và hiệu chỉnh bản ghi lỗi '
          'bằng OfflineStorageService.getQuarantinedRecords().',
        );

        return MigrationResult(
          status: MigrationStatus.hasQuarantinedRecords,
          migratedCount: migratedCount,
          quarantinedCount: totalQuarantined,
          newlyQuarantinedCount: newlyQuarantinedCount,
          message: 'Di chuyển hoàn tất một phần. Có $totalQuarantined bản ghi bị cách ly cần xử lý.',
        );
      } else {
        // Hoàn tất 100% thành công không có bản ghi lỗi
        if (updatePrefs) {
          await prefs.setBool('sqlite_v1_migrated', true);
          await prefs.setString('sqlite_v1_migration_status', 'COMPLETED');
          await prefs.setInt('sqlite_v1_quarantined_count', 0);
        }

        // ignore: avoid_print
        print(
          '[SQLITE MIGRATION SUCCESS] Di chuyển thành công toàn bộ $migratedCount bản ghi từ v1 sang v2.',
        );

        return MigrationResult(
          status: MigrationStatus.success,
          migratedCount: migratedCount,
          quarantinedCount: 0,
          message: 'Di chuyển thành công toàn bộ dữ liệu.',
        );
      }
    } catch (e) {
      if (updatePrefs) {
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('sqlite_v1_migrated', false);
          await prefs.setString('sqlite_v1_migration_status', 'FAILED');
        } catch (_) {}
      }

      // ignore: avoid_print
      print('[SQLITE MIGRATION FAILED] Lỗi hệ thống trong quá trình migration: $e');

      if (catchErrors) {
        return MigrationResult(
          status: MigrationStatus.failed,
          migratedCount: 0,
          quarantinedCount: 0,
          errorMessage: e.toString(),
          message: 'Migration thất bại do lỗi hệ thống: $e',
        );
      }
      rethrow;
    } finally {
      if (v1Db != null && v1Db.isOpen) {
        await v1Db.close();
      }
    }
  }

  static Future<void> cacheOrders(List<OrderModel> orders) async {
    final db = await database;
    final batch = db.batch();
    batch.delete('cached_orders');

    for (var order in orders) {
      batch.insert('cached_orders', {
        'orderId': order.orderId,
        'jsonData': jsonEncode(order.toJson()),
      });
    }

    await batch.commit(noResult: true);
  }

  static Future<List<OrderModel>> getCachedOrders() async {
    final db = await database;
    final maps = await db.query('cached_orders');
    return maps.map((m) {
      final json = jsonDecode(m['jsonData'] as String);
      return OrderModel.fromJson(json);
    }).toList();
  }

  static Future<void> addToSyncQueue({
    required SavedLocationModel location,
    String? imageBase64,
  }) async {
    final db = await database;
    await db.insert('offline_sync_queue', {
      'customerId': location.customerId,
      'latitude': location.latitude,
      'longitude': location.longitude,
      'gpsAccuracy': location.gpsAccuracy,
      'identificationNotes': location.identificationNotes,
      'imageUrl': location.imageUrl,
      'imageBase64': imageBase64,
      'syncStatus': 'PENDING',
      'retryCount': 0,
      'createdAt': DateTime.now().toIso8601String(),
    });
  }

  static Future<List<Map<String, dynamic>>> getPendingSyncQueue() async {
    final db = await database;
    return await db.query(
      'offline_sync_queue',
      where: 'syncStatus = ?',
      whereArgs: ['PENDING'],
      orderBy: 'createdAt ASC',
    );
  }

  static Future<int> getPendingCount() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM offline_sync_queue WHERE syncStatus = ?',
      ['PENDING'],
    );
    if (result.isNotEmpty) {
      return (result.first['count'] as num?)?.toInt() ?? 0;
    }
    return 0;
  }

  static Future<void> incrementRetry(int id, int currentRetries) async {
    final db = await database;
    await db.update(
      'offline_sync_queue',
      {
        'retryCount': currentRetries + 1,
        'syncStatus': currentRetries >= 5 ? 'FAILED' : 'PENDING',
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  static Future<void> clearSyncQueueItem(int id) async {
    final db = await database;
    await db.delete('offline_sync_queue', where: 'id = ?', whereArgs: [id]);
  }
}
