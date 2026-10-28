import 'package:flutter/material.dart';
import 'package:delivery_marker_mobile/core/theme/app_buttons.dart';

/// Header danh bạ: Tiêu đề + Huy hiệu tổng + Nút dán nhiều số + Nút thêm số + Ô tìm kiếm
class DirectoryHeader extends StatelessWidget {
  final int totalCount;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onBulkPaste;
  final VoidCallback onAddSingle;

  const DirectoryHeader({
    super.key,
    required this.totalCount,
    required this.searchController,
    required this.onSearchChanged,
    required this.onBulkPaste,
    required this.onAddSingle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header: "Danh bạ" kèm huy hiệu tổng + nút "+ Thêm số"
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                const Text(
                  'Danh bạ',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: Text(
                    '$totalCount',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF475569),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  key: const ValueKey('btn_bulk_paste_directory'),
                  style: AppButtons.secondary(
                    minHeight: 48,
                    borderRadius: 10,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                  icon: const Icon(Icons.playlist_add_rounded, size: 18),
                  label: const Text(
                    'Dán nhiều số',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                  onPressed: onBulkPaste,
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  key: const ValueKey('btn_add_single_customer'),
                  style: AppButtons.primary(
                    minHeight: 48,
                    borderRadius: 10,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text(
                    'Thêm số',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                  onPressed: onAddSingle,
                ),
              ],
            ),
          ),
        ),

        // Ô tìm kiếm bo tròn "Tìm số điện thoại, tên, địa chỉ..."
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: TextField(
              controller: searchController,
              onChanged: onSearchChanged,
              style: const TextStyle(fontSize: 14, color: Color(0xFF0F172A)),
              decoration: InputDecoration(
                hintText: 'Tìm số điện thoại, tên, địa chỉ...',
                hintStyle: const TextStyle(fontSize: 14, color: Color(0xFF94A3B8)),
                prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF64748B), size: 20),
                suffixIcon: searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF64748B)),
                        tooltip: 'Xóa tìm kiếm',
                        onPressed: () {
                          searchController.clear();
                          onSearchChanged('');
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
