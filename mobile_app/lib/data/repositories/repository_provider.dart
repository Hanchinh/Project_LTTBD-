import 'package:delivery_marker_mobile/data/repositories/customer_repository.dart';
import 'package:delivery_marker_mobile/data/repositories/location_repository.dart';
import 'package:delivery_marker_mobile/data/repositories/photo_repository.dart';
import 'package:delivery_marker_mobile/data/repositories/profile_repository.dart';
import 'package:delivery_marker_mobile/data/repositories/sharing_repository.dart';
import 'package:delivery_marker_mobile/data/repositories/shift_repository.dart';
import 'package:delivery_marker_mobile/data/local/local_customer_repository.dart';
import 'package:delivery_marker_mobile/data/local/local_location_repository.dart';
import 'package:delivery_marker_mobile/data/local/local_photo_repository.dart';
import 'package:delivery_marker_mobile/data/local/local_profile_repository.dart';
import 'package:delivery_marker_mobile/data/local/local_sharing_repository.dart';
import 'package:delivery_marker_mobile/data/local/local_shift_repository.dart';

/// Service locator & provider cho toàn bộ các Repository trong ứng dụng Local-First.
/// Mọi dữ liệu khách hàng, vị trí, ca làm việc, ảnh và hồ sơ được lưu trữ cục bộ qua SQLite.
/// Hỗ trợ override trong kiểm thử (Unit / Widget test) mà không ảnh hưởng UI.
class RepositoryProvider {
  static bool? _useLocalDataOverride;

  /// Cờ xác định trạng thái sử dụng kho dữ liệu cục bộ (mặc định luôn true trong bản Local-First).
  static bool get useLocalData => _useLocalDataOverride ?? true;

  static set useLocalData(bool value) {
    _useLocalDataOverride = value;
  }

  static CustomerRepository? _customerRepository;
  static LocationRepository? _locationRepository;
  static PhotoRepository? _photoRepository;
  static ShiftRepository? _shiftRepository;
  static SharingRepository? _sharingRepository;
  static ProfileRepository? _profileRepository;

  static CustomerRepository get customer =>
      _customerRepository ??= LocalCustomerRepository();

  static LocationRepository get location =>
      _locationRepository ??= LocalLocationRepository();

  static PhotoRepository get photo =>
      _photoRepository ??= LocalPhotoRepository();

  static ShiftRepository get shift =>
      _shiftRepository ??= LocalShiftRepository();

  static SharingRepository get sharing =>
      _sharingRepository ??= LocalSharingRepository();

  static LocalSharingRepository get localSharing {
    final s = sharing;
    if (s is LocalSharingRepository) return s;
    return LocalSharingRepository();
  }

  static ProfileRepository get profile =>
      _profileRepository ??= LocalProfileRepository();

  static LocalProfileRepository get localProfile {
    final p = profile;
    if (p is LocalProfileRepository) return p;
    return LocalProfileRepository();
  }

  /// Ghi đè (override) các repository khi chạy test
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
