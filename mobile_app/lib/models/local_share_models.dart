// Định nghĩa cấu trúc dữ liệu gói chia sẻ ngoại tuyến P2P (SharePackagePayload).
// Chứa danh sách điểm giao, mã băm bảo mật và metadata của gói chia sẻ.
import 'dart:typed_data';
import 'package:delivery_marker_mobile/models/customer_photo_model.dart';

class SharedPointPayload {
  final String phoneNumber, timestamp;
  final String? fullName, addressText, identificationNotes, senderName;
  final double latitude, longitude;
  final double? gpsAccuracy;
  final List<String> photoFileNames;

  const SharedPointPayload({
    required this.phoneNumber, this.fullName, this.addressText,
    required this.latitude, required this.longitude, this.gpsAccuracy,
    this.identificationNotes, this.photoFileNames = const [],
    this.senderName, required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'phone': phoneNumber, if (fullName?.isNotEmpty == true) 'name': fullName,
    if (addressText?.isNotEmpty == true) 'address': addressText,
    'lat': latitude, 'lng': longitude, if (gpsAccuracy != null) 'acc': gpsAccuracy,
    if (identificationNotes?.isNotEmpty == true) 'notes': identificationNotes,
    if (photoFileNames.isNotEmpty) 'photos': photoFileNames,
    if (senderName?.isNotEmpty == true) 'sender': senderName, 'ts': timestamp,
  };

  factory SharedPointPayload.fromJson(Map<String, dynamic> j) => SharedPointPayload(
    phoneNumber: j['phone']?.toString() ?? '', fullName: j['name']?.toString(),
    addressText: j['address']?.toString(),
    latitude: (j['lat'] as num?)?.toDouble() ?? 0.0, longitude: (j['lng'] as num?)?.toDouble() ?? 0.0,
    gpsAccuracy: (j['acc'] as num?)?.toDouble(), identificationNotes: j['notes']?.toString(),
    photoFileNames: (j['photos'] as List?)?.map((e) => e.toString()).toList() ?? [],
    senderName: j['sender']?.toString(), timestamp: j['ts']?.toString() ?? DateTime.now().toUtc().toIso8601String(),
  );
}

class SharePackageManifest {
  final int formatVersion, schemaVersion, pointsCount, photosCount;
  final String type, appVersion, createdAt, senderDisplayName;
  final bool isEncrypted;
  final String? salt, iv;
  final Map<String, String> checksums;

  const SharePackageManifest({
    this.formatVersion = 1, this.type = 'dshare', this.appVersion = '1.0.0+1',
    required this.schemaVersion, required this.createdAt, required this.senderDisplayName,
    required this.pointsCount, required this.photosCount, this.isEncrypted = false,
    this.salt, this.iv, required this.checksums,
  });

  Map<String, dynamic> toJson() => {
    'formatVersion': formatVersion, 'type': type, 'appVersion': appVersion,
    'schemaVersion': schemaVersion, 'createdAt': createdAt, 'senderDisplayName': senderDisplayName,
    'pointsCount': pointsCount, 'photosCount': photosCount, 'isEncrypted': isEncrypted,
    if (salt != null) 'salt': salt, if (iv != null) 'iv': iv, 'checksums': checksums,
  };

  factory SharePackageManifest.fromJson(Map<String, dynamic> j) {
    final raw = j['checksums'];
    final cs = raw is Map ? raw.map((k, v) => MapEntry(k.toString(), v.toString())) : <String, String>{};
    return SharePackageManifest(
      formatVersion: (j['formatVersion'] as num?)?.toInt() ?? 1, type: j['type']?.toString() ?? 'dshare',
      appVersion: j['appVersion']?.toString() ?? '1.0.0+1', schemaVersion: (j['schemaVersion'] as num?)?.toInt() ?? 1,
      createdAt: j['createdAt']?.toString() ?? '', senderDisplayName: j['senderDisplayName']?.toString() ?? 'Shipper',
      pointsCount: (j['pointsCount'] as num?)?.toInt() ?? 0, photosCount: (j['photosCount'] as num?)?.toInt() ?? 0,
      isEncrypted: j['isEncrypted'] == true, salt: j['salt']?.toString(), iv: j['iv']?.toString(), checksums: cs,
    );
  }
}

enum SharePointClassification { newCustomer, existingWithoutLocation, existingWithLocation, invalid }

class ClassifiedSharePoint {
  final SharedPointPayload point;
  final SharePointClassification classification;
  final String? existingCustomerId, existingCustomerName, existingAddress, invalidReason;
  final double? existingLatitude, existingLongitude, distanceMeters;
  bool isSelected;

  ClassifiedSharePoint({
    required this.point, required this.classification, this.existingCustomerId,
    this.existingCustomerName, this.existingAddress, this.existingLatitude,
    this.existingLongitude, this.distanceMeters, this.invalidReason, this.isSelected = true,
  });

  String get formattedDistance => distanceMeters == null ? '' : (distanceMeters! < 1000 ? '${distanceMeters!.round()} m' : '${(distanceMeters! / 1000).toStringAsFixed(1)} km');
}

class SharePackagePreview {
  final SharePackageManifest manifest;
  final List<ClassifiedSharePoint> classifiedPoints;
  final Map<String, Uint8List> photos;
  final String? filePath;
  final bool isFromQr;

  const SharePackagePreview({
    required this.manifest, required this.classifiedPoints,
    this.photos = const {}, this.filePath, this.isFromQr = false,
  });

  int get totalPoints => classifiedPoints.length;
  int get validPointsCount => classifiedPoints.where((p) => p.classification != SharePointClassification.invalid).length;
  int get newCount => classifiedPoints.where((p) => p.classification == SharePointClassification.newCustomer).length;
  int get existingWithoutLocCount => classifiedPoints.where((p) => p.classification == SharePointClassification.existingWithoutLocation).length;
  int get existingWithLocCount => classifiedPoints.where((p) => p.classification == SharePointClassification.existingWithLocation).length;
  int get invalidCount => classifiedPoints.where((p) => p.classification == SharePointClassification.invalid).length;
  int get selectedCount => classifiedPoints.where((p) => p.isSelected && p.classification != SharePointClassification.invalid).length;
}

enum ShareImportMode { addOnly, replaceExisting }

class ShareImportResult {
  final int addedCount, replacedCount, skippedCount, errorCount, photosAdded, photosSkipped;
  final String? createdShiftId, createdShiftName;
  final String message;

  const ShareImportResult({
    this.addedCount = 0, this.replacedCount = 0, this.skippedCount = 0, this.errorCount = 0,
    this.photosAdded = 0, this.photosSkipped = 0, this.createdShiftId, this.createdShiftName,
    required this.message,
  });
}

class SharedLocationPointModel {
  final String id, customerId, customerCode, customerName, customerPhone, customerAddress, areaId, areaName, identificationNotes, sharedByName, shareId;
  final double latitude, longitude, gpsAccuracy;
  final String? imageUrl;
  final int photoCount;
  final List<CustomerPhotoModel> photos;

  SharedLocationPointModel({
    required this.id, required this.customerId, required this.customerCode,
    required this.customerName, required this.customerPhone, required this.customerAddress,
    required this.areaId, required this.areaName, required this.latitude,
    required this.longitude, required this.gpsAccuracy, required this.identificationNotes,
    this.imageUrl, this.photoCount = 0, this.photos = const [],
    required this.sharedByName, required this.shareId,
  });

  factory SharedLocationPointModel.fromJson(Map<String, dynamic> j) {
    final rawPhotos = j['photos'] as List? ?? [];
    return SharedLocationPointModel(
      id: j['id']?.toString() ?? '', customerId: j['customerId']?.toString() ?? j['customer_id']?.toString() ?? '',
      customerCode: j['customerCode']?.toString() ?? j['customer_code']?.toString() ?? '',
      customerName: j['customerName']?.toString() ?? j['customer_name']?.toString() ?? '',
      customerPhone: j['customerPhone']?.toString() ?? j['customer_phone']?.toString() ?? '',
      customerAddress: j['customerAddress']?.toString() ?? j['customer_address']?.toString() ?? '',
      areaId: j['areaId']?.toString() ?? j['area_id']?.toString() ?? '',
      areaName: j['areaName']?.toString() ?? j['area_name']?.toString() ?? '',
      latitude: (j['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (j['longitude'] as num?)?.toDouble() ?? 0.0,
      gpsAccuracy: (j['gpsAccuracy'] as num?)?.toDouble() ?? (j['gps_accuracy'] as num?)?.toDouble() ?? 0.0,
      identificationNotes: j['identificationNotes']?.toString() ?? j['identification_notes']?.toString() ?? '',
      imageUrl: j['imageUrl']?.toString() ?? j['image_url']?.toString(),
      photoCount: (j['photoCount'] as num?)?.toInt() ?? (j['photo_count'] as num?)?.toInt() ?? 0,
      photos: rawPhotos.map((p) => CustomerPhotoModel.fromJson(p as Map<String, dynamic>, defaultCustomerId: j['customerId']?.toString() ?? '')).toList(),
      sharedByName: j['sharedByName']?.toString() ?? j['shared_by_name']?.toString() ?? 'Shipper',
      shareId: j['shareId']?.toString() ?? j['share_id']?.toString() ?? '',
    );
  }
}
