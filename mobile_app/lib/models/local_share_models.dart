import 'dart:typed_data';

/// Mô hình một điểm chia sẻ được xuất/nhập (Clean PII: không ID nội bộ, không activity_log, không lịch sử)
class SharedPointPayload {
  final String phoneNumber;
  final String? fullName;
  final String? addressText;
  final double latitude;
  final double longitude;
  final double? gpsAccuracy;
  final String? identificationNotes;
  final List<String> photoFileNames;
  final String? senderName;
  final String timestamp;

  const SharedPointPayload({
    required this.phoneNumber,
    this.fullName,
    this.addressText,
    required this.latitude,
    required this.longitude,
    this.gpsAccuracy,
    this.identificationNotes,
    this.photoFileNames = const [],
    this.senderName,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'phone': phoneNumber,
        if (fullName != null && fullName!.isNotEmpty) 'name': fullName,
        if (addressText != null && addressText!.isNotEmpty) 'address': addressText,
        'lat': latitude,
        'lng': longitude,
        if (gpsAccuracy != null) 'acc': gpsAccuracy,
        if (identificationNotes != null && identificationNotes!.isNotEmpty) 'notes': identificationNotes,
        if (photoFileNames.isNotEmpty) 'photos': photoFileNames,
        if (senderName != null && senderName!.isNotEmpty) 'sender': senderName,
        'ts': timestamp,
      };

  factory SharedPointPayload.fromJson(Map<String, dynamic> json) {
    final rawPhotos = json['photos'];
    List<String> photosList = [];
    if (rawPhotos is List) {
      photosList = rawPhotos.map((e) => e.toString()).toList();
    }

    return SharedPointPayload(
      phoneNumber: json['phone']?.toString() ?? '',
      fullName: json['name']?.toString(),
      addressText: json['address']?.toString(),
      latitude: (json['lat'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['lng'] as num?)?.toDouble() ?? 0.0,
      gpsAccuracy: (json['acc'] as num?)?.toDouble(),
      identificationNotes: json['notes']?.toString(),
      photoFileNames: photosList,
      senderName: json['sender']?.toString(),
      timestamp: json['ts']?.toString() ?? DateTime.now().toUtc().toIso8601String(),
    );
  }
}

/// Manifest của gói chia sẻ (.dshare)
class SharePackageManifest {
  final int formatVersion;
  final String type;
  final String appVersion;
  final int schemaVersion;
  final String createdAt;
  final String senderDisplayName;
  final int pointsCount;
  final int photosCount;
  final bool isEncrypted;
  final String? salt;
  final String? iv;
  final Map<String, String> checksums;

  const SharePackageManifest({
    this.formatVersion = 1,
    this.type = 'dshare',
    this.appVersion = '1.0.0+1',
    required this.schemaVersion,
    required this.createdAt,
    required this.senderDisplayName,
    required this.pointsCount,
    required this.photosCount,
    this.isEncrypted = false,
    this.salt,
    this.iv,
    required this.checksums,
  });

  Map<String, dynamic> toJson() => {
        'formatVersion': formatVersion,
        'type': type,
        'appVersion': appVersion,
        'schemaVersion': schemaVersion,
        'createdAt': createdAt,
        'senderDisplayName': senderDisplayName,
        'pointsCount': pointsCount,
        'photosCount': photosCount,
        'isEncrypted': isEncrypted,
        if (salt != null) 'salt': salt,
        if (iv != null) 'iv': iv,
        'checksums': checksums,
      };

  factory SharePackageManifest.fromJson(Map<String, dynamic> json) {
    final rawChecksums = json['checksums'];
    final Map<String, String> mapChecksums = {};
    if (rawChecksums is Map) {
      rawChecksums.forEach((key, value) {
        mapChecksums[key.toString()] = value.toString();
      });
    }

    return SharePackageManifest(
      formatVersion: (json['formatVersion'] as num?)?.toInt() ?? 1,
      type: json['type']?.toString() ?? 'dshare',
      appVersion: json['appVersion']?.toString() ?? '1.0.0+1',
      schemaVersion: (json['schemaVersion'] as num?)?.toInt() ?? 1,
      createdAt: json['createdAt']?.toString() ?? '',
      senderDisplayName: json['senderDisplayName']?.toString() ?? 'Shipper',
      pointsCount: (json['pointsCount'] as num?)?.toInt() ?? 0,
      photosCount: (json['photosCount'] as num?)?.toInt() ?? 0,
      isEncrypted: json['isEncrypted'] == true,
      salt: json['salt']?.toString(),
      iv: json['iv']?.toString(),
      checksums: mapChecksums,
    );
  }
}

/// Phân loại điểm chia sẻ khi so sánh với CSDL người nhận
enum SharePointClassification {
  /// Khách hàng mới (SĐT chưa từng có trong hệ thống)
  newCustomer,

  /// Trùng SĐT nhưng khách chưa có vị trí đã lưu
  existingWithoutLocation,

  /// Trùng SĐT và khách đã có vị trí đã lưu (hiển thị khoảng cách giữa 2 điểm)
  existingWithLocation,

  /// Điểm lỗi dữ liệu (tọa độ sai dải, SĐT không hợp lệ,...)
  invalid,
}

/// Thông tin điểm chia sẻ đã phân loại phục vụ hiển thị xem trước (Preview)
class ClassifiedSharePoint {
  final SharedPointPayload point;
  final SharePointClassification classification;
  final String? existingCustomerId;
  final String? existingCustomerName;
  final String? existingAddress;
  final double? existingLatitude;
  final double? existingLongitude;
  final double? distanceMeters;
  final String? invalidReason;
  bool isSelected;

  ClassifiedSharePoint({
    required this.point,
    required this.classification,
    this.existingCustomerId,
    this.existingCustomerName,
    this.existingAddress,
    this.existingLatitude,
    this.existingLongitude,
    this.distanceMeters,
    this.invalidReason,
    this.isSelected = true,
  });

  String get formattedDistance {
    if (distanceMeters == null) return '';
    if (distanceMeters! < 1000) {
      return '${distanceMeters!.round()} m';
    }
    return '${(distanceMeters! / 1000).toStringAsFixed(1)} km';
  }
}

/// Thông tin xem trước của gói chia sẻ trước khi ghi vào CSDL
class SharePackagePreview {
  final SharePackageManifest manifest;
  final List<ClassifiedSharePoint> classifiedPoints;
  final Map<String, Uint8List> photos;
  final String? filePath;
  final bool isFromQr;

  const SharePackagePreview({
    required this.manifest,
    required this.classifiedPoints,
    this.photos = const {},
    this.filePath,
    this.isFromQr = false,
  });

  int get totalPoints => classifiedPoints.length;

  int get validPointsCount =>
      classifiedPoints.where((p) => p.classification != SharePointClassification.invalid).length;

  int get newCount =>
      classifiedPoints.where((p) => p.classification == SharePointClassification.newCustomer).length;

  int get existingWithoutLocCount =>
      classifiedPoints.where((p) => p.classification == SharePointClassification.existingWithoutLocation).length;

  int get existingWithLocCount =>
      classifiedPoints.where((p) => p.classification == SharePointClassification.existingWithLocation).length;

  int get invalidCount =>
      classifiedPoints.where((p) => p.classification == SharePointClassification.invalid).length;

  int get selectedCount =>
      classifiedPoints.where((p) => p.isSelected && p.classification != SharePointClassification.invalid).length;
}

/// Chế độ nhập dữ liệu
enum ShareImportMode {
  /// Chỉ thêm điểm mới (bỏ qua trùng SĐT đã có vị trí)
  addOnly,

  /// Thay vị trí cũ bằng vị trí nhận được (vị trí cũ lưu vào lịch sử qua trigger)
  replaceExisting,
}

/// Kết quả nhập gói chia sẻ
class ShareImportResult {
  final int addedCount;
  final int replacedCount;
  final int skippedCount;
  final int errorCount;
  final int photosAdded;
  final int photosSkipped;
  final String? createdShiftId;
  final String? createdShiftName;
  final String message;

  const ShareImportResult({
    this.addedCount = 0,
    this.replacedCount = 0,
    this.skippedCount = 0,
    this.errorCount = 0,
    this.photosAdded = 0,
    this.photosSkipped = 0,
    this.createdShiftId,
    this.createdShiftName,
    required this.message,
  });
}

