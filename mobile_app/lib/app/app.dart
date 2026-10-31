import 'package:flutter/material.dart';
import 'package:delivery_marker_mobile/app/theme/app_theme.dart';
import 'package:delivery_marker_mobile/app/auth_splash_view.dart';

/// Ứng dụng Quản lý & Ghim Điểm Giao Hàng (Kiến trúc Local-First, không cần máy chủ)
class DeliveryLocationMarkerApp extends StatelessWidget {
  const DeliveryLocationMarkerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ghim Điểm Giao Hàng',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      home: const AuthSplashScreen(),
    );
  }
}
