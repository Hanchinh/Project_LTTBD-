// Cấu hình chủ đề giao diện Material 3 toàn ứng dụng (Light & Dark theme).
// Quản lý màu sắc thương hiệu, font chữ và phong cách hiển thị thích ứng.
import 'package:flutter/material.dart';

/// Hệ thống Token màu và Chủ đề (Theme) chuẩn Material 3 của ứng dụng
class AppTheme {
  AppTheme._();

  // Bảng màu nhận diện thương hiệu
  static const Color primaryNavy = Color(0xFF0F172A);
  static const Color accentBlue = Color(0xFF2563EB);
  static const Color lightBg = Color(0xFFF8FAFC);
  static const Color lightSurface = Colors.white;
  static const Color lightBorder = Color(0xFFE2E8F0);
  static const Color lightText = Color(0xFF0F172A);
  static const Color lightSubtext = Color(0xFF64748B);

  // Bảng màu Dark Mode chống chói ban đêm cho tài xế
  static const Color darkBg = Color(0xFF0B0F19);
  static const Color darkSurface = Color(0xFF1E293B);
  static const Color darkBorder = Color(0xFF334155);
  static const Color darkText = Color(0xFFF1F5F9);
  static const Color darkSubtext = Color(0xFF94A3B8);

  // Trạng thái nghiệp vụ
  static const Color statusGreen = Color(0xFF15803D);
  static const Color statusGreenBg = Color(0xFFDCFCE7);
  static const Color statusAmber = Color(0xFFD97706);
  static const Color statusAmberBg = Color(0xFFFEF3C7);
  static const Color statusRed = Color(0xFFEF4444);

  /// Chủ đề ban ngày (Light Theme) tối ưu tương phản ngoài trời nắng
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: lightBg,
      colorScheme: const ColorScheme.light(
        primary: primaryNavy,
        onPrimary: Colors.white,
        secondary: accentBlue,
        onSecondary: Colors.white,
        surface: lightSurface,
        onSurface: lightText,
        error: statusRed,
        onError: Colors.white,
        outline: lightBorder,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: lightSurface,
        foregroundColor: lightText,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: lightSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: lightBorder),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: lightBorder,
        thickness: 1,
        space: 1,
      ),
    );
  }

  /// Chủ đề ban đêm (Dark Theme) chống chói mắt khi chạy ca tối
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: darkBg,
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFF38BDF8),
        onPrimary: primaryNavy,
        secondary: Color(0xFF60A5FA),
        onSecondary: primaryNavy,
        surface: darkSurface,
        onSurface: darkText,
        error: Color(0xFFF87171),
        onError: primaryNavy,
        outline: darkBorder,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: darkSurface,
        foregroundColor: darkText,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: darkSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: darkBorder),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: darkBorder,
        thickness: 1,
        space: 1,
      ),
    );
  }

  // Tiện ích kiểm tra và lấy màu ngữ cảnh
  static bool isDark(BuildContext context) => Theme.of(context).brightness == Brightness.dark;
  static Color surface(BuildContext context) => Theme.of(context).colorScheme.surface;
  static Color background(BuildContext context) => Theme.of(context).scaffoldBackgroundColor;
  static Color text(BuildContext context) => Theme.of(context).colorScheme.onSurface;
  static Color subtext(BuildContext context) => isDark(context) ? darkSubtext : lightSubtext;
  static Color border(BuildContext context) => isDark(context) ? darkBorder : lightBorder;
}
