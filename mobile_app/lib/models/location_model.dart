import 'package:delivery_marker_mobile/models/customer_photo_model.dart';

class SavedLocationModel {
  final String? id, imageUrl, updatedAt;
  final String customerId, identificationNotes;
  final double latitude, longitude, gpsAccuracy;

  SavedLocationModel({
    this.id, required this.customerId, required this.latitude,
    required this.longitude, required this.gpsAccuracy,
    required this.identificationNotes, this.imageUrl, this.updatedAt,
  });

  factory SavedLocationModel.fromJson(Map<String, dynamic> j, String customerId) => SavedLocationModel(
    id: j['id'], customerId: customerId,
    latitude: (j['latitude'] as num).toDouble(), longitude: (j['longitude'] as num).toDouble(),
    gpsAccuracy: (j['gpsAccuracy'] as num).toDouble(), identificationNotes: j['identificationNotes'] ?? '',
    imageUrl: j['imageUrl'], updatedAt: j['updatedAt'],
  );

  Map<String, dynamic> toJson() => {
    'id': id, 'customerId': customerId, 'latitude': latitude, 'longitude': longitude,
    'gpsAccuracy': gpsAccuracy, 'identificationNotes': identificationNotes,
    'imageUrl': imageUrl, 'updatedAt': updatedAt,
  };
}

class MasterSavedLocationModel {
  final String id, customerId, customerCode, customerName, customerPhone, customerAddress, identificationNotes;
  final String? areaId, areaName, imageUrl;
  final double latitude, longitude, gpsAccuracy;
  final int photoCount;
  final List<CustomerPhotoModel> photos;
  final DateTime? createdAt, updatedAt;

  MasterSavedLocationModel({
    required this.id, required this.customerId, required this.customerCode,
    required this.customerName, required this.customerPhone, required this.customerAddress,
    this.areaId, this.areaName, required this.latitude, required this.longitude,
    required this.gpsAccuracy, required this.identificationNotes, this.imageUrl,
    this.photoCount = 0, this.photos = const [], this.createdAt, this.updatedAt,
  });

  bool get hasValidCoordinates => latitude != 0.0 && longitude != 0.0;
  bool get hasPhoto => (photoCount > 0) || (imageUrl != null && imageUrl!.trim().isNotEmpty);

  MasterSavedLocationModel copyWith({
    String? id, customerId, customerCode, customerName, customerPhone, customerAddress,
    areaId, areaName, identificationNotes, imageUrl,
    double? latitude, longitude, gpsAccuracy, int? photoCount,
    List<CustomerPhotoModel>? photos, DateTime? createdAt, updatedAt,
  }) => MasterSavedLocationModel(
    id: id ?? this.id, customerId: customerId ?? this.customerId,
    customerCode: customerCode ?? this.customerCode, customerName: customerName ?? this.customerName,
    customerPhone: customerPhone ?? this.customerPhone, customerAddress: customerAddress ?? this.customerAddress,
    areaId: areaId ?? this.areaId, areaName: areaName ?? this.areaName,
    latitude: latitude ?? this.latitude, longitude: longitude ?? this.longitude,
    gpsAccuracy: gpsAccuracy ?? this.gpsAccuracy,
    identificationNotes: identificationNotes ?? this.identificationNotes,
    imageUrl: imageUrl ?? this.imageUrl, photoCount: photoCount ?? this.photoCount,
    photos: photos ?? this.photos, createdAt: createdAt ?? this.createdAt, updatedAt: updatedAt ?? this.updatedAt,
  );

  factory MasterSavedLocationModel.fromJson(Map<String, dynamic> j) {
    final custId = j['customerId']?.toString() ?? '';
    final rawPhotos = j['photos'];
    final photos = rawPhotos is List ? rawPhotos.whereType<Map<String, dynamic>>().map((p) => CustomerPhotoModel.fromJson(p, defaultCustomerId: custId)).toList() : <CustomerPhotoModel>[];
    final pCount = int.tryParse(j['photoCount']?.toString() ?? '') ?? photos.length;
    final img = j['imageUrl']?.toString();

    return MasterSavedLocationModel(
      id: j['id']?.toString() ?? '', customerId: custId,
      customerCode: j['customerCode']?.toString() ?? '', customerName: j['customerName']?.toString() ?? 'Khách hàng',
      customerPhone: j['customerPhone']?.toString() ?? '', customerAddress: j['customerAddress']?.toString() ?? '',
      areaId: j['areaId']?.toString(), areaName: j['areaName']?.toString(),
      latitude: (j['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (j['longitude'] as num?)?.toDouble() ?? 0.0,
      gpsAccuracy: (j['gpsAccuracy'] as num?)?.toDouble() ?? 0.0,
      identificationNotes: j['identificationNotes']?.toString() ?? '', imageUrl: img,
      photoCount: pCount > 0 ? pCount : (img != null && img.isNotEmpty ? 1 : 0),
      photos: photos,
      createdAt: j['createdAt'] != null ? DateTime.tryParse(j['createdAt'].toString()) : null,
      updatedAt: j['updatedAt'] != null ? DateTime.tryParse(j['updatedAt'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id, 'customerId': customerId, 'customerCode': customerCode,
    'customerName': customerName, 'customerPhone': customerPhone,
    'customerAddress': customerAddress, 'areaId': areaId, 'areaName': areaName,
    'latitude': latitude, 'longitude': longitude, 'gpsAccuracy': gpsAccuracy,
    'identificationNotes': identificationNotes, 'imageUrl': imageUrl,
    'createdAt': createdAt?.toIso8601String(), 'updatedAt': updatedAt?.toIso8601String(),
  };
}
