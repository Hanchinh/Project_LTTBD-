import 'package:delivery_marker_mobile/data/customers/customer_repository.dart';
import 'package:delivery_marker_mobile/data/locations/location_repository.dart';
import 'package:delivery_marker_mobile/data/photos/photo_repository.dart';
import 'package:delivery_marker_mobile/data/profile/profile_repository.dart';
import 'package:delivery_marker_mobile/data/sharing/sharing_repository.dart';
import 'package:delivery_marker_mobile/data/shifts/shift_repository.dart';

/// Quản lý truy cập toàn cục cho các kho lưu trữ dữ liệu (Repository Provider).
/// Toàn bộ dữ liệu khách hàng, vị trí, ca làm việc, ảnh và hồ sơ được lưu trữ cục bộ qua SQLite.
class RepositoryProvider {
  static bool? _useLocalDataOverride;

  /// Cờ trạng thái kho dữ liệu (mặc định luôn true trong bản Local-First).
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
      _locationRepository ??= LocationRepository();

  static PhotoRepository get photo =>
      _photoRepository ??= PhotoRepository();

  static ShiftRepository get shift =>
      _shiftRepository ??= LocalShiftRepository();

  static SharingRepository get sharing =>
      _sharingRepository ??= SharingRepository();

  static SharingRepository get localSharing => sharing;

  static ProfileRepository get profile =>
      _profileRepository ??= ProfileRepository();

  static ProfileRepository get localProfile => profile;

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

