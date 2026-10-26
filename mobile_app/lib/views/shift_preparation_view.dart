import 'package:flutter/material.dart';
import '../models/shift_model.dart';
import '../services/api_service.dart';
import 'crosshair_location_picker_view.dart';
import 'shift_map_view.dart';
import '../widgets/quick_add_customer_sheet.dart';
import '../widgets/bulk_paste_phone_sheet.dart';
import '../theme/app_buttons.dart';

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
      final updated = await ApiService.getShiftDetail(_currentShift.id);
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

    // Đóng bàn phím
    FocusScope.of(context).unfocus();
    setState(() => _isAddingPoint = true);

    try {
      // 1. Tra cứu khách hàng qua API
      final lookupResult = await ApiService.lookupCustomerLocationByPhone(phone);

      if (lookupResult == null || lookupResult['customer'] == null) {
        // Khách hàng chưa có hồ sơ trong hệ thống: Mở luồng tạo nhanh hồ sơ (Giai đoạn B)
        if (!mounted) return;
        _showQuickCreateCustomerBottomSheet(phone);
        return;
      }

      final customer = lookupResult['customer'] as Map<String, dynamic>;
      final customerId = customer['id']?.toString() ?? '';

      // 2. Thêm vào ca làm việc
      final addResult = await ApiService.addPointToShift(
        _currentShift.id,
        customerId: customerId,
        deliveryNotes: 'Thêm thủ công qua SĐT $phone',
      );

      final isExisting = addResult['isExisting'] == true;
      final point = addResult['point'] as ShiftDeliveryPointModel;
      final apiSummary = addResult['summary'] as ShiftSummaryModel?;

      if (!mounted) return;

      // Cập nhật danh sách cục bộ
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
      final addResult = await ApiService.addPointToShift(
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
      await ApiService.removePointFromShift(_currentShift.id, point.id);
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
      final updated = await ApiService.updateShiftStatus(_currentShift.id, newStatus);
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

  /// Banner hiển thị kết quả thêm hàng loạt SĐT vừa xong (2 nhóm vị trí + số bị từ chối)
  Widget _buildBulkResultBanner() {
    if (_lastBulkResult == null) return const SizedBox.shrink();

    final result = _lastBulkResult!;
    final verifiedAndTemp = result.added.where((p) => p.locationStatus != LocationStatus.noLocation).toList();
    final noLocation = result.added.where((p) => p.locationStatus == LocationStatus.noLocation).toList();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF86EFAC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 18),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Kết quả nhập hàng loạt vừa xong',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF166534)),
                ),
              ),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF166534)),
                onPressed: () => setState(() => _lastBulkResult = null),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '✓ Đã có vị trí: ${verifiedAndTemp.length}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF15803D)),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '! Chưa có vị trí: ${noLocation.length}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFB45309)),
                ),
              ),
              if (result.rejected.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '✕ Bị từ chối: ${result.rejected.length}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFB91C1C)),
                  ),
                ),
            ],
          ),
          if (result.rejected.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...result.rejected.take(3).map((r) => Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    '• ${r.phone}: ${r.message}',
                    style: const TextStyle(fontSize: 11, color: Color(0xFFDC2626)),
                  ),
                )),
            if (result.rejected.length > 3)
              Text(
                'và ${result.rejected.length - 3} số khác bị từ chối',
                style: const TextStyle(fontSize: 11, color: Color(0xFFDC2626), fontStyle: FontStyle.italic),
              ),
          ],
        ],
      ),
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
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // NÚT LỚN "NHẬP HÀNG LOẠT SĐT" (>= 56px) (TASK: PHOTO-SYNC-SHIFT-PICKER-BULK-016 Mục C)
                SizedBox(
                  height: 56,
                  child: ElevatedButton.icon(
                    key: const Key('btn_bulk_paste_phones'),
                    onPressed: _openBulkPasteSheet,
                    style: AppButtons.primaryLarge(minHeight: 56, borderRadius: 14),
                    icon: const Icon(Icons.paste_rounded, size: 22),
                    label: const Text(
                      'NHẬP HÀNG LOẠT SĐT',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: 0.5),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Phân cách hoặc nhãn nhập lẻ từng số
                Row(
                  children: [
                    const Expanded(child: Divider(color: Color(0xFFE2E8F0), thickness: 1)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text(
                        'HOẶC THÊM TỪNG SỐ',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade500),
                      ),
                    ),
                    const Expanded(child: Divider(color: Color(0xFFE2E8F0), thickness: 1)),
                  ],
                ),

                const SizedBox(height: 10),

                // Ô nhập một số để thêm nhanh từng số
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: TextField(
                          controller: _phoneController,
                          focusNode: _phoneFocusNode,
                          keyboardType: TextInputType.phone,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                          decoration: InputDecoration(
                            hintText: 'Nhập số điện thoại (VD: 0901234567)',
                            hintStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.normal, color: Color(0xFF94A3B8)),
                            prefixIcon: const Icon(Icons.phone_android_rounded, size: 20, color: Color(0xFF64748B)),
                            suffixIcon: _phoneController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 18, color: Color(0xFF94A3B8)),
                                    onPressed: () => setState(() => _phoneController.clear()),
                                  )
                                : null,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
                            ),
                          ),
                          onSubmitted: (_) => _lookupAndAddCustomer(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      height: 48,
                      child: ElevatedButton.icon(
                        key: const Key('btn_add_single_phone'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F172A),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                        ),
                        icon: _isAddingPoint
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Icon(Icons.person_add_rounded, size: 20),
                        label: Text(
                          _isAddingPoint ? '...' : 'Thêm',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                        onPressed: _isAddingPoint ? null : _lookupAndAddCustomer,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Banner kết quả nhập hàng loạt vừa xong (nếu có)
          if (_lastBulkResult != null)
            _buildBulkResultBanner(),

          const Divider(height: 1, thickness: 1, color: Color(0xFFE2E8F0)),

          // 2. Bộ lọc danh sách (Filter Chips hiện đại, nền nhạt, hiển thị số lượng trực tiếp)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: const Color(0xFFF8FAFC),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildCleanFilterChip(
                    key: 'ALL',
                    label: 'Tất cả (${summary.totalPoints})',
                  ),
                  const SizedBox(width: 8),
                  _buildCleanFilterChip(
                    key: 'VERIFIED',
                    label: 'Đã xác minh (${summary.verifiedCount})',
                    dotColor: const Color(0xFF10B981),
                  ),
                  const SizedBox(width: 8),
                  _buildCleanFilterChip(
                    key: 'TEMPORARY',
                    label: 'Vị trí tạm (${summary.temporaryCount})',
                    dotColor: const Color(0xFFF59E0B),
                  ),
                  const SizedBox(width: 8),
                  _buildCleanFilterChip(
                    key: 'NO_LOCATION',
                    label: 'Chưa có (${summary.noLocationCount})',
                    dotColor: const Color(0xFF64748B),
                  ),
                ],
              ),
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
                            return _buildPointCard(point);
                          },
                        ),
                      ),
          ),

          // 4. Thanh hành động đáy: Bắt đầu ca & Nút XEM BẢN ĐỒ CA LÀM NÀY
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  // Nút trạng thái ca
                  if (_currentShift.status == ShiftStatus.preparing)
                    Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: SizedBox(
                        height: 48,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF0F172A),
                            side: const BorderSide(color: Color(0xFFCBD5E1)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                          ),
                          onPressed: () => _updateShiftStatus(ShiftStatus.inProgress),
                          child: const Text(
                            'Bắt đầu ca',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    )
                  else if (_currentShift.status == ShiftStatus.inProgress)
                    Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: SizedBox(
                        height: 48,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF15803D),
                            side: const BorderSide(color: Color(0xFF86EFAC)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                          ),
                          onPressed: () => _updateShiftStatus(ShiftStatus.completed),
                          child: const Text(
                            'Hoàn thành',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ),

                  // Nút chính: XEM BẢN ĐỒ CA LÀM NÀY
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: ElevatedButton.icon(
                        style: AppButtons.primary(minHeight: 48, borderRadius: 12),
                        icon: const Icon(Icons.map_rounded, size: 20),
                        label: const Text(
                          'Xem bản đồ ca làm này',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                        ),
                        onPressed: _openShiftMap,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCleanFilterChip({
    required String key,
    required String label,
    Color? dotColor,
  }) {
    final isSelected = _selectedFilter == key;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => setState(() => _selectedFilter = key),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF0F172A) : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (dotColor != null) ...[
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.white : dotColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected ? Colors.white : const Color(0xFF475569),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPointCard(ShiftDeliveryPointModel point) {
    Color badgeBg;
    Color badgeText;
    IconData badgeIcon;
    String statusName = point.locationStatus.displayName;

    switch (point.locationStatus) {
      case LocationStatus.verified:
        badgeBg = const Color(0xFFDCFCE7); // green-100
        badgeText = const Color(0xFF15803D); // green-700
        badgeIcon = Icons.check_circle_rounded;
        break;
      case LocationStatus.temporary:
        badgeBg = const Color(0xFFFEF3C7); // amber-100
        badgeText = const Color(0xFFD97706); // amber-700
        badgeIcon = Icons.pin_drop_rounded;
        break;
      case LocationStatus.noLocation:
        badgeBg = const Color(0xFFF1F5F9); // slate-100
        badgeText = const Color(0xFF64748B); // slate-500
        badgeIcon = Icons.location_off_rounded;
        break;
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Dòng 1: Tên khách hàng & Badge trạng thái
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        point.customerName,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.phone_rounded, size: 13, color: Color(0xFF2563EB)),
                          const SizedBox(width: 4),
                          Text(
                            point.customerPhone,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF2563EB),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: badgeBg,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(badgeIcon, size: 13, color: badgeText),
                      const SizedBox(width: 4),
                      Text(
                        statusName,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: badgeText,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Địa chỉ khách hàng
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.location_on_outlined, size: 15, color: Color(0xFF94A3B8)),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    point.customerAddress,
                    style: const TextStyle(fontSize: 13, color: Color(0xFF475569), height: 1.3),
                  ),
                ),
              ],
            ),

            // Tọa độ nếu có
            if (point.hasValidCoordinates) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.gps_fixed_rounded, size: 13, color: Color(0xFF94A3B8)),
                  const SizedBox(width: 5),
                  Text(
                    '${point.latitude!.toStringAsFixed(6)}, ${point.longitude!.toStringAsFixed(6)}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontFamily: 'monospace',
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 12),
            const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
            const SizedBox(height: 10),

            // Dòng hành động: Ghim/cập nhật vị trí và nút Xóa khỏi ca
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 38,
                    child: point.locationStatus == LocationStatus.noLocation
                        ? ElevatedButton.icon(
                            style: AppButtons.primary(minHeight: 38, borderRadius: 8),
                            icon: const Icon(Icons.add_location_alt_rounded, size: 16),
                            label: const Text(
                              'Ghim vị trí',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                            onPressed: () => _openCrosshairPicker(point),
                          )
                        : OutlinedButton.icon(
                            style: AppButtons.secondary(minHeight: 38, borderRadius: 8),
                            icon: Icon(
                              point.locationStatus == LocationStatus.temporary
                                  ? Icons.edit_location_alt_rounded
                                  : Icons.location_on_rounded,
                              size: 16,
                              color: point.locationStatus == LocationStatus.temporary
                                  ? const Color(0xFFD97706)
                                  : const Color(0xFF15803D),
                            ),
                            label: Text(
                              point.locationStatus == LocationStatus.temporary
                                  ? 'Sửa vị trí tạm'
                                  : 'Xem vị trí',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                            onPressed: () => _openCrosshairPicker(point),
                          ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  height: 38,
                  width: 38,
                  child: IconButton(
                    style: IconButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      padding: EdgeInsets.zero,
                    ),
                    icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFF94A3B8)),
                    tooltip: 'Bỏ khỏi ca',
                    onPressed: () => _removePoint(point),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
