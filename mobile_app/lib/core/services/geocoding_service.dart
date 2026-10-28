import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:delivery_marker_mobile/models/address_search_result.dart';

/// Dịch vụ tìm kiếm địa chỉ trực tiếp qua OpenStreetMap Nominatim
/// Chạy độc lập trong chế độ Local-First (không phụ thuộc vào máy chủ backend riêng).
class GeocodingService {
  /// Tìm kiếm gợi ý địa chỉ dựa trên từ khóa người dùng nhập.
  /// Đầu vào: chuỗi tìm kiếm [query].
  /// Đầu ra: danh sách [AddressSearchResult] chứa tên hiển thị và tọa độ lat/lng.
  static Future<List<AddressSearchResult>> searchAddress(String query) async {
    final trimmed = query.trim();
    if (trimmed.length < 2) return [];

    try {
      final encodedQuery = Uri.encodeComponent(trimmed);
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=$encodedQuery&format=json&addressdetails=1&limit=5&countrycodes=vn',
      );
      final response = await http.get(
        uri,
        headers: {'User-Agent': 'DeliveryMarkerApp/1.0 (Local-First Flutter App)'},
      ).timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final List list = jsonDecode(response.body) as List;
        return list.map((item) {
          final lat = double.tryParse(item['lat']?.toString() ?? '') ?? 0.0;
          final lon = double.tryParse(item['lon']?.toString() ?? '') ?? 0.0;
          return AddressSearchResult(
            displayName: item['display_name'] as String? ?? '',
            latitude: lat,
            longitude: lon,
            source: 'nominatim',
          );
        }).toList();
      }
      return [];
    } catch (_) {
      // Khi mất mạng hoặc timeout, trả về danh sách rỗng an toàn
      return [];
    }
  }
}

