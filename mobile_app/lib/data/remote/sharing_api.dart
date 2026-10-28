import 'package:delivery_marker_mobile/models/data_share_model.dart';
import 'package:delivery_marker_mobile/data/remote/api_client.dart';

/// Module API phụ trách chia sẻ dữ liệu trực tuyến qua máy chủ tập trung (Server Mode).
class SharingApi {
  static Future<DataShareModel> createShare({
    required String recipientPhone,
    required String scope,
    String? shiftId,
    bool includePhotos = false,
    int? expiresInDays,
  }) async {
    final response = await ApiClient.post(
      '/shares',
      body: {
        'recipientPhone': recipientPhone,
        'scope': scope,
        if (shiftId != null) 'shiftId': shiftId,
        'includePhotos': includePhotos,
        if (expiresInDays != null) 'expiresInDays': expiresInDays,
      },
      timeout: const Duration(seconds: 15),
    );

    if (response is Map && (response['success'] == true || response['statusCode'] == 201)) {
      return DataShareModel.fromJson(response['data'] as Map<String, dynamic>);
    }
    throw Exception(response['message'] ?? 'Không gửi được lời mời, kiểm tra số điện thoại');
  }

  static Future<List<DataShareModel>> getOutgoingShares() async {
    final response = await ApiClient.get(
      '/shares/outgoing',
      timeout: const Duration(seconds: 15),
    );

    if (response is Map && response['success'] == true) {
      final List list = response['data'] ?? [];
      return list.map((item) => DataShareModel.fromJson(item as Map<String, dynamic>)).toList();
    }
    throw Exception(response['message'] ?? 'Không thể tải danh sách chia sẻ');
  }

  static Future<List<DataShareModel>> getIncomingShares() async {
    final response = await ApiClient.get(
      '/shares/incoming',
      timeout: const Duration(seconds: 15),
    );

    if (response is Map && response['success'] == true) {
      final List list = response['data'] ?? [];
      return list.map((item) => DataShareModel.fromJson(item as Map<String, dynamic>)).toList();
    }
    throw Exception(response['message'] ?? 'Không thể tải danh sách chia sẻ');
  }

  static Future<void> acceptShare(String shareId) async {
    final response = await ApiClient.post(
      '/shares/$shareId/accept',
      timeout: const Duration(seconds: 15),
    );

    if (response is Map && response['success'] == true) {
      return;
    }
    throw Exception(response['message'] ?? 'Không thể chấp nhận lời mời');
  }

  static Future<void> declineShare(String shareId) async {
    final response = await ApiClient.post(
      '/shares/$shareId/decline',
      timeout: const Duration(seconds: 15),
    );

    if (response is Map && response['success'] == true) {
      return;
    }
    throw Exception(response['message'] ?? 'Không thể từ chối lời mời');
  }

  static Future<void> revokeShare(String shareId) async {
    final response = await ApiClient.post(
      '/shares/$shareId/revoke',
      timeout: const Duration(seconds: 15),
    );

    if (response is Map && response['success'] == true) {
      return;
    }
    throw Exception(response['message'] ?? 'Không thể dừng chia sẻ');
  }

  static Future<Map<String, dynamic>> getSharedLocations() async {
    final response = await ApiClient.get(
      '/shares/shared-locations',
      timeout: const Duration(seconds: 15),
    );

    if (response is Map && response['success'] == true) {
      final data = response['data'] as Map<String, dynamic>? ?? {};
      final List rawLocs = data['locations'] as List? ?? [];
      final locations = rawLocs
          .map((e) => SharedLocationPointModel.fromJson(e as Map<String, dynamic>))
          .toList();
      final totalCount = (data['totalCount'] as num?)?.toInt() ?? locations.length;
      final skippedOutOfAreaCount = (data['skippedOutOfAreaCount'] as num?)?.toInt() ?? 0;

      return {
        'locations': locations,
        'totalCount': totalCount,
        'skippedOutOfAreaCount': skippedOutOfAreaCount,
      };
    }
    throw Exception(response['message'] ?? 'Không thể tải điểm chia sẻ');
  }

  static Future<Map<String, dynamic>> importSharedLocations(
    String shareId, {
    List<String>? customerIds,
    bool all = true,
    bool replaceExisting = false,
  }) async {
    final response = await ApiClient.post(
      '/shares/$shareId/import',
      body: {
        if (customerIds != null) 'customerIds': customerIds,
        'all': all,
        'replaceExisting': replaceExisting,
      },
      timeout: const Duration(seconds: 20),
    );

    if (response is Map && response['success'] == true) {
      return response['data'] as Map<String, dynamic>? ?? {};
    }
    throw Exception(response['message'] ?? 'Không thể nhập điểm chia sẻ');
  }
}

