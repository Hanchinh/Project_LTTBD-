// Bottom sheet danh sách cuộn các mốc giao bên dưới màn hình bản đồ ca.
// Cho phép tài xế duyệt nhanh danh sách và chọn mốc để bản đồ tập trung tới.
import 'package:flutter/material.dart';
import 'package:delivery_marker_mobile/models/shift_model.dart';

class ShiftPointSelectorSheet extends StatelessWidget {
  final List<ShiftDeliveryPointModel> points;
  final ValueChanged<ShiftDeliveryPointModel> onPointSelected;

  const ShiftPointSelectorSheet({
    super.key,
    required this.points,
    required this.onPointSelected,
  });

  static Future<void> show({
    required BuildContext context,
    required List<ShiftDeliveryPointModel> points,
    required ValueChanged<ShiftDeliveryPointModel> onPointSelected,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => ShiftPointSelectorSheet(
        points: points,
        onPointSelected: (point) {
          Navigator.pop(ctx);
          onPointSelected(point);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.55,
      minChildSize: 0.35,
      maxChildSize: 0.85,
      builder: (sheetCtx, scrollController) {
        return Column(
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
              child: Row(
                children: [
                  const Icon(Icons.add_location_alt_rounded, color: Color(0xFF2563EB), size: 22),
                  const SizedBox(width: 8),
                  const Text(
                    'Chọn điểm giao để gán vị trí',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                  ),
                  const Spacer(),
                  Text(
                    '${points.length} điểm',
                    style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFE2E8F0)),
            Expanded(
              child: ListView.separated(
                controller: scrollController,
                padding: const EdgeInsets.all(12),
                itemCount: points.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (itemCtx, idx) {
                  final point = points[idx];
                  Color statusBg;
                  Color statusText;

                  switch (point.locationStatus) {
                    case LocationStatus.verified:
                      statusBg = const Color(0xFFDCFCE7);
                      statusText = const Color(0xFF15803D);
                      break;
                    case LocationStatus.temporary:
                      statusBg = const Color(0xFFFEF3C7);
                      statusText = const Color(0xFFD97706);
                      break;
                    case LocationStatus.noLocation:
                      statusBg = const Color(0xFFF1F5F9);
                      statusText = const Color(0xFF64748B);
                      break;
                  }

                  return Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                      leading: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: statusBg,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          point.locationStatus == LocationStatus.verified
                              ? Icons.verified_rounded
                              : (point.locationStatus == LocationStatus.temporary
                                  ? Icons.pin_drop_rounded
                                  : Icons.location_off_rounded),
                          color: statusText,
                          size: 18,
                        ),
                      ),
                      title: Text(
                        point.customerName,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Color(0xFF0F172A)),
                      ),
                      subtitle: Text(
                        '${point.customerPhone} · ${point.customerAddress}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusBg,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          point.locationStatus.displayName,
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: statusText),
                        ),
                      ),
                      onTap: () => onPointSelected(point),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
