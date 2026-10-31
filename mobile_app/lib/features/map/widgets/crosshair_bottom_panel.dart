// Bảng điều khiển phía dưới màn hình trong chế độ tâm ngắm ghim vị trí.
// Hiển thị tọa độ hiện tại, địa chỉ tham khảo và nút xác nhận ghim vị trí.
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:delivery_marker_mobile/models/shift_model.dart';
import 'package:delivery_marker_mobile/core/theme/app_buttons.dart';

class CrosshairBottomPanel extends StatelessWidget {
  final ShiftDeliveryPointModel point;
  final String shiftId;
  final LatLng currentCrosshairCenter;
  final bool isSaving;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  const CrosshairBottomPanel({
    super.key,
    required this.point,
    required this.shiftId,
    required this.currentCrosshairCenter,
    required this.isSaving,
    required this.onCancel,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    Color badgeBg;
    Color badgeText;
    IconData badgeIcon;

    switch (point.locationStatus) {
      case LocationStatus.verified:
        badgeBg = const Color(0xFFDCFCE7);
        badgeText = const Color(0xFF15803D);
        badgeIcon = Icons.check_circle_rounded;
        break;
      case LocationStatus.temporary:
        badgeBg = const Color(0xFFFEF3C7);
        badgeText = const Color(0xFFD97706);
        badgeIcon = Icons.pin_drop_rounded;
        break;
      case LocationStatus.noLocation:
        badgeBg = const Color(0xFFF1F5F9);
        badgeText = const Color(0xFF64748B);
        badgeIcon = Icons.location_off_rounded;
        break;
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(
          top: BorderSide(
            color: theme.dividerTheme.color ?? const Color(0xFFE2E8F0),
          ),
        ),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -2)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Banner Đang ghim lại cho khách hàng
            Container(
              key: const Key('repin_customer_banner'),
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.push_pin_rounded, size: 16, color: Color(0xFF2563EB)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Đang ghim lại cho: ${point.customerName} - ${point.customerPhone}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1D4ED8),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

            // Thông tin khách hàng & Trạng thái hiện tại
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        point.customerName,
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: colorScheme.onSurface),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        point.customerAddress,
                        style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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
                      Icon(badgeIcon, size: 12, color: badgeText),
                      const SizedBox(width: 4),
                      Text(
                        point.locationStatus.displayName,
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
            const SizedBox(height: 10),

            // Tọa độ hiện tại tại tâm ngắm
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: theme.dividerTheme.color ?? const Color(0xFFE2E8F0),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.gps_fixed_rounded, size: 16, color: Color(0xFFEF4444)),
                  const SizedBox(width: 6),
                  Text(
                    'Tọa độ tâm ngắm: ',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: colorScheme.onSurfaceVariant),
                  ),
                  Expanded(
                    child: Text(
                      '${currentCrosshairCenter.latitude.toStringAsFixed(6)}, ${currentCrosshairCenter.longitude.toStringAsFixed(6)}',
                      style: TextStyle(
                        fontSize: 13,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // 2 Nút: HỦY và XÁC NHẬN VỊ TRÍ
            Row(
              children: [
                Expanded(
                  flex: 1,
                  child: SizedBox(
                    height: 48,
                    child: OutlinedButton(
                      style: AppButtons.secondary(minHeight: 48, borderRadius: 12),
                      onPressed: isSaving ? null : onCancel,
                      child: const Text(
                        'Hủy',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    height: 48,
                    child: ElevatedButton.icon(
                      style: AppButtons.primary(minHeight: 48, borderRadius: 12),
                      icon: isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Icon(Icons.check_rounded, size: 20),
                      label: Text(
                        isSaving
                            ? 'Đang lưu...'
                            : (shiftId.isNotEmpty ? 'Lưu vị trí tạm' : 'Xác nhận vị trí'),
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                      onPressed: isSaving ? null : onConfirm,
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
