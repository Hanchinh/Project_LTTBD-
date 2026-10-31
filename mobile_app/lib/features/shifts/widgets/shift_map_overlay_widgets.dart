import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:delivery_marker_mobile/models/shift_model.dart';
import 'package:delivery_marker_mobile/models/customer_photo_model.dart';
import 'package:delivery_marker_mobile/core/services/map_navigation_service.dart';
import 'package:delivery_marker_mobile/shared_widgets/point_detail_bottom_sheet.dart';

class ShiftPointDetailCard extends StatelessWidget {
  final ShiftDeliveryPointModel point;
  final VoidCallback onCall;
  final VoidCallback onRepin;
  final ValueChanged<List<CustomerPhotoModel>> onPhotosUpdated;
  final VoidCallback onClose;

  const ShiftPointDetailCard({
    super.key,
    required this.point,
    required this.onCall,
    required this.onRepin,
    required this.onPhotosUpdated,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    Color badgeBg;
    Color badgeText;
    IconData badgeIcon;

    switch (point.locationStatus) {
      case LocationStatus.verified:
        badgeBg = const Color(0xFFDCFCE7);
        badgeText = const Color(0xFF15803D);
        badgeIcon = Icons.check_circle_rounded;
        break;
      case LocationStatus.temporary:
        badgeBg = const Color(0xFFFEF3C7);
        badgeText = const Color(0xFFD97706);
        badgeIcon = Icons.pin_drop_rounded;
        break;
      case LocationStatus.noLocation:
        badgeBg = const Color(0xFFF1F5F9);
        badgeText = const Color(0xFF64748B);
        badgeIcon = Icons.location_off_rounded;
        break;
    }

    return RepaintBoundary(
      child: PointDetailBottomSheet(
        customerId: point.customerId,
        customerName: point.customerName,
        customerPhone: point.customerPhone,
        customerAddress: point.customerAddress,
        locationStatusText: point.locationStatus.displayName,
        statusBadgeBg: badgeBg,
        statusBadgeTextColor: badgeText,
        statusBadgeIcon: badgeIcon,
        identificationNotes: point.locationNotes,
        latitude: point.latitude,
        longitude: point.longitude,
        initialPhotos: point.photos,
        legacyImageUrl: point.photoUrl,
        onCall: onCall,
        onDirections: () {
          if (point.hasValidCoordinates) {
            MapNavigationHelper.openExternalNavigation(point.latitude!, point.longitude!);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Khách hàng chưa có tọa độ để chỉ đường')),
            );
          }
        },
        onRepin: onRepin,
        onPhotosUpdated: onPhotosUpdated,
        onClose: onClose,
      ),
    );
  }
}

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

