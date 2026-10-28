import 'package:flutter/material.dart';

class ProfileEditNameDialog {
  static Future<String?> show({
    required BuildContext context,
    required String currentName,
  }) {
    final controller = TextEditingController(text: currentName);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Đổi tên hiển thị', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        content: TextField(
          key: const Key('edit_display_name_input'),
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Họ và tên của bạn',
            hintText: 'Nhập tên mới...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('HỦY')),
          ElevatedButton(
            key: const Key('edit_display_name_save_btn'),
            onPressed: () {
              final text = controller.text.trim();
              if (text.isNotEmpty) Navigator.pop(ctx, text);
            },
            child: const Text('LƯU'),
          ),
        ],
      ),
    );
  }
}

class ProfileAboutDialog {
  static void show(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.info_outline_rounded, color: Color(0xFF2563EB)),
            SizedBox(width: 8),
            Text('Về ứng dụng', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Delivery Location Marker',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A)),
            ),
            SizedBox(height: 4),
            Text('Phiên bản: 1.0.0 (Local-First Edition)', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
            SizedBox(height: 12),
            Text(
              'Ứng dụng hỗ trợ ghi nhận vị trí giao hàng, số điện thoại, ảnh cửa nhà và quản lý ca làm việc ngoại tuyến an toàn trên thiết bị.',
              style: TextStyle(fontSize: 13, color: Color(0xFF334155), height: 1.4),
            ),
            SizedBox(height: 8),
            Text(
              'Toàn bộ dữ liệu của bạn được lưu an toàn trong SQLite cục bộ, không gửi lên máy chủ khi không có sự đồng ý của bạn.',
              style: TextStyle(fontSize: 12, color: Color(0xFF10B981), fontWeight: FontWeight.w500),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('ĐÓNG', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
