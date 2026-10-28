import 'package:flutter/material.dart';
import 'package:delivery_marker_mobile/models/address_search_result.dart';

class CrosshairSearchPanel extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final bool isSearching;
  final bool showSuggestions;
  final List<AddressSearchResult> searchResults;
  final String? searchErrorMessage;
  final ValueChanged<AddressSearchResult> onSelectResult;
  final VoidCallback onClear;

  const CrosshairSearchPanel({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.isSearching,
    required this.showSuggestions,
    required this.searchResults,
    required this.searchErrorMessage,
    required this.onSelectResult,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Ô tìm kiếm địa chỉ chính
        Container(
          height: 48,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFCBD5E1)),
            boxShadow: const [
              BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 3)),
            ],
          ),
          child: Row(
            children: [
              const SizedBox(width: 12),
              const Icon(Icons.search_rounded, color: Color(0xFF2563EB), size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  onChanged: onChanged,
                  textInputAction: TextInputAction.search,
                  style: const TextStyle(fontSize: 14, color: Color(0xFF0F172A), fontWeight: FontWeight.w500),
                  decoration: const InputDecoration(
                    hintText: 'Tìm địa chỉ hoặc địa điểm...',
                    hintStyle: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              if (isSearching)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF2563EB)),
                  ),
                )
              else if (controller.text.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 18, color: Color(0xFF64748B)),
                  onPressed: onClear,
                ),
              const SizedBox(width: 4),
            ],
          ),
        ),

        // Danh sách gợi ý địa chỉ
        if (showSuggestions)
          Container(
            margin: const EdgeInsets.only(top: 6),
            constraints: const BoxConstraints(maxHeight: 220),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: const [
                BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4)),
              ],
            ),
            child: _buildSearchResultsList(),
          ),

        // Gợi ý kéo tâm ngắm (khi không mở gợi ý)
        if (!showSuggestions)
          Container(
            margin: const EdgeInsets.only(top: 6),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4, offset: const Offset(0, 2)),
              ],
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.touch_app_rounded, color: Color(0xFF2563EB), size: 16),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Kéo bản đồ để mũi ghim trỏ đúng cổng/cửa nhà khách',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF334155),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildSearchResultsList() {
    if (isSearching && searchResults.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF2563EB))),
              SizedBox(width: 10),
              Text('Đang tìm kiếm địa chỉ...', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
            ],
          ),
        ),
      );
    }

    if (searchErrorMessage != null) {
      return Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            const Icon(Icons.wifi_off_rounded, color: Color(0xFFEF4444), size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Lỗi tìm kiếm: $searchErrorMessage',
                style: const TextStyle(fontSize: 12, color: Color(0xFFEF4444)),
              ),
            ),
          ],
        ),
      );
    }

    if (searchResults.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16, horizontal: 14),
        child: Row(
          children: [
            Icon(Icons.search_off_rounded, color: Color(0xFF94A3B8), size: 20),
            SizedBox(width: 8),
            Text(
              'Không tìm thấy kết quả địa chỉ phù hợp',
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: searchResults.length,
      separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
      itemBuilder: (ctx, index) {
        final item = searchResults[index];
        return ListTile(
          dense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          leading: const Icon(Icons.place_outlined, color: Color(0xFF2563EB), size: 20),
          title: Text(
            item.displayName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
          ),
          subtitle: Text(
            '${item.latitude.toStringAsFixed(5)}, ${item.longitude.toStringAsFixed(5)}${item.source != null ? ' · ${item.source}' : ''}',
            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontFamily: 'monospace'),
          ),
          onTap: () => onSelectResult(item),
        );
      },
    );
  }
}
