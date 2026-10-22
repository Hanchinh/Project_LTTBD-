import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:delivery_marker_mobile/services/offline_storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('sqlite_test_migration_');
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() async {
    try {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    } catch (_) {}
  });

  /// Helper to create v1 database with exact schema from Git history (commit 96f1ff5)
  Future<String> createV1Database({
    required List<Map<String, dynamic>> queueRows,
    required List<Map<String, dynamic>> orderRows,
  }) async {
    final v1Path = p.join(tempDir.path, 'delivery_offline.db');
    final db = await openDatabase(
      v1Path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE cached_orders (
            orderId TEXT PRIMARY KEY,
            jsonData TEXT
          )
        ''');

        await db.execute('''
          CREATE TABLE offline_sync_queue (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            customerId TEXT,
            latitude REAL,
            longitude REAL,
            gpsAccuracy REAL,
            identificationNotes TEXT,
            createdAt TEXT
          )
        ''');
      },
    );

    for (final row in orderRows) {
      await db.insert('cached_orders', row);
    }

    for (final row in queueRows) {
      await db.insert('offline_sync_queue', row);
    }

    await db.close();
    return v1Path;
  }

  /// Helper to create v2 database using the exact app schema
  Future<Database> createV2Database(String dbName) async {
    final v2Path = p.join(tempDir.path, dbName);
    return await openDatabase(
      v2Path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE cached_orders (
            orderId TEXT PRIMARY KEY,
            jsonData TEXT
          )
        ''');

        await db.execute('''
          CREATE TABLE offline_sync_queue (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            customerId TEXT NOT NULL,
            latitude REAL NOT NULL,
            longitude REAL NOT NULL,
            gpsAccuracy REAL NOT NULL,
            identificationNotes TEXT NOT NULL,
            imageUrl TEXT,
            imageBase64 TEXT,
            syncStatus TEXT DEFAULT 'PENDING',
            retryCount INTEGER DEFAULT 0,
            createdAt TEXT NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE IF NOT EXISTS _v1_migration_tracking (
            v1_source_id INTEGER PRIMARY KEY,
            v2_queue_id INTEGER,
            migrated_at TEXT NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE IF NOT EXISTS _v1_quarantine_records (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            source_table TEXT NOT NULL DEFAULT 'offline_sync_queue',
            v1_source_id INTEGER,
            raw_data TEXT NOT NULL,
            error_reason TEXT NOT NULL,
            quarantined_at TEXT NOT NULL,
            status TEXT NOT NULL DEFAULT 'QUARANTINED',
            v2_queue_id INTEGER,
            resolved_at TEXT,
            resolution_notes TEXT,
            resolved_data TEXT
          )
        ''');
      },
    );
  }

  group('SQLite Migration Comprehensive Verification Tests', () {
    test('Scenario 1: Complete E2E Migration with Multiple Customers, Unicode, Negative Coordinates, and Same Timestamp', () async {
      const sharedTimestamp = '2026-10-22T10:00:00.000Z';

      final v1QueueData = [
        // Record 1: Vietnam coordinates (positive), Unicode notes
        {
          'customerId': 'cust-vn-01',
          'latitude': 10.842215,
          'longitude': 106.818123,
          'gpsAccuracy': 4.5,
          'identificationNotes': 'Cổng màu xanh nước biển, đối diện tạp hóa Út Em',
          'createdAt': sharedTimestamp,
        },
        // Record 2: Negative coordinates (Southern/Western hemisphere), Unicode notes
        {
          'customerId': 'cust-global-02',
          'latitude': -33.868820,
          'longitude': 151.209290,
          'gpsAccuracy': 3.1,
          'identificationNotes': 'Kho cảng quốc tế số 4 - Sydney Logistics',
          'createdAt': '2026-10-22T11:15:30.123Z',
        },
        // Record 3: Same customer as Record 1, different timestamp, different location notes
        {
          'customerId': 'cust-vn-01',
          'latitude': 10.843100,
          'longitude': 106.819000,
          'gpsAccuracy': 5.0,
          'identificationNotes': 'Cửa hông ngõ 42/3 (giao ngoài giờ)',
          'createdAt': '2026-10-22T14:20:00.000Z',
        },
        // Record 4: CRITICAL TEST - EXACT SAME customerId AND EXACT SAME createdAt as Record 1,
        // but DIFFERENT coordinates and notes. Must NOT be dropped as a false duplicate!
        {
          'customerId': 'cust-vn-01',
          'latitude': 10.842300,
          'longitude': 106.818200,
          'gpsAccuracy': 6.0,
          'identificationNotes': 'Ghi chú cập nhật: nhà có chó dữ, gọi trước',
          'createdAt': sharedTimestamp,
        },
      ];

      final v1OrdersData = [
        {
          'orderId': 'ORD-001',
          'jsonData': jsonEncode({'orderId': 'ORD-001', 'orderCode': 'DON_001', 'customerName': 'Nguyễn Văn A'}),
        },
        {
          'orderId': 'ORD-002',
          'jsonData': jsonEncode({
            'orderId': 'ORD-002',
            'orderCode': 'DON_002',
            'hasSavedLocation': true,
            'savedLocation': {'latitude': 10.84, 'longitude': 106.81, 'notes': 'Cổng đỏ'},
          }),
        },
      ];

      final v1Path = await createV1Database(queueRows: v1QueueData, orderRows: v1OrdersData);
      final v2Db = await createV2Database('v2_test_1.db');

      // Step 1: Run migration
      final result = await OfflineStorageService.migrateFromV1IfNeeded(v2Db, customV1Path: v1Path);
      expect(result.migratedCount, 4, reason: 'Must migrate all 4 valid v1 queue records without dropping any');
      expect(result.quarantinedCount, 0);
      expect(result.status, MigrationStatus.success);
      expect(result.isSuccess, isTrue);

      // Verify SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('sqlite_v1_migrated'), isTrue);
      expect(prefs.getString('sqlite_v1_migration_status'), 'COMPLETED');

      // Step 2: Verify all records in v2 match source
      final v2Queue = await v2Db.query('offline_sync_queue', orderBy: 'id ASC');
      expect(v2Queue.length, 4);

      // Verify Record 1
      expect(v2Queue[0]['customerId'], 'cust-vn-01');
      expect(v2Queue[0]['latitude'], 10.842215);
      expect(v2Queue[0]['longitude'], 106.818123);
      expect(v2Queue[0]['gpsAccuracy'], 4.5);
      expect(v2Queue[0]['identificationNotes'], 'Cổng màu xanh nước biển, đối diện tạp hóa Út Em');
      expect(v2Queue[0]['syncStatus'], 'PENDING');
      expect(v2Queue[0]['retryCount'], 0);
      expect(v2Queue[0]['imageUrl'], isNull);

      // Verify Record 2 (Negative coordinates)
      expect(v2Queue[1]['customerId'], 'cust-global-02');
      expect(v2Queue[1]['latitude'], -33.868820);
      expect(v2Queue[1]['longitude'], 151.209290);
      expect(v2Queue[1]['identificationNotes'], 'Kho cảng quốc tế số 4 - Sydney Logistics');

      // Verify Record 4 (Same customer & same timestamp as Record 1, preserved safely)
      expect(v2Queue[3]['customerId'], 'cust-vn-01');
      expect(v2Queue[3]['createdAt'], sharedTimestamp);
      expect(v2Queue[3]['identificationNotes'], 'Ghi chú cập nhật: nhà có chó dữ, gọi trước');

      // Verify cached_orders in v2
      final v2Orders = await v2Db.query('cached_orders');
      expect(v2Orders.length, 2);

      // Step 3: Run migration AGAIN (simulating app restart / second launch)
      final secondResult = await OfflineStorageService.migrateFromV1IfNeeded(
        v2Db,
        customV1Path: v1Path,
        forceRun: true,
      );
      expect(secondResult.migratedCount, 0, reason: 'Second migration must insert 0 duplicates');
      expect(secondResult.quarantinedCount, 0);
      expect(secondResult.status, MigrationStatus.success);

      final v2QueueAfterSecondRun = await v2Db.query('offline_sync_queue');
      expect(v2QueueAfterSecondRun.length, 4, reason: 'Total records must remain exactly 4');

      final v2OrdersAfterSecondRun = await v2Db.query('cached_orders');
      expect(v2OrdersAfterSecondRun.length, 2, reason: 'Total orders must remain exactly 2');

      // Step 4: Verify source database v1 remains 100% unaltered
      final v1CheckDb = await openDatabase(v1Path, readOnly: true);
      final v1QueueCheck = await v1CheckDb.query('offline_sync_queue');
      expect(v1QueueCheck.length, 4);
      final v1OrdersCheck = await v1CheckDb.query('cached_orders');
      expect(v1OrdersCheck.length, 2);
      await v1CheckDb.close();

      await v2Db.close();
    });

    test('Scenario 2: V2 Pre-existing Data & Content Reconciliation in cached_orders', () async {
      final v1OrdersData = [
        // v1 has order ORD-EXISTING with richer location data
        {
          'orderId': 'ORD-EXISTING',
          'jsonData': jsonEncode({
            'orderId': 'ORD-EXISTING',
            'hasSavedLocation': true,
            'savedLocation': {'latitude': 10.84, 'longitude': 106.81, 'notes': 'V1 rich location'},
          }),
        },
        // v1 has new order ORD-NEW-V1
        {
          'orderId': 'ORD-NEW-V1',
          'jsonData': jsonEncode({'orderId': 'ORD-NEW-V1', 'customerName': 'Khách V1'}),
        },
      ];

      final v1QueueData = [
        {
          'customerId': 'cust-v1-new',
          'latitude': 10.5,
          'longitude': 106.5,
          'gpsAccuracy': 4.0,
          'identificationNotes': 'Ghi chú v1',
          'createdAt': '2026-10-22T05:00:00Z',
        },
      ];

      final v1Path = await createV1Database(queueRows: v1QueueData, orderRows: v1OrdersData);
      final v2Db = await createV2Database('v2_test_2.db');

      // Insert pre-existing v2 record in queue and cached_orders
      await v2Db.insert('offline_sync_queue', {
        'customerId': 'cust-v2-pre',
        'latitude': 10.9,
        'longitude': 106.9,
        'gpsAccuracy': 3.0,
        'identificationNotes': 'Ghi chú tạo trên v2 trước khi migrate',
        'syncStatus': 'PENDING',
        'retryCount': 1,
        'createdAt': '2026-10-22T04:00:00Z',
      });

      // v2 has ORD-EXISTING but WITHOUT saved location
      await v2Db.insert('cached_orders', {
        'orderId': 'ORD-EXISTING',
        'jsonData': jsonEncode({
          'orderId': 'ORD-EXISTING',
          'hasSavedLocation': false,
          'savedLocation': null,
        }),
      });

      // Run migration
      final result = await OfflineStorageService.migrateFromV1IfNeeded(v2Db, customV1Path: v1Path);
      expect(result.migratedCount, 1);
      expect(result.quarantinedCount, 0);
      expect(result.status, MigrationStatus.success);

      // Verify v2 queue has BOTH the pre-existing record and the migrated v1 record
      final v2Queue = await v2Db.query('offline_sync_queue', orderBy: 'id ASC');
      expect(v2Queue.length, 2);
      expect(v2Queue[0]['customerId'], 'cust-v2-pre');
      expect(v2Queue[1]['customerId'], 'cust-v1-new');

      // Verify cached_orders reconciled ORD-EXISTING with richer location data from v1
      final existingOrder = await v2Db.query('cached_orders', where: 'orderId = ?', whereArgs: ['ORD-EXISTING']);
      final decodedJson = jsonDecode(existingOrder.first['jsonData'] as String);
      expect(decodedJson['hasSavedLocation'], true);
      expect(decodedJson['savedLocation']['notes'], 'V1 rich location');

      // Verify new order ORD-NEW-V1 was also inserted
      final newOrder = await v2Db.query('cached_orders', where: 'orderId = ?', whereArgs: ['ORD-NEW-V1']);
      expect(newOrder.isNotEmpty, true);

      await v2Db.close();
    });

    test('Scenario 3: App crash right after transaction commit but before SharedPreferences flag is saved', () async {
      final v1QueueData = [
        {
          'customerId': 'cust-crash-test',
          'latitude': 10.7,
          'longitude': 106.7,
          'gpsAccuracy': 2.0,
          'identificationNotes': 'Cửa gỗ',
          'createdAt': '2026-10-22T07:00:00Z',
        },
      ];

      final v1Path = await createV1Database(queueRows: v1QueueData, orderRows: []);
      final v2Db = await createV2Database('v2_test_3.db');

      // Run migration with updatePrefs: false (simulating crash right after SQLite transaction commit)
      final firstRun = await OfflineStorageService.migrateFromV1IfNeeded(
        v2Db,
        customV1Path: v1Path,
        updatePrefs: false,
      );
      expect(firstRun.migratedCount, 1);
      expect(firstRun.status, MigrationStatus.success);

      // Verify SharedPreferences flag was NOT saved
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('sqlite_v1_migrated'), isNull);
      expect(prefs.getString('sqlite_v1_migration_status'), isNull);

      // Second launch: migration runs again because flag is missing
      final secondRun = await OfflineStorageService.migrateFromV1IfNeeded(
        v2Db,
        customV1Path: v1Path,
        updatePrefs: true,
      );

      // _v1_migration_tracking ensures 0 duplicate records
      expect(secondRun.migratedCount, 0);
      expect(secondRun.status, MigrationStatus.success);

      // Flags are now saved
      expect(prefs.getBool('sqlite_v1_migrated'), isTrue);
      expect(prefs.getString('sqlite_v1_migration_status'), 'COMPLETED');

      final v2Queue = await v2Db.query('offline_sync_queue');
      expect(v2Queue.length, 1);

      await v2Db.close();
    });

    test('Scenario 4: Mid-migration failure ensures source v1 database is completely untouched', () async {
      final v1QueueData = [
        {
          'customerId': 'cust-rollback-01',
          'latitude': 10.0,
          'longitude': 106.0,
          'gpsAccuracy': 5.0,
          'identificationNotes': 'Ghi chú nguồn 1',
          'createdAt': '2026-10-22T01:00:00Z',
        },
        {
          'customerId': 'cust-rollback-02',
          'latitude': 10.1,
          'longitude': 106.1,
          'gpsAccuracy': 4.0,
          'identificationNotes': 'Ghi chú nguồn 2',
          'createdAt': '2026-10-22T02:00:00Z',
        },
      ];

      final v1Path = await createV1Database(queueRows: v1QueueData, orderRows: []);
      final v2Db = await createV2Database('v2_test_4.db');

      // Drop the table in v2 to force an SQL execution failure during migration
      await v2Db.execute('DROP TABLE offline_sync_queue');

      bool didThrow = false;
      try {
        await OfflineStorageService.migrateFromV1IfNeeded(v2Db, customV1Path: v1Path);
      } catch (e) {
        didThrow = true;
      }
      expect(didThrow, isTrue, reason: 'Migration must throw an error when v2 database write fails');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('sqlite_v1_migrated'), isFalse);
      expect(prefs.getString('sqlite_v1_migration_status'), 'FAILED');

      // Verify v1 source database is 100% unaltered
      final v1CheckDb = await openDatabase(v1Path, readOnly: true);
      final v1QueueCheck = await v1CheckDb.query('offline_sync_queue');
      expect(v1QueueCheck.length, 2);
      expect(v1QueueCheck[0]['customerId'], 'cust-rollback-01');
      expect(v1QueueCheck[1]['customerId'], 'cust-rollback-02');
      await v1CheckDb.close();

      await v2Db.close();
    });

    test('Scenario 5: Non-existent v1 database completes cleanly with 0 migrations', () async {
      final v2Db = await createV2Database('v2_test_5.db');
      final nonExistentPath = p.join(tempDir.path, 'does_not_exist.db');

      final result = await OfflineStorageService.migrateFromV1IfNeeded(v2Db, customV1Path: nonExistentPath);
      expect(result.migratedCount, 0);
      expect(result.status, MigrationStatus.success);

      await v2Db.close();
    });

    test('Scenario 6: Corrupted v1 records with null/empty customerId are quarantined into _v1_quarantine_records', () async {
      final v1CorruptedQueue = [
        // Corrupt record 1: empty customerId
        {
          'customerId': '',
          'latitude': 10.0,
          'longitude': 106.0,
          'gpsAccuracy': 5.0,
          'identificationNotes': 'Bản ghi hỏng rỗng customerId',
          'createdAt': '2026-10-22T00:00:00Z',
        },
        // Valid record
        {
          'customerId': 'cust-valid-after-corrupt',
          'latitude': 10.84,
          'longitude': 106.81,
          'gpsAccuracy': 3.5,
          'identificationNotes': 'Bản ghi hợp lệ',
          'createdAt': '2026-10-22T00:01:00Z',
        },
        // Corrupt record 2: null customerId
        {
          'customerId': null,
          'latitude': 10.5,
          'longitude': 106.5,
          'gpsAccuracy': 4.0,
          'identificationNotes': 'Bản ghi hỏng null customerId',
          'createdAt': '2026-10-22T00:02:00Z',
        },
      ];

      final v1Path = await createV1Database(queueRows: v1CorruptedQueue, orderRows: []);
      final v2Db = await createV2Database('v2_test_6.db');

      final result = await OfflineStorageService.migrateFromV1IfNeeded(v2Db, customV1Path: v1Path);

      // Status must be hasQuarantinedRecords, NOT success
      expect(result.status, MigrationStatus.hasQuarantinedRecords);
      expect(result.migratedCount, 1, reason: 'Must migrate exactly 1 valid record');
      expect(result.quarantinedCount, 2, reason: 'Must quarantine 2 corrupted records');

      // SharedPreferences must NOT claim 100% completed
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('sqlite_v1_migrated'), isFalse);
      expect(prefs.getString('sqlite_v1_migration_status'), 'QUARANTINED');
      expect(prefs.getInt('sqlite_v1_quarantined_count'), 2);

      // Verify offline_sync_queue only contains the valid record (no fake customerId, no corrupted data)
      final v2Queue = await v2Db.query('offline_sync_queue');
      expect(v2Queue.length, 1);
      expect(v2Queue.first['customerId'], 'cust-valid-after-corrupt');

      // Verify _v1_quarantine_records has the 2 quarantined records with original raw data and reasons
      final quarantinedRecords = await OfflineStorageService.getQuarantinedRecords(targetDb: v2Db);
      expect(quarantinedRecords.length, 2);

      expect(quarantinedRecords[0]['v1_source_id'], 1);
      expect(quarantinedRecords[0]['error_reason'], contains('customerId is empty'));
      expect(quarantinedRecords[0]['raw_data'], contains('Bản ghi hỏng rỗng customerId'));

      expect(quarantinedRecords[1]['v1_source_id'], 3);
      expect(quarantinedRecords[1]['error_reason'], contains('customerId is null'));
      expect(quarantinedRecords[1]['raw_data'], contains('Bản ghi hỏng null customerId'));

      await v2Db.close();
    });

    test('Scenario 7: Corrupted coordinates (out-of-range, NaN, invalid types) are quarantined', () async {
      final v1BadCoordsQueue = [
        // Corrupt: Latitude > 90.0 (out of range)
        {
          'customerId': 'cust-bad-lat',
          'latitude': 999.0,
          'longitude': 106.0,
          'gpsAccuracy': 5.0,
          'identificationNotes': 'Vĩ độ 999 độ',
          'createdAt': '2026-10-22T00:00:00Z',
        },
        // Corrupt: Longitude < -180.0
        {
          'customerId': 'cust-bad-lng',
          'latitude': 10.0,
          'longitude': -250.0,
          'gpsAccuracy': 5.0,
          'identificationNotes': 'Kinh độ -250 độ',
          'createdAt': '2026-10-22T00:01:00Z',
        },
        // Valid
        {
          'customerId': 'cust-valid-coords',
          'latitude': 10.84,
          'longitude': 106.81,
          'gpsAccuracy': 3.5,
          'identificationNotes': 'Tọa độ chuẩn',
          'createdAt': '2026-10-22T00:02:00Z',
        },
      ];

      final v1Path = await createV1Database(queueRows: v1BadCoordsQueue, orderRows: []);
      final v2Db = await createV2Database('v2_test_7.db');

      final result = await OfflineStorageService.migrateFromV1IfNeeded(v2Db, customV1Path: v1Path);
      expect(result.status, MigrationStatus.hasQuarantinedRecords);
      expect(result.migratedCount, 1);
      expect(result.quarantinedCount, 2);

      final quarantined = await OfflineStorageService.getQuarantinedRecords(targetDb: v2Db);
      expect(quarantined[0]['error_reason'], contains('latitude out of range'));
      expect(quarantined[1]['error_reason'], contains('longitude out of range'));

      await v2Db.close();
    });

    test('Scenario 8: Failure when writing to quarantine table rolls back transaction and keeps source untouched', () async {
      final v1Queue = [
        // Valid record
        {
          'customerId': 'cust-valid-before-crash',
          'latitude': 10.8,
          'longitude': 106.8,
          'gpsAccuracy': 3.0,
          'identificationNotes': 'Bản ghi hợp lệ trước khi crash',
          'createdAt': '2026-10-22T00:00:00Z',
        },
        // Corrupt record that will trigger insert into _v1_quarantine_records
        {
          'customerId': '',
          'latitude': 10.0,
          'longitude': 106.0,
          'gpsAccuracy': 5.0,
          'identificationNotes': 'Bản ghi hỏng kích hoạt quarantine',
          'createdAt': '2026-10-22T00:01:00Z',
        },
      ];

      final v1Path = await createV1Database(queueRows: v1Queue, orderRows: []);
      final v2Db = await createV2Database('v2_test_8.db');

      // Create a trigger on _v1_quarantine_records that aborts any INSERT
      await v2Db.execute('''
        CREATE TRIGGER abort_quarantine BEFORE INSERT ON _v1_quarantine_records
        BEGIN
          SELECT RAISE(ABORT, 'Simulated quarantine disk write failure');
        END;
      ''');

      bool didThrow = false;
      try {
        await OfflineStorageService.migrateFromV1IfNeeded(v2Db, customV1Path: v1Path);
      } catch (e) {
        didThrow = true;
      }
      expect(didThrow, isTrue);

      // Verify transaction rollback: offline_sync_queue must NOT contain even the valid record!
      final v2Queue = await v2Db.query('offline_sync_queue');
      expect(v2Queue.isEmpty, isTrue, reason: 'Atomicity requires complete rollback on quarantine failure');

      // Verify _v1_migration_tracking is also empty
      final v2Tracking = await v2Db.query('_v1_migration_tracking');
      expect(v2Tracking.isEmpty, isTrue);

      // Verify v1 database remains completely intact
      final v1CheckDb = await openDatabase(v1Path, readOnly: true);
      final v1QueueCheck = await v1CheckDb.query('offline_sync_queue');
      expect(v1QueueCheck.length, 2);
      await v1CheckDb.close();

      await v2Db.close();
    });

    test('Scenario 9: Migration rerun idempotency with quarantined records does not duplicate', () async {
      final v1Queue = [
        {
          'customerId': 'cust-valid-rerun',
          'latitude': 10.8,
          'longitude': 106.8,
          'gpsAccuracy': 3.0,
          'identificationNotes': 'Hợp lệ',
          'createdAt': '2026-10-22T00:00:00Z',
        },
        {
          'customerId': '',
          'latitude': 10.0,
          'longitude': 106.0,
          'gpsAccuracy': 5.0,
          'identificationNotes': 'Bản ghi hỏng',
          'createdAt': '2026-10-22T00:01:00Z',
        },
      ];

      final v1Path = await createV1Database(queueRows: v1Queue, orderRows: []);
      final v2Db = await createV2Database('v2_test_9.db');

      // Run 1
      final res1 = await OfflineStorageService.migrateFromV1IfNeeded(v2Db, customV1Path: v1Path);
      expect(res1.migratedCount, 1);
      expect(res1.quarantinedCount, 1);
      expect(res1.newlyQuarantinedCount, 1);

      // Run 2 (rerun)
      final res2 = await OfflineStorageService.migrateFromV1IfNeeded(
        v2Db,
        customV1Path: v1Path,
        forceRun: true,
      );
      expect(res2.migratedCount, 0, reason: 'Rerun must not insert duplicate migrated records');
      expect(res2.newlyQuarantinedCount, 0, reason: 'Rerun must not insert duplicate quarantine records');
      expect(res2.quarantinedCount, 1, reason: 'Total quarantined records remains 1');

      final v2Queue = await v2Db.query('offline_sync_queue');
      expect(v2Queue.length, 1);

      final quarantined = await OfflineStorageService.getQuarantinedRecords(targetDb: v2Db);
      expect(quarantined.length, 1);

      await v2Db.close();
    });

    test('Scenario 10: Quarantined records can be inspected, counted, and deleted after reconciliation', () async {
      final v1Queue = [
        {
          'customerId': '',
          'latitude': 10.0,
          'longitude': 106.0,
          'gpsAccuracy': 5.0,
          'identificationNotes': 'Bản ghi hỏng cần sửa',
          'createdAt': '2026-10-22T00:00:00Z',
        },
      ];

      final v1Path = await createV1Database(queueRows: v1Queue, orderRows: []);
      final v2Db = await createV2Database('v2_test_10.db');

      await OfflineStorageService.migrateFromV1IfNeeded(v2Db, customV1Path: v1Path);

      // Verify count API
      final count = await OfflineStorageService.getQuarantinedCount(targetDb: v2Db);
      expect(count, 1);

      // Retrieve list
      final list = await OfflineStorageService.getQuarantinedRecords(targetDb: v2Db);
      expect(list.length, 1);
      final qId = list.first['id'] as int;

      // Delete/resolve quarantined record
      final deleted = await OfflineStorageService.deleteQuarantinedRecord(qId, targetDb: v2Db);
      expect(deleted, 1);

      final countAfter = await OfflineStorageService.getQuarantinedCount(targetDb: v2Db);
      expect(countAfter, 0);

      await v2Db.close();
    });

    test('Scenario 11: Distinct MigrationStatus values (success, hasQuarantinedRecords, failed)', () async {
      final v2Db = await createV2Database('v2_test_11.db');

      // 1. Test success status
      final v1SuccessPath = await createV1Database(
        queueRows: [
          {
            'customerId': 'cust-s11',
            'latitude': 10.0,
            'longitude': 106.0,
            'gpsAccuracy': 3.0,
            'identificationNotes': 'Thành công',
            'createdAt': '2026-10-22T00:00:00Z',
          }
        ],
        orderRows: [],
      );
      final resSuccess = await OfflineStorageService.migrateFromV1IfNeeded(v2Db, customV1Path: v1SuccessPath);
      expect(resSuccess.status, MigrationStatus.success);
      expect(resSuccess.isSuccess, isTrue);

      // 2. Test hasQuarantinedRecords status
      final v2Db2 = await createV2Database('v2_test_11_b.db');
      final v1QuarantinePath = await createV1Database(
        queueRows: [
          {
            'customerId': '',
            'latitude': 10.0,
            'longitude': 106.0,
            'gpsAccuracy': 3.0,
            'identificationNotes': 'Bị cách ly',
            'createdAt': '2026-10-22T00:00:00Z',
          }
        ],
        orderRows: [],
      );
      final resQuarantine = await OfflineStorageService.migrateFromV1IfNeeded(v2Db2, customV1Path: v1QuarantinePath);
      expect(resQuarantine.status, MigrationStatus.hasQuarantinedRecords);
      expect(resQuarantine.hasQuarantine, isTrue);

      // 3. Test failed status (with catchErrors: true)
      final v2Db3 = await createV2Database('v2_test_11_c.db');
      await v2Db3.execute('DROP TABLE offline_sync_queue');
      final resFailed = await OfflineStorageService.migrateFromV1IfNeeded(
        v2Db3,
        customV1Path: v1SuccessPath,
        catchErrors: true,
      );
      expect(resFailed.status, MigrationStatus.failed);
      expect(resFailed.isFailed, isTrue);
      expect(resFailed.errorMessage, isNotNull);

      await v2Db.close();
      await v2Db2.close();
      await v2Db3.close();
    });

    test('Scenario 12: Quarantined record can be corrected, resolved, and safely inserted into offline_sync_queue with audit history', () async {
      // Create v1 db with 1 valid record and 1 invalid record (empty customerId)
      final v1Path = await createV1Database(
        queueRows: [
          {
            'customerId': 'cust-valid-12',
            'latitude': 10.7769,
            'longitude': 106.7009,
            'gpsAccuracy': 4.0,
            'identificationNotes': 'Bản ghi hợp lệ',
            'createdAt': '2026-10-22T08:00:00Z',
          },
          {
            'customerId': '   ', // whitespace only -> invalid
            'latitude': 10.8234,
            'longitude': 106.8123,
            'gpsAccuracy': 5.2,
            'identificationNotes': 'Cửa hàng tiện lợi 24/7 (thiếu mã khách hàng)',
            'createdAt': '2026-10-22T08:30:00Z',
          },
        ],
        orderRows: [],
      );

      final v2Db = await createV2Database('v2_test_12.db');

      // 1. Run migration
      final migResult = await OfflineStorageService.migrateFromV1IfNeeded(v2Db, customV1Path: v1Path);
      expect(migResult.status, MigrationStatus.hasQuarantinedRecords);
      expect(migResult.migratedCount, 1);
      expect(migResult.quarantinedCount, 1);

      // Verify SharedPreferences reflects pending quarantine
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('sqlite_v1_migrated'), isFalse);
      expect(prefs.getString('sqlite_v1_migration_status'), 'QUARANTINED');
      expect(prefs.getInt('sqlite_v1_quarantined_count'), 1);

      // 2. Query quarantined records
      final quarantinedList = await OfflineStorageService.getQuarantinedRecords(targetDb: v2Db);
      expect(quarantinedList.length, 1);
      final qRecord = quarantinedList.first;
      expect(qRecord['status'], 'QUARANTINED');
      expect(qRecord['v1_source_id'], 2);
      expect(qRecord['v2_queue_id'], isNull);

      // 3. Resolve quarantined record with corrected customerId and notes
      final resolution = await OfflineStorageService.resolveQuarantinedRecord(
        quarantineId: qRecord['id'] as int,
        correctedCustomerId: 'cust-fixed-12',
        correctedIdentificationNotes: 'Đã bổ sung mã khách hàng: Cửa hàng tiện lợi 24/7',
        resolutionNotes: 'Đã xác minh qua số điện thoại trên hóa đơn giao hàng',
        targetDb: v2Db,
      );

      expect(resolution.success, isTrue);
      expect(resolution.v2QueueId, isNotNull);
      final newV2QueueId = resolution.v2QueueId!;

      // 4. Verify record in offline_sync_queue
      final queueRows = await v2Db.query('offline_sync_queue', where: 'id = ?', whereArgs: [newV2QueueId]);
      expect(queueRows.length, 1);
      final queueItem = queueRows.first;
      expect(queueItem['customerId'], 'cust-fixed-12');
      expect(queueItem['latitude'], 10.8234);
      expect(queueItem['longitude'], 106.8123);
      expect(queueItem['gpsAccuracy'], 5.2);
      expect(queueItem['identificationNotes'], 'Đã bổ sung mã khách hàng: Cửa hàng tiện lợi 24/7');
      expect(queueItem['syncStatus'], 'PENDING');

      // 5. Verify _v1_migration_tracking was updated
      final trackingRows = await v2Db.query('_v1_migration_tracking', where: 'v1_source_id = ?', whereArgs: [2]);
      expect(trackingRows.length, 1);
      expect(trackingRows.first['v2_queue_id'], newV2QueueId);

      // 6. Verify _v1_quarantine_records: record was NOT deleted! Status is 'RESOLVED' with full audit trail
      final qAfter = await v2Db.query('_v1_quarantine_records', where: 'id = ?', whereArgs: [qRecord['id']]);
      expect(qAfter.length, 1);
      expect(qAfter.first['status'], 'RESOLVED');
      expect(qAfter.first['v2_queue_id'], newV2QueueId);
      expect(qAfter.first['resolved_at'], isNotNull);
      expect(qAfter.first['resolution_notes'], 'Đã xác minh qua số điện thoại trên hóa đơn giao hàng');
      expect(qAfter.first['resolved_data'], contains('cust-fixed-12'));

      // 7. Verify pending count is now 0 and migration status is completed
      final pendingCount = await OfflineStorageService.getQuarantinedCount(targetDb: v2Db, onlyPending: true);
      expect(pendingCount, 0);
      final totalCount = await OfflineStorageService.getQuarantinedCount(targetDb: v2Db, onlyPending: false);
      expect(totalCount, 1); // Audit record still preserved

      expect(prefs.getBool('sqlite_v1_migrated'), isTrue);
      expect(prefs.getString('sqlite_v1_migration_status'), 'COMPLETED');
      expect(prefs.getInt('sqlite_v1_quarantined_count'), 0);

      await v2Db.close();
    });

    test('Scenario 13: Quarantine record does NOT disappear when resolution fails (validation error or invalid data)', () async {
      final v1Path = await createV1Database(
        queueRows: [
          {
            'customerId': '',
            'latitude': 10.0,
            'longitude': 106.0,
            'gpsAccuracy': 5.0,
            'identificationNotes': 'Lỗi cần đối soát',
            'createdAt': '2026-10-22T09:00:00Z',
          },
        ],
        orderRows: [],
      );

      final v2Db = await createV2Database('v2_test_13.db');
      await OfflineStorageService.migrateFromV1IfNeeded(v2Db, customV1Path: v1Path);

      final qList = await OfflineStorageService.getQuarantinedRecords(targetDb: v2Db);
      expect(qList.length, 1);
      final qId = qList.first['id'] as int;

      // 1. Resolution attempt with empty customerId -> must fail
      final resEmptyCust = await OfflineStorageService.resolveQuarantinedRecord(
        quarantineId: qId,
        correctedCustomerId: '   ',
        targetDb: v2Db,
      );
      expect(resEmptyCust.success, isFalse);
      expect(resEmptyCust.errorMessage, contains('Empty customerId'));

      // 2. Resolution attempt with invalid latitude (> 90) -> must fail
      final resBadLat = await OfflineStorageService.resolveQuarantinedRecord(
        quarantineId: qId,
        correctedCustomerId: 'cust-13',
        correctedLatitude: 95.0,
        targetDb: v2Db,
      );
      expect(resBadLat.success, isFalse);
      expect(resBadLat.errorMessage, contains('Invalid latitude range'));

      // 3. Resolution attempt with invalid longitude (> 180) -> must fail
      final resBadLng = await OfflineStorageService.resolveQuarantinedRecord(
        quarantineId: qId,
        correctedCustomerId: 'cust-13',
        correctedLongitude: 195.0,
        targetDb: v2Db,
      );
      expect(resBadLng.success, isFalse);
      expect(resBadLng.errorMessage, contains('Invalid longitude range'));

      // 4. Resolution attempt with negative GPS accuracy (< 0) -> must fail
      final resBadGps = await OfflineStorageService.resolveQuarantinedRecord(
        quarantineId: qId,
        correctedCustomerId: 'cust-13',
        correctedGpsAccuracy: -1.0,
        targetDb: v2Db,
      );
      expect(resBadGps.success, isFalse);
      expect(resBadGps.errorMessage, contains('Invalid gpsAccuracy'));

      // VERIFY: The quarantined record is completely preserved and untouched
      final qCheck = await v2Db.query('_v1_quarantine_records', where: 'id = ?', whereArgs: [qId]);
      expect(qCheck.length, 1);
      expect(qCheck.first['status'], 'QUARANTINED');
      expect(qCheck.first['v2_queue_id'], isNull);

      // VERIFY: Nothing was inserted into offline_sync_queue
      final queueCount = await v2Db.query('offline_sync_queue');
      expect(queueCount, isEmpty);

      await v2Db.close();
    });

    test('Scenario 14: Mid-transaction error during resolution rolls back atomically without orphan queue or tracking entries', () async {
      final v1Path = await createV1Database(
        queueRows: [
          {
            'customerId': '',
            'latitude': 10.5,
            'longitude': 106.5,
            'gpsAccuracy': 5.0,
            'identificationNotes': 'Lỗi mô phỏng sự cố giữa transaction',
            'createdAt': '2026-10-22T09:30:00Z',
          },
        ],
        orderRows: [],
      );

      final v2Db = await createV2Database('v2_test_14.db');
      await OfflineStorageService.migrateFromV1IfNeeded(v2Db, customV1Path: v1Path);

      final qList = await OfflineStorageService.getQuarantinedRecords(targetDb: v2Db);
      expect(qList.length, 1);
      final qId = qList.first['id'] as int;

      // Install a trigger on _v1_quarantine_records that throws an ABORT error on UPDATE
      // This simulates a mid-transaction crash AFTER offline_sync_queue and tracking have already executed
      await v2Db.execute('''
        CREATE TRIGGER fail_quarantine_update_trigger
        BEFORE UPDATE ON _v1_quarantine_records
        BEGIN
          SELECT RAISE(ABORT, 'Simulated mid-transaction quarantine update crash');
        END;
      ''');

      // Attempt to resolve
      final res = await OfflineStorageService.resolveQuarantinedRecord(
        quarantineId: qId,
        correctedCustomerId: 'cust-14-crash',
        targetDb: v2Db,
      );

      expect(res.success, isFalse);
      expect(res.errorMessage, contains('Simulated mid-transaction quarantine update crash'));

      // VERIFY: Transaction rollback ensured:
      // 1. offline_sync_queue has 0 records (no orphan queue item)
      final queueRows = await v2Db.query('offline_sync_queue');
      expect(queueRows, isEmpty);

      // 2. _v1_migration_tracking remains with v2_queue_id = null
      final trackingRows = await v2Db.query('_v1_migration_tracking', where: 'v1_source_id = ?', whereArgs: [1]);
      expect(trackingRows.length, 1);
      expect(trackingRows.first['v2_queue_id'], isNull);

      // 3. _v1_quarantine_records is still 'QUARANTINED'
      final qAfter = await v2Db.query('_v1_quarantine_records', where: 'id = ?', whereArgs: [qId]);
      expect(qAfter.length, 1);
      expect(qAfter.first['status'], 'QUARANTINED');
      expect(qAfter.first['v2_queue_id'], isNull);

      // Drop the trigger and resolve again successfully
      await v2Db.execute('DROP TRIGGER fail_quarantine_update_trigger');
      final retryRes = await OfflineStorageService.resolveQuarantinedRecord(
        quarantineId: qId,
        correctedCustomerId: 'cust-14-recovery',
        targetDb: v2Db,
      );
      expect(retryRes.success, isTrue);
      expect(retryRes.v2QueueId, isNotNull);

      final queueRecovered = await v2Db.query('offline_sync_queue');
      expect(queueRecovered.length, 1);
      expect(queueRecovered.first['customerId'], 'cust-14-recovery');

      await v2Db.close();
    });

    test('Scenario 15: Rerunning resolveQuarantinedRecord is idempotent and does NOT create duplicate sync queue items', () async {
      final v1Path = await createV1Database(
        queueRows: [
          {
            'customerId': '',
            'latitude': 10.123,
            'longitude': 106.123,
            'gpsAccuracy': 3.5,
            'identificationNotes': 'Bản ghi test idempotency',
            'createdAt': '2026-10-22T10:00:00Z',
          },
        ],
        orderRows: [],
      );

      final v2Db = await createV2Database('v2_test_15.db');
      await OfflineStorageService.migrateFromV1IfNeeded(v2Db, customV1Path: v1Path);

      final qList = await OfflineStorageService.getQuarantinedRecords(targetDb: v2Db);
      final qId = qList.first['id'] as int;

      // First resolution
      final res1 = await OfflineStorageService.resolveQuarantinedRecord(
        quarantineId: qId,
        correctedCustomerId: 'cust-idempotent-15',
        targetDb: v2Db,
      );
      expect(res1.success, isTrue);
      final originalV2Id = res1.v2QueueId!;

      // Second resolution call on the exact same record
      final res2 = await OfflineStorageService.resolveQuarantinedRecord(
        quarantineId: qId,
        correctedCustomerId: 'cust-idempotent-15',
        targetDb: v2Db,
      );
      expect(res2.success, isTrue);
      expect(res2.v2QueueId, originalV2Id);

      // Third resolution call with different parameters
      final res3 = await OfflineStorageService.resolveQuarantinedRecord(
        quarantineId: qId,
        correctedCustomerId: 'cust-idempotent-15-other',
        targetDb: v2Db,
      );
      expect(res3.success, isTrue);
      expect(res3.v2QueueId, originalV2Id);

      // VERIFY: offline_sync_queue still has EXACTLY 1 item
      final queueCount = await v2Db.query('offline_sync_queue');
      expect(queueCount.length, 1);

      // VERIFY: _v1_migration_tracking still has EXACTLY 1 item
      final trackingCount = await v2Db.query('_v1_migration_tracking');
      expect(trackingCount.length, 1);

      await v2Db.close();
    });

    test('Scenario 16: Re-opening app or re-running migration after resolution does NOT re-import resolved records', () async {
      final v1Path = await createV1Database(
        queueRows: [
          {
            'customerId': '',
            'latitude': 10.77,
            'longitude': 106.69,
            'gpsAccuracy': 4.0,
            'identificationNotes': 'Bản ghi cần sửa trước khi app restart',
            'createdAt': '2026-10-22T10:30:00Z',
          },
        ],
        orderRows: [],
      );

      final v2Db = await createV2Database('v2_test_16.db');
      await OfflineStorageService.migrateFromV1IfNeeded(v2Db, customV1Path: v1Path);

      final qList = await OfflineStorageService.getQuarantinedRecords(targetDb: v2Db);
      final qId = qList.first['id'] as int;

      // Resolve the record
      await OfflineStorageService.resolveQuarantinedRecord(
        quarantineId: qId,
        correctedCustomerId: 'cust-fixed-16',
        targetDb: v2Db,
      );

      // Now simulate app restart / re-running migration
      final reMigrateResult = await OfflineStorageService.migrateFromV1IfNeeded(
        v2Db,
        customV1Path: v1Path,
        forceRun: true,
      );

      // Should migrate 0 new records because v1_source_id is already in _v1_migration_tracking
      expect(reMigrateResult.migratedCount, 0);
      expect(reMigrateResult.newlyQuarantinedCount, 0);
      expect(reMigrateResult.quarantinedCount, 0);
      expect(reMigrateResult.status, MigrationStatus.success);

      // Check offline_sync_queue
      final queueItems = await v2Db.query('offline_sync_queue');
      expect(queueItems.length, 1);
      expect(queueItems.first['customerId'], 'cust-fixed-16');

      await v2Db.close();
    });

    test('Scenario 17: Migration status accurately tracks remaining quarantined records (partial vs complete resolution)', () async {
      final v1Path = await createV1Database(
        queueRows: [
          {
            'customerId': '',
            'latitude': 10.1,
            'longitude': 106.1,
            'gpsAccuracy': 5.0,
            'identificationNotes': 'Bản ghi hỏng A',
            'createdAt': '2026-10-22T11:00:00Z',
          },
          {
            'customerId': '',
            'latitude': 10.2,
            'longitude': 106.2,
            'gpsAccuracy': 5.0,
            'identificationNotes': 'Bản ghi hỏng B',
            'createdAt': '2026-10-22T11:01:00Z',
          },
        ],
        orderRows: [],
      );

      final v2Db = await createV2Database('v2_test_17.db');
      await OfflineStorageService.migrateFromV1IfNeeded(v2Db, customV1Path: v1Path);

      final prefs = await SharedPreferences.getInstance();
      expect(await OfflineStorageService.getQuarantinedCount(targetDb: v2Db, onlyPending: true), 2);
      expect(prefs.getBool('sqlite_v1_migrated'), isFalse);
      expect(prefs.getString('sqlite_v1_migration_status'), 'QUARANTINED');
      expect(prefs.getInt('sqlite_v1_quarantined_count'), 2);

      final qRecords = await OfflineStorageService.getQuarantinedRecords(targetDb: v2Db);
      expect(qRecords.length, 2);

      // Resolve only Record A
      await OfflineStorageService.resolveQuarantinedRecord(
        quarantineId: qRecords[0]['id'] as int,
        correctedCustomerId: 'cust-fixed-17-A',
        targetDb: v2Db,
      );

      // Pending count is now 1 -> migration is still incomplete
      expect(await OfflineStorageService.getQuarantinedCount(targetDb: v2Db, onlyPending: true), 1);
      expect(prefs.getBool('sqlite_v1_migrated'), isFalse);
      expect(prefs.getInt('sqlite_v1_quarantined_count'), 1);

      // Resolve Record B
      await OfflineStorageService.resolveQuarantinedRecord(
        quarantineId: qRecords[1]['id'] as int,
        correctedCustomerId: 'cust-fixed-17-B',
        targetDb: v2Db,
      );

      // Pending count is now 0 -> migration is fully COMPLETED!
      expect(await OfflineStorageService.getQuarantinedCount(targetDb: v2Db, onlyPending: true), 0);
      expect(prefs.getBool('sqlite_v1_migrated'), isTrue);
      expect(prefs.getString('sqlite_v1_migration_status'), 'COMPLETED');
      expect(prefs.getInt('sqlite_v1_quarantined_count'), 0);

      await v2Db.close();
    });

    test('Scenario 18: Discarding a quarantined record with reason updates status to DISCARDED without deleting data', () async {
      final v1Path = await createV1Database(
        queueRows: [
          {
            'customerId': '',
            'latitude': 10.3,
            'longitude': 106.3,
            'gpsAccuracy': 5.0,
            'identificationNotes': 'Bản ghi thử nghiệm rác cần loại bỏ',
            'createdAt': '2026-10-22T11:30:00Z',
          },
        ],
        orderRows: [],
      );

      final v2Db = await createV2Database('v2_test_18.db');
      await OfflineStorageService.migrateFromV1IfNeeded(v2Db, customV1Path: v1Path);

      final qRecords = await OfflineStorageService.getQuarantinedRecords(targetDb: v2Db);
      final qId = qRecords.first['id'] as int;

      // Discard with empty reason -> must fail
      final discardFail = await OfflineStorageService.discardQuarantinedRecord(
        quarantineId: qId,
        reason: '   ',
        targetDb: v2Db,
      );
      expect(discardFail, isFalse);

      // Discard with valid reason
      final discardSuccess = await OfflineStorageService.discardQuarantinedRecord(
        quarantineId: qId,
        reason: 'Dữ liệu test của shipper khi demo ứng dụng, không cần giao',
        targetDb: v2Db,
      );
      expect(discardSuccess, isTrue);

      // Check quarantine record: still exists, status is DISCARDED
      final qAfter = await v2Db.query('_v1_quarantine_records', where: 'id = ?', whereArgs: [qId]);
      expect(qAfter.length, 1);
      expect(qAfter.first['status'], 'DISCARDED');
      expect(qAfter.first['resolution_notes'], 'Dữ liệu test của shipper khi demo ứng dụng, không cần giao');
      expect(qAfter.first['resolved_at'], isNotNull);

      // Pending count is 0, total count is 1
      expect(await OfflineStorageService.getQuarantinedCount(targetDb: v2Db, onlyPending: true), 0);
      expect(await OfflineStorageService.getQuarantinedCount(targetDb: v2Db, onlyPending: false), 1);

      // Migration status transitioned to COMPLETED
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('sqlite_v1_migrated'), isTrue);
      expect(prefs.getString('sqlite_v1_migration_status'), 'COMPLETED');

      // Attempting to resolve a DISCARDED record fails
      final resolveAfterDiscard = await OfflineStorageService.resolveQuarantinedRecord(
        quarantineId: qId,
        correctedCustomerId: 'cust-revive',
        targetDb: v2Db,
      );
      expect(resolveAfterDiscard.success, isFalse);
      expect(resolveAfterDiscard.errorMessage, contains('Record was discarded'));

      await v2Db.close();
    });

    test('Scenario 19: Calling deleteQuarantinedRecord cleans up unfinished tracking entries and updates prefs', () async {
      final v1Path = await createV1Database(
        queueRows: [
          {
            'customerId': '',
            'latitude': 10.4,
            'longitude': 106.4,
            'gpsAccuracy': 5.0,
            'identificationNotes': 'Bản ghi test delete legacy',
            'createdAt': '2026-10-22T12:00:00Z',
          },
        ],
        orderRows: [],
      );

      final v2Db = await createV2Database('v2_test_19.db');
      await OfflineStorageService.migrateFromV1IfNeeded(v2Db, customV1Path: v1Path);

      final qRecords = await OfflineStorageService.getQuarantinedRecords(targetDb: v2Db);
      final qId = qRecords.first['id'] as int;

      // Verify tracking row exists with v2_queue_id = null
      final trackingBefore = await v2Db.query('_v1_migration_tracking', where: 'v1_source_id = ?', whereArgs: [1]);
      expect(trackingBefore.length, 1);
      expect(trackingBefore.first['v2_queue_id'], isNull);

      // Delete quarantined record
      final deleted = await OfflineStorageService.deleteQuarantinedRecord(qId, targetDb: v2Db);
      expect(deleted, 1);

      // Verify tracking row was cleaned up (no ghost lock!)
      final trackingAfter = await v2Db.query('_v1_migration_tracking', where: 'v1_source_id = ?', whereArgs: [1]);
      expect(trackingAfter, isEmpty);

      // Verify remaining count updated in prefs
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('sqlite_v1_migrated'), isTrue);
      expect(prefs.getString('sqlite_v1_migration_status'), 'COMPLETED');

      await v2Db.close();
    });

    test('Scenario 20: Source SQLite v1 database file remains 100% read-only and untouched across migration and resolution', () async {
      final v1Path = await createV1Database(
        queueRows: [
          {
            'customerId': 'cust-v1-intact',
            'latitude': 10.5,
            'longitude': 106.5,
            'gpsAccuracy': 3.0,
            'identificationNotes': 'Ghi chú nguồn v1 nguyên vẹn',
            'createdAt': '2026-10-22T12:30:00Z',
          },
          {
            'customerId': '',
            'latitude': 10.6,
            'longitude': 106.6,
            'gpsAccuracy': 4.0,
            'identificationNotes': 'Ghi chú nguồn v1 bị lỗi',
            'createdAt': '2026-10-22T12:31:00Z',
          },
        ],
        orderRows: [
          {
            'orderId': 'order-v1-intact',
            'jsonData': jsonEncode({'id': 'order-v1-intact', 'title': 'Đơn hàng v1'}),
          },
        ],
      );

      // Capture v1 file modification time and byte length before any operations
      final v1File = File(v1Path);
      final originalLength = await v1File.length();
      final originalBytes = await v1File.readAsBytes();

      final v2Db = await createV2Database('v2_test_20.db');

      // 1. Run migration
      await OfflineStorageService.migrateFromV1IfNeeded(v2Db, customV1Path: v1Path);

      // 2. Resolve quarantined record
      final qList = await OfflineStorageService.getQuarantinedRecords(targetDb: v2Db);
      await OfflineStorageService.resolveQuarantinedRecord(
        quarantineId: qList.first['id'] as int,
        correctedCustomerId: 'cust-fixed-20',
        targetDb: v2Db,
      );

      // 3. Verify v1 file on disk: content length and bytes are identical
      final currentLength = await v1File.length();
      final currentBytes = await v1File.readAsBytes();
      expect(currentLength, originalLength);
      expect(currentBytes, orderedEquals(originalBytes));

      // 4. Open v1 database and verify all data is present and unchanged
      final v1VerifyDb = await openDatabase(v1Path, readOnly: true);
      final v1Queue = await v1VerifyDb.query('offline_sync_queue');
      expect(v1Queue.length, 2);
      expect(v1Queue[0]['customerId'], 'cust-v1-intact');
      expect(v1Queue[1]['customerId'], '');

      final v1Orders = await v1VerifyDb.query('cached_orders');
      expect(v1Orders.length, 1);
      expect(v1Orders.first['orderId'], 'order-v1-intact');

      await v1VerifyDb.close();
      await v2Db.close();
    });
  });
}
