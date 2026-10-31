import 'package:delivery_marker_mobile/core/utils/phone_utils.dart';
import 'package:delivery_marker_mobile/core/utils/uuid_utils.dart';
import 'package:delivery_marker_mobile/core/utils/vietnamese_utils.dart';
import 'package:delivery_marker_mobile/data/database/app_database.dart';
import 'package:delivery_marker_mobile/data/photos/photo_repository.dart';
import 'package:delivery_marker_mobile/models/customer_model.dart';
import 'package:delivery_marker_mobile/models/customer_photo_model.dart';
import 'package:delivery_marker_mobile/models/shift_model.dart';

/// Thao tác CSDL SQLite mức thấp cho Khách hàng
extension CustomerDatabaseOps on AppDatabase {
  /// Thêm khách hàng mới kèm đồng bộ trường tìm kiếm không dấu
  Future<String> insertCustomer({
    String? id,
    String? customerCode,
    required String fullName,
    required String phoneNumber,
    String? addressText,
    String? notes,
  }) async {
    final db = await database;
    final customerId = id ?? AppDatabase.generateId();
    final cleanPhone = normalizeCustomerPhone(phoneNumber);
    final now = AppDatabase.currentIsoUtc();
    final searchText = buildCustomerSearchText(
      fullName: fullName,
      phoneNumber: cleanPhone,
      addressText: addressText,
      notes: notes,
    );

    await db.insert('customers', {
      'id': customerId,
      'customer_code': customerCode ?? 'CUST-${cleanPhone.length >= 4 ? cleanPhone.substring(cleanPhone.length - 4) : cleanPhone}',
      'full_name': fullName,
      'phone_number': cleanPhone,
      'address_text': addressText,
      'notes': notes,
      'search_text': searchText,
      'created_at': now,
      'updated_at': now,
      'deleted_at': null,
    });

    return customerId;
  }

  /// Cập nhật khách hàng kèm đồng bộ trường tìm kiếm
  Future<int> updateCustomer(
    String id, {
    String? fullName,
    String? phoneNumber,
    String? addressText,
    String? notes,
  }) async {
    final db = await database;
    final current = await getCustomerById(id);
    if (current == null) return 0;

    final newFullName = fullName ?? (current['full_name'] as String);
    final newPhone = phoneNumber != null ? normalizeCustomerPhone(phoneNumber) : (current['phone_number'] as String);
    final newAddress = addressText ?? (current['address_text'] as String?);
    final newNotes = notes ?? (current['notes'] as String?);
    final now = AppDatabase.currentIsoUtc();

    final searchText = buildCustomerSearchText(
      fullName: newFullName,
      phoneNumber: newPhone,
      addressText: newAddress,
      notes: newNotes,
    );

    return await db.update(
      'customers',
      {
        'full_name': newFullName,
        'phone_number': newPhone,
        'address_text': newAddress,
        'notes': newNotes,
        'search_text': searchText,
        'updated_at': now,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Lấy khách hàng theo ID
  Future<Map<String, dynamic>?> getCustomerById(String id) async {
    final db = await database;
    final rows = await db.query(
      'customers',
      where: 'id = ? AND deleted_at IS NULL',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isNotEmpty ? rows.first : null;
  }

  /// Lấy khách hàng theo số điện thoại (tự động chuẩn hóa)
  Future<Map<String, dynamic>?> getCustomerByPhone(String phoneNumber) async {
    final db = await database;
    final clean = normalizeCustomerPhone(phoneNumber);
    final rows = await db.query(
      'customers',
      where: 'phone_number = ? AND deleted_at IS NULL',
      whereArgs: [clean],
      limit: 1,
    );
    return rows.isNotEmpty ? rows.first : null;
  }

  /// Tìm kiếm khách hàng theo từ khóa (hỗ trợ không dấu unaccent 2 chiều)
  Future<List<Map<String, dynamic>>> searchCustomers(String query, {int limit = 50, int offset = 0}) async {
    final db = await database;
    final cleanQuery = normalizeSearchQuery(query);

    if (cleanQuery.isEmpty) {
      return await db.query(
        'customers',
        where: 'deleted_at IS NULL',
        orderBy: 'updated_at DESC',
        limit: limit,
        offset: offset,
      );
    }

    final digitsOnly = query.replaceAll(RegExp(r'\D'), '');
    final hasDigits = digitsOnly.length >= 3;

    final whereClause = StringBuffer('deleted_at IS NULL AND (search_text LIKE ?');
    final whereArgs = <dynamic>['%$cleanQuery%'];

    if (hasDigits && digitsOnly != cleanQuery) {
      whereClause.write(' OR search_text LIKE ?');
      whereArgs.add('%$digitsOnly%');
    }
    whereClause.write(')');

    return await db.query(
      'customers',
      where: whereClause.toString(),
      whereArgs: whereArgs,
      orderBy: 'updated_at DESC',
      limit: limit,
      offset: offset,
    );
  }

  /// Xóa mềm khách hàng (đặt deleted_at)
  Future<int> softDeleteCustomer(String id) async {
    final db = await database;
    return await db.update(
      'customers',
      {'deleted_at': AppDatabase.currentIsoUtc()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}

/// Helper thực thi truy vấn, tìm kiếm, phân loại và phân trang khách hàng từ SQLite
class CustomerQueryHelpers {
  static Future<CustomerDirectoryResponse> queryCustomersResponse({
    required AppDatabase appDb,
    required PhotoRepository photoRepo,
    String? query,
    String? status,
    bool? hasPhoto,
    int? limit,
    int? offset,
    String defaultAreaId = 'default-area-hcm',
    String defaultAreaName = 'Khu vực chung',
  }) async {
    final db = await appDb.database;
    final cleanQuery = query != null ? normalizeSearchQuery(query) : '';
    final customerRows = cleanQuery.isNotEmpty
        ? await appDb.searchCustomers(query!, limit: 10000, offset: 0)
        : await db.query('customers', where: 'deleted_at IS NULL', orderBy: 'updated_at DESC, created_at DESC');

    final savedLocRows = await db.query('saved_locations');
    final savedLocMap = {for (final r in savedLocRows) r['customer_id'] as String: r};

    final activeTempPoints = await db.rawQuery('''
      SELECT sdp.customer_id, sdp.latitude, sdp.longitude, sdp.identification_notes, sdp.gps_accuracy
      FROM shift_delivery_points sdp JOIN shifts s ON s.id = sdp.shift_id
      WHERE sdp.location_status = 'TEMPORARY' AND s.status IN ('PREPARING', 'IN_PROGRESS')
      ORDER BY sdp.updated_at DESC
    ''');
    final tempPointMap = <String, Map<String, dynamic>>{};
    for (final r in activeTempPoints) {
      tempPointMap.putIfAbsent(r['customer_id'] as String, () => r);
    }

    final allModels = <CustomerDirectoryModel>[];
    int verifiedCount = 0, temporaryCount = 0, noLocationCount = 0;

    for (final c in customerRows) {
      final custId = c['id'] as String;
      final savedLoc = savedLocMap[custId];
      final tempPoint = tempPointMap[custId];
      LocationStatus locState = LocationStatus.noLocation;
      double? lat, lng;
      String? notes, savedLocId;

      if (savedLoc != null && savedLoc['latitude'] != null && savedLoc['longitude'] != null) {
        locState = LocationStatus.verified;
        lat = (savedLoc['latitude'] as num).toDouble();
        lng = (savedLoc['longitude'] as num).toDouble();
        notes = savedLoc['identification_notes'] as String?;
        savedLocId = savedLoc['id'] as String?;
        verifiedCount++;
      } else if (tempPoint != null && tempPoint['latitude'] != null && tempPoint['longitude'] != null) {
        locState = LocationStatus.temporary;
        lat = (tempPoint['latitude'] as num).toDouble();
        lng = (tempPoint['longitude'] as num).toDouble();
        notes = tempPoint['identification_notes'] as String?;
        temporaryCount++;
      } else {
        noLocationCount++;
      }

      allModels.add(CustomerDirectoryModel(
        id: custId,
        customerCode: (c['customer_code'] as String?) ?? 'CUST',
        fullName: (c['full_name'] as String?) ?? '',
        phoneNumber: (c['phone_number'] as String?) ?? '',
        addressText: (c['address_text'] as String?) ?? '',
        areaId: defaultAreaId,
        areaName: defaultAreaName,
        locationStatus: locState,
        locationState: locState,
        hasLocation: locState != LocationStatus.noLocation,
        latitude: lat,
        longitude: lng,
        identificationNotes: notes,
        savedLocationId: savedLocId,
        createdAt: DateTime.tryParse(c['created_at']?.toString() ?? ''),
        updatedAt: DateTime.tryParse(c['updated_at']?.toString() ?? ''),
      ));
    }

    var filtered = allModels;
    if (status != null && status.toUpperCase() != 'ALL') {
      final target = LocationStatus.fromString(status);
      filtered = allModels.where((m) => m.locationState == target).toList();
    }

    final effOffset = offset ?? 0;
    final effLimit = limit ?? 30;
    final paged = filtered.skip(effOffset).take(effLimit).toList();

    final photoSummaries = await photoRepo.getBatchPhotoSummaries(paged.map((c) => c.id).toList());
    final enriched = paged.map((c) {
      final s = photoSummaries[c.id];
      if (s == null) return c;
      final thumb = s['firstThumbnailUrl'] as String?;
      return c.copyWith(
        photoCount: s['photoCount'] as int,
        photos: s['photos'] as List<CustomerPhotoModel>,
        firstThumbnailUrl: thumb,
        imageUrl: thumb ?? c.imageUrl,
      );
    }).toList();

    return CustomerDirectoryResponse(
      items: enriched,
      counts: CustomerTabCounts(
        total: allModels.length,
        verified: verifiedCount,
        temporary: temporaryCount,
        noLocation: noLocationCount,
      ),
      pagination: CustomerPagination(
        total: filtered.length,
        limit: effLimit,
        offset: effOffset,
        hasMore: effOffset + paged.length < filtered.length,
      ),
    );
  }
}

/// Helper thực thi thêm khách hàng hàng loạt từ văn bản hoặc danh sách SĐT trong một Transaction SQLite duy nhất
class CustomerBulkHelpers {
  static Future<BulkCreateCustomersResult> executeBulkCreate({
    required AppDatabase appDb,
    String? rawText,
    List<String>? phones,
    String? areaId,
    String defaultAreaId = 'default-area-hcm',
  }) async {
    final parsed = parseAndNormalizeBulkPhones(rawText: rawText, phones: phones);
    if (parsed.items.isEmpty) throw ArgumentError('Không tìm thấy số điện thoại nào trong dữ liệu gửi lên');
    if (parsed.uniquePhones.length > 200) {
      throw ArgumentError('Vượt quá giới hạn tối đa 200 số điện thoại cho mỗi lần thêm hàng loạt (nhận được ${parsed.uniquePhones.length} số)');
    }

    return await appDb.transaction<BulkCreateCustomersResult>((txn) async {
      final created = <BulkCustomerItem>[];
      final alreadyExists = <BulkCustomerItem>[];
      final rejected = parsed.items
          .where((it) => !it.isValid)
          .map((it) => RejectedPhoneItem(
                phone: it.original,
                reason: 'INVALID_FORMAT',
                message: it.reason ?? 'Số điện thoại không đúng định dạng (cần 10 chữ số hợp lệ)',
              ))
          .toList();

      final now = AppDatabase.currentIsoUtc();

      for (final phone in parsed.uniquePhones) {
        final exRows = await txn.query('customers', where: 'phone_number = ? AND deleted_at IS NULL', whereArgs: [phone], limit: 1);
        if (exRows.isNotEmpty) {
          final row = exRows.first;
          final cid = row['id'] as String;
          final locs = await txn.query('saved_locations', where: 'customer_id = ?', whereArgs: [cid], limit: 1);
          alreadyExists.add(BulkCustomerItem(
            id: cid,
            customerCode: (row['customer_code'] as String?) ?? 'CUST',
            phoneNumber: phone,
            fullName: (row['full_name'] as String?) ?? '',
            addressText: (row['address_text'] as String?) ?? '',
            areaId: defaultAreaId,
            locationState: locs.isNotEmpty ? LocationStatus.verified : LocationStatus.noLocation,
          ));
        } else {
          final newId = UuidUtils.generate();
          final name = 'Khách $phone';
          const addr = 'Chưa cập nhật địa chỉ';
          final custCode = 'CUST-${phone.substring(phone.length - 4)}';
          final searchText = buildCustomerSearchText(fullName: name, phoneNumber: phone, addressText: addr);

          await txn.insert('customers', {
            'id': newId,
            'customer_code': custCode,
            'full_name': name,
            'phone_number': phone,
            'address_text': addr,
            'search_text': searchText,
            'created_at': now,
            'updated_at': now,
          });

          created.add(BulkCustomerItem(
            id: newId,
            customerCode: custCode,
            phoneNumber: phone,
            fullName: name,
            addressText: addr,
            areaId: defaultAreaId,
            locationState: LocationStatus.noLocation,
          ));
        }
      }

      await appDb.logActivity(
        executor: txn,
        action: 'BULK_CREATE_CUSTOMERS',
        entity: 'CUSTOMERS',
        details: {'total': parsed.items.length, 'created': created.length, 'alreadyExists': alreadyExists.length, 'rejected': rejected.length},
      );

      return BulkCreateCustomersResult(
        created: created,
        alreadyExists: alreadyExists,
        rejected: rejected,
        total: parsed.items.length,
        createdCount: created.length,
        alreadyExistsCount: alreadyExists.length,
        rejectedCount: rejected.length,
      );
    });
  }
}
