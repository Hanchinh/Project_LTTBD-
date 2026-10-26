import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import '../models/location_model.dart';
import '../repositories/repository_provider.dart';
import '../theme/app_buttons.dart';

class SaveLocationView extends StatefulWidget {
  final String customerId;
  final String customerName;
  final String? customerPhone;
  final String? customerAddress;
  final double? initialLat;
  final double? initialLng;
  final SavedLocationModel? existingLocation;

  const SaveLocationView({
    super.key,
    required this.customerId,
    required this.customerName,
    this.customerPhone,
    this.customerAddress,
    this.initialLat,
    this.initialLng,
    this.existingLocation,
  });

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
  final ImagePicker _picker = ImagePicker();

  XFile? _capturedImage;
  String? _existingImageUrl;
  String? _base64Image;

  @override
  void initState() {
    super.initState();
    if (widget.existingLocation != null) {
      _selectedLatLng = LatLng(widget.existingLocation!.latitude, widget.existingLocation!.longitude);
      _gpsAccuracy = widget.existingLocation!.gpsAccuracy;
      _notesController.text = widget.existingLocation!.identificationNotes;
      _existingImageUrl = widget.existingLocation!.imageUrl;
      _isLoadingGps = false;
    } else if (widget.initialLat != null && widget.initialLng != null) {
      _selectedLatLng = LatLng(widget.initialLat!, widget.initialLng!);
      _gpsAccuracy = 5.0; // Tọa độ được người dùng căn chỉnh thủ công
      _isLoadingGps = false;
    } else {
      _getCurrentGpsLocation();
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentGpsLocation() async {
    setState(() => _isLoadingGps = true);
    try {
      final isServiceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!isServiceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Dịch vụ định vị GPS trên thiết bị đang tắt. Vui lòng bật GPS để lấy vị trí.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        setState(() => _isLoadingGps = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Quyền truy cập vị trí bị từ chối. Bạn có thể chọn điểm ghim thủ công.'),
                backgroundColor: Colors.orange,
              ),
            );
          }
          setState(() => _isLoadingGps = false);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Quyền vị trí bị từ chối vĩnh viễn. Vui lòng cấp quyền trong cài đặt máy.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        setState(() => _isLoadingGps = false);
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );

      setState(() {
        _selectedLatLng = LatLng(position.latitude, position.longitude);
        _gpsAccuracy = position.accuracy;
        _isLoadingGps = false;
      });

      _mapController.move(_selectedLatLng, 17.5);
    } catch (e) {
      setState(() => _isLoadingGps = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể lấy GPS hiện tại: $e')),
        );
      }
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 80,
      );

      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();
        // Check file size (limit: max 5MB)
        if (bytes.lengthInBytes > 5 * 1024 * 1024) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Kích thước ảnh vượt quá 5MB. Vui lòng chụp lại.'), backgroundColor: Colors.red),
          );
          return;
        }

        final base64String = 'data:image/jpeg;base64,${base64Encode(bytes)}';
        setState(() {
          _capturedImage = pickedFile;
          _base64Image = base64String;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi truy cập camera hoặc thư viện ảnh: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _removeCapturedImage() {
    setState(() {
      _capturedImage = null;
      _base64Image = null;
    });
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Color(0xFF1E88E5)),
              title: const Text('Chụp ảnh cổng/mặt tiền nhà (Camera)'),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Color(0xFF2E7D32)),
              title: const Text('Chọn ảnh từ thư viện thiết bị'),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showConfirmationAndSave() async {
    final notes = _notesController.text.trim();
    if (notes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng nhập ghi chú nhận diện vị trí (VD: Cổng màu xanh, cạnh tiệm tạp hóa...)'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final isGpsLowAccuracy = _gpsAccuracy > 20.0;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận thông tin vị trí'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Khách hàng: ${widget.customerName}', style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('Tọa độ: ${_selectedLatLng.latitude.toStringAsFixed(6)}, ${_selectedLatLng.longitude.toStringAsFixed(6)}'),
              Text('Độ sai số GPS: ±${_gpsAccuracy.toStringAsFixed(1)} m'),
              if (isGpsLowAccuracy)
                Container(
                  padding: const EdgeInsets.all(8),
                  margin: const EdgeInsets.only(top: 6),
                  decoration: BoxDecoration(color: Colors.amber.shade100, borderRadius: BorderRadius.circular(6)),
                  child: const Text(
                    'Lưu ý: Độ sai số GPS lớn (> 20m). Đảm bảo bạn đã kéo điểm ghim đúng vị trí cổng nhà.',
                    style: TextStyle(fontSize: 12, color: Colors.brown, fontWeight: FontWeight.w500),
                  ),
                ),
              const SizedBox(height: 8),
              Text('Ghi chú: $notes', style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic)),
              const SizedBox(height: 8),
              Text(
                _capturedImage != null ? 'Ảnh: Đã chụp ảnh mặt tiền đính kèm' : (_existingImageUrl != null ? 'Ảnh: Sử dụng ảnh cũ đã lưu' : 'Ảnh: Chưa đính kèm ảnh'),
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Xem lại')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: AppButtons.primary(),
            child: const Text('Xác nhận lưu'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isSaving = true);
    try {
      final location = SavedLocationModel(
        customerId: widget.customerId,
        latitude: _selectedLatLng.latitude,
        longitude: _selectedLatLng.longitude,
        gpsAccuracy: _gpsAccuracy,
        identificationNotes: notes,
        imageUrl: _existingImageUrl,
      );

      final isSavedToServer = await RepositoryProvider.location.saveCustomerLocation(
        location,
        imageBase64: _base64Image,
      );

      if (!mounted) return;

      if (isSavedToServer) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã lưu vị trí khách hàng thành công trên máy chủ!'),
            backgroundColor: Color(0xFF2E7D32),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã lưu cục bộ offline. Dữ liệu sẽ tự động đồng bộ khi có kết nối mạng.'),
            backgroundColor: Colors.amber,
          ),
        );
      }

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
    final isGpsLowAccuracy = _gpsAccuracy > 20.0;

    return Scaffold(
      appBar: AppBar(
        title: Text('Lưu Vị Trí: ${widget.customerName}'),
        backgroundColor: const Color(0xFF1E88E5),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // STEP 1: GPS Accuracy & Controls
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: isGpsLowAccuracy ? Colors.amber.shade50 : Colors.blue.shade50,
              child: Row(
                children: [
                  Icon(
                    isGpsLowAccuracy ? Icons.warning_amber_rounded : Icons.gps_fixed,
                    color: isGpsLowAccuracy ? Colors.orange.shade800 : Colors.blue,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isLoadingGps
                              ? 'Đang đo tọa độ GPS...'
                              : 'Sai số GPS: ±${_gpsAccuracy.toStringAsFixed(1)} m',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: isGpsLowAccuracy ? Colors.orange.shade900 : Colors.black87,
                          ),
                        ),
                        if (isGpsLowAccuracy && !_isLoadingGps)
                          const Text(
                            'Sai số lớn. Chạm trên bản đồ để kéo ghim vào đúng cổng.',
                            style: TextStyle(fontSize: 11, color: Colors.brown),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.my_location),
                    tooltip: 'Đo lại GPS hiện tại',
                    onPressed: _getCurrentGpsLocation,
                  ),
                ],
              ),
            ),

            // STEP 2: Interactive Map with Pin adjustment
            SizedBox(
              height: 260,
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
                        color: const Color.fromRGBO(0, 0, 0, 0.75),
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

            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tọa độ chọn: ${_selectedLatLng.latitude.toStringAsFixed(6)}, ${_selectedLatLng.longitude.toStringAsFixed(6)}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 16),

                  // STEP 3: House photo capture section
                  const Text(
                    'Ảnh nhận diện mặt tiền/cổng nhà:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 8),

                  if (_capturedImage != null) ...[
                    Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: kIsWeb
                              ? Image.network(
                                  _capturedImage!.path,
                                  height: 180,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                )
                              : Image.file(
                                  File(_capturedImage!.path),
                                  height: 180,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                ),
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: Colors.black54,
                                child: IconButton(
                                  icon: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                                  onPressed: _showImageSourceDialog,
                                  tooltip: 'Chụp lại',
                                ),
                              ),
                              const SizedBox(width: 8),
                              CircleAvatar(
                                backgroundColor: Colors.black54,
                                child: IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.redAccent, size: 20),
                                  onPressed: _removeCapturedImage,
                                  tooltip: 'Xóa ảnh',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    OutlinedButton.icon(
                      onPressed: _showImageSourceDialog,
                      icon: const Icon(Icons.add_a_photo, color: AppButtons.primaryColor),
                      label: const Text('Chụp hoặc chọn ảnh mặt tiền/cổng nhà'),
                      style: AppButtons.secondary(minHeight: 50, borderRadius: 10),
                    ),
                  ],
                  const SizedBox(height: 16),

                  // STEP 4: Identification Notes
                  TextField(
                    controller: _notesController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'Ghi chú nhận diện vị trí *',
                      hintText: 'VD: Hẻm cạnh tạp hóa Hai Thu, cổng sắt xanh da trời, số nhà 124/5...',
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // SUBMIT BUTTON
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _isSaving ? null : _showConfirmationAndSave,
                      icon: const Icon(Icons.check_circle_outline, color: Colors.white),
                      label: _isSaving
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                            )
                          : const Text(
                              'KIỂM TRA & XÁC NHẬN LƯU VỊ TRÍ',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                      style: AppButtons.primary(minHeight: 50, borderRadius: 10),
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
