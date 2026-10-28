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
    final iconColor = colorScheme.onSurfaceVariant;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'THÔNG TIN ỨNG DỤNG',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: subtextColor,
            ),
          ),
        ),
        Material(
          color: bgCard,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: borderColor),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              ListTile(
                dense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                leading: Icon(Icons.info_outline_rounded, color: iconColor, size: 20),
                title: Text(
                  'Phiên bản ứng dụng',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: colorScheme.onSurface),
                ),
                trailing: Text(
                  'v1.0.0 (Local-First)',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: subtextColor,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              Divider(height: 1, indent: 52, endIndent: 16, color: borderColor),
              ListTile(
                key: const Key('profile_map_attribution_item'),
                dense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                leading: Icon(Icons.map_outlined, color: iconColor, size: 20),
                title: Text(
                  'Nguồn bản đồ & Bản quyền',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: colorScheme.onSurface),
                ),
                subtitle: Text(
                  MapConfig.defaultAttribution,
                  style: TextStyle(fontSize: 12, color: subtextColor),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
