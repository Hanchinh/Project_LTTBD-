import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/customer_photo_model.dart';
import '../services/api_service.dart';
import 'customer_photos_strip_widget.dart';
import '../theme/app_buttons.dart';

/// Thẻ chi tiết điểm giao / vị trí đã lưu thiết kế cho SHIPPER ĐI XE MỘT TAY (TASK: MULTI-PHOTO-AND-THUMB-UI-015A)
/// - Bottom sheet bám đáy màn hình (vùng ngón cái), vuốt lên để xem thêm, vuốt xuống để đóng.
/// - Không đặt nút quan trọng ở góc trên.
/// - Trên cùng: Dải ảnh cuộn ngang (ảnh to, chạm xem full màn hình, vuốt qua lại các ảnh).
/// - Điểm chưa có ảnh vẫn luôn hiện ô "Chưa có ảnh - Thêm ảnh" cỡ lớn.
/// - Nút "+ Thêm ảnh" lớn (cao >= 56px): mở camera 1 chạm, phụ chọn từ thư viện, nén client <= 1600px/80%.
/// - Giữ ảnh: nhấn giữ -> hộp thoại xóa mềm có xác nhận.
/// - Dưới dải ảnh: Tên khách + SĐT (chữ to), hàng 3 nút lớn chia đều: GỌI | CHỈ ĐƯỜNG | GHIM LẠI.
///   Cỡ chạm >= 56px, khoảng cách >= 12px, chữ >= 16sp, tương phản cao ngoài nắng.
class PointDetailBottomSheet extends StatefulWidget {
  final String customerId;
  final String customerName;
  final String customerPhone;
  final String customerAddress;
  final String? locationStatusText;
  final Color? statusBadgeBg;
  final Color? statusBadgeTextColor;
  final IconData? statusBadgeIcon;
  final String? identificationNotes;
  final double? latitude;
  final double? longitude;
  final List<CustomerPhotoModel> initialPhotos;
  final String? legacyImageUrl;
  final VoidCallback? onCall;
  final VoidCallback? onDirections;
  final VoidCallback? onRepin;
  final ValueChanged<List<CustomerPhotoModel>>? onPhotosUpdated;
  final VoidCallback? onClose;
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

  /// Hàm tiện ích mở bottom sheet dạng modal
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
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      enableDrag: true,
      builder: (modalCtx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.65,
          minChildSize: 0.35,
          maxChildSize: 0.92,
          snap: true,
          snapSizes: const [0.45, 0.65, 0.92],
          builder: (ctx, scrollController) {
            return PointDetailBottomSheet(
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
            );
          },
        );
      },
    );
  }

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
    if (_photos.isEmpty && widget.legacyImageUrl != null && widget.legacyImageUrl!.trim().isNotEmpty) {
      _photos.add(
        CustomerPhotoModel(
          id: 'legacy',
          customerId: widget.customerId,
          imageUrl: widget.legacyImageUrl!.trim(),
        ),
      );
    }
  }

  @override
  void didUpdateWidget(covariant PointDetailBottomSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.customerId != widget.customerId) {
      _photos = List.from(widget.initialPhotos);
    }
  }

  Future<void> _makePhoneCall() async {
    if (widget.onCall != null) {
      widget.onCall!();
      return;
    }
    final cleanPhone = widget.customerPhone.replaceAll(RegExp(r'\D'), '');
    if (cleanPhone.isEmpty) return;
    final url = Uri.parse('tel:$cleanPhone');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  Future<void> _openNavigation() async {
    if (widget.onDirections != null) {
      widget.onDirections!();
      return;
    }
    if (widget.latitude != null && widget.longitude != null) {
      await ApiService.openExternalNavigation(widget.latitude!, widget.longitude!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    // Chiều cao ban đầu khoảng 40-45% màn hình (TASK 017 - Mục B.4)
    final double initialHeight = (screenHeight * 0.46).clamp(365.0, 480.0);
    final double expandedHeight = (screenHeight * 0.85).clamp(450.0, 750.0);
    final double currentHeight = _isExpanded ? expandedHeight : initialHeight;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      height: currentHeight,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(color: Colors.black26, blurRadius: 16, offset: Offset(0, -4)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            // Thanh tiêu đề trên cùng của thẻ: Drag Handle Bar + Nút tắt X (>= 48px, tương phản cao)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onVerticalDragEnd: (details) {
                final v = details.primaryVelocity ?? 0;
                if (v > 250) {
                  // Vuốt xuống
                  if (_isExpanded) {
                    setState(() => _isExpanded = false);
                  } else {
                    widget.onClose?.call();
                  }
                } else if (v < -250) {
                  // Vuốt lên
                  setState(() => _isExpanded = true);
                }
              },
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 6, 12, 4),
                child: Row(
                  children: [
                    // Chỗ trống đối xứng bên trái
                    const SizedBox(width: 48),
                    // Thanh kéo bám đáy (Handle bar) ở giữa
                    Expanded(
                      child: Center(
                        child: Container(
                          width: 44,
                          height: 5,
                          decoration: BoxDecoration(
                            color: const Color(0xFFCBD5E1),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                    ),
                    // Nút tắt X rõ ràng, tương phản cao (vùng chạm >= 48px) (TASK 017 - Mục B.1)
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
                              child: const Icon(
                                Icons.close_rounded,
                                size: 24,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Nội dung cuộn được (cuộn ngón tay một tay)
            Expanded(
              child: NotificationListener<ScrollNotification>(
                onNotification: (notification) {
                  if (notification is OverscrollNotification && notification.overscroll < -20) {
                    if (_isExpanded) {
                      setState(() => _isExpanded = false);
                    } else {
                      widget.onClose?.call();
                    }
                  }
                  return false;
                },
                child: SingleChildScrollView(
                  controller: widget.scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. DẢI ẢNH CUỘN NGANG (TOP OF SHEET) - KHÔNG ĐƯỢC ẨN KHU VỰC ẢNH
                      _buildPhotoArea(),

                    const SizedBox(height: 8),

                    // 2. TÊN KHÁCH HÀNG (CHỮ TO, RÕ RÀNG NGOÀI NẮNG)
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            widget.customerName.isNotEmpty ? widget.customerName : 'Khách hàng',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                              letterSpacing: -0.3,
                            ),
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
                                Icon(
                                  widget.statusBadgeIcon ?? Icons.check_circle_rounded,
                                  color: widget.statusBadgeTextColor ?? const Color(0xFF15803D),
                                  size: 14,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  widget.locationStatusText!,
                                  style: TextStyle(
                                    color: widget.statusBadgeTextColor ?? const Color(0xFF15803D),
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),

                    const SizedBox(height: 2),

                    // SỐ ĐIỆN THOẠI (CHỮ TO, CHẠM GỌI NHANH)
                    GestureDetector(
                      onTap: _makePhoneCall,
                      child: Row(
                        children: [
                          const Icon(Icons.phone_rounded, color: Color(0xFF1D4ED8), size: 18),
                          const SizedBox(width: 6),
                          Text(
                            widget.customerPhone,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1D4ED8),
                              decoration: TextDecoration.underline,
                            ),
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

                    // 3. HÀNG 3 NÚT LỚN CHIA ĐỀU CHIỀU NGANG: GỌI | CHỈ ĐƯỜNG | GHIM LẠI
                    // Cỡ chạm >= 56px, khoảng cách >= 12px, chữ >= 16sp, tương phản cao ngoài nắng
                    _buildOneHandedActionButtons(),

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

  /// Khu vực ảnh cuộn ngang (top của thẻ) sử dụng widget dải ảnh dùng chung
  Widget _buildPhotoArea() {
    return CustomerPhotosStripWidget(
      key: const ValueKey('point_detail_photo_area'),
      customerId: widget.customerId,
      customerName: widget.customerName,
      initialPhotos: _photos,
      legacyImageUrl: widget.legacyImageUrl,
      onPhotosUpdated: (updated) {
        setState(() => _photos = updated);
        widget.onPhotosUpdated?.call(updated);
      },
    );
  }



  /// Hàng 3 nút lớn chia đều chiều ngang: GỌI | CHỈ ĐƯỜNG | GHIM LẠI
  /// - Cỡ chạm tối thiểu 56px
  /// - Khoảng cách giữa nút >= 12px
  /// - Chữ >= 16sp
  /// - Tương phản cao dùng được ngoài nắng
  Widget _buildOneHandedActionButtons() {
    return Row(
      children: [
        // 1. NÚT GỌI (Navy/đen)
        Expanded(
          child: SizedBox(
            height: 56,
            child: ElevatedButton(
              key: const ValueKey('btn_call'),
              style: AppButtons.primaryLarge(
                minHeight: 56,
                borderRadius: 14,
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              ),
              onPressed: _makePhoneCall,
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.phone_in_talk_rounded, size: 20),
                  SizedBox(height: 2),
                  Text(
                    'GỌI',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                  ),
                ],
              ),
            ),
          ),
        ),

        const SizedBox(width: 12),

        // 2. NÚT CHỈ ĐƯỜNG (Navy/đen)
        Expanded(
          child: SizedBox(
            height: 56,
            child: ElevatedButton(
              key: const ValueKey('btn_directions'),
              style: AppButtons.primaryLarge(
                minHeight: 56,
                borderRadius: 14,
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              ),
              onPressed: _openNavigation,
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.directions_rounded, size: 20),
                  SizedBox(height: 2),
                  Text(
                    'CHỈ ĐƯỜNG',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.3),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ),

        const SizedBox(width: 12),

        // 3. NÚT GHIM LẠI (Navy/đen)
        Expanded(
          child: SizedBox(
            height: 56,
            child: ElevatedButton(
              key: const ValueKey('btn_repin'),
              style: AppButtons.primaryLarge(
                minHeight: 56,
                borderRadius: 14,
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              ),
              onPressed: widget.onRepin,
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.edit_location_alt_rounded, size: 20),
                  SizedBox(height: 2),
                  Text(
                    'GHIM LẠI',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.3),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
