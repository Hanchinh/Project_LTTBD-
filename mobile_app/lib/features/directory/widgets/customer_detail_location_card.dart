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
    final hasLocation = latitude != null && longitude != null;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Color(0x08000000), blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'TỌA ĐỘ & GHI CHÚ VỊ TRÍ',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
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
                  icon: const Icon(Icons.delete_outline_rounded, size: 16, color: Color(0xFF0F172A)),
                  label: const Text(
                    'Xóa vị trí',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
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
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.gps_fixed_rounded, size: 16, color: Color(0xFF2563EB)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Tọa độ: ${latitude!.toStringAsFixed(6)}, ${longitude!.toStringAsFixed(6)}',
                      style: const TextStyle(fontSize: 13, fontFamily: 'monospace', fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
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
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, size: 18, color: Color(0xFFD97706)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Khách hàng chưa có tọa độ ghim cổng nhà.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF92400E)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          const Text('GHI CHÚ NHẬN DIỆN (ĐẶC ĐIỂM CỔNG/CỬA)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
          const SizedBox(height: 6),
          TextField(
            controller: notesController,
            maxLines: 2,
            decoration: InputDecoration(
              hintText: 'Ví dụ: Cổng sắt màu xanh, hẻm cụt, chuông cửa bên phải...',
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
            ),
          ),
        ],
      ),
    );
  }
}

