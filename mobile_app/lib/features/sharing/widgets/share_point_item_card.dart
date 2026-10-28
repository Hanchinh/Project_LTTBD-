import 'package:flutter/material.dart';
import 'package:delivery_marker_mobile/models/local_share_models.dart';

/// Thẻ hiển thị một điểm giao trong danh sách xem trước gói chia sẻ
class SharePointItemCard extends StatelessWidget {
  final ClassifiedSharePoint item;
  final int index;
  final ValueChanged<bool?>? onSelectionChanged;

  const SharePointItemCard({
    super.key,
    required this.item,
    required this.index,
    this.onSelectionChanged,
  });

  @override
  Widget build(BuildContext context) {
    final pt = item.point;
    final isInvalid = item.classification == SharePointClassification.invalid;

    Color badgeBg;
    Color badgeColor;
    String badgeText;

    switch (item.classification) {
      case SharePointClassification.newCustomer:
        badgeBg = const Color(0xFFDCFCE7);
        badgeColor = const Color(0xFF15803D);
        badgeText = 'MỚI';
        break;
      case SharePointClassification.existingWithoutLocation:
        badgeBg = const Color(0xFFFEF3C7);
        badgeColor = const Color(0xFFB45309);
        badgeText = 'CHƯA CÓ VỊ TRÍ';
        break;
      case SharePointClassification.existingWithLocation:
        badgeBg = const Color(0xFFDBEAFE);
        badgeColor = const Color(0xFF1D4ED8);
        badgeText = 'TRÙNG (${item.formattedDistance})';
        break;
      case SharePointClassification.invalid:
        badgeBg = const Color(0xFFFEE2E2);
        badgeColor = const Color(0xFFB91C1C);
        badgeText = 'LỖI';
        break;
    }

    return Container(
      decoration: BoxDecoration(
        color: isInvalid ? const Color(0xFFFDF2F2) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isInvalid ? const Color(0xFFFCA5A5) : const Color(0xFFE2E8F0),
        ),
      ),
      child: CheckboxListTile(
        key: ValueKey('preview_point_$index'),
        dense: true,
        controlAffinity: ListTileControlAffinity.leading,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        value: item.isSelected,
        onChanged: isInvalid ? null : onSelectionChanged,
        title: Row(
          children: [
            Expanded(
              child: Text(
                pt.fullName?.isNotEmpty == true ? pt.fullName! : pt.phoneNumber,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: badgeBg,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                badgeText,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: badgeColor),
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Text(
              pt.phoneNumber,
              style: const TextStyle(fontSize: 13, color: Color(0xFF2563EB), fontWeight: FontWeight.w600),
            ),
            if (pt.addressText != null && pt.addressText!.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                pt.addressText!,
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if (isInvalid) ...[
              const SizedBox(height: 2),
              Text(
                'Lỗi: ${item.invalidReason}',
                style: const TextStyle(fontSize: 12, color: Color(0xFFDC2626), fontWeight: FontWeight.w600),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

