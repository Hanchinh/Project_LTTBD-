import 'package:flutter/material.dart';
import 'package:delivery_marker_mobile/data/repository_provider.dart';
import 'package:delivery_marker_mobile/home_shell_view.dart';

/// Màn hình chào mừng khi mở ứng dụng lần đầu tiên (Local-First)
class WelcomeOnboardingView extends StatefulWidget {
  final VoidCallback? onStartFinished;
  const WelcomeOnboardingView({super.key, this.onStartFinished});

  @override
  State<WelcomeOnboardingView> createState() => _WelcomeOnboardingViewState();
}

class _WelcomeOnboardingViewState extends State<WelcomeOnboardingView> {
  final TextEditingController _nameController = TextEditingController();
  bool _isSubmitting = false;

  Future<void> _handleStart({bool isSkipped = false}) async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    try {
      final name = isSkipped ? null : _nameController.text.trim();
      await RepositoryProvider.localProfile.completeFirstOpen(
        displayName: name != null && name.isNotEmpty ? name : null,
      );

      if (!mounted) return;
      if (widget.onStartFinished != null) {
        widget.onStartFinished!();
        return;
      }
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeShellView()),
      );
    } catch (_) {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Logo / Icon
                  Center(
                    child: Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: const Color(0xFFBFDBFE), width: 1.5),
                      ),
                      child: const Icon(
                        Icons.local_shipping_rounded,
                        color: Color(0xFF2563EB),
                        size: 48,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  const Text(
                    'CHÀO MỪNG BẠN!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),

                  const Text(
                    'Định Vị Giao Hàng hoạt động hoàn toàn trên thiết bị của bạn (Local-First). Không cần tài khoản máy chủ, tra cứu vị trí siêu tốc ngay cả khi mất mạng.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF64748B),
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Khung nhập tên
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Họ và tên của bạn',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          key: const Key('welcome_display_name_input'),
                          controller: _nameController,
                          textCapitalization: TextCapitalization.words,
                          decoration: InputDecoration(
                            hintText: 'VD: Nguyễn Văn Shipper',
                            hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                            prefixIcon: const Icon(Icons.person_outline_rounded, color: Color(0xFF64748B)),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Tên này dùng để hiển thị trên ứng dụng. Bạn có thể thay đổi bất kỳ lúc nào tại mục Cá nhân.',
                          style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Nút Bắt đầu ngay
                  SizedBox(
                    height: 56,
                    child: ElevatedButton(
                      key: const Key('welcome_start_btn'),
                      onPressed: _isSubmitting ? null : () => _handleStart(isSkipped: false),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                            )
                          : const Text('BẮT ĐẦU NGAY'),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Nút Bỏ qua
                  SizedBox(
                    height: 48,
                    child: TextButton(
                      key: const Key('welcome_skip_btn'),
                      onPressed: _isSubmitting ? null : () => _handleStart(isSkipped: true),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF64748B),
                        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                      child: const Text('Bỏ qua, dùng tên mặc định'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
