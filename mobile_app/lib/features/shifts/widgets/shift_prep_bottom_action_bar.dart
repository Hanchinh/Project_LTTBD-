import 'package:flutter/material.dart';
import 'package:delivery_marker_mobile/core/theme/app_buttons.dart';
import 'package:delivery_marker_mobile/models/shift_model.dart';

/// Thanh hành động phía đáy màn hình: Chuyển đổi trạng thái ca và mở bản đồ ca
class ShiftPrepBottomActionBar extends StatelessWidget {
  final ShiftStatus status;
  final ValueChanged<ShiftStatus> onStatusChanged;
  final VoidCallback onOpenMap;

  const ShiftPrepBottomActionBar({
    super.key,
    required this.status,
    required this.onStatusChanged,
    required this.onOpenMap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
      ),
      child: SafeArea(
        child: Row(
          children: [
            // Nút trạng thái ca
            if (status == ShiftStatus.preparing)
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: SizedBox(
                  height: 48,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF0F172A),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                    ),
                    onPressed: () => onStatusChanged(ShiftStatus.inProgress),
                    child: const Text(
                      'Bắt đầu ca',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              )
            else if (status == ShiftStatus.inProgress)
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: SizedBox(
                  height: 48,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF15803D),
                      side: const BorderSide(color: Color(0xFF86EFAC)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                    ),
                    onPressed: () => onStatusChanged(ShiftStatus.completed),
                    child: const Text(
                      'Hoàn thành',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ),

            // Nút chính: XEM BẢN ĐỒ CA LÀM NÀY
            Expanded(
              child: SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  style: AppButtons.primary(minHeight: 48, borderRadius: 12),
                  icon: const Icon(Icons.map_rounded, size: 20),
                  label: const Text(
                    'Xem bản đồ ca làm này',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  onPressed: onOpenMap,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

