import '../../models/user_model.dart';
import '../../services/api_service.dart';
import '../profile_repository.dart';

class RemoteProfileRepository implements ProfileRepository {
  @override
  Future<UserModel?> login(String phoneNumber, String password) {
    return ApiService.login(phoneNumber, password);
  }

  @override
  Future<void> logout() {
    return ApiService.logout();
  }

  @override
  Future<UserModel?> getCurrentUser() {
    return ApiService.getCurrentUser();
  }

  @override
  Future<Map<String, int>> getMyStats() {
    return ApiService.getMyStats();
  }

  @override
  Future<List<Map<String, dynamic>>> getMyAreas() {
    return ApiService.getMyAreas();
  }

  @override
  Future<String?> getPreferredAreaId() {
    return ApiService.getPreferredAreaId();
  }

  @override
  Future<void> setPreferredAreaId(String areaId) {
    return ApiService.setPreferredAreaId(areaId);
  }

  @override
  Future<void> clearPreferredAreaId() {
    return ApiService.clearPreferredAreaId();
  }

  @override
  Future<Map<String, dynamic>> changePassword({
    required String currentPassword,
    required String newPassword,
    String? confirmPassword,
  }) {
    return ApiService.changePassword(
      currentPassword: currentPassword,
      newPassword: newPassword,
      confirmPassword: confirmPassword,
    );
  }

  @override
  Future<String?> getSavedLoginPhone() {
    return ApiService.getSavedLoginPhone();
  }
}
