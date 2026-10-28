import 'package:flutter/material.dart';
import 'package:delivery_marker_mobile/core/theme/app_buttons.dart';
import 'package:delivery_marker_mobile/features/profile/widgets/backup_restore_bottom_sheet.dart';
import 'package:delivery_marker_mobile/features/sharing/data_share_send_sheet.dart';
import 'package:delivery_marker_mobile/features/profile/widgets/pin_settings_bottom_sheet.dart';
import 'package:delivery_marker_mobile/features/profile/widgets/receive_share_modal.dart';

class ProfileLocalActionsSection extends StatelessWidget {
  final VoidCallback onDataReload;

  const ProfileLocalActionsSection({
    super.key,
    required this.onDataReload,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final bgCard = colorScheme.surface;
    final borderColor = theme.dividerTheme.color ?? (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0));
    final subtextColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Column(
      children: [
        // 1. MỤC BẢO MẬT & SAO LƯU (LOCAL-FIRST)
        Material(
          color: bgCard,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: borderColor),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              ListTile(
                key: const Key('profile_pin_item'),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF2563EB).withValues(alpha: 0.15) : const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.shield_outlined, color: Color(0xFF2563EB), size: 22),
                ),
                title: Text(
                  'Bảo mật & Mã PIN khóa app',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: colorScheme.onSurface),
                ),
                subtitle: Text(
                  'Đặt/đổi mã PIN hoặc cấu hình thời gian tự động khóa',
                  style: TextStyle(fontSize: 12, color: subtextColor),
                ),
                trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
                onTap: () => PinSettingsBottomSheet.show(context),
              ),
              Divider(height: 1, indent: 64, endIndent: 16, color: borderColor),
              ListTile(
                key: const Key('profile_backup_item'),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF16A34A).withValues(alpha: 0.15) : const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.backup_outlined, color: Color(0xFF16A34A), size: 22),
                ),
                title: Text(
                  'Sao lưu & Khôi phục dữ liệu',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: colorScheme.onSurface),
                ),
                subtitle: Text(
                  'Xuất file zip sao lưu hoặc phục hồi dữ liệu',
                  style: TextStyle(fontSize: 12, color: subtextColor),
                ),
                trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
                onTap: () => BackupRestoreBottomSheet.show(context, onRestored: onDataReload),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // 2. MỤC CHIA SẺ DỮ LIỆU CỤC BỘ (LOCAL-FIRST)
        Material(
          color: bgCard,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: borderColor),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.share_location_rounded, color: Color(0xFF2563EB), size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Chia sẻ dữ liệu',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Gửi và nhận điểm trực tiếp giữa các shipper qua tệp .dshare hoặc quét mã QR',
                  style: TextStyle(fontSize: 13, color: subtextColor),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: ElevatedButton.icon(
                          key: const Key('profile_btn_send_share'),
                          style: AppButtons.primary(minHeight: 48, borderRadius: 12),
                          onPressed: () => DataShareSendSheet.show(context),
                          icon: const Icon(Icons.upload_rounded, size: 18),
                          label: const Text('GỬI DỮ LIỆU'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: OutlinedButton.icon(
                          key: const Key('profile_btn_receive_share'),
                          style: AppButtons.secondary(minHeight: 48, borderRadius: 12),
                          onPressed: () => ReceiveShareModal.show(
                            context: context,
                            onImportSuccess: onDataReload,
                          ),
                          icon: const Icon(Icons.download_rounded, size: 18),
                          label: const Text('NHẬN DỮ LIỆU'),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
