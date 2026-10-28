import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:delivery_marker_mobile/models/location_model.dart';
import 'package:delivery_marker_mobile/data/remote/offline_storage_service.dart';
import 'package:delivery_marker_mobile/data/remote/api_client.dart';

/// Module API phụ trách định vị, lưu vị trí khách hàng, xem danh sách vị trí và mở bản đồ ngoài.
class LocationApi {
  static Future<bool> saveCustomerLocation(
    SavedLocationModel location, {
    String? imageBase64,
  }) async {
    final connectivity = await Connectivity().checkConnectivity();

    if (connectivity == ConnectivityResult.none) {
      await OfflineStorageService.addToSyncQueue(
        location: location,
        imageBase64: imageBase64,
      );
      return false;
    }

    try {
      final payload = <String, dynamic>{
        'latitude': location.latitude,
        'longitude': location.longitude,
        'gpsAccuracy': location.gpsAccuracy,
        'identificationNotes': location.identificationNotes,
        if (imageBase64 != null && imageBase64.isNotEmpty) 'imageBase64': imageBase64,
      };

      await ApiClient.post(
        '/customers/${location.customerId}/location',
        body: payload,
        timeout: const Duration(seconds: 15),
      );
      return true;
    } catch (_) {
      await OfflineStorageService.addToSyncQueue(
        location: location,
        imageBase64: imageBase64,
      );
      return false;
    }
  }

  static Future<Map<String, dynamic>> updateCustomerLocationAndPhoto({
    required String customerId,
    required double latitude,
    required double longitude,
    double? gpsAccuracy,
    required String identificationNotes,
    String? imageBase64,
    bool? deletePhoto,
  }) async {
    final payload = <String, dynamic>{
      'latitude': latitude,
      'longitude': longitude,
      'gpsAccuracy': gpsAccuracy ?? 0.0,
      'identificationNotes': identificationNotes.trim(),
      if (imageBase64 != null) 'imageBase64': imageBase64,
      if (deletePhoto == true) 'deletePhoto': true,
    };

    final response = await ApiClient.post(
      '/customers/$customerId/location',
      body: payload,
      timeout: const Duration(seconds: 20),
    );

    if (response is Map && response['success'] == true) {
      return response['data'] as Map<String, dynamic>;
    }
    throw Exception(response['message'] ?? 'Không thể cập nhật vị trí khách hàng');
  }

  static Future<void> deleteCustomerLocation(String customerId) async {
    final response = await ApiClient.delete(
      '/customers/$customerId/location',
      timeout: const Duration(seconds: 15),
    );

    if (response is Map && response['success'] == true) {
      return;
    }
    throw Exception(response['message'] ?? 'Không thể xóa vị trí đã lưu của khách hàng');
  }

  static Future<List<MasterSavedLocationModel>> getMySavedLocations() async {
    try {
      final response = await ApiClient.get(
        '/locations/my-saved-locations',
        timeout: const Duration(seconds: 15),
      );

      if (response is Map && response['success'] == true) {
        final List list = response['data'] as List? ?? [];
        return list.map((json) => MasterSavedLocationModel.fromJson(json)).toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  static Future<void> openExternalNavigation(double lat, double lng) async {
    final appUrl = Uri.parse('google.navigation:q=$lat,$lng&mode=d');
    final webUrl = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');

    try {
      if (await canLaunchUrl(appUrl)) {
        await launchUrl(appUrl);
      } else if (await canLaunchUrl(webUrl)) {
        await launchUrl(webUrl, mode: LaunchMode.externalApplication);
      } else {
        throw Exception('Không thể mở ứng dụng bản đồ trên thiết bị');
      }
    } catch (_) {
      await launchUrl(webUrl, mode: LaunchMode.externalApplication);
    }
  }
}

