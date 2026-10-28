import 'package:delivery_marker_mobile/models/user_model.dart';
import 'package:delivery_marker_mobile/data/remote/api_client.dart';
import 'package:delivery_marker_mobile/data/remote/auth_api.dart';
import 'package:delivery_marker_mobile/data/repositories/profile_repository.dart';

class RemoteProfileRepository implements ProfileRepository {
  @override
  Future<UserModel?> login(String phoneNumber, String password) {
    return AuthApi.login(phoneNumber, password);
  }

  @override
  Future<void> logout() {
    return ApiClient.logout();
  }

  @override
  Future<UserModel?> getCurrentUser() {
    return AuthApi.getCurrentUser();
  }

  @override
  Future<Map<String, int>> getMyStats() {
    return AuthApi.getMyStats();
  }

  @override
  Future<List<Map<String, dynamic>>> getMyAreas() {
    return AuthApi.getMyAreas();
  }

  @override
  Future<String?> getPreferredAreaId() {
    return ApiClient.getPreferredAreaId();
  }

  @override
  Future<void> setPreferredAreaId(String areaId) {
    return ApiClient.setPreferredAreaId(areaId);
  }

  @override
  Future<void> clearPreferredAreaId() {
    return ApiClient.clearPreferredAreaId();
  }

  @override
  Future<Map<String, dynamic>> changePassword({
    required String currentPassword,
    required String newPassword,
    String? confirmPassword,
  }) {
    return AuthApi.changePassword(
      currentPassword: currentPassword,
      newPassword: newPassword,
      confirmPassword: confirmPassword,
    );
  }

  @override
  Future<String?> getSavedLoginPhone() {
    return ApiClient.getSavedLoginPhone();
  }
}
