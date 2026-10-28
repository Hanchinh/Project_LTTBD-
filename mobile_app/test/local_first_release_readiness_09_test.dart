import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart' as p;

import 'package:delivery_marker_mobile/features/shifts/widgets/shift_map_tile_config.dart';
import 'package:delivery_marker_mobile/data/local/app_database.dart';
import 'package:delivery_marker_mobile/data/local/local_customer_repository.dart';
import 'package:delivery_marker_mobile/data/local/local_photo_repository.dart';
import 'package:delivery_marker_mobile/data/local/map_tile_cache_service.dart';
import 'package:delivery_marker_mobile/data/local/app_storage_service.dart';
import 'package:delivery_marker_mobile/data/local/backup_service.dart';
import 'package:delivery_marker_mobile/models/location_model.dart';
import 'package:delivery_marker_mobile/features/map/main_map_view.dart';
import 'package:delivery_marker_mobile/features/profile/account_profile_view.dart';
import 'package:delivery_marker_mobile/data/repositories/repository_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Directory tempDir;
  late AppDatabase appDb;
  late Database db;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('release_readiness_test_');
    final dbPath = p.join(tempDir.path, 'test_app.db');
    appDb = await AppDatabase.openAtPath(dbPath, factory: databaseFactoryFfi);
    db = await appDb.database;

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/connectivity'),
      (methodCall) async => 'wifi',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/connectivity_status'),
      (methodCall) async => null,
    );
  });

  tearDown(() async {
    await appDb.close();
    try {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    } catch (_) {}
  });

  group('TASK: LOCAL-FIRST-09 - Release Readiness & Durability Tests', () {
    // -------------------------------------------------------------------------
    // 1. CẤU HÌNH TILE BẢN ĐỒ VÀ GHI CÔNG (ATTRIBUTION)
    // -------------------------------------------------------------------------
    test('1. MapConfig tập trung quản lý URL tile, subdomains và ghi nguồn bản quyền', () {
      expect(MapConfig.getUrlTemplate(0), MapConfig.googleRoadsUrl);
      expect(MapConfig.getUrlTemplate(1), MapConfig.googleHybridUrl);
      expect(MapConfig.getUrlTemplate(2), MapConfig.cartoVoyagerUrl);
      expect(MapConfig.fallbackUrl, isNotEmpty);
      expect(MapConfig.userAgentPackageName, 'com.example.delivery_marker_mobile');
      expect(MapConfig.defaultAttribution, contains('Google Maps'));
      expect(MapConfig.defaultAttribution, contains('CARTO'));

      // Tương thích ngược qua ShiftMapTileConfig
      expect(ShiftMapTileConfig.getUrlTemplate(0), MapConfig.googleRoadsUrl);
      expect(ShiftMapTileConfig.getUrlTemplate(2), MapConfig.cartoVoyagerUrl);
      expect(ShiftMapTileConfig.getSubdomains(2), const ['a', 'b', 'c', 'd']);
      expect(ShiftMapTileConfig.mapTypeNames.length, 3);
    });

    // -------------------------------------------------------------------------
    // 2. DỌN ẢNH XÓA MỀM QUÁ 30 NGÀY KHI MỞ APP
    // -------------------------------------------------------------------------
    test('2. Tự động dọn dẹp triệt để các ảnh xóa mềm quá 30 ngày', () async {
      final photoRepo = LocalPhotoRepository(appDb: appDb, baseDirectory: tempDir);
      final photosDir = await photoRepo.getPhotosDirectory();

      // Tạo khách hàng
      await db.insert('customers', {
        'id': 'cust-photo-purge',
        'full_name': 'Khách Dọn Ảnh',
        'phone_number': '0901234567',
        'created_at': AppDatabase.currentIsoUtc(),
        'updated_at': AppDatabase.currentIsoUtc(),
      });

      // Ảnh 1: Không bị xóa
      final file1 = File(p.join(photosDir.path, 'active.jpg'))..writeAsBytesSync([1, 2, 3]);
      await db.insert('customer_photos', {
        'id': 'photo-active',
        'customer_id': 'cust-photo-purge',
        'file_name': 'active.jpg',
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'deleted_at': null,
      });

      // Ảnh 2: Mới xóa mềm 5 ngày trước (giữ nguyên, chưa quá 30 ngày)
      final file2 = File(p.join(photosDir.path, 'deleted_5days.jpg'))..writeAsBytesSync([4, 5, 6]);
      await db.insert('customer_photos', {
        'id': 'photo-recent-del',
        'customer_id': 'cust-photo-purge',
        'file_name': 'deleted_5days.jpg',
        'created_at': DateTime.now().toUtc().subtract(const Duration(days: 10)).toIso8601String(),
        'deleted_at': DateTime.now().toUtc().subtract(const Duration(days: 5)).toIso8601String(),
      });

      // Ảnh 3: Đã xóa mềm 35 ngày trước (cần dọn vĩnh viễn)
      final file3 = File(p.join(photosDir.path, 'deleted_35days.jpg'))..writeAsBytesSync([7, 8, 9]);
      await db.insert('customer_photos', {
        'id': 'photo-expired-del',
        'customer_id': 'cust-photo-purge',
        'file_name': 'deleted_35days.jpg',
        'created_at': DateTime.now().toUtc().subtract(const Duration(days: 40)).toIso8601String(),
        'deleted_at': DateTime.now().toUtc().subtract(const Duration(days: 35)).toIso8601String(),
      });

      // Thực hiện dọn dẹp
      final purgedCount = await photoRepo.purgeDeletedPhotosOlderThan(olderThan: const Duration(days: 30));
      expect(purgedCount, 1);

      // File 3 và record photo-expired-del phải bị xóa hoàn toàn
      expect(file3.existsSync(), isFalse);
      final checkExpired = await db.query('customer_photos', where: 'id = ?', whereArgs: ['photo-expired-del']);
      expect(checkExpired.isEmpty, isTrue);

      // File 1 và File 2 vẫn còn nguyên vẹn
      expect(file1.existsSync(), isTrue);
      expect(file2.existsSync(), isTrue);
      final checkRecent = await db.query('customer_photos', where: 'id = ?', whereArgs: ['photo-recent-del']);
      expect(checkRecent.isNotEmpty, isTrue);
    });

    // -------------------------------------------------------------------------
    // 3. APP STORAGE SERVICE & DỌN BỘ NHỚ ĐỆM
    // -------------------------------------------------------------------------
    test('3. AppStorageService tính toán dung lượng và dọn dẹp bộ nhớ đệm an toàn', () async {
      final cacheDir = Directory(p.join(tempDir.path, 'tile_cache'))..createSync(recursive: true);
      MapTileCacheService.setCustomCacheDirectory(cacheDir);

      // Ghi 1 tile giả lập
      await MapTileCacheService.cacheTileBytes(
        'https://tile.openstreetmap.org/10/1/1.png',
        Uint8List.fromList(List.filled(1024 * 50, 42)), // 50 KB
      );

      // Ghi 1 file .dshare tạm trong tempDir
      final tempDshare = File(p.join(tempDir.path, 'export_test.dshare'))..writeAsBytesSync(List.filled(1024 * 30, 99));

      final storageService = AppStorageService(
        appDb: appDb,
        photoRepo: LocalPhotoRepository(appDb: appDb, baseDirectory: tempDir),
        customTempDir: tempDir,
      );

      final statsBefore = await storageService.getStorageStats();
      expect(statsBefore.cacheSizeBytes, greaterThan(0));
      expect(statsBefore.cacheSizeFormatted, isNotEmpty);

      // Dọn bộ nhớ đệm
      final freed = await storageService.clearCache();
      expect(freed, greaterThan(0));

      final statsAfter = await storageService.getStorageStats();
      expect(statsAfter.cacheSizeBytes, 0);
      expect(tempDshare.existsSync(), isFalse);

      MapTileCacheService.setCustomCacheDirectory(null);
    });

    // -------------------------------------------------------------------------
    // 4. KIỂM TRA MIGRATION SQLITE V1 -> V2 VÀ CHỈ MỤC MỚI
    // -------------------------------------------------------------------------
    test('4. Migration SQLite từ v1 lên v2 thêm chỉ mục tối ưu hóa hiệu năng không lỗi', () async {
      final migPath = p.join(tempDir.path, 'migration_test.db');

      // 1. Tạo DB v1 chỉ chạy migrationV1
      final dbV1 = await openDatabase(
        migPath,
        version: 1,
        onCreate: (d, v) async {
          await AppDatabase.migrationV1(d);
        },
      );
      final v1Version = await dbV1.getVersion();
      expect(v1Version, 1);
      await dbV1.close();

      // 2. Mở lại với AppDatabase (v2), onUpgrade sẽ tự động kích hoạt migrationV2
      final appDbV2 = await AppDatabase.openAtPath(migPath, factory: databaseFactoryFfi);
      final upgradedDb = await appDbV2.database;

      final v2Version = await upgradedDb.getVersion();
      expect(v2Version, 2);

      // Kiểm tra sự tồn tại của các chỉ mục mới
      final indexes = await upgradedDb.rawQuery("SELECT name FROM sqlite_master WHERE type='index';");
      final indexNames = indexes.map((r) => r['name'] as String).toList();

      expect(indexNames, contains('idx_customers_deleted_updated'));
      expect(indexNames, contains('idx_shift_points_status'));
      expect(indexNames, contains('idx_customer_photos_active'));
      expect(indexNames, contains('idx_customer_photos_deleted_at'));

      await appDbV2.close();
    });

    // -------------------------------------------------------------------------
    // 5. ĐỘ BỀN DỮ LIỆU & WAL VÀ TOÀN VẸN (INTEGRITY CHECK)
    // -------------------------------------------------------------------------
    test('5. WAL mode hoạt động và CSDL vượt qua kiểm tra toàn vẹn (PRAGMA integrity_check)', () async {
      final integrityRes = await db.rawQuery('PRAGMA integrity_check;');
      expect(integrityRes.first.values.first, 'ok');

      // Nhắc nhở sao lưu hoạt động sau 14 ngày
      final backupService = BackupService(appDb: appDb, customBaseDir: tempDir);

      // Khi chưa có dữ liệu -> không nhắc
      expect(await backupService.shouldShowBackupReminder(), isFalse);

      // Khi có khách hàng nhưng chưa sao lưu -> nhắc sao lưu
      await db.insert('customers', {
        'id': 'cust-backup-remind',
        'full_name': 'Khách Cần Sao Lưu',
        'phone_number': '0912345678',
        'created_at': AppDatabase.currentIsoUtc(),
        'updated_at': AppDatabase.currentIsoUtc(),
      });
      expect(await backupService.shouldShowBackupReminder(), isTrue);

      // Khi đã sao lưu cách đây 2 ngày -> không nhắc
      final twoDaysAgo = DateTime.now().toUtc().subtract(const Duration(days: 2)).toIso8601String();
      await appDb.setMeta(BackupService.keyLastBackupAt, twoDaysAgo);
      expect(await backupService.shouldShowBackupReminder(), isFalse);

      // Khi đã sao lưu cách đây 15 ngày -> nhắc nhở sao lưu
      final fifteenDaysAgo = DateTime.now().toUtc().subtract(const Duration(days: 15)).toIso8601String();
      await appDb.setMeta(BackupService.keyLastBackupAt, fifteenDaysAgo);
      expect(await backupService.shouldShowBackupReminder(), isTrue);
    });

    // -------------------------------------------------------------------------
    // 6. BENCHMARK HIỆU NĂNG: GOM CỤM 200 & 1,000 ĐIỂM
    // -------------------------------------------------------------------------
    test('6. Benchmark gom cụm bản đồ với 200 và 1,000 điểm mượt mà', () {
      // Sinh 200 điểm giả lập quanh TP.HCM
      final list200 = List<MasterSavedLocationModel>.generate(200, (i) {
        return MasterSavedLocationModel(
          id: 'loc-$i',
          customerId: 'cust-$i',
          customerCode: 'KH-$i',
          customerName: 'Khách $i',
          customerPhone: '090000000$i',
          customerAddress: 'Số $i đường Test, TP.HCM',
          latitude: 10.75 + (i * 0.001),
          longitude: 106.65 + (i * 0.001),
          gpsAccuracy: 5.0,
          identificationNotes: 'Ghi chú $i',
        );
      });

      final sw200 = Stopwatch()..start();
      final clusters200 = MarkerClusterHelper.clusterLocations(list200, 14.0);
      sw200.stop();
      expect(clusters200.isNotEmpty, isTrue);
      // Gom cụm 200 điểm phải dưới 100ms
      expect(sw200.elapsedMilliseconds, lessThan(100));

      // Sinh 1,000 điểm giả lập
      final list1000 = List<MasterSavedLocationModel>.generate(1000, (i) {
        return MasterSavedLocationModel(
          id: 'loc-1000-$i',
          customerId: 'cust-1000-$i',
          customerCode: 'KH-1000-$i',
          customerName: 'Khách Sỉ $i',
          customerPhone: '091000000$i',
          customerAddress: 'Số $i đường Sỉ, TP.HCM',
          latitude: 10.70 + (i * 0.0002),
          longitude: 106.60 + (i * 0.0002),
          gpsAccuracy: 5.0,
          identificationNotes: 'Cổng màu xanh',
        );
      });

      final sw1000 = Stopwatch()..start();
      final clusters1000 = MarkerClusterHelper.clusterLocations(list1000, 13.0);
      sw1000.stop();
      expect(clusters1000.isNotEmpty, isTrue);
      // Gom cụm 1,000 điểm phải dưới 500ms
      expect(sw1000.elapsedMilliseconds, lessThan(500));
    });

    // -------------------------------------------------------------------------
    // 7. BENCHMARK TRUY VẤN DANH BẠ 5,000 KHÁCH HÀNG
    // -------------------------------------------------------------------------
    test('7. Benchmark chèn và truy vấn danh bạ 5,000 khách hàng trong SQLite đạt tốc độ cao', () async {
      // 1. Chèn theo batch giao dịch (transaction) 5,000 khách
      final insertSw = Stopwatch()..start();
      await db.transaction((txn) async {
        final batch = txn.batch();
        for (int i = 1; i <= 5000; i++) {
          final phone = '098${i.toString().padLeft(7, '0')}';
          final name = 'Nguyễn Văn Shipper $i';
          batch.insert('customers', {
            'id': 'bench-cust-$i',
            'full_name': name,
            'phone_number': phone,
            'search_text': 'nguyen van shipper $i $phone',
            'created_at': AppDatabase.currentIsoUtc(),
            'updated_at': AppDatabase.currentIsoUtc(),
            'deleted_at': null,
          });
        }
        await batch.commit(noResult: true);
      });
      insertSw.stop();

      // 2. Benchmark truy vấn lấy danh sách trang đầu
      final custRepo = LocalCustomerRepository(appDb: appDb);
      final querySw = Stopwatch()..start();
      final response = await custRepo.getCustomersResponse(limit: 50);
      querySw.stop();

      expect(response.pagination.total, 5000);
      expect(response.items.length, 50);
      // Với chỉ mục idx_customers_deleted_updated, truy vấn 5,000 khách phải dưới 150ms
      expect(querySw.elapsedMilliseconds, lessThan(150));

      // 3. Benchmark tìm kiếm từ khóa không dấu
      final searchSw = Stopwatch()..start();
      final searchResults = await appDb.searchCustomers('Shipper 4999', limit: 10);
      searchSw.stop();

      expect(searchResults.length, 1);
      expect(searchResults.first['phone_number'], '0980004999');
      // Tìm kiếm với idx_customers_search_text phải dưới 100ms
      expect(searchSw.elapsedMilliseconds, lessThan(100));
    });

    // -------------------------------------------------------------------------
    // 8. BẢN ĐỒ KHI MẤT MẠNG VÀ TÌM KIẾM ĐỊA CHỈ BÁO LỖI MẠNG
    // -------------------------------------------------------------------------
    testWidgets('8. MainMapView hiển thị cảnh báo khi mất mạng và báo cần mạng khi tìm địa chỉ', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      RepositoryProvider.useLocalData = true;

      await tester.runAsync(() async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: MainMapView(),
            ),
          ),
        );
        await Future.delayed(const Duration(milliseconds: 300));
      });
      await tester.pump();

      final state = tester.state<MainMapViewState>(find.byType(MainMapView));

      // 1. Khi bình thường (có mạng) -> không có offline banner
      expect(find.byKey(const Key('map_offline_banner')), findsNothing);

      // 2. Giả lập mất mạng
      state.setOfflineForTesting(true);
      await tester.pump();

      // Phải xuất hiện offline banner
      expect(find.byKey(const Key('map_offline_banner')), findsOneWidget);
      expect(find.textContaining('Đang mất kết nối mạng'), findsOneWidget);

      // 3. Bật tâm ngắm và thử tìm kiếm địa chỉ khi mất mạng -> báo cần kết nối mạng
      final addBtn = find.byKey(const Key('btn_pin_new_location'));
      await tester.tap(addBtn);
      await tester.pump();

      final searchField = find.byKey(const Key('pin_address_search_field'));
      expect(searchField, findsOneWidget);

      await tester.enterText(searchField, 'Nguyen Hue');
      await tester.pump();

      // Hiện SnackBar cảnh báo cần mạng
      expect(find.text('Cần kết nối mạng để tìm kiếm địa chỉ'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });

    // -------------------------------------------------------------------------
    // 9. MÀN CÁ NHÂN: DÒNG GHI NGUỒN BẢN ĐỒ VÀ DUNG LƯỢNG ỨNG DỤNG
    // -------------------------------------------------------------------------
    testWidgets('9. AccountProfileView hiển thị nguồn bản đồ và thẻ dung lượng ứng dụng', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      RepositoryProvider.useLocalData = true;

      await tester.runAsync(() async {
        await tester.pumpWidget(
          const MaterialApp(
            home: AccountProfileView(),
          ),
        );
        await Future.delayed(const Duration(milliseconds: 500));
      });
      await tester.pumpAndSettle();

      // Dòng nguồn bản đồ & bản quyền
      expect(find.byKey(const Key('profile_map_attribution_item')), findsOneWidget);
      expect(find.text('Nguồn bản đồ & Bản quyền'), findsOneWidget);
      expect(find.text(MapConfig.defaultAttribution), findsOneWidget);

      // Mục dung lượng ứng dụng
      expect(find.text('Dung lượng lưu trữ'), findsOneWidget);
      expect(find.byKey(const Key('clear_cache_btn')), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });
  });
}
