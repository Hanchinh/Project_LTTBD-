import 'package:latlong2/latlong.dart';
import 'package:delivery_marker_mobile/models/customer_photo_model.dart';

enum ShiftStatus {
  preparing, inProgress, completed, cancelled;
  static ShiftStatus fromString(String? v) => switch (v?.toUpperCase()) {
    'IN_PROGRESS' => ShiftStatus.inProgress, 'COMPLETED' => ShiftStatus.completed,
    'CANCELLED' => ShiftStatus.cancelled, _ => ShiftStatus.preparing,
  };
  String get displayName => switch (this) {
    ShiftStatus.preparing => 'Đang chuẩn bị', ShiftStatus.inProgress => 'Đang thực hiện',
    ShiftStatus.completed => 'Đã hoàn thành', ShiftStatus.cancelled => 'Đã hủy',
  };
  String toApiString() => switch (this) {
    ShiftStatus.preparing => 'PREPARING', ShiftStatus.inProgress => 'IN_PROGRESS',
    ShiftStatus.completed => 'COMPLETED', ShiftStatus.cancelled => 'CANCELLED',
  };
}

enum LocationStatus {
  verified, temporary, noLocation;
  static LocationStatus fromString(String? v) => switch (v?.toUpperCase()) {
    'VERIFIED' => LocationStatus.verified, 'TEMPORARY' => LocationStatus.temporary,
    _ => LocationStatus.noLocation,
  };
  String get displayName => switch (this) {
    LocationStatus.verified => 'Đã xác minh', LocationStatus.temporary => 'Vị trí tạm',
    LocationStatus.noLocation => 'Chưa có vị trí',
  };
  String get pickerDisplayName => switch (this) {
    LocationStatus.verified => 'Đã xác minh',
    LocationStatus.temporary => 'Đã ghim vị trí · Chờ xác minh',
    LocationStatus.noLocation => 'Chưa ghim vị trí',
  };
  String toApiString() => switch (this) {
    LocationStatus.verified => 'VERIFIED', LocationStatus.temporary => 'TEMPORARY',
    LocationStatus.noLocation => 'NO_LOCATION',
  };
}

class ShiftSummaryModel {
  final int totalPoints, verifiedCount, temporaryCount, noLocationCount;
  ShiftSummaryModel({this.totalPoints = 0, this.verifiedCount = 0, this.temporaryCount = 0, this.noLocationCount = 0});
  factory ShiftSummaryModel.fromJson(Map<String, dynamic>? j) => ShiftSummaryModel(
    totalPoints: int.tryParse(j?['totalPoints']?.toString() ?? '0') ?? 0,
    verifiedCount: int.tryParse(j?['verifiedCount']?.toString() ?? '0') ?? 0,
    temporaryCount: int.tryParse(j?['temporaryCount']?.toString() ?? '0') ?? 0,
    noLocationCount: int.tryParse(j?['noLocationCount']?.toString() ?? '0') ?? 0,
  );
  Map<String, dynamic> toJson() => {'totalPoints': totalPoints, 'verifiedCount': verifiedCount, 'temporaryCount': temporaryCount, 'noLocationCount': noLocationCount};
}

class ShiftDeliveryPointModel {
  final String id, shiftId, customerId, customerName, customerPhone, customerAddress;
  final String? areaId, areaName, orderId, orderTrackingNumber, locationType, locationNotes, photoUrl, deliveryNotes;
  final int sequenceNumber, photoCount;
  final String deliveryStatus;
  final LocationStatus locationStatus;
  final double? latitude, longitude;
  final List<CustomerPhotoModel> photos;
  final DateTime? createdAt, updatedAt;

  ShiftDeliveryPointModel({
    required this.id, required this.shiftId, required this.customerId,
    required this.customerName, required this.customerPhone, required this.customerAddress,
    this.areaId, this.areaName, this.orderId, this.orderTrackingNumber,
    this.sequenceNumber = 1, this.deliveryStatus = 'PENDING',
    this.locationStatus = LocationStatus.noLocation,
    this.latitude, this.longitude, this.locationType, this.locationNotes,
    this.photoUrl, this.photoCount = 0, this.photos = const [],
    this.deliveryNotes, this.createdAt, this.updatedAt,
  });

  bool get hasValidCoordinates => latitude != null && longitude != null;
  bool get hasPhoto => (photoCount > 0) || (photoUrl != null && photoUrl!.trim().isNotEmpty);
  LatLng? get latLng => hasValidCoordinates ? LatLng(latitude!, longitude!) : null;

  factory ShiftDeliveryPointModel.fromJson(Map<String, dynamic> j) {
    final cust = j['customer'] is Map<String, dynamic> ? j['customer'] as Map<String, dynamic> : null;
    final area = cust != null && cust['area'] is Map<String, dynamic> ? cust['area'] as Map<String, dynamic> : null;
    final custId = j['customerId']?.toString() ?? cust?['id']?.toString() ?? '';
    final rawPhotos = j['photos'];
    final photos = rawPhotos is List ? rawPhotos.whereType<Map<String, dynamic>>().map((p) => CustomerPhotoModel.fromJson(p, defaultCustomerId: custId)).toList() : <CustomerPhotoModel>[];
    final resolvedUrl = j['photoUrl']?.toString() ?? j['imageUrl']?.toString();
    final pCount = int.tryParse(j['photoCount']?.toString() ?? '') ?? photos.length;

    double? parseCoord(dynamic v) => v == null ? null : (v is num ? v.toDouble() : double.tryParse(v.toString()));

    return ShiftDeliveryPointModel(
      id: j['id']?.toString() ?? j['pointId']?.toString() ?? '',
      shiftId: j['shiftId']?.toString() ?? j['shift_id']?.toString() ?? '',
      customerId: custId,
      customerName: j['customerName']?.toString() ?? cust?['fullName']?.toString() ?? cust?['name']?.toString() ?? 'Khách hàng',
      customerPhone: j['customerPhone']?.toString() ?? cust?['phoneNumber']?.toString() ?? cust?['phone']?.toString() ?? '',
      customerAddress: j['customerAddress']?.toString() ?? cust?['addressText']?.toString() ?? cust?['address']?.toString() ?? '',
      areaId: j['areaId']?.toString() ?? area?['id']?.toString(),
      areaName: j['areaName']?.toString() ?? area?['name']?.toString(),
      orderId: j['orderId']?.toString(),
      orderTrackingNumber: j['orderTrackingNumber']?.toString(),
      sequenceNumber: int.tryParse(j['sequenceNumber']?.toString() ?? j['deliveryOrderIndex']?.toString() ?? '1') ?? 1,
      deliveryStatus: j['deliveryStatus']?.toString() ?? 'PENDING',
      locationStatus: LocationStatus.fromString(j['locationStatus']?.toString()),
      latitude: parseCoord(j['latitude']), longitude: parseCoord(j['longitude']),
      locationType: j['locationType']?.toString(),
      locationNotes: j['locationNotes']?.toString() ?? j['identificationNotes']?.toString(),
      photoUrl: resolvedUrl,
      photoCount: pCount > 0 ? pCount : (resolvedUrl != null && resolvedUrl.isNotEmpty ? 1 : 0),
      photos: photos,
      deliveryNotes: j['deliveryNotes']?.toString(),
      createdAt: j['createdAt'] != null ? DateTime.tryParse(j['createdAt'].toString()) : null,
      updatedAt: j['updatedAt'] != null ? DateTime.tryParse(j['updatedAt'].toString()) : null,
    );
  }

  ShiftDeliveryPointModel copyWith({
    String? id, shiftId, customerId, customerName, customerPhone, customerAddress, areaId, areaName,
    orderId, orderTrackingNumber, deliveryStatus, locationType, locationNotes, photoUrl, deliveryNotes,
    int? sequenceNumber, photoCount, LocationStatus? locationStatus, double? latitude, longitude,
    List<CustomerPhotoModel>? photos,
  }) => ShiftDeliveryPointModel(
    id: id ?? this.id, shiftId: shiftId ?? this.shiftId, customerId: customerId ?? this.customerId,
    customerName: customerName ?? this.customerName, customerPhone: customerPhone ?? this.customerPhone,
    customerAddress: customerAddress ?? this.customerAddress, areaId: areaId ?? this.areaId,
    areaName: areaName ?? this.areaName, orderId: orderId ?? this.orderId,
    orderTrackingNumber: orderTrackingNumber ?? this.orderTrackingNumber,
    sequenceNumber: sequenceNumber ?? this.sequenceNumber, deliveryStatus: deliveryStatus ?? this.deliveryStatus,
    locationStatus: locationStatus ?? this.locationStatus, latitude: latitude ?? this.latitude,
    longitude: longitude ?? this.longitude, locationType: locationType ?? this.locationType,
    locationNotes: locationNotes ?? this.locationNotes, photoUrl: photoUrl ?? this.photoUrl,
    photoCount: photoCount ?? this.photoCount, photos: photos ?? this.photos,
    deliveryNotes: deliveryNotes ?? this.deliveryNotes, createdAt: createdAt, updatedAt: updatedAt,
  );
}

class ShiftModel {
  final String id, shiftCode, shiftDate, shipperId;
  final String? shiftName, notes;
  final ShiftStatus status;
  final DateTime? startedAt, completedAt, createdAt, updatedAt;
  final ShiftSummaryModel summary;
  final List<ShiftDeliveryPointModel> deliveryPoints;

  ShiftModel({
    required this.id, required this.shiftCode, this.shiftName, required this.shiftDate,
    required this.shipperId, required this.status, this.startedAt, this.completedAt,
    this.createdAt, this.updatedAt, this.notes, ShiftSummaryModel? summary,
    List<ShiftDeliveryPointModel>? deliveryPoints,
  })  : summary = summary ?? ShiftSummaryModel(),
        deliveryPoints = deliveryPoints ?? [];

  static String formatVnDate(DateTime dt, {DateTime? now}) {
    final curYear = (now ?? DateTime.now()).toUtc().add(const Duration(hours: 7)).year;
    final vn = dt.toUtc().add(const Duration(hours: 7));
    final d = vn.day.toString().padLeft(2, '0'), m = vn.month.toString().padLeft(2, '0');
    return vn.year != curYear ? '$d/$m/${vn.year}' : '$d/$m';
  }

  static String inferShiftName(DateTime dt, {DateTime? now}) {
    final h = dt.toUtc().add(const Duration(hours: 7)).hour;
    final s = h < 12 ? 'Ca sáng' : (h < 18 ? 'Ca chiều' : 'Ca tối');
    return '$s ${formatVnDate(dt, now: now)}';
  }

  static String suggestShiftName({DateTime? dateTime, List<String> existingNames = const []}) {
    final base = inferShiftName(dateTime ?? DateTime.now());
    if (!existingNames.contains(base)) return base;
    int suffix = 2;
    while (existingNames.contains('$base ($suffix)')) { suffix++; }
    return '$base ($suffix)';
  }

  String get displayTitle => (shiftName != null && shiftName!.trim().isNotEmpty)
      ? shiftName!.trim()
      : (createdAt ?? startedAt ?? DateTime.tryParse(shiftDate)).let((dt) => dt != null ? inferShiftName(dt) : 'Ca giao hàng');

  factory ShiftModel.fromJson(Map<String, dynamic> j) {
    final rawPts = j['deliveryPoints'] ?? j['points'];
    final pts = rawPts is List ? rawPts.map((i) => ShiftDeliveryPointModel.fromJson(i as Map<String, dynamic>)).toList() : <ShiftDeliveryPointModel>[];
    final rawDate = j['shiftDate'] ?? j['workDate'];
    return ShiftModel(
      id: j['id']?.toString() ?? '', shiftCode: j['shiftCode']?.toString() ?? '',
      shiftName: j['shiftName']?.toString() ?? j['shift_name']?.toString(),
      shiftDate: rawDate != null ? rawDate.toString().split('T')[0] : '',
      shipperId: j['shipperId']?.toString() ?? j['shipper']?['id']?.toString() ?? '',
      status: ShiftStatus.fromString(j['status']?.toString()),
      startedAt: j['startedAt'] != null ? DateTime.tryParse(j['startedAt'].toString()) : null,
      completedAt: j['completedAt'] != null ? DateTime.tryParse(j['completedAt'].toString()) : null,
      createdAt: j['createdAt'] != null ? DateTime.tryParse(j['createdAt'].toString()) : null,
      updatedAt: j['updatedAt'] != null ? DateTime.tryParse(j['updatedAt'].toString()) : null,
      notes: j['notes']?.toString(),
      summary: ShiftSummaryModel.fromJson(j['summary'] as Map<String, dynamic>?),
      deliveryPoints: pts,
    );
  }

  ShiftModel copyWith({
    String? id, shiftCode, shiftName, shiftDate, shipperId, notes,
    ShiftStatus? status, DateTime? startedAt, completedAt, createdAt, updatedAt,
    ShiftSummaryModel? summary, List<ShiftDeliveryPointModel>? deliveryPoints,
  }) => ShiftModel(
    id: id ?? this.id, shiftCode: shiftCode ?? this.shiftCode, shiftName: shiftName ?? this.shiftName,
    shiftDate: shiftDate ?? this.shiftDate, shipperId: shipperId ?? this.shipperId,
    status: status ?? this.status, startedAt: startedAt ?? this.startedAt,
    completedAt: completedAt ?? this.completedAt, createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt, notes: notes ?? this.notes,
    summary: summary ?? this.summary, deliveryPoints: deliveryPoints ?? this.deliveryPoints,
  );
}

class BulkAddSummary {
  final int total, addedCount, alreadyInShiftCount, rejectedCount;
  BulkAddSummary({this.total = 0, this.addedCount = 0, this.alreadyInShiftCount = 0, this.rejectedCount = 0});
  factory BulkAddSummary.fromJson(Map<String, dynamic>? j) => BulkAddSummary(
    total: int.tryParse(j?['total']?.toString() ?? '0') ?? 0,
    addedCount: int.tryParse(j?['addedCount']?.toString() ?? '0') ?? 0,
    alreadyInShiftCount: int.tryParse(j?['alreadyInShiftCount']?.toString() ?? '0') ?? 0,
    rejectedCount: int.tryParse(j?['rejectedCount']?.toString() ?? '0') ?? 0,
  );
}

class AlreadyInShiftItem {
  final String phone, pointId, customerId, customerName, locationStatus;
  AlreadyInShiftItem({required this.phone, required this.pointId, required this.customerId, required this.customerName, required this.locationStatus});
  factory AlreadyInShiftItem.fromJson(Map<String, dynamic> j) => AlreadyInShiftItem(
    phone: j['phone']?.toString() ?? '', pointId: j['pointId']?.toString() ?? '',
    customerId: j['customerId']?.toString() ?? '', customerName: j['customerName']?.toString() ?? '',
    locationStatus: j['locationStatus']?.toString() ?? '',
  );
}

class RejectedPhoneItem {
  final String phone, reason, message;
  RejectedPhoneItem({required this.phone, required this.reason, required this.message});
  factory RejectedPhoneItem.fromJson(Map<String, dynamic> j) => RejectedPhoneItem(
    phone: j['phone']?.toString() ?? '', reason: j['reason']?.toString() ?? '', message: j['message']?.toString() ?? '',
  );
}

class BulkAddPointsResult {
  final List<ShiftDeliveryPointModel> added;
  final List<AlreadyInShiftItem> alreadyInShift;
  final List<RejectedPhoneItem> rejected;
  final BulkAddSummary summary;
  BulkAddPointsResult({required this.added, required this.alreadyInShift, required this.rejected, required this.summary});
  factory BulkAddPointsResult.fromJson(Map<String, dynamic> j) {
    final rawA = j['added'], rawS = j['alreadyInShift'], rawR = j['rejected'];
    return BulkAddPointsResult(
      added: rawA is List ? rawA.whereType<Map<String, dynamic>>().map(ShiftDeliveryPointModel.fromJson).toList() : [],
      alreadyInShift: rawS is List ? rawS.whereType<Map<String, dynamic>>().map(AlreadyInShiftItem.fromJson).toList() : [],
      rejected: rawR is List ? rawR.whereType<Map<String, dynamic>>().map(RejectedPhoneItem.fromJson).toList() : [],
      summary: BulkAddSummary.fromJson(j['summary'] as Map<String, dynamic>?),
    );
  }
}

extension _ScopeExt<T> on T {
  R let<R>(R Function(T it) op) => op(this);
}
