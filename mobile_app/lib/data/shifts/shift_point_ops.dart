// Xử lý các thao tác quản lý danh sách mốc giao trong ca làm việc.
// Hỗ trợ sắp xếp thứ tự lộ trình, gán vị trí và cập nhật trạng thái điểm.
part of 'shift_repository.dart';

class ShiftCodeHelpers {
  static Future<Map<String, dynamic>> resolveShiftCodeAndName({
    required Database db,
    String? shiftDate,
    String? shiftName,
  }) async {
    final nowVn = DateTime.now().toUtc().add(const Duration(hours: 7));
    final target = (shiftDate?.trim().isNotEmpty == true)
        ? (DateTime.tryParse(shiftDate!.trim()) ?? nowVn)
        : nowVn;
    String pad(int n) => n.toString().padLeft(2, '0');
    final workDate = '${target.year}-${pad(target.month)}-${pad(target.day)}';
    final dateSlug = '${target.year}${pad(target.month)}${pad(target.day)}';

    final rows = await db.rawQuery(
      'SELECT shift_code, shift_name FROM shifts WHERE work_date = ? OR shift_code LIKE ? ORDER BY shift_code DESC',
      [workDate, 'SHF-$dateSlug-%'],
    );
    int maxSeq = 0;
    final pat = RegExp(r'^SHF-\d{8}-(\d+)$');
    for (final r in rows) {
      final code = r['shift_code'] as String?;
      if (code != null) {
        final m = pat.firstMatch(code);
        if (m != null) {
          final s = int.tryParse(m.group(1)!) ?? 0;
          if (s > maxSeq) maxSeq = s;
        }
      }
    }
    final shiftCode = 'SHF-$dateSlug-${(maxSeq + 1).toString().padLeft(3, '0')}';
    final resolvedName = (shiftName?.trim().isNotEmpty == true)
        ? (shiftName!.trim().length > 100 ? shiftName.trim().substring(0, 100) : shiftName.trim())
        : ShiftModel.suggestShiftName(
            dateTime: target,
            existingNames: rows.map((r) => r['shift_name'] as String?).whereType<String>().toList(),
          );

    return {'workDate': workDate, 'shiftCode': shiftCode, 'shiftName': resolvedName, 'targetVnDate': target};
  }
}

class ShiftRowMapper {
  static ShiftDeliveryPointModel mapToPointModel(
    Map<String, dynamic> r, {
    String defaultAreaId = 'local-area',
    String defaultAreaName = 'Khu vực cục bộ',
  }) =>
      ShiftDeliveryPointModel(
        id: r['id'] as String,
        shiftId: r['shift_id'] as String,
        customerId: r['customer_id'] as String,
        customerName: (r['customer_name'] as String?) ?? 'Khách hàng',
        customerPhone: (r['customer_phone'] as String?) ?? '',
        customerAddress: (r['customer_address'] as String?) ?? '',
        areaId: defaultAreaId,
        areaName: defaultAreaName,
        orderId: r['order_id'] as String?,
        sequenceNumber: (r['delivery_order_index'] as num?)?.toInt() ?? 1,
        deliveryStatus: (r['delivery_status'] as String?) ?? 'PENDING',
        locationStatus: LocationStatus.fromString(r['location_status'] as String?),
        latitude: (r['latitude'] as num?)?.toDouble(),
        longitude: (r['longitude'] as num?)?.toDouble(),
        locationNotes: r['identification_notes'] as String?,
        createdAt: DateTime.tryParse(r['created_at']?.toString() ?? ''),
        updatedAt: DateTime.tryParse(r['updated_at']?.toString() ?? ''),
      );
}

extension _ShiftPointOps on LocalShiftRepository {
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
      final shiftRows = await txn.query('shifts', where: 'id = ?', whereArgs: [shiftId], limit: 1);
      if (shiftRows.isEmpty) throw Exception('Không tìm thấy ca làm việc');

      Map<String, dynamic>? cust;
      if (customerId != null && customerId.isNotEmpty) {
        final rows = await txn.query('customers', where: 'id = ? AND deleted_at IS NULL', whereArgs: [customerId], limit: 1);
        if (rows.isNotEmpty) cust = rows.first;
      }
      if (cust == null && phoneNumber != null && phoneNumber.trim().isNotEmpty) {
        final norm = normalizeCustomerPhone(phoneNumber);
        final rows = await txn.query('customers', where: 'phone_number = ? AND deleted_at IS NULL', whereArgs: [norm], limit: 1);
        if (rows.isNotEmpty) {
          cust = rows.first;
        } else {
          final newId = UuidUtils.generate(), name = (fullName?.trim().isNotEmpty == true) ? fullName!.trim() : 'Khách $norm';
          final addr = (addressText?.trim().isNotEmpty == true) ? addressText!.trim() : 'Chưa cập nhật địa chỉ';
          final now = AppDatabase.currentIsoUtc();
          await txn.insert('customers', {
            'id': newId,
            'customer_code': null,
            'full_name': name,
            'phone_number': norm,
            'address_text': addr,
            'notes': deliveryNotes,
            'search_text': buildCustomerSearchText(fullName: name, phoneNumber: norm, addressText: addr),
            'created_at': now,
            'updated_at': now,
            'deleted_at': null,
          });
          cust = {'id': newId, 'full_name': name, 'phone_number': norm, 'address_text': addr};
        }
      }
      if (cust == null) throw Exception('Vui lòng cung cấp customerId hoặc phoneNumber hợp lệ');

      final cId = cust['id'] as String;
      final existPts = await txn.rawQuery('''
        SELECT sdp.*, c.full_name AS customer_name, c.phone_number AS customer_phone, c.address_text AS customer_address,
               sl.latitude AS saved_lat, sl.longitude AS saved_lng, sl.identification_notes AS saved_notes
        FROM shift_delivery_points sdp JOIN customers c ON sdp.customer_id = c.id
        LEFT JOIN saved_locations sl ON sdp.customer_id = sl.customer_id
        WHERE sdp.shift_id = ? AND sdp.customer_id = ? LIMIT 1
      ''', [shiftId, cId]);

      if (existPts.isNotEmpty) {
        return {
          'isExisting': true,
          'message': 'Khách hàng đã có trong ca làm việc',
          'point': _mapToPointModel(existPts.first),
          'summary': await _calculateSummary(txn, shiftId),
        };
      }

      final saved = await txn.query('saved_locations', where: 'customer_id = ?', whereArgs: [cId], limit: 1);
      final hasSaved = saved.isNotEmpty;
      final locStatus = hasSaved ? LocationStatus.verified : LocationStatus.noLocation;
      final lat = hasSaved ? (saved.first['latitude'] as num?)?.toDouble() : null;
      final lng = hasSaved ? (saved.first['longitude'] as num?)?.toDouble() : null;
      final gps = hasSaved ? (saved.first['gps_accuracy'] as num?)?.toDouble() : null;
      final ident = hasSaved ? saved.first['identification_notes'] as String? : null;

      final maxIdxRows = await txn.rawQuery('SELECT MAX(delivery_order_index) AS max_idx FROM shift_delivery_points WHERE shift_id = ?', [shiftId]);
      final targetIdx = sequenceNumber ?? (((maxIdxRows.first['max_idx'] as int?) ?? 0) + 1);
      final pointId = UuidUtils.generate(), now = AppDatabase.currentIsoUtc();

      await txn.insert('shift_delivery_points', {
        'id': pointId,
        'shift_id': shiftId,
        'customer_id': cId,
        'delivery_order_index': targetIdx,
        'location_status': locStatus.toApiString(),
        'latitude': lat,
        'longitude': lng,
        'gps_accuracy': gps,
        'identification_notes': ident,
        'created_at': now,
        'updated_at': now,
      });

      final newPoint = ShiftDeliveryPointModel(
        id: pointId,
        shiftId: shiftId,
        customerId: cId,
        customerName: (cust['full_name'] as String?) ?? 'Khách hàng',
        customerPhone: (cust['phone_number'] as String?) ?? '',
        customerAddress: (cust['address_text'] as String?) ?? '',
        areaId: LocalShiftRepository.defaultAreaId,
        areaName: LocalShiftRepository.defaultAreaName,
        orderId: orderId,
        sequenceNumber: targetIdx,
        deliveryStatus: 'PENDING',
        locationStatus: locStatus,
        latitude: lat,
        longitude: lng,
        locationNotes: ident,
        deliveryNotes: deliveryNotes,
        createdAt: DateTime.tryParse(now),
        updatedAt: DateTime.tryParse(now),
      );

      final summary = await _calculateSummary(txn, shiftId);
      await _appDb.logActivity(
        action: 'ADD_POINT_TO_SHIFT',
        entity: 'shift_delivery_points',
        entityId: pointId,
        details: {'shiftId': shiftId, 'customerId': cId, 'locationStatus': locStatus.toApiString(), 'deliveryOrderIndex': targetIdx},
        executor: txn,
      );
      return {'isExisting': false, 'message': 'Đã thêm điểm giao vào ca thành công', 'point': newPoint, 'summary': summary};
    });
  }

  Future<void> _removePointFromShift(String shiftId, String pointId) async {
    final db = await _appDb.database;
    final c = await db.delete('shift_delivery_points', where: 'shift_id = ? AND id = ?', whereArgs: [shiftId, pointId]);
    if (c > 0) {
      await _appDb.logActivity(
        action: 'REMOVE_POINT_FROM_SHIFT',
        entity: 'shift_delivery_points',
        entityId: pointId,
        details: {'shiftId': shiftId},
      );
    }
  }

  Future<ShiftSummaryModel> _calculateSummary(DatabaseExecutor executor, String shiftId) async {
    final rows = await executor.rawQuery('''
      SELECT COUNT(*) AS total_points,
             SUM(CASE WHEN location_status = 'VERIFIED' THEN 1 ELSE 0 END) AS verified_count,
             SUM(CASE WHEN location_status = 'TEMPORARY' THEN 1 ELSE 0 END) AS temporary_count,
             SUM(CASE WHEN location_status = 'NO_LOCATION' THEN 1 ELSE 0 END) AS no_location_count
      FROM shift_delivery_points WHERE shift_id = ?
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

