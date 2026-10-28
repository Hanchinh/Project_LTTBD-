part of 'app_database.dart';

/// Các thao tác CRUD mức thấp cho Khách hàng (Customers) và Vị trí đã lưu (Saved Locations)
extension AppDatabaseCustomerOps on AppDatabase {
  // --- Khách hàng (Customers) ---

  /// Thêm khách hàng mới kèm đồng bộ trường tìm kiếm không dấu
  Future<String> insertCustomer({
    String? id,
    String? customerCode,
    required String fullName,
    required String phoneNumber,
    String? addressText,
    String? notes,
  }) async {
    final db = await database;
    final customerId = id ?? AppDatabase.generateId();
    final cleanPhone = normalizeCustomerPhone(phoneNumber);
    final now = AppDatabase.currentIsoUtc();
    final searchText = buildCustomerSearchText(
      fullName: fullName,
      phoneNumber: cleanPhone,
      addressText: addressText,
      notes: notes,
    );

    await db.insert('customers', {
      'id': customerId,
      'customer_code': customerCode ?? 'CUST-${cleanPhone.length >= 4 ? cleanPhone.substring(cleanPhone.length - 4) : cleanPhone}',
      'full_name': fullName,
      'phone_number': cleanPhone,
      'address_text': addressText,
      'notes': notes,
      'search_text': searchText,
      'created_at': now,
      'updated_at': now,
      'deleted_at': null,
    });

    return customerId;
  }

  /// Cập nhật khách hàng kèm đồng bộ trường tìm kiếm
  Future<int> updateCustomer(
    String id, {
    String? fullName,
    String? phoneNumber,
    String? addressText,
    String? notes,
  }) async {
    final db = await database;
    final current = await getCustomerById(id);
    if (current == null) return 0;

    final newFullName = fullName ?? (current['full_name'] as String);
    final newPhone = phoneNumber != null ? normalizeCustomerPhone(phoneNumber) : (current['phone_number'] as String);
    final newAddress = addressText ?? (current['address_text'] as String?);
    final newNotes = notes ?? (current['notes'] as String?);
    final now = AppDatabase.currentIsoUtc();

    final searchText = buildCustomerSearchText(
      fullName: newFullName,
      phoneNumber: newPhone,
      addressText: newAddress,
      notes: newNotes,
    );

    return await db.update(
      'customers',
      {
        'full_name': newFullName,
        'phone_number': newPhone,
        'address_text': newAddress,
        'notes': newNotes,
        'search_text': searchText,
        'updated_at': now,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Lấy khách hàng theo ID
  Future<Map<String, dynamic>?> getCustomerById(String id) async {
    final db = await database;
    final rows = await db.query(
      'customers',
      where: 'id = ? AND deleted_at IS NULL',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isNotEmpty ? rows.first : null;
  }

  /// Lấy khách hàng theo số điện thoại (tự động chuẩn hóa)
  Future<Map<String, dynamic>?> getCustomerByPhone(String phoneNumber) async {
    final db = await database;
    final clean = normalizeCustomerPhone(phoneNumber);
    final rows = await db.query(
      'customers',
      where: 'phone_number = ? AND deleted_at IS NULL',
      whereArgs: [clean],
      limit: 1,
    );
    return rows.isNotEmpty ? rows.first : null;
  }

  /// Tìm kiếm khách hàng theo từ khóa (hỗ trợ không dấu unaccent 2 chiều)
  Future<List<Map<String, dynamic>>> searchCustomers(String query, {int limit = 50, int offset = 0}) async {
    final db = await database;
    final cleanQuery = normalizeSearchQuery(query);

    if (cleanQuery.isEmpty) {
      return await db.query(
        'customers',
        where: 'deleted_at IS NULL',
        orderBy: 'updated_at DESC',
        limit: limit,
        offset: offset,
      );
    }

    final digitsOnly = query.replaceAll(RegExp(r'\D'), '');
    final hasDigits = digitsOnly.length >= 3;

    final whereClause = StringBuffer('deleted_at IS NULL AND (search_text LIKE ?');
    final whereArgs = <dynamic>['%$cleanQuery%'];

    if (hasDigits && digitsOnly != cleanQuery) {
      whereClause.write(' OR search_text LIKE ?');
      whereArgs.add('%$digitsOnly%');
    }
    whereClause.write(')');

    return await db.query(
      'customers',
      where: whereClause.toString(),
      whereArgs: whereArgs,
      orderBy: 'updated_at DESC',
      limit: limit,
      offset: offset,
    );
  }

  /// Xóa mềm khách hàng (đặt deleted_at)
  Future<int> softDeleteCustomer(String id) async {
    final db = await database;
    return await db.update(
      'customers',
      {'deleted_at': AppDatabase.currentIsoUtc()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // --- Vị trí đã lưu (Saved Locations) ---

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
