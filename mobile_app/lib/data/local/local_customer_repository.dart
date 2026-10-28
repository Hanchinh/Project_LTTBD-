import 'package:delivery_marker_mobile/core/utils/phone_utils.dart';
import 'package:delivery_marker_mobile/core/utils/uuid_utils.dart';
import 'package:delivery_marker_mobile/core/utils/vietnamese_utils.dart';
import 'package:delivery_marker_mobile/data/local/app_database.dart';
import 'package:delivery_marker_mobile/data/local/customer_bulk_helpers.dart';
import 'package:delivery_marker_mobile/data/local/customer_query_helpers.dart';
import 'package:delivery_marker_mobile/data/local/local_photo_repository.dart';
import 'package:delivery_marker_mobile/data/repositories/customer_repository.dart';
import 'package:delivery_marker_mobile/models/customer_model.dart';
import 'package:delivery_marker_mobile/models/shift_model.dart';

/// Triển khai CustomerRepository cục bộ bằng SQLite (Local-First).
/// Toàn bộ dữ liệu khách hàng được lưu trữ và truy vấn trực tiếp trên thiết bị.
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
  }) =>
      CustomerQueryHelpers.queryCustomersResponse(
        appDb: _appDb,
        photoRepo: _photoRepo,
        query: query,
        status: status,
        hasPhoto: hasPhoto,
        limit: limit,
        offset: offset,
        defaultAreaId: defaultAreaId,
        defaultAreaName: defaultAreaName,
      );

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

    // Nạp danh sách ảnh
    final photos = await _photoRepo.getCustomerPhotos(customerId);

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
      savedLocationId: savedLocId,
      createdAt: DateTime.tryParse(customer['created_at']?.toString() ?? ''),
      updatedAt: DateTime.tryParse(customer['updated_at']?.toString() ?? ''),
      photoCount: photos.length,
      photos: photos,
      firstThumbnailUrl: photos.isNotEmpty ? photos.first.imageUrl : null,
      imageUrl: photos.isNotEmpty ? photos.first.imageUrl : null,
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
      // 1. Kiểm tra xem số điện thoại đã tồn tại trong CSDL chưa
      final existingRows = await txn.query(
        'customers',
        where: 'phone_number = ? AND deleted_at IS NULL',
        whereArgs: [cleanPhone],
        limit: 1,
      );

      if (existingRows.isNotEmpty) {
        final existing = existingRows.first;
        final custId = existing['id'] as String;

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

  /// Tiện ích tạo khách hàng nhanh
  Future<CustomerDirectoryModel> createCustomerQuick({
    required String phoneNumber,
    String? fullName,
    String? addressText,
    String? areaId,
    double? latitude,
    double? longitude,
    double? gpsAccuracy,
    String? identificationNotes,
  }) =>
      createCustomer(
        phoneNumber: phoneNumber,
        fullName: fullName,
        addressText: addressText,
        areaId: areaId,
        latitude: latitude,
        longitude: longitude,
        gpsAccuracy: gpsAccuracy,
        identificationNotes: identificationNotes,
      );

  @override
  Future<BulkCreateCustomersResult> createBulkCustomers({
    String? rawText,
    List<String>? phones,
    String? areaId,
  }) =>
      CustomerBulkHelpers.executeBulkCreate(
        appDb: _appDb,
        rawText: rawText,
        phones: phones,
        areaId: areaId,
        defaultAreaId: defaultAreaId,
      );

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
