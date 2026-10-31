// Bottom sheet quản lý sao lưu và phục hồi dữ liệu ứng dụng dạng gói ZIP.
// Cho phép xuất file sao lưu kèm ảnh và nhập lại dữ liệu an toàn khi đổi máy.
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:delivery_marker_mobile/data/backup/backup_service.dart';

class BackupRestoreBottomSheet extends StatefulWidget {
  final VoidCallback? onRestored;
  const BackupRestoreBottomSheet({super.key, this.onRestored});

  static Future<void> show(BuildContext context, {VoidCallback? onRestored}) =>
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => BackupRestoreBottomSheet(onRestored: onRestored),
      );

  @override
  State<BackupRestoreBottomSheet> createState() => _BackupRestoreBottomSheetState();
}

class _BackupRestoreBottomSheetState extends State<BackupRestoreBottomSheet> {
  final _backupService = BackupService();
  bool _includePhotos = true;
  bool _isProcessing = false;
  String? _statusMessage;
  File? _selectedBackupFile;
  BackupPreview? _backupPreview;
  RestoreMode _selectedRestoreMode = RestoreMode.merge;

  Future<void> _handleCreateBackup() async {
    if (_isProcessing) return;
    setState(() { _isProcessing = true; _statusMessage = 'Đang đóng gói CSDL và nén file sao lưu...'; });
    try {
      final zipFile = await _backupService.createBackup(includePhotos: _includePhotos);
      setState(() => _statusMessage = 'Đang mở hộp thoại chia sẻ hệ thống...');
      await _backupService.shareBackup(zipFile);
      if (!mounted) return;
      setState(() { _isProcessing = false; _statusMessage = null; });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Đã tạo file sao lưu: ${zipFile.path.split(Platform.pathSeparator).last}'), backgroundColor: const Color(0xFF10B981)));
    } catch (e) {
      if (!mounted) return;
      setState(() { _isProcessing = false; _statusMessage = null; });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi khi sao lưu: $e'), backgroundColor: const Color(0xFFDC2626)));
    }
  }

  Future<void> _handlePickFile() async {
    try {
      final files = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['zip']);
      if (files.isNotEmpty && files.first.path != null) {
        final file = File(files.first.path!);
        setState(() { _isProcessing = true; _statusMessage = 'Đang kiểm tra toàn vẹn file sao lưu...'; });
        final preview = await _backupService.readBackupPreview(file);
        if (!mounted) return;
        setState(() { _selectedBackupFile = file; _backupPreview = preview; _isProcessing = false; _statusMessage = null; });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() { _isProcessing = false; _statusMessage = null; });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Tệp không hợp lệ: ${e.toString().replaceAll('Exception: ', '')}'), backgroundColor: const Color(0xFFDC2626)));
    }
  }

  Future<void> _handleExecuteRestore() async {
    if (_selectedBackupFile == null || _isProcessing) return;
    if (_selectedRestoreMode == RestoreMode.fullReplace) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Cảnh báo thay thế toàn bộ', style: TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.w700)),
          content: const Text('Toàn bộ dữ liệu hiện tại trong máy sẽ bị thay thế bằng dữ liệu trong file sao lưu.\n\nHệ thống sẽ tự động tạo một bản sao lưu an toàn trước khi thực hiện. Bạn có chắc chắn muốn thay thế toàn bộ không?', style: TextStyle(fontSize: 13, height: 1.5)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('HỦY')),
            ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626), foregroundColor: Colors.white), onPressed: () => Navigator.pop(ctx, true), child: const Text('XÁC NHẬN GHI ĐÈ')),
          ],
        ),
      );
      if (confirm != true) return;
    }

    setState(() { _isProcessing = true; _statusMessage = 'Đang tiến hành khôi phục dữ liệu...'; });
    try {
      final res = await _backupService.restoreBackup(_selectedBackupFile!, mode: _selectedRestoreMode);
      if (!mounted) return;
      setState(() { _isProcessing = false; _statusMessage = null; });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res.message), backgroundColor: const Color(0xFF10B981), duration: const Duration(seconds: 4)));
      widget.onRestored?.call();
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() { _isProcessing = false; _statusMessage = null; });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi khôi phục: $e'), backgroundColor: const Color(0xFFDC2626)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final subtextColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final cardBg = isDark ? const Color(0xFF0B0F19) : const Color(0xFFF8FAFC);
    final borderColor = theme.dividerTheme.color ?? (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0));

    return Container(
      padding: EdgeInsets.only(top: 20, left: 20, right: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 24),
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
      decoration: BoxDecoration(color: colorScheme.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            Row(children: [const Icon(Icons.backup_rounded, color: Color(0xFF2563EB), size: 24), const SizedBox(width: 10), Text('Sao Lưu & Khôi Phục Dữ Liệu', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: colorScheme.onSurface))]),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: borderColor)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [const Icon(Icons.cloud_upload_outlined, color: Color(0xFF2563EB), size: 20), const SizedBox(width: 8), Text('1. Tạo bản sao lưu (.zip)', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: colorScheme.onSurface))]),
                  const SizedBox(height: 8),
                  Text('Đóng gói toàn bộ CSDL và ảnh mặt tiền thành 1 tệp .zip duy nhất để gửi qua Zalo, Drive hoặc lưu vào máy.', style: TextStyle(fontSize: 12, color: subtextColor, height: 1.4)),
                  const SizedBox(height: 12),
                  SwitchListTile(title: const Text('Bao gồm ảnh mặt tiền nhà', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)), subtitle: const Text('Bật để lưu giữ toàn bộ hình ảnh khách hàng', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))), value: _includePhotos, onChanged: (val) => setState(() => _includePhotos = val), dense: true, contentPadding: EdgeInsets.zero),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    key: const Key('btn_create_backup'),
                    onPressed: _isProcessing ? null : _handleCreateBackup,
                    icon: const Icon(Icons.archive_outlined),
                    label: const Text('TẠO BẢN SAO LƯU & CHIA SẺ'),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white, minimumSize: const Size.fromHeight(48), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: borderColor)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [const Icon(Icons.settings_backup_restore_rounded, color: Color(0xFF16A34A), size: 20), const SizedBox(width: 8), Text('2. Khôi phục từ file sao lưu', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: colorScheme.onSurface))]),
                  const SizedBox(height: 8),
                  Text('Chọn tệp .zip đã sao lưu trước đó để phục hồi lại dữ liệu.', style: TextStyle(fontSize: 12, color: subtextColor)),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    key: const Key('btn_pick_backup_file'),
                    onPressed: _isProcessing ? null : _handlePickFile,
                    icon: const Icon(Icons.file_open_outlined),
                    label: Text(_selectedBackupFile == null ? 'CHỌN FILE SAO LƯU (.ZIP)' : 'ĐỔI FILE KHÁC'),
                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  ),
                  if (_backupPreview != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: colorScheme.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: borderColor)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Xem trước dữ liệu bản sao lưu:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: colorScheme.onSurface)),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildStatItem('Khách hàng', _backupPreview!.customersCount),
                              _buildStatItem('Vị trí', _backupPreview!.savedLocationsCount),
                              _buildStatItem('Ca giao', _backupPreview!.shiftsCount),
                              _buildStatItem('Ảnh', _backupPreview!.photosCount),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text('Chọn phương thức khôi phục:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: colorScheme.onSurface)),
                    const SizedBox(height: 4),
                    _buildRestoreTile('Gộp vào dữ liệu hiện có (Khuyên dùng)', 'Khách trùng SĐT được giữ nguyên, chỉ thêm vị trí/ảnh mới.', RestoreMode.merge),
                    _buildRestoreTile('Thay toàn bộ dữ liệu', 'Xóa dữ liệu hiện tại và thay bằng file sao lưu (có tự động sao lưu an toàn).', RestoreMode.fullReplace, isDanger: true),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      key: const Key('btn_execute_restore'),
                      onPressed: _isProcessing ? null : _handleExecuteRestore,
                      style: ElevatedButton.styleFrom(backgroundColor: _selectedRestoreMode == RestoreMode.fullReplace ? const Color(0xFFDC2626) : const Color(0xFF16A34A), foregroundColor: Colors.white, minimumSize: const Size.fromHeight(48), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                      child: const Text('TIẾN HÀNH KHÔI PHỤC'),
                    ),
                  ],
                ],
              ),
            ),
            if (_isProcessing) ...[
              const SizedBox(height: 20),
              Center(child: Column(children: [const CircularProgressIndicator(), const SizedBox(height: 10), Text(_statusMessage ?? 'Đang xử lý...', style: TextStyle(fontSize: 13, color: subtextColor))])),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, int val) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        Text(val.toString(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF2563EB))),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
      ],
    );
  }

  Widget _buildRestoreTile(String title, String subtitle, RestoreMode mode, {bool isDanger = false}) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final sel = _selectedRestoreMode == mode;
    final borderColor = theme.dividerTheme.color ?? (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0));

    return InkWell(
      key: Key('restore_mode_${mode.name}'),
      onTap: () => setState(() => _selectedRestoreMode = mode),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: sel ? (isDanger ? (isDark ? const Color(0xFF7F1D1D).withValues(alpha: 0.3) : const Color(0xFFFEF2F2)) : (isDark ? const Color(0xFF064E3B).withValues(alpha: 0.3) : const Color(0xFFF0FDF4))) : (isDark ? const Color(0xFF0B0F19) : const Color(0xFFF8FAFC)),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: sel ? (isDanger ? const Color(0xFFDC2626) : const Color(0xFF16A34A)) : borderColor, width: sel ? 1.5 : 1.0),
        ),
        child: Row(
          children: [
            Icon(sel ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded, color: sel ? (isDanger ? const Color(0xFFDC2626) : const Color(0xFF16A34A)) : const Color(0xFF94A3B8), size: 20),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: TextStyle(fontSize: 13, fontWeight: sel ? FontWeight.w700 : FontWeight.w500, color: isDanger && sel ? const Color(0xFFDC2626) : theme.colorScheme.onSurface)), const SizedBox(height: 2), Text(subtitle, style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)))])),
          ],
        ),
      ),
    );
  }
}
