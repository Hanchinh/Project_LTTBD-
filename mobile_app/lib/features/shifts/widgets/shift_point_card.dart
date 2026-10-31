// Thẻ hiển thị một mốc giao trong danh sách chuẩn bị ca làm việc.
// Cho phép kéo thả thay đổi thứ tự, xem tọa độ, gán vị trí và xóa mốc khỏi ca.
import 'package:flutter/material.dart';
import 'package:delivery_marker_mobile/models/shift_model.dart';
import 'package:delivery_marker_mobile/core/theme/app_buttons.dart';

/// Thẻ hiển thị một điểm giao trong màn hình Chuẩn bị ca
class ShiftPointCard extends StatelessWidget {
  final ShiftDeliveryPointModel point;
  final ValueChanged<ShiftDeliveryPointModel> onPickerRequested;
  final ValueChanged<ShiftDeliveryPointModel> onRemoveRequested;

  const ShiftPointCard({
    super.key,
    required this.point,
    required this.onPickerRequested,
    required this.onRemoveRequested,
  });

  @override
  Widget build(BuildContext context) {
    Color badgeBg;
    Color badgeText;
    IconData badgeIcon;
    String statusName = point.locationStatus.displayName;

    switch (point.locationStatus) {
      case LocationStatus.verified:
        badgeBg = const Color(0xFFDCFCE7); // green-100
        badgeText = const Color(0xFF15803D); // green-700
        badgeIcon = Icons.check_circle_rounded;
        break;
      case LocationStatus.temporary:
        badgeBg = const Color(0xFFFEF3C7); // amber-100
        badgeText = const Color(0xFFD97706); // amber-700
        badgeIcon = Icons.pin_drop_rounded;
        break;
      case LocationStatus.noLocation:
        badgeBg = const Color(0xFFF1F5F9); // slate-100
        badgeText = const Color(0xFF64748B); // slate-500
        badgeIcon = Icons.location_off_rounded;
        break;
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Dòng 1: Tên khách hàng & Badge trạng thái
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        point.customerName,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.phone_rounded, size: 13, color: Color(0xFF2563EB)),
                          const SizedBox(width: 4),
                          Text(
                            point.customerPhone,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF2563EB),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: badgeBg,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(badgeIcon, size: 13, color: badgeText),
                      const SizedBox(width: 4),
                      Text(
                        statusName,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: badgeText,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Địa chỉ khách hàng
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.location_on_outlined, size: 15, color: Color(0xFF94A3B8)),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    point.customerAddress,
                    style: const TextStyle(fontSize: 13, color: Color(0xFF475569), height: 1.3),
                  ),
                ),
              ],
            ),

            // Tọa độ nếu có
            if (point.hasValidCoordinates) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.gps_fixed_rounded, size: 13, color: Color(0xFF94A3B8)),
                  const SizedBox(width: 5),
                  Text(
                    '${point.latitude!.toStringAsFixed(6)}, ${point.longitude!.toStringAsFixed(6)}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontFamily: 'monospace',
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 12),
            const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
            const SizedBox(height: 10),

            // Dòng hành động: Ghim/cập nhật vị trí và nút Xóa khỏi ca
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 38,
                    child: point.locationStatus == LocationStatus.noLocation
                        ? ElevatedButton.icon(
                            style: AppButtons.primary(minHeight: 38, borderRadius: 8),
                            icon: const Icon(Icons.add_location_alt_rounded, size: 16),
                            label: const Text(
                              'Ghim vị trí',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                            onPressed: () => onPickerRequested(point),
                          )
                        : OutlinedButton.icon(
                            style: AppButtons.secondary(minHeight: 38, borderRadius: 8),
                            icon: Icon(
                              point.locationStatus == LocationStatus.temporary
                                  ? Icons.edit_location_alt_rounded
                                  : Icons.location_on_rounded,
                              size: 16,
                              color: point.locationStatus == LocationStatus.temporary
                                  ? const Color(0xFFD97706)
                                  : const Color(0xFF15803D),
                            ),
                            label: Text(
                              point.locationStatus == LocationStatus.temporary
                                  ? 'Sửa vị trí tạm'
                                  : 'Xem vị trí',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                            onPressed: () => onPickerRequested(point),
                          ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  height: 38,
                  width: 38,
                  child: IconButton(
                    style: IconButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      padding: EdgeInsets.zero,
                    ),
                    icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFF94A3B8)),
                    tooltip: 'Bỏ khỏi ca',
                    onPressed: () => onRemoveRequested(point),
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
