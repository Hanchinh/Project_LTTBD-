// Tiện ích mã hóa và giải mã gói dữ liệu chia sẻ (.dshare) bằng AES-GCM.
// Bảo vệ dữ liệu điểm giao khi chuyển giao giữa các thiết bị tài xế.
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;

import 'package:delivery_marker_mobile/core/utils/pin_crypto_utils.dart';

/// Tiện ích mã hóa bảo vệ tệp chia sẻ và chia/ghép mã QR nhiều mảnh
class ShareCryptoUtils {
  static const int pbkdf2Iterations = 10000;
  static const int saltBytesLength = 16;
  static const int ivBytesLength = 16;
  static const int keyBytesLength = 32;

  /// Tạo salt ngẫu nhiên an toàn mật mã học
  static Uint8List _randomBytes(int length) {
    final rng = Random.secure();
    final bytes = Uint8List(length);
    for (int i = 0; i < length; i++) {
      bytes[i] = rng.nextInt(256);
    }
    return bytes;
  }

  static String _toHex(List<int> bytes) =>
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

  static Uint8List _fromHex(String hex) {
    final cleanHex = hex.trim();
    final result = Uint8List(cleanHex.length ~/ 2);
    for (int i = 0; i < result.length; i++) {
      result[i] = int.parse(cleanHex.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return result;
  }

  /// Mã hóa chuỗi byte (JSON data) bằng AES-GCM với khóa sinh từ mật khẩu qua PBKDF2
  static Map<String, dynamic> encryptBytes(Uint8List plainBytes, String password) {
    if (password.trim().isEmpty) {
      throw ArgumentError('Mật khẩu không được để trống');
    }
    final salt = _randomBytes(saltBytesLength);
    final ivBytes = _randomBytes(ivBytesLength);

    final keyBytes = PinCryptoUtils.pbkdf2Sha256(
      password: utf8.encode(password.trim()),
      salt: salt,
      iterations: pbkdf2Iterations,
      keyLength: keyBytesLength,
    );

    final key = enc.Key(keyBytes);
    final iv = enc.IV(ivBytes);
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.gcm));

    final encrypted = encrypter.encryptBytes(plainBytes, iv: iv);

    return {
      'cipher': encrypted.bytes,
      'salt': _toHex(salt),
      'iv': _toHex(ivBytes),
    };
  }

  /// Giải mã chuỗi byte bằng AES-GCM với mật khẩu
  static Uint8List decryptBytes({
    required Uint8List cipherBytes,
    required String password,
    required String saltHex,
    required String ivHex,
  }) {
    if (password.trim().isEmpty) {
      throw ArgumentError('Vui lòng nhập mật khẩu để mở gói dữ liệu');
    }

    try {
      final salt = _fromHex(saltHex);
      final ivBytes = _fromHex(ivHex);

      final keyBytes = PinCryptoUtils.pbkdf2Sha256(
        password: utf8.encode(password.trim()),
        salt: salt,
        iterations: pbkdf2Iterations,
        keyLength: keyBytesLength,
      );

      final key = enc.Key(keyBytes);
      final iv = enc.IV(ivBytes);
      final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.gcm));

      final decrypted = encrypter.decryptBytes(enc.Encrypted(cipherBytes), iv: iv);
      return Uint8List.fromList(decrypted);
    } catch (e) {
      throw const FormatException('Mật khẩu không chính xác hoặc dữ liệu bị sửa đổi');
    }
  }

  /// Nén JSON thành danh sách các chuỗi mã QR (gzip + base64url, chia mảnh nếu > 1.2KB)
  static List<String> createQrChunks(String pointsJson, {int maxChunkChars = 1200}) {
    // 1. Nén gzip
    final gzipped = Uint8List.fromList(gzip.encode(utf8.encode(pointsJson)));

    // 2. Mã hóa base64url
    final encoded = base64Url.encode(gzipped);

    // 3. Tính mã băm ngắn SHA-256 (8 ký tự hex) để kiểm tra toàn vẹn
    final checksum = sha256.convert(utf8.encode(encoded)).toString().substring(0, 8);

    if (encoded.length <= 1400) {
      return ['DSHARE:1:1:$checksum:$encoded'];
    }

    // 4. Chia nhiều mảnh
    final List<String> chunks = [];
    final totalChunks = (encoded.length + maxChunkChars - 1) ~/ maxChunkChars;

    for (int i = 0; i < totalChunks; i++) {
      final start = i * maxChunkChars;
      final end = min(start + maxChunkChars, encoded.length);
      final slice = encoded.substring(start, end);
      final index = i + 1; // 1-based
      chunks.add('DSHARE:$index:$totalChunks:$checksum:$slice');
    }

    return chunks;
  }
}

/// Trạng thái quét mảnh mã QR
class QrScanChunkStatus {
  final bool isComplete;
  final int totalChunks;
  final int scannedCount;
  final List<int> missingIndexes;
  final String? errorMessage;
  final bool isNewChunk;

  const QrScanChunkStatus({
    required this.isComplete,
    required this.totalChunks,
    required this.scannedCount,
    required this.missingIndexes,
    this.errorMessage,
    this.isNewChunk = false,
  });
}

/// Bộ thu thập và ghép nối các mảnh mã QR
class QrChunkCollector {
  final Map<int, String> _chunks = {};
  int? _totalChunks;
  String? _expectedChecksum;

  int? get totalChunks => _totalChunks;
  int get scannedCount => _chunks.length;
  bool get isComplete => _totalChunks != null && _chunks.length == _totalChunks;

  List<int> get missingIndexes {
    if (_totalChunks == null) return [];
    final missing = <int>[];
    for (int i = 1; i <= _totalChunks!; i++) {
      if (!_chunks.containsKey(i)) {
        missing.add(i);
      }
    }
    return missing;
  }

  void reset() {
    _chunks.clear();
    _totalChunks = null;
    _expectedChecksum = null;
  }

  /// Xử lý một mã QR vừa quét
  QrScanChunkStatus addRawCode(String rawCode) {
    final clean = rawCode.trim();
    if (!clean.startsWith('DSHARE:')) {
      return QrScanChunkStatus(
        isComplete: false,
        totalChunks: _totalChunks ?? 0,
        scannedCount: _chunks.length,
        missingIndexes: missingIndexes,
        errorMessage: 'Mã QR không thuộc định dạng chia sẻ điểm (DSHARE)',
      );
    }

    final parts = clean.split(':');
    if (parts.length < 5) {
      return QrScanChunkStatus(
        isComplete: false,
        totalChunks: _totalChunks ?? 0,
        scannedCount: _chunks.length,
        missingIndexes: missingIndexes,
        errorMessage: 'Cấu trúc mã QR không hợp lệ',
      );
    }

    final index = int.tryParse(parts[1]);
    final total = int.tryParse(parts[2]);
    final checksum = parts[3];
    final chunkData = parts.sublist(4).join(':');

    if (index == null || total == null || index < 1 || index > total) {
      return QrScanChunkStatus(
        isComplete: false,
        totalChunks: _totalChunks ?? 0,
        scannedCount: _chunks.length,
        missingIndexes: missingIndexes,
        errorMessage: 'Chỉ mục mảnh QR không hợp lệ ($parts[1]/$parts[2])',
      );
    }

    if (_totalChunks != null && _totalChunks != total) {
      return QrScanChunkStatus(
        isComplete: false,
        totalChunks: _totalChunks!,
        scannedCount: _chunks.length,
        missingIndexes: missingIndexes,
        errorMessage: 'Mã này thuộc một gói chia sẻ khác (tổng $total != $_totalChunks)',
      );
    }

    if (_expectedChecksum != null && _expectedChecksum != checksum) {
      return QrScanChunkStatus(
        isComplete: false,
        totalChunks: _totalChunks!,
        scannedCount: _chunks.length,
        missingIndexes: missingIndexes,
        errorMessage: 'Mã này thuộc một gói chia sẻ khác (mã kiểm tra không khớp)',
      );
    }

    _totalChunks = total;
    _expectedChecksum = checksum;

    final isNew = !_chunks.containsKey(index);
    _chunks[index] = chunkData;

    return QrScanChunkStatus(
      isComplete: isComplete,
      totalChunks: total,
      scannedCount: _chunks.length,
      missingIndexes: missingIndexes,
      isNewChunk: isNew,
    );
  }

  /// Ghép nối các mảnh và giải nén thành chuỗi JSON gốc
  String assembleAndDecode() {
    if (!isComplete) {
      throw StateError('Chưa quét đủ các mảnh QR (còn thiếu: ${missingIndexes.join(", ")})');
    }

    final sb = StringBuffer();
    for (int i = 1; i <= _totalChunks!; i++) {
      sb.write(_chunks[i]!);
    }
    final fullEncoded = sb.toString();

    // Kiểm tra checksum
    final computedChecksum = sha256.convert(utf8.encode(fullEncoded)).toString().substring(0, 8);
    if (computedChecksum != _expectedChecksum) {
      throw const FormatException('Mã kiểm tra toàn vẹn của chuỗi QR không khớp, dữ liệu có thể bị lỗi');
    }

    // Giải mã base64url và giải nén gzip
    try {
      final gzipped = base64Url.decode(fullEncoded);
      final decompressed = gzip.decode(gzipped);
      return utf8.decode(decompressed);
    } catch (e) {
      throw FormatException('Không thể giải nén dữ liệu từ mã QR: $e');
    }
  }
}

