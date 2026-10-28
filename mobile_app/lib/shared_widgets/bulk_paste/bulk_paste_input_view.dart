import 'package:flutter/material.dart';
import 'package:delivery_marker_mobile/core/theme/app_buttons.dart';

/// Giao diện nhập liệu dán danh sách SĐT hàng loạt
class BulkPasteInputView extends StatelessWidget {
  final bool isDirectoryMode;
  final TextEditingController textController;
  final List<String> validPhones;
  final List<String> invalidPhones;
  final bool isSubmitting;
  final String? errorMessage;
  final List<Map<String, dynamic>> availableAreas;
  final String? selectedAreaId;
  final bool needAreaSelection;
  final VoidCallback onPasteFromClipboard;
  final ValueChanged<String?> onAreaChanged;
  final VoidCallback onSubmit;
  final VoidCallback onClose;

  const BulkPasteInputView({
    super.key,
    required this.isDirectoryMode,
    required this.textController,
    required this.validPhones,
    required this.invalidPhones,
    required this.isSubmitting,
    required this.errorMessage,
    required this.availableAreas,
    required this.selectedAreaId,
    required this.needAreaSelection,
    required this.onPasteFromClipboard,
    required this.onAreaChanged,
    required this.onSubmit,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(18, 14, 18, 16 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Thanh gạt
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.playlist_add_rounded, color: Color(0xFF0F172A), size: 24),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isDirectoryMode ? 'Dán danh sách SĐT vào danh bạ' : 'Dán danh sách SĐT vào ca',
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                    const Text(
                      'Tách tự động theo xuống dòng, phẩy, chấm phẩy (tối đa 200 số)',
                      style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                onPressed: onClose,
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Phần thân cuộn được chứa nút Dán, ô nhập không cố định chiều cao và các cảnh báo
          Flexible(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Nút "DÁN TỪ BỘ NHỚ TẠM" một chạm (>= 48px, Navy/đen viền)
                  SizedBox(
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: onPasteFromClipboard,
                      style: AppButtons.secondary(minHeight: 48, borderRadius: 12),
                      icon: const Icon(Icons.content_paste_rounded, size: 20),
                      label: const Text(
                        'DÁN TỪ BỘ NHỚ TẠM',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 0.3),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Ô nhập văn bản không cố định chiều cao, minLines: 4, maxLines: 8, contentPadding >= 12px
                  TextField(
                    controller: textController,
                    autofocus: true,
                    minLines: 4,
                    maxLines: 8,
                    keyboardType: TextInputType.multiline,
                    textAlignVertical: TextAlignVertical.top,
                    decoration: InputDecoration(
                      hintText: 'Nhập hoặc dán danh sách SĐT tại đây...\n\nVí dụ:\n0908 911 111\n+84 988 000 001\n0988.000.002, 0988000003; 0912345678',
                      hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFF0F172A), width: 2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Xem trước đếm số & cảnh báo
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: validPhones.isNotEmpty ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.check_circle_rounded,
                              size: 15,
                              color: validPhones.isNotEmpty ? const Color(0xFF16A34A) : const Color(0xFF94A3B8),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              'Hợp lệ: ${validPhones.length}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: validPhones.isNotEmpty ? const Color(0xFF15803D) : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (invalidPhones.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEE2E2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.warning_amber_rounded, size: 15, color: Color(0xFFDC2626)),
                              const SizedBox(width: 5),
                              Text(
                                'Sai định dạng: ${invalidPhones.length}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFB91C1C),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),

                  // Chọn khu vực nếu shipper phụ trách nhiều khu vực
                  if (needAreaSelection || availableAreas.length > 1) ...[
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: selectedAreaId,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'Khu vực áp dụng cho khách hàng mới',
                        labelStyle: const TextStyle(fontSize: 12),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      items: availableAreas.map((a) {
                        final aId = a['id']?.toString() ?? '';
                        final aName = a['name']?.toString() ?? '';
                        return DropdownMenuItem<String>(
                          value: aId,
                          child: Text(aName, style: const TextStyle(fontSize: 13)),
                        );
                      }).toList(),
                      onChanged: onAreaChanged,
                    ),
                  ],

                  // Thông báo lỗi nếu có
                  if (errorMessage != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      errorMessage!,
                      style: const TextStyle(color: Color(0xFFDC2626), fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Nút hành động chính luôn thấy được phía trên bàn phím (chiều cao >= 56px)
          SizedBox(
            height: 56,
            child: ElevatedButton.icon(
              onPressed: isSubmitting || (validPhones.isEmpty && invalidPhones.isEmpty)
                  ? null
                  : onSubmit,
              style: AppButtons.primaryLarge(minHeight: 56, borderRadius: 16),
              icon: isSubmitting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                    )
                  : Icon(isDirectoryMode ? Icons.group_add_rounded : Icons.add_location_alt_rounded, size: 22),
              label: Text(
                isSubmitting
                    ? 'ĐANG XỬ LÝ LÔ...'
                    : (isDirectoryMode
                        ? 'THÊM ${validPhones.length} SỐ VÀO DANH BẠ'
                        : 'THÊM ${validPhones.length} ĐIỂM VÀO CA'),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.4),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
