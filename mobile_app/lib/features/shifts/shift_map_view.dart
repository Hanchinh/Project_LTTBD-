import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:delivery_marker_mobile/models/shift_model.dart';
import 'package:delivery_marker_mobile/data/repositories/repository_provider.dart';
import 'package:delivery_marker_mobile/features/map/crosshair_location_picker_view.dart';
import 'package:delivery_marker_mobile/shared_widgets/bulk_paste_phone_sheet.dart';
import 'package:delivery_marker_mobile/data/local/map_tile_cache_service.dart';
import 'package:delivery_marker_mobile/features/shifts/widgets/shift_map_header.dart';
import 'package:delivery_marker_mobile/features/shifts/widgets/shift_map_controls.dart';
import 'package:delivery_marker_mobile/features/shifts/widgets/shift_point_selector_sheet.dart';
import 'package:delivery_marker_mobile/features/shifts/widgets/shift_map_markers_builder.dart';
import 'package:delivery_marker_mobile/features/shifts/widgets/shift_point_detail_card.dart';
import 'package:delivery_marker_mobile/features/shifts/widgets/shift_map_tile_config.dart';

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

  void _switchMapType() {
    setState(() {
      _currentMapType = (_currentMapType + 1) % 3;
      _hasTileError = false;
    });
    ShiftMapTileConfig.showMapTypeSnackBar(context, _currentMapType);
  }

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
      final shift = await RepositoryProvider.shift.getShiftDetail(widget.shiftId);
      if (!mounted) return;

      setState(() {
        _shift = shift;
        _isLoading = false;

        if (preserveSelected && _selectedPoint != null) {
          final matched = shift.deliveryPoints.where((p) => p.id == _selectedPoint!.id).toList();
          if (matched.isNotEmpty) {
            _selectedPoint = matched.first;
          }
        }
      });

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

  void _handleFloatingCrosshairPicker() {
    if (_shift == null) return;

    if (_selectedPoint != null) {
      _openCrosshairPickerForPoint(_selectedPoint!);
    } else {
      ShiftPointSelectorSheet.show(
        context: context,
        points: _shift!.deliveryPoints,
        onPointSelected: _openCrosshairPickerForPoint,
      );
    }
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
            // 1. Bản đồ nền toàn màn hình
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
                      setState(() => _selectedPoint = null);
                    },
                  ),
                  children: [
                    TileLayer(
                      key: ValueKey('shift_tile_layer_$_currentMapType'),
                      urlTemplate: ShiftMapTileConfig.getUrlTemplate(_currentMapType),
                      fallbackUrl: 'https://a.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
                      subdomains: ShiftMapTileConfig.getSubdomains(_currentMapType),
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
                    MarkerLayer(
                      markers: ShiftMapMarkersBuilder.build(
                        shipperLocation: _shipperLocation,
                        validPoints: validPoints,
                        selectedPoint: _selectedPoint,
                        onPointSelected: (point) {
                          setState(() => _selectedPoint = point);
                          _mapController.move(point.latLng!, 17.0);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 2. Floating header
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: ShiftMapHeader(
                shift: shift,
                validPointsCount: validPoints.length,
                noLocationPointsCount: noLocationPoints.length,
                onBack: () => Navigator.pop(context),
                onRefresh: () => _loadShiftData(preserveSelected: true),
              ),
            ),

            // Banner mạng tile
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

            // 3. Map tool buttons (Góc phải trên)
            Positioned(
              right: 14,
              top: 76,
              child: ShiftMapToolButtons(
                isLocatingShipper: _isLocatingShipper,
                onMyLocationTap: () {
                  if (_shipperLocation != null) {
                    _mapController.move(_shipperLocation!, 16.5);
                  } else {
                    _getShipperLocation();
                  }
                },
                onSwitchMapType: _switchMapType,
                onFitBounds: _fitMapBounds,
              ),
            ),

            // 4. Thẻ chi tiết điểm giao đang chọn
            if (_selectedPoint != null)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: ShiftPointDetailCard(
                  point: _selectedPoint!,
                  onCall: () => _makePhoneCall(_selectedPoint!.customerPhone),
                  onRepin: () => _openCrosshairPickerForPoint(_selectedPoint!),
                  onPhotosUpdated: (updatedPhotos) {
                    setState(() {
                      _selectedPoint = _selectedPoint!.copyWith(
                        photos: updatedPhotos,
                        photoCount: updatedPhotos.length,
                      );
                      if (_shift != null) {
                        final idx = _shift!.deliveryPoints.indexWhere((p) => p.id == _selectedPoint!.id);
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
              ),

            // 5. Thanh nhắc nhở khách chưa có vị trí
            if (noLocationPoints.isNotEmpty && _selectedPoint == null)
              Positioned(
                left: 14,
                bottom: 24,
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () {
                    ShiftPointSelectorSheet.show(
                      context: context,
                      points: _shift!.deliveryPoints,
                      onPointSelected: _openCrosshairPickerForPoint,
                    );
                  },
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

            // 6. Action buttons ở góc phải dưới
            if (_selectedPoint == null)
              Positioned(
                right: 16,
                bottom: 20,
                child: ShiftMapActionButtons(
                  onBulkPasteTap: _showBulkPasteBottomSheet,
                  onChooseLocationTap: _handleFloatingCrosshairPicker,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
