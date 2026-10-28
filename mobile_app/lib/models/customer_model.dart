import 'package:latlong2/latlong.dart';
import 'package:delivery_marker_mobile/models/shift_model.dart';
import 'package:delivery_marker_mobile/models/customer_photo_model.dart';

class CustomerDirectoryModel {
  final String id, customerCode, fullName, phoneNumber, addressText;
  final String? areaId, areaName, identificationNotes, imageUrl, firstThumbnailUrl, savedLocationId;
  final LocationStatus locationStatus, locationState;
  final bool hasLocation, isExisting;
  final double? latitude, longitude;
  final int photoCount;
  final List<CustomerPhotoModel> photos;
  final DateTime? createdAt, updatedAt;

  CustomerDirectoryModel({
    required this.id, required this.customerCode, required this.fullName,
    required this.phoneNumber, required this.addressText, this.areaId, this.areaName,
    this.locationStatus = LocationStatus.noLocation, LocationStatus? locationState,
    this.hasLocation = false, this.latitude, this.longitude, this.identificationNotes,
    this.imageUrl, this.firstThumbnailUrl, this.photoCount = 0, this.photos = const [],
    this.savedLocationId, this.createdAt, this.updatedAt, this.isExisting = false,
  }) : locationState = locationState ?? locationStatus;

  bool get hasValidCoordinates => latitude != null && longitude != null;
  LatLng? get latLng => hasValidCoordinates ? LatLng(latitude!, longitude!) : null;
  bool get hasPhoto => photoCount > 0 || (imageUrl != null && imageUrl!.trim().isNotEmpty) || (firstThumbnailUrl != null && firstThumbnailUrl!.trim().isNotEmpty);
  String get effectivePhotoUrl => firstThumbnailUrl ?? imageUrl ?? (photos.isNotEmpty ? photos.first.imageUrl : '');

  String get formattedPhoneNumber {
    final c = phoneNumber.replaceAll(RegExp(r'\D'), '');
    if (c.length == 10 && c.startsWith('0')) return '${c.substring(0, 4)} ${c.substring(4, 7)} ${c.substring(7)}';
    if (c.length == 11 && c.startsWith('84')) { final vn = '0${c.substring(2)}'; return '${vn.substring(0, 4)} ${vn.substring(4, 7)} ${vn.substring(7)}'; }
    return phoneNumber;
  }

  factory CustomerDirectoryModel.fromJson(Map<String, dynamic> j) {
    double? parseCoord(dynamic v) => v == null ? null : (v is num ? v.toDouble() : double.tryParse(v.toString()));
    final rawPhotos = j['photos'];
    final photos = rawPhotos is List ? rawPhotos.whereType<Map<String, dynamic>>().map((i) => CustomerPhotoModel.fromJson(i, defaultCustomerId: j['id']?.toString())).toList() : <CustomerPhotoModel>[];
    final pCount = j['photoCount'] is int ? j['photoCount'] as int : (int.tryParse(j['photoCount']?.toString() ?? '') ?? photos.length);
    final rawImg = j['imageUrl']?.toString() ?? (photos.isNotEmpty ? photos.first.imageUrl : null);
    final locStatus = LocationStatus.fromString(j['locationStatus']?.toString());

    return CustomerDirectoryModel(
      id: j['id']?.toString() ?? '', customerCode: j['customerCode']?.toString() ?? '',
      fullName: j['fullName']?.toString() ?? 'Khách hàng', phoneNumber: j['phoneNumber']?.toString() ?? '',
      addressText: j['addressText']?.toString() ?? 'Chưa có địa chỉ chi tiết',
      areaId: j['areaId']?.toString(), areaName: j['areaName']?.toString(),
      locationStatus: locStatus,
      locationState: j['locationState'] != null ? LocationStatus.fromString(j['locationState']?.toString()) : locStatus,
      hasLocation: j['hasLocation'] == true || (j['latitude'] != null && j['longitude'] != null),
      latitude: parseCoord(j['latitude']), longitude: parseCoord(j['longitude']),
      identificationNotes: j['identificationNotes']?.toString(), imageUrl: rawImg,
      firstThumbnailUrl: j['firstThumbnailUrl']?.toString() ?? rawImg,
      photoCount: pCount, photos: photos, savedLocationId: j['savedLocationId']?.toString(),
      createdAt: j['createdAt'] != null ? DateTime.tryParse(j['createdAt'].toString()) : null,
      updatedAt: j['updatedAt'] != null ? DateTime.tryParse(j['updatedAt'].toString()) : null,
      isExisting: j['isExisting'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id, 'customerCode': customerCode, 'fullName': fullName, 'phoneNumber': phoneNumber,
    'addressText': addressText, 'areaId': areaId, 'areaName': areaName,
    'locationStatus': locationStatus.toApiString(), 'locationState': locationState.toApiString(),
    'hasLocation': hasLocation, 'latitude': latitude, 'longitude': longitude,
    'identificationNotes': identificationNotes, 'imageUrl': imageUrl,
    'firstThumbnailUrl': firstThumbnailUrl, 'photoCount': photoCount,
    'photos': photos.map((p) => p.toJson()).toList(), 'savedLocationId': savedLocationId,
    'createdAt': createdAt?.toIso8601String(), 'updatedAt': updatedAt?.toIso8601String(), 'isExisting': isExisting,
  };

  CustomerDirectoryModel copyWith({
    String? id, customerCode, fullName, phoneNumber, addressText, areaId, areaName,
    identificationNotes, imageUrl, firstThumbnailUrl, savedLocationId,
    LocationStatus? locationStatus, locationState, bool? hasLocation, isExisting,
    double? latitude, longitude, int? photoCount, List<CustomerPhotoModel>? photos,
    DateTime? createdAt, updatedAt,
  }) => CustomerDirectoryModel(
    id: id ?? this.id, customerCode: customerCode ?? this.customerCode,
    fullName: fullName ?? this.fullName, phoneNumber: phoneNumber ?? this.phoneNumber,
    addressText: addressText ?? this.addressText, areaId: areaId ?? this.areaId,
    areaName: areaName ?? this.areaName, locationStatus: locationStatus ?? this.locationStatus,
    locationState: locationState ?? this.locationState, hasLocation: hasLocation ?? this.hasLocation,
    latitude: latitude ?? this.latitude, longitude: longitude ?? this.longitude,
    identificationNotes: identificationNotes ?? this.identificationNotes,
    imageUrl: imageUrl ?? this.imageUrl, firstThumbnailUrl: firstThumbnailUrl ?? this.firstThumbnailUrl,
    photoCount: photoCount ?? this.photoCount, photos: photos ?? this.photos,
    savedLocationId: savedLocationId ?? this.savedLocationId,
    createdAt: createdAt ?? this.createdAt, updatedAt: updatedAt ?? this.updatedAt,
    isExisting: isExisting ?? this.isExisting,
  );
}

class CustomerTabCounts {
  final int total, verified, temporary, noLocation;
  const CustomerTabCounts({this.total = 0, this.verified = 0, this.temporary = 0, this.noLocation = 0});
  factory CustomerTabCounts.fromJson(Map<String, dynamic>? j) => CustomerTabCounts(
    total: (j?['total'] as num?)?.toInt() ?? 0, verified: (j?['verified'] as num?)?.toInt() ?? 0,
    temporary: (j?['temporary'] as num?)?.toInt() ?? 0, noLocation: (j?['noLocation'] as num?)?.toInt() ?? 0,
  );
}

class CustomerPagination {
  final int total, limit, offset;
  final bool hasMore;
  const CustomerPagination({this.total = 0, this.limit = 30, this.offset = 0, this.hasMore = false});
  factory CustomerPagination.fromJson(Map<String, dynamic>? j) => CustomerPagination(
    total: (j?['total'] as num?)?.toInt() ?? 0, limit: (j?['limit'] as num?)?.toInt() ?? 30,
    offset: (j?['offset'] as num?)?.toInt() ?? 0, hasMore: j?['hasMore'] == true,
  );
}

class CustomerDirectoryResponse {
  final List<CustomerDirectoryModel> items;
  final CustomerTabCounts counts;
  final CustomerPagination pagination;
  const CustomerDirectoryResponse({this.items = const [], this.counts = const CustomerTabCounts(), this.pagination = const CustomerPagination()});
}

class BulkCustomerItem {
  final String id, customerCode, phoneNumber, fullName, addressText;
  final String? areaId;
  final LocationStatus locationState;
  BulkCustomerItem({required this.id, required this.customerCode, required this.phoneNumber, required this.fullName, required this.addressText, this.areaId, this.locationState = LocationStatus.noLocation});
  factory BulkCustomerItem.fromJson(Map<String, dynamic> j) => BulkCustomerItem(
    id: j['id']?.toString() ?? '', customerCode: j['customerCode']?.toString() ?? '',
    phoneNumber: j['phoneNumber']?.toString() ?? j['phone']?.toString() ?? '',
    fullName: j['fullName']?.toString() ?? j['name']?.toString() ?? '',
    addressText: j['addressText']?.toString() ?? j['address']?.toString() ?? '',
    areaId: j['areaId']?.toString(), locationState: LocationStatus.fromString(j['locationState']?.toString()),
  );
}

class BulkCreateCustomersResult {
  final List<BulkCustomerItem> created, alreadyExists;
  final List<RejectedPhoneItem> rejected;
  final int total, createdCount, alreadyExistsCount, rejectedCount;
  BulkCreateCustomersResult({required this.created, required this.alreadyExists, required this.rejected, required this.total, required this.createdCount, required this.alreadyExistsCount, required this.rejectedCount});
  factory BulkCreateCustomersResult.fromJson(Map<String, dynamic> j) {
    final c = (j['created'] as List? ?? []).whereType<Map<String, dynamic>>().map(BulkCustomerItem.fromJson).toList();
    final a = (j['alreadyExists'] as List? ?? []).whereType<Map<String, dynamic>>().map(BulkCustomerItem.fromJson).toList();
    final r = (j['rejected'] as List? ?? []).whereType<Map<String, dynamic>>().map(RejectedPhoneItem.fromJson).toList();
    final s = j['summary'] as Map<String, dynamic>? ?? {};
    return BulkCreateCustomersResult(
      created: c, alreadyExists: a, rejected: r,
      total: int.tryParse(s['total']?.toString() ?? '') ?? (c.length + a.length + r.length),
      createdCount: int.tryParse(s['createdCount']?.toString() ?? '') ?? c.length,
      alreadyExistsCount: int.tryParse(s['alreadyExistsCount']?.toString() ?? '') ?? a.length,
      rejectedCount: int.tryParse(s['rejectedCount']?.toString() ?? '') ?? r.length,
    );
  }
}
