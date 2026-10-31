// Cụm nút bấm thao tác nhanh trên bottom sheet chi tiết điểm giao.
// Bao gồm nút gọi điện, nút mở ứng dụng chỉ đường và nút ghim lại vị trí.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:delivery_marker_mobile/core/theme/app_buttons.dart';

class PointDetailActionButtons extends StatelessWidget {
  final VoidCallback onCall;
  final VoidCallback onDirections;
  final VoidCallback? onRepin;

  const PointDetailActionButtons({
    super.key,
    required this.onCall,
    required this.onDirections,
    this.onRepin,
  });

  @override
  Widget build(BuildContext context) {
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
              onPressed: () {
                HapticFeedback.lightImpact();
                onCall();
              },
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
              onPressed: () {
                HapticFeedback.lightImpact();
                onDirections();
              },
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
              onPressed: onRepin == null
                  ? null
                  : () {
                      HapticFeedback.lightImpact();
                      onRepin!();
                    },
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
