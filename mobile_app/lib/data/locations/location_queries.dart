import 'package:delivery_marker_mobile/data/database/app_database.dart';

/// Thao tác CSDL SQLite mức thấp cho Vị trí đã lưu (Saved Locations) và Lịch sử vị trí
extension LocationDatabaseOps on AppDatabase {
  /// Lưu hoặc cập nhật vị trí đã xác minh (VERIFIED) của khách
  Future<String> setSavedLocation({
    String? id,
    required String customerId,
    required double latitude,
    required double longitude,
    double? gpsAccuracy,
    String? identificationNotes,
  }) async {
    final db = await database;
    final locationId = id ?? AppDatabase.generateId();
    final now = AppDatabase.currentIsoUtc();

    await db.rawInsert('''
      INSERT INTO saved_locations (id, customer_id, latitude, longitude, gps_accuracy, identification_notes, created_at, updated_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(customer_id) DO UPDATE SET
        latitude = excluded.latitude,
        longitude = excluded.longitude,
        gps_accuracy = excluded.gps_accuracy,
        identification_notes = excluded.identification_notes,
        updated_at = excluded.updated_at
    ''', [
      locationId,
      customerId,
      latitude,
      longitude,
      gpsAccuracy,
      identificationNotes,
      now,
      now,
    ]);

    return locationId;
  }

  /// Lấy vị trí đã lưu theo ID khách hàng
  Future<Map<String, dynamic>?> getSavedLocationByCustomerId(String customerId) async {
    final db = await database;
    final rows = await db.query(
      'saved_locations',
      where: 'customer_id = ?',
      whereArgs: [customerId],
      limit: 1,
    );
    return rows.isNotEmpty ? rows.first : null;
  }

  /// Xóa vị trí đã lưu (kích hoạt ON DELETE SET NULL để bảo toàn lịch sử)
  Future<int> deleteSavedLocation(String id) async {
    final db = await database;
    return await db.delete(
      'saved_locations',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Lấy danh sách vị trí đã lưu trong khung nhìn bản đồ (Bounding Box)
  Future<List<Map<String, dynamic>>> getSavedLocationsInBounds({
    required double minLat,
    required double maxLat,
    required double minLng,
    required double maxLng,
  }) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT sl.*, c.full_name, c.phone_number, c.address_text
      FROM saved_locations sl
      JOIN customers c ON sl.customer_id = c.id
      WHERE sl.latitude BETWEEN ? AND ?
        AND sl.longitude BETWEEN ? AND ?
        AND c.deleted_at IS NULL
    ''', [minLat, maxLat, minLng, maxLng]);
  }

  /// Lấy lịch sử thay đổi vị trí của một khách hàng
  Future<List<Map<String, dynamic>>> getLocationHistory(String customerId) async {
    final db = await database;
    return await db.query(
      'location_history',
      where: 'customer_id = ?',
      whereArgs: [customerId],
      orderBy: 'created_at DESC',
    );
  }
}
