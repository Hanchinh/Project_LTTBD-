import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class MapMarkerCloneApp extends StatelessWidget {
  const MapMarkerCloneApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Map Marker Prototype',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepOrange),
        useMaterial3: true,
      ),
      home: const MapMarkerScreen(),
    );
  }
}

// Model dữ liệu của từng Marker
class PlaceMarker {
  final String id;
  String title;
  String description;
  double latitude;
  double longitude;
  int colorValue;

  PlaceMarker({
    required this.id,
    required this.title,
    required this.description,
    required this.latitude,
    required this.longitude,
    required this.colorValue,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'description': description,
        'latitude': latitude,
        'longitude': longitude,
        'colorValue': colorValue,
      };

  factory PlaceMarker.fromMap(Map<String, dynamic> map) => PlaceMarker(
        id: map['id'],
        title: map['title'] ?? '',
        description: map['description'] ?? '',
        latitude: map['latitude'],
        longitude: map['longitude'],
        colorValue: map['colorValue'] ?? 0xFFE53935,
      );
}

class MapMarkerScreen extends StatefulWidget {
  const MapMarkerScreen({super.key});

  @override
  State<MapMarkerScreen> createState() => _MapMarkerScreenState();
}

class _MapMarkerScreenState extends State<MapMarkerScreen> {
  final MapController _mapController = MapController();
  LatLng _currentCenter = const LatLng(10.7769, 106.7009); // Mặc định TP.HCM
  final List<PlaceMarker> _savedMarkers = [];
  bool _isLoadingGps = false;

  static const List<Color> _availableColors = [
    Colors.red,
    Colors.blue,
    Colors.green,
    Colors.orange,
    Colors.purple,
  ];

  int _currentMapType = 0; // 0: Google Maps, 1: Vệ tinh Hybrid, 2: OpenStreetMap Voyager

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

  @override
  void initState() {
    super.initState();
    _loadMarkersFromStorage();
    _moveToUserLocation();
  }

  // Tải danh sách mốc đã lưu từ SharedPreferences
  Future<void> _loadMarkersFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = prefs.getStringList('saved_markers_data') ?? [];
    setState(() {
      _savedMarkers.clear();
      for (final item in jsonList) {
        _savedMarkers.add(PlaceMarker.fromMap(jsonDecode(item)));
      }
    });
  }

  // Lưu danh sách mốc vào bộ nhớ máy
  Future<void> _saveMarkersToStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = _savedMarkers.map((m) => jsonEncode(m.toMap())).toList();
    await prefs.setStringList('saved_markers_data', jsonList);
  }

  // Lấy vị trí GPS và bay camera về đó
  Future<void> _moveToUserLocation() async {
    setState(() => _isLoadingGps = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => _isLoadingGps = false);
        return;
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() => _isLoadingGps = false);
          return;
        }
      }

      final position = await Geolocator.getCurrentPosition();
      final myLatLng = LatLng(position.latitude, position.longitude);
      setState(() {
        _currentCenter = myLatLng;
        _isLoadingGps = false;
      });
      _mapController.move(myLatLng, 16.0);
    } catch (_) {
      setState(() => _isLoadingGps = false);
    }
  }

  // Hộp thoại tạo mới hoặc sửa Marker
  void _showAddEditMarkerDialog(LatLng targetPoint,
      {PlaceMarker? existingMarker}) {
    final titleController =
        TextEditingController(text: existingMarker?.title ?? '');
    final descController =
        TextEditingController(text: existingMarker?.description ?? '');
    Color selectedColor = existingMarker != null
        ? Color(existingMarker.colorValue)
        : _availableColors.first;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title:
                Text(existingMarker == null ? 'Thêm mốc mới' : 'Chỉnh sửa mốc'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tọa độ: ${targetPoint.latitude.toStringAsFixed(5)}, ${targetPoint.longitude.toStringAsFixed(5)}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: 'Tên địa điểm / Tên khách hàng',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Ghi chú nhận diện (hẻm, số nhà, cổng...)',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text('Màu biểu tượng ghim:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: _availableColors.map((color) {
                      final isSelected = color.toARGB32() == selectedColor.toARGB32();
                      return GestureDetector(
                        onTap: () =>
                            setDialogState(() => selectedColor = color),
                        child: CircleAvatar(
                          backgroundColor: color,
                          radius: isSelected ? 18 : 14,
                          child: isSelected
                              ? const Icon(Icons.check,
                                  color: Colors.white, size: 18)
                              : null,
                        ),
                      );
                    }).toList(),
                  )
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Hủy'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (titleController.text.trim().isEmpty) return;

                  setState(() {
                    if (existingMarker != null) {
                      existingMarker.title = titleController.text.trim();
                      existingMarker.description = descController.text.trim();
                      existingMarker.colorValue = selectedColor.toARGB32();
                    } else {
                      _savedMarkers.add(PlaceMarker(
                        id: DateTime.now().millisecondsSinceEpoch.toString(),
                        title: titleController.text.trim(),
                        description: descController.text.trim(),
                        latitude: targetPoint.latitude,
                        longitude: targetPoint.longitude,
                        colorValue: selectedColor.toARGB32(),
                      ));
                    }
                  });
                  _saveMarkersToStorage();
                  Navigator.pop(ctx);
                },
                child: const Text('Lưu mốc'),
              ),
            ],
          );
        },
      ),
    );
  }

  // Xem chi tiết Marker dưới dạng BottomSheet
  void _showMarkerDetails(PlaceMarker marker) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.location_on,
                      color: Color(marker.colorValue), size: 32),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      marker.title,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.blue),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _showAddEditMarkerDialog(
                        LatLng(marker.latitude, marker.longitude),
                        existingMarker: marker,
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () {
                      setState(() {
                        _savedMarkers.removeWhere((m) => m.id == marker.id);
                      });
                      _saveMarkersToStorage();
                      Navigator.pop(ctx);
                    },
                  ),
                ],
              ),
              const Divider(),
              const SizedBox(height: 6),
              const Text('Ghi chú nhận diện:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              Text(
                marker.description.isEmpty
                    ? 'Không có ghi chú'
                    : marker.description,
                style: const TextStyle(fontSize: 14, color: Colors.black87),
              ),
              const SizedBox(height: 8),
              Text(
                'Tọa độ: ${marker.latitude.toStringAsFixed(6)}, ${marker.longitude.toStringAsFixed(6)}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(Icons.navigation),
                  label: const Text('DẪN ĐƯỜNG VỚI GOOGLE MAPS'),
                  onPressed: () async {
                    final googleNavUrl = Uri.parse(
                        'google.navigation:q=${marker.latitude},${marker.longitude}&mode=d');
                    final webFallbackUrl = Uri.parse(
                        'https://www.google.com/maps/dir/?api=1&destination=${marker.latitude},${marker.longitude}');

                    if (await canLaunchUrl(googleNavUrl)) {
                      await launchUrl(googleNavUrl);
                    } else {
                      await launchUrl(webFallbackUrl,
                          mode: LaunchMode.externalApplication);
                    }
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Danh sách toàn bộ các Marker đã lưu
  void _showAllMarkersList() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          builder: (_, scrollController) {
            return Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Danh sách mốc đã lưu (${_savedMarkers.length})',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: _savedMarkers.isEmpty
                      ? const Center(child: Text('Chưa có mốc nào được lưu.'))
                      : ListView.separated(
                          controller: scrollController,
                          itemCount: _savedMarkers.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final m = _savedMarkers[index];
                            return ListTile(
                              leading: Icon(Icons.place,
                                  color: Color(m.colorValue), size: 30),
                              title: Text(m.title,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600)),
                              subtitle: Text(
                                m.description.isEmpty
                                    ? 'Không có ghi chú'
                                    : m.description,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () {
                                Navigator.pop(ctx);
                                final target = LatLng(m.latitude, m.longitude);
                                _mapController.move(target, 17.0);
                                _showMarkerDetails(m);
                              },
                            );
                          },
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Map Marker App',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        actions: [
          IconButton(
            icon: const Icon(Icons.layers_outlined),
            tooltip: 'Đổi kiểu bản đồ',
            onPressed: () {
              setState(() {
                _currentMapType = (_currentMapType + 1) % 3;
              });
              final mapNames = [
                'Google Maps (Đường phố)',
                'Google Hybrid (Vệ tinh + Tên đường)',
                'OpenStreetMap (Voyager)'
              ];
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  duration: const Duration(seconds: 1),
                  content: Text('Chuyển sang: ${mapNames[_currentMapType]}'),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.list_alt),
            tooltip: 'Danh sách mốc',
            onPressed: _showAllMarkersList,
          ),
        ],
      ),
      body: Stack(
        children: [
          // Lớp bản đồ
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentCenter,
              initialZoom: 15.0,
              onTap: (tapPosition, point) => _showAddEditMarkerDialog(point),
            ),
            children: [
              TileLayer(
                key: ValueKey(_currentMapType),
                urlTemplate: _getUrlTemplate(),
                subdomains: _getSubdomains(),
                userAgentPackageName: 'com.example.delivery_marker_mobile',
              ),
              MarkerLayer(
                markers: _savedMarkers.map((m) {
                  return Marker(
                    point: LatLng(m.latitude, m.longitude),
                    width: 45,
                    height: 45,
                    child: GestureDetector(
                      onTap: () => _showMarkerDetails(m),
                      child: Icon(
                        Icons.location_on,
                        size: 42,
                        color: Color(m.colorValue),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),

          // Thanh gợi ý thao tác
          const Positioned(
            top: 10,
            left: 15,
            right: 15,
            child: Card(
              elevation: 3,
              child: Padding(
                padding:
                    EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: Row(
                  children: [
                    Icon(Icons.touch_app, size: 20, color: Colors.deepOrange),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Chạm vào bản đồ để tạo mốc mới',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.small(
            heroTag: 'fab_list',
            onPressed: _showAllMarkersList,
            backgroundColor: Colors.white,
            child: const Icon(Icons.bookmarks, color: Colors.black87),
          ),
          const SizedBox(height: 10),
          FloatingActionButton(
            heroTag: 'fab_gps',
            onPressed: _isLoadingGps ? null : _moveToUserLocation,
            child: _isLoadingGps
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5, color: Colors.white),
                  )
                : const Icon(Icons.my_location),
          ),
        ],
      ),
    );
  }
}
