import 'dart:async';
import 'package:flutter/material.dart';
import '../models/customer_model.dart';
import '../models/shift_model.dart';
import '../services/api_service.dart';
import '../widgets/quick_add_customer_sheet.dart';
import '../widgets/authenticated_image.dart';
import '../widgets/customer_photos_strip_widget.dart';
import '../widgets/create_shift_dialog.dart';
import '../widgets/bulk_paste_phone_sheet.dart';
import '../theme/app_buttons.dart';
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
  final ScrollController _scrollController = ScrollController();
  Timer? _debounceTimer;

  List<CustomerDirectoryModel> _customers = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _errorMessage;

  String _selectedFilter = 'ALL'; // ALL, VERIFIED, TEMPORARY, NO_LOCATION
  CustomerTabCounts _tabCounts = const CustomerTabCounts();

  static const int _pageSize = 30;
  int _offset = 0;
  bool _hasMore = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _fetchCustomers(reset: true);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.hasClients &&
        _scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoading && !_isLoadingMore && _hasMore) {
        _loadMoreCustomers();
      }
    }
  }

  Future<void> _fetchCustomers({bool reset = true}) async {
    if (reset) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
        _offset = 0;
      });
    }

    try {
      String? statusParam;
      if (_selectedFilter != 'ALL') {
        statusParam = _selectedFilter;
      }

      final res = await ApiService.getCustomersResponse(
        query: _searchController.text.trim(),
        status: statusParam,
        limit: _pageSize,
        offset: 0,
      );

      if (mounted) {
        setState(() {
          _customers = res.items;
          _tabCounts = res.counts;
          _hasMore = res.pagination.hasMore;
          _offset = res.items.length;
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

  Future<void> _loadMoreCustomers() async {
    setState(() => _isLoadingMore = true);

    try {
      String? statusParam;
      if (_selectedFilter != 'ALL') {
        statusParam = _selectedFilter;
      }

      final res = await ApiService.getCustomersResponse(
        query: _searchController.text.trim(),
        status: statusParam,
        limit: _pageSize,
        offset: _offset,
      );

      if (mounted) {
        setState(() {
          _customers.addAll(res.items);
          _hasMore = res.pagination.hasMore;
          _offset += res.items.length;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingMore = false);
      }
    }
  }

  void _onSearchChanged(String val) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _fetchCustomers(reset: true);
    });
  }

  /// Xử lý bấm nút "+" thêm khách vào ca làm việc
  Future<void> _handleAddCustomerToShift(CustomerDirectoryModel customer) async {
    try {
      // 1. Tải danh sách ca hiện có của shipper
      final shifts = await ApiService.getShifts();
      // Ca ứng viên: PREPARING hoặc IN_PROGRESS
      final candidateShifts = shifts
          .where((s) => s.status == ShiftStatus.preparing || s.status == ShiftStatus.inProgress)
          .toList();

      if (!mounted) return;

      if (candidateShifts.isEmpty) {
        // Nhánh 3: Chưa có ca -> Hỏi "Chưa có ca, tạo ca mới?"
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
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('TẠO CA MỚI', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );

        if (shouldCreate == true && mounted) {
          final newShift = await CreateShiftBottomSheet.show(context);
          if (newShift != null && mounted) {
            await _executeAddCustomerToShift(newShift, customer);
          }
        }
      } else if (candidateShifts.length == 1) {
        // Nhánh 1: Đúng 1 ca đang chuẩn bị/thực hiện -> Thêm thẳng
        await _executeAddCustomerToShift(candidateShifts.first, customer);
      } else {
        // Nhánh 2: Nhiều ca -> Mở BottomSheet chọn ca (tên ca, ngày, trạng thái)
        final selectedShift = await showModalBottomSheet<ShiftModel>(
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
                        'Chọn ca làm việc để thêm điểm',
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

        if (selectedShift != null && mounted) {
          await _executeAddCustomerToShift(selectedShift, customer);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e'), backgroundColor: const Color(0xFFEF4444)),
        );
      }
    }
  }

  /// Thực thi gọi API thêm khách vào ca và xử lý Hoàn tác / Trùng lặp
  Future<void> _executeAddCustomerToShift(ShiftModel shift, CustomerDirectoryModel customer) async {
    try {
      final res = await ApiService.addPointToShift(
        shift.id,
        customerId: customer.id,
      );

      final isExisting = res['isExisting'] == true;
      final point = res['point'] as ShiftDeliveryPointModel?;
      final shiftTitle = shift.displayTitle;

      if (!mounted) return;

      if (isExisting) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã có trong ca $shiftTitle'),
            backgroundColor: const Color(0xFFF59E0B),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      // Thông báo thành công kèm nút HOÀN TÁC
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã thêm vào $shiftTitle'),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
          action: point != null
              ? SnackBarAction(
                  label: 'HOÀN TÁC',
                  textColor: Colors.white,
                  onPressed: () async {
                    try {
                      await ApiService.removePointFromShift(shift.id, point.id);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Đã hoàn tác, xóa điểm khỏi ca $shiftTitle'),
                            backgroundColor: const Color(0xFF64748B),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    } catch (err) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Lỗi hoàn tác: $err'), backgroundColor: const Color(0xFFEF4444)),
                        );
                      }
                    }
                  },
                )
              : null,
        ),
      );

      // Cập nhật lại danh bạ
      _fetchCustomers(reset: false);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi thêm vào ca: $e'), backgroundColor: const Color(0xFFEF4444)),
        );
      }
    }
  }

  Future<void> _openCreateCustomerSheet() async {
    final customer = await showQuickAddCustomerBottomSheet(context);
    if (customer == null) return;

    if (!mounted) return;
    await _fetchCustomers(reset: true);

    _openCustomerDetailEdit(customer);
  }

  void _openBulkPasteDirectorySheet() {
    BulkPastePhoneSheet.show(
      context: context,
      isDirectoryMode: true,
      onCustomersAdded: (result) {
        _fetchCustomers(reset: true);
      },
    );
  }

  void _openCustomerDetailEdit(CustomerDirectoryModel customer) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CustomerDetailEditView(
          customer: customer,
          onCustomerUpdated: (updated) async {
            _fetchCustomers(reset: true);
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

  Widget _buildFilterTab({
    required String key,
    required String label,
    required int count,
    Color? dotColor,
  }) {
    final isSelected = _selectedFilter == key;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          if (_selectedFilter != key) {
            setState(() => _selectedFilter = key);
            _fetchCustomers(reset: true);
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF0F172A) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (dotColor != null) ...[
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
              ],
              Text(
                '$label ($count)',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? Colors.white : const Color(0xFF475569),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCustomerRow(CustomerDirectoryModel customer) {
    // Trạng thái: VERIFIED (xanh), TEMPORARY (cam), NO_LOCATION (xám)
    Color dotColor;
    switch (customer.locationState) {
      case LocationStatus.verified:
        dotColor = const Color(0xFF10B981); // Xanh lá
        break;
      case LocationStatus.temporary:
        dotColor = const Color(0xFFF59E0B); // Cam
        break;
      case LocationStatus.noLocation:
        dotColor = const Color(0xFF94A3B8); // Xám
        break;
    }

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Color(0xFFF1F5F9), width: 1),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _openCustomerDetailEdit(customer),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                // 1. Ảnh vuông nhỏ bo góc ở trái kèm chấm trạng thái góc dưới phải
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: customer.hasPhoto
                            ? AuthenticatedImage(
                                photoUrl: customer.effectivePhotoUrl,
                                fit: BoxFit.cover,
                                errorWidget: const Icon(Icons.photo_camera_outlined, color: Color(0xFF94A3B8), size: 22),
                              )
                            : const Center(
                                child: Icon(Icons.photo_camera_outlined, color: Color(0xFF94A3B8), size: 22),
                              ),
                      ),
                    ),
                    Positioned(
                      bottom: -2,
                      right: -2,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: dotColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),

                // 2. Dòng 1: "SĐT định dạng 0908 333 166 · Tên" & Dòng 2: Địa chỉ/ghi chú cắt "..."
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${customer.formattedPhoneNumber} · ${customer.fullName}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        customer.addressText.isNotEmpty ? customer.addressText : 'Chưa có địa chỉ',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF64748B),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // 3. Nút "+" bo vuông nhỏ ở phải mỗi dòng, vùng chạm >= 48px
                SizedBox(
                  width: 48,
                  height: 48,
                  child: Center(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => _handleAddCustomerToShift(customer),
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        child: const Icon(Icons.add_rounded, size: 20, color: Color(0xFF0F172A)),
                      ),
                    ),
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
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            // Header: "Danh bạ" kèm huy hiệu tổng + nút "+ Thêm số"
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [
                    const Text(
                      'Danh bạ',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: Text(
                        '${_tabCounts.total}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF475569),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      key: const ValueKey('btn_bulk_paste_directory'),
                      style: AppButtons.secondary(
                        minHeight: 48,
                        borderRadius: 10,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                      icon: const Icon(Icons.playlist_add_rounded, size: 18),
                      label: const Text(
                        'Dán nhiều số',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                      ),
                      onPressed: _openBulkPasteDirectorySheet,
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      key: const ValueKey('btn_add_single_customer'),
                      style: AppButtons.primary(
                        minHeight: 48,
                        borderRadius: 10,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text(
                        'Thêm số',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                      ),
                      onPressed: _openCreateCustomerSheet,
                    ),
                  ],
                ),
              ),
            ),

            // Ô tìm kiếm bo tròn "Tìm số điện thoại, tên, địa chỉ..."
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  style: const TextStyle(fontSize: 14, color: Color(0xFF0F172A)),
                  decoration: InputDecoration(
                    hintText: 'Tìm số điện thoại, tên, địa chỉ...',
                    hintStyle: const TextStyle(fontSize: 14, color: Color(0xFF94A3B8)),
                    prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF64748B), size: 20),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF64748B)),
                            onPressed: () {
                              _searchController.clear();
                              _onSearchChanged('');
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Hàng tab lọc cuộn ngang có số lượng: Tất cả | Đã xác minh | Vị trí tạm | Chưa có vị trí
            SizedBox(
              height: 38,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _buildFilterTab(
                    key: 'ALL',
                    label: 'Tất cả',
                    count: _tabCounts.total,
                  ),
                  _buildFilterTab(
                    key: 'VERIFIED',
                    label: 'Đã xác minh',
                    count: _tabCounts.verified,
                    dotColor: const Color(0xFF10B981),
                  ),
                  _buildFilterTab(
                    key: 'TEMPORARY',
                    label: 'Vị trí tạm',
                    count: _tabCounts.temporary,
                    dotColor: const Color(0xFFF59E0B),
                  ),
                  _buildFilterTab(
                    key: 'NO_LOCATION',
                    label: 'Chưa có vị trí',
                    count: _tabCounts.noLocation,
                    dotColor: const Color(0xFF94A3B8),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Danh sách khách hàng ListView.builder + phân trang
            Expanded(
              child: _isLoading && _customers.isEmpty
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
                                  style: AppButtons.secondary(minHeight: 48, borderRadius: 10),
                                  icon: const Icon(Icons.refresh_rounded, size: 18),
                                  onPressed: () => _fetchCustomers(reset: true),
                                  label: const Text('Thử lại'),
                                ),
                              ],
                            ),
                          ),
                        )
                      : _customers.isEmpty
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
                                      child: const Icon(Icons.person_off_outlined, size: 44, color: Color(0xFF94A3B8)),
                                    ),
                                    const SizedBox(height: 16),
                                    const Text(
                                      'Chưa có khách nào',
                                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                                    ),
                                    const SizedBox(height: 6),
                                    const Text(
                                      'Bác tài có thể bấm "+ Thêm số" ở trên để lưu khách mới.',
                                      style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : RefreshIndicator(
                              color: const Color(0xFF2563EB),
                              onRefresh: () => _fetchCustomers(reset: true),
                              child: ListView.builder(
                                controller: _scrollController,
                                itemCount: _customers.length + (_isLoadingMore ? 1 : 0),
                                itemBuilder: (ctx, idx) {
                                  if (idx < _customers.length) {
                                    return _buildCustomerRow(_customers[idx]);
                                  } else {
                                    return const Padding(
                                      padding: EdgeInsets.symmetric(vertical: 16),
                                      child: Center(
                                        child: SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF2563EB)),
                                        ),
                                      ),
                                    );
                                  }
                                },
                              ),
                            ),
            ),
          ],
        ),
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
                      const Expanded(
                        child: Text(
                          'Ảnh mặt tiền / cổng nhà',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Tối đa 10 ảnh',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
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
                  const Text(
                    'TỌA ĐỘ & GHI CHÚ VỊ TRÍ',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.start,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (_currentLat != null && _currentLng != null)
                        OutlinedButton.icon(
                          key: const Key('btn_delete_customer_location'),
                          style: AppButtons.secondary(minHeight: 48, borderRadius: 8),
                          icon: const Icon(Icons.delete_outline_rounded, size: 16, color: Color(0xFF0F172A)),
                          label: const Text(
                            'Xóa vị trí',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                          ),
                          onPressed: _isSaving ? null : _confirmAndDeleteLocation,
                        ),
                      ElevatedButton.icon(
                        key: const Key('btn_pick_location_map'),
                        style: AppButtons.primary(minHeight: 48, borderRadius: 8),
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
                          Expanded(
                            child: Text(
                              'Tọa độ: ${_currentLat!.toStringAsFixed(6)}, ${_currentLng!.toStringAsFixed(6)}',
                              style: const TextStyle(fontSize: 13, fontFamily: 'monospace', fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
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
