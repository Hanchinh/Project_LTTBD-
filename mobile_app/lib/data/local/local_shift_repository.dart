import 'package:sqflite/sqflite.dart';

import 'package:delivery_marker_mobile/core/utils/phone_utils.dart';
import 'package:delivery_marker_mobile/core/utils/uuid_utils.dart';
import 'package:delivery_marker_mobile/core/utils/vietnamese_utils.dart';
import 'package:delivery_marker_mobile/data/local/app_database.dart';
import 'package:delivery_marker_mobile/data/local/local_customer_repository.dart';
import 'package:delivery_marker_mobile/data/local/local_photo_repository.dart';
import 'package:delivery_marker_mobile/data/local/shift_bulk_helpers.dart';
import 'package:delivery_marker_mobile/data/local/shift_code_helpers.dart';
import 'package:delivery_marker_mobile/data/local/shift_row_mapper.dart';
import 'package:delivery_marker_mobile/data/repositories/shift_repository.dart';
import 'package:delivery_marker_mobile/models/customer_photo_model.dart';
import 'package:delivery_marker_mobile/models/order_model.dart';
import 'package:delivery_marker_mobile/models/shift_model.dart';

part 'shift_point_ops.dart';

/// Triển khai ShiftRepository cục bộ bằng SQLite (Local-First).
/// Toàn bộ dữ liệu ca làm việc, điểm giao và dán hàng loạt được lưu trữ trên thiết bị.
class LocalShiftRepository implements ShiftRepository {
  final AppDatabase _appDb;
  final LocalPhotoRepository _photoRepo;

  LocalShiftRepository({AppDatabase? appDb, LocalPhotoRepository? photoRepo})
      : _appDb = appDb ?? AppDatabase.instance,
        _photoRepo = photoRepo ?? LocalPhotoRepository(appDb: appDb ?? AppDatabase.instance);

  static const String defaultAreaId = LocalCustomerRepository.defaultAreaId;
  static const String defaultAreaName = LocalCustomerRepository.defaultAreaName;
  static const String defaultShipperId = 'local-shipper';

  @override
  Future<List<ShiftModel>> getShifts() async {
    final db = await _appDb.database;

    // Lấy toàn bộ ca làm việc sắp xếp mới nhất trước
    final shiftRows = await db.query(
      'shifts',
      orderBy: 'work_date DESC, created_at DESC',
    );

    if (shiftRows.isEmpty) {
      return [];
    }

    // Lấy thống kê tổng hợp (summary) cho toàn bộ ca
    final summaryRows = await db.rawQuery('''
      SELECT 
        shift_id,
        COUNT(*) AS total_points,
        SUM(CASE WHEN location_status = 'VERIFIED' THEN 1 ELSE 0 END) AS verified_count,
        SUM(CASE WHEN location_status = 'TEMPORARY' THEN 1 ELSE 0 END) AS temporary_count,
        SUM(CASE WHEN location_status = 'NO_LOCATION' THEN 1 ELSE 0 END) AS no_location_count
      FROM shift_delivery_points
      GROUP BY shift_id
    ''');

    final summaryMap = <String, ShiftSummaryModel>{};
    for (final s in summaryRows) {
      final sId = s['shift_id'] as String;
      summaryMap[sId] = ShiftSummaryModel(
        totalPoints: (s['total_points'] as num?)?.toInt() ?? 0,
        verifiedCount: (s['verified_count'] as num?)?.toInt() ?? 0,
        temporaryCount: (s['temporary_count'] as num?)?.toInt() ?? 0,
        noLocationCount: (s['no_location_count'] as num?)?.toInt() ?? 0,
      );
    }

    return shiftRows.map((r) {
      final shiftId = r['id'] as String;
      final summary = summaryMap[shiftId] ?? ShiftSummaryModel();
      return _mapToShiftModel(r, summary);
    }).toList();
  }

  @override
  Future<ShiftModel> createShift({
    String? shiftDate,
    String? shiftName,
    String? notes,
  }) async {
    final db = await _appDb.database;
    final resolved = await ShiftCodeHelpers.resolveShiftCodeAndName(
      db: db,
      shiftDate: shiftDate,
      shiftName: shiftName,
    );
    final workDateStr = resolved['workDate'] as String;
    final shiftCode = resolved['shiftCode'] as String;
    final resolvedName = resolved['shiftName'] as String;

    final shiftId = UuidUtils.generate();
    final nowIso = AppDatabase.currentIsoUtc();

    await db.insert('shifts', {
      'id': shiftId,
      'shift_code': shiftCode,
      'shift_name': resolvedName,
      'work_date': workDateStr,
      'status': 'PREPARING',
      'started_at': null,
      'completed_at': null,
      'created_at': nowIso,
      'updated_at': nowIso,
    });

    await _appDb.logActivity(
      action: 'CREATE_SHIFT',
      entity: 'shifts',
      entityId: shiftId,
      details: {
        'shiftCode': shiftCode,
        'shiftName': resolvedName,
        'workDate': workDateStr,
      },
    );

    return ShiftModel(
      id: shiftId,
      shiftCode: shiftCode,
      shiftName: resolvedName,
      shiftDate: workDateStr,
      shipperId: defaultShipperId,
      status: ShiftStatus.preparing,
      startedAt: null,
      completedAt: null,
      createdAt: DateTime.tryParse(nowIso),
      updatedAt: DateTime.tryParse(nowIso),
      notes: notes,
      summary: ShiftSummaryModel(),
      deliveryPoints: [],
    );
  }

  @override
  Future<ShiftModel> getShiftDetail(String shiftId) async {
    final db = await _appDb.database;

    final shiftRows = await db.query(
      'shifts',
      where: 'id = ?',
      whereArgs: [shiftId],
      limit: 1,
    );

    if (shiftRows.isEmpty) {
      throw Exception('Không tìm thấy ca làm việc');
    }

    final shiftRow = shiftRows.first;

    // Lấy toàn bộ điểm giao trong ca kèm thông tin khách hàng và vị trí đã xác nhận (nếu có)
    final pointRows = await db.rawQuery('''
      SELECT 
        sdp.*,
        c.full_name AS customer_name,
        c.phone_number AS customer_phone,
        c.address_text AS customer_address,
        sl.latitude AS saved_lat,
        sl.longitude AS saved_lng,
        sl.identification_notes AS saved_notes
      FROM shift_delivery_points sdp
      JOIN customers c ON sdp.customer_id = c.id
      LEFT JOIN saved_locations sl ON sdp.customer_id = sl.customer_id
      WHERE sdp.shift_id = ?
      ORDER BY sdp.delivery_order_index ASC, sdp.created_at ASC
    ''', [shiftId]);

    final initialPoints = pointRows.map(_mapToPointModel).toList();
    final customerIds = initialPoints.map((p) => p.customerId).toSet().toList();
    final photoSummaries = await _photoRepo.getBatchPhotoSummaries(customerIds);

    final points = initialPoints.map((p) {
      final summary = photoSummaries[p.customerId];
      if (summary != null) {
        final count = summary['photoCount'] as int;
        final photos = summary['photos'] as List<CustomerPhotoModel>;
        final firstThumb = summary['firstThumbnailUrl'] as String?;
        return p.copyWith(
          photoCount: count,
          photos: photos,
          photoUrl: firstThumb,
        );
      }
      return p;
    }).toList();

    int verifiedCount = 0;
    int temporaryCount = 0;
    int noLocationCount = 0;
    for (final p in points) {
      switch (p.locationStatus) {
        case LocationStatus.verified:
          verifiedCount++;
          break;
        case LocationStatus.temporary:
          temporaryCount++;
          break;
        case LocationStatus.noLocation:
          noLocationCount++;
          break;
      }
    }

    final summary = ShiftSummaryModel(
      totalPoints: points.length,
      verifiedCount: verifiedCount,
      temporaryCount: temporaryCount,
      noLocationCount: noLocationCount,
    );

    return _mapToShiftModel(shiftRow, summary, points);
  }

  @override
  Future<ShiftModel> updateShiftName(String shiftId, String shiftName) async {
    final db = await _appDb.database;

    final cleanName = shiftName.trim();
    if (cleanName.isEmpty) {
      throw ArgumentError('Tên ca làm việc không được để trống');
    }
    final truncatedName = cleanName.length > 100 ? cleanName.substring(0, 100) : cleanName;
    final nowIso = AppDatabase.currentIsoUtc();

    final count = await db.update(
      'shifts',
      {
        'shift_name': truncatedName,
        'updated_at': nowIso,
      },
      where: 'id = ?',
      whereArgs: [shiftId],
    );

    if (count == 0) {
      throw Exception('Không tìm thấy ca làm việc');
    }

    await _appDb.logActivity(
      action: 'UPDATE_SHIFT_NAME',
      entity: 'shifts',
      entityId: shiftId,
      details: {'shiftName': truncatedName},
    );

    return getShiftDetail(shiftId);
  }

  @override
  Future<ShiftModel> updateShiftStatus(String shiftId, ShiftStatus status) async {
    final db = await _appDb.database;

    final shiftRows = await db.query(
      'shifts',
      where: 'id = ?',
      whereArgs: [shiftId],
      limit: 1,
    );

    if (shiftRows.isEmpty) {
      throw Exception('Không tìm thấy ca làm việc');
    }

    final currentStatusStr = shiftRows.first['status'] as String? ?? 'PREPARING';
    final currentStatus = ShiftStatus.fromString(currentStatusStr);

    // Kiểm tra tính hợp lệ của việc chuyển đổi trạng thái: PREPARING -> IN_PROGRESS -> COMPLETED
    if (currentStatus == ShiftStatus.completed) {
      throw Exception('Ca làm việc đã hoàn thành, không thể thay đổi trạng thái.');
    }

    if (currentStatus == ShiftStatus.preparing && status == ShiftStatus.completed) {
      throw Exception('Không thể chuyển ca từ PREPARING sang COMPLETED. Vui lòng chuyển sang IN_PROGRESS trước.');
    }

    if (currentStatus == ShiftStatus.inProgress && status == ShiftStatus.preparing) {
      throw Exception('Không thể chuyển ca từ IN_PROGRESS ngược về PREPARING.');
    }

    final nowIso = AppDatabase.currentIsoUtc();
    final updateData = <String, dynamic>{
      'status': status.toApiString(),
      'updated_at': nowIso,
    };

    if (status == ShiftStatus.inProgress) {
      final existingStartedAt = shiftRows.first['started_at'];
      if (existingStartedAt == null) {
        updateData['started_at'] = nowIso;
      }
    } else if (status == ShiftStatus.completed) {
      updateData['completed_at'] = nowIso;
    }

    await db.update(
      'shifts',
      updateData,
      where: 'id = ?',
      whereArgs: [shiftId],
    );

    await _appDb.logActivity(
      action: 'UPDATE_SHIFT_STATUS',
      entity: 'shifts',
      entityId: shiftId,
      details: {
        'fromStatus': currentStatusStr,
        'toStatus': status.toApiString(),
      },
    );

    return getShiftDetail(shiftId);
  }

  @override
  Future<bool> deleteShift(String shiftId) async {
    final db = await _appDb.database;

    final shiftRows = await db.query(
      'shifts',
      where: 'id = ?',
      whereArgs: [shiftId],
      limit: 1,
    );

    if (shiftRows.isEmpty) {
      return false;
    }

    final shift = shiftRows.first;
    final shiftCode = shift['shift_code'] as String? ?? '';
    final status = shift['status'] as String? ?? '';

    // Đếm số điểm giao trước khi xóa để ghi audit log
    final pointsCountRows = await db.rawQuery(
      'SELECT COUNT(*) AS total FROM shift_delivery_points WHERE shift_id = ?',
      [shiftId],
    );
    final pointsCount = (pointsCountRows.first['total'] as num?)?.toInt() ?? 0;

    // Thực thi xóa trong transaction: Cascade xóa shift_delivery_points, TUYỆT ĐỐI KHÔNG xóa customers hay saved_locations
    await db.transaction((txn) async {
      await txn.delete(
        'shift_delivery_points',
        where: 'shift_id = ?',
        whereArgs: [shiftId],
      );

      await txn.delete(
        'shifts',
        where: 'id = ?',
        whereArgs: [shiftId],
      );

      await _appDb.logActivity(
        action: 'DELETE_SHIFT',
        entity: 'shifts',
        entityId: shiftId,
        details: {
          'shiftCode': shiftCode,
          'status': status,
          'deletedPointsCount': pointsCount,
        },
        executor: txn,
      );
    });

    return true;
  }

  @override
  Future<Map<String, dynamic>> addPointToShift(
    String shiftId, {
    String? customerId,
    String? phoneNumber,
    bool createIfNotFound = false,
    String? fullName,
    String? addressText,
    String? orderId,
    int? sequenceNumber,
    String? deliveryNotes,
    String? areaId,
  }) =>
      _addPointToShift(
        shiftId,
        customerId: customerId,
        phoneNumber: phoneNumber,
        createIfNotFound: createIfNotFound,
        fullName: fullName,
        addressText: addressText,
        orderId: orderId,
        sequenceNumber: sequenceNumber,
        deliveryNotes: deliveryNotes,
        areaId: areaId,
      );

  @override
  Future<BulkAddPointsResult> addBulkPointsToShift({
    required String shiftId,
    String? rawText,
    List<String>? phones,
    String? areaId,
  }) async {
    final db = await _appDb.database;
    return await ShiftBulkHelpers.executeBulkAdd(
      db: db,
      appDb: _appDb,
      shiftId: shiftId,
      rawText: rawText,
      phones: phones,
      defaultAreaId: defaultAreaId,
      defaultAreaName: defaultAreaName,
    );
  }

  @override
  Future<void> removePointFromShift(String shiftId, String pointId) =>
      _removePointFromShift(shiftId, pointId);

  @override
  Future<List<OrderModel>> getMyShiftOrders() => _getMyShiftOrders();

  @override
  Future<Map<String, dynamic>> addOrderToShift({
    required String customerId,
    bool allowMultiple = false,
    String? idempotencyKey,
  }) =>
      _addOrderToShift(
        customerId: customerId,
        allowMultiple: allowMultiple,
        idempotencyKey: idempotencyKey,
      );

  @override
  Future<void> verifyPointLocation(String shiftId, String pointId) async {
    throw UnsupportedError(
      'Endpoint xác minh vị trí trong ca đã ngừng hoạt động (410 Gone). Theo quy chuẩn LOCATION-RULES-012, vị trí chuẩn chỉ được xác nhận qua luồng Danh bạ -> Hồ sơ khách -> Xác nhận vị trí.',
    );
  }

  // ===========================================================================
  // CÁC HÀM TIỆN ÍCH ÁNH XẠ DỮ LIỆU CỤC BỘ
  // ===========================================================================

  ShiftModel _mapToShiftModel(
    Map<String, dynamic> r,
    ShiftSummaryModel summary, [
    List<ShiftDeliveryPointModel> points = const [],
  ]) {
    final workDate = (r['work_date'] as String?)?.split('T')[0] ?? '';
    return ShiftModel(
      id: r['id'] as String,
      shiftCode: r['shift_code'] as String,
      shiftName: r['shift_name'] as String?,
      shiftDate: workDate,
      shipperId: defaultShipperId,
      status: ShiftStatus.fromString(r['status'] as String?),
      startedAt: DateTime.tryParse(r['started_at']?.toString() ?? ''),
      completedAt: DateTime.tryParse(r['completed_at']?.toString() ?? ''),
      createdAt: DateTime.tryParse(r['created_at']?.toString() ?? ''),
      updatedAt: DateTime.tryParse(r['updated_at']?.toString() ?? ''),
      notes: null,
      summary: summary,
      deliveryPoints: points,
    );
  }

  ShiftDeliveryPointModel _mapToPointModel(Map<String, dynamic> r) => ShiftRowMapper.mapToPointModel(r);
}
