import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/customer_model.dart';
import '../models/location_model.dart';
import '../models/shift_model.dart';
import '../services/api_service.dart';
import '../widgets/quick_add_customer_sheet.dart';
import '../widgets/point_detail_bottom_sheet.dart';
import '../widgets/create_shift_dialog.dart';
import '../widgets/shift_picker_bottom_sheet.dart';
import '../services/map_tile_cache_service.dart';
import '../theme/app_buttons.dart';
import '../models/data_share_model.dart';
import '../widgets/customer_photos_strip_widget.dart';
import 'shift_map_view.dart';

/// Lớp đại diện cho cụm điểm (Cluster) trên Bản đồ chính
class _LocationCluster {
  final LatLng center;
  final List<MasterSavedLocationModel> items;

  _LocationCluster({required this.center, required this.items});
}

/// Lớp đại diện cho cụm điểm được chia sẻ (TASK 023)
class _SharedLocationCluster {
  final LatLng center;
  final List<SharedLocationPointModel> items;

  _SharedLocationCluster({required this.center, required this.items});
}

/// Màn hình Bản đồ Chính độc lập với ca (TASK: MASTER-MAP-014)
/// - Hiển thị tất cả các điểm shipper đang đăng nhập đã lưu (saved_locations do chính họ lưu)
/// - Hỗ trợ gom cụm marker (Clustering) khi ở mức zoom xa
/// - Nút nổi "Ghim vị trí mới": mở tâm ngắm, kéo chọn tọa độ tùy ý
/// - Hộp thoại "Gán cho số điện thoại nào?": tự tạo khách nếu mới, hỏi thay thế nếu đã có vị trí
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

  // Danh sách toàn bộ vị trí đã lưu của shipper đăng nhập
  List<MasterSavedLocationModel> _savedLocations = [];
  bool _isLoading = true;
  String? _errorMessage;

  // Điểm được chọn để hiển thị chi tiết dưới đáy màn hình
  MasterSavedLocationModel? _selectedLocation;
  bool _isMapReady = false;
  double _currentZoom = 15.0;

  // CHIA SẺ DỮ LIỆU GIỮA CÁC SHIPPER (TASK 023)
  bool _showSharedLocations = false; // Mặc định tắt
  List<SharedLocationPointModel> _sharedLocations = [];
  SharedLocationPointModel? _selectedSharedLocation;
  int _skippedOutOfAreaCount = 0;
  bool _isLoadingShared = false;
  bool _isOutOfAreaBannerDismissed = false;

  // Vị trí GPS của shipper
  LatLng? _shipperLocation;
  bool _isLocatingShipper = false;

  // Loại bản đồ nền (0: Google Đường phố, 1: Google Hybrid Vệ tinh, 2: CartoDB Voyager)
  int _currentMapType = 0;

  // Chế độ ghim vị trí mới bằng tâm ngắm (TASK: MASTER-MAP-014)
  bool _isPinningMode = false;
  LatLng _crosshairCoord = _hcmDefault;

  // Tìm kiếm địa chỉ Geocoding trong chế độ ghim
  final TextEditingController _addressSearchCtrl = TextEditingController();
  List<AddressSearchResult> _addressSearchResults = [];
  bool _isSearchingAddress = false;
  Timer? _searchDebounceTimer;

  // Danh bạ khách hàng lưu tạm trong bộ nhớ để gợi ý khi gán SĐT
  List<CustomerDirectoryModel> _directoryCustomers = [];

  // Khách hàng mục tiêu khi kích hoạt luồng Ghim lại (TASK 019)
  MasterSavedLocationModel? _repinTarget;

  // Tile Provider hỗ trợ Disk Cache tối đa 200MB & Cancellable trên mobile, fallback NetworkTileProvider trên web (TASK 021B)
  final TileProvider _tileProvider = createPlatformTileProvider();

  // Tối ưu gom cụm: debounce 150ms, cache kết quả theo zoom, chỉ tính điểm trong viewport (TASK 019)
  Timer? _clusterDebounceTimer;
  final Map<String, List<_LocationCluster>> _clusterCache = {};
  List<_LocationCluster> _cachedClusters = [];

  // Tọa độ mặc định (TP.HCM)
  static const LatLng _hcmDefault = LatLng(10.842215, 106.818123);

  @override
  void initState() {
    super.initState();
    _loadMasterData();
    _getShipperLocation();
  }

  @override
  void dispose() {
    _addressSearchCtrl.dispose();
    _searchDebounceTimer?.cancel();
    _clusterDebounceTimer?.cancel();
    super.dispose();
  }

  /// Mở hộp thoại tạo ca làm việc mới từ bản đồ chính (TASK: SHIFT-FROM-MAP-AND-BULK-PASTE-015B)
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

  /// Mở bottom sheet chọn ca làm việc từ bản đồ chính (TASK: PHOTO-SYNC-SHIFT-PICKER-BULK-016 - Mục B)
  Future<void> _handleOpenShiftPicker() async {
    await ShiftPickerBottomSheet.show(
      context: context,
      onShiftSelected: (selectedShift) {
        widget.onActiveShiftChanged?.call(selectedShift);
      },
    );
  }

  /// Tải dữ liệu các vị trí đã lưu của shipper và danh bạ để gợi ý SĐT
  Future<void> _loadMasterData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final futures = await Future.wait([
        ApiService.getMySavedLocations(),
        ApiService.getCustomers().catchError((_) => <CustomerDirectoryModel>[]),
      ]);

      if (!mounted) return;

      final locations = futures[0] as List<MasterSavedLocationModel>;
      final customers = futures[1] as List<CustomerDirectoryModel>;

      setState(() {
        _savedLocations = locations;
        _directoryCustomers = customers;
        _isLoading = false;
        _clusterCache.clear();
        _cachedClusters = _clusterLocations(locations, _currentZoom);
      });

      // Nếu có vị trí và bản đồ đã sẵn sàng, tự động căn khung hình
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

  /// Cho phép các màn hình khác (như HomeShellView) gọi reload qua GlobalKey
  void reloadLocations() {
    _loadMasterData();
    if (_showSharedLocations) {
      _loadSharedLocations();
    }
  }

  /// Bật/tắt chế độ hiển thị điểm chia sẻ (TASK 023)
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

  /// Tải danh sách điểm được chia sẻ còn hiệu lực
  Future<void> _loadSharedLocations() async {
    setState(() => _isLoadingShared = true);
    try {
      final res = await ApiService.getSharedLocations();
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

  /// Thuật toán gom cụm cho các điểm chia sẻ (TASK 023: Gom cụm tính riêng)
  List<_SharedLocationCluster> _clusterSharedLocations(List<SharedLocationPointModel> locations, double zoom) {
    if (locations.isEmpty) return [];

    if (zoom >= 16.5) {
      return locations
          .where((loc) => loc.latitude != 0.0 && loc.longitude != 0.0)
          .map((loc) => _SharedLocationCluster(
                center: LatLng(loc.latitude, loc.longitude),
                items: [loc],
              ))
          .toList();
    }

    final double threshold = 0.065 / math.pow(2, (zoom - 10).clamp(0.0, 10.0));
    final List<_SharedLocationCluster> clusters = [];

    for (final loc in locations) {
      if (loc.latitude == 0.0 && loc.longitude == 0.0) continue;
      final latLng = LatLng(loc.latitude, loc.longitude);

      _SharedLocationCluster? closestCluster;
      double minDistance = double.infinity;

      for (final cluster in clusters) {
        final dLat = cluster.center.latitude - latLng.latitude;
        final dLng = cluster.center.longitude - latLng.longitude;
        final dist = math.sqrt(dLat * dLat + dLng * dLng);

        if (dist < threshold && dist < minDistance) {
          minDistance = dist;
          closestCluster = cluster;
        }
      }

      if (closestCluster != null) {
        closestCluster.items.add(loc);
      } else {
        clusters.add(_SharedLocationCluster(center: latLng, items: [loc]));
      }
    }

    return clusters;
  }

  /// Nhập 1 điểm chia sẻ cụ thể vào danh bạ của tôi
  Future<void> _handleImportSingleSharedPoint(SharedLocationPointModel point) async {
    bool replaceExisting = false;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text(
                'Nhập vị trí vào của tôi',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Lưu vị trí khách hàng "${point.customerName}" vào danh sách vị trí đã lưu của bạn.',
                    style: const TextStyle(fontSize: 14, color: Color(0xFF334155)),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    key: const Key('switch_replace_existing_single'),
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Ghi đè nếu đã tồn tại vị trí',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    value: replaceExisting,
                    activeThumbColor: AppButtons.navy,
                    onChanged: (val) => setDialogState(() => replaceExisting = val),
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
                  key: const Key('btn_confirm_import_single_point'),
                  style: AppButtons.primary(minHeight: 48, borderRadius: 10),
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: const Text('NHẬP VỊ TRÍ'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirm == true) {
      try {
        final res = await ApiService.importSharedLocations(
          point.shareId,
          customerIds: [point.customerId],
          all: false,
          replaceExisting: replaceExisting,
        );
        final imported = res['importedCount'] ?? 0;
        final skipped = res['skippedCount'] ?? 0;

        if (mounted) {
          if (imported > 0) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Đã nhập vị trí vào danh bạ của bạn thành công!'),
                backgroundColor: Color(0xFF0F172A),
                behavior: SnackBarBehavior.floating,
              ),
            );
            setState(() => _selectedSharedLocation = null);
            _loadMasterData();
          } else if (skipped > 0) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Khách hàng này đã có vị trí trong danh bạ của bạn (bỏ qua).'),
                backgroundColor: Color(0xFF0F172A),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.toString().replaceAll('Exception: ', '')),
              backgroundColor: const Color(0xFFDC2626),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  /// Tương thích ngược với lời gọi cũ từ HomeShellView
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

  /// Căn chỉnh khung hình bản đồ bao quát các điểm đã lưu
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

  /// Thuật toán gom cụm marker (Clustering) theo khoảng cách tại mức zoom hiện tại
  List<_LocationCluster> _clusterLocations(List<MasterSavedLocationModel> locations, double zoom) {
    if (locations.isEmpty) return [];

    // Khi zoom rất gần (zoom >= 16.5), không gom cụm để hiện từng điểm riêng biệt
    if (zoom >= 16.5) {
      return locations
          .where((loc) => loc.hasValidCoordinates)
          .map((loc) => _LocationCluster(
                center: LatLng(loc.latitude, loc.longitude),
                items: [loc],
              ))
          .toList();
    }

    // Ngưỡng khoảng cách tính theo độ kinh/vĩ dựa theo mức zoom
    final double threshold = 0.065 / math.pow(2, (zoom - 10).clamp(0.0, 10.0));
    final List<_LocationCluster> clusters = [];

    for (final loc in locations) {
      if (!loc.hasValidCoordinates) continue;
      final latLng = LatLng(loc.latitude, loc.longitude);

      _LocationCluster? closestCluster;
      double minDistance = double.infinity;

      for (final cluster in clusters) {
        final dLat = cluster.center.latitude - latLng.latitude;
        final dLng = cluster.center.longitude - latLng.longitude;
        final dist = math.sqrt(dLat * dLat + dLng * dLng);

        if (dist < threshold && dist < minDistance) {
          minDistance = dist;
          closestCluster = cluster;
        }
      }

      if (closestCluster != null) {
        closestCluster.items.add(loc);
      } else {
        clusters.add(_LocationCluster(center: latLng, items: [loc]));
      }
    }

    return clusters;
  }

  /// Tối ưu hiệu năng gom cụm marker (TASK 019 - Mục B.4):
  /// 1. Chỉ tính toán cho các điểm nằm trong khung nhìn (visibleBounds + 15% margin)
  /// 2. Cache kết quả gom cụm theo mức zoom và khung nhìn để tránh tính toán lại liên tục
  void _recomputeClusters(double zoom, LatLngBounds? bounds) {
    if (!mounted) return;
    if (bounds == null) {
      final res = _clusterLocations(_savedLocations, zoom);
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

    final computed = _clusterLocations(visible, zoom);
    _clusterCache[cacheKey] = computed;
    if (_clusterCache.length > 50) {
      _clusterCache.remove(_clusterCache.keys.first);
    }

    setState(() => _cachedClusters = computed);
  }

  /// Lấy tọa độ GPS hiện tại của Shipper
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

        // Nếu shipper chưa có điểm nào được lưu, di chuyển đến vị trí shipper
        if (_savedLocations.isEmpty && _isMapReady) {
          _mapController.move(_shipperLocation!, 16.0);
        }
      }
    } catch (_) {
      if (mounted) setState(() => _isLocatingShipper = false);
    }
  }

  /// Chuyển đổi giữa 3 loại bản đồ nền
  void _switchMapType() {
    setState(() {
      _currentMapType = (_currentMapType + 1) % 3;
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

  /// Bắt đầu chế độ ghim vị trí mới bằng tâm ngắm (luồng Ghim vị trí mới)
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

  /// Hủy chế độ ghim vị trí mới
  void _cancelPinningMode() {
    setState(() {
      _repinTarget = null;
      _isPinningMode = false;
      _addressSearchCtrl.clear();
      _addressSearchResults = [];
    });
  }

  /// Tìm kiếm địa chỉ bằng Geocoding
  void _onAddressSearchChanged(String query) {
    _searchDebounceTimer?.cancel();
    if (query.trim().length < 3) {
      setState(() => _addressSearchResults = []);
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
        if (mounted) setState(() => _isSearchingAddress = false);
      }
    });
  }

  /// Chọn kết quả tìm kiếm và bay bản đồ tới đó
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

  /// Mở hộp thoại "Gán cho số điện thoại nào?" (TASK: MASTER-MAP-014 Điểm 3, 4, 5 & TASK 019 Mục A)
  Future<void> _showAssignPhoneDialog(LatLng targetCoord) async {
    final phoneCtrl = TextEditingController(text: _repinTarget?.customerPhone ?? '');
    final nameCtrl = TextEditingController(text: _repinTarget?.customerName ?? '');
    final notesCtrl = TextEditingController(text: _repinTarget?.identificationNotes ?? '');

    String normalizedPhone = _repinTarget != null ? normalizeCustomerPhone(_repinTarget!.customerPhone) : '';
    List<CustomerDirectoryModel> suggestions = List.from(_directoryCustomers);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            void updateFilter(String query) {
              final clean = normalizeCustomerPhone(query);
              setSheetState(() {
                normalizedPhone = clean;
                if (query.trim().isEmpty) {
                  suggestions = List.from(_directoryCustomers);
                } else {
                  suggestions = _directoryCustomers.where((c) {
                    final pMatch = c.phoneNumber.contains(clean) || c.phoneNumber.contains(query.trim());
                    final nMatch = c.fullName.toLowerCase().contains(query.trim().toLowerCase());
                    return pMatch || nMatch;
                  }).toList();
                }
              });
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 16,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Thanh gạt
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFFCBD5E1),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Tiêu đề
                    const Row(
                      children: [
                        Icon(Icons.add_location_alt_rounded, color: Color(0xFF2563EB), size: 24),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Gán cho số điện thoại nào?',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tọa độ: ${targetCoord.latitude.toStringAsFixed(6)}, ${targetCoord.longitude.toStringAsFixed(6)}',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 16),

                    // Banner thông báo ghim lại cho khách đã chọn (TASK 019 - Mục A.2)
                    if (_repinTarget != null) ...[
                      Container(
                        key: const ValueKey('repin_customer_banner'),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFBFDBFE)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline_rounded, size: 18, color: Color(0xFF2563EB)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Đang ghim lại cho: ${_repinTarget!.customerName} - ${_repinTarget!.customerPhone}',
                                key: const ValueKey('repin_customer_banner_text'),
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1E40AF),
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            TextButton(
                              key: const ValueKey('btn_change_repin_phone'),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              onPressed: () {
                                setSheetState(() {
                                  _repinTarget = null;
                                  phoneCtrl.clear();
                                  nameCtrl.clear();
                                  notesCtrl.clear();
                                  normalizedPhone = '';
                                  suggestions = List.from(_directoryCustomers);
                                });
                              },
                              child: const Text(
                                'Đổi số',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF2563EB),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Ô nhập SĐT
                    const Text(
                      'SỐ ĐIỆN THOẠI KHÁCH HÀNG *',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      key: const Key('input_assign_phone'),
                      controller: phoneCtrl,
                      autofocus: _repinTarget == null,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        hintText: 'Nhập SĐT (VD: 0908911111)',
                        prefixIcon: const Icon(Icons.phone_rounded, color: Color(0xFF2563EB)),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF2563EB), width: 2),
                        ),
                      ),
                      onChanged: updateFilter,
                    ),

                    // Nhãn số đã chuẩn hóa
                    if (normalizedPhone.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Số đã chuẩn hóa: $normalizedPhone (${normalizedPhone.length} số)',
                        style: TextStyle(
                          fontSize: 12,
                          color: normalizedPhone.length == 10 ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],

                    // Danh sách gợi ý số điện thoại trong danh bạ
                    if (suggestions.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      const Text(
                        'Gợi ý từ danh bạ:',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 4),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 120),
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: suggestions.length > 3 ? 3 : suggestions.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (itemCtx, index) {
                            final cust = suggestions[index];
                            return ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              leading: CircleAvatar(
                                radius: 14,
                                backgroundColor: const Color(0xFFE0E7FF),
                                child: Text(
                                  cust.fullName.isNotEmpty ? cust.fullName[0].toUpperCase() : 'K',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                                ),
                              ),
                              title: Text(cust.fullName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                              subtitle: Text(cust.phoneNumber, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                              trailing: cust.hasLocation
                                  ? const Text('Đã có vị trí', style: TextStyle(fontSize: 10, color: Color(0xFF10B981)))
                                  : null,
                              onTap: () {
                                phoneCtrl.text = cust.phoneNumber;
                                nameCtrl.text = cust.fullName;
                                updateFilter(cust.phoneNumber);
                              },
                            );
                          },
                        ),
                      ),
                    ],

                    const SizedBox(height: 14),

                    // Tên khách hàng (tùy chọn)
                    const Text(
                      'TÊN KHÁCH HÀNG (TÙY CHỌN)',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: nameCtrl,
                      decoration: InputDecoration(
                        hintText: 'Mặc định: Khách [SĐT]',
                        prefixIcon: const Icon(Icons.person_outline_rounded, color: Color(0xFF64748B)),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Ghi chú đặc điểm vị trí / cổng nhà
                    const Text(
                      'GHI CHÚ VỊ TRÍ / CỔNG NHÀ (TÙY CHỌN)',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: notesCtrl,
                      maxLines: 2,
                      decoration: InputDecoration(
                        hintText: 'VD: Cổng sắt xanh, hẻm cạnh tạp hóa',
                        prefixIcon: const Icon(Icons.edit_note_rounded, color: Color(0xFF64748B)),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Nút bấm xác nhận LƯU
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        key: const Key('btn_confirm_save_location'),
                        style: AppButtons.primary(minHeight: 50, borderRadius: 12),
                        onPressed: () async {
                          final rawPhone = phoneCtrl.text.trim();
                          if (rawPhone.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Vui lòng nhập số điện thoại khách hàng')),
                            );
                            return;
                          }

                          final clean = normalizeCustomerPhone(rawPhone);
                          if (clean.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Số điện thoại không hợp lệ')),
                            );
                            return;
                          }

                          // Cảnh báo nếu số khác 10 số
                          if (clean.length != 10) {
                            final proceed = await showDialog<bool>(
                              context: context,
                              builder: (dlgCtx) => AlertDialog(
                                title: const Row(
                                  children: [
                                    Icon(Icons.warning_amber_rounded, color: Color(0xFFF59E0B)),
                                    SizedBox(width: 8),
                                    Text('Cảnh báo số điện thoại', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                                content: Text('Số này có ${clean.length} chữ số ($clean), bạn có chắc muốn tiếp tục?'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(dlgCtx, false),
                                    child: const Text('HỦY'),
                                  ),
                                  ElevatedButton(
                                    style: AppButtons.primary(),
                                    onPressed: () => Navigator.pop(dlgCtx, true),
                                    child: const Text('TIẾP TỤC'),
                                  ),
                                ],
                              ),
                            );
                            if (proceed != true) return;
                          }

                          if (!sheetCtx.mounted) return;
                          Navigator.pop(sheetCtx);
                          await _processSaveLocation(
                            phone: clean,
                            fullName: nameCtrl.text.trim(),
                            notes: notesCtrl.text.trim(),
                            targetCoord: targetCoord,
                            knownCustomerId: _repinTarget?.customerId,
                          );
                        },
                        child: const Text(
                          'LƯU VỊ TRÍ NÀY',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// Xử lý logic nghiệp vụ lưu vị trí theo TASK: MASTER-MAP-014 Điểm 4 & 5
  Future<void> _processSaveLocation({
    required String phone,
    required String fullName,
    required String notes,
    required LatLng targetCoord,
    String? knownCustomerId,
  }) async {
    setState(() => _isLoading = true);

    String? customerId = knownCustomerId;
    String customerDisplayName = fullName.isNotEmpty ? fullName : 'Khách $phone';
    bool isNewlyCreated = false;

    try {
      if (customerId == null) {
        // 1. Tra cứu khách hàng theo SĐT xem đã có trong CSDL chưa
        final lookup = await ApiService.lookupCustomerLocationByPhone(phone);

        if (lookup != null && lookup['customer'] != null) {
          // Khách hàng đã tồn tại trong CSDL
          final cust = lookup['customer'] as Map<String, dynamic>;
          customerId = cust['id']?.toString() ?? '';
          customerDisplayName = cust['fullName']?.toString() ?? customerDisplayName;

          final hasOldLocation = lookup['hasSavedLocation'] == true;

          if (hasOldLocation) {
            // TASK: MASTER-MAP-014 Điểm 5: Khách đã có vị trí cũ -> Hỏi xác nhận thay thế
            if (!mounted) return;
            final confirmReplace = await showDialog<bool>(
              context: context,
              builder: (dlgCtx) => AlertDialog(
                title: const Row(
                  children: [
                    Icon(Icons.help_outline_rounded, color: Color(0xFF2563EB)),
                    SizedBox(width: 8),
                    Text('Thay vị trí cũ bằng vị trí này?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ],
                ),
                content: Text(
                  'Khách hàng $customerDisplayName ($phone) đã có vị trí đã lưu trước đó.\n\n'
                  'Bạn có chắc muốn thay thế vị trí cũ bằng vị trí này không?\n'
                  '(Lịch sử vị trí cũ vẫn được lưu trữ đối soát đầy đủ).',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dlgCtx, false),
                    child: const Text('HỦY', style: TextStyle(color: Color(0xFF64748B))),
                  ),
                  ElevatedButton(
                    style: AppButtons.primary(),
                    onPressed: () => Navigator.pop(dlgCtx, true),
                    child: const Text('THAY VỊ TRÍ CŨ'),
                  ),
                ],
              ),
            );

            if (confirmReplace != true) {
              if (mounted) setState(() => _isLoading = false);
              return;
            }
          }
        } else {
          // Khách hàng chưa có trong hệ thống -> Tự tạo hồ sơ khách hàng mới (TASK: MASTER-MAP-014 Điểm 4)
          final preferredAreaId = await ApiService.getPreferredAreaId();
          final newCust = await ApiService.createCustomer(
            phoneNumber: phone,
            fullName: fullName.isNotEmpty ? fullName : null,
            areaId: preferredAreaId,
          );
          customerId = newCust.id;
          customerDisplayName = newCust.fullName;
          isNewlyCreated = true;
        }
      }

      // 2. Ghi tọa độ tâm ngắm vào saved_locations (Vị trí lưu là ĐÃ XÁC NHẬN)
      await ApiService.updateCustomerLocationAndPhoto(
        customerId: customerId,
        latitude: targetCoord.latitude,
        longitude: targetCoord.longitude,
        gpsAccuracy: 0.0,
        identificationNotes: notes.isNotEmpty ? notes : 'Ghim trực tiếp từ Bản đồ chính',
      );

      // 3. Tải lại danh sách vị trí đã lưu để marker hiện ngay trên bản đồ chính
      await _loadMasterData();

      if (!mounted) return;

      setState(() {
        _isPinningMode = false;
        _isLoading = false;
      });

      // Di chuyển bản đồ đến điểm vừa ghim
      _mapController.move(targetCoord, 17.5);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã ghim vị trí ĐÃ XÁC NHẬN cho $customerDisplayName!'),
          backgroundColor: const Color(0xFF10B981),
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);

      // TASK: MASTER-MAP-014B Điểm 2: Nếu tạo khách xong mà lưu vị trí lỗi -> Báo rõ kèm nút thử lại
      if (isNewlyCreated || knownCustomerId != null) {
        final errText = 'Đã tạo khách $phone nhưng chưa lưu được vị trí, thử lại';

        // 1. Hiện SnackBar có nút thử lại
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errText),
            backgroundColor: const Color(0xFFEF4444),
            duration: const Duration(seconds: 12),
            action: SnackBarAction(
              label: 'THỬ LẠI',
              textColor: Colors.white,
              onPressed: () {
                _processSaveLocation(
                  phone: phone,
                  fullName: fullName,
                  notes: notes,
                  targetCoord: targetCoord,
                  knownCustomerId: customerId,
                );
              },
            ),
          ),
        );

        // 2. Hiện AlertDialog thông báo rõ ràng kèm nút thử lại, không để im lặng
        await showDialog<void>(
          context: context,
          builder: (dlgCtx) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444)),
                SizedBox(width: 8),
                Expanded(
                  child: Text('Lưu vị trí không thành công', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            content: Text('$errText.\n\nChi tiết lỗi: $e'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dlgCtx),
                child: const Text('ĐÓNG', style: TextStyle(color: Color(0xFF64748B))),
              ),
              ElevatedButton.icon(
                style: AppButtons.primary(),
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('THỬ LẠI'),
                onPressed: () {
                  Navigator.pop(dlgCtx);
                  _processSaveLocation(
                    phone: phone,
                    fullName: fullName,
                    notes: notes,
                    targetCoord: targetCoord,
                    knownCustomerId: customerId,
                  );
                },
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi lưu vị trí: $e'),
            backgroundColor: const Color(0xFFEF4444),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  /// Mở ứng dụng gọi điện thoại ngoài
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
    // Tính toán các cụm marker (Clusters) theo zoom hiện tại hoặc dùng kết quả đã cache (TASK 019)
    final clusters = _cachedClusters.isNotEmpty
        ? _cachedClusters
        : _clusterLocations(_savedLocations, _currentZoom);

    // Tính toán các cụm marker điểm được chia sẻ nếu đang bật (TASK 023)
    final sharedClusters = _showSharedLocations
        ? _clusterSharedLocations(_sharedLocations, _currentZoom)
        : <_SharedLocationCluster>[];

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
            // 1. BẢN ĐỒ FLUTTER MAP (CÔ LẬP RENDER VỚI REPAINT BOUNDARY)
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
                      // Chạm vào vùng bản đồ trống bên ngoài thẻ để đóng thẻ (TASK 017 - Mục B.2 & TASK 023)
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
                      // Debounce 150ms khi đang kéo bản đồ (TASK 019 Mục B.4)
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
                    // Lớp ngói bản đồ hỗ trợ Disk Cache tối đa 200MB, panBuffer 1, keepBuffer 2 (TASK 019)
                    TileLayer(
                      urlTemplate: _getUrlTemplate(),
                      subdomains: _getSubdomains(),
                      userAgentPackageName: 'com.deliverymarker.mobile',
                      maxZoom: 19,
                      panBuffer: 1,
                      keepBuffer: 2,
                      tileProvider: _tileProvider,
                    ),

              // Marker vị trí GPS thực tế của Shipper (chấm xanh radar)
              if (_shipperLocation != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _shipperLocation!,
                      width: 24,
                      height: 24,
                      child: Container(
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
                  ],
                ),

              // MarkerLayer: Danh sách các marker / cụm marker (Chỉ hiện khi KHÔNG ở chế độ tâm ngắm)
              if (!_isPinningMode)
                MarkerLayer(
                  markers: clusters.map((cluster) {
                    final isCluster = cluster.items.length > 1;

                    if (isCluster) {
                      // MARKER CỤM (CLUSTER BADGE)
                      final count = cluster.items.length;
                      return Marker(
                        point: cluster.center,
                        width: 48,
                        height: 48,
                        child: GestureDetector(
                          onTap: () {
                            _mapController.move(cluster.center, (_currentZoom + 2.5).clamp(1.0, 18.0));
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              border: Border.all(color: Colors.white, width: 3),
                              boxShadow: const [
                                BoxShadow(color: Color(0x662563EB), blurRadius: 8, offset: Offset(0, 3)),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                '$count',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    } else {
                      // MARKER ĐƠN LẺ (SINGLE LOCATION PIN - ĐÃ XÁC NHẬN)
                      final item = cluster.items.first;
                      final isSelected = _selectedLocation?.id == item.id;

                      return Marker(
                        point: cluster.center,
                        width: isSelected ? 48 : 40,
                        height: isSelected ? 48 : 40,
                        child: GestureDetector(
                          onTap: () {
                            setState(() => _selectedLocation = item);
                            _mapController.move(cluster.center, 17.0);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981), // Xanh lá: ĐÃ XÁC NHẬN
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white,
                                width: isSelected ? 3 : 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: isSelected ? const Color(0x8010B981) : Colors.black26,
                                  blurRadius: isSelected ? 8 : 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Icon(
                                Icons.check_circle_rounded,
                                color: Colors.white,
                                size: isSelected ? 24 : 20,
                              ),
                            ),
                          ),
                        ),
                      );
                    }
                  }).toList(),
                ),

              // MarkerLayer: Danh sách các marker / cụm marker ĐƯỢC CHIA SẺ (màu tím #7C3AED, TASK 023)
              if (!_isPinningMode && _showSharedLocations)
                MarkerLayer(
                  markers: sharedClusters.map((cluster) {
                    final isCluster = cluster.items.length > 1;

                    if (isCluster) {
                      // MARKER CỤM CHIA SẺ (PURPLE CLUSTER BADGE)
                      final count = cluster.items.length;
                      return Marker(
                        point: cluster.center,
                        width: 48,
                        height: 48,
                        child: GestureDetector(
                          onTap: () {
                            _mapController.move(cluster.center, (_currentZoom + 2.5).clamp(1.0, 18.0));
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                colors: [Color(0xFF7C3AED), Color(0xFF6D28D9)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              border: Border.all(color: Colors.white, width: 3),
                              boxShadow: const [
                                BoxShadow(color: Color(0x667C3AED), blurRadius: 8, offset: Offset(0, 3)),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                '$count',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    } else {
                      // MARKER ĐƠN LẺ CHIA SẺ (PURPLE PIN)
                      final item = cluster.items.first;
                      final isSelected = _selectedSharedLocation?.customerId == item.customerId;

                      return Marker(
                        point: cluster.center,
                        width: isSelected ? 48 : 40,
                        height: isSelected ? 48 : 40,
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedLocation = null;
                              _selectedSharedLocation = item;
                            });
                            _mapController.move(cluster.center, 17.0);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            decoration: BoxDecoration(
                              color: const Color(0xFF7C3AED), // Tím: ĐƯỢC CHIA SẺ
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white,
                                width: isSelected ? 3 : 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: isSelected ? const Color(0x807C3AED) : Colors.black26,
                                  blurRadius: isSelected ? 8 : 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Icon(
                                Icons.share_location_rounded,
                                color: Colors.white,
                                size: isSelected ? 24 : 20,
                              ),
                            ),
                          ),
                        ),
                      );
                    }
                  }).toList(),
                ),
            ],
          ),
        ),
      ),

          // 2. CHẾ ĐỘ TÂM NGẮM (CROSSHAIR PINNING MODE)
          if (_isPinningMode) ...[
            // Icon tâm ngắm cố định giữa màn hình
            Center(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 36),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A).withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Kéo bản đồ để đặt tâm ghim',
                        style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Icon(Icons.location_pin, size: 48, color: Color(0xFFEF4444)),
                  ],
                ),
              ),
            ),

            // Thanh tìm kiếm địa chỉ Geocoding phía trên
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
                  child: Column(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
                        ),
                        child: TextField(
                          controller: _addressSearchCtrl,
                          decoration: InputDecoration(
                            hintText: 'Tìm địa chỉ (VD: Nguyễn Xiển, Thủ Đức)...',
                            prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF2563EB)),
                            suffixIcon: _isSearchingAddress
                                ? const Padding(
                                    padding: EdgeInsets.all(12),
                                    child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                                  )
                                : (_addressSearchCtrl.text.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.clear, size: 18),
                                        onPressed: () {
                                          _addressSearchCtrl.clear();
                                          setState(() => _addressSearchResults = []);
                                        },
                                      )
                                    : null),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          onChanged: _onAddressSearchChanged,
                        ),
                      ),

                      // Danh sách kết quả gợi ý địa chỉ Geocoding
                      if (_addressSearchResults.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
                          ),
                          child: ListView.separated(
                            shrinkWrap: true,
                            padding: EdgeInsets.zero,
                            itemCount: _addressSearchResults.length > 4 ? 4 : _addressSearchResults.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (ctx, idx) {
                              final item = _addressSearchResults[idx];
                              return ListTile(
                                dense: true,
                                leading: const Icon(Icons.place_outlined, color: Color(0xFF2563EB), size: 18),
                                title: Text(item.displayName, style: const TextStyle(fontSize: 12)),
                                onTap: () => _selectSearchResult(item),
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),

            // Thanh điều khiển ghim dưới đáy
            Positioned(
              left: 16,
              right: 16,
              bottom: 20,
              child: SafeArea(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4))],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: AppButtons.secondary(minHeight: 48, borderRadius: 10),
                          onPressed: _cancelPinningMode,
                          child: const Text('HỦY'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          key: const Key('btn_confirm_crosshair'),
                          style: AppButtons.primary(minHeight: 48, borderRadius: 10),
                          onPressed: () => _showAssignPhoneDialog(_crosshairCoord),
                          child: const Text('XÁC NHẬN VỊ TRÍ NÀY'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],

          // 3. THANH ĐIỀU HƯỚNG TRÊN CÙNG KHI Ở CHẾ ĐỘ XEM BÌNH THƯỜNG (TASK 017: THU MẢNH CAO <= 52PX, CÔ LẬP REPAINT BOUNDARY)
          if (!_isPinningMode)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: RepaintBoundary(
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
                    child: Container(
                      height: 48,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.96),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2))],
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.pin_drop_rounded, color: Color(0xFF2563EB), size: 20),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Bản đồ vị trí đã lưu',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          // Nút bật/tắt Điểm được chia sẻ (TASK 023)
                          IconButton(
                            key: const Key('toggle_shared_locations'),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                            icon: _isLoadingShared
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF7C3AED)),
                                  )
                                : Icon(
                                    _showSharedLocations ? Icons.share_location_rounded : Icons.share_location_outlined,
                                    color: _showSharedLocations ? const Color(0xFF7C3AED) : const Color(0xFF64748B),
                                    size: 20,
                                  ),
                            tooltip: _showSharedLocations ? 'Tắt điểm chia sẻ' : 'Bật điểm chia sẻ',
                            onPressed: () => _toggleSharedLocations(!_showSharedLocations),
                          ),
                          // Nút đổi nền bản đồ
                          IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                            icon: const Icon(Icons.layers_rounded, color: Color(0xFF64748B), size: 20),
                            tooltip: 'Đổi kiểu bản đồ',
                            onPressed: _switchMapType,
                          ),
                          // Nút làm mới
                          IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF64748B), size: 20),
                            tooltip: 'Tải lại vị trí',
                            onPressed: _loadMasterData,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // Banner cảnh báo điểm chia sẻ ngoài khu vực (TASK 023)
          if (!_isPinningMode && _showSharedLocations && !_isOutOfAreaBannerDismissed && _skippedOutOfAreaCount > 0)
            Positioned(
              key: const Key('banner_out_of_area_warning'),
              top: 62,
              left: 14,
              right: 14,
              child: SafeArea(
                child: Material(
                  elevation: 4,
                  borderRadius: BorderRadius.circular(10),
                  color: const Color(0xFFFEF3C7),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: Color(0xFFD97706), size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '$_skippedOutOfAreaCount điểm không hiển thị vì ngoài khu vực của bạn',
                            style: const TextStyle(color: Color(0xFF92400E), fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ),
                        IconButton(
                          key: const Key('btn_close_out_of_area_banner'),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: const Icon(Icons.close_rounded, size: 16, color: Color(0xFF92400E)),
                          onPressed: () => setState(() => _isOutOfAreaBannerDismissed = true),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // Legend phân biệt màu sắc marker: Xanh (Của tôi) - Tím (Được chia sẻ) (TASK 023)
          if (!_isPinningMode && _showSharedLocations)
            Positioned(
              top: (!_isOutOfAreaBannerDismissed && _skippedOutOfAreaCount > 0) ? 112 : 62,
              left: 14,
              child: SafeArea(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'Của tôi',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(color: Color(0xFF7C3AED), shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'Được chia sẻ',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                      ),
                    ],
                  ),
                ),
              ),
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

          // 4. CÁC NÚT ĐIỀU KHIỂN NỔI BÊN PHẢI (GPS VÀ PHÓNG TO/THU NHỎ)
          if (!_isPinningMode)
            Positioned(
              right: 14,
              top: 100,
              child: Column(
                children: [
                  FloatingActionButton.small(
                    heroTag: 'master_map_gps',
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF2563EB),
                    elevation: 3,
                    onPressed: _getShipperLocation,
                    child: _isLocatingShipper
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.my_location_rounded),
                  ),
                  const SizedBox(height: 8),
                  FloatingActionButton.small(
                    heroTag: 'master_map_fit_bounds',
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF475569),
                    elevation: 3,
                    onPressed: _fitLocationsBounds,
                    child: const Icon(Icons.fit_screen_rounded),
                  ),
                ],
              ),
            ),

          // 5. THẺ CHI TIẾT ĐIỂM ĐÃ LƯU (CÔ LẬP VỚI REPAINT BOUNDARY)
          if (!_isPinningMode && _selectedLocation != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: RepaintBoundary(
                child: PointDetailBottomSheet(
                  customerId: _selectedLocation!.customerId,
                  customerName: _selectedLocation!.customerName,
                  customerPhone: _selectedLocation!.customerPhone,
                  customerAddress: _selectedLocation!.customerAddress,
                  locationStatusText: 'ĐÃ XÁC NHẬN',
                  statusBadgeBg: const Color(0xFFDCFCE7),
                  statusBadgeTextColor: const Color(0xFF15803D),
                  statusBadgeIcon: Icons.check_circle_rounded,
                  identificationNotes: _selectedLocation!.identificationNotes,
                  latitude: _selectedLocation!.latitude,
                  longitude: _selectedLocation!.longitude,
                  initialPhotos: _selectedLocation!.photos,
                  legacyImageUrl: _selectedLocation!.imageUrl,
                  onCall: () => _makePhoneCall(_selectedLocation!.customerPhone),
                  onDirections: () {
                    ApiService.openExternalNavigation(
                      _selectedLocation!.latitude,
                      _selectedLocation!.longitude,
                    );
                  },
                  onRepin: () {
                    final loc = _selectedLocation!;
                    setState(() {
                      _selectedLocation = null;
                      _repinTarget = loc;
                      _crosshairCoord = LatLng(loc.latitude, loc.longitude);
                      _isPinningMode = true;
                    });
                    try {
                      _mapController.move(_crosshairCoord, 17.5);
                    } catch (_) {}
                  },
                  onPhotosUpdated: (updatedPhotos) {
                    setState(() {
                      _selectedLocation = _selectedLocation!.copyWith(
                        photos: updatedPhotos,
                        photoCount: updatedPhotos.length,
                      );
                      final idx = _savedLocations.indexWhere((l) => l.customerId == _selectedLocation!.customerId);
                      if (idx != -1) {
                        _savedLocations[idx] = _savedLocations[idx].copyWith(
                          photos: updatedPhotos,
                          photoCount: updatedPhotos.length,
                        );
                      }
                    });
                  },
                  onClose: () => setState(() => _selectedLocation = null),
                ),
              ),
            ),

          // 5B. THẺ CHI TIẾT ĐIỂM ĐƯỢC CHIA SẺ (READ-ONLY, KHÔNG CÓ GHIM LẠI / XÓA) (TASK 023)
          if (!_isPinningMode && _selectedSharedLocation != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: RepaintBoundary(
                child: _buildSharedPointBottomSheet(_selectedSharedLocation!),
              ),
            ),

          // 6. CỘT ICON DỌC Ở MÉP PHẢI PHÍA DƯỚI (VÙNG NGÓN CÁI, CÔ LẬP REPAINT BOUNDARY) (TASK 017 - MỤC A & TASK 019)
          // Từ dưới lên: Ghim vị trí mới (60px, #2563EB) | Tạo ca (52px, #0F172A) | Ca làm việc (52px, trắng viền xám)
          // Khoảng cách >= 12px, có Tooltip & Semantics label đầy đủ, ẩn khi mở tâm ngắm hoặc mở thẻ chi tiết
          if (!_isPinningMode && _selectedLocation == null && _selectedSharedLocation == null)
            Positioned(
              right: 16,
              bottom: 20,
              child: RepaintBoundary(
                child: SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // 1. Nút "Ca làm việc" (trên cùng của cột, nút tròn 52px, nền trắng viền xám)
                      Semantics(
                        label: 'Ca làm việc',
                        button: true,
                        child: Tooltip(
                          message: 'Ca làm việc',
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              key: const Key('btn_open_shift_picker'),
                              borderRadius: BorderRadius.circular(26),
                              onTap: _handleOpenShiftPicker,
                              child: Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: const Color(0xFFCBD5E1), width: 1.5),
                                  boxShadow: const [
                                    BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 3)),
                                  ],
                                ),
                                child: const Center(
                                  child: Icon(
                                    Icons.work_history_rounded,
                                    size: 24,
                                    color: AppButtons.navy,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // 2. Nút "Tạo ca" (ở giữa cột, nút tròn 52px, nền Navy #0F172A)
                      Semantics(
                        label: 'Tạo ca',
                        button: true,
                        child: Tooltip(
                          message: 'Tạo ca',
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              key: const Key('btn_create_shift_from_map'),
                              borderRadius: BorderRadius.circular(26),
                              onTap: _handleCreateShift,
                              child: Container(
                                width: 52,
                                height: 52,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF0F172A),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 3)),
                                  ],
                                ),
                                child: const Center(
                                  child: Icon(
                                    Icons.add_task_rounded,
                                    size: 24,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // 3. Nút "Ghim vị trí mới" (dưới cùng của cột, to nhất 60px, màu xanh đen #0F172A)
                      Semantics(
                        label: 'Ghim vị trí mới',
                        button: true,
                        child: Tooltip(
                          message: 'Ghim vị trí mới',
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              key: const Key('btn_pin_new_location'),
                              borderRadius: BorderRadius.circular(30),
                              onTap: _startPinningMode,
                              child: Container(
                                width: 60,
                                height: 60,
                                decoration: const BoxDecoration(
                                  color: AppButtons.navy,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(color: Color(0x660F172A), blurRadius: 10, offset: Offset(0, 4)),
                                  ],
                                ),
                                child: const Center(
                                  child: Icon(
                                    Icons.add_location_alt_rounded,
                                    size: 28,
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

          // Loading overlay
          if (_isLoading)
            const IgnorePointer(
              child: Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    ),
  );
  }

  /// Thẻ chi tiết điểm được chia sẻ (Read-only, không có nút Ghim lại / Xóa) (TASK 023)
  Widget _buildSharedPointBottomSheet(SharedLocationPointModel point) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, -2)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thanh gạt drag handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header: Badge tím "Chia sẻ từ [tên]" + nút đóng
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3E8FF),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFDDD6FE)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.share_rounded, size: 14, color: Color(0xFF7C3AED)),
                      const SizedBox(width: 6),
                      Text(
                        'Chia sẻ từ ${point.sharedByName}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF7C3AED),
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF64748B)),
                  onPressed: () => setState(() => _selectedSharedLocation = null),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Tên khách hàng + Số điện thoại
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    point.customerName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  point.customerPhone,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),

            // Địa chỉ khách hàng
            if (point.customerAddress.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.place_outlined, size: 16, color: Color(0xFF64748B)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      point.customerAddress,
                      style: const TextStyle(fontSize: 13, color: Color(0xFF334155)),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],

            // Ghi chú định danh
            if (point.identificationNotes.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.notes_rounded, size: 16, color: Color(0xFF64748B)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      point.identificationNotes,
                      style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic, color: Color(0xFF475569)),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],

            // Dải ảnh (nếu có ảnh từ người chia sẻ)
            if (point.photos.isNotEmpty || (point.imageUrl != null && point.imageUrl!.isNotEmpty)) ...[
              const SizedBox(height: 10),
              CustomerPhotosStripWidget(
                customerId: point.customerId,
                customerName: point.customerName,
                initialPhotos: point.photos,
                legacyImageUrl: point.imageUrl,
                canAddPhoto: false,
                canDeletePhoto: false,
                height: 100,
              ),
            ],

            const SizedBox(height: 14),

            // Hàng nút hành động: GỌI | CHỈ ĐƯỜNG
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    key: const Key('btn_call_shared_point'),
                    style: AppButtons.secondary(minHeight: 48, borderRadius: 10),
                    icon: const Icon(Icons.phone_rounded, size: 18),
                    label: const Text('GỌI'),
                    onPressed: () => _makePhoneCall(point.customerPhone),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    key: const Key('btn_directions_shared_point'),
                    style: AppButtons.secondary(minHeight: 48, borderRadius: 10),
                    icon: const Icon(Icons.navigation_rounded, size: 18),
                    label: const Text('CHỈ ĐƯỜNG'),
                    onPressed: () {
                      ApiService.openExternalNavigation(point.latitude, point.longitude);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Nút "NHẬP VÀO CỦA TÔI"
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                key: const Key('btn_import_shared_point_to_mine'),
                style: AppButtons.primary(minHeight: 48, borderRadius: 10),
                icon: const Icon(Icons.download_rounded, size: 20),
                label: const Text('NHẬP VÀO CỦA TÔI', style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: () => _handleImportSingleSharedPoint(point),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
