import 'package:delivery_marker_mobile/core/utils/phone_utils.dart';
import 'package:delivery_marker_mobile/core/utils/uuid_utils.dart';
import 'package:delivery_marker_mobile/data/database/app_database.dart';
import 'package:delivery_marker_mobile/data/photos/photo_repository.dart';
import 'package:delivery_marker_mobile/models/customer_photo_model.dart';
import 'package:delivery_marker_mobile/models/location_model.dart';
import 'package:delivery_marker_mobile/models/shift_model.dart';

/// Kho dữ liệu quản lý Vị trí mốc giao hàng cục bộ (Local-First)
class LocationRepository {
  final AppDatabase _appDb;
  final PhotoRepository _photoRepo;

  LocationRepository({AppDatabase? appDb, PhotoRepository? photoRepo})
      : _appDb = appDb ?? AppDatabase.instance,
        _photoRepo = photoRepo ?? PhotoRepository(appDb: appDb ?? AppDatabase.instance);

  static const String defaultAreaId = 'local-area-default';
  static const String defaultAreaName = 'Của tôi';

  Future<List<MasterSavedLocationModel>> getMySavedLocations() async {
    final db = await _appDb.database;
    final rows = await db.rawQuery('SELECT sl.*, c.customer_code, c.full_name, c.phone_number, c.address_text FROM saved_locations sl JOIN customers c ON sl.customer_id = c.id WHERE c.deleted_at IS NULL ORDER BY sl.updated_at DESC');
    final summaries = await _photoRepo.getBatchPhotoSummaries(rows.map((r) => r['customer_id'] as String).toList());
    return rows.map((r) => _mapToMasterSavedLocation(r, summaries[r['customer_id'] as String])).toList();
  }

  Future<List<MasterSavedLocationModel>> getSavedLocationsInBounds({required double minLat, required double maxLat, required double minLng, required double maxLng}) async {
    final db = await _appDb.database;
    final rows = await db.rawQuery('SELECT sl.*, c.customer_code, c.full_name, c.phone_number, c.address_text FROM saved_locations sl JOIN customers c ON sl.customer_id = c.id WHERE c.deleted_at IS NULL AND sl.latitude BETWEEN ? AND ? AND sl.longitude BETWEEN ? AND ? ORDER BY sl.updated_at DESC', [minLat, maxLat, minLng, maxLng]);
    final summaries = await _photoRepo.getBatchPhotoSummaries(rows.map((r) => r['customer_id'] as String).toList());
    return rows.map((r) => _mapToMasterSavedLocation(r, summaries[r['customer_id'] as String])).toList();
  }

  Future<bool> saveCustomerLocation(SavedLocationModel location, {String? imageBase64}) async {
    final res = await updateCustomerLocationAndPhoto(
      customerId: location.customerId, latitude: location.latitude, longitude: location.longitude,
      gpsAccuracy: location.gpsAccuracy, identificationNotes: location.identificationNotes, imageBase64: imageBase64,
    );
    return res['success'] == true;
  }

  Future<Map<String, dynamic>> updateCustomerLocationAndPhoto({
    required String customerId, required double latitude, required double longitude,
    double? gpsAccuracy, required String identificationNotes, String? imageBase64, bool? deletePhoto,
  }) async {
    if (latitude < -90 || latitude > 90 || longitude < -180 || longitude > 180) throw ArgumentError('Tọa độ không hợp lệ (-90..90, -180..180)');

    return await _appDb.transaction<Map<String, dynamic>>((txn) async {
      String resCustId = customerId;
      var custRows = await txn.query('customers', where: 'id = ? AND deleted_at IS NULL', whereArgs: [customerId], limit: 1);
      if (custRows.isEmpty) {
        final cleanPhone = normalizeCustomerPhone(customerId);
        if (isValidVnPhone(cleanPhone)) {
          final byPhone = await txn.query('customers', where: 'phone_number = ? AND deleted_at IS NULL', whereArgs: [cleanPhone], limit: 1);
          if (byPhone.isNotEmpty) {
            resCustId = byPhone.first['id'] as String;
          } else {
            resCustId = UuidUtils.generate();
            final now = AppDatabase.currentIsoUtc();
            await txn.insert('customers', {
              'id': resCustId, 'customer_code': 'CUST-${cleanPhone.length >= 4 ? cleanPhone.substring(cleanPhone.length - 4) : cleanPhone}',
              'full_name': 'Khách $cleanPhone', 'phone_number': cleanPhone, 'address_text': 'Chưa cập nhật địa chỉ',
              'created_at': now, 'updated_at': now, 'deleted_at': null,
            });
          }
        } else {
          throw Exception('Không tìm thấy khách hàng với ID: $customerId');
        }
      }

      final now = AppDatabase.currentIsoUtc();
      await txn.rawInsert('''
        INSERT INTO saved_locations (id, customer_id, latitude, longitude, gps_accuracy, identification_notes, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(customer_id) DO UPDATE SET
          latitude = excluded.latitude, longitude = excluded.longitude, gps_accuracy = excluded.gps_accuracy,
          identification_notes = excluded.identification_notes, updated_at = excluded.updated_at
      ''', [UuidUtils.generate(), resCustId, latitude, longitude, gpsAccuracy ?? 0.0, identificationNotes, now, now]);

      final updatedPoints = await txn.rawUpdate('''
        UPDATE shift_delivery_points SET location_status = 'VERIFIED', latitude = ?, longitude = ?,
               gps_accuracy = ?, identification_notes = ?, updated_at = ?
        WHERE customer_id = ? AND location_status IN ('NO_LOCATION', 'TEMPORARY')
          AND shift_id IN (SELECT id FROM shifts WHERE status IN ('PREPARING', 'IN_PROGRESS'))
      ''', [latitude, longitude, gpsAccuracy ?? 0.0, identificationNotes, now, resCustId]);

      await _appDb.logActivity(executor: txn, action: 'UPDATE_CUSTOMER_LOCATION', entity: 'LOCATION', entityId: resCustId, details: {'latitude': latitude, 'longitude': longitude, 'updatedShiftPointsCount': updatedPoints});
      return {'success': true, 'message': 'Cập nhật vị trí khách hàng thành công', 'updatedShiftPointsCount': updatedPoints};
    });
  }

  Future<void> deleteCustomerLocation(String customerId) async {
    await _appDb.transaction((txn) async {
      await txn.delete('saved_locations', where: 'customer_id = ?', whereArgs: [customerId]);
      await txn.rawUpdate('''
        UPDATE shift_delivery_points SET location_status = 'NO_LOCATION', latitude = NULL, longitude = NULL, gps_accuracy = NULL, updated_at = ?
        WHERE customer_id = ? AND location_status = 'VERIFIED' AND shift_id IN (SELECT id FROM shifts WHERE status IN ('PREPARING', 'IN_PROGRESS'))
      ''', [AppDatabase.currentIsoUtc(), customerId]);
      await _appDb.logActivity(executor: txn, action: 'DELETE_CUSTOMER_LOCATION', entity: 'LOCATION', entityId: customerId);
    });
  }

  Future<ShiftDeliveryPointModel> updateTemporaryLocation(String shiftId, String pointId, {required double latitude, required double longitude, String? locationNotes, String? identificationNotes}) async {
    if (latitude < -90 || latitude > 90 || longitude < -180 || longitude > 180) throw ArgumentError('Tọa độ không hợp lệ (-90..90, -180..180)');
    final db = await _appDb.database, now = AppDatabase.currentIsoUtc(), notes = identificationNotes ?? locationNotes;

    final target = await db.query('shift_delivery_points', columns: ['customer_id'], where: 'shift_id = ? AND id = ?', whereArgs: [shiftId, pointId], limit: 1);
    if (target.isEmpty) throw Exception('Không tìm thấy điểm giao hàng trong ca');
    final custId = target.first['customer_id'] as String;

    await db.transaction((txn) async {
      await txn.update('shift_delivery_points', {'location_status': 'TEMPORARY', 'latitude': latitude, 'longitude': longitude, 'identification_notes': notes, 'updated_at': now}, where: 'shift_id = ? AND id = ?', whereArgs: [shiftId, pointId]);
      await txn.rawUpdate('''
        UPDATE shift_delivery_points SET location_status = 'TEMPORARY', latitude = ?, longitude = ?, identification_notes = COALESCE(?, identification_notes), updated_at = ?
        WHERE customer_id = ? AND id != ? AND shift_id IN (SELECT id FROM shifts WHERE status IN ('PREPARING', 'IN_PROGRESS'))
      ''', [latitude, longitude, notes, now, custId, pointId]);
      await _appDb.logActivity(action: 'PIN_TEMPORARY_LOCATION', entity: 'shift_delivery_points', entityId: pointId, details: {'shiftId': shiftId, 'customerId': custId, 'latitude': latitude, 'longitude': longitude}, executor: txn);
    });

    final rows = await db.rawQuery('SELECT sdp.*, c.customer_code, c.full_name, c.phone_number, c.address_text FROM shift_delivery_points sdp JOIN customers c ON sdp.customer_id = c.id WHERE sdp.shift_id = ? AND sdp.id = ? LIMIT 1', [shiftId, pointId]);
    if (rows.isEmpty) throw Exception('Không tìm thấy điểm giao hàng trong ca');
    final r = rows.first;

    return ShiftDeliveryPointModel(
      id: r['id'] as String, shiftId: r['shift_id'] as String, customerId: r['customer_id'] as String,
      customerName: (r['full_name'] as String?) ?? '', customerPhone: (r['phone_number'] as String?) ?? '',
      customerAddress: (r['address_text'] as String?) ?? '', areaId: defaultAreaId, areaName: defaultAreaName,
      sequenceNumber: (r['delivery_order_index'] as num?)?.toInt() ?? 0, deliveryStatus: 'PENDING',
      locationStatus: LocationStatus.temporary, latitude: (r['latitude'] as num?)?.toDouble(),
      longitude: (r['longitude'] as num?)?.toDouble(), locationNotes: r['identification_notes'] as String?,
      createdAt: DateTime.tryParse(r['created_at']?.toString() ?? ''), updatedAt: DateTime.tryParse(r['updated_at']?.toString() ?? ''),
    );
  }

  Future<int> getPendingSyncCount() async => 0;

  Future<void> syncOfflineQueue() async {}

  Future<List<Map<String, dynamic>>> getLocationHistory(String customerId) => _appDb.getLocationHistory(customerId);

  MasterSavedLocationModel _mapToMasterSavedLocation(Map<String, dynamic> r, [Map<String, dynamic>? photoSummary]) => MasterSavedLocationModel(
    id: r['id'] as String, customerId: r['customer_id'] as String, customerCode: (r['customer_code'] as String?) ?? 'KH',
    customerName: (r['full_name'] as String?) ?? '', customerPhone: (r['phone_number'] as String?) ?? '',
    customerAddress: (r['address_text'] as String?) ?? '', areaId: defaultAreaId, areaName: defaultAreaName,
    latitude: (r['latitude'] as num).toDouble(), longitude: (r['longitude'] as num).toDouble(),
    gpsAccuracy: (r['gps_accuracy'] as num?)?.toDouble() ?? 0.0, identificationNotes: (r['identification_notes'] as String?) ?? '',
    imageUrl: photoSummary?['firstThumbnailUrl'] as String?, photoCount: (photoSummary?['photoCount'] as int?) ?? 0,
    photos: (photoSummary?['photos'] as List<CustomerPhotoModel>?) ?? const [],
    createdAt: DateTime.tryParse(r['created_at']?.toString() ?? ''), updatedAt: DateTime.tryParse(r['updated_at']?.toString() ?? ''),
  );
}

typedef LocalLocationRepository = LocationRepository;
