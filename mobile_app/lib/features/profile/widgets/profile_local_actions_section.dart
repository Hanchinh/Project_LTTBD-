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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. MỤC BẢO MẬT & SAO LƯU
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'BẢO MẬT & SAO LƯU',
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
            side: BorderSide(color: borderColor, width: 1),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              ListTile(
                key: const Key('profile_pin_item'),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                leading: const Icon(Icons.shield_outlined, color: Color(0xFF2563EB), size: 24),
                title: Text(
                  'Bảo mật & Mã PIN khóa app',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: colorScheme.onSurface),
                ),
                subtitle: Text(
                  'Đặt/đổi mã PIN hoặc cấu hình thời gian tự động khóa',
                  style: TextStyle(fontSize: 12, color: subtextColor),
                ),
                trailing: Icon(Icons.chevron_right_rounded, color: subtextColor, size: 22),
                onTap: () => PinSettingsBottomSheet.show(context),
              ),
              Divider(height: 1, indent: 56, endIndent: 16, color: borderColor),
              ListTile(
                key: const Key('profile_backup_item'),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                leading: const Icon(Icons.backup_outlined, color: Color(0xFF16A34A), size: 24),
                title: Text(
                  'Sao lưu & Khôi phục dữ liệu',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: colorScheme.onSurface),
                ),
                subtitle: Text(
                  'Xuất file zip sao lưu hoặc phục hồi dữ liệu',
                  style: TextStyle(fontSize: 12, color: subtextColor),
                ),
                trailing: Icon(Icons.chevron_right_rounded, color: subtextColor, size: 22),
                onTap: () => BackupRestoreBottomSheet.show(context, onRestored: onDataReload),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),

        // 2. MỤC CHIA SẺ DỮ LIỆU
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'CHIA SẺ DỮ LIỆU THỰC ĐỊA',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: subtextColor,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: bgCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.share_location_rounded, color: Color(0xFF2563EB), size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Chia sẻ điểm & ca giao hàng',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Gửi và nhận điểm trực tiếp giữa các shipper qua tệp .dshare hoặc quét mã QR',
                style: TextStyle(fontSize: 12, color: subtextColor),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: ElevatedButton.icon(
                        key: const Key('profile_btn_send_share'),
                        style: AppButtons.primary(
                          minHeight: 48,
                          borderRadius: 10,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                        ),
                        onPressed: () => DataShareSendSheet.show(context),
                        icon: const Icon(Icons.upload_rounded, size: 18),
                        label: const Text(
                          'GỬI DỮ LIỆU',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: OutlinedButton.icon(
                        key: const Key('profile_btn_receive_share'),
                        style: AppButtons.secondary(
                          minHeight: 48,
                          borderRadius: 10,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                        ),
                        onPressed: () => ReceiveShareModal.show(
                          context: context,
                          onImportSuccess: onDataReload,
                        ),
                        icon: const Icon(Icons.download_rounded, size: 18),
                        label: const Text(
                          'NHẬN DỮ LIỆU',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
