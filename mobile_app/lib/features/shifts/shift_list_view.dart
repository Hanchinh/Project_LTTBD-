import 'package:flutter/material.dart';
import 'package:delivery_marker_mobile/models/shift_model.dart';
import 'package:delivery_marker_mobile/data/repositories/repository_provider.dart';
import 'package:delivery_marker_mobile/features/shifts/widgets/create_shift_dialog.dart';
import 'package:delivery_marker_mobile/shared_widgets/bulk_paste_phone_sheet.dart';
import 'package:delivery_marker_mobile/features/shifts/shift_preparation_view.dart';
import 'package:delivery_marker_mobile/features/shifts/shift_map_view.dart';
import 'package:delivery_marker_mobile/features/shifts/widgets/shift_card.dart';
import 'package:delivery_marker_mobile/features/shifts/widgets/shift_list_row.dart';
import 'package:delivery_marker_mobile/core/theme/app_buttons.dart';

class ShiftListView extends StatefulWidget {
  final Function(ShiftModel)? onSelectShiftForMap;
  final bool showAppBarLogout;

  const ShiftListView({
    super.key,
    this.onSelectShiftForMap,
    this.showAppBarLogout = false,
  });

  @override
  State<ShiftListView> createState() => _ShiftListViewState();
}

class _ShiftListViewState extends State<ShiftListView> {
  List<ShiftModel> _shifts = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchShifts();
  }

  Future<void> _fetchShifts() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final list = await RepositoryProvider.shift.getShifts();
      // Sắp xếp: mới nhất trước (theo createdAt giảm dần, fallback shiftDate)
      list.sort((a, b) {
        if (a.createdAt != null && b.createdAt != null) {
          return b.createdAt!.compareTo(a.createdAt!);
        }
        return b.shiftDate.compareTo(a.shiftDate);
      });

      if (!mounted) return;
      setState(() {
        _shifts = list;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  /// Mở hộp thoại tạo ca làm việc mới có sẵn ô đặt tên
  Future<void> _openCreateShiftDialog() async {
    final newShift = await CreateShiftBottomSheet.show(context);
    if (newShift == null || !mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Đã tạo thành công ca làm: ${newShift.displayTitle}'),
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
      ),
    );

    await _fetchShifts();

    if (!mounted) return;
    if (widget.onSelectShiftForMap != null) {
      widget.onSelectShiftForMap!(newShift);
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ShiftPreparationView(shift: newShift)),
      ).then((_) => _fetchShifts());
    }
  }

  /// Mở chi tiết ca: nếu ca chuẩn bị thì mở màn chuẩn bị, nếu ca khác thì mở bản đồ ca
  void _openShift(ShiftModel shift) {
    if (shift.status == ShiftStatus.preparing) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ShiftPreparationView(shift: shift)),
      ).then((_) => _fetchShifts());
    } else {
      _openShiftMap(shift);
    }
  }

  void _openShiftMap(ShiftModel shift) {
    if (widget.onSelectShiftForMap != null) {
      widget.onSelectShiftForMap!(shift);
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ShiftMapView(shiftId: shift.id)),
      ).then((_) => _fetchShifts());
    }
  }

  void _openBulkPasteSheet(ShiftModel shift) {
    BulkPastePhoneSheet.show(
      context: context,
      shiftId: shift.id,
      onPointsAdded: (result) {
        _fetchShifts();
      },
    );
  }

  /// Đổi tên ca làm việc
  Future<void> _handleRenameShift(ShiftModel shift) async {
    final controller = TextEditingController(text: shift.shiftName ?? '');
    final formKey = GlobalKey<FormState>();

    final newName = await showDialog<String>(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Đổi tên ca làm việc',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF0F172A)),
        ),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Tên ca làm',
              hintText: 'Ví dụ: Ca sáng 25/10',
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Vui lòng nhập tên ca';
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dlgCtx),
            child: const Text('HỦY', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F172A),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              if (formKey.currentState?.validate() == true) {
                Navigator.pop(dlgCtx, controller.text.trim());
              }
            },
            child: const Text('LƯU', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (newName != null && newName.isNotEmpty && newName != shift.shiftName) {
      try {
        await RepositoryProvider.shift.updateShiftName(shift.id, newName);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Đã đổi tên ca thành: $newName'),
              backgroundColor: const Color(0xFF10B981),
              behavior: SnackBarBehavior.floating,
            ),
          );
          _fetchShifts();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Lỗi đổi tên: $e'), backgroundColor: const Color(0xFFEF4444)),
          );
        }
      }
    }
  }

  /// Xác nhận xóa ca làm việc
  Future<void> _confirmDeleteShift(ShiftModel shift, {bool isStrongWarning = false}) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Xóa ca làm việc',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF0F172A)),
        ),
        content: Text(
          isStrongWarning
              ? 'Ca đang thực hiện, xóa vẫn sẽ hủy các điểm giao trong ca. Bác tài có chắc muốn xóa không?'
              : 'Xóa ca ${shift.displayTitle}? Các điểm giao trong ca sẽ bị hủy, vị trí khách đã lưu không bị mất.',
          style: const TextStyle(fontSize: 14, color: Color(0xFF334155), height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('HỦY', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('XÓA CA', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await RepositoryProvider.shift.deleteShift(shift.id);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã xóa ca làm việc ${shift.displayTitle} thành công'),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
        await _fetchShifts();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi xóa ca: ${e.toString().replaceAll('Exception: ', '')}'),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _handleLogout() async {}

  @override
  Widget build(BuildContext context) {
    // Tìm ca IN_PROGRESS mới nhất
    final inProgressShifts = _shifts.where((s) => s.status == ShiftStatus.inProgress).toList();
    final ShiftModel? activeInProgressShift = inProgressShifts.isNotEmpty ? inProgressShifts.first : null;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            // 1. Tiêu đề "Ca làm việc" và nút "Tạo ca mới" (nền Navy) góc phải
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Ca làm việc',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        style: AppButtons.primary(minHeight: 48, borderRadius: 10),
                        icon: const Icon(Icons.add_rounded, size: 20),
                        label: const Text(
                          'Tạo ca mới',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                        ),
                        onPressed: _openCreateShiftDialog,
                      ),
                      if (widget.showAppBarLogout) ...[
                        const SizedBox(width: 4),
                        IconButton(
                          icon: const Icon(Icons.logout_rounded, color: Color(0xFF64748B)),
                          tooltip: 'Đăng xuất',
                          onPressed: _handleLogout,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            // Thân danh sách
            Expanded(
              child: _isLoading && _shifts.isEmpty
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF2563EB)))
                  : _errorMessage != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.error_outline_rounded, size: 48, color: Color(0xFFEF4444)),
                                const SizedBox(height: 12),
                                Text(
                                  'Lỗi: $_errorMessage',
                                  style: const TextStyle(fontSize: 14, color: Color(0xFF334155)),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 16),
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFF2563EB),
                                    side: const BorderSide(color: Color(0xFF2563EB)),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  icon: const Icon(Icons.refresh_rounded, size: 18),
                                  onPressed: _fetchShifts,
                                  label: const Text('Thử lại'),
                                ),
                              ],
                            ),
                          ),
                        )
                      : _shifts.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: const BoxDecoration(
                                        color: Color(0xFFE2E8F0),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.assignment_outlined, size: 44, color: Color(0xFF94A3B8)),
                                    ),
                                    const SizedBox(height: 16),
                                    const Text(
                                      'Chưa có ca làm việc nào',
                                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                                    ),
                                    const SizedBox(height: 6),
                                    const Text(
                                      'Bác tài bấm "Tạo ca mới" ở trên để bắt đầu sắp xếp danh sách giao.',
                                      style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 16),
                                    ElevatedButton.icon(
                                      style: AppButtons.primary(minHeight: 48, borderRadius: 10),
                                      icon: const Icon(Icons.add, size: 18),
                                      label: const Text('Tạo ca'),
                                      onPressed: _openCreateShiftDialog,
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : RefreshIndicator(
                              color: const Color(0xFF2563EB),
                              onRefresh: _fetchShifts,
                              child: ListView(
                                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                                children: [
                                  // 2. Mục "ĐANG THỰC HIỆN" (nếu có ca IN_PROGRESS)
                                  if (activeInProgressShift != null) ...[
                                    Row(
                                      children: [
                                        Container(
                                          width: 8,
                                          height: 8,
                                          decoration: const BoxDecoration(
                                            color: Color(0xFF10B981),
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        const Text(
                                          'ĐANG THỰC HIỆN',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF10B981),
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    ShiftInProgressCard(
                                      shift: activeInProgressShift,
                                      onRename: () => _handleRenameShift(activeInProgressShift),
                                      onDelete: () => _confirmDeleteShift(activeInProgressShift, isStrongWarning: true),
                                      onBulkPaste: () => _openBulkPasteSheet(activeInProgressShift),
                                      onOpenMap: () => _openShiftMap(activeInProgressShift),
                                    ),
                                  ],

                                  // 3. Mục "DANH SÁCH CA (n)"
                                  Text(
                                    'DANH SÁCH CA (${_shifts.length})',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF64748B),
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 10),

                                  ListView.separated(
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    itemCount: _shifts.length,
                                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                                    itemBuilder: (ctx, idx) {
                                      final shift = _shifts[idx];
                                      return ShiftListRow(
                                        shift: shift,
                                        onTap: () => _openShift(shift),
                                        onDelete: () => _confirmDeleteShift(shift),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
            ),
          ],
        ),
      ),
    );
  }
}
