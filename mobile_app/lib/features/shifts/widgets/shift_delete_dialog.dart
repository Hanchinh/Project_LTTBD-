import 'package:flutter/material.dart';
import 'package:delivery_marker_mobile/models/shift_model.dart';

/// Hộp thoại xác nhận xóa ca làm việc
class ShiftDeleteDialog {
  static Future<bool?> show(BuildContext context, ShiftModel shift) {
    return showDialog<bool>(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.delete_outline_rounded, color: Color(0xFFDC2626)),
            SizedBox(width: 8),
            Text('Xác nhận xóa ca?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Text(
          'Bạn có chắc chắn muốn xóa ca "${shift.displayTitle}" (${shift.shiftCode})?\n\n'
          'Các điểm giao trong ca này sẽ bị hủy khỏi ca. Vị trí khách hàng đã lưu trên hệ thống vẫn được giữ nguyên an toàn.',
          style: const TextStyle(fontSize: 14, height: 1.4, color: Color(0xFF334155)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dlgCtx, false),
            child: const Text('HỦY', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(dlgCtx, true),
            child: const Text('XÓA CA', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

