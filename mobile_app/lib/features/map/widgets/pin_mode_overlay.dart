import 'package:flutter/material.dart';
import 'package:delivery_marker_mobile/models/address_search_result.dart';
import 'package:delivery_marker_mobile/core/theme/app_buttons.dart';

/// Lớp giao diện phủ (overlay) cho chế độ ghim vị trí bằng tâm ngắm
class PinModeOverlay extends StatelessWidget {
  final TextEditingController searchController;
  final bool isSearchingAddress;
  final List<AddressSearchResult> searchResults;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<AddressSearchResult> onSelectSearchResult;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  const PinModeOverlay({
    super.key,
    required this.searchController,
    required this.isSearchingAddress,
    required this.searchResults,
    required this.onSearchChanged,
    required this.onSelectSearchResult,
    required this.onCancel,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 1. Icon tâm ngắm cố định giữa màn hình
        Center(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 36),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A).withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Kéo bản đồ để đặt tâm ghim',
                    style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: 4),
                const Icon(Icons.location_pin, size: 48, color: Color(0xFFEF4444)),
              ],
            ),
          ),
        ),

        // 2. Thanh tìm kiếm địa chỉ Geocoding phía trên
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
              child: Column(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
                    ),
                    child: TextField(
                      controller: searchController,
                      decoration: InputDecoration(
                        hintText: 'Tìm địa chỉ (VD: Nguyễn Xiển, Thủ Đức)...',
                        prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF2563EB)),
                        suffixIcon: isSearchingAddress
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                              )
                            : (searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 18),
                                    onPressed: () {
                                      searchController.clear();
                                      onSearchChanged('');
                                    },
                                  )
                                : null),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onChanged: onSearchChanged,
                    ),
                  ),

                  // Danh sách kết quả gợi ý địa chỉ Geocoding
                  if (searchResults.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        padding: EdgeInsets.zero,
                        itemCount: searchResults.length > 4 ? 4 : searchResults.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (ctx, idx) {
                          final item = searchResults[idx];
                          return ListTile(
                            dense: true,
                            leading: const Icon(Icons.place_outlined, color: Color(0xFF2563EB), size: 18),
                            title: Text(item.displayName, style: const TextStyle(fontSize: 12)),
                            onTap: () => onSelectSearchResult(item),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),

        // 3. Thanh điều khiển ghim dưới đáy
        Positioned(
          left: 16,
          right: 16,
          bottom: 20,
          child: SafeArea(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4))],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: AppButtons.secondary(minHeight: 48, borderRadius: 10),
                      onPressed: onCancel,
                      child: const Text('HỦY'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      key: const Key('btn_confirm_crosshair'),
                      style: AppButtons.primary(minHeight: 48, borderRadius: 10),
                      onPressed: onConfirm,
                      child: const Text('XÁC NHẬN VỊ TRÍ NÀY'),
                    ),
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
