import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';

/// Tiện ích băm và xác thực mã PIN bảo mật theo chuẩn PBKDF2/HMAC-SHA-256.
/// TUYỆT ĐỐI KHÔNG lưu PIN thô, KHÔNG ghi PIN vào log hay CSDL.
class PinCryptoUtils {
  static const int defaultIterations = 10000;
  static const int saltBytesLength = 16;
  static const int keyBytesLength = 32;

  /// Kiểm tra định dạng mã PIN (chỉ chấp nhận từ 4 đến 6 chữ số)
  static bool isValidPin(String? pin) {
    if (pin == null) return false;
    return RegExp(r'^\d{4,6}$').hasMatch(pin.trim());
  }

  /// Băm mã PIN với Salt ngẫu nhiên và số vòng lặp PBKDF2
  /// Định dạng đầu ra: `pbkdf2:sha256:<iterations>:<saltHex>:<hashHex>`
  static String hashPin(String pin, {int iterations = defaultIterations, Uint8List? customSalt}) {
    final cleanPin = pin.trim();
    if (!isValidPin(cleanPin)) {
      throw ArgumentError('Mã PIN phải từ 4 đến 6 chữ số');
    }
    final salt = customSalt ?? _generateSalt(saltBytesLength);
    final derivedKey = pbkdf2Sha256(
      password: utf8.encode(cleanPin),
      salt: salt,
      iterations: iterations,
      keyLength: keyBytesLength,
    );

    final saltHex = _toHex(salt);
    final hashHex = _toHex(derivedKey);
    return 'pbkdf2:sha256:$iterations:$saltHex:$hashHex';
  }

  /// Xác thực mã PIN nhập vào với chuỗi băm đã lưu (so sánh thời gian hằng số)
  static bool verifyPin(String pin, String? storedHash) {
    if (storedHash == null || storedHash.isEmpty) return false;
    final cleanPin = pin.trim();
    if (!isValidPin(cleanPin)) return false;

    try {
      final parts = storedHash.split(':');
      if (parts.length != 5 || parts[0] != 'pbkdf2' || parts[1] != 'sha256') {
        return false;
      }
      final iterations = int.parse(parts[2]);
      final salt = _fromHex(parts[3]);
      final expectedHash = parts[4];

      final derivedKey = pbkdf2Sha256(
        password: utf8.encode(cleanPin),
        salt: salt,
        iterations: iterations,
        keyLength: keyBytesLength,
      );
      final derivedHex = _toHex(derivedKey);
      return _constantTimeEquals(derivedHex, expectedHash);
    } catch (_) {
      return false;
    }
  }

  /// Thuật toán chuẩn PBKDF2 với hàm giả ngẫu nhiên HMAC-SHA-256 (RFC 2898 / RFC 8018)
  static Uint8List pbkdf2Sha256({
    required List<int> password,
    required List<int> salt,
    required int iterations,
    required int keyLength,
  }) {
    final hmac = Hmac(sha256, password);
    final numBlocks = (keyLength + 31) ~/ 32;
    final result = BytesBuilder(copy: false);

    for (int block = 1; block <= numBlocks; block++) {
      // U_1 = PRF(P, S || INT(i))
      final saltBlock = List<int>.from(salt)
        ..addAll([
          (block >> 24) & 0xff,
          (block >> 16) & 0xff,
          (block >> 8) & 0xff,
          block & 0xff,
        ]);

      List<int> u = hmac.convert(saltBlock).bytes;
      final blockResult = List<int>.from(u);

      for (int i = 1; i < iterations; i++) {
        u = hmac.convert(u).bytes;
        for (int j = 0; j < blockResult.length; j++) {
          blockResult[j] ^= u[j];
        }
      }

      result.add(blockResult);
    }

    final bytes = result.takeBytes();
    return Uint8List.sublistView(bytes, 0, keyLength);
  }

  static Uint8List _generateSalt(int length) {
    final random = Random.secure();
    final salt = Uint8List(length);
    for (int i = 0; i < length; i++) {
      salt[i] = random.nextInt(256);
    }
    return salt;
  }

  static String _toHex(List<int> bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  static Uint8List _fromHex(String hex) {
    final result = Uint8List(hex.length ~/ 2);
    for (int i = 0; i < result.length; i++) {
      result[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return result;
  }

  static bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    int diff = 0;
    for (int i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }
}
