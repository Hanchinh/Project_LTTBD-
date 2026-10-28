import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:delivery_marker_mobile/models/customer_model.dart';
import 'package:delivery_marker_mobile/models/data_share_model.dart';
import 'package:delivery_marker_mobile/models/location_model.dart';
import 'package:delivery_marker_mobile/models/shift_model.dart';
import 'package:delivery_marker_mobile/data/repositories/repository_provider.dart';
import 'package:delivery_marker_mobile/data/remote/api_service.dart';
import 'package:delivery_marker_mobile/data/local/map_tile_cache_service.dart';
import 'package:delivery_marker_mobile/features/shifts/widgets/create_shift_dialog.dart';
import 'package:delivery_marker_mobile/features/shifts/widgets/shift_picker_bottom_sheet.dart';
import 'package:delivery_marker_mobile/features/map/widgets/assign_phone_dialog.dart';
import 'package:delivery_marker_mobile/features/map/widgets/control_column.dart';
import 'package:delivery_marker_mobile/features/map/widgets/import_shared_point_helper.dart';
import 'package:delivery_marker_mobile/features/map/widgets/main_map_top_bar.dart';
import 'package:delivery_marker_mobile/features/map/widgets/map_legend.dart';
import 'package:delivery_marker_mobile/features/map/widgets/map_markers_builder.dart';
import 'package:delivery_marker_mobile/features/map/widgets/marker_cluster_helper.dart';
import 'package:delivery_marker_mobile/features/map/widgets/out_of_area_banner.dart';
import 'package:delivery_marker_mobile/features/map/widgets/pin_mode_overlay.dart';
import 'package:delivery_marker_mobile/features/map/widgets/save_location_processor.dart';
import 'package:delivery_marker_mobile/features/map/widgets/saved_location_detail_card.dart';
import 'package:delivery_marker_mobile/features/map/widgets/shared_point_detail_sheet.dart';
import 'package:delivery_marker_mobile/features/shifts/widgets/shift_map_tile_config.dart';
import 'package:delivery_marker_mobile/features/shifts/shift_map_view.dart';

// Tái xuất các lớp Cluster cho tương thích ngược nếu có file khác import
export 'package:delivery_marker_mobile/features/map/widgets/marker_cluster_helper.dart' show LocationCluster, SharedLocationCluster, MarkerClusterHelper;

/// Màn hình Bản đồ Chính độc lập với ca (TASK: MASTER-MAP-014)
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

  List<MasterSavedLocationModel> _savedLocations = [];
  bool _isLoading = true;
  String? _errorMessage;

  MasterSavedLocationModel? _selectedLocation;
  bool _isMapReady = false;
  double _currentZoom = 15.0;

  // CHIA SẺ DỮ LIỆU GIỮA CÁC SHIPPER (TASK 023)
  bool _showSharedLocations = false;
  List<SharedLocationPointModel> _sharedLocations = [];
  SharedLocationPointModel? _selectedSharedLocation;
  int _skippedOutOfAreaCount = 0;
  bool _isLoadingShared = false;
  bool _isOutOfAreaBannerDismissed = false;

  bool _isOffline = false;
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;

  LatLng? _shipperLocation;
  bool _isLocatingShipper = false;

  int _currentMapType = 0;

  bool _isPinningMode = false;
  LatLng _crosshairCoord = _hcmDefault;

  final TextEditingController _addressSearchCtrl = TextEditingController();
  List<AddressSearchResult> _addressSearchResults = [];
  bool _isSearchingAddress = false;
  Timer? _searchDebounceTimer;

  List<CustomerDirectoryModel> _directoryCustomers = [];
  MasterSavedLocationModel? _repinTarget;

  final TileProvider _tileProvider = createPlatformTileProvider();

  Timer? _clusterDebounceTimer;
  final Map<String, List<LocationCluster>> _clusterCache = {};
  List<LocationCluster> _cachedClusters = [];

  static const LatLng _hcmDefault = LatLng(10.842215, 106.818123);

  @override
  void initState() {
    super.initState();
    _loadMasterData();
    _getShipperLocation();
    _initConnectivity();
  }

  @override
  void dispose() {
    try {
      _connectivitySubscription?.cancel();
    } catch (_) {}
    _addressSearchCtrl.dispose();
    _searchDebounceTimer?.cancel();
    _clusterDebounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _initConnectivity() async {
    try {
      final res = await Connectivity().checkConnectivity();
      if (mounted) {
        setState(() => _isOffline = res == ConnectivityResult.none);
      }
    } catch (_) {}
    try {
      _connectivitySubscription = Connectivity().onConnectivityChanged.listen(
        (res) {
          if (mounted) {
            setState(() => _isOffline = res == ConnectivityResult.none);
          }
        },
        onError: (_) {},
        cancelOnError: false,
      );
    } catch (_) {}
  }

  @visibleForTesting
  void setOfflineForTesting(bool isOffline) {
    setState(() => _isOffline = isOffline);
  }

  Future<void> _handleCreateShift() async {
    final newShift = await CreateShiftBottomSheet.show(context);
    if (newShift != null && mounted) {
      widget.onActiveShiftChanged?.call(newShift);
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ShiftMapView(shiftId: newShift.id),
        ),
      );
    }
  }

  Future<void> _handleOpenShiftPicker() async {
    await ShiftPickerBottomSheet.show(
      context: context,
      onShiftSelected: (selectedShift) {
        widget.onActiveShiftChanged?.call(selectedShift);
      },
    );
  }

  Future<void> _loadMasterData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final futures = await Future.wait([
        RepositoryProvider.location.getMySavedLocations(),
        RepositoryProvider.customer.getCustomers().catchError((_) => <CustomerDirectoryModel>[]),
      ]);

      if (!mounted) return;

      final locations = futures[0] as List<MasterSavedLocationModel>;
      final customers = futures[1] as List<CustomerDirectoryModel>;

      setState(() {
        _savedLocations = locations;
        _directoryCustomers = customers;
        _isLoading = false;
        _clusterCache.clear();
        _cachedClusters = MarkerClusterHelper.clusterLocations(locations, _currentZoom);
      });

      if (_isMapReady && locations.isNotEmpty) {
        _fitLocationsBounds();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  void reloadLocations() {
    _loadMasterData();
    if (_showSharedLocations) {
      _loadSharedLocations();
    }
  }

  Future<void> _toggleSharedLocations(bool enable) async {
    setState(() {
      _showSharedLocations = enable;
      _isOutOfAreaBannerDismissed = false;
      if (!enable) {
        _selectedSharedLocation = null;
      }
    });

    if (enable) {
      await _loadSharedLocations();
    }
  }

  Future<void> _loadSharedLocations() async {
    setState(() => _isLoadingShared = true);
    try {
      final res = await RepositoryProvider.sharing.getSharedLocations();
      if (!mounted) return;
      setState(() {
        _sharedLocations = (res['locations'] as List).cast<SharedLocationPointModel>();
        _skippedOutOfAreaCount = res['skippedOutOfAreaCount'] as int? ?? 0;
        _isLoadingShared = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoadingShared = false;
      });
    }
  }

  Future<void> _handleImportSingleSharedPoint(SharedLocationPointModel point) async {
    await ImportSharedPointHelper.handleImportSinglePoint(
      context: context,
      point: point,
      onSuccess: () {
        _loadMasterData();
        setState(() => _selectedSharedLocation = null);
      },
    );
  }

  void reloadActiveShift({bool preserveSelected = true}) {
    reloadLocations();
  }

  @visibleForTesting
  void setSelectedSharedLocationForTesting(SharedLocationPointModel? point) {
    setState(() {
      _selectedLocation = null;
      _selectedSharedLocation = point;
    });
  }

  @visibleForTesting
  void setOutOfAreaWarningForTesting(int skippedCount) {
    setState(() {
      _showSharedLocations = true;
      _skippedOutOfAreaCount = skippedCount;
      _isOutOfAreaBannerDismissed = false;
    });
  }

  void _fitLocationsBounds() {
    final validCoords = _savedLocations
        .where((loc) => loc.hasValidCoordinates)
        .map((loc) => LatLng(loc.latitude, loc.longitude))
        .toList();

    if (validCoords.isEmpty) {
      if (_shipperLocation != null) {
        _mapController.move(_shipperLocation!, 15.5);
      }
      return;
    }

    if (validCoords.length == 1) {
      _mapController.move(validCoords.first, 16.5);
      return;
    }

    final bounds = LatLngBounds.fromPoints(validCoords);
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.fromLTRB(40, 110, 40, 140),
        maxZoom: 17.5,
      ),
    );
  }

  void _recomputeClusters(double zoom, LatLngBounds? bounds) {
    if (!mounted) return;
    if (bounds == null) {
      final res = MarkerClusterHelper.clusterLocations(_savedLocations, zoom);
      setState(() => _cachedClusters = res);
      return;
    }

    final zoomKey = zoom.toStringAsFixed(1);
    final cacheKey = '${zoomKey}_${bounds.southWest.latitude.toStringAsFixed(2)}_${bounds.northEast.latitude.toStringAsFixed(2)}';
    if (_clusterCache.containsKey(cacheKey)) {
      setState(() => _cachedClusters = _clusterCache[cacheKey]!);
      return;
    }

    final latPad = (bounds.northEast.latitude - bounds.southWest.latitude).abs() * 0.15;
    final lngPad = (bounds.northEast.longitude - bounds.southWest.longitude).abs() * 0.15;
    final extendedBounds = LatLngBounds(
      LatLng(bounds.southWest.latitude - latPad, bounds.southWest.longitude - lngPad),
      LatLng(bounds.northEast.latitude + latPad, bounds.northEast.longitude + lngPad),
    );

    final visible = _savedLocations.where((loc) {
      if (!loc.hasValidCoordinates) return false;
      return extendedBounds.contains(LatLng(loc.latitude, loc.longitude));
    }).toList();

    final computed = MarkerClusterHelper.clusterLocations(visible, zoom);
    _clusterCache[cacheKey] = computed;
    if (_clusterCache.length > 50) {
      _clusterCache.remove(_clusterCache.keys.first);
    }

    setState(() => _cachedClusters = computed);
  }

  Future<void> _getShipperLocation() async {
    setState(() => _isLocatingShipper = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        if (mounted) setState(() => _isLocatingShipper = false);
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );

      if (mounted) {
        setState(() {
          _shipperLocation = LatLng(position.latitude, position.longitude);
          _isLocatingShipper = false;
        });

        if (_savedLocations.isEmpty && _isMapReady) {
          _mapController.move(_shipperLocation!, 16.0);
        }
      }
    } catch (_) {
      if (mounted) setState(() => _isLocatingShipper = false);
    }
  }

  void _switchMapType() {
    setState(() {
      _currentMapType = (_currentMapType + 1) % 3;
    });
    ShiftMapTileConfig.showMapTypeSnackBar(context, _currentMapType);
  }

  void _startPinningMode() {
    setState(() {
      _repinTarget = null;
      _isPinningMode = true;
      _selectedLocation = null;
      try {
        _crosshairCoord = _mapController.camera.center;
      } catch (_) {
        _crosshairCoord = _hcmDefault;
      }
      _addressSearchCtrl.clear();
      _addressSearchResults = [];
    });
  }

  void _cancelPinningMode() {
    setState(() {
      _repinTarget = null;
      _isPinningMode = false;
      _addressSearchCtrl.clear();
      _addressSearchResults = [];
    });
  }

  void _onAddressSearchChanged(String query) {
    _searchDebounceTimer?.cancel();
    if (query.trim().length < 3) {
      setState(() => _addressSearchResults = []);
      return;
    }

    if (_isOffline) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            key: Key('offline_address_search_snackbar'),
            content: Text('Cần kết nối mạng để tìm kiếm địa chỉ'),
            backgroundColor: Color(0xFFDC2626),
            duration: Duration(seconds: 2),
          ),
        );
      }
      setState(() {
        _addressSearchResults = [];
        _isSearchingAddress = false;
      });
      return;
    }

    _searchDebounceTimer = Timer(const Duration(milliseconds: 350), () async {
      setState(() => _isSearchingAddress = true);
      try {
        final results = await ApiService.searchAddress(query.trim());
        if (mounted) {
          setState(() {
            _addressSearchResults = results;
            _isSearchingAddress = false;
          });
        }
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              key: Key('offline_address_search_snackbar'),
              content: Text('Cần kết nối mạng để tìm kiếm địa chỉ'),
              backgroundColor: Color(0xFFDC2626),
              duration: Duration(seconds: 2),
            ),
          );
          setState(() => _isSearchingAddress = false);
        }
      }
    });
  }

  void _selectSearchResult(AddressSearchResult result) {
    final target = LatLng(result.latitude, result.longitude);
    _mapController.move(target, 17.5);
    setState(() {
      _crosshairCoord = target;
      _addressSearchResults = [];
      _addressSearchCtrl.text = result.displayName;
    });
    FocusScope.of(context).unfocus();
  }

  Future<void> _showAssignPhoneDialog(LatLng targetCoord) async {
    await AssignPhoneBottomSheet.show(
      context: context,
      targetCoord: targetCoord,
      repinTarget: _repinTarget,
      directoryCustomers: _directoryCustomers,
      onConfirmSave: ({
        required String phone,
        required String fullName,
        required String notes,
        required LatLng targetCoord,
        String? knownCustomerId,
      }) async {
        setState(() => _isLoading = true);
        final success = await SaveLocationProcessor.processSaveLocation(
          context: context,
          phone: phone,
          fullName: fullName,
          notes: notes,
          targetCoord: targetCoord,
          knownCustomerId: knownCustomerId,
        );
        if (success) {
          await _loadMasterData();
          if (mounted) {
            setState(() {
              _isPinningMode = false;
              _isLoading = false;
            });
            _mapController.move(targetCoord, 17.5);
          }
        } else {
          if (mounted) setState(() => _isLoading = false);
        }
      },
    );
  }

  Future<void> _makePhoneCall(String phone) async {
    final clean = phone.replaceAll(RegExp(r'[^\d+]'), '');
    final uri = Uri.parse('tel:$clean');
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
    final clusters = _cachedClusters.isNotEmpty
        ? _cachedClusters
        : MarkerClusterHelper.clusterLocations(_savedLocations, _currentZoom);

    final sharedClusters = _showSharedLocations
        ? MarkerClusterHelper.clusterSharedLocations(_sharedLocations, _currentZoom)
        : <SharedLocationCluster>[];

    final shipperMarker = MapMarkersBuilder.buildShipperMarker(_shipperLocation);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: PopScope(
        canPop: _selectedLocation == null && _selectedSharedLocation == null && !_isPinningMode,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          if (_selectedLocation != null) {
            setState(() => _selectedLocation = null);
          } else if (_selectedSharedLocation != null) {
            setState(() => _selectedSharedLocation = null);
          } else if (_isPinningMode) {
            _cancelPinningMode();
          }
        },
        child: Stack(
          children: [
            // 1. Bản đồ FlutterMap
            Positioned.fill(
              child: RepaintBoundary(
                child: FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _savedLocations.isNotEmpty
                        ? LatLng(_savedLocations.first.latitude, _savedLocations.first.longitude)
                        : (_shipperLocation ?? _hcmDefault),
                    initialZoom: _currentZoom,
                    minZoom: 4.0,
                    maxZoom: 18.5,
                    onTap: (tapPosition, point) {
                      if (_selectedLocation != null) {
                        setState(() => _selectedLocation = null);
                      }
                      if (_selectedSharedLocation != null) {
                        setState(() => _selectedSharedLocation = null);
                      }
                    },
                    onMapReady: () {
                      _isMapReady = true;
                      if (_savedLocations.isNotEmpty) {
                        _fitLocationsBounds();
                      }
                    },
                    onPositionChanged: (position, hasGesture) {
                      if (position.zoom != null && position.zoom != _currentZoom) {
                        _currentZoom = position.zoom!;
                      }
                      if (_isPinningMode && position.center != null) {
                        _crosshairCoord = position.center!;
                      }
                      if (hasGesture) {
                        _clusterDebounceTimer?.cancel();
                        _clusterDebounceTimer = Timer(const Duration(milliseconds: 150), () {
                          _recomputeClusters(
                            position.zoom ?? _currentZoom,
                            position.bounds,
                          );
                        });
                      } else {
                        _clusterDebounceTimer?.cancel();
                        _recomputeClusters(
                          position.zoom ?? _currentZoom,
                          position.bounds,
                        );
                      }
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: ShiftMapTileConfig.getUrlTemplate(_currentMapType),
                      subdomains: ShiftMapTileConfig.getSubdomains(_currentMapType),
                      userAgentPackageName: 'com.deliverymarker.mobile',
                      maxZoom: 19,
                      panBuffer: 1,
                      keepBuffer: 2,
                      tileProvider: _tileProvider,
                    ),

                    if (shipperMarker != null)
                      MarkerLayer(markers: [shipperMarker]),

                    if (!_isPinningMode)
                      MarkerLayer(
                        markers: MapMarkersBuilder.buildSavedLocationMarkers(
                          clusters: clusters,
                          selectedLocation: _selectedLocation,
                          currentZoom: _currentZoom,
                          onClusterTap: (center, targetZoom) {
                            _mapController.move(center, targetZoom);
                          },
                          onLocationTap: (loc) {
                            setState(() => _selectedLocation = loc);
                            _mapController.move(LatLng(loc.latitude, loc.longitude), 17.0);
                          },
                        ),
                      ),

                    if (!_isPinningMode && _showSharedLocations)
                      MarkerLayer(
                        markers: MapMarkersBuilder.buildSharedLocationMarkers(
                          sharedClusters: sharedClusters,
                          selectedSharedLocation: _selectedSharedLocation,
                          currentZoom: _currentZoom,
                          onClusterTap: (center, targetZoom) {
                            _mapController.move(center, targetZoom);
                          },
                          onPointTap: (point) {
                            setState(() {
                              _selectedLocation = null;
                              _selectedSharedLocation = point;
                            });
                            _mapController.move(LatLng(point.latitude, point.longitude), 17.0);
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // 2. Chế độ tâm ngắm
            if (_isPinningMode)
              PinModeOverlay(
                searchController: _addressSearchCtrl,
                isSearchingAddress: _isSearchingAddress,
                searchResults: _addressSearchResults,
                onSearchChanged: _onAddressSearchChanged,
                onSelectSearchResult: _selectSearchResult,
                onCancel: _cancelPinningMode,
                onConfirm: () => _showAssignPhoneDialog(_crosshairCoord),
              ),

            // 3. Thanh điều hướng trên cùng
            if (!_isPinningMode)
              MainMapTopBar(
                isLoadingShared: _isLoadingShared,
                showSharedLocations: _showSharedLocations,
                onToggleShared: _toggleSharedLocations,
                onSwitchMapType: _switchMapType,
                onReload: _loadMasterData,
              ),

            // Banner thông báo mất mạng (TASK: LOCAL-FIRST-09)
            if (_isOffline)
              Positioned(
                top: _isPinningMode ? 86 : 68,
                left: 14,
                right: 14,
                child: Container(
                  key: const Key('map_offline_banner'),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFCA5A5)),
                    boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.wifi_off_rounded, color: Color(0xFFDC2626), size: 18),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Đang mất kết nối mạng. Bản đồ hiển thị dữ liệu cục bộ / bộ nhớ đệm.',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF991B1B)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Banner cảnh báo điểm ngoài khu vực
            if (!_isPinningMode && _showSharedLocations && !_isOutOfAreaBannerDismissed && _skippedOutOfAreaCount > 0)
              OutOfAreaBanner(
                count: _skippedOutOfAreaCount,
                onDismiss: () => setState(() => _isOutOfAreaBannerDismissed = true),
              ),

            // Chú thích phân biệt marker
            if (!_isPinningMode && _showSharedLocations)
              MapLegendWidget(
                isOutOfAreaBannerVisible: !_isOutOfAreaBannerDismissed && _skippedOutOfAreaCount > 0,
              ),

            // Banner thông báo lỗi nếu có
            if (_errorMessage != null && !_isPinningMode)
              Positioned(
                top: 75,
                left: 14,
                right: 14,
                child: SafeArea(
                  child: Material(
                    elevation: 4,
                    borderRadius: BorderRadius.circular(10),
                    color: const Color(0xFFFEE2E2),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline_rounded, color: Color(0xFFEF4444), size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 12),
                            ),
                          ),
                          IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            icon: const Icon(Icons.close_rounded, size: 16, color: Color(0xFFB91C1C)),
                            onPressed: () => setState(() => _errorMessage = null),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

            // 4. Các nút GPS và xem toàn bộ (góc trên bên phải)
            if (!_isPinningMode)
              MainMapGpsControls(
                isLocatingShipper: _isLocatingShipper,
                onGetShipperLocation: _getShipperLocation,
                onFitLocationsBounds: _fitLocationsBounds,
              ),

            // 5. Thẻ chi tiết điểm của tôi
            if (!_isPinningMode && _selectedLocation != null)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: SavedLocationDetailCard(
                  location: _selectedLocation!,
                  onCall: () => _makePhoneCall(_selectedLocation!.customerPhone),
                  onRepin: () {
                    setState(() {
                      _repinTarget = _selectedLocation;
                      _isPinningMode = true;
                      _crosshairCoord = LatLng(
                        _selectedLocation!.latitude,
                        _selectedLocation!.longitude,
                      );
                      _selectedLocation = null;
                      _addressSearchCtrl.clear();
                      _addressSearchResults = [];
                    });
                    _mapController.move(_crosshairCoord, 17.5);
                  },
                  onClose: () => setState(() => _selectedLocation = null),
                ),
              ),

            // 6. Thẻ chi tiết điểm được chia sẻ
            if (!_isPinningMode && _selectedSharedLocation != null)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: SharedPointDetailSheet(
                  point: _selectedSharedLocation!,
                  onCall: _makePhoneCall,
                  onDirections: () {
                    ApiService.openExternalNavigation(
                      _selectedSharedLocation!.latitude,
                      _selectedSharedLocation!.longitude,
                    );
                  },
                  onImport: _handleImportSingleSharedPoint,
                  onClose: () => setState(() => _selectedSharedLocation = null),
                ),
              ),

            // 7. Cột icon điều khiển ở góc phải dưới
            if (!_isPinningMode && _selectedLocation == null && _selectedSharedLocation == null)
              MainMapControlColumn(
                onOpenShiftPicker: _handleOpenShiftPicker,
                onCreateShift: _handleCreateShift,
                onStartPinning: _startPinningMode,
              ),

            if (_isLoading && _savedLocations.isEmpty)
              const Center(
                child: CircularProgressIndicator(color: Color(0xFF2563EB)),
              ),
          ],
        ),
      ),
    );
  }
}
