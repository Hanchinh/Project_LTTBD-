import '../../models/order_model.dart';
import '../../models/shift_model.dart';
import '../../services/api_service.dart';
import '../shift_repository.dart';

class RemoteShiftRepository implements ShiftRepository {
  @override
  Future<List<ShiftModel>> getShifts() {
    return ApiService.getShifts();
  }

  @override
  Future<ShiftModel> createShift({
    String? shiftDate,
    String? shiftName,
    String? notes,
  }) {
    return ApiService.createShift(
      shiftDate: shiftDate,
      shiftName: shiftName,
      notes: notes,
    );
  }

  @override
  Future<ShiftModel> getShiftDetail(String shiftId) {
    return ApiService.getShiftDetail(shiftId);
  }

  @override
  Future<ShiftModel> updateShiftName(String shiftId, String shiftName) {
    return ApiService.updateShiftName(shiftId, shiftName);
  }

  @override
  Future<ShiftModel> updateShiftStatus(String shiftId, ShiftStatus status) {
    return ApiService.updateShiftStatus(shiftId, status);
  }

  @override
  Future<bool> deleteShift(String shiftId) {
    return ApiService.deleteShift(shiftId);
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
    return ApiService.addPointToShift(
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
    return ApiService.addBulkPointsToShift(
      shiftId: shiftId,
      rawText: rawText,
      phones: phones,
      areaId: areaId,
    );
  }

  @override
  Future<void> removePointFromShift(String shiftId, String pointId) {
    return ApiService.removePointFromShift(shiftId, pointId);
  }

  @override
  Future<List<OrderModel>> getMyShiftOrders() {
    return ApiService.getMyShiftOrders();
  }

  @override
  Future<Map<String, dynamic>> addOrderToShift({
    required String customerId,
    bool allowMultiple = false,
    String? idempotencyKey,
  }) {
    return ApiService.addOrderToShift(
      customerId: customerId,
      allowMultiple: allowMultiple,
      idempotencyKey: idempotencyKey,
    );
  }
}
