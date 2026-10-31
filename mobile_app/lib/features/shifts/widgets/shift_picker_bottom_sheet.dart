import 'package:flutter/material.dart';
import 'package:delivery_marker_mobile/models/shift_model.dart';
import 'package:delivery_marker_mobile/data/repository_provider.dart';
import 'package:delivery_marker_mobile/features/shifts/shift_map_view.dart';
import 'package:delivery_marker_mobile/features/shifts/widgets/create_shift_dialog.dart';
import 'package:delivery_marker_mobile/features/shifts/widgets/shift_dialogs.dart';
import 'package:delivery_marker_mobile/features/shifts/widgets/shift_picker_item_card.dart';
import 'package:delivery_marker_mobile/core/theme/app_buttons.dart';

/// Bottom sheet chọn ca làm việc từ bản đồ chính
class ShiftPickerBottomSheet extends StatefulWidget {
  final Function(ShiftModel)? onShiftSelected;
  const ShiftPickerBottomSheet({super.key, this.onShiftSelected});

  static Future<ShiftModel?> show({required BuildContext context, Function(ShiftModel)? onShiftSelected}) =>
      showModalBottomSheet<ShiftModel>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => ShiftPickerBottomSheet(onShiftSelected: onShiftSelected),
      );

  @override
  State<ShiftPickerBottomSheet> createState() => _ShiftPickerBottomSheetState();
}

class _ShiftPickerBottomSheetState extends State<ShiftPickerBottomSheet> {
  List<ShiftModel> _shifts = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadShifts();
  }

  Future<void> _loadShifts() async {
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
      setState(() { _errorMessage = e.toString().replaceFirst('Exception: ', ''); _isLoading = false; });
    }
  }

  Future<void> _handleCreateNewShift() async {
    final newShift = await CreateShiftBottomSheet.show(context);
    if (newShift != null && mounted) {
      widget.onShiftSelected?.call(newShift);
      Navigator.of(context).pop(newShift);
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => ShiftMapView(shiftId: newShift.id)));
    }
  }

  Future<void> _handleRenameShift(ShiftModel shift) async {
    final newName = await ShiftRenameDialog.show(context, shift);
    if (newName != null && newName.isNotEmpty && newName != shift.shiftName) {
      try {
        final updated = await RepositoryProvider.shift.updateShiftName(shift.id, newName);
        if (!mounted) return;
        setState(() {
          final idx = _shifts.indexWhere((s) => s.id == shift.id);
          if (idx != -1) _shifts[idx] = updated;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Đã đổi tên ca thành "${updated.displayTitle}"'), backgroundColor: const Color(0xFF16A34A)));
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi đổi tên: ${e.toString().replaceFirst('Exception: ', '')}'), backgroundColor: const Color(0xFFDC2626)));
      }
    }
  }

  Future<void> _handleDeleteShift(ShiftModel shift) async {
    final confirm = await ShiftDeleteDialog.show(context, shift);
    if (confirm == true) {
      try {
        await RepositoryProvider.shift.deleteShift(shift.id);
        if (!mounted) return;
        setState(() => _shifts.removeWhere((s) => s.id == shift.id));
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Đã xóa ca "${shift.displayTitle}" thành công'), backgroundColor: const Color(0xFF16A34A)));
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi xóa ca: ${e.toString().replaceFirst('Exception: ', '')}'), backgroundColor: const Color(0xFFDC2626)));
      }
    }
  }

  void _openShiftMap(ShiftModel shift) {
    widget.onShiftSelected?.call(shift);
    Navigator.of(context).pop(shift);
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => ShiftMapView(shiftId: shift.id)));
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    return Container(
      constraints: BoxConstraints(maxHeight: screenHeight * 0.82, minHeight: screenHeight * 0.45),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 16, offset: Offset(0, -4))],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 12, 12),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Column(
                children: [
                  Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 12), decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2)))),
                  Row(
                    children: [
                      const Icon(Icons.work_history_rounded, color: Color(0xFF2563EB), size: 24),
                      const SizedBox(width: 10),
                      const Expanded(child: Text('Ca làm việc của bạn', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)))),
                      IconButton(icon: const Icon(Icons.refresh_rounded, color: Color(0xFF64748B)), tooltip: 'Tải lại', onPressed: _loadShifts),
                      IconButton(icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)), tooltip: 'Đóng', onPressed: () => Navigator.of(context).pop()),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, color: Color(0xFFEF4444), size: 40),
              const SizedBox(height: 12),
              Text(_errorMessage!, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF991B1B), fontSize: 14)),
              const SizedBox(height: 16),
              ElevatedButton.icon(onPressed: _loadShifts, icon: const Icon(Icons.refresh_rounded, size: 18), label: const Text('Thử lại')),
            ],
          ),
        ),
      );
    }
    if (_shifts.isEmpty) return _buildEmptyState();

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: _shifts.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) return _buildCreateNewShiftCard();
        final shift = _shifts[index - 1];
        return ShiftPickerItemCard(
          shift: shift,
          onTap: () => _openShiftMap(shift),
          onRename: () => _handleRenameShift(shift),
          onDelete: () => _handleDeleteShift(shift),
        );
      },
    );
  }

  Widget _buildCreateNewShiftCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        elevation: 1,
        child: InkWell(
          key: const Key('btn_new_shift_in_picker'),
          onTap: _handleCreateNewShift,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF93C5FD), width: 1.5),
              color: const Color(0xFFF0FDF4),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(color: const Color(0xFF16A34A), borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('+ Tạo ca làm việc mới', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF166534))),
                      SizedBox(height: 2),
                      Text('Đặt tên ca và lên danh sách điểm giao', style: TextStyle(fontSize: 12, color: Color(0xFF4B5563))),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Color(0xFF16A34A)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(color: const Color(0xFFEFF6FF), shape: BoxShape.circle, border: Border.all(color: const Color(0xFFBFDBFE))),
              child: const Icon(Icons.work_outline_rounded, color: Color(0xFF2563EB), size: 36),
            ),
            const SizedBox(height: 16),
            const Text('Chưa có ca làm việc nào', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
            const SizedBox(height: 8),
            const Text('Hãy bắt đầu bằng cách tạo ca mới để lên lộ trình giao hàng và dán danh sách số điện thoại.', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: Color(0xFF64748B), height: 1.4)),
            const SizedBox(height: 24),
            SizedBox(
              height: 56,
              width: double.infinity,
              child: ElevatedButton.icon(
                key: const Key('btn_empty_create_shift'),
                onPressed: _handleCreateNewShift,
                style: AppButtons.primaryLarge(minHeight: 56, borderRadius: 16),
                icon: const Icon(Icons.add_rounded, size: 22),
                label: const Text('+ TẠO CA MỚI', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
