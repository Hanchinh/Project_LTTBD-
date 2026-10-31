// Bottom sheet xem trước và chọn lọc các điểm giao trước khi nhập vào máy.
// Hỗ trợ nhập mật khẩu giải mã gói và phân loại các điểm trùng lặp.
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:delivery_marker_mobile/models/local_share_models.dart';
import 'package:delivery_marker_mobile/data/repository_provider.dart';
import 'package:delivery_marker_mobile/core/theme/app_buttons.dart';
import 'package:delivery_marker_mobile/features/sharing/widgets/share_point_item_card.dart';
import 'package:delivery_marker_mobile/features/sharing/widgets/share_import_options_card.dart';

class DataShareImportPreviewSheet extends StatefulWidget {
  final File? packageFile;
  final String? qrPayload;
  final VoidCallback? onImportSuccess;

  const DataShareImportPreviewSheet({super.key, this.packageFile, this.qrPayload, this.onImportSuccess});

  static Future<void> showFromFile(BuildContext context, {required File file, VoidCallback? onImportSuccess}) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => DataShareImportPreviewSheet(packageFile: file, onImportSuccess: onImportSuccess)));

  static Future<void> showFromQr(BuildContext context, {required String qrPayload, VoidCallback? onImportSuccess}) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => DataShareImportPreviewSheet(qrPayload: qrPayload, onImportSuccess: onImportSuccess)));

  @override
  State<DataShareImportPreviewSheet> createState() => _DataShareImportPreviewSheetState();
}

class _DataShareImportPreviewSheetState extends State<DataShareImportPreviewSheet> {
  bool _isLoading = true;
  String? _errorMessage;
  SharePackagePreview? _preview;
  ShareImportMode _importMode = ShareImportMode.addOnly;
  bool _createShift = true;
  late final TextEditingController _shiftNameController = TextEditingController();
  bool _isImporting = false;

  @override
  void initState() {
    super.initState();
    _loadAndInspectData();
  }

  @override
  void dispose() {
    _shiftNameController.dispose();
    super.dispose();
  }

  Future<void> _loadAndInspectData({String? password}) async {
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      final preview = widget.packageFile != null
          ? await RepositoryProvider.localSharing.inspectPackageFile(widget.packageFile!, password: password)
          : await RepositoryProvider.localSharing.inspectQrPayload(widget.qrPayload!, password: password);

      final nowUtc = DateTime.now().toUtc().add(const Duration(hours: 7));
      final dateStr = '${nowUtc.day.toString().padLeft(2, '0')}/${nowUtc.month.toString().padLeft(2, '0')}';
      _shiftNameController.text = 'Từ ${preview.manifest.senderDisplayName} $dateStr';

      if (mounted) setState(() { _preview = preview; _isLoading = false; });
    } on FormatException catch (e) {
      if (e.message == 'GÓI_YÊU_CẦU_MẬT_KHẨU' || e.message.contains('Mật khẩu không chính xác')) {
        if (!mounted) return;
        final pass = await SharePasswordDialog.show(context, isRetry: e.message.contains('Mật khẩu không chính xác'));
        if (pass != null) {
          await _loadAndInspectData(password: pass);
          return;
        }
      }
      if (mounted) setState(() { _errorMessage = e.message; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() { _errorMessage = e.toString().replaceAll('Exception: ', ''); _isLoading = false; });
    }
  }

  Future<void> _handleConfirmImport() async {
    if (_preview == null) return;
    final selectedIndexes = <int>{};
    for (int i = 0; i < _preview!.classifiedPoints.length; i++) {
      if (_preview!.classifiedPoints[i].isSelected && _preview!.classifiedPoints[i].classification != SharePointClassification.invalid) {
        selectedIndexes.add(i);
      }
    }
    if (selectedIndexes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng chọn ít nhất một điểm hợp lệ để nhập')));
      return;
    }

    if (_importMode == ShareImportMode.replaceExisting && _preview!.existingWithLocCount > 0) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(children: [Icon(Icons.warning_amber_rounded, color: Color(0xFFD97706), size: 24), SizedBox(width: 8), Text('Xác nhận thay vị trí cũ?')]),
          content: Text('Có ${_preview!.existingWithLocCount} khách hàng đã có vị trí trong máy của bạn.\n\nTọa độ cũ sẽ được thay bằng tọa độ nhận được. Lịch sử vị trí cũ vẫn được hệ thống lưu trữ an toàn.', style: const TextStyle(fontSize: 14, height: 1.4)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('HỦY')),
            ElevatedButton(style: AppButtons.primary(minHeight: 44), onPressed: () => Navigator.pop(ctx, true), child: const Text('ĐỒNG Ý THAY')),
          ],
        ),
      );
      if (confirm != true) return;
    }

    setState(() => _isImporting = true);
    try {
      final result = await RepositoryProvider.localSharing.importPackage(
        preview: _preview!,
        mode: _importMode,
        selectedIndexes: selectedIndexes,
        createShift: _createShift,
        shiftName: _shiftNameController.text.trim().isNotEmpty ? _shiftNameController.text.trim() : null,
      );
      if (!mounted) return;
      widget.onImportSuccess?.call();

      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(children: [Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 26), SizedBox(width: 8), Text('Nhập Dữ Liệu Hoàn Tất', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))]),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildResultRow('Điểm mới đã thêm:', '${result.addedCount} điểm', const Color(0xFF16A34A)),
              _buildResultRow('Vị trí đã thay thế:', '${result.replacedCount} điểm', const Color(0xFF2563EB)),
              _buildResultRow('Điểm trùng bỏ qua:', '${result.skippedCount} điểm', const Color(0xFF64748B)),
              if (result.photosAdded > 0) _buildResultRow('Ảnh nhà đã nạp:', '${result.photosAdded} ảnh', const Color(0xFFD97706)),
              if (result.createdShiftName != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(8)),
                  child: Row(children: [const Icon(Icons.assignment_turned_in_rounded, size: 18, color: Color(0xFF0F172A)), const SizedBox(width: 6), Expanded(child: Text('Đã tạo ca: ${result.createdShiftName}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)))]),
                ),
              ],
            ],
          ),
          actions: [
            ElevatedButton(
              key: const Key('btn_close_import_success'),
              style: AppButtons.primary(minHeight: 48),
              onPressed: () { Navigator.pop(ctx); Navigator.pop(context); },
              child: const Text('XONG'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isImporting = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi khi nhập dữ liệu: $e'), backgroundColor: const Color(0xFFDC2626)));
      }
    }
  }

  Widget _buildResultRow(String label, String value, Color color) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label, style: const TextStyle(fontSize: 14, color: Color(0xFF475569))), Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color))]),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(backgroundColor: const Color(0xFF0F172A), foregroundColor: Colors.white, elevation: 0, title: const Text('Tiếp Nhận Dữ Liệu', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
      body: _isLoading ? const Center(child: CircularProgressIndicator()) : _errorMessage != null ? _buildErrorView() : _buildPreviewContent(),
    );
  }

  Widget _buildErrorView() => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 54),
          const SizedBox(height: 16),
          const Text('Không Thể Mở Gói Dữ Liệu', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
          const SizedBox(height: 8),
          Text(_errorMessage!, style: const TextStyle(fontSize: 14, color: Color(0xFF64748B), height: 1.4), textAlign: TextAlign.center),
          const SizedBox(height: 24),
          ElevatedButton(style: AppButtons.primary(minHeight: 48), onPressed: () => Navigator.pop(context), child: const Text('QUAY LẠI')),
        ],
      ),
    ),
  );

  Widget _buildPreviewContent() {
    final p = _preview!;
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE2E8F0))),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [const Icon(Icons.person_pin_circle_rounded, color: Color(0xFF2563EB), size: 22), const SizedBox(width: 8), Expanded(child: Text('Từ người gửi: ${p.manifest.senderDisplayName}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))))]),
                      const SizedBox(height: 10),
                      Row(children: [
                        _buildBadge('${p.validPointsCount} điểm hợp lệ', const Color(0xFF16A34A), const Color(0xFFF0FDF4)),
                        const SizedBox(width: 8),
                        if (p.photos.isNotEmpty) _buildBadge('${p.photos.length} ảnh nhà', const Color(0xFFD97706), const Color(0xFFFFFBEB)),
                        if (p.invalidCount > 0) ...[const SizedBox(width: 8), _buildBadge('${p.invalidCount} lỗi (bỏ qua)', const Color(0xFFDC2626), const Color(0xFFFEF2F2))],
                      ]),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                ShareImportOptionsCard(
                  importMode: _importMode,
                  onImportModeChanged: (val) => setState(() => _importMode = val),
                  createShift: _createShift,
                  onCreateShiftChanged: (val) => setState(() => _createShift = val),
                  shiftNameController: _shiftNameController,
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Danh sách điểm (${p.selectedCount}/${p.validPointsCount})', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                    TextButton(
                      style: AppButtons.text(minHeight: 36),
                      onPressed: () {
                        final anyUnselected = p.classifiedPoints.any((pt) => !pt.isSelected && pt.classification != SharePointClassification.invalid);
                        setState(() { for (final pt in p.classifiedPoints) { if (pt.classification != SharePointClassification.invalid) pt.isSelected = anyUnselected; } });
                      },
                      child: Text(
                        p.classifiedPoints.any((pt) => !pt.isSelected && pt.classification != SharePointClassification.invalid) ? 'Chọn tất cả' : 'Bỏ chọn tất cả',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF2563EB)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: p.classifiedPoints.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (ctx, idx) {
                    final item = p.classifiedPoints[idx];
                    return SharePointItemCard(item: item, index: idx, onSelectionChanged: (val) { if (val != null) setState(() => item.isSelected = val); });
                  },
                ),
              ],
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: const BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.08), blurRadius: 8, offset: Offset(0, -2))]),
          child: SafeArea(
            top: false,
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                key: const Key('btn_confirm_import'),
                style: AppButtons.primary(minHeight: 52),
                onPressed: _isImporting ? null : _handleConfirmImport,
                child: _isImporting
                    ? const Row(mainAxisAlignment: MainAxisAlignment.center, children: [SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5)), SizedBox(width: 10), Text('ĐANG LƯU DỮ LIỆU...')])
                    : Text('TIẾP NHẬN ${p.selectedCount} ĐIỂM', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBadge(String label, Color text, Color bg) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
    child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: text)),
  );
}

/// Hộp thoại yêu cầu người dùng nhập mật khẩu giải mã gói dữ liệu chia sẻ
class SharePasswordDialog {
  static Future<String?> show(BuildContext context, {bool isRetry = false}) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.lock_rounded, color: Color(0xFF0F172A), size: 24),
            const SizedBox(width: 8),
            Text(
              isRetry ? 'Mật khẩu sai, thử lại' : 'Nhập mật khẩu mở gói',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isRetry
                  ? 'Mật khẩu bạn vừa nhập không đúng. Vui lòng kiểm tra lại với người gửi.'
                  : 'Gói chia sẻ này được mã hóa bảo vệ bằng mật khẩu.',
              style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('input_share_password'),
              controller: controller,
              obscureText: true,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Nhập mật khẩu...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('HỦY', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            key: const Key('btn_confirm_share_password'),
            style: AppButtons.primary(minHeight: 44),
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('MỞ KHÓA'),
          ),
        ],
      ),
    );
  }
}

