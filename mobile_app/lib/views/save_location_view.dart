import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../models/location_model.dart';
import '../services/api_service.dart';

class SaveLocationView extends StatefulWidget {
  final String customerId;
  final String customerName;
  final SavedLocationModel? existingLocation;

  const SaveLocationView({
    Key? key,
    required this.customerId,
    required this.customerName,
    this.existingLocation,
  }) : super(key: key);

  @override
  State<SaveLocationView> createState() => _SaveLocationViewState();
}

class _SaveLocationViewState extends State<SaveLocationView> {
  LatLng _selectedLatLng = const LatLng(10.842215, 106.818123);
  double _gpsAccuracy = 0.0;
  bool _isLoadingGps = true;
  bool _isSaving = false;
  final _notesController = TextEditingController();
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    if (widget.existingLocation != null) {
      _selectedLatLng = LatLng(widget.existingLocation!.latitude, widget.existingLocation!.longitude);
      _gpsAccuracy = widget.existingLocation!.gpsAccuracy;
      _notesController.text = widget.existingLocation!.identificationNotes;
      _isLoadingGps = false;
    } else {
      _getCurrentGpsLocation();
    }
  }

  Future<void> _getCurrentGpsLocation() async {
    setState(() => _isLoadingGps = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _selectedLatLng = LatLng(position.latitude, position.longitude);
        _gpsAccuracy = position.accuracy;
        _isLoadingGps = false;
      });

      _mapController.move(_selectedLatLng, 17.0);
    } catch (e) {
      setState(() => _isLoadingGps = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể lấy GPS hiện tại, dùng tọa độ mặc định: $e')),
        );
      }
    }
  }

  void _handleSave() async {
    if (_notesController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập ghi chú nhận diện vị trí (ví dụ: cổng xanh, cạnh tạp hóa)')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final location = SavedLocationModel(
        customerId: widget.customerId,
        latitude: _selectedLatLng.latitude,
        longitude: _selectedLatLng.longitude,
        gpsAccuracy: _gpsAccuracy,
        identificationNotes: _notesController.text.trim(),
      );

      await ApiService.saveCustomerLocation(location);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã lưu vị trí khách hàng thành công!'), backgroundColor: Colors.green),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: ${e.toString().replaceAll("Exception: ", "")}'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Lưu Vị Trí: ${widget.customerName}'),
        backgroundColor: const Color(0xFF1E88E5),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Step 1: GPS Accuracy Header
            Container(
              padding: const EdgeInsets.all(12),
              color: Colors.blue.shade50,
              child: Row(
                children: [
                  const Icon(Icons.gps_fixed, color: Colors.blue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _isLoadingGps
                          ? 'Đang đo tọa độ GPS...'
                          : 'Độ chính xác GPS hiện tại: ±${_gpsAccuracy.toStringAsFixed(1)} m',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.my_location),
                    tooltip: 'Cập nhật lại GPS',
                    onPressed: _getCurrentGpsLocation,
                  ),
                ],
              ),
            ),

            // Step 2: Interactive Map with Pin adjustment
            SizedBox(
              height: 280,
              child: Stack(
                children: [
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: _selectedLatLng,
                      initialZoom: 17.0,
                      onTap: (tapPosition, point) {
                        setState(() {
                          _selectedLatLng = point;
                        });
                      },
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://mt1.google.com/vt/lyrs=m&x={x}&y={y}&z={z}',
                        userAgentPackageName: 'com.example.delivery_marker_mobile',
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _selectedLatLng,
                            width: 44,
                            height: 44,
                            child: const Icon(Icons.location_on, color: Colors.red, size: 44),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Chạm trên bản đồ để di chuyển ghim',
                        style: TextStyle(color: Colors.white, fontSize: 11),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Step 3: Input Identification Notes
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tọa độ chọn: ${_selectedLatLng.latitude.toStringAsFixed(6)}, ${_selectedLatLng.longitude.toStringAsFixed(6)}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _notesController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'Ghi chú nhận diện vị trí *',
                      hintText: 'VD: Hẻm cạnh tạp hóa Hai Thu, cổng sắt xanh da trời...',
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _isSaving ? null : _handleSave,
                      icon: const Icon(Icons.save_rounded, color: Colors.white),
                      label: _isSaving
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('XÁC NHẬN LƯU VỊ TRÍ (3 BƯỚC)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E88E5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
