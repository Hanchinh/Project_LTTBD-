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
import '../models/shift_model.dart';
import '../models/customer_model.dart';
import '../models/customer_photo_model.dart';
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

  static Future<String?> getLastActiveShiftId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('last_active_shift_id');
  }

  static Future<void> saveLastActiveShiftId(String shiftId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_active_shift_id', shiftId);
  }

  static Future<UserModel?> getCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userStr = prefs.getString('user_profile');
    final token = await getToken();
    if (userStr != null && token != null) {
      try {
        final json = jsonDecode(userStr);
        return UserModel.fromJson(json, token);
      } catch (_) {}
    }
    return null;
  }

  static Future<List<Map<String, dynamic>>> getMyAreas() async {
    final token = await getToken();
    final baseUrl = await getBaseUrl();
    final url = Uri.parse('$baseUrl/areas/my-areas');
    try {
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      final body = jsonDecode(response.body);
      if (response.statusCode == 200 && body['success'] == true) {
        return List<Map<String, dynamic>>.from(body['data']);
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  static Future<String?> getPreferredAreaId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('preferred_customer_area_id');
  }

  static Future<void> setPreferredAreaId(String areaId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('preferred_customer_area_id', areaId);
  }

  static Future<void> clearPreferredAreaId() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('preferred_customer_area_id');
  }

  static Future<Map<String, String>> getPhotoAuthInfo(String photoPath, {int? cacheVersion, bool bustCache = false}) async {
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

    if (cacheVersion != null) {
      fullUrl += fullUrl.contains('?') ? '&v=$cacheVersion' : '?v=$cacheVersion';
    } else if (bustCache) {
      final now = DateTime.now().millisecondsSinceEpoch;
      fullUrl += fullUrl.contains('?') ? '&v=$now' : '?v=$now';
    }

    if (token != null && token.isNotEmpty) {
      fullUrl += fullUrl.contains('?')
          ? '&token=${Uri.encodeComponent(token)}'
          : '?token=${Uri.encodeComponent(token)}';
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
    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity == ConnectivityResult.none) {
      throw Exception(
          'Không có kết nối mạng. Bác tài vui lòng kiểm tra kết nối WiFi/4G.');
    }

    final token = await getToken();
    if (token == null) {
      throw Exception('Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.');
    }

    final cleanPhone = phoneNumber.replaceAll(RegExp(r'\D'), '');
    final baseUrl = await getBaseUrl();
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/customers/by-phone/$cleanPhone/location'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        return body['data'];
      } else if (response.statusCode == 404) {
        return null; // Khách hàng chưa đăng ký trong hệ thống
      }

      final err = jsonDecode(response.body);
      throw Exception(err['message'] ?? 'Lỗi tra cứu vị trí');
    } on http.ClientException catch (_) {
      throw Exception('Không thể kết nối đến máy chủ. Vui lòng thử lại.');
    }
  }

  /// Thêm đơn hàng mới (điểm giao mới) vào ca của shipper
  static Future<Map<String, dynamic>> addOrderToShift({
    required String customerId,
    bool allowMultiple = false,
    String? idempotencyKey,
  }) async {
    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity == ConnectivityResult.none) {
      throw Exception(
          'Không có kết nối mạng. Bác tài vui lòng kiểm tra kết nối WiFi/4G.');
    }

    final token = await getToken();
    if (token == null) {
      throw Exception('Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.');
    }

    final baseUrl = await getBaseUrl();
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/orders/my-shift'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'customerId': customerId,
              'allowMultiple': allowMultiple,
              if (idempotencyKey != null) 'idempotencyKey': idempotencyKey,
            }),
          )
          .timeout(const Duration(seconds: 12));

      final body = jsonDecode(response.body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        return {
          'isExisting': body['isExisting'] ?? false,
          'message': body['message'] ?? 'Thành công',
          'order': OrderModel.fromJson(body['data']),
        };
      }

      throw Exception(body['message'] ?? 'Không thể thêm điểm giao vào ca');
    } on http.ClientException catch (_) {
      throw Exception('Không thể kết nối đến máy chủ. Vui lòng thử lại.');
    }
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

  // ==========================================
  // QUẢN LÝ CA LÀM VIỆC (SHIFTS & DELIVERY POINTS)
  // ==========================================

  /// Lấy danh sách ca làm việc của shipper
  static Future<List<ShiftModel>> getShifts() async {
    final token = await getToken();
    if (token == null) {
      throw Exception('Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.');
    }

    final baseUrl = await getBaseUrl();
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/shifts'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 12));

      final body = jsonDecode(response.body);
      if (response.statusCode == 200 && body['success'] == true) {
        final List list = body['data'] ?? [];
        return list.map((item) => ShiftModel.fromJson(item as Map<String, dynamic>)).toList();
      }

      throw Exception(body['message'] ?? 'Không thể tải danh sách ca làm');
    } on http.ClientException catch (_) {
      throw Exception('Không thể kết nối đến máy chủ. Vui lòng thử lại.');
    }
  }

  /// Tạo ca làm việc mới
  static Future<ShiftModel> createShift({String? shiftDate, String? shiftName, String? notes}) async {
    final token = await getToken();
    if (token == null) {
      throw Exception('Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.');
    }

    final baseUrl = await getBaseUrl();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/shifts'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          if (shiftDate != null) ...{
            'shiftDate': shiftDate,
            'workDate': shiftDate,
          },
          if (shiftName != null && shiftName.trim().isNotEmpty) 'shiftName': shiftName.trim(),
          if (notes != null) 'notes': notes,
        }),
      ).timeout(const Duration(seconds: 12));

      final body = jsonDecode(response.body);
      if (response.statusCode == 201 && body['success'] == true) {
        return ShiftModel.fromJson(body['data']);
      }

      throw Exception(body['message'] ?? 'Không thể tạo ca làm mới');
    } on http.ClientException catch (_) {
      throw Exception('Không thể kết nối đến máy chủ. Vui lòng thử lại.');
    }
  }

  /// Đổi tên ca làm việc (TASK: SHIFT-FROM-MAP-AND-BULK-PASTE-015B)
  static Future<ShiftModel> updateShiftName(String shiftId, String shiftName) async {
    final token = await getToken();
    if (token == null) {
      throw Exception('Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.');
    }

    final baseUrl = await getBaseUrl();
    try {
      final response = await http.patch(
        Uri.parse('$baseUrl/shifts/$shiftId/name'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'shiftName': shiftName.trim(),
        }),
      ).timeout(const Duration(seconds: 12));

      final body = jsonDecode(response.body);
      if (response.statusCode == 200 && body['success'] == true) {
        return ShiftModel.fromJson(body['data']);
      }

      throw Exception(body['message'] ?? 'Không thể đổi tên ca làm việc');
    } on http.ClientException catch (_) {
      throw Exception('Không thể kết nối đến máy chủ. Vui lòng thử lại.');
    }
  }

  /// Thêm hàng loạt số điện thoại vào ca (TASK: SHIFT-FROM-MAP-AND-BULK-PASTE-015B)
  static Future<BulkAddPointsResult> addBulkPointsToShift({
    required String shiftId,
    String? rawText,
    List<String>? phones,
    String? areaId,
  }) async {
    final token = await getToken();
    if (token == null) {
      throw Exception('Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.');
    }

    final baseUrl = await getBaseUrl();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/shifts/$shiftId/points/bulk'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          if (rawText != null) 'rawText': rawText,
          if (phones != null) 'phones': phones,
          if (areaId != null) 'areaId': areaId,
        }),
      ).timeout(const Duration(seconds: 25));

      final body = jsonDecode(response.body);
      if (response.statusCode == 200 && body['success'] == true) {
        return BulkAddPointsResult.fromJson(body['data']);
      }

      throw Exception(body['message'] ?? 'Không thể thêm danh sách SĐT vào ca');
    } on http.ClientException catch (_) {
      throw Exception('Không thể kết nối đến máy chủ. Vui lòng kiểm tra mạng.');
    }
  }

  /// Xóa ca làm việc và các điểm giao của ca
  static Future<bool> deleteShift(String shiftId) async {
    final token = await getToken();
    if (token == null) {
      throw Exception('Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.');
    }

    final baseUrl = await getBaseUrl();
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/shifts/$shiftId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 12));

      final body = jsonDecode(response.body);
      if (response.statusCode == 200 && body['success'] == true) {
        return true;
      }

      throw Exception(body['message'] ?? 'Không thể xóa ca làm việc');
    } on http.ClientException catch (_) {
      throw Exception('Không thể kết nối đến máy chủ. Vui lòng thử lại.');
    }
  }

  /// Lấy chi tiết ca làm việc (kèm danh sách điểm giao và thống kê)
  static Future<ShiftModel> getShiftDetail(String shiftId) async {
    final token = await getToken();
    if (token == null) {
      throw Exception('Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.');
    }

    final baseUrl = await getBaseUrl();
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/shifts/$shiftId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 12));

      final body = jsonDecode(response.body);
      if (response.statusCode == 200 && body['success'] == true) {
        return ShiftModel.fromJson(body['data']);
      }

      throw Exception(body['message'] ?? 'Không thể tải chi tiết ca làm');
    } on http.ClientException catch (_) {
      throw Exception('Không thể kết nối đến máy chủ. Vui lòng thử lại.');
    }
  }

  /// Cập nhật trạng thái ca làm việc (PREPARING -> IN_PROGRESS -> COMPLETED)
  static Future<ShiftModel> updateShiftStatus(String shiftId, ShiftStatus status) async {
    final token = await getToken();
    if (token == null) {
      throw Exception('Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.');
    }

    final baseUrl = await getBaseUrl();
    try {
      final response = await http.patch(
        Uri.parse('$baseUrl/shifts/$shiftId/status'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'status': status.toApiString(),
        }),
      ).timeout(const Duration(seconds: 12));

      final body = jsonDecode(response.body);
      if (response.statusCode == 200 && body['success'] == true) {
        return ShiftModel.fromJson(body['data']);
      }

      throw Exception(body['message'] ?? 'Không thể cập nhật trạng thái ca làm');
    } on http.ClientException catch (_) {
      throw Exception('Không thể kết nối đến máy chủ. Vui lòng thử lại.');
    }
  }

  /// Thêm điểm giao vào ca làm (hỗ trợ cả customerId hoặc SĐT kèm cờ tạo mới)
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
  }) async {
    final token = await getToken();
    if (token == null) {
      throw Exception('Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.');
    }

    final baseUrl = await getBaseUrl();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/shifts/$shiftId/points'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          if (customerId != null) 'customerId': customerId,
          if (phoneNumber != null) 'phoneNumber': phoneNumber,
          if (createIfNotFound) 'createIfNotFound': true,
          if (fullName != null && fullName.isNotEmpty) 'fullName': fullName,
          if (addressText != null && addressText.isNotEmpty) 'addressText': addressText,
          if (orderId != null) 'orderId': orderId,
          if (sequenceNumber != null) 'sequenceNumber': sequenceNumber,
          if (deliveryNotes != null) 'deliveryNotes': deliveryNotes,
          if (areaId != null) 'areaId': areaId,
        }),
      ).timeout(const Duration(seconds: 12));

      final body = jsonDecode(response.body);
      if ((response.statusCode == 200 || response.statusCode == 201) && body['success'] == true) {
        return {
          'isExisting': body['isExisting'] ?? false,
          'message': body['message'] ?? 'Thành công',
          'point': ShiftDeliveryPointModel.fromJson(body['data']),
          'summary': ShiftSummaryModel.fromJson(body['summary'] as Map<String, dynamic>?),
        };
      }

      throw Exception(body['message'] ?? 'Không thể thêm điểm giao vào ca');
    } on http.ClientException catch (_) {
      throw Exception('Không thể kết nối đến máy chủ. Vui lòng thử lại.');
    }
  }

  /// Tạo nhanh khách hàng mới và tự động thêm vào ca làm (Giai đoạn B)
  static Future<Map<String, dynamic>> quickCreateCustomerAndAddToShift({
    required String shiftId,
    required String phoneNumber,
    String? fullName,
    String? addressText,
    String? deliveryNotes,
    String? areaId,
  }) async {
    return addPointToShift(
      shiftId,
      phoneNumber: phoneNumber,
      createIfNotFound: true,
      fullName: fullName,
      addressText: addressText,
      deliveryNotes: deliveryNotes,
      areaId: areaId,
    );
  }

  /// Tra cứu địa chỉ sang tọa độ WGS84 qua API Geocoding (Giai đoạn C)
  static Future<List<AddressSearchResult>> searchAddress(String query) async {
    if (query.trim().length < 2) return [];

    final token = await getToken();
    if (token == null) {
      throw Exception('Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.');
    }

    final baseUrl = await getBaseUrl();
    try {
      final encodedQuery = Uri.encodeComponent(query.trim());
      final response = await http.get(
        Uri.parse('$baseUrl/geocoding/search?q=$encodedQuery'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 8));

      final body = jsonDecode(response.body);
      if (response.statusCode == 200 && body['success'] == true) {
        final List list = body['data'] ?? [];
        return list.map((item) => AddressSearchResult.fromJson(item as Map<String, dynamic>)).toList();
      }

      throw Exception(body['message'] ?? 'Không thể tìm kiếm địa chỉ');
    } on http.ClientException catch (_) {
      throw Exception('Lỗi kết nối máy chủ khi tìm kiếm địa chỉ');
    }
  }

  /// Xóa điểm giao khỏi ca làm
  static Future<void> removePointFromShift(String shiftId, String pointId) async {
    final token = await getToken();
    if (token == null) {
      throw Exception('Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.');
    }

    final baseUrl = await getBaseUrl();
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/shifts/$shiftId/points/$pointId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 12));

      final body = jsonDecode(response.body);
      if (response.statusCode == 200 && body['success'] == true) {
        return;
      }

      throw Exception(body['message'] ?? 'Không thể xóa điểm giao');
    } on http.ClientException catch (_) {
      throw Exception('Không thể kết nối đến máy chủ. Vui lòng thử lại.');
    }
  }

  /// Cập nhật vị trí tạm (TEMPORARY) từ bộ chọn tâm ngắm
  static Future<ShiftDeliveryPointModel> updateTemporaryLocation(
    String shiftId,
    String pointId, {
    required double latitude,
    required double longitude,
    String? locationNotes,
    String? identificationNotes,
  }) async {
    final token = await getToken();
    if (token == null) {
      throw Exception('Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.');
    }

    final notes = locationNotes ?? identificationNotes;

    final baseUrl = await getBaseUrl();
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/shifts/$shiftId/points/$pointId/temporary-location'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'latitude': latitude,
          'longitude': longitude,
          if (notes != null) ...{
            'locationNotes': notes,
            'identificationNotes': notes,
          },
        }),
      ).timeout(const Duration(seconds: 12));

      final body = jsonDecode(response.body);
      if (response.statusCode == 200 && body['success'] == true) {
        return ShiftDeliveryPointModel.fromJson(body['data']);
      }

      throw Exception(body['message'] ?? 'Không thể lưu vị trí tạm');
    } on http.ClientException catch (_) {
      throw Exception('Không thể kết nối đến máy chủ. Vui lòng thử lại.');
    }
  }



  // =========================================================================
  // CUSTOMER DIRECTORY API (MAP-FIRST-ARCHITECTURE-005)
  // =========================================================================

  /// 1. Lấy danh sách khách hàng & vị trí độc lập từ danh bạ (kèm thống kê tab và phân trang)
  static Future<CustomerDirectoryResponse> getCustomersResponse({
    String? query,
    String? status,
    bool? hasPhoto,
    int? limit,
    int? offset,
  }) async {
    final token = await getToken();
    final baseUrl = await getBaseUrl();

    final queryParams = <String, String>{};
    if (query != null && query.trim().isNotEmpty) {
      queryParams['q'] = query.trim();
    }
    if (status != null && status != 'ALL') {
      queryParams['status'] = status;
    }
    if (hasPhoto != null) {
      queryParams['hasPhoto'] = hasPhoto ? 'true' : 'false';
    }
    if (limit != null) {
      queryParams['limit'] = limit.toString();
    }
    if (offset != null) {
      queryParams['offset'] = offset.toString();
    }

    final uri = Uri.parse('$baseUrl/customers').replace(
      queryParameters: queryParams.isNotEmpty ? queryParams : null,
    );

    try {
      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 12));

      final body = jsonDecode(response.body);
      if (response.statusCode == 200 && body['success'] == true) {
        final List data = body['data'] as List? ?? [];
        final items = data.map((json) => CustomerDirectoryModel.fromJson(json)).toList();
        final counts = CustomerTabCounts.fromJson(body['counts'] as Map<String, dynamic>?);
        final pagination = CustomerPagination.fromJson(body['pagination'] as Map<String, dynamic>?);
        return CustomerDirectoryResponse(
          items: items,
          counts: counts,
          pagination: pagination,
        );
      }

      throw Exception(body['message'] ?? 'Không thể tải danh bạ khách hàng');
    } on http.ClientException catch (_) {
      throw Exception('Không thể kết nối đến máy chủ. Vui lòng kiểm tra mạng.');
    }
  }

  /// Tương thích ngược: Lấy danh sách items khách hàng
  static Future<List<CustomerDirectoryModel>> getCustomers({
    String? query,
    String? status,
    bool? hasPhoto,
    int? limit,
    int? offset,
  }) async {
    final res = await getCustomersResponse(
      query: query,
      status: status,
      hasPhoto: hasPhoto,
      limit: limit,
      offset: offset,
    );
    return res.items;
  }

  /// 2. Lấy chi tiết khách hàng và vị trí từ danh bạ
  static Future<CustomerDirectoryModel> getCustomerDetail(String customerId) async {
    final token = await getToken();
    final baseUrl = await getBaseUrl();
    final url = Uri.parse('$baseUrl/customers/$customerId');

    try {
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      final body = jsonDecode(response.body);
      if (response.statusCode == 200 && body['success'] == true) {
        final cust = body['data']['customer'];
        final loc = body['data']['savedLocation'];
        final statusStr = body['data']['locationStatus']?.toString() ??
            (loc != null ? (loc['status']?.toString() ?? 'VERIFIED') : 'NO_LOCATION');
        LocationStatus status;
        if (statusStr == 'VERIFIED') {
          status = LocationStatus.verified;
        } else if (statusStr == 'TEMPORARY') {
          status = LocationStatus.temporary;
        } else {
          status = LocationStatus.noLocation;
        }

        return CustomerDirectoryModel(
          id: cust['id'],
          customerCode: cust['customerCode'] ?? '',
          fullName: cust['fullName'] ?? '',
          phoneNumber: cust['phoneNumber'] ?? '',
          addressText: cust['addressText'] ?? '',
          areaId: cust['areaId'],
          areaName: cust['areaName'],
          locationStatus: status,
          hasLocation: loc != null && loc['latitude'] != null && loc['longitude'] != null,
          latitude: loc != null ? (loc['latitude'] as num?)?.toDouble() : null,
          longitude: loc != null ? (loc['longitude'] as num?)?.toDouble() : null,
          identificationNotes: loc?['identificationNotes'],
          imageUrl: loc?['imageUrl'],
          savedLocationId: loc?['id'],
          createdAt: cust['createdAt'] != null ? DateTime.tryParse(cust['createdAt']) : null,
          updatedAt: cust['updatedAt'] != null ? DateTime.tryParse(cust['updatedAt']) : null,
        );
      }

      throw Exception(body['message'] ?? 'Không thể lấy thông tin chi tiết khách hàng');
    } on http.ClientException catch (_) {
      throw Exception('Không thể kết nối đến máy chủ.');
    }
  }

  /// 3. Tạo mới khách hàng trực tiếp từ Danh bạ
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
  }) async {
    final token = await getToken();
    final baseUrl = await getBaseUrl();
    final url = Uri.parse('$baseUrl/customers');

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'phoneNumber': phoneNumber.trim(),
          if (fullName != null) 'fullName': fullName.trim(),
          if (addressText != null) 'addressText': addressText.trim(),
          if (areaId != null) 'areaId': areaId,
          if (latitude != null) 'latitude': latitude,
          if (longitude != null) 'longitude': longitude,
          if (gpsAccuracy != null) 'gpsAccuracy': gpsAccuracy,
          if (identificationNotes != null) 'identificationNotes': identificationNotes.trim(),
          if (imageBase64 != null) 'imageBase64': imageBase64,
        }),
      ).timeout(const Duration(seconds: 15));

      final body = jsonDecode(response.body);
      if ((response.statusCode == 201 || response.statusCode == 200) && body['success'] == true) {
        final cust = CustomerDirectoryModel.fromJson(body['data']);
        return cust.copyWith(
          isExisting: body['isExisting'] == true,
        );
      }

      throw Exception(body['message'] ?? 'Không thể tạo hồ sơ khách hàng mới');
    } on http.ClientException catch (_) {
      throw Exception('Không thể kết nối đến máy chủ.');
    }
  }

  /// 4. Cập nhật thông tin khách hàng (Tên, SĐT, Địa chỉ)
  static Future<Map<String, dynamic>> updateCustomer({
    required String customerId,
    required String fullName,
    required String phoneNumber,
    String? addressText,
  }) async {
    final token = await getToken();
    final baseUrl = await getBaseUrl();
    final url = Uri.parse('$baseUrl/customers/$customerId');

    try {
      final response = await http.put(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'fullName': fullName.trim(),
          'phoneNumber': phoneNumber.trim(),
          if (addressText != null) 'addressText': addressText.trim(),
        }),
      ).timeout(const Duration(seconds: 10));

      final body = jsonDecode(response.body);
      if (response.statusCode == 200 && body['success'] == true) {
        return body['data'] as Map<String, dynamic>;
      }

      throw Exception(body['message'] ?? 'Không thể cập nhật khách hàng');
    } on http.ClientException catch (_) {
      throw Exception('Không thể kết nối đến máy chủ.');
    }
  }

  /// 5. Cập nhật vị trí, ghi chú và quản lý ảnh (thêm, thay, xóa) của khách hàng
  static Future<Map<String, dynamic>> updateCustomerLocationAndPhoto({
    required String customerId,
    required double latitude,
    required double longitude,
    double? gpsAccuracy,
    required String identificationNotes,
    String? imageBase64,
    bool? deletePhoto,
  }) async {
    final token = await getToken();
    final baseUrl = await getBaseUrl();
    final url = Uri.parse('$baseUrl/customers/$customerId/location');

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'latitude': latitude,
          'longitude': longitude,
          'gpsAccuracy': gpsAccuracy ?? 0.0,
          'identificationNotes': identificationNotes.trim(),
          if (imageBase64 != null) 'imageBase64': imageBase64,
          if (deletePhoto == true) 'deletePhoto': true,
        }),
      ).timeout(const Duration(seconds: 20));

      final body = jsonDecode(response.body);
      if (response.statusCode == 200 && body['success'] == true) {
        return body['data'] as Map<String, dynamic>;
      }

      throw Exception(body['message'] ?? 'Không thể cập nhật vị trí khách hàng');
    } on http.ClientException catch (_) {
      throw Exception('Không thể kết nối đến máy chủ.');
    }
  }

  /// Shipper / Admin xóa vị trí đã lưu của khách hàng
  static Future<void> deleteCustomerLocation(String customerId) async {
    final token = await getToken();
    final baseUrl = await getBaseUrl();
    final url = Uri.parse('$baseUrl/customers/$customerId/location');

    try {
      final response = await http.delete(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 15));

      final body = jsonDecode(response.body);
      if (response.statusCode == 200 && body['success'] == true) {
        return;
      }

      throw Exception(body['message'] ?? 'Không thể xóa vị trí đã lưu của khách hàng');
    } on http.ClientException catch (_) {
      throw Exception('Không thể kết nối đến máy chủ.');
    }
  }

  /// Lấy toàn bộ danh sách vị trí đã lưu của shipper đăng nhập (TASK: MASTER-MAP-014)
  static Future<List<MasterSavedLocationModel>> getMySavedLocations() async {
    final token = await getToken();
    final baseUrl = await getBaseUrl();
    final url = Uri.parse('$baseUrl/locations/my-saved-locations');

    try {
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 15));

      final body = jsonDecode(response.body);
      if (response.statusCode == 200 && body['success'] == true) {
        final List list = body['data'] as List? ?? [];
        return list.map((item) => MasterSavedLocationModel.fromJson(item as Map<String, dynamic>)).toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  /// Lấy danh sách ảnh của khách hàng (TASK: MULTI-PHOTO-AND-THUMB-UI-015A)
  static Future<List<CustomerPhotoModel>> getCustomerPhotos(String customerId) async {
    final token = await getToken();
    final baseUrl = await getBaseUrl();
    final url = Uri.parse('$baseUrl/customers/$customerId/photos');

    try {
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 15));

      final body = jsonDecode(response.body);
      if (response.statusCode == 200 && body['success'] == true) {
        final List list = body['data'] as List? ?? [];
        return list
            .map((item) => CustomerPhotoModel.fromJson(item as Map<String, dynamic>, defaultCustomerId: customerId))
            .toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  /// Tải lên 1 ảnh mới cho khách hàng (imageBase64)
  static Future<CustomerPhotoModel> addCustomerPhoto(String customerId, String imageBase64) async {
    final token = await getToken();
    final baseUrl = await getBaseUrl();
    final url = Uri.parse('$baseUrl/customers/$customerId/photos');

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'imageBase64': imageBase64}),
      ).timeout(const Duration(seconds: 30));

      final body = jsonDecode(response.body);
      if (response.statusCode == 201 && body['success'] == true) {
        return CustomerPhotoModel.fromJson(body['data'] as Map<String, dynamic>, defaultCustomerId: customerId);
      }
      throw Exception(body['message'] ?? 'Không thể tải ảnh lên');
    } on http.ClientException {
      throw Exception('Mất kết nối mạng, không thể tải ảnh');
    }
  }

  /// Xóa mềm 1 ảnh của khách hàng
  static Future<void> deleteCustomerPhoto(String customerId, String photoId) async {
    final token = await getToken();
    final baseUrl = await getBaseUrl();
    final url = Uri.parse('$baseUrl/customers/$customerId/photos/$photoId');

    try {
      final response = await http.delete(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 15));

      final body = jsonDecode(response.body);
      if (response.statusCode == 200 && body['success'] == true) {
        return;
      }
      throw Exception(body['message'] ?? 'Không thể xóa ảnh');
    } on http.ClientException {
      throw Exception('Mất kết nối mạng, không thể xóa ảnh');
    }
  }
}

/// Mô hình kết quả tìm kiếm địa chỉ (Geocoding Result)
class AddressSearchResult {
  final String displayName;
  final double latitude;
  final double longitude;
  final String? source;

  AddressSearchResult({
    required this.displayName,
    required this.latitude,
    required this.longitude,
    this.source,
  });

  factory AddressSearchResult.fromJson(Map<String, dynamic> json) {
    return AddressSearchResult(
      displayName: json['displayName'] as String? ?? '',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      source: json['source'] as String?,
    );
  }
}
