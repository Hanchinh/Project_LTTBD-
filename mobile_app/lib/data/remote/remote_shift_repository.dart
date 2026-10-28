import 'package:delivery_marker_mobile/models/order_model.dart';
import 'package:delivery_marker_mobile/models/shift_model.dart';
import 'package:delivery_marker_mobile/data/remote/shift_api.dart';
import 'package:delivery_marker_mobile/data/repositories/shift_repository.dart';

class RemoteShiftRepository implements ShiftRepository {
  @override
  Future<List<ShiftModel>> getShifts() {
    return ShiftApi.getShifts();
  }

  @override
  Future<ShiftModel> createShift({
    String? shiftDate,
    String? shiftName,
    String? notes,
  }) {
    return ShiftApi.createShift(
      shiftDate: shiftDate,
      shiftName: shiftName,
      notes: notes,
    );
  }

  @override
  Future<ShiftModel> getShiftDetail(String shiftId) {
    return ShiftApi.getShiftDetail(shiftId);
  }

  @override
  Future<ShiftModel> updateShiftName(String shiftId, String shiftName) {
    return ShiftApi.updateShiftName(shiftId, shiftName);
  }

  @override
  Future<ShiftModel> updateShiftStatus(String shiftId, ShiftStatus status) {
    return ShiftApi.updateShiftStatus(shiftId, status);
  }

  @override
  Future<bool> deleteShift(String shiftId) {
    return ShiftApi.deleteShift(shiftId);
  }

  @override
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
  }) {
    return ShiftApi.addPointToShift(
      shiftId,
      customerId: customerId,
      phoneNumber: phoneNumber,
      createIfNotFound: createIfNotFound,
      fullName: fullName,
      addressText: addressText,
      orderId: orderId,
      sequenceNumber: sequenceNumber,
      deliveryNotes: deliveryNotes,
      areaId: areaId,
    );
  }

  @override
  Future<BulkAddPointsResult> addBulkPointsToShift({
    required String shiftId,
    String? rawText,
    List<String>? phones,
    String? areaId,
  }) {
    return ShiftApi.addBulkPointsToShift(
      shiftId: shiftId,
      rawText: rawText,
      phones: phones,
      areaId: areaId,
    );
  }

  @override
  Future<void> removePointFromShift(String shiftId, String pointId) {
    return ShiftApi.removePointFromShift(shiftId, pointId);
  }

  @override
  Future<List<OrderModel>> getMyShiftOrders() {
    return ShiftApi.getMyShiftOrders();
  }

  @override
  Future<Map<String, dynamic>> addOrderToShift({
    required String customerId,
    bool allowMultiple = false,
    String? idempotencyKey,
  }) {
    return ShiftApi.addOrderToShift(
      customerId: customerId,
      allowMultiple: allowMultiple,
      idempotencyKey: idempotencyKey,
    );
  }

  @override
  Future<void> verifyPointLocation(String shiftId, String pointId) async {
    throw UnsupportedError(
      'Endpoint xác minh vị trí trong ca đã ngừng hoạt động (410 Gone). Theo quy chuẩn LOCATION-RULES-012, vị trí chuẩn chỉ được xác nhận qua luồng Danh bạ -> Hồ sơ khách -> Xác nhận vị trí.',
    );
  }
}

