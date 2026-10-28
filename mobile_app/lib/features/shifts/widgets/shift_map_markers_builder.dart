import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:delivery_marker_mobile/models/shift_model.dart';

class ShiftMapMarkersBuilder {
  static List<Marker> build({
    required LatLng? shipperLocation,
    required List<ShiftDeliveryPointModel> validPoints,
    required ShiftDeliveryPointModel? selectedPoint,
    required ValueChanged<ShiftDeliveryPointModel> onPointSelected,
  }) {
    return [
      if (shipperLocation != null)
        Marker(
          point: shipperLocation,
          width: 48,
          height: 48,
          child: Center(
            child: Container(
              width: 22,
              height: 22,
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
        ),
      ...validPoints.map((point) {
        final isSelected = selectedPoint?.id == point.id;
        final isVerified = point.locationStatus == LocationStatus.verified;
        final markerColor = isVerified ? const Color(0xFF10B981) : const Color(0xFFF59E0B);

        return Marker(
          point: point.latLng!,
          width: isSelected ? 48 : 40,
          height: isSelected ? 48 : 40,
          child: GestureDetector(
            onTap: () => onPointSelected(point),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                color: markerColor,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white,
                  width: isSelected ? 3 : 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isSelected ? markerColor.withValues(alpha: 0.5) : Colors.black26,
                    blurRadius: isSelected ? 8 : 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: Icon(
                  isVerified ? Icons.check_circle_rounded : Icons.pin_drop_rounded,
                  color: Colors.white,
                  size: isSelected ? 24 : 20,
                ),
              ),
            ),
          ),
        );
      }),
    ];
  }
}
