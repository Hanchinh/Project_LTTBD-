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

import 'package:delivery_marker_mobile/data/local/app_database.dart';
import 'package:delivery_marker_mobile/models/data_share_model.dart';
import 'package:delivery_marker_mobile/models/local_share_models.dart';
import 'package:delivery_marker_mobile/core/utils/phone_utils.dart';
import 'package:delivery_marker_mobile/core/utils/share_crypto_utils.dart';
import 'package:delivery_marker_mobile/core/utils/uuid_utils.dart';
import 'package:delivery_marker_mobile/data/repositories/sharing_repository.dart';
import 'package:delivery_marker_mobile/data/local/local_photo_repository.dart';

/// Triển khai SharingRepository cục bộ (Local-First Peer-to-Peer Sharing)
/// Cho phép xuất/nhập điểm qua file .dshare và chuỗi mã QR nhiều mảnh.
/// Toàn quyền chạy offline, không gửi dữ liệu lên máy chủ ngoài.
class LocalSharingRepository implements SharingRepository {
  final AppDatabase _appDb;
  final LocalPhotoRepository _photoRepo;
  final Directory? _customBaseDir;

  LocalSharingRepository({
    AppDatabase? appDb,
    LocalPhotoRepository? photoRepo,
    Directory? customBaseDir,
  })  : _appDb = appDb ?? AppDatabase.instance,
        _photoRepo = photoRepo ?? LocalPhotoRepository(appDb: appDb ?? AppDatabase.instance, baseDirectory: customBaseDir),
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
  // 1. XUẤT GÓI CHIA SẺ (.dshare)
  // ===========================================================================

  /// Thu thập danh sách điểm cần xuất theo phạm vi
  Future<List<SharedPointPayload>> collectPointsForExport({
    required String scope, // 'all', 'shift', 'selected'
    String? shiftId,
    List<String>? customerIds,
    bool includeCustomerInfo = true,
    bool includePhotos = false,
  }) async {
    final db = await _appDb.database;
    final senderName = await _getSenderDisplayName();
    final nowIso = AppDatabase.currentIsoUtc();

    List<Map<String, dynamic>> rawRows = [];

    if (scope == 'all') {
      rawRows = await db.rawQuery('''
        SELECT c.id AS customer_id, c.customer_code, c.full_name, c.phone_number, c.address_text,
               sl.latitude, sl.longitude, sl.gps_accuracy, sl.identification_notes, sl.updated_at
        FROM customers c
        JOIN saved_locations sl ON c.id = sl.customer_id
        WHERE c.deleted_at IS NULL
        ORDER BY sl.updated_at DESC
      ''');
    } else if (scope == 'shift' && shiftId != null) {
      rawRows = await db.rawQuery('''
        SELECT c.id AS customer_id, c.customer_code, c.full_name, c.phone_number, c.address_text,
               sdp.latitude, sdp.longitude, sdp.gps_accuracy, sdp.identification_notes, sdp.updated_at
        FROM shift_delivery_points sdp
        JOIN customers c ON sdp.customer_id = c.id
        WHERE sdp.shift_id = ? 
          AND c.deleted_at IS NULL 
          AND sdp.latitude IS NOT NULL 
          AND sdp.longitude IS NOT NULL
        ORDER BY sdp.delivery_order_index ASC
      ''', [shiftId]);
    } else if (scope == 'selected' && customerIds != null && customerIds.isNotEmpty) {
      final placeholders = List.filled(customerIds.length, '?').join(',');
      rawRows = await db.rawQuery('''
        SELECT c.id AS customer_id, c.customer_code, c.full_name, c.phone_number, c.address_text,
               sl.latitude, sl.longitude, sl.gps_accuracy, sl.identification_notes, sl.updated_at
        FROM customers c
        JOIN saved_locations sl ON c.id = sl.customer_id
        WHERE c.deleted_at IS NULL AND c.id IN ($placeholders)
        ORDER BY sl.updated_at DESC
      ''', customerIds);
    }

    final List<SharedPointPayload> points = [];

    for (final r in rawRows) {
      final custId = r['customer_id'] as String;
      final rawPhone = r['phone_number'] as String? ?? '';
      final normPhone = normalizeCustomerPhone(rawPhone);

      final lat = (r['latitude'] as num?)?.toDouble() ?? 0.0;
      final lng = (r['longitude'] as num?)?.toDouble() ?? 0.0;

      // Lấy danh sách ảnh nếu được yêu cầu
      List<String> photoFiles = [];
      if (includePhotos) {
        final photoRows = await db.query(
          'customer_photos',
          columns: ['file_name'],
          where: 'customer_id = ? AND deleted_at IS NULL',
          whereArgs: [custId],
          limit: 10,
          orderBy: 'created_at DESC',
        );
        photoFiles = photoRows.map((p) => p['file_name'] as String).toList();
      }

      points.add(SharedPointPayload(
        phoneNumber: normPhone,
        fullName: includeCustomerInfo ? (r['full_name'] as String?) : null,
        addressText: includeCustomerInfo ? (r['address_text'] as String?) : null,
        latitude: lat,
        longitude: lng,
        gpsAccuracy: (r['gps_accuracy'] as num?)?.toDouble(),
        identificationNotes: r['identification_notes'] as String?,
        photoFileNames: photoFiles,
        senderName: senderName,
        timestamp: r['updated_at']?.toString() ?? nowIso,
      ));
    }

    return points;
  }

  /// Tạo tệp gói chia sẻ (.dshare)
  Future<File> exportSharePackage({
    required String scope,
    String? shiftId,
    List<String>? customerIds,
    bool includeCustomerInfo = true,
    bool includePhotos = false,
    String? password,
  }) async {
    final points = await collectPointsForExport(
      scope: scope,
      shiftId: shiftId,
      customerIds: customerIds,
      includeCustomerInfo: includeCustomerInfo,
      includePhotos: includePhotos,
    );

    if (points.isEmpty) {
      throw StateError('Không có điểm nào để tạo gói chia sẻ');
    }

    if (points.length > maxPointsAllowed) {
      throw StateError('Số lượng điểm vượt quá giới hạn tối đa ($maxPointsAllowed điểm)');
    }

    final tempDir = await _getTempDir();
    final photosDir = await _photoRepo.getPhotosDirectory();
    final archive = Archive();
    final Map<String, String> checksums = {};

    // 1. Chuẩn bị ảnh
    final List<Map<String, dynamic>> photoEntries = [];
    if (includePhotos && photosDir.existsSync()) {
      final Set<String> neededPhotos = {};
      for (final p in points) {
        neededPhotos.addAll(p.photoFileNames);
      }

      for (final fileName in neededPhotos) {
        final f = File(p.join(photosDir.path, fileName));
        if (f.existsSync()) {
          final bytes = await f.readAsBytes();
          final hash = sha256.convert(bytes).toString();
          final zipPath = 'photos/$fileName';
          checksums[zipPath] = hash;
          photoEntries.add({'zipPath': zipPath, 'bytes': bytes});
        }
      }
    }

    // 2. Chuẩn bị points.json và mã hóa nếu có mật khẩu
    final pointsJsonText = jsonEncode(points.map((pt) => pt.toJson()).toList());
    final pointsRawBytes = Uint8List.fromList(utf8.encode(pointsJsonText));

    bool isEncrypted = false;
    String? salt;
    String? iv;

    if (password != null && password.trim().isNotEmpty) {
      isEncrypted = true;
      final encResult = ShareCryptoUtils.encryptBytes(pointsRawBytes, password.trim());
      final cipherBytes = encResult['cipher'] as Uint8List;
      salt = encResult['salt'] as String;
      iv = encResult['iv'] as String;

      final pointsHash = sha256.convert(cipherBytes).toString();
      checksums['points.enc'] = pointsHash;
      archive.addFile(ArchiveFile('points.enc', cipherBytes.length, cipherBytes));
    } else {
      final pointsHash = sha256.convert(pointsRawBytes).toString();
      checksums['points.json'] = pointsHash;
      archive.addFile(ArchiveFile('points.json', pointsRawBytes.length, pointsRawBytes));
    }

    // 3. Thêm ảnh vào archive
    for (final pe in photoEntries) {
      final b = pe['bytes'] as Uint8List;
      archive.addFile(ArchiveFile(pe['zipPath'] as String, b.length, b));
    }

    // 4. Tạo manifest.json
    final nowUtc = DateTime.now().toUtc();
    final senderName = await _getSenderDisplayName();
    final manifest = SharePackageManifest(
      formatVersion: 1,
      type: 'dshare',
      appVersion: '1.0.0+1',
      schemaVersion: AppDatabase.currentVersion,
      createdAt: nowUtc.toIso8601String(),
      senderDisplayName: senderName,
      pointsCount: points.length,
      photosCount: photoEntries.length,
      isEncrypted: isEncrypted,
      salt: salt,
      iv: iv,
      checksums: checksums,
    );

    final manifestBytes = utf8.encode(jsonEncode(manifest.toJson()));
    archive.addFile(ArchiveFile('manifest.json', manifestBytes.length, manifestBytes));

    // 5. Đóng gói ZIP
    final zipBytes = ZipEncoder().encode(archive);

    // 6. Đặt tên tệp delivery-share-YYYYMMDD-HHmm.dshare (Giờ VN UTC+7)
    final vnTime = nowUtc.add(const Duration(hours: 7));
    final year = vnTime.year.toString().padLeft(4, '0');
    final month = vnTime.month.toString().padLeft(2, '0');
    final day = vnTime.day.toString().padLeft(2, '0');
    final hour = vnTime.hour.toString().padLeft(2, '0');
    final minute = vnTime.minute.toString().padLeft(2, '0');
    final fileName = 'delivery-share-$year$month$day-$hour$minute.dshare';

    final targetFile = File(p.join(tempDir.path, fileName));
    await targetFile.writeAsBytes(zipBytes, flush: true);

    // 7. Ghi activity_log (không chứa SĐT hay tên khách)
    await _appDb.logActivity(
      action: 'EXPORT_SHARE_PACKAGE',
      entity: 'sharing',
      details: {
        'fileName': fileName,
        'scope': scope,
        'pointsCount': points.length,
        'photosCount': photoEntries.length,
        'hasPassword': isEncrypted,
        'fileSizeBytes': targetFile.lengthSync(),
      },
    );

    return targetFile;
  }

  /// Chia sẻ tệp qua Share Sheet hệ thống (Zalo, Drive, Files,...)
  Future<void> sharePackageFile(File file) async {
    if (!file.existsSync()) {
      throw StateError('Tệp chia sẻ không tồn tại');
    }
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        subject: 'Chia sẻ điểm giao hàng (.dshare)',
        text: 'Gói dữ liệu điểm giao hàng (${p.basename(file.path)})',
      ),
    );
  }

  // ===========================================================================
  // 2. XUẤT MÃ QR (GZIP + BASE64URL, CHIA MẢNH)
  // ===========================================================================

  /// Tạo các mảnh mã QR cho gói chia sẻ (không kèm ảnh)
  Future<List<String>> exportQrChunks({
    required String scope,
    String? shiftId,
    List<String>? customerIds,
    bool includeCustomerInfo = true,
    String? password,
  }) async {
    final points = await collectPointsForExport(
      scope: scope,
      shiftId: shiftId,
      customerIds: customerIds,
      includeCustomerInfo: includeCustomerInfo,
      includePhotos: false, // QR không bao giờ kèm ảnh
    );

    if (points.isEmpty) {
      throw StateError('Không có điểm nào để tạo mã QR');
    }

    if (points.length > maxPointsAllowed) {
      throw StateError('Số lượng điểm vượt quá giới hạn tối đa ($maxPointsAllowed điểm)');
    }

    final senderName = await _getSenderDisplayName();
    final nowUtc = DateTime.now().toUtc();

    String pointsPayloadString;

    if (password != null && password.trim().isNotEmpty) {
      final rawJson = jsonEncode(points.map((pt) => pt.toJson()).toList());
      final encResult = ShareCryptoUtils.encryptBytes(Uint8List.fromList(utf8.encode(rawJson)), password.trim());
      final envelope = {
        'enc': true,
        'sender': senderName,
        'ts': nowUtc.toIso8601String(),
        'salt': encResult['salt'],
        'iv': encResult['iv'],
        'data': base64.encode(encResult['cipher'] as Uint8List),
      };
      pointsPayloadString = jsonEncode(envelope);
    } else {
      final envelope = {
        'enc': false,
        'sender': senderName,
        'ts': nowUtc.toIso8601String(),
        'points': points.map((pt) => pt.toJson()).toList(),
      };
      pointsPayloadString = jsonEncode(envelope);
    }

    final chunks = ShareCryptoUtils.createQrChunks(pointsPayloadString, maxChunkChars: 1200);

    await _appDb.logActivity(
      action: 'EXPORT_SHARE_QR',
      entity: 'sharing',
      details: {
        'scope': scope,
        'pointsCount': points.length,
        'chunksCount': chunks.length,
        'hasPassword': password != null && password.trim().isNotEmpty,
      },
    );

    return chunks;
  }

  // ===========================================================================
  // 3. KIỂM TRA & XEM TRƯỚC GÓI CHIA SẺ (INSPECT & PREVIEW)
  // ===========================================================================

  /// Đọc và kiểm tra tính toàn vẹn của tệp .dshare trước khi cho phép nhập
  Future<SharePackagePreview> inspectPackageFile(File file, {String? password}) async {
    if (!file.existsSync()) {
      throw ArgumentError('Tệp chia sẻ không tồn tại: ${file.path}');
    }

    // 1. Kiểm tra kích thước tối đa 50MB
    final fileSize = file.lengthSync();
    if (fileSize > maxFileSizeBytes) {
      throw const FormatException('Gói chia sẻ vượt quá dung lượng cho phép (tối đa 50MB)');
    }

    final bytes = await file.readAsBytes();
    Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes);
    } catch (e) {
      throw const FormatException('Tệp không đúng định dạng zip/dshare hoặc đã bị hỏng');
    }

    // 2. Chống Path Traversal (../, .., /, :)
    for (final f in archive) {
      final name = f.name.replaceAll('\\', '/');
      if (name.contains('../') || name.contains('..') || name.startsWith('/') || name.contains(':')) {
        throw const FormatException('Phát hiện đường dẫn bất thường (Path Traversal) trong gói chia sẻ');
      }
    }

    // 3. Tìm manifest.json
    final manifestFile = archive.findFile('manifest.json');
    if (manifestFile == null) {
      throw const FormatException('Gói chia sẻ không hợp lệ: Thiếu tệp manifest.json');
    }

    SharePackageManifest manifest;
    try {
      final manifestJson = jsonDecode(utf8.decode(manifestFile.content as List<int>)) as Map<String, dynamic>;
      manifest = SharePackageManifest.fromJson(manifestJson);
    } catch (e) {
      throw FormatException('Tệp manifest.json không hợp lệ: $e');
    }

    // 4. Kiểm tra phiên bản schema
    if (manifest.schemaVersion > AppDatabase.currentVersion) {
      throw FormatException(
        'Gói chia sẻ từ phiên bản ứng dụng mới hơn (v${manifest.schemaVersion} > v${AppDatabase.currentVersion}). Vui lòng cập nhật ứng dụng trước khi nhận.',
      );
    }

    // 5. Kiểm tra giới hạn số điểm
    if (manifest.pointsCount > maxPointsAllowed) {
      throw const FormatException('Gói chia sẻ chứa quá nhiều điểm (tối đa 2000 điểm)');
    }

    // 6. Kiểm tra checksum các file trong zip
    for (final entry in manifest.checksums.entries) {
      final zipEntryName = entry.key;
      final expectedHash = entry.value;
      final entryFile = archive.findFile(zipEntryName);
      if (entryFile == null) {
        throw FormatException('Gói chia sẻ thiếu tệp dữ liệu đã khai báo: $zipEntryName');
      }
      final entryBytes = entryFile.content as List<int>;
      final actualHash = sha256.convert(entryBytes).toString();
      if (actualHash != expectedHash) {
        throw FormatException('Tệp $zipEntryName không khớp mã kiểm tra SHA-256 (có thể bị sửa đổi hoặc hỏng)');
      }
    }

    // 7. Giải mã và đọc danh sách points
    List<SharedPointPayload> points = [];

    if (manifest.isEncrypted) {
      if (password == null || password.trim().isEmpty) {
        throw const FormatException('GÓI_YÊU_CẦU_MẬT_KHẨU');
      }
      final encFile = archive.findFile('points.enc');
      if (encFile == null) {
        throw const FormatException('Thiếu tệp dữ liệu mã hóa points.enc');
      }
      final cipherBytes = Uint8List.fromList(encFile.content as List<int>);
      final decryptedBytes = ShareCryptoUtils.decryptBytes(
        cipherBytes: cipherBytes,
        password: password.trim(),
        saltHex: manifest.salt ?? '',
        ivHex: manifest.iv ?? '',
      );
      final pointsJson = jsonDecode(utf8.decode(decryptedBytes)) as List<dynamic>;
      points = pointsJson.map((e) => SharedPointPayload.fromJson(e as Map<String, dynamic>)).toList();
    } else {
      final pointsFile = archive.findFile('points.json');
      if (pointsFile == null) {
        throw const FormatException('Thiếu tệp dữ liệu points.json');
      }
      final pointsJson = jsonDecode(utf8.decode(pointsFile.content as List<int>)) as List<dynamic>;
      points = pointsJson.map((e) => SharedPointPayload.fromJson(e as Map<String, dynamic>)).toList();
    }

    if (points.length > maxPointsAllowed) {
      throw const FormatException('Gói chia sẻ chứa quá nhiều điểm (tối đa 2000 điểm)');
    }

    // 8. Thu thập các ảnh đính kèm
    final Map<String, Uint8List> photos = {};
    for (final f in archive) {
      if (f.name.startsWith('photos/') && !f.isDirectory) {
        final relName = f.name.substring('photos/'.length);
        photos[relName] = Uint8List.fromList(f.content as List<int>);
      }
    }

    // 9. Phân loại từng điểm so với CSDL hiện tại
    final classified = await _classifyPoints(points);

    return SharePackagePreview(
      manifest: manifest,
      classifiedPoints: classified,
      photos: photos,
      filePath: file.path,
      isFromQr: false,
    );
  }

  /// Đọc và kiểm tra chuỗi dữ liệu nhận được từ mã QR
  Future<SharePackagePreview> inspectQrPayload(String rawPayload, {String? password}) async {
    final cleanPayload = rawPayload.trim();
    final jsonMap = jsonDecode(cleanPayload) as Map<String, dynamic>;

    final isEnc = jsonMap['enc'] == true;
    final senderName = jsonMap['sender']?.toString() ?? 'Shipper';
    final ts = jsonMap['ts']?.toString() ?? DateTime.now().toUtc().toIso8601String();

    List<SharedPointPayload> points = [];

    if (isEnc) {
      if (password == null || password.trim().isEmpty) {
        throw const FormatException('GÓI_YÊU_CẦU_MẬT_KHẨU');
      }
      final cipherBytes = base64.decode(jsonMap['data'] as String);
      final salt = jsonMap['salt'] as String;
      final iv = jsonMap['iv'] as String;

      final decryptedBytes = ShareCryptoUtils.decryptBytes(
        cipherBytes: Uint8List.fromList(cipherBytes),
        password: password.trim(),
        saltHex: salt,
        ivHex: iv,
      );
      final rawPointsList = jsonDecode(utf8.decode(decryptedBytes)) as List<dynamic>;
      points = rawPointsList.map((e) => SharedPointPayload.fromJson(e as Map<String, dynamic>)).toList();
    } else {
      final rawPointsList = jsonMap['points'] as List<dynamic>? ?? [];
      points = rawPointsList.map((e) => SharedPointPayload.fromJson(e as Map<String, dynamic>)).toList();
    }

    if (points.length > maxPointsAllowed) {
      throw const FormatException('Gói chia sẻ chứa quá nhiều điểm (tối đa 2000 điểm)');
    }

    final manifest = SharePackageManifest(
      formatVersion: 1,
      type: 'dshare-qr',
      appVersion: '1.0.0+1',
      schemaVersion: AppDatabase.currentVersion,
      createdAt: ts,
      senderDisplayName: senderName,
      pointsCount: points.length,
      photosCount: 0,
      isEncrypted: isEnc,
      checksums: {},
    );

    final classified = await _classifyPoints(points);

    return SharePackagePreview(
      manifest: manifest,
      classifiedPoints: classified,
      photos: const {},
      isFromQr: true,
    );
  }

  /// Phân loại danh sách điểm so với CSDL máy nhận
  Future<List<ClassifiedSharePoint>> _classifyPoints(List<SharedPointPayload> points) async {
    final db = await _appDb.database;
    final List<ClassifiedSharePoint> classified = [];

    for (final pt in points) {
      // 1. Kiểm tra tính hợp lệ của tọa độ
      if (pt.latitude < -90.0 || pt.latitude > 90.0) {
        classified.add(ClassifiedSharePoint(
          point: pt,
          classification: SharePointClassification.invalid,
          invalidReason: 'Tọa độ vĩ độ ngoài phạm vi [-90, 90]',
          isSelected: false,
        ));
        continue;
      }

      if (pt.longitude < -180.0 || pt.longitude > 180.0) {
        classified.add(ClassifiedSharePoint(
          point: pt,
          classification: SharePointClassification.invalid,
          invalidReason: 'Tọa độ kinh độ ngoài phạm vi [-180, 180]',
          isSelected: false,
        ));
        continue;
      }

      // 2. Chuẩn hóa và kiểm tra SĐT
      final normPhone = normalizeCustomerPhone(pt.phoneNumber);
      if (!isValidVnPhone(normPhone)) {
        classified.add(ClassifiedSharePoint(
          point: pt,
          classification: SharePointClassification.invalid,
          invalidReason: 'Số điện thoại không hợp lệ (${pt.phoneNumber})',
          isSelected: false,
        ));
        continue;
      }

      // 3. Tra cứu khách hàng theo SĐT trong CSDL
      final custRows = await db.query(
        'customers',
        where: 'phone_number = ? AND deleted_at IS NULL',
        whereArgs: [normPhone],
        limit: 1,
      );

      if (custRows.isEmpty) {
        // Chưa có trong hệ thống -> Khách hàng MỚI
        classified.add(ClassifiedSharePoint(
          point: pt,
          classification: SharePointClassification.newCustomer,
          isSelected: true,
        ));
        continue;
      }

      final existingCust = custRows.first;
      final existingCustId = existingCust['id'] as String;
      final existingName = existingCust['full_name'] as String?;
      final existingAddress = existingCust['address_text'] as String?;

      // 4. Tra cứu vị trí đã lưu của khách
      final locRows = await db.query(
        'saved_locations',
        where: 'customer_id = ?',
        whereArgs: [existingCustId],
        limit: 1,
      );

      if (locRows.isEmpty) {
        // Trùng SĐT nhưng chưa có vị trí
        classified.add(ClassifiedSharePoint(
          point: pt,
          classification: SharePointClassification.existingWithoutLocation,
          existingCustomerId: existingCustId,
          existingCustomerName: existingName,
          existingAddress: existingAddress,
          isSelected: true,
        ));
      } else {
        // Trùng SĐT và đã có vị trí -> tính khoảng cách
        final loc = locRows.first;
        final existingLat = (loc['latitude'] as num).toDouble();
        final existingLng = (loc['longitude'] as num).toDouble();

        final distMeters = Geolocator.distanceBetween(
          existingLat,
          existingLng,
          pt.latitude,
          pt.longitude,
        );

        classified.add(ClassifiedSharePoint(
          point: pt,
          classification: SharePointClassification.existingWithLocation,
          existingCustomerId: existingCustId,
          existingCustomerName: existingName,
          existingAddress: existingAddress,
          existingLatitude: existingLat,
          existingLongitude: existingLng,
          distanceMeters: distMeters,
          isSelected: true,
        ));
      }
    }

    return classified;
  }

  // ===========================================================================
  // 4. NHẬP GÓI CHIA SẺ VÀO CƠ SỞ DỮ LIỆU
  // ===========================================================================

  /// Kiểm tra magic bytes của ảnh (JPEG, PNG, WEBP)
  bool _isValidImageBytes(Uint8List bytes) {
    if (bytes.length < 8) return false;
    // JPEG: FF D8 FF
    if (bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) return true;
    // PNG: 89 50 4E 47
    if (bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47) return true;
    // WEBP: 52 49 46 46 (RIFF) ... 57 45 42 50 (WEBP)
    if (bytes[0] == 0x52 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x46) return true;
    return false;
  }

  /// Thực hiện nhập dữ liệu từ Preview trong một Transaction duy nhất
  Future<ShareImportResult> importPackage({
    required SharePackagePreview preview,
    required ShareImportMode mode,
    required Set<int> selectedIndexes,
    bool createShift = false,
    String? shiftName,
  }) async {
    final db = await _appDb.database;
    final nowIso = AppDatabase.currentIsoUtc();
    final nowUtc = DateTime.now().toUtc();
    final vnTime = nowUtc.add(const Duration(hours: 7));
    final nowVnDayMonth = '${vnTime.day.toString().padLeft(2, '0')}/${vnTime.month.toString().padLeft(2, '0')}';
    final workDate = nowIso.split('T').first;

    final photosDir = await _photoRepo.getPhotosDirectory();
    final thumbsDir = await _photoRepo.getThumbsDirectory();
    final List<File> writtenFiles = [];

    int addedCount = 0;
    int replacedCount = 0;
    int skippedCount = 0;
    int errorCount = 0;
    int photosAdded = 0;
    int photosSkipped = 0;
    String? createdShiftId;
    String? finalShiftName;

    try {
      await db.transaction((txn) async {
        // 1. Tạo ca mới nếu được chọn
        int deliveryOrderIndex = 1;
        if (createShift) {
          createdShiftId = UuidUtils.generate();
          finalShiftName = shiftName ?? 'Từ ${preview.manifest.senderDisplayName} $nowVnDayMonth';

          final shiftCode = 'SHIFT-${DateTime.now().millisecondsSinceEpoch % 10000}';
          await txn.insert('shifts', {
            'id': createdShiftId,
            'shift_code': shiftCode,
            'shift_name': finalShiftName,
            'work_date': workDate,
            'status': 'PREPARING',
            'created_at': nowIso,
            'updated_at': nowIso,
          });
        }

        // 2. Lặp qua từng điểm được chọn
        for (int i = 0; i < preview.classifiedPoints.length; i++) {
          if (!selectedIndexes.contains(i)) continue;

          final item = preview.classifiedPoints[i];
          if (item.classification == SharePointClassification.invalid) {
            errorCount++;
            continue;
          }

          final pt = item.point;
          final normPhone = normalizeCustomerPhone(pt.phoneNumber);

          String customerId;
          bool shouldAddPhotos = false;

          if (item.classification == SharePointClassification.newCustomer) {
            // A. Khách hàng mới: tạo khách và tạo vị trí đã lưu
            customerId = UuidUtils.generate();
            final customerCode = 'CUST-${normPhone.substring(normPhone.length > 4 ? normPhone.length - 4 : 0)}';

            await txn.insert('customers', {
              'id': customerId,
              'customer_code': customerCode,
              'full_name': pt.fullName ?? 'Khách hàng',
              'phone_number': normPhone,
              'address_text': pt.addressText ?? '',
              'search_text': '${pt.fullName ?? ''} $normPhone ${pt.addressText ?? ''}'.toLowerCase(),
              'created_at': nowIso,
              'updated_at': nowIso,
            });

            await txn.insert('saved_locations', {
              'id': UuidUtils.generate(),
              'customer_id': customerId,
              'latitude': pt.latitude,
              'longitude': pt.longitude,
              'gps_accuracy': pt.gpsAccuracy,
              'identification_notes': pt.identificationNotes,
              'created_at': nowIso,
              'updated_at': nowIso,
            });

            addedCount++;
            shouldAddPhotos = true;
          } else if (item.classification == SharePointClassification.existingWithoutLocation) {
            // B. Khách trùng SĐT chưa có vị trí: thêm vị trí
            customerId = item.existingCustomerId!;

            await txn.insert('saved_locations', {
              'id': UuidUtils.generate(),
              'customer_id': customerId,
              'latitude': pt.latitude,
              'longitude': pt.longitude,
              'gps_accuracy': pt.gpsAccuracy,
              'identification_notes': pt.identificationNotes,
              'created_at': nowIso,
              'updated_at': nowIso,
            });

            addedCount++;
            shouldAddPhotos = true;
          } else {
            // C. Khách trùng SĐT đã có vị trí
            customerId = item.existingCustomerId!;

            if (mode == ShareImportMode.replaceExisting) {
              // Thay thế vị trí: trigger trg_saved_locations_history sẽ tự động lưu vị trí cũ vào location_history
              await txn.update(
                'saved_locations',
                {
                  'latitude': pt.latitude,
                  'longitude': pt.longitude,
                  'gps_accuracy': pt.gpsAccuracy,
                  'identification_notes': pt.identificationNotes,
                  'updated_at': nowIso,
                },
                where: 'customer_id = ?',
                whereArgs: [customerId],
              );

              replacedCount++;
              shouldAddPhotos = true;
            } else {
              // Bỏ qua điểm trùng
              skippedCount++;
              shouldAddPhotos = false;
            }
          }

          // Thêm điểm vào ca mới (nếu có yêu cầu tạo ca)
          if (createShift && createdShiftId != null) {
            await txn.insert('shift_delivery_points', {
              'id': UuidUtils.generate(),
              'shift_id': createdShiftId,
              'customer_id': customerId,
              'delivery_order_index': deliveryOrderIndex++,
              'location_status': 'VERIFIED',
              'latitude': pt.latitude,
              'longitude': pt.longitude,
              'gps_accuracy': pt.gpsAccuracy,
              'identification_notes': pt.identificationNotes,
              'created_at': nowIso,
              'updated_at': nowIso,
            });
          }

          // Xử lý ảnh đính kèm của điểm
          if (shouldAddPhotos && pt.photoFileNames.isNotEmpty && preview.photos.isNotEmpty) {
            // Đếm số ảnh hiện tại của khách hàng
            final countRows = await txn.rawQuery(
              'SELECT COUNT(*) AS total FROM customer_photos WHERE customer_id = ? AND deleted_at IS NULL',
              [customerId],
            );
            int currentPhotoCount = Sqflite.firstIntValue(countRows) ?? 0;

            for (final photoName in pt.photoFileNames) {
              final photoBytes = preview.photos[photoName];
              if (photoBytes == null) continue;

              // 1. Kiểm tra dung lượng <= 5MB
              if (photoBytes.lengthInBytes > maxPhotoSizeBytes) {
                photosSkipped++;
                continue;
              }

              // 2. Kiểm tra magic bytes
              if (!_isValidImageBytes(photoBytes)) {
                photosSkipped++;
                continue;
              }

              // 3. Giới hạn tối đa 10 ảnh/khách
              if (currentPhotoCount >= 10) {
                photosSkipped++;
                continue;
              }

              // 4. Lưu ảnh và thumbnail vào đĩa
              final photoId = UuidUtils.generate();
              final targetFileName = '$customerId-$photoId.jpg';
              final fullFile = File(p.join(photosDir.path, targetFileName));
              final thumbFile = File(p.join(thumbsDir.path, targetFileName));

              await fullFile.writeAsBytes(photoBytes, flush: true);
              writtenFiles.add(fullFile);

              await thumbFile.writeAsBytes(photoBytes, flush: true);
              writtenFiles.add(thumbFile);

              // 5. Ghi CSDL
              await txn.insert('customer_photos', {
                'id': photoId,
                'customer_id': customerId,
                'file_name': targetFileName,
                'thumb_file_name': targetFileName,
                'created_at': nowIso,
                'deleted_at': null,
              });

              photosAdded++;
              currentPhotoCount++;
            }
          }
        }
      });
    } catch (e) {
      // Nếu có lỗi giữa chừng, rollback dọn dẹp các file ảnh vừa ghi ra đĩa
      for (final f in writtenFiles) {
        try {
          if (f.existsSync()) f.deleteSync();
        } catch (_) {}
      }
      rethrow;
    }

    // Ghi activity_log tổng hợp (không chứa PII)
    await _appDb.logActivity(
      action: 'IMPORT_SHARED_DATA',
      entity: 'sharing',
      details: {
        'addedCount': addedCount,
        'replacedCount': replacedCount,
        'skippedCount': skippedCount,
        'errorCount': errorCount,
        'photosAdded': photosAdded,
        'photosSkipped': photosSkipped,
        'createdShift': createShift,
        'mode': mode.toString(),
      },
    );

    return ShareImportResult(
      addedCount: addedCount,
      replacedCount: replacedCount,
      skippedCount: skippedCount,
      errorCount: errorCount,
      photosAdded: photosAdded,
      photosSkipped: photosSkipped,
      createdShiftId: createdShiftId,
      createdShiftName: finalShiftName,
      message: 'Nhập thành công: $addedCount điểm mới, $replacedCount đã thay, $skippedCount bỏ qua, $photosAdded ảnh',
    );
  }

  // ===========================================================================
  // 5. CÁC HÀM CŨ CỦA SHARING_REPOSITORY (GIỮ NGUYÊN INTERFACE)
  // ===========================================================================

  @override
  Future<List<DataShareModel>> getOutgoingShares() async => [];

  @override
  Future<List<DataShareModel>> getIncomingShares() async => [];

  @override
  Future<Map<String, dynamic>> getSharedLocations() async => {'shares': []};

  @override
  Future<DataShareModel> createShare({
    required String recipientPhone,
    required String scope,
    String? shiftId,
    bool includePhotos = false,
    int? expiresInDays,
  }) {
    throw UnsupportedError('Chế độ cục bộ sử dụng xuất tệp .dshare và mã QR');
  }

  @override
  Future<void> acceptShare(String shareId) async {}

  @override
  Future<void> declineShare(String shareId) async {}

  @override
  Future<void> revokeShare(String shareId) async {}

  @override
  Future<Map<String, dynamic>> importSharedLocations(
    String shareId, {
    List<String>? customerIds,
    bool all = true,
    bool replaceExisting = false,
  }) async {
    return {'imported': 0};
  }
}

