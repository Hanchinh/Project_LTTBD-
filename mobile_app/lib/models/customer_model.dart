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
  final LocationStatus locationState;
  final bool hasLocation;
  final double? latitude;
  final double? longitude;
  final String? identificationNotes;
  final String? imageUrl;
  final String? firstThumbnailUrl;
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
    LocationStatus? locationState,
    this.hasLocation = false,
    this.latitude,
    this.longitude,
    this.identificationNotes,
    this.imageUrl,
    this.firstThumbnailUrl,
    this.photoCount = 0,
    this.photos = const [],
    this.savedLocationId,
    this.createdAt,
    this.updatedAt,
    this.isExisting = false,
  }) : locationState = locationState ?? locationStatus;

  bool get hasValidCoordinates => latitude != null && longitude != null;

  LatLng? get latLng => hasValidCoordinates ? LatLng(latitude!, longitude!) : null;

  bool get hasPhoto => photoCount > 0 || (imageUrl != null && imageUrl!.trim().isNotEmpty) || (firstThumbnailUrl != null && firstThumbnailUrl!.trim().isNotEmpty);

  String get effectivePhotoUrl => firstThumbnailUrl ?? imageUrl ?? (photos.isNotEmpty ? photos.first.imageUrl : '');

  /// Định dạng số điện thoại chuẩn Việt Nam: ví dụ "0908 333 166" hoặc "090 833 3166"
  String get formattedPhoneNumber {
    final clean = phoneNumber.replaceAll(RegExp(r'\D'), '');
    if (clean.length == 10 && clean.startsWith('0')) {
      // 0908 333 166
      return '${clean.substring(0, 4)} ${clean.substring(4, 7)} ${clean.substring(7)}';
    } else if (clean.length == 11 && clean.startsWith('84')) {
      final vn = '0${clean.substring(2)}';
      return '${vn.substring(0, 4)} ${vn.substring(4, 7)} ${vn.substring(7)}';
    }
    return phoneNumber;
  }

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
    final rawFirstThumb = json['firstThumbnailUrl']?.toString() ?? rawImageUrl;

    final locStatus = LocationStatus.fromString(json['locationStatus']?.toString());
    final locState = json['locationState'] != null
        ? LocationStatus.fromString(json['locationState']?.toString())
        : locStatus;

    return CustomerDirectoryModel(
      id: json['id']?.toString() ?? '',
      customerCode: json['customerCode']?.toString() ?? '',
      fullName: json['fullName']?.toString() ?? 'Khách hàng',
      phoneNumber: json['phoneNumber']?.toString() ?? '',
      addressText: json['addressText']?.toString() ?? 'Chưa có địa chỉ chi tiết',
      areaId: json['areaId']?.toString(),
      areaName: json['areaName']?.toString(),
      locationStatus: locStatus,
      locationState: locState,
      hasLocation: json['hasLocation'] == true || (json['latitude'] != null && json['longitude'] != null),
      latitude: parseCoord(json['latitude']),
      longitude: parseCoord(json['longitude']),
      identificationNotes: json['identificationNotes']?.toString(),
      imageUrl: rawImageUrl,
      firstThumbnailUrl: rawFirstThumb,
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
      'locationState': locationState.toApiString(),
      'hasLocation': hasLocation,
      'latitude': latitude,
      'longitude': longitude,
      'identificationNotes': identificationNotes,
      'imageUrl': imageUrl,
      'firstThumbnailUrl': firstThumbnailUrl,
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
    LocationStatus? locationState,
    bool? hasLocation,
    double? latitude,
    double? longitude,
    String? identificationNotes,
    String? imageUrl,
    String? firstThumbnailUrl,
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
      locationState: locationState ?? this.locationState,
      hasLocation: hasLocation ?? this.hasLocation,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      identificationNotes: identificationNotes ?? this.identificationNotes,
      imageUrl: imageUrl ?? this.imageUrl,
      firstThumbnailUrl: firstThumbnailUrl ?? this.firstThumbnailUrl,
      photoCount: photoCount ?? this.photoCount,
      photos: photos ?? this.photos,
      savedLocationId: savedLocationId ?? this.savedLocationId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isExisting: isExisting ?? this.isExisting,
    );
  }
}

class CustomerTabCounts {
  final int total;
  final int verified;
  final int temporary;
  final int noLocation;

  const CustomerTabCounts({
    this.total = 0,
    this.verified = 0,
    this.temporary = 0,
    this.noLocation = 0,
  });

  factory CustomerTabCounts.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const CustomerTabCounts();
    return CustomerTabCounts(
      total: (json['total'] as num?)?.toInt() ?? 0,
      verified: (json['verified'] as num?)?.toInt() ?? 0,
      temporary: (json['temporary'] as num?)?.toInt() ?? 0,
      noLocation: (json['noLocation'] as num?)?.toInt() ?? 0,
    );
  }
}

class CustomerPagination {
  final int total;
  final int limit;
  final int offset;
  final bool hasMore;

  const CustomerPagination({
    this.total = 0,
    this.limit = 30,
    this.offset = 0,
    this.hasMore = false,
  });

  factory CustomerPagination.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const CustomerPagination();
    return CustomerPagination(
      total: (json['total'] as num?)?.toInt() ?? 0,
      limit: (json['limit'] as num?)?.toInt() ?? 30,
      offset: (json['offset'] as num?)?.toInt() ?? 0,
      hasMore: json['hasMore'] == true,
    );
  }
}

class CustomerDirectoryResponse {
  final List<CustomerDirectoryModel> items;
  final CustomerTabCounts counts;
  final CustomerPagination pagination;

  const CustomerDirectoryResponse({
    this.items = const [],
    this.counts = const CustomerTabCounts(),
    this.pagination = const CustomerPagination(),
  });
}
