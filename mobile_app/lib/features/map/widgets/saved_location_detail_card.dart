import 'package:flutter/material.dart';
import 'package:delivery_marker_mobile/models/location_model.dart';
import 'package:delivery_marker_mobile/core/services/map_navigation_service.dart';
import 'package:delivery_marker_mobile/shared_widgets/point_detail_bottom_sheet.dart';

class SavedLocationDetailCard extends StatelessWidget {
  final MasterSavedLocationModel location;
  final VoidCallback onCall;
  final VoidCallback onRepin;
  final VoidCallback onClose;

  const SavedLocationDetailCard({
    super.key,
    required this.location,
    required this.onCall,
    required this.onRepin,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: PointDetailBottomSheet(
        customerId: location.customerId,
        customerName: location.customerName,
        customerPhone: location.customerPhone,
        customerAddress: location.customerAddress,
        locationStatusText: 'ĐÃ XÁC NHẬN',
        statusBadgeBg: const Color(0xFFDCFCE7),
        statusBadgeTextColor: const Color(0xFF15803D),
        statusBadgeIcon: Icons.check_circle_rounded,
        identificationNotes: location.identificationNotes,
        latitude: location.latitude,
        longitude: location.longitude,
        initialPhotos: location.photos,
        legacyImageUrl: location.imageUrl,
        onCall: onCall,
        onDirections: () {
          MapNavigationHelper.openExternalNavigation(location.latitude, location.longitude);
        },
        onRepin: onRepin,
        onPhotosUpdated: (updatedPhotos) {
          location.photos.clear();
          location.photos.addAll(updatedPhotos);
        },
        onClose: onClose,
      ),
    );
  }
}
