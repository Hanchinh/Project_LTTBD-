import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/user_model.dart';
import '../models/order_model.dart';
import '../models/location_model.dart';
import 'offline_storage_service.dart';

class ApiService {
  // Use 10.0.2.2 for Android Emulator, or localhost / LAN IP for physical device
  static const String baseUrl = 'http://10.0.2.2:3000/api/v1';

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt_token');
  }

  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('jwt_token', token);
  }

  static Future<UserModel?> login(String phoneNumber, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'phoneNumber': phoneNumber, 'password': password}),
    );

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      if (body['success'] == true) {
        final token = body['data']['token'];
        await saveToken(token);
        return UserModel.fromJson(body['data']['user'], token);
      }
    }
    throw Exception(jsonDecode(response.body)['message'] ?? 'Đăng nhập thất bại');
  }

  static Future<List<OrderModel>> getMyShiftOrders() async {
    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity == ConnectivityResult.none) {
      // Return cached orders if offline
      return await OfflineStorageService.getCachedOrders();
    }

    final token = await getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/orders/my-shift'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      final List list = body['data'];
      final orders = list.map((e) => OrderModel.fromJson(e)).toList();

      // Cache orders locally for offline access
      await OfflineStorageService.cacheOrders(orders);
      return orders;
    }
    throw Exception('Không thể lấy danh sách đơn hàng');
  }

  static Future<bool> saveCustomerLocation(SavedLocationModel location) async {
    final connectivity = await Connectivity().checkConnectivity();

    if (connectivity == ConnectivityResult.none) {
      // Save to local sync queue if offline
      await OfflineStorageService.addToSyncQueue(location);
      return true;
    }

    final token = await getToken();
    final response = await http.post(
      Uri.parse('$baseUrl/customers/${location.customerId}/location'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'latitude': location.latitude,
        'longitude': location.longitude,
        'gpsAccuracy': location.gpsAccuracy,
        'identificationNotes': location.identificationNotes,
      }),
    );

    if (response.statusCode == 200) {
      return true;
    } else {
      final err = jsonDecode(response.body);
      throw Exception(err['message'] ?? 'Không thể lưu vị trí');
    }
  }

  static Future<void> syncOfflineQueue() async {
    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity == ConnectivityResult.none) return;

    final queue = await OfflineStorageService.getSyncQueue();
    for (var item in queue) {
      try {
        final loc = SavedLocationModel(
          customerId: item['customerId'],
          latitude: item['latitude'],
          longitude: item['longitude'],
          gpsAccuracy: item['gpsAccuracy'],
          identificationNotes: item['identificationNotes'],
        );

        await saveCustomerLocation(loc);
        await OfflineStorageService.clearSyncQueueItem(item['id']);
      } catch (e) {
        print('Error syncing item ${item['id']}: $e');
      }
    }
  }

  static Future<void> openExternalNavigation(double lat, double lng) async {
    // Deep-link to Google Maps / Apple Maps
    final googleMapsUrl = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    if (await canLaunchUrl(googleMapsUrl)) {
      await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication);
    } else {
      throw Exception('Không thể mở ứng dụng bản đồ dẫn đường');
    }
  }
}
