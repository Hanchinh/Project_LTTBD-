import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/user_model.dart';
import '../models/order_model.dart';
import '../models/location_model.dart';
import 'offline_storage_service.dart';

class ApiService {
  static const String _defaultAndroidUrl = 'http://127.0.0.1:3000/api/v1';
  static const String _defaultIosUrl = 'http://localhost:3000/api/v1';

  static Future<String> getBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final customUrl = prefs.getString('custom_api_base_url');
    if (customUrl != null && customUrl.isNotEmpty) {
      return customUrl;
    }
    if (!kIsWeb && Platform.isAndroid) {
      return _defaultAndroidUrl;
    }
    return _defaultIosUrl;
  }

  static Future<void> setCustomBaseUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('custom_api_base_url', url);
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt_token');
  }

  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('jwt_token', token);
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
    await prefs.remove('user_profile');
  }

  static Future<Map<String, String>> getPhotoAuthInfo(String photoPath) async {
    final token = await getToken();
    final baseUrl = await getBaseUrl();

    String fullUrl;
    if (photoPath.startsWith('http://') || photoPath.startsWith('https://')) {
      fullUrl = photoPath;
    } else {
      final uri = Uri.parse(baseUrl);
      final origin =
          '${uri.scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}';
      final cleanPath = photoPath.startsWith('/') ? photoPath : '/$photoPath';
      fullUrl = '$origin$cleanPath';
    }

    return {
      'url': fullUrl,
      'token': token ?? '',
    };
  }

  static Future<UserModel?> login(String phoneNumber, String password) async {
    final baseUrl = await getBaseUrl();
    final url = Uri.parse('$baseUrl/auth/login');

    try {
      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(
                {'phoneNumber': phoneNumber.trim(), 'password': password}),
          )
          .timeout(const Duration(seconds: 10));

      final body = jsonDecode(response.body);

      if (response.statusCode == 200 && body['success'] == true) {
        final token = body['data']['token'];
        await saveToken(token);

        final user = UserModel.fromJson(body['data']['user'], token);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_profile', jsonEncode(user.toJson()));
        return user;
      }

      throw Exception(body['message'] ??
          'Đăng nhập thất bại (Mã lỗi ${response.statusCode})');
    } on http.ClientException catch (_) {
      throw Exception(
          'Không thể kết nối đến máy chủ. Vui lòng kiểm tra mạng hoặc địa chỉ máy chủ.');
    }
  }

  static Future<List<OrderModel>> getMyShiftOrders() async {
    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity == ConnectivityResult.none) {
      // Return cached orders when offline
      return await OfflineStorageService.getCachedOrders();
    }

    final token = await getToken();
    if (token == null) {
      throw Exception('Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.');
    }

    final baseUrl = await getBaseUrl();
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/orders/my-shift'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final List list = body['data'] ?? [];
        final orders = list.map((e) => OrderModel.fromJson(e)).toList();

        // Cache locally for offline availability
        await OfflineStorageService.cacheOrders(orders);
        return orders;
      }

      if (response.statusCode == 401) {
        await logout();
        throw Exception('Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.');
      }

      final body = jsonDecode(response.body);
      throw Exception(body['message'] ?? 'Không thể tải danh sách đơn hàng');
    } catch (e) {
      // Fallback to cached orders on network failure
      final cached = await OfflineStorageService.getCachedOrders();
      if (cached.isNotEmpty) {
        return cached;
      }
      rethrow;
    }
  }

  static Future<bool> saveCustomerLocation(
    SavedLocationModel location, {
    String? imageBase64,
  }) async {
    final connectivity = await Connectivity().checkConnectivity();

    if (connectivity == ConnectivityResult.none) {
      // Queue offline for later synchronization
      await OfflineStorageService.addToSyncQueue(
        location: location,
        imageBase64: imageBase64,
      );
      return false; // Stored offline, pending server sync
    }

    final token = await getToken();
    if (token == null) {
      throw Exception('Chưa xác thực đăng nhập');
    }

    final baseUrl = await getBaseUrl();
    try {
      final payload = <String, dynamic>{
        'latitude': location.latitude,
        'longitude': location.longitude,
        'gpsAccuracy': location.gpsAccuracy,
        'identificationNotes': location.identificationNotes,
      };

      if (imageBase64 != null && imageBase64.isNotEmpty) {
        payload['imageBase64'] = imageBase64;
      }

      final response = await http
          .post(
            Uri.parse('$baseUrl/customers/${location.customerId}/location'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return true; // Successfully saved to server
      }

      final err = jsonDecode(response.body);
      throw Exception(err['message'] ?? 'Lỗi lưu vị trí máy chủ');
    } catch (e) {
      // If server call fails due to timeout or network, queue offline
      await OfflineStorageService.addToSyncQueue(
        location: location,
        imageBase64: imageBase64,
      );
      return false;
    }
  }

  static Future<int> getPendingSyncCount() async {
    return await OfflineStorageService.getPendingCount();
  }

  static Future<void> syncOfflineQueue() async {
    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity == ConnectivityResult.none) return;

    final token = await getToken();
    if (token == null) return;

    final queue = await OfflineStorageService.getPendingSyncQueue();
    for (var item in queue) {
      try {
        final loc = SavedLocationModel(
          customerId: item['customerId'],
          latitude: (item['latitude'] as num).toDouble(),
          longitude: (item['longitude'] as num).toDouble(),
          gpsAccuracy: (item['gpsAccuracy'] as num).toDouble(),
          identificationNotes: item['identificationNotes'] ?? '',
          imageUrl: item['imageUrl'],
        );

        final baseUrl = await getBaseUrl();
        final payload = <String, dynamic>{
          'latitude': loc.latitude,
          'longitude': loc.longitude,
          'gpsAccuracy': loc.gpsAccuracy,
          'identificationNotes': loc.identificationNotes,
        };
        if (item['imageBase64'] != null) {
          payload['imageBase64'] = item['imageBase64'];
        }

        final response = await http.post(
          Uri.parse('$baseUrl/customers/${loc.customerId}/location'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode(payload),
        );

        if (response.statusCode == 200) {
          await OfflineStorageService.clearSyncQueueItem(item['id']);
        } else {
          await OfflineStorageService.incrementRetry(
              item['id'], item['retryCount'] ?? 0);
        }
      } catch (e) {
        await OfflineStorageService.incrementRetry(
            item['id'], item['retryCount'] ?? 0);
      }
    }
  }

  /// Tra cứu vị trí khách hàng bằng số điện thoại
  static Future<Map<String, dynamic>?> lookupCustomerLocationByPhone(
      String phoneNumber) async {
    final token = await getToken();
    if (token == null) {
      throw Exception('Phiên đăng nhập đã hết hạn');
    }

    final cleanPhone = phoneNumber.replaceAll(RegExp(r'\D'), '');
    final baseUrl = await getBaseUrl();
    final response = await http.get(
      Uri.parse('$baseUrl/customers/by-phone/$cleanPhone/location'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      return body['data'];
    } else if (response.statusCode == 404) {
      return null; // Khách hàng chưa có vị trí hoặc chưa đăng ký
    }

    final err = jsonDecode(response.body);
    throw Exception(err['message'] ?? 'Lỗi tra cứu vị trí');
  }

  static Future<void> openExternalNavigation(double lat, double lng) async {
    // Deep-link to Google Maps application with fallback to browser
    final appUrl = Uri.parse('google.navigation:q=$lat,$lng&mode=d');
    final webUrl =
        Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');

    try {
      if (await canLaunchUrl(appUrl)) {
        await launchUrl(appUrl);
      } else if (await canLaunchUrl(webUrl)) {
        await launchUrl(webUrl, mode: LaunchMode.externalApplication);
      } else {
        throw Exception('Không thể mở ứng dụng bản đồ trên thiết bị');
      }
    } catch (_) {
      // Fallback to web directly
      await launchUrl(webUrl, mode: LaunchMode.externalApplication);
    }
  }
}
