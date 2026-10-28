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
  }) async =>
      (await getCustomersResponse(
        query: query,
        status: status,
        hasPhoto: hasPhoto,
        limit: limit,
        offset: offset,
      )).items;

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

  Future<_ResolvedLoc> _getResolvedLoc(String customerId) async {
    final saved = await _appDb.getSavedLocationByCustomerId(customerId);
    if (saved != null && saved['latitude'] != null && saved['longitude'] != null) {
      return _ResolvedLoc(
        state: LocationStatus.verified,
        lat: (saved['latitude'] as num).toDouble(),
        lng: (saved['longitude'] as num).toDouble(),
        notes: saved['identification_notes'] as String?,
        savedLocId: saved['id'] as String?,
      );
    }
    final db = await _appDb.database;
    final temp = await db.rawQuery('''
      SELECT sdp.latitude, sdp.longitude, sdp.identification_notes
      FROM shift_delivery_points sdp
      JOIN shifts s ON s.id = sdp.shift_id
      WHERE sdp.customer_id = ? AND sdp.location_status = 'TEMPORARY' AND s.status IN ('PREPARING', 'IN_PROGRESS')
      ORDER BY sdp.updated_at DESC LIMIT 1
    ''', [customerId]);
    if (temp.isNotEmpty) {
      return _ResolvedLoc(
        state: LocationStatus.temporary,
        lat: (temp.first['latitude'] as num).toDouble(),
        lng: (temp.first['longitude'] as num).toDouble(),
        notes: temp.first['identification_notes'] as String?,
      );
    }
    return const _ResolvedLoc(state: LocationStatus.noLocation);
  }

  @override
  Future<CustomerDirectoryModel> getCustomerDetail(String customerId) async {
    final customer = await _appDb.getCustomerById(customerId);
    if (customer == null) throw Exception('Không tìm thấy thông tin khách hàng');
    final loc = await _getResolvedLoc(customerId);
    final photos = await _photoRepo.getCustomerPhotos(customerId);
    final thumb = photos.isNotEmpty ? photos.first.imageUrl : null;

    return CustomerDirectoryModel(
      id: customerId,
      customerCode: (customer['customer_code'] as String?) ?? 'CUST',
      fullName: (customer['full_name'] as String?) ?? '',
      phoneNumber: (customer['phone_number'] as String?) ?? '',
      addressText: (customer['address_text'] as String?) ?? '',
      areaId: defaultAreaId,
      areaName: defaultAreaName,
      locationStatus: loc.state,
      locationState: loc.state,
      hasLocation: loc.state != LocationStatus.noLocation,
      latitude: loc.lat,
      longitude: loc.lng,
      identificationNotes: loc.notes,
      savedLocationId: loc.savedLocId,
      createdAt: DateTime.tryParse(customer['created_at']?.toString() ?? ''),
      updatedAt: DateTime.tryParse(customer['updated_at']?.toString() ?? ''),
      photoCount: photos.length,
      photos: photos,
      firstThumbnailUrl: thumb,
      imageUrl: thumb,
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
    if (!isValidVnPhone(cleanPhone)) throw ArgumentError('Số điện thoại không hợp lệ (cần 10 chữ số bắt đầu bằng 0)');

    return await _appDb.transaction<CustomerDirectoryModel>((txn) async {
      final existingRows = await txn.query('customers', where: 'phone_number = ? AND deleted_at IS NULL', whereArgs: [cleanPhone], limit: 1);
      if (existingRows.isNotEmpty) {
        final ex = existingRows.first;
        final cid = ex['id'] as String;
        final locs = await txn.query('saved_locations', where: 'customer_id = ?', whereArgs: [cid], limit: 1);
        final hasLoc = locs.isNotEmpty;
        final loc = hasLoc ? locs.first : null;
        return CustomerDirectoryModel(
          id: cid,
          customerCode: (ex['customer_code'] as String?) ?? 'CUST',
          fullName: (ex['full_name'] as String?) ?? '',
          phoneNumber: (ex['phone_number'] as String?) ?? cleanPhone,
          addressText: (ex['address_text'] as String?) ?? '',
          areaId: defaultAreaId,
          areaName: defaultAreaName,
          locationStatus: hasLoc ? LocationStatus.verified : LocationStatus.noLocation,
          locationState: hasLoc ? LocationStatus.verified : LocationStatus.noLocation,
          hasLocation: hasLoc,
          latitude: loc != null ? (loc['latitude'] as num).toDouble() : null,
          longitude: loc != null ? (loc['longitude'] as num).toDouble() : null,
          identificationNotes: loc?['identification_notes'] as String?,
          savedLocationId: loc?['id'] as String?,
          createdAt: DateTime.tryParse(ex['created_at']?.toString() ?? ''),
          updatedAt: DateTime.tryParse(ex['updated_at']?.toString() ?? ''),
          isExisting: true,
        );
      }

      final newId = UuidUtils.generate();
      final name = (fullName != null && fullName.trim().isNotEmpty) ? fullName.trim() : 'Khách $cleanPhone';
      final addr = (addressText != null && addressText.trim().isNotEmpty) ? addressText.trim() : 'Chưa cập nhật địa chỉ';
      final now = AppDatabase.currentIsoUtc();
      final searchText = buildCustomerSearchText(fullName: name, phoneNumber: cleanPhone, addressText: addr);

      await txn.insert('customers', {
        'id': newId,
        'customer_code': 'CUST-${cleanPhone.substring(cleanPhone.length - 4)}',
        'full_name': name,
        'phone_number': cleanPhone,
        'address_text': addr,
        'search_text': searchText,
        'created_at': now,
        'updated_at': now,
      });

      String? savedLocationId;
      bool hasLocation = false;
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
        fullName: name,
        phoneNumber: cleanPhone,
        addressText: addr,
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
      return {'success': false, 'message': 'Số điện thoại không hợp lệ (cần 10 chữ số bắt đầu bằng 0)'};
    }
    final db = await _appDb.database;
    final duplicate = await db.query('customers', where: 'phone_number = ? AND id != ? AND deleted_at IS NULL', whereArgs: [cleanPhone, customerId], limit: 1);
    if (duplicate.isNotEmpty) {
      return {'success': false, 'message': 'Số điện thoại đã thuộc về một khách hàng khác'};
    }
    final count = await _appDb.updateCustomer(customerId, fullName: fullName, phoneNumber: cleanPhone, addressText: addressText);
    return {
      'success': count > 0,
      'message': count > 0 ? 'Cập nhật thông tin khách hàng thành công' : 'Không tìm thấy khách hàng để cập nhật',
    };
  }

  @override
  Future<Map<String, dynamic>?> lookupCustomerLocationByPhone(String phoneNumber) async {
    final cleanPhone = normalizeCustomerPhone(phoneNumber);
    final customer = await _appDb.getCustomerByPhone(cleanPhone);
    if (customer == null) return null;
    final custId = customer['id'] as String;
    final loc = await _getResolvedLoc(custId);

    return {
      'id': custId,
      'customerId': custId,
      'customerCode': customer['customer_code'] ?? 'CUST',
      'fullName': customer['full_name'] ?? '',
      'phoneNumber': customer['phone_number'] ?? cleanPhone,
      'addressText': customer['address_text'] ?? '',
      'areaId': defaultAreaId,
      'areaName': defaultAreaName,
      'hasLocation': loc.state != LocationStatus.noLocation,
      'latitude': loc.lat,
      'longitude': loc.lng,
      'locationStatus': loc.state.toApiString(),
      'locationState': loc.state.toApiString(),
      'identificationNotes': loc.notes,
      'savedLocationId': loc.savedLocId,
      'createdAt': customer['created_at'],
      'updatedAt': customer['updated_at'],
    };
  }

  @override
  Future<bool> deleteCustomer(String customerId) async {
    final db = await _appDb.database;
    final inActive = await db.rawQuery('''
      SELECT COUNT(*) as cnt FROM shift_delivery_points sdp
      JOIN shifts s ON s.id = sdp.shift_id
      WHERE sdp.customer_id = ? AND s.status IN ('PREPARING', 'IN_PROGRESS')
    ''', [customerId]);
    if (((inActive.first['cnt'] as num?)?.toInt() ?? 0) > 0) {
      throw Exception('Không thể xóa khách hàng đang nằm trong ca làm việc đang chuẩn bị hoặc đang thực hiện');
    }
    return (await _appDb.softDeleteCustomer(customerId)) > 0;
  }
}

class _ResolvedLoc {
  final LocationStatus state;
  final double? lat;
  final double? lng;
  final String? notes;
  final String? savedLocId;
  const _ResolvedLoc({required this.state, this.lat, this.lng, this.notes, this.savedLocId});
}
