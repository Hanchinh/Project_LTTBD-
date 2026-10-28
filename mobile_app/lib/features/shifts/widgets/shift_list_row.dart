import 'package:flutter/material.dart';
import 'package:delivery_marker_mobile/models/shift_model.dart';

class ShiftListRow extends StatelessWidget {
  final ShiftModel shift;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const ShiftListRow({
    super.key,
    required this.shift,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    Color chipBg;
    Color chipText;
    switch (shift.status) {
      case ShiftStatus.preparing:
        chipBg = const Color(0xFFFEF3C7);
        chipText = const Color(0xFFD97706);
        break;
      case ShiftStatus.inProgress:
        chipBg = const Color(0xFFDBEAFE);
        chipText = const Color(0xFF1D4ED8);
        break;
      case ShiftStatus.completed:
        chipBg = const Color(0xFFDCFCE7);
        chipText = const Color(0xFF15803D);
        break;
      case ShiftStatus.cancelled:
        chipBg = const Color(0xFFFEE2E2);
        chipText = const Color(0xFFB91C1C);
        break;
    }

    final summary = shift.summary;
    final dateStr = ShiftModel.formatVnDate(DateTime.tryParse(shift.shiftDate) ?? shift.createdAt ?? DateTime.now());
    final String subText = shift.status == ShiftStatus.completed
        ? '$dateStr · ${summary.totalPoints} điểm hoàn tất'
        : '$dateStr · ${summary.totalPoints} điểm (${summary.verifiedCount} xác minh, ${summary.temporaryCount} tạm)';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              shift.displayTitle,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0F172A),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            shift.shiftCode,
                            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: chipBg,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              shift.status.displayName,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: chipText,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subText,
                        style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 48,
                  height: 48,
                  child: IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 20),
                    tooltip: 'Xóa ca',
                    onPressed: onDelete,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
