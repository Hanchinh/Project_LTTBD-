import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import '../models/shift_model.dart';
import '../services/api_service.dart';
import '../widgets/fullscreen_image_viewer.dart';

/// Màn hình Bản đồ Chính làm Trung tâm (Map-First Architecture)
class MainMapView extends StatefulWidget {
  final ShiftModel? initialShift;
  final Function(ShiftModel)? onActiveShiftChanged;
  final VoidCallback? onOpenDirectory;
  final VoidCallback? onOpenShifts;

  const MainMapView({
    super.key,
    this.initialShift,
    this.onActiveShiftChanged,
    this.onOpenDirectory,
    this.onOpenShifts,
  });

  @override
  State<MainMapView> createState() => MainMapViewState();
}

class MainMapViewState extends State<MainMapView> {
  final MapController _mapController = MapController();
  final ImagePicker _imagePicker = ImagePicker();

  ShiftModel? _activeShift;
  List<ShiftModel> _availableShifts = [];
  bool _isLoadingShifts = true;
  bool _isLoadingPoints = false;
  String? _errorMessage;

  // Race-condition protection counter khi đổi ca liên tục
  int _loadSequence = 0;

  // Timestamp làm mới ảnh chống dính cache
  int _photoCacheVersion = DateTime.now().millisecondsSinceEpoch;

  // Vị trí GPS của shipper
  LatLng? _shipperLocation;
  bool _isLocatingShipper = false;

  // Điểm giao đang được chọn trên bản đồ
  ShiftDeliveryPointModel? _selectedPoint;
  bool _isMapReady = false;

  // Chế độ ghim vị trí trực tiếp trên bản đồ chính (TASK: MAP-PIN-FLOW-SIMPLIFICATION-006)
  bool _isPinningMode = false;
  ShiftDeliveryPointModel? _pinningPoint;
  LatLng _currentCrosshairCoord = _hcmDefault;
  bool _isSavingPin = false;

  // Loại bản đồ nền (0: Google Đường phố, 1: Google Hybrid Vệ tinh, 2: CartoDB Voyager)
  int _currentMapType = 0;
  bool _hasTileError = false;

  // Mở rộng khay tóm tắt danh sách điểm giao dưới đáy
  bool _isSummaryTrayExpanded = false;

  // Tọa độ mặc định (TP.HCM)
  static const LatLng _hcmDefault = LatLng(10.776889, 106.700806);

  @override
  void initState() {
    super.initState();
    _activeShift = widget.initialShift;
    _initShiftsAndSelectDefault();
    _getShipperLocation();
  }

  String _getUrlTemplate() {
    switch (_currentMapType) {
      case 1:
        return 'https://mt1.google.com/vt/lyrs=y&x={x}&y={y}&z={z}';
      case 2:
        return 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png';
      case 0:
      default:
        return 'https://mt1.google.com/vt/lyrs=m&x={x}&y={y}&z={z}';
    }
  }

  List<String> _getSubdomains() {
    if (_currentMapType == 2) {
      return const ['a', 'b', 'c', 'd'];
    }
    return const [];
  }

  void _switchMapType() {
    setState(() {
      _currentMapType = (_currentMapType + 1) % 3;
      _hasTileError = false;
    });
    final names = [
      'Bản đồ đường phố',
      'Ảnh vệ tinh + Tên đường',
      'Bản đồ CartoDB Voyager',
    ];
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Đã chuyển sang: ${names[_currentMapType]}'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Khởi tạo danh sách ca làm việc và chọn ca mặc định theo thứ tự ưu tiên
  Future<void> _initShiftsAndSelectDefault() async {
    setState(() {
      _isLoadingShifts = true;
      _errorMessage = null;
    });

    try {
      final shifts = await ApiService.getShifts();
      if (!mounted) return;

      setState(() {
        _availableShifts = shifts;
        _isLoadingShifts = false;
      });

      if (shifts.isEmpty) {
        setState(() {
          _activeShift = null;
        });
        return;
      }

      // 1. Kiểm tra ca đã chọn gần nhất trong SharedPreferences
      final savedShiftId = await ApiService.getLastActiveShiftId();
      ShiftModel? chosenShift;

      if (savedShiftId != null) {
        final found = shifts.where((s) => s.id == savedShiftId).toList();
        if (found.isNotEmpty) {
          chosenShift = found.first;
        }
      }

      // 2. Nếu không có, tự động chọn ca IN_PROGRESS phù hợp
      if (chosenShift == null) {
        final inProgressList = shifts.where((s) => s.status == ShiftStatus.inProgress).toList();
        if (inProgressList.isNotEmpty) {
          chosenShift = inProgressList.first;
        }
      }

      // 3. Nếu không có ca đang thực hiện, chọn ca PREPARING mới nhất
      if (chosenShift == null) {
        final preparingList = shifts.where((s) => s.status == ShiftStatus.preparing).toList();
        if (preparingList.isNotEmpty) {
          chosenShift = preparingList.first;
        }
      }

      // 4. Nếu vẫn không có, chọn ca đầu tiên trong danh sách
      chosenShift ??= shifts.first;

      // Kích hoạt ca được chọn
      await _switchShift(chosenShift.id, preserveCamera: false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoadingShifts = false;
      });
    }
  }

  /// Chuyển đổi sang ca làm việc khác (chống race condition với _loadSequence)
  Future<void> _switchShift(String shiftId, {bool preserveCamera = false, bool preserveSelected = false}) async {
    final currentSeq = ++_loadSequence;

    setState(() {
      _isLoadingPoints = true;
      if (!preserveSelected) {
        _selectedPoint = null;
      }
    });

    try {
      // Lưu lại ca đã chọn gần nhất vào bộ nhớ
      await ApiService.saveLastActiveShiftId(shiftId);

      // Tải chi tiết ca kèm các điểm giao
      final fullShift = await ApiService.getShiftDetail(shiftId);

      // Chống race-condition: nếu đã có request đổi ca mới hơn thì bỏ qua
      if (currentSeq != _loadSequence || !mounted) return;

      setState(() {
        _activeShift = fullShift;
        _isLoadingPoints = false;
        _photoCacheVersion = DateTime.now().millisecondsSinceEpoch;

        // Cập nhật lại điểm đang chọn nếu có yêu cầu giữ lại
        if (preserveSelected && _selectedPoint != null) {
          final matched = fullShift.deliveryPoints.where((p) => p.id == _selectedPoint!.id).toList();
          if (matched.isNotEmpty) {
            _selectedPoint = matched.first;
          }
        }
      });

      // Báo cho component cha (nếu có)
      widget.onActiveShiftChanged?.call(fullShift);

      // Fit bounds camera bản đồ
      if (!preserveCamera && _isMapReady) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _fitMapBounds();
        });
      }
    } catch (e) {
      if (currentSeq != _loadSequence || !mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoadingPoints = false;
      });
    }
  }

  /// Gọi từ bên ngoài khi có điểm mới thêm vào ca
  void reloadActiveShift({bool preserveSelected = true}) {
    if (_activeShift != null) {
      _switchShift(_activeShift!.id, preserveCamera: true, preserveSelected: preserveSelected);
    }
  }

  /// Lấy vị trí GPS của shipper
  Future<void> _getShipperLocation() async {
    setState(() => _isLocatingShipper = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      if (permission == LocationPermission.deniedForever) return;

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );

      if (mounted) {
        setState(() {
          _shipperLocation = LatLng(pos.latitude, pos.longitude);
        });
      }
    } catch (_) {
      // Bỏ qua lỗi định vị
    } finally {
      if (mounted) setState(() => _isLocatingShipper = false);
    }
  }

  /// Căn chỉnh camera bao quát toàn bộ điểm giao có tọa độ
  void _fitMapBounds() {
    if (!_isMapReady) return;

    if (_activeShift == null) {
      if (_shipperLocation != null) {
        _mapController.move(_shipperLocation!, 15.0);
      }
      return;
    }

    final validPoints = _activeShift!.deliveryPoints.where((p) => p.hasValidCoordinates).toList();
    if (validPoints.isEmpty) {
      if (_shipperLocation != null) {
        _mapController.move(_shipperLocation!, 15.0);
      }
      return;
    }

    if (validPoints.length == 1) {
      _mapController.move(validPoints.first.latLng!, 16.5);
      return;
    }

    double minLat = validPoints.first.latitude!;
    double maxLat = validPoints.first.latitude!;
    double minLng = validPoints.first.longitude!;
    double maxLng = validPoints.first.longitude!;

    for (final p in validPoints) {
      if (p.latitude! < minLat) minLat = p.latitude!;
      if (p.latitude! > maxLat) maxLat = p.latitude!;
      if (p.longitude! < minLng) minLng = p.longitude!;
      if (p.longitude! > maxLng) maxLng = p.longitude!;
    }

    final bounds = LatLngBounds(LatLng(minLat, minLng), LatLng(maxLat, maxLng));
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.fromLTRB(40, 110, 40, 240),
      ),
    );
  }

  /// Mở Bottom Sheet danh sách ca làm việc để chọn/chuyển ca
  void _openShiftPickerSheet() {
    final searchCtrl = TextEditingController();
    String filterStatus = 'ALL';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final query = searchCtrl.text.trim().toLowerCase();

            final filteredShifts = _availableShifts.where((s) {
              if (filterStatus != 'ALL' && s.status.toApiString() != filterStatus) {
                return false;
              }
              if (query.isNotEmpty) {
                final matchCode = s.shiftCode.toLowerCase().contains(query);
                final matchDate = s.shiftDate.toLowerCase().contains(query);
                return matchCode || matchDate;
              }
              return true;
            }).toList();

            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.65,
              minChildSize: 0.4,
              maxChildSize: 0.9,
              builder: (_, scrollCtrl) {
                return Column(
                  children: [
                    // Thanh gạch ngang (Drag handle)
                    Container(
                      width: 36,
                      height: 4,
                      margin: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),

                    // Tiêu đề
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                      child: Row(
                        children: [
                          const Icon(Icons.swap_horiz_rounded, color: Color(0xFF2563EB), size: 24),
                          const SizedBox(width: 8),
                          const Text(
                            'Chọn ca làm việc',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const Spacer(),
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFF2563EB),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            ),
                            icon: const Icon(Icons.add_rounded, size: 18),
                            label: const Text('Tạo ca', style: TextStyle(fontWeight: FontWeight.w700)),
                            onPressed: () {
                              Navigator.pop(sheetCtx);
                              _handleCreateNewShift();
                            },
                          ),
                        ],
                      ),
                    ),

                    // Ô tìm kiếm nhanh
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
                      child: SizedBox(
                        height: 42,
                        child: TextField(
                          controller: searchCtrl,
                          onChanged: (_) => setSheetState(() {}),
                          decoration: InputDecoration(
                            hintText: 'Tìm theo mã ca (VD: SHF-...), ngày...',
                            hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                            prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF64748B)),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Filter Chips trạng thái
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildShiftStatusFilterChip(
                              label: 'Tất cả',
                              isSelected: filterStatus == 'ALL',
                              onTap: () => setSheetState(() => filterStatus = 'ALL'),
                            ),
                            const SizedBox(width: 8),
                            _buildShiftStatusFilterChip(
                              label: 'Đang làm',
                              isSelected: filterStatus == 'IN_PROGRESS',
                              onTap: () => setSheetState(() => filterStatus = 'IN_PROGRESS'),
                              dotColor: const Color(0xFF2563EB),
                            ),
                            const SizedBox(width: 8),
                            _buildShiftStatusFilterChip(
                              label: 'Chuẩn bị',
                              isSelected: filterStatus == 'PREPARING',
                              onTap: () => setSheetState(() => filterStatus = 'PREPARING'),
                              dotColor: const Color(0xFFF59E0B),
                            ),
                            const SizedBox(width: 8),
                            _buildShiftStatusFilterChip(
                              label: 'Hoàn thành',
                              isSelected: filterStatus == 'COMPLETED',
                              onTap: () => setSheetState(() => filterStatus = 'COMPLETED'),
                              dotColor: const Color(0xFF10B981),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),
                    const Divider(height: 1, color: Color(0xFFE2E8F0)),

                    // Danh sách ca
                    Expanded(
                      child: filteredShifts.isEmpty
                          ? const Center(
                              child: Text(
                                'Không tìm thấy ca làm việc phù hợp',
                                style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
                              ),
                            )
                          : ListView.separated(
                              controller: scrollCtrl,
                              padding: const EdgeInsets.all(16),
                              itemCount: filteredShifts.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 10),
                              itemBuilder: (itemCtx, idx) {
                                final shift = filteredShifts[idx];
                                final isCurrent = _activeShift?.id == shift.id;
                                final summary = shift.summary;

                                return Container(
                                  decoration: BoxDecoration(
                                    color: isCurrent ? const Color(0xFFEFF6FF) : Colors.white,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: isCurrent ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
                                      width: isCurrent ? 1.5 : 1.0,
                                    ),
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
                                        Navigator.pop(sheetCtx);
                                        _switchShift(shift.id);
                                      },
                                      child: Padding(
                                        padding: const EdgeInsets.all(14),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    shift.shiftCode,
                                                    style: TextStyle(
                                                      fontSize: 15,
                                                      fontWeight: FontWeight.w700,
                                                      color: isCurrent ? const Color(0xFF1D4ED8) : const Color(0xFF0F172A),
                                                    ),
                                                  ),
                                                ),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                  decoration: BoxDecoration(
                                                    color: _getShiftStatusBg(shift.status),
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                  child: Text(
                                                    shift.status.displayName,
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.w600,
                                                      color: _getShiftStatusText(shift.status),
                                                    ),
                                                  ),
                                                ),
                                                if (isCurrent) ...[
                                                  const SizedBox(width: 8),
                                                  const Icon(Icons.check_circle_rounded, color: Color(0xFF2563EB), size: 18),
                                                ],
                                              ],
                                            ),
                                            const SizedBox(height: 6),
                                            Row(
                                              children: [
                                                const Icon(Icons.calendar_today_outlined, size: 13, color: Color(0xFF64748B)),
                                                const SizedBox(width: 4),
                                                Text(
                                                  shift.shiftDate,
                                                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                                ),
                                                const Text(' · ', style: TextStyle(color: Color(0xFFCBD5E1))),
                                                Text(
                                                  '${summary.totalPoints} điểm',
                                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                                                ),
                                                const Spacer(),
                                                // Dot Badges tóm tắt
                                                _buildDotBadge(count: summary.verifiedCount, color: const Color(0xFF10B981)),
                                                const SizedBox(width: 4),
                                                _buildDotBadge(count: summary.temporaryCount, color: const Color(0xFFF59E0B)),
                                                const SizedBox(width: 4),
                                                _buildDotBadge(count: summary.noLocationCount, color: const Color(0xFF64748B)),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildShiftStatusFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    Color? dotColor,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (dotColor != null) ...[
              Container(width: 6, height: 6, decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle)),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? Colors.white : const Color(0xFF475569),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDotBadge({required int count, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 5, height: 5, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 3),
          Text(
            '$count',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  Color _getShiftStatusBg(ShiftStatus status) {
    switch (status) {
      case ShiftStatus.inProgress:
        return const Color(0xFFDBEAFE);
      case ShiftStatus.completed:
        return const Color(0xFFDCFCE7);
      case ShiftStatus.cancelled:
        return const Color(0xFFFEE2E2);
      case ShiftStatus.preparing:
        return const Color(0xFFFEF3C7);
    }
  }

  Color _getShiftStatusText(ShiftStatus status) {
    switch (status) {
      case ShiftStatus.inProgress:
        return const Color(0xFF1D4ED8);
      case ShiftStatus.completed:
        return const Color(0xFF15803D);
      case ShiftStatus.cancelled:
        return const Color(0xFFB91C1C);
      case ShiftStatus.preparing:
        return const Color(0xFFD97706);
    }
  }

  /// Xử lý tạo ca làm việc mới ngay từ bản đồ
  Future<void> _handleCreateNewShift() async {
    try {
      final newShift = await ApiService.createShift();
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã tạo thành công ca làm: ${newShift.shiftCode}'),
          backgroundColor: const Color(0xFF10B981),
        ),
      );

      // Cập nhật danh sách ca và chuyển thẳng sang ca vừa tạo
      _availableShifts.insert(0, newShift);
      await _switchShift(newShift.id);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi tạo ca: $e'),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    }
  }

  /// Mở menu thêm nhanh khi bấm nút [+] trên Floating Bar
  void _openQuickActionMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2)),
              ),
              ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: const Color(0xFFDBEAFE), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.post_add_rounded, color: Color(0xFF2563EB)),
                ),
                title: const Text('Tạo ca làm việc mới', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                subtitle: const Text('Bắt đầu một ca làm việc và thêm điểm giao mới', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                onTap: () {
                  Navigator.pop(ctx);
                  _handleCreateNewShift();
                },
              ),
              const Divider(height: 1, color: Color(0xFFE2E8F0)),
              ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.contacts_rounded, color: Color(0xFF15803D)),
                ),
                title: const Text('Mở Danh bạ vị trí', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                subtitle: const Text('Chọn khách hàng từ danh bạ để thêm vào ca này', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                onTap: () {
                  Navigator.pop(ctx);
                  widget.onOpenDirectory?.call();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  /// Nút ghim nổi góc dưới bên phải - Mở danh sách chọn khách hàng thuộc ca để ghim vị trí
  void _handleFloatingCrosshairPicker() {
    if (_activeShift == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn hoặc tạo ca làm việc trước'), backgroundColor: Color(0xFFF59E0B)),
      );
      return;
    }

    if (_activeShift!.deliveryPoints.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ca làm việc này chưa có điểm giao nào. Hãy thêm khách từ Danh bạ.'), backgroundColor: Color(0xFFF59E0B)),
      );
      return;
    }

    _showPointSelectionForCrosshairSheet();
  }

  /// Bước 1: Mở Bottom Sheet nhỏ gọn chọn khách hàng thuộc ca đang chọn (có tìm kiếm nhanh)
  void _showPointSelectionForCrosshairSheet() {
    if (_activeShift == null) return;
    final allPoints = _activeShift!.deliveryPoints;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        String searchQuery = '';

        return StatefulBuilder(
          builder: (sheetCtx, setSheetState) {
            final filteredPoints = allPoints.where((p) {
              if (searchQuery.isEmpty) return true;
              final q = searchQuery.toLowerCase();
              return p.customerName.toLowerCase().contains(q) ||
                     p.customerPhone.contains(q) ||
                     p.customerAddress.toLowerCase().contains(q);
            }).toList();

            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.6,
              minChildSize: 0.35,
              maxChildSize: 0.85,
              builder: (_, scrollCtrl) {
                return Column(
                  children: [
                    Container(
                      width: 36,
                      height: 4,
                      margin: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2)),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                      child: Row(
                        children: [
                          const Icon(Icons.add_location_alt_rounded, color: Color(0xFF2563EB), size: 22),
                          const SizedBox(width: 8),
                          const Text(
                            'Chọn khách để ghim vị trí',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                          ),
                          const Spacer(),
                          Text('${filteredPoints.length}/${allPoints.length} khách', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                        ],
                      ),
                    ),

                    // Ô tìm kiếm nhanh theo SĐT hoặc Tên
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: 'Tìm theo tên hoặc số điện thoại...',
                          hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                          prefixIcon: const Icon(Icons.search_rounded, size: 20, color: Color(0xFF64748B)),
                          filled: true,
                          fillColor: const Color(0xFFF1F5F9),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          isDense: true,
                        ),
                        onChanged: (val) {
                          setSheetState(() {
                            searchQuery = val.trim();
                          });
                        },
                      ),
                    ),

                    const SizedBox(height: 8),
                    const Divider(height: 1, color: Color(0xFFE2E8F0)),

                    Expanded(
                      child: filteredPoints.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.search_off_rounded, size: 36, color: Color(0xFF94A3B8)),
                                  const SizedBox(height: 8),
                                  Text(
                                    searchQuery.isEmpty ? 'Không có điểm giao nào' : 'Không tìm thấy khách "$searchQuery"',
                                    style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                            )
                          : ListView.separated(
                              controller: scrollCtrl,
                              padding: const EdgeInsets.all(12),
                              itemCount: filteredPoints.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 8),
                              itemBuilder: (_, idx) {
                                final point = filteredPoints[idx];
                                return _buildPointPickerListItem(point, () {
                                  Navigator.pop(ctx);
                                  _startPinningMode(point);
                                });
                              },
                            ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildPointPickerListItem(ShiftDeliveryPointModel point, VoidCallback onTap) {
    Color statusBg;
    Color statusText;

    switch (point.locationStatus) {
      case LocationStatus.verified:
        statusBg = const Color(0xFFDCFCE7);
        statusText = const Color(0xFF15803D);
        break;
      case LocationStatus.temporary:
        statusBg = const Color(0xFFFEF3C7);
        statusText = const Color(0xFFD97706);
        break;
      case LocationStatus.noLocation:
        statusBg = const Color(0xFFF1F5F9);
        statusText = const Color(0xFF64748B);
        break;
    }

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(color: statusBg, shape: BoxShape.circle),
          child: Icon(
            point.locationStatus == LocationStatus.verified
                ? Icons.verified_rounded
                : (point.locationStatus == LocationStatus.temporary ? Icons.pin_drop_rounded : Icons.location_off_rounded),
            color: statusText,
            size: 18,
          ),
        ),
        title: Text(point.customerName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Color(0xFF0F172A))),
        subtitle: Text(
          '${point.customerPhone} · ${point.customerAddress}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(6)),
          child: Text(
            point.locationStatus.pickerDisplayName,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: statusText),
          ),
        ),
        onTap: onTap,
      ),
    );
  }

  /// Bước 2: Bắt đầu chế độ ghim vị trí trực tiếp trên bản đồ chính
  void _startPinningMode(ShiftDeliveryPointModel point) {
    setState(() {
      _isPinningMode = true;
      _pinningPoint = point;
      _selectedPoint = null;
      _isSummaryTrayExpanded = false;
    });

    LatLng targetCoord;
    if (point.hasValidCoordinates) {
      targetCoord = point.latLng!;
    } else if (_shipperLocation != null) {
      targetCoord = _shipperLocation!;
    } else {
      targetCoord = _isMapReady ? _mapController.camera.center : _hcmDefault;
    }

    _currentCrosshairCoord = targetCoord;
    if (_isMapReady) {
      _mapController.move(targetCoord, 17.5);
    }
  }

  /// Hủy chế độ ghim vị trí - Không lưu và trở về bản đồ bình thường
  void _cancelPinningMode() {
    setState(() {
      _isPinningMode = false;
      _pinningPoint = null;
    });
  }

  /// Bước 3: Xác nhận vị trí - Gửi API 1 lần duy nhất, cập nhật trực tiếp trên bản đồ chính
  Future<void> _confirmPinningLocation() async {
    if (_activeShift == null || _pinningPoint == null) return;

    setState(() => _isSavingPin = true);
    final pointToPin = _pinningPoint!;
    final shiftId = _activeShift!.id;
    final targetCoord = _currentCrosshairCoord;

    try {
      final updatedPoint = await ApiService.updateTemporaryLocation(
        shiftId,
        pointToPin.id,
        latitude: targetCoord.latitude,
        longitude: targetCoord.longitude,
      );

      if (!mounted) return;

      // Thoát chế độ ghim
      setState(() {
        _isPinningMode = false;
        _pinningPoint = null;
        _isSavingPin = false;
      });

      // Tải lại dữ liệu ca và giữ vị trí camera
      await _switchShift(shiftId, preserveCamera: true, preserveSelected: false);

      if (mounted) {
        // Chọn điểm vừa ghim để hiển thị chi tiết
        final refreshedPoint = _activeShift?.deliveryPoints.firstWhere(
          (p) => p.id == pointToPin.id,
          orElse: () => updatedPoint,
        );
        setState(() {
          _selectedPoint = refreshedPoint ?? updatedPoint;
        });

        if (_isMapReady) {
          _mapController.move(targetCoord, 17.5);
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Đã ghim vị trí cho ${pointToPin.customerName} (${targetCoord.latitude.toStringAsFixed(5)}, ${targetCoord.longitude.toStringAsFixed(5)})',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF10B981),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSavingPin = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi lưu vị trí: ${e.toString().replaceAll('Exception: ', '')}'),
          backgroundColor: const Color(0xFFEF4444),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  Widget _buildCrosshairReticle() {
    return IgnorePointer(
      child: Center(
        child: SizedBox(
          width: 84,
          height: 84,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Vòng tròn tâm ngắm đỏ
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFEF4444), width: 2),
                  color: const Color(0xFFEF4444).withValues(alpha: 0.08),
                ),
              ),
              // Trục chữ thập ngang và dọc
              Container(width: 72, height: 1.5, color: const Color(0xFFEF4444).withValues(alpha: 0.8)),
              Container(width: 1.5, height: 72, color: const Color(0xFFEF4444).withValues(alpha: 0.8)),
              // Chấm tâm ngắm chính xác
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFFEF4444),
                  shape: BoxShape.circle,
                ),
              ),
              // Icon ghim nổi phía trên tâm ngắm
              Transform.translate(
                offset: const Offset(0, -26),
                child: const Icon(
                  Icons.location_on,
                  size: 36,
                  color: Color(0xFFEF4444),
                  shadows: [
                    Shadow(color: Colors.black38, blurRadius: 6, offset: Offset(0, 3)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPinningHeaderCard() {
    if (_pinningPoint == null) return const SizedBox.shrink();
    final point = _pinningPoint!;

    Color badgeBg;
    Color badgeText;
    switch (point.locationStatus) {
      case LocationStatus.verified:
        badgeBg = const Color(0xFFDCFCE7);
        badgeText = const Color(0xFF15803D);
        break;
      case LocationStatus.temporary:
        badgeBg = const Color(0xFFFEF3C7);
        badgeText = const Color(0xFFD97706);
        break;
      case LocationStatus.noLocation:
        badgeBg = const Color(0xFFF1F5F9);
        badgeText = const Color(0xFF64748B);
        break;
    }

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.gps_fixed_rounded, color: Color(0xFF2563EB), size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Ghim vị trí: ${point.customerName}',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF0F172A),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: badgeBg, borderRadius: BorderRadius.circular(4)),
                              child: Text(
                                point.locationStatus.displayName,
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: badgeText),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'SĐT: ${point.customerPhone}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF2563EB)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              // Hiển thị tọa độ tâm ngắm trực tiếp
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.my_location_rounded, size: 14, color: Color(0xFFEF4444)),
                    const SizedBox(width: 6),
                    Text(
                      'Tọa độ: ${_currentCrosshairCoord.latitude.toStringAsFixed(6)}, ${_currentCrosshairCoord.longitude.toStringAsFixed(6)}',
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPinningActionBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Nút HỦY
          SizedBox(
            height: 48,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF64748B),
                side: const BorderSide(color: Color(0xFFCBD5E1)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              icon: const Icon(Icons.close_rounded, size: 18),
              label: const Text('Hủy', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              onPressed: _isSavingPin ? null : _cancelPinningMode,
            ),
          ),
          const SizedBox(width: 10),
          // Nút XÁC NHẬN VỊ TRÍ duy nhất
          Expanded(
            child: SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                icon: _isSavingPin
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.check_circle_rounded, size: 20),
                label: Text(
                  _isSavingPin ? 'ĐANG LƯU VỊ TRÍ...' : 'XÁC NHẬN VỊ TRÍ',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 0.3),
                ),
                onPressed: _isSavingPin ? null : _confirmPinningLocation,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Mở hộp thoại chụp hoặc thay đổi ảnh trực tiếp từ thẻ điểm giao
  void _openPhotoManagementSheet(ShiftDeliveryPointModel point) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2)),
              ),
              Text(
                'Thao tác vị trí & ảnh: ${point.customerName}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.edit_location_alt_rounded, color: Color(0xFFD97706)),
                ),
                title: const Text('Ghim lại vị trí bằng tâm ngắm', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: const Text('Chỉnh sửa tọa độ trực tiếp trên bản đồ chính', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                onTap: () {
                  Navigator.pop(ctx);
                  _startPinningMode(point);
                },
              ),
              ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: const Color(0xFFEDE9FE), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.edit_note_rounded, color: Color(0xFF7C3AED)),
                ),
                title: const Text('Sửa ghi chú nhận diện vị trí', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: const Text('Cập nhật màu cửa, cổng nhà, số hẻm...', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                onTap: () {
                  Navigator.pop(ctx);
                  _editNotesForPoint(point);
                },
              ),
              const Divider(height: 1, color: Color(0xFFE2E8F0)),
              ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: const Color(0xFFDBEAFE), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.camera_alt_rounded, color: Color(0xFF2563EB)),
                ),
                title: const Text('Chụp ảnh mới bằng Camera', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                onTap: () {
                  Navigator.pop(ctx);
                  _captureAndUploadPhoto(point, ImageSource.camera);
                },
              ),
              ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.photo_library_rounded, color: Color(0xFF475569)),
                ),
                title: const Text('Chọn ảnh từ Thư viện', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                onTap: () {
                  Navigator.pop(ctx);
                  _captureAndUploadPhoto(point, ImageSource.gallery);
                },
              ),
              if (point.photoUrl != null && point.photoUrl!.isNotEmpty) ...[
                const Divider(height: 1, color: Color(0xFFE2E8F0)),
                ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(color: const Color(0xFFFEE2E2), borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.delete_outline_rounded, color: Color(0xFFDC2626)),
                  ),
                  title: const Text('Xóa ảnh vị trí hiện tại', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Color(0xFFDC2626))),
                  onTap: () {
                    Navigator.pop(ctx);
                    _deletePhotoForPoint(point);
                  },
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Future<void> _editNotesForPoint(ShiftDeliveryPointModel point) async {
    final controller = TextEditingController(text: point.locationNotes ?? '');
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Ghi chú nhận diện vị trí', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Khách: ${point.customerName} - ${point.customerPhone}', style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Nhập ghi chú (màu cửa, cổng nhà, số hẻm...)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('HỦY', style: TextStyle(color: Color(0xFF64748B)))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('LƯU GHI CHÚ'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final targetLat = point.latitude ?? _shipperLocation?.latitude ?? _hcmDefault.latitude;
      final targetLng = point.longitude ?? _shipperLocation?.longitude ?? _hcmDefault.longitude;
      final newNotes = controller.text.trim();

      await ApiService.updateCustomerLocationAndPhoto(
        customerId: point.customerId,
        latitude: targetLat,
        longitude: targetLng,
        identificationNotes: newNotes.isNotEmpty ? newNotes : 'Vị trí đã lưu',
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã cập nhật ghi chú thành công!'), backgroundColor: Color(0xFF10B981)),
      );

      await _switchShift(_activeShift!.id, preserveCamera: true, preserveSelected: true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi cập nhật ghi chú: $e'), backgroundColor: const Color(0xFFEF4444)),
      );
    }
  }

  Future<void> _captureAndUploadPhoto(ShiftDeliveryPointModel point, ImageSource source) async {
    try {
      final picked = await _imagePicker.pickImage(source: source, maxWidth: 1600, maxHeight: 1600, imageQuality: 85);
      if (picked == null) return;

      // Đọc byte trực tiếp từ XFile - hỗ trợ hoàn hảo cả Flutter Web (Chrome) và Android
      final bytes = await picked.readAsBytes();
      if (bytes.lengthInBytes > 5 * 1024 * 1024) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ảnh quá lớn (vượt quá 5MB). Vui lòng chọn ảnh khác.'), backgroundColor: Color(0xFFEF4444)),
        );
        return;
      }

      // Hiển thị bản xem trước ảnh trước khi lưu chính thức (BUG-04)
      if (!mounted) return;
      final confirmSave = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Xem trước ảnh vị trí', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.memory(
                  bytes,
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 10),
              Text(point.customerName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF0F172A))),
              const SizedBox(height: 2),
              Text(point.customerAddress, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)), maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('HỦY', style: TextStyle(color: Color(0xFF64748B))),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white),
              icon: const Icon(Icons.cloud_upload_rounded, size: 16),
              label: const Text('LƯU ẢNH'),
              onPressed: () => Navigator.pop(ctx, true),
            ),
          ],
        ),
      );

      if (confirmSave != true) return;

      final base64Image = 'data:image/jpeg;base64,${base64Encode(bytes)}';

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đang tải ảnh lên máy chủ...'), duration: Duration(seconds: 2)),
      );

      final targetLat = point.latitude ?? _shipperLocation?.latitude ?? _hcmDefault.latitude;
      final targetLng = point.longitude ?? _shipperLocation?.longitude ?? _hcmDefault.longitude;
      final safeNotes = (point.locationNotes != null && point.locationNotes!.trim().isNotEmpty)
          ? point.locationNotes!.trim()
          : 'Vị trí đã lưu';

      // Cập nhật vị trí và ảnh lên backend
      final updateRes = await ApiService.updateCustomerLocationAndPhoto(
        customerId: point.customerId,
        latitude: targetLat,
        longitude: targetLng,
        identificationNotes: safeNotes,
        imageBase64: base64Image,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã cập nhật ảnh thành công!'), backgroundColor: Color(0xFF10B981)),
      );

      // Xóa triệt để cache ảnh của Flutter
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();

      final newPhotoUrl = updateRes['data']?['imageUrl'] as String?;
      setState(() {
        _photoCacheVersion = DateTime.now().millisecondsSinceEpoch;
        if (_selectedPoint != null && _selectedPoint!.id == point.id) {
          _selectedPoint = _selectedPoint!.copyWith(
            photoUrl: newPhotoUrl ?? _selectedPoint!.photoUrl,
            locationStatus: LocationStatus.verified,
          );
        }
      });
      await _switchShift(_activeShift!.id, preserveCamera: true, preserveSelected: true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi tải ảnh: $e'), backgroundColor: const Color(0xFFEF4444)),
      );
    }
  }

  Future<void> _deletePhotoForPoint(ShiftDeliveryPointModel point) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Xác nhận xóa ảnh', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
        content: const Text('Bác tài có chắc muốn xóa ảnh cổng nhà/vị trí của khách hàng này?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('HỦY', style: TextStyle(color: Color(0xFF64748B)))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444), foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('XÓA'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final targetLat = point.latitude ?? _shipperLocation?.latitude ?? _hcmDefault.latitude;
      final targetLng = point.longitude ?? _shipperLocation?.longitude ?? _hcmDefault.longitude;
      final safeNotes = (point.locationNotes != null && point.locationNotes!.trim().isNotEmpty)
          ? point.locationNotes!.trim()
          : 'Vị trí đã lưu';

      await ApiService.updateCustomerLocationAndPhoto(
        customerId: point.customerId,
        latitude: targetLat,
        longitude: targetLng,
        identificationNotes: safeNotes,
        deletePhoto: true,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã xóa ảnh vị trí thành công!'), backgroundColor: Color(0xFF10B981)),
      );

      // Xóa triệt để cache ảnh của Flutter
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();

      setState(() {
        _photoCacheVersion = DateTime.now().millisecondsSinceEpoch;
        if (_selectedPoint != null && _selectedPoint!.id == point.id) {
          _selectedPoint = _selectedPoint!.copyWith(
            photoUrl: '', // Xóa ảnh trên state tức thì
          );
        }
      });
      await _switchShift(_activeShift!.id, preserveCamera: true, preserveSelected: true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi xóa ảnh: $e'), backgroundColor: const Color(0xFFEF4444)),
      );
    }
  }

  Future<void> _makePhoneCall(String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
    final uri = Uri.parse('tel:$cleanPhone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể gọi số $phone')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final validPoints = _activeShift?.deliveryPoints.where((p) => p.hasValidCoordinates).toList() ?? [];
    final noLocationPoints = _activeShift?.deliveryPoints.where((p) => !p.hasValidCoordinates).toList() ?? [];

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. BẢN ĐỒ TOÀN MÀN HÌNH (FULL-BLEED)
          Positioned.fill(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: validPoints.isNotEmpty
                    ? validPoints.first.latLng!
                    : (_shipperLocation ?? _hcmDefault),
                initialZoom: 15.0,
                maxZoom: 19.0,
                minZoom: 10.0,
                onMapReady: () {
                  _isMapReady = true;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted && !_isPinningMode) _fitMapBounds();
                  });
                },
                onTap: (_, __) {
                  if (!_isPinningMode) {
                    setState(() => _selectedPoint = null);
                  }
                },
                onPositionChanged: (camera, hasGesture) {
                  if (_isPinningMode && camera.center != null) {
                    setState(() {
                      _currentCrosshairCoord = camera.center!;
                    });
                  }
                },
              ),
              children: [
                TileLayer(
                  key: ValueKey('main_tile_layer_$_currentMapType'),
                  urlTemplate: _getUrlTemplate(),
                  fallbackUrl: 'https://a.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
                  subdomains: _getSubdomains(),
                  userAgentPackageName: 'com.example.delivery_marker_mobile',
                  errorTileCallback: (tile, error, stackTrace) {
                    if (!_hasTileError && mounted) {
                      setState(() => _hasTileError = true);
                    }
                  },
                ),

                // LỚP MARKER
                MarkerLayer(
                  markers: [
                    // Marker GPS Shipper (Chấm xanh dương nổi bật)
                    if (_shipperLocation != null)
                      Marker(
                        point: _shipperLocation!,
                        width: 48,
                        height: 48,
                        child: Center(
                          child: Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              color: const Color(0xFF2563EB),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3),
                              boxShadow: const [
                                BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2)),
                              ],
                            ),
                          ),
                        ),
                      ),

                    // Markers các điểm giao có tọa độ hợp lệ
                    ...validPoints.map((point) {
                      final isSelected = _selectedPoint?.id == point.id;
                      final isVerified = point.locationStatus == LocationStatus.verified;
                      final markerColor = isVerified ? const Color(0xFF10B981) : const Color(0xFFF59E0B);

                      return Marker(
                        point: point.latLng!,
                        width: isSelected ? 48 : 40,
                        height: isSelected ? 48 : 40,
                        child: GestureDetector(
                          onTap: () {
                            if (_isPinningMode) return;
                            setState(() => _selectedPoint = point);
                            _mapController.move(point.latLng!, 17.0);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            decoration: BoxDecoration(
                              color: markerColor,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white,
                                width: isSelected ? 3 : 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: isSelected ? markerColor.withValues(alpha: 0.5) : Colors.black26,
                                  blurRadius: isSelected ? 8 : 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Icon(
                                isVerified ? Icons.check_circle_rounded : Icons.pin_drop_rounded,
                                color: Colors.white,
                                size: isSelected ? 24 : 20,
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ],
            ),
          ),

          // 2. CHẾ ĐỘ GHIM: TÂM NGẮM CỐ ĐỊNH CHÍNH GIỮA MÀN HÌNH
          if (_isPinningMode) _buildCrosshairReticle(),

          // 3. THANH NỔI PHÍA TRÊN: HOẶC THANH CHỌN CA, HOẶC THANH THÔNG TIN ĐANG GHIM
          if (!_isPinningMode)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
                  child: Row(
                    children: [
                      // Thanh chọn ca bấm được
                      Expanded(
                        child: Container(
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.96),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.06),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: _openShiftPickerSheet,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 14),
                                child: Row(
                                  children: [
                                    // Chấm tròn trạng thái ca
                                    Container(
                                      width: 10,
                                      height: 10,
                                      decoration: BoxDecoration(
                                        color: _activeShift != null
                                            ? (_activeShift!.status == ShiftStatus.inProgress
                                                ? const Color(0xFF2563EB)
                                                : (_activeShift!.status == ShiftStatus.completed
                                                    ? const Color(0xFF10B981)
                                                    : const Color(0xFFF59E0B)))
                                            : const Color(0xFF94A3B8),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 8),

                                    Expanded(
                                      child: _activeShift != null
                                          ? Column(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  _activeShift!.shiftCode,
                                                  style: const TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w700,
                                                    color: Color(0xFF0F172A),
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                Text(
                                                  '${validPoints.length} đã ghim · ${noLocationPoints.length} chưa vị trí',
                                                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                                ),
                                              ],
                                            )
                                          : const Text(
                                              'Chưa chọn ca làm việc',
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color: Color(0xFF64748B),
                                              ),
                                            ),
                                    ),

                                    if (_isLoadingPoints)
                                      const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF2563EB)),
                                      )
                                    else
                                      const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF64748B), size: 22),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(width: 8),

                      // Nút [+] Thao tác nhanh
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: _openQuickActionMenu,
                            child: const Center(
                              child: Icon(Icons.add_rounded, color: Colors.white, size: 26),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            // Khi đang ở chế độ ghim: Thẻ thông tin khách hàng đang ghim
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _buildPinningHeaderCard(),
            ),

          // CẢNH BÁO TILE LỖI NẾU CÓ
          if (_hasTileError)
            Positioned(
              top: _isPinningMode ? 106 : 76,
              left: 14,
              right: 14,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
                ),
                child: const Row(
                  children: [
                    Icon(Icons.wifi_off_rounded, color: Colors.white, size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Không tải được tile trực tuyến. Dữ liệu ghim và tọa độ vẫn an toàn.',
                        style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // 4. CÁC NÚT ĐIỀU KHIỂN BẢN ĐỒ GÓC PHẢI (44x44)
          Positioned(
            right: 14,
            top: _isPinningMode ? 106 : 76,
            child: Column(
              children: [
                _buildMapToolButton(
                  icon: Icons.my_location_rounded,
                  tooltip: 'Vị trí của tôi',
                  isLoading: _isLocatingShipper,
                  iconColor: const Color(0xFF2563EB),
                  onTap: () {
                    if (_shipperLocation != null) {
                      _mapController.move(_shipperLocation!, 17.5);
                      if (_isPinningMode) {
                        setState(() {
                          _currentCrosshairCoord = _shipperLocation!;
                        });
                      }
                    } else {
                      _getShipperLocation();
                    }
                  },
                ),
                const SizedBox(height: 8),
                _buildMapToolButton(
                  icon: Icons.layers_outlined,
                  tooltip: 'Đổi kiểu bản đồ',
                  iconColor: const Color(0xFF0F172A),
                  onTap: _switchMapType,
                ),
                if (!_isPinningMode) ...[
                  const SizedBox(height: 8),
                  _buildMapToolButton(
                    icon: Icons.crop_free_rounded,
                    tooltip: 'Xem toàn bộ điểm',
                    iconColor: const Color(0xFF0F172A),
                    onTap: _fitMapBounds,
                  ),
                ],
              ],
            ),
          ),

          // 5. THẺ THÔNG TIN ĐIỂM GIAO KHI CHẠM MARKER (CHỈ HIỂN THỊ KHI KHÔNG GHIM)
          if (!_isPinningMode && _selectedPoint != null)
            Positioned(
              left: 14,
              right: 14,
              bottom: 84,
              child: _buildSelectedPointDetailCard(_selectedPoint!),
            ),

          // 6. THẺ THÔNG BÁO KHI CHƯA CÓ CA LÀM VIỆC NÀO
          if (!_isPinningMode && _activeShift == null && !_isLoadingShifts)
            Positioned(
              left: 20,
              right: 20,
              bottom: 84,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4))],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.map_outlined, color: Color(0xFF64748B), size: 36),
                    const SizedBox(height: 8),
                    Text(
                      _errorMessage != null ? 'Lỗi tải ca làm việc' : 'Chưa chọn ca làm việc nào',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _errorMessage ?? 'Bác tài hãy chọn một ca có sẵn hoặc tạo ca mới để bắt đầu giao hàng.',
                      style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF2563EB),
                              side: const BorderSide(color: Color(0xFFBFDBFE)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: _openShiftPickerSheet,
                            child: const Text('Chọn ca', style: TextStyle(fontWeight: FontWeight.w600)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0F172A),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: _handleCreateNewShift,
                            child: const Text('Tạo ca mới', style: TextStyle(fontWeight: FontWeight.w600)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

          // 7. KHAY KÉO TÓM TẮT ĐIỂM GIAO DƯỚI ĐÁY (COLLAPSIBLE TRAY KHI KHÔNG CHỌN MARKER VÀ KHÔNG GHIM)
          if (!_isPinningMode && _selectedPoint == null && _activeShift != null)
            Positioned(
              left: 14,
              bottom: 20,
              child: InkWell(
                borderRadius: BorderRadius.circular(24),
                onTap: () {
                  setState(() => _isSummaryTrayExpanded = !_isSummaryTrayExpanded);
                  _showShiftSummaryListSheet();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.96),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 6, offset: const Offset(0, 2)),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.list_alt_rounded, size: 18, color: Color(0xFF2563EB)),
                      const SizedBox(width: 8),
                      Text(
                        '${_activeShift!.deliveryPoints.length} điểm',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                      ),
                      const Text(' · ', style: TextStyle(color: Color(0xFFCBD5E1))),
                      _buildDotBadge(count: validPoints.length, color: const Color(0xFF10B981)),
                      if (noLocationPoints.isNotEmpty) ...[
                        const SizedBox(width: 4),
                        _buildDotBadge(count: noLocationPoints.length, color: const Color(0xFFF59E0B)),
                      ],
                      const SizedBox(width: 4),
                      const Icon(Icons.expand_less_rounded, size: 18, color: Color(0xFF64748B)),
                    ],
                  ),
                ),
              ),
            ),

          // 8. NÚT HÀNH ĐỘNG "CHỌN VỊ TRÍ" GÓC DƯỚI BÊN PHẢI (KHI KHÔNG GHIM)
          if (!_isPinningMode)
            Positioned(
              right: 14,
              bottom: 18,
              child: SizedBox(
                height: 50,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A),
                    foregroundColor: Colors.white,
                    elevation: 4,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                  ),
                  icon: const Icon(Icons.add_location_alt_rounded, size: 20),
                  label: const Text(
                    'CHỌN VỊ TRÍ',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 0.3),
                  ),
                  onPressed: _handleFloatingCrosshairPicker,
                ),
              ),
            ),

          // 9. CHẾ ĐỘ GHIM: THANH THAO TÁC XÁC NHẬN / HỦY Ở CUỐI MÀN HÌNH
          if (_isPinningMode)
            Positioned(
              left: 14,
              right: 14,
              bottom: 18,
              child: _buildPinningActionBar(),
            ),
        ],
      ),
    );
  }

  Widget _buildMapToolButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    Color iconColor = const Color(0xFF0F172A),
    bool isLoading = false,
  }) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Center(
            child: isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF2563EB)),
                  )
                : Icon(icon, color: iconColor, size: 22),
          ),
        ),
      ),
    );
  }

  /// Mở Bottom Sheet danh sách tóm tắt toàn bộ điểm giao trong ca
  void _showShiftSummaryListSheet() {
    if (_activeShift == null) return;
    final points = _activeShift!.deliveryPoints;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetCtx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          minChildSize: 0.35,
          maxChildSize: 0.88,
          builder: (_, scrollCtrl) {
            return Column(
              children: [
                // Drag handle
                Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2)),
                ),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.local_shipping_rounded, color: Color(0xFF2563EB), size: 22),
                      const SizedBox(width: 8),
                      Text(
                        'Điểm giao ca ${_activeShift!.shiftCode}',
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                      ),
                      const Spacer(),
                      Text('${points.length} khách', style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                    ],
                  ),
                ),

                const Divider(height: 14, color: Color(0xFFE2E8F0)),

                Expanded(
                  child: ListView.separated(
                    controller: scrollCtrl,
                    padding: const EdgeInsets.all(16),
                    itemCount: points.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, idx) {
                      final point = points[idx];
                      return _buildSummaryPointItem(point, sheetCtx);
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildSummaryPointItem(ShiftDeliveryPointModel point, BuildContext sheetCtx) {
    Color badgeBg;
    Color badgeText;
    switch (point.locationStatus) {
      case LocationStatus.verified:
        badgeBg = const Color(0xFFDCFCE7);
        badgeText = const Color(0xFF15803D);
        break;
      case LocationStatus.temporary:
        badgeBg = const Color(0xFFFEF3C7);
        badgeText = const Color(0xFFD97706);
        break;
      case LocationStatus.noLocation:
        badgeBg = const Color(0xFFF1F5F9);
        badgeText = const Color(0xFF64748B);
        break;
    }

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            Navigator.pop(sheetCtx);
            setState(() => _selectedPoint = point);
            if (point.hasValidCoordinates) {
              _mapController.move(point.latLng!, 17.5);
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        point.customerName,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: badgeBg, borderRadius: BorderRadius.circular(6)),
                      child: Text(
                        point.locationStatus.displayName,
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: badgeText),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text('${point.customerPhone} · ${point.customerAddress}', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),

                if (point.locationNotes != null && point.locationNotes!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text('Ghi chú: ${point.locationNotes}', style: const TextStyle(fontSize: 11, color: Color(0xFF334155), fontStyle: FontStyle.italic)),
                ],

                // Nếu chưa có vị trí -> Nút "Định vị ngay"
                if (!point.hasValidCoordinates) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: 36,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F172A),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.add_location_alt_rounded, size: 16),
                      label: const Text('Định vị ngay', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                      onPressed: () {
                        Navigator.pop(sheetCtx);
                        _startPinningMode(point);
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Thẻ chi tiết khi chạm marker: Có ẢNH THỰC TẾ NỔI BẬT (170px, tap phóng to),
  /// placeholder khi chưa có ảnh + nút Chụp ngay, thông tin, ghi chú nổi bật, nút Gọi/Đường đi/Sửa.
  Widget _buildSelectedPointDetailCard(ShiftDeliveryPointModel point) {
    Color badgeBg;
    Color badgeText;
    IconData badgeIcon;

    switch (point.locationStatus) {
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

    final hasPhoto = point.photoUrl != null && point.photoUrl!.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. KHU VỰC ẢNH VỊ TRÍ NỔI BẬT (CHIỀU CAO 170PX)
          if (hasPhoto)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
              child: SizedBox(
                height: 170,
                width: double.infinity,
                child: FutureBuilder<Map<String, String>>(
                  key: ValueKey('main_photo_${point.id}_${point.photoUrl}_$_photoCacheVersion'),
                  future: ApiService.getPhotoAuthInfo(
                    point.photoUrl!,
                    bustCache: true,
                    cacheVersion: _photoCacheVersion,
                  ),
                  builder: (ctx, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Container(
                        color: const Color(0xFFF1F5F9),
                        child: const Center(
                          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF2563EB)),
                        ),
                      );
                    }

                    if (snapshot.hasError || !snapshot.hasData) {
                      return _buildPhotoPlaceholder(point);
                    }

                    final authInfo = snapshot.data!;
                    final photoUrlWithAuth = authInfo['url'] ?? '';
                    final token = authInfo['token'];

                    return GestureDetector(
                      onTap: () {
                        FullscreenImageViewer.show(
                          context,
                          photoUrl: point.photoUrl!,
                          title: point.customerName,
                          cacheVersion: _photoCacheVersion,
                        );
                      },
                      child: Image.network(
                        photoUrlWithAuth,
                        key: ValueKey('main_img_${point.id}_$photoUrlWithAuth'),
                        headers: {
                          if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
                        },
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _buildPhotoPlaceholder(point),
                        loadingBuilder: (ctx, child, progress) {
                          if (progress == null) {
                            return Stack(
                              fit: StackFit.expand,
                              children: [
                                child,
                                Positioned(
                                  right: 10,
                                  bottom: 10,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.6),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.zoom_in_rounded, color: Colors.white, size: 14),
                                        SizedBox(width: 4),
                                        Text('Chạm để phóng to', style: TextStyle(color: Colors.white, fontSize: 11)),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }
                          return Container(
                            color: const Color(0xFFF1F5F9),
                            child: Center(
                              child: CircularProgressIndicator(
                                value: progress.expectedTotalBytes != null
                                    ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes!
                                    : null,
                                strokeWidth: 2,
                                color: const Color(0xFF2563EB),
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
            )
          else
            _buildPhotoPlaceholder(point),

          // 2. THÔNG TIN KHÁCH HÀNG & GHI CHÚ
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Tên, SĐT & Nút đóng
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            point.customerName,
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
                                point.customerPhone,
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
                            point.locationStatus.displayName,
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: badgeText),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    InkWell(
                      onTap: () => setState(() => _selectedPoint = null),
                      borderRadius: BorderRadius.circular(20),
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(Icons.close_rounded, size: 18, color: Color(0xFF94A3B8)),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),
                Text(
                  point.customerAddress,
                  style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),

                if (point.hasValidCoordinates) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Tọa độ: ${point.latitude!.toStringAsFixed(6)}, ${point.longitude!.toStringAsFixed(6)}',
                    style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: Color(0xFF64748B)),
                  ),
                ],

                // Khung ghi chú nhận diện nổi bật (cổng nhà, màu cửa...)
                if (point.locationNotes != null && point.locationNotes!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.note_alt_outlined, size: 16, color: Color(0xFF2563EB)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            point.locationNotes!,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                            maxLines: 2,
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

                // Hàng nút thao tác nhanh: [Gọi], [Đường đi], [Sửa vị trí / Ảnh]
                Row(
                  children: [
                    // Nút Gọi
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF2563EB),
                        side: const BorderSide(color: Color(0xFFBFDBFE)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                      icon: const Icon(Icons.phone_rounded, size: 15),
                      label: const Text('Gọi', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      onPressed: () => _makePhoneCall(point.customerPhone),
                    ),
                    const SizedBox(width: 8),

                    // Nút Chỉ đường
                    if (point.hasValidCoordinates) ...[
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF15803D),
                          side: const BorderSide(color: Color(0xFFBBF7D0)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        ),
                        icon: const Icon(Icons.directions_rounded, size: 15),
                        label: const Text('Đường đi', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        onPressed: () => ApiService.openExternalNavigation(point.latitude!, point.longitude!),
                      ),
                      const SizedBox(width: 8),
                    ],

                    // Nút Sửa vị trí / Ảnh
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F172A),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        ),
                        icon: const Icon(Icons.edit_location_alt_rounded, size: 16),
                        label: const Text(
                          'Sửa vị trí / Ảnh',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                        onPressed: () => _openPhotoManagementSheet(point),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Placeholder khi điểm giao chưa có ảnh
  Widget _buildPhotoPlaceholder(ShiftDeliveryPointModel point) {
    return Container(
      height: 90,
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.photo_camera_outlined, size: 20, color: Color(0xFF94A3B8)),
            const SizedBox(width: 8),
            const Text('Chưa có ảnh vị trí', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
            const SizedBox(width: 12),
            TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF2563EB),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              ),
              icon: const Icon(Icons.add_a_photo_outlined, size: 16),
              label: const Text('Chụp ngay', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              onPressed: () => _openPhotoManagementSheet(point),
            ),
          ],
        ),
      ),
    );
  }
}
