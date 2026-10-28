import 'dart:math';

/// Bộ sinh định danh chuẩn UUID v4 thuần Dart
/// Đảm bảo tính duy nhất ngẫu nhiên cao cho các thực thể Local-First mà không cần thư viện ngoài.
class UuidUtils {
  static final Random _random = Random.secure();

  /// Sinh một chuỗi UUID v4 chuẩn (36 ký tự, định dạng xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx)
  static String generate() {
    final bytes = List<int>.generate(16, (i) => _random.nextInt(256));
    // Set version bits (0100 for v4)
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    // Set variant bits (10xx for RFC 4122)
    bytes[8] = (bytes[8] & 0x3f) | 0x80;

    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20, 32)}';
  }
}
