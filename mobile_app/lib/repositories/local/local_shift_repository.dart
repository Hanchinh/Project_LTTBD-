import 'package:sqflite/sqflite.dart';

import '../../local/app_database.dart';
import '../../models/customer_photo_model.dart';
import '../../models/location_model.dart';
import '../../models/order_model.dart';
import '../../models/shift_model.dart';
import '../../utils/phone_utils.dart';
import '../../utils/uuid_utils.dart';
import '../../utils/vietnamese_utils.dart';
import '../shift_repository.dart';
import 'local_customer_repository.dart';
import 'local_photo_repository.dart';

/// Triển khai ShiftRepository cục bộ bằng SQLite (Local-First)
/// Toàn bộ dữ liệu ca làm việc, điểm giao và dán hàng loạt được lưu trữ trên thiết bị
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
    final nowUtc = DateTime.now().toUtc();
    final nowVn = nowUtc.add(const Duration(hours: 7));

    // Xác định ngày làm việc (work_date) theo giờ Việt Nam
    DateTime targetVnDate;
    if (shiftDate != null && shiftDate.trim().isNotEmpty) {
      final parsed = DateTime.tryParse(shiftDate.trim());
      if (parsed != null) {
        targetVnDate = parsed;
      } else {
        targetVnDate = nowVn;
      }
    } else {
      targetVnDate = nowVn;
    }

    final yearStr = targetVnDate.year.toString();
    final monthStr = targetVnDate.month.toString().padLeft(2, '0');
    final dayStr = targetVnDate.day.toString().padLeft(2, '0');
    final workDateStr = '$yearStr-$monthStr-$dayStr';
    final dateSlug = '$yearStr$monthStr$dayStr';

    // 1. Sinh shift_code dạng SHF-YYYYMMDD-XXX tăng theo ngày và reset khi sang ngày mới
    final existingRows = await db.rawQuery('''
      SELECT shift_code, shift_name FROM shifts
      WHERE work_date = ? OR shift_code LIKE ?
      ORDER BY shift_code DESC
    ''', [workDateStr, 'SHF-$dateSlug-%']);

    final codePattern = RegExp(r'^SHF-\d{8}-(\d+)$');
    int maxSeq = 0;
    for (final r in existingRows) {
      final code = r['shift_code'] as String?;
      if (code != null) {
        final match = codePattern.firstMatch(code);
        if (match != null) {
          final seq = int.tryParse(match.group(1)!) ?? 0;
          if (seq > maxSeq) {
            maxSeq = seq;
          }
        }
      }
    }
    final nextSeq = maxSeq + 1;
    final shiftCode = 'SHF-$dateSlug-${nextSeq.toString().padLeft(3, '0')}';

    // 2. Xác định shift_name (cắt khoảng trắng, tối đa 100 ký tự; nếu rỗng thì gợi ý tự động)
    String resolvedName;
    if (shiftName != null && shiftName.trim().isNotEmpty) {
      final trimmed = shiftName.trim();
      resolvedName = trimmed.length > 100 ? trimmed.substring(0, 100) : trimmed;
    } else {
      final existingNames = existingRows
          .map((r) => r['shift_name'] as String?)
          .whereType<String>()
          .toList();
      resolvedName = ShiftModel.suggestShiftName(
        dateTime: targetVnDate,
        existingNames: existingNames,
      );
    }

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
        areaId: defaultAreaId,
        areaName: defaultAreaName,
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

  @override
  Future<BulkAddPointsResult> addBulkPointsToShift({
    required String shiftId,
    String? rawText,
    List<String>? phones,
    String? areaId,
  }) async {
    // 1. Phân tách danh sách SĐT dùng hàm tách số chung trong phone_utils.dart
    String textToParse = '';
    if (rawText != null && rawText.isNotEmpty) {
      textToParse = rawText;
    } else if (phones != null && phones.isNotEmpty) {
      textToParse = phones.join('\n');
    }

    if (textToParse.trim().isEmpty) {
      return BulkAddPointsResult(
        added: [],
        alreadyInShift: [],
        rejected: [],
        summary: BulkAddSummary(),
      );
    }

    final parsed = parseAndNormalizeBulkPhones(rawText: textToParse);

    // Chặn nghiêm ngặt danh sách vượt quá 200 số
    if (parsed.isExceededLimit) {
      throw ArgumentError(
        'Danh sách vượt quá giới hạn 200 số điện thoại (có ${parsed.totalCount} số). Vui lòng chia nhỏ danh sách.',
      );
    }

    final db = await _appDb.database;

    // 2. Chạy trong ĐÚNG MỘT transaction duy nhất cho cả lô
    return await db.transaction<BulkAddPointsResult>((txn) async {
      final shiftRows = await txn.query(
        'shifts',
        where: 'id = ?',
        whereArgs: [shiftId],
        limit: 1,
      );
      if (shiftRows.isEmpty) {
        throw Exception('Không tìm thấy ca làm việc');
      }

      // Lấy danh sách điểm giao hiện có trong ca
      final existingPoints = await txn.rawQuery('''
        SELECT 
          sdp.id, sdp.customer_id, sdp.location_status,
          c.phone_number, c.full_name
        FROM shift_delivery_points sdp
        JOIN customers c ON sdp.customer_id = c.id
        WHERE sdp.shift_id = ?
      ''', [shiftId]);

      final shiftPhonesMap = <String, Map<String, dynamic>>{};
      for (final p in existingPoints) {
        final phone = p['phone_number'] as String?;
        if (phone != null) {
          shiftPhonesMap[phone] = p;
        }
      }

      final maxIndexRows = await txn.rawQuery(
        'SELECT MAX(delivery_order_index) AS max_idx FROM shift_delivery_points WHERE shift_id = ?',
        [shiftId],
      );
      int currentOrderIndex = (maxIndexRows.first['max_idx'] as int?) ?? 0;

      final added = <ShiftDeliveryPointModel>[];
      final alreadyInShift = <AlreadyInShiftItem>[];
      final rejected = <RejectedPhoneItem>[];

      final nowIso = AppDatabase.currentIsoUtc();

      for (final item in parsed.items) {
        // A. Nhóm số điện thoại không hợp lệ
        if (!item.isValid) {
          rejected.add(RejectedPhoneItem(
            phone: item.rawInput,
            reason: 'INVALID_FORMAT',
            message: 'Số điện thoại không đúng định dạng VN (10 chữ số)',
          ));
          continue;
        }

        final normPhone = item.normalizedPhone;

        // B. Nhóm đã có trong ca
        if (shiftPhonesMap.containsKey(normPhone)) {
          final p = shiftPhonesMap[normPhone]!;
          alreadyInShift.add(AlreadyInShiftItem(
            phone: normPhone,
            pointId: p['id'] as String,
            customerId: p['customer_id'] as String,
            customerName: (p['full_name'] as String?) ?? '',
            locationStatus: (p['location_status'] as String?) ?? 'NO_LOCATION',
          ));
          continue;
        }

        // C. Nhóm cần thêm mới vào ca
        // Tìm khách hàng theo SĐT
        final custRows = await txn.query(
          'customers',
          where: 'phone_number = ? AND deleted_at IS NULL',
          whereArgs: [normPhone],
          limit: 1,
        );

        String custId;
        String custName;
        String custAddress;
        if (custRows.isNotEmpty) {
          final c = custRows.first;
          custId = c['id'] as String;
          custName = (c['full_name'] as String?) ?? 'Khách $normPhone';
          custAddress = (c['address_text'] as String?) ?? 'Chưa cập nhật địa chỉ';
        } else {
          // Tạo khách hàng nhanh nếu chưa có hồ sơ
          custId = UuidUtils.generate();
          custName = 'Khách $normPhone';
          custAddress = 'Chưa cập nhật địa chỉ';
          final searchText = buildCustomerSearchText(
            fullName: custName,
            phoneNumber: normPhone,
            addressText: custAddress,
          );
          await txn.insert('customers', {
            'id': custId,
            'customer_code': null,
            'full_name': custName,
            'phone_number': normPhone,
            'address_text': custAddress,
            'notes': null,
            'search_text': searchText,
            'created_at': nowIso,
            'updated_at': nowIso,
            'deleted_at': null,
          });
        }

        // Kiểm tra vị trí đã lưu
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
        String? notes;
        if (savedLocRows.isNotEmpty) {
          final sl = savedLocRows.first;
          locStatus = LocationStatus.verified;
          lat = (sl['latitude'] as num?)?.toDouble();
          lng = (sl['longitude'] as num?)?.toDouble();
          gps = (sl['gps_accuracy'] as num?)?.toDouble();
          notes = sl['identification_notes'] as String?;
        }

        currentOrderIndex++;
        final pointId = UuidUtils.generate();

        await txn.insert('shift_delivery_points', {
          'id': pointId,
          'shift_id': shiftId,
          'customer_id': custId,
          'delivery_order_index': currentOrderIndex,
          'location_status': locStatus.toApiString(),
          'latitude': lat,
          'longitude': lng,
          'gps_accuracy': gps,
          'identification_notes': notes,
          'created_at': nowIso,
          'updated_at': nowIso,
        });

        final pointModel = ShiftDeliveryPointModel(
          id: pointId,
          shiftId: shiftId,
          customerId: custId,
          customerName: custName,
          customerPhone: normPhone,
          customerAddress: custAddress,
          areaId: defaultAreaId,
          areaName: defaultAreaName,
          sequenceNumber: currentOrderIndex,
          deliveryStatus: 'PENDING',
          locationStatus: locStatus,
          latitude: lat,
          longitude: lng,
          locationNotes: notes,
          createdAt: DateTime.tryParse(nowIso),
          updatedAt: DateTime.tryParse(nowIso),
        );

        added.add(pointModel);

        // Lưu vào cache map để ngăn thêm trùng lặp trong cùng một lô
        shiftPhonesMap[normPhone] = {
          'id': pointId,
          'customer_id': custId,
          'full_name': custName,
          'location_status': locStatus.toApiString(),
        };
      }

      final summary = BulkAddSummary(
        total: parsed.items.length,
        addedCount: added.length,
        alreadyInShiftCount: alreadyInShift.length,
        rejectedCount: rejected.length,
      );

      // Ghi ĐÚNG 1 dòng activity_log duy nhất cho cả lô
      await _appDb.logActivity(
        action: 'BULK_ADD_POINTS',
        entity: 'shifts',
        entityId: shiftId,
        details: {
          'total': summary.total,
          'addedCount': summary.addedCount,
          'alreadyInShiftCount': summary.alreadyInShiftCount,
          'rejectedCount': summary.rejectedCount,
        },
        executor: txn,
      );

      return BulkAddPointsResult(
        added: added,
        alreadyInShift: alreadyInShift,
        rejected: rejected,
        summary: summary,
      );
    });
  }

  @override
  Future<void> removePointFromShift(String shiftId, String pointId) async {
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

  @override
  Future<List<OrderModel>> getMyShiftOrders() async {
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

    return points.map((p) {
      final custId = p['customer_id'] as String;
      final hasSaved = p['saved_lat'] != null && p['saved_lng'] != null;
      SavedLocationModel? savedLoc;
      if (hasSaved) {
        savedLoc = SavedLocationModel(
          customerId: custId,
          latitude: (p['saved_lat'] as num).toDouble(),
          longitude: (p['saved_lng'] as num).toDouble(),
          gpsAccuracy: 0.0,
          identificationNotes: (p['saved_notes'] as String?) ?? '',
        );
      }

      return OrderModel(
        orderId: p['id'] as String,
        orderCode: 'ORD-${(p['id'] as String).substring(0, 8).toUpperCase()}',
        orderStatus: (p['delivery_status'] as String?) ?? 'PENDING',
        areaName: defaultAreaName,
        customerId: custId,
        customerName: (p['customer_name'] as String?) ?? 'Khách hàng',
        customerPhone: (p['customer_phone'] as String?) ?? '',
        customerAddress: (p['customer_address'] as String?) ?? '',
        hasSavedLocation: hasSaved,
        savedLocation: savedLoc,
      );
    }).toList();
  }

  @override
  Future<Map<String, dynamic>> addOrderToShift({
    required String customerId,
    bool allowMultiple = false,
    String? idempotencyKey,
  }) async {
    final db = await _appDb.database;

    // Tìm ca làm việc đang mở hoặc tự động tạo ca mới cho ngày hôm nay
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
      areaName: defaultAreaName,
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

  @override
  Future<void> verifyPointLocation(String shiftId, String pointId) async {
    throw UnsupportedError(
      'Endpoint xác minh vị trí trong ca đã ngừng hoạt động (410 Gone). Theo quy chuẩn LOCATION-RULES-012, vị trí chuẩn chỉ được xác nhận qua luồng Danh bạ -> Hồ sơ khách -> Xác nhận vị trí.',
    );
  }

  // ===========================================================================
  // CÁC HÀM TIỆN ÍCH ÁNH XẠ DỮ LIỆU CỤC BỘ
  // ===========================================================================

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

  ShiftDeliveryPointModel _mapToPointModel(Map<String, dynamic> r) {
    return ShiftDeliveryPointModel(
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
      photoUrl: null,
      photoCount: 0,
      photos: const [],
      deliveryNotes: null,
      createdAt: DateTime.tryParse(r['created_at']?.toString() ?? ''),
      updatedAt: DateTime.tryParse(r['updated_at']?.toString() ?? ''),
    );
  }
}
