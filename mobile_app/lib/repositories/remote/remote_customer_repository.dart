import '../../models/customer_model.dart';
import '../../services/api_service.dart';
import '../customer_repository.dart';

class RemoteCustomerRepository implements CustomerRepository {
  @override
  Future<List<CustomerDirectoryModel>> getCustomers({
    String? query,
    String? status,
    bool? hasPhoto,
    int? limit,
    int? offset,
  }) {
    return ApiService.getCustomers(
      query: query,
      status: status,
      hasPhoto: hasPhoto,
      limit: limit,
      offset: offset,
    );
  }

  @override
  Future<CustomerDirectoryResponse> getCustomersResponse({
    String? query,
    String? status,
    bool? hasPhoto,
    int? limit,
    int? offset,
  }) {
    return ApiService.getCustomersResponse(
      query: query,
      status: status,
      hasPhoto: hasPhoto,
      limit: limit,
      offset: offset,
    );
  }

  @override
  Future<CustomerDirectoryModel> getCustomerDetail(String customerId) {
    return ApiService.getCustomerDetail(customerId);
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
  }) {
    return ApiService.createCustomer(
      phoneNumber: phoneNumber,
      fullName: fullName,
      addressText: addressText,
      areaId: areaId,
      latitude: latitude,
      longitude: longitude,
      gpsAccuracy: gpsAccuracy,
      identificationNotes: identificationNotes,
      imageBase64: imageBase64,
    );
  }

  @override
  Future<BulkCreateCustomersResult> createBulkCustomers({
    String? rawText,
    List<String>? phones,
    String? areaId,
  }) {
    return ApiService.createBulkCustomers(
      rawText: rawText,
      phones: phones,
      areaId: areaId,
    );
  }

  @override
  Future<Map<String, dynamic>> updateCustomer({
    required String customerId,
    required String fullName,
    required String phoneNumber,
    String? addressText,
  }) {
    return ApiService.updateCustomer(
      customerId: customerId,
      fullName: fullName,
      phoneNumber: phoneNumber,
      addressText: addressText,
    );
  }

  @override
  Future<Map<String, dynamic>?> lookupCustomerLocationByPhone(String phoneNumber) {
    return ApiService.lookupCustomerLocationByPhone(phoneNumber);
  }
}
