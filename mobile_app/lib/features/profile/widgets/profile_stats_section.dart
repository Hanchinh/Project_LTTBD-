import 'package:flutter/material.dart';

class ProfileStatsSection extends StatelessWidget {
  final Map<String, int> stats;

  const ProfileStatsSection({
    super.key,
    required this.stats,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      key: const Key('profile_stats_card'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bar_chart_rounded, color: colorScheme.onSurface, size: 20),
              const SizedBox(width: 8),
              Text(
                'Thống kê của tôi',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatTile(
                  label: 'Vị trí đã lưu',
                  count: stats['savedLocationsCount'] ?? 0,
                  icon: Icons.place_rounded,
                  color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB),
                  isDark: isDark,
                  surfaceColor: colorScheme.surface,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildStatTile(
                  label: 'Ca đã tạo',
                  count: stats['createdShiftsCount'] ?? 0,
                  icon: Icons.assignment_rounded,
                  color: isDark ? const Color(0xFF4ADE80) : const Color(0xFF16A34A),
                  isDark: isDark,
                  surfaceColor: colorScheme.surface,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildStatTile(
                  label: 'Ảnh đã tải',
                  count: stats['uploadedPhotosCount'] ?? 0,
                  icon: Icons.photo_library_rounded,
                  color: isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706),
                  isDark: isDark,
                  surfaceColor: colorScheme.surface,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatTile({
    required String label,
    required int count,
    required IconData icon,
    required Color color,
    required bool isDark,
    required Color surfaceColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: isDark ? surfaceColor : color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? color.withValues(alpha: 0.3) : color.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 8),
          Text(
            count.toString(),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
            ),
          ),
        ],
      ),
    );
  }
}
