// Cụm trường nhập liệu bổ sung và bộ chọn khu vực khi thêm nhanh khách hàng.
// Cho phép điền tên, địa chỉ chi tiết và ghi chú nhận diện thực địa.
import 'package:flutter/material.dart';

Future<Map<String, dynamic>?> showAreaSelectionDialog({
  required BuildContext context,
  required List<Map<String, dynamic>> areas,
  required String? selectedAreaId,
}) {
  return showDialog<Map<String, dynamic>>(
    context: context,
    builder: (dlgCtx) {
      return AlertDialog(
        title: const Text(
          'Chọn khu vực phụ trách',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: areas.map((area) {
              final areaId = area['id']?.toString();
              final isSelected = areaId == selectedAreaId;
              return ListTile(
                title: Text(area['name']?.toString() ?? 'Khu vực'),
                subtitle: Text('Mã: ${area['code'] ?? ''}'),
                trailing: isSelected
                    ? const Icon(Icons.check_circle, color: Color(0xFF2563EB))
                    : null,
                onTap: () => Navigator.pop(dlgCtx, area),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dlgCtx),
            child: const Text('ĐÓNG'),
          ),
        ],
      );
    },
  );
}

class QuickAddAreaRow extends StatelessWidget {
  final String? selectedAreaName;
  final bool loadingAreas;
  final bool hasMultipleAreas;
  final VoidCallback onPromptSelect;

  const QuickAddAreaRow({
    super.key,
    required this.selectedAreaName,
    required this.loadingAreas,
    required this.hasMultipleAreas,
    required this.onPromptSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          const Icon(Icons.map_outlined, size: 16, color: Color(0xFF64748B)),
          const SizedBox(width: 6),
          Text(
            'Khu vực: ${selectedAreaName ?? (loadingAreas ? "Đang tải..." : "Chưa chọn")}',
            style: const TextStyle(fontSize: 13, color: Color(0xFF475569), fontWeight: FontWeight.w500),
          ),
          if (hasMultipleAreas) ...[
            const SizedBox(width: 6),
            InkWell(
              onTap: onPromptSelect,
              borderRadius: BorderRadius.circular(4),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Text(
                  '(Đổi)',
                  style: TextStyle(fontSize: 13, color: Color(0xFF2563EB), fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class QuickAddOptionalFields extends StatelessWidget {
  final TextEditingController nameCtrl;
  final TextEditingController addressCtrl;
  final TextEditingController notesCtrl;
  final VoidCallback onSubmitted;

  const QuickAddOptionalFields({
    super.key,
    required this.nameCtrl,
    required this.addressCtrl,
    required this.notesCtrl,
    required this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 14),
        const Text(
          'TÊN KHÁCH HÀNG (TÙY CHỌN)',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: nameCtrl,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            hintText: 'Mặc định: Khách [SĐT]',
            hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            prefixIcon: const Icon(Icons.person_outline_rounded, size: 20, color: Color(0xFF64748B)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
            ),
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'ĐỊA CHỈ GIAO HÀNG (TÙY CHỌN)',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: addressCtrl,
          maxLines: 2,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            hintText: 'Mặc định: Chưa cập nhật địa chỉ',
            hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            prefixIcon: const Icon(Icons.location_on_outlined, size: 20, color: Color(0xFF64748B)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
            ),
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'GHI CHÚ VỊ TRÍ (TÙY CHỌN)',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: notesCtrl,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => onSubmitted(),
          decoration: InputDecoration(
            hintText: 'Ví dụ: Cổng sắt màu xanh, gần tiệm sửa xe...',
            hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            prefixIcon: const Icon(Icons.note_alt_outlined, size: 20, color: Color(0xFF64748B)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
            ),
          ),
        ),
      ],
    );
  }
}

