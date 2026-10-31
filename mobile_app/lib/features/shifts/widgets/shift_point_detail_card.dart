import 'package:flutter/material.dart';
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
