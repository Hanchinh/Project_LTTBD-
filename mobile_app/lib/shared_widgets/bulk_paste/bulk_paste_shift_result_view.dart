import 'package:flutter/material.dart';
import 'package:delivery_marker_mobile/models/shift_model.dart';
import 'package:delivery_marker_mobile/core/theme/app_buttons.dart';
import 'package:delivery_marker_mobile/core/widgets/bulk_section_header.dart';

/// Giao diện kết quả dán SĐT cho ca làm việc (Shift Mode)
class BulkPasteShiftResultView extends StatelessWidget {
  final BulkAddPointsResult result;
  final ValueChanged<ShiftDeliveryPointModel>? onPinPointRequested;
  final VoidCallback onClose;

  const BulkPasteShiftResultView({
    super.key,
    required this.result,
    this.onPinPointRequested,
    required this.onClose,
  });

  Widget _buildVerifiedRow(ShiftDeliveryPointModel point) {
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
            decoration: const BoxDecoration(color: Color(0xFFDCFCE7), shape: BoxShape.circle),
            child: const Icon(Icons.check_rounded, color: Color(0xFF16A34A), size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(point.customerName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                Text(point.customerPhone, style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFDCFCE7),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              'ĐÃ CÓ TỌA ĐỘ',
              style: TextStyle(color: Color(0xFF15803D), fontSize: 10, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoLocationRow(BuildContext context, ShiftDeliveryPointModel point) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.location_off_rounded, color: Color(0xFFD97706), size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(point.customerName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF92400E))),
                    Text(point.customerPhone, style: const TextStyle(color: Color(0xFFB45309), fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Nút lớn "GHIM TÂM NGẮM" chiều cao >= 56px cho thao tác 1 tay, Navy/đen #0F172A
          SizedBox(
            height: 56,
            child: ElevatedButton.icon(
              onPressed: () {
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                }
                onPinPointRequested?.call(point);
              },
              style: AppButtons.primaryLarge(minHeight: 56, borderRadius: 12),
              icon: const Icon(Icons.add_location_alt_rounded, size: 20),
              label: const Text(
                'GHIM TÂM NGẮM',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 0.3),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final verifiedPoints = result.added.where((p) => p.locationStatus == LocationStatus.verified).toList();
    final noLocationPoints = result.added.where((p) => p.locationStatus == LocationStatus.noLocation).toList();

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
                      'Kết quả thêm danh sách SĐT',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                    Text(
                      'Đã thêm ${result.added.length} điểm · ${result.alreadyInShift.length} đã có · ${result.rejected.length} từ chối',
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

          // Danh sách cuộn kết quả
          Expanded(
            child: ListView(
              children: [
                // 1. NHÓM 1: ĐÃ CÓ VỊ TRÍ (VERIFIED)
                if (verifiedPoints.isNotEmpty) ...[
                  buildBulkSectionHeader(
                    title: 'ĐÃ CÓ VỊ TRÍ (${verifiedPoints.length})',
                    subtitle: 'Hiện ngay marker trên bản đồ ca',
                    color: const Color(0xFF16A34A),
                    icon: Icons.check_circle_rounded,
                  ),
                  ...verifiedPoints.map((p) => _buildVerifiedRow(p)),
                  const SizedBox(height: 16),
                ],

                // 2. NHÓM 2: CHƯA CÓ VỊ TRÍ - CẦN XÁC NHẬN (NO_LOCATION)
                if (noLocationPoints.isNotEmpty) ...[
                  buildBulkSectionHeader(
                    title: 'CHƯA CÓ VỊ TRÍ - CẦN XÁC NHẬN (${noLocationPoints.length})',
                    subtitle: 'Dùng tâm ngắm để ghim vị trí tạm thời',
                    color: const Color(0xFFD97706),
                    icon: Icons.location_searching_rounded,
                  ),
                  ...noLocationPoints.map((p) => _buildNoLocationRow(context, p)),
                  const SizedBox(height: 16),
                ],

                // 3. NHÓM 3: ĐÃ CÓ TRONG CA
                if (result.alreadyInShift.isNotEmpty) ...[
                  buildBulkSectionHeader(
                    title: 'ĐÃ CÓ TRONG CA (${result.alreadyInShift.length})',
                    subtitle: 'Bỏ qua, không thêm trùng lặp',
                    color: const Color(0xFF64748B),
                    icon: Icons.info_outline_rounded,
                  ),
                  ...result.alreadyInShift.map((item) => ListTile(
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                        leading: const Icon(Icons.check_rounded, color: Color(0xFF64748B), size: 18),
                        title: Text('${item.customerName} · ${item.phone}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        subtitle: Text('Trạng thái: ${item.locationStatus}', style: const TextStyle(fontSize: 11)),
                      )),
                  const SizedBox(height: 16),
                ],

                // 4. NHÓM 4: BỊ TỪ CHỐI
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
          const SizedBox(height: 12),

          // Nút ĐÓNG VÀ XEM BẢN ĐỒ CA >= 56px, Navy/đen #0F172A
          SizedBox(
            height: 56,
            child: ElevatedButton.icon(
              onPressed: onClose,
              style: AppButtons.primaryLarge(minHeight: 56, borderRadius: 16),
              icon: const Icon(Icons.map_rounded, size: 22),
              label: const Text(
                'XONG · XEM BẢN ĐỒ CA',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.4),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
