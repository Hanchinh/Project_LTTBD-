// Thẻ hiển thị tóm tắt thông tin vị trí đã ghim của khách hàng.
// Cung cấp trạng thái ghim, tọa độ GPS, ghi chú nhận diện và nút mở bản đồ.
import 'package:flutter/material.dart';
import 'package:delivery_marker_mobile/core/theme/app_buttons.dart';

class CustomerDetailLocationCard extends StatelessWidget {
  final double? latitude;
  final double? longitude;
  final TextEditingController notesController;
  final bool isSaving;
  final VoidCallback onPickOnMap;
  final VoidCallback onDeleteLocation;

  const CustomerDetailLocationCard({
    super.key,
    required this.latitude,
    required this.longitude,
    required this.notesController,
    required this.isSaving,
    required this.onPickOnMap,
    required this.onDeleteLocation,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final borderColor = theme.dividerTheme.color ?? (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0));
    final subtextColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final hasLocation = latitude != null && longitude != null;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'TỌA ĐỘ & GHI CHÚ VỊ TRÍ',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: subtextColor,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.start,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (hasLocation)
                OutlinedButton.icon(
                  key: const Key('btn_delete_customer_location'),
                  style: AppButtons.secondary(minHeight: 48, borderRadius: 8),
                  icon: Icon(Icons.delete_outline_rounded, size: 16, color: colorScheme.onSurface),
                  label: Text(
                    'Xóa vị trí',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: colorScheme.onSurface),
                  ),
                  onPressed: isSaving ? null : onDeleteLocation,
                ),
              ElevatedButton.icon(
                key: const Key('btn_pick_location_map'),
                style: AppButtons.primary(minHeight: 48, borderRadius: 8),
                icon: const Icon(Icons.add_location_alt_rounded, size: 16),
                label: const Text('Chọn trên bản đồ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                onPressed: onPickOnMap,
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (hasLocation) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: borderColor),
              ),
              child: Row(
                children: [
                  const Icon(Icons.gps_fixed_rounded, size: 16, color: Color(0xFF2563EB)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Tọa độ: ${latitude!.toStringAsFixed(6)}, ${longitude!.toStringAsFixed(6)}',
                      style: TextStyle(
                        fontSize: 13,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF451A03).withValues(alpha: 0.4) : const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: isDark ? const Color(0xFF92400E) : const Color(0xFFFDE68A)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, size: 18, color: Color(0xFFD97706)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Khách hàng chưa có tọa độ ghim cổng nhà.',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? const Color(0xFFFDE68A) : const Color(0xFF92400E),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          Text(
            'GHI CHÚ NHẬN DIỆN (ĐẶC ĐIỂM CỔNG/CỬA)',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: subtextColor,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: notesController,
            maxLines: 2,
            style: TextStyle(fontSize: 14, color: colorScheme.onSurface),
            decoration: InputDecoration(
              hintText: 'Ví dụ: Cổng sắt màu xanh, hẻm cụt, chuông cửa bên phải...',
              hintStyle: TextStyle(fontSize: 13, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
              filled: true,
              fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: borderColor)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: borderColor)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5)),
            ),
          ),
        ],
      ),
    );
  }
}
