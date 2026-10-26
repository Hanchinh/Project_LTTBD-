import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/order_model.dart';
import '../repositories/repository_provider.dart';
import '../services/api_service.dart';
import 'order_detail_view.dart';
import 'save_location_view.dart';
import 'order_list_view.dart';
import 'shift_list_view.dart';
import 'login_view.dart';

/// Màn hình Bản đồ Giao hàng Chính (Delivery Map View)
/// Được tối ưu trải nghiệm trực quan cho nhân viên giao hàng (kể cả người lớn tuổi):
/// - Chữ to, nút bấm lớn (vùng chạm >= 48px), tương phản cao.
/// - Bản đồ tương tác lớn ở trên, danh sách đơn hàng kéo lên từ dưới (bottom sheet).
/// - Thẻ chi tiết điểm giao hiển thị ngay trên ứng dụng khi chạm marker hoặc chọn đơn.
/// - Marker phân biệt rõ ràng vị trí shipper (xanh lam) và điểm giao hàng (đỏ/cam).
/// - Xử lý an toàn quyền GPS, hỗ trợ bản đồ vệ tinh & chế độ xem danh sách cổ điển.
class DeliveryMapView extends StatefulWidget {
  const DeliveryMapView({super.key});

  @override
  State<DeliveryMapView> createState() => _DeliveryMapViewState();
}

class _DeliveryMapViewState extends State<DeliveryMapView> {
  // Controller bản đồ và bottom sheet
  final MapController _mapController = MapController();
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();

  // Dữ liệu đơn hàng
  List<OrderModel> _orders = [];
  bool _isLoadingOrders = true;
  String? _ordersErrorMessage;
  int _pendingSyncCount = 0;

  // Trạng thái đơn hàng đang được chọn xem thẻ chi tiết
  OrderModel? _selectedOrder;

  // Tìm kiếm khách hàng theo số điện thoại (FEATURE-ORDER-ENTRY-001)
  final TextEditingController _phoneSearchController = TextEditingController();
  bool _isSearchingPhone = false;
  Map<String, dynamic>? _searchedCustomerData;
  bool _isAddingOrder = false;

  // Dữ liệu GPS của nhân viên giao hàng
  LatLng? _shipperPosition;
  double? _gpsAccuracy;
  bool _isLoadingGps = false;
  String? _gpsErrorMessage;
  bool _isGpsServiceDisabled = false;
  bool _isGpsPermissionDeniedForever = false;

  // Kiểu bản đồ: 0 = Google Maps Đường phố, 1 = Google Hybrid Vệ tinh, 2 = OpenStreetMap Voyager
  int _currentMapType = 0;

  // Tọa độ trung tâm mặc định (Khu vực TP.HCM / Thủ Đức)
  static const LatLng _defaultCenter = LatLng(10.842215, 106.818123);

  @override
  void initState() {
    super.initState();
    _loadOrders();
    _getCurrentGpsLocation(isInitial: true);
  }

  @override
  void dispose() {
    _phoneSearchController.dispose();
    _sheetController.dispose();
    super.dispose();
  }

  // ===========================================================================
  // 1. TẢI ĐƠN HÀNG VÀ ĐỒNG BỘ OFFLINE
  // ===========================================================================

  Future<void> _loadOrders() async {
    setState(() {
      _isLoadingOrders = true;
      _ordersErrorMessage = null;
    });

    try {
      final orders = await RepositoryProvider.shift.getMyShiftOrders();
      if (!mounted) return;

      setState(() {
        _orders = orders;
        _isLoadingOrders = false;
        _ordersErrorMessage = null;
      });

      // Nếu đơn hàng đang chọn bị thay đổi hoặc làm mới, cập nhật lại đối tượng
      if (_selectedOrder != null) {
        final updatedSelected = orders.firstWhere(
          (o) => o.orderId == _selectedOrder!.orderId,
          orElse: () => _selectedOrder!,
        );
        setState(() {
          _selectedOrder = updatedSelected;
        });
      }

      // Kiểm tra queue offline
      _checkPendingSync();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingOrders = false;
        _ordersErrorMessage = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  Future<void> _checkPendingSync() async {
    try {
      final count = await RepositoryProvider.location.getPendingSyncCount();
      if (mounted) {
        setState(() => _pendingSyncCount = count);
      }
      if (count > 0) {
        await RepositoryProvider.location.syncOfflineQueue();
        final afterCount = await RepositoryProvider.location.getPendingSyncCount();
        if (mounted) {
          setState(() => _pendingSyncCount = afterCount);
        }
      }
    } catch (_) {
      // Giữ im lặng với lỗi kiểm tra đồng bộ ngầm
    }
  }

  // ===========================================================================
  // 2. XỬ LÝ ĐỊNH VỊ GPS VÀ QUYỀN TRUY CẬP
  // ===========================================================================

  Future<void> _getCurrentGpsLocation({bool isInitial = false}) async {
    setState(() {
      _isLoadingGps = true;
      _gpsErrorMessage = null;
      _isGpsServiceDisabled = false;
      _isGpsPermissionDeniedForever = false;
    });

    try {
      final isServiceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!isServiceEnabled) {
        setState(() {
          _isLoadingGps = false;
          _isGpsServiceDisabled = true;
          _gpsErrorMessage = 'Định vị GPS trên máy đang tắt.';
        });
        if (!isInitial && mounted) {
          _showGpsServiceDialog();
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _isLoadingGps = false;
            _gpsErrorMessage = 'Quyền truy cập vị trí bị từ chối.';
          });
          if (!isInitial && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Vui lòng cấp quyền vị trí để định vị shipper trên bản đồ.'),
                backgroundColor: Colors.orange,
              ),
            );
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _isLoadingGps = false;
          _isGpsPermissionDeniedForever = true;
          _gpsErrorMessage = 'Quyền vị trí bị từ chối vĩnh viễn.';
        });
        if (!isInitial && mounted) {
          _showPermissionDeniedForeverDialog();
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 12),
        ),
      );

      final myLatLng = LatLng(position.latitude, position.longitude);
      if (!mounted) return;

      setState(() {
        _shipperPosition = myLatLng;
        _gpsAccuracy = position.accuracy;
        _isLoadingGps = false;
        _gpsErrorMessage = null;
      });

      // Di chuyển camera đến vị trí shipper
      _mapController.move(myLatLng, 16.5);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingGps = false;
        _gpsErrorMessage = 'Không thể lấy GPS hiện tại.';
      });
      if (!isInitial) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi lấy GPS: ${e.toString().replaceAll("Exception: ", "")}'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  void _showGpsServiceDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.location_off_rounded, color: Colors.orange, size: 28),
            SizedBox(width: 8),
            Text('GPS Đang Tắt', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'Dịch vụ định vị GPS trên điện thoại đang tắt. Bác tài vui lòng bật GPS để ứng dụng xác định vị trí hiện tại.',
          style: TextStyle(fontSize: 16, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Để sau', style: TextStyle(fontSize: 16)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E88E5),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            icon: const Icon(Icons.settings),
            label: const Text('MỞ CÀI ĐẶT BẬT GPS', style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () {
              Navigator.pop(ctx);
              Geolocator.openLocationSettings();
            },
          ),
        ],
      ),
    );
  }

  void _showPermissionDeniedForeverDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
            SizedBox(width: 8),
            Text('Quyền Vị Trí', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'Quyền định vị đã bị chặn trong cài đặt máy. Bác tài vui lòng bấm vào nút dưới đây để cấp quyền "Khi dùng ứng dụng".',
          style: TextStyle(fontSize: 16, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Bỏ qua', style: TextStyle(fontSize: 16)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E88E5),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            icon: const Icon(Icons.app_settings_alt),
            label: const Text('CÀI ĐẶT ỨNG DỤNG', style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () {
              Navigator.pop(ctx);
              Geolocator.openAppSettings();
            },
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 3. ĐIỀU HƯỚNG BẢN ĐỒ & THAO TÁC VỚI MARKER
  // ===========================================================================

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
        // Google Maps Đường phố
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
    });
    final names = [
      'Bản đồ đường phố',
      'Ảnh vệ tinh + Tên đường',
      'OpenStreetMap Voyager'
    ];
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 1),
        content: Text('Đã đổi: ${names[_currentMapType]}'),
      ),
    );
  }

  void _onOrderMarkerTapped(OrderModel order) {
    setState(() {
      _selectedOrder = order;
    });

    if (order.savedLocation != null) {
      final target = LatLng(
        order.savedLocation!.latitude,
        order.savedLocation!.longitude,
      );
      _mapController.move(target, 17.0);
    }

    // Thu gọn danh sách xuống mức nhỏ nhất để lộ bản đồ và thẻ chi tiết
    if (_sheetController.isAttached) {
      _sheetController.animateTo(
        0.13,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
      );
    }
  }

  void _focusOrderOnMap(OrderModel order) {
    if (order.savedLocation != null) {
      setState(() {
        _selectedOrder = order;
      });
      final target = LatLng(
        order.savedLocation!.latitude,
        order.savedLocation!.longitude,
      );
      _mapController.move(target, 17.0);

      if (_sheetController.isAttached) {
        _sheetController.animateTo(
          0.13,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    } else {
      // Đơn chưa có tọa độ: Mở trực tiếp màn hình chi tiết hoặc chụp vị trí
      _openOrderDetail(order);
    }
  }

  void _fitAllDeliveryMarkers() {
    final pointsWithLocation = _orders
        .where((o) => o.hasSavedLocation && o.savedLocation != null)
        .map((o) => LatLng(o.savedLocation!.latitude, o.savedLocation!.longitude))
        .toList();

    if (_shipperPosition != null) {
      pointsWithLocation.add(_shipperPosition!);
    }

    if (pointsWithLocation.isEmpty) {
      _mapController.move(_defaultCenter, 15.0);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Chưa có đơn hàng nào có tọa độ trên bản đồ.'),
        ),
      );
      return;
    }

    if (pointsWithLocation.length == 1) {
      _mapController.move(pointsWithLocation.first, 16.5);
      return;
    }

    double minLat = pointsWithLocation.first.latitude;
    double maxLat = pointsWithLocation.first.latitude;
    double minLng = pointsWithLocation.first.longitude;
    double maxLng = pointsWithLocation.first.longitude;

    for (final p in pointsWithLocation) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    final center = LatLng((minLat + maxLat) / 2, (minLng + maxLng) / 2);
    _mapController.move(center, 14.5);
  }

  // ===========================================================================
  // 4. CÁC HÀNH ĐỘNG VỚI ĐƠN HÀNG (GỌI ĐIỆN, DẪN ĐƯỜNG, LƯU VỊ TRÍ, CHI TIẾT)
  // ===========================================================================

  Future<void> _makePhoneCall(String phoneNumber) async {
    final cleanPhone = phoneNumber.replaceAll(RegExp(r'\D'), '');
    if (cleanPhone.isEmpty) return;

    final uri = Uri(scheme: 'tel', path: cleanPhone);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Không thể mở ứng dụng cuộc gọi tới số $phoneNumber'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi gọi điện: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _openOrderDetail(OrderModel order) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => OrderDetailView(order: order)),
    );
    _loadOrders();
  }

  Future<void> _openSaveLocation(OrderModel order) async {
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => SaveLocationView(
          customerId: order.customerId,
          customerName: order.customerName,
          existingLocation: order.savedLocation,
        ),
      ),
    );
    if (updated == true) {
      _loadOrders();
    }
  }

  Future<void> _handleSearchCustomer() async {
    final raw = _phoneSearchController.text.trim();
    if (raw.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng nhập số điện thoại khách hàng cần tìm.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    var clean = raw.replaceAll(RegExp(r'\D'), '');
    if (clean.startsWith('84') && clean.length == 11) {
      clean = '0${clean.substring(2)}';
    } else if (clean.length == 9 && !clean.startsWith('0')) {
      clean = '0$clean';
    }

    if (clean.length != 10 || !clean.startsWith('0')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Số điện thoại không đúng định dạng (cần 10 chữ số).'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _isSearchingPhone = true;
      _searchedCustomerData = null;
    });

    try {
      final result = await RepositoryProvider.customer.lookupCustomerLocationByPhone(clean);
      if (!mounted) return;

      setState(() {
        _isSearchingPhone = false;
      });

      if (result == null) {
        _showCustomerNotFoundDialog(raw);
        return;
      }

      final customer = result['customer'];
      final custId = customer['id'] as String;
      final hasLoc = result['hasSavedLocation'] == true;
      final location = result['location'];

      // Kiểm tra xem khách hàng đã có đơn hàng nào trong ca của shipper chưa
      OrderModel? existingOrder;
      for (final o in _orders) {
        if (o.customerId == custId) {
          existingOrder = o;
          break;
        }
      }

      if (existingOrder != null) {
        setState(() {
          _selectedOrder = existingOrder;
          _searchedCustomerData = null;
        });

        if (existingOrder.savedLocation != null) {
          _mapController.move(
            LatLng(existingOrder.savedLocation!.latitude, existingOrder.savedLocation!.longitude),
            17.0,
          );
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Khách hàng đã có Đơn ${existingOrder.orderCode} trong ca!'),
            backgroundColor: const Color(0xFF1565C0),
            duration: const Duration(seconds: 3),
          ),
        );
        return;
      }

      // Khách hàng tồn tại nhưng chưa có đơn trong ca
      setState(() {
        _searchedCustomerData = result;
        _selectedOrder = null;
      });

      if (hasLoc && location != null) {
        final lat = (location['latitude'] as num).toDouble();
        final lng = (location['longitude'] as num).toDouble();
        _mapController.move(LatLng(lat, lng), 17.0);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(hasLoc
              ? 'Đã tìm thấy: ${customer["fullName"]} (Đã lưu vị trí)'
              : 'Đã tìm thấy: ${customer["fullName"]} (Chưa có vị trí nhà)'),
          backgroundColor: hasLoc ? const Color(0xFF2E7D32) : Colors.orange.shade800,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSearchingPhone = false;
      });

      final errStr = e.toString().replaceAll('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errStr),
          backgroundColor: Colors.red.shade700,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  void _showCustomerNotFoundDialog(String phoneInput) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.person_search, color: Colors.orange, size: 28),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Chưa Tìm Thấy Hồ Sơ',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Không tìm thấy khách hàng nào với số điện thoại: $phoneInput',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFE3F2FD),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF90CAF9)),
              ),
              child: const Text(
                'Số điện thoại này chưa được đăng ký trong hệ thống CSDL.\n\n'
                'Hiện tại tính năng tạo hồ sơ khách hàng mới thuộc thẩm quyền của Quản trị viên (Admin) hoặc Điều phối viên.\n\n'
                'Bác tài vui lòng liên hệ điều phối viên để bổ sung thông tin khách hàng vào hệ thống trước khi thêm điểm giao.',
                style: TextStyle(fontSize: 13, color: Colors.black87, height: 1.4),
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E88E5),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('ĐÃ HIỂU', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          ),
        ],
      ),
    );
  }

  Future<void> _addSearchedCustomerToShift(Map<String, dynamic> customerData) async {
    final customer = customerData['customer'];
    final custId = customer['id'] as String;
    final custName = customer['fullName'] as String;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.add_task_rounded, color: Color(0xFF1E88E5), size: 26),
            SizedBox(width: 8),
            Text('Thêm Điểm Giao Vào Ca', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'Bác tài có muốn thêm điểm giao cho khách "$custName" vào ca làm việc hiện tại không?',
          style: const TextStyle(fontSize: 16, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('HỦY', style: TextStyle(fontSize: 16)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E88E5),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('XÁC NHẬN THÊM', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isAddingOrder = true);

    try {
      final res = await RepositoryProvider.shift.addOrderToShift(customerId: custId);
      final order = res['order'] as OrderModel;
      final isExisting = res['isExisting'] == true;

      if (!mounted) return;

      setState(() {
        _isAddingOrder = false;
        _searchedCustomerData = null;

        final idx = _orders.indexWhere((o) => o.orderId == order.orderId);
        if (idx >= 0) {
          _orders[idx] = order;
        } else {
          _orders.insert(0, order);
        }
        _selectedOrder = order;
      });

      if (order.savedLocation != null) {
        _mapController.move(
          LatLng(order.savedLocation!.latitude, order.savedLocation!.longitude),
          17.0,
        );
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isExisting
              ? 'Khách hàng đã có sẵn Đơn ${order.orderCode} trong ca!'
              : 'Đã thêm thành công Đơn ${order.orderCode} vào ca!'),
          backgroundColor: const Color(0xFF2E7D32),
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isAddingOrder = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi: ${e.toString().replaceAll("Exception: ", "")}'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Đăng Xuất Tài Khoản', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text(
          'Bác tài có chắc chắn muốn đăng xuất khỏi ứng dụng?',
          style: TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('HỦY', style: TextStyle(fontSize: 16)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('ĐĂNG XUẤT', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await RepositoryProvider.profile.logout();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginView()),
        (route) => false,
      );
    }
  }

  // ===========================================================================
  // 5. GIAO DIỆN CHÍNH (BUILD)
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    // Phân loại đơn có tọa độ và chưa có tọa độ
    final ordersWithLocation = _orders
        .where((o) => o.hasSavedLocation && o.savedLocation != null)
        .toList();
    final ordersWithoutLocationCount =
        _orders.where((o) => !o.hasSavedLocation || o.savedLocation == null).length;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: const Color(0xFFF4F6F9),
      body: Stack(
        children: [
          // -------------------------------------------------------------------
          // A. LỚP BẢN ĐỒ TOÀN MÀN HÌNH (FLUTTER MAP)
          // -------------------------------------------------------------------
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _shipperPosition ?? _defaultCenter,
              initialZoom: 15.5,
              onTap: (_, __) {
                // Chạm vào vùng trống trên bản đồ: đóng thẻ chi tiết nếu đang mở
                if (_selectedOrder != null || _searchedCustomerData != null) {
                  setState(() {
                    _selectedOrder = null;
                    _searchedCustomerData = null;
                  });
                }
              },
            ),
            children: [
              TileLayer(
                key: ValueKey(_currentMapType),
                urlTemplate: _getUrlTemplate(),
                subdomains: _getSubdomains(),
                userAgentPackageName: 'com.example.delivery_marker_mobile',
              ),

              // Lớp Marker điểm giao hàng
              MarkerLayer(
                markers: [
                  // 1. Marker các đơn hàng đã có vị trí xác minh
                  for (int i = 0; i < ordersWithLocation.length; i++)
                    _buildOrderMarker(ordersWithLocation[i], i + 1),

                  // 2. Marker khách hàng vừa tìm thấy qua SĐT (nếu đã có vị trí lưu)
                  if (_searchedCustomerData != null &&
                      _searchedCustomerData!['hasSavedLocation'] == true &&
                      _searchedCustomerData!['location'] != null)
                    _buildSearchedCustomerMarker(_searchedCustomerData!),

                  // 3. Marker vị trí của Shipper (nếu có GPS)
                  if (_shipperPosition != null) _buildShipperMarker(),
                ],
              ),
            ],
          ),

          // -------------------------------------------------------------------
          // B. THANH ĐIỀU HƯỚNG NỔI PHÍA TRÊN (FLOATING HEADER BAR)
          // -------------------------------------------------------------------
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 12,
            right: 12,
            child: _buildTopHeaderCard(ordersWithoutLocationCount),
          ),

          // -------------------------------------------------------------------
          // C. NÚT ĐIỀU KHIỂN NỔI BÊN PHẢI (FLOATING ACTION BUTTONS)
          // -------------------------------------------------------------------
          Positioned(
            right: 14,
            bottom: (_selectedOrder != null || _searchedCustomerData != null) ? 410 : 130,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Nút vừa vặn tất cả các đơn
                FloatingActionButton.small(
                  heroTag: 'fab_fit_bounds',
                  tooltip: 'Xem toàn bộ điểm giao',
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF1565C0),
                  onPressed: _fitAllDeliveryMarkers,
                  child: const Icon(Icons.zoom_out_map, size: 22),
                ),
                const SizedBox(height: 10),

                // Nút định vị GPS của shipper (nút to, dễ bấm)
                SizedBox(
                  width: 56,
                  height: 56,
                  child: FloatingActionButton(
                    heroTag: 'fab_my_gps',
                    tooltip: 'Vị trí của tôi',
                    backgroundColor: const Color(0xFF1E88E5),
                    foregroundColor: Colors.white,
                    elevation: 4,
                    onPressed: _isLoadingGps
                        ? null
                        : () => _getCurrentGpsLocation(isInitial: false),
                    child: _isLoadingGps
                        ? const SizedBox(
                            width: 26,
                            height: 26,
                            child: CircularProgressIndicator(
                              strokeWidth: 3,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.my_location, size: 28),
                  ),
                ),
              ],
            ),
          ),

          // -------------------------------------------------------------------
          // D1. THẺ CHI TIẾT ĐIỂM GIAO TRÊN BẢN ĐỒ (SELECTED ORDER CARD OVERLAY)
          // -------------------------------------------------------------------
          if (_selectedOrder != null && _searchedCustomerData == null)
            Positioned(
              left: 12,
              right: 12,
              bottom: 120,
              child: _buildSelectedOrderCard(_selectedOrder!),
            ),

          // -------------------------------------------------------------------
          // D2. THẺ HỒ SƠ KHÁCH HÀNG TÌM THẤY (SEARCHED CUSTOMER CARD OVERLAY)
          // -------------------------------------------------------------------
          if (_searchedCustomerData != null)
            Positioned(
              left: 12,
              right: 12,
              bottom: 120,
              child: _buildSearchedCustomerCard(_searchedCustomerData!),
            ),

          // -------------------------------------------------------------------
          // E. DANH SÁCH ĐƠN HÀNG DẠNG BOTTOM SHEET KÉO LÊN/XUỐNG
          // -------------------------------------------------------------------
          NotificationListener<DraggableScrollableNotification>(
            onNotification: (notification) {
              // Nếu người dùng kéo sheet lên cao (> 0.22), ẩn thẻ nổi để tránh đè giao diện
              if (notification.extent > 0.22 &&
                  (_selectedOrder != null || _searchedCustomerData != null)) {
                setState(() {
                  _selectedOrder = null;
                  _searchedCustomerData = null;
                });
              }
              return false;
            },
            child: DraggableScrollableSheet(
              controller: _sheetController,
              initialChildSize: 0.14,
              minChildSize: 0.12,
              maxChildSize: 0.82,
              snap: true,
              snapSizes: const [0.14, 0.45, 0.82],
              builder: (context, scrollController) {
                return _buildBottomSheetContent(
                  scrollController,
                  ordersWithoutLocationCount,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 6. BUILD CÁC WIDGET THÀNH PHẦN (HEADER, MARKER, CARDS, BOTTOM SHEET)
  // ===========================================================================

  /// Header trên cùng màn hình bản đồ
  Widget _buildTopHeaderCard(int ordersWithoutLocationCount) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                // Icon ứng dụng
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Color(0x1F1E88E5),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.delivery_dining_rounded,
                    color: Color(0xFF1E88E5),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 10),

                // Tiêu đề & tóm tắt số lượng đơn
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Bản Đồ Giao Hàng',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1565C0),
                        ),
                      ),
                      Text(
                        _isLoadingOrders
                            ? 'Đang tải đơn...'
                            : '${_orders.length} đơn ca này • $ordersWithoutLocationCount chưa có GPS',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: ordersWithoutLocationCount > 0
                              ? Colors.orange.shade900
                              : Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),

                // Badge đồng bộ offline nếu có
                if (_pendingSyncCount > 0)
                  IconButton(
                    icon: Badge(
                      label: Text('$_pendingSyncCount'),
                      child: const Icon(Icons.cloud_upload_outlined, color: Colors.amber),
                    ),
                    tooltip: '$_pendingSyncCount vị trí đang chờ đồng bộ',
                    onPressed: _checkPendingSync,
                  ),

                // Nút đổi kiểu bản đồ (Vệ tinh / Đường phố)
                IconButton(
                  icon: Icon(
                    _currentMapType == 1 ? Icons.map_outlined : Icons.satellite_alt_outlined,
                    color: const Color(0xFF1E88E5),
                  ),
                  tooltip: _currentMapType == 1 ? 'Xem bản đồ đường' : 'Xem ảnh vệ tinh',
                  onPressed: _switchMapType,
                ),

                // Menu thêm (Xem danh sách dạng truyền thống, Làm mới, Đăng xuất)
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Colors.black87),
                  tooltip: 'Thao tác khác',
                  onSelected: (val) {
                    if (val == 'refresh') _loadOrders();
                    if (val == 'shifts') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ShiftListView()),
                      );
                    }
                    if (val == 'list_view') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const OrderListView()),
                      );
                    }
                    if (val == 'logout') _handleLogout();
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(
                      value: 'shifts',
                      child: Row(
                        children: [
                          Icon(Icons.badge_rounded, color: Colors.blue),
                          SizedBox(width: 10),
                          Text('Quản lý Ca làm việc', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'refresh',
                      child: Row(
                        children: [
                          Icon(Icons.refresh, color: Colors.blue),
                          SizedBox(width: 10),
                          Text('Tải lại đơn hàng', style: TextStyle(fontSize: 15)),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'list_view',
                      child: Row(
                        children: [
                          Icon(Icons.format_list_bulleted, color: Colors.teal),
                          SizedBox(width: 10),
                          Text('Xem dạng danh sách', style: TextStyle(fontSize: 15)),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(),
                    const PopupMenuItem(
                      value: 'logout',
                      child: Row(
                        children: [
                          Icon(Icons.logout, color: Colors.red),
                          SizedBox(width: 10),
                          Text('Đăng xuất tài khoản', style: TextStyle(fontSize: 15, color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Ô tìm kiếm số điện thoại khách hàng (FEATURE-ORDER-ENTRY-001)
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F4F9),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFCFD8DC)),
                    ),
                    child: TextField(
                      controller: _phoneSearchController,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => _handleSearchCustomer(),
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                      decoration: InputDecoration(
                        hintText: 'Nhập SĐT khách hàng...',
                        hintStyle: TextStyle(fontSize: 14, color: Colors.grey.shade600, fontWeight: FontWeight.normal),
                        prefixIcon: const Icon(Icons.phone_outlined, size: 20, color: Color(0xFF1E88E5)),
                        suffixIcon: _phoneSearchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18, color: Colors.grey),
                                onPressed: () {
                                  _phoneSearchController.clear();
                                  setState(() {});
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E88E5),
                      foregroundColor: Colors.white,
                      elevation: 2,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: _isSearchingPhone
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.search, size: 20),
                    label: const Text(
                      'TÌM KHÁCH',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    onPressed: _isSearchingPhone ? null : _handleSearchCustomer,
                  ),
                ),
              ],
            ),

            // Dòng cảnh báo GPS nếu thiết bị tắt GPS hoặc từ chối quyền
            if (_gpsErrorMessage != null) ...[
              const SizedBox(height: 6),
              InkWell(
                onTap: () {
                  if (_isGpsServiceDisabled) {
                    _showGpsServiceDialog();
                  } else if (_isGpsPermissionDeniedForever) {
                    _showPermissionDeniedForeverDialog();
                  } else {
                    _getCurrentGpsLocation(isInitial: false);
                  }
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber.shade300),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.location_off_rounded, size: 16, color: Colors.amber.shade900),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _gpsErrorMessage!,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.brown.shade800,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        _isGpsServiceDisabled
                            ? 'Bật GPS'
                            : (_isGpsPermissionDeniedForever ? 'Cài đặt' : 'Cấp quyền'),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1565C0),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Marker tạm thời hiển thị vị trí khách hàng vừa tìm thấy qua SĐT
  Marker _buildSearchedCustomerMarker(Map<String, dynamic> data) {
    final loc = data['location'];
    final lat = (loc['latitude'] as num).toDouble();
    final lng = (loc['longitude'] as num).toDouble();

    return Marker(
      point: LatLng(lat, lng),
      width: 90,
      height: 72,
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedOrder = null;
          });
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF7B1FA2),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: const [
                  BoxShadow(color: Color(0x59000000), blurRadius: 4, offset: Offset(0, 2)),
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.person_pin_circle, color: Colors.white, size: 16),
                  SizedBox(width: 4),
                  Text(
                    'Khách tìm',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_drop_down, color: Color(0xFF7B1FA2), size: 22),
          ],
        ),
      ),
    );
  }

  /// Marker vị trí hiện tại của Shipper (Màu xanh dương, vòng tỏa sáng, phân biệt rõ với đơn hàng)
  Marker _buildShipperMarker() {
    return Marker(
      point: _shipperPosition!,
      width: 60,
      height: 60,
      child: Tooltip(
        message: 'Vị trí hiện tại của bạn (Sai số: ±${_gpsAccuracy?.toStringAsFixed(1) ?? "?"}m)',
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Vòng tròn ánh sáng mờ xung quanh
            Container(
              width: 58,
              height: 58,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0x381E88E5),
              ),
            ),
            // Chấm tròn định vị chính
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF0D47A1),
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: const [
                  BoxShadow(color: Colors.black38, blurRadius: 4, offset: Offset(0, 2)),
                ],
              ),
              child: const Icon(
                Icons.navigation_rounded,
                color: Colors.white,
                size: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Marker điểm giao hàng (Màu đỏ/cam với số thứ tự và nhãn khách hàng)
  Marker _buildOrderMarker(OrderModel order, int index) {
    final loc = order.savedLocation!;
    final isSelected = _selectedOrder?.orderId == order.orderId;

    return Marker(
      point: LatLng(loc.latitude, loc.longitude),
      width: isSelected ? 80 : 64,
      height: isSelected ? 76 : 60,
      child: GestureDetector(
        onTap: () => _onOrderMarkerTapped(order),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Khối nhãn ghim hiển thị số thứ tự đơn
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFFD32F2F) : const Color(0xFF2E7D32),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white, width: isSelected ? 2.5 : 1.8),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0x59000000),
                    blurRadius: isSelected ? 6 : 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isSelected ? Icons.check_circle : Icons.home_rounded,
                    color: Colors.white,
                    size: isSelected ? 16 : 13,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Đơn $index',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: isSelected ? 13 : 11,
                    ),
                  ),
                ],
              ),
            ),
            // Mũi nhọn chỉ xuống tọa độ
            Icon(
              Icons.arrow_drop_down,
              color: isSelected ? const Color(0xFFD32F2F) : const Color(0xFF2E7D32),
              size: isSelected ? 22 : 18,
            ),
          ],
        ),
      ),
    );
  }

  /// Thẻ chi tiết điểm giao trên cùng bản đồ (Selected Order Card)
  Widget _buildSelectedOrderCard(OrderModel order) {
    final hasLoc = order.hasSavedLocation && order.savedLocation != null;
    final loc = order.savedLocation;

    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFF1E88E5), width: 1.5),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Tiêu đề: Tên khách + Mã đơn + Nút đóng
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.customerName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1565C0),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Mã đơn: ${order.orderCode} • SĐT: ${order.customerPhone}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 26, color: Colors.grey),
                  tooltip: 'Đóng thẻ',
                  onPressed: () => setState(() => _selectedOrder = null),
                ),
              ],
            ),
            const Divider(height: 14),

            // Địa chỉ trên đơn
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.location_on_outlined, size: 18, color: Colors.grey),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    order.customerAddress,
                    style: const TextStyle(fontSize: 14, color: Colors.black87),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Ghi chú nhận diện nhà & Ảnh (nếu đã có vị trí lưu)
            if (hasLoc && loc != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.verified, color: Colors.green, size: 18),
                        const SizedBox(width: 6),
                        const Text(
                          'Đã xác minh cổng nhà',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: Colors.green,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          'Sai số: ±${loc.gpsAccuracy.toStringAsFixed(1)}m',
                          style: const TextStyle(fontSize: 11, color: Colors.black54),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      loc.identificationNotes.isNotEmpty
                          ? 'Ghi chú: ${loc.identificationNotes}'
                          : 'Ghi chú: Chưa có ghi chú mô tả cổng',
                      style: const TextStyle(fontSize: 14, color: Colors.black87),
                    ),
                  ],
                ),
              ),

              // Ảnh nhà (nếu có)
              if (loc.imageUrl != null && loc.imageUrl!.isNotEmpty) ...[
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    height: 110,
                    width: double.infinity,
                    child: FutureBuilder<Map<String, String>>(
                      future: RepositoryProvider.photo.getPhotoAuthInfo(loc.imageUrl!),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return Container(
                            color: Colors.grey.shade100,
                            alignment: Alignment.center,
                            child: const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          );
                        }
                        if (!snapshot.hasData || snapshot.hasError) {
                          return Container(
                            color: Colors.grey.shade200,
                            alignment: Alignment.center,
                            child: const Text('Ảnh mặt tiền không tải được', style: TextStyle(fontSize: 12)),
                          );
                        }
                        final photoInfo = snapshot.data!;
                        final token = photoInfo['token'];
                        final fullUrl = photoInfo['url']!;
                        return Image.network(
                          fullUrl,
                          headers: {
                            if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
                          },
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: Colors.grey.shade200,
                            alignment: Alignment.center,
                            child: const Text('Lỗi hiển thị ảnh mặt tiền', style: TextStyle(fontSize: 12)),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ] else ...[
              // Trạng thái chưa có vị trí
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.amber.shade300),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.help_outline, color: Colors.amber, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Chưa có tọa độ cổng nhà đã lưu. Vui lòng giao theo địa chỉ và chụp ảnh xác minh.',
                        style: TextStyle(fontSize: 13, color: Colors.brown, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 12),

            // Các nút thao tác lớn (Dẫn đường, Gọi khách, Chi tiết đơn, Lưu vị trí)
            // Nút hành động chính (Dẫn đường hoặc Lưu vị trí)
            SizedBox(
              width: double.infinity,
              height: 48,
              child: hasLoc && loc != null
                  ? ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2E7D32),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.navigation_rounded, size: 20),
                      label: const Text(
                        'DẪN ĐƯỜNG ĐẾN CỔNG NHÀ',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      onPressed: () {
                        ApiService.openExternalNavigation(loc.latitude, loc.longitude);
                      },
                    )
                  : ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE65100),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.add_location_alt_rounded, size: 20),
                      label: const Text(
                        'XÁC ĐỊNH & LƯU VỊ TRÍ',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      onPressed: () => _openSaveLocation(order),
                    ),
            ),
            const SizedBox(height: 8),

            // Hàng nút phụ: Gọi khách & Chi tiết đơn (Vùng chạm >= 48px)
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 46,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E88E5),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.phone, size: 18),
                      label: const Text(
                        'GỌI KHÁCH',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      onPressed: () => _makePhoneCall(order.customerPhone),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SizedBox(
                    height: 46,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF1E88E5), width: 1.4),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.info_outline, size: 18),
                      label: const Text(
                        'CHI TIẾT ĐƠN',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      onPressed: () => _openOrderDetail(order),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Thẻ hồ sơ khách hàng tìm thấy qua số điện thoại (FEATURE-ORDER-ENTRY-001)
  Widget _buildSearchedCustomerCard(Map<String, dynamic> data) {
    final customer = data['customer'];
    final custName = customer['fullName'] ?? 'Khách hàng';
    final custPhone = customer['phoneNumber'] ?? '';
    final custAddress = customer['addressText'] ?? '';
    final areaName = customer['area']?['name'] ?? '';
    final hasLoc = data['hasSavedLocation'] == true;
    final loc = data['location'];

    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFF1E88E5), width: 2),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Tiêu đề: Tên khách + SĐT + Nút đóng
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE3F2FD),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'HỒ SƠ KHÁCH HÀNG',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1565C0),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          if (hasLoc)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'ĐÃ CÓ VỊ TRÍ',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green.shade800,
                                ),
                              ),
                            )
                          else
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'CHƯA CÓ VỊ TRÍ NHÀ',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange.shade900,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        custName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1565C0),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'SĐT: $custPhone${areaName.isNotEmpty ? " • $areaName" : ""}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 26, color: Colors.grey),
                  tooltip: 'Đóng thẻ',
                  onPressed: () => setState(() => _searchedCustomerData = null),
                ),
              ],
            ),
            const Divider(height: 14),

            // Địa chỉ
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.location_on_outlined, size: 18, color: Colors.grey),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    custAddress,
                    style: const TextStyle(fontSize: 14, color: Colors.black87),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Nếu đã có vị trí: hiển thị ghi chú, sai số, ảnh
            if (hasLoc && loc != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.verified, color: Colors.green, size: 18),
                        const SizedBox(width: 6),
                        const Text(
                          'Cổng nhà đã lưu trong hệ thống',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: Colors.green,
                          ),
                        ),
                        const Spacer(),
                        if (loc['gpsAccuracy'] != null)
                          Text(
                            'Sai số: ±${(loc["gpsAccuracy"] as num).toStringAsFixed(1)}m',
                            style: const TextStyle(fontSize: 11, color: Colors.black54),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      loc['identificationNotes'] != null &&
                              (loc['identificationNotes'] as String).isNotEmpty
                          ? 'Ghi chú: ${loc["identificationNotes"]}'
                          : 'Ghi chú: Chưa có ghi chú mô tả cổng',
                      style: const TextStyle(fontSize: 14, color: Colors.black87),
                    ),
                  ],
                ),
              ),

              if (loc['imageUrl'] != null && (loc['imageUrl'] as String).isNotEmpty) ...[
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    height: 100,
                    width: double.infinity,
                    child: FutureBuilder<Map<String, String>>(
                      future: RepositoryProvider.photo.getPhotoAuthInfo(loc['imageUrl']),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return Container(
                            color: Colors.grey.shade100,
                            alignment: Alignment.center,
                            child: const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          );
                        }
                        if (!snapshot.hasData || snapshot.hasError) {
                          return Container(
                            color: Colors.grey.shade200,
                            alignment: Alignment.center,
                            child: const Text('Không tải được ảnh', style: TextStyle(fontSize: 12)),
                          );
                        }
                        final photoInfo = snapshot.data!;
                        final token = photoInfo['token'];
                        final fullUrl = photoInfo['url']!;
                        return Image.network(
                          fullUrl,
                          headers: {
                            if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
                          },
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: Colors.grey.shade200,
                            alignment: Alignment.center,
                            child: const Text('Lỗi ảnh', style: TextStyle(fontSize: 12)),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ] else ...[
              // Trạng thái chưa có vị trí lưu
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange.shade800, size: 20),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Khách hàng chưa có vị trí GPS. Điểm giao sẽ được thêm vào ca ở trạng thái "Chờ xác định vị trí".',
                        style: TextStyle(fontSize: 13, color: Colors.brown, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 12),

            // Nút Thêm vào ca
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E88E5),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: _isAddingOrder
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                      )
                    : const Icon(Icons.add_task_rounded, size: 22),
                label: Text(
                  _isAddingOrder ? 'ĐANG THÊM...' : 'THÊM ĐIỂM GIAO VÀO CA',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                onPressed: _isAddingOrder ? null : () => _addSearchedCustomerToShift(data),
              ),
            ),
            const SizedBox(height: 8),

            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF1565C0),
                        side: const BorderSide(color: Color(0xFF1565C0), width: 1.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.phone_in_talk, size: 18),
                      label: const Text('GỌI KHÁCH', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      onPressed: () => _makePhoneCall(custPhone),
                    ),
                  ),
                ),
                if (hasLoc && loc != null) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: SizedBox(
                      height: 44,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF2E7D32),
                          side: const BorderSide(color: Color(0xFF2E7D32), width: 1.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.navigation_outlined, size: 18),
                        label: const Text('DẪN ĐƯỜNG', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        onPressed: () {
                          final lat = (loc['latitude'] as num).toDouble();
                          final lng = (loc['longitude'] as num).toDouble();
                          ApiService.openExternalNavigation(lat, lng);
                        },
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Nội dung Bottom Sheet danh sách đơn hàng
  Widget _buildBottomSheetContent(
    ScrollController scrollController,
    int ordersWithoutLocationCount,
  ) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, -3)),
        ],
      ),
      child: Column(
        children: [
          // Tay cầm kéo (Drag handle)
          Container(
            width: 48,
            height: 5,
            margin: const EdgeInsets.only(top: 8, bottom: 6),
            decoration: BoxDecoration(
              color: Colors.grey.shade400,
              borderRadius: BorderRadius.circular(10),
            ),
          ),

          // Thanh tóm tắt luôn hiển thị ở trạng thái thu gọn - Chạm để mở rộng / thu gọn
          InkWell(
            onTap: () {
              if (_sheetController.isAttached) {
                final currentSize = _sheetController.size;
                final targetSize = currentSize < 0.3 ? 0.70 : 0.14;
                _sheetController.animateTo(
                  targetSize,
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeInOut,
                );
              }
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Danh Sách Đơn Trong Ca (${_orders.length})',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        ordersWithoutLocationCount == 0
                            ? 'Tất cả đơn đã có tọa độ GPS cổng nhà'
                            : '$ordersWithoutLocationCount đơn chưa xác định vị trí',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: ordersWithoutLocationCount > 0
                              ? Colors.orange.shade900
                              : Colors.green.shade800,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Text(
                        'Chạm xem',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.blue.shade700,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.unfold_more_rounded,
                        color: Colors.blue.shade700,
                        size: 22,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 10),

          // Nội dung danh sách đơn hàng khi kéo lên
          Expanded(
            child: _buildOrdersListOrStates(scrollController),
          ),
        ],
      ),
    );
  }

  /// Trạng thái tải / lỗi / rỗng hoặc danh sách đơn
  Widget _buildOrdersListOrStates(ScrollController scrollController) {
    if (_isLoadingOrders) {
      return SingleChildScrollView(
        controller: scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 12),
              Text(
                'Đang tải danh sách đơn hàng trong ca...',
                style: TextStyle(fontSize: 15, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    if (_ordersErrorMessage != null) {
      return SingleChildScrollView(
        controller: scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20.0),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off, size: 48, color: Colors.redAccent),
              const SizedBox(height: 10),
              const Text(
                'Không thể tải đơn hàng',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                _ordersErrorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 14),
              ElevatedButton.icon(
                onPressed: _loadOrders,
                icon: const Icon(Icons.refresh),
                label: const Text('Thử lại'),
              ),
            ],
          ),
        ),
      );
    }

    if (_orders.isEmpty) {
      return SingleChildScrollView(
        controller: scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20.0),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.inventory_2_outlined, size: 54, color: Colors.grey),
              const SizedBox(height: 12),
              const Text(
                'Không có đơn hàng nào trong ca hôm nay',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              const Text(
                'Bác tài đã hoàn thành hết các đơn hoặc ca hiện tại chưa có đơn mới.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: _loadOrders,
                icon: const Icon(Icons.refresh),
                label: const Text('Kiểm tra lại'),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 24),
      itemCount: _orders.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final order = _orders[index];
        final hasLoc = order.hasSavedLocation && order.savedLocation != null;
        final isSelected = _selectedOrder?.orderId == order.orderId;

        return Card(
          elevation: isSelected ? 4 : 1.5,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: isSelected ? const Color(0xFF1E88E5) : Colors.grey.shade300,
              width: isSelected ? 2.0 : 1.0,
            ),
          ),
          color: isSelected ? const Color(0x66E3F2FD) : Colors.white,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _focusOrderOnMap(order),
            child: Padding(
              padding: const EdgeInsets.all(14.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Dòng 1: Mã đơn & Trạng thái vị trí
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '#${index + 1} - ${order.orderCode}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1565C0),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: hasLoc ? Colors.green.shade50 : Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: hasLoc ? Colors.green.shade300 : Colors.amber.shade300,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              hasLoc ? Icons.check_circle : Icons.help_outline,
                              size: 14,
                              color: hasLoc ? Colors.green.shade700 : Colors.amber.shade900,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              hasLoc ? 'Đã có vị trí' : 'Chưa có vị trí',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: hasLoc ? Colors.green.shade800 : Colors.amber.shade900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Dòng 2: Tên khách & SĐT
                  Row(
                    children: [
                      const Icon(Icons.person, size: 17, color: Colors.grey),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '${order.customerName} (${order.customerPhone})',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  // Dòng 3: Địa chỉ
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.home_outlined, size: 17, color: Colors.grey),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          order.customerAddress,
                          style: const TextStyle(fontSize: 14, color: Colors.black87),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Dòng 4: Các nút hành động lớn
                  Row(
                    children: [
                      if (hasLoc) ...[
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1E88E5),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: const Icon(Icons.map, size: 16),
                          label: const Text('Xem trên bản đồ', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                          onPressed: () => _focusOrderOnMap(order),
                        ),
                      ] else ...[
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFE65100),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: const Icon(Icons.add_location_alt_outlined, size: 16),
                          label: const Text('Xác định vị trí', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                          onPressed: () => _openSaveLocation(order),
                        ),
                      ],
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.phone, color: Colors.blue, size: 22),
                        tooltip: 'Gọi cho khách',
                        onPressed: () => _makePhoneCall(order.customerPhone),
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right, color: Colors.grey, size: 24),
                        tooltip: 'Chi tiết đơn',
                        onPressed: () => _openOrderDetail(order),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
