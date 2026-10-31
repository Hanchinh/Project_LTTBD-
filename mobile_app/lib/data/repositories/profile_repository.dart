import 'package:delivery_marker_mobile/models/user_profile.dart';

abstract class ProfileRepository {
  Future<UserProfile?> getCurrentUser();

  Future<Map<String, int>> getMyStats();

  Future<List<Map<String, dynamic>>> getMyAreas();

  Future<String?> getPreferredAreaId();

  Future<void> setPreferredAreaId(String areaId);

  Future<void> clearPreferredAreaId();
}
