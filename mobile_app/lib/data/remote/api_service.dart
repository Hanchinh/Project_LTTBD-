import 'package:delivery_marker_mobile/models/address_search_result.dart';
import 'package:delivery_marker_mobile/models/user_model.dart';
import 'package:delivery_marker_mobile/models/order_model.dart';
import 'package:delivery_marker_mobile/models/location_model.dart';
import 'package:delivery_marker_mobile/models/shift_model.dart';
import 'package:delivery_marker_mobile/models/customer_model.dart';
import 'package:delivery_marker_mobile/models/customer_photo_model.dart';
import 'package:delivery_marker_mobile/models/data_share_model.dart';
import 'package:delivery_marker_mobile/data/remote/api_client.dart';
import 'package:delivery_marker_mobile/data/remote/auth_api.dart';
import 'package:delivery_marker_mobile/data/remote/customer_api.dart';
import 'package:delivery_marker_mobile/data/remote/location_api.dart';
import 'package:delivery_marker_mobile/data/remote/photo_api.dart';
import 'package:delivery_marker_mobile/data/remote/shift_api.dart';
import 'package:delivery_marker_mobile/data/remote/sharing_api.dart';
import 'package:delivery_marker_mobile/data/remote/geocoding_api.dart';

export 'package:delivery_marker_mobile/models/address_search_result.dart';

/// Facade mỏng duy trì tương thích 100% cho ApiService cũ.
/// Mọi lời gọi được chuyển tiếp sang các module chuyên biệt trong `services/remote/`.
class ApiService {
  // --- Cấu hình Base URL & Token ---
  static Future<String> getBaseUrl() => ApiClient.getBaseUrl();
  static Future<void> setCustomBaseUrl(String url) => ApiClient.setCustomBaseUrl(url);
  static Future<void> resetCustomBaseUrl() => ApiClient.resetCustomBaseUrl();
  static Future<String?> getToken() => ApiClient.getToken();
  static Future<void> saveToken(String token) => ApiClient.saveToken(token);
  static Future<void> logout() => ApiClient.logout();
  static Future<String?> getSavedLoginPhone() => ApiClient.getSavedLoginPhone();
  static Future<void> saveLoginPhone(String phone) => ApiClient.saveLoginPhone(phone);
  static Future<String?> getLastActiveShiftId() => ApiClient.getLastActiveShiftId();
  static Future<void> saveLastActiveShiftId(String shiftId) => ApiClient.saveLastActiveShiftId(shiftId);
  static Future<String?> getPreferredAreaId() => ApiClient.getPreferredAreaId();
  static Future<void> setPreferredAreaId(String areaId) => ApiClient.setPreferredAreaId(areaId);
  static Future<void> clearPreferredAreaId() => ApiClient.clearPreferredAreaId();

  // --- Auth & Profile API ---
  static Future<UserModel?> getCurrentUser() => AuthApi.getCurrentUser();
  static Future<List<Map<String, dynamic>>> getMyAreas() => AuthApi.getMyAreas();
  static Future<UserModel?> login(String phoneNumber, String password) => AuthApi.login(phoneNumber, password);
  static Future<Map<String, int>> getMyStats() => AuthApi.getMyStats();
  static Future<Map<String, dynamic>> changePassword({
    required String currentPassword,
    required String newPassword,
    String? confirmPassword,
  }) =>
      AuthApi.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
        confirmPassword: confirmPassword,
      );

  // --- Photo API ---
  static Future<Map<String, String>> getPhotoAuthInfo(
    String photoPath, {
    int? cacheVersion,
    bool bustCache = false,
  }) =>
      PhotoApi.getPhotoAuthInfo(photoPath, cacheVersion: cacheVersion, bustCache: bustCache);

  static Future<List<CustomerPhotoModel>> getCustomerPhotos(String customerId) =>
      PhotoApi.getCustomerPhotos(customerId);

  static Future<CustomerPhotoModel> addCustomerPhoto(String customerId, String imageBase64) =>
      PhotoApi.addCustomerPhoto(customerId, imageBase64);

  static Future<void> deleteCustomerPhoto(String customerId, String photoId) =>
      PhotoApi.deleteCustomerPhoto(customerId, photoId);

  // --- Location API ---
  static Future<bool> saveCustomerLocation(SavedLocationModel location, {String? imageBase64}) =>
      LocationApi.saveCustomerLocation(location, imageBase64: imageBase64);

  static Future<Map<String, dynamic>> updateCustomerLocationAndPhoto({
    required String customerId,
    required double latitude,
    required double longitude,
    double? gpsAccuracy,
    required String identificationNotes,
    String? imageBase64,
    bool? deletePhoto,
  }) =>
      LocationApi.updateCustomerLocationAndPhoto(
        customerId: customerId,
        latitude: latitude,
        longitude: longitude,
        gpsAccuracy: gpsAccuracy,
        identificationNotes: identificationNotes,
        imageBase64: imageBase64,
        deletePhoto: deletePhoto,
      );

  static Future<void> deleteCustomerLocation(String customerId) =>
      LocationApi.deleteCustomerLocation(customerId);

  static Future<List<MasterSavedLocationModel>> getMySavedLocations() => LocationApi.getMySavedLocations();

  static Future<void> openExternalNavigation(double lat, double lng) =>
      LocationApi.openExternalNavigation(lat, lng);

  // --- Shift API & Delivery Points ---
  static Future<List<ShiftModel>> getShifts() => ShiftApi.getShifts();

  static Future<ShiftModel> createShift({String? shiftDate, String? shiftName, String? notes}) =>
      ShiftApi.createShift(shiftDate: shiftDate, shiftName: shiftName, notes: notes);

  static Future<ShiftModel> updateShiftName(String shiftId, String shiftName) =>
      ShiftApi.updateShiftName(shiftId, shiftName);

  static Future<bool> deleteShift(String shiftId) => ShiftApi.deleteShift(shiftId);

  static Future<ShiftModel> getShiftDetail(String shiftId) => ShiftApi.getShiftDetail(shiftId);

  static Future<ShiftModel> updateShiftStatus(String shiftId, ShiftStatus status) =>
      ShiftApi.updateShiftStatus(shiftId, status);

  static Future<Map<String, dynamic>> addPointToShift(
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
  }) =>
      ShiftApi.addPointToShift(
        shiftId,
        customerId: customerId,
        phoneNumber: phoneNumber,
        createIfNotFound: createIfNotFound,
        fullName: fullName,
        addressText: addressText,
        orderId: orderId,
        sequenceNumber: sequenceNumber,
        deliveryNotes: deliveryNotes,
        areaId: areaId,
      );

  static Future<Map<String, dynamic>> quickCreateCustomerAndAddToShift({
    required String shiftId,
    required String phoneNumber,
    String? fullName,
    String? addressText,
    String? deliveryNotes,
    String? areaId,
  }) =>
      ShiftApi.quickCreateCustomerAndAddToShift(
        shiftId: shiftId,
        phoneNumber: phoneNumber,
        fullName: fullName,
        addressText: addressText,
        deliveryNotes: deliveryNotes,
        areaId: areaId,
      );

  static Future<void> removePointFromShift(String shiftId, String pointId) =>
      ShiftApi.removePointFromShift(shiftId, pointId);

  static Future<BulkAddPointsResult> addBulkPointsToShift({
    required String shiftId,
    String? rawText,
    List<String>? phones,
    String? areaId,
  }) =>
      ShiftApi.addBulkPointsToShift(
        shiftId: shiftId,
        rawText: rawText,
        phones: phones,
        areaId: areaId,
      );

  static Future<ShiftDeliveryPointModel> updateTemporaryLocation(
    String shiftId,
    String pointId, {
    required double latitude,
    required double longitude,
    String? locationNotes,
    String? identificationNotes,
  }) =>
      ShiftApi.updateTemporaryLocation(
        shiftId,
        pointId,
        latitude: latitude,
        longitude: longitude,
        locationNotes: locationNotes,
        identificationNotes: identificationNotes,
      );

  // Legacy Orders
  static Future<List<OrderModel>> getMyShiftOrders() => ShiftApi.getMyShiftOrders();

  static Future<Map<String, dynamic>> addOrderToShift({
    required String customerId,
    bool allowMultiple = false,
    String? idempotencyKey,
  }) =>
      ShiftApi.addOrderToShift(
        customerId: customerId,
        allowMultiple: allowMultiple,
        idempotencyKey: idempotencyKey,
      );

  static Future<int> getPendingSyncCount() => ShiftApi.getPendingSyncCount();
  static Future<void> syncOfflineQueue() => ShiftApi.syncOfflineQueue();

  // --- Customer Directory API ---
  static Future<Map<String, dynamic>?> lookupCustomerLocationByPhone(String phoneNumber) =>
      CustomerApi.lookupCustomerLocationByPhone(phoneNumber);

  static Future<CustomerDirectoryResponse> getCustomersResponse({
    String? query,
    String? status,
    bool? hasPhoto,
    int? limit,
    int? offset,
  }) =>
      CustomerApi.getCustomersResponse(
        query: query,
        status: status,
        hasPhoto: hasPhoto,
        limit: limit,
        offset: offset,
      );

  static Future<List<CustomerDirectoryModel>> getCustomers({
    String? query,
    String? status,
    bool? hasPhoto,
    int? limit,
    int? offset,
  }) =>
      CustomerApi.getCustomers(
        query: query,
        status: status,
        hasPhoto: hasPhoto,
        limit: limit,
        offset: offset,
      );

  static Future<CustomerDirectoryModel> getCustomerDetail(String customerId) =>
      CustomerApi.getCustomerDetail(customerId);

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
  }) =>
      CustomerApi.createCustomer(
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

  static Future<Map<String, dynamic>> updateCustomer({
    required String customerId,
    required String fullName,
    required String phoneNumber,
    String? addressText,
  }) =>
      CustomerApi.updateCustomer(
        customerId: customerId,
        fullName: fullName,
        phoneNumber: phoneNumber,
        addressText: addressText,
      );

  static Future<BulkCreateCustomersResult> createBulkCustomers({
    String? rawText,
    List<String>? phones,
    String? areaId,
  }) =>
      CustomerApi.createBulkCustomers(
        rawText: rawText,
        phones: phones,
        areaId: areaId,
      );

  // --- Geocoding API ---
  static Future<List<AddressSearchResult>> searchAddress(String query) =>
      GeocodingApi.searchAddress(query);

  // --- Data Sharing API (Server Mode) ---
  static Future<DataShareModel> createShare({
    required String recipientPhone,
    required String scope,
    String? shiftId,
    bool includePhotos = false,
    int? expiresInDays,
  }) =>
      SharingApi.createShare(
        recipientPhone: recipientPhone,
        scope: scope,
        shiftId: shiftId,
        includePhotos: includePhotos,
        expiresInDays: expiresInDays,
      );

  static Future<List<DataShareModel>> getOutgoingShares() => SharingApi.getOutgoingShares();
  static Future<List<DataShareModel>> getIncomingShares() => SharingApi.getIncomingShares();
  static Future<void> acceptShare(String shareId) => SharingApi.acceptShare(shareId);
  static Future<void> declineShare(String shareId) => SharingApi.declineShare(shareId);
  static Future<void> revokeShare(String shareId) => SharingApi.revokeShare(shareId);
  static Future<Map<String, dynamic>> getSharedLocations() => SharingApi.getSharedLocations();
  static Future<Map<String, dynamic>> importSharedLocations(
    String shareId, {
    List<String>? customerIds,
    bool all = true,
    bool replaceExisting = false,
  }) =>
      SharingApi.importSharedLocations(
        shareId,
        customerIds: customerIds,
        all: all,
        replaceExisting: replaceExisting,
      );
}
