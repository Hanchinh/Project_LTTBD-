import 'package:flutter/material.dart';
import '../models/data_share_model.dart';
import '../models/shift_model.dart';
import '../repositories/repository_provider.dart';
import '../theme/app_buttons.dart';

/// Màn hình Quản lý Chia sẻ Dữ liệu giữa các Shipper (TASK: DATA-SHARING-BETWEEN-SHIPPERS-023)
/// Nút bấm theo tông đen/navy của 022A (AppButtons), vùng chạm >= 48px, chữ tiếng Việt chuẩn hóa.
class DataSharingView extends StatefulWidget {
  const DataSharingView({super.key});

  @override
  State<DataSharingView> createState() => _DataSharingViewState();
}

class _DataSharingViewState extends State<DataSharingView> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  List<DataShareModel> _outgoingShares = [];
  List<DataShareModel> _incomingShares = [];
  bool _isLoadingOutgoing = false;
  bool _isLoadingIncoming = false;
  String? _outgoingError;
  String? _incomingError;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadOutgoing();
    _loadIncoming();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadOutgoing() async {
    setState(() {
      _isLoadingOutgoing = true;
      _outgoingError = null;
    });
    try {
      final list = await RepositoryProvider.sharing.getOutgoingShares();
      if (mounted) {
        setState(() {
          _outgoingShares = list;
          _isLoadingOutgoing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _outgoingError = e.toString().replaceAll('Exception: ', '');
          _isLoadingOutgoing = false;
        });
      }
    }
  }

  Future<void> _loadIncoming() async {
    setState(() {
      _isLoadingIncoming = true;
      _incomingError = null;
    });
    try {
      final list = await RepositoryProvider.sharing.getIncomingShares();
      if (mounted) {
        setState(() {
          _incomingShares = list;
          _isLoadingIncoming = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _incomingError = e.toString().replaceAll('Exception: ', '');
          _isLoadingIncoming = false;
        });
      }
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontSize: 14)),
        backgroundColor: isError ? const Color(0xFFDC2626) : const Color(0xFF0F172A),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// Mở Modal tạo lời mời chia sẻ mới
  Future<void> _openCreateShareSheet() async {
    final formKey = GlobalKey<FormState>();
    final phoneController = TextEditingController();
    String scope = 'ALL_POINTS';
    String? selectedShiftId;
    bool includePhotos = false;
    int? expiresInDays = 7; // Mặc định 7 ngày
    List<ShiftModel> myShifts = [];
    bool loadingShifts = false;

    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(modalCtx).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Tạo lời mời chia sẻ dữ liệu',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () => Navigator.of(modalCtx).pop(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // 1. Số điện thoại người nhận
                      const Text(
                        'Số điện thoại người nhận *',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        key: const Key('input_recipient_phone'),
                        controller: phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          hintText: 'Nhập số điện thoại shipper nhận (VD: 090xxxxxxx)',
                          hintStyle: const TextStyle(fontSize: 14, color: Color(0xFF94A3B8)),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                          ),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Vui lòng nhập số điện thoại người nhận';
                          }
                          final digits = val.replaceAll(RegExp(r'\D'), '');
                          if (digits.length < 9 || digits.length > 11) {
                            return 'Số điện thoại không hợp lệ';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // 2. Phạm vi chia sẻ
                      const Text(
                        'Phạm vi chia sẻ *',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: ChoiceChip(
                              key: const Key('chip_scope_all_points'),
                              label: const Text('Tất cả điểm đã lưu'),
                              selected: scope == 'ALL_POINTS',
                              onSelected: (selected) {
                                if (selected) {
                                  setModalState(() {
                                    scope = 'ALL_POINTS';
                                    selectedShiftId = null;
                                  });
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ChoiceChip(
                              key: const Key('chip_scope_shift'),
                              label: const Text('Một ca làm việc'),
                              selected: scope == 'SHIFT',
                              onSelected: (selected) async {
                                if (selected) {
                                  setModalState(() {
                                    scope = 'SHIFT';
                                    loadingShifts = true;
                                  });
                                  try {
                                    final shifts = await RepositoryProvider.shift.getShifts();
                                    setModalState(() {
                                      myShifts = shifts;
                                      if (myShifts.isNotEmpty) {
                                        selectedShiftId = myShifts.first.id;
                                      }
                                      loadingShifts = false;
                                    });
                                  } catch (_) {
                                    setModalState(() => loadingShifts = false);
                                  }
                                }
                              },
                            ),
                          ),
                        ],
                      ),

                      // Chọn ca nếu chọn SHIFT
                      if (scope == 'SHIFT') ...[
                        const SizedBox(height: 12),
                        if (loadingShifts)
                          const Center(child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator()))
                        else if (myShifts.isEmpty)
                          const Text(
                            'Bạn chưa có ca làm việc nào để chia sẻ',
                            style: TextStyle(fontSize: 13, color: Color(0xFFDC2626)),
                          )
                        else
                          DropdownButtonFormField<String>(
                            key: const Key('dropdown_select_shift'),
                            initialValue: selectedShiftId,
                            decoration: InputDecoration(
                              labelText: 'Chọn ca cần chia sẻ',
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            items: myShifts.map((s) {
                              return DropdownMenuItem<String>(
                                value: s.id,
                                child: Text('${s.shiftCode} (${s.shiftName ?? s.shiftDate})'),
                              );
                            }).toList(),
                            onChanged: (val) {
                              setModalState(() => selectedShiftId = val);
                            },
                            validator: (val) {
                              if (scope == 'SHIFT' && (val == null || val.isEmpty)) {
                                return 'Vui lòng chọn một ca';
                              }
                              return null;
                            },
                          ),
                      ],
                      const SizedBox(height: 16),

                      // 3. Công tắc kèm ảnh nhà
                      SwitchListTile(
                        key: const Key('switch_include_photos'),
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'Kèm ảnh nhà / định vị hình ảnh',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                        ),
                        subtitle: const Text(
                          'Cho phép người nhận xem ảnh ngôi nhà của khách hàng',
                          style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                        value: includePhotos,
                        activeThumbColor: AppButtons.navy,
                        onChanged: (val) {
                          setModalState(() => includePhotos = val);
                        },
                      ),
                      const SizedBox(height: 12),

                      // 4. Thời hạn sử dụng
                      const Text(
                        'Thời hạn chia sẻ',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        children: [
                          ChoiceChip(
                            key: const Key('chip_expires_7_days'),
                            label: const Text('7 ngày'),
                            selected: expiresInDays == 7,
                            onSelected: (val) => setModalState(() => expiresInDays = val ? 7 : null),
                          ),
                          ChoiceChip(
                            key: const Key('chip_expires_30_days'),
                            label: const Text('30 ngày'),
                            selected: expiresInDays == 30,
                            onSelected: (val) => setModalState(() => expiresInDays = val ? 30 : null),
                          ),
                          ChoiceChip(
                            key: const Key('chip_expires_unlimited'),
                            label: const Text('Không thời hạn'),
                            selected: expiresInDays == null,
                            onSelected: (val) => setModalState(() => expiresInDays = null),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // 5. Nút gửi lời mời
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          key: const Key('btn_submit_create_share'),
                          style: AppButtons.primary(minHeight: 48, borderRadius: 12),
                          onPressed: () async {
                            if (!formKey.currentState!.validate()) return;
                            try {
                              await RepositoryProvider.sharing.createShare(
                                recipientPhone: phoneController.text.trim(),
                                scope: scope,
                                shiftId: selectedShiftId,
                                includePhotos: includePhotos,
                                expiresInDays: expiresInDays,
                              );
                              if (modalCtx.mounted) {
                                Navigator.of(modalCtx).pop(true);
                              }
                              _showSnackBar('Đã gửi lời mời chia sẻ dữ liệu thành công');
                              _loadOutgoing();
                            } catch (e) {
                              _showSnackBar(e.toString().replaceAll('Exception: ', ''), isError: true);
                            }
                          },
                          child: const Text('GỬI LỜI MỜI', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// Hộp thoại xác nhận dừng chia sẻ
  Future<void> _handleRevokeShare(DataShareModel share) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Dừng chia sẻ dữ liệu?'),
          content: Text(
            'Bạn có chắc chắn muốn dừng chia sẻ với ${share.recipientName ?? share.recipientPhone ?? 'người nhận'}? Người này sẽ không còn quyền xem các điểm này nữa.',
          ),
          actions: [
            TextButton(
              style: AppButtons.text(minHeight: 48),
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('HỦY', style: TextStyle(color: Color(0xFF64748B))),
            ),
            ElevatedButton(
              key: const Key('btn_confirm_revoke_dialog'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
                minimumSize: const Size(48, 48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('DỪNG CHIA SẺ'),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      try {
        await RepositoryProvider.sharing.revokeShare(share.id);
        _showSnackBar('Đã dừng chia sẻ dữ liệu thành công');
        _loadOutgoing();
      } catch (e) {
        _showSnackBar(e.toString().replaceAll('Exception: ', ''), isError: true);
      }
    }
  }

  /// Xử lý chấp nhận lời mời
  Future<void> _handleAcceptShare(DataShareModel share) async {
    try {
      await RepositoryProvider.sharing.acceptShare(share.id);
      _showSnackBar('Đã chấp nhận lời mời chia sẻ dữ liệu');
      _loadIncoming();
    } catch (e) {
      _showSnackBar(e.toString().replaceAll('Exception: ', ''), isError: true);
    }
  }

  /// Xử lý từ chối lời mời
  Future<void> _handleDeclineShare(DataShareModel share) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Từ chối lời mời?'),
        content: Text('Bạn có chắc muốn từ chối lời mời từ ${share.ownerName ?? share.ownerPhone ?? 'người gửi'}?'),
        actions: [
          TextButton(
            style: AppButtons.text(minHeight: 48),
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('QUAY LẠI'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              minimumSize: const Size(48, 48),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('TỪ CHỐI'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await RepositoryProvider.sharing.declineShare(share.id);
        _showSnackBar('Đã từ chối lời mời chia sẻ');
        _loadIncoming();
      } catch (e) {
        _showSnackBar(e.toString().replaceAll('Exception: ', ''), isError: true);
      }
    }
  }

  /// Hộp thoại nhập điểm chia sẻ vào vị trí đã lưu của người nhận
  Future<void> _handleImportShare(DataShareModel share) async {
    bool replaceExisting = false;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text(
                'Nhập điểm vào vị trí của tôi',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Bạn chuẩn bị nhập ${share.sharedPointsCount} điểm từ ${share.ownerName ?? 'người chia sẻ'} vào danh bạ vị trí đã lưu của mình.',
                    style: const TextStyle(fontSize: 14, color: Color(0xFF334155)),
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    key: const Key('switch_replace_existing_import'),
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Ghi đè nếu khách hàng đã có vị trí',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    subtitle: const Text(
                      'Mặc định sẽ bỏ qua những khách hàng bạn đã lưu vị trí',
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                    value: replaceExisting,
                    activeThumbColor: AppButtons.navy,
                    onChanged: (val) {
                      setDialogState(() => replaceExisting = val);
                    },
                  ),
                ],
              ),
              actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              actions: [
                TextButton(
                  style: AppButtons.text(minHeight: 48),
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('HỦY', style: TextStyle(color: Color(0xFF64748B))),
                ),
                ElevatedButton(
                  key: const Key('btn_confirm_import_dialog'),
                  style: AppButtons.primary(minHeight: 48, borderRadius: 10),
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: const Text('BẮT ĐẦU NHẬP'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirm == true) {
      try {
        final result = await RepositoryProvider.sharing.importSharedLocations(
          share.id,
          all: true,
          replaceExisting: replaceExisting,
        );
        final imported = result['importedCount'] ?? 0;
        final skipped = result['skippedCount'] ?? 0;
        final outOfArea = result['outOfAreaCount'] ?? 0;

        _showSnackBar(
          'Đã nhập thành công $imported điểm'
          '${skipped > 0 ? ', bỏ qua $skipped điểm đã có' : ''}'
          '${outOfArea > 0 ? ', $outOfArea điểm ngoài khu vực' : ''}',
        );
        _loadIncoming();
      } catch (e) {
        _showSnackBar(e.toString().replaceAll('Exception: ', ''), isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Chia sẻ dữ liệu',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0F172A),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF0F172A),
          unselectedLabelColor: const Color(0xFF64748B),
          indicatorColor: const Color(0xFF0F172A),
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          tabs: const [
            Tab(key: Key('tab_outgoing_shares'), text: 'Tôi chia sẻ'),
            Tab(key: Key('tab_incoming_shares'), text: 'Chia sẻ cho tôi'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOutgoingTab(),
          _buildIncomingTab(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('btn_open_create_share_sheet'),
        backgroundColor: AppButtons.navy,
        foregroundColor: Colors.white,
        elevation: 4,
        onPressed: _openCreateShareSheet,
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'TẠO LỜI MỜI',
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
        ),
      ),
    );
  }

  // ==========================================
  // TAB 1: TÔI CHIA SẺ (OUTGOING)
  // ==========================================
  Widget _buildOutgoingTab() {
    if (_isLoadingOutgoing) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_outgoingError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, size: 48, color: Color(0xFFEF4444)),
              const SizedBox(height: 12),
              Text(
                _outgoingError!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                style: AppButtons.primary(minHeight: 48),
                onPressed: _loadOutgoing,
                child: const Text('Thử lại'),
              ),
            ],
          ),
        ),
      );
    }

    if (_outgoingShares.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.share_location_rounded, size: 48, color: Color(0xFF94A3B8)),
              ),
              const SizedBox(height: 16),
              const Text(
                'Bạn chưa gửi lời mời chia sẻ nào',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
              ),
              const SizedBox(height: 8),
              const Text(
                'Nhấn "TẠO LỜI MỜI" để chia sẻ danh bạ vị trí hoặc ca giao hàng với đồng nghiệp.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadOutgoing,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
        itemCount: _outgoingShares.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (ctx, idx) {
          final share = _outgoingShares[idx];
          return _buildOutgoingCard(share);
        },
      ),
    );
  }

  Widget _buildOutgoingCard(DataShareModel share) {
    final canRevoke = share.isPending || share.isActive;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Color(0x0D000000), blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Người nhận & Trạng thái
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const CircleAvatar(
                      radius: 18,
                      backgroundColor: Color(0xFFF1F5F9),
                      child: Icon(Icons.person_rounded, size: 20, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            share.recipientName ?? share.recipientPhone ?? 'Người nhận',
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (share.recipientPhone != null)
                            Text(
                              share.recipientPhone!,
                              style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: share.statusBgColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  share.statusLabel,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: share.statusTextColor,
                  ),
                ),
              ),
            ],
          ),

          const Divider(height: 20, color: Color(0xFFF1F5F9)),

          // Chi tiết phạm vi & số điểm
          Row(
            children: [
              Icon(
                share.scope == 'SHIFT' ? Icons.work_history_rounded : Icons.place_rounded,
                size: 16,
                color: const Color(0xFF64748B),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  share.scope == 'SHIFT' ? 'Ca: ${share.shiftCode ?? 'Một ca'}' : 'Tất cả điểm đã lưu',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Text(
                  '${share.sharedPointsCount} điểm',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
              ),
            ],
          ),

          const SizedBox(height: 6),

          // Kèm ảnh & Hạn dùng
          Row(
            children: [
              Icon(
                share.includePhotos ? Icons.photo_library_rounded : Icons.no_photography_rounded,
                size: 14,
                color: share.includePhotos ? const Color(0xFF16A34A) : const Color(0xFF94A3B8),
              ),
              const SizedBox(width: 6),
              Text(
                share.includePhotos ? 'Có kèm ảnh nhà' : 'Không kèm ảnh',
                style: TextStyle(fontSize: 12, color: share.includePhotos ? const Color(0xFF16A34A) : const Color(0xFF94A3B8)),
              ),
              if (share.expiresAt != null) ...[
                const SizedBox(width: 12),
                const Icon(Icons.timer_outlined, size: 14, color: Color(0xFF64748B)),
                const SizedBox(width: 4),
                Text(
                  'Hết hạn: ${share.expiresAt!.day}/${share.expiresAt!.month}/${share.expiresAt!.year}',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
              ],
            ],
          ),

          if (canRevoke) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: SizedBox(
                height: 48,
                child: OutlinedButton(
                  key: Key('btn_revoke_share_${share.id}'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFDC2626),
                    side: const BorderSide(color: Color(0xFFFCA5A5)),
                    minimumSize: const Size(48, 48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => _handleRevokeShare(share),
                  child: const Text('DỪNG CHIA SẺ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ==========================================
  // TAB 2: CHIA SẺ CHO TÔI (INCOMING)
  // ==========================================
  Widget _buildIncomingTab() {
    if (_isLoadingIncoming) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_incomingError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, size: 48, color: Color(0xFFEF4444)),
              const SizedBox(height: 12),
              Text(
                _incomingError!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                style: AppButtons.primary(minHeight: 48),
                onPressed: _loadIncoming,
                child: const Text('Thử lại'),
              ),
            ],
          ),
        ),
      );
    }

    if (_incomingShares.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.inbox_rounded, size: 48, color: Color(0xFF94A3B8)),
              ),
              const SizedBox(height: 16),
              const Text(
                'Bạn chưa nhận được lời mời nào',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
              ),
              const SizedBox(height: 8),
              const Text(
                'Khi đồng nghiệp chia sẻ điểm vị trí hoặc ca cho bạn, lời mời sẽ xuất hiện tại đây.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadIncoming,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
        itemCount: _incomingShares.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (ctx, idx) {
          final share = _incomingShares[idx];
          return _buildIncomingCard(share);
        },
      ),
    );
  }

  Widget _buildIncomingCard(DataShareModel share) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Color(0x0D000000), blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Người gửi & Trạng thái
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const CircleAvatar(
                      radius: 18,
                      backgroundColor: Color(0xFFF1F5F9),
                      child: Icon(Icons.arrow_downward_rounded, size: 20, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            share.ownerName ?? share.ownerPhone ?? 'Người chia sẻ',
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (share.ownerPhone != null)
                            Text(
                              share.ownerPhone!,
                              style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: share.statusBgColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  share.statusLabel,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: share.statusTextColor,
                  ),
                ),
              ),
            ],
          ),

          const Divider(height: 20, color: Color(0xFFF1F5F9)),

          // Phạm vi & Số điểm
          Row(
            children: [
              Icon(
                share.scope == 'SHIFT' ? Icons.work_history_rounded : Icons.place_rounded,
                size: 16,
                color: const Color(0xFF64748B),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  share.scope == 'SHIFT' ? 'Ca: ${share.shiftCode ?? 'Một ca'}' : 'Tất cả điểm đã lưu',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Text(
                  '${share.sharedPointsCount} điểm',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
              ),
            ],
          ),

          const SizedBox(height: 6),

          // Kèm ảnh & Hạn dùng
          Row(
            children: [
              Icon(
                share.includePhotos ? Icons.photo_library_rounded : Icons.no_photography_rounded,
                size: 14,
                color: share.includePhotos ? const Color(0xFF16A34A) : const Color(0xFF94A3B8),
              ),
              const SizedBox(width: 6),
              Text(
                share.includePhotos ? 'Có kèm ảnh nhà' : 'Không kèm ảnh',
                style: TextStyle(fontSize: 12, color: share.includePhotos ? const Color(0xFF16A34A) : const Color(0xFF94A3B8)),
              ),
              if (share.expiresAt != null) ...[
                const SizedBox(width: 12),
                const Icon(Icons.timer_outlined, size: 14, color: Color(0xFF64748B)),
                const SizedBox(width: 4),
                Text(
                  'Hết hạn: ${share.expiresAt!.day}/${share.expiresAt!.month}/${share.expiresAt!.year}',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
              ],
            ],
          ),

          // Các nút hành động
          if (share.isPending) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: OutlinedButton(
                      key: Key('btn_decline_share_${share.id}'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFDC2626),
                        side: const BorderSide(color: Color(0xFFFCA5A5)),
                        minimumSize: const Size(48, 48),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () => _handleDeclineShare(share),
                      child: const Text('TỪ CHỐI', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      key: Key('btn_accept_share_${share.id}'),
                      style: AppButtons.primary(minHeight: 48, borderRadius: 10),
                      onPressed: () => _handleAcceptShare(share),
                      child: const Text('CHẤP NHẬN', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
              ],
            ),
          ] else if (share.isActive) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                key: Key('btn_import_share_${share.id}'),
                style: AppButtons.primary(minHeight: 48, borderRadius: 10),
                onPressed: () => _handleImportShare(share),
                icon: const Icon(Icons.download_rounded, size: 20),
                label: Text(
                  'NHẬP VÀO CỦA TÔI (${share.sharedPointsCount} ĐIỂM)',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
