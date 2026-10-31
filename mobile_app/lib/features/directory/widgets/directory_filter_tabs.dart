// Thanh tab lọc danh bạ nhanh theo trạng thái vị trí và khu vực phụ trách.
// Cho phép tài xế nhanh chóng chuyển đổi danh sách cần giao hoặc kiểm tra.
import 'package:flutter/material.dart';
import 'package:delivery_marker_mobile/models/customer_model.dart';

/// Hàng tab lọc dạng thanh công cụ thực địa kỹ thuật (Tactile Segmented Tabs)
/// Tất cả | Đã xác minh | Vị trí tạm | Chưa có vị trí
class DirectoryFilterTabs extends StatelessWidget {
  final String selectedFilter;
  final CustomerTabCounts tabCounts;
  final ValueChanged<String> onFilterSelected;

  const DirectoryFilterTabs({
    super.key,
    required this.selectedFilter,
    required this.tabCounts,
    required this.onFilterSelected,
  });

  Widget _buildTab({
    required BuildContext context,
    required String key,
    required String label,
    required int count,
    Color? dotColor,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final isSelected = selectedFilter == key;

    final bgColor = isSelected
        ? (isDark ? const Color(0xFF2563EB) : const Color(0xFF0F172A))
        : colorScheme.surface;
    final borderColor = isSelected
        ? (isDark ? const Color(0xFF3B82F6) : const Color(0xFF0F172A))
        : (theme.dividerTheme.color ?? (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)));
    final textColor = isSelected
        ? Colors.white
        : (isDark ? const Color(0xFFF1F5F9) : const Color(0xFF475569));

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () {
            if (selectedFilter != key) {
              onFilterSelected(key);
            }
          },
          child: Container(
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (dotColor != null) ...[
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 6),
                ],
                Text(
                  '$label ($count)',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: textColor,
                    letterSpacing: 0.2,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _buildTab(
            context: context,
            key: 'ALL',
            label: 'Tất cả',
            count: tabCounts.total,
          ),
          _buildTab(
            context: context,
            key: 'VERIFIED',
            label: 'Đã xác minh',
            count: tabCounts.verified,
            dotColor: const Color(0xFF10B981),
          ),
          _buildTab(
            context: context,
            key: 'TEMPORARY',
            label: 'Vị trí tạm',
            count: tabCounts.temporary,
            dotColor: const Color(0xFFF59E0B),
          ),
          _buildTab(
            context: context,
            key: 'NO_LOCATION',
            label: 'Chưa có vị trí',
            count: tabCounts.noLocation,
            dotColor: const Color(0xFF94A3B8),
          ),
        ],
      ),
    );
  }
}
