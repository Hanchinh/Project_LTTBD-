/// Loại bỏ toàn bộ dấu thanh và dấu mũ tiếng Việt
String removeVietnameseDiacritics(String str) {
  if (str.isEmpty) return str;
  var result = str;

  // A, a
  result = result.replaceAll(RegExp(r'[àáạảãâầấậẩẫăằắặẳẵ]'), 'a');
  result = result.replaceAll(RegExp(r'[ÀÁẠẢÃÂẦẤẬẨẪĂẰẮẶẲẴ]'), 'A');

  // E, e
  result = result.replaceAll(RegExp(r'[èéẹẻẽêềếệểễ]'), 'e');
  result = result.replaceAll(RegExp(r'[ÈÉẸẺẼÊỀẾỆỂỄ]'), 'E');

  // I, i
  result = result.replaceAll(RegExp(r'[ìíịỉĩ]'), 'i');
  result = result.replaceAll(RegExp(r'[ÌÍỊỈĨ]'), 'I');

  // O, o
  result = result.replaceAll(RegExp(r'[òóọỏõôồốộổỗơờớợởỡ]'), 'o');
  result = result.replaceAll(RegExp(r'[ÒÓỌỎÕÔỒỐỘỔỖƠỜỚỢỞỠ]'), 'O');

  // U, u
  result = result.replaceAll(RegExp(r'[ùúụủũưừứựửữ]'), 'u');
  result = result.replaceAll(RegExp(r'[ÙÚỤỦŨƯỪỨỰỬỮ]'), 'U');

  // Y, y
  result = result.replaceAll(RegExp(r'[ỳýỵỷỹ]'), 'y');
  result = result.replaceAll(RegExp(r'[ỲÝỴỶỸ]'), 'Y');

  // D, d
  result = result.replaceAll(RegExp(r'[đ]'), 'd');
  result = result.replaceAll(RegExp(r'[Đ]'), 'D');

  return result;
}

/// Chuẩn hóa từ khóa tìm kiếm (bỏ dấu tiếng Việt, chuyển chữ thường, loại bỏ khoảng trắng thừa)
String normalizeSearchQuery(String query) {
  return removeVietnameseDiacritics(query).toLowerCase().trim();
}

/// Xây dựng trường tìm kiếm (search_text) đồng bộ cho bảng customers
/// Kết hợp tên, số điện thoại, địa chỉ, ghi chú ở cả dạng có dấu và không dấu
String buildCustomerSearchText({
  required String fullName,
  required String phoneNumber,
  String? addressText,
  String? notes,
}) {
  final components = <String>[
    fullName,
    phoneNumber,
    phoneNumber.replaceAll(RegExp(r'\D'), ''),
    if (addressText != null && addressText.trim().isNotEmpty) addressText.trim(),
    if (notes != null && notes.trim().isNotEmpty) notes.trim(),
  ];

  final raw = components.join(' ');
  final unaccented = removeVietnameseDiacritics(raw);
  return '$raw $unaccented'.toLowerCase();
}
