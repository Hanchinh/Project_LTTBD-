import 'package:flutter/material.dart';
import 'package:delivery_marker_mobile/models/data_share_model.dart';
import 'package:delivery_marker_mobile/core/theme/app_buttons.dart';
import 'package:delivery_marker_mobile/features/photos/customer_photos_strip_widget.dart';

/// Thẻ chi tiết điểm được chia sẻ (TASK 023)
class SharedPointDetailSheet extends StatelessWidget {
  final SharedLocationPointModel point;
  final VoidCallback onClose;
  final ValueChanged<String> onCall;
  final VoidCallback onDirections;
  final ValueChanged<SharedLocationPointModel> onImport;

  const SharedPointDetailSheet({
    super.key,
    required this.point,
    required this.onClose,
    required this.onCall,
    required this.onDirections,
    required this.onImport,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, -2)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thanh gạt drag handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header: Badge tím "Chia sẻ từ [tên]" + nút đóng
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3E8FF),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFDDD6FE)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.share_rounded, size: 14, color: Color(0xFF7C3AED)),
                      const SizedBox(width: 6),
                      Text(
                        'Chia sẻ từ ${point.sharedByName}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF7C3AED),
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF64748B)),
                  onPressed: onClose,
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Tên khách hàng + Số điện thoại
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    point.customerName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  point.customerPhone,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),

            // Địa chỉ khách hàng
            if (point.customerAddress.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.place_outlined, size: 16, color: Color(0xFF64748B)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      point.customerAddress,
                      style: const TextStyle(fontSize: 13, color: Color(0xFF334155)),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],

            // Ghi chú định danh
            if (point.identificationNotes.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.notes_rounded, size: 16, color: Color(0xFF64748B)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      point.identificationNotes,
                      style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic, color: Color(0xFF475569)),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],

            // Dải ảnh (nếu có ảnh từ người chia sẻ)
            if (point.photos.isNotEmpty || (point.imageUrl != null && point.imageUrl!.isNotEmpty)) ...[
              const SizedBox(height: 10),
              CustomerPhotosStripWidget(
                customerId: point.customerId,
                customerName: point.customerName,
                initialPhotos: point.photos,
                legacyImageUrl: point.imageUrl,
                canAddPhoto: false,
                canDeletePhoto: false,
                height: 100,
              ),
            ],

            const SizedBox(height: 14),

            // Hàng nút hành động: GỌI | CHỈ ĐƯỜNG
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    key: const Key('btn_call_shared_point'),
                    style: AppButtons.secondary(minHeight: 48, borderRadius: 10),
                    icon: const Icon(Icons.phone_rounded, size: 18),
                    label: const Text('GỌI'),
                    onPressed: () => onCall(point.customerPhone),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    key: const Key('btn_directions_shared_point'),
                    style: AppButtons.secondary(minHeight: 48, borderRadius: 10),
                    icon: const Icon(Icons.navigation_rounded, size: 18),
                    label: const Text('CHỈ ĐƯỜNG'),
                    onPressed: onDirections,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Nút "NHẬP VÀO CỦA TÔI"
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                key: const Key('btn_import_shared_point_to_mine'),
                style: AppButtons.primary(minHeight: 48, borderRadius: 10),
                icon: const Icon(Icons.download_rounded, size: 20),
                label: const Text('NHẬP VÀO CỦA TÔI', style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: () => onImport(point),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
