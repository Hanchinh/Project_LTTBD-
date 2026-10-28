import 'package:delivery_marker_mobile/core/utils/pin_crypto_utils.dart';
import 'package:delivery_marker_mobile/data/local/app_database.dart';
import 'package:delivery_marker_mobile/data/repositories/profile_repository.dart';
import 'package:delivery_marker_mobile/models/user_model.dart';

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
class LocalProfileRepository implements ProfileRepository {
  final AppDatabase _appDb;
  LocalProfileRepository({AppDatabase? appDb}) : _appDb = appDb ?? AppDatabase.instance;
  AppDatabase get appDb => _appDb;

  static const _keyPinTimeout = 'pin_timeout_seconds';
  static const _keyFailedAttempts = 'pin_failed_attempts';
  static const _keyLockoutUntil = 'pin_lockout_until';
  static const _keyLastActiveAt = 'pin_last_active_at';
  static const _keyOnboardingDone = 'onboarding_completed';

  @override
  Future<UserModel?> getCurrentUser() async {
    final profile = await _appDb.getAppProfile();
    final name = (profile?['display_name'] as String?)?.trim();
    return UserModel(
      id: 'local_shipper_1',
      fullName: (name != null && name.isNotEmpty) ? name : 'Người giao hàng',
      phoneNumber: '',
      role: 'SHIPPER',
      assignedAreaIds: const [],
      token: 'local_token',
    );
  }

  @override
  Future<Map<String, int>> getMyStats() => _appDb.getStats();

  Future<void> updateDisplayName(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw ArgumentError('Tên hiển thị không được để trống');
    await _appDb.updateDisplayName(trimmed);
    await _appDb.logActivity(action: 'UPDATE_PROFILE_NAME', entity: 'app_profile', entityId: '1', details: {'displayName': trimmed});
  }

  Future<bool> hasPin() async {
    final profile = await _appDb.getAppProfile();
    final pinHash = profile?['pin_hash'] as String?;
    return pinHash != null && pinHash.isNotEmpty;
  }

  Future<void> setPin(String newPin) async {
    final cleanPin = newPin.trim();
    if (!PinCryptoUtils.isValidPin(cleanPin)) throw ArgumentError('Mã PIN phải từ 4 đến 6 chữ số');
    await _appDb.updatePinHash(PinCryptoUtils.hashPin(cleanPin));
    await _clearLockoutState();
    await _appDb.logActivity(action: 'SET_PIN', entity: 'app_profile', entityId: '1', details: {'pinLength': cleanPin.length});
  }

  Future<void> disablePin() async {
    await _appDb.updatePinHash(null);
    await _clearLockoutState();
    await _appDb.logActivity(action: 'DISABLE_PIN', entity: 'app_profile', entityId: '1');
  }

  Future<PinVerifyResult?> _checkLockout() async {
    final str = await _appDb.getMeta(_keyLockoutUntil);
    if (str == null) return null;
    final until = DateTime.tryParse(str);
    if (until == null || !DateTime.now().isBefore(until)) return null;
    final remaining = until.difference(DateTime.now()).inSeconds + 1;
    final failed = int.tryParse(await _appDb.getMeta(_keyFailedAttempts) ?? '0') ?? 0;
    return PinVerifyResult(
      success: false,
      isLocked: true,
      remainingLockoutSeconds: remaining > 0 ? remaining : 1,
      failedAttempts: failed,
      message: 'Đã nhập sai quá nhiều lần. Vui lòng chờ $remaining giây để thử lại.',
    );
  }

  Future<PinVerifyResult?> checkLockoutStatus() => _checkLockout();

  Future<PinVerifyResult> verifyPin(String inputPin) async {
    final profile = await _appDb.getAppProfile();
    final storedHash = profile?['pin_hash'] as String?;
    if (storedHash == null || storedHash.isEmpty) return const PinVerifyResult(success: true);

    final locked = await _checkLockout();
    if (locked != null) return locked;

    if (PinCryptoUtils.verifyPin(inputPin, storedHash)) {
      await _clearLockoutState();
      await recordActiveNow();
      return const PinVerifyResult(success: true);
    }

    final failed = (int.tryParse(await _appDb.getMeta(_keyFailedAttempts) ?? '0') ?? 0) + 1;
    await _appDb.setMeta(_keyFailedAttempts, failed.toString());

    if (failed >= 5) {
      final dur = 30 + (failed - 5) * 15;
      await _appDb.setMeta(_keyLockoutUntil, DateTime.now().add(Duration(seconds: dur)).toIso8601String());
      return PinVerifyResult(success: false, isLocked: true, remainingLockoutSeconds: dur, failedAttempts: failed, message: 'Mã PIN không đúng. Ứng dụng bị tạm khóa trong $dur giây.');
    }

    return PinVerifyResult(success: false, isLocked: false, failedAttempts: failed, message: 'Mã PIN không chính xác (còn ${5 - failed} lần thử).');
  }

  Future<int> getPinTimeoutSeconds() async => int.tryParse(await _appDb.getMeta(_keyPinTimeout) ?? '60') ?? 60;
  Future<void> setPinTimeoutSeconds(int seconds) => _appDb.setMeta(_keyPinTimeout, seconds.toString());

  Future<bool> shouldLockApp() async {
    if (!await hasPin()) return false;
    final lastActiveStr = await _appDb.getMeta(_keyLastActiveAt);
    if (lastActiveStr == null) return true;
    final lastActive = DateTime.tryParse(lastActiveStr);
    if (lastActive == null) return true;
    final timeout = await getPinTimeoutSeconds();
    return timeout <= 0 || DateTime.now().difference(lastActive).inSeconds >= timeout;
  }

  Future<void> recordActiveNow() => _appDb.setMeta(_keyLastActiveAt, DateTime.now().toIso8601String());
  Future<bool> isFirstOpen() async => (await _appDb.getMeta(_keyOnboardingDone)) != 'true';

  Future<void> completeFirstOpen({String? displayName}) async {
    if (displayName != null && displayName.trim().isNotEmpty) await _appDb.updateDisplayName(displayName.trim());
    await _appDb.setMeta(_keyOnboardingDone, 'true');
  }

  Future<void> resetAllDataWithWipe() async {
    final db = await _appDb.database;
    await db.transaction((txn) async {
      for (final table in ['customer_photos', 'shift_delivery_points', 'shifts', 'location_history', 'saved_locations', 'customers', 'activity_log', 'app_meta', 'app_profile']) {
        await txn.delete(table);
      }
    });
    await _appDb.setAppProfile(displayName: 'Người giao hàng', pinHash: null);
    await _appDb.setMeta(_keyOnboardingDone, 'true');
    await _appDb.logActivity(action: 'WIPE_RESET_FORGOT_PIN', entity: 'system', details: {'timestamp': AppDatabase.currentIsoUtc()});
  }

  Future<void> _clearLockoutState() async {
    final db = await _appDb.database;
    await db.delete('app_meta', where: 'key IN (?, ?)', whereArgs: [_keyFailedAttempts, _keyLockoutUntil]);
  }

  @override
  Future<UserModel?> login(String phoneNumber, String password) => getCurrentUser();
  @override
  Future<void> logout() async {}
  @override
  Future<List<Map<String, dynamic>>> getMyAreas() async => const [];
  @override
  Future<String?> getPreferredAreaId() async => null;
  @override
  Future<void> setPreferredAreaId(String areaId) async {}
  @override
  Future<void> clearPreferredAreaId() async {}
  @override
  Future<Map<String, dynamic>> changePassword({required String currentPassword, required String newPassword, String? confirmPassword}) =>
      throw UnsupportedError('Chế độ Local-First hoạt động không cần tài khoản máy chủ hay mật khẩu.');
  @override
  Future<String?> getSavedLoginPhone() async => null;
}
