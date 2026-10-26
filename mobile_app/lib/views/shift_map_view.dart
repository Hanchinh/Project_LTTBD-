import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/shift_model.dart';
import '../services/api_service.dart';
import 'crosshair_location_picker_view.dart';
import '../widgets/point_detail_bottom_sheet.dart';
import '../widgets/bulk_paste_phone_sheet.dart';
import '../services/map_tile_cache_service.dart';

class ShiftMapView extends StatefulWidget {
  final String shiftId;

  const ShiftMapView({
    super.key,
    required this.shiftId,
  });

  @override
  State<ShiftMapView> createState() => _ShiftMapViewState();
}

class _ShiftMapViewState extends State<ShiftMapView> {
  final MapController _mapController = MapController();
  final TileProvider _tileProvider = createPlatformTileProvider();
  ShiftModel? _shift;
  bool _isLoading = true;
  String? _errorMessage;

  // Vị trí GPS của shipper
  LatLng? _shipperLocation;
  bool _isLocatingShipper = false;

  // Điểm giao hiện đang được chọn để xem chi tiết
  ShiftDeliveryPointModel? _selectedPoint;
  bool _isMapReady = false;

  // Loại bản đồ nền (0: Google Đường phố, 1: Google Hybrid Vệ tinh, 2: CartoDB Voyager)
  int _currentMapType = 0;
  bool _hasTileError = false;

  String _getUrlTemplate() {
    switch (_currentMapType) {
      case 1:
        // Google Hybrid (Vệ tinh có tên đường)
        return 'https://mt1.google.com/vt/lyrs=y&x={x}&y={y}&z={z}';
      case 2:
        // CartoDB Voyager
        return 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png';
      case 0:
      default:
        // Google Maps Đường phố chuẩn (tiếng Việt, ổn định cao)
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

  // Tọa độ mặc định (TP.HCM)
  static const LatLng _hcmDefault = LatLng(10.776889, 106.700806);

  @override
  void initState() {
    super.initState();
    _loadShiftData();
    _getShipperLocation();
  }

  Future<void> _loadShiftData({bool preserveSelected = true}) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final shift = await ApiService.getShiftDetail(widget.shiftId);
      if (!mounted) return;

      setState(() {
        _shift = shift;
        _isLoading = false;

        // Cập nhật lại điểm đang chọn nếu có
        if (preserveSelected && _selectedPoint != null) {
          final matched = shift.deliveryPoints.where((p) => p.id == _selectedPoint!.id).toList();
          if (matched.isNotEmpty) {
            _selectedPoint = matched.first;
          }
        }
      });

      // Fit bounds bản đồ nếu map đã sẵn sàng
      if (_isMapReady) {
        _fitMapBounds();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  /// Mở bottom sheet dán danh sách số điện thoại hàng loạt (TASK: SHIFT-FROM-MAP-AND-BULK-PASTE-015B)
  void _showBulkPasteBottomSheet() {
    BulkPastePhoneSheet.show(
      context: context,
      shiftId: widget.shiftId,
      onPointsAdded: (result) {
        _loadShiftData(preserveSelected: false).then((_) {
          if (mounted) {
            _fitMapBounds();
          }
        });
      },
      onPinPointRequested: (point) {
        _openCrosshairPickerForPoint(point);
      },
    );
  }

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
      // Bỏ qua lỗi định vị GPS
    } finally {
      if (mounted) setState(() => _isLocatingShipper = false);
    }
  }

  void _fitMapBounds() {
    if (!_isMapReady || _shift == null) return;
    final validPoints = _shift!.deliveryPoints.where((p) => p.hasValidCoordinates).toList();
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
        padding: const EdgeInsets.fromLTRB(40, 90, 40, 220),
      ),
    );
  }

  /// Xử lý bấm Nút Ghim nổi ở góc dưới bên phải
  void _handleFloatingCrosshairPicker() {
    if (_shift == null) return;

    if (_selectedPoint != null) {
      // Đã chọn điểm: mở ngay bộ chọn cho điểm đó
      _openCrosshairPickerForPoint(_selectedPoint!);
    } else {
      // Chưa chọn điểm: mở danh sách chọn điểm giao cần gán/cập nhật vị trí
      _showPointSelectionBottomSheet();
    }
  }

  void _showPointSelectionBottomSheet() {
    if (_shift == null) return;
    final points = _shift!.deliveryPoints;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.55,
          minChildSize: 0.35,
          maxChildSize: 0.85,
          builder: (sheetCtx, scrollController) {
            return Column(
              children: [
                // Drag handle hiện đại
                Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                  child: Row(
                    children: [
                      const Icon(Icons.add_location_alt_rounded, color: Color(0xFF2563EB), size: 22),
                      const SizedBox(width: 8),
                      const Text(
                        'Chọn điểm giao để gán vị trí',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                      ),
                      const Spacer(),
                      Text(
                        '${points.length} điểm',
                        style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: Color(0xFFE2E8F0)),
                Expanded(
                  child: ListView.separated(
                    controller: scrollController,
                    padding: const EdgeInsets.all(12),
                    itemCount: points.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (itemCtx, idx) {
                      final point = points[idx];
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
                            decoration: BoxDecoration(
                              color: statusBg,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              point.locationStatus == LocationStatus.verified
                                  ? Icons.verified_rounded
                                  : (point.locationStatus == LocationStatus.temporary
                                      ? Icons.pin_drop_rounded
                                      : Icons.location_off_rounded),
                              color: statusText,
                              size: 18,
                            ),
                          ),
                          title: Text(
                            point.customerName,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Color(0xFF0F172A)),
                          ),
                          subtitle: Text(
                            '${point.customerPhone} · ${point.customerAddress}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: statusBg,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              point.locationStatus.displayName,
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: statusText),
                            ),
                          ),
                          onTap: () {
                            Navigator.pop(ctx);
                            _openCrosshairPickerForPoint(point);
                          },
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
  }

  void _openCrosshairPickerForPoint(ShiftDeliveryPointModel point) async {
    final result = await Navigator.push<CrosshairLocationPickerResult>(
      context,
      MaterialPageRoute(
        builder: (context) => CrosshairLocationPickerView(
          point: point,
          shiftId: widget.shiftId,
          myLocation: _shipperLocation,
        ),
      ),
    );

    if (result != null) {
      await _loadShiftData(preserveSelected: true);
      // Di chuyển bản đồ đến điểm vừa ghim nếu map sẵn sàng
      if (_isMapReady) {
        _mapController.move(LatLng(result.latitude, result.longitude), 17.5);
      }
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
    if (_isLoading && _shift == null) {
      return const Scaffold(
        backgroundColor: Color(0xFFF8FAFC),
        body: Center(child: CircularProgressIndicator(color: Color(0xFF2563EB))),
      );
    }

    if (_errorMessage != null && _shift == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, size: 48, color: Color(0xFFEF4444)),
              const SizedBox(height: 12),
              Text('Lỗi: $_errorMessage', style: const TextStyle(fontSize: 14, color: Color(0xFF334155))),
              const SizedBox(height: 16),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  foregroundColor: Colors.white,
                ),
                onPressed: _loadShiftData,
                child: const Text('Thử lại'),
              ),
            ],
          ),
        ),
      );
    }

    final shift = _shift!;
    final validPoints = shift.deliveryPoints.where((p) => p.hasValidCoordinates).toList();
    final noLocationPoints = shift.deliveryPoints.where((p) => !p.hasValidCoordinates).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: PopScope(
        canPop: _selectedPoint == null,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          if (_selectedPoint != null) {
            setState(() => _selectedPoint = null);
          }
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
          // 1. BẢN ĐỒ TOÀN MÀN HÌNH (Google Maps & CartoDB tiles, CÔ LẬP REPAINT BOUNDARY)
          Positioned.fill(
            child: RepaintBoundary(
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
                    if (mounted) {
                      _fitMapBounds();
                    }
                  });
                },
                onTap: (_, __) {
                  // Chạm vào nền bản đồ để đóng thẻ chi tiết
                  setState(() => _selectedPoint = null);
                },
              ),
              children: [
                TileLayer(
                  key: ValueKey('shift_tile_layer_$_currentMapType'),
                  urlTemplate: _getUrlTemplate(),
                  fallbackUrl: 'https://a.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
                  subdomains: _getSubdomains(),
                  userAgentPackageName: 'com.example.delivery_marker_mobile',
                  panBuffer: 1,
                  keepBuffer: 2,
                  tileProvider: _tileProvider,
                  errorTileCallback: (tile, error, stackTrace) {
                    if (!_hasTileError && mounted) {
                      setState(() => _hasTileError = true);
                    }
                  },
                ),

                // MARKER LAYER
                MarkerLayer(
                  markers: [
                    // Marker GPS Shipper (Chấm xanh dương hiện đại)
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
                                BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
                              ],
                            ),
                          ),
                        ),
                      ),

                    // Markers các điểm giao trong ca (CHỈ TẠO KHI CÓ TỌA ĐỘ HỢP LỆ)
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
        ),

          // 2. HEADER NỔI HIỆN ĐẠI (FLOATING TOP BAR, CÔ LẬP REPAINT BOUNDARY)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: RepaintBoundary(
              child: SafeArea(
                bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.96),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A), size: 22),
                        tooltip: 'Quay lại',
                        onPressed: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              shift.displayTitle,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0F172A),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Row(
                              children: [
                                Text(
                                  '${validPoints.length} đã ghim',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF10B981)),
                                ),
                                if (noLocationPoints.isNotEmpty) ...[
                                  const Text(' · ', style: TextStyle(color: Color(0xFFCBD5E1))),
                                  Text(
                                    '${noLocationPoints.length} chưa có vị trí',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFFF59E0B)),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh_rounded, color: Color(0xFF475569), size: 22),
                        tooltip: 'Tải lại',
                        onPressed: () => _loadShiftData(preserveSelected: true),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),

          // BANNER CẢNH BÁO KHI TILE MẠNG GẶP SỰ CỐ
          if (_hasTileError)
            Positioned(
              top: 76,
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

          // 3. CÁC NÚT ĐIỀU KHIỂN BẢN ĐỒ CHUẨN HÓA 44x44 (GÓC PHẢI TRÊN)
          Positioned(
            right: 14,
            top: 76,
            child: Column(
              children: [
                _buildMapToolButton(
                  icon: Icons.my_location_rounded,
                  tooltip: 'Vị trí của tôi',
                  isLoading: _isLocatingShipper,
                  iconColor: const Color(0xFF2563EB),
                  onTap: () {
                    if (_shipperLocation != null) {
                      _mapController.move(_shipperLocation!, 16.5);
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
                const SizedBox(height: 8),
                _buildMapToolButton(
                  icon: Icons.crop_free_rounded,
                  tooltip: 'Xem toàn bộ điểm',
                  iconColor: const Color(0xFF0F172A),
                  onTap: _fitMapBounds,
                ),
              ],
            ),
          ),

          // 4. THẺ THÔNG TIN ĐIỂM GIAO KHI CHẠM MARKER - BOTTOM SHEET BÁM ĐÁY MÀN HÌNH (TASK: MULTI-PHOTO-AND-THUMB-UI-015A)
          if (_selectedPoint != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _buildSelectedPointCard(_selectedPoint!),
            ),

          // 5. THANH NHỎ NHẮC NHỞ KHÁCH CHƯA CÓ VỊ TRÍ
          if (noLocationPoints.isNotEmpty && _selectedPoint == null)
            Positioned(
              left: 14,
              bottom: 24,
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: _showPointSelectionBottomSheet,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.96),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4, offset: const Offset(0, 2)),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.pin_drop_outlined, size: 16, color: Color(0xFFF59E0B)),
                      const SizedBox(width: 6),
                      Text(
                        '${noLocationPoints.length} khách chưa ghim',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.chevron_right_rounded, size: 16, color: Color(0xFF94A3B8)),
                    ],
                  ),
                ),
              ),
            ),

          // 6. CỘT ICON DỌC Ở MÉP PHẢI PHÍA DƯỚI (VÙNG NGÓN CÁI) (TASK 017 - MỤC C)
          // Nút tròn 56px: Dán danh sách SĐT (xanh #2563EB) & Chọn vị trí (Navy #0F172A), kèm Tooltip & Semantics
          if (_selectedPoint == null)
            Positioned(
              right: 16,
              bottom: 20,
              child: RepaintBoundary(
                child: SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Nút "DÁN DANH SÁCH SĐT" (nút tròn 56px, màu xanh #2563EB)
                      Semantics(
                        label: 'Dán danh sách SĐT',
                        button: true,
                        child: Tooltip(
                          message: 'Dán danh sách SĐT',
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              key: const Key('btn_bulk_paste_phones'),
                              borderRadius: BorderRadius.circular(28),
                              onTap: _showBulkPasteBottomSheet,
                              child: Container(
                                width: 56,
                                height: 56,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF2563EB),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(color: Color(0x662563EB), blurRadius: 10, offset: Offset(0, 4)),
                                  ],
                                ),
                                child: const Center(
                                  child: Icon(
                                    Icons.playlist_add_rounded,
                                    size: 28,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Nút "CHỌN VỊ TRÍ" (nút tròn 56px, nền Navy #0F172A)
                      Semantics(
                        label: 'Chọn vị trí',
                        button: true,
                        child: Tooltip(
                          message: 'Chọn vị trí',
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              key: const Key('btn_choose_location'),
                              borderRadius: BorderRadius.circular(28),
                              onTap: _handleFloatingCrosshairPicker,
                              child: Container(
                                width: 56,
                                height: 56,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF0F172A),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 3)),
                                  ],
                                ),
                                child: const Center(
                                  child: Icon(
                                    Icons.add_location_alt_rounded,
                                    size: 24,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
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

  Widget _buildSelectedPointCard(ShiftDeliveryPointModel point) {
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

    return RepaintBoundary(
      child: PointDetailBottomSheet(
        customerId: point.customerId,
        customerName: point.customerName,
        customerPhone: point.customerPhone,
        customerAddress: point.customerAddress,
        locationStatusText: point.locationStatus.displayName,
        statusBadgeBg: badgeBg,
        statusBadgeTextColor: badgeText,
        statusBadgeIcon: badgeIcon,
        identificationNotes: point.locationNotes,
        latitude: point.latitude,
        longitude: point.longitude,
        initialPhotos: point.photos,
        legacyImageUrl: point.photoUrl,
        onCall: () => _makePhoneCall(point.customerPhone),
        onDirections: () {
          if (point.hasValidCoordinates) {
            ApiService.openExternalNavigation(point.latitude!, point.longitude!);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Khách hàng chưa có tọa độ để chỉ đường')),
            );
          }
        },
        onRepin: () => _openCrosshairPickerForPoint(point),
        onPhotosUpdated: (updatedPhotos) {
          setState(() {
            _selectedPoint = _selectedPoint!.copyWith(
              photos: updatedPhotos,
              photoCount: updatedPhotos.length,
            );
            if (_shift != null) {
              final idx = _shift!.deliveryPoints.indexWhere((p) => p.id == point.id);
              if (idx != -1) {
                _shift!.deliveryPoints[idx] = _shift!.deliveryPoints[idx].copyWith(
                  photos: updatedPhotos,
                  photoCount: updatedPhotos.length,
                );
              }
            }
          });
        },
        onClose: () => setState(() => _selectedPoint = null),
      ),
    );
  }
}
