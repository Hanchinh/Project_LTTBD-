import 'package:delivery_marker_mobile/models/shift_model.dart';
import 'package:delivery_marker_mobile/models/order_model.dart';

abstract class ShiftRepository {
  Future<List<ShiftModel>> getShifts();

  Future<ShiftModel> createShift({
    String? shiftDate,
    String? shiftName,
    String? notes,
  });

  Future<ShiftModel> getShiftDetail(String shiftId);

  Future<ShiftModel> updateShiftName(String shiftId, String shiftName);

  Future<ShiftModel> updateShiftStatus(String shiftId, ShiftStatus status);

  Future<bool> deleteShift(String shiftId);

  Future<Map<String, dynamic>> addPointToShift(
    String shiftId, {
    String? customerId,
    String? phoneNumber,
    bool createIfNotFound = false,
    String? fullName,
    String? addressText,
    String? orderId,
    int? sequenceNumber,
    String? deliveryNotes,
    String? areaId,
  });

  Future<BulkAddPointsResult> addBulkPointsToShift({
    required String shiftId,
    String? rawText,
    List<String>? phones,
    String? areaId,
  });

  Future<void> removePointFromShift(String shiftId, String pointId);

  Future<List<OrderModel>> getMyShiftOrders();

  Future<Map<String, dynamic>> addOrderToShift({
    required String customerId,
    bool allowMultiple = false,
    String? idempotencyKey,
  });

  /// Xác minh vị trí trong ca (Đã ngừng hoạt động theo LOCATION-RULES-012, chỉ dùng luồng Danh bạ)
  Future<void> verifyPointLocation(String shiftId, String pointId) async {
    throw UnsupportedError(
      'Endpoint xác minh vị trí trong ca đã ngừng hoạt động (410 Gone). Theo quy chuẩn LOCATION-RULES-012, vị trí chuẩn chỉ được xác nhận qua luồng Danh bạ -> Hồ sơ khách -> Xác nhận vị trí.',
    );
  }
}

