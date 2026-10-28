import 'package:flutter/material.dart';
import 'package:delivery_marker_mobile/models/local_share_models.dart';

/// Thẻ cấu hình quy tắc xử lý trùng lặp và tùy chọn tạo ca mới khi nhập dữ liệu
class ShareImportOptionsCard extends StatelessWidget {
  final ShareImportMode importMode;
  final ValueChanged<ShareImportMode> onImportModeChanged;
  final bool createShift;
  final ValueChanged<bool> onCreateShiftChanged;
  final TextEditingController shiftNameController;

  const ShareImportOptionsCard({
    super.key,
    required this.importMode,
    required this.onImportModeChanged,
    required this.createShift,
    required this.onCreateShiftChanged,
    required this.shiftNameController,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Chế độ nhập (Chỉ thêm mới / Thay vị trí cũ)
        const Text(
          'Quy tắc xử lý trùng lặp:',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: RadioGroup<ShareImportMode>(
            groupValue: importMode,
            onChanged: (val) {
              if (val != null) onImportModeChanged(val);
            },
            child: const Column(
              children: [
                RadioListTile<ShareImportMode>(
                  key: Key('mode_add_only'),
                  dense: true,
                  value: ShareImportMode.addOnly,
                  title: Text('Chỉ thêm điểm mới (khuyên dùng)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  subtitle: Text('Giữ nguyên các vị trí cũ đã lưu trong máy', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                ),
                Divider(height: 1, indent: 16, endIndent: 16),
                RadioListTile<ShareImportMode>(
                  key: Key('mode_replace_existing'),
                  dense: true,
                  value: ShareImportMode.replaceExisting,
                  title: Text('Thay vị trí cũ bằng vị trí nhận được', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  subtitle: Text('Tọa độ cũ được chuyển an toàn vào lịch sử', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // 2. Tùy chọn nhập thành ca mới
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            children: [
              SwitchListTile(
                key: const Key('switch_create_shift'),
                dense: true,
                title: const Text('Nhập thành một ca làm việc mới', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                subtitle: const Text('Tạo ngay ca giao hàng gồm các điểm này', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                value: createShift,
                activeThumbColor: const Color(0xFF0F172A),
                onChanged: onCreateShiftChanged,
              ),
              if (createShift) ...[
                Padding(
                  padding: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
                  child: TextField(
                    key: const Key('input_shift_name'),
                    controller: shiftNameController,
                    style: const TextStyle(fontSize: 14),
                    decoration: InputDecoration(
                      labelText: 'Tên ca làm việc',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

