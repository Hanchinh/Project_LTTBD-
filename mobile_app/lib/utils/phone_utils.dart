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
