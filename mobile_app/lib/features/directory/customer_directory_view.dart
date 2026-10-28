import 'dart:async';
import 'package:flutter/material.dart';
import 'package:delivery_marker_mobile/models/customer_model.dart';
import 'package:delivery_marker_mobile/models/shift_model.dart';
import 'package:delivery_marker_mobile/data/repositories/repository_provider.dart';
import 'package:delivery_marker_mobile/shared_widgets/quick_add_customer_sheet.dart';
import 'package:delivery_marker_mobile/features/shifts/widgets/create_shift_dialog.dart';
import 'package:delivery_marker_mobile/shared_widgets/bulk_paste_phone_sheet.dart';
import 'package:delivery_marker_mobile/features/directory/customer_detail_edit_view.dart';
import 'package:delivery_marker_mobile/features/directory/widgets/customer_list_item.dart';
import 'package:delivery_marker_mobile/features/directory/widgets/directory_filter_tabs.dart';
import 'package:delivery_marker_mobile/features/directory/widgets/directory_header.dart';
import 'package:delivery_marker_mobile/features/directory/widgets/directory_state_views.dart';

export 'package:delivery_marker_mobile/features/directory/customer_detail_edit_view.dart' show CustomerDetailEditView;

class CustomerDirectoryView extends StatefulWidget {
  final ShiftModel? activeShift;
  final Function(ShiftModel)? onShiftUpdated;
  final VoidCallback? onSwitchToMapTab;

  const CustomerDirectoryView({super.key, this.activeShift, this.onShiftUpdated, this.onSwitchToMapTab});

  @override
  State<CustomerDirectoryView> createState() => _CustomerDirectoryViewState();
}

class _CustomerDirectoryViewState extends State<CustomerDirectoryView> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _debounceTimer;

  List<CustomerDirectoryModel> _customers = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _errorMessage;
  String _selectedFilter = 'ALL';
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
    if (_scrollController.hasClients && _scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoading && !_isLoadingMore && _hasMore) _loadMoreCustomers();
    }
  }

  Future<void> _fetchCustomers({bool reset = true}) async {
    if (reset) setState(() { _isLoading = true; _errorMessage = null; _offset = 0; });
    try {
      final res = await RepositoryProvider.customer.getCustomersResponse(
        query: _searchController.text.trim(),
        status: _selectedFilter != 'ALL' ? _selectedFilter : null,
        limit: _pageSize,
        offset: 0,
      );
      if (mounted) setState(() { _customers = res.items; _tabCounts = res.counts; _hasMore = res.pagination.hasMore; _offset = res.items.length; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() { _errorMessage = e.toString().replaceAll('Exception: ', ''); _isLoading = false; });
    }
  }

  Future<void> _loadMoreCustomers() async {
    setState(() => _isLoadingMore = true);
    try {
      final res = await RepositoryProvider.customer.getCustomersResponse(
        query: _searchController.text.trim(),
        status: _selectedFilter != 'ALL' ? _selectedFilter : null,
        limit: _pageSize,
        offset: _offset,
      );
      if (mounted) setState(() { _customers.addAll(res.items); _hasMore = res.pagination.hasMore; _offset += res.items.length; _isLoadingMore = false; });
    } catch (_) {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () => _fetchCustomers(reset: true));
  }

  Future<void> _handleAddCustomerToShift(CustomerDirectoryModel customer) async {
    try {
      final shifts = await RepositoryProvider.shift.getShifts();
      final candidates = shifts.where((s) => s.status == ShiftStatus.preparing || s.status == ShiftStatus.inProgress).toList();
      if (!mounted) return;

      if (candidates.isEmpty) {
        final create = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('Chưa có ca làm việc', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18, color: Color(0xFF0F172A))),
            content: const Text('Chưa có ca làm việc nào đang chuẩn bị hoặc thực hiện. Bác tài có muốn tạo ca mới không?', style: TextStyle(fontSize: 14, color: Color(0xFF334155), height: 1.4)),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('HỦY', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold))),
              ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), onPressed: () => Navigator.pop(ctx, true), child: const Text('TẠO CA MỚI', style: TextStyle(fontWeight: FontWeight.bold))),
            ],
          ),
        );
        if (create == true && mounted) {
          final newShift = await CreateShiftBottomSheet.show(context);
          if (newShift != null && mounted) {
            widget.onShiftUpdated?.call(newShift);
            await _executeAddCustomerToShift(newShift, customer);
          }
        }
      } else if (candidates.length == 1) {
        await _executeAddCustomerToShift(candidates.first, customer);
      } else {
        final selected = await showModalBottomSheet<ShiftModel>(
          context: context,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
          builder: (ctx) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8), child: Text('Chọn ca làm việc để thêm điểm', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)))),
                  const Divider(height: 1, color: Color(0xFFE2E8F0)),
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: candidates.length,
                      separatorBuilder: (_, __) => const Divider(height: 1, indent: 16, endIndent: 16, color: Color(0xFFF1F5F9)),
                      itemBuilder: (c, idx) {
                        final s = candidates[idx];
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                          title: Text(s.displayTitle, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Color(0xFF0F172A))),
                          subtitle: Text('${s.shiftDate} · ${s.status.displayName} · ${s.summary.totalPoints} điểm', style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                          onTap: () => Navigator.pop(ctx, s),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
        if (selected != null && mounted) await _executeAddCustomerToShift(selected, customer);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e'), backgroundColor: const Color(0xFFEF4444)));
    }
  }

  Future<void> _executeAddCustomerToShift(ShiftModel shift, CustomerDirectoryModel customer) async {
    try {
      final res = await RepositoryProvider.shift.addPointToShift(shift.id, customerId: customer.id);
      final isExisting = res['isExisting'] == true;
      final point = res['point'] as ShiftDeliveryPointModel?;
      final shiftTitle = shift.displayTitle;
      if (!mounted) return;

      if (isExisting) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Đã có trong ca $shiftTitle'), backgroundColor: const Color(0xFFF59E0B), behavior: SnackBarBehavior.floating));
        return;
      }

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
                      await RepositoryProvider.shift.removePointFromShift(shift.id, point.id);
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Đã hoàn tác, xóa điểm khỏi ca $shiftTitle'), backgroundColor: const Color(0xFF64748B), behavior: SnackBarBehavior.floating));
                    } catch (err) {
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi hoàn tác: $err'), backgroundColor: const Color(0xFFEF4444)));
                    }
                  },
                )
              : null,
        ),
      );
      _fetchCustomers(reset: false);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi thêm vào ca: $e'), backgroundColor: const Color(0xFFEF4444)));
    }
  }

  Future<void> _openCreateCustomerSheet() async {
    final customer = await showQuickAddCustomerBottomSheet(context);
    if (customer == null || !mounted) return;
    await _fetchCustomers(reset: true);
    _openCustomerDetailEdit(customer);
  }

  void _openBulkPasteDirectorySheet() {
    BulkPastePhoneSheet.show(context: context, isDirectoryMode: true, onCustomersAdded: (_) => _fetchCustomers(reset: true));
  }

  void _openCustomerDetailEdit(CustomerDirectoryModel customer) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CustomerDetailEditView(
          customer: customer,
          onCustomerUpdated: (updated) async {
            _fetchCustomers(reset: true);
            if (widget.activeShift != null) {
              try {
                final shift = await RepositoryProvider.shift.getShiftDetail(widget.activeShift!.id);
                widget.onShiftUpdated?.call(shift);
              } catch (_) {}
            }
          },
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
            DirectoryHeader(
              totalCount: _tabCounts.total,
              searchController: _searchController,
              onSearchChanged: _onSearchChanged,
              onBulkPaste: _openBulkPasteDirectorySheet,
              onAddSingle: _openCreateCustomerSheet,
            ),
            const SizedBox(height: 12),
            DirectoryFilterTabs(
              selectedFilter: _selectedFilter,
              tabCounts: _tabCounts,
              onFilterSelected: (key) {
                setState(() => _selectedFilter = key);
                _fetchCustomers(reset: true);
              },
            ),
            const SizedBox(height: 10),
            Expanded(
              child: _isLoading && _customers.isEmpty
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF2563EB)))
                  : _errorMessage != null
                      ? DirectoryErrorView(errorMessage: _errorMessage!, onRetry: () => _fetchCustomers(reset: true))
                      : _customers.isEmpty
                          ? const DirectoryEmptyView()
                          : RefreshIndicator(
                              color: const Color(0xFF2563EB),
                              onRefresh: () => _fetchCustomers(reset: true),
                              child: ListView.builder(
                                controller: _scrollController,
                                itemCount: _customers.length + (_isLoadingMore ? 1 : 0),
                                itemBuilder: (ctx, idx) {
                                  if (idx < _customers.length) {
                                    return CustomerListItemWidget(customer: _customers[idx], onTap: _openCustomerDetailEdit, onAddToShift: _handleAddCustomerToShift);
                                  }
                                  return const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF2563EB)))));
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
