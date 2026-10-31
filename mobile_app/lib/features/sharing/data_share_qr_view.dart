// Màn hình tạo và trình chiếu chuỗi mã QR động để chia sẻ dữ liệu điểm giao.
// Chia nhỏ gói dữ liệu thành các mảnh QR để thiết bị khác quét ngoại tuyến.
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:delivery_marker_mobile/core/theme/app_buttons.dart';

/// Màn hình hiển thị mã QR chia sẻ điểm giao (hỗ trợ nhiều mảnh nếu dữ liệu lớn)
class DataShareQrView extends StatefulWidget {
  final List<String> qrChunks;
  final int pointsCount;
  final String senderName;

  const DataShareQrView({
    super.key,
    required this.qrChunks,
    required this.pointsCount,
    required this.senderName,
  });

  static Future<void> show(
    BuildContext context, {
    required List<String> qrChunks,
    required int pointsCount,
    required String senderName,
  }) {
    return Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DataShareQrView(
          qrChunks: qrChunks,
          pointsCount: pointsCount,
          senderName: senderName,
        ),
      ),
    );
  }

  @override
  State<DataShareQrView> createState() => _DataShareQrViewState();
}

class _DataShareQrViewState extends State<DataShareQrView> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final total = widget.qrChunks.length;
    final currentPayload = widget.qrChunks[_currentIndex];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Mã QR Chia Sẻ Điểm',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: () => Navigator.pop(context),
            tooltip: 'Đóng',
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 1. Thông tin tóm tắt
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.share_location_rounded, color: Color(0xFF2563EB), size: 20),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        '${widget.pointsCount} điểm giao từ ${widget.senderName}',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0F172A),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // 2. Chỉ báo mảnh QR (nếu chia nhiều mảnh)
              if (total > 1) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: Text(
                    'MÃ ${_currentIndex + 1} / $total',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1D4ED8),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Người nhận cần quét lần lượt từng mã để nhận đầy đủ dữ liệu',
                  style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
              ],

              // 3. Khung hiển thị QR to, độ tương phản cao ngoài nắng
              Center(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE2E8F0), width: 2),
                    boxShadow: const [
                      BoxShadow(
                        color: Color.fromRGBO(0, 0, 0, 0.06),
                        blurRadius: 16,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: QrImageView(
                    key: ValueKey('qr_image_chunk_$_currentIndex'),
                    data: currentPayload,
                    version: QrVersions.auto,
                    size: 280,
                    backgroundColor: Colors.white,
                    errorCorrectionLevel: QrErrorCorrectLevel.M,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // 4. Lời khuyên tăng độ sáng
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.brightness_high_rounded, size: 18, color: Color(0xFFD97706)),
                  SizedBox(width: 6),
                  Text(
                    'Mẹo: Tăng độ sáng màn hình để máy đối diện quét nhanh hơn',
                    style: TextStyle(fontSize: 12, color: Color(0xFF78350F), fontWeight: FontWeight.w500),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // 5. Nút điều hướng các mảnh
              if (total > 1) ...[
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 52,
                        child: OutlinedButton.icon(
                          key: const Key('qr_btn_prev'),
                          style: AppButtons.secondary(minHeight: 52),
                          onPressed: _currentIndex > 0
                              ? () => setState(() => _currentIndex--)
                              : null,
                          icon: const Icon(Icons.arrow_back_rounded),
                          label: const Text('MÃ TRƯỚC'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SizedBox(
                        height: 52,
                        child: ElevatedButton.icon(
                          key: const Key('qr_btn_next'),
                          style: AppButtons.primary(minHeight: 52),
                          onPressed: _currentIndex < total - 1
                              ? () => setState(() => _currentIndex++)
                              : null,
                          icon: const Icon(Icons.arrow_forward_rounded),
                          label: const Text('MÃ TIẾP THEO'),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],

              // 6. Nút Đóng
              SizedBox(
                width: double.infinity,
                height: 48,
                child: TextButton(
                  key: const Key('qr_btn_close'),
                  style: AppButtons.text(minHeight: 48),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Đóng', style: TextStyle(fontSize: 16, color: Color(0xFF64748B))),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

