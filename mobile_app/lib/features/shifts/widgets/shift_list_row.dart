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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final borderColor = theme.dividerTheme.color ?? (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0));
    final subtextColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    Color chipBg;
    Color chipText;
    switch (shift.status) {
      case ShiftStatus.preparing:
        chipBg = isDark ? const Color(0xFF78350F).withValues(alpha: 0.4) : const Color(0xFFFEF3C7);
        chipText = isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706);
        break;
      case ShiftStatus.inProgress:
        chipBg = isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.4) : const Color(0xFFDBEAFE);
        chipText = isDark ? const Color(0xFF60A5FA) : const Color(0xFF1D4ED8);
        break;
      case ShiftStatus.completed:
        chipBg = isDark ? const Color(0xFF064E3B).withValues(alpha: 0.4) : const Color(0xFFDCFCE7);
        chipText = isDark ? const Color(0xFF4ADE80) : const Color(0xFF15803D);
        break;
      case ShiftStatus.cancelled:
        chipBg = isDark ? const Color(0xFF7F1D1D).withValues(alpha: 0.4) : const Color(0xFFFEE2E2);
        chipText = isDark ? const Color(0xFFF87171) : const Color(0xFFB91C1C);
        break;
    }

    final summary = shift.summary;
    final dateStr = ShiftModel.formatVnDate(DateTime.tryParse(shift.shiftDate) ?? shift.createdAt ?? DateTime.now());
    final String subText = shift.status == ShiftStatus.completed
        ? '$dateStr · ${summary.totalPoints} điểm hoàn tất'
        : '$dateStr · ${summary.totalPoints} điểm (${summary.verifiedCount} xác minh, ${summary.temporaryCount} tạm)';

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
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
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: colorScheme.onSurface,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            shift.shiftCode,
                            style: TextStyle(fontSize: 12, color: subtextColor),
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
                        style: TextStyle(fontSize: 13, color: subtextColor),
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
