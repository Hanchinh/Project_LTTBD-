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

    final Color statusColor;
    final Color badgeBg;
    switch (shift.status) {
      case ShiftStatus.preparing:
        statusColor = const Color(0xFFD97706);
        badgeBg = isDark ? const Color(0xFF78350F).withValues(alpha: 0.35) : const Color(0xFFFEF3C7);
        break;
      case ShiftStatus.inProgress:
        statusColor = const Color(0xFF2563EB);
        badgeBg = isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.35) : const Color(0xFFDBEAFE);
        break;
      case ShiftStatus.completed:
        statusColor = const Color(0xFF16A34A);
        badgeBg = isDark ? const Color(0xFF064E3B).withValues(alpha: 0.35) : const Color(0xFFDCFCE7);
        break;
      case ShiftStatus.cancelled:
        statusColor = const Color(0xFFDC2626);
        badgeBg = isDark ? const Color(0xFF7F1D1D).withValues(alpha: 0.35) : const Color(0xFFFEE2E2);
        break;
    }

    final summary = shift.summary;
    final dateStr = ShiftModel.formatVnDate(DateTime.tryParse(shift.shiftDate) ?? shift.createdAt ?? DateTime.now());
    final String pointsDetail = shift.status == ShiftStatus.completed
        ? '$dateStr · ${summary.totalPoints} điểm hoàn tất'
        : '$dateStr · ${summary.totalPoints} điểm (${summary.verifiedCount} xác minh, ${summary.temporaryCount} tạm)';

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 4dp left status edge border (Dispatch Ticket indicator)
                Container(
                  width: 4,
                  color: statusColor,
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Hàng 1: Tiêu đề ca & Mã ca & Badge trạng thái
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      shift.displayTitle,
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                        color: colorScheme.onSurface,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: badgeBg,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                                    ),
                                    child: Text(
                                      shift.status.displayName,
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: statusColor,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              // Hàng 2: Mã ca & Chi tiết số điểm với Tabular Figures
                              Row(
                                children: [
                                  Text(
                                    shift.shiftCode,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: subtextColor,
                                      fontFeatures: const [FontFeature.tabularFigures()],
                                    ),
                                  ),
                                  Text(' · ', style: TextStyle(color: subtextColor, fontSize: 12)),
                                  Expanded(
                                    child: Text(
                                      pointsDetail,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: subtextColor,
                                        fontFeatures: const [FontFeature.tabularFigures()],
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        // Nút xóa ca
                        SizedBox(
                          key: Key('btn_delete_shift_${shift.id}'),
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
