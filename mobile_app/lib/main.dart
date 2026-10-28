import 'package:flutter/material.dart';
import 'package:delivery_marker_mobile/data/local/local_photo_repository.dart';
import 'package:delivery_marker_mobile/data/repositories/repository_provider.dart';
import 'package:delivery_marker_mobile/data/remote/api_service.dart';
import 'package:delivery_marker_mobile/home_shell_view.dart';
import 'package:delivery_marker_mobile/features/server_mode/login_view.dart';
import 'package:delivery_marker_mobile/features/onboarding_lock/pin_lock_screen.dart';
import 'package:delivery_marker_mobile/features/onboarding_lock/welcome_onboarding_view.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DeliveryLocationMarkerApp());
}

class DeliveryLocationMarkerApp extends StatelessWidget {
  const DeliveryLocationMarkerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ghim Điểm Giao Hàng',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0F172A),
          primary: const Color(0xFF0F172A),
          secondary: const Color(0xFF2563EB),
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
      ),
      home: const AuthSplashScreen(),
    );
  }
}

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
    final isLocalMode = RepositoryProvider.useLocalData;
    if (isLocalMode) {
      final photoRepo = RepositoryProvider.photo;
      if (photoRepo is LocalPhotoRepository) {
        photoRepo.purgeDeletedPhotosOlderThan().catchError((_) => 0);
      }

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
      return;
    }

    final token = await ApiService.getToken();
    if (!mounted) return;

    if (token != null && token.isNotEmpty) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomeShellView()),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginView()),
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
