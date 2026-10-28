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
    final cleanQuery = query != null ? normalizeSearchQuery(query) : '';
    final customerRows = cleanQuery.isNotEmpty
        ? await appDb.searchCustomers(query!, limit: 10000, offset: 0)
        : await db.query('customers', where: 'deleted_at IS NULL', orderBy: 'updated_at DESC, created_at DESC');

    final savedLocRows = await db.query('saved_locations');
    final savedLocMap = {for (final r in savedLocRows) r['customer_id'] as String: r};

    final activeTempPoints = await db.rawQuery('''
      SELECT sdp.customer_id, sdp.latitude, sdp.longitude, sdp.identification_notes, sdp.gps_accuracy
      FROM shift_delivery_points sdp JOIN shifts s ON s.id = sdp.shift_id
      WHERE sdp.location_status = 'TEMPORARY' AND s.status IN ('PREPARING', 'IN_PROGRESS')
      ORDER BY sdp.updated_at DESC
    ''');
    final tempPointMap = <String, Map<String, dynamic>>{};
    for (final r in activeTempPoints) {
      tempPointMap.putIfAbsent(r['customer_id'] as String, () => r);
    }

    final allModels = <CustomerDirectoryModel>[];
    int verifiedCount = 0, temporaryCount = 0, noLocationCount = 0;

    for (final c in customerRows) {
      final custId = c['id'] as String;
      final savedLoc = savedLocMap[custId];
      final tempPoint = tempPointMap[custId];
      LocationStatus locState = LocationStatus.noLocation;
      double? lat, lng;
      String? notes, savedLocId;

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

    var filtered = allModels;
    if (status != null && status.toUpperCase() != 'ALL') {
      final target = LocationStatus.fromString(status);
      filtered = allModels.where((m) => m.locationState == target).toList();
    }

    final effOffset = offset ?? 0;
    final effLimit = limit ?? 30;
    final paged = filtered.skip(effOffset).take(effLimit).toList();

    final photoSummaries = await photoRepo.getBatchPhotoSummaries(paged.map((c) => c.id).toList());
    final enriched = paged.map((c) {
      final s = photoSummaries[c.id];
      if (s == null) return c;
      final thumb = s['firstThumbnailUrl'] as String?;
      return c.copyWith(
        photoCount: s['photoCount'] as int,
        photos: s['photos'] as List<CustomerPhotoModel>,
        firstThumbnailUrl: thumb,
        imageUrl: thumb ?? c.imageUrl,
      );
    }).toList();

    return CustomerDirectoryResponse(
      items: enriched,
      counts: CustomerTabCounts(
        total: allModels.length,
        verified: verifiedCount,
        temporary: temporaryCount,
        noLocation: noLocationCount,
      ),
      pagination: CustomerPagination(
        total: filtered.length,
        limit: effLimit,
        offset: effOffset,
        hasMore: effOffset + paged.length < filtered.length,
      ),
    );
  }
}
