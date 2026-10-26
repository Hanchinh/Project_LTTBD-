import 'package:flutter/material.dart';
import '../models/shift_model.dart';
import '../repositories/repository_provider.dart';
import '../widgets/create_shift_dialog.dart';
import '../widgets/bulk_paste_phone_sheet.dart';
import 'shift_preparation_view.dart';
import 'shift_map_view.dart';
import 'login_view.dart';
import '../theme/app_buttons.dart';

class ShiftListView extends StatefulWidget {
  final Function(ShiftModel)? onSelectShiftForMap;
  final bool showAppBarLogout;

  const ShiftListView({
    super.key,
    this.onSelectShiftForMap,
    this.showAppBarLogout = true,
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

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Đăng xuất',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF0F172A)),
        ),
        content: const Text(
          'Bác tài có chắc muốn đăng xuất khỏi ứng dụng?',
          style: TextStyle(fontSize: 14, color: Color(0xFF334155)),
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('ĐĂNG XUẤT', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await RepositoryProvider.profile.logout();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginView()),
        (route) => false,
      );
    }
  }

  /// Thẻ nổi bật cho ca ĐANG THỰC HIỆN
  Widget _buildInProgressCard(ShiftModel shift) {
    final summary = shift.summary;
    final total = summary.totalPoints;
    final verified = summary.verifiedCount;
    final progress = total > 0 ? (verified / total).clamp(0.0, 1.0) : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFDBEAFE), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2563EB).withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hàng 1: Tiêu đề ca, ngày, số điểm & menu "..."
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        shift.displayTitle,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        shift.shiftCode,
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${ShiftModel.formatVnDate(DateTime.tryParse(shift.shiftDate) ?? shift.createdAt ?? DateTime.now())} · $total điểm',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                    ),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert_rounded, color: Color(0xFF64748B), size: 20),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      onSelected: (value) {
                        if (value == 'rename') {
                          _handleRenameShift(shift);
                        } else if (value == 'delete') {
                          _confirmDeleteShift(shift, isStrongWarning: true);
                        }
                      },
                      itemBuilder: (ctx) => [
                        const PopupMenuItem(
                          value: 'rename',
                          child: Row(
                            children: [
                              Icon(Icons.edit_note_rounded, size: 18, color: Color(0xFF334155)),
                              SizedBox(width: 8),
                              Text('Đổi tên ca', style: TextStyle(fontSize: 14)),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFEF4444)),
                              SizedBox(width: 8),
                              Text('Xóa ca', style: TextStyle(fontSize: 14, color: Color(0xFFEF4444))),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Hàng 2: Thanh tiến độ
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: const Color(0xFFE2E8F0),
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
              ),
            ),
            const SizedBox(height: 8),

            // Hàng 3: Dòng tóm tắt: "8 Đã xác minh · 3 Tạm · 1 Chưa có"
            Text(
              '${summary.verifiedCount} Đã xác minh · ${summary.temporaryCount} Tạm · ${summary.noLocationCount} Chưa có',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 14),

            // Hàng 4: 2 nút "Dán SĐT" và "Mở bản đồ" (chiều cao >= 48px)
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: OutlinedButton.icon(
                      style: AppButtons.secondary(minHeight: 48, borderRadius: 10),
                      icon: const Icon(Icons.paste_rounded, size: 18),
                      label: const Text('Dán SĐT', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                      onPressed: () => _openBulkPasteSheet(shift),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: ElevatedButton.icon(
                      style: AppButtons.primary(minHeight: 48, borderRadius: 10),
                      icon: const Icon(Icons.map_rounded, size: 18),
                      label: const Text('Mở bản đồ', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                      onPressed: () => _openShiftMap(shift),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Mỗi ca một dòng trong "DANH SÁCH CA (n)"
  Widget _buildShiftRow(ShiftModel shift) {
    // Chip trạng thái
    Color chipBg;
    Color chipText;
    switch (shift.status) {
      case ShiftStatus.preparing:
        chipBg = const Color(0xFFFEF3C7); // Vàng nhạt
        chipText = const Color(0xFFD97706);
        break;
      case ShiftStatus.inProgress:
        chipBg = const Color(0xFFDBEAFE); // Xanh dương nhạt
        chipText = const Color(0xFF1D4ED8);
        break;
      case ShiftStatus.completed:
        chipBg = const Color(0xFFDCFCE7); // Xanh lá nhạt
        chipText = const Color(0xFF15803D);
        break;
      case ShiftStatus.cancelled:
        chipBg = const Color(0xFFFEE2E2);
        chipText = const Color(0xFFB91C1C);
        break;
    }

    final summary = shift.summary;
    final dateStr = ShiftModel.formatVnDate(DateTime.tryParse(shift.shiftDate) ?? shift.createdAt ?? DateTime.now());
    final String subText = shift.status == ShiftStatus.completed
        ? '$dateStr · ${summary.totalPoints} điểm hoàn tất'
        : '$dateStr · ${summary.totalPoints} điểm (${summary.verifiedCount} xác minh, ${summary.temporaryCount} tạm)';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _openShift(shift),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              shift.displayTitle,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0F172A),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            shift.shiftCode,
                            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: chipBg,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              shift.status.displayName,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: chipText,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subText,
                        style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                // Icon thùng rác có vùng chạm >= 48px
                SizedBox(
                  width: 48,
                  height: 48,
                  child: IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 20),
                    tooltip: 'Xóa ca',
                    onPressed: () => _confirmDeleteShift(shift),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

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
                                    _buildInProgressCard(activeInProgressShift),
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
                                      return _buildShiftRow(shift);
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
