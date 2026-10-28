import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:delivery_marker_mobile/data/local/app_database.dart';
import 'package:delivery_marker_mobile/data/local/backup_models.dart';

/// Helper xử lý nén, giải nén và kiểm tra an toàn tệp ZIP sao lưu (.dbackup)
class BackupZipHelpers {
  /// Kiểm tra chống tấn công Path Traversal trong file ZIP sao lưu.
  static void assertNoPathTraversal(Archive archive) {
    for (final file in archive) {
      final name = file.name.replaceAll('\\', '/');
      if (name.contains('../') || name.contains('..') || name.startsWith('/') || name.contains(':')) {
        throw const FormatException('Phát hiện đường dẫn bất thường (Path Traversal) trong file sao lưu.');
      }
    }
  }

  /// Đọc và xác thực tính toàn vẹn của tệp sao lưu trước khi phục hồi.
  static Future<BackupPreview> readBackupPreview(File zipFile) async {
    if (!zipFile.existsSync()) {
      throw ArgumentError('Tệp sao lưu không tồn tại');
    }
    final bytes = await zipFile.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    // 1. Chống Path Traversal
    assertNoPathTraversal(archive);

    // 2. Tìm manifest.json
    final manifestFile = archive.findFile('manifest.json');
    if (manifestFile == null) {
      throw const FormatException('File sao lưu không hợp lệ: Thiếu tệp manifest.json.');
    }
    final manifestJson = jsonDecode(utf8.decode(manifestFile.content as List<int>)) as Map<String, dynamic>;

    // 3. Tìm database.db
    final dbFile = archive.findFile('database.db');
    if (dbFile == null) {
      throw const FormatException('File sao lưu không hợp lệ: Thiếu tệp database.db.');
    }

    // 4. Kiểm tra phiên bản schema
    final fileSchemaVersion = manifestJson['schemaVersion'] as int? ?? 1;
    if (fileSchemaVersion > AppDatabase.currentVersion) {
      throw FormatException(
        'File sao lưu từ phiên bản CSDL mới hơn (v$fileSchemaVersion > v${AppDatabase.currentVersion}). Vui lòng nâng cấp ứng dụng trước khi khôi phục.',
      );
    }

    // 5. Kiểm tra mã Checksum SHA-256
    final checksums = (manifestJson['checksums'] as Map<String, dynamic>?) ?? {};
    final expectedDbChecksum = checksums['database.db'] as String?;
    final actualDbChecksum = sha256.convert(dbFile.content as List<int>).toString();
    if (expectedDbChecksum != null && expectedDbChecksum != actualDbChecksum) {
      throw const FormatException('Mã băm CSDL không khớp. Tệp sao lưu có dấu hiệu bị hỏng hoặc bị sửa đổi.');
    }

    final counts = (manifestJson['counts'] as Map<String, dynamic>?) ?? {};
    final createdAtStr = manifestJson['createdAt'] as String? ?? DateTime.now().toUtc().toIso8601String();

    return BackupPreview(
      formatVersion: manifestJson['formatVersion'] as int? ?? 1,
      schemaVersion: fileSchemaVersion,
      appVersion: manifestJson['appVersion'] as String? ?? '1.0.0',
      createdAt: DateTime.parse(createdAtStr),
      includePhotos: manifestJson['includePhotos'] as bool? ?? false,
      customersCount: counts['customers'] as int? ?? 0,
      savedLocationsCount: counts['savedLocations'] as int? ?? 0,
      shiftsCount: counts['shifts'] as int? ?? 0,
      photosCount: counts['photos'] as int? ?? 0,
      fileSizeBytes: zipFile.lengthSync(),
      rawManifest: manifestJson,
    );
  }

  /// Khôi phục dữ liệu từ tệp ZIP vào SQLite và thư mục ảnh
  static Future<RestoreResult> executeRestore({
    required File zipFile,
    required RestoreMode mode,
    required AppDatabase appDb,
    required Directory photosDir,
  }) async {
    final preview = await readBackupPreview(zipFile);
    final bytes = await zipFile.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    final dbEntry = archive.findFile('database.db')!;
    final dbBytes = dbEntry.content as List<int>;

    final tempDir = Directory.systemTemp.createTempSync('restore_src_');
    final tempDbFile = File(p.join(tempDir.path, 'source_backup.db'));
    await tempDbFile.writeAsBytes(dbBytes, flush: true);

    final effectiveFactory = appDb.factory ?? databaseFactory;
    final Database sourceDb = await effectiveFactory.openDatabase(
      tempDbFile.path,
      options: OpenDatabaseOptions(readOnly: true),
    );

    try {
      final currentDb = await appDb.database;

      if (mode == RestoreMode.fullReplace) {
        final dbPath = await appDb.getDatabasePath();
        final safetyBackupFile = File('$dbPath.safety_backup_${DateTime.now().millisecondsSinceEpoch}');
        final currentDbFile = File(dbPath);
        if (currentDbFile.existsSync()) {
          await currentDbFile.copy(safetyBackupFile.path);
        }

        try {
          await currentDb.transaction((txn) async {
            await txn.delete('customer_photos');
            await txn.delete('shift_delivery_points');
            await txn.delete('shifts');
            await txn.delete('location_history');
            await txn.delete('saved_locations');
            await txn.delete('customers');
            await txn.delete('activity_log');
            await txn.delete('app_profile');
            await txn.delete('app_meta');

            for (final table in [
              'customers',
              'saved_locations',
              'customer_photos',
              'shifts',
              'shift_delivery_points',
              'location_history',
              'app_profile',
              'app_meta',
              'activity_log',
            ]) {
              final rows = await sourceDb.query(table);
              for (final row in rows) {
                await txn.insert(table, row);
              }
            }
          });

          if (safetyBackupFile.existsSync()) {
            try {
              safetyBackupFile.deleteSync();
            } catch (_) {}
          }
        } catch (e) {
          if (safetyBackupFile.existsSync()) {
            await safetyBackupFile.copy(dbPath);
          }
          rethrow;
        }

        if (photosDir.existsSync()) {
          try {
            photosDir.deleteSync(recursive: true);
          } catch (_) {}
        }
        photosDir.createSync(recursive: true);

        if (preview.includePhotos) {
          for (final file in archive) {
            final name = file.name.replaceAll('\\', '/');
            if (name.startsWith('photos/') && !name.endsWith('/')) {
              final rel = name.substring('photos/'.length);
              final destFile = File(p.join(photosDir.path, rel));
              destFile.parent.createSync(recursive: true);
              destFile.writeAsBytesSync(file.content as List<int>, flush: true);
            }
          }
        }

        await appDb.logActivity(
          action: 'RESTORE_BACKUP_REPLACE',
          entity: 'system',
          details: {
            'formatVersion': preview.formatVersion,
            'customersCount': preview.customersCount,
            'savedLocationsCount': preview.savedLocationsCount,
            'shiftsCount': preview.shiftsCount,
            'photosCount': preview.photosCount,
          },
        );

        return RestoreResult(
          mode: RestoreMode.fullReplace,
          addedCustomers: preview.customersCount,
          addedLocations: preview.savedLocationsCount,
          addedShifts: preview.shiftsCount,
          addedPhotos: preview.photosCount,
          message: 'Khôi phục hoàn tất. Đã thay thế toàn bộ dữ liệu bằng bản sao lưu.',
        );
      } else {
        int addedCustomers = 0;
        int skippedCustomers = 0;
        int addedLocations = 0;
        int addedPhotos = 0;
        int addedShifts = 0;

        final customerIdMap = <String, String>{};

        await currentDb.transaction((txn) async {
          final sourceCustomers = await sourceDb.query('customers');
          for (final sc in sourceCustomers) {
            final phone = sc['phone_number'] as String;
            final existing = await txn.query('customers', where: 'phone_number = ?', whereArgs: [phone]);

            if (existing.isNotEmpty) {
              skippedCustomers++;
              customerIdMap[sc['id'] as String] = existing.first['id'] as String;

              final existingLoc = await txn.query(
                'saved_locations',
                where: 'customer_id = ?',
                whereArgs: [existing.first['id']],
              );
              if (existingLoc.isEmpty) {
                final sourceLoc = await sourceDb.query(
                  'saved_locations',
                  where: 'customer_id = ?',
                  whereArgs: [sc['id']],
                );
                if (sourceLoc.isNotEmpty) {
                  final newLoc = Map<String, dynamic>.from(sourceLoc.first);
                  newLoc['id'] = AppDatabase.generateId();
                  newLoc['customer_id'] = existing.first['id'];
                  await txn.insert('saved_locations', newLoc);
                  addedLocations++;
                }
              }
            } else {
              final newCust = Map<String, dynamic>.from(sc);
              await txn.insert('customers', newCust);
              customerIdMap[sc['id'] as String] = sc['id'] as String;
              addedCustomers++;

              final sourceLoc = await sourceDb.query(
                'saved_locations',
                where: 'customer_id = ?',
                whereArgs: [sc['id']],
              );
              if (sourceLoc.isNotEmpty) {
                await txn.insert('saved_locations', sourceLoc.first);
                addedLocations++;
              }
            }

            final currentPhotosCount = Sqflite.firstIntValue(
              await txn.rawQuery(
                'SELECT COUNT(*) FROM customer_photos WHERE customer_id = ? AND deleted_at IS NULL',
                [customerIdMap[sc['id']]],
              ),
            ) ?? 0;

            final sourcePhotos = await sourceDb.query(
              'customer_photos',
              where: 'customer_id = ? AND deleted_at IS NULL',
              whereArgs: [sc['id']],
            );

            int allowedAdd = 10 - currentPhotosCount;
            for (final sp in sourcePhotos) {
              if (allowedAdd <= 0) break;
              final fileName = sp['file_name'] as String;
              final existingPhoto = await txn.query('customer_photos', where: 'file_name = ?', whereArgs: [fileName]);
              if (existingPhoto.isEmpty) {
                final newPhotoRow = Map<String, dynamic>.from(sp);
                newPhotoRow['id'] = AppDatabase.generateId();
                newPhotoRow['customer_id'] = customerIdMap[sc['id']];
                await txn.insert('customer_photos', newPhotoRow);
                addedPhotos++;
                allowedAdd--;
              }
            }
          }

          final sourceShifts = await sourceDb.query('shifts');
          for (final ss in sourceShifts) {
            final shiftCode = ss['shift_code'] as String;
            final existingShift = await txn.query('shifts', where: 'shift_code = ?', whereArgs: [shiftCode]);
            if (existingShift.isEmpty) {
              await txn.insert('shifts', ss);
              addedShifts++;

              final sourcePoints = await sourceDb.query(
                'shift_delivery_points',
                where: 'shift_id = ?',
                whereArgs: [ss['id']],
              );
              for (final sp in sourcePoints) {
                final pointCustomerOldId = sp['customer_id'] as String;
                final resolvedCustomerId = customerIdMap[pointCustomerOldId] ?? pointCustomerOldId;
                final newPoint = Map<String, dynamic>.from(sp);
                newPoint['id'] = AppDatabase.generateId();
                newPoint['customer_id'] = resolvedCustomerId;
                await txn.insert('shift_delivery_points', newPoint);
              }
            }
          }
        });

        if (preview.includePhotos) {
          for (final file in archive) {
            final name = file.name.replaceAll('\\', '/');
            if (name.startsWith('photos/') && !name.endsWith('/')) {
              final rel = name.substring('photos/'.length);
              final destFile = File(p.join(photosDir.path, rel));
              if (!destFile.existsSync()) {
                destFile.parent.createSync(recursive: true);
                destFile.writeAsBytesSync(file.content as List<int>, flush: true);
              }
            }
          }
        }

        await appDb.logActivity(
          action: 'RESTORE_BACKUP_MERGE',
          entity: 'system',
          details: {
            'addedCustomers': addedCustomers,
            'skippedCustomers': skippedCustomers,
            'addedLocations': addedLocations,
            'addedPhotos': addedPhotos,
            'addedShifts': addedShifts,
          },
        );

        return RestoreResult(
          mode: RestoreMode.merge,
          addedCustomers: addedCustomers,
          skippedCustomers: skippedCustomers,
          addedLocations: addedLocations,
          addedPhotos: addedPhotos,
          addedShifts: addedShifts,
          message: 'Gộp thành công $addedCustomers khách mới ($skippedCustomers khách đã có sẵn được giữ nguyên).',
        );
      }
    } finally {
      await sourceDb.close();
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    }
  }
}
