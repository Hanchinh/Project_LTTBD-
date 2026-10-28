import 'package:flutter/material.dart';

class ProfileStatsCard extends StatelessWidget {
  final Map<String, int> stats;

  const ProfileStatsCard({
    super.key,
    required this.stats,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildStatItem(
            icon: Icons.place_rounded,
            iconColor: const Color(0xFF2563EB),
            count: stats['savedLocationsCount'] ?? 0,
            label: 'Vị trí đã lưu',
          ),
          Container(height: 36, width: 1, color: const Color(0xFFE2E8F0)),
          _buildStatItem(
            icon: Icons.local_shipping_rounded,
            iconColor: const Color(0xFF10B981),
            count: stats['createdShiftsCount'] ?? 0,
            label: 'Ca đã tạo',
          ),
          Container(height: 36, width: 1, color: const Color(0xFFE2E8F0)),
          _buildStatItem(
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
    required IconData icon,
    required Color iconColor,
    required int count,
    required String label,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: iconColor, size: 22),
        const SizedBox(height: 4),
        Text(
          '$count',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: Color(0xFF64748B),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
