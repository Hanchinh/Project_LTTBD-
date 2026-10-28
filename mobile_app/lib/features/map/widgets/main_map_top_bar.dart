import 'package:flutter/material.dart';

/// Thanh điều hướng trên cùng khi ở chế độ xem bình thường (TASK 017: thu mảnh cao <= 52px)
class MainMapTopBar extends StatelessWidget {
  final bool isLoadingShared;
  final bool showSharedLocations;
  final ValueChanged<bool> onToggleShared;
  final VoidCallback onSwitchMapType;
  final VoidCallback onReload;

  const MainMapTopBar({
    super.key,
    required this.isLoadingShared,
    required this.showSharedLocations,
    required this.onToggleShared,
    required this.onSwitchMapType,
    required this.onReload,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: RepaintBoundary(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
            child: Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.96),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2))],
              ),
              child: Row(
                children: [
                  const Icon(Icons.pin_drop_rounded, color: Color(0xFF2563EB), size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Bản đồ vị trí đã lưu',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // Nút bật/tắt Điểm được chia sẻ (TASK 023)
                  IconButton(
                    key: const Key('toggle_shared_locations'),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    icon: isLoadingShared
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF7C3AED)),
                          )
                        : Icon(
                            showSharedLocations ? Icons.share_location_rounded : Icons.share_location_outlined,
                            color: showSharedLocations ? const Color(0xFF7C3AED) : const Color(0xFF64748B),
                            size: 20,
                          ),
                    tooltip: showSharedLocations ? 'Tắt điểm chia sẻ' : 'Bật điểm chia sẻ',
                    onPressed: () => onToggleShared(!showSharedLocations),
                  ),
                  // Nút đổi nền bản đồ
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    icon: const Icon(Icons.layers_rounded, color: Color(0xFF64748B), size: 20),
                    tooltip: 'Đổi kiểu bản đồ',
                    onPressed: onSwitchMapType,
                  ),
                  // Nút làm mới
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    icon: const Icon(Icons.refresh_rounded, color: Color(0xFF64748B), size: 20),
                    tooltip: 'Tải lại vị trí',
                    onPressed: onReload,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
