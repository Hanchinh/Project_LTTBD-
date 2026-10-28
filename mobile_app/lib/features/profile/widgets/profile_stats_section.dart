import 'package:flutter/material.dart';

class ProfileStatsSection extends StatelessWidget {
  final Map<String, int> stats;

  const ProfileStatsSection({
    super.key,
    required this.stats,
  });

  @override
  Widget build(BuildContext context) {
    const bgCard = Colors.white;
    const borderColor = Color(0xFFE2E8F0);

    return Container(
      key: const Key('profile_stats_card'),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.bar_chart_rounded, color: Color(0xFF0F172A), size: 20),
              SizedBox(width: 8),
              Text(
                'Thống kê của tôi',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildStatTile(
                  label: 'Vị trí đã lưu',
                  count: stats['savedLocationsCount'] ?? 0,
                  icon: Icons.place_rounded,
                  color: const Color(0xFF2563EB),
                  bgColor: const Color(0xFFEFF6FF),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildStatTile(
                  label: 'Ca đã tạo',
                  count: stats['createdShiftsCount'] ?? 0,
                  icon: Icons.assignment_rounded,
                  color: const Color(0xFF16A34A),
                  bgColor: const Color(0xFFF0FDF4),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildStatTile(
                  label: 'Ảnh đã tải',
                  count: stats['uploadedPhotosCount'] ?? 0,
                  icon: Icons.photo_library_rounded,
                  color: const Color(0xFFD97706),
                  bgColor: const Color(0xFFFFFBEB),
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
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
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
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF475569),
            ),
          ),
        ],
      ),
    );
  }
}
