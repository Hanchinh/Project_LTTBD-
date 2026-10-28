import 'package:flutter/material.dart';
import 'package:delivery_marker_mobile/data/remote/api_service.dart';
import 'package:delivery_marker_mobile/core/theme/app_buttons.dart';

class ProfileServerConfigDialog {
  static Future<void> show({
    required BuildContext context,
    required String currentBaseUrl,
    required ValueChanged<String> onUrlUpdated,
  }) async {
    final controller = TextEditingController(text: currentBaseUrl);
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
                  'Địa chỉ API Backend (ví dụ: http://10.0.2.2:3000/api/v1):',
                  style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const Key('account_server_url_input'),
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
                final defUrl = await ApiService.getBaseUrl();
                onUrlUpdated(defUrl);
                if (dialogCtx.mounted) {
                  Navigator.of(dialogCtx).pop('Đã khôi phục địa chỉ máy chủ mặc định');
                }
              },
              child: const Text('Mặc định', style: TextStyle(color: Color(0xFF64748B))),
            ),
            ElevatedButton(
              key: const Key('account_server_url_save_btn'),
              style: AppButtons.primary(minHeight: 48, borderRadius: 10),
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  final newUrl = controller.text.trim();
                  await ApiService.setCustomBaseUrl(newUrl);
                  onUrlUpdated(newUrl);
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

    if (result != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result)),
      );
    }
  }
}
