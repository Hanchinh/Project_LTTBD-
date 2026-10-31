// Modal hướng dẫn và chọn phương thức tiếp nhận gói chia sẻ từ đồng nghiệp.
// Hỗ trợ mở tệp tin .dshare từ máy hoặc quét camera mã QR.
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:delivery_marker_mobile/features/sharing/data_share_import_preview_sheet.dart';
import 'package:delivery_marker_mobile/features/sharing/data_share_qr_scanner_view.dart';

class ReceiveShareModal {
  static void show({
    required BuildContext context,
    required VoidCallback onImportSuccess,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final colorScheme = theme.colorScheme;
        final isDark = theme.brightness == Brightness.dark;
        final subtextColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                'Chọn phương thức nhận dữ liệu',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: colorScheme.onSurface),
              ),
              const SizedBox(height: 16),
              ListTile(
                key: const Key('btn_receive_scan_qr'),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF2563EB).withValues(alpha: 0.15) : const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.qr_code_scanner_rounded, color: Color(0xFF2563EB), size: 24),
                ),
                title: Text('Quét mã QR từ máy khác', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: colorScheme.onSurface)),
                subtitle: Text('Nhận dữ liệu nhanh trực tiếp bằng camera', style: TextStyle(fontSize: 12, color: subtextColor)),
                trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
                onTap: () {
                  Navigator.pop(ctx);
                  DataShareQrScannerView.show(context, onImportSuccess: onImportSuccess);
                },
              ),
              Divider(height: 1, indent: 64, color: theme.dividerTheme.color),
              ListTile(
                key: const Key('btn_receive_open_file'),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF16A34A).withValues(alpha: 0.15) : const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.folder_open_rounded, color: Color(0xFF16A34A), size: 24),
                ),
                title: Text('Mở tệp chia sẻ (.dshare)', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: colorScheme.onSurface)),
                subtitle: Text('Chọn tệp đã lưu trong máy hoặc tải về từ Zalo/Drive', style: TextStyle(fontSize: 12, color: subtextColor)),
                trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
                onTap: () async {
                  Navigator.pop(ctx);
                  try {
                    final files = await FilePicker.pickFiles(
                      type: FileType.custom,
                      allowedExtensions: ['dshare', 'zip'],
                    );
                    if (files.isNotEmpty && files.first.path != null) {
                      final pickedFile = File(files.first.path!);
                      if (context.mounted) {
                        DataShareImportPreviewSheet.showFromFile(
                          context,
                          file: pickedFile,
                          onImportSuccess: onImportSuccess,
                        );
                      }
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Lỗi mở tệp: $e'), backgroundColor: const Color(0xFFDC2626)),
                      );
                    }
                  }
                },
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }
}
