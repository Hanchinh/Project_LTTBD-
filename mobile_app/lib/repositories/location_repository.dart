import '../models/location_model.dart';
import '../models/shift_model.dart';

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
}
