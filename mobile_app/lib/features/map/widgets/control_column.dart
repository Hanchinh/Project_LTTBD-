import 'package:flutter/material.dart';
import 'package:delivery_marker_mobile/core/theme/app_buttons.dart';

/// Cột icon dọc ở mép phải phía dưới (Vùng ngón cái - TASK 017 & TASK 019)
/// Nút:
/// 1. "Ca làm việc" (btn_open_shift_picker)
/// 2. "Tạo ca" (btn_create_shift_from_map)
/// 3. "Ghim vị trí mới" (btn_pin_new_location)
class MainMapControlColumn extends StatelessWidget {
  final VoidCallback onOpenShiftPicker;
  final VoidCallback onCreateShift;
  final VoidCallback onStartPinning;

  const MainMapControlColumn({
    super.key,
    required this.onOpenShiftPicker,
    required this.onCreateShift,
    required this.onStartPinning,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 16,
      bottom: 20,
      child: RepaintBoundary(
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // 1. Nút "Ca làm việc" (trên cùng của cột, nút tròn 52px, nền trắng viền xám)
              Semantics(
                label: 'Ca làm việc',
                button: true,
                child: Tooltip(
                  message: 'Ca làm việc',
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      key: const Key('btn_open_shift_picker'),
                      borderRadius: BorderRadius.circular(26),
                      onTap: onOpenShiftPicker,
                      child: Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFFCBD5E1), width: 1.5),
                          boxShadow: const [
                            BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 3)),
                          ],
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.work_history_rounded,
                            size: 24,
                            color: AppButtons.navy,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // 2. Nút "Tạo ca" (ở giữa cột, nút tròn 52px, nền Navy #0F172A)
              Semantics(
                label: 'Tạo ca',
                button: true,
                child: Tooltip(
                  message: 'Tạo ca',
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      key: const Key('btn_create_shift_from_map'),
                      borderRadius: BorderRadius.circular(26),
                      onTap: onCreateShift,
                      child: Container(
                        width: 52,
                        height: 52,
                        decoration: const BoxDecoration(
                          color: Color(0xFF0F172A),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 3)),
                          ],
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.add_task_rounded,
                            size: 24,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // 3. Nút "Ghim vị trí mới" (dưới cùng của cột, to nhất 60px, màu xanh đen #0F172A)
              Semantics(
                label: 'Ghim vị trí mới',
                button: true,
                child: Tooltip(
                  message: 'Ghim vị trí mới',
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      key: const Key('btn_pin_new_location'),
                      borderRadius: BorderRadius.circular(30),
                      onTap: onStartPinning,
                      child: Container(
                        width: 60,
                        height: 60,
                        decoration: const BoxDecoration(
                          color: AppButtons.navy,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(color: Color(0x660F172A), blurRadius: 10, offset: Offset(0, 4)),
                          ],
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.add_location_alt_rounded,
                            size: 28,
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
      ),
    );
  }
}

/// Nút điều khiển định vị GPS và xem toàn bộ (Góc trên bên phải)
class MainMapGpsControls extends StatelessWidget {
  final bool isLocatingShipper;
  final VoidCallback onGetShipperLocation;
  final VoidCallback onFitLocationsBounds;

  const MainMapGpsControls({
    super.key,
    required this.isLocatingShipper,
    required this.onGetShipperLocation,
    required this.onFitLocationsBounds,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 14,
      top: 100,
      child: Column(
        children: [
          FloatingActionButton.small(
            heroTag: 'master_map_gps',
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFF2563EB),
            elevation: 3,
            onPressed: onGetShipperLocation,
            child: isLocatingShipper
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.my_location_rounded),
          ),
          const SizedBox(height: 8),
          FloatingActionButton.small(
            heroTag: 'master_map_fit_bounds',
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFF475569),
            elevation: 3,
            onPressed: onFitLocationsBounds,
            child: const Icon(Icons.fit_screen_rounded),
          ),
        ],
      ),
    );
  }
}
