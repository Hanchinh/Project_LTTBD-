import 'package:delivery_marker_mobile/core/utils/vietnamese_utils.dart';
import 'package:delivery_marker_mobile/data/local/app_database.dart';
import 'package:delivery_marker_mobile/data/local/local_customer_repository.dart';
import 'package:delivery_marker_mobile/data/local/local_photo_repository.dart';
import 'package:delivery_marker_mobile/models/customer_model.dart';
import 'package:delivery_marker_mobile/models/customer_photo_model.dart';
import 'package:delivery_marker_mobile/models/shift_model.dart';

/// Helper thực thi truy vấn, tìm kiếm, phân loại và phân trang khách hàng từ SQLite
class CustomerQueryHelpers {
  static Future<CustomerDirectoryResponse> queryCustomersResponse({
    required AppDatabase appDb,
    required LocalPhotoRepository photoRepo,
    String? query,
    String? status,
    bool? hasPhoto,
    int? limit,
    int? offset,
    String defaultAreaId = LocalCustomerRepository.defaultAreaId,
    String defaultAreaName = LocalCustomerRepository.defaultAreaName,
  }) async {
    final db = await appDb.database;

    // 1. Lọc khách hàng chưa xóa mềm
    List<Map<String, dynamic>> customerRows;
    final cleanQuery = query != null ? normalizeSearchQuery(query) : '';

    if (cleanQuery.isNotEmpty) {
      customerRows = await appDb.searchCustomers(query!, limit: 10000, offset: 0);
    } else {
      customerRows = await db.query(
        'customers',
        where: 'deleted_at IS NULL',
        orderBy: 'updated_at DESC, created_at DESC',
      );
    }

    // 2. Lấy toàn bộ vị trí đã lưu và điểm ghim tạm trong ca đang mở để xác định locationState
    final savedLocRows = await db.query('saved_locations');
    final savedLocMap = <String, Map<String, dynamic>>{};
    for (final r in savedLocRows) {
      savedLocMap[r['customer_id'] as String] = r;
    }

    // Lấy các điểm giao TEMPORARY trong ca PREPARING hoặc IN_PROGRESS
    final activeTempPoints = await db.rawQuery('''
      SELECT sdp.customer_id, sdp.latitude, sdp.longitude, sdp.identification_notes, sdp.gps_accuracy
      FROM shift_delivery_points sdp
      JOIN shifts s ON s.id = sdp.shift_id
      WHERE sdp.location_status = 'TEMPORARY'
        AND s.status IN ('PREPARING', 'IN_PROGRESS')
      ORDER BY sdp.updated_at DESC
    ''');
    final tempPointMap = <String, Map<String, dynamic>>{};
    for (final r in activeTempPoints) {
      final custId = r['customer_id'] as String;
      tempPointMap.putIfAbsent(custId, () => r);
    }

    // 3. Xây dựng danh sách CustomerDirectoryModel và tính toán Counts
    final allModels = <CustomerDirectoryModel>[];
    int verifiedCount = 0;
    int temporaryCount = 0;
    int noLocationCount = 0;

    for (final c in customerRows) {
      final custId = c['id'] as String;
      final savedLoc = savedLocMap[custId];
      final tempPoint = tempPointMap[custId];

      LocationStatus locState = LocationStatus.noLocation;
      double? lat;
      double? lng;
      String? notes;
      String? savedLocId;

      if (savedLoc != null && savedLoc['latitude'] != null && savedLoc['longitude'] != null) {
        locState = LocationStatus.verified;
        lat = (savedLoc['latitude'] as num).toDouble();
        lng = (savedLoc['longitude'] as num).toDouble();
        notes = savedLoc['identification_notes'] as String?;
        savedLocId = savedLoc['id'] as String?;
        verifiedCount++;
      } else if (tempPoint != null && tempPoint['latitude'] != null && tempPoint['longitude'] != null) {
        locState = LocationStatus.temporary;
        lat = (tempPoint['latitude'] as num).toDouble();
        lng = (tempPoint['longitude'] as num).toDouble();
        notes = tempPoint['identification_notes'] as String?;
        temporaryCount++;
      } else {
        locState = LocationStatus.noLocation;
        noLocationCount++;
      }

      allModels.add(CustomerDirectoryModel(
        id: custId,
        customerCode: (c['customer_code'] as String?) ?? 'CUST',
        fullName: (c['full_name'] as String?) ?? '',
        phoneNumber: (c['phone_number'] as String?) ?? '',
        addressText: (c['address_text'] as String?) ?? '',
        areaId: defaultAreaId,
        areaName: defaultAreaName,
        locationStatus: locState,
        locationState: locState,
        hasLocation: locState != LocationStatus.noLocation,
        latitude: lat,
        longitude: lng,
        identificationNotes: notes,
        savedLocationId: savedLocId,
        createdAt: DateTime.tryParse(c['created_at']?.toString() ?? ''),
        updatedAt: DateTime.tryParse(c['updated_at']?.toString() ?? ''),
      ));
    }

    // 4. Lọc theo tab status nếu có yêu cầu
    List<CustomerDirectoryModel> filtered = allModels;
    if (status != null && status.toUpperCase() != 'ALL') {
      final targetStatus = LocationStatus.fromString(status);
      filtered = allModels.where((m) => m.locationState == targetStatus).toList();
    }

    final totalCountForTab = filtered.length;
    final effOffset = offset ?? 0;
    final effLimit = limit ?? 30;

    final pagedItems = filtered.skip(effOffset).take(effLimit).toList();

    // 5. Nạp photoCount và tối đa 3 ảnh thumbnail cho danh sách khách hàng hiển thị
    final customerIds = pagedItems.map((c) => c.id).toList();
    final photoSummaries = await photoRepo.getBatchPhotoSummaries(customerIds);

    final enrichedItems = pagedItems.map((c) {
      final summary = photoSummaries[c.id];
      if (summary != null) {
        final count = summary['photoCount'] as int;
        final photos = summary['photos'] as List<CustomerPhotoModel>;
        final firstThumb = summary['firstThumbnailUrl'] as String?;
        return c.copyWith(
          photoCount: count,
          photos: photos,
          firstThumbnailUrl: firstThumb,
          imageUrl: firstThumb ?? c.imageUrl,
        );
      }
      return c;
    }).toList();

    return CustomerDirectoryResponse(
      items: enrichedItems,
      counts: CustomerTabCounts(
        total: allModels.length,
        verified: verifiedCount,
        temporary: temporaryCount,
        noLocation: noLocationCount,
      ),
      pagination: CustomerPagination(
        total: totalCountForTab,
        limit: effLimit,
        offset: effOffset,
        hasMore: effOffset + pagedItems.length < totalCountForTab,
      ),
    );
  }
}

