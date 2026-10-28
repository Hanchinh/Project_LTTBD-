import 'package:flutter/material.dart';

/// Cấu hình tập trung cho toàn bộ nguồn Tile Bản đồ của ứng dụng (TASK: LOCAL-FIRST-09)
/// Đưa toàn bộ URL, fallback, subdomains, user agent và chuỗi bản quyền (Attribution) về một nơi duy nhất.
class MapConfig {
  MapConfig._();

  /// Nguồn mặc định: Google Maps Roads (lyrs=m)
  static const String googleRoadsUrl = 'https://mt1.google.com/vt/lyrs=m&x={x}&y={y}&z={z}';

  /// Google Maps Hybrid / Satellite + Tên đường (lyrs=y)
  static const String googleHybridUrl = 'https://mt1.google.com/vt/lyrs=y&x={x}&y={y}&z={z}';

  /// CartoDB Voyager Basemap
  static const String cartoVoyagerUrl = 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png';

  /// Fallback URL khi tile chính gặp sự cố
  static const String fallbackUrl = 'https://a.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png';

  /// OpenStreetMap Standard Tile URL
  static const String openStreetMapUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  /// Subdomains cho CartoDB
  static const List<String> cartoSubdomains = ['a', 'b', 'c', 'd'];

  /// Tên gói User-Agent cho các yêu cầu HTTP tile
  static const String userAgentPackageName = 'com.example.delivery_marker_mobile';

  /// Tên các chế độ bản đồ trong app
  static const List<String> mapTypeNames = [
    'Bản đồ đường phố',
    'Ảnh vệ tinh + Tên đường',
    'Bản đồ CartoDB Voyager',
  ];

  /// Lấy URL template theo loại bản đồ (0: Roads, 1: Hybrid/Satellite, 2: CartoDB Voyager)
  static String getUrlTemplate(int mapType) {
    switch (mapType) {
      case 1:
        return googleHybridUrl;
      case 2:
        return cartoVoyagerUrl;
      case 0:
      default:
        return googleRoadsUrl;
    }
  }

  /// Lấy subdomains theo loại bản đồ
  static List<String> getSubdomains(int mapType) {
    if (mapType == 2) {
      return cartoSubdomains;
    }
    return const [];
  }

  /// Hiển thị thông báo khi đổi kiểu bản đồ
  static void showMapTypeSnackBar(BuildContext context, int newMapType) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Đã chuyển sang: ${mapTypeNames[newMapType]}'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Thông tin ghi công / bản quyền nguồn bản đồ (Attribution)
  static const String defaultAttribution = 'Google Maps (Mặc định) / CARTO / OpenStreetMap';
  static const String legalNotice = 'Dữ liệu bản đồ được cung cấp bởi các dịch vụ bản đồ trực tuyến. Không chứa dữ liệu cá nhân khách hàng.';
}

