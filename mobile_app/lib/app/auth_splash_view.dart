// Màn hình Splash khởi động ứng dụng định vị giao hàng.
// Xử lý dọn ảnh tạm quá hạn, kiểm tra mở lần đầu và mở khóa mã PIN bảo mật.
import 'package:flutter/material.dart';
import 'package:delivery_marker_mobile/data/repository_provider.dart';
import 'package:delivery_marker_mobile/app/home_shell_view.dart';
import 'package:delivery_marker_mobile/features/onboarding_lock/welcome_onboarding_view.dart';
import 'package:delivery_marker_mobile/features/onboarding_lock/pin_lock_view.dart';

/// Màn hình Splash khởi động ứng dụng:
/// 1. Tự động dọn dẹp các ảnh đã xóa mềm quá 30 ngày.
/// 2. Điều hướng sang WelcomeOnboardingView nếu người dùng mở app lần đầu.
/// 3. Khóa bằng PinLockScreen nếu đã cài mã PIN.
/// 4. Mở trực tiếp HomeShellView.
class AuthSplashScreen extends StatefulWidget {
  const AuthSplashScreen({super.key});

  @override
  State<AuthSplashScreen> createState() => _AuthSplashScreenState();
}

class _AuthSplashScreenState extends State<AuthSplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuthState();
  }

  Future<void> _checkAuthState() async {
    try {
      final photoRepo = RepositoryProvider.photo;
      photoRepo.purgeDeletedPhotosOlderThan().catchError((_) => 0);

      // 1. Kiểm tra lần đầu mở app -> Màn chào WelcomeOnboardingView
      final isFirst = await RepositoryProvider.localProfile.isFirstOpen();
      if (!mounted) return;
      if (isFirst) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const WelcomeOnboardingView()),
        );
        return;
      }

      // 2. Kiểm tra mã PIN khóa app
      final needPin = await RepositoryProvider.localProfile.shouldLockApp();
      if (!mounted) return;
      if (needPin) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => PinLockScreen(
              onSuccess: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const HomeShellView()),
                );
              },
            ),
          ),
        );
        return;
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomeShellView()),
      );
    } catch (_) {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomeShellView()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFFF4F6F9),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.location_on_rounded, size: 72, color: Color(0xFF1E88E5)),
            SizedBox(height: 16),
            Text(
              'HỆ THỐNG ĐỊNH VỊ GIAO HÀNG',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
                color: Color(0xFF1565C0),
              ),
            ),
            SizedBox(height: 24),
            CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}

