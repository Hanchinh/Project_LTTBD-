import '../../local/app_database.dart';
import '../../models/user_model.dart';
import '../../utils/pin_crypto_utils.dart';
import '../profile_repository.dart';

/// Kết quả xác thực mã PIN
class PinVerifyResult {
  final bool success;
  final bool isLocked;
  final int remainingLockoutSeconds;
  final int failedAttempts;
  final String? message;

  const PinVerifyResult({
    required this.success,
    this.isLocked = false,
    this.remainingLockoutSeconds = 0,
    this.failedAttempts = 0,
    this.message,
  });
}

/// Triển khai ProfileRepository cục bộ (Local-First)
/// - Hồ sơ lưu trong bảng `app_profile` (id = 1): Tên hiển thị, mã PIN băm
/// - Thống kê số lượng tính trực tiếp từ SQLite (vị trí, ca, ảnh)
/// - Quản lý chu kỳ khóa PIN, thời gian chờ nền, chống brute-force tăng dần
/// - TUYỆT ĐỐI KHÔNG lưu PIN thô, KHÔNG ghi PIN vào log hay CSDL
class LocalProfileRepository implements ProfileRepository {
  final AppDatabase _appDb;

  LocalProfileRepository({AppDatabase? appDb}) : _appDb = appDb ?? AppDatabase.instance;

  /// CSDL AppDatabase cục bộ
  AppDatabase get appDb => _appDb;

  static const String _keyPinTimeout = 'pin_timeout_seconds';
  static const String _keyFailedAttempts = 'pin_failed_attempts';
  static const String _keyLockoutUntil = 'pin_lockout_until';
  static const String _keyLastActiveAt = 'pin_last_active_at';
  static const String _keyOnboardingDone = 'onboarding_completed';

  @override
  Future<UserModel?> getCurrentUser() async {
    final profile = await _appDb.getAppProfile();
    final displayName = (profile?['display_name'] as String?)?.trim();
    final name = (displayName != null && displayName.isNotEmpty) ? displayName : 'Người giao hàng';

    return UserModel(
      id: 'local_shipper_1',
      fullName: name,
      phoneNumber: '',
      role: 'SHIPPER',
      assignedAreaIds: const [],
      token: 'local_token',
    );
  }

  @override
  Future<Map<String, int>> getMyStats() async {
    return await _appDb.getStats();
  }

  /// Cập nhật tên hiển thị người dùng
  Future<void> updateDisplayName(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Tên hiển thị không được để trống');
    }
    await _appDb.updateDisplayName(trimmed);
    await _appDb.logActivity(
      action: 'UPDATE_PROFILE_NAME',
      entity: 'app_profile',
      entityId: '1',
      details: {'displayName': trimmed},
    );
  }

  /// Kiểm tra ứng dụng đã thiết lập mã PIN hay chưa
  Future<bool> hasPin() async {
    final profile = await _appDb.getAppProfile();
    final pinHash = profile?['pin_hash'] as String?;
    return pinHash != null && pinHash.isNotEmpty;
  }

  /// Thiết lập mã PIN mới (băm bằng PBKDF2/SHA-256)
  Future<void> setPin(String newPin) async {
    final cleanPin = newPin.trim();
    if (!PinCryptoUtils.isValidPin(cleanPin)) {
      throw ArgumentError('Mã PIN phải từ 4 đến 6 chữ số');
    }
    final hash = PinCryptoUtils.hashPin(cleanPin);
    await _appDb.updatePinHash(hash);
    await _clearLockoutState();
    await _appDb.logActivity(
      action: 'SET_PIN',
      entity: 'app_profile',
      entityId: '1',
      details: {'pinLength': cleanPin.length},
    );
  }

  /// Tắt mã PIN khóa app
  Future<void> disablePin() async {
    await _appDb.updatePinHash(null);
    await _clearLockoutState();
    await _appDb.logActivity(
      action: 'DISABLE_PIN',
      entity: 'app_profile',
      entityId: '1',
    );
  }

  /// Kiểm tra trạng thái khóa tạm thời mà không tính vào số lần nhập sai
  Future<PinVerifyResult?> checkLockoutStatus() async {
    final lockoutUntilStr = await _appDb.getMeta(_keyLockoutUntil);
    if (lockoutUntilStr != null) {
      final lockoutUntil = DateTime.tryParse(lockoutUntilStr);
      if (lockoutUntil != null && DateTime.now().isBefore(lockoutUntil)) {
        final remaining = lockoutUntil.difference(DateTime.now()).inSeconds + 1;
        final failedCountStr = await _appDb.getMeta(_keyFailedAttempts);
        final failedCount = int.tryParse(failedCountStr ?? '0') ?? 0;
        return PinVerifyResult(
          success: false,
          isLocked: true,
          remainingLockoutSeconds: remaining > 0 ? remaining : 1,
          failedAttempts: failedCount,
          message: 'Đã nhập sai quá nhiều lần. Vui lòng chờ $remaining giây để thử lại.',
        );
      }
    }
    return null;
  }

  /// Xác thực mã PIN nhập vào với cơ chế khóa tăng dần khi nhập sai
  Future<PinVerifyResult> verifyPin(String inputPin) async {
    final profile = await _appDb.getAppProfile();
    final storedHash = profile?['pin_hash'] as String?;
    if (storedHash == null || storedHash.isEmpty) {
      return const PinVerifyResult(success: true);
    }

    // 1. Kiểm tra trạng thái khóa tạm thời (lockout)
    final lockoutUntilStr = await _appDb.getMeta(_keyLockoutUntil);
    if (lockoutUntilStr != null) {
      final lockoutUntil = DateTime.tryParse(lockoutUntilStr);
      if (lockoutUntil != null && DateTime.now().isBefore(lockoutUntil)) {
        final remaining = lockoutUntil.difference(DateTime.now()).inSeconds + 1;
        final failedCountStr = await _appDb.getMeta(_keyFailedAttempts);
        final failedCount = int.tryParse(failedCountStr ?? '0') ?? 0;
        return PinVerifyResult(
          success: false,
          isLocked: true,
          remainingLockoutSeconds: remaining > 0 ? remaining : 1,
          failedAttempts: failedCount,
          message: 'Đã nhập sai quá nhiều lần. Vui lòng chờ $remaining giây để thử lại.',
        );
      }
    }

    // 2. Xác thực băm PIN
    final isMatch = PinCryptoUtils.verifyPin(inputPin, storedHash);
    if (isMatch) {
      await _clearLockoutState();
      await recordActiveNow();
      return const PinVerifyResult(success: true);
    }

    // 3. Xử lý khi nhập sai: Tăng số lần thử sai
    final currentFailedStr = await _appDb.getMeta(_keyFailedAttempts);
    final failedCount = (int.tryParse(currentFailedStr ?? '0') ?? 0) + 1;
    await _appDb.setMeta(_keyFailedAttempts, failedCount.toString());

    if (failedCount >= 5) {
      // 5 lần sai -> khóa 30 giây; mỗi lần sai thêm cộng 15 giây
      final lockoutDuration = 30 + (failedCount - 5) * 15;
      final lockoutUntil = DateTime.now().add(Duration(seconds: lockoutDuration));
      await _appDb.setMeta(_keyLockoutUntil, lockoutUntil.toIso8601String());

      return PinVerifyResult(
        success: false,
        isLocked: true,
        remainingLockoutSeconds: lockoutDuration,
        failedAttempts: failedCount,
        message: 'Mã PIN không đúng. Ứng dụng bị tạm khóa trong $lockoutDuration giây.',
      );
    }

    final remainingTries = 5 - failedCount;
    return PinVerifyResult(
      success: false,
      isLocked: false,
      failedAttempts: failedCount,
      message: 'Mã PIN không chính xác (còn $remainingTries lần thử).',
    );
  }

  /// Lấy cấu hình thời gian tự động khóa (giây). Mặc định 60 giây (1 phút).
  Future<int> getPinTimeoutSeconds() async {
    final val = await _appDb.getMeta(_keyPinTimeout);
    return int.tryParse(val ?? '60') ?? 60;
  }

  /// Cập nhật cấu hình thời gian tự động khóa (0: ngay lập tức, 60: 1 phút, 300: 5 phút)
  Future<void> setPinTimeoutSeconds(int seconds) async {
    await _appDb.setMeta(_keyPinTimeout, seconds.toString());
  }

  /// Kiểm tra có cần hiển thị màn hình khóa PIN hay không
  Future<bool> shouldLockApp() async {
    final hasActivePin = await hasPin();
    if (!hasActivePin) return false;

    final lastActiveStr = await _appDb.getMeta(_keyLastActiveAt);
    if (lastActiveStr == null) return true; // Chưa từng mở hoặc mới khởi động

    final lastActive = DateTime.tryParse(lastActiveStr);
    if (lastActive == null) return true;

    final timeoutSeconds = await getPinTimeoutSeconds();
    if (timeoutSeconds <= 0) return true; // Khóa ngay lập tức

    final elapsedSeconds = DateTime.now().difference(lastActive).inSeconds;
    return elapsedSeconds >= timeoutSeconds;
  }

  /// Ghi nhận thời điểm người dùng hoạt động gần nhất
  Future<void> recordActiveNow() async {
    await _appDb.setMeta(_keyLastActiveAt, DateTime.now().toIso8601String());
  }

  /// Kiểm tra có phải lần đầu tiên mở app không
  Future<bool> isFirstOpen() async {
    final val = await _appDb.getMeta(_keyOnboardingDone);
    return val != 'true';
  }

  /// Hoàn tất màn chào mở đầu
  Future<void> completeFirstOpen({String? displayName}) async {
    if (displayName != null && displayName.trim().isNotEmpty) {
      await _appDb.updateDisplayName(displayName.trim());
    }
    await _appDb.setMeta(_keyOnboardingDone, 'true');
  }

  /// Xóa toàn bộ dữ liệu khi quên mã PIN (có cảnh báo mạnh mẽ)
  Future<void> resetAllDataWithWipe() async {
    final db = await _appDb.database;
    await db.transaction((txn) async {
      await txn.delete('customer_photos');
      await txn.delete('shift_delivery_points');
      await txn.delete('shifts');
      await txn.delete('location_history');
      await txn.delete('saved_locations');
      await txn.delete('customers');
      await txn.delete('activity_log');
      await txn.delete('app_meta');
      await txn.delete('app_profile');
    });

    final now = AppDatabase.currentIsoUtc();
    await _appDb.setAppProfile(displayName: 'Người giao hàng', pinHash: null);
    await _appDb.setMeta(_keyOnboardingDone, 'true');
    await _appDb.logActivity(
      action: 'WIPE_RESET_FORGOT_PIN',
      entity: 'system',
      details: {'timestamp': now},
    );
  }

  Future<void> _clearLockoutState() async {
    final db = await _appDb.database;
    await db.delete('app_meta', where: 'key IN (?, ?)', whereArgs: [_keyFailedAttempts, _keyLockoutUntil]);
  }

  // --- Các hàm ProfileRepository kế thừa (tương thích) ---

  @override
  Future<UserModel?> login(String phoneNumber, String password) async {
    return await getCurrentUser();
  }

  @override
  Future<void> logout() async {
    // Không đăng xuất trong chế độ Local
  }

  @override
  Future<List<Map<String, dynamic>>> getMyAreas() async {
    return const [];
  }

  @override
  Future<String?> getPreferredAreaId() async => null;

  @override
  Future<void> setPreferredAreaId(String areaId) async {}

  @override
  Future<void> clearPreferredAreaId() async {}

  @override
  Future<Map<String, dynamic>> changePassword({
    required String currentPassword,
    required String newPassword,
    String? confirmPassword,
  }) async {
    throw UnsupportedError('Chế độ Local-First hoạt động không cần tài khoản máy chủ hay mật khẩu.');
  }

  @override
  Future<String?> getSavedLoginPhone() async => null;
}
