import 'package:flutter/material.dart';
import 'package:delivery_marker_mobile/models/shift_model.dart';
import 'package:delivery_marker_mobile/core/theme/app_buttons.dart';

class ShiftInProgressCard extends StatelessWidget {
  final ShiftModel shift;
  final VoidCallback onRename;
  final VoidCallback onDelete;
  final VoidCallback onBulkPaste;
  final VoidCallback onOpenMap;

  const ShiftInProgressCard({
    super.key,
    required this.shift,
    required this.onRename,
    required this.onDelete,
    required this.onBulkPaste,
    required this.onOpenMap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final borderColor = theme.dividerTheme.color ?? (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0));
    final subtextColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    final summary = shift.summary;
    final total = summary.totalPoints;
    final verified = summary.verifiedCount;
    final progress = total > 0 ? (verified / total).clamp(0.0, 1.0) : 0.0;
    final dateStr = ShiftModel.formatVnDate(DateTime.tryParse(shift.shiftDate) ?? shift.createdAt ?? DateTime.now());

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 4dp left solid blue indicator for inProgress
            Container(
              width: 4,
              color: const Color(0xFF2563EB),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Hàng 1: Tiêu đề ca, ngày, số điểm & menu "..."
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                shift.displayTitle,
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                shift.shiftCode,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: subtextColor,
                                  fontFeatures: const [FontFeature.tabularFigures()],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '$dateStr · $total điểm',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: subtextColor,
                                fontFeatures: const [FontFeature.tabularFigures()],
                              ),
                            ),
                            PopupMenuButton<String>(
                              icon: Icon(Icons.more_vert_rounded, color: subtextColor, size: 20),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                              onSelected: (value) {
                                if (value == 'rename') {
                                  onRename();
                                } else if (value == 'delete') {
                                  onDelete();
                                }
                              },
                              itemBuilder: (ctx) => [
                                PopupMenuItem(
                                  value: 'rename',
                                  child: Row(
                                    children: [
                                      Icon(Icons.edit_note_rounded, size: 18, color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155)),
                                      const SizedBox(width: 8),
                                      const Text('Đổi tên ca', style: TextStyle(fontSize: 14)),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFEF4444)),
                                      SizedBox(width: 8),
                                      Text('Xóa ca', style: TextStyle(fontSize: 14, color: Color(0xFFEF4444))),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Hàng 2: Thanh tiến độ
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 6,
                        backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Hàng 3: Dòng tóm tắt (preserve exact text string for tests)
                    Text(
                      '${summary.verifiedCount} Đã xác minh · ${summary.temporaryCount} Tạm · ${summary.noLocationCount} Chưa có',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: subtextColor,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Hàng 4: 2 nút "Dán SĐT" và "Mở bản đồ"
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 48,
                            child: OutlinedButton.icon(
                              style: AppButtons.secondary(minHeight: 48, borderRadius: 10),
                              icon: const Icon(Icons.paste_rounded, size: 18),
                              label: const Text('Dán SĐT', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                              onPressed: onBulkPaste,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: SizedBox(
                            height: 48,
                            child: ElevatedButton.icon(
                              style: AppButtons.primary(minHeight: 48, borderRadius: 10),
                              icon: const Icon(Icons.map_rounded, size: 18),
                              label: const Text('Mở bản đồ', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                              onPressed: onOpenMap,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
