import 'package:sqflite/sqflite.dart';
import 'package:delivery_marker_mobile/models/shift_model.dart';

/// Helper xử lý sinh mã ca làm việc (SHF-YYYYMMDD-001) và tên ca tự động
class ShiftCodeHelpers {
  /// Xác định ngày làm việc, mã ca và tên ca mới.
  /// Đảm bảo mã ca tăng tuần tự theo ngày, reset khi sang ngày mới,
  /// và tên ca được gợi ý tránh trùng lặp.
  static Future<Map<String, dynamic>> resolveShiftCodeAndName({
    required Database db,
    String? shiftDate,
    String? shiftName,
  }) async {
    final nowUtc = DateTime.now().toUtc();
    final nowVn = nowUtc.add(const Duration(hours: 7));

    // Xác định ngày làm việc theo giờ Việt Nam
    DateTime targetVnDate;
    if (shiftDate != null && shiftDate.trim().isNotEmpty) {
      final parsed = DateTime.tryParse(shiftDate.trim());
      targetVnDate = parsed ?? nowVn;
    } else {
      targetVnDate = nowVn;
    }

    final yearStr = targetVnDate.year.toString();
    final monthStr = targetVnDate.month.toString().padLeft(2, '0');
    final dayStr = targetVnDate.day.toString().padLeft(2, '0');
    final workDateStr = '$yearStr-$monthStr-$dayStr';
    final dateSlug = '$yearStr$monthStr$dayStr';

    // 1. Sinh shift_code dạng SHF-YYYYMMDD-XXX tăng theo ngày
    final existingRows = await db.rawQuery('''
      SELECT shift_code, shift_name FROM shifts
      WHERE work_date = ? OR shift_code LIKE ?
      ORDER BY shift_code DESC
    ''', [workDateStr, 'SHF-$dateSlug-%']);

    final codePattern = RegExp(r'^SHF-\d{8}-(\d+)$');
    int maxSeq = 0;
    for (final r in existingRows) {
      final code = r['shift_code'] as String?;
      if (code != null) {
        final match = codePattern.firstMatch(code);
        if (match != null) {
          final seq = int.tryParse(match.group(1)!) ?? 0;
          if (seq > maxSeq) {
            maxSeq = seq;
          }
        }
      }
    }
    final nextSeq = maxSeq + 1;
    final shiftCode = 'SHF-$dateSlug-${nextSeq.toString().padLeft(3, '0')}';

    // 2. Xác định shift_name (cắt khoảng trắng, tối đa 100 ký tự; nếu rỗng thì gợi ý)
    String resolvedName;
    if (shiftName != null && shiftName.trim().isNotEmpty) {
      final trimmed = shiftName.trim();
      resolvedName = trimmed.length > 100 ? trimmed.substring(0, 100) : trimmed;
    } else {
      final existingNames = existingRows
          .map((r) => r['shift_name'] as String?)
          .whereType<String>()
          .toList();
      resolvedName = ShiftModel.suggestShiftName(
        dateTime: targetVnDate,
        existingNames: existingNames,
      );
    }

    return {
      'workDate': workDateStr,
      'shiftCode': shiftCode,
      'shiftName': resolvedName,
      'targetVnDate': targetVnDate,
    };
  }
}

