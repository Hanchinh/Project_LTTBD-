import '../../local/app_database.dart';
import '../../models/customer_model.dart';
import '../../models/customer_photo_model.dart';
import '../../models/shift_model.dart';
import '../../utils/phone_utils.dart';
import '../../utils/uuid_utils.dart';
import '../../utils/vietnamese_utils.dart';
import '../customer_repository.dart';
import 'local_photo_repository.dart';

/// Triển khai CustomerRepository cục bộ bằng SQLite (Local-First)
/// Toàn bộ dữ liệu khách hàng được lưu trữ và truy vấn trực tiếp trên thiết bị
class LocalCustomerRepository implements CustomerRepository {
  final AppDatabase _appDb;
  final LocalPhotoRepository _photoRepo;

  LocalCustomerRepository({AppDatabase? appDb, LocalPhotoRepository? photoRepo})
      : _appDb = appDb ?? AppDatabase.instance,
        _photoRepo = photoRepo ?? LocalPhotoRepository(appDb: appDb ?? AppDatabase.instance);

  static const String defaultAreaId = 'local-area-default';
  static const String defaultAreaName = 'Của tôi';

  @override
  Future<List<CustomerDirectoryModel>> getCustomers({
    String? query,
    String? status,
    bool? hasPhoto,
    int? limit,
    int? offset,
  }) async {
    final response = await getCustomersResponse(
      query: query,
      status: status,
      hasPhoto: hasPhoto,
      limit: limit,
      offset: offset,
    );
    return response.items;
  }

  @override
  Future<CustomerDirectoryResponse> getCustomersResponse({
    String? query,
    String? status,
    bool? hasPhoto,
    int? limit,
    int? offset,
  }) async {
    final db = await _appDb.database;

    // 1. Lọc khách hàng chưa xóa mềm
    List<Map<String, dynamic>> customerRows;
    final cleanQuery = query != null ? normalizeSearchQuery(query) : '';

    if (cleanQuery.isNotEmpty) {
      customerRows = await _appDb.searchCustomers(query!, limit: 10000, offset: 0);
    } else {
      customerRows = await db.query(
        'customers',
        where: 'deleted_at IS NULL',
        orderBy: 'updated_at DESC, created_at DESC',
      );
    }

    // 2. Lấy toàn bộ vị trí đã lưu và điểm ghim tạm trong ca đang mở để xác định locationState
    final savedLocRows = await db.query('saved_locations');
    final savedLocMap = <String, Map<String, dynamic>>{};
    for (final r in savedLocRows) {
      savedLocMap[r['customer_id'] as String] = r;
    }

    // Lấy các điểm giao TEMPORARY trong ca PREPARING hoặc IN_PROGRESS
    final activeTempPoints = await db.rawQuery('''
      SELECT sdp.customer_id, sdp.latitude, sdp.longitude, sdp.identification_notes, sdp.gps_accuracy
      FROM shift_delivery_points sdp
      JOIN shifts s ON s.id = sdp.shift_id
      WHERE sdp.location_status = 'TEMPORARY'
        AND s.status IN ('PREPARING', 'IN_PROGRESS')
      ORDER BY sdp.updated_at DESC
    ''');
    final tempPointMap = <String, Map<String, dynamic>>{};
    for (final r in activeTempPoints) {
      final custId = r['customer_id'] as String;
      tempPointMap.putIfAbsent(custId, () => r);
    }

    // 3. Xây dựng danh sách CustomerDirectoryModel và tính toán Counts
    final allModels = <CustomerDirectoryModel>[];
    int verifiedCount = 0;
    int temporaryCount = 0;
    int noLocationCount = 0;

    for (final c in customerRows) {
      final custId = c['id'] as String;
      final savedLoc = savedLocMap[custId];
      final tempPoint = tempPointMap[custId];

      LocationStatus locState = LocationStatus.noLocation;
      double? lat;
      double? lng;
      String? notes;
      String? savedLocId;

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
        locState = LocationStatus.noLocation;
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

    // 4. Lọc theo tab status nếu có yêu cầu
    List<CustomerDirectoryModel> filtered = allModels;
    if (status != null && status.toUpperCase() != 'ALL') {
      final targetStatus = LocationStatus.fromString(status);
      filtered = allModels.where((m) => m.locationState == targetStatus).toList();
    }

    final totalCountForTab = filtered.length;
    final effOffset = offset ?? 0;
    final effLimit = limit ?? 30;

    final pagedItems = filtered.skip(effOffset).take(effLimit).toList();

    // 5. Nạp photoCount và tối đa 3 ảnh thumbnail cho danh sách khách hàng hiển thị
    final customerIds = pagedItems.map((c) => c.id).toList();
    final photoSummaries = await _photoRepo.getBatchPhotoSummaries(customerIds);

    final enrichedItems = pagedItems.map((c) {
      final summary = photoSummaries[c.id];
      if (summary != null) {
        final count = summary['photoCount'] as int;
        final photos = summary['photos'] as List<CustomerPhotoModel>;
        final firstThumb = summary['firstThumbnailUrl'] as String?;
        return c.copyWith(
          photoCount: count,
          photos: photos,
          firstThumbnailUrl: firstThumb,
          imageUrl: firstThumb ?? c.imageUrl,
        );
      }
      return c;
    }).toList();

    return CustomerDirectoryResponse(
      items: enrichedItems,
      counts: CustomerTabCounts(
        total: allModels.length,
        verified: verifiedCount,
        temporary: temporaryCount,
        noLocation: noLocationCount,
      ),
      pagination: CustomerPagination(
        total: totalCountForTab,
        limit: effLimit,
        offset: effOffset,
        hasMore: effOffset + pagedItems.length < totalCountForTab,
      ),
    );
  }

  @override
  Future<CustomerDirectoryModel> getCustomerDetail(String customerId) async {
    final db = await _appDb.database;
    final customer = await _appDb.getCustomerById(customerId);
    if (customer == null) {
      throw Exception('Không tìm thấy thông tin khách hàng');
    }

    final savedLoc = await _appDb.getSavedLocationByCustomerId(customerId);
    LocationStatus locState = LocationStatus.noLocation;
    double? lat;
    double? lng;
    String? notes;
    String? savedLocId;

    if (savedLoc != null && savedLoc['latitude'] != null && savedLoc['longitude'] != null) {
      locState = LocationStatus.verified;
      lat = (savedLoc['latitude'] as num).toDouble();
      lng = (savedLoc['longitude'] as num).toDouble();
      notes = savedLoc['identification_notes'] as String?;
      savedLocId = savedLoc['id'] as String?;
    } else {
      final activeTemp = await db.rawQuery('''
        SELECT sdp.latitude, sdp.longitude, sdp.identification_notes
        FROM shift_delivery_points sdp
        JOIN shifts s ON s.id = sdp.shift_id
        WHERE sdp.customer_id = ?
          AND sdp.location_status = 'TEMPORARY'
          AND s.status IN ('PREPARING', 'IN_PROGRESS')
        ORDER BY sdp.updated_at DESC
        LIMIT 1
      ''', [customerId]);
      if (activeTemp.isNotEmpty) {
        locState = LocationStatus.temporary;
        lat = (activeTemp.first['latitude'] as num).toDouble();
        lng = (activeTemp.first['longitude'] as num).toDouble();
        notes = activeTemp.first['identification_notes'] as String?;
      }
    }

    final photoSummary = await _photoRepo.getCustomerPhotoSummary(customerId);
    final count = photoSummary['photoCount'] as int;
    final photos = photoSummary['photos'] as List<CustomerPhotoModel>;
    final firstThumb = photoSummary['firstThumbnailUrl'] as String?;

    return CustomerDirectoryModel(
      id: customerId,
      customerCode: (customer['customer_code'] as String?) ?? 'CUST',
      fullName: (customer['full_name'] as String?) ?? '',
      phoneNumber: (customer['phone_number'] as String?) ?? '',
      addressText: (customer['address_text'] as String?) ?? '',
      areaId: defaultAreaId,
      areaName: defaultAreaName,
      locationStatus: locState,
      locationState: locState,
      hasLocation: locState != LocationStatus.noLocation,
      latitude: lat,
      longitude: lng,
      identificationNotes: notes,
      imageUrl: firstThumb,
      firstThumbnailUrl: firstThumb,
      photoCount: count,
      photos: photos,
      savedLocationId: savedLocId,
      createdAt: DateTime.tryParse(customer['created_at']?.toString() ?? ''),
      updatedAt: DateTime.tryParse(customer['updated_at']?.toString() ?? ''),
    );
  }

  @override
  Future<CustomerDirectoryModel> createCustomer({
    required String phoneNumber,
    String? fullName,
    String? addressText,
    String? areaId,
    double? latitude,
    double? longitude,
    double? gpsAccuracy,
    String? identificationNotes,
    String? imageBase64,
  }) async {
    final cleanPhone = normalizeCustomerPhone(phoneNumber);
    if (!isValidVnPhone(cleanPhone)) {
      throw ArgumentError('Số điện thoại không hợp lệ (cần 10 chữ số bắt đầu bằng 0)');
    }

    return await _appDb.transaction<CustomerDirectoryModel>((txn) async {
      // 1. Kiểm tra SĐT đã tồn tại chưa
      final existingRows = await txn.query(
        'customers',
        where: 'phone_number = ? AND deleted_at IS NULL',
        whereArgs: [cleanPhone],
        limit: 1,
      );

      if (existingRows.isNotEmpty) {
        final existing = existingRows.first;
        final custId = existing['id'] as String;

        // Lấy vị trí đã lưu nếu có
        final locRows = await txn.query(
          'saved_locations',
          where: 'customer_id = ?',
          whereArgs: [custId],
          limit: 1,
        );

        final hasLoc = locRows.isNotEmpty;
        final loc = hasLoc ? locRows.first : null;

        return CustomerDirectoryModel(
          id: custId,
          customerCode: (existing['customer_code'] as String?) ?? 'CUST',
          fullName: (existing['full_name'] as String?) ?? '',
          phoneNumber: (existing['phone_number'] as String?) ?? cleanPhone,
          addressText: (existing['address_text'] as String?) ?? '',
          areaId: defaultAreaId,
          areaName: defaultAreaName,
          locationStatus: hasLoc ? LocationStatus.verified : LocationStatus.noLocation,
          locationState: hasLoc ? LocationStatus.verified : LocationStatus.noLocation,
          hasLocation: hasLoc,
          latitude: loc != null ? (loc['latitude'] as num).toDouble() : null,
          longitude: loc != null ? (loc['longitude'] as num).toDouble() : null,
          identificationNotes: loc?['identification_notes'] as String?,
          savedLocationId: loc?['id'] as String?,
          createdAt: DateTime.tryParse(existing['created_at']?.toString() ?? ''),
          updatedAt: DateTime.tryParse(existing['updated_at']?.toString() ?? ''),
          isExisting: true,
        );
      }

      // 2. Tạo mới khách hàng trong transaction
      final newId = UuidUtils.generate();
      final displayName = (fullName != null && fullName.trim().isNotEmpty)
          ? fullName.trim()
          : 'Khách $cleanPhone';
      final displayAddress = (addressText != null && addressText.trim().isNotEmpty)
          ? addressText.trim()
          : 'Chưa cập nhật địa chỉ';
      final now = AppDatabase.currentIsoUtc();
      final searchText = buildCustomerSearchText(
        fullName: displayName,
        phoneNumber: cleanPhone,
        addressText: displayAddress,
        notes: null,
      );

      await txn.insert('customers', {
        'id': newId,
        'customer_code': 'CUST-${cleanPhone.substring(cleanPhone.length - 4)}',
        'full_name': displayName,
        'phone_number': cleanPhone,
        'address_text': displayAddress,
        'notes': null,
        'search_text': searchText,
        'created_at': now,
        'updated_at': now,
        'deleted_at': null,
      });

      String? savedLocationId;
      bool hasLocation = false;

      // 3. Nếu có kèm tọa độ, lưu luôn vào saved_locations trong cùng transaction
      if (latitude != null && longitude != null) {
        if (latitude < -90 || latitude > 90 || longitude < -180 || longitude > 180) {
          throw ArgumentError('Tọa độ không hợp lệ (-90..90, -180..180)');
        }

        savedLocationId = UuidUtils.generate();
        await txn.insert('saved_locations', {
          'id': savedLocationId,
          'customer_id': newId,
          'latitude': latitude,
          'longitude': longitude,
          'gps_accuracy': gpsAccuracy ?? 0.0,
          'identification_notes': identificationNotes ?? '',
          'created_at': now,
          'updated_at': now,
        });
        hasLocation = true;
      }

      return CustomerDirectoryModel(
        id: newId,
        customerCode: 'CUST-${cleanPhone.substring(cleanPhone.length - 4)}',
        fullName: displayName,
        phoneNumber: cleanPhone,
        addressText: displayAddress,
        areaId: defaultAreaId,
        areaName: defaultAreaName,
        locationStatus: hasLocation ? LocationStatus.verified : LocationStatus.noLocation,
        locationState: hasLocation ? LocationStatus.verified : LocationStatus.noLocation,
        hasLocation: hasLocation,
        latitude: latitude,
        longitude: longitude,
        identificationNotes: identificationNotes,
        savedLocationId: savedLocationId,
        createdAt: DateTime.tryParse(now),
        updatedAt: DateTime.tryParse(now),
        isExisting: false,
      );
    });
  }

  @override
  Future<BulkCreateCustomersResult> createBulkCustomers({
    String? rawText,
    List<String>? phones,
    String? areaId,
  }) async {
    final parsed = parseAndNormalizeBulkPhones(rawText: rawText, phones: phones);

    if (parsed.items.isEmpty) {
      throw ArgumentError('Không tìm thấy số điện thoại nào trong dữ liệu gửi lên');
    }

    if (parsed.uniquePhones.length > 200) {
      throw ArgumentError(
        'Vượt quá giới hạn tối đa 200 số điện thoại cho mỗi lần thêm hàng loạt (nhận được ${parsed.uniquePhones.length} số)',
      );
    }

    return await _appDb.transaction<BulkCreateCustomersResult>((txn) async {
      final created = <BulkCustomerItem>[];
      final alreadyExists = <BulkCustomerItem>[];
      final rejected = <RejectedPhoneItem>[];

      // Đưa các số sai định dạng vào rejected
      for (final item in parsed.items) {
        if (!item.isValid) {
          rejected.add(RejectedPhoneItem(
            phone: item.original,
            reason: 'INVALID_FORMAT',
            message: item.reason ?? 'Số điện thoại không đúng định dạng (cần 10 chữ số hợp lệ)',
          ));
        }
      }

      final now = AppDatabase.currentIsoUtc();

      for (final phone in parsed.uniquePhones) {
        final existingRows = await txn.query(
          'customers',
          where: 'phone_number = ? AND deleted_at IS NULL',
          whereArgs: [phone],
          limit: 1,
        );

        if (existingRows.isNotEmpty) {
          final row = existingRows.first;
          final custId = row['id'] as String;

          // Kiểm tra vị trí để gán locationState
          final locRows = await txn.query(
            'saved_locations',
            where: 'customer_id = ?',
            whereArgs: [custId],
            limit: 1,
          );

          LocationStatus locState = locRows.isNotEmpty ? LocationStatus.verified : LocationStatus.noLocation;

          alreadyExists.add(BulkCustomerItem(
            id: custId,
            customerCode: (row['customer_code'] as String?) ?? 'CUST',
            phoneNumber: phone,
            fullName: (row['full_name'] as String?) ?? '',
            addressText: (row['address_text'] as String?) ?? '',
            areaId: defaultAreaId,
            locationState: locState,
          ));
        } else {
          final newId = UuidUtils.generate();
          final displayName = 'Khách $phone';
          const displayAddress = 'Chưa cập nhật địa chỉ';
          final custCode = 'CUST-${phone.substring(phone.length - 4)}';
          final searchText = buildCustomerSearchText(
            fullName: displayName,
            phoneNumber: phone,
            addressText: displayAddress,
          );

          await txn.insert('customers', {
            'id': newId,
            'customer_code': custCode,
            'full_name': displayName,
            'phone_number': phone,
            'address_text': displayAddress,
            'notes': null,
            'search_text': searchText,
            'created_at': now,
            'updated_at': now,
            'deleted_at': null,
          });

          created.add(BulkCustomerItem(
            id: newId,
            customerCode: custCode,
            phoneNumber: phone,
            fullName: displayName,
            addressText: displayAddress,
            areaId: defaultAreaId,
            locationState: LocationStatus.noLocation,
          ));
        }
      }

      // Ghi nhật ký activity_log cho cả lô
      await _appDb.logActivity(
        executor: txn,
        action: 'BULK_CREATE_CUSTOMERS',
        entity: 'CUSTOMERS',
        details: {
          'total': parsed.items.length,
          'created': created.length,
          'alreadyExists': alreadyExists.length,
          'rejected': rejected.length,
        },
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

  @override
  Future<Map<String, dynamic>> updateCustomer({
    required String customerId,
    required String fullName,
    required String phoneNumber,
    String? addressText,
  }) async {
    final cleanPhone = normalizeCustomerPhone(phoneNumber);
    if (!isValidVnPhone(cleanPhone)) {
      return {
        'success': false,
        'message': 'Số điện thoại không hợp lệ (cần 10 chữ số bắt đầu bằng 0)',
      };
    }

    final db = await _appDb.database;

    // Kiểm tra trùng SĐT với khách hàng khác
    final duplicate = await db.query(
      'customers',
      where: 'phone_number = ? AND id != ? AND deleted_at IS NULL',
      whereArgs: [cleanPhone, customerId],
      limit: 1,
    );

    if (duplicate.isNotEmpty) {
      return {
        'success': false,
        'message': 'Số điện thoại đã thuộc về một khách hàng khác',
      };
    }

    final updatedCount = await _appDb.updateCustomer(
      customerId,
      fullName: fullName,
      phoneNumber: cleanPhone,
      addressText: addressText,
    );

    if (updatedCount > 0) {
      return {
        'success': true,
        'message': 'Cập nhật thông tin khách hàng thành công',
      };
    }

    return {
      'success': false,
      'message': 'Không tìm thấy khách hàng để cập nhật',
    };
  }

  @override
  Future<Map<String, dynamic>?> lookupCustomerLocationByPhone(String phoneNumber) async {
    final cleanPhone = normalizeCustomerPhone(phoneNumber);
    final customer = await _appDb.getCustomerByPhone(cleanPhone);
    if (customer == null) return null;

    final custId = customer['id'] as String;
    final savedLoc = await _appDb.getSavedLocationByCustomerId(custId);

    LocationStatus locState = LocationStatus.noLocation;
    double? lat;
    double? lng;
    String? notes;
    String? savedLocId;

    if (savedLoc != null && savedLoc['latitude'] != null && savedLoc['longitude'] != null) {
      locState = LocationStatus.verified;
      lat = (savedLoc['latitude'] as num).toDouble();
      lng = (savedLoc['longitude'] as num).toDouble();
      notes = savedLoc['identification_notes'] as String?;
      savedLocId = savedLoc['id'] as String?;
    } else {
      final db = await _appDb.database;
      final tempRows = await db.rawQuery('''
        SELECT sdp.latitude, sdp.longitude, sdp.identification_notes
        FROM shift_delivery_points sdp
        JOIN shifts s ON s.id = sdp.shift_id
        WHERE sdp.customer_id = ?
          AND sdp.location_status = 'TEMPORARY'
          AND s.status IN ('PREPARING', 'IN_PROGRESS')
        ORDER BY sdp.updated_at DESC
        LIMIT 1
      ''', [custId]);
      if (tempRows.isNotEmpty) {
        locState = LocationStatus.temporary;
        lat = (tempRows.first['latitude'] as num).toDouble();
        lng = (tempRows.first['longitude'] as num).toDouble();
        notes = tempRows.first['identification_notes'] as String?;
      }
    }

    return {
      'id': custId,
      'customerId': custId,
      'customerCode': customer['customer_code'] ?? 'CUST',
      'fullName': customer['full_name'] ?? '',
      'phoneNumber': customer['phone_number'] ?? cleanPhone,
      'addressText': customer['address_text'] ?? '',
      'areaId': defaultAreaId,
      'areaName': defaultAreaName,
      'hasLocation': locState != LocationStatus.noLocation,
      'latitude': lat,
      'longitude': lng,
      'locationStatus': locState.toApiString(),
      'locationState': locState.toApiString(),
      'identificationNotes': notes,
      'savedLocationId': savedLocId,
      'createdAt': customer['created_at'],
      'updatedAt': customer['updated_at'],
    };
  }

  @override
  Future<bool> deleteCustomer(String customerId) async {
    final db = await _appDb.database;

    // Kiểm tra khách hàng có nằm trong ca PREPARING hoặc IN_PROGRESS không
    final inActiveShift = await db.rawQuery('''
      SELECT COUNT(*) as cnt
      FROM shift_delivery_points sdp
      JOIN shifts s ON s.id = sdp.shift_id
      WHERE sdp.customer_id = ?
        AND s.status IN ('PREPARING', 'IN_PROGRESS')
    ''', [customerId]);

    final cnt = (inActiveShift.first['cnt'] as num?)?.toInt() ?? 0;
    if (cnt > 0) {
      throw Exception('Không thể xóa khách hàng đang nằm trong ca làm việc đang chuẩn bị hoặc đang thực hiện');
    }

    final affected = await _appDb.softDeleteCustomer(customerId);
    return affected > 0;
  }
}
