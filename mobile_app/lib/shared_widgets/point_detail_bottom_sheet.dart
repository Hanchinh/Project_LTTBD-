import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:delivery_marker_mobile/models/customer_photo_model.dart';
import 'package:delivery_marker_mobile/core/utils/map_navigation_helper.dart';
import 'package:delivery_marker_mobile/features/photos/customer_photos_strip_widget.dart';
import 'package:delivery_marker_mobile/features/sharing/data_share_send_sheet.dart';
import 'package:delivery_marker_mobile/shared_widgets/point_detail/point_detail_action_buttons.dart';

/// Thẻ chi tiết điểm giao / vị trí đã lưu thiết kế cho Shipper một tay
class PointDetailBottomSheet extends StatefulWidget {
  final String customerId, customerName, customerPhone, customerAddress;
  final String? locationStatusText, identificationNotes, legacyImageUrl;
  final Color? statusBadgeBg, statusBadgeTextColor;
  final IconData? statusBadgeIcon;
  final double? latitude, longitude;
  final List<CustomerPhotoModel> initialPhotos;
  final VoidCallback? onCall, onDirections, onRepin, onClose;
  final ValueChanged<List<CustomerPhotoModel>>? onPhotosUpdated;
  final ScrollController? scrollController;

  const PointDetailBottomSheet({
    super.key,
    required this.customerId,
    required this.customerName,
    required this.customerPhone,
    this.customerAddress = '',
    this.locationStatusText,
    this.statusBadgeBg,
    this.statusBadgeTextColor,
    this.statusBadgeIcon,
    this.identificationNotes,
    this.latitude,
    this.longitude,
    this.initialPhotos = const [],
    this.legacyImageUrl,
    this.onCall,
    this.onDirections,
    this.onRepin,
    this.onPhotosUpdated,
    this.onClose,
    this.scrollController,
  });

  static Future<void> show(
    BuildContext context, {
    required String customerId,
    required String customerName,
    required String customerPhone,
    String customerAddress = '',
    String? locationStatusText,
    Color? statusBadgeBg,
    Color? statusBadgeTextColor,
    IconData? statusBadgeIcon,
    String? identificationNotes,
    double? latitude,
    double? longitude,
    List<CustomerPhotoModel> initialPhotos = const [],
    String? legacyImageUrl,
    VoidCallback? onCall,
    VoidCallback? onDirections,
    VoidCallback? onRepin,
    ValueChanged<List<CustomerPhotoModel>>? onPhotosUpdated,
  }) =>
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        enableDrag: true,
        builder: (modalCtx) => DraggableScrollableSheet(
          initialChildSize: 0.65,
          minChildSize: 0.35,
          maxChildSize: 0.92,
          snap: true,
          snapSizes: const [0.45, 0.65, 0.92],
          builder: (ctx, scrollController) => PointDetailBottomSheet(
            customerId: customerId,
            customerName: customerName,
            customerPhone: customerPhone,
            customerAddress: customerAddress,
            locationStatusText: locationStatusText,
            statusBadgeBg: statusBadgeBg,
            statusBadgeTextColor: statusBadgeTextColor,
            statusBadgeIcon: statusBadgeIcon,
            identificationNotes: identificationNotes,
            latitude: latitude,
            longitude: longitude,
            initialPhotos: initialPhotos,
            legacyImageUrl: legacyImageUrl,
            onCall: onCall,
            onDirections: onDirections,
            onRepin: onRepin,
            onPhotosUpdated: onPhotosUpdated,
            onClose: () => Navigator.pop(modalCtx),
            scrollController: scrollController,
          ),
        ),
      );

  @override
  State<PointDetailBottomSheet> createState() => _PointDetailBottomSheetState();
}

class _PointDetailBottomSheetState extends State<PointDetailBottomSheet> {
  List<CustomerPhotoModel> _photos = [];
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _photos = List.from(widget.initialPhotos);
    final leg = widget.legacyImageUrl?.trim();
    if (_photos.isEmpty && leg != null && leg.isNotEmpty) {
      _photos.add(CustomerPhotoModel(id: 'legacy', customerId: widget.customerId, imageUrl: leg));
    }
  }

  @override
  void didUpdateWidget(covariant PointDetailBottomSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.customerId != widget.customerId) _photos = List.from(widget.initialPhotos);
  }

  Future<void> _makePhoneCall() async {
    if (widget.onCall != null) return widget.onCall!();
    final clean = widget.customerPhone.replaceAll(RegExp(r'\D'), '');
    if (clean.isEmpty) return;
    final url = Uri.parse('tel:$clean');
    if (await canLaunchUrl(url)) await launchUrl(url);
  }

  Future<void> _openNavigation() async {
    if (widget.onDirections != null) return widget.onDirections!();
    if (widget.latitude != null && widget.longitude != null) {
      await MapNavigationHelper.openExternalNavigation(widget.latitude!, widget.longitude!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.sizeOf(context).height;
    final curH = _isExpanded ? (h * 0.85).clamp(450.0, 750.0) : (h * 0.46).clamp(365.0, 480.0);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      height: curH,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 16, offset: Offset(0, -4))],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onVerticalDragEnd: (d) {
                final v = d.primaryVelocity ?? 0;
                if (v > 250) {
                  _isExpanded ? setState(() => _isExpanded = false) : widget.onClose?.call();
                } else if (v < -250) {
                  setState(() => _isExpanded = true);
                }
              },
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 6, 12, 4),
                child: Row(
                  children: [
                    const SizedBox(width: 48),
                    Expanded(
                      child: Center(
                        child: Container(
                          width: 44,
                          height: 5,
                          decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(3)),
                        ),
                      ),
                    ),
                    Semantics(
                      label: 'Đóng thẻ chi tiết',
                      button: true,
                      child: Tooltip(
                        message: 'Đóng',
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            key: const ValueKey('btn_close_point_detail'),
                            borderRadius: BorderRadius.circular(24),
                            onTap: widget.onClose,
                            child: Container(
                              width: 48,
                              height: 48,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                shape: BoxShape.circle,
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: const Icon(Icons.close_rounded, size: 24, color: Color(0xFF0F172A)),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: NotificationListener<ScrollNotification>(
                onNotification: (n) {
                  if (n is OverscrollNotification && n.overscroll < -20) {
                    _isExpanded ? setState(() => _isExpanded = false) : widget.onClose?.call();
                  }
                  return false;
                },
                child: SingleChildScrollView(
                  controller: widget.scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CustomerPhotosStripWidget(
                        key: const ValueKey('point_detail_photo_area'),
                        customerId: widget.customerId,
                        customerName: widget.customerName,
                        initialPhotos: _photos,
                        legacyImageUrl: widget.legacyImageUrl,
                        onPhotosUpdated: (u) {
                          setState(() => _photos = u);
                          widget.onPhotosUpdated?.call(u);
                        },
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              widget.customerName.isNotEmpty ? widget.customerName : 'Khách hàng',
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A), letterSpacing: -0.3),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (widget.locationStatusText != null) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: widget.statusBadgeBg ?? const Color(0xFFDCFCE7),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(widget.statusBadgeIcon ?? Icons.check_circle_rounded, color: widget.statusBadgeTextColor ?? const Color(0xFF15803D), size: 14),
                                  const SizedBox(width: 4),
                                  Text(
                                    widget.locationStatusText!,
                                    style: TextStyle(color: widget.statusBadgeTextColor ?? const Color(0xFF15803D), fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(width: 6),
                          IconButton(
                            key: const Key('btn_quick_share_point'),
                            icon: const Icon(Icons.share_outlined, color: Color(0xFF0F172A), size: 22),
                            tooltip: 'Chia sẻ điểm này',
                            padding: const EdgeInsets.all(8),
                            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                            onPressed: () => DataShareSendSheet.show(context, initialCustomerIds: [widget.customerId], singleCustomerName: widget.customerName),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      GestureDetector(
                        onTap: _makePhoneCall,
                        child: Row(
                          children: [
                            const Icon(Icons.phone_rounded, color: Color(0xFF1D4ED8), size: 18),
                            const SizedBox(width: 6),
                            Text(
                              widget.customerPhone,
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1D4ED8), decoration: TextDecoration.underline),
                            ),
                          ],
                        ),
                      ),
                      if (widget.customerAddress.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.location_on_outlined, color: Color(0xFF64748B), size: 16),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                widget.customerAddress,
                                style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (widget.identificationNotes != null && widget.identificationNotes!.trim().isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Text(
                            'Ghi chú: ${widget.identificationNotes!}',
                            style: const TextStyle(fontSize: 13, color: Color(0xFF334155), fontStyle: FontStyle.italic),
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      PointDetailActionButtons(
                        onCall: _makePhoneCall,
                        onDirections: _openNavigation,
                        onRepin: widget.onRepin,
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
