import 'package:flutter/material.dart';
import 'package:delivery_marker_mobile/models/data_share_model.dart';
import 'package:delivery_marker_mobile/data/repositories/repository_provider.dart';
import 'package:delivery_marker_mobile/core/theme/app_buttons.dart';

class ImportSharedPointHelper {
  static Future<void> handleImportSinglePoint({
    required BuildContext context,
    required SharedLocationPointModel point,
    required VoidCallback onSuccess,
  }) async {
    bool replaceExisting = false;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text(
                'Nhập vị trí vào của tôi',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Lưu vị trí khách hàng "${point.customerName}" vào danh sách vị trí đã lưu của bạn.',
                    style: const TextStyle(fontSize: 14, color: Color(0xFF334155)),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    key: const Key('switch_replace_existing_single'),
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Ghi đè nếu đã tồn tại vị trí',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    value: replaceExisting,
                    activeThumbColor: AppButtons.navy,
                    onChanged: (val) => setDialogState(() => replaceExisting = val),
                  ),
                ],
              ),
              actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              actions: [
                TextButton(
                  style: AppButtons.text(minHeight: 48),
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('HỦY', style: TextStyle(color: Color(0xFF64748B))),
                ),
                ElevatedButton(
                  key: const Key('btn_confirm_import_single_point'),
                  style: AppButtons.primary(minHeight: 48, borderRadius: 10),
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: const Text('NHẬP VỊ TRÍ'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirm == true) {
      try {
        final res = await RepositoryProvider.sharing.importSharedLocations(
          point.shareId,
          customerIds: [point.customerId],
          all: false,
          replaceExisting: replaceExisting,
        );
        final imported = res['importedCount'] ?? 0;
        final skipped = res['skippedCount'] ?? 0;

        if (context.mounted) {
          if (imported > 0) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Đã nhập vị trí vào danh bạ của bạn thành công!'),
                backgroundColor: Color(0xFF0F172A),
              ),
            );
            onSuccess();
          } else if (skipped > 0) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Khách hàng đã có vị trí (chưa bật ghi đè)'),
                backgroundColor: Color(0xFFF59E0B),
              ),
            );
          }
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Lỗi khi nhập vị trí: $e'),
              backgroundColor: const Color(0xFFEF4444),
            ),
          );
        }
      }
    }
  }
}
