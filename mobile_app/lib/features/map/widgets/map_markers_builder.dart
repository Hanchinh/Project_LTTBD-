import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:delivery_marker_mobile/models/local_share_models.dart';
import 'package:delivery_marker_mobile/models/location_model.dart';
import 'package:delivery_marker_mobile/features/map/widgets/marker_cluster_helper.dart';

/// Lớp hỗ trợ tạo Marker cho FlutterMap trong MainMapView
class MapMarkersBuilder {
  /// Marker vị trí GPS thực tế của Shipper (chấm xanh radar)
  static Marker? buildShipperMarker(LatLng? shipperLocation) {
    if (shipperLocation == null) return null;
    return Marker(
      point: shipperLocation,
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
    );
  }

  /// Danh sách Marker cho các vị trí đã lưu của shipper (xanh lá #10B981)
  static List<Marker> buildSavedLocationMarkers({
    required List<LocationCluster> clusters,
    required MasterSavedLocationModel? selectedLocation,
    required double currentZoom,
    required void Function(LatLng center, double targetZoom) onClusterTap,
    required void Function(MasterSavedLocationModel location) onLocationTap,
  }) {
    return clusters.map((cluster) {
      final isCluster = cluster.items.length > 1;

      if (isCluster) {
        // MARKER CỤM (CLUSTER BADGE)
        final count = cluster.items.length;
        return Marker(
          point: cluster.center,
          width: 48,
          height: 48,
          child: GestureDetector(
            onTap: () => onClusterTap(cluster.center, (currentZoom + 2.5).clamp(1.0, 18.0)),
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
        final isSelected = selectedLocation?.id == item.id;

        return Marker(
          point: cluster.center,
          width: isSelected ? 48 : 40,
          height: isSelected ? 48 : 40,
          child: GestureDetector(
            onTap: () => onLocationTap(item),
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
    }).toList();
  }

  /// Danh sách Marker cho các vị trí được chia sẻ (tím #7C3AED)
  static List<Marker> buildSharedLocationMarkers({
    required List<SharedLocationCluster> sharedClusters,
    required SharedLocationPointModel? selectedSharedLocation,
    required double currentZoom,
    required void Function(LatLng center, double targetZoom) onClusterTap,
    required void Function(SharedLocationPointModel point) onPointTap,
  }) {
    return sharedClusters.map((cluster) {
      final isCluster = cluster.items.length > 1;

      if (isCluster) {
        // MARKER CỤM CHIA SẺ (PURPLE CLUSTER BADGE)
        final count = cluster.items.length;
        return Marker(
          point: cluster.center,
          width: 48,
          height: 48,
          child: GestureDetector(
            onTap: () => onClusterTap(cluster.center, (currentZoom + 2.5).clamp(1.0, 18.0)),
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
        final isSelected = selectedSharedLocation?.customerId == item.customerId;

        return Marker(
          point: cluster.center,
          width: isSelected ? 48 : 40,
          height: isSelected ? 48 : 40,
          child: GestureDetector(
            onTap: () => onPointTap(item),
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
    }).toList();
  }
}
