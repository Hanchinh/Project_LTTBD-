import '../models/shift_model.dart';
import '../models/order_model.dart';

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
}
