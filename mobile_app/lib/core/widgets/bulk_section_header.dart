import 'package:flutter/material.dart';

/// Tiêu đề từng nhóm kết quả thêm SĐT hàng loạt
Widget buildBulkSectionHeader({
  required String title,
  required String subtitle,
  required Color color,
  required IconData icon,
}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    margin: const EdgeInsets.only(bottom: 8),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 13),
              ),
              Text(
                subtitle,
                style: TextStyle(color: color.withValues(alpha: 0.85), fontSize: 11),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

