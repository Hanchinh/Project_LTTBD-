import 'package:flutter/material.dart';
import 'package:delivery_marker_mobile/models/shift_model.dart';
import 'package:delivery_marker_mobile/data/repositories/repository_provider.dart';
import 'package:delivery_marker_mobile/features/map/crosshair_location_picker_view.dart';
import 'package:delivery_marker_mobile/features/shifts/shift_map_view.dart';
import 'package:delivery_marker_mobile/features/shifts/widgets/shift_bulk_banner.dart';
import 'package:delivery_marker_mobile/features/shifts/widgets/shift_point_card.dart';
import 'package:delivery_marker_mobile/features/shifts/widgets/shift_prep_filter_bar.dart';
import 'package:delivery_marker_mobile/features/shifts/widgets/shift_prep_phone_input_header.dart';
import 'package:delivery_marker_mobile/features/shifts/widgets/shift_prep_bottom_action_bar.dart';
import 'package:delivery_marker_mobile/shared_widgets/quick_add_customer_sheet.dart';
import 'package:delivery_marker_mobile/shared_widgets/bulk_paste_phone_sheet.dart';

class ShiftPreparationView extends StatefulWidget {
  final ShiftModel shift;

  const ShiftPreparationView({
    super.key,
    required this.shift,
  });

  @override
  State<ShiftPreparationView> createState() => _ShiftPreparationViewState();
}

class _ShiftPreparationViewState extends State<ShiftPreparationView> {
  late ShiftModel _currentShift;
  bool _isLoading = false;
  bool _isAddingPoint = false;
  final TextEditingController _phoneController = TextEditingController();
  final FocusNode _phoneFocusNode = FocusNode();

  // Bộ lọc danh sách điểm giao: 'ALL', 'VERIFIED', 'TEMPORARY', 'NO_LOCATION'
  String _selectedFilter = 'ALL';

  // Kết quả sau khi nhập hàng loạt SĐT vừa xong (TASK: PHOTO-SYNC-SHIFT-PICKER-BULK-016 - Mục C)
  BulkAddPointsResult? _lastBulkResult;

  @override
  void initState() {
    super.initState();
    _currentShift = widget.shift;
    _refreshShiftDetail();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _phoneFocusNode.dispose();
    super.dispose();
  }

  Future<void> _refreshShiftDetail() async {
    setState(() => _isLoading = true);
    try {
      final updated = await RepositoryProvider.shift.getShiftDetail(_currentShift.id);
      if (mounted) {
        setState(() {
          _currentShift = updated;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi tải dữ liệu ca làm: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Tra cứu khách hàng theo SĐT và thêm vào ca làm việc
  Future<void> _lookupAndAddCustomer() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng nhập số điện thoại khách hàng'),
          backgroundColor: Color(0xFFF59E0B),
        ),
      );
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _isAddingPoint = true);

    try {
      final lookupResult = await RepositoryProvider.customer.lookupCustomerLocationByPhone(phone);

      if (lookupResult == null || lookupResult['customer'] == null) {
        if (!mounted) return;
        _showQuickCreateCustomerBottomSheet(phone);
        return;
      }

      final customer = lookupResult['customer'] as Map<String, dynamic>;
      final customerId = customer['id']?.toString() ?? '';

      final addResult = await RepositoryProvider.shift.addPointToShift(
        _currentShift.id,
        customerId: customerId,
        deliveryNotes: 'Thêm thủ công qua SĐT $phone',
      );

      final isExisting = addResult['isExisting'] == true;
      final point = addResult['point'] as ShiftDeliveryPointModel;
      final apiSummary = addResult['summary'] as ShiftSummaryModel?;

      if (!mounted) return;

      setState(() {
        _phoneController.clear();

        List<ShiftDeliveryPointModel> updatedPoints = List.from(_currentShift.deliveryPoints);
        final existingIndex = updatedPoints.indexWhere((p) => p.id == point.id || p.customerId == point.customerId);
        if (existingIndex >= 0) {
          updatedPoints[existingIndex] = point;
        } else {
          updatedPoints.insert(0, point);
        }

        final vCount = updatedPoints.where((p) => p.locationStatus == LocationStatus.verified).length;
        final tCount = updatedPoints.where((p) => p.locationStatus == LocationStatus.temporary).length;
        final nCount = updatedPoints.where((p) => p.locationStatus == LocationStatus.noLocation).length;
        final fallbackSummary = ShiftSummaryModel(
          totalPoints: updatedPoints.length,
          verifiedCount: vCount,
          temporaryCount: tCount,
          noLocationCount: nCount,
        );

        _currentShift = _currentShift.copyWith(
          deliveryPoints: updatedPoints,
          summary: apiSummary ?? fallbackSummary,
          updatedAt: DateTime.now(),
        );
      });

      if (isExisting) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Khách hàng ${point.customerName} đã có trong ca làm này!'),
            backgroundColor: const Color(0xFF2563EB),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã thêm khách hàng ${point.customerName} vào ca!'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi: $e'),
          backgroundColor: const Color(0xFFEF4444),
          duration: const Duration(seconds: 4),
        ),
      );
    } finally {
      if (mounted) setState(() => _isAddingPoint = false);
    }
  }

  Future<void> _showQuickCreateCustomerBottomSheet(String phone) async {
    final customer = await showQuickAddCustomerBottomSheet(
      context,
      initialPhone: phone,
    );
    if (customer == null) return;

    if (!mounted) return;
    setState(() => _isAddingPoint = true);

    try {
      final addResult = await RepositoryProvider.shift.addPointToShift(
        _currentShift.id,
        customerId: customer.id,
        deliveryNotes: 'Thêm khách hàng qua hồ sơ',
      );

      final isExisting = addResult['isExisting'] == true;
      final point = addResult['point'] as ShiftDeliveryPointModel;
      final apiSummary = addResult['summary'] as ShiftSummaryModel?;

      if (!mounted) return;

      setState(() {
        _phoneController.clear();
        List<ShiftDeliveryPointModel> updatedPoints = List.from(_currentShift.deliveryPoints);
        final existingIndex = updatedPoints.indexWhere((p) => p.id == point.id || p.customerId == point.customerId);
        if (existingIndex >= 0) {
          updatedPoints[existingIndex] = point;
        } else {
          updatedPoints.insert(0, point);
        }

        final vCount = updatedPoints.where((p) => p.locationStatus == LocationStatus.verified).length;
        final tCount = updatedPoints.where((p) => p.locationStatus == LocationStatus.temporary).length;
        final nCount = updatedPoints.where((p) => p.locationStatus == LocationStatus.noLocation).length;
        final fallbackSummary = ShiftSummaryModel(
          totalPoints: updatedPoints.length,
          verifiedCount: vCount,
          temporaryCount: tCount,
          noLocationCount: nCount,
        );

        _currentShift = _currentShift.copyWith(
          deliveryPoints: updatedPoints,
          summary: apiSummary ?? fallbackSummary,
          updatedAt: DateTime.now(),
        );
        _isAddingPoint = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isExisting
                ? 'Khách hàng  đã có trong ca làm này!'
                : 'Đã tạo hồ sơ và thêm  vào ca!',
          ),
          backgroundColor: isExisting ? const Color(0xFF2563EB) : const Color(0xFF10B981),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isAddingPoint = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi thêm khách vào ca: ${e.toString().replaceAll('Exception: ', '')}'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  Future<void> _removePoint(ShiftDeliveryPointModel point) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Bỏ điểm giao này?',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Color(0xFF0F172A)),
        ),
        content: Text(
          'Bác tài có chắc muốn bỏ khách hàng "${point.customerName}" khỏi ca làm?',
          style: const TextStyle(fontSize: 14, color: Color(0xFF334155)),
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
            child: const Text('BỎ ĐIỂM GIAO', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await RepositoryProvider.shift.removePointFromShift(_currentShift.id, point.id);
      _refreshShiftDetail();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã bỏ điểm giao của ${point.customerName}'),
            backgroundColor: const Color(0xFF334155),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi xóa điểm giao: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  Future<void> _updateShiftStatus(ShiftStatus newStatus) async {
    try {
      final updated = await RepositoryProvider.shift.updateShiftStatus(_currentShift.id, newStatus);
      if (mounted) {
        setState(() => _currentShift = updated);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Trạng thái ca làm: ${newStatus.displayName}'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi cập nhật: $e'), backgroundColor: const Color(0xFFEF4444)),
        );
      }
    }
  }

  void _openCrosshairPicker(ShiftDeliveryPointModel point) async {
    final result = await Navigator.push<CrosshairLocationPickerResult>(
      context,
      MaterialPageRoute(
        builder: (context) => CrosshairLocationPickerView(
          point: point,
          shiftId: _currentShift.id,
        ),
      ),
    );

    if (result != null) {
      _refreshShiftDetail();
    }
  }

  void _openShiftMap() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ShiftMapView(shiftId: _currentShift.id),
      ),
    ).then((_) => _refreshShiftDetail());
  }

  /// Mở bottom sheet nhập hàng loạt SĐT vào ca (TASK: PHOTO-SYNC-SHIFT-PICKER-BULK-016 - Mục C)
  Future<void> _openBulkPasteSheet() async {
    await BulkPastePhoneSheet.show(
      context: context,
      shiftId: _currentShift.id,
      onPointsAdded: (result) async {
        setState(() {
          _lastBulkResult = result;
        });
        await _refreshShiftDetail();
      },
      onPinPointRequested: (point) {
        _openCrosshairPicker(point);
      },
    );
  }

  List<ShiftDeliveryPointModel> get _filteredPoints {
    if (_selectedFilter == 'VERIFIED') {
      return _currentShift.deliveryPoints.where((p) => p.locationStatus == LocationStatus.verified).toList();
    }
    if (_selectedFilter == 'TEMPORARY') {
      return _currentShift.deliveryPoints.where((p) => p.locationStatus == LocationStatus.temporary).toList();
    }
    if (_selectedFilter == 'NO_LOCATION') {
      return _currentShift.deliveryPoints.where((p) => p.locationStatus == LocationStatus.noLocation).toList();
    }
    return _currentShift.deliveryPoints;
  }

  @override
  Widget build(BuildContext context) {
    final summary = _currentShift.summary;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8FAFC),
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _currentShift.displayTitle,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
              ),
            ),
            Text(
              '${_currentShift.shiftCode} · ${_currentShift.status.displayName}',
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
          ],
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
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF475569)),
            tooltip: 'Tải lại',
            onPressed: _refreshShiftDetail,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          // 1. Cụm nhập số điện thoại khách hàng (Nhập hàng loạt & Nhập nhanh từng số)
          ShiftPrepPhoneInputHeader(
            phoneController: _phoneController,
            phoneFocusNode: _phoneFocusNode,
            isAddingPoint: _isAddingPoint,
            onOpenBulkPaste: _openBulkPasteSheet,
            onAddSinglePhone: _lookupAndAddCustomer,
            onClearPhone: () => setState(() => _phoneController.clear()),
          ),

          // Banner kết quả nhập hàng loạt vừa xong (nếu có)
          if (_lastBulkResult != null)
            ShiftBulkBanner(
              result: _lastBulkResult!,
              onDismiss: () => setState(() => _lastBulkResult = null),
            ),

          const Divider(height: 1, thickness: 1, color: Color(0xFFE2E8F0)),

          // 2. Bộ lọc danh sách (Filter Chips hiện đại, nền nhạt, hiển thị số lượng trực tiếp)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            color: const Color(0xFFF8FAFC),
            child: ShiftPrepFilterBar(
              selectedFilter: _selectedFilter,
              totalCount: summary.totalPoints,
              verifiedCount: summary.verifiedCount,
              tempCount: summary.temporaryCount,
              noLocationCount: summary.noLocationCount,
              onFilterChanged: (key) => setState(() => _selectedFilter = key),
            ),
          ),

          // 3. Danh sách điểm giao
          Expanded(
            child: _isLoading && _currentShift.deliveryPoints.isEmpty
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF2563EB)))
                : _filteredPoints.isEmpty
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
                                child: const Icon(Icons.pin_drop_outlined, size: 40, color: Color(0xFF94A3B8)),
                              ),
                              const SizedBox(height: 14),
                              const Text(
                                'Chưa có điểm giao trong mục này',
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Nhập số điện thoại khách hàng ở trên để thêm điểm giao.',
                                style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        color: const Color(0xFF2563EB),
                        onRefresh: _refreshShiftDetail,
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                          itemCount: _filteredPoints.length,
                          separatorBuilder: (ctx, idx) => const SizedBox(height: 10),
                          itemBuilder: (ctx, idx) {
                            final point = _filteredPoints[idx];
                            return ShiftPointCard(
                              point: point,
                              onPickerRequested: _openCrosshairPicker,
                              onRemoveRequested: _removePoint,
                            );
                          },
                        ),
                      ),
          ),

          // 4. Thanh hành động đáy: Bắt đầu ca & Nút XEM BẢN ĐỒ CA LÀM NÀY
          ShiftPrepBottomActionBar(
            status: _currentShift.status,
            onStatusChanged: _updateShiftStatus,
            onOpenMap: _openShiftMap,
          ),
        ],
      ),
    );
  }
}
