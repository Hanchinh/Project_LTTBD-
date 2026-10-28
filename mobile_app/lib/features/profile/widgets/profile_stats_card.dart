import 'package:flutter/material.dart';

class ProfileStatsCard extends StatelessWidget {
  final Map<String, int> stats;

  const ProfileStatsCard({
    super.key,
    required this.stats,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final borderColor = theme.dividerTheme.color ?? (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0));

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildStatItem(
            context: context,
            icon: Icons.place_rounded,
            iconColor: const Color(0xFF2563EB),
            count: stats['savedLocationsCount'] ?? 0,
            label: 'Vị trí đã lưu',
          ),
          Container(height: 36, width: 1, color: borderColor),
          _buildStatItem(
            context: context,
            icon: Icons.local_shipping_rounded,
            iconColor: const Color(0xFF10B981),
            count: stats['createdShiftsCount'] ?? 0,
            label: 'Ca đã tạo',
          ),
          Container(height: 36, width: 1, color: borderColor),
          _buildStatItem(
            context: context,
            icon: Icons.photo_camera_rounded,
            iconColor: const Color(0xFFF59E0B),
            count: stats['uploadedPhotosCount'] ?? 0,
            label: 'Ảnh đã chụp',
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required int count,
    required String label,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Column(
      children: [
        Icon(icon, color: iconColor, size: 22),
        const SizedBox(height: 6),
        Text(
          '$count',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: onSurface,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          ),
        ),
      ],
    );
  }
}
