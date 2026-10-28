import 'package:flutter/material.dart';
import 'package:delivery_marker_mobile/data/local/app_storage_service.dart';

/// Widget hiển thị dung lượng bộ nhớ lưu trữ cục bộ của ứng dụng (SQLite, Ảnh, Bộ nhớ đệm Tile)
/// Kèm nút hành động dọn dẹp bộ nhớ đệm tạm thời.
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
    const bgCard = Colors.white;
    const borderColor = Color(0xFFE2E8F0);

    return Material(
      color: bgCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.storage_rounded, color: Color(0xFF2563EB), size: 20),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Dung lượng lưu trữ',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                  ),
                ),
                if (storageStats != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      storageStats!.totalSizeFormatted,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1, color: borderColor),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.inventory_2_outlined, size: 16, color: Color(0xFF64748B)),
                        SizedBox(width: 8),
                        Text('Cơ sở dữ liệu:', style: TextStyle(fontSize: 13, color: Color(0xFF475569))),
                      ],
                    ),
                    Text(
                      storageStats?.databaseSizeFormatted ?? '...',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.photo_library_outlined, size: 16, color: Color(0xFF64748B)),
                        SizedBox(width: 8),
                        Text('Ảnh nhà khách hàng:', style: TextStyle(fontSize: 13, color: Color(0xFF475569))),
                      ],
                    ),
                    Text(
                      storageStats?.photosSizeFormatted ?? '...',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.cached_rounded, size: 16, color: Color(0xFF64748B)),
                        SizedBox(width: 8),
                        Text('Bộ nhớ đệm (Tile & Tệp tạm):', style: TextStyle(fontSize: 13, color: Color(0xFF475569))),
                      ],
                    ),
                    Text(
                      storageStats?.cacheSizeFormatted ?? '...',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: borderColor),
          Padding(
            padding: const EdgeInsets.all(12),
            child: SizedBox(
              width: double.infinity,
              height: 44,
              child: OutlinedButton.icon(
                key: const Key('clear_cache_btn'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF2563EB),
                  side: const BorderSide(color: Color(0xFFBFDBFE)),
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
                  isClearingCache ? 'Đang dọn...' : 'Dọn bộ nhớ đệm',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
