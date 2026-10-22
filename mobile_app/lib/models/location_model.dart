class SavedLocationModel {
  final String? id;
  final String customerId;
  final double latitude;
  final double longitude;
  final double gpsAccuracy;
  final String identificationNotes;
  final String? updatedAt;

  SavedLocationModel({
    this.id,
    required this.customerId,
    required this.latitude,
    required this.longitude,
    required this.gpsAccuracy,
    required this.identificationNotes,
    this.updatedAt,
  });

  factory SavedLocationModel.fromJson(Map<String, dynamic> json, String customerId) {
    return SavedLocationModel(
      id: json['id'],
      customerId: customerId,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      gpsAccuracy: (json['gpsAccuracy'] as num).toDouble(),
      identificationNotes: json['identificationNotes'] ?? '',
      updatedAt: json['updatedAt'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'customerId': customerId,
      'latitude': latitude,
      'longitude': longitude,
      'gpsAccuracy': gpsAccuracy,
      'identificationNotes': identificationNotes,
      'updatedAt': updatedAt,
    };
  }
}
