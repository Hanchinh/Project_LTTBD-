import 'package:flutter/material.dart';

class CrosshairMapControls extends StatelessWidget {
  final bool isLoadingGps;
  final VoidCallback onMyLocation;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;

  const CrosshairMapControls({
    super.key,
    required this.isLoadingGps,
    required this.onMyLocation,
    required this.onZoomIn,
    required this.onZoomOut,
  });

  Widget _buildPickerToolButton({
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
        _buildPickerToolButton(
          icon: Icons.my_location_rounded,
          tooltip: 'Về vị trí GPS của tôi',
          isLoading: isLoadingGps,
          iconColor: const Color(0xFF2563EB),
          onTap: onMyLocation,
        ),
        const SizedBox(height: 8),
        _buildPickerToolButton(
          icon: Icons.add_rounded,
          tooltip: 'Phóng to',
          onTap: onZoomIn,
        ),
        const SizedBox(height: 8),
        _buildPickerToolButton(
          icon: Icons.remove_rounded,
          tooltip: 'Thu nhỏ',
          onTap: onZoomOut,
        ),
      ],
    );
  }
}
