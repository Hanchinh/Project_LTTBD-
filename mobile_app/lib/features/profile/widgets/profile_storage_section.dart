import 'package:flutter/material.dart';
import 'package:delivery_marker_mobile/data/local/app_storage_service.dart';

/// Widget hiển thị dung lượng bộ nhớ lưu trữ cục bộ của ứng dụng (SQLite, Ảnh, Bộ nhớ đệm Tile)
class ProfileStorageSection extends StatelessWidget {
  final AppStorageStats? storageStats;
  final bool isClearingCache;
  final VoidCallback onClearCache;

  const ProfileStorageSection({
    super.key,
    required this.storageStats,
    required this.isClearingCache,
    required this.onClearCache,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final bgCard = colorScheme.surface;
    final borderColor = theme.dividerTheme.color ?? (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0));
    final subtextColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final valueColor = colorScheme.onSurface;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'BỘ NHỚ & LƯU TRỮ CỤC BỘ',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: subtextColor,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: bgCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    const Icon(Icons.storage_rounded, color: Color(0xFF2563EB), size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Dung lượng lưu trữ',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: valueColor),
                      ),
                    ),
                    if (storageStats != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1)),
                        ),
                        child: Text(
                          storageStats!.totalSizeFormatted,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            fontFeatures: const [FontFeature.tabularFigures()],
                            color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF334155),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Divider(height: 1, color: borderColor),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.inventory_2_outlined, size: 16, color: subtextColor),
                            const SizedBox(width: 8),
                            Text('Cơ sở dữ liệu SQLite:', style: TextStyle(fontSize: 13, color: subtextColor)),
                          ],
                        ),
                        Text(
                          storageStats?.databaseSizeFormatted ?? '...',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            fontFeatures: const [FontFeature.tabularFigures()],
                            color: valueColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.photo_library_outlined, size: 16, color: subtextColor),
                            const SizedBox(width: 8),
                            Text('Ảnh mặt tiền cửa nhà:', style: TextStyle(fontSize: 13, color: subtextColor)),
                          ],
                        ),
                        Text(
                          storageStats?.photosSizeFormatted ?? '...',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            fontFeatures: const [FontFeature.tabularFigures()],
                            color: valueColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.cached_rounded, size: 16, color: subtextColor),
                            const SizedBox(width: 8),
                            Text('Bộ nhớ đệm (Tile & Tệp tạm):', style: TextStyle(fontSize: 13, color: subtextColor)),
                          ],
                        ),
                        Text(
                          storageStats?.cacheSizeFormatted ?? '...',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            fontFeatures: const [FontFeature.tabularFigures()],
                            color: valueColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: borderColor),
              Padding(
                padding: const EdgeInsets.all(12),
                child: SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: OutlinedButton.icon(
                    key: const Key('clear_cache_btn'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB),
                      side: BorderSide(color: isDark ? const Color(0xFF1E3A8A) : const Color(0xFFBFDBFE)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: isClearingCache ? null : onClearCache,
                    icon: isClearingCache
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.cleaning_services_rounded, size: 18),
                    label: Text(
                      isClearingCache ? 'Đang dọn dẹp...' : 'Dọn bộ nhớ đệm',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
