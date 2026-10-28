import 'package:flutter/material.dart';
import 'package:delivery_marker_mobile/models/customer_model.dart';
import 'package:delivery_marker_mobile/data/repositories/repository_provider.dart';
import 'package:delivery_marker_mobile/core/theme/app_buttons.dart';
import 'package:delivery_marker_mobile/core/utils/phone_utils.dart';
import 'package:delivery_marker_mobile/shared_widgets/quick_add/quick_add_optional_fields.dart';
import 'package:delivery_marker_mobile/shared_widgets/quick_add/quick_add_area_selector.dart';
export 'package:delivery_marker_mobile/core/utils/phone_utils.dart' show normalizeCustomerPhone;

/// Mở bottom sheet Thêm nhanh khách hàng (TASK: QUICK-ADD-CUSTOMER-013)
Future<CustomerDirectoryModel?> showQuickAddCustomerBottomSheet(
  BuildContext context, {
  String? initialPhone,
  String? prefilledAreaId,
}) {
  return showModalBottomSheet<CustomerDirectoryModel>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (bSheetCtx) {
      return QuickAddCustomerSheet(
        initialPhone: initialPhone,
        prefilledAreaId: prefilledAreaId,
      );
    },
  );
}

class QuickAddCustomerSheet extends StatefulWidget {
  final String? initialPhone;
  final String? prefilledAreaId;

  const QuickAddCustomerSheet({
    super.key,
    this.initialPhone,
    this.prefilledAreaId,
  });

  @override
  State<QuickAddCustomerSheet> createState() => _QuickAddCustomerSheetState();
}

class _QuickAddCustomerSheetState extends State<QuickAddCustomerSheet> {
  late final TextEditingController _phoneCtrl;
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _addressCtrl = TextEditingController();
  final TextEditingController _notesCtrl = TextEditingController();

  bool _isExpanded = false;
  bool _isSaving = false;
  String _normalizedPhone = '';

  List<Map<String, dynamic>> _myAreas = [];
  String? _selectedAreaId;
  String? _selectedAreaName;
  bool _loadingAreas = true;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialPhone ?? '';
    _phoneCtrl = TextEditingController(text: initial);
    _normalizedPhone = normalizeCustomerPhone(initial);

    _phoneCtrl.addListener(() {
      final normalized = normalizeCustomerPhone(_phoneCtrl.text);
      if (normalized != _normalizedPhone) {
        setState(() {
          _normalizedPhone = normalized;
        });
      }
    });

    _loadAreas();
  }

  Future<void> _loadAreas() async {
    try {
      final areas = await RepositoryProvider.profile.getMyAreas();
      final preferred = await RepositoryProvider.profile.getPreferredAreaId();

      bool preferredWasInvalid = false;
      if (preferred != null) {
        final isValidPreferred = areas.any((a) => a['id']?.toString() == preferred);
        if (!isValidPreferred) {
          // TASK: QUICK-ADD-013B: Khi đọc preferred_customer_area_id, so với getMyAreas(); nếu không còn hợp lệ thì xóa và hỏi chọn lại.
          await RepositoryProvider.profile.clearPreferredAreaId();
          preferredWasInvalid = true;
        }
      }

      String? targetId = widget.prefilledAreaId ?? (preferredWasInvalid ? null : preferred);
      String? targetName;

      if (targetId != null) {
        final found = areas.firstWhere(
          (a) => a['id']?.toString() == targetId,
          orElse: () => <String, dynamic>{},
        );
        if (found.isNotEmpty) {
          targetName = found['name']?.toString();
        } else {
          targetId = null;
        }
      }

      if (targetId == null && areas.length == 1) {
        targetId = areas.first['id']?.toString();
        targetName = areas.first['name']?.toString();
        if (targetId != null) {
          await RepositoryProvider.profile.setPreferredAreaId(targetId);
        }
      }

      if (mounted) {
        setState(() {
          _myAreas = areas;
          _selectedAreaId = targetId;
          _selectedAreaName = targetName;
          _loadingAreas = false;
        });

        // Nếu preferred_customer_area_id không còn hợp lệ và shipper có nhiều hơn 1 khu vực, hỏi chọn lại ngay
        if (preferredWasInvalid && areas.length > 1) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _selectedAreaId == null) {
              _promptSelectArea();
            }
          });
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loadingAreas = false);
      }
    }
  }

  Future<void> _promptSelectArea() async {
    if (_myAreas.isEmpty) return;

    final selected = await showAreaSelectionDialog(
      context: context,
      areas: _myAreas,
      selectedAreaId: _selectedAreaId,
    );

    if (selected != null && mounted) {
      final chosenId = selected['id']?.toString();
      setState(() {
        _selectedAreaId = chosenId;
        _selectedAreaName = selected['name']?.toString();
      });
      if (chosenId != null) {
        await RepositoryProvider.profile.setPreferredAreaId(chosenId);
      }
    }
  }

  Future<void> _handleCreate() async {
    final rawPhone = _phoneCtrl.text.trim();
    if (rawPhone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng nhập số điện thoại'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }

    final cleanPhone = normalizeCustomerPhone(rawPhone);
    if (cleanPhone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Số điện thoại không hợp lệ'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }

    // Cảnh báo nếu số không đủ 10 số để tránh rác do gõ nhầm
    if (cleanPhone.length != 10) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dlgCtx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Color(0xFFF59E0B)),
              SizedBox(width: 8),
              Text('Cảnh báo số điện thoại', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Text('Số này có ${cleanPhone.length} chữ số ($cleanPhone), bạn có chắc?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dlgCtx, false),
              child: const Text('HỦY', style: TextStyle(color: Color(0xFF64748B))),
            ),
            ElevatedButton(
              style: AppButtons.primary(),
              onPressed: () => Navigator.pop(dlgCtx, true),
              child: const Text('TIẾP TỤC'),
            ),
          ],
        ),
      );

      if (confirmed != true) return;
    }

    // Nếu có nhiều khu vực mà chưa chọn, hỏi chọn 1 lần
    if (_selectedAreaId == null && _myAreas.length > 1) {
      await _promptSelectArea();
      if (_selectedAreaId == null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vui lòng chọn khu vực phụ trách cho khách hàng mới'),
            backgroundColor: Color(0xFFF59E0B),
          ),
        );
        return;
      }
    }

    setState(() => _isSaving = true);

    try {
      // Mặc định tên "Khách [SĐT]" và địa chỉ "Chưa cập nhật địa chỉ"
      final rawName = _nameCtrl.text.trim();
      final rawAddress = _addressCtrl.text.trim();
      final rawNotes = _notesCtrl.text.trim();

      final created = await RepositoryProvider.customer.createCustomer(
        phoneNumber: cleanPhone,
        fullName: rawName.isNotEmpty ? rawName : 'Khách $cleanPhone',
        addressText: rawAddress.isNotEmpty ? rawAddress : 'Chưa cập nhật địa chỉ',
        identificationNotes: rawNotes.isNotEmpty ? rawNotes : null,
        areaId: _selectedAreaId,
      );

      if (!mounted) return;

      if (created.isExisting) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Số đã tồn tại. Mở hồ sơ ${created.fullName}!'),
            backgroundColor: const Color(0xFF2563EB),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã tạo khách hàng ${created.fullName}!'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }

      Navigator.pop(context, created);
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi: ${e.toString().replaceAll('Exception: ', '')}'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final maxHeight = MediaQuery.of(context).size.height * 0.85;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottomInset),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Handle bar
              Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Header
            Row(
              children: [
                const Icon(Icons.person_add_rounded, color: Color(0xFF2563EB), size: 24),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Thêm nhanh khách hàng',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(height: 20, color: Color(0xFFE2E8F0)),

            // Thông tin khu vực phụ trách
            if (_myAreas.isNotEmpty)
              QuickAddAreaRow(
                selectedAreaName: _selectedAreaName,
                loadingAreas: _loadingAreas,
                hasMultipleAreas: _myAreas.length > 1,
                onPromptSelect: _promptSelectArea,
              ),

            // SỐ ĐIỆN THOẠI (Bắt buộc duy nhất, tự động focus)
            const Text(
              'SỐ ĐIỆN THOẠI *',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _phoneCtrl,
              autofocus: true,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _handleCreate(),
              decoration: InputDecoration(
                hintText: 'Nhập số điện thoại (VD: 0901234567)',
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                prefixIcon: const Icon(Icons.phone_rounded, size: 20, color: Color(0xFF2563EB)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5)),
              ),
            ),

            // Hiển thị số đã chuẩn hóa
            if (_normalizedPhone.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  children: [
                    Icon(
                      _normalizedPhone.length == 10 ? Icons.check_circle_outline : Icons.info_outline,
                      size: 14,
                      color: _normalizedPhone.length == 10 ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Số đã chuẩn hóa: $_normalizedPhone (${_normalizedPhone.length} số)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: _normalizedPhone.length == 10 ? const Color(0xFF059669) : const Color(0xFFD97706),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 12),

            // Nút mở rộng "Thêm thông tin" (ẩn/hiện tên, địa chỉ, ghi chú)
            InkWell(
              onTap: () => setState(() => _isExpanded = !_isExpanded),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      _isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                      color: const Color(0xFF2563EB),
                      size: 20,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _isExpanded ? 'Ẩn thông tin tùy chọn' : 'Thêm thông tin (Tên, địa chỉ, ghi chú)',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF2563EB),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Khối thông tin tùy chọn khi mở rộng
            if (_isExpanded)
              QuickAddOptionalFields(
                nameCtrl: _nameCtrl,
                addressCtrl: _addressCtrl,
                notesCtrl: _notesCtrl,
                onSubmitted: _handleCreate,
              ),

            const SizedBox(height: 20),

            // Nút HỦY và TẠO
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: AppButtons.secondary(minHeight: 48, borderRadius: 10),
                    onPressed: () => Navigator.pop(context),
                    child: const Text('HỦY', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    style: AppButtons.primary(minHeight: 48, borderRadius: 10),
                    icon: _isSaving
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.check_rounded, size: 20),
                    label: Text(_isSaving ? 'ĐANG TẠO...' : 'TẠO', style: const TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: _isSaving ? null : _handleCreate,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
}
