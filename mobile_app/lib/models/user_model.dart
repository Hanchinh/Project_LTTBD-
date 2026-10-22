class UserModel {
  final String id;
  final String fullName;
  final String phoneNumber;
  final String role;
  final List<String> assignedAreaIds;
  final String token;

  UserModel({
    required this.id,
    required this.fullName,
    required this.phoneNumber,
    required this.role,
    required this.assignedAreaIds,
    required this.token,
  });

  factory UserModel.fromJson(Map<String, dynamic> json, String token) {
    return UserModel(
      id: json['id'],
      fullName: json['fullName'],
      phoneNumber: json['phoneNumber'],
      role: json['role'],
      assignedAreaIds: List<String>.from(json['assignedAreaIds'] ?? []),
      token: token,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fullName': fullName,
      'phoneNumber': phoneNumber,
      'role': role,
      'assignedAreaIds': assignedAreaIds,
      'token': token,
    };
  }
}
