import 'package:flutter/material.dart';
import 'package:delivery_marker_mobile/models/customer_model.dart';
import 'package:delivery_marker_mobile/models/shift_model.dart';
import 'package:delivery_marker_mobile/core/theme/app_buttons.dart';
import 'package:delivery_marker_mobile/core/widgets/bulk_section_header.dart';

/// Giao diện kết quả dán SĐT cho chế độ Danh bạ (3 nhóm: Mới tạo, Đã tồn tại, Bị từ chối)
class BulkPasteDirectoryResultView extends StatelessWidget {
  final BulkCreateCustomersResult result;
  final bool isAddingToShift;
  final VoidCallback onAddAllToShift;
  final VoidCallback onClose;

  const BulkPasteDirectoryResultView({
    super.key,
    required this.result,
    required this.isAddingToShift,
    required this.onAddAllToShift,
    required this.onClose,
  });

  Widget _buildCustomerRow(BulkCustomerItem customer, {required bool isCreated}) {
    String tagLabel;
    Color tagBg;
    Color tagText;

    if (isCreated) {
      tagLabel = 'MỚI TẠO';
      tagBg = const Color(0xFFDCFCE7);
      tagText = const Color(0xFF15803D);
    } else {
      switch (customer.locationState) {
        case LocationStatus.verified:
          tagLabel = 'ĐÃ CÓ TỌA ĐỘ';
          tagBg = const Color(0xFFDCFCE7);
          tagText = const Color(0xFF15803D);
          break;
        case LocationStatus.temporary:
          tagLabel = 'TỌA ĐỘ TẠM';
          tagBg = const Color(0xFFFEF3C7);
          tagText = const Color(0xFFB45309);
          break;
        case LocationStatus.noLocation:
          tagLabel = 'CHƯA CÓ VỊ TRÍ';
          tagBg = const Color(0xFFF1F5F9);
          tagText = const Color(0xFF64748B);
          break;
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: isCreated ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isCreated ? Icons.person_add_rounded : Icons.person_rounded,
              color: isCreated ? const Color(0xFF16A34A) : const Color(0xFF0F172A),
              size: 16,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(customer.fullName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                Text(customer.phoneNumber, style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: tagBg,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              tagLabel,
              style: TextStyle(color: tagText, fontSize: 10, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
      child: Column(
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

          // Tiêu đề kết quả
          Row(
            children: [
              const Icon(Icons.task_alt_rounded, color: Color(0xFF16A34A), size: 26),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Kết quả thêm vào danh bạ',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                    Text(
                      'Tạo mới ${result.createdCount} · ${result.alreadyExistsCount} đã có · ${result.rejectedCount} bị từ chối',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                tooltip: 'Đóng',
                onPressed: onClose,
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Danh sách cuộn kết quả 3 nhóm
          Expanded(
            child: ListView(
              children: [
                // 1. NHÓM 1: MỚI TẠO (CREATED)
                if (result.created.isNotEmpty) ...[
                  buildBulkSectionHeader(
                    title: 'MỚI TẠO (${result.created.length})',
                    subtitle: 'Đã lưu vào danh bạ với tên "Khách [SĐT]"',
                    color: const Color(0xFF16A34A),
                    icon: Icons.person_add_alt_1_rounded,
                  ),
                  ...result.created.map((c) => _buildCustomerRow(c, isCreated: true)),
                  const SizedBox(height: 16),
                ],

                // 2. NHÓM 2: ĐÃ TỒN TẠI (ALREADY EXISTS)
                if (result.alreadyExists.isNotEmpty) ...[
                  buildBulkSectionHeader(
                    title: 'ĐÃ TỒN TẠI (${result.alreadyExists.length})',
                    subtitle: 'Khách đã có trong hệ thống kèm trạng thái vị trí',
                    color: const Color(0xFF0F172A),
                    icon: Icons.people_alt_rounded,
                  ),
                  ...result.alreadyExists.map((c) => _buildCustomerRow(c, isCreated: false)),
                  const SizedBox(height: 16),
                ],

                // 3. NHÓM 3: BỊ TỪ CHỐI (REJECTED)
                if (result.rejected.isNotEmpty) ...[
                  buildBulkSectionHeader(
                    title: 'BỊ TỪ CHỐI (${result.rejected.length})',
                    subtitle: 'Sai định dạng hoặc ngoài khu vực phụ trách',
                    color: const Color(0xFFDC2626),
                    icon: Icons.cancel_rounded,
                  ),
                  ...result.rejected.map((item) => Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFFECACA)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item.phone, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF991B1B))),
                                  Text(item.message, style: const TextStyle(fontSize: 11, color: Color(0xFFB91C1C))),
                                ],
                              ),
                            ),
                          ],
                        ),
                      )),
                ],
              ],
            ),
          ),

          // Nút "THÊM TẤT CẢ VÀO CA" (nếu có khách mới hoặc đã có)
          if (result.created.isNotEmpty || result.alreadyExists.isNotEmpty) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 56,
              child: ElevatedButton.icon(
                onPressed: isAddingToShift ? null : onAddAllToShift,
                style: AppButtons.primaryLarge(minHeight: 56, borderRadius: 16),
                icon: isAddingToShift
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.add_task_rounded, size: 22),
                label: Text(
                  isAddingToShift
                      ? 'ĐANG THÊM VÀO CA...'
                      : 'THÊM TẤT CẢ VÀO CA (${result.created.length + result.alreadyExists.length})',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.4),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
