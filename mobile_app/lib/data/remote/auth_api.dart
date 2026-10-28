import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:delivery_marker_mobile/models/user_model.dart';
import 'package:delivery_marker_mobile/data/remote/api_client.dart';

/// Module API phụ trách xác thực, tài khoản người dùng, thống kê và đổi mật khẩu.
class AuthApi {
  static Future<UserModel?> login(String phoneNumber, String password) async {
    final response = await ApiClient.post(
      '/auth/login',
      body: {
        'phoneNumber': phoneNumber.trim(),
        'password': password,
      },
      requireAuth: false,
      timeout: const Duration(seconds: 10),
    );

    if (response is Map && response['success'] == true) {
      final token = response['data']['token'];
      await ApiClient.saveToken(token);
      await ApiClient.saveLoginPhone(phoneNumber.trim());

      final user = UserModel.fromJson(response['data']['user'], token);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_profile', jsonEncode(user.toJson()));
      return user;
    }

    throw Exception(response['message'] ?? 'Đăng nhập thất bại');
  }

  static Future<UserModel?> getCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userStr = prefs.getString('user_profile');
    final token = await ApiClient.getToken();
    if (userStr != null && token != null) {
      try {
        final json = jsonDecode(userStr);
        return UserModel.fromJson(json, token);
      } catch (_) {}
    }
    return null;
  }

  static Future<List<Map<String, dynamic>>> getMyAreas() async {
    try {
      final response = await ApiClient.get(
        '/areas/my-areas',
        timeout: const Duration(seconds: 10),
      );
      if (response is Map && response['success'] == true) {
        return List<Map<String, dynamic>>.from(response['data'] ?? []);
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  static Future<Map<String, int>> getMyStats() async {
    try {
      final response = await ApiClient.get(
        '/auth/me/stats',
        timeout: const Duration(seconds: 10),
      );
      if (response is Map && response['success'] == true) {
        final data = response['data'] as Map<String, dynamic>;
        return {
          'savedLocationsCount': (data['savedLocationsCount'] as num?)?.toInt() ?? 0,
          'createdShiftsCount': (data['createdShiftsCount'] as num?)?.toInt() ?? 0,
          'uploadedPhotosCount': (data['uploadedPhotosCount'] as num?)?.toInt() ?? 0,
        };
      }
    } catch (_) {}
    return {
      'savedLocationsCount': 0,
      'createdShiftsCount': 0,
      'uploadedPhotosCount': 0,
    };
  }

  static Future<Map<String, dynamic>> changePassword({
    required String currentPassword,
    required String newPassword,
    String? confirmPassword,
  }) async {
    final response = await ApiClient.post(
      '/auth/change-password',
      body: {
        'currentPassword': currentPassword,
        'newPassword': newPassword,
        'confirmPassword': confirmPassword ?? newPassword,
      },
      timeout: const Duration(seconds: 10),
    );

    if (response is Map && response['success'] == true) {
      return {
        'success': true,
        'message': response['message'] ?? 'Đổi mật khẩu thành công!',
      };
    }
    throw Exception(response['message'] ?? 'Đổi mật khẩu thất bại');
  }
}

