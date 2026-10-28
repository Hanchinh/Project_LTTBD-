import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:delivery_marker_mobile/models/shift_model.dart';
import 'package:delivery_marker_mobile/data/repositories/repository_provider.dart';
import 'package:delivery_marker_mobile/core/services/geocoding_service.dart';
import 'package:delivery_marker_mobile/models/address_search_result.dart';
import 'package:delivery_marker_mobile/data/local/map_tile_cache_service.dart';
import 'package:delivery_marker_mobile/core/constants/map_config.dart';
import 'package:delivery_marker_mobile/features/map/widgets/fixed_crosshair_target.dart';
import 'package:delivery_marker_mobile/features/map/widgets/crosshair_bottom_panel.dart';
import 'package:delivery_marker_mobile/features/map/widgets/crosshair_search_panel.dart';
import 'package:delivery_marker_mobile/features/map/widgets/crosshair_map_controls.dart';

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
  final TileProvider _tileProvider = createPlatformTileProvider();
  late LatLng _currentCrosshairCenter;
  LatLng? _shipperLocation;
  bool _isLoadingGps = false;
  bool _isSaving = false;
  bool _isMapReady = false;

  // Tìm kiếm địa chỉ
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
        final results = await GeocodingService.searchAddress(trimmed);
        if (!mounted) return;
        setState(() {
          _searchResults = results;
          _isSearchingAddress = false;
          _searchErrorMessage = null;
        });
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _searchErrorMessage = 'Cần kết nối mạng để tìm kiếm địa chỉ';
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
      final updatedPoint = await RepositoryProvider.location.updateTemporaryLocation(
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
                    urlTemplate: MapConfig.googleRoadsUrl,
                    fallbackUrl: MapConfig.fallbackUrl,
                    userAgentPackageName: MapConfig.userAgentPackageName,
                    panBuffer: 1,
                    keepBuffer: 2,
                    tileProvider: _tileProvider,
                  ),
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

          // 2. Tâm ngắm cố định chính giữa màn hình
          const FixedCrosshairTarget(),

          // 3. Thanh tìm kiếm địa chỉ Google Maps & Gợi ý
          Positioned(
            top: 10,
            left: 14,
            right: 14,
            child: CrosshairSearchPanel(
              controller: _searchController,
              focusNode: _searchFocusNode,
              onChanged: _onSearchQueryChanged,
              isSearching: _isSearchingAddress,
              showSuggestions: _showSuggestions,
              searchResults: _searchResults,
              searchErrorMessage: _searchErrorMessage,
              onSelectResult: _selectAddressResult,
              onClear: () {
                _searchController.clear();
                setState(() {
                  _searchResults = [];
                  _showSuggestions = false;
                  _searchErrorMessage = null;
                });
              },
            ),
          ),

          // 4. Nút định vị GPS và Zoom
          Positioned(
            right: 14,
            bottom: 210,
            child: CrosshairMapControls(
              isLoadingGps: _isLoadingGps,
              onMyLocation: _moveToMyLocation,
              onZoomIn: () {
                final zoom = _mapController.camera.zoom;
                _mapController.move(_currentCrosshairCenter, zoom + 1);
              },
              onZoomOut: () {
                final zoom = _mapController.camera.zoom;
                _mapController.move(_currentCrosshairCenter, zoom - 1);
              },
            ),
          ),

          // 5. Bảng thông tin tọa độ và nút Xác nhận
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: CrosshairBottomPanel(
              point: widget.point,
              shiftId: widget.shiftId,
              currentCrosshairCenter: _currentCrosshairCenter,
              isSaving: _isSaving,
              onCancel: () => Navigator.pop(context),
              onConfirm: () {
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
        ],
      ),
    );
  }
}
