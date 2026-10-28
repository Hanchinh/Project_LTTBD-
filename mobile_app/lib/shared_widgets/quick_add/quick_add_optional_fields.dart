import 'package:flutter/material.dart';

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
