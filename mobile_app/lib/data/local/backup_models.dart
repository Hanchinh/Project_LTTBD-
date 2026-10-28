/// Chế độ khôi phục dữ liệu
enum RestoreMode {
  /// Thay thế toàn bộ dữ liệu hiện tại bằng dữ liệu trong bản sao lưu
  fullReplace,

  /// Gộp dữ liệu mới vào dữ liệu hiện có (không ghi đè khách hàng trùng SĐT)
  merge,
}

/// Thông tin xem trước bản sao lưu trước khi khôi phục
class BackupPreview {
  final int formatVersion;
  final int schemaVersion;
  final String appVersion;
  final DateTime createdAt;
  final bool includePhotos;
  final int customersCount;
  final int savedLocationsCount;
  final int shiftsCount;
  final int photosCount;
  final int fileSizeBytes;
  final Map<String, dynamic> rawManifest;

  const BackupPreview({
    required this.formatVersion,
    required this.schemaVersion,
    required this.appVersion,
    required this.createdAt,
    required this.includePhotos,
    required this.customersCount,
    required this.savedLocationsCount,
    required this.shiftsCount,
    required this.photosCount,
    required this.fileSizeBytes,
    required this.rawManifest,
  });
}

/// Kết quả khôi phục dữ liệu
class RestoreResult {
  final RestoreMode mode;
  final int addedCustomers;
  final int skippedCustomers;
  final int addedLocations;
  final int addedPhotos;
  final int addedShifts;
  final String message;

  const RestoreResult({
    required this.mode,
    this.addedCustomers = 0,
    this.skippedCustomers = 0,
    this.addedLocations = 0,
    this.addedPhotos = 0,
    this.addedShifts = 0,
    required this.message,
  });
}

