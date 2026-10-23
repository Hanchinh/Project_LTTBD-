import 'package:latlong2/latlong.dart';

enum ShiftStatus {
  preparing,
  inProgress,
  completed,
  cancelled;

  static ShiftStatus fromString(String? value) {
    switch (value?.toUpperCase()) {
      case 'IN_PROGRESS':
        return ShiftStatus.inProgress;
      case 'COMPLETED':
        return ShiftStatus.completed;
      case 'CANCELLED':
        return ShiftStatus.cancelled;
      case 'PREPARING':
      default:
        return ShiftStatus.preparing;
    }
  }

  String get displayName {
    switch (this) {
      case ShiftStatus.preparing:
        return 'Đang chuẩn bị';
      case ShiftStatus.inProgress:
        return 'Đang thực hiện';
      case ShiftStatus.completed:
        return 'Đã hoàn thành';
      case ShiftStatus.cancelled:
        return 'Đã hủy';
    }
  }

  String toApiString() {
    switch (this) {
      case ShiftStatus.preparing:
        return 'PREPARING';
      case ShiftStatus.inProgress:
        return 'IN_PROGRESS';
      case ShiftStatus.completed:
        return 'COMPLETED';
      case ShiftStatus.cancelled:
        return 'CANCELLED';
    }
  }
}

enum LocationStatus {
  verified,
  temporary,
  noLocation;

  static LocationStatus fromString(String? value) {
    switch (value?.toUpperCase()) {
      case 'VERIFIED':
        return LocationStatus.verified;
      case 'TEMPORARY':
        return LocationStatus.temporary;
      case 'NO_LOCATION':
      default:
        return LocationStatus.noLocation;
    }
  }

  String get displayName {
    switch (this) {
      case LocationStatus.verified:
        return 'Đã xác minh';
      case LocationStatus.temporary:
        return 'Vị trí tạm';
      case LocationStatus.noLocation:
        return 'Chưa có vị trí';
    }
  }

  String get pickerDisplayName {
    switch (this) {
      case LocationStatus.verified:
        return 'Đã xác minh';
      case LocationStatus.temporary:
        return 'Đã ghim vị trí · Chờ xác minh';
      case LocationStatus.noLocation:
        return 'Chưa ghim vị trí';
    }
  }

  String toApiString() {
    switch (this) {
      case LocationStatus.verified:
        return 'VERIFIED';
      case LocationStatus.temporary:
        return 'TEMPORARY';
      case LocationStatus.noLocation:
        return 'NO_LOCATION';
    }
  }
}

class ShiftSummaryModel {
  final int totalPoints;
  final int verifiedCount;
  final int temporaryCount;
  final int noLocationCount;

  ShiftSummaryModel({
    this.totalPoints = 0,
    this.verifiedCount = 0,
    this.temporaryCount = 0,
    this.noLocationCount = 0,
  });

  factory ShiftSummaryModel.fromJson(Map<String, dynamic>? json) {
    if (json == null) return ShiftSummaryModel();
    return ShiftSummaryModel(
      totalPoints: int.tryParse(json['totalPoints']?.toString() ?? '0') ?? 0,
      verifiedCount: int.tryParse(json['verifiedCount']?.toString() ?? '0') ?? 0,
      temporaryCount: int.tryParse(json['temporaryCount']?.toString() ?? '0') ?? 0,
      noLocationCount: int.tryParse(json['noLocationCount']?.toString() ?? '0') ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'totalPoints': totalPoints,
    'verifiedCount': verifiedCount,
    'temporaryCount': temporaryCount,
    'noLocationCount': noLocationCount,
  };
}

class ShiftDeliveryPointModel {
  final String id;
  final String shiftId;
  final String customerId;
  final String customerName;
  final String customerPhone;
  final String customerAddress;
  final String? areaId;
  final String? areaName;
  final String? orderId;
  final String? orderTrackingNumber;
  final int sequenceNumber;
  final String deliveryStatus;
  final LocationStatus locationStatus;
  final double? latitude;
  final double? longitude;
  final String? locationType;
  final String? locationNotes;
  final String? photoUrl;
  final String? deliveryNotes;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  ShiftDeliveryPointModel({
    required this.id,
    required this.shiftId,
    required this.customerId,
    required this.customerName,
    required this.customerPhone,
    required this.customerAddress,
    this.areaId,
    this.areaName,
    this.orderId,
    this.orderTrackingNumber,
    this.sequenceNumber = 1,
    this.deliveryStatus = 'PENDING',
    this.locationStatus = LocationStatus.noLocation,
    this.latitude,
    this.longitude,
    this.locationType,
    this.locationNotes,
    this.photoUrl,
    this.deliveryNotes,
    this.createdAt,
    this.updatedAt,
  });

  bool get hasValidCoordinates => latitude != null && longitude != null;

  bool get hasPhoto => photoUrl != null && photoUrl!.trim().isNotEmpty;

  LatLng? get latLng => hasValidCoordinates ? LatLng(latitude!, longitude!) : null;

  factory ShiftDeliveryPointModel.fromJson(Map<String, dynamic> json) {
    double? parseCoord(dynamic value) {
      if (value == null) return null;
      if (value is num) return value.toDouble();
      return double.tryParse(value.toString());
    }

    final cust = json['customer'] is Map<String, dynamic> ? json['customer'] as Map<String, dynamic> : null;
    final area = cust != null && cust['area'] is Map<String, dynamic> ? cust['area'] as Map<String, dynamic> : null;

    return ShiftDeliveryPointModel(
      id: json['id']?.toString() ?? json['pointId']?.toString() ?? '',
      shiftId: json['shiftId']?.toString() ?? json['shift_id']?.toString() ?? '',
      customerId: json['customerId']?.toString() ?? cust?['id']?.toString() ?? '',
      customerName: json['customerName']?.toString() ?? cust?['fullName']?.toString() ?? cust?['name']?.toString() ?? 'Khách hàng',
      customerPhone: json['customerPhone']?.toString() ?? cust?['phoneNumber']?.toString() ?? cust?['phone']?.toString() ?? '',
      customerAddress: json['customerAddress']?.toString() ?? cust?['addressText']?.toString() ?? cust?['address']?.toString() ?? '',
      areaId: json['areaId']?.toString() ?? area?['id']?.toString(),
      areaName: json['areaName']?.toString() ?? area?['name']?.toString(),
      orderId: json['orderId']?.toString(),
      orderTrackingNumber: json['orderTrackingNumber']?.toString(),
      sequenceNumber: int.tryParse(json['sequenceNumber']?.toString() ?? json['deliveryOrderIndex']?.toString() ?? '1') ?? 1,
      deliveryStatus: json['deliveryStatus']?.toString() ?? 'PENDING',
      locationStatus: LocationStatus.fromString(json['locationStatus']?.toString()),
      latitude: parseCoord(json['latitude']),
      longitude: parseCoord(json['longitude']),
      locationType: json['locationType']?.toString(),
      locationNotes: json['locationNotes']?.toString() ?? json['identificationNotes']?.toString(),
      photoUrl: json['photoUrl']?.toString() ?? json['imageUrl']?.toString(),
      deliveryNotes: json['deliveryNotes']?.toString(),
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'].toString()) : null,
      updatedAt: json['updatedAt'] != null ? DateTime.tryParse(json['updatedAt'].toString()) : null,
    );
  }

  ShiftDeliveryPointModel copyWith({
    String? id,
    String? shiftId,
    String? customerId,
    String? customerName,
    String? customerPhone,
    String? customerAddress,
    String? areaId,
    String? areaName,
    String? orderId,
    String? orderTrackingNumber,
    int? sequenceNumber,
    String? deliveryStatus,
    LocationStatus? locationStatus,
    double? latitude,
    double? longitude,
    String? locationType,
    String? locationNotes,
    String? photoUrl,
    String? deliveryNotes,
  }) {
    return ShiftDeliveryPointModel(
      id: id ?? this.id,
      shiftId: shiftId ?? this.shiftId,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      customerAddress: customerAddress ?? this.customerAddress,
      areaId: areaId ?? this.areaId,
      areaName: areaName ?? this.areaName,
      orderId: orderId ?? this.orderId,
      orderTrackingNumber: orderTrackingNumber ?? this.orderTrackingNumber,
      sequenceNumber: sequenceNumber ?? this.sequenceNumber,
      deliveryStatus: deliveryStatus ?? this.deliveryStatus,
      locationStatus: locationStatus ?? this.locationStatus,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      locationType: locationType ?? this.locationType,
      locationNotes: locationNotes ?? this.locationNotes,
      photoUrl: photoUrl ?? this.photoUrl,
      deliveryNotes: deliveryNotes ?? this.deliveryNotes,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

class ShiftModel {
  final String id;
  final String shiftCode;
  final String shiftDate;
  final String shipperId;
  final ShiftStatus status;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? notes;
  final ShiftSummaryModel summary;
  final List<ShiftDeliveryPointModel> deliveryPoints;

  ShiftModel({
    required this.id,
    required this.shiftCode,
    required this.shiftDate,
    required this.shipperId,
    required this.status,
    this.startedAt,
    this.completedAt,
    this.createdAt,
    this.updatedAt,
    this.notes,
    ShiftSummaryModel? summary,
    List<ShiftDeliveryPointModel>? deliveryPoints,
  })  : summary = summary ?? ShiftSummaryModel(),
        deliveryPoints = deliveryPoints ?? [];

  factory ShiftModel.fromJson(Map<String, dynamic> json) {
    List<ShiftDeliveryPointModel> points = [];
    final rawPoints = json['deliveryPoints'] ?? json['points'];
    if (rawPoints != null && rawPoints is List) {
      points = rawPoints
          .map((item) => ShiftDeliveryPointModel.fromJson(item as Map<String, dynamic>))
          .toList();
    }

    final rawDate = json['shiftDate'] ?? json['workDate'];
    final cleanDate = rawDate != null ? rawDate.toString().split('T')[0] : '';

    return ShiftModel(
      id: json['id']?.toString() ?? '',
      shiftCode: json['shiftCode']?.toString() ?? '',
      shiftDate: cleanDate,
      shipperId: json['shipperId']?.toString() ?? json['shipper']?['id']?.toString() ?? '',
      status: ShiftStatus.fromString(json['status']?.toString()),
      startedAt: json['startedAt'] != null ? DateTime.tryParse(json['startedAt'].toString()) : null,
      completedAt: json['completedAt'] != null ? DateTime.tryParse(json['completedAt'].toString()) : null,
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'].toString()) : null,
      updatedAt: json['updatedAt'] != null ? DateTime.tryParse(json['updatedAt'].toString()) : null,
      notes: json['notes']?.toString(),
      summary: ShiftSummaryModel.fromJson(json['summary'] as Map<String, dynamic>?),
      deliveryPoints: points,
    );
  }

  ShiftModel copyWith({
    String? id,
    String? shiftCode,
    String? shiftDate,
    String? shipperId,
    ShiftStatus? status,
    DateTime? startedAt,
    DateTime? completedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? notes,
    ShiftSummaryModel? summary,
    List<ShiftDeliveryPointModel>? deliveryPoints,
  }) {
    return ShiftModel(
      id: id ?? this.id,
      shiftCode: shiftCode ?? this.shiftCode,
      shiftDate: shiftDate ?? this.shiftDate,
      shipperId: shipperId ?? this.shipperId,
      status: status ?? this.status,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      notes: notes ?? this.notes,
      summary: summary ?? this.summary,
      deliveryPoints: deliveryPoints ?? this.deliveryPoints,
    );
  }
}
