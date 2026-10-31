// Tập hợp câu truy vấn SQLite chuyên biệt cho phân hệ ca làm việc.
// Truy vấn danh sách ca, thông tin chi tiết mốc giao và đếm tiến độ hoàn thành.
import 'package:delivery_marker_mobile/data/database/app_database.dart';

/// Thao tác CSDL SQLite mức thấp cho Ca làm việc (Shifts) và Điểm giao.
extension ShiftDatabaseOps on AppDatabase {
  /// Tạo ca làm việc mới
  Future<String> createShift({
    String? id,
    required String shiftCode,
    String? shiftName,
    required String workDate,
    String status = 'PREPARING',
  }) async {
    final db = await database;
    final shiftId = id ?? AppDatabase.generateId();
    final now = AppDatabase.currentIsoUtc();

    await db.insert('shifts', {
      'id': shiftId,
      'shift_code': shiftCode,
      'shift_name': shiftName,
      'work_date': workDate,
      'status': status,
      'started_at': null,
      'completed_at': null,
      'created_at': now,
      'updated_at': now,
    });

    return shiftId;
  }

  /// Cập nhật trạng thái ca
  Future<int> updateShiftStatus(String shiftId, String status) async {
    final db = await database;
    final now = AppDatabase.currentIsoUtc();
    final Map<String, dynamic> updates = {
      'status': status,
      'updated_at': now,
    };
    if (status == 'IN_PROGRESS') {
      updates['started_at'] = now;
    } else if (status == 'COMPLETED') {
      updates['completed_at'] = now;
    }

    return await db.update(
      'shifts',
      updates,
      where: 'id = ?',
      whereArgs: [shiftId],
    );
  }

  /// Xóa ca làm việc (Chỉ cascade xóa điểm giao trong ca, không xóa khách hay vị trí)
  Future<int> deleteShift(String shiftId) async {
    final db = await database;
    return await db.delete(
      'shifts',
      where: 'id = ?',
      whereArgs: [shiftId],
    );
  }

  /// Thêm điểm giao vào ca
  Future<String> addShiftDeliveryPoint({
    String? id,
    required String shiftId,
    required String customerId,
    int deliveryOrderIndex = 0,
    String locationStatus = 'NO_LOCATION',
    double? latitude,
    double? longitude,
    double? gpsAccuracy,
    String? identificationNotes,
  }) async {
    final db = await database;
    final pointId = id ?? AppDatabase.generateId();
    final now = AppDatabase.currentIsoUtc();

    await db.insert('shift_delivery_points', {
      'id': pointId,
      'shift_id': shiftId,
      'customer_id': customerId,
      'delivery_order_index': deliveryOrderIndex,
      'location_status': locationStatus,
      'latitude': latitude,
      'longitude': longitude,
      'gps_accuracy': gpsAccuracy,
      'identification_notes': identificationNotes,
      'created_at': now,
      'updated_at': now,
    });

    return pointId;
  }

  /// Lấy danh sách điểm giao trong một ca kèm thông tin khách hàng
  Future<List<Map<String, dynamic>>> getShiftDeliveryPoints(String shiftId) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT sdp.*, c.full_name, c.phone_number, c.address_text,
             sl.latitude AS saved_latitude, sl.longitude AS saved_longitude
      FROM shift_delivery_points sdp
      JOIN customers c ON sdp.customer_id = c.id
      LEFT JOIN saved_locations sl ON c.id = sl.customer_id
      WHERE sdp.shift_id = ?
      ORDER BY sdp.delivery_order_index ASC
    ''', [shiftId]);
  }
}
