import 'package:flutter/material.dart';
import 'package:delivery_marker_mobile/models/customer_model.dart';
import 'package:delivery_marker_mobile/models/shift_model.dart';
import 'package:delivery_marker_mobile/shared_widgets/authenticated_image.dart';

/// Dòng hiển thị khách hàng trong danh bạ
class CustomerListItemWidget extends StatelessWidget {
  final CustomerDirectoryModel customer;
  final ValueChanged<CustomerDirectoryModel> onTap;
  final ValueChanged<CustomerDirectoryModel> onAddToShift;

  const CustomerListItemWidget({
    super.key,
    required this.customer,
    required this.onTap,
    required this.onAddToShift,
  });

  @override
  Widget build(BuildContext context) {
    Color dotColor;
    switch (customer.locationState) {
      case LocationStatus.verified:
        dotColor = const Color(0xFF10B981); // Xanh lá
        break;
      case LocationStatus.temporary:
        dotColor = const Color(0xFFF59E0B); // Cam
        break;
      case LocationStatus.noLocation:
        dotColor = const Color(0xFF94A3B8); // Xám
        break;
    }

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Color(0xFFF1F5F9), width: 1),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onTap(customer),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                // 1. Ảnh vuông nhỏ bo góc ở trái kèm chấm trạng thái góc dưới phải
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: customer.hasPhoto
                            ? AuthenticatedImage(
                                photoUrl: customer.effectivePhotoUrl,
                                fit: BoxFit.cover,
                                errorWidget: const Icon(Icons.photo_camera_outlined, color: Color(0xFF94A3B8), size: 22),
                              )
                            : const Center(
                                child: Icon(Icons.photo_camera_outlined, color: Color(0xFF94A3B8), size: 22),
                              ),
                      ),
                    ),
                    Positioned(
                      bottom: -2,
                      right: -2,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: dotColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),

                // 2. Dòng 1: "SĐT định dạng 0908 333 166 · Tên" & Dòng 2: Địa chỉ/ghi chú cắt "..."
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${customer.formattedPhoneNumber} · ${customer.fullName}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        customer.addressText.isNotEmpty ? customer.addressText : 'Chưa có địa chỉ',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF64748B),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // 3. Nút "+" bo vuông nhỏ ở phải mỗi dòng, vùng chạm >= 48px
                SizedBox(
                  width: 48,
                  height: 48,
                  child: Center(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => onAddToShift(customer),
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        child: const Icon(Icons.add_rounded, size: 20, color: Color(0xFF0F172A)),
                      ),
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
