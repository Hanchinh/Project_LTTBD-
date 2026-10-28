import 'package:flutter/material.dart';

/// Legend phân biệt màu sắc marker: Xanh (Của tôi) - Tím (Được chia sẻ) (TASK 023)
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
