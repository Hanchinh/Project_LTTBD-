import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_buttons.dart';
import 'home_shell_view.dart';

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadSavedPhone();
  }

  Future<void> _loadSavedPhone() async {
    final savedPhone = await ApiService.getSavedLoginPhone();
    if (savedPhone != null && savedPhone.isNotEmpty && mounted) {
      setState(() {
        _phoneController.text = savedPhone;
      });
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String _normalizePhone(String input) {
    return input.replaceAll(RegExp(r'\s+'), '').trim();
  }

  String _formatFriendlyError(String rawError) {
    final lower = rawError.toLowerCase();
    if (lower.contains('401') || lower.contains('không chính xác') || lower.contains('invalid credentials')) {
      return 'Số điện thoại hoặc mật khẩu không chính xác.';
    }
    if (lower.contains('kết nối') || lower.contains('connection') || lower.contains('failed host lookup') || lower.contains('socketexception')) {
      return 'Không thể kết nối đến máy chủ. Vui lòng kiểm tra mạng hoặc cấu hình máy chủ.';
    }
    if (lower.contains('timed out') || lower.contains('hết thời gian')) {
      return 'Yêu cầu kết nối quá thời gian chờ. Vui lòng thử lại.';
    }
    return rawError.replaceFirst('Exception: ', '').replaceFirst('Error: ', '');
  }

  Future<void> _handleLogin() async {
    if (_isLoading) return;

    setState(() {
      _errorMessage = null;
    });

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final phone = _normalizePhone(_phoneController.text);
    final password = _passwordController.text;

    try {
      final user = await ApiService.login(phone, password);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Chào mừng ${user?.fullName ?? "bạn"} trở lại!',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomeShellView()),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = _formatFriendlyError(e.toString());
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _showServerConfigDialog() async {
    final currentUrl = await ApiService.getBaseUrl();
    if (!mounted) return;
    final controller = TextEditingController(text: currentUrl);
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<String>(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.dns_rounded, color: Color(0xFF0F172A), size: 24),
              SizedBox(width: 10),
              Text(
                'Cấu hình máy chủ',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Thay đổi địa chỉ API khi không kết nối được máy chủ:',
                  style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const Key('login_server_url_input'),
                  controller: controller,
                  style: const TextStyle(fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'http://...',
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Vui lòng nhập địa chỉ máy chủ';
                    }
                    if (!val.startsWith('http://') && !val.startsWith('https://')) {
                      return 'Địa chỉ phải bắt đầu bằng http:// hoặc https://';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          actions: [
            TextButton(
              style: AppButtons.text(minHeight: 48),
              onPressed: () async {
                await ApiService.resetCustomBaseUrl();
                if (dialogCtx.mounted) {
                  Navigator.of(dialogCtx).pop('Đã khôi phục địa chỉ máy chủ mặc định');
                }
              },
              child: const Text('Mặc định', style: TextStyle(color: Color(0xFF64748B))),
            ),
            ElevatedButton(
              key: const Key('login_server_url_save_btn'),
              style: AppButtons.primary(minHeight: 48, borderRadius: 10),
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  final newUrl = controller.text.trim();
                  await ApiService.setCustomBaseUrl(newUrl);
                  if (dialogCtx.mounted) {
                    Navigator.of(dialogCtx).pop('Đã cập nhật địa chỉ máy chủ');
                  }
                }
              },
              child: const Text('Lưu thay đổi'),
            ),
          ],
        );
      },
    );

    if (result != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const borderColor = Color(0xFFE2E8F0);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Logo / Biểu tượng và tên App ở trên
                  Center(
                    child: Column(
                      children: [
                        Container(
                          width: 68,
                          height: 68,
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A),
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF0F172A).withValues(alpha: 0.15),
                                blurRadius: 16,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.local_shipping_rounded,
                            size: 36,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Định Vị Giao Hàng',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Hệ thống quản lý vị trí & tuyến giao chuyên nghiệp',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

                  // 2. Thẻ trắng bo 16px, viền mảnh, không bóng nặng
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: borderColor, width: 1.0),
                    ),
                    padding: const EdgeInsets.all(24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Đăng nhập',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Ô SĐT (bàn phím số, tự chuẩn hóa)
                          const Text(
                            'Số điện thoại',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF334155),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            key: const Key('login_phone_input'),
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            textInputAction: TextInputAction.next,
                            enabled: !_isLoading,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                            decoration: InputDecoration(
                              hintText: 'Nhập số điện thoại nhận việc',
                              hintStyle: const TextStyle(fontSize: 14, color: Color(0xFF94A3B8)),
                              prefixIcon: const Icon(Icons.phone_outlined, size: 20, color: Color(0xFF64748B)),
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: borderColor),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: borderColor),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Color(0xFF0F172A), width: 1.5),
                              ),
                            ),
                            validator: (value) {
                              final normalized = _normalizePhone(value ?? '');
                              if (normalized.isEmpty) {
                                return 'Vui lòng nhập số điện thoại';
                              }
                              if (normalized.length < 9 || normalized.length > 12) {
                                return 'Số điện thoại không hợp lệ (9 - 12 số)';
                              }
                              return null;
                            },
                          ),

                          const SizedBox(height: 18),

                          // Ô Mật khẩu có nút ẩn/hiện
                          const Text(
                            'Mật khẩu',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF334155),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            key: const Key('login_password_input'),
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            textInputAction: TextInputAction.done,
                            enabled: !_isLoading,
                            onFieldSubmitted: (_) => _handleLogin(),
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                            decoration: InputDecoration(
                              hintText: 'Nhập mật khẩu tài khoản',
                              hintStyle: const TextStyle(fontSize: 14, color: Color(0xFF94A3B8)),
                              prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20, color: Color(0xFF64748B)),
                              suffixIcon: IconButton(
                                key: const Key('login_password_toggle_btn'),
                                icon: Icon(
                                  _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                  size: 20,
                                  color: const Color(0xFF64748B),
                                ),
                                onPressed: () {
                                  setState(() => _obscurePassword = !_obscurePassword);
                                },
                              ),
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: borderColor),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: borderColor),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Color(0xFF0F172A), width: 1.5),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Vui lòng nhập mật khẩu';
                              }
                              return null;
                            },
                          ),

                          const SizedBox(height: 16),

                          // Trạng thái Lỗi hiển thị ngay dưới ô với nút Thử lại
                          if (_errorMessage != null) ...[
                            Container(
                              key: const Key('login_error_container'),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF2F2),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFFCA5A5)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Icon(
                                        Icons.error_outline_rounded,
                                        color: Color(0xFFDC2626),
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _errorMessage!,
                                          key: const Key('login_error_text'),
                                          style: const TextStyle(
                                            color: Color(0xFFB91C1C),
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            height: 1.35,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton.icon(
                                      key: const Key('login_retry_btn'),
                                      onPressed: _isLoading ? null : _handleLogin,
                                      style: TextButton.styleFrom(
                                        foregroundColor: const Color(0xFFB91C1C),
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        minimumSize: const Size(48, 36),
                                      ),
                                      icon: const Icon(Icons.refresh_rounded, size: 16),
                                      label: const Text(
                                        'Thử lại',
                                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],

                          const SizedBox(height: 6),

                          // Nút ĐĂNG NHẬP đen rộng đầy chiều ngang (>= 56px)
                          SizedBox(
                            height: 56,
                            child: ElevatedButton(
                              key: const Key('login_submit_btn'),
                              onPressed: _isLoading ? null : _handleLogin,
                              style: AppButtons.primaryLarge(
                                minHeight: 56,
                                borderRadius: 14,
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                    )
                                  : const Text(
                                      'ĐĂNG NHẬP',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 3. Đường nhỏ "Cấu hình máy chủ" ở chân trang
                  Center(
                    child: TextButton.icon(
                      key: const Key('login_server_config_link'),
                      onPressed: _showServerConfigDialog,
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF64748B),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        minimumSize: const Size(48, 48),
                      ),
                      icon: const Icon(Icons.settings_ethernet_rounded, size: 16),
                      label: const Text(
                        'Cấu hình máy chủ',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.underline,
                        ),
                      ),
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
