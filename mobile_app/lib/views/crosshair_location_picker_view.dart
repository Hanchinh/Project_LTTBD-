import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../models/shift_model.dart';
import '../services/api_service.dart';
import '../services/map_tile_cache_service.dart';

class CrosshairLocationPickerResult {
  final double latitude;
  final double longitude;
  final String action; // 'TEMPORARY' or 'VERIFY'

  CrosshairLocationPickerResult({
    required this.latitude,
    required this.longitude,
    required this.action,
  });
}

class CrosshairLocationPickerView extends StatefulWidget {
  final ShiftDeliveryPointModel point;
  final String shiftId;
  final LatLng? initialCenter;
  final LatLng? myLocation;

  const CrosshairLocationPickerView({
    super.key,
    required this.point,
    required this.shiftId,
    this.initialCenter,
    this.myLocation,
  });

  @override
  State<CrosshairLocationPickerView> createState() => _CrosshairLocationPickerViewState();
}

class _CrosshairLocationPickerViewState extends State<CrosshairLocationPickerView> {
  final MapController _mapController = MapController();
  final TileProvider _tileProvider = CancellableDiskCachedTileProvider();
  late LatLng _currentCrosshairCenter;
  LatLng? _shipperLocation;
  bool _isLoadingGps = false;
  bool _isSaving = false;
  bool _isMapReady = false;

  // Tìm kiếm địa chỉ (Giai đoạn C)
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  Timer? _debounceTimer;
  bool _isSearchingAddress = false;
  String? _searchErrorMessage;
  List<AddressSearchResult> _searchResults = [];
  bool _showSuggestions = false;

  // Tọa độ trung tâm mặc định nếu không có dữ liệu (Quận 1, TP.HCM)
  static const LatLng _hcmDefault = LatLng(10.776889, 106.700806);

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onSearchQueryChanged(String query) {
    _debounceTimer?.cancel();
    final trimmed = query.trim();
    if (trimmed.length < 2) {
      setState(() {
        _searchResults = [];
        _isSearchingAddress = false;
        _searchErrorMessage = null;
        _showSuggestions = false;
      });
      return;
    }

    setState(() {
      _isSearchingAddress = true;
      _searchErrorMessage = null;
      _showSuggestions = true;
    });

    _debounceTimer = Timer(const Duration(milliseconds: 350), () async {
      try {
        final results = await ApiService.searchAddress(trimmed);
        if (!mounted) return;
        setState(() {
          _searchResults = results;
          _isSearchingAddress = false;
          _searchErrorMessage = null;
        });
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _searchErrorMessage = e.toString().replaceAll('Exception: ', '');
          _isSearchingAddress = false;
        });
      }
    });
  }

  void _selectAddressResult(AddressSearchResult item) {
    _searchFocusNode.unfocus();
    _searchController.text = item.displayName;
    final targetLatLng = LatLng(item.latitude, item.longitude);
    setState(() {
      _showSuggestions = false;
      _currentCrosshairCenter = targetLatLng;
    });

    if (_isMapReady) {
      _mapController.move(targetLatLng, 17.5);
    }
  }

  @override
  void initState() {
    super.initState();

    _shipperLocation = widget.myLocation;

    // Ưu tiên:
    // 1. Tọa độ hiện có của điểm giao
    // 2. InitialCenter truyền vào
    // 3. Vị trí shipper hiện tại
    // 4. Mặc định TP.HCM
    if (widget.point.hasValidCoordinates) {
      _currentCrosshairCenter = LatLng(widget.point.latitude!, widget.point.longitude!);
    } else if (widget.initialCenter != null) {
      _currentCrosshairCenter = widget.initialCenter!;
    } else if (_shipperLocation != null) {
      _currentCrosshairCenter = _shipperLocation!;
    } else {
      _currentCrosshairCenter = _hcmDefault;
      _getCurrentLocation(centerMap: true);
    }
  }

  Future<void> _getCurrentLocation({bool centerMap = false}) async {
    setState(() => _isLoadingGps = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Vui lòng bật định vị GPS trên thiết bị')),
          );
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );

      final latLng = LatLng(position.latitude, position.longitude);
      if (!mounted) return;

      setState(() {
        _shipperLocation = latLng;
        if (centerMap) {
          _currentCrosshairCenter = latLng;
          if (_isMapReady) {
            _mapController.move(latLng, 17.5);
          }
        }
      });
    } catch (_) {
      // Vẫn cho phép chọn thủ công dù GPS lỗi
    } finally {
      if (mounted) {
        setState(() => _isLoadingGps = false);
      }
    }
  }

  void _moveToMyLocation() {
    if (_shipperLocation != null) {
      if (_isMapReady) {
        _mapController.move(_shipperLocation!, 17.5);
      }
      setState(() {
        _currentCrosshairCenter = _shipperLocation!;
      });
    } else {
      _getCurrentLocation(centerMap: true);
    }
  }

  Future<void> _saveTemporaryLocation() async {
    setState(() => _isSaving = true);
    try {
      final updatedPoint = await ApiService.updateTemporaryLocation(
        widget.shiftId,
        widget.point.id,
        latitude: _currentCrosshairCenter.latitude,
        longitude: _currentCrosshairCenter.longitude,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã ghim vị trí tạm cho ${updatedPoint.customerName}'),
          backgroundColor: const Color(0xFFF59E0B),
        ),
      );

      Navigator.pop(
        context,
        CrosshairLocationPickerResult(
          latitude: _currentCrosshairCenter.latitude,
          longitude: _currentCrosshairCenter.longitude,
          action: 'TEMPORARY',
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: $e'), backgroundColor: const Color(0xFFEF4444)),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    Color badgeBg;
    Color badgeText;
    IconData badgeIcon;

    switch (widget.point.locationStatus) {
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
            const Text(
              'Chọn vị trí bằng tâm ngắm',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
            ),
            Text(
              'Khách: ${widget.point.customerName}',
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              overflow: TextOverflow.ellipsis,
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
            tooltip: 'Hướng dẫn',
            icon: const Icon(Icons.help_outline_rounded, color: Color(0xFF475569)),
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  title: const Text('Cách chọn vị trí', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                  content: const Text(
                    '1. Kéo bản đồ để di chuyển vị trí nhà khách hàng vào đúng mũi tâm ngắm màu đỏ ở giữa màn hình.\n\n'
                    '2. Phóng to bản đồ để căn chính xác cổng nhà hoặc cửa vào.\n\n'
                    '3. Bấm "XÁC NHẬN VỊ TRÍ" ở góc dưới để lưu lại.',
                    style: TextStyle(fontSize: 14, height: 1.4),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('ĐÃ HIỂU', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Stack(
        children: [
          // 1. Bản đồ có thể kéo/pan/zoom tự do
          Positioned.fill(
            child: RepaintBoundary(
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _currentCrosshairCenter,
                  initialZoom: 17.5,
                  maxZoom: 19.0,
                  minZoom: 10.0,
                  onMapReady: () => _isMapReady = true,
                  onPositionChanged: (position, hasGesture) {
                    // Cập nhật tọa độ tâm ngắm live khi kéo bản đồ
                    if (position.center != null) {
                      setState(() {
                        _currentCrosshairCenter = position.center!;
                      });
                    }
                  },
                ),
                children: [
                  TileLayer(
                    key: const ValueKey('crosshair_picker_tile'),
                    urlTemplate: 'https://mt1.google.com/vt/lyrs=m&x={x}&y={y}&z={z}',
                    fallbackUrl: 'https://a.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.delivery_marker_mobile',
                    panBuffer: 1,
                    keepBuffer: 2,
                    tileProvider: _tileProvider,
                  ),
                  // Hiển thị marker vị trí GPS của shipper (nếu có)
                  if (_shipperLocation != null)
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: _shipperLocation!,
                          width: 48,
                          height: 48,
                          child: Center(
                            child: Container(
                              width: 20,
                              height: 20,
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
                      ],
                    ),
                ],
              ),
            ),
          ),

          // 2. TÂM NGẮM CỐ ĐỊNH CHÍNH GIỮA MÀN HÌNH (Fixed Crosshair Pin)
          IgnorePointer(
            child: Center(
              child: SizedBox(
                width: 90,
                height: 90,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Vòng tròn tâm ngắm
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFEF4444), width: 2),
                      ),
                    ),
                    // Trục ngang và dọc
                    Container(width: 76, height: 1.5, color: const Color(0xFFEF4444).withValues(alpha: 0.8)),
                    Container(width: 1.5, height: 76, color: const Color(0xFFEF4444).withValues(alpha: 0.8)),
                    // Chấm tâm ngắm chính xác
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFFEF4444),
                        shape: BoxShape.circle,
                      ),
                    ),
                    // Ghim vị trí nổi đặt phía trên tâm ngắm
                    Transform.translate(
                      offset: const Offset(0, -28),
                      child: const Icon(
                        Icons.location_on,
                        size: 38,
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
          ),

          // 3. Thanh tìm kiếm địa chỉ Google Maps & Gợi ý (Giai đoạn C)
          Positioned(
            top: 10,
            left: 14,
            right: 14,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Ô tìm kiếm địa chỉ chính
                Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                    boxShadow: const [
                      BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 3)),
                    ],
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 12),
                      const Icon(Icons.search_rounded, color: Color(0xFF2563EB), size: 22),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          focusNode: _searchFocusNode,
                          onChanged: _onSearchQueryChanged,
                          textInputAction: TextInputAction.search,
                          style: const TextStyle(fontSize: 14, color: Color(0xFF0F172A), fontWeight: FontWeight.w500),
                          decoration: const InputDecoration(
                            hintText: 'Tìm địa chỉ hoặc địa điểm...',
                            hintStyle: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      if (_isSearchingAddress)
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF2563EB)),
                          ),
                        )
                      else if (_searchController.text.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18, color: Color(0xFF64748B)),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _searchResults = [];
                              _showSuggestions = false;
                              _searchErrorMessage = null;
                            });
                          },
                        ),
                      const SizedBox(width: 4),
                    ],
                  ),
                ),

                // Danh sách gợi ý địa chỉ
                if (_showSuggestions)
                  Container(
                    margin: const EdgeInsets.only(top: 6),
                    constraints: const BoxConstraints(maxHeight: 220),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: const [
                        BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4)),
                      ],
                    ),
                    child: _buildSearchResultsList(),
                  ),

                // Gợi ý kéo tâm ngắm (khi không mở gợi ý)
                if (!_showSuggestions)
                  Container(
                    margin: const EdgeInsets.only(top: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4, offset: const Offset(0, 2)),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.touch_app_rounded, color: Color(0xFF2563EB), size: 16),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Kéo bản đồ để mũi ghim trỏ đúng cổng/cửa nhà khách',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF334155),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // 4. Nút định vị GPS và nút Zoom chuẩn hóa 44x44
          Positioned(
            right: 14,
            bottom: 210,
            child: Column(
              children: [
                _buildPickerToolButton(
                  icon: Icons.my_location_rounded,
                  tooltip: 'Về vị trí GPS của tôi',
                  isLoading: _isLoadingGps,
                  iconColor: const Color(0xFF2563EB),
                  onTap: _moveToMyLocation,
                ),
                const SizedBox(height: 8),
                _buildPickerToolButton(
                  icon: Icons.add_rounded,
                  tooltip: 'Phóng to',
                  onTap: () {
                    final zoom = _mapController.camera.zoom;
                    _mapController.move(_currentCrosshairCenter, zoom + 1);
                  },
                ),
                const SizedBox(height: 8),
                _buildPickerToolButton(
                  icon: Icons.remove_rounded,
                  tooltip: 'Thu nhỏ',
                  onTap: () {
                    final zoom = _mapController.camera.zoom;
                    _mapController.move(_currentCrosshairCenter, zoom - 1);
                  },
                ),
              ],
            ),
          ),

          // 5. Bảng thông tin tọa độ và 2 nút lớn: HỦY và XÁC NHẬN VỊ TRÍ
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                boxShadow: [
                  BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -2)),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Banner Đang ghim lại cho khách hàng
                    Container(
                      key: const Key('repin_customer_banner'),
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFBFDBFE)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.push_pin_rounded, size: 16, color: Color(0xFF2563EB)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Đang ghim lại cho: ${widget.point.customerName} - ${widget.point.customerPhone}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1D4ED8),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Thông tin khách hàng & Trạng thái hiện tại
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.point.customerName,
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                widget.point.customerAddress,
                                style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
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
                              Icon(badgeIcon, size: 12, color: badgeText),
                              const SizedBox(width: 4),
                              Text(
                                widget.point.locationStatus.displayName,
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
                    const SizedBox(height: 10),

                    // Tọa độ hiện tại tại tâm ngắm
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.gps_fixed_rounded, size: 16, color: Color(0xFFEF4444)),
                          const SizedBox(width: 6),
                          const Text(
                            'Tọa độ tâm ngắm: ',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF64748B)),
                          ),
                          Expanded(
                            child: Text(
                              '${_currentCrosshairCenter.latitude.toStringAsFixed(6)}, ${_currentCrosshairCenter.longitude.toStringAsFixed(6)}',
                              style: const TextStyle(
                                fontSize: 13,
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // 2 Nút: HỦY và XÁC NHẬN VỊ TRÍ
                    Row(
                      children: [
                        // Nút HỦY
                        Expanded(
                          flex: 1,
                          child: SizedBox(
                            height: 48,
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF64748B),
                                side: const BorderSide(color: Color(0xFFCBD5E1)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: _isSaving ? null : () => Navigator.pop(context),
                              child: const Text(
                                'Hủy',
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Nút XÁC NHẬN VỊ TRÍ
                        Expanded(
                          flex: 2,
                          child: SizedBox(
                            height: 48,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0F172A),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              icon: _isSaving
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                    )
                                  : const Icon(Icons.check_rounded, size: 20),
                              label: Text(
                                _isSaving
                                    ? 'Đang lưu...'
                                    : (widget.shiftId.isNotEmpty ? 'Lưu vị trí tạm' : 'Xác nhận vị trí'),
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                              ),
                              onPressed: _isSaving
                                  ? null
                                  : () {
                                      if (widget.shiftId.isNotEmpty) {
                                        _saveTemporaryLocation();
                                      } else {
                                        Navigator.pop(
                                          context,
                                          CrosshairLocationPickerResult(
                                            latitude: _currentCrosshairCenter.latitude,
                                            longitude: _currentCrosshairCenter.longitude,
                                            action: 'TEMPORARY',
                                          ),
                                        );
                                      }
                                    },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPickerToolButton({
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

  Widget _buildSearchResultsList() {
    if (_isSearchingAddress && _searchResults.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF2563EB))),
              SizedBox(width: 10),
              Text('Đang tìm kiếm địa chỉ...', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
            ],
          ),
        ),
      );
    }

    if (_searchErrorMessage != null) {
      return Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            const Icon(Icons.wifi_off_rounded, color: Color(0xFFEF4444), size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Lỗi tìm kiếm: $_searchErrorMessage',
                style: const TextStyle(fontSize: 12, color: Color(0xFFEF4444)),
              ),
            ),
          ],
        ),
      );
    }

    if (_searchResults.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16, horizontal: 14),
        child: Row(
          children: [
            Icon(Icons.search_off_rounded, color: Color(0xFF94A3B8), size: 20),
            SizedBox(width: 8),
            Text(
              'Không tìm thấy kết quả địa chỉ phù hợp',
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: _searchResults.length,
      separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
      itemBuilder: (ctx, index) {
        final item = _searchResults[index];
        return ListTile(
          dense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          leading: const Icon(Icons.place_outlined, color: Color(0xFF2563EB), size: 20),
          title: Text(
            item.displayName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
          ),
          subtitle: Text(
            '${item.latitude.toStringAsFixed(5)}, ${item.longitude.toStringAsFixed(5)}${item.source != null ? ' · ${item.source}' : ''}',
            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontFamily: 'monospace'),
          ),
          onTap: () => _selectAddressResult(item),
        );
      },
    );
  }
}

