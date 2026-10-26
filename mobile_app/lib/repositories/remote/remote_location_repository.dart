import '../../models/location_model.dart';
import '../../models/shift_model.dart';
import '../../services/api_service.dart';
import '../location_repository.dart';

class RemoteLocationRepository implements LocationRepository {
  @override
  Future<List<MasterSavedLocationModel>> getMySavedLocations() {
    return ApiService.getMySavedLocations();
  }

  @override
  Future<bool> saveCustomerLocation(
    SavedLocationModel location, {
    String? imageBase64,
  }) {
    return ApiService.saveCustomerLocation(
      location,
      imageBase64: imageBase64,
    );
  }

  @override
  Future<Map<String, dynamic>> updateCustomerLocationAndPhoto({
    required String customerId,
    required double latitude,
    required double longitude,
    double? gpsAccuracy,
    required String identificationNotes,
    String? imageBase64,
    bool? deletePhoto,
  }) {
    return ApiService.updateCustomerLocationAndPhoto(
      customerId: customerId,
      latitude: latitude,
      longitude: longitude,
      gpsAccuracy: gpsAccuracy,
      identificationNotes: identificationNotes,
      imageBase64: imageBase64,
      deletePhoto: deletePhoto,
    );
  }

  @override
  Future<void> deleteCustomerLocation(String customerId) {
    return ApiService.deleteCustomerLocation(customerId);
  }

  @override
  Future<ShiftDeliveryPointModel> updateTemporaryLocation(
    String shiftId,
    String pointId, {
    required double latitude,
    required double longitude,
    String? locationNotes,
    String? identificationNotes,
  }) {
    return ApiService.updateTemporaryLocation(
      shiftId,
      pointId,
      latitude: latitude,
      longitude: longitude,
      locationNotes: locationNotes,
      identificationNotes: identificationNotes,
    );
  }

  @override
  Future<int> getPendingSyncCount() {
    return ApiService.getPendingSyncCount();
  }

  @override
  Future<void> syncOfflineQueue() {
    return ApiService.syncOfflineQueue();
  }
}
