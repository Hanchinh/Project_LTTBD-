import 'package:flutter/material.dart';
import 'package:delivery_marker_mobile/core/constants/map_config.dart';

/// Widget hiển thị thông tin ứng dụng: Phiên bản & Nguồn dữ liệu bản đồ
class ProfileAboutSection extends StatelessWidget {
  const ProfileAboutSection({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final bgCard = colorScheme.surface;
    final borderColor = theme.dividerTheme.color ?? (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0));
    final subtextColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final iconBg = isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9);
    final iconColor = colorScheme.onSurface;

    return Material(
      color: bgCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: borderColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.info_outline_rounded, color: iconColor, size: 22),
            ),
            title: Text(
              'Phiên bản ứng dụng',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: colorScheme.onSurface),
            ),
            trailing: Text(
              'v1.0.0 (Local-First)',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: subtextColor,
              ),
            ),
          ),
          Divider(height: 1, indent: 64, endIndent: 16, color: borderColor),
          ListTile(
            key: const Key('profile_map_attribution_item'),
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.map_outlined, color: iconColor, size: 22),
            ),
            title: Text(
              'Nguồn bản đồ & Bản quyền',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: colorScheme.onSurface),
            ),
            subtitle: Text(
              MapConfig.defaultAttribution,
              style: TextStyle(fontSize: 13, color: subtextColor),
            ),
          ),
        ],
      ),
    );
  }
}
