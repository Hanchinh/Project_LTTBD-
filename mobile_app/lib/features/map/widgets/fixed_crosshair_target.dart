import 'package:flutter/material.dart';

class FixedCrosshairTarget extends StatelessWidget {
  const FixedCrosshairTarget({super.key});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: SizedBox(
          width: 90,
          height: 90,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFEF4444), width: 2),
                ),
              ),
              Container(width: 76, height: 1.5, color: const Color(0xFFEF4444).withValues(alpha: 0.8)),
              Container(width: 1.5, height: 76, color: const Color(0xFFEF4444).withValues(alpha: 0.8)),
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFFEF4444),
                  shape: BoxShape.circle,
                ),
              ),
              Transform.translate(
                offset: const Offset(0, -28),
                child: const Icon(
                  Icons.location_on,
                  size: 38,
                  color: Color(0xFFEF4444),
                  shadows: [
                    Shadow(color: Colors.black38, blurRadius: 6, offset: Offset(0, 3)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
