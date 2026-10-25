import 'customer_photo_model.dart';

class SavedLocationModel {
  final String? id;
  final String customerId;
  final double latitude;
  final double longitude;
  final double gpsAccuracy;
  final String identificationNotes;
  final String? imageUrl;
  final String? updatedAt;

  SavedLocationModel({
    this.id,
    required this.customerId,
    required this.latitude,
    required this.longitude,
    required this.gpsAccuracy,
    required this.identificationNotes,
    this.imageUrl,
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
      imageUrl: json['imageUrl'],
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
      'imageUrl': imageUrl,
      'updatedAt': updatedAt,
    };
  }
}

/// Mô hình vị trí đã lưu của Shipper phục vụ Bản đồ chính (TASK: MASTER-MAP-014)
class MasterSavedLocationModel {
  final String id;
  final String customerId;
  final String customerCode;
  final String customerName;
  final String customerPhone;
  final String customerAddress;
  final String? areaId;
  final String? areaName;
  final double latitude;
  final double longitude;
  final double gpsAccuracy;
  final String identificationNotes;
  final String? imageUrl;
  final int photoCount;
  final List<CustomerPhotoModel> photos;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  MasterSavedLocationModel({
    required this.id,
    required this.customerId,
    required this.customerCode,
    required this.customerName,
    required this.customerPhone,
    required this.customerAddress,
    this.areaId,
    this.areaName,
    required this.latitude,
    required this.longitude,
    required this.gpsAccuracy,
    required this.identificationNotes,
    this.imageUrl,
    this.photoCount = 0,
    this.photos = const [],
    this.createdAt,
    this.updatedAt,
  });

  bool get hasValidCoordinates => latitude != 0.0 && longitude != 0.0;
  bool get hasPhoto => (photoCount > 0) || (imageUrl != null && imageUrl!.trim().isNotEmpty);

  MasterSavedLocationModel copyWith({
    String? id,
    String? customerId,
    String? customerCode,
    String? customerName,
    String? customerPhone,
    String? customerAddress,
    String? areaId,
    String? areaName,
    double? latitude,
    double? longitude,
    double? gpsAccuracy,
    String? identificationNotes,
    String? imageUrl,
    int? photoCount,
    List<CustomerPhotoModel>? photos,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MasterSavedLocationModel(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      customerCode: customerCode ?? this.customerCode,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      customerAddress: customerAddress ?? this.customerAddress,
      areaId: areaId ?? this.areaId,
      areaName: areaName ?? this.areaName,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      gpsAccuracy: gpsAccuracy ?? this.gpsAccuracy,
      identificationNotes: identificationNotes ?? this.identificationNotes,
      imageUrl: imageUrl ?? this.imageUrl,
      photoCount: photoCount ?? this.photoCount,
      photos: photos ?? this.photos,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory MasterSavedLocationModel.fromJson(Map<String, dynamic> json) {
    final custId = json['customerId']?.toString() ?? '';
    final rawPhotos = json['photos'];
    List<CustomerPhotoModel> parsedPhotos = [];
    if (rawPhotos is List) {
      parsedPhotos = rawPhotos
          .whereType<Map<String, dynamic>>()
          .map((p) => CustomerPhotoModel.fromJson(p, defaultCustomerId: custId))
          .toList();
    }

    final pCount = int.tryParse(json['photoCount']?.toString() ?? '') ?? parsedPhotos.length;
    final img = json['imageUrl']?.toString();

    return MasterSavedLocationModel(
      id: json['id']?.toString() ?? '',
      customerId: custId,
      customerCode: json['customerCode']?.toString() ?? '',
      customerName: json['customerName']?.toString() ?? 'Khách hàng',
      customerPhone: json['customerPhone']?.toString() ?? '',
      customerAddress: json['customerAddress']?.toString() ?? '',
      areaId: json['areaId']?.toString(),
      areaName: json['areaName']?.toString(),
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      gpsAccuracy: (json['gpsAccuracy'] as num?)?.toDouble() ?? 0.0,
      identificationNotes: json['identificationNotes']?.toString() ?? '',
      imageUrl: img,
      photoCount: pCount > 0 ? pCount : (img != null && img.isNotEmpty ? 1 : 0),
      photos: parsedPhotos,
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'].toString()) : null,
      updatedAt: json['updatedAt'] != null ? DateTime.tryParse(json['updatedAt'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'customerId': customerId,
      'customerCode': customerCode,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'customerAddress': customerAddress,
      'areaId': areaId,
      'areaName': areaName,
      'latitude': latitude,
      'longitude': longitude,
      'gpsAccuracy': gpsAccuracy,
      'identificationNotes': identificationNotes,
      'imageUrl': imageUrl,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }
}

