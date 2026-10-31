import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:delivery_marker_mobile/models/shift_model.dart';
import 'package:delivery_marker_mobile/models/customer_model.dart';
import 'package:delivery_marker_mobile/data/repository_provider.dart';
import 'package:delivery_marker_mobile/core/theme/app_buttons.dart';
import 'package:delivery_marker_mobile/shared_widgets/bulk_paste/bulk_paste_directory_result_view.dart';
import 'package:delivery_marker_mobile/shared_widgets/bulk_paste/bulk_paste_input_view.dart';
import 'package:delivery_marker_mobile/shared_widgets/bulk_paste/bulk_paste_shift_result_view.dart';
import 'package:delivery_marker_mobile/features/shifts/widgets/create_shift_dialog.dart';

/// BottomSheet dán danh sách số điện thoại hàng loạt vào ca hoặc danh bạ
class BulkPastePhoneSheet extends StatefulWidget {
  final String? shiftId;
  final bool isDirectoryMode;
  final Function(BulkAddPointsResult result)? onPointsAdded;
  final Function(BulkCreateCustomersResult result)? onCustomersAdded;
  final Function(ShiftDeliveryPointModel point)? onPinPointRequested;
  final BulkAddPointsResult? initialResult;
  final BulkCreateCustomersResult? initialDirectoryResult;

  const BulkPastePhoneSheet({
    super.key,
    this.shiftId,
    this.isDirectoryMode = false,
    this.onPointsAdded,
    this.onCustomersAdded,
    this.onPinPointRequested,
    this.initialResult,
    this.initialDirectoryResult,
  });

  static Future<void> show({
    required BuildContext context,
    String? shiftId,
    bool isDirectoryMode = false,
    Function(BulkAddPointsResult result)? onPointsAdded,
    Function(BulkCreateCustomersResult result)? onCustomersAdded,
    Function(ShiftDeliveryPointModel point)? onPinPointRequested,
    BulkAddPointsResult? initialResult,
    BulkCreateCustomersResult? initialDirectoryResult,
  }) =>
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => BulkPastePhoneSheet(
          shiftId: shiftId,
          isDirectoryMode: isDirectoryMode,
          onPointsAdded: onPointsAdded,
          onCustomersAdded: onCustomersAdded,
          onPinPointRequested: onPinPointRequested,
          initialResult: initialResult,
          initialDirectoryResult: initialDirectoryResult,
        ),
      );

  @override
  State<BulkPastePhoneSheet> createState() => _BulkPastePhoneSheetState();
}

class _BulkPastePhoneSheetState extends State<BulkPastePhoneSheet> {
  final TextEditingController _textCtrl = TextEditingController();
  List<String> _validPhones = [];
  List<String> _invalidPhones = [];
  bool _isSubmitting = false, _isAddingToShift = false, _needAreaSelection = false;
  String? _errorMessage, _selectedAreaId;
  List<Map<String, dynamic>> _availableAreas = [];
  BulkAddPointsResult? _result;
  BulkCreateCustomersResult? _directoryResult;

  @override
  void initState() {
    super.initState();
    _result = widget.initialResult;
    _directoryResult = widget.initialDirectoryResult;
    _loadAreas();
    _textCtrl.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _textCtrl.removeListener(_onTextChanged);
    _textCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAreas() async {
    try {
      final areas = await RepositoryProvider.profile.getMyAreas();
      if (!mounted) return;
      setState(() {
        _availableAreas = areas;
        if (areas.length == 1) _selectedAreaId = areas.first['id']?.toString();
      });
    } catch (_) {}
  }

  void _onTextChanged() {
    final seen = <String>{}, valid = <String>[], invalid = <String>[];
    for (final raw in _textCtrl.text.split(RegExp(r'[\r\n,;]+'))) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) continue;
      var clean = trimmed.replaceAll(RegExp(r'[\s\.\-\(\)]'), '');
      if (clean.startsWith('+84')) {
        clean = '0${clean.substring(3)}';
      } else if (clean.startsWith('84') && clean.length == 11) {
        clean = '0${clean.substring(2)}';
      } else if (clean.length == 9 && !clean.startsWith('0')) {
        clean = '0$clean';
      }
      if (RegExp(r'^0\d{9}$').hasMatch(clean)) {
        if (seen.add(clean)) valid.add(clean);
      } else if (!invalid.contains(trimmed)) {
        invalid.add(trimmed);
      }
    }
    setState(() {
      _validPhones = valid;
      _invalidPhones = invalid;
    });
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (text != null && text.isNotEmpty) {
      final cur = _textCtrl.text.trim();
      _textCtrl.text = cur.isEmpty ? data!.text! : '$cur\n${data!.text!}';
      _textCtrl.selection = TextSelection.fromPosition(TextPosition(offset: _textCtrl.text.length));
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bộ nhớ tạm không có văn bản')));
    }
  }

  Future<void> _submitBulk() async {
    if (_validPhones.isEmpty && _invalidPhones.isEmpty) {
      return setState(() => _errorMessage = 'Vui lòng nhập hoặc dán danh sách số điện thoại');
    }
    if (_validPhones.length > 200) {
      return setState(() => _errorMessage = 'Vượt quá giới hạn tối đa 200 số điện thoại (${_validPhones.length} số)');
    }
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });
    try {
      if (widget.isDirectoryMode) {
        final dirRes = await RepositoryProvider.customer.createBulkCustomers(rawText: _textCtrl.text, areaId: _selectedAreaId);
        if (!mounted) return;
        widget.onCustomersAdded?.call(dirRes);
        setState(() {
          _isSubmitting = false;
          _directoryResult = dirRes;
        });
      } else {
        final res = await RepositoryProvider.shift.addBulkPointsToShift(shiftId: widget.shiftId!, rawText: _textCtrl.text, areaId: _selectedAreaId);
        if (!mounted) return;
        widget.onPointsAdded?.call(res);
        setState(() {
          _isSubmitting = false;
          _result = res;
        });
      }
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().replaceFirst('Exception: ', '');
      setState(() {
        _isSubmitting = false;
        _errorMessage = msg;
        if (msg.contains('nhiều khu vực') || msg.contains('chọn khu vực')) {
          _needAreaSelection = true;
        }
      });
    }
  }

  Future<ShiftModel?> _resolveTargetShift(List<ShiftModel> candidates) async {
    if (candidates.length == 1) return candidates.first;
    if (candidates.isEmpty) {
      final shouldCreate = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Chưa có ca làm việc', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18, color: Color(0xFF0F172A))),
          content: const Text('Chưa có ca làm việc nào đang chuẩn bị hoặc thực hiện. Bác tài có muốn tạo ca mới không?', style: TextStyle(fontSize: 14, color: Color(0xFF334155), height: 1.4)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('HỦY', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold))),
            ElevatedButton(style: AppButtons.primary(), onPressed: () => Navigator.pop(ctx, true), child: const Text('TẠO CA MỚI', style: TextStyle(fontWeight: FontWeight.bold))),
          ],
        ),
      );
      return (shouldCreate == true && mounted) ? await CreateShiftBottomSheet.show(context) : null;
    }
    return showModalBottomSheet<ShiftModel>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Text('Chọn ca làm việc để thêm danh sách SĐT', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
              ),
              const Divider(height: 1, color: Color(0xFFE2E8F0)),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: candidates.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, indent: 16, endIndent: 16, color: Color(0xFFF1F5F9)),
                  itemBuilder: (_, idx) {
                    final s = candidates[idx];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                      title: Text(s.displayTitle, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Color(0xFF0F172A))),
                      subtitle: Text('${s.shiftDate} · ${s.status.displayName} · ${s.summary.totalPoints} điểm', style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Color(0xFF94A3B8)),
                      onTap: () => Navigator.pop(ctx, s),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _addAllToShift() async {
    if (_directoryResult == null) return;
    final allPhones = [..._directoryResult!.created.map((c) => c.phoneNumber), ..._directoryResult!.alreadyExists.map((c) => c.phoneNumber)];
    if (allPhones.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Không có số điện thoại hợp lệ để thêm vào ca')));
      return;
    }
    setState(() => _isAddingToShift = true);
    try {
      final shifts = await RepositoryProvider.shift.getShifts();
      final candidates = shifts.where((s) => s.status == ShiftStatus.preparing || s.status == ShiftStatus.inProgress).toList();
      if (!mounted) return;
      final target = await _resolveTargetShift(candidates);
      if (target == null) {
        if (mounted) setState(() => _isAddingToShift = false);
        return;
      }
      final res = await RepositoryProvider.shift.addBulkPointsToShift(shiftId: target.id, phones: allPhones);
      if (!mounted) return;
      setState(() => _isAddingToShift = false);
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Đã thêm ${res.added.length} điểm vào ${target.displayTitle} (${res.alreadyInShift.length} đã có trong ca)'),
        backgroundColor: const Color(0xFF0F172A),
        behavior: SnackBarBehavior.floating,
      ));
    } catch (e) {
      if (mounted) {
        setState(() => _isAddingToShift = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi thêm vào ca: $e'), backgroundColor: const Color(0xFFEF4444)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.of(context).size.height * 0.85;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 16, offset: Offset(0, -4))],
        ),
        child: SafeArea(
          top: false,
          child: _directoryResult != null
              ? BulkPasteDirectoryResultView(
                  result: _directoryResult!,
                  isAddingToShift: _isAddingToShift,
                  onAddAllToShift: _addAllToShift,
                  onClose: () => Navigator.of(context).pop(),
                )
              : (_result != null
                  ? BulkPasteShiftResultView(result: _result!, onPinPointRequested: widget.onPinPointRequested, onClose: () => Navigator.of(context).pop())
                  : BulkPasteInputView(
                      isDirectoryMode: widget.isDirectoryMode,
                      textController: _textCtrl,
                      validPhones: _validPhones,
                      invalidPhones: _invalidPhones,
                      isSubmitting: _isSubmitting,
                      errorMessage: _errorMessage,
                      availableAreas: _availableAreas,
                      selectedAreaId: _selectedAreaId,
                      needAreaSelection: _needAreaSelection,
                      onPasteFromClipboard: _pasteFromClipboard,
                      onAreaChanged: (val) => setState(() => _selectedAreaId = val),
                      onSubmit: _submitBulk,
                      onClose: () => Navigator.of(context).pop(),
                    )),
        ),
      ),
    );
  }
}
