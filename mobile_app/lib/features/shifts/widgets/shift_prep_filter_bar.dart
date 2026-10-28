import 'package:flutter/material.dart';

/// Hàng lọc trạng thái điểm giao trong màn hình chuẩn bị ca
class ShiftPrepFilterBar extends StatelessWidget {
  final String selectedFilter;
  final int totalCount;
  final int verifiedCount;
  final int tempCount;
  final int noLocationCount;
  final ValueChanged<String> onFilterChanged;

  const ShiftPrepFilterBar({
    super.key,
    required this.selectedFilter,
    required this.totalCount,
    required this.verifiedCount,
    required this.tempCount,
    required this.noLocationCount,
    required this.onFilterChanged,
  });

  Widget _buildChip({
    required String key,
    required String label,
    Color? dotColor,
  }) {
    final isSelected = selectedFilter == key;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => onFilterChanged(key),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF0F172A) : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (dotColor != null) ...[
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.white : dotColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected ? Colors.white : const Color(0xFF475569),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _buildChip(
            key: 'ALL',
            label: 'Tất cả ($totalCount)',
          ),
          const SizedBox(width: 6),
          _buildChip(
            key: 'VERIFIED',
            label: 'Đã xác minh ($verifiedCount)',
            dotColor: const Color(0xFF10B981),
          ),
          const SizedBox(width: 6),
          _buildChip(
            key: 'TEMPORARY',
            label: 'Vị trí tạm ($tempCount)',
            dotColor: const Color(0xFFF59E0B),
          ),
          const SizedBox(width: 6),
          _buildChip(
            key: 'NO_LOCATION',
            label: 'Chưa có ($noLocationCount)',
            dotColor: const Color(0xFF94A3B8),
          ),
        ],
      ),
    );
  }
}
