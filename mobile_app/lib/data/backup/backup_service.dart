// Dịch vụ tạo và khôi phục bản sao lưu dữ liệu toàn diện dạng file ZIP.
// Đóng gói cơ sở dữ liệu SQLite và thư mục ảnh kèm mã băm kiểm tra tính toàn vẹn.
import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sqflite/sqflite.dart';
import 'package:delivery_marker_mobile/data/database/app_database.dart';

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

class BackupZipHelpers {
  static void assertNoPathTraversal(Archive archive) {
    for (final file in archive) {
      final name = file.name.replaceAll('\\', '/');
      if (name.contains('../') || name.contains('..') || name.startsWith('/') || name.contains(':')) {
        throw const FormatException('Phát hiện đường dẫn bất thường (Path Traversal) trong file sao lưu.');
      }
    }
  }

  static Future<BackupPreview> readBackupPreview(File zipFile) async {
    if (!zipFile.existsSync()) throw ArgumentError('Tệp sao lưu không tồn tại');
    final archive = ZipDecoder().decodeBytes(await zipFile.readAsBytes());
    assertNoPathTraversal(archive);

    final mFile = archive.findFile('manifest.json');
    if (mFile == null) throw const FormatException('File sao lưu không hợp lệ: Thiếu tệp manifest.json.');
    final manifest = jsonDecode(utf8.decode(mFile.content as List<int>)) as Map<String, dynamic>;

    final dbFile = archive.findFile('database.db');
    if (dbFile == null) throw const FormatException('File sao lưu không hợp lệ: Thiếu tệp database.db.');

    final schemaVer = manifest['schemaVersion'] as int? ?? 1;
    if (schemaVer > AppDatabase.currentVersion) {
      throw FormatException('File sao lưu từ phiên bản CSDL mới hơn (v$schemaVer > v${AppDatabase.currentVersion}). Vui lòng nâng cấp ứng dụng.');
    }

    final checksums = (manifest['checksums'] as Map<String, dynamic>?) ?? {};
    final expectedDb = checksums['database.db'] as String?;
    final actualDb = sha256.convert(dbFile.content as List<int>).toString();
    if (expectedDb != null && expectedDb != actualDb) {
      throw const FormatException('Mã băm CSDL không khớp. Tệp sao lưu có dấu hiệu bị hỏng hoặc bị sửa đổi.');
    }

    final counts = (manifest['counts'] as Map<String, dynamic>?) ?? {};
    return BackupPreview(
      formatVersion: manifest['formatVersion'] as int? ?? 1,
      schemaVersion: schemaVer, appVersion: manifest['appVersion'] as String? ?? '1.0.0',
      createdAt: DateTime.parse(manifest['createdAt'] as String? ?? DateTime.now().toUtc().toIso8601String()),
      includePhotos: manifest['includePhotos'] as bool? ?? false,
      customersCount: counts['customers'] as int? ?? 0,
      savedLocationsCount: counts['savedLocations'] as int? ?? 0,
      shiftsCount: counts['shifts'] as int? ?? 0, photosCount: counts['photos'] as int? ?? 0,
      fileSizeBytes: zipFile.lengthSync(), rawManifest: manifest,
    );
  }

  static Future<RestoreResult> executeRestore({
    required File zipFile, required RestoreMode mode, required AppDatabase appDb, required Directory photosDir,
  }) async {
    final preview = await readBackupPreview(zipFile);
    final archive = ZipDecoder().decodeBytes(await zipFile.readAsBytes());
    final dbEntry = archive.findFile('database.db')!;

    final tempDir = Directory.systemTemp.createTempSync('restore_src_');
    final tempDbFile = File(p.join(tempDir.path, 'source_backup.db'));
    await tempDbFile.writeAsBytes(dbEntry.content as List<int>, flush: true);

    final factory = appDb.factory ?? databaseFactory;
    final Database srcDb = await factory.openDatabase(tempDbFile.path, options: OpenDatabaseOptions(readOnly: true));

    int addedCust = 0, skipCust = 0, addedLoc = 0, addedPhotos = 0, addedShifts = 0;

    try {
      if (mode == RestoreMode.fullReplace) {
        await appDb.checkpoint();
        await appDb.close();
        final targetPath = await appDb.getDatabasePath();
        final targetFile = File(targetPath);
        if (targetFile.existsSync()) await targetFile.delete();
        await tempDbFile.copy(targetPath);
        await appDb.database;

        if (preview.includePhotos) {
          if (!photosDir.existsSync()) photosDir.createSync(recursive: true);
          for (final f in archive) {
            if (f.name.startsWith('photos/') && !f.isDirectory) {
              final bName = p.basename(f.name);
              await File(p.join(photosDir.path, bName)).writeAsBytes(f.content as List<int>, flush: true);
              addedPhotos++;
            }
          }
        }
        return RestoreResult(mode: mode, addedCustomers: preview.customersCount, addedLocations: preview.savedLocationsCount, addedPhotos: addedPhotos, addedShifts: preview.shiftsCount, message: 'Khôi phục toàn bộ thành công');
      }

      // RestoreMode.merge
      final targetDb = await appDb.database;
      final srcCustomers = await srcDb.query('customers');

      for (final c in srcCustomers) {
        final phone = c['phone_number'] as String;
        final existing = await targetDb.query('customers', where: 'phone_number = ?', whereArgs: [phone]);
        if (existing.isNotEmpty) {
          skipCust++;
          continue;
        }
        final cId = c['id'] as String;
        await targetDb.insert('customers', Map<String, dynamic>.from(c), conflictAlgorithm: ConflictAlgorithm.ignore);
        addedCust++;

        final locs = await srcDb.query('saved_locations', where: 'customer_id = ?', whereArgs: [cId]);
        for (final l in locs) {
          await targetDb.insert('saved_locations', Map<String, dynamic>.from(l), conflictAlgorithm: ConflictAlgorithm.ignore);
          addedLoc++;
        }

        final photos = await srcDb.query('customer_photos', where: 'customer_id = ?', whereArgs: [cId]);
        for (final ph in photos) {
          await targetDb.insert('customer_photos', Map<String, dynamic>.from(ph), conflictAlgorithm: ConflictAlgorithm.ignore);
          addedPhotos++;
        }
      }

      final srcShifts = await srcDb.query('shifts');
      for (final s in srcShifts) {
        final sId = s['id'] as String;
        final exist = await targetDb.query('shifts', where: 'id = ?', whereArgs: [sId]);
        if (exist.isEmpty) {
          await targetDb.insert('shifts', Map<String, dynamic>.from(s), conflictAlgorithm: ConflictAlgorithm.ignore);
          addedShifts++;
          final items = await srcDb.query('shift_delivery_points', where: 'shift_id = ?', whereArgs: [sId]);
          for (final it in items) {
            await targetDb.insert('shift_delivery_points', Map<String, dynamic>.from(it), conflictAlgorithm: ConflictAlgorithm.ignore);
          }
        }
      }

      if (preview.includePhotos && photosDir.existsSync()) {
        for (final f in archive) {
          if (f.name.startsWith('photos/') && !f.isDirectory) {
            final targetF = File(p.join(photosDir.path, p.basename(f.name)));
            if (!targetF.existsSync()) {
              await targetF.writeAsBytes(f.content as List<int>, flush: true);
            }
          }
        }
      }

      return RestoreResult(mode: mode, addedCustomers: addedCust, skippedCustomers: skipCust, addedLocations: addedLoc, addedPhotos: addedPhotos, addedShifts: addedShifts, message: 'Gộp dữ liệu thành công');
    } finally {
      await srcDb.close();
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    }
  }
}

