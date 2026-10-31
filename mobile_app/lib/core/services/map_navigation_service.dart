import 'package:url_launcher/url_launcher.dart';

/// Dịch vụ hỗ trợ mở ứng dụng bản đồ dẫn đường bên ngoài (Google Maps, Apple Maps...)
class MapNavigationService {
  /// Mở ứng dụng chỉ đường ngoài tới tọa độ [lat], [lng].
  /// Ưu tiên intent ứng dụng Google Maps native; nếu thất bại sẽ mở qua trình duyệt web.
  static Future<void> openExternalNavigation(double lat, double lng) async {
    final appUrl = Uri.parse('google.navigation:q=$lat,$lng&mode=d');
    final webUrl = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');

    try {
      if (await canLaunchUrl(appUrl)) {
        await launchUrl(appUrl);
      } else if (await canLaunchUrl(webUrl)) {
        await launchUrl(webUrl, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      if (await canLaunchUrl(webUrl)) {
        await launchUrl(webUrl, mode: LaunchMode.externalApplication);
      }
    }
  }
}

/// Bí danh tương thích
typedef MapNavigationHelper = MapNavigationService;
