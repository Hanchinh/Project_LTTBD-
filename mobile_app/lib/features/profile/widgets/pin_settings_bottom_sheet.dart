import 'package:flutter/material.dart';
import 'package:delivery_marker_mobile/data/repositories/repository_provider.dart';

class PinSettingsBottomSheet extends StatefulWidget {
  const PinSettingsBottomSheet({super.key});

  static Future<void> show(BuildContext context) =>
      showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (_) => const PinSettingsBottomSheet());

  @override
  State<PinSettingsBottomSheet> createState() => _PinSettingsBottomSheetState();
}

class _PinSettingsBottomSheetState extends State<PinSettingsBottomSheet> {
  bool _isLoading = true;
  bool _hasPin = false;
  int _timeoutSeconds = 60;

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  Future<void> _loadState() async {
    setState(() => _isLoading = true);
    final hasPin = await RepositoryProvider.localProfile.hasPin();
    final timeout = await RepositoryProvider.localProfile.getPinTimeoutSeconds();
    if (mounted) setState(() { _hasPin = hasPin; _timeoutSeconds = timeout; _isLoading = false; });
  }

  Future<void> _handleSetNewPin() async {
    final pinController = TextEditingController();
    final confirmController = TextEditingController();
    String? errorText;

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Thiết lập mã PIN', style: TextStyle(fontWeight: FontWeight.w700)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Mã PIN từ 4 đến 6 chữ số dùng để khóa ứng dụng khi mở hoặc quay lại từ nền.', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
              const SizedBox(height: 16),
              TextField(key: const Key('setup_pin_input'), controller: pinController, keyboardType: TextInputType.number, obscureText: true, maxLength: 6, decoration: const InputDecoration(labelText: 'Nhập mã PIN mới (4-6 số)', counterText: '', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              TextField(key: const Key('setup_pin_confirm_input'), controller: confirmController, keyboardType: TextInputType.number, obscureText: true, maxLength: 6, decoration: const InputDecoration(labelText: 'Xác nhận lại mã PIN', counterText: '', border: OutlineInputBorder())),
              if (errorText != null) ...[const SizedBox(height: 10), Text(errorText!, style: const TextStyle(color: Color(0xFFDC2626), fontSize: 13))],
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogCtx, null), child: const Text('HỦY', style: TextStyle(color: Color(0xFF64748B)))),
            ElevatedButton(
              key: const Key('setup_pin_save_btn'),
              onPressed: () {
                final p1 = pinController.text.trim(), p2 = confirmController.text.trim();
                if (!RegExp(r'^\d{4,6}$').hasMatch(p1)) { setDialogState(() => errorText = 'Mã PIN phải từ 4 đến 6 chữ số'); return; }
                if (p1 != p2) { setDialogState(() => errorText = 'Hai lần nhập mã PIN không khớp'); return; }
                Navigator.pop(dialogCtx, p1);
              },
              child: const Text('LƯU MÃ PIN'),
            ),
          ],
        ),
      ),
    );

    if (result != null && mounted) {
      await RepositoryProvider.localProfile.setPin(result);
      await _loadState();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã thiết lập mã PIN thành công!'), backgroundColor: Color(0xFF10B981)));
    }
  }

  Future<void> _handleDisablePin() async {
    final oldPinController = TextEditingController();
    String? errorText;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Tắt mã PIN', style: TextStyle(fontWeight: FontWeight.w700)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Nhập mã PIN hiện tại để xác nhận tắt khóa ứng dụng.', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
              const SizedBox(height: 16),
              TextField(key: const Key('disable_pin_old_input'), controller: oldPinController, keyboardType: TextInputType.number, obscureText: true, maxLength: 6, decoration: const InputDecoration(labelText: 'Mã PIN hiện tại', counterText: '', border: OutlineInputBorder())),
              if (errorText != null) ...[const SizedBox(height: 10), Text(errorText!, style: const TextStyle(color: Color(0xFFDC2626), fontSize: 13))],
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogCtx, false), child: const Text('HỦY', style: TextStyle(color: Color(0xFF64748B)))),
            ElevatedButton(
              key: const Key('disable_pin_confirm_btn'),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626), foregroundColor: Colors.white),
              onPressed: () async {
                final res = await RepositoryProvider.localProfile.verifyPin(oldPinController.text.trim());
                if (res.success) {
                  if (dialogCtx.mounted) Navigator.pop(dialogCtx, true);
                } else if (dialogCtx.mounted) {
                  setDialogState(() => errorText = res.message ?? 'Mã PIN hiện tại không đúng');
                }
              },
              child: const Text('XÁC NHẬN TẮT'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && mounted) {
      await RepositoryProvider.localProfile.disablePin();
      await _loadState();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã tắt mã PIN khóa ứng dụng.'), backgroundColor: Color(0xFF10B981)));
    }
  }

  Future<void> _handleTimeoutChanged(int seconds) async {
    await RepositoryProvider.localProfile.setPinTimeoutSeconds(seconds);
    setState(() => _timeoutSeconds = seconds);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final subtextColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final borderColor = theme.dividerTheme.color ?? (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0));

    return Container(
      padding: EdgeInsets.only(top: 20, left: 20, right: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 24),
      decoration: BoxDecoration(color: colorScheme.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 16),
          Row(children: [const Icon(Icons.shield_outlined, color: Color(0xFF2563EB), size: 24), const SizedBox(width: 10), Text('Bảo Mật & Mã PIN Khóa App', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: colorScheme.onSurface))]),
          const SizedBox(height: 16),
          if (_isLoading)
            const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
          else ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _hasPin ? (isDark ? const Color(0xFF064E3B).withValues(alpha: 0.3) : const Color(0xFFF0FDF4)) : (isDark ? const Color(0xFF0B0F19) : const Color(0xFFF8FAFC)),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _hasPin ? (isDark ? const Color(0xFF059669) : const Color(0xFFBBF7D0)) : borderColor),
              ),
              child: Row(
                children: [
                  Icon(_hasPin ? Icons.lock_rounded : Icons.lock_open_rounded, color: _hasPin ? const Color(0xFF16A34A) : const Color(0xFF94A3B8), size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_hasPin ? 'Mã PIN đang BẬT' : 'Chưa thiết lập mã PIN', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _hasPin ? (isDark ? const Color(0xFF4ADE80) : const Color(0xFF166534)) : colorScheme.onSurface)),
                        const SizedBox(height: 2),
                        Text(_hasPin ? 'Khóa ứng dụng khi mở hoặc rời app.' : 'Mã PIN 4-6 số bảo vệ dữ liệu cục bộ.', style: TextStyle(fontSize: 12, color: subtextColor)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (!_hasPin)
              ElevatedButton.icon(
                key: const Key('btn_setup_pin'),
                onPressed: _handleSetNewPin,
                icon: const Icon(Icons.add_moderator_rounded),
                label: const Text('THIẾT LẬP MÃ PIN'),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white, minimumSize: const Size.fromHeight(50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              )
            else ...[
              Row(
                children: [
                  Expanded(child: OutlinedButton(key: const Key('btn_change_pin'), onPressed: _handleSetNewPin, style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), child: const Text('ĐỔI MÃ PIN'))),
                  const SizedBox(width: 12),
                  Expanded(child: OutlinedButton(key: const Key('btn_disable_pin'), onPressed: _handleDisablePin, style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFDC2626), side: const BorderSide(color: Color(0xFFFCA5A5)), minimumSize: const Size.fromHeight(48), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), child: const Text('TẮT MÃ PIN'))),
                ],
              ),
              const SizedBox(height: 20),
              Text('Thời gian tự động khóa khi rời app:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: colorScheme.onSurface)),
              const SizedBox(height: 8),
              _buildTimeoutTile('Ngay lập tức', 'Khóa ứng dụng ngay khi chuyển sang ứng dụng khác', 0),
              _buildTimeoutTile('Sau 1 phút (Khuyên dùng)', 'Cho phép quay lại app nhanh chóng trong vòng 60 giây', 60),
              _buildTimeoutTile('Sau 5 phút', 'Tiện lợi khi liên tục chuyển đổi app lúc giao hàng', 300),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildTimeoutTile(String title, String subtitle, int value) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final sel = _timeoutSeconds == value;
    final borderColor = theme.dividerTheme.color ?? (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0));

    return InkWell(
      key: Key('pin_timeout_$value'),
      onTap: () => _handleTimeoutChanged(value),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: sel ? (isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.3) : const Color(0xFFEFF6FF)) : (isDark ? const Color(0xFF0B0F19) : const Color(0xFFF8FAFC)),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: sel ? const Color(0xFF2563EB) : borderColor, width: sel ? 1.5 : 1.0),
        ),
        child: Row(
          children: [
            Icon(sel ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded, color: sel ? const Color(0xFF2563EB) : const Color(0xFF94A3B8), size: 20),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: TextStyle(fontSize: 13, fontWeight: sel ? FontWeight.w700 : FontWeight.w500, color: theme.colorScheme.onSurface)), const SizedBox(height: 2), Text(subtitle, style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)))])),
          ],
        ),
      ),
    );
  }
}
