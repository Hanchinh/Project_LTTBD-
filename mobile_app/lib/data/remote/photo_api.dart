import 'package:delivery_marker_mobile/models/customer_photo_model.dart';
import 'package:delivery_marker_mobile/data/remote/api_client.dart';

/// Module API phụ trách xem, tải lên, xóa ảnh và tạo URL ảnh kèm xác thực cho khách hàng.
class PhotoApi {
  static Future<Map<String, String>> getPhotoAuthInfo(
    String photoPath, {
    int? cacheVersion,
    bool bustCache = false,
  }) async {
    final token = await ApiClient.getToken();
    final baseUrl = await ApiClient.getBaseUrl();

    String fullUrl;
    if (photoPath.startsWith('http://') || photoPath.startsWith('https://')) {
      fullUrl = photoPath;
    } else {
      final uri = Uri.parse(baseUrl);
      final origin = '${uri.scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}';
      final cleanPath = photoPath.startsWith('/') ? photoPath : '/$photoPath';
      fullUrl = '$origin$cleanPath';
    }

    if (cacheVersion != null) {
      fullUrl += fullUrl.contains('?') ? '&v=$cacheVersion' : '?v=$cacheVersion';
    } else if (bustCache) {
      final now = DateTime.now().millisecondsSinceEpoch;
      fullUrl += fullUrl.contains('?') ? '&v=$now' : '?v=$now';
    }

    if (token != null && token.isNotEmpty) {
      fullUrl += fullUrl.contains('?')
          ? '&token=${Uri.encodeComponent(token)}'
          : '?token=${Uri.encodeComponent(token)}';
    }

    return {
      'url': fullUrl,
      'token': token ?? '',
    };
  }

  static Future<List<CustomerPhotoModel>> getCustomerPhotos(String customerId) async {
    try {
      final response = await ApiClient.get(
        '/customers/$customerId/photos',
        timeout: const Duration(seconds: 15),
      );

      if (response is Map && response['success'] == true) {
        final List list = response['data'] as List? ?? [];
        return list
            .map((item) => CustomerPhotoModel.fromJson(item as Map<String, dynamic>, defaultCustomerId: customerId))
            .toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  static Future<CustomerPhotoModel> addCustomerPhoto(String customerId, String imageBase64) async {
    final response = await ApiClient.post(
      '/customers/$customerId/photos',
      body: {'imageBase64': imageBase64},
      timeout: const Duration(seconds: 30),
    );

    if (response is Map && (response['success'] == true || response['statusCode'] == 201)) {
      return CustomerPhotoModel.fromJson(response['data'] as Map<String, dynamic>, defaultCustomerId: customerId);
    }
    throw Exception(response['message'] ?? 'Không thể tải ảnh lên');
  }

  static Future<void> deleteCustomerPhoto(String customerId, String photoId) async {
    final response = await ApiClient.delete(
      '/customers/$customerId/photos/$photoId',
      timeout: const Duration(seconds: 15),
    );

    if (response is Map && response['success'] == true) {
      return;
    }
    throw Exception(response['message'] ?? 'Không thể xóa ảnh');
  }
}

