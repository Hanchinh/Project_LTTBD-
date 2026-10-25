import 'package:latlong2/latlong.dart';
import 'shift_model.dart';
import 'customer_photo_model.dart';

class CustomerDirectoryModel {
  final String id;
  final String customerCode;
  final String fullName;
  final String phoneNumber;
  final String addressText;
  final String? areaId;
  final String? areaName;
  final LocationStatus locationStatus;
  final bool hasLocation;
  final double? latitude;
  final double? longitude;
  final String? identificationNotes;
  final String? imageUrl;
  final int photoCount;
  final List<CustomerPhotoModel> photos;
  final String? savedLocationId;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final bool isExisting;

  CustomerDirectoryModel({
    required this.id,
    required this.customerCode,
    required this.fullName,
    required this.phoneNumber,
    required this.addressText,
    this.areaId,
    this.areaName,
    this.locationStatus = LocationStatus.noLocation,
    this.hasLocation = false,
    this.latitude,
    this.longitude,
    this.identificationNotes,
    this.imageUrl,
    this.photoCount = 0,
    this.photos = const [],
    this.savedLocationId,
    this.createdAt,
    this.updatedAt,
    this.isExisting = false,
  });

  bool get hasValidCoordinates => latitude != null && longitude != null;

  LatLng? get latLng => hasValidCoordinates ? LatLng(latitude!, longitude!) : null;

  bool get hasPhoto => photoCount > 0 || (imageUrl != null && imageUrl!.trim().isNotEmpty);

  factory CustomerDirectoryModel.fromJson(Map<String, dynamic> json) {
    double? parseCoord(dynamic value) {
      if (value == null) return null;
      if (value is num) return value.toDouble();
      return double.tryParse(value.toString());
    }

    List<CustomerPhotoModel> parsedPhotos = [];
    if (json['photos'] != null && json['photos'] is List) {
      parsedPhotos = (json['photos'] as List)
          .map((item) => CustomerPhotoModel.fromJson(item as Map<String, dynamic>, defaultCustomerId: json['id']?.toString()))
          .toList();
    }

    final pCount = json['photoCount'] is int
        ? json['photoCount'] as int
        : (int.tryParse(json['photoCount']?.toString() ?? '') ?? parsedPhotos.length);

    final rawImageUrl = json['imageUrl']?.toString() ?? (parsedPhotos.isNotEmpty ? parsedPhotos.first.imageUrl : null);

    return CustomerDirectoryModel(
      id: json['id']?.toString() ?? '',
      customerCode: json['customerCode']?.toString() ?? '',
      fullName: json['fullName']?.toString() ?? 'Khách hàng',
      phoneNumber: json['phoneNumber']?.toString() ?? '',
      addressText: json['addressText']?.toString() ?? 'Chưa có địa chỉ chi tiết',
      areaId: json['areaId']?.toString(),
      areaName: json['areaName']?.toString(),
      locationStatus: LocationStatus.fromString(json['locationStatus']?.toString()),
      hasLocation: json['hasLocation'] == true || (json['latitude'] != null && json['longitude'] != null),
      latitude: parseCoord(json['latitude']),
      longitude: parseCoord(json['longitude']),
      identificationNotes: json['identificationNotes']?.toString(),
      imageUrl: rawImageUrl,
      photoCount: pCount,
      photos: parsedPhotos,
      savedLocationId: json['savedLocationId']?.toString(),
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'].toString()) : null,
      updatedAt: json['updatedAt'] != null ? DateTime.tryParse(json['updatedAt'].toString()) : null,
      isExisting: json['isExisting'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'customerCode': customerCode,
      'fullName': fullName,
      'phoneNumber': phoneNumber,
      'addressText': addressText,
      'areaId': areaId,
      'areaName': areaName,
      'locationStatus': locationStatus.toApiString(),
      'hasLocation': hasLocation,
      'latitude': latitude,
      'longitude': longitude,
      'identificationNotes': identificationNotes,
      'imageUrl': imageUrl,
      'photoCount': photoCount,
      'photos': photos.map((p) => p.toJson()).toList(),
      'savedLocationId': savedLocationId,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'isExisting': isExisting,
    };
  }

  CustomerDirectoryModel copyWith({
    String? id,
    String? customerCode,
    String? fullName,
    String? phoneNumber,
    String? addressText,
    String? areaId,
    String? areaName,
    LocationStatus? locationStatus,
    bool? hasLocation,
    double? latitude,
    double? longitude,
    String? identificationNotes,
    String? imageUrl,
    int? photoCount,
    List<CustomerPhotoModel>? photos,
    String? savedLocationId,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isExisting,
  }) {
    return CustomerDirectoryModel(
      id: id ?? this.id,
      customerCode: customerCode ?? this.customerCode,
      fullName: fullName ?? this.fullName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      addressText: addressText ?? this.addressText,
      areaId: areaId ?? this.areaId,
      areaName: areaName ?? this.areaName,
      locationStatus: locationStatus ?? this.locationStatus,
      hasLocation: hasLocation ?? this.hasLocation,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      identificationNotes: identificationNotes ?? this.identificationNotes,
      imageUrl: imageUrl ?? this.imageUrl,
      photoCount: photoCount ?? this.photoCount,
      photos: photos ?? this.photos,
      savedLocationId: savedLocationId ?? this.savedLocationId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isExisting: isExisting ?? this.isExisting,
    );
  }
}
