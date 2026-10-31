import 'package:flutter/material.dart';
import 'package:delivery_marker_mobile/models/shift_model.dart';
import 'package:delivery_marker_mobile/data/repository_provider.dart';
import 'package:delivery_marker_mobile/features/shifts/widgets/create_shift_dialog.dart';
import 'package:delivery_marker_mobile/features/shifts/widgets/shift_rename_dialog.dart';
import 'package:delivery_marker_mobile/features/shifts/widgets/shift_delete_dialog.dart';
import 'package:delivery_marker_mobile/shared_widgets/bulk_paste_phone_sheet.dart';
import 'package:delivery_marker_mobile/features/shifts/shift_preparation_view.dart';
import 'package:delivery_marker_mobile/features/shifts/shift_map_view.dart';
import 'package:delivery_marker_mobile/features/shifts/widgets/shift_card.dart';
import 'package:delivery_marker_mobile/features/shifts/widgets/shift_list_row.dart';
import 'package:delivery_marker_mobile/core/theme/app_buttons.dart';

class ShiftListView extends StatefulWidget {
  final Function(ShiftModel)? onSelectShiftForMap;
  final bool showAppBarLogout;

  const ShiftListView({super.key, this.onSelectShiftForMap, this.showAppBarLogout = false});

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
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      final list = await RepositoryProvider.shift.getShifts();
      list.sort((a, b) {
        if (a.createdAt != null && b.createdAt != null) return b.createdAt!.compareTo(a.createdAt!);
        return b.shiftDate.compareTo(a.shiftDate);
      });
      if (!mounted) return;
      setState(() { _shifts = list; _isLoading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _errorMessage = e.toString().replaceAll('Exception: ', ''); _isLoading = false; });
    }
  }

  Future<void> _openCreateShiftDialog() async {
    final newShift = await CreateShiftBottomSheet.show(context);
    if (newShift == null || !mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Đã tạo thành công ca làm: ${newShift.displayTitle}'),
      backgroundColor: const Color(0xFF10B981),
      behavior: SnackBarBehavior.floating,
    ));

    await _fetchShifts();
    if (!mounted) return;
    if (widget.onSelectShiftForMap != null) {
      widget.onSelectShiftForMap!(newShift);
    } else {
      Navigator.push(context, MaterialPageRoute(builder: (_) => ShiftPreparationView(shift: newShift))).then((_) => _fetchShifts());
    }
  }

  void _openShift(ShiftModel shift) {
    if (shift.status == ShiftStatus.preparing) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => ShiftPreparationView(shift: shift))).then((_) => _fetchShifts());
    } else {
      _openShiftMap(shift);
    }
  }

  void _openShiftMap(ShiftModel shift) {
    if (widget.onSelectShiftForMap != null) {
      widget.onSelectShiftForMap!(shift);
    } else {
      Navigator.push(context, MaterialPageRoute(builder: (_) => ShiftMapView(shiftId: shift.id))).then((_) => _fetchShifts());
    }
  }

  void _openBulkPasteSheet(ShiftModel shift) {
    BulkPastePhoneSheet.show(context: context, shiftId: shift.id, onPointsAdded: (_) => _fetchShifts());
  }

  Future<void> _handleRenameShift(ShiftModel shift) async {
    final newName = await ShiftRenameDialog.show(context, shift);
    if (newName != null && newName.isNotEmpty && newName != shift.shiftName) {
      try {
        await RepositoryProvider.shift.updateShiftName(shift.id, newName);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Đã đổi tên ca thành: $newName'), backgroundColor: const Color(0xFF10B981), behavior: SnackBarBehavior.floating));
          _fetchShifts();
        }
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi đổi tên: $e'), backgroundColor: const Color(0xFFEF4444)));
      }
    }
  }

  Future<void> _confirmDeleteShift(ShiftModel shift, {bool isStrongWarning = false}) async {
    final confirm = await ShiftDeleteDialog.show(context, shift);
    if (confirm == true) {
      try {
        await RepositoryProvider.shift.deleteShift(shift.id);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Đã xóa ca làm việc ${shift.displayTitle} thành công'), backgroundColor: const Color(0xFF10B981), behavior: SnackBarBehavior.floating));
        await _fetchShifts();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi xóa ca: ${e.toString().replaceAll('Exception: ', '')}'), backgroundColor: const Color(0xFFEF4444), behavior: SnackBarBehavior.floating));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final subtextColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    final inProgress = _shifts.where((s) => s.status == ShiftStatus.inProgress).toList();
    final activeShift = inProgress.isNotEmpty ? inProgress.first : null;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Ca làm việc',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  ElevatedButton.icon(
                    style: AppButtons.primary(minHeight: 48, borderRadius: 10),
                    icon: const Icon(Icons.add_rounded, size: 20),
                    label: const Text('Tạo ca mới', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                    onPressed: _openCreateShiftDialog,
                  ),
                ],
              ),
            ),
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
                                Text('Lỗi: $_errorMessage', style: TextStyle(fontSize: 14, color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155)), textAlign: TextAlign.center),
                                const SizedBox(height: 16),
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF2563EB), side: const BorderSide(color: Color(0xFF2563EB)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
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
                                      decoration: BoxDecoration(
                                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.assignment_outlined, size: 44, color: Color(0xFF94A3B8)),
                                    ),
                                    const SizedBox(height: 16),
                                    Text('Chưa có ca làm việc nào', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: colorScheme.onSurface)),
                                    const SizedBox(height: 6),
                                    Text('Bác tài bấm "Tạo ca mới" ở trên để bắt đầu sắp xếp danh sách giao.', style: TextStyle(fontSize: 13, color: subtextColor), textAlign: TextAlign.center),
                                    const SizedBox(height: 16),
                                    ElevatedButton.icon(style: AppButtons.primary(minHeight: 48, borderRadius: 10), icon: const Icon(Icons.add, size: 18), label: const Text('Tạo ca'), onPressed: _openCreateShiftDialog),
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
                                  if (activeShift != null) ...[
                                    Padding(
                                      padding: const EdgeInsets.only(left: 2, bottom: 8),
                                      child: Row(
                                        children: [
                                          Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle)),
                                          const SizedBox(width: 8),
                                          const Text(
                                            'ĐANG THỰC HIỆN',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: 1.2,
                                              color: Color(0xFF10B981),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    ShiftInProgressCard(
                                      shift: activeShift,
                                      onRename: () => _handleRenameShift(activeShift),
                                      onDelete: () => _confirmDeleteShift(activeShift, isStrongWarning: true),
                                      onBulkPaste: () => _openBulkPasteSheet(activeShift),
                                      onOpenMap: () => _openShiftMap(activeShift),
                                    ),
                                  ],
                                  Padding(
                                    padding: const EdgeInsets.only(left: 2, bottom: 8),
                                    child: Text(
                                      'DANH SÁCH CA (${_shifts.length})',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 1.2,
                                        color: subtextColor,
                                        fontFeatures: const [FontFeature.tabularFigures()],
                                      ),
                                    ),
                                  ),
                                  ListView.separated(
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    itemCount: _shifts.length,
                                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                                    itemBuilder: (ctx, idx) => ShiftListRow(shift: _shifts[idx], onTap: () => _openShift(_shifts[idx]), onDelete: () => _confirmDeleteShift(_shifts[idx])),
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
