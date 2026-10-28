import 'package:flutter/material.dart';
import 'package:delivery_marker_mobile/core/theme/app_buttons.dart';
import 'package:delivery_marker_mobile/models/shift_model.dart';

/// Hộp thoại đổi tên ca làm việc
class ShiftRenameDialog {
  static Future<String?> show(BuildContext context, ShiftModel shift) {
    final controller = TextEditingController(text: shift.shiftName ?? '');
    final formKey = GlobalKey<FormState>();

    return showDialog<String>(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Đổi tên ca làm việc',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF0F172A)),
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Mã ca: ${shift.shiftCode}',
                style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: controller,
                autofocus: true,
                maxLength: 100,
                decoration: InputDecoration(
                  labelText: 'Tên ca làm việc',
                  hintText: 'Ví dụ: Ca sáng Quận 9',
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  counterText: '',
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Vui lòng nhập tên ca';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dlgCtx),
            child: const Text('HỦY', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: AppButtons.primary(),
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.pop(dlgCtx, controller.text.trim());
              }
            },
            child: const Text('LƯU', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

