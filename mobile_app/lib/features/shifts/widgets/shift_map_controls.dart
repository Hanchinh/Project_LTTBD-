// Cụm nút điều khiển chuyên biệt trên màn hình bản đồ ca làm việc.
// Bao gồm nút căn chỉnh toàn bộ lộ trình ca, nút vị trí GPS và nút danh sách mốc.
import 'package:flutter/material.dart';

class ShiftMapToolButtons extends StatelessWidget {
  final bool isLocatingShipper;
  final VoidCallback onMyLocationTap;
  final VoidCallback onSwitchMapType;
  final VoidCallback onFitBounds;

  const ShiftMapToolButtons({
    super.key,
    required this.isLocatingShipper,
    required this.onMyLocationTap,
    required this.onSwitchMapType,
    required this.onFitBounds,
  });

  Widget _buildMapToolButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    Color iconColor = const Color(0xFF0F172A),
    bool isLoading = false,
  }) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Center(
            child: isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF2563EB)),
                  )
                : Icon(icon, color: iconColor, size: 22),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildMapToolButton(
          icon: Icons.my_location_rounded,
          tooltip: 'Vị trí của tôi',
          isLoading: isLocatingShipper,
          iconColor: const Color(0xFF2563EB),
          onTap: onMyLocationTap,
        ),
        const SizedBox(height: 8),
        _buildMapToolButton(
          icon: Icons.layers_outlined,
          tooltip: 'Đổi kiểu bản đồ',
          iconColor: const Color(0xFF0F172A),
          onTap: onSwitchMapType,
        ),
        const SizedBox(height: 8),
        _buildMapToolButton(
          icon: Icons.crop_free_rounded,
          tooltip: 'Xem toàn bộ điểm',
          iconColor: const Color(0xFF0F172A),
          onTap: onFitBounds,
        ),
      ],
    );
  }
}

class ShiftMapActionButtons extends StatelessWidget {
  final VoidCallback onBulkPasteTap;
  final VoidCallback onChooseLocationTap;

  const ShiftMapActionButtons({
    super.key,
    required this.onBulkPasteTap,
    required this.onChooseLocationTap,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Semantics(
              label: 'Dán danh sách SĐT',
              button: true,
              child: Tooltip(
                message: 'Dán danh sách SĐT',
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    key: const Key('btn_bulk_paste_phones'),
                    borderRadius: BorderRadius.circular(28),
                    onTap: onBulkPasteTap,
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: const BoxDecoration(
                        color: Color(0xFF0F172A),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: Color(0x660F172A), blurRadius: 10, offset: Offset(0, 4)),
                        ],
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.playlist_add_rounded,
                          size: 28,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Semantics(
              label: 'Chọn vị trí',
              button: true,
              child: Tooltip(
                message: 'Chọn vị trí',
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    key: const Key('btn_choose_location'),
                    borderRadius: BorderRadius.circular(28),
                    onTap: onChooseLocationTap,
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: const BoxDecoration(
                        color: Color(0xFF0F172A),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 3)),
                        ],
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.add_location_alt_rounded,
                          size: 24,
                          color: Colors.white,
                        ),
                      ),
                    ),
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
