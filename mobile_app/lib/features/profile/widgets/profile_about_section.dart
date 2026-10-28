import 'package:flutter/material.dart';
import 'package:delivery_marker_mobile/core/constants/map_config.dart';

/// Widget hiển thị thông tin ứng dụng: Phiên bản & Nguồn dữ liệu bản đồ
class ProfileAboutSection extends StatelessWidget {
  const ProfileAboutSection({super.key});

  @override
  Widget build(BuildContext context) {
    const bgCard = Colors.white;
    const borderColor = Color(0xFFE2E8F0);

    return Material(
      color: bgCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: borderColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.info_outline_rounded, color: Color(0xFF0F172A), size: 22),
            ),
            title: const Text(
              'Phiên bản ứng dụng',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
            ),
            trailing: const Text(
              'v1.0.0 (Local-First)',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B),
              ),
            ),
          ),
          const Divider(height: 1, indent: 64, endIndent: 16, color: borderColor),
          ListTile(
            key: const Key('profile_map_attribution_item'),
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.map_outlined, color: Color(0xFF0F172A), size: 22),
            ),
            title: const Text(
              'Nguồn bản đồ & Bản quyền',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
            ),
            subtitle: const Text(
              MapConfig.defaultAttribution,
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
          ),
        ],
      ),
    );
  }
}

