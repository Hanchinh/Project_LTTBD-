import 'customer_repository.dart';
import 'location_repository.dart';
import 'photo_repository.dart';
import 'profile_repository.dart';
import 'sharing_repository.dart';
import 'shift_repository.dart';
import 'remote/remote_customer_repository.dart';
import 'remote/remote_location_repository.dart';
import 'remote/remote_photo_repository.dart';
import 'remote/remote_profile_repository.dart';
import 'remote/remote_sharing_repository.dart';
import 'remote/remote_shift_repository.dart';
import 'local/local_customer_repository.dart';
import 'local/local_location_repository.dart';
import 'local/local_photo_repository.dart';
import 'local/local_profile_repository.dart';
import 'local/local_shift_repository.dart';

/// Service locator & provider cho toàn bộ các Repository trong ứng dụng.
/// Mặc định nhánh local-first: useLocalData = true (Customer, Location, Shift, Photo & Profile đều Local SQLite).
/// Cho phép chuyển đổi `useLocalData = false` để chạy Remote như cũ khi có kết nối backend.
/// Hỗ trợ ghi đè (override) trong kiểm thử widget test mà không làm xáo trộn UI.
class RepositoryProvider {
  static const bool _compileTimeLocalData = bool.fromEnvironment('LOCAL_DATA', defaultValue: true);
  static bool? _useLocalDataOverride;

  /// Cờ xác định có đang sử dụng Local Repositories cho Customer, Location, Shift, Photo & Profile hay không
  /// Mặc định nhánh local-first: true.
  static bool get useLocalData => _useLocalDataOverride ?? _compileTimeLocalData;

  static set useLocalData(bool value) {
    _useLocalDataOverride = value;
    // Reset instance để tạo lại với loại repository tương ứng
    _customerRepository = null;
    _locationRepository = null;
    _photoRepository = null;
    _shiftRepository = null;
    _profileRepository = null;
  }

  static CustomerRepository? _customerRepository;
  static LocationRepository? _locationRepository;
  static PhotoRepository? _photoRepository;
  static ShiftRepository? _shiftRepository;
  static SharingRepository? _sharingRepository;
  static ProfileRepository? _profileRepository;

  static CustomerRepository get customer =>
      _customerRepository ??= (useLocalData ? LocalCustomerRepository() : RemoteCustomerRepository());

  static LocationRepository get location =>
      _locationRepository ??= (useLocalData ? LocalLocationRepository() : RemoteLocationRepository());

  static PhotoRepository get photo =>
      _photoRepository ??= (useLocalData ? LocalPhotoRepository() : RemotePhotoRepository());

  static ShiftRepository get shift =>
      _shiftRepository ??= (useLocalData ? LocalShiftRepository() : RemoteShiftRepository());

  static SharingRepository get sharing =>
      _sharingRepository ??= RemoteSharingRepository();

  static ProfileRepository get profile =>
      _profileRepository ??= (useLocalData ? LocalProfileRepository() : RemoteProfileRepository());

  static LocalProfileRepository get localProfile {
    final p = profile;
    if (p is LocalProfileRepository) return p;
    return LocalProfileRepository();
  }

  /// Ghi đè (override) các repository khi chạy test hoặc khi chuyển chế độ hoạt động
  static void overrideRepositories({
    CustomerRepository? customer,
    LocationRepository? location,
    PhotoRepository? photo,
    ShiftRepository? shift,
    SharingRepository? sharing,
    ProfileRepository? profile,
  }) {
    if (customer != null) _customerRepository = customer;
    if (location != null) _locationRepository = location;
    if (photo != null) _photoRepository = photo;
    if (shift != null) _shiftRepository = shift;
    if (sharing != null) _sharingRepository = sharing;
    if (profile != null) _profileRepository = profile;
  }

  /// Khôi phục trạng thái mặc định
  static void reset() {
    _useLocalDataOverride = null;
    _customerRepository = null;
    _locationRepository = null;
    _photoRepository = null;
    _shiftRepository = null;
    _sharingRepository = null;
    _profileRepository = null;
  }
}
