import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/shift_model.dart';
import '../models/customer_model.dart';
import '../services/api_service.dart';
import '../theme/app_buttons.dart';
import 'create_shift_dialog.dart';

/// BottomSheet dán danh sách số điện thoại hàng loạt vào ca hoặc danh bạ (TASK: DIRECTORY-BULK-SHIFT-NAME-BLACK-BUTTONS-022A)
/// - Thiết kế chuẩn cho shipper thao tác một tay ở vùng ngón cái
/// - Nút "DÁN TỪ BỘ NHỚ TẠM" 1 chạm
/// - Xem trước số đã chuẩn hóa, cảnh báo số sai định dạng
/// - Hỗ trợ 2 chế độ:
///   1. Gắn ca: Thêm trực tiếp vào ca làm việc hiện tại
///   2. Danh bạ: Thêm vào danh bạ (không gắn ca), hiển thị kết quả 3 nhóm (Mới tạo, Đã tồn tại, Bị từ chối)
///      kèm nút "Thêm tất cả vào ca"
/// - Nút bấm hành động chuyển sang Navy/đen #0F172A chữ trắng, vùng chạm >= 48px (>= 56px ở thẻ điểm/thao tác chính)
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
  }) {
    return showModalBottomSheet(
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
  }

  @override
  State<BulkPastePhoneSheet> createState() => _BulkPastePhoneSheetState();
}

class _BulkPastePhoneSheetState extends State<BulkPastePhoneSheet> {
  final TextEditingController _textCtrl = TextEditingController();

  // Danh sách số hợp lệ và không hợp lệ từ live parsing
  List<String> _validPhones = [];
  List<String> _invalidPhones = [];

  // Trạng thái xử lý
  bool _isSubmitting = false;
  bool _isAddingToShift = false;
  String? _errorMessage;

  // Khu vực áp dụng cho số mới nếu shipper có nhiều khu vực
  List<Map<String, dynamic>> _availableAreas = [];
  String? _selectedAreaId;
  bool _needAreaSelection = false;

  // Kết quả sau khi nộp thành công
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
      final areas = await ApiService.getMyAreas();
      if (!mounted) return;
      setState(() {
        _availableAreas = areas;
        if (areas.length == 1) {
          _selectedAreaId = areas.first['id']?.toString();
        }
      });
    } catch (_) {}
  }

  void _onTextChanged() {
    final text = _textCtrl.text;
    final splitTokens = text.split(RegExp(r'[\r\n,;]+'));

    final seen = <String>{};
    final valid = <String>[];
    final invalid = <String>[];

    for (final raw in splitTokens) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) continue;

      // Giữ khoảng trắng và dấu chấm bên trong một số rồi chuẩn hóa
      var clean = trimmed.replaceAll(RegExp(r'[\s\.\-\(\)]'), '');
      if (clean.startsWith('+84')) {
        clean = '0${clean.substring(3)}';
      } else if (clean.startsWith('84') && clean.length == 11) {
        clean = '0${clean.substring(2)}';
      } else if (clean.length == 9 && !clean.startsWith('0')) {
        clean = '0$clean';
      }

      if (RegExp(r'^0\d{9}$').hasMatch(clean)) {
        if (!seen.contains(clean)) {
          seen.add(clean);
          valid.add(clean);
        }
      } else {
        if (!invalid.contains(trimmed)) {
          invalid.add(trimmed);
        }
      }
    }

    setState(() {
      _validPhones = valid;
      _invalidPhones = invalid;
    });
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null && data!.text!.trim().isNotEmpty) {
      final current = _textCtrl.text.trim();
      if (current.isEmpty) {
        _textCtrl.text = data.text!;
      } else {
        _textCtrl.text = '$current\n${data.text!}';
      }
      _textCtrl.selection = TextSelection.fromPosition(
        TextPosition(offset: _textCtrl.text.length),
      );
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bộ nhớ tạm không có văn bản')),
      );
    }
  }

  Future<void> _submitBulk() async {
    if (_validPhones.isEmpty && _invalidPhones.isEmpty) {
      setState(() {
        _errorMessage = 'Vui lòng nhập hoặc dán danh sách số điện thoại';
      });
      return;
    }

    if (_validPhones.length > 200) {
      setState(() {
        _errorMessage = 'Vượt quá giới hạn tối đa 200 số điện thoại (${_validPhones.length} số)';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      if (widget.isDirectoryMode) {
        // Thêm vào danh bạ khách hàng
        final dirResult = await ApiService.createBulkCustomers(
          rawText: _textCtrl.text,
          areaId: _selectedAreaId,
        );

        if (!mounted) return;
        widget.onCustomersAdded?.call(dirResult);

        setState(() {
          _isSubmitting = false;
          _directoryResult = dirResult;
        });
      } else {
        // Thêm vào ca làm việc
        final result = await ApiService.addBulkPointsToShift(
          shiftId: widget.shiftId!,
          rawText: _textCtrl.text,
          areaId: _selectedAreaId,
        );

        if (!mounted) return;
        widget.onPointsAdded?.call(result);

        setState(() {
          _isSubmitting = false;
          _result = result;
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

  /// Thêm tất cả khách hàng trong kết quả danh bạ vào ca làm việc
  Future<void> _addAllToShift() async {
    if (_directoryResult == null) return;
    final allPhones = [
      ..._directoryResult!.created.map((c) => c.phoneNumber),
      ..._directoryResult!.alreadyExists.map((c) => c.phoneNumber),
    ];

    if (allPhones.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không có số điện thoại hợp lệ để thêm vào ca')),
      );
      return;
    }

    setState(() => _isAddingToShift = true);

    try {
      final shifts = await ApiService.getShifts();
      final candidateShifts = shifts
          .where((s) => s.status == ShiftStatus.preparing || s.status == ShiftStatus.inProgress)
          .toList();

      if (!mounted) return;

      ShiftModel? targetShift;

      if (candidateShifts.isEmpty) {
        // Chưa có ca -> Hỏi tạo ca mới
        final shouldCreate = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text(
              'Chưa có ca làm việc',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18, color: Color(0xFF0F172A)),
            ),
            content: const Text(
              'Chưa có ca làm việc nào đang chuẩn bị hoặc thực hiện. Bác tài có muốn tạo ca mới không?',
              style: TextStyle(fontSize: 14, color: Color(0xFF334155), height: 1.4),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('HỦY', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
              ),
              ElevatedButton(
                style: AppButtons.primary(),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('TẠO CA MỚI', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );

        if (shouldCreate == true && mounted) {
          targetShift = await CreateShiftBottomSheet.show(context);
        }
      } else if (candidateShifts.length == 1) {
        targetShift = candidateShifts.first;
      } else {
        // Nhiều ca -> Hiện danh sách chọn ca
        targetShift = await showModalBottomSheet<ShiftModel>(
          context: context,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (ctx) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      child: Text(
                        'Chọn ca làm việc để thêm danh sách SĐT',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                      ),
                    ),
                    const Divider(height: 1, color: Color(0xFFE2E8F0)),
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: candidateShifts.length,
                        separatorBuilder: (_, __) => const Divider(height: 1, indent: 16, endIndent: 16, color: Color(0xFFF1F5F9)),
                        itemBuilder: (c, idx) {
                          final s = candidateShifts[idx];
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                            title: Text(
                              s.displayTitle,
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Color(0xFF0F172A)),
                            ),
                            subtitle: Text(
                              '${s.shiftDate} · ${s.status.displayName} · ${s.summary.totalPoints} điểm',
                              style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                            ),
                            trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Color(0xFF94A3B8)),
                            onTap: () => Navigator.pop(ctx, s),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      }

      if (targetShift == null) {
        if (mounted) setState(() => _isAddingToShift = false);
        return;
      }

      // Thêm toàn bộ SĐT vào ca đã chọn
      final bulkAddRes = await ApiService.addBulkPointsToShift(
        shiftId: targetShift.id,
        phones: allPhones,
      );

      if (!mounted) return;
      setState(() => _isAddingToShift = false);

      final addedCount = bulkAddRes.added.length;
      final alreadyCount = bulkAddRes.alreadyInShift.length;
      final shiftTitle = targetShift.displayTitle;

      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã thêm $addedCount điểm vào $shiftTitle ($alreadyCount đã có trong ca)'),
          backgroundColor: const Color(0xFF0F172A),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isAddingToShift = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi thêm vào ca: $e'), backgroundColor: const Color(0xFFEF4444)),
        );
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
          boxShadow: [
            BoxShadow(color: Colors.black26, blurRadius: 16, offset: Offset(0, -4)),
          ],
        ),
        child: SafeArea(
          top: false,
          child: _directoryResult != null
              ? _buildDirectoryResultView()
              : (_result != null ? _buildResultView() : _buildInputView()),
        ),
      ),
    );
  }

  Widget _buildInputView() {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final isDir = widget.isDirectoryMode;

    return Padding(
      padding: EdgeInsets.fromLTRB(18, 14, 18, 16 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Thanh gạt
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.playlist_add_rounded, color: Color(0xFF0F172A), size: 24),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isDir ? 'Dán danh sách SĐT vào danh bạ' : 'Dán danh sách SĐT vào ca',
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                    const Text(
                      'Tách tự động theo xuống dòng, phẩy, chấm phẩy (tối đa 200 số)',
                      style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Phần thân cuộn được chứa nút Dán, ô nhập không cố định chiều cao và các cảnh báo
          Flexible(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Nút "DÁN TỪ BỘ NHỚ TẠM" một chạm (>= 48px, Navy/đen viền)
                  SizedBox(
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: _pasteFromClipboard,
                      style: AppButtons.secondary(minHeight: 48, borderRadius: 12),
                      icon: const Icon(Icons.content_paste_rounded, size: 20),
                      label: const Text(
                        'DÁN TỪ BỘ NHỚ TẠM',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 0.3),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Ô nhập văn bản không cố định chiều cao, minLines: 4, maxLines: 8, contentPadding >= 12px
                  TextField(
                    controller: _textCtrl,
                    autofocus: true,
                    minLines: 4,
                    maxLines: 8,
                    keyboardType: TextInputType.multiline,
                    textAlignVertical: TextAlignVertical.top,
                    decoration: InputDecoration(
                      hintText: 'Nhập hoặc dán danh sách SĐT tại đây...\n\nVí dụ:\n0908 911 111\n+84 988 000 001\n0988.000.002, 0988000003; 0912345678',
                      hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFF0F172A), width: 2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Xem trước đếm số & cảnh báo
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: _validPhones.isNotEmpty ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.check_circle_rounded,
                              size: 15,
                              color: _validPhones.isNotEmpty ? const Color(0xFF16A34A) : const Color(0xFF94A3B8),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              'Hợp lệ: ${_validPhones.length}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: _validPhones.isNotEmpty ? const Color(0xFF15803D) : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_invalidPhones.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEE2E2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.warning_amber_rounded, size: 15, color: Color(0xFFDC2626)),
                              const SizedBox(width: 5),
                              Text(
                                'Sai định dạng: ${_invalidPhones.length}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFB91C1C),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),

                  // Chọn khu vực nếu shipper phụ trách nhiều khu vực
                  if (_needAreaSelection || _availableAreas.length > 1) ...[
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedAreaId,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'Khu vực áp dụng cho khách hàng mới',
                        labelStyle: const TextStyle(fontSize: 12),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      items: _availableAreas.map((a) {
                        final aId = a['id']?.toString() ?? '';
                        final aName = a['name']?.toString() ?? '';
                        return DropdownMenuItem<String>(
                          value: aId,
                          child: Text(aName, style: const TextStyle(fontSize: 13)),
                        );
                      }).toList(),
                      onChanged: (val) => setState(() => _selectedAreaId = val),
                    ),
                  ],

                  // Thông báo lỗi nếu có
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _errorMessage!,
                      style: const TextStyle(color: Color(0xFFDC2626), fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Nút hành động chính luôn thấy được phía trên bàn phím (chiều cao >= 56px)
          SizedBox(
            height: 56,
            child: ElevatedButton.icon(
              onPressed: _isSubmitting || (_validPhones.isEmpty && _invalidPhones.isEmpty)
                  ? null
                  : _submitBulk,
              style: AppButtons.primaryLarge(minHeight: 56, borderRadius: 16),
              icon: _isSubmitting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                    )
                  : Icon(isDir ? Icons.group_add_rounded : Icons.add_location_alt_rounded, size: 22),
              label: Text(
                _isSubmitting
                    ? 'ĐANG XỬ LÝ LÔ...'
                    : (isDir
                        ? 'THÊM ${_validPhones.length} SỐ VÀO DANH BẠ'
                        : 'THÊM ${_validPhones.length} ĐIỂM VÀO CA'),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.4),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Giao diện kết quả cho chế độ thêm vào Danh bạ (3 nhóm: Mới tạo, Đã tồn tại, Bị từ chối)
  Widget _buildDirectoryResultView() {
    final result = _directoryResult!;

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Thanh gạt
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Tiêu đề kết quả
          Row(
            children: [
              const Icon(Icons.task_alt_rounded, color: Color(0xFF16A34A), size: 26),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Kết quả thêm vào danh bạ',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                    Text(
                      'Tạo mới ${result.createdCount} · ${result.alreadyExistsCount} đã có · ${result.rejectedCount} bị từ chối',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Danh sách cuộn kết quả 3 nhóm
          Expanded(
            child: ListView(
              children: [
                // 1. NHÓM 1: MỚI TẠO (CREATED)
                if (result.created.isNotEmpty) ...[
                  _buildSectionHeader(
                    title: 'MỚI TẠO (${result.created.length})',
                    subtitle: 'Đã lưu vào danh bạ với tên "Khách [SĐT]"',
                    color: const Color(0xFF16A34A),
                    icon: Icons.person_add_alt_1_rounded,
                  ),
                  ...result.created.map((c) => _buildBulkCustomerRow(c, isCreated: true)),
                  const SizedBox(height: 16),
                ],

                // 2. NHÓM 2: ĐÃ TỒN TẠI (ALREADY EXISTS)
                if (result.alreadyExists.isNotEmpty) ...[
                  _buildSectionHeader(
                    title: 'ĐÃ TỒN TẠI (${result.alreadyExists.length})',
                    subtitle: 'Khách đã có trong hệ thống kèm trạng thái vị trí',
                    color: const Color(0xFF0F172A),
                    icon: Icons.people_alt_rounded,
                  ),
                  ...result.alreadyExists.map((c) => _buildBulkCustomerRow(c, isCreated: false)),
                  const SizedBox(height: 16),
                ],

                // 3. NHÓM 3: BỊ TỪ CHỐI (REJECTED)
                if (result.rejected.isNotEmpty) ...[
                  _buildSectionHeader(
                    title: 'BỊ TỪ CHỐI (${result.rejected.length})',
                    subtitle: 'Sai định dạng hoặc ngoài khu vực phụ trách',
                    color: const Color(0xFFDC2626),
                    icon: Icons.cancel_rounded,
                  ),
                  ...result.rejected.map((item) => Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFFECACA)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item.phone, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF991B1B))),
                                  Text(item.message, style: const TextStyle(fontSize: 11, color: Color(0xFFB91C1C))),
                                ],
                              ),
                            ),
                          ],
                        ),
                      )),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Nút 1: "THÊM TẤT CẢ VÀO CA" (>= 56px, Navy/đen)
          SizedBox(
            height: 56,
            child: ElevatedButton.icon(
              onPressed: _isAddingToShift ? null : _addAllToShift,
              style: AppButtons.primaryLarge(minHeight: 56, borderRadius: 16),
              icon: _isAddingToShift
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                    )
                  : const Icon(Icons.playlist_add_rounded, size: 22),
              label: Text(
                _isAddingToShift
                    ? 'ĐANG THÊM VÀO CA...'
                    : 'THÊM TẤT CẢ VÀO CA',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.4),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Nút 2: "ĐÓNG VÀ XEM DANH BẠ" (>= 48px, viền đen nền trắng)
          SizedBox(
            height: 48,
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: AppButtons.secondary(minHeight: 48, borderRadius: 12),
              child: const Text(
                'ĐÓNG VÀ XEM DANH BẠ',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBulkCustomerRow(BulkCustomerItem customer, {required bool isCreated}) {
    Color tagBg;
    Color tagText;
    String tagLabel;

    if (isCreated) {
      tagBg = const Color(0xFFDCFCE7);
      tagText = const Color(0xFF15803D);
      tagLabel = 'MỚI TẠO';
    } else {
      switch (customer.locationState) {
        case LocationStatus.verified:
          tagBg = const Color(0xFFDCFCE7);
          tagText = const Color(0xFF15803D);
          tagLabel = 'ĐÃ XÁC MINH';
          break;
        case LocationStatus.temporary:
          tagBg = const Color(0xFFFEF3C7);
          tagText = const Color(0xFFB45309);
          tagLabel = 'VỊ TRÍ TẠM';
          break;
        case LocationStatus.noLocation:
          tagBg = const Color(0xFFF1F5F9);
          tagText = const Color(0xFF64748B);
          tagLabel = 'CHƯA CÓ VỊ TRÍ';
          break;
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: isCreated ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isCreated ? Icons.person_add_rounded : Icons.person_rounded,
              color: isCreated ? const Color(0xFF16A34A) : const Color(0xFF0F172A),
              size: 16,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(customer.fullName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                Text(customer.phoneNumber, style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: tagBg,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              tagLabel,
              style: TextStyle(color: tagText, fontSize: 10, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  /// Giao diện kết quả cho ca làm việc (Shift Mode)
  Widget _buildResultView() {
    final result = _result!;
    final verifiedPoints = result.added.where((p) => p.locationStatus == LocationStatus.verified).toList();
    final noLocationPoints = result.added.where((p) => p.locationStatus == LocationStatus.noLocation).toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Thanh gạt
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Tiêu đề kết quả
          Row(
            children: [
              const Icon(Icons.task_alt_rounded, color: Color(0xFF16A34A), size: 26),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Kết quả thêm danh sách SĐT',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                    Text(
                      'Đã thêm ${result.added.length} điểm · ${result.alreadyInShift.length} đã có · ${result.rejected.length} từ chối',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Danh sách cuộn kết quả
          Expanded(
            child: ListView(
              children: [
                // 1. NHÓM 1: ĐÃ CÓ VỊ TRÍ (VERIFIED)
                if (verifiedPoints.isNotEmpty) ...[
                  _buildSectionHeader(
                    title: 'ĐÃ CÓ VỊ TRÍ (${verifiedPoints.length})',
                    subtitle: 'Hiện ngay marker trên bản đồ ca',
                    color: const Color(0xFF16A34A),
                    icon: Icons.check_circle_rounded,
                  ),
                  ...verifiedPoints.map((p) => _buildVerifiedRow(p)),
                  const SizedBox(height: 16),
                ],

                // 2. NHÓM 2: CHƯA CÓ VỊ TRÍ - CẦN XÁC NHẬN (NO_LOCATION)
                if (noLocationPoints.isNotEmpty) ...[
                  _buildSectionHeader(
                    title: 'CHƯA CÓ VỊ TRÍ - CẦN XÁC NHẬN (${noLocationPoints.length})',
                    subtitle: 'Dùng tâm ngắm để ghim vị trí tạm thời',
                    color: const Color(0xFFD97706),
                    icon: Icons.location_searching_rounded,
                  ),
                  ...noLocationPoints.map((p) => _buildNoLocationRow(p)),
                  const SizedBox(height: 16),
                ],

                // 3. NHÓM 3: ĐÃ CÓ TRONG CA
                if (result.alreadyInShift.isNotEmpty) ...[
                  _buildSectionHeader(
                    title: 'ĐÃ CÓ TRONG CA (${result.alreadyInShift.length})',
                    subtitle: 'Bỏ qua, không thêm trùng lặp',
                    color: const Color(0xFF64748B),
                    icon: Icons.info_outline_rounded,
                  ),
                  ...result.alreadyInShift.map((item) => ListTile(
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                        leading: const Icon(Icons.check_rounded, color: Color(0xFF64748B), size: 18),
                        title: Text('${item.customerName} · ${item.phone}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        subtitle: Text('Trạng thái: ${item.locationStatus}', style: const TextStyle(fontSize: 11)),
                      )),
                  const SizedBox(height: 16),
                ],

                // 4. NHÓM 4: BỊ TỪ CHỐI
                if (result.rejected.isNotEmpty) ...[
                  _buildSectionHeader(
                    title: 'BỊ TỪ CHỐI (${result.rejected.length})',
                    subtitle: 'Sai định dạng hoặc ngoài khu vực phụ trách',
                    color: const Color(0xFFDC2626),
                    icon: Icons.cancel_rounded,
                  ),
                  ...result.rejected.map((item) => Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFFECACA)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item.phone, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF991B1B))),
                                  Text(item.message, style: const TextStyle(fontSize: 11, color: Color(0xFFB91C1C))),
                                ],
                              ),
                            ),
                          ],
                        ),
                      )),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Nút ĐÓNG VÀ XEM BẢN ĐỒ CA >= 56px, Navy/đen #0F172A
          SizedBox(
            height: 56,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              style: AppButtons.primaryLarge(minHeight: 56, borderRadius: 16),
              icon: const Icon(Icons.map_rounded, size: 22),
              label: const Text(
                'XONG · XEM BẢN ĐỒ CA',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.4),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader({
    required String title,
    required String subtitle,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 13),
                ),
                Text(
                  subtitle,
                  style: TextStyle(color: color.withValues(alpha: 0.85), fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerifiedRow(ShiftDeliveryPointModel point) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: const BoxDecoration(color: Color(0xFFDCFCE7), shape: BoxShape.circle),
            child: const Icon(Icons.check_rounded, color: Color(0xFF16A34A), size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(point.customerName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                Text(point.customerPhone, style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFDCFCE7),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              'ĐÃ CÓ TỌA ĐỘ',
              style: TextStyle(color: Color(0xFF15803D), fontSize: 10, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoLocationRow(ShiftDeliveryPointModel point) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.location_off_rounded, color: Color(0xFFD97706), size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(point.customerName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF92400E))),
                    Text(point.customerPhone, style: const TextStyle(color: Color(0xFFB45309), fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Nút lớn "GHIM TÂM NGẮM" chiều cao >= 56px cho thao tác 1 tay, Navy/đen #0F172A
          SizedBox(
            height: 56,
            child: ElevatedButton.icon(
              onPressed: () {
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                }
                widget.onPinPointRequested?.call(point);
              },
              style: AppButtons.primaryLarge(minHeight: 56, borderRadius: 12),
              icon: const Icon(Icons.add_location_alt_rounded, size: 20),
              label: const Text(
                'GHIM TÂM NGẮM',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 0.3),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
