import 'package:flutter/material.dart';
import 'package:delivery_marker_mobile/core/theme/app_buttons.dart';

/// Cụm nhập số điện thoại khách hàng (Nhập hàng loạt qua nút lớn & Nhập nhanh từng số)
class ShiftPrepPhoneInputHeader extends StatelessWidget {
  final TextEditingController phoneController;
  final FocusNode phoneFocusNode;
  final bool isAddingPoint;
  final VoidCallback onOpenBulkPaste;
  final VoidCallback onAddSinglePhone;
  final VoidCallback onClearPhone;

  const ShiftPrepPhoneInputHeader({
    super.key,
    required this.phoneController,
    required this.phoneFocusNode,
    required this.isAddingPoint,
    required this.onOpenBulkPaste,
    required this.onAddSinglePhone,
    required this.onClearPhone,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // NÚT LỚN "NHẬP HÀNG LOẠT SĐT" (>= 56px)
          SizedBox(
            height: 56,
            child: ElevatedButton.icon(
              key: const Key('btn_bulk_paste_phones'),
              onPressed: onOpenBulkPaste,
              style: AppButtons.primaryLarge(minHeight: 56, borderRadius: 14),
              icon: const Icon(Icons.paste_rounded, size: 22),
              label: const Text(
                'NHẬP HÀNG LOẠT SĐT',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: 0.5),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Phân cách hoặc nhãn nhập lẻ từng số
          Row(
            children: [
              const Expanded(child: Divider(color: Color(0xFFE2E8F0), thickness: 1)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  'HOẶC THÊM TỪNG SỐ',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade500),
                ),
              ),
              const Expanded(child: Divider(color: Color(0xFFE2E8F0), thickness: 1)),
            ],
          ),

          const SizedBox(height: 10),

          // Ô nhập một số để thêm nhanh từng số
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: TextField(
                    controller: phoneController,
                    focusNode: phoneFocusNode,
                    keyboardType: TextInputType.phone,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                    decoration: InputDecoration(
                      hintText: 'Nhập số điện thoại (VD: 0901234567)',
                      hintStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.normal, color: Color(0xFF94A3B8)),
                      prefixIcon: const Icon(Icons.phone_android_rounded, size: 20, color: Color(0xFF64748B)),
                      suffixIcon: phoneController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18, color: Color(0xFF94A3B8)),
                              onPressed: onClearPhone,
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
                      ),
                    ),
                    onSubmitted: (_) => onAddSinglePhone(),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  key: const Key('btn_add_single_phone'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  icon: isAddingPoint
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Icon(Icons.person_add_rounded, size: 20),
                  label: Text(
                    isAddingPoint ? '...' : 'Thêm',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  onPressed: isAddingPoint ? null : onAddSinglePhone,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

