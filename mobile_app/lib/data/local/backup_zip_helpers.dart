import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:delivery_marker_mobile/data/local/app_database.dart';
import 'package:delivery_marker_mobile/data/local/backup_service.dart';

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
