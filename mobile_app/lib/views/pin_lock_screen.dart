import 'dart:async';
import 'package:flutter/material.dart';
import '../repositories/repository_provider.dart';

/// Màn hình khóa mã PIN bảo vệ ứng dụng (Local-First PIN Lock Screen)
class PinLockScreen extends StatefulWidget {
  final VoidCallback? onSuccess;
  final bool isCancelable;

  const PinLockScreen({
    super.key,
    this.onSuccess,
    this.isCancelable = false,
  });

  @override
  State<PinLockScreen> createState() => _PinLockScreenState();
}

class _PinLockScreenState extends State<PinLockScreen> {
  String _enteredPin = '';
  String? _errorMessage;
  bool _isChecking = false;
  int _remainingLockoutSeconds = 0;
  Timer? _lockoutTimer;

  @override
  void initState() {
    super.initState();
    _checkInitialLockout();
  }

  @override
  void dispose() {
    _lockoutTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkInitialLockout() async {
    // Kiểm tra xem có đang bị khóa lockout hay không (không làm tăng số lần thử sai)
    final res = await RepositoryProvider.localProfile.checkLockoutStatus();
    if (res != null && res.isLocked && mounted) {
      _startLockoutTimer(res.remainingLockoutSeconds);
    }
  }

  void _startLockoutTimer(int seconds) {
    setState(() {
      _remainingLockoutSeconds = seconds;
      _errorMessage = 'Ứng dụng tạm khóa do nhập sai nhiều lần. Vui lòng chờ $seconds giây.';
    });

    _lockoutTimer?.cancel();
    _lockoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_remainingLockoutSeconds > 1) {
          _remainingLockoutSeconds--;
          _errorMessage = 'Ứng dụng tạm khóa do nhập sai nhiều lần. Vui lòng chờ $_remainingLockoutSeconds giây.';
        } else {
          _remainingLockoutSeconds = 0;
          _errorMessage = null;
          timer.cancel();
        }
      });
    });
  }

  void _onDigitPressed(String digit) {
    if (_isChecking || _remainingLockoutSeconds > 0) return;
    if (_enteredPin.length >= 6) return;

    setState(() {
      _enteredPin += digit;
      _errorMessage = null;
    });

    // Tự động kiểm tra khi đủ từ 4 đến 6 ký tự nếu người dùng bấm tiếp hoặc đủ 6 số
    if (_enteredPin.length == 6) {
      _verifyEnteredPin();
    }
  }

  void _onDeletePressed() {
    if (_isChecking || _remainingLockoutSeconds > 0) return;
    if (_enteredPin.isNotEmpty) {
      setState(() {
        _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
        _errorMessage = null;
      });
    }
  }

  Future<void> _verifyEnteredPin() async {
    if (_enteredPin.length < 4 || _isChecking || _remainingLockoutSeconds > 0) return;
    setState(() => _isChecking = true);

    try {
      final result = await RepositoryProvider.localProfile.verifyPin(_enteredPin);
      if (!mounted) return;

      if (result.success) {
        if (widget.onSuccess != null) {
          widget.onSuccess!();
        } else {
          Navigator.of(context).pop(true);
        }
      } else {
        setState(() {
          _enteredPin = '';
          _isChecking = false;
        });

        if (result.isLocked) {
          _startLockoutTimer(result.remainingLockoutSeconds);
        } else {
          setState(() {
            _errorMessage = result.message ?? 'Mã PIN không chính xác.';
          });
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _enteredPin = '';
          _isChecking = false;
          _errorMessage = 'Đã có lỗi xảy ra khi xác thực PIN.';
        });
      }
    }
  }

  Future<void> _showForgotPinDialog() async {
    final confirmController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 28),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Quên mã PIN?',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFFDC2626)),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Ứng dụng hoạt động theo kiến trúc Local-First bảo mật cao, không lưu PIN thô và KHÔNG có bất kỳ cửa sau nào để khôi phục PIN.\n\n'
                'Nếu quên mã PIN, bạn BẮT BUỘC phải ĐẶT LẠI (XÓA TOÀN BỘ DỮ LIỆU) của ứng dụng để mở lại.\n\n'
                'Sau khi đặt lại, bạn có thể khôi phục lại dữ liệu từ tệp sao lưu (.zip) đã xuất trước đó.',
                style: TextStyle(fontSize: 13, height: 1.5, color: Color(0xFF334155)),
              ),
              const SizedBox(height: 16),
              const Text(
                'Nhập "XÓA HẾT" vào ô bên dưới để xác nhận:',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 8),
              TextField(
                key: const Key('forgot_pin_confirm_input'),
                controller: confirmController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'XÓA HẾT',
                  hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('HỦY BỎ', style: TextStyle(color: Color(0xFF64748B))),
            ),
            ElevatedButton(
              key: const Key('forgot_pin_confirm_btn'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                if (confirmController.text.trim().toUpperCase() == 'XÓA HẾT') {
                  Navigator.pop(ctx, true);
                }
              },
              child: const Text('XÁC NHẬN ĐẶT LẠI'),
            ),
          ],
        );
      },
    );

    if (confirmed == true && mounted) {
      await RepositoryProvider.localProfile.resetAllDataWithWipe();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã đặt lại dữ liệu ứng dụng thành công.'),
          backgroundColor: Color(0xFF10B981),
        ),
      );
      if (widget.onSuccess != null) {
        widget.onSuccess!();
      } else {
        Navigator.of(context).pop(true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLockedOut = _remainingLockoutSeconds > 0;

    return PopScope(
      canPop: widget.isCancelable,
      child: Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        body: SafeArea(
          child: Column(
            children: [
              // Thanh trên (nếu cho phép hủy)
              Align(
                alignment: Alignment.centerLeft,
                child: widget.isCancelable
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.white70),
                        onPressed: () => Navigator.of(context).pop(false),
                      )
                    : const SizedBox(height: 48),
              ),

              const Spacer(),

              // Logo & Khóa
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF334155), width: 1.5),
                ),
                child: const Icon(
                  Icons.lock_outline_rounded,
                  color: Color(0xFF60A5FA),
                  size: 36,
                ),
              ),
              const SizedBox(height: 18),

              const Text(
                'MÃ PIN KHÓA ỨNG DỤNG',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Nhập mã PIN để mở khóa',
                style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
              ),
              const SizedBox(height: 24),

              // Dãy chấm tròn biểu thị số chữ số
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(6, (index) {
                  final isFilled = index < _enteredPin.length;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    width: isFilled ? 18 : 14,
                    height: isFilled ? 18 : 14,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isFilled ? const Color(0xFF3B82F6) : Colors.transparent,
                      border: Border.all(
                        color: isFilled ? const Color(0xFF60A5FA) : const Color(0xFF64748B),
                        width: 2,
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 16),

              // Thông báo lỗi hoặc đếm ngược
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    _errorMessage!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isLockedOut ? const Color(0xFFF87171) : const Color(0xFFFCA5A5),
                    ),
                  ),
                )
              else
                const SizedBox(height: 18),

              const Spacer(),

              // BÀN PHÍM SỐ LỚN
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 340),
                child: Column(
                  children: [
                    _buildKeypadRow(['1', '2', '3']),
                    const SizedBox(height: 14),
                    _buildKeypadRow(['4', '5', '6']),
                    const SizedBox(height: 14),
                    _buildKeypadRow(['7', '8', '9']),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Nút OK xác nhận nếu nhập 4 hoặc 5 số
                        SizedBox(
                          width: 72,
                          height: 72,
                          child: (_enteredPin.length >= 4 && _enteredPin.length < 6)
                              ? IconButton(
                                  key: const Key('pin_submit_btn'),
                                  onPressed: _verifyEnteredPin,
                                  icon: const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 36),
                                )
                              : const SizedBox.shrink(),
                        ),
                        _buildKeypadButton('0'),
                        SizedBox(
                          width: 72,
                          height: 72,
                          child: IconButton(
                            key: const Key('pin_delete_btn'),
                            onPressed: _onDeletePressed,
                            icon: const Icon(Icons.backspace_outlined, color: Colors.white70, size: 28),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Nút Quên mã PIN
              TextButton(
                key: const Key('pin_forgot_btn'),
                onPressed: _showForgotPinDialog,
                child: const Text(
                  'Quên mã PIN?',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF94A3B8),
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKeypadRow(List<String> digits) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: digits.map((d) => _buildKeypadButton(d)).toList(),
    );
  }

  Widget _buildKeypadButton(String digit) {
    return InkWell(
      key: Key('pin_keypad_$digit'),
      onTap: () => _onDigitPressed(digit),
      borderRadius: BorderRadius.circular(36),
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFF334155), width: 1.2),
        ),
        alignment: Alignment.center,
        child: Text(
          digit,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
