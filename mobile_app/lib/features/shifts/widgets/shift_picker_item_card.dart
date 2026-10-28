import 'package:flutter/material.dart';
import 'package:delivery_marker_mobile/models/shift_model.dart';

/// Card hiển thị thông tin ca làm việc trong ShiftPickerBottomSheet
class ShiftPickerItemCard extends StatelessWidget {
  final ShiftModel shift;
  final VoidCallback onTap;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  const ShiftPickerItemCard({
    super.key,
    required this.shift,
    required this.onTap,
    required this.onRename,
    required this.onDelete,
  });

  Color _getStatusColor(ShiftStatus status) {
    switch (status) {
      case ShiftStatus.inProgress:
        return const Color(0xFF16A34A);
      case ShiftStatus.preparing:
        return const Color(0xFF2563EB);
      case ShiftStatus.completed:
        return const Color(0xFF64748B);
      case ShiftStatus.cancelled:
        return const Color(0xFFDC2626);
    }
  }

  Color _getStatusBgColor(ShiftStatus status) {
    switch (status) {
      case ShiftStatus.inProgress:
        return const Color(0xFFDCFCE7);
      case ShiftStatus.preparing:
        return const Color(0xFFEFF6FF);
      case ShiftStatus.completed:
        return const Color(0xFFF1F5F9);
      case ShiftStatus.cancelled:
        return const Color(0xFFFEE2E2);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasLocationCount = shift.summary.verifiedCount + shift.summary.temporaryCount;
    final noLocationCount = shift.summary.noLocationCount;
    final statusColor = _getStatusColor(shift.status);
    final statusBgColor = _getStatusBgColor(shift.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        elevation: 1,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Hàng 1: Tiêu đề ca, badge trạng thái và popup menu 3 chấm
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
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            shift.shiftCode,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusBgColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        shift.status.displayName,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                    ),
                    // Menu đổi tên và xóa ca
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert_rounded, size: 20, color: Color(0xFF64748B)),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: 'Tùy chọn ca',
                      onSelected: (action) {
                        if (action == 'rename') {
                          onRename();
                        } else if (action == 'delete') {
                          onDelete();
                        }
                      },
                      itemBuilder: (ctx) => [
                        const PopupMenuItem(
                          value: 'rename',
                          child: Row(
                            children: [
                              Icon(Icons.edit_outlined, size: 18, color: Color(0xFF2563EB)),
                              SizedBox(width: 10),
                              Text('Đổi tên ca', style: TextStyle(fontSize: 14)),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFDC2626)),
                              SizedBox(width: 10),
                              Text('Xóa ca', style: TextStyle(fontSize: 14, color: Color(0xFFDC2626))),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // Hàng 2: Ngày làm việc & Thống kê điểm (có vị trí / chưa có vị trí)
                Row(
                  children: [
                    const Icon(Icons.calendar_today_rounded, size: 14, color: Color(0xFF64748B)),
                    const SizedBox(width: 4),
                    Text(
                      ShiftModel.formatVnDate(DateTime.tryParse(shift.shiftDate) ?? shift.createdAt ?? DateTime.now()),
                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                    const Spacer(),
                    // Badge Đã có vị trí
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFBBF7D0)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.location_on_rounded, size: 12, color: Color(0xFF16A34A)),
                          const SizedBox(width: 2),
                          Text(
                            '$hasLocationCount có vị trí',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF166534)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Badge Chưa có vị trí
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFFECACA)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.location_off_rounded, size: 12, color: Color(0xFFDC2626)),
                          const SizedBox(width: 2),
                          Text(
                            '$noLocationCount chưa vị trí',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF991B1B)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

