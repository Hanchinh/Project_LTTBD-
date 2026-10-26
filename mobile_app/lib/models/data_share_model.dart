import 'package:flutter/material.dart';
import 'customer_photo_model.dart';

/// Mô hình lời mời chia sẻ dữ liệu giữa các shipper (TASK: DATA-SHARING-BETWEEN-SHIPPERS-023)
class DataShareModel {
  final String id;
  final String ownerId;
  final String? ownerName;
  final String? ownerPhone;
  final String recipientId;
  final String? recipientName;
  final String? recipientPhone;
  final String scope; // 'ALL_POINTS' | 'SHIFT'
  final String? shiftId;
  final String? shiftCode;
  final String? workDate;
  final bool includePhotos;
  final String status; // 'PENDING' | 'ACTIVE' | 'DECLINED' | 'REVOKED'
  final DateTime createdAt;
  final DateTime? acceptedAt;
  final DateTime? revokedAt;
  final DateTime? expiresAt;
  final int sharedPointsCount;

  DataShareModel({
    required this.id,
    required this.ownerId,
    this.ownerName,
    this.ownerPhone,
    required this.recipientId,
    this.recipientName,
    this.recipientPhone,
    required this.scope,
    this.shiftId,
    this.shiftCode,
    this.workDate,
    required this.includePhotos,
    required this.status,
    required this.createdAt,
    this.acceptedAt,
    this.revokedAt,
    this.expiresAt,
    this.sharedPointsCount = 0,
  });

  bool get isPending => status == 'PENDING';
  bool get isActive => status == 'ACTIVE' && !isExpired;
  bool get isDeclined => status == 'DECLINED';
  bool get isRevoked => status == 'REVOKED';
  bool get isExpired => expiresAt != null && expiresAt!.isBefore(DateTime.now());

  String get statusLabel {
    if (isExpired) return 'Đã hết hạn';
    switch (status) {
      case 'PENDING':
        return 'Chờ chấp nhận';
      case 'ACTIVE':
        return 'Đang chia sẻ';
      case 'DECLINED':
        return 'Đã từ chối';
      case 'REVOKED':
        return 'Đã dừng';
      default:
        return status;
    }
  }

  Color get statusTextColor {
    if (isExpired) return const Color(0xFF64748B);
    switch (status) {
      case 'PENDING':
        return const Color(0xFFD97706); // Amber
      case 'ACTIVE':
        return const Color(0xFF16A34A); // Green
      case 'DECLINED':
        return const Color(0xFFDC2626); // Red
      case 'REVOKED':
        return const Color(0xFF64748B); // Slate
      default:
        return const Color(0xFF0F172A);
    }
  }

  Color get statusBgColor {
    if (isExpired) return const Color(0xFFF1F5F9);
    switch (status) {
      case 'PENDING':
        return const Color(0xFFFEF3C7);
      case 'ACTIVE':
        return const Color(0xFFDCFCE7);
      case 'DECLINED':
        return const Color(0xFFFEE2E2);
      case 'REVOKED':
        return const Color(0xFFF1F5F9);
      default:
        return const Color(0xFFF8FAFC);
    }
  }

  factory DataShareModel.fromJson(Map<String, dynamic> json) {
    return DataShareModel(
      id: json['id'] as String? ?? '',
      ownerId: json['ownerId'] as String? ?? json['owner_id'] as String? ?? '',
      ownerName: json['ownerName'] as String? ?? json['owner_name'] as String?,
      ownerPhone: json['ownerPhone'] as String? ?? json['owner_phone'] as String?,
      recipientId: json['recipientId'] as String? ?? json['recipient_id'] as String? ?? '',
      recipientName: json['recipientName'] as String? ?? json['recipient_name'] as String?,
      recipientPhone: json['recipientPhone'] as String? ?? json['recipient_phone'] as String?,
      scope: json['scope'] as String? ?? 'ALL_POINTS',
      shiftId: json['shiftId'] as String? ?? json['shift_id'] as String?,
      shiftCode: json['shiftCode'] as String? ?? json['shift_code'] as String?,
      workDate: json['workDate'] as String? ?? json['work_date'] as String?,
      includePhotos: json['includePhotos'] as bool? ?? json['include_photos'] as bool? ?? false,
      status: json['status'] as String? ?? 'PENDING',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : (json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : DateTime.now()),
      acceptedAt: json['acceptedAt'] != null
          ? DateTime.tryParse(json['acceptedAt'] as String)
          : (json['accepted_at'] != null ? DateTime.tryParse(json['accepted_at'] as String) : null),
      revokedAt: json['revokedAt'] != null
          ? DateTime.tryParse(json['revokedAt'] as String)
          : (json['revoked_at'] != null ? DateTime.tryParse(json['revoked_at'] as String) : null),
      expiresAt: json['expiresAt'] != null
          ? DateTime.tryParse(json['expiresAt'] as String)
          : (json['expires_at'] != null ? DateTime.tryParse(json['expires_at'] as String) : null),
      sharedPointsCount: (json['sharedPointsCount'] as num?)?.toInt() ?? (json['shared_points_count'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Mô hình điểm vị trí được chia sẻ (TASK: DATA-SHARING-BETWEEN-SHIPPERS-023)
class SharedLocationPointModel {
  final String id;
  final String customerId;
  final String customerCode;
  final String customerName;
  final String customerPhone;
  final String customerAddress;
  final String areaId;
  final String areaName;
  final double latitude;
  final double longitude;
  final double gpsAccuracy;
  final String identificationNotes;
  final String? imageUrl;
  final int photoCount;
  final List<CustomerPhotoModel> photos;
  final String sharedByName;
  final String shareId;

  SharedLocationPointModel({
    required this.id,
    required this.customerId,
    required this.customerCode,
    required this.customerName,
    required this.customerPhone,
    required this.customerAddress,
    required this.areaId,
    required this.areaName,
    required this.latitude,
    required this.longitude,
    required this.gpsAccuracy,
    required this.identificationNotes,
    this.imageUrl,
    this.photoCount = 0,
    this.photos = const [],
    required this.sharedByName,
    required this.shareId,
  });

  factory SharedLocationPointModel.fromJson(Map<String, dynamic> json) {
    final rawPhotos = json['photos'] as List? ?? [];
    return SharedLocationPointModel(
      id: json['id'] as String? ?? '',
      customerId: json['customerId'] as String? ?? json['customer_id'] as String? ?? '',
      customerCode: json['customerCode'] as String? ?? json['customer_code'] as String? ?? '',
      customerName: json['customerName'] as String? ?? json['customer_name'] as String? ?? '',
      customerPhone: json['customerPhone'] as String? ?? json['customer_phone'] as String? ?? '',
      customerAddress: json['customerAddress'] as String? ?? json['customer_address'] as String? ?? '',
      areaId: json['areaId'] as String? ?? json['area_id'] as String? ?? '',
      areaName: json['areaName'] as String? ?? json['area_name'] as String? ?? '',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      gpsAccuracy: (json['gpsAccuracy'] as num?)?.toDouble() ?? (json['gps_accuracy'] as num?)?.toDouble() ?? 0.0,
      identificationNotes: json['identificationNotes'] as String? ?? json['identification_notes'] as String? ?? '',
      imageUrl: json['imageUrl'] as String? ?? json['image_url'] as String?,
      photoCount: (json['photoCount'] as num?)?.toInt() ?? (json['photo_count'] as num?)?.toInt() ?? 0,
      photos: rawPhotos.map((p) => CustomerPhotoModel.fromJson(p as Map<String, dynamic>, defaultCustomerId: json['customerId'] as String? ?? '')).toList(),
      sharedByName: json['sharedByName'] as String? ?? json['shared_by_name'] as String? ?? 'Shipper',
      shareId: json['shareId'] as String? ?? json['share_id'] as String? ?? '',
    );
  }
}
