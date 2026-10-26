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

/// Service locator & provider cho toàn bộ các Repository trong ứng dụng.
/// Mặc định: Trỏ về RemoteRepository (bọc ApiService kết nối backend hiện tại).
/// Kiến trúc Local-First: Cho phép thay thế bằng LocalRepository (SQLite OfflineStorageService)
/// hoặc ghi đè (override) trong kiểm thử widget test mà không làm xáo trộn UI.
class RepositoryProvider {
  static CustomerRepository? _customerRepository;
  static LocationRepository? _locationRepository;
  static PhotoRepository? _photoRepository;
  static ShiftRepository? _shiftRepository;
  static SharingRepository? _sharingRepository;
  static ProfileRepository? _profileRepository;

  static CustomerRepository get customer =>
      _customerRepository ??= RemoteCustomerRepository();

  static LocationRepository get location =>
      _locationRepository ??= RemoteLocationRepository();

  static PhotoRepository get photo =>
      _photoRepository ??= RemotePhotoRepository();

  static ShiftRepository get shift =>
      _shiftRepository ??= RemoteShiftRepository();

  static SharingRepository get sharing =>
      _sharingRepository ??= RemoteSharingRepository();

  static ProfileRepository get profile =>
      _profileRepository ??= RemoteProfileRepository();

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
    _customerRepository = null;
    _locationRepository = null;
    _photoRepository = null;
    _shiftRepository = null;
    _sharingRepository = null;
    _profileRepository = null;
  }
}
