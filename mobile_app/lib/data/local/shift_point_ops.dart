part of 'local_shift_repository.dart';

/// Các thao tác quản lý điểm giao hàng trong ca (Thêm điểm đơn lẻ, tính thống kê tóm tắt, tìm ca hiện tại)
extension _ShiftPointOps on LocalShiftRepository {
  /// Thêm một điểm giao hàng vào ca làm việc (tìm khách hoặc tạo nhanh nếu chưa có)
  Future<Map<String, dynamic>> _addPointToShift(
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
  }) async {
    final db = await _appDb.database;

    return await db.transaction<Map<String, dynamic>>((txn) async {
      // 1. Kiểm tra ca làm việc tồn tại
      final shiftRows = await txn.query(
        'shifts',
        where: 'id = ?',
        whereArgs: [shiftId],
        limit: 1,
      );
      if (shiftRows.isEmpty) {
        throw Exception('Không tìm thấy ca làm việc');
      }

      // 2. Xác định khách hàng
      Map<String, dynamic>? targetCustomer;
      if (customerId != null && customerId.isNotEmpty) {
        final custRows = await txn.query(
          'customers',
          where: 'id = ? AND deleted_at IS NULL',
          whereArgs: [customerId],
          limit: 1,
        );
        if (custRows.isNotEmpty) {
          targetCustomer = custRows.first;
        }
      }

      if (targetCustomer == null && phoneNumber != null && phoneNumber.trim().isNotEmpty) {
        final normPhone = normalizeCustomerPhone(phoneNumber);
        final custRows = await txn.query(
          'customers',
          where: 'phone_number = ? AND deleted_at IS NULL',
          whereArgs: [normPhone],
          limit: 1,
        );
        if (custRows.isNotEmpty) {
          targetCustomer = custRows.first;
        } else {
          // Tạo khách hàng nhanh nếu chưa có trong CSDL
          final newCustId = UuidUtils.generate();
          final custName = (fullName != null && fullName.trim().isNotEmpty)
              ? fullName.trim()
              : 'Khách $normPhone';
          final custAddress = (addressText != null && addressText.trim().isNotEmpty)
              ? addressText.trim()
              : 'Chưa cập nhật địa chỉ';
          final nowIso = AppDatabase.currentIsoUtc();
          final searchText = buildCustomerSearchText(
            fullName: custName,
            phoneNumber: normPhone,
            addressText: custAddress,
          );

          await txn.insert('customers', {
            'id': newCustId,
            'customer_code': null,
            'full_name': custName,
            'phone_number': normPhone,
            'address_text': custAddress,
            'notes': deliveryNotes,
            'search_text': searchText,
            'created_at': nowIso,
            'updated_at': nowIso,
            'deleted_at': null,
          });

          targetCustomer = {
            'id': newCustId,
            'customer_code': null,
            'full_name': custName,
            'phone_number': normPhone,
            'address_text': custAddress,
          };
        }
      }

      if (targetCustomer == null) {
        throw Exception('Vui lòng cung cấp customerId hoặc phoneNumber hợp lệ');
      }

      final custId = targetCustomer['id'] as String;

      // 3. Kiểm tra xem khách đã có trong ca chưa
      final existingPointRows = await txn.rawQuery('''
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
        WHERE sdp.shift_id = ? AND sdp.customer_id = ?
        LIMIT 1
      ''', [shiftId, custId]);

      if (existingPointRows.isNotEmpty) {
        final existingPoint = _mapToPointModel(existingPointRows.first);
        final summary = await _calculateSummary(txn, shiftId);
        return {
          'isExisting': true,
          'message': 'Khách hàng đã có trong ca làm việc',
          'point': existingPoint,
          'summary': summary,
        };
      }

      // 4. Kiểm tra vị trí đã lưu của khách hàng
      final savedLocRows = await txn.query(
        'saved_locations',
        where: 'customer_id = ?',
        whereArgs: [custId],
        limit: 1,
      );

      LocationStatus locStatus = LocationStatus.noLocation;
      double? lat;
      double? lng;
      double? gps;
      String? identNotes;

      if (savedLocRows.isNotEmpty) {
        final sl = savedLocRows.first;
        locStatus = LocationStatus.verified;
        lat = (sl['latitude'] as num?)?.toDouble();
        lng = (sl['longitude'] as num?)?.toDouble();
        gps = (sl['gps_accuracy'] as num?)?.toDouble();
        identNotes = sl['identification_notes'] as String?;
      }

      // 5. Xác định thứ tự giao trong ca (delivery_order_index)
      final maxIndexRows = await txn.rawQuery(
        'SELECT MAX(delivery_order_index) AS max_idx FROM shift_delivery_points WHERE shift_id = ?',
        [shiftId],
      );
      final maxIdx = (maxIndexRows.first['max_idx'] as int?) ?? 0;
      final targetIndex = sequenceNumber ?? (maxIdx + 1);

      final pointId = UuidUtils.generate();
      final nowIso = AppDatabase.currentIsoUtc();

      await txn.insert('shift_delivery_points', {
        'id': pointId,
        'shift_id': shiftId,
        'customer_id': custId,
        'delivery_order_index': targetIndex,
        'location_status': locStatus.toApiString(),
        'latitude': lat,
        'longitude': lng,
        'gps_accuracy': gps,
        'identification_notes': identNotes,
        'created_at': nowIso,
        'updated_at': nowIso,
      });

      final newPoint = ShiftDeliveryPointModel(
        id: pointId,
        shiftId: shiftId,
        customerId: custId,
        customerName: (targetCustomer['full_name'] as String?) ?? 'Khách hàng',
        customerPhone: (targetCustomer['phone_number'] as String?) ?? '',
        customerAddress: (targetCustomer['address_text'] as String?) ?? '',
        areaId: LocalShiftRepository.defaultAreaId,
        areaName: LocalShiftRepository.defaultAreaName,
        orderId: orderId,
        sequenceNumber: targetIndex,
        deliveryStatus: 'PENDING',
        locationStatus: locStatus,
        latitude: lat,
        longitude: lng,
        locationNotes: identNotes,
        deliveryNotes: deliveryNotes,
        createdAt: DateTime.tryParse(nowIso),
        updatedAt: DateTime.tryParse(nowIso),
      );

      final updatedSummary = await _calculateSummary(txn, shiftId);

      await _appDb.logActivity(
        action: 'ADD_POINT_TO_SHIFT',
        entity: 'shift_delivery_points',
        entityId: pointId,
        details: {
          'shiftId': shiftId,
          'customerId': custId,
          'locationStatus': locStatus.toApiString(),
          'deliveryOrderIndex': targetIndex,
        },
        executor: txn,
      );

      return {
        'isExisting': false,
        'message': 'Đã thêm điểm giao vào ca thành công',
        'point': newPoint,
        'summary': updatedSummary,
      };
    });
  }

  /// Xóa điểm giao khỏi ca làm việc
  Future<void> _removePointFromShift(String shiftId, String pointId) async {
    final db = await _appDb.database;

    final count = await db.delete(
      'shift_delivery_points',
      where: 'shift_id = ? AND id = ?',
      whereArgs: [shiftId, pointId],
    );

    if (count > 0) {
      await _appDb.logActivity(
        action: 'REMOVE_POINT_FROM_SHIFT',
        entity: 'shift_delivery_points',
        entityId: pointId,
        details: {'shiftId': shiftId},
      );
    }
  }

  /// Lấy danh sách điểm giao của ca đang diễn ra dưới dạng OrderModel
  Future<List<OrderModel>> _getMyShiftOrders() async {
    final db = await _appDb.database;

    // Tìm ca làm việc đang mở: Ưu tiên IN_PROGRESS rồi tới PREPARING mới nhất
    final activeShifts = await db.query(
      'shifts',
      where: "status IN ('IN_PROGRESS', 'PREPARING')",
      orderBy: "CASE status WHEN 'IN_PROGRESS' THEN 1 WHEN 'PREPARING' THEN 2 ELSE 3 END, created_at DESC",
      limit: 1,
    );

    if (activeShifts.isEmpty) {
      return [];
    }

    final shiftId = activeShifts.first['id'] as String;
    final points = await db.rawQuery('''
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

    return ShiftRowMapper.mapPointsToOrders(points, LocalShiftRepository.defaultAreaName);
  }

  /// Thêm đơn giao vào ca đang mở (hoặc tạo ca mới nếu chưa có)
  Future<Map<String, dynamic>> _addOrderToShift({
    required String customerId,
    bool allowMultiple = false,
    String? idempotencyKey,
  }) async {
    final db = await _appDb.database;

    final activeShifts = await db.query(
      'shifts',
      where: "status IN ('IN_PROGRESS', 'PREPARING')",
      orderBy: "CASE status WHEN 'IN_PROGRESS' THEN 1 WHEN 'PREPARING' THEN 2 ELSE 3 END, created_at DESC",
      limit: 1,
    );

    String shiftId;
    if (activeShifts.isNotEmpty) {
      shiftId = activeShifts.first['id'] as String;
    } else {
      final newShift = await createShift();
      shiftId = newShift.id;
    }

    final res = await addPointToShift(
      shiftId,
      customerId: customerId,
    );

    final point = res['point'] as ShiftDeliveryPointModel;
    final orderModel = OrderModel(
      orderId: point.id,
      orderCode: 'ORD-${point.id.substring(0, 8).toUpperCase()}',
      orderStatus: point.deliveryStatus,
      areaName: LocalShiftRepository.defaultAreaName,
      customerId: point.customerId,
      customerName: point.customerName,
      customerPhone: point.customerPhone,
      customerAddress: point.customerAddress,
      hasSavedLocation: point.locationStatus == LocationStatus.verified,
    );

    return {
      'isExisting': res['isExisting'] ?? false,
      'message': res['message'] ?? 'Thành công',
      'order': orderModel,
    };
  }

  /// Tính toán số lượng thống kê của các điểm trong ca
  Future<ShiftSummaryModel> _calculateSummary(DatabaseExecutor executor, String shiftId) async {
    final rows = await executor.rawQuery('''
      SELECT 
        COUNT(*) AS total_points,
        SUM(CASE WHEN location_status = 'VERIFIED' THEN 1 ELSE 0 END) AS verified_count,
        SUM(CASE WHEN location_status = 'TEMPORARY' THEN 1 ELSE 0 END) AS temporary_count,
        SUM(CASE WHEN location_status = 'NO_LOCATION' THEN 1 ELSE 0 END) AS no_location_count
      FROM shift_delivery_points
      WHERE shift_id = ?
    ''', [shiftId]);

    if (rows.isEmpty) return ShiftSummaryModel();
    final r = rows.first;
    return ShiftSummaryModel(
      totalPoints: (r['total_points'] as num?)?.toInt() ?? 0,
      verifiedCount: (r['verified_count'] as num?)?.toInt() ?? 0,
      temporaryCount: (r['temporary_count'] as num?)?.toInt() ?? 0,
      noLocationCount: (r['no_location_count'] as num?)?.toInt() ?? 0,
    );
  }
}

