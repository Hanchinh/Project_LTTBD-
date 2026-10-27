import 'package:flutter/material.dart';
import 'repositories/local/local_photo_repository.dart';
import 'repositories/repository_provider.dart';
import 'services/api_service.dart';
import 'views/home_shell_view.dart';
import 'views/login_view.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DeliveryLocationMarkerApp());
}

class DeliveryLocationMarkerApp extends StatelessWidget {
  const DeliveryLocationMarkerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Định Vị Giao Hàng',
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
    }
    final token = await ApiService.getToken();
    if (!mounted) return;

    if (isLocalMode || (token != null && token.isNotEmpty)) {
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
