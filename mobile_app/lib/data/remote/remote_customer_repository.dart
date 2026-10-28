import 'package:delivery_marker_mobile/models/customer_model.dart';
import 'package:delivery_marker_mobile/data/remote/customer_api.dart';
import 'package:delivery_marker_mobile/data/repositories/customer_repository.dart';

class RemoteCustomerRepository implements CustomerRepository {
  @override
  Future<List<CustomerDirectoryModel>> getCustomers({
    String? query,
    String? status,
    bool? hasPhoto,
    int? limit,
    int? offset,
  }) {
    return CustomerApi.getCustomers(
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
    return CustomerApi.getCustomersResponse(
      query: query,
      status: status,
      hasPhoto: hasPhoto,
      limit: limit,
      offset: offset,
    );
  }

  @override
  Future<CustomerDirectoryModel> getCustomerDetail(String customerId) {
    return CustomerApi.getCustomerDetail(customerId);
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
    return CustomerApi.createCustomer(
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
    return CustomerApi.createBulkCustomers(
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
    return CustomerApi.updateCustomer(
      customerId: customerId,
      fullName: fullName,
      phoneNumber: phoneNumber,
      addressText: addressText,
    );
  }

  @override
  Future<Map<String, dynamic>?> lookupCustomerLocationByPhone(String phoneNumber) {
    return CustomerApi.lookupCustomerLocationByPhone(phoneNumber);
  }

  @override
  Future<bool> deleteCustomer(String customerId) async {
    return false;
  }
}
