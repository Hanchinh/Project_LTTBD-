import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform, SocketException;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Lớp client HTTP cơ sở xử lý URL, xác thực Token, Headers và ngoại lệ mạng dùng chung.
class ApiClient {
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

  static Future<void> resetCustomBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('custom_api_base_url');
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

  static Future<String?> getSavedLoginPhone() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('saved_login_phone');
  }

  static Future<void> saveLoginPhone(String phone) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('saved_login_phone', phone);
  }

  static Future<String?> getLastActiveShiftId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('last_active_shift_id');
  }

  static Future<void> saveLastActiveShiftId(String shiftId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_active_shift_id', shiftId);
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

  /// Tạo Header cho request HTTP, kèm Authorization Bearer nếu có token
  static Future<Map<String, String>> getHeaders({bool requireAuth = true}) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (requireAuth) {
      final token = await getToken();
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }
    return headers;
  }

  /// Thực thi GET request với xử lý lỗi mạng chuẩn hoá
  static Future<dynamic> get(
    String endpoint, {
    Map<String, dynamic>? queryParams,
    bool requireAuth = true,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    try {
      final baseUrl = await getBaseUrl();
      var uri = Uri.parse('$baseUrl$endpoint');
      if (queryParams != null && queryParams.isNotEmpty) {
        final stringParams = queryParams.map((k, v) => MapEntry(k, v.toString()));
        uri = uri.replace(queryParameters: stringParams);
      }

      final headers = await getHeaders(requireAuth: requireAuth);
      final response = await http.get(uri, headers: headers).timeout(timeout);
      return _processResponse(response);
    } on http.ClientException {
      throw Exception('Mất kết nối mạng, vui lòng thử lại');
    } on SocketException {
      throw Exception('Không thể kết nối đến máy chủ');
    } on TimeoutException {
      throw Exception('Quá thời gian kết nối (Timeout), vui lòng thử lại');
    }
  }

  /// Thực thi POST request với xử lý lỗi mạng chuẩn hoá
  static Future<dynamic> post(
    String endpoint, {
    dynamic body,
    bool requireAuth = true,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    try {
      final baseUrl = await getBaseUrl();
      final uri = Uri.parse('$baseUrl$endpoint');
      final headers = await getHeaders(requireAuth: requireAuth);
      final response = await http
          .post(uri, headers: headers, body: body != null ? jsonEncode(body) : null)
          .timeout(timeout);
      return _processResponse(response);
    } on http.ClientException {
      throw Exception('Mất kết nối mạng, vui lòng thử lại');
    } on SocketException {
      throw Exception('Không thể kết nối đến máy chủ');
    } on TimeoutException {
      throw Exception('Quá thời gian kết nối (Timeout), vui lòng thử lại');
    }
  }

  /// Thực thi PUT request với xử lý lỗi mạng chuẩn hoá
  static Future<dynamic> put(
    String endpoint, {
    dynamic body,
    bool requireAuth = true,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    try {
      final baseUrl = await getBaseUrl();
      final uri = Uri.parse('$baseUrl$endpoint');
      final headers = await getHeaders(requireAuth: requireAuth);
      final response = await http
          .put(uri, headers: headers, body: body != null ? jsonEncode(body) : null)
          .timeout(timeout);
      return _processResponse(response);
    } on http.ClientException {
      throw Exception('Mất kết nối mạng, vui lòng thử lại');
    } on SocketException {
      throw Exception('Không thể kết nối đến máy chủ');
    } on TimeoutException {
      throw Exception('Quá thời gian kết nối (Timeout), vui lòng thử lại');
    }
  }

  /// Thực thi DELETE request với xử lý lỗi mạng chuẩn hoá
  static Future<dynamic> delete(
    String endpoint, {
    dynamic body,
    bool requireAuth = true,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    try {
      final baseUrl = await getBaseUrl();
      final uri = Uri.parse('$baseUrl$endpoint');
      final headers = await getHeaders(requireAuth: requireAuth);
      final response = await http
          .delete(uri, headers: headers, body: body != null ? jsonEncode(body) : null)
          .timeout(timeout);
      return _processResponse(response);
    } on http.ClientException {
      throw Exception('Mất kết nối mạng, vui lòng thử lại');
    } on SocketException {
      throw Exception('Không thể kết nối đến máy chủ');
    } on TimeoutException {
      throw Exception('Quá thời gian kết nối (Timeout), vui lòng thử lại');
    }
  }

  static dynamic _processResponse(http.Response response) {
    dynamic data;
    try {
      data = jsonDecode(response.body);
    } catch (_) {
      data = {'message': response.body};
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data;
    }

    final message = (data is Map && data['message'] != null)
        ? data['message']
        : 'Yêu cầu thất bại (Mã lỗi: ${response.statusCode})';
    throw Exception(message);
  }
}

