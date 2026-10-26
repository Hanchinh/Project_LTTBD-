import 'package:latlong2/latlong.dart';
import 'customer_photo_model.dart';

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
  final int photoCount;
  final List<CustomerPhotoModel> photos;
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
    this.photoCount = 0,
    this.photos = const [],
    this.deliveryNotes,
    this.createdAt,
    this.updatedAt,
  });

  bool get hasValidCoordinates => latitude != null && longitude != null;

  bool get hasPhoto => (photoCount > 0) || (photoUrl != null && photoUrl!.trim().isNotEmpty);

  LatLng? get latLng => hasValidCoordinates ? LatLng(latitude!, longitude!) : null;

  factory ShiftDeliveryPointModel.fromJson(Map<String, dynamic> json) {
    double? parseCoord(dynamic value) {
      if (value == null) return null;
      if (value is num) return value.toDouble();
      return double.tryParse(value.toString());
    }

    final cust = json['customer'] is Map<String, dynamic> ? json['customer'] as Map<String, dynamic> : null;
    final area = cust != null && cust['area'] is Map<String, dynamic> ? cust['area'] as Map<String, dynamic> : null;
    final custId = json['customerId']?.toString() ?? cust?['id']?.toString() ?? '';

    final rawPhotos = json['photos'];
    List<CustomerPhotoModel> parsedPhotos = [];
    if (rawPhotos is List) {
      parsedPhotos = rawPhotos
          .whereType<Map<String, dynamic>>()
          .map((p) => CustomerPhotoModel.fromJson(p, defaultCustomerId: custId))
          .toList();
    }

    final pCount = int.tryParse(json['photoCount']?.toString() ?? '') ?? parsedPhotos.length;
    final resolvedPhotoUrl = json['photoUrl']?.toString() ?? json['imageUrl']?.toString();

    return ShiftDeliveryPointModel(
      id: json['id']?.toString() ?? json['pointId']?.toString() ?? '',
      shiftId: json['shiftId']?.toString() ?? json['shift_id']?.toString() ?? '',
      customerId: custId,
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
      photoUrl: resolvedPhotoUrl,
      photoCount: pCount > 0 ? pCount : (resolvedPhotoUrl != null && resolvedPhotoUrl.isNotEmpty ? 1 : 0),
      photos: parsedPhotos,
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
    int? photoCount,
    List<CustomerPhotoModel>? photos,
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
      photoCount: photoCount ?? this.photoCount,
      photos: photos ?? this.photos,
      deliveryNotes: deliveryNotes ?? this.deliveryNotes,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

class ShiftModel {
  final String id;
  final String shiftCode;
  final String? shiftName;
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
    this.shiftName,
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

  /// Định dạng ngày dd/MM (hoặc dd/MM/yyyy nếu khác năm hiện tại)
  static String formatVnDate(DateTime dt, {DateTime? now}) {
    final currentYear = (now ?? DateTime.now()).toUtc().add(const Duration(hours: 7)).year;
    final vnTime = dt.toUtc().add(const Duration(hours: 7));
    final d = vnTime.day.toString().padLeft(2, '0');
    final m = vnTime.month.toString().padLeft(2, '0');
    if (vnTime.year != currentYear) {
      return '$d/$m/${vnTime.year}';
    }
    return '$d/$m';
  }

  /// Suy ra tên ca theo thời gian Việt Nam (GMT+7)
  /// Sáng: < 12h, Chiều: 12h - 18h, Tối: >= 18h
  static String inferShiftName(DateTime dt, {DateTime? now}) {
    final vnTime = dt.toUtc().add(const Duration(hours: 7));
    String session;
    if (vnTime.hour < 12) {
      session = 'Ca sáng';
    } else if (vnTime.hour < 18) {
      session = 'Ca chiều';
    } else {
      session = 'Ca tối';
    }
    return '$session ${formatVnDate(dt, now: now)}';
  }

  /// Gợi ý tên khi tạo ca mới: "Ca sáng/chiều/tối dd/MM", nếu trùng thì thêm " (2)", " (3)"
  static String suggestShiftName({DateTime? dateTime, List<String> existingNames = const []}) {
    final now = dateTime ?? DateTime.now();
    final baseName = inferShiftName(now);

    if (!existingNames.contains(baseName)) {
      return baseName;
    }

    int suffix = 2;
    while (existingNames.contains('$baseName ($suffix)')) {
      suffix++;
    }
    return '$baseName ($suffix)';
  }

  /// Tên hiển thị của ca: ưu tiên shiftName nếu có, nếu chưa có thì suy ra "Ca sáng/chiều/tối dd/MM"
  String get displayTitle {
    if (shiftName != null && shiftName!.trim().isNotEmpty) {
      return shiftName!.trim();
    }
    final dt = createdAt ?? startedAt ?? DateTime.tryParse(shiftDate);
    if (dt != null) {
      return inferShiftName(dt);
    }
    return 'Ca giao hàng';
  }

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
      shiftName: json['shiftName']?.toString() ?? json['shift_name']?.toString(),
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
    String? shiftName,
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
      shiftName: shiftName ?? this.shiftName,
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

class BulkAddSummary {
  final int total;
  final int addedCount;
  final int alreadyInShiftCount;
  final int rejectedCount;

  BulkAddSummary({
    this.total = 0,
    this.addedCount = 0,
    this.alreadyInShiftCount = 0,
    this.rejectedCount = 0,
  });

  factory BulkAddSummary.fromJson(Map<String, dynamic>? json) {
    if (json == null) return BulkAddSummary();
    return BulkAddSummary(
      total: int.tryParse(json['total']?.toString() ?? '0') ?? 0,
      addedCount: int.tryParse(json['addedCount']?.toString() ?? '0') ?? 0,
      alreadyInShiftCount: int.tryParse(json['alreadyInShiftCount']?.toString() ?? '0') ?? 0,
      rejectedCount: int.tryParse(json['rejectedCount']?.toString() ?? '0') ?? 0,
    );
  }
}

class AlreadyInShiftItem {
  final String phone;
  final String pointId;
  final String customerId;
  final String customerName;
  final String locationStatus;

  AlreadyInShiftItem({
    required this.phone,
    required this.pointId,
    required this.customerId,
    required this.customerName,
    required this.locationStatus,
  });

  factory AlreadyInShiftItem.fromJson(Map<String, dynamic> json) {
    return AlreadyInShiftItem(
      phone: json['phone']?.toString() ?? '',
      pointId: json['pointId']?.toString() ?? '',
      customerId: json['customerId']?.toString() ?? '',
      customerName: json['customerName']?.toString() ?? '',
      locationStatus: json['locationStatus']?.toString() ?? '',
    );
  }
}

class RejectedPhoneItem {
  final String phone;
  final String reason;
  final String message;

  RejectedPhoneItem({
    required this.phone,
    required this.reason,
    required this.message,
  });

  factory RejectedPhoneItem.fromJson(Map<String, dynamic> json) {
    return RejectedPhoneItem(
      phone: json['phone']?.toString() ?? '',
      reason: json['reason']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
    );
  }
}

class BulkAddPointsResult {
  final List<ShiftDeliveryPointModel> added;
  final List<AlreadyInShiftItem> alreadyInShift;
  final List<RejectedPhoneItem> rejected;
  final BulkAddSummary summary;

  BulkAddPointsResult({
    required this.added,
    required this.alreadyInShift,
    required this.rejected,
    required this.summary,
  });

  factory BulkAddPointsResult.fromJson(Map<String, dynamic> json) {
    final rawAdded = json['added'];
    List<ShiftDeliveryPointModel> addedList = [];
    if (rawAdded is List) {
      addedList = rawAdded
          .whereType<Map<String, dynamic>>()
          .map((p) => ShiftDeliveryPointModel.fromJson(p))
          .toList();
    }

    final rawAlready = json['alreadyInShift'];
    List<AlreadyInShiftItem> alreadyList = [];
    if (rawAlready is List) {
      alreadyList = rawAlready
          .whereType<Map<String, dynamic>>()
          .map((item) => AlreadyInShiftItem.fromJson(item))
          .toList();
    }

    final rawRejected = json['rejected'];
    List<RejectedPhoneItem> rejectedList = [];
    if (rawRejected is List) {
      rejectedList = rawRejected
          .whereType<Map<String, dynamic>>()
          .map((item) => RejectedPhoneItem.fromJson(item))
          .toList();
    }

    return BulkAddPointsResult(
      added: addedList,
      alreadyInShift: alreadyList,
      rejected: rejectedList,
      summary: BulkAddSummary.fromJson(json['summary'] as Map<String, dynamic>?),
    );
  }
}
