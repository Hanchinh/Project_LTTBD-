/// Thông tin hồ sơ người dùng cục bộ (Local-First)
class UserProfile {
  final String id;
  final String fullName;
  final String? phoneNumber;
  final String role;

  const UserProfile({
    this.id = 'local_user',
    required this.fullName,
    this.phoneNumber = '',
    this.role = 'LOCAL',
  });
}

