import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:delivery_marker_mobile/models/customer_model.dart';
import 'package:delivery_marker_mobile/models/shift_model.dart';
import 'package:delivery_marker_mobile/data/remote/api_client.dart';

/// Module API phụ trách quản lý khách hàng, danh bạ, tra cứu và thêm hàng loạt.
class CustomerApi {
  static Future<Map<String, dynamic>?> lookupCustomerLocationByPhone(String phoneNumber) async {
    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity == ConnectivityResult.none) {
      throw Exception('Không có kết nối mạng. Bác tài vui lòng kiểm tra kết nối WiFi/4G.');
    }

    final cleanPhone = phoneNumber.replaceAll(RegExp(r'\D'), '');
    try {
      final response = await ApiClient.get(
        '/customers/by-phone/$cleanPhone/location',
        timeout: const Duration(seconds: 10),
      );
      if (response is Map) {
        return response['data'] as Map<String, dynamic>?;
      }
      return null;
    } catch (e) {
      if (e.toString().contains('404')) return null;
      rethrow;
    }
  }

  static Future<CustomerDirectoryResponse> getCustomersResponse({
    String? query,
    String? status,
    bool? hasPhoto,
    int? limit,
    int? offset,
  }) async {
    final queryParams = <String, dynamic>{};
    if (query != null && query.trim().isNotEmpty) queryParams['q'] = query.trim();
    if (status != null && status != 'ALL') queryParams['status'] = status;
    if (hasPhoto != null) queryParams['hasPhoto'] = hasPhoto ? 'true' : 'false';
    if (limit != null) queryParams['limit'] = limit;
    if (offset != null) queryParams['offset'] = offset;

    final response = await ApiClient.get(
      '/customers',
      queryParams: queryParams.isNotEmpty ? queryParams : null,
      timeout: const Duration(seconds: 12),
    );

    if (response is Map && response['success'] == true) {
      final List data = response['data'] as List? ?? [];
      final items = data.map((json) => CustomerDirectoryModel.fromJson(json)).toList();
      final counts = CustomerTabCounts.fromJson(response['counts'] as Map<String, dynamic>?);
      final pagination = CustomerPagination.fromJson(response['pagination'] as Map<String, dynamic>?);
      return CustomerDirectoryResponse(
        items: items,
        counts: counts,
        pagination: pagination,
      );
    }
    throw Exception(response['message'] ?? 'Không thể tải danh bạ khách hàng');
  }

  static Future<List<CustomerDirectoryModel>> getCustomers({
    String? query,
    String? status,
    bool? hasPhoto,
    int? limit,
    int? offset,
  }) async {
    final res = await getCustomersResponse(
      query: query,
      status: status,
      hasPhoto: hasPhoto,
      limit: limit,
      offset: offset,
    );
    return res.items;
  }

  static Future<CustomerDirectoryModel> getCustomerDetail(String customerId) async {
    final response = await ApiClient.get(
      '/customers/$customerId',
      timeout: const Duration(seconds: 10),
    );

    if (response is Map && response['success'] == true) {
      final cust = response['data']['customer'];
      final loc = response['data']['savedLocation'];
      final statusStr = response['data']['locationStatus']?.toString() ??
          (loc != null ? (loc['status']?.toString() ?? 'VERIFIED') : 'NO_LOCATION');
      LocationStatus status;
      if (statusStr == 'VERIFIED') {
        status = LocationStatus.verified;
      } else if (statusStr == 'TEMPORARY') {
        status = LocationStatus.temporary;
      } else {
        status = LocationStatus.noLocation;
      }

      return CustomerDirectoryModel(
        id: cust['id'],
        customerCode: cust['customerCode'] ?? '',
        fullName: cust['fullName'] ?? '',
        phoneNumber: cust['phoneNumber'] ?? '',
        addressText: cust['addressText'] ?? '',
        areaId: cust['areaId'],
        areaName: cust['areaName'],
        locationStatus: status,
        hasLocation: loc != null && loc['latitude'] != null && loc['longitude'] != null,
        latitude: loc != null ? (loc['latitude'] as num?)?.toDouble() : null,
        longitude: loc != null ? (loc['longitude'] as num?)?.toDouble() : null,
        identificationNotes: loc?['identificationNotes'],
        imageUrl: loc?['imageUrl'],
        savedLocationId: loc?['id'],
        createdAt: cust['createdAt'] != null ? DateTime.tryParse(cust['createdAt']) : null,
        updatedAt: cust['updatedAt'] != null ? DateTime.tryParse(cust['updatedAt']) : null,
      );
    }
    throw Exception(response['message'] ?? 'Không thể lấy thông tin chi tiết khách hàng');
  }

  static Future<CustomerDirectoryModel> createCustomer({
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
    final response = await ApiClient.post(
      '/customers',
      body: {
        'phoneNumber': phoneNumber.trim(),
        if (fullName != null) 'fullName': fullName.trim(),
        if (addressText != null) 'addressText': addressText.trim(),
        if (areaId != null) 'areaId': areaId,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        if (gpsAccuracy != null) 'gpsAccuracy': gpsAccuracy,
        if (identificationNotes != null) 'identificationNotes': identificationNotes.trim(),
        if (imageBase64 != null) 'imageBase64': imageBase64,
      },
      timeout: const Duration(seconds: 15),
    );

    if (response is Map && response['success'] == true) {
      final cust = CustomerDirectoryModel.fromJson(response['data']);
      return cust.copyWith(isExisting: response['isExisting'] == true);
    }
    throw Exception(response['message'] ?? 'Không thể tạo hồ sơ khách hàng mới');
  }

  static Future<Map<String, dynamic>> updateCustomer({
    required String customerId,
    required String fullName,
    required String phoneNumber,
    String? addressText,
  }) async {
    final response = await ApiClient.put(
      '/customers/$customerId',
      body: {
        'fullName': fullName.trim(),
        'phoneNumber': phoneNumber.trim(),
        if (addressText != null) 'addressText': addressText.trim(),
      },
      timeout: const Duration(seconds: 10),
    );

    if (response is Map && response['success'] == true) {
      return response['data'] as Map<String, dynamic>;
    }
    throw Exception(response['message'] ?? 'Không thể cập nhật khách hàng');
  }

  static Future<BulkCreateCustomersResult> createBulkCustomers({
    String? rawText,
    List<String>? phones,
    String? areaId,
  }) async {
    final response = await ApiClient.post(
      '/customers/bulk',
      body: {
        if (rawText != null) 'rawText': rawText,
        if (phones != null) 'phones': phones,
        if (areaId != null) 'areaId': areaId,
      },
      timeout: const Duration(seconds: 25),
    );

    if (response is Map && response['success'] == true) {
      return BulkCreateCustomersResult.fromJson(response['data']);
    }
    throw Exception(response['message'] ?? 'Không thể thêm danh sách SĐT vào danh bạ');
  }
}

