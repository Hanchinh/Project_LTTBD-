import 'package:flutter/material.dart';
import 'package:delivery_marker_mobile/core/theme/app_buttons.dart';

/// Hộp thoại yêu cầu người dùng nhập mật khẩu giải mã gói dữ liệu chia sẻ
class SharePasswordDialog {
  static Future<String?> show(BuildContext context, {bool isRetry = false}) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.lock_rounded, color: Color(0xFF0F172A), size: 24),
            const SizedBox(width: 8),
            Text(
              isRetry ? 'Mật khẩu sai, thử lại' : 'Nhập mật khẩu mở gói',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isRetry
                  ? 'Mật khẩu bạn vừa nhập không đúng. Vui lòng kiểm tra lại với người gửi.'
                  : 'Gói chia sẻ này được mã hóa bảo vệ bằng mật khẩu.',
              style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('input_share_password'),
              controller: controller,
              obscureText: true,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Nhập mật khẩu...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('HỦY', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            key: const Key('btn_confirm_share_password'),
            style: AppButtons.primary(minHeight: 44),
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('MỞ KHÓA'),
          ),
        ],
      ),
    );
  }
}

