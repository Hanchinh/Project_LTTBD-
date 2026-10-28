import 'package:delivery_marker_mobile/models/address_search_result.dart';
import 'package:delivery_marker_mobile/data/remote/api_client.dart';

/// Module API phụ trách tìm kiếm địa chỉ geocoding (OpenStreetMap Nominatim / Geocoding Service).
class GeocodingApi {
  static Future<List<AddressSearchResult>> searchAddress(String query) async {
    if (query.trim().length < 2) return [];

    final encodedQuery = Uri.encodeComponent(query.trim());
    final response = await ApiClient.get(
      '/geocoding/search?q=$encodedQuery',
      timeout: const Duration(seconds: 8),
    );

    if (response is Map && response['success'] == true) {
      final List list = response['data'] ?? [];
      return list.map((item) => AddressSearchResult.fromJson(item as Map<String, dynamic>)).toList();
    }
    throw Exception(response['message'] ?? 'Không thể tìm kiếm địa chỉ');
  }
}

