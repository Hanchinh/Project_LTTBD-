// Hộp thoại gán số điện thoại khách hàng khi ghim vị trí mới trực tiếp trên map.
// Tự động đối soát với danh bạ hiện có để liên kết hoặc tạo khách hàng mới.
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:delivery_marker_mobile/models/customer_model.dart';
import 'package:delivery_marker_mobile/models/location_model.dart';
import 'package:delivery_marker_mobile/core/theme/app_buttons.dart';
import 'package:delivery_marker_mobile/core/utils/phone_utils.dart';

class AssignPhoneBottomSheet extends StatefulWidget {
  final LatLng targetCoord;
  final MasterSavedLocationModel? repinTarget;
  final List<CustomerDirectoryModel> directoryCustomers;
  final Future<void> Function({
    required String phone,
    required String fullName,
    required String notes,
    required LatLng targetCoord,
    String? knownCustomerId,
  }) onConfirmSave;

  const AssignPhoneBottomSheet({
    super.key,
    required this.targetCoord,
    this.repinTarget,
    required this.directoryCustomers,
    required this.onConfirmSave,
  });

  static Future<void> show({
    required BuildContext context,
    required LatLng targetCoord,
    MasterSavedLocationModel? repinTarget,
    required List<CustomerDirectoryModel> directoryCustomers,
    required Future<void> Function({required String phone, required String fullName, required String notes, required LatLng targetCoord, String? knownCustomerId}) onConfirmSave,
  }) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (_) => AssignPhoneBottomSheet(targetCoord: targetCoord, repinTarget: repinTarget, directoryCustomers: directoryCustomers, onConfirmSave: onConfirmSave),
      );

  @override
  State<AssignPhoneBottomSheet> createState() => _AssignPhoneBottomSheetState();
}

class _AssignPhoneBottomSheetState extends State<AssignPhoneBottomSheet> {
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _nameCtrl;
  late final TextEditingController _notesCtrl;
  MasterSavedLocationModel? _currentRepinTarget;
  late String _normalizedPhone;
  late List<CustomerDirectoryModel> _suggestions;

  @override
  void initState() {
    super.initState();
    _currentRepinTarget = widget.repinTarget;
    _phoneCtrl = TextEditingController(text: _currentRepinTarget?.customerPhone ?? '');
    _nameCtrl = TextEditingController(text: _currentRepinTarget?.customerName ?? '');
    _notesCtrl = TextEditingController(text: _currentRepinTarget?.identificationNotes ?? '');
    _normalizedPhone = _currentRepinTarget != null ? normalizeCustomerPhone(_currentRepinTarget!.customerPhone) : '';
    _suggestions = List.from(widget.directoryCustomers);
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _nameCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _updateFilter(String query) {
    final clean = normalizeCustomerPhone(query);
    setState(() {
      _normalizedPhone = clean;
      if (query.trim().isEmpty) {
        _suggestions = List.from(widget.directoryCustomers);
      } else {
        _suggestions = widget.directoryCustomers.where((c) => c.phoneNumber.contains(clean) || c.phoneNumber.contains(query.trim()) || c.fullName.toLowerCase().contains(query.trim().toLowerCase())).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: 20, right: 20, top: 16, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 12),
            const Row(children: [Icon(Icons.add_location_alt_rounded, color: Color(0xFF2563EB), size: 24), SizedBox(width: 8), Expanded(child: Text('Gán cho số điện thoại nào?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))))]),
            const SizedBox(height: 4),
            Text('Tọa độ: ${widget.targetCoord.latitude.toStringAsFixed(6)}, ${widget.targetCoord.longitude.toStringAsFixed(6)}', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
            const SizedBox(height: 16),
            if (_currentRepinTarget != null)
              Container(
                key: const Key('repin_customer_banner'),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFBFDBFE))),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded, size: 18, color: Color(0xFF2563EB)),
                    const SizedBox(width: 8),
                    Expanded(child: Text('Đang ghim lại cho: ${_currentRepinTarget!.customerName} - ${_currentRepinTarget!.customerPhone}', key: const ValueKey('repin_customer_banner_text'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E40AF)), maxLines: 2, overflow: TextOverflow.ellipsis)),
                    TextButton(
                      key: const ValueKey('btn_change_repin_phone'),
                      style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                      onPressed: () => setState(() {
                        _currentRepinTarget = null;
                        _phoneCtrl.clear();
                        _nameCtrl.clear();
                        _notesCtrl.clear();
                        _normalizedPhone = '';
                        _suggestions = List.from(widget.directoryCustomers);
                      }),
                      child: const Text('Đổi số', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                    ),
                  ],
                ),
              ),
            const Text('SỐ ĐIỆN THOẠI KHÁCH HÀNG *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
            const SizedBox(height: 6),
            TextField(
              key: const Key('input_assign_phone'),
              controller: _phoneCtrl,
              autofocus: _currentRepinTarget == null,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                hintText: 'Nhập SĐT (VD: 0908911111)',
                prefixIcon: const Icon(Icons.phone_rounded, color: Color(0xFF2563EB)),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF2563EB), width: 2)),
              ),
              onChanged: _updateFilter,
            ),
            if (_normalizedPhone.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('Số đã chuẩn hóa: $_normalizedPhone (${_normalizedPhone.length} số)', style: TextStyle(fontSize: 12, color: _normalizedPhone.length == 10 ? const Color(0xFF10B981) : const Color(0xFFF59E0B), fontWeight: FontWeight.w600)),
            ],
            if (_suggestions.isNotEmpty) ...[
              const SizedBox(height: 10),
              const Text('Gợi ý từ danh bạ:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
              const SizedBox(height: 4),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 120),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _suggestions.length > 3 ? 3 : _suggestions.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (itemCtx, idx) {
                    final c = _suggestions[idx];
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(radius: 14, backgroundColor: const Color(0xFFE0E7FF), child: Text(c.fullName.isNotEmpty ? c.fullName[0].toUpperCase() : 'K', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)))),
                      title: Text(c.fullName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      subtitle: Text(c.phoneNumber, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                      trailing: c.hasLocation ? const Text('Đã có vị trí', style: TextStyle(fontSize: 10, color: Color(0xFF10B981))) : null,
                      onTap: () {
                        _phoneCtrl.text = c.phoneNumber;
                        _nameCtrl.text = c.fullName;
                        _updateFilter(c.phoneNumber);
                      },
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: 14),
            const Text('TÊN KHÁCH HÀNG (TÙY CHỌN)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
            const SizedBox(height: 6),
            TextField(
              controller: _nameCtrl,
              decoration: InputDecoration(hintText: 'Mặc định: Khách [SĐT]', prefixIcon: const Icon(Icons.person_outline_rounded, color: Color(0xFF64748B)), filled: true, fillColor: const Color(0xFFF8FAFC), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0)))),
            ),
            const SizedBox(height: 14),
            const Text('GHI CHÚ VỊ TRÍ / CỔNG NHÀ (TÙY CHỌN)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
            const SizedBox(height: 6),
            TextField(
              controller: _notesCtrl,
              maxLines: 2,
              decoration: InputDecoration(hintText: 'VD: Cổng sắt xanh, hẻm cạnh tạp hóa', prefixIcon: const Icon(Icons.edit_note_rounded, color: Color(0xFF64748B)), filled: true, fillColor: const Color(0xFFF8FAFC), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0)))),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                key: const Key('btn_confirm_save_location'),
                style: AppButtons.primary(minHeight: 50, borderRadius: 12),
                onPressed: () async {
                  final rawPhone = _phoneCtrl.text.trim();
                  if (rawPhone.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng nhập số điện thoại khách hàng'))); return; }
                  final clean = normalizeCustomerPhone(rawPhone);
                  if (clean.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Số điện thoại không hợp lệ'))); return; }
                  if (clean.length != 10) {
                    final proceed = await showDialog<bool>(
                      context: context,
                      builder: (dlgCtx) => AlertDialog(
                        title: const Row(children: [Icon(Icons.warning_amber_rounded, color: Color(0xFFF59E0B)), SizedBox(width: 8), Text('Cảnh báo số điện thoại', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))]),
                        content: Text('Số này có ${clean.length} chữ số ($clean), bạn có chắc muốn tiếp tục?'),
                        actions: [TextButton(onPressed: () => Navigator.pop(dlgCtx, false), child: const Text('HỦY')), ElevatedButton(style: AppButtons.primary(), onPressed: () => Navigator.pop(dlgCtx, true), child: const Text('TIẾP TỤC'))],
                      ),
                    );
                    if (proceed != true) return;
                  }
                  if (!context.mounted) return;
                  Navigator.pop(context);
                  await widget.onConfirmSave(
                    phone: clean,
                    fullName: _nameCtrl.text.trim(),
                    notes: _notesCtrl.text.trim(),
                    targetCoord: widget.targetCoord,
                    knownCustomerId: _currentRepinTarget?.customerId,
                  );
                },
                child: const Text('LƯU VỊ TRÍ NÀY', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
