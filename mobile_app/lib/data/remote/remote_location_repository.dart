import 'package:delivery_marker_mobile/models/location_model.dart';
import 'package:delivery_marker_mobile/models/shift_model.dart';
import 'package:delivery_marker_mobile/data/remote/location_api.dart';
import 'package:delivery_marker_mobile/data/remote/shift_api.dart';
import 'package:delivery_marker_mobile/data/repositories/location_repository.dart';

class RemoteLocationRepository implements LocationRepository {
  @override
  Future<List<MasterSavedLocationModel>> getMySavedLocations() {
    return LocationApi.getMySavedLocations();
  }

  @override
  Future<bool> saveCustomerLocation(
    SavedLocationModel location, {
    String? imageBase64,
  }) {
    return LocationApi.saveCustomerLocation(
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
    return LocationApi.updateCustomerLocationAndPhoto(
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
    return LocationApi.deleteCustomerLocation(customerId);
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
    return ShiftApi.updateTemporaryLocation(
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
    return ShiftApi.getPendingSyncCount();
  }

  @override
  Future<void> syncOfflineQueue() {
    return ShiftApi.syncOfflineQueue();
  }

  @override
  Future<List<MasterSavedLocationModel>> getSavedLocationsInBounds({
    required double minLat,
    required double maxLat,
    required double minLng,
    required double maxLng,
  }) async {
    final all = await getMySavedLocations();
    return all.where((loc) =>
      loc.latitude >= minLat && loc.latitude <= maxLat &&
      loc.longitude >= minLng && loc.longitude <= maxLng
    ).toList();
  }

  @override
  Future<List<Map<String, dynamic>>> getLocationHistory(String customerId) async => [];
}
