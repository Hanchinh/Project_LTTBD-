import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/order_model.dart';
import '../models/location_model.dart';
import '../repositories/repository_provider.dart';
import '../services/api_service.dart';
import 'save_location_view.dart';

class OrderDetailView extends StatefulWidget {
  final OrderModel order;

  const OrderDetailView({super.key, required this.order});

  @override
  State<OrderDetailView> createState() => _OrderDetailViewState();
}

class _OrderDetailViewState extends State<OrderDetailView> {
  bool _isSatellite = false;
  bool _isLookingUpPhone = false;
  SavedLocationModel? _currentLocation;
  String? _lookupMessage;

  @override
  void initState() {
    super.initState();
    _currentLocation = widget.order.savedLocation;
  }

  Future<void> _handlePhoneLookup() async {
    setState(() {
      _isLookingUpPhone = true;
      _lookupMessage = null;
    });

    try {
      final result = await RepositoryProvider.customer.lookupCustomerLocationByPhone(widget.order.customerPhone);
      if (!mounted) return;

      if (result != null && result['hasSavedLocation'] == true) {
        final locData = result['location'];
        final foundLoc = SavedLocationModel(
          id: locData['id'],
          customerId: widget.order.customerId,
          latitude: (locData['latitude'] as num).toDouble(),
          longitude: (locData['longitude'] as num).toDouble(),
          gpsAccuracy: (locData['gpsAccuracy'] as num).toDouble(),
          identificationNotes: locData['identificationNotes'] ?? '',
          imageUrl: locData['imageUrl'],
          updatedAt: locData['updatedAt'],
        );

        setState(() {
          _currentLocation = foundLoc;
          _lookupMessage = 'Tìm thấy hồ sơ vị trí đã lưu của khách hàng qua SĐT!';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã tìm thấy hồ sơ vị trí từ số điện thoại khách hàng!'),
            backgroundColor: Color(0xFF2E7D32),
          ),
        );
      } else {
        setState(() {
          _lookupMessage = 'Số điện thoại này chưa có hồ sơ vị trí nào được ghi nhận.';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Chưa có hồ sơ vị trí nào gắn với số điện thoại này.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi tra cứu: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLookingUpPhone = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final hasLoc = _currentLocation != null;
    final loc = _currentLocation;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        title: Text('Chi Tiết Đơn: ${order.orderCode}'),
        backgroundColor: const Color(0xFF1E88E5),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Customer Info Header Card
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          order.customerName,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.phone, size: 14, color: Colors.blue),
                            const SizedBox(width: 4),
                            Text(
                              order.customerPhone,
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blue),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.location_city, size: 16, color: Colors.grey),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text('Địa chỉ ghi trên đơn: ${order.customerAddress}', style: const TextStyle(fontSize: 13)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.map, size: 16, color: Colors.blueAccent),
                      const SizedBox(width: 6),
                      Text('Khu vực: ${order.areaName}', style: const TextStyle(fontSize: 12, color: Colors.blueAccent)),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            if (_lookupMessage != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                color: Colors.blue.shade50,
                child: Text(
                  _lookupMessage!,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF1565C0), fontWeight: FontWeight.w500),
                  textAlign: TextAlign.center,
                ),
              ),

            // LOCATION DETAILS OR NO-LOCATION BANNER
            if (hasLoc) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                color: Colors.green.shade50,
                child: Row(
                  children: [
                    const Icon(Icons.verified, color: Colors.green, size: 20),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Đã có hồ sơ vị trí thực tế được xác minh',
                        style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                    IconButton(
                      icon: Icon(_isSatellite ? Icons.map : Icons.satellite_alt),
                      tooltip: _isSatellite ? 'Xem bản đồ đường phố' : 'Xem ảnh vệ tinh',
                      onPressed: () => setState(() => _isSatellite = !_isSatellite),
                    ),
                  ],
                ),
              ),

              // Interactive Map View
              SizedBox(
                height: 250,
                child: FlutterMap(
                  options: MapOptions(
                    initialCenter: LatLng(loc!.latitude, loc.longitude),
                    initialZoom: 16.5,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: _isSatellite
                          ? 'https://mt1.google.com/vt/lyrs=y&x={x}&y={y}&z={z}'
                          : 'https://mt1.google.com/vt/lyrs=m&x={x}&y={y}&z={z}',
                      userAgentPackageName: 'com.example.delivery_marker_mobile',
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: LatLng(loc.latitude, loc.longitude),
                          width: 44,
                          height: 44,
                          child: const Icon(Icons.location_on, color: Colors.red, size: 44),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Photo Display (if available)
              if (loc.imageUrl != null && loc.imageUrl!.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: FutureBuilder<Map<String, String>>(
                      future: RepositoryProvider.photo.getPhotoAuthInfo(loc.imageUrl!),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return Container(
                            height: 180,
                            color: Colors.grey.shade100,
                            alignment: Alignment.center,
                            child: const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          );
                        }

                        if (!snapshot.hasData || snapshot.hasError) {
                          return Container(
                            height: 120,
                            color: Colors.grey.shade200,
                            alignment: Alignment.center,
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.broken_image, color: Colors.grey),
                                SizedBox(width: 8),
                                Text('Không thể tải ảnh mặt tiền', style: TextStyle(color: Colors.grey)),
                              ],
                            ),
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
                          height: 180,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            height: 120,
                            color: Colors.grey.shade200,
                            alignment: Alignment.center,
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.broken_image, color: Colors.grey),
                                SizedBox(width: 8),
                                Text('Không thể tải ảnh mặt tiền', style: TextStyle(color: Colors.grey)),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],

              // Notes Card
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Card(
                  color: Colors.white,
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.lightbulb_outline, color: Colors.amber, size: 20),
                            SizedBox(width: 6),
                            Text('Ghi chú nhận diện nhà:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          loc.identificationNotes.isNotEmpty ? loc.identificationNotes : 'Không có ghi chú thêm',
                          style: const TextStyle(fontSize: 14, height: 1.4),
                        ),
                        const Divider(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Độ chính xác GPS: ±${loc.gpsAccuracy.toStringAsFixed(1)} m', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                            if (loc.updatedAt != null)
                              Text('Cập nhật: ${loc.updatedAt!.substring(0, 10)}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Navigation Action Button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      ApiService.openExternalNavigation(loc.latitude, loc.longitude);
                    },
                    icon: const Icon(Icons.navigation_rounded, color: Colors.white),
                    label: const Text('DẪN ĐƯỜNG ĐẾN ĐÚNG CỔNG NHÀ', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2E7D32),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ] else ...[
              // No Location State
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.shade300),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.location_off_outlined, color: Colors.amber, size: 54),
                    const SizedBox(height: 12),
                    const Text(
                      'Khách hàng chưa có hồ sơ vị trí lưu!',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Giao theo địa chỉ trên đơn. Khi xác định đúng ngôi nhà, hãy chụp ảnh và lưu vị trí GPS để tái sử dụng.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey, fontSize: 13, height: 1.4),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: _isLookingUpPhone ? null : _handlePhoneLookup,
                      icon: _isLookingUpPhone
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.search, size: 18),
                      label: const Text('TRA CỨU HỒ SƠ QUA SỐ ĐIỆN THOẠI'),
                    ),
                  ],
                ),
              ),
            ],

            // Save / Update Location Action
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final updated = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SaveLocationView(
                          customerId: order.customerId,
                          customerName: order.customerName,
                          existingLocation: _currentLocation,
                        ),
                      ),
                    );
                    if (updated == true) {
                      _handlePhoneLookup();
                    }
                  },
                  icon: Icon(hasLoc ? Icons.edit_location_alt : Icons.add_a_photo_outlined),
                  label: Text(
                    hasLoc ? 'CẬP NHẬT LẠI VỊ TRÍ & ẢNH NHÀ' : 'CHỤP ẢNH & LƯU VỊ TRÍ GIAO HÀNG',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF1E88E5), width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
