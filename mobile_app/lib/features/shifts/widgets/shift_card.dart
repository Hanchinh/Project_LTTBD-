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
    final summary = shift.summary;
    final total = summary.totalPoints;
    final verified = summary.verifiedCount;
    final progress = total > 0 ? (verified / total).clamp(0.0, 1.0) : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFDBEAFE), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2563EB).withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
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
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        shift.shiftCode,
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${ShiftModel.formatVnDate(DateTime.tryParse(shift.shiftDate) ?? shift.createdAt ?? DateTime.now())} · $total điểm',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                    ),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert_rounded, color: Color(0xFF64748B), size: 20),
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
                        const PopupMenuItem(
                          value: 'rename',
                          child: Row(
                            children: [
                              Icon(Icons.edit_note_rounded, size: 18, color: Color(0xFF334155)),
                              SizedBox(width: 8),
                              Text('Đổi tên ca', style: TextStyle(fontSize: 14)),
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
                backgroundColor: const Color(0xFFE2E8F0),
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
              ),
            ),
            const SizedBox(height: 8),

            // Hàng 3: Dòng tóm tắt
            Text(
              '${summary.verifiedCount} Đã xác minh · ${summary.temporaryCount} Tạm · ${summary.noLocationCount} Chưa có',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF64748B)),
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
    );
  }
}
