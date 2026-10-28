part of 'app_database.dart';

/// Các thao tác CRUD mức thấp cho Ca làm việc (Shifts), Điểm giao, Hồ sơ cá nhân và Cài đặt Meta
extension AppDatabaseShiftOps on AppDatabase {
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
    final shiftId = id ?? AppDatabase.generateId();
    final now = AppDatabase.currentIsoUtc();

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
    final now = AppDatabase.currentIsoUtc();
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
    final pointId = id ?? AppDatabase.generateId();
    final now = AppDatabase.currentIsoUtc();

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
    final logId = AppDatabase.generateId();
    final now = AppDatabase.currentIsoUtc();

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
