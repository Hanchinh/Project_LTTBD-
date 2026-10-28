import 'package:sqflite/sqflite.dart';
import 'package:delivery_marker_mobile/core/utils/phone_utils.dart';
import 'package:delivery_marker_mobile/core/utils/uuid_utils.dart';
import 'package:delivery_marker_mobile/core/utils/vietnamese_utils.dart';
import 'package:delivery_marker_mobile/data/local/app_database.dart';
import 'package:delivery_marker_mobile/data/local/local_customer_repository.dart';
import 'package:delivery_marker_mobile/data/local/local_photo_repository.dart';
import 'package:delivery_marker_mobile/data/local/shift_bulk_helpers.dart';
import 'package:delivery_marker_mobile/data/repositories/shift_repository.dart';
import 'package:delivery_marker_mobile/models/customer_photo_model.dart';
import 'package:delivery_marker_mobile/models/location_model.dart';
import 'package:delivery_marker_mobile/models/order_model.dart';
import 'package:delivery_marker_mobile/models/shift_model.dart';

part 'shift_point_ops.dart';

class LocalShiftRepository implements ShiftRepository {
  final AppDatabase _appDb;
  final LocalPhotoRepository _photoRepo;

  LocalShiftRepository({AppDatabase? appDb, LocalPhotoRepository? photoRepo})
      : _appDb = appDb ?? AppDatabase.instance, _photoRepo = photoRepo ?? LocalPhotoRepository(appDb: appDb ?? AppDatabase.instance);

  static const String defaultAreaId = LocalCustomerRepository.defaultAreaId;
  static const String defaultAreaName = LocalCustomerRepository.defaultAreaName;
  static const String defaultShipperId = 'local-shipper';

  @override
  Future<List<ShiftModel>> getShifts() async {
    final db = await _appDb.database;
    final shiftRows = await db.query('shifts', orderBy: 'work_date DESC, created_at DESC');
    if (shiftRows.isEmpty) return [];

    final summaryRows = await db.rawQuery('''
      SELECT shift_id, COUNT(*) AS total_points,
             SUM(CASE WHEN location_status = 'VERIFIED' THEN 1 ELSE 0 END) AS verified_count,
             SUM(CASE WHEN location_status = 'TEMPORARY' THEN 1 ELSE 0 END) AS temporary_count,
             SUM(CASE WHEN location_status = 'NO_LOCATION' THEN 1 ELSE 0 END) AS no_location_count
      FROM shift_delivery_points GROUP BY shift_id
    ''');

    final summaryMap = {
      for (final s in summaryRows)
        s['shift_id'] as String: ShiftSummaryModel(
          totalPoints: (s['total_points'] as num?)?.toInt() ?? 0,
          verifiedCount: (s['verified_count'] as num?)?.toInt() ?? 0,
          temporaryCount: (s['temporary_count'] as num?)?.toInt() ?? 0,
          noLocationCount: (s['no_location_count'] as num?)?.toInt() ?? 0,
        )
    };

    return shiftRows.map((r) => _mapToShiftModel(r, summaryMap[r['id'] as String] ?? ShiftSummaryModel())).toList();
  }

  @override
  Future<ShiftModel> createShift({String? shiftDate, String? shiftName, String? notes}) async {
    final db = await _appDb.database;
    final res = await ShiftCodeHelpers.resolveShiftCodeAndName(db: db, shiftDate: shiftDate, shiftName: shiftName);
    final workDate = res['workDate'] as String, code = res['shiftCode'] as String, name = res['shiftName'] as String;
    final shiftId = UuidUtils.generate(), now = AppDatabase.currentIsoUtc();

    await db.insert('shifts', {
      'id': shiftId, 'shift_code': code, 'shift_name': name, 'work_date': workDate,
      'status': 'PREPARING', 'created_at': now, 'updated_at': now,
    });
    await _appDb.logActivity(action: 'CREATE_SHIFT', entity: 'shifts', entityId: shiftId, details: {'shiftCode': code, 'shiftName': name, 'workDate': workDate});

    return ShiftModel(id: shiftId, shiftCode: code, shiftName: name, shiftDate: workDate, shipperId: defaultShipperId, status: ShiftStatus.preparing, createdAt: DateTime.tryParse(now), updatedAt: DateTime.tryParse(now), notes: notes);
  }

  @override
  Future<ShiftModel> getShiftDetail(String shiftId) async {
    final db = await _appDb.database;
    final shiftRows = await db.query('shifts', where: 'id = ?', whereArgs: [shiftId], limit: 1);
    if (shiftRows.isEmpty) throw Exception('Không tìm thấy ca làm việc');

    final pointRows = await db.rawQuery('''
      SELECT sdp.*, c.full_name AS customer_name, c.phone_number AS customer_phone, c.address_text AS customer_address,
             sl.latitude AS saved_lat, sl.longitude AS saved_lng, sl.identification_notes AS saved_notes
      FROM shift_delivery_points sdp JOIN customers c ON sdp.customer_id = c.id
      LEFT JOIN saved_locations sl ON sdp.customer_id = sl.customer_id
      WHERE sdp.shift_id = ? ORDER BY sdp.delivery_order_index ASC, sdp.created_at ASC
    ''', [shiftId]);

    final initial = pointRows.map(_mapToPointModel).toList();
    final summaries = await _photoRepo.getBatchPhotoSummaries(initial.map((p) => p.customerId).toSet().toList());

    final points = initial.map((p) {
      final s = summaries[p.customerId];
      return s != null ? p.copyWith(photoCount: s['photoCount'] as int, photos: s['photos'] as List<CustomerPhotoModel>, photoUrl: s['firstThumbnailUrl'] as String?) : p;
    }).toList();

    int ver = 0, temp = 0, noLoc = 0;
    for (final p in points) {
      switch (p.locationStatus) {
        case LocationStatus.verified: ver++; break;
        case LocationStatus.temporary: temp++; break;
        case LocationStatus.noLocation: noLoc++; break;
      }
    }

    return _mapToShiftModel(shiftRows.first, ShiftSummaryModel(totalPoints: points.length, verifiedCount: ver, temporaryCount: temp, noLocationCount: noLoc), points);
  }

  @override
  Future<ShiftModel> updateShiftName(String shiftId, String shiftName) async {
    final db = await _appDb.database;
    final clean = shiftName.trim();
    if (clean.isEmpty) throw ArgumentError('Tên ca làm việc không được để trống');
    final name = clean.length > 100 ? clean.substring(0, 100) : clean;
    final now = AppDatabase.currentIsoUtc();

    final count = await db.update('shifts', {'shift_name': name, 'updated_at': now}, where: 'id = ?', whereArgs: [shiftId]);
    if (count == 0) throw Exception('Không tìm thấy ca làm việc');
    await _appDb.logActivity(action: 'UPDATE_SHIFT_NAME', entity: 'shifts', entityId: shiftId, details: {'shiftName': name});
    return getShiftDetail(shiftId);
  }

  @override
  Future<ShiftModel> updateShiftStatus(String shiftId, ShiftStatus status) async {
    final db = await _appDb.database;
    final rows = await db.query('shifts', where: 'id = ?', whereArgs: [shiftId], limit: 1);
    if (rows.isEmpty) throw Exception('Không tìm thấy ca làm việc');

    final cur = ShiftStatus.fromString(rows.first['status'] as String?);
    if (cur == ShiftStatus.completed) throw Exception('Ca làm việc đã hoàn thành, không thể thay đổi trạng thái.');
    if (cur == ShiftStatus.preparing && status == ShiftStatus.completed) throw Exception('Không thể chuyển ca từ PREPARING sang COMPLETED. Vui lòng chuyển sang IN_PROGRESS trước.');
    if (cur == ShiftStatus.inProgress && status == ShiftStatus.preparing) throw Exception('Không thể chuyển ca từ IN_PROGRESS ngược về PREPARING.');

    final now = AppDatabase.currentIsoUtc();
    final updateData = <String, dynamic>{'status': status.toApiString(), 'updated_at': now};
    if (status == ShiftStatus.inProgress && rows.first['started_at'] == null) updateData['started_at'] = now;
    if (status == ShiftStatus.completed) updateData['completed_at'] = now;

    await db.update('shifts', updateData, where: 'id = ?', whereArgs: [shiftId]);
    await _appDb.logActivity(action: 'UPDATE_SHIFT_STATUS', entity: 'shifts', entityId: shiftId, details: {'fromStatus': cur.toApiString(), 'toStatus': status.toApiString()});
    return getShiftDetail(shiftId);
  }

  @override
  Future<bool> deleteShift(String shiftId) async {
    final db = await _appDb.database;
    final rows = await db.query('shifts', where: 'id = ?', whereArgs: [shiftId], limit: 1);
    if (rows.isEmpty) return false;

    final shift = rows.first;
    final ptsCountRows = await db.rawQuery('SELECT COUNT(*) AS total FROM shift_delivery_points WHERE shift_id = ?', [shiftId]);
    final ptsCount = (ptsCountRows.first['total'] as num?)?.toInt() ?? 0;

    await db.transaction((txn) async {
      await txn.delete('shift_delivery_points', where: 'shift_id = ?', whereArgs: [shiftId]);
      await txn.delete('shifts', where: 'id = ?', whereArgs: [shiftId]);
      await _appDb.logActivity(action: 'DELETE_SHIFT', entity: 'shifts', entityId: shiftId, details: {'shiftCode': shift['shift_code'], 'status': shift['status'], 'deletedPointsCount': ptsCount}, executor: txn);
    });
    return true;
  }

  @override
  Future<Map<String, dynamic>> addPointToShift(String shiftId, {String? customerId, String? phoneNumber, bool createIfNotFound = false, String? fullName, String? addressText, String? orderId, int? sequenceNumber, String? deliveryNotes, String? areaId}) =>
      _addPointToShift(shiftId, customerId: customerId, phoneNumber: phoneNumber, createIfNotFound: createIfNotFound, fullName: fullName, addressText: addressText, orderId: orderId, sequenceNumber: sequenceNumber, deliveryNotes: deliveryNotes, areaId: areaId);

  @override
  Future<BulkAddPointsResult> addBulkPointsToShift({required String shiftId, String? rawText, List<String>? phones, String? areaId}) async {
    return await ShiftBulkHelpers.executeBulkAdd(db: await _appDb.database, appDb: _appDb, shiftId: shiftId, rawText: rawText, phones: phones, defaultAreaId: defaultAreaId, defaultAreaName: defaultAreaName);
  }

  @override
  Future<void> removePointFromShift(String shiftId, String pointId) => _removePointFromShift(shiftId, pointId);

  @override
  Future<List<OrderModel>> getMyShiftOrders() => _getMyShiftOrders();

  @override
  Future<Map<String, dynamic>> addOrderToShift({required String customerId, bool allowMultiple = false, String? idempotencyKey}) =>
      _addOrderToShift(customerId: customerId, allowMultiple: allowMultiple, idempotencyKey: idempotencyKey);

  @override
  Future<void> verifyPointLocation(String shiftId, String pointId) async {
    throw UnsupportedError('Endpoint xác minh vị trí trong ca đã ngừng hoạt động (410 Gone). Theo quy chuẩn LOCATION-RULES-012, vị trí chuẩn chỉ được xác nhận qua luồng Danh bạ -> Hồ sơ khách -> Xác nhận vị trí.');
  }

  ShiftModel _mapToShiftModel(Map<String, dynamic> r, ShiftSummaryModel summary, [List<ShiftDeliveryPointModel> points = const []]) => ShiftModel(
    id: r['id'] as String, shiftCode: r['shift_code'] as String, shiftName: r['shift_name'] as String?,
    shiftDate: (r['work_date'] as String?)?.split('T')[0] ?? '', shipperId: defaultShipperId,
    status: ShiftStatus.fromString(r['status'] as String?), startedAt: DateTime.tryParse(r['started_at']?.toString() ?? ''),
    completedAt: DateTime.tryParse(r['completed_at']?.toString() ?? ''), createdAt: DateTime.tryParse(r['created_at']?.toString() ?? ''),
    updatedAt: DateTime.tryParse(r['updated_at']?.toString() ?? ''), summary: summary, deliveryPoints: points,
  );

  ShiftDeliveryPointModel _mapToPointModel(Map<String, dynamic> r) => ShiftRowMapper.mapToPointModel(r);
}
