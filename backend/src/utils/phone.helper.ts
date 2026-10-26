// Helper to parse and normalize Vietnamese phone numbers for bulk operations

export interface ParsedPhoneItem {
  original: string;
  cleanPhone: string;
  isValid: boolean;
  reason?: string;
}

export interface ParseBulkPhonesResult {
  items: ParsedPhoneItem[];
  uniquePhones: string[];
  totalRawCount: number;
}

export function parseAndNormalizeBulkPhones(
  rawText?: string,
  phonesArray?: string[]
): ParseBulkPhonesResult {
  const rawItems: string[] = [];

  if (phonesArray && Array.isArray(phonesArray)) {
    for (const p of phonesArray) {
      if (typeof p === 'string' && p.trim()) {
        rawItems.push(p.trim());
      }
    }
  }

  if (rawText && typeof rawText === 'string') {
    // Tách số từ rawText theo xuống dòng, dấu phẩy, dấu chấm phẩy
    const splitTokens = rawText.split(/[\r\n,;]+/);
    for (const token of splitTokens) {
      if (token && token.trim()) {
        rawItems.push(token.trim());
      }
    }
  }

  const items: ParsedPhoneItem[] = [];
  const seenValid = new Set<string>();
  const seenInvalid = new Set<string>();
  const uniquePhones: string[] = [];

  for (const raw of rawItems) {
    // Giữ khoảng trắng, dấu chấm bên trong một số rồi chuẩn hóa
    // Ví dụ: "0908 911 111", "+84 908 911 111", "0908.911.111"
    let clean = raw.replace(/[\s\.\-\(\)]/g, '');
    if (clean.startsWith('+84')) {
      clean = '0' + clean.substring(3);
    } else if (clean.startsWith('84') && clean.length === 11) {
      clean = '0' + clean.substring(2);
    } else if (clean.length === 9 && !clean.startsWith('0')) {
      clean = '0' + clean;
    }

    // Kiểm tra định dạng số điện thoại Việt Nam (10 chữ số, bắt đầu bằng 0)
    const isValidFormat = /^0\d{9}$/.test(clean);

    if (isValidFormat) {
      if (!seenValid.has(clean)) {
        seenValid.add(clean);
        uniquePhones.push(clean);
        items.push({ original: raw, cleanPhone: clean, isValid: true });
      }
    } else {
      const invalidKey = raw.trim();
      if (!seenInvalid.has(invalidKey)) {
        seenInvalid.add(invalidKey);
        items.push({
          original: raw,
          cleanPhone: clean,
          isValid: false,
          reason: 'Số điện thoại không đúng định dạng (cần 10 chữ số hợp lệ)',
        });
      }
    }
  }

  return {
    items,
    uniquePhones,
    totalRawCount: rawItems.length,
  };
}
