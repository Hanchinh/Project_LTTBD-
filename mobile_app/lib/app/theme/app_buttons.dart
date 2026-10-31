import 'package:flutter/material.dart';

/// Bộ phong cách nút hành động tập trung của toàn app (TASK: DIRECTORY-BULK-SHIFT-NAME-BLACK-BUTTONS-022A)
/// - Tông màu chủ đạo: Navy/đen #0F172A, chữ trắng
/// - Nút phụ: Nền trắng, viền đen #0F172A, chữ đen #0F172A
/// - Vùng chạm chuẩn: tối thiểu 48px, tại thẻ điểm chi tiết/thao tác chính là >= 56px
/// - KHÔNG đổi: Chấm/marker trạng thái xanh/cam/xám, chip trạng thái ca, nút xóa màu đỏ.
class AppButtons {
  AppButtons._();

  /// Màu Navy/đen chuẩn toàn ứng dụng
  static const Color primaryColor = Color(0xFF0F172A);
  static const Color navy = primaryColor;

  /// Nút hành động chính (ElevatedButton)
  /// Nền Navy/đen #0F172A, chữ trắng
  static ButtonStyle primary({
    double minHeight = 48.0,
    double borderRadius = 12.0,
    EdgeInsetsGeometry? padding,
  }) {
    return ElevatedButton.styleFrom(
      backgroundColor: primaryColor,
      foregroundColor: Colors.white,
      disabledBackgroundColor: const Color(0xFF94A3B8),
      disabledForegroundColor: const Color(0xFFF1F5F9),
      elevation: 2,
      shadowColor: primaryColor.withValues(alpha: 0.3),
      minimumSize: Size(minHeight, minHeight),
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      textStyle: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.3,
      ),
    );
  }

  /// Nút hành động nổi bật lớn (>= 56px) cho thẻ điểm / bottom sheet thao tác một tay
  static ButtonStyle primaryLarge({
    double minHeight = 56.0,
    double borderRadius = 14.0,
    EdgeInsetsGeometry? padding,
  }) {
    return primary(
      minHeight: minHeight,
      borderRadius: borderRadius,
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    );
  }

  /// Nút hành động phụ (OutlinedButton)
  /// Nền trắng, viền đen #0F172A, chữ #0F172A
  static ButtonStyle secondary({
    double minHeight = 48.0,
    double borderRadius = 12.0,
    EdgeInsetsGeometry? padding,
  }) {
    return OutlinedButton.styleFrom(
      foregroundColor: primaryColor,
      backgroundColor: Colors.white,
      disabledForegroundColor: const Color(0xFF94A3B8),
      side: const BorderSide(color: primaryColor, width: 1.5),
      minimumSize: Size(minHeight, minHeight),
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      textStyle: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.3,
      ),
    );
  }

  /// Nút phụ lớn (>= 56px)
  static ButtonStyle secondaryLarge({
    double minHeight = 56.0,
    double borderRadius = 14.0,
    EdgeInsetsGeometry? padding,
  }) {
    return secondary(
      minHeight: minHeight,
      borderRadius: borderRadius,
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    );
  }

  /// Nút dạng TextButton với vùng chạm >= 48px
  static ButtonStyle text({
    double minHeight = 48.0,
    Color color = primaryColor,
  }) {
    return TextButton.styleFrom(
      foregroundColor: color,
      minimumSize: Size(minHeight, minHeight),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      textStyle: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}
