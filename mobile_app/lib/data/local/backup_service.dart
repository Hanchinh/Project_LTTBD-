import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:delivery_marker_mobile/data/local/app_database.dart';
import 'package:delivery_marker_mobile/data/local/backup_zip_helpers.dart';

enum RestoreMode { fullReplace, merge }

class BackupPreview {
  final int formatVersion, schemaVersion, customersCount, savedLocationsCount, shiftsCount, photosCount, fileSizeBytes;
  final String appVersion;
  final DateTime createdAt;
  final bool includePhotos;
  final Map<String, dynamic> rawManifest;

  const BackupPreview({
    required this.formatVersion, required this.schemaVersion, required this.appVersion,
    required this.createdAt, required this.includePhotos, required this.customersCount,
    required this.savedLocationsCount, required this.shiftsCount, required this.photosCount,
    required this.fileSizeBytes, required this.rawManifest,
  });
}

class RestoreResult {
  final RestoreMode mode;
  final int addedCustomers, skippedCustomers, addedLocations, addedPhotos, addedShifts;
  final String message;

  const RestoreResult({
    required this.mode, this.addedCustomers = 0, this.skippedCustomers = 0,
    this.addedLocations = 0, this.addedPhotos = 0, this.addedShifts = 0, required this.message,
  });
}

class BackupService {
  final AppDatabase _appDb;
  final Directory? _customBaseDir, _customPhotosDir;

  BackupService({AppDatabase? appDb, Directory? customBaseDir, Directory? customPhotosDir})
      : _appDb = appDb ?? AppDatabase.instance, _customBaseDir = customBaseDir, _customPhotosDir = customPhotosDir;

  static const String keyLastBackupAt = 'last_backup_at';

  Future<Directory> _getPhotosDir() async {
    if (_customPhotosDir != null) return _customPhotosDir!;
    final baseDir = _customBaseDir ?? await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(baseDir.path, 'app_photos'));
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  Future<File> createBackup({required bool includePhotos, String? password}) async {
    await _appDb.checkpoint();
    final baseDir = _customBaseDir ?? await getApplicationDocumentsDirectory();
    final backupDir = Directory(p.join(baseDir.path, 'backups'));
    if (!backupDir.existsSync()) backupDir.createSync(recursive: true);

    final dbPath = await _appDb.getDatabasePath();
    final dbFile = File(dbPath);
    if (!dbFile.existsSync()) throw StateError('Không tìm thấy tệp cơ sở dữ liệu để sao lưu');

    final nowUtc = DateTime.now().toUtc();
    final nowVn = nowUtc.add(const Duration(hours: 7));
    String pad(int n) => n.toString().padLeft(2, '0');
    final fileName = 'delivery-backup-${nowVn.year}${pad(nowVn.month)}${pad(nowVn.day)}-${pad(nowVn.hour)}${pad(nowVn.minute)}${pad(nowVn.second)}.zip';
    final zipFile = File(p.join(backupDir.path, fileName));

    final archive = Archive();
    final dbBytes = await dbFile.readAsBytes();
    final dbChecksum = sha256.convert(dbBytes).toString();
    archive.addFile(ArchiveFile('database.db', dbBytes.length, dbBytes));

    final photoChecksums = <String, String>{};
    int includedPhotos = 0;
    if (includePhotos) {
      final pDir = await _getPhotosDir();
      if (pDir.existsSync()) {
        for (final e in pDir.listSync()) {
          if (e is File) {
            final name = p.basename(e.path), b = await e.readAsBytes();
            photoChecksums[name] = sha256.convert(b).toString();
            archive.addFile(ArchiveFile('photos/$name', b.length, b));
            includedPhotos++;
          }
        }
      }
    }

    final stats = await _appDb.getStats();
    final manifest = {
      'formatVersion': 1, 'appVersion': '1.0.0', 'schemaVersion': AppDatabase.currentVersion,
      'createdAt': nowUtc.toIso8601String(), 'includePhotos': includePhotos,
      'counts': {'customers': stats['customersCount'] ?? 0, 'savedLocations': stats['savedLocationsCount'] ?? 0, 'shifts': stats['createdShiftsCount'] ?? 0, 'photos': includedPhotos},
      'checksums': {'database.db': dbChecksum, if (includePhotos) 'photos': photoChecksums},
    };
    final mBytes = utf8.encode(jsonEncode(manifest));
    archive.addFile(ArchiveFile('manifest.json', mBytes.length, mBytes));
    await zipFile.writeAsBytes(ZipEncoder().encode(archive), flush: true);

    await _appDb.setMeta(keyLastBackupAt, nowUtc.toIso8601String());
    await _appDb.logActivity(action: 'CREATE_BACKUP', entity: 'system', details: {'fileName': fileName, 'fileSize': zipFile.lengthSync(), 'includePhotos': includePhotos});
    return zipFile;
  }

  Future<void> shareBackup(File backupFile) async {
    if (!backupFile.existsSync()) throw ArgumentError('Tệp sao lưu không tồn tại');
    await SharePlus.instance.share(ShareParams(files: [XFile(backupFile.path, mimeType: 'application/zip', name: p.basename(backupFile.path))], text: 'Bản sao lưu dữ liệu Delivery Location Marker', subject: 'Sao lưu dữ liệu giao hàng'));
  }

  Future<void> shareBackupFile(File f) => shareBackup(f);

  Future<BackupPreview> readBackupPreview(File zipFile) => BackupZipHelpers.readBackupPreview(zipFile);

  Future<RestoreResult> restoreBackup(File zipFile, {required RestoreMode mode}) async {
    return await BackupZipHelpers.executeRestore(zipFile: zipFile, mode: mode, appDb: _appDb, photosDir: await _getPhotosDir());
  }

  Future<bool> shouldShowBackupReminder() async {
    try {
      final last = await _appDb.getMeta(keyLastBackupAt);
      if (last == null || last.isEmpty) {
        final stats = await _appDb.getStats();
        return (stats['savedLocationsCount'] ?? 0) > 0 || (stats['createdShiftsCount'] ?? 0) > 0 || (stats['customersCount'] ?? 0) > 0;
      }
      final dt = DateTime.tryParse(last);
      return dt == null || DateTime.now().toUtc().difference(dt).inDays >= 14;
    } catch (_) {
      return false;
    }
  }

  Future<List<File>> getExistingBackups() async {
    final baseDir = _customBaseDir ?? await getApplicationDocumentsDirectory();
    final backupDir = Directory(p.join(baseDir.path, 'backups'));
    if (!backupDir.existsSync()) return [];
    final files = backupDir.listSync().whereType<File>().where((f) => f.path.endsWith('.zip') || f.path.endsWith('.dbackup')).toList();
    files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
    return files;
  }
}
