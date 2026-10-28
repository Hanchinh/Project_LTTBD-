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
import 'package:delivery_marker_mobile/core/services/geocoding_service.dart';
import 'package:delivery_marker_mobile/core/utils/map_navigation_helper.dart';
import 'package:delivery_marker_mobile/models/address_search_result.dart';
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

export 'package:delivery_marker_mobile/features/map/widgets/marker_cluster_helper.dart' show LocationCluster, SharedLocationCluster, MarkerClusterHelper;

part 'main_map_view_handlers.dart';

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

  // Chia sẻ dữ liệu giữa các shipper (TASK 023)
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

  void updateState(VoidCallback fn) {
    if (mounted) setState(fn);
  }

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

  @visibleForTesting
  void setOfflineForTesting(bool isOffline) {
    setState(() => _isOffline = isOffline);
  }

  void reloadLocations() {
    _loadMasterData();
    if (_showSharedLocations) {
      _loadSharedLocations();
    }
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
                    MapNavigationHelper.openExternalNavigation(
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
