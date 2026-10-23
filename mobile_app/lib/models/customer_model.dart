import 'package:latlong2/latlong.dart';
import 'shift_model.dart';

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
  final String? savedLocationId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

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
    this.savedLocationId,
    this.createdAt,
    this.updatedAt,
  });

  bool get hasValidCoordinates => latitude != null && longitude != null;

  LatLng? get latLng => hasValidCoordinates ? LatLng(latitude!, longitude!) : null;

  bool get hasPhoto => imageUrl != null && imageUrl!.trim().isNotEmpty;

  factory CustomerDirectoryModel.fromJson(Map<String, dynamic> json) {
    double? parseCoord(dynamic value) {
      if (value == null) return null;
      if (value is num) return value.toDouble();
      return double.tryParse(value.toString());
    }

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
      imageUrl: json['imageUrl']?.toString(),
      savedLocationId: json['savedLocationId']?.toString(),
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'].toString()) : null,
      updatedAt: json['updatedAt'] != null ? DateTime.tryParse(json['updatedAt'].toString()) : null,
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
      'savedLocationId': savedLocationId,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
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
    String? savedLocationId,
    DateTime? createdAt,
    DateTime? updatedAt,
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
      savedLocationId: savedLocationId ?? this.savedLocationId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
