import 'dart:async';
import 'package:flutter/material.dart';
import '../models/customer_model.dart';
import '../models/shift_model.dart';
import '../services/api_service.dart';
import '../widgets/fullscreen_image_viewer.dart';
import '../widgets/quick_add_customer_sheet.dart';
import '../widgets/authenticated_image.dart';
import '../widgets/customer_photos_strip_widget.dart';
import 'crosshair_location_picker_view.dart';

class CustomerDirectoryView extends StatefulWidget {
  final ShiftModel? activeShift;
  final Function(ShiftModel)? onShiftUpdated;
  final VoidCallback? onSwitchToMapTab;

  const CustomerDirectoryView({
    super.key,
    this.activeShift,
    this.onShiftUpdated,
    this.onSwitchToMapTab,
  });

  @override
  State<CustomerDirectoryView> createState() => _CustomerDirectoryViewState();
}

class _CustomerDirectoryViewState extends State<CustomerDirectoryView> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;

  List<CustomerDirectoryModel> _customers = [];
  bool _isLoading = false;
  String? _errorMessage;

  String _selectedFilter = 'ALL'; // ALL, VERIFIED, TEMPORARY, NO_LOCATION, HAS_PHOTO, NO_PHOTO
  String? _addingToShiftCustomerId;

  @override
  void initState() {
    super.initState();
    _fetchCustomers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchCustomers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      String? statusParam;
      bool? hasPhotoParam;

      if (_selectedFilter == 'VERIFIED' || _selectedFilter == 'TEMPORARY' || _selectedFilter == 'NO_LOCATION') {
        statusParam = _selectedFilter;
      } else if (_selectedFilter == 'HAS_PHOTO') {
        hasPhotoParam = true;
      } else if (_selectedFilter == 'NO_PHOTO') {
        hasPhotoParam = false;
      }

      final list = await ApiService.getCustomers(
        query: _searchController.text.trim(),
        status: statusParam,
        hasPhoto: hasPhotoParam,
      );

      if (mounted) {
        setState(() {
          _customers = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  void _onSearchChanged(String val) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _fetchCustomers();
    });
  }

  Future<void> _addCustomerToCurrentShift(CustomerDirectoryModel customer) async {
    if (widget.activeShift == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Chưa có ca làm việc nào đang chọn. Vui lòng chọn ca trên bản đồ trước.'),
          backgroundColor: Color(0xFFF59E0B),
        ),
      );
      return;
    }

    final shiftId = widget.activeShift!.id;
    setState(() => _addingToShiftCustomerId = customer.id);

    try {
      final res = await ApiService.addPointToShift(
        shiftId,
        customerId: customer.id,
      );

      final isExisting = res['isExisting'] == true;
      final point = res['point'] as ShiftDeliveryPointModel;
      final summary = res['summary'] as ShiftSummaryModel?;

      if (!mounted) return;

      // Cập nhật active shift nếu có callback
      if (widget.onShiftUpdated != null && widget.activeShift != null) {
        final currentPoints = List<ShiftDeliveryPointModel>.from(widget.activeShift!.deliveryPoints);
        final idx = currentPoints.indexWhere((p) => p.id == point.id || p.customerId == point.customerId);
        if (idx >= 0) {
          currentPoints[idx] = point;
        } else {
          currentPoints.insert(0, point);
        }
        widget.onShiftUpdated!(widget.activeShift!.copyWith(
          deliveryPoints: currentPoints,
          summary: summary ?? widget.activeShift!.summary,
        ));
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isExisting
                ? 'Khách ${customer.fullName} đã có trong ca ${widget.activeShift!.shiftCode}!'
                : 'Đã thêm ${customer.fullName} vào ca ${widget.activeShift!.shiftCode}!',
          ),
          backgroundColor: isExisting ? const Color(0xFF2563EB) : const Color(0xFF10B981),
          action: widget.onSwitchToMapTab != null
              ? SnackBarAction(
                  label: 'XEM BẢN ĐỒ',
                  textColor: Colors.white,
                  onPressed: widget.onSwitchToMapTab!,
                )
              : null,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e'), backgroundColor: const Color(0xFFEF4444)),
        );
      }
    } finally {
      if (mounted) setState(() => _addingToShiftCustomerId = null);
    }
  }

  Future<void> _openCreateCustomerSheet() async {
    final customer = await showQuickAddCustomerBottomSheet(context);
    if (customer == null) return;

    if (!mounted) return;
    await _fetchCustomers();

    // TASK: QUICK-ADD-CUSTOMER-013: Mở luôn hồ sơ khách hàng đó (dù mới tạo hay đã tồn tại)
    _openCustomerDetailEdit(customer);
  }

  void _openCustomerDetailEdit(CustomerDirectoryModel customer) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CustomerDetailEditView(
          customer: customer,
          onCustomerUpdated: (updated) async {
            _fetchCustomers();
            if (widget.activeShift != null) {
              try {
                final shift = await ApiService.getShiftDetail(widget.activeShift!.id);
                widget.onShiftUpdated?.call(shift);
              } catch (_) {}
            }
          },
        ),
      ),
    );
  }

  Widget _buildFilterChip({
    required String key,
    required String label,
    Color? dotColor,
  }) {
    final isSelected = _selectedFilter == key;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () {
        setState(() => _selectedFilter = key);
        _fetchCustomers();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0F172A) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (dotColor != null) ...[
              Container(width: 8, height: 8, decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle)),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? Colors.white : const Color(0xFF475569),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerCard(CustomerDirectoryModel customer) {
    Color badgeBg;
    Color badgeText;
    IconData badgeIcon;

    switch (customer.locationStatus) {
      case LocationStatus.verified:
        badgeBg = const Color(0xFFDCFCE7);
        badgeText = const Color(0xFF15803D);
        badgeIcon = Icons.check_circle_rounded;
        break;
      case LocationStatus.temporary:
        badgeBg = const Color(0xFFFEF3C7);
        badgeText = const Color(0xFFD97706);
        badgeIcon = Icons.pin_drop_rounded;
        break;
      case LocationStatus.noLocation:
        badgeBg = const Color(0xFFF1F5F9);
        badgeText = const Color(0xFF64748B);
        badgeIcon = Icons.location_off_rounded;
        break;
    }

    final isAddingThis = _addingToShiftCustomerId == customer.id;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 1)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _openCustomerDetailEdit(customer),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Hàng 1: Tên khách hàng & Status Badge
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Thumbnail ảnh hoặc icon
                    if (customer.hasPhoto)
                      GestureDetector(
                        onTap: () {
                          FullscreenImageViewer.show(
                            context,
                            photoUrl: customer.imageUrl!,
                            title: customer.fullName,
                          );
                        },
                        child: Container(
                          width: 48,
                          height: 48,
                          margin: const EdgeInsets.only(right: 12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            color: const Color(0xFFF1F5F9),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                AuthenticatedImage(
                                  photoUrl: customer.imageUrl!,
                                  fit: BoxFit.cover,
                                  errorWidget: const Icon(Icons.broken_image_rounded, size: 22, color: Color(0xFF94A3B8)),
                                ),
                                if (customer.photoCount > 1)
                                  Positioned(
                                    right: 2,
                                    bottom: 2,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: Colors.black87,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        '${customer.photoCount}',
                                        style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      )
                    else
                      Container(
                        width: 44,
                        height: 44,
                        margin: const EdgeInsets.only(right: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.person_rounded, color: Color(0xFF64748B), size: 22),
                      ),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            customer.fullName,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              const Icon(Icons.phone_rounded, size: 13, color: Color(0xFF2563EB)),
                              const SizedBox(width: 4),
                              Text(
                                customer.phoneNumber,
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF2563EB)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: badgeBg, borderRadius: BorderRadius.circular(6)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(badgeIcon, size: 12, color: badgeText),
                          const SizedBox(width: 4),
                          Text(
                            customer.locationStatus.displayName,
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: badgeText),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // Địa chỉ
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.location_on_outlined, size: 15, color: Color(0xFF94A3B8)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        customer.addressText,
                        style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),

                // Ghi chú nếu có
                if (customer.identificationNotes != null && customer.identificationNotes!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.note_alt_outlined, size: 13, color: Color(0xFF64748B)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            customer.identificationNotes!,
                            style: const TextStyle(fontSize: 12, color: Color(0xFF334155)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 12),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                const SizedBox(height: 10),

                // Nút hành động: Thêm vào ca đang chọn & Chi tiết
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF2563EB),
                          side: const BorderSide(color: Color(0xFFBFDBFE)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                        icon: isAddingThis
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF2563EB)))
                            : const Icon(Icons.playlist_add_rounded, size: 18),
                        label: Text(
                          isAddingThis ? 'Đang thêm...' : 'Thêm vào ca đang chọn',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                        onPressed: isAddingThis ? null : () => _addCustomerToCurrentShift(customer),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      style: IconButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: const BorderSide(color: Color(0xFFE2E8F0))),
                      ),
                      icon: const Icon(Icons.chevron_right_rounded, color: Color(0xFF64748B)),
                      tooltip: 'Xem & Sửa',
                      onPressed: () => _openCustomerDetailEdit(customer),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          'Danh bạ vị trí',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 19, color: Color(0xFF0F172A)),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_alt_1_rounded, color: Color(0xFF2563EB)),
            tooltip: 'Thêm khách hàng',
            onPressed: _openCreateCustomerSheet,
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF475569)),
            tooltip: 'Tải lại',
            onPressed: _fetchCustomers,
          ),
          const SizedBox(width: 4),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: const Color(0xFFE2E8F0), height: 1),
        ),
      ),
      body: Column(
        children: [
          // 1. Ô tìm kiếm
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            color: Colors.white,
            child: SizedBox(
              height: 46,
              child: TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  hintText: 'Tìm theo SĐT, tên, địa chỉ, ghi chú...',
                  hintStyle: const TextStyle(fontSize: 14, color: Color(0xFF94A3B8)),
                  prefixIcon: const Icon(Icons.search_rounded, size: 20, color: Color(0xFF64748B)),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18, color: Color(0xFF94A3B8)),
                          onPressed: () {
                            _searchController.clear();
                            _fetchCustomers();
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5)),
                ),
              ),
            ),
          ),

          // 2. Filter chips ngang
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: const Color(0xFFF8FAFC),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip(key: 'ALL', label: 'Tất cả (${_customers.length})'),
                  const SizedBox(width: 8),
                  _buildFilterChip(key: 'VERIFIED', label: 'Đã xác minh', dotColor: const Color(0xFF10B981)),
                  const SizedBox(width: 8),
                  _buildFilterChip(key: 'TEMPORARY', label: 'Vị trí tạm', dotColor: const Color(0xFFF59E0B)),
                  const SizedBox(width: 8),
                  _buildFilterChip(key: 'NO_LOCATION', label: 'Chưa có vị trí', dotColor: const Color(0xFF64748B)),
                  const SizedBox(width: 8),
                  _buildFilterChip(key: 'HAS_PHOTO', label: 'Có ảnh 📷'),
                  const SizedBox(width: 8),
                  _buildFilterChip(key: 'NO_PHOTO', label: 'Chưa có ảnh'),
                ],
              ),
            ),
          ),

          const Divider(height: 1, color: Color(0xFFE2E8F0)),

          // 3. Danh sách khách hàng
          Expanded(
            child: _isLoading && _customers.isEmpty
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF2563EB)))
                : _customers.isEmpty
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
                                child: const Icon(Icons.people_outline_rounded, size: 40, color: Color(0xFF94A3B8)),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _errorMessage != null ? 'Lỗi tải danh bạ' : 'Không tìm thấy khách hàng nào',
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _errorMessage ?? 'Bác tài có thể bấm nút "+ Thêm khách hàng" ở trên để tạo hồ sơ mới.',
                                style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        color: const Color(0xFF2563EB),
                        onRefresh: _fetchCustomers,
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                          itemCount: _customers.length,
                          separatorBuilder: (ctx, idx) => const SizedBox(height: 10),
                          itemBuilder: (ctx, idx) {
                            final customer = _customers[idx];
                            return _buildCustomerCard(customer);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

/// Màn hình Chi Tiết & Toàn Quyền Chỉnh Sửa Khách Hàng (Tên, SĐT, Vị trí, Ghi chú, Ảnh)
class CustomerDetailEditView extends StatefulWidget {
  final CustomerDirectoryModel customer;
  final Function(CustomerDirectoryModel)? onCustomerUpdated;

  const CustomerDetailEditView({
    super.key,
    required this.customer,
    this.onCustomerUpdated,
  });

  @override
  State<CustomerDetailEditView> createState() => _CustomerDetailEditViewState();
}

class _CustomerDetailEditViewState extends State<CustomerDetailEditView> {
  late CustomerDirectoryModel _customer;
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _notesController = TextEditingController();

  double? _currentLat;
  double? _currentLng;
  String? _currentPhotoUrl;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _customer = widget.customer;
    _nameController.text = _customer.fullName;
    _phoneController.text = _customer.phoneNumber;
    _addressController.text = _customer.addressText;
    _notesController.text = _customer.identificationNotes ?? '';
    _currentLat = _customer.latitude;
    _currentLng = _customer.longitude;
    _currentPhotoUrl = _customer.imageUrl;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _confirmAndDeleteLocation() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận xóa vị trí đã lưu?'),
        content: Text(
          'Vị trí cổng nhà đã lưu của khách hàng "${_nameController.text.trim()}" sẽ bị xóa khỏi hồ sơ hệ thống.\n\n'
          'Các điểm giao trong ca đang chạy của khách này sẽ quay về trạng thái "Chưa có vị trí".\n\n'
          'Lịch sử đối soát trước đây vẫn được lưu trữ an toàn trong hệ thống.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xóa vị trí'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isSaving = true);
    try {
      await ApiService.deleteCustomerLocation(_customer.id);

      setState(() {
        _currentLat = null;
        _currentLng = null;
        _currentPhotoUrl = null;
      });

      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã xóa vị trí đã lưu thành công (lịch sử đối soát được bảo toàn)'),
          backgroundColor: Color(0xFF10B981),
        ),
      );

      final updated = await ApiService.getCustomerDetail(_customer.id);
      widget.onCustomerUpdated?.call(updated);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: $e'), backgroundColor: const Color(0xFFEF4444)),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _openCrosshairPicker() async {
    // Tạo dummy ShiftDeliveryPointModel để tận dụng bộ chọn tâm ngắm hoàn chỉnh
    final dummyPoint = ShiftDeliveryPointModel(
      id: 'dir-${_customer.id}',
      shiftId: '',
      customerId: _customer.id,
      customerName: _nameController.text.trim(),
      customerPhone: _phoneController.text.trim(),
      customerAddress: _addressController.text.trim(),
      locationStatus: _customer.locationStatus,
      latitude: _currentLat,
      longitude: _currentLng,
      locationNotes: _notesController.text.trim(),
    );

    final result = await Navigator.push<CrosshairLocationPickerResult>(
      context,
      MaterialPageRoute(
        builder: (context) => CrosshairLocationPickerView(
          point: dummyPoint,
          shiftId: '',
        ),
      ),
    );

    if (result != null) {
      setState(() {
        _currentLat = result.latitude;
        _currentLng = result.longitude;
      });
    }
  }

  Future<void> _handleSave() async {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final address = _addressController.text.trim();
    final notes = _notesController.text.trim();

    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Số điện thoại không được để trống'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      // 1. Cập nhật thông tin khách hàng
      await ApiService.updateCustomer(
        customerId: _customer.id,
        fullName: name,
        phoneNumber: phone,
        addressText: address,
      );

      // 2. Nếu có cập nhật vị trí hoặc ảnh
      if (_currentLat != null && _currentLng != null) {
        await ApiService.updateCustomerLocationAndPhoto(
          customerId: _customer.id,
          latitude: _currentLat!,
          longitude: _currentLng!,
          identificationNotes: notes.isNotEmpty ? notes : 'Vị trí đã lưu',
        );

        PaintingBinding.instance.imageCache.clear();
        PaintingBinding.instance.imageCache.clearLiveImages();
      }

      // 3. Tải lại chi tiết mới nhất
      final updated = await ApiService.getCustomerDetail(_customer.id);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã cập nhật hồ sơ khách hàng thành công!'), backgroundColor: Color(0xFF10B981)),
      );

      widget.onCustomerUpdated?.call(updated);
      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi lưu: $e'), backgroundColor: const Color(0xFFEF4444)),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Hồ sơ & Vị trí khách hàng',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18, color: Color(0xFF0F172A)),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: const Color(0xFFE2E8F0), height: 1),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Ảnh khách hàng (Multi-photo strip)
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.photo_camera_rounded, size: 20, color: Color(0xFF2563EB)),
                      const SizedBox(width: 8),
                      const Text(
                        'Ảnh mặt tiền / cổng nhà',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                      ),
                      const Spacer(),
                      Text(
                        'Tối đa 10 ảnh',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  CustomerPhotosStripWidget(
                    customerId: _customer.id,
                    customerName: _customer.fullName,
                    initialPhotos: _customer.photos,
                    legacyImageUrl: _customer.imageUrl,
                    height: 145,
                    canAddPhoto: true,
                    canDeletePhoto: true,
                    onPhotosUpdated: (photos) {
                      setState(() {
                        _currentPhotoUrl = photos.isNotEmpty ? photos.first.imageUrl : null;
                        _customer = _customer.copyWith(
                          photos: photos,
                          photoCount: photos.length,
                          imageUrl: _currentPhotoUrl,
                        );
                      });
                      widget.onCustomerUpdated?.call(_customer);
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // 2. Thông tin khách hàng
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('THÔNG TIN LIÊN HỆ', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                  const SizedBox(height: 12),
                  const Text('TÊN KHÁCH HÀNG', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text('SỐ ĐIỆN THOẠI *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text('ĐỊA CHỈ KHÁCH HÀNG', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _addressController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // 3. Tọa độ & Ghi chú nhận diện vị trí
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('TỌA ĐỘ & GHI CHÚ VỊ TRÍ', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                      const Spacer(),
                      if (_currentLat != null && _currentLng != null) ...[
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFFEF4444),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          ),
                          icon: const Icon(Icons.delete_outline_rounded, size: 16),
                          label: const Text('Xóa vị trí', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          onPressed: _isSaving ? null : _confirmAndDeleteLocation,
                        ),
                        const SizedBox(width: 4),
                      ],
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.add_location_alt_rounded, size: 16),
                        label: const Text('Chọn trên bản đồ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        onPressed: _openCrosshairPicker,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_currentLat != null && _currentLng != null) ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.gps_fixed_rounded, size: 16, color: Color(0xFF2563EB)),
                          const SizedBox(width: 8),
                          Text(
                            'Tọa độ: ${_currentLat!.toStringAsFixed(6)}, ${_currentLng!.toStringAsFixed(6)}',
                            style: const TextStyle(fontSize: 13, fontFamily: 'monospace', fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFFDE68A)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.warning_amber_rounded, size: 18, color: Color(0xFFD97706)),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Khách hàng chưa có tọa độ ghim cổng nhà.',
                              style: TextStyle(fontSize: 12, color: Color(0xFF92400E)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  const Text('GHI CHÚ NHẬN DIỆN (ĐẶC ĐIỂM CỔNG/CỬA)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _notesController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: 'Ví dụ: Cổng sắt màu xanh, hẻm cụt, chuông cửa bên phải...',
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Nút Lưu thay đổi
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: _isSaving
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.save_rounded, size: 20),
                label: Text(
                  _isSaving ? 'ĐANG LƯU HỒ SƠ...' : 'LƯU TẤT CẢ THAY ĐỔI',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
                onPressed: _isSaving ? null : _handleSave,
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
