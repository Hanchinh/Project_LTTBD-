// Tập hợp các widget phủ trên bản đồ chính: thẻ thông tin mốc, chú thích và cảnh báo.
// Hiển thị tóm tắt điểm giao khi tài xế chạm vào marker trên bản đồ.
import 'package:flutter/material.dart';
import 'package:delivery_marker_mobile/core/services/map_navigation_service.dart';
import 'package:delivery_marker_mobile/models/location_model.dart';
import 'package:delivery_marker_mobile/core/widgets/point_detail_bottom_sheet.dart';

/// Thẻ xem chi tiết vị trí đã lưu trên bản đồ chính
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

/// Banner cảnh báo điểm chia sẻ ngoài khu vực hoạt động
class OutOfAreaBanner extends StatelessWidget {
  final int count;
  final VoidCallback onDismiss;

  const OutOfAreaBanner({
    super.key,
    required this.count,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      key: const Key('banner_out_of_area_warning'),
      top: 62,
      left: 14,
      right: 14,
      child: SafeArea(
        child: Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(10),
          color: const Color(0xFFFEF3C7),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Color(0xFFD97706), size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$count điểm không hiển thị vì ngoài khu vực của bạn',
                    style: const TextStyle(color: Color(0xFF92400E), fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  key: const Key('btn_close_out_of_area_banner'),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: const Icon(Icons.close_rounded, size: 16, color: Color(0xFF92400E)),
                  tooltip: 'Đóng cảnh báo',
                  onPressed: onDismiss,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Legend phân biệt màu sắc marker: Xanh (Của tôi) - Tím (Được chia sẻ)
class MapLegendWidget extends StatelessWidget {
  final bool isOutOfAreaBannerVisible;

  const MapLegendWidget({
    super.key,
    required this.isOutOfAreaBannerVisible,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: isOutOfAreaBannerVisible ? 112 : 62,
      left: 14,
      child: SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle),
              ),
              const SizedBox(width: 4),
              const Text(
                'Của tôi',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
              ),
              const SizedBox(width: 10),
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(color: Color(0xFF7C3AED), shape: BoxShape.circle),
              ),
              const SizedBox(width: 4),
              const Text(
                'Được chia sẻ',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

