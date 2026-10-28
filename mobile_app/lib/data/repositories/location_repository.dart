import 'package:delivery_marker_mobile/models/location_model.dart';
import 'package:delivery_marker_mobile/models/shift_model.dart';

abstract class LocationRepository {
  Future<List<MasterSavedLocationModel>> getMySavedLocations();

  Future<bool> saveCustomerLocation(
    SavedLocationModel location, {
    String? imageBase64,
  });

  Future<Map<String, dynamic>> updateCustomerLocationAndPhoto({
    required String customerId,
    required double latitude,
    required double longitude,
    double? gpsAccuracy,
    required String identificationNotes,
    String? imageBase64,
    bool? deletePhoto,
  });

  Future<void> deleteCustomerLocation(String customerId);

  Future<ShiftDeliveryPointModel> updateTemporaryLocation(
    String shiftId,
    String pointId, {
    required double latitude,
    required double longitude,
    String? locationNotes,
    String? identificationNotes,
  });

  Future<int> getPendingSyncCount();

  Future<void> syncOfflineQueue();

  /// Lấy danh sách vị trí đã lưu trong khung nhìn bản đồ (bbox)
  Future<List<MasterSavedLocationModel>> getSavedLocationsInBounds({
    required double minLat,
    required double maxLat,
    required double minLng,
    required double maxLng,
  }) async => [];

  /// Lấy lịch sử thay đổi vị trí của khách hàng
  Future<List<Map<String, dynamic>>> getLocationHistory(String customerId) async => [];
}
