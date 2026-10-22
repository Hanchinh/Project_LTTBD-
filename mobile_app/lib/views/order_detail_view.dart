import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/order_model.dart';
import '../services/api_service.dart';
import 'save_location_view.dart';

class OrderDetailView extends StatefulWidget {
  final OrderModel order;

  const OrderDetailView({Key? key, required this.order}) : super(key: key);

  @override
  State<OrderDetailView> createState() => _OrderDetailViewState();
}

class _OrderDetailViewState extends State<OrderDetailView> {
  bool _isSatellite = false;

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final hasLoc = order.hasSavedLocation && order.savedLocation != null;
    final loc = order.savedLocation;

    return Scaffold(
      appBar: AppBar(
        title: Text('Chi Tiết Đơn: ${order.orderCode}'),
        backgroundColor: const Color(0xFF1E88E5),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Customer Info Header
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        order.customerName,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        order.customerPhone,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.blue),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('Địa chỉ HĐ: ${order.customerAddress}', style: const TextStyle(fontSize: 14)),
                ],
              ),
            ),
            const Divider(height: 1),

            // Location Status Banner / Map View
            if (hasLoc) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: Colors.green.shade50,
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green, size: 20),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Đã có vị trí ghi nhớ thực tế',
                        style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      icon: Icon(_isSatellite ? Icons.map : Icons.satellite_alt),
                      tooltip: _isSatellite ? 'Chuyển sang Bản đồ thường' : 'Chuyển sang Ảnh vệ tinh',
                      onPressed: () => setState(() => _isSatellite = !_isSatellite),
                    ),
                  ],
                ),
              ),
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
                          width: 40,
                          height: 40,
                          child: const Icon(Icons.location_on, color: Colors.red, size: 40),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Card(
                  color: Colors.amber.shade50,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  child: Padding(
                    padding: const EdgeInsets.all(14.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.edit_note_rounded, color: Colors.brown),
                            SizedBox(width: 6),
                            Text('Ghi chú nhận diện vị trí:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.brown)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(loc.identificationNotes, style: const TextStyle(fontSize: 14)),
                        const SizedBox(height: 6),
                        Text('Độ chính xác GPS lúc lưu: ±${loc.gpsAccuracy} m', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  ),
                ),
              ),
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
                    label: const Text('DẪN ĐƯỜNG BẰNG GOOGLE MAPS', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2E7D32),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ] else ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 48),
                    SizedBox(height: 8),
                    Text(
                      'Khách hàng chưa có vị trí lưu!',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.orange),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Vui lòng lưu vị trí thực tế sau khi giao hàng thành công.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.black87),
                    ),
                  ],
                ),
              ),
            ],

            // Save / Update Location Button
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SaveLocationView(
                          customerId: order.customerId,
                          customerName: order.customerName,
                          existingLocation: order.savedLocation,
                        ),
                      ),
                    );
                    setState(() {});
                  },
                  icon: Icon(hasLoc ? Icons.edit_location_alt : Icons.add_location_alt),
                  label: Text(
                    hasLoc ? 'CẬP NHẬT LẠI VỊ TRÍ THỰC TẾ' : 'LƯU VỊ TRÍ GIAO THÀNH CÔNG',
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
