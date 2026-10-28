import 'dart:math' as math;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:delivery_marker_mobile/models/data_share_model.dart';
import 'package:delivery_marker_mobile/models/location_model.dart';

/// Lớp đại diện cho cụm điểm (Cluster) trên Bản đồ chính
class LocationCluster {
  final LatLng center;
  final List<MasterSavedLocationModel> items;

  LocationCluster({required this.center, required this.items});
}

/// Lớp đại diện cho cụm điểm được chia sẻ (TASK 023)
class SharedLocationCluster {
  final LatLng center;
  final List<SharedLocationPointModel> items;

  SharedLocationCluster({required this.center, required this.items});
}

/// Helper tính toán gom cụm (Clustering) thuần Dart
class MarkerClusterHelper {
  /// Thuật toán gom cụm cho vị trí đã lưu của shipper
  static List<LocationCluster> clusterLocations(
    List<MasterSavedLocationModel> locations,
    double zoom, {
    LatLngBounds? bounds,
  }) {
    if (locations.isEmpty) return [];

    // Lọc theo khung nhìn (viewport bounds) nếu có
    final visibleLocations = bounds != null
        ? locations.where((loc) {
            if (loc.latitude == 0.0 && loc.longitude == 0.0) return false;
            final lat = loc.latitude;
            final lng = loc.longitude;
            return lat >= bounds.south - 0.01 &&
                lat <= bounds.north + 0.01 &&
                lng >= bounds.west - 0.01 &&
                lng <= bounds.east + 0.01;
          }).toList()
        : locations;

    if (visibleLocations.isEmpty) return [];

    // Khi zoom sâu (>= 16.5), bung toàn bộ thành marker đơn lẻ
    if (zoom >= 16.5) {
      return visibleLocations
          .where((loc) => loc.latitude != 0.0 && loc.longitude != 0.0)
          .map((loc) => LocationCluster(
                center: LatLng(loc.latitude, loc.longitude),
                items: [loc],
              ))
          .toList();
    }

    final double threshold = 0.065 / math.pow(2, (zoom - 10).clamp(0.0, 10.0));
    final List<LocationCluster> clusters = [];

    for (final loc in visibleLocations) {
      if (loc.latitude == 0.0 && loc.longitude == 0.0) continue;
      final point = LatLng(loc.latitude, loc.longitude);
      bool merged = false;

      for (int i = 0; i < clusters.length; i++) {
        final c = clusters[i];
        final double dLat = (c.center.latitude - point.latitude).abs();
        final double dLng = (c.center.longitude - point.longitude).abs();
        final double dist = math.sqrt(dLat * dLat + dLng * dLng);

        if (dist <= threshold) {
          final int newCount = c.items.length + 1;
          final double newLat = (c.center.latitude * c.items.length + point.latitude) / newCount;
          final double newLng = (c.center.longitude * c.items.length + point.longitude) / newCount;

          clusters[i] = LocationCluster(
            center: LatLng(newLat, newLng),
            items: [...c.items, loc],
          );
          merged = true;
          break;
        }
      }

      if (!merged) {
        clusters.add(LocationCluster(center: point, items: [loc]));
      }
    }

    return clusters;
  }

  /// Thuật toán gom cụm cho các điểm chia sẻ (TASK 023)
  static List<SharedLocationCluster> clusterSharedLocations(
    List<SharedLocationPointModel> locations,
    double zoom,
  ) {
    if (locations.isEmpty) return [];

    if (zoom >= 16.5) {
      return locations
          .where((loc) => loc.latitude != 0.0 && loc.longitude != 0.0)
          .map((loc) => SharedLocationCluster(
                center: LatLng(loc.latitude, loc.longitude),
                items: [loc],
              ))
          .toList();
    }

    final double threshold = 0.065 / math.pow(2, (zoom - 10).clamp(0.0, 10.0));
    final List<SharedLocationCluster> clusters = [];

    for (final loc in locations) {
      if (loc.latitude == 0.0 && loc.longitude == 0.0) continue;
      final point = LatLng(loc.latitude, loc.longitude);
      bool merged = false;

      for (int i = 0; i < clusters.length; i++) {
        final c = clusters[i];
        final double dLat = (c.center.latitude - point.latitude).abs();
        final double dLng = (c.center.longitude - point.longitude).abs();
        final double dist = math.sqrt(dLat * dLat + dLng * dLng);

        if (dist <= threshold) {
          final int newCount = c.items.length + 1;
          final double newLat = (c.center.latitude * c.items.length + point.latitude) / newCount;
          final double newLng = (c.center.longitude * c.items.length + point.longitude) / newCount;

          clusters[i] = SharedLocationCluster(
            center: LatLng(newLat, newLng),
            items: [...c.items, loc],
          );
          merged = true;
          break;
        }
      }

      if (!merged) {
        clusters.add(SharedLocationCluster(center: point, items: [loc]));
      }
    }

    return clusters;
  }
}
