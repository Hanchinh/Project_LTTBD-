import 'package:flutter/material.dart';
import '../models/shift_model.dart';
import '../services/api_service.dart';
import 'shift_preparation_view.dart';
import 'shift_map_view.dart';
import 'login_view.dart';

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
  bool _isCreating = false;
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
      final list = await ApiService.getShifts();
      if (!mounted) return;
      setState(() {
        _shifts = list;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _createShift() async {
    setState(() => _isCreating = true);
    try {
      final newShift = await ApiService.createShift();
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã tạo thành công ca làm: ${newShift.shiftCode}'),
          backgroundColor: const Color(0xFF10B981),
        ),
      );

      // Nếu có callback chọn ca cho Bản đồ thì chuyển ngay sang Bản đồ
      if (widget.onSelectShiftForMap != null) {
        widget.onSelectShiftForMap!(newShift);
      } else {
        // Mở ngay màn hình chuẩn bị ca vừa tạo
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ShiftPreparationView(shift: newShift),
          ),
        ).then((_) => _fetchShifts());
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi tạo ca: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  void _openShift(ShiftModel shift) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ShiftPreparationView(shift: shift),
      ),
    ).then((_) => _fetchShifts());
  }

  Future<void> _confirmDeleteShift(ShiftModel shift) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Xóa ca làm việc',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF0F172A)),
        ),
        content: Text(
          'Xóa ca ${shift.shiftCode}? Các điểm giao trong ca sẽ bị hủy, vị trí khách đã lưu không bị mất.',
          style: const TextStyle(fontSize: 15, color: Color(0xFF334155), height: 1.4),
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
        await ApiService.deleteShift(shift.id);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã xóa ca làm việc ${shift.shiftCode} thành công'),
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
          style: TextStyle(fontSize: 15, color: Color(0xFF334155)),
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
            child: const Text('ĐĂNG XUẤT', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ApiService.logout();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginView()),
        (route) => false,
      );
    }
  }

  String _formatTodayDate() {
    final now = DateTime.now();
    return 'Hôm nay, ${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8FAFC),
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          'Ca làm việc',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 20,
            color: Color(0xFF0F172A),
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            color: const Color(0xFFE2E8F0),
            height: 1,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.map_outlined, color: Color(0xFF475569)),
            tooltip: 'Bản đồ ca làm',
            onPressed: () {
              if (_shifts.isNotEmpty) {
                final activeShift = _shifts.firstWhere(
                  (s) => s.status == ShiftStatus.inProgress,
                  orElse: () => _shifts.first,
                );
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ShiftMapView(shiftId: activeShift.id)),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Chưa có ca làm việc nào. Bác tài vui lòng bấm "+ Tạo ca mới" trước.'),
                    backgroundColor: Color(0xFFF59E0B),
                  ),
                );
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF475569)),
            tooltip: 'Tải lại',
            onPressed: _fetchShifts,
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Color(0xFF475569)),
            tooltip: 'Đăng xuất',
            onPressed: _handleLogout,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          // Header tóm tắt ngắn & Nút tạo ca mới
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Hàng thông tin tóm tắt ngắn gọn
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${_formatTodayDate()} · ${_shifts.length} ca làm việc',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    if (_isLoading)
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF2563EB)),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                // Nút Tạo ca mới gọn gàng, thanh lịch
                SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F172A),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: _isCreating
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Icon(Icons.add_rounded, size: 22),
                    label: Text(
                      _isCreating ? 'Đang tạo ca mới...' : 'Tạo ca làm mới',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                    onPressed: _isCreating ? null : _createShift,
                  ),
                ),
              ],
            ),
          ),

          // Danh sách ca làm việc
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
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE2E8F0).withValues(alpha: 0.5),
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
                                    'Bấm "+ Tạo ca làm mới" ở trên để chuẩn bị danh sách giao hàng.',
                                    style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          )
                        : RefreshIndicator(
                            color: const Color(0xFF2563EB),
                            onRefresh: _fetchShifts,
                            child: ListView.separated(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                              itemCount: _shifts.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 12),
                              itemBuilder: (ctx, idx) {
                                final shift = _shifts[idx];
                                return _buildShiftCard(shift);
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildShiftCard(ShiftModel shift) {
    // Màu badge trạng thái ca làm: pill badge nhạt, tinh tế
    Color statusBgColor;
    Color statusTextColor;

    switch (shift.status) {
      case ShiftStatus.inProgress:
        statusBgColor = const Color(0xFFDBEAFE); // Blue 100
        statusTextColor = const Color(0xFF1D4ED8); // Blue 700
        break;
      case ShiftStatus.completed:
        statusBgColor = const Color(0xFFDCFCE7); // Green 100
        statusTextColor = const Color(0xFF15803D); // Green 700
        break;
      case ShiftStatus.cancelled:
        statusBgColor = const Color(0xFFFEE2E2); // Red 100
        statusTextColor = const Color(0xFFB91C1C); // Red 700
        break;
      case ShiftStatus.preparing:
        statusBgColor = const Color(0xFFFEF3C7); // Amber 100
        statusTextColor = const Color(0xFFD97706); // Amber 700
        break;
    }

    final summary = shift.summary;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            if (widget.onSelectShiftForMap != null) {
              widget.onSelectShiftForMap!(shift);
            } else {
              _openShift(shift);
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Hàng 1: Mã ca & Badge trạng thái & Nút thùng rác xóa ca
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      shift.shiftCode,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.2,
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusBgColor,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            shift.status.displayName,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: statusTextColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 20),
                          tooltip: 'Xóa ca làm việc',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                          onPressed: () => _confirmDeleteShift(shift),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 6),

                // Hàng 2: Ngày làm việc & Tổng số điểm giao
                Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined, size: 14, color: Color(0xFF64748B)),
                    const SizedBox(width: 5),
                    Text(
                      'Ngày ${shift.shiftDate}',
                      style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                    ),
                    const Text('  ·  ', style: TextStyle(color: Color(0xFFCBD5E1))),
                    Text(
                      '${summary.totalPoints} điểm giao',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF334155),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Hàng 3: 3 Chip thống kê vị trí + Nút Thao tác
                Row(
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          _buildMiniStatusChip(
                            dotColor: const Color(0xFF10B981),
                            count: summary.verifiedCount,
                            label: 'Đã xác minh',
                          ),
                          _buildMiniStatusChip(
                            dotColor: const Color(0xFFF59E0B),
                            count: summary.temporaryCount,
                            label: 'Vị trí tạm',
                          ),
                          _buildMiniStatusChip(
                            dotColor: const Color(0xFF64748B),
                            count: summary.noLocationCount,
                            label: 'Chưa vị trí',
                          ),
                        ],
                      ),
                    ),
                    if (widget.onSelectShiftForMap != null) ...[
                      IconButton(
                        icon: const Icon(Icons.edit_note_rounded, color: Color(0xFF2563EB), size: 22),
                        tooltip: 'Chuẩn bị ca / Thêm SĐT',
                        onPressed: () => _openShift(shift),
                      ),
                    ],
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: Color(0xFF94A3B8),
                      size: 22,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMiniStatusChip({
    required Color dotColor,
    required int count,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            '$count $label',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: Color(0xFF475569),
            ),
          ),
        ],
      ),
    );
  }
}
