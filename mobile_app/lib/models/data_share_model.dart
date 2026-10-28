import 'package:flutter/material.dart';
import 'package:delivery_marker_mobile/models/customer_photo_model.dart';

class DataShareModel {
  final String id, ownerId, recipientId, scope, status;
  final String? ownerName, ownerPhone, recipientName, recipientPhone, shiftId, shiftCode, workDate;
  final bool includePhotos;
  final DateTime createdAt;
  final DateTime? acceptedAt, revokedAt, expiresAt;
  final int sharedPointsCount;

  DataShareModel({
    required this.id, required this.ownerId, this.ownerName, this.ownerPhone,
    required this.recipientId, this.recipientName, this.recipientPhone,
    required this.scope, this.shiftId, this.shiftCode, this.workDate,
    required this.includePhotos, required this.status, required this.createdAt,
    this.acceptedAt, this.revokedAt, this.expiresAt, this.sharedPointsCount = 0,
  });

  bool get isPending => status == 'PENDING';
  bool get isActive => status == 'ACTIVE' && !isExpired;
  bool get isDeclined => status == 'DECLINED';
  bool get isRevoked => status == 'REVOKED';
  bool get isExpired => expiresAt != null && expiresAt!.isBefore(DateTime.now());

  String get statusLabel => isExpired ? 'Đã hết hạn' : switch (status) {
    'PENDING' => 'Chờ chấp nhận', 'ACTIVE' => 'Đang chia sẻ',
    'DECLINED' => 'Đã từ chối', 'REVOKED' => 'Đã dừng', _ => status,
  };

  Color get statusTextColor => isExpired ? const Color(0xFF64748B) : switch (status) {
    'PENDING' => const Color(0xFFD97706), 'ACTIVE' => const Color(0xFF16A34A),
    'DECLINED' => const Color(0xFFDC2626), 'REVOKED' => const Color(0xFF64748B),
    _ => const Color(0xFF0F172A),
  };

  Color get statusBgColor => isExpired ? const Color(0xFFF1F5F9) : switch (status) {
    'PENDING' => const Color(0xFFFEF3C7), 'ACTIVE' => const Color(0xFFDCFCE7),
    'DECLINED' => const Color(0xFFFEE2E2), 'REVOKED' => const Color(0xFFF1F5F9),
    _ => const Color(0xFFF8FAFC),
  };

  factory DataShareModel.fromJson(Map<String, dynamic> j) => DataShareModel(
    id: j['id']?.toString() ?? '', ownerId: j['ownerId']?.toString() ?? j['owner_id']?.toString() ?? '',
    ownerName: j['ownerName']?.toString() ?? j['owner_name']?.toString(),
    ownerPhone: j['ownerPhone']?.toString() ?? j['owner_phone']?.toString(),
    recipientId: j['recipientId']?.toString() ?? j['recipient_id']?.toString() ?? '',
    recipientName: j['recipientName']?.toString() ?? j['recipient_name']?.toString(),
    recipientPhone: j['recipientPhone']?.toString() ?? j['recipient_phone']?.toString(),
    scope: j['scope']?.toString() ?? 'ALL_POINTS',
    shiftId: j['shiftId']?.toString() ?? j['shift_id']?.toString(),
    shiftCode: j['shiftCode']?.toString() ?? j['shift_code']?.toString(),
    workDate: j['workDate']?.toString() ?? j['work_date']?.toString(),
    includePhotos: j['includePhotos'] == true || j['include_photos'] == true,
    status: j['status']?.toString() ?? 'PENDING',
    createdAt: DateTime.tryParse(j['createdAt']?.toString() ?? j['created_at']?.toString() ?? '') ?? DateTime.now(),
    acceptedAt: DateTime.tryParse(j['acceptedAt']?.toString() ?? j['accepted_at']?.toString() ?? ''),
    revokedAt: DateTime.tryParse(j['revokedAt']?.toString() ?? j['revoked_at']?.toString() ?? ''),
    expiresAt: DateTime.tryParse(j['expiresAt']?.toString() ?? j['expires_at']?.toString() ?? ''),
    sharedPointsCount: (j['sharedPointsCount'] as num?)?.toInt() ?? (j['shared_points_count'] as num?)?.toInt() ?? 0,
  );
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
