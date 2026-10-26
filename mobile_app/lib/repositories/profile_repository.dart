import '../models/user_model.dart';

abstract class ProfileRepository {
  Future<UserModel?> login(String phoneNumber, String password);

  Future<void> logout();

  Future<UserModel?> getCurrentUser();

  Future<Map<String, int>> getMyStats();

  Future<List<Map<String, dynamic>>> getMyAreas();

  Future<String?> getPreferredAreaId();

  Future<void> setPreferredAreaId(String areaId);

  Future<void> clearPreferredAreaId();

  Future<Map<String, dynamic>> changePassword({
    required String currentPassword,
    required String newPassword,
    String? confirmPassword,
  });

  Future<String?> getSavedLoginPhone();
}
