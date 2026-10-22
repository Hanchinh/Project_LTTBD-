import 'package:flutter/material.dart';
import 'services/api_service.dart';
import 'views/login_view.dart';
import 'views/order_list_view.dart';

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
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1E88E5),
          primary: const Color(0xFF1E88E5),
          secondary: const Color(0xFF2E7D32),
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 2,
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
    final token = await ApiService.getToken();
    if (!mounted) return;

    if (token != null && token.isNotEmpty) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const OrderListView()),
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
