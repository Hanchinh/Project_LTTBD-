// Thành phần hiển thị một dòng thông tin khách hàng trong danh sách danh bạ.
// Hiển thị ảnh đại diện, chấm trạng thái, thao tác gọi điện và thêm vào ca.
import 'package:flutter/material.dart';
import 'package:delivery_marker_mobile/models/customer_model.dart';
import 'package:delivery_marker_mobile/models/shift_model.dart';
import 'package:delivery_marker_mobile/core/widgets/authenticated_image.dart';

/// Dòng hiển thị khách hàng trong danh bạ chuẩn công thái học thực địa (Industrial Field Utility)
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final borderColor = theme.dividerTheme.color ?? (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0));
    final subtextColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

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
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: borderColor,
            width: 1,
          ),
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
                        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: borderColor),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: customer.hasPhoto
                            ? AuthenticatedImage(
                                photoUrl: customer.effectivePhotoUrl,
                                fit: BoxFit.cover,
                                cacheWidth: 150,
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
                          border: Border.all(color: colorScheme.surface, width: 2),
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
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: colorScheme.onSurface,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        customer.addressText.isNotEmpty ? customer.addressText : 'Chưa có địa chỉ',
                        style: TextStyle(
                          fontSize: 13,
                          color: subtextColor,
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
                  child: Tooltip(
                    message: 'Thêm vào ca',
                    child: Center(
                      child: InkWell(
                        key: const Key('btn_add_to_shift'),
                        borderRadius: BorderRadius.circular(8),
                        onTap: () => onAddToShift(customer),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: borderColor),
                          ),
                          child: Icon(Icons.add_rounded, size: 22, color: colorScheme.onSurface),
                        ),
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
