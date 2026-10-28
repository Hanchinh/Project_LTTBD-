import 'package:delivery_marker_mobile/models/customer_model.dart';

abstract class CustomerRepository {
  Future<List<CustomerDirectoryModel>> getCustomers({
    String? query,
    String? status,
    bool? hasPhoto,
    int? limit,
    int? offset,
  });

  Future<CustomerDirectoryResponse> getCustomersResponse({
    String? query,
    String? status,
    bool? hasPhoto,
    int? limit,
    int? offset,
  });

  Future<CustomerDirectoryModel> getCustomerDetail(String customerId);

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
  });

  Future<BulkCreateCustomersResult> createBulkCustomers({
    String? rawText,
    List<String>? phones,
    String? areaId,
  });

  Future<Map<String, dynamic>> updateCustomer({
    required String customerId,
    required String fullName,
    required String phoneNumber,
    String? addressText,
  });

  Future<Map<String, dynamic>?> lookupCustomerLocationByPhone(String phoneNumber);

  /// Xóa mềm khách hàng (kiểm tra không nằm trong ca PREPARING/IN_PROGRESS)
  Future<bool> deleteCustomer(String customerId) async => false;
}
