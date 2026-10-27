import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../theme/app_buttons.dart';
import '../utils/share_crypto_utils.dart';
import 'data_share_import_preview_sheet.dart';

/// Màn hình Quét mã QR tiếp nhận dữ liệu chia sẻ
class DataShareQrScannerView extends StatefulWidget {
  final VoidCallback? onImportSuccess;

  const DataShareQrScannerView({super.key, this.onImportSuccess});

  static Future<void> show(BuildContext context, {VoidCallback? onImportSuccess}) {
    return Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DataShareQrScannerView(onImportSuccess: onImportSuccess),
      ),
    );
  }

  @override
  State<DataShareQrScannerView> createState() => _DataShareQrScannerViewState();
}

class _DataShareQrScannerViewState extends State<DataShareQrScannerView> {
  final MobileScannerController _controller = MobileScannerController();
  final QrChunkCollector _collector = QrChunkCollector();

  bool _isProcessing = false;
  String _scanStatusText = 'Hướng camera vào mã QR để quét';
  String? _errorMessage;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) async {
    if (_isProcessing) return;

    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final rawVal = barcodes.first.rawValue;
    if (rawVal == null || rawVal.isEmpty) return;

    final status = _collector.addRawCode(rawVal);

    if (status.errorMessage != null) {
      setState(() {
        _errorMessage = status.errorMessage;
      });
      return;
    }

    setState(() {
      _errorMessage = null;
      if (status.totalChunks > 1) {
        if (status.isComplete) {
          _scanStatusText = 'Đã quét đủ ${status.totalChunks}/${status.totalChunks} mã!';
        } else {
          _scanStatusText = 'Đã nhận ${status.scannedCount}/${status.totalChunks} mã. Còn thiếu mã: ${status.missingIndexes.join(", ")}';
        }
      }
    });

    if (status.isComplete) {
      _isProcessing = true;
      try {
        final decodedJson = _collector.assembleAndDecode();

        if (!mounted) return;
        // Chuyển sang màn hình xem trước (Preview)
        await Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => DataShareImportPreviewSheet(
              qrPayload: decodedJson,
              onImportSuccess: widget.onImportSuccess,
            ),
          ),
        );
      } catch (e) {
        if (mounted) {
          setState(() {
            _errorMessage = 'Lỗi giải nén dữ liệu: $e';
            _isProcessing = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Quét Mã QR Tiếp Nhận',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on_rounded),
            onPressed: () => _controller.toggleTorch(),
            tooltip: 'Bật/Tắt đèn pin',
          ),
          IconButton(
            icon: const Icon(Icons.flip_camera_android_rounded),
            onPressed: () => _controller.switchCamera(),
            tooltip: 'Đổi camera',
          ),
        ],
      ),
      body: Stack(
        children: [
          // 1. Khung camera MobileScanner
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.camera_alt_outlined, color: Colors.white70, size: 54),
                      const SizedBox(height: 16),
                      const Text(
                        'Không thể truy cập camera',
                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Vui lòng cấp quyền truy cập máy ảnh để quét mã QR: ${error.errorCode}',
                        style: const TextStyle(color: Colors.white60, fontSize: 14),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        style: AppButtons.primary(minHeight: 48),
                        onPressed: () => _controller.start(),
                        child: const Text('THỬ LẠI'),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          // 2. Lớp phủ khung ngắm quét
          Center(
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFF38BDF8), width: 2.5),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),

          // 3. Khung thông báo trạng thái phía dưới
          Positioned(
            left: 16,
            right: 16,
            bottom: 32,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color.fromRGBO(15, 23, 42, 0.92),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.qr_code_scanner_rounded, color: Color(0xFF38BDF8), size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _scanStatusText,
                          style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color.fromRGBO(220, 38, 38, 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded, color: Color(0xFFF87171), size: 16),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(color: Color(0xFFFCA5A5), fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

