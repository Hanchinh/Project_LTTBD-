import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:geolocator/geolocator.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sqflite/sqflite.dart';

import 'package:delivery_marker_mobile/core/utils/phone_utils.dart';
import 'package:delivery_marker_mobile/core/utils/share_crypto_utils.dart';
import 'package:delivery_marker_mobile/core/utils/uuid_utils.dart';
import 'package:delivery_marker_mobile/data/database/app_database.dart';
import 'package:delivery_marker_mobile/data/photos/photo_repository.dart';
import 'package:delivery_marker_mobile/models/local_share_models.dart';

part 'sharing_export_ops.dart';
part 'sharing_import_ops.dart';

/// Kho lưu trữ chia sẻ dữ liệu cục bộ (Local-First Peer-to-Peer Sharing).
/// Cho phép xuất/nhập điểm qua file .dshare và chuỗi mã QR nhiều mảnh hoàn toàn offline.
class SharingRepository {
  final AppDatabase _appDb;
  final PhotoRepository _photoRepo;
  final Directory? _customBaseDir;

  SharingRepository({
    AppDatabase? appDb,
    PhotoRepository? photoRepo,
    Directory? customBaseDir,
  })  : _appDb = appDb ?? AppDatabase.instance,
        _photoRepo = photoRepo ?? PhotoRepository(appDb: appDb ?? AppDatabase.instance, baseDirectory: customBaseDir),
        _customBaseDir = customBaseDir;

  static const int maxFileSizeBytes = 50 * 1024 * 1024; // 50MB
  static const int maxPointsAllowed = 2000;
  static const int maxPhotoSizeBytes = 5 * 1024 * 1024; // 5MB

  Future<Directory> _getTempDir() async {
    final base = _customBaseDir ?? await getTemporaryDirectory();
    final dir = Directory(p.join(base.path, 'dshare_temp'));
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    return dir;
  }

  /// Dọn dẹp các tệp .dshare và dữ liệu giải nén tạm
  Future<void> cleanupTempFiles() async {
    try {
      final tempDir = await _getTempDir();
      if (tempDir.existsSync()) {
        final entries = tempDir.listSync();
        for (final entity in entries) {
          try {
            entity.deleteSync(recursive: true);
          } catch (_) {}
        }
      }
    } catch (_) {}
  }

  /// Lấy tên hiển thị của người gửi từ app_profile
  Future<String> _getSenderDisplayName() async {
    final profile = await _appDb.getAppProfile();
    final name = profile?['display_name'] as String?;
    if (name != null && name.trim().isNotEmpty) {
      return name.trim();
    }
    return 'Shipper';
  }

  // ===========================================================================
  // 1. XUẤT GÓI CHIA SẺ (.dshare / QR)
  // ===========================================================================

  /// Thu thập danh sách điểm cần xuất theo phạm vi
  Future<List<SharedPointPayload>> collectPointsForExport({
    required String scope,
    String? shiftId,
    List<String>? customerIds,
    bool includeCustomerInfo = true,
    bool includePhotos = false,
  }) =>
      _collectPointsForExport(
        scope: scope,
        shiftId: shiftId,
        customerIds: customerIds,
        includeCustomerInfo: includeCustomerInfo,
        includePhotos: includePhotos,
      );

  /// Tạo tệp gói chia sẻ (.dshare)
  Future<File> exportSharePackage({
    required String scope,
    String? shiftId,
    List<String>? customerIds,
    bool includeCustomerInfo = true,
    bool includePhotos = false,
    String? password,
  }) =>
      _exportSharePackage(
        scope: scope,
        shiftId: shiftId,
        customerIds: customerIds,
        includeCustomerInfo: includeCustomerInfo,
        includePhotos: includePhotos,
        password: password,
      );

  /// Chia sẻ tệp qua Share Sheet hệ thống (Zalo, Drive, Files,...)
  Future<void> sharePackageFile(File file) => _sharePackageFile(file);

  /// Tạo các mảnh mã QR cho gói chia sẻ (không kèm ảnh)
  Future<List<String>> exportQrChunks({
    required String scope,
    String? shiftId,
    List<String>? customerIds,
    bool includeCustomerInfo = true,
    String? password,
  }) =>
      _exportQrChunks(
        scope: scope,
        shiftId: shiftId,
        customerIds: customerIds,
        includeCustomerInfo: includeCustomerInfo,
        password: password,
      );

  // ===========================================================================
  // 2. KIỂM TRA & XEM TRƯỚC GÓI CHIA SẺ (INSPECT & PREVIEW)
  // ===========================================================================

  /// Đọc và kiểm tra tính toàn vẹn của tệp .dshare trước khi cho phép nhập
  Future<SharePackagePreview> inspectPackageFile(File file, {String? password}) =>
      _inspectPackageFile(file, password: password);

  /// Đọc và kiểm tra chuỗi dữ liệu nhận được từ mã QR
  Future<SharePackagePreview> inspectQrPayload(String rawPayload, {String? password}) =>
      _inspectQrPayload(rawPayload, password: password);

  // ===========================================================================
  // 3. THỰC HIỆN NHẬP DỮ LIỆU
  // ===========================================================================

  /// Thực hiện nhập dữ liệu từ Preview trong một Transaction duy nhất
  Future<ShareImportResult> importPackage({
    required SharePackagePreview preview,
    required ShareImportMode mode,
    required Set<int> selectedIndexes,
    bool createShift = false,
    String? shiftName,
  }) =>
      _importPackage(
        preview: preview,
        mode: mode,
        selectedIndexes: selectedIndexes,
        createShift: createShift,
        shiftName: shiftName,
      );

  // ===========================================================================
  // 4. TƯƠNG THÍCH NỘI BỘ
  // ===========================================================================

  Future<Map<String, dynamic>> getSharedLocations() async => {};

  Future<Map<String, dynamic>> importSharedLocations(
    String shareId, {
    List<String>? customerIds,
    bool all = true,
    bool replaceExisting = false,
  }) async =>
      {};
}

/// Giữ bí danh LocalSharingRepository cho tương thích ngược
typedef LocalSharingRepository = SharingRepository;

