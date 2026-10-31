// Bottom sheet tạo gói chia sẻ điểm giao hàng gửi cho tài xế khác.
// Cho phép chọn danh sách điểm, cài đặt mật khẩu bảo vệ và xuất file .dshare.
import 'package:flutter/material.dart';
import 'package:delivery_marker_mobile/models/shift_model.dart';
import 'package:delivery_marker_mobile/data/repository_provider.dart';
import 'package:delivery_marker_mobile/core/theme/app_buttons.dart';
import 'package:delivery_marker_mobile/features/sharing/data_share_qr_view.dart';

class DataShareSendSheet extends StatefulWidget {
  final List<String>? initialCustomerIds;
  final String? initialShiftId;
  final String? singleCustomerName;

  const DataShareSendSheet({super.key, this.initialCustomerIds, this.initialShiftId, this.singleCustomerName});

  static Future<void> show(BuildContext context, {List<String>? initialCustomerIds, String? initialShiftId, String? singleCustomerName}) =>
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => DataShareSendSheet(initialCustomerIds: initialCustomerIds, initialShiftId: initialShiftId, singleCustomerName: singleCustomerName),
      );

  @override
  State<DataShareSendSheet> createState() => _DataShareSendSheetState();
}

class _DataShareSendSheetState extends State<DataShareSendSheet> {
  String _scope = 'all';
  List<ShiftModel> _shifts = [];
  String? _selectedShiftId;
  bool _isLoadingShifts = false;
  bool _includePhotos = false;
  bool _includeCustomerInfo = true;
  bool _hasPassword = false;
  final _passwordController = TextEditingController();
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialCustomerIds != null && widget.initialCustomerIds!.isNotEmpty) {
      _scope = 'selected';
    } else if (widget.initialShiftId != null) {
      _scope = 'shift';
      _selectedShiftId = widget.initialShiftId;
    }
    _loadShifts();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadShifts() async {
    setState(() => _isLoadingShifts = true);
    try {
      final list = await RepositoryProvider.shift.getShifts();
      if (mounted) setState(() { _shifts = list; _selectedShiftId ??= list.isNotEmpty ? list.first.id : null; _isLoadingShifts = false; });
    } catch (_) {
      if (mounted) setState(() => _isLoadingShifts = false);
    }
  }

  Future<void> _handleExportFile() async {
    setState(() => _isExporting = true);
    try {
      final repo = RepositoryProvider.localSharing;
      final file = await repo.exportSharePackage(
        scope: _scope,
        shiftId: _scope == 'shift' ? _selectedShiftId : null,
        customerIds: _scope == 'selected' ? widget.initialCustomerIds : null,
        includeCustomerInfo: _includeCustomerInfo,
        includePhotos: _includePhotos,
        password: _hasPassword ? _passwordController.text.trim() : null,
      );
      if (!mounted) return;
      Navigator.pop(context);
      await repo.sharePackageFile(file);
    } catch (e) {
      if (mounted) {
        setState(() => _isExporting = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi tạo gói chia sẻ: $e'), backgroundColor: const Color(0xFFDC2626)));
      }
    }
  }

  Future<void> _handleExportQr() async {
    setState(() => _isExporting = true);
    try {
      final repo = RepositoryProvider.localSharing;
      final chunks = await repo.exportQrChunks(
        scope: _scope,
        shiftId: _scope == 'shift' ? _selectedShiftId : null,
        customerIds: _scope == 'selected' ? widget.initialCustomerIds : null,
        includeCustomerInfo: _includeCustomerInfo,
        password: _hasPassword ? _passwordController.text.trim() : null,
      );
      if (!mounted) return;
      final profile = await RepositoryProvider.localProfile.getCurrentUser();
      if (!mounted) return;
      Navigator.pop(context);
      await DataShareQrView.show(
        context,
        qrChunks: chunks,
        pointsCount: widget.initialCustomerIds?.length ?? 1,
        senderName: (profile != null && profile.fullName.isNotEmpty) ? profile.fullName : 'Shipper',
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isExporting = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi tạo mã QR: $e'), backgroundColor: const Color(0xFFDC2626)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.82,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      snap: true,
      builder: (ctx, scrollController) {
        return Container(
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
          child: Column(
            children: [
              Center(child: Container(margin: const EdgeInsets.only(top: 10, bottom: 8), width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2)))),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    const Icon(Icons.share_rounded, color: Color(0xFF0F172A), size: 22),
                    const SizedBox(width: 10),
                    Expanded(child: Text(widget.singleCustomerName != null ? 'Chia sẻ: ${widget.singleCustomerName}' : 'Gửi Dữ Liệu Điểm Giao', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)), overflow: TextOverflow.ellipsis)),
                    IconButton(icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)), tooltip: 'Đóng', onPressed: () => Navigator.pop(context)),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  children: [
                    Container(
                      key: const Key('share_warning_banner'),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFFECACA))),
                      child: const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.shield_outlined, color: Color(0xFFDC2626), size: 22),
                          SizedBox(width: 10),
                          Expanded(child: Text('Dữ liệu chứa số điện thoại và địa chỉ khách. Đã gửi thì không thu hồi được. Chỉ gửi cho người bạn tin tưởng.', style: TextStyle(fontSize: 13, color: Color(0xFF991B1B), fontWeight: FontWeight.w600, height: 1.35))),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    if (widget.initialCustomerIds == null) ...[
                      const Text('Phạm vi chia sẻ:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                      const SizedBox(height: 8),
                      Material(
                        color: const Color(0xFFF8FAFC),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFFE2E8F0))),
                        clipBehavior: Clip.antiAlias,
                        child: RadioGroup<String>(
                          groupValue: _scope,
                          onChanged: (val) { if (val != null) setState(() => _scope = val); },
                          child: const Column(
                            children: [
                              RadioListTile<String>(key: Key('scope_all'), dense: true, value: 'all', title: Text('Tất cả điểm đã lưu', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)), subtitle: Text('Toàn bộ sổ địa chỉ khách có vị trí', style: TextStyle(fontSize: 12, color: Color(0xFF64748B)))),
                              Divider(height: 1, indent: 16, endIndent: 16),
                              RadioListTile<String>(key: Key('scope_shift'), dense: true, value: 'shift', title: Text('Một ca làm việc', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)), subtitle: Text('Chỉ các điểm nằm trong một ca cụ thể', style: TextStyle(fontSize: 12, color: Color(0xFF64748B)))),
                            ],
                          ),
                        ),
                      ),
                      if (_scope == 'shift') ...[
                        const SizedBox(height: 10),
                        _isLoadingShifts
                            ? const Center(child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator()))
                            : _shifts.isEmpty
                                ? const Padding(padding: EdgeInsets.all(8), child: Text('Chưa có ca làm việc nào', style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8))))
                                : Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14),
                                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFCBD5E1))),
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<String>(
                                        isExpanded: true,
                                        value: _selectedShiftId,
                                        items: _shifts.map((s) => DropdownMenuItem(value: s.id, child: Text('${s.shiftName ?? s.shiftCode} (${s.shiftDate})', style: const TextStyle(fontSize: 14)))).toList(),
                                        onChanged: (val) => setState(() => _selectedShiftId = val),
                                      ),
                                    ),
                                  ),
                      ],
                      const SizedBox(height: 18),
                    ],
                    const Text('Tùy chọn dữ liệu:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                    const SizedBox(height: 8),
                    Material(
                      color: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFFE2E8F0))),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        children: [
                          SwitchListTile(
                            key: const Key('switch_include_customer_info'),
                            dense: true,
                            title: const Text('Kèm tên và địa chỉ khách', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                            subtitle: const Text('Tắt để giảm dữ liệu cá nhân (chỉ gửi SĐT & tọa độ)', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                            value: _includeCustomerInfo,
                            activeThumbColor: const Color(0xFF0F172A),
                            onChanged: (val) => setState(() => _includeCustomerInfo = val),
                          ),
                          const Divider(height: 1, indent: 16, endIndent: 16),
                          SwitchListTile(
                            key: const Key('switch_include_photos'),
                            dense: true,
                            title: const Text('Kèm ảnh nhà', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                            subtitle: const Text('Chỉ áp dụng khi tạo file .dshare (mã QR không kèm ảnh)', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                            value: _includePhotos,
                            activeThumbColor: const Color(0xFF0F172A),
                            onChanged: (val) => setState(() => _includePhotos = val),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    Material(
                      color: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFFE2E8F0))),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        children: [
                          SwitchListTile(
                            key: const Key('switch_has_password'),
                            dense: true,
                            title: const Text('Bảo vệ bằng mật khẩu (AES-GCM)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                            subtitle: const Text('Người nhận phải nhập đúng mật khẩu mới mở được', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                            value: _hasPassword,
                            activeThumbColor: const Color(0xFF0F172A),
                            onChanged: (val) => setState(() => _hasPassword = val),
                          ),
                          if (_hasPassword)
                            Padding(
                              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  TextField(
                                    key: const Key('input_export_password'),
                                    controller: _passwordController,
                                    obscureText: true,
                                    decoration: InputDecoration(hintText: 'Nhập mật khẩu bảo vệ...', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
                                  ),
                                  const SizedBox(height: 6),
                                  const Text('Lưu ý: Mất mật khẩu sẽ không thể mở được tệp dữ liệu.', style: TextStyle(fontSize: 11, color: Color(0xFFDC2626), fontStyle: FontStyle.italic)),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      height: 52,
                      child: ElevatedButton.icon(
                        key: const Key('btn_export_file_and_send'),
                        style: AppButtons.primary(minHeight: 52),
                        onPressed: _isExporting ? null : _handleExportFile,
                        icon: const Icon(Icons.send_rounded),
                        label: const Text('TẠO FILE VÀ GỬI (.dshare)', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 52,
                      child: OutlinedButton.icon(
                        key: const Key('btn_export_qr_code'),
                        style: AppButtons.secondary(minHeight: 52),
                        onPressed: _isExporting ? null : _handleExportQr,
                        icon: const Icon(Icons.qr_code_2_rounded),
                        label: const Text('HIỆN MÃ QR', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
