import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:delivery_marker_mobile/models/order_model.dart';
import 'package:delivery_marker_mobile/models/shift_model.dart';
import 'package:delivery_marker_mobile/models/location_model.dart';
import 'package:delivery_marker_mobile/data/remote/offline_storage_service.dart';
import 'package:delivery_marker_mobile/data/remote/api_client.dart';

/// Module API phụ trách quản lý ca làm việc, thêm/sửa/xóa điểm giao trong ca và đơn hàng legacy.
class ShiftApi {
  static Future<List<ShiftModel>> getShifts() async {
    final response = await ApiClient.get(
      '/shifts',
      timeout: const Duration(seconds: 12),
    );

    if (response is Map && response['success'] == true) {
      final List list = response['data'] ?? [];
      return list.map((item) => ShiftModel.fromJson(item as Map<String, dynamic>)).toList();
    }
    throw Exception(response['message'] ?? 'Không thể tải danh sách ca làm');
  }

  static Future<ShiftModel> createShift({String? shiftDate, String? shiftName, String? notes}) async {
    final response = await ApiClient.post(
      '/shifts',
      body: {
        if (shiftDate != null) ...{
          'shiftDate': shiftDate,
          'workDate': shiftDate,
        },
        if (shiftName != null && shiftName.trim().isNotEmpty) 'shiftName': shiftName.trim(),
        if (notes != null) 'notes': notes,
      },
      timeout: const Duration(seconds: 12),
    );

    if (response is Map && (response['success'] == true || response['statusCode'] == 201)) {
      return ShiftModel.fromJson(response['data']);
    }
    throw Exception(response['message'] ?? 'Không thể tạo ca làm mới');
  }

  static Future<ShiftModel> updateShiftName(String shiftId, String shiftName) async {
    final response = await ApiClient.put(
      '/shifts/$shiftId/name',
      body: {'shiftName': shiftName.trim()},
      timeout: const Duration(seconds: 12),
    );

    if (response is Map && response['success'] == true) {
      return ShiftModel.fromJson(response['data']);
    }
    throw Exception(response['message'] ?? 'Không thể đổi tên ca làm việc');
  }

  static Future<bool> deleteShift(String shiftId) async {
    final response = await ApiClient.delete(
      '/shifts/$shiftId',
      timeout: const Duration(seconds: 12),
    );

    if (response is Map && response['success'] == true) {
      return true;
    }
    throw Exception(response['message'] ?? 'Không thể xóa ca làm việc');
  }

  static Future<ShiftModel> getShiftDetail(String shiftId) async {
    final response = await ApiClient.get(
      '/shifts/$shiftId',
      timeout: const Duration(seconds: 12),
    );

    if (response is Map && response['success'] == true) {
      return ShiftModel.fromJson(response['data']);
    }
    throw Exception(response['message'] ?? 'Không thể tải chi tiết ca làm');
  }

  static Future<ShiftModel> updateShiftStatus(String shiftId, ShiftStatus status) async {
    final response = await ApiClient.put(
      '/shifts/$shiftId/status',
      body: {'status': status.toApiString()},
      timeout: const Duration(seconds: 12),
    );

    if (response is Map && response['success'] == true) {
      return ShiftModel.fromJson(response['data']);
    }
    throw Exception(response['message'] ?? 'Không thể cập nhật trạng thái ca làm');
  }

  static Future<Map<String, dynamic>> addPointToShift(
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
  }) async {
    final response = await ApiClient.post(
      '/shifts/$shiftId/points',
      body: {
        if (customerId != null) 'customerId': customerId,
        if (phoneNumber != null) 'phoneNumber': phoneNumber,
        if (createIfNotFound) 'createIfNotFound': true,
        if (fullName != null && fullName.isNotEmpty) 'fullName': fullName,
        if (addressText != null && addressText.isNotEmpty) 'addressText': addressText,
        if (orderId != null) 'orderId': orderId,
        if (sequenceNumber != null) 'sequenceNumber': sequenceNumber,
        if (deliveryNotes != null) 'deliveryNotes': deliveryNotes,
        if (areaId != null) 'areaId': areaId,
      },
      timeout: const Duration(seconds: 12),
    );

    if (response is Map && response['success'] == true) {
      return {
        'isExisting': response['isExisting'] ?? false,
        'message': response['message'] ?? 'Thành công',
        'point': ShiftDeliveryPointModel.fromJson(response['data']),
        'summary': ShiftSummaryModel.fromJson(response['summary'] as Map<String, dynamic>?),
      };
    }
    throw Exception(response['message'] ?? 'Không thể thêm điểm giao vào ca');
  }

  static Future<Map<String, dynamic>> quickCreateCustomerAndAddToShift({
    required String shiftId,
    required String phoneNumber,
    String? fullName,
    String? addressText,
    String? deliveryNotes,
    String? areaId,
  }) async {
    return addPointToShift(
      shiftId,
      phoneNumber: phoneNumber,
      createIfNotFound: true,
      fullName: fullName,
      addressText: addressText,
      deliveryNotes: deliveryNotes,
      areaId: areaId,
    );
  }

  static Future<void> removePointFromShift(String shiftId, String pointId) async {
    final response = await ApiClient.delete(
      '/shifts/$shiftId/points/$pointId',
      timeout: const Duration(seconds: 12),
    );

    if (response is Map && response['success'] == true) {
      return;
    }
    throw Exception(response['message'] ?? 'Không thể xóa điểm giao');
  }

  static Future<BulkAddPointsResult> addBulkPointsToShift({
    required String shiftId,
    String? rawText,
    List<String>? phones,
    String? areaId,
  }) async {
    final response = await ApiClient.post(
      '/shifts/$shiftId/points/bulk',
      body: {
        if (rawText != null) 'rawText': rawText,
        if (phones != null) 'phones': phones,
        if (areaId != null) 'areaId': areaId,
      },
      timeout: const Duration(seconds: 25),
    );

    if (response is Map && response['success'] == true) {
      return BulkAddPointsResult.fromJson(response['data']);
    }
    throw Exception(response['message'] ?? 'Không thể thêm danh sách SĐT vào ca');
  }

  static Future<ShiftDeliveryPointModel> updateTemporaryLocation(
    String shiftId,
    String pointId, {
    required double latitude,
    required double longitude,
    String? locationNotes,
    String? identificationNotes,
  }) async {
    final notes = locationNotes ?? identificationNotes;
    final response = await ApiClient.put(
      '/shifts/$shiftId/points/$pointId/temporary-location',
      body: {
        'latitude': latitude,
        'longitude': longitude,
        if (notes != null) ...{
          'locationNotes': notes,
          'identificationNotes': notes,
        },
      },
      timeout: const Duration(seconds: 12),
    );

    if (response is Map && response['success'] == true) {
      return ShiftDeliveryPointModel.fromJson(response['data']);
    }
    throw Exception(response['message'] ?? 'Không thể lưu vị trí tạm');
  }

  // Legacy Order APIs
  static Future<List<OrderModel>> getMyShiftOrders() async {
    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity == ConnectivityResult.none) {
      return await OfflineStorageService.getCachedOrders();
    }

    try {
      final response = await ApiClient.get(
        '/orders/my-shift',
        timeout: const Duration(seconds: 10),
      );

      if (response is Map) {
        final List list = response['data'] ?? [];
        final orders = list.map((e) => OrderModel.fromJson(e)).toList();
        await OfflineStorageService.cacheOrders(orders);
        return orders;
      }
      throw Exception('Không thể tải danh sách đơn hàng');
    } catch (e) {
      final cached = await OfflineStorageService.getCachedOrders();
      if (cached.isNotEmpty) return cached;
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> addOrderToShift({
    required String customerId,
    bool allowMultiple = false,
    String? idempotencyKey,
  }) async {
    final response = await ApiClient.post(
      '/orders/my-shift',
      body: {
        'customerId': customerId,
        'allowMultiple': allowMultiple,
        if (idempotencyKey != null) 'idempotencyKey': idempotencyKey,
      },
      timeout: const Duration(seconds: 12),
    );

    if (response is Map) {
      return {
        'isExisting': response['isExisting'] ?? false,
        'message': response['message'] ?? 'Thành công',
        'order': OrderModel.fromJson(response['data']),
      };
    }
    throw Exception('Không thể thêm điểm giao vào ca');
  }

  static Future<int> getPendingSyncCount() async {
    return await OfflineStorageService.getPendingCount();
  }

  static Future<void> syncOfflineQueue() async {
    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity == ConnectivityResult.none) return;

    final token = await ApiClient.getToken();
    if (token == null) return;

    final queue = await OfflineStorageService.getPendingSyncQueue();
    for (var item in queue) {
      try {
        final loc = SavedLocationModel(
          customerId: item['customerId'],
          latitude: (item['latitude'] as num).toDouble(),
          longitude: (item['longitude'] as num).toDouble(),
          gpsAccuracy: (item['gpsAccuracy'] as num).toDouble(),
          identificationNotes: item['identificationNotes'] ?? '',
          imageUrl: item['imageUrl'],
        );

        final payload = <String, dynamic>{
          'latitude': loc.latitude,
          'longitude': loc.longitude,
          'gpsAccuracy': loc.gpsAccuracy,
          'identificationNotes': loc.identificationNotes,
          if (item['imageBase64'] != null) 'imageBase64': item['imageBase64'],
        };

        final response = await ApiClient.post(
          '/customers/${loc.customerId}/location',
          body: payload,
        );

        if (response != null) {
          await OfflineStorageService.clearSyncQueueItem(item['id']);
        } else {
          await OfflineStorageService.incrementRetry(item['id'], item['retryCount'] ?? 0);
        }
      } catch (e) {
        await OfflineStorageService.incrementRetry(item['id'], item['retryCount'] ?? 0);
      }
    }
  }
}

