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
  const ShiftPreparationView({super.key, required this.shift});

  @override
  State<ShiftPreparationView> createState() => _ShiftPreparationViewState();
}

class _ShiftPreparationViewState extends State<ShiftPreparationView> {
  late ShiftModel _currentShift;
  bool _isLoading = false;
  bool _isAddingPoint = false;
  final _phoneController = TextEditingController();
  final _phoneFocusNode = FocusNode();
  String _selectedFilter = 'ALL';
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
      if (mounted) setState(() => _currentShift = updated);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi tải dữ liệu ca làm: $e'), backgroundColor: const Color(0xFFEF4444)));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applyPointUpdate(ShiftDeliveryPointModel point, ShiftSummaryModel? apiSummary) {
    _phoneController.clear();
    final updated = List<ShiftDeliveryPointModel>.from(_currentShift.deliveryPoints);
    final idx = updated.indexWhere((p) => p.id == point.id || p.customerId == point.customerId);
    if (idx >= 0) {
      updated[idx] = point;
    } else {
      updated.insert(0, point);
    }
    final vCount = updated.where((p) => p.locationStatus == LocationStatus.verified).length;
    final tCount = updated.where((p) => p.locationStatus == LocationStatus.temporary).length;
    final nCount = updated.where((p) => p.locationStatus == LocationStatus.noLocation).length;
    _currentShift = _currentShift.copyWith(
      deliveryPoints: updated,
      summary: apiSummary ?? ShiftSummaryModel(totalPoints: updated.length, verifiedCount: vCount, temporaryCount: tCount, noLocationCount: nCount),
      updatedAt: DateTime.now(),
    );
  }

  Future<void> _lookupAndAddCustomer() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng nhập số điện thoại khách hàng'), backgroundColor: Color(0xFFF59E0B)));
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _isAddingPoint = true);
    try {
      final lookup = await RepositoryProvider.customer.lookupCustomerLocationByPhone(phone);
      if (lookup == null || lookup['customer'] == null) {
        if (!mounted) return;
        _showQuickCreateCustomer(phone);
        return;
      }
      final custId = (lookup['customer'] as Map<String, dynamic>)['id']?.toString() ?? '';
      final res = await RepositoryProvider.shift.addPointToShift(_currentShift.id, customerId: custId, deliveryNotes: 'Thêm thủ công qua SĐT $phone');
      final isEx = res['isExisting'] == true;
      final point = res['point'] as ShiftDeliveryPointModel;
      if (!mounted) return;
      setState(() => _applyPointUpdate(point, res['summary'] as ShiftSummaryModel?));
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(isEx ? 'Khách hàng ${point.customerName} đã có trong ca làm này!' : 'Đã thêm khách hàng ${point.customerName} vào ca!'),
        backgroundColor: isEx ? const Color(0xFF2563EB) : const Color(0xFF10B981),
      ));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e'), backgroundColor: const Color(0xFFEF4444)));
    } finally {
      if (mounted) setState(() => _isAddingPoint = false);
    }
  }

  Future<void> _showQuickCreateCustomer(String phone) async {
    final customer = await showQuickAddCustomerBottomSheet(context, initialPhone: phone);
    if (customer == null || !mounted) return;
    setState(() => _isAddingPoint = true);
    try {
      final res = await RepositoryProvider.shift.addPointToShift(_currentShift.id, customerId: customer.id, deliveryNotes: 'Thêm khách hàng qua hồ sơ');
      final isEx = res['isExisting'] == true;
      final point = res['point'] as ShiftDeliveryPointModel;
      if (!mounted) return;
      setState(() { _applyPointUpdate(point, res['summary'] as ShiftSummaryModel?); _isAddingPoint = false; });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(isEx ? 'Khách hàng đã có trong ca làm này!' : 'Đã tạo hồ sơ và thêm vào ca!'),
        backgroundColor: isEx ? const Color(0xFF2563EB) : const Color(0xFF10B981),
      ));
    } catch (e) {
      if (mounted) {
        setState(() => _isAddingPoint = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi thêm khách vào ca: ${e.toString().replaceAll('Exception: ', '')}'), backgroundColor: const Color(0xFFEF4444)));
      }
    }
  }

  Future<void> _removePoint(ShiftDeliveryPointModel point) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Bỏ điểm giao này?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Color(0xFF0F172A))),
        content: Text('Bác tài có chắc muốn bỏ khách hàng "${point.customerName}" khỏi ca làm?', style: const TextStyle(fontSize: 14, color: Color(0xFF334155))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('HỦY', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444), foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
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
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Đã bỏ điểm giao của ${point.customerName}'), backgroundColor: const Color(0xFF334155)));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi xóa điểm giao: $e'), backgroundColor: const Color(0xFFEF4444)));
    }
  }

  Future<void> _updateShiftStatus(ShiftStatus newStatus) async {
    try {
      final updated = await RepositoryProvider.shift.updateShiftStatus(_currentShift.id, newStatus);
      if (mounted) {
        setState(() => _currentShift = updated);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Trạng thái ca làm: ${newStatus.displayName}'), backgroundColor: const Color(0xFF10B981)));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi cập nhật: $e'), backgroundColor: const Color(0xFFEF4444)));
    }
  }

  void _openCrosshairPicker(ShiftDeliveryPointModel point) async {
    final res = await Navigator.push<CrosshairLocationPickerResult>(context, MaterialPageRoute(builder: (_) => CrosshairLocationPickerView(point: point, shiftId: _currentShift.id)));
    if (res != null) _refreshShiftDetail();
  }

  void _openShiftMap() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => ShiftMapView(shiftId: _currentShift.id))).then((_) => _refreshShiftDetail());
  }

  Future<void> _openBulkPasteSheet() async {
    await BulkPastePhoneSheet.show(
      context: context,
      shiftId: _currentShift.id,
      onPointsAdded: (result) async {
        setState(() => _lastBulkResult = result);
        await _refreshShiftDetail();
      },
      onPinPointRequested: (point) => _openCrosshairPicker(point),
    );
  }

  List<ShiftDeliveryPointModel> get _filteredPoints => switch (_selectedFilter) {
    'VERIFIED' => _currentShift.deliveryPoints.where((p) => p.locationStatus == LocationStatus.verified).toList(),
    'TEMPORARY' => _currentShift.deliveryPoints.where((p) => p.locationStatus == LocationStatus.temporary).toList(),
    'NO_LOCATION' => _currentShift.deliveryPoints.where((p) => p.locationStatus == LocationStatus.noLocation).toList(),
    _ => _currentShift.deliveryPoints,
  };

  @override
  Widget build(BuildContext context) {
    final summary = _currentShift.summary;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8FAFC),
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A)), tooltip: 'Quay lại', onPressed: () => Navigator.pop(context)),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_currentShift.displayTitle, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
            Text('${_currentShift.shiftCode} · ${_currentShift.status.displayName}', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
          ],
        ),
        bottom: const PreferredSize(preferredSize: Size.fromHeight(1), child: Divider(height: 1, color: Color(0xFFE2E8F0))),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded, color: Color(0xFF475569)), tooltip: 'Tải lại', onPressed: _refreshShiftDetail),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          ShiftPrepPhoneInputHeader(
            phoneController: _phoneController,
            phoneFocusNode: _phoneFocusNode,
            isAddingPoint: _isAddingPoint,
            onOpenBulkPaste: _openBulkPasteSheet,
            onAddSinglePhone: _lookupAndAddCustomer,
            onClearPhone: () => setState(() => _phoneController.clear()),
          ),
          if (_lastBulkResult != null) ShiftBulkBanner(result: _lastBulkResult!, onDismiss: () => setState(() => _lastBulkResult = null)),
          const Divider(height: 1, thickness: 1, color: Color(0xFFE2E8F0)),
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
                              Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: const Color(0xFFE2E8F0).withValues(alpha: 0.5), shape: BoxShape.circle), child: const Icon(Icons.pin_drop_outlined, size: 40, color: Color(0xFF94A3B8))),
                              const SizedBox(height: 14),
                              const Text('Chưa có điểm giao trong mục này', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
                              const SizedBox(height: 4),
                              const Text('Nhập số điện thoại khách hàng ở trên để thêm điểm giao.', style: TextStyle(fontSize: 13, color: Color(0xFF64748B)), textAlign: TextAlign.center),
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
                          itemBuilder: (ctx, idx) => ShiftPointCard(point: _filteredPoints[idx], onPickerRequested: _openCrosshairPicker, onRemoveRequested: _removePoint),
                        ),
                      ),
          ),
          ShiftPrepBottomActionBar(status: _currentShift.status, onStatusChanged: _updateShiftStatus, onOpenMap: _openShiftMap),
        ],
      ),
    );
  }
}
