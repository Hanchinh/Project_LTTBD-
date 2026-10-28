import 'package:flutter/material.dart';

/// Dải đo lường thực địa (Telemetry Strip) hiển thị số liệu vị trí, ca làm và ảnh đã tải
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
    final borderColor = theme.dividerTheme.color ?? (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0));
    final subtextColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Container(
      key: const Key('profile_stats_card'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              'THỐNG KÊ HOẠT ĐỘNG',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
                color: subtextColor,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor, width: 1),
            ),
            child: IntrinsicHeight(
              child: Row(
                children: [
                  Expanded(
                    child: _buildTelemetryCell(
                      label: 'VỊ TRÍ ĐÃ LƯU',
                      count: stats['savedLocationsCount'] ?? 0,
                      icon: Icons.place_outlined,
                      accentColor: const Color(0xFF2563EB),
                      onSurface: colorScheme.onSurface,
                      subtextColor: subtextColor,
                    ),
                  ),
                  VerticalDivider(width: 1, thickness: 1, color: borderColor),
                  Expanded(
                    child: _buildTelemetryCell(
                      label: 'CA ĐÃ TẠO',
                      count: stats['createdShiftsCount'] ?? 0,
                      icon: Icons.assignment_outlined,
                      accentColor: const Color(0xFF16A34A),
                      onSurface: colorScheme.onSurface,
                      subtextColor: subtextColor,
                    ),
                  ),
                  VerticalDivider(width: 1, thickness: 1, color: borderColor),
                  Expanded(
                    child: _buildTelemetryCell(
                      label: 'ẢNH ĐÃ TẢI',
                      count: stats['uploadedPhotosCount'] ?? 0,
                      icon: Icons.photo_library_outlined,
                      accentColor: const Color(0xFFD97706),
                      onSurface: colorScheme.onSurface,
                      subtextColor: subtextColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTelemetryCell({
    required String label,
    required int count,
    required IconData icon,
    required Color accentColor,
    required Color onSurface,
    required Color subtextColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            count.toString(),
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              fontFeatures: const [FontFeature.tabularFigures()],
              color: onSurface,
              letterSpacing: -0.5,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 13, color: accentColor),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                    color: subtextColor,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
