import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:delivery_marker_mobile/data/local/app_database.dart';
import 'package:delivery_marker_mobile/data/local/backup_models.dart';
import 'package:delivery_marker_mobile/data/local/backup_zip_helpers.dart';

export 'package:delivery_marker_mobile/data/local/backup_models.dart';

/// Dịch vụ Sao lưu và Khôi phục dữ liệu Cục bộ (Local-First Backup & Restore)
class BackupService {
  final AppDatabase _appDb;
  final Directory? _customBaseDir;
  final Directory? _customPhotosDir;

  BackupService({
    AppDatabase? appDb,
    Directory? customBaseDir,
    Directory? customPhotosDir,
  })  : _appDb = appDb ?? AppDatabase.instance,
        _customBaseDir = customBaseDir,
        _customPhotosDir = customPhotosDir;

  static const String keyLastBackupAt = 'last_backup_at';

  Future<Directory> _getPhotosDir() async {
    if (_customPhotosDir != null) return _customPhotosDir!;
    final baseDir = _customBaseDir ?? await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(baseDir.path, 'app_photos'));
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    return dir;
  }

  /// 1. TẠO BẢN SAO LƯU (.dbackup / .zip)
  Future<File> createBackup({
    required bool includePhotos,
    String? password,
  }) async {
    await _appDb.checkpoint();

    final baseDir = _customBaseDir ?? await getApplicationDocumentsDirectory();
    final backupDir = Directory(p.join(baseDir.path, 'backups'));
    if (!backupDir.existsSync()) {
      backupDir.createSync(recursive: true);
    }

    final dbPath = await _appDb.getDatabasePath();
    final dbFile = File(dbPath);
    if (!dbFile.existsSync()) {
      throw StateError('Không tìm thấy tệp cơ sở dữ liệu để sao lưu');
    }

    final nowUtc = DateTime.now().toUtc();
    final nowVn = nowUtc.add(const Duration(hours: 7));
    final year = nowVn.year.toString();
    final month = nowVn.month.toString().padLeft(2, '0');
    final day = nowVn.day.toString().padLeft(2, '0');
    final hour = nowVn.hour.toString().padLeft(2, '0');
    final min = nowVn.minute.toString().padLeft(2, '0');
    final sec = nowVn.second.toString().padLeft(2, '0');
    final fileName = 'delivery-backup-$year$month$day-$hour$min$sec.zip';
    final zipFile = File(p.join(backupDir.path, fileName));

    final archive = Archive();

    final dbBytes = await dbFile.readAsBytes();
    final dbChecksum = sha256.convert(dbBytes).toString();
    archive.addFile(ArchiveFile('database.db', dbBytes.length, dbBytes));

    final photoChecksums = <String, String>{};
    int includedPhotosCount = 0;
    if (includePhotos) {
      final photosDir = await _getPhotosDir();
      if (photosDir.existsSync()) {
        final photoEntities = photosDir.listSync(recursive: false);
        for (final entity in photoEntities) {
          if (entity is File) {
            final name = p.basename(entity.path);
            final bytes = await entity.readAsBytes();
            final chk = sha256.convert(bytes).toString();
            photoChecksums[name] = chk;
            archive.addFile(ArchiveFile('photos/$name', bytes.length, bytes));
            includedPhotosCount++;
          }
        }
      }
    }

    final stats = await _appDb.getStats();

    final manifest = {
      'formatVersion': 1,
      'appVersion': '1.0.0',
      'schemaVersion': AppDatabase.currentVersion,
      'createdAt': nowUtc.toIso8601String(),
      'includePhotos': includePhotos,
      'counts': {
        'customers': stats['customersCount'] ?? 0,
        'savedLocations': stats['savedLocationsCount'] ?? 0,
        'shifts': stats['createdShiftsCount'] ?? 0,
        'photos': includedPhotosCount,
      },
      'checksums': {
        'database.db': dbChecksum,
        if (includePhotos) 'photos': photoChecksums,
      },
    };

    final manifestBytes = utf8.encode(jsonEncode(manifest));
    archive.addFile(ArchiveFile('manifest.json', manifestBytes.length, manifestBytes));

    final zipData = ZipEncoder().encode(archive);
    await zipFile.writeAsBytes(zipData, flush: true);

    await _appDb.setMeta(keyLastBackupAt, nowUtc.toIso8601String());

    await _appDb.logActivity(
      action: 'CREATE_BACKUP',
      entity: 'system',
      details: {
        'fileName': fileName,
        'fileSize': zipFile.lengthSync(),
        'includePhotos': includePhotos,
        'customersCount': stats['customersCount'],
        'locationsCount': stats['savedLocationsCount'],
        'shiftsCount': stats['createdShiftsCount'],
        'photosCount': includedPhotosCount,
      },
    );

    return zipFile;
  }

  /// 2. CHIA SẺ FILE SAO LƯU QUA HỆ THỐNG
  Future<void> shareBackup(File backupFile) async {
    if (!backupFile.existsSync()) {
      throw ArgumentError('Tệp sao lưu không tồn tại');
    }
    final xFile = XFile(
      backupFile.path,
      mimeType: 'application/zip',
      name: p.basename(backupFile.path),
    );
    await SharePlus.instance.share(
      ShareParams(
        files: [xFile],
        text: 'Bản sao lưu dữ liệu Delivery Location Marker',
        subject: 'Sao lưu dữ liệu giao hàng',
      ),
    );
  }

  /// 3. ĐỌC VÀ XÁC THỰC BẢN SAO LƯU TRƯỚC KHI KHÔI PHỤC
  Future<BackupPreview> readBackupPreview(File zipFile) =>
      BackupZipHelpers.readBackupPreview(zipFile);

  /// 4. THỰC HIỆN KHÔI PHỤC DỮ LIỆU
  Future<RestoreResult> restoreBackup(
    File zipFile, {
    required RestoreMode mode,
  }) async {
    final photosDir = await _getPhotosDir();
    return await BackupZipHelpers.executeRestore(
      zipFile: zipFile,
      mode: mode,
      appDb: _appDb,
      photosDir: photosDir,
    );
  }

  /// 5. KIỂM TRA CÓ CẦN HIỂN THỊ NHẮC NHỞ SAO LƯU (> 14 ngày)
  Future<bool> shouldShowBackupReminder() async {
    try {
      final lastBackupStr = await _appDb.getMeta(keyLastBackupAt);
      if (lastBackupStr == null || lastBackupStr.isEmpty) {
        final stats = await _appDb.getStats();
        final hasData = (stats['savedLocationsCount'] ?? 0) > 0 ||
            (stats['createdShiftsCount'] ?? 0) > 0 ||
            (stats['customersCount'] ?? 0) > 0;
        return hasData;
      }

      final lastBackup = DateTime.tryParse(lastBackupStr);
      if (lastBackup == null) return false;

      final diff = DateTime.now().toUtc().difference(lastBackup);
      return diff.inDays >= 14;
    } catch (_) {
      return false;
    }
  }
}
