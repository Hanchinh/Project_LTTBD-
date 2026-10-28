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
