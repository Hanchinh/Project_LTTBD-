import 'package:flutter/material.dart';
import 'package:delivery_marker_mobile/models/shift_model.dart';

class ShiftMapHeader extends StatelessWidget {
  final ShiftModel shift;
  final int validPointsCount;
  final int noLocationPointsCount;
  final VoidCallback onBack;
  final VoidCallback onRefresh;

  const ShiftMapHeader({
    super.key,
    required this.shift,
    required this.validPointsCount,
    required this.noLocationPointsCount,
    required this.onBack,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.96),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A), size: 22),
                  tooltip: 'Quay lại',
                  onPressed: onBack,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        shift.displayTitle,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Row(
                        children: [
                          Text(
                            shift.shiftCode,
                            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                          ),
                          const Text(' · ', style: TextStyle(color: Color(0xFFCBD5E1))),
                          Text(
                            '$validPointsCount đã ghim',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF10B981)),
                          ),
                          if (noLocationPointsCount > 0) ...[
                            const Text(' · ', style: TextStyle(color: Color(0xFFCBD5E1))),
                            Text(
                              '$noLocationPointsCount chưa có vị trí',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFFF59E0B)),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, color: Color(0xFF475569), size: 22),
                  tooltip: 'Tải lại',
                  onPressed: onRefresh,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
