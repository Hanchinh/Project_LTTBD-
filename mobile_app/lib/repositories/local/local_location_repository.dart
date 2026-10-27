import '../../local/app_database.dart';
import '../../models/location_model.dart';
import '../../models/shift_model.dart';
import '../../utils/phone_utils.dart';
import '../../utils/uuid_utils.dart';
import '../location_repository.dart';

/// Triển khai LocationRepository cục bộ bằng SQLite (Local-First)
/// Toàn bộ thao tác lưu, sửa, xóa vị trí được quản lý và bảo toàn lịch sử trên thiết bị
class LocalLocationRepository implements LocationRepository {
  final AppDatabase _appDb;

  LocalLocationRepository({AppDatabase? appDb})
      : _appDb = appDb ?? AppDatabase.instance;

  static const String defaultAreaId = 'local-area-default';
  static const String defaultAreaName = 'Của tôi';

  @override
  Future<List<MasterSavedLocationModel>> getMySavedLocations() async {
    final db = await _appDb.database;
    final rows = await db.rawQuery('''
      SELECT sl.*, c.customer_code, c.full_name, c.phone_number, c.address_text
      FROM saved_locations sl
      JOIN customers c ON sl.customer_id = c.id
      WHERE c.deleted_at IS NULL
      ORDER BY sl.updated_at DESC
    ''');

    return rows.map((r) => _mapToMasterSavedLocation(r)).toList();
  }

  @override
  Future<List<MasterSavedLocationModel>> getSavedLocationsInBounds({
    required double minLat,
    required double maxLat,
    required double minLng,
    required double maxLng,
  }) async {
    final db = await _appDb.database;
    final rows = await db.rawQuery('''
      SELECT sl.*, c.customer_code, c.full_name, c.phone_number, c.address_text
      FROM saved_locations sl
      JOIN customers c ON sl.customer_id = c.id
      WHERE c.deleted_at IS NULL
        AND sl.latitude BETWEEN ? AND ?
        AND sl.longitude BETWEEN ? AND ?
      ORDER BY sl.updated_at DESC
    ''', [minLat, maxLat, minLng, maxLng]);

    return rows.map((r) => _mapToMasterSavedLocation(r)).toList();
  }

  @override
  Future<bool> saveCustomerLocation(
    SavedLocationModel location, {
    String? imageBase64,
  }) async {
    final result = await updateCustomerLocationAndPhoto(
      customerId: location.customerId,
      latitude: location.latitude,
      longitude: location.longitude,
      gpsAccuracy: location.gpsAccuracy,
      identificationNotes: location.identificationNotes,
      imageBase64: imageBase64,
    );
    return result['success'] == true;
  }

  @override
  Future<Map<String, dynamic>> updateCustomerLocationAndPhoto({
    required String customerId,
    required double latitude,
    required double longitude,
    double? gpsAccuracy,
    required String identificationNotes,
    String? imageBase64,
    bool? deletePhoto,
  }) async {
    if (latitude < -90 || latitude > 90 || longitude < -180 || longitude > 180) {
      throw ArgumentError('Tọa độ không hợp lệ (-90..90, -180..180)');
    }

    return await _appDb.transaction<Map<String, dynamic>>((txn) async {
      // 1. Xác định ID khách hàng hợp lệ (nếu customerId là SĐT thì tìm hoặc tạo mới)
      String resolvedCustomerId = customerId;
      var custRows = await txn.query(
        'customers',
        where: 'id = ? AND deleted_at IS NULL',
        whereArgs: [customerId],
        limit: 1,
      );

      if (custRows.isEmpty) {
        final cleanPhone = normalizeCustomerPhone(customerId);
        if (isValidVnPhone(cleanPhone)) {
          final byPhone = await txn.query(
            'customers',
            where: 'phone_number = ? AND deleted_at IS NULL',
            whereArgs: [cleanPhone],
            limit: 1,
          );
          if (byPhone.isNotEmpty) {
            resolvedCustomerId = byPhone.first['id'] as String;
          } else {
            // Tạo khách hàng mới trong CÙNG một transaction
            resolvedCustomerId = UuidUtils.generate();
            final now = AppDatabase.currentIsoUtc();
            await txn.insert('customers', {
              'id': resolvedCustomerId,
              'customer_code': 'CUST-${cleanPhone.substring(cleanPhone.length - 4)}',
              'full_name': 'Khách $cleanPhone',
              'phone_number': cleanPhone,
              'address_text': 'Chưa cập nhật địa chỉ',
              'notes': null,
              'created_at': now,
              'updated_at': now,
              'deleted_at': null,
            });
          }
        } else {
          throw Exception('Không tìm thấy khách hàng với ID: $customerId');
        }
      }

      final now = AppDatabase.currentIsoUtc();
      final newLocId = UuidUtils.generate();

      // 2. Lưu hoặc cập nhật vị trí vào saved_locations (kích hoạt trigger nếu UPDATE)
      await txn.rawInsert('''
        INSERT INTO saved_locations (id, customer_id, latitude, longitude, gps_accuracy, identification_notes, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(customer_id) DO UPDATE SET
          latitude = excluded.latitude,
          longitude = excluded.longitude,
          gps_accuracy = excluded.gps_accuracy,
          identification_notes = excluded.identification_notes,
          updated_at = excluded.updated_at
      ''', [
        newLocId,
        resolvedCustomerId,
        latitude,
        longitude,
        gpsAccuracy ?? 0.0,
        identificationNotes,
        now,
        now,
      ]);

      // 3. Quy tắc LOCATION-RULES-012: Điểm giao trong ca của khách đang NO_LOCATION/TEMPORARY chuyển sang VERIFIED
      final updatedPoints = await txn.rawUpdate('''
        UPDATE shift_delivery_points
        SET location_status = 'VERIFIED',
            latitude = ?,
            longitude = ?,
            gps_accuracy = ?,
            identification_notes = ?,
            updated_at = ?
        WHERE customer_id = ?
          AND location_status IN ('NO_LOCATION', 'TEMPORARY')
          AND shift_id IN (
            SELECT id FROM shifts WHERE status IN ('PREPARING', 'IN_PROGRESS')
          )
      ''', [
        latitude,
        longitude,
        gpsAccuracy ?? 0.0,
        identificationNotes,
        now,
        resolvedCustomerId,
      ]);

      // 4. Ghi activity_log
      await _appDb.logActivity(
        executor: txn,
        action: 'UPDATE_CUSTOMER_LOCATION',
        entity: 'LOCATION',
        entityId: resolvedCustomerId,
        details: {
          'latitude': latitude,
          'longitude': longitude,
          'updatedShiftPointsCount': updatedPoints,
        },
      );

      return {
        'success': true,
        'message': 'Cập nhật vị trí khách hàng thành công',
        'updatedShiftPointsCount': updatedPoints,
      };
    });
  }

  @override
  Future<void> deleteCustomerLocation(String customerId) async {
    await _appDb.transaction((txn) async {
      // 1. Xóa vị trí đã lưu (foreign key ON DELETE SET NULL sẽ giữ lại location_history với saved_location_id = NULL)
      await txn.delete(
        'saved_locations',
        where: 'customer_id = ?',
        whereArgs: [customerId],
      );

      // 2. Điểm giao VERIFIED trong ca PREPARING/IN_PROGRESS của khách chuyển về NO_LOCATION
      // (Điểm TEMPORARY giữ nguyên vị trí ghim tạm của ca đó)
      await txn.rawUpdate('''
        UPDATE shift_delivery_points
        SET location_status = 'NO_LOCATION',
            latitude = NULL,
            longitude = NULL,
            gps_accuracy = NULL,
            updated_at = ?
        WHERE customer_id = ?
          AND location_status = 'VERIFIED'
          AND shift_id IN (
            SELECT id FROM shifts WHERE status IN ('PREPARING', 'IN_PROGRESS')
          )
      ''', [AppDatabase.currentIsoUtc(), customerId]);

      // 3. Ghi activity_log
      await _appDb.logActivity(
        executor: txn,
        action: 'DELETE_CUSTOMER_LOCATION',
        entity: 'LOCATION',
        entityId: customerId,
      );
    });
  }

  @override
  Future<ShiftDeliveryPointModel> updateTemporaryLocation(
    String shiftId,
    String pointId, {
    required double latitude,
    required double longitude,
    String? locationNotes,
    String? identificationNotes,
  }) async {
    if (latitude < -90 || latitude > 90 || longitude < -180 || longitude > 180) {
      throw ArgumentError('Tọa độ không hợp lệ (-90..90, -180..180)');
    }

    final db = await _appDb.database;
    final now = AppDatabase.currentIsoUtc();
    final effectiveNotes = identificationNotes ?? locationNotes;

    await db.update(
      'shift_delivery_points',
      {
        'location_status': 'TEMPORARY',
        'latitude': latitude,
        'longitude': longitude,
        'identification_notes': effectiveNotes,
        'updated_at': now,
      },
      where: 'shift_id = ? AND id = ?',
      whereArgs: [shiftId, pointId],
    );

    final rows = await db.rawQuery('''
      SELECT sdp.*, c.customer_code, c.full_name, c.phone_number, c.address_text
      FROM shift_delivery_points sdp
      JOIN customers c ON sdp.customer_id = c.id
      WHERE sdp.shift_id = ? AND sdp.id = ?
      LIMIT 1
    ''', [shiftId, pointId]);

    if (rows.isEmpty) {
      throw Exception('Không tìm thấy điểm giao hàng trong ca');
    }

    final r = rows.first;
    return ShiftDeliveryPointModel(
      id: r['id'] as String,
      shiftId: r['shift_id'] as String,
      customerId: r['customer_id'] as String,
      customerName: (r['full_name'] as String?) ?? '',
      customerPhone: (r['phone_number'] as String?) ?? '',
      customerAddress: (r['address_text'] as String?) ?? '',
      areaId: defaultAreaId,
      areaName: defaultAreaName,
      sequenceNumber: (r['delivery_order_index'] as num?)?.toInt() ?? 0,
      deliveryStatus: 'PENDING',
      locationStatus: LocationStatus.temporary,
      latitude: (r['latitude'] as num?)?.toDouble(),
      longitude: (r['longitude'] as num?)?.toDouble(),
      locationNotes: r['identification_notes'] as String?,
      createdAt: DateTime.tryParse(r['created_at']?.toString() ?? ''),
      updatedAt: DateTime.tryParse(r['updated_at']?.toString() ?? ''),
    );
  }

  @override
  Future<int> getPendingSyncCount() async => 0;

  @override
  Future<void> syncOfflineQueue() async {}

  @override
  Future<List<Map<String, dynamic>>> getLocationHistory(String customerId) async {
    return await _appDb.getLocationHistory(customerId);
  }

  MasterSavedLocationModel _mapToMasterSavedLocation(Map<String, dynamic> r) {
    return MasterSavedLocationModel(
      id: r['id'] as String,
      customerId: r['customer_id'] as String,
      customerCode: (r['customer_code'] as String?) ?? 'KH',
      customerName: (r['full_name'] as String?) ?? '',
      customerPhone: (r['phone_number'] as String?) ?? '',
      customerAddress: (r['address_text'] as String?) ?? '',
      areaId: defaultAreaId,
      areaName: defaultAreaName,
      latitude: (r['latitude'] as num).toDouble(),
      longitude: (r['longitude'] as num).toDouble(),
      gpsAccuracy: (r['gps_accuracy'] as num?)?.toDouble() ?? 0.0,
      identificationNotes: (r['identification_notes'] as String?) ?? '',
      photoCount: 0,
      photos: const [],
      createdAt: DateTime.tryParse(r['created_at']?.toString() ?? ''),
      updatedAt: DateTime.tryParse(r['updated_at']?.toString() ?? ''),
    );
  }
}
