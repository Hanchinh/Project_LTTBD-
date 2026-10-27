import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../local/app_database.dart';
import '../../models/customer_photo_model.dart';
import '../../utils/uuid_utils.dart';
import '../photo_repository.dart';

/// Kết quả nén ảnh và tạo thumbnail trong luồng riêng Isolate
class CompressedImageData {
  final Uint8List fullBytes;
  final Uint8List thumbBytes;

  CompressedImageData({required this.fullBytes, required this.thumbBytes});
}

/// Nén cạnh dài <= 1600px chất lượng ~80 và tạo thumbnail ~300px chạy trong Isolate riêng (compute)
CompressedImageData compressAndGenerateThumbnailTask(Uint8List rawBytes) {
  final image = img.decodeImage(rawBytes);
  if (image == null) {
    // Nếu không decode được bằng package:image (ví dụ file giả lập trong unit test),
    // giữ nguyên rawBytes để bảo toàn dữ liệu kiểm thử
    return CompressedImageData(fullBytes: rawBytes, thumbBytes: rawBytes);
  }

  // 1. Cạnh dài <= 1600px, chất lượng ~80
  img.Image fullImage = image;
  if (image.width > 1600 || image.height > 1600) {
    if (image.width >= image.height) {
      fullImage = img.copyResize(image, width: 1600);
    } else {
      fullImage = img.copyResize(image, height: 1600);
    }
  }
  final fullJpg = Uint8List.fromList(img.encodeJpg(fullImage, quality: 80));

  // 2. Thumbnail cạnh dài ~300px
  img.Image thumbImage = fullImage;
  if (fullImage.width > 300 || fullImage.height > 300) {
    if (fullImage.width >= fullImage.height) {
      thumbImage = img.copyResize(fullImage, width: 300);
    } else {
      thumbImage = img.copyResize(fullImage, height: 300);
    }
  }
  final thumbJpg = Uint8List.fromList(img.encodeJpg(thumbImage, quality: 75));

  return CompressedImageData(fullBytes: fullJpg, thumbBytes: thumbJpg);
}

/// Triển khai PhotoRepository cục bộ bằng SQLite và hệ thống tệp riêng của app (Local-First)
/// Toàn bộ ảnh được lưu trữ trong thư mục riêng của app (documents/photos & photos/thumbs),
/// không lưu vào thư viện ảnh công khai hay cache dùng chung, bảo đảm tối đa quyền riêng tư.
class LocalPhotoRepository implements PhotoRepository {
  final AppDatabase _appDb;
  final Directory? _baseDirectory;

  LocalPhotoRepository({AppDatabase? appDb, Directory? baseDirectory})
      : _appDb = appDb ?? AppDatabase.instance,
        _baseDirectory = baseDirectory;

  /// Lấy thư mục gốc lưu trữ ảnh của ứng dụng
  Future<Directory> getBaseDirectory() async {
    if (_baseDirectory != null) {
      return _baseDirectory!;
    }
    try {
      return await getApplicationDocumentsDirectory();
    } catch (_) {
      // Môi trường test không có platform channel path_provider
      final temp = Directory(p.join(Directory.systemTemp.path, 'app_delivery_photos'));
      if (!temp.existsSync()) {
        temp.createSync(recursive: true);
      }
      return temp;
    }
  }

  /// Thư mục lưu ảnh đầy đủ: <baseDir>/photos
  Future<Directory> getPhotosDirectory() async {
    final base = await getBaseDirectory();
    final dir = Directory(p.join(base.path, 'photos'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Thư mục lưu thumbnail: <baseDir>/photos/thumbs
  Future<Directory> getThumbsDirectory() async {
    final base = await getBaseDirectory();
    final dir = Directory(p.join(base.path, 'photos', 'thumbs'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Nhận diện định dạng ảnh dựa trên Magic Bytes (JPEG, PNG, WEBP)
  static String? detectMimeType(Uint8List bytes) {
    if (bytes.length < 12) return null;
    // JPEG: FF D8 FF
    if (bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) {
      return 'image/jpeg';
    }
    // PNG: 89 50 4E 47 0D 0A 1A 0A
    if (bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47 &&
        bytes[4] == 0x0D &&
        bytes[5] == 0x0A &&
        bytes[6] == 0x1A &&
        bytes[7] == 0x0A) {
      return 'image/png';
    }
    // WebP: RIFF .... WEBP
    if (bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50) {
      return 'image/webp';
    }
    return null;
  }

  /// Giải mã chuỗi base64 (hỗ trợ cả Data URI và raw base64)
  static Uint8List decodeBase64Image(String rawInput) {
    String clean = rawInput.trim();
    final commaIdx = clean.indexOf(',');
    if (commaIdx != -1 && clean.substring(0, commaIdx).contains('base64')) {
      clean = clean.substring(commaIdx + 1);
    }
    clean = clean.replaceAll(RegExp(r'\s+'), '');
    return base64Decode(clean);
  }

  @override
  Future<CustomerPhotoModel> addCustomerPhoto(String customerId, String imageBase64) async {
    final bytes = decodeBase64Image(imageBase64);

    // 1. Kiểm tra định dạng bằng Magic Bytes
    final mime = detectMimeType(bytes);
    if (mime == null) {
      throw ArgumentError('Định dạng ảnh không hợp lệ (chỉ hỗ trợ JPG, PNG, WEBP)');
    }

    // 2. Kiểm tra dung lượng tối đa 5MB
    if (bytes.lengthInBytes > 5 * 1024 * 1024) {
      throw ArgumentError('Dung lượng ảnh vượt quá giới hạn 5MB');
    }

    final db = await _appDb.database;

    // 3. Kiểm tra giới hạn tối đa 10 ảnh/khách hàng (chỉ tính ảnh chưa xóa mềm)
    final existingPhotos = await db.query(
      'customer_photos',
      where: 'customer_id = ? AND deleted_at IS NULL',
      whereArgs: [customerId],
    );
    if (existingPhotos.length >= 10) {
      throw StateError('Mỗi khách hàng chỉ được lưu tối đa 10 ảnh mặt tiền nhà');
    }

    // 4. Sinh tên file ngẫu nhiên UUID (không chứa SĐT hay tên khách để bảo mật)
    final photoId = UuidUtils.generate();
    final fileName = '$photoId.jpg';
    final thumbFileName = '${photoId}_thumb.jpg';

    final photosDir = await getPhotosDirectory();
    final thumbsDir = await getThumbsDirectory();

    final fullFile = File(p.join(photosDir.path, fileName));
    final thumbFile = File(p.join(thumbsDir.path, thumbFileName));

    // Nén cạnh dài <= 1600px quality ~80 và tạo thumbnail ~300px ở luồng riêng (compute/isolate)
    final compressed = (_baseDirectory != null || Platform.environment.containsKey('FLUTTER_TEST'))
        ? compressAndGenerateThumbnailTask(bytes)
        : await compute(compressAndGenerateThumbnailTask, bytes);

    await fullFile.writeAsBytes(compressed.fullBytes, flush: true);
    await thumbFile.writeAsBytes(compressed.thumbBytes, flush: true);

    // 5. Ghi dữ liệu vào SQLite; nếu DB lỗi thì xóa ngay file vừa tạo (chống file mồ côi)
    try {
      final nowIso = AppDatabase.currentIsoUtc();
      await db.insert('customer_photos', {
        'id': photoId,
        'customer_id': customerId,
        'file_name': fileName,
        'thumb_file_name': thumbFileName,
        'created_at': nowIso,
        'deleted_at': null,
      });

      await _appDb.logActivity(
        action: 'ADD_CUSTOMER_PHOTO',
        entity: 'customer_photos',
        entityId: photoId,
        details: {
          'customerId': customerId,
          'fileName': fileName,
          'fileSize': compressed.fullBytes.lengthInBytes,
        },
      );

      return CustomerPhotoModel(
        id: photoId,
        customerId: customerId,
        imageUrl: fullFile.path,
        createdAt: DateTime.tryParse(nowIso),
      );
    } catch (e) {
      // Dọn dẹp file mồ côi nếu ghi CSDL thất bại
      if (await fullFile.exists()) await fullFile.delete();
      if (await thumbFile.exists()) await thumbFile.delete();
      rethrow;
    }
  }

  @override
  Future<List<CustomerPhotoModel>> getCustomerPhotos(String customerId) async {
    final db = await _appDb.database;
    final rows = await db.query(
      'customer_photos',
      where: 'customer_id = ? AND deleted_at IS NULL',
      whereArgs: [customerId],
      orderBy: 'created_at DESC',
    );

    final photosDir = await getPhotosDirectory();
    return rows.map((r) {
      final fileName = r['file_name'] as String;
      final fullPath = p.join(photosDir.path, fileName);
      return CustomerPhotoModel(
        id: r['id'] as String,
        customerId: r['customer_id'] as String,
        imageUrl: fullPath,
        createdAt: DateTime.tryParse(r['created_at']?.toString() ?? ''),
      );
    }).toList();
  }

  @override
  Future<void> deleteCustomerPhoto(String customerId, String photoId) async {
    final db = await _appDb.database;
    final nowIso = AppDatabase.currentIsoUtc();

    // Xóa mềm: gán deleted_at = now, KHÔNG xóa file ngay lập tức
    final count = await db.update(
      'customer_photos',
      {
        'deleted_at': nowIso,
      },
      where: 'id = ? AND customer_id = ?',
      whereArgs: [photoId, customerId],
    );

    if (count > 0) {
      await _appDb.logActivity(
        action: 'DELETE_CUSTOMER_PHOTO',
        entity: 'customer_photos',
        entityId: photoId,
        details: {'customerId': customerId},
      );
    }
  }

  /// Dọn dẹp các tệp ảnh đã xóa mềm quá thời hạn (mặc định 30 ngày)
  Future<int> purgeDeletedPhotosOlderThan({Duration olderThan = const Duration(days: 30)}) async {
    final db = await _appDb.database;
    final rows = await db.query(
      'customer_photos',
      where: 'deleted_at IS NOT NULL',
    );

    if (rows.isEmpty) return 0;

    final cutoff = DateTime.now().toUtc().subtract(olderThan);
    final photosDir = await getPhotosDirectory();
    final thumbsDir = await getThumbsDirectory();

    int purgedCount = 0;

    for (final r in rows) {
      final deletedAtStr = r['deleted_at'] as String?;
      if (deletedAtStr == null) continue;
      final deletedAt = DateTime.tryParse(deletedAtStr);
      if (deletedAt != null && deletedAt.isBefore(cutoff)) {
        final photoId = r['id'] as String;
        final fileName = r['file_name'] as String;
        final thumbName = r['thumb_file_name'] as String?;

        final fullFile = File(p.join(photosDir.path, fileName));
        if (await fullFile.exists()) {
          await fullFile.delete();
        }

        if (thumbName != null) {
          final thumbFile = File(p.join(thumbsDir.path, thumbName));
          if (await thumbFile.exists()) {
            await thumbFile.delete();
          }
        }

        await db.delete(
          'customer_photos',
          where: 'id = ?',
          whereArgs: [photoId],
        );

        purgedCount++;
      }
    }

    if (purgedCount > 0) {
      await _appDb.logActivity(
        action: 'PURGE_EXPIRED_PHOTOS',
        entity: 'customer_photos',
        entityId: 'batch',
        details: {'purgedCount': purgedCount},
      );
    }

    return purgedCount;
  }

  @override
  Future<Map<String, String>> getPhotoAuthInfo(
    String photoPath, {
    int? cacheVersion,
    bool bustCache = false,
  }) async {
    final clean = photoPath.trim();
    if (clean.isEmpty) {
      return {'url': '', 'token': '', 'isLocal': 'false'};
    }

    // Nếu là URI dạng file://
    if (clean.startsWith('file://')) {
      final pathStr = clean.replaceFirst('file://', '');
      return {
        'url': clean,
        'filePath': pathStr,
        'isLocal': 'true',
        'token': '',
      };
    }

    // Nếu là đường dẫn tệp tuyệt đối trên thiết bị
    if (clean.startsWith('/') || clean.contains(':\\') || clean.contains(':/')) {
      return {
        'url': 'file://$clean',
        'filePath': clean,
        'isLocal': 'true',
        'token': '',
      };
    }

    // Nếu là tên tệp tương đối trong thư mục photos hoặc thumbs
    final photosDir = await getPhotosDirectory();
    final thumbsDir = await getThumbsDirectory();

    final photoPathFull = p.join(photosDir.path, clean);
    final thumbPathFull = p.join(thumbsDir.path, clean);

    String resolvedPath = photoPathFull;
    if (clean.contains('_thumb') && await File(thumbPathFull).exists()) {
      resolvedPath = thumbPathFull;
    }

    return {
      'url': 'file://$resolvedPath',
      'filePath': resolvedPath,
      'isLocal': 'true',
      'token': '',
    };
  }

  /// Lấy photoCount và tối đa [limit] ảnh thumbnail đầu tiên cho khách hàng
  Future<Map<String, dynamic>> getCustomerPhotoSummary(String customerId, {int limit = 3}) async {
    final db = await _appDb.database;
    final countResult = await db.rawQuery(
      'SELECT COUNT(*) as count FROM customer_photos WHERE customer_id = ? AND deleted_at IS NULL',
      [customerId],
    );
    final count = (countResult.isNotEmpty ? countResult.first['count'] as num? : 0)?.toInt() ?? 0;

    final rows = await db.query(
      'customer_photos',
      where: 'customer_id = ? AND deleted_at IS NULL',
      whereArgs: [customerId],
      orderBy: 'created_at DESC',
      limit: limit,
    );

    final thumbsDir = await getThumbsDirectory();
    final photosDir = await getPhotosDirectory();

    final photos = rows.map((r) {
      final thumbName = r['thumb_file_name'] as String?;
      final fileName = r['file_name'] as String;
      final targetPath = thumbName != null
          ? p.join(thumbsDir.path, thumbName)
          : p.join(photosDir.path, fileName);

      return CustomerPhotoModel(
        id: r['id'] as String,
        customerId: r['customer_id'] as String,
        imageUrl: targetPath,
        createdAt: DateTime.tryParse(r['created_at']?.toString() ?? ''),
      );
    }).toList();

    final firstThumb = photos.isNotEmpty ? photos.first.imageUrl : null;

    return {
      'photoCount': count,
      'photos': photos,
      'firstThumbnailUrl': firstThumb,
    };
  }

  /// Lấy danh sách photoCount và thumbnails theo lô cho nhiều khách hàng
  Future<Map<String, Map<String, dynamic>>> getBatchPhotoSummaries(
    List<String> customerIds, {
    int limit = 3,
  }) async {
    if (customerIds.isEmpty) return {};
    final db = await _appDb.database;
    final thumbsDir = await getThumbsDirectory();
    final photosDir = await getPhotosDirectory();

    final placeholders = List.filled(customerIds.length, '?').join(',');

    // 1. Lấy count cho từng customer
    final countRows = await db.rawQuery('''
      SELECT customer_id, COUNT(*) as cnt
      FROM customer_photos
      WHERE customer_id IN ($placeholders) AND deleted_at IS NULL
      GROUP BY customer_id
    ''', customerIds);

    final countMap = <String, int>{};
    for (final r in countRows) {
      countMap[r['customer_id'] as String] = (r['cnt'] as num).toInt();
    }

    // 2. Lấy top N ảnh cho từng customer bằng window function
    final photoRows = await db.rawQuery('''
      SELECT id, customer_id, file_name, thumb_file_name, created_at
      FROM (
        SELECT id, customer_id, file_name, thumb_file_name, created_at,
               ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY created_at DESC) as rn
        FROM customer_photos
        WHERE customer_id IN ($placeholders) AND deleted_at IS NULL
      )
      WHERE rn <= $limit
    ''', customerIds);

    final resultMap = <String, Map<String, dynamic>>{};
    for (final cid in customerIds) {
      resultMap[cid] = {
        'photoCount': countMap[cid] ?? 0,
        'photos': <CustomerPhotoModel>[],
        'firstThumbnailUrl': null,
      };
    }

    for (final r in photoRows) {
      final cid = r['customer_id'] as String;
      final thumbName = r['thumb_file_name'] as String?;
      final fileName = r['file_name'] as String;
      final targetPath = thumbName != null
          ? p.join(thumbsDir.path, thumbName)
          : p.join(photosDir.path, fileName);

      final model = CustomerPhotoModel(
        id: r['id'] as String,
        customerId: cid,
        imageUrl: targetPath,
        createdAt: DateTime.tryParse(r['created_at']?.toString() ?? ''),
      );
      (resultMap[cid]!['photos'] as List<CustomerPhotoModel>).add(model);
    }

    for (final cid in customerIds) {
      final photos = resultMap[cid]!['photos'] as List<CustomerPhotoModel>;
      if (photos.isNotEmpty) {
        resultMap[cid]!['firstThumbnailUrl'] = photos.first.imageUrl;
      }
    }

    return resultMap;
  }
}
