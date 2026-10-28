/// Hàm chuẩn hóa số điện thoại theo định dạng chuẩn Việt Nam (10 chữ số bắt đầu bằng 0)
String normalizeCustomerPhone(String raw) {
  String clean = raw.replaceAll(RegExp(r'\D'), '');
  if (clean.startsWith('84') && clean.length == 11) {
    clean = '0${clean.substring(2)}';
  } else if (clean.length == 9 && !clean.startsWith('0')) {
    clean = '0$clean';
  }
  return clean;
}

/// Kiểm tra số điện thoại có đúng định dạng Việt Nam chuẩn (10 chữ số bắt đầu bằng 0)
bool isValidVnPhone(String raw) {
  final clean = normalizeCustomerPhone(raw);
  return RegExp(r'^0\d{9}$').hasMatch(clean);
}

/// Kết quả phân tích một số điện thoại trong danh sách dán hàng loạt
class ParsedPhoneItem {
  final String original;
  final String cleanPhone;
  final bool isValid;
  final String? reason;

  const ParsedPhoneItem({
    required this.original,
    required this.cleanPhone,
    required this.isValid,
    this.reason,
  });

  String get rawInput => original;
  String get normalizedPhone => cleanPhone;
}

/// Kết quả tách và chuẩn hóa danh sách số điện thoại hàng loạt
class ParseBulkPhonesResult {
  final List<ParsedPhoneItem> items;
  final List<String> uniquePhones;
  final int totalRawCount;

  const ParseBulkPhonesResult({
    required this.items,
    required this.uniquePhones,
    required this.totalRawCount,
  });

  int get totalCount => totalRawCount;
  bool get isExceededLimit => totalRawCount > 200 || items.length > 200 || uniquePhones.length > 200;
}


/// Tách và chuẩn hóa danh sách số điện thoại hàng loạt từ chuỗi văn bản hoặc mảng
/// - Tách theo: xuống dòng (\r, \n), dấu phẩy (,), dấu chấm phẩy (;)
/// - Giữ khoảng trắng, dấu chấm, gạch nối bên trong số rồi chuẩn hóa
///   Ví dụ: "0908 911 111", "+84 908 911 111", "0908.911.111" -> "0908911111"
/// - Lọc trùng lặp tự động
ParseBulkPhonesResult parseAndNormalizeBulkPhones({
  String? rawText,
  List<String>? phones,
}) {
  final rawItems = <String>[];

  if (phones != null) {
    for (final p in phones) {
      if (p.trim().isNotEmpty) {
        rawItems.add(p.trim());
      }
    }
  }

  if (rawText != null && rawText.trim().isNotEmpty) {
    final tokens = rawText.split(RegExp(r'[\r\n,;]+'));
    for (final t in tokens) {
      final trimmed = t.trim();
      if (trimmed.isNotEmpty) {
        rawItems.add(trimmed);
      }
    }
  }

  final items = <ParsedPhoneItem>[];
  final seenValid = <String>{};
  final seenInvalid = <String>{};
  final uniquePhones = <String>[];

  for (final raw in rawItems) {
    final clean = normalizeCustomerPhone(raw);
    final valid = isValidVnPhone(raw);

    if (valid) {
      if (!seenValid.contains(clean)) {
        seenValid.add(clean);
        uniquePhones.add(clean);
        items.add(ParsedPhoneItem(
          original: raw,
          cleanPhone: clean,
          isValid: true,
        ));
      }
    } else {
      final invalidKey = raw.trim();
      if (!seenInvalid.contains(invalidKey)) {
        seenInvalid.add(invalidKey);
        items.add(ParsedPhoneItem(
          original: raw,
          cleanPhone: clean,
          isValid: false,
          reason: 'Số điện thoại không đúng định dạng (cần 10 chữ số hợp lệ)',
        ));
      }
    }
  }

  return ParseBulkPhonesResult(
    items: items,
    uniquePhones: uniquePhones,
    totalRawCount: rawItems.length,
  );
}
