import 'package:flutter/material.dart';

/// Banner cảnh báo điểm chia sẻ ngoài khu vực hoạt động (TASK 023)
class OutOfAreaBanner extends StatelessWidget {
  final int count;
  final VoidCallback onDismiss;

  const OutOfAreaBanner({
    super.key,
    required this.count,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      key: const Key('banner_out_of_area_warning'),
      top: 62,
      left: 14,
      right: 14,
      child: SafeArea(
        child: Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(10),
          color: const Color(0xFFFEF3C7),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Color(0xFFD97706), size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$count điểm không hiển thị vì ngoài khu vực của bạn',
                    style: const TextStyle(color: Color(0xFF92400E), fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  key: const Key('btn_close_out_of_area_banner'),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: const Icon(Icons.close_rounded, size: 16, color: Color(0xFF92400E)),
                  onPressed: onDismiss,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
