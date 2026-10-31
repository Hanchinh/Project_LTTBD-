// Repository quản lý hình ảnh mặt tiền nhà thực địa của khách hàng.
// Thực hiện nén ảnh, tạo thumbnail, xóa mềm và tự động dọn rác sau 30 ngày.
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:delivery_marker_mobile/core/utils/uuid_utils.dart';
import 'package:delivery_marker_mobile/data/database/app_database.dart';
import 'package:delivery_marker_mobile/models/customer_photo_model.dart';

class CompressedImageData {
  final Uint8List fullBytes, thumbBytes;
  CompressedImageData({required this.fullBytes, required this.thumbBytes});
}

CompressedImageData compressAndGenerateThumbnailTask(Uint8List rawBytes) {
  final image = img.decodeImage(rawBytes);
  if (image == null) return CompressedImageData(fullBytes: rawBytes, thumbBytes: rawBytes);
  var full = image;
  if (image.width > 1600 || image.height > 1600) {
    full = img.copyResize(image, width: image.width >= image.height ? 1600 : null, height: image.height > image.width ? 1600 : null);
  }
  var thumb = full;
  if (full.width > 300 || full.height > 300) {
    thumb = img.copyResize(full, width: full.width >= full.height ? 300 : null, height: full.height > full.width ? 300 : null);
  }
  return CompressedImageData(
    fullBytes: Uint8List.fromList(img.encodeJpg(full, quality: 80)),
    thumbBytes: Uint8List.fromList(img.encodeJpg(thumb, quality: 75)),
  );
}

/// Kho dữ liệu quản lý hình ảnh mốc giao hàng cục bộ (Local-First).
class PhotoRepository {
  final AppDatabase _appDb;
  final Directory? _baseDirectory;

  PhotoRepository({AppDatabase? appDb, Directory? baseDirectory})
      : _appDb = appDb ?? AppDatabase.instance,
        _baseDirectory = baseDirectory;

  Future<Directory> getBaseDirectory() async {
    if (_baseDirectory != null) return _baseDirectory!;
    try {
      return await getApplicationDocumentsDirectory();
    } catch (_) {
      final temp = Directory(p.join(Directory.systemTemp.path, 'app_delivery_photos'));
      if (!temp.existsSync()) temp.createSync(recursive: true);
      return temp;
    }
  }

  Future<Directory> getPhotosDirectory() async {
    final dir = Directory(p.join((await getBaseDirectory()).path, 'photos'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<Directory> getThumbsDirectory() async {
    final dir = Directory(p.join((await getBaseDirectory()).path, 'photos', 'thumbs'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  static String? detectMimeType(Uint8List b) {
    if (b.length < 12) return null;
    if (b[0] == 0xFF && b[1] == 0xD8 && b[2] == 0xFF) return 'image/jpeg';
    if (b.length >= 8 && b[0] == 0x89 && b[1] == 0x50 && b[2] == 0x4E && b[3] == 0x47 && b[4] == 0x0D && b[5] == 0x0A && b[6] == 0x1A && b[7] == 0x0A) return 'image/png';
    if (b[0] == 0x52 && b[1] == 0x49 && b[2] == 0x46 && b[3] == 0x46 && b[8] == 0x57 && b[9] == 0x45 && b[10] == 0x42 && b[11] == 0x50) return 'image/webp';
    return null;
  }

  static Uint8List decodeBase64Image(String raw) {
    var c = raw.trim();
    final idx = c.indexOf(',');
    if (idx != -1 && c.substring(0, idx).contains('base64')) c = c.substring(idx + 1);
    return base64Decode(c.replaceAll(RegExp(r'\s+'), ''));
  }

  Future<CustomerPhotoModel> addCustomerPhoto(String customerId, String imageBase64) async {
    final bytes = decodeBase64Image(imageBase64);
    if (detectMimeType(bytes) == null) throw ArgumentError('Định dạng ảnh không hợp lệ (chỉ hỗ trợ JPG, PNG, WEBP)');
    if (bytes.lengthInBytes > 5 * 1024 * 1024) throw ArgumentError('Dung lượng ảnh vượt quá giới hạn 5MB');

    final db = await _appDb.database;
    final existing = await db.query('customer_photos', where: 'customer_id = ? AND deleted_at IS NULL', whereArgs: [customerId]);
    if (existing.length >= 10) throw StateError('Mỗi khách hàng chỉ được lưu tối đa 10 ảnh mặt tiền nhà');

    final photoId = UuidUtils.generate();
    final fileName = '$photoId.jpg', thumbFileName = '${photoId}_thumb.jpg';
    final fullFile = File(p.join((await getPhotosDirectory()).path, fileName));
    final thumbFile = File(p.join((await getThumbsDirectory()).path, thumbFileName));

    final compressed = (_baseDirectory != null || Platform.environment.containsKey('FLUTTER_TEST'))
        ? compressAndGenerateThumbnailTask(bytes)
        : await compute(compressAndGenerateThumbnailTask, bytes);

    await fullFile.writeAsBytes(compressed.fullBytes, flush: true);
    await thumbFile.writeAsBytes(compressed.thumbBytes, flush: true);

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
        details: {'customerId': customerId, 'fileName': fileName, 'fileSize': compressed.fullBytes.lengthInBytes},
      );

      return CustomerPhotoModel(
        id: photoId,
        customerId: customerId,
        imageUrl: fullFile.path,
        createdAt: DateTime.tryParse(nowIso),
      );
    } catch (_) {
      if (await fullFile.exists()) await fullFile.delete();
      if (await thumbFile.exists()) await thumbFile.delete();
      rethrow;
    }
  }

  Future<List<CustomerPhotoModel>> getCustomerPhotos(String customerId) async {
    final db = await _appDb.database;
    final rows = await db.query(
      'customer_photos',
      where: 'customer_id = ? AND deleted_at IS NULL',
      whereArgs: [customerId],
      orderBy: 'created_at DESC',
    );
    final pDir = await getPhotosDirectory();
    return rows.map((r) => CustomerPhotoModel(
      id: r['id'] as String,
      customerId: customerId,
      imageUrl: p.join(pDir.path, r['file_name'] as String),
      createdAt: DateTime.tryParse(r['created_at']?.toString() ?? ''),
    )).toList();
  }

  Future<void> deleteCustomerPhoto(String customerId, String photoId) async {
    final db = await _appDb.database;
    final count = await db.update(
      'customer_photos',
      {'deleted_at': AppDatabase.currentIsoUtc()},
      where: 'id = ? AND customer_id = ? AND deleted_at IS NULL',
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

  Future<int> purgeDeletedPhotosOlderThan({Duration olderThan = const Duration(days: 30)}) async {
    final db = await _appDb.database;
    final rows = await db.query('customer_photos', where: 'deleted_at IS NOT NULL');
    if (rows.isEmpty) return 0;

    final cutoff = DateTime.now().toUtc().subtract(olderThan);
    final pDir = await getPhotosDirectory(), tDir = await getThumbsDirectory();
    int purged = 0;

    for (final r in rows) {
      final delStr = r['deleted_at'] as String?;
      if (delStr != null && DateTime.tryParse(delStr)?.isBefore(cutoff) == true) {
        final f = File(p.join(pDir.path, r['file_name'] as String));
        if (await f.exists()) await f.delete();
        final thumb = r['thumb_file_name'] as String?;
        if (thumb != null) {
          final tf = File(p.join(tDir.path, thumb));
          if (await tf.exists()) await tf.delete();
        }
        await db.delete('customer_photos', where: 'id = ?', whereArgs: [r['id']]);
        purged++;
      }
    }
    if (purged > 0) {
      await _appDb.logActivity(
        action: 'PURGE_EXPIRED_PHOTOS',
        entity: 'customer_photos',
        entityId: 'batch',
        details: {'purgedCount': purged},
      );
    }
    return purged;
  }

  Future<Map<String, String>> getPhotoAuthInfo(String photoPath, {int? cacheVersion, bool bustCache = false}) async {
    final clean = photoPath.trim();
    if (clean.isEmpty) return {'url': '', 'token': '', 'isLocal': 'false'};
    if (clean.startsWith('file://')) return {'url': clean, 'filePath': clean.replaceFirst('file://', ''), 'isLocal': 'true', 'token': ''};
    if (clean.startsWith('/') || clean.contains(':\\') || clean.contains(':/')) return {'url': 'file://$clean', 'filePath': clean, 'isLocal': 'true', 'token': ''};

    final pFull = p.join((await getPhotosDirectory()).path, clean);
    final tFull = p.join((await getThumbsDirectory()).path, clean);
    var resolved = pFull;
    if (clean.contains('_thumb') && await File(tFull).exists()) resolved = tFull;
    return {'url': 'file://$resolved', 'filePath': resolved, 'isLocal': 'true', 'token': ''};
  }

  Future<Map<String, dynamic>> getCustomerPhotoSummary(String customerId, {int limit = 3}) async {
    final db = await _appDb.database;
    final countRes = await db.rawQuery('SELECT COUNT(*) as count FROM customer_photos WHERE customer_id = ? AND deleted_at IS NULL', [customerId]);
    final count = (countRes.isNotEmpty ? countRes.first['count'] as num? : 0)?.toInt() ?? 0;
    final rows = await db.query('customer_photos', where: 'customer_id = ? AND deleted_at IS NULL', whereArgs: [customerId], orderBy: 'created_at DESC', limit: limit);

    final tDir = await getThumbsDirectory(), pDir = await getPhotosDirectory();
    final photos = rows.map((r) {
      final tName = r['thumb_file_name'] as String?;
      return CustomerPhotoModel(id: r['id'] as String, customerId: r['customer_id'] as String, imageUrl: tName != null ? p.join(tDir.path, tName) : p.join(pDir.path, r['file_name'] as String), createdAt: DateTime.tryParse(r['created_at']?.toString() ?? ''));
    }).toList();

    return {'photoCount': count, 'photos': photos, 'firstThumbnailUrl': photos.isNotEmpty ? photos.first.imageUrl : null};
  }

  Future<Map<String, Map<String, dynamic>>> getBatchPhotoSummaries(List<String> customerIds, {int limit = 3}) async {
    if (customerIds.isEmpty) return {};
    final db = await _appDb.database;
    final tDir = await getThumbsDirectory(), pDir = await getPhotosDirectory();
    final ph = List.filled(customerIds.length, '?').join(',');

    final countRows = await db.rawQuery('SELECT customer_id, COUNT(*) as cnt FROM customer_photos WHERE customer_id IN ($ph) AND deleted_at IS NULL GROUP BY customer_id', customerIds);
    final countMap = {for (var r in countRows) r['customer_id'] as String: (r['cnt'] as num).toInt()};

    final photoRows = await db.rawQuery('''
      SELECT id, customer_id, file_name, thumb_file_name, created_at FROM (
        SELECT id, customer_id, file_name, thumb_file_name, created_at, ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY created_at DESC) as rn
        FROM customer_photos WHERE customer_id IN ($ph) AND deleted_at IS NULL
      ) WHERE rn <= $limit
    ''', customerIds);

    final res = {for (var cid in customerIds) cid: {'photoCount': countMap[cid] ?? 0, 'photos': <CustomerPhotoModel>[], 'firstThumbnailUrl': null}};
    for (final r in photoRows) {
      final cid = r['customer_id'] as String, tName = r['thumb_file_name'] as String?;
      (res[cid]!['photos'] as List<CustomerPhotoModel>).add(CustomerPhotoModel(id: r['id'] as String, customerId: cid, imageUrl: tName != null ? p.join(tDir.path, tName) : p.join(pDir.path, r['file_name'] as String), createdAt: DateTime.tryParse(r['created_at']?.toString() ?? '')));
    }
    for (final cid in customerIds) {
      final pts = res[cid]!['photos'] as List<CustomerPhotoModel>;
      if (pts.isNotEmpty) res[cid]!['firstThumbnailUrl'] = pts.first.imageUrl;
    }
    return res;
  }
}

typedef LocalPhotoRepository = PhotoRepository;
