import 'package:sqflite/sqflite.dart';
import 'package:delivery_marker_mobile/models/shift_model.dart';
import 'package:delivery_marker_mobile/models/order_model.dart';
import 'package:delivery_marker_mobile/models/location_model.dart';

/// Lớp ánh xạ (Mapper) chuyển đổi các hàng SQLite thành các đối tượng Model của Ca làm việc
class ShiftRowMapper {
  /// Ánh xạ một dòng truy vấn CSDL sang đối tượng [ShiftDeliveryPointModel].
  static ShiftDeliveryPointModel mapToPointModel(
    Map<String, dynamic> r, {
    String defaultAreaId = 'local-area',
    String defaultAreaName = 'Khu vực cục bộ',
  }) {
    return ShiftDeliveryPointModel(
      id: r['id'] as String,
      shiftId: r['shift_id'] as String,
      customerId: r['customer_id'] as String,
      customerName: (r['customer_name'] as String?) ?? 'Khách hàng',
      customerPhone: (r['customer_phone'] as String?) ?? '',
      customerAddress: (r['customer_address'] as String?) ?? '',
      areaId: defaultAreaId,
      areaName: defaultAreaName,
      orderId: r['order_id'] as String?,
      sequenceNumber: (r['delivery_order_index'] as num?)?.toInt() ?? 1,
      deliveryStatus: (r['delivery_status'] as String?) ?? 'PENDING',
      locationStatus: LocationStatus.fromString(r['location_status'] as String?),
      latitude: (r['latitude'] as num?)?.toDouble(),
      longitude: (r['longitude'] as num?)?.toDouble(),
      locationNotes: r['identification_notes'] as String?,
      photoUrl: null,
      photoCount: 0,
      photos: const [],
      deliveryNotes: null,
      createdAt: DateTime.tryParse(r['created_at']?.toString() ?? ''),
      updatedAt: DateTime.tryParse(r['updated_at']?.toString() ?? ''),
    );
  }

  /// Tính toán số liệu thống kê tóm tắt (Summary) của một ca làm việc từ SQLite.
  static Future<ShiftSummaryModel> calculateSummary(DatabaseExecutor executor, String shiftId) async {
    final rows = await executor.rawQuery('''
      SELECT 
        COUNT(*) AS total_points,
        SUM(CASE WHEN location_status = 'VERIFIED' THEN 1 ELSE 0 END) AS verified_count,
        SUM(CASE WHEN location_status = 'TEMPORARY' THEN 1 ELSE 0 END) AS temporary_count,
        SUM(CASE WHEN location_status = 'NO_LOCATION' THEN 1 ELSE 0 END) AS no_location_count
      FROM shift_delivery_points
      WHERE shift_id = ?
    ''', [shiftId]);

    if (rows.isEmpty) {
      return ShiftSummaryModel(
        totalPoints: 0,
        verifiedCount: 0,
        temporaryCount: 0,
        noLocationCount: 0,
      );
    }

    final row = rows.first;
    return ShiftSummaryModel(
      totalPoints: (row['total_points'] as num?)?.toInt() ?? 0,
      verifiedCount: (row['verified_count'] as num?)?.toInt() ?? 0,
      temporaryCount: (row['temporary_count'] as num?)?.toInt() ?? 0,
      noLocationCount: (row['no_location_count'] as num?)?.toInt() ?? 0,
    );
  }

  /// Chuyển đổi danh sách điểm giao SQLite sang [OrderModel] tương thích màn hình cũ.
  static List<OrderModel> mapPointsToOrders(List<Map<String, dynamic>> points, String defaultAreaName) {
    return points.map((p) {
      final custId = p['customer_id'] as String;
      final hasSaved = p['saved_lat'] != null && p['saved_lng'] != null;
      SavedLocationModel? savedLoc;
      if (hasSaved) {
        savedLoc = SavedLocationModel(
          customerId: custId,
          latitude: (p['saved_lat'] as num).toDouble(),
          longitude: (p['saved_lng'] as num).toDouble(),
          gpsAccuracy: 0.0,
          identificationNotes: (p['saved_notes'] as String?) ?? '',
        );
      }

      return OrderModel(
        orderId: p['id'] as String,
        orderCode: 'ORD-${(p['id'] as String).substring(0, 8).toUpperCase()}',
        orderStatus: (p['delivery_status'] as String?) ?? 'PENDING',
        areaName: defaultAreaName,
        customerId: custId,
        customerName: (p['customer_name'] as String?) ?? 'Khách hàng',
        customerPhone: (p['customer_phone'] as String?) ?? '',
        customerAddress: (p['customer_address'] as String?) ?? '',
        hasSavedLocation: hasSaved,
        savedLocation: savedLoc,
      );
    }).toList();
  }
}
