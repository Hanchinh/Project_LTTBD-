import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:delivery_marker_mobile/data/local/app_database.dart';
import 'package:delivery_marker_mobile/models/user_model.dart';
import 'package:delivery_marker_mobile/data/local/local_customer_repository.dart';
import 'package:delivery_marker_mobile/data/local/local_location_repository.dart';
import 'package:delivery_marker_mobile/data/local/local_photo_repository.dart';
import 'package:delivery_marker_mobile/data/local/local_profile_repository.dart';
import 'package:delivery_marker_mobile/data/local/local_shift_repository.dart';
import 'package:delivery_marker_mobile/data/repositories/repository_provider.dart';
import 'package:delivery_marker_mobile/data/local/backup_service.dart';
import 'package:delivery_marker_mobile/core/utils/pin_crypto_utils.dart';
import 'package:delivery_marker_mobile/features/profile/account_profile_view.dart';
import 'package:delivery_marker_mobile/features/onboarding_lock/pin_lock_screen.dart';
import 'package:delivery_marker_mobile/features/onboarding_lock/welcome_onboarding_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('TASK: LOCAL-FIRST-06-PROFILE-PIN-BACKUP Tests', () {
    late Directory tempDir;
    late AppDatabase appDb;
    late LocalProfileRepository profileRepo;
    late LocalCustomerRepository customerRepo;
    late LocalLocationRepository locationRepo;
    late LocalPhotoRepository photoRepo;
    late LocalShiftRepository shiftRepo;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('local_profile_pin_test_');
      final dbPath = '${tempDir.path}/test_local_data.db';
      appDb = AppDatabase(factory: databaseFactoryFfi, customPath: dbPath);
      await appDb.database;

      photoRepo = LocalPhotoRepository(appDb: appDb, baseDirectory: tempDir);
      customerRepo = LocalCustomerRepository(appDb: appDb);
      locationRepo = LocalLocationRepository(appDb: appDb);
      shiftRepo = LocalShiftRepository(appDb: appDb);
      profileRepo = LocalProfileRepository(appDb: appDb);

      RepositoryProvider.useLocalData = true;
      RepositoryProvider.overrideRepositories(
        profile: profileRepo,
        customer: customerRepo,
        location: locationRepo,
        photo: photoRepo,
        shift: shiftRepo,
      );
    });

    tearDown(() async {
      RepositoryProvider.reset();
      await appDb.close();
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    });

    test('1. RepositoryProvider mặc định useLocalData=true và trả về LocalProfileRepository', () {
      RepositoryProvider.reset();
      expect(RepositoryProvider.useLocalData, isTrue);
      expect(RepositoryProvider.profile, isA<LocalProfileRepository>());

      // Chuyển sang Remote
      RepositoryProvider.useLocalData = false;
      expect(RepositoryProvider.useLocalData, isFalse);

      // Chuyển lại Local
      RepositoryProvider.useLocalData = true;
      expect(RepositoryProvider.useLocalData, isTrue);
      expect(RepositoryProvider.profile, isA<LocalProfileRepository>());
    });

    test('2. PinCryptoUtils: Băm và xác thực PBKDF2/SHA-256 an toàn, chống timing attacks', () {
      expect(PinCryptoUtils.isValidPin('1234'), isTrue);
      expect(PinCryptoUtils.isValidPin('123456'), isTrue);
      expect(PinCryptoUtils.isValidPin('123'), isFalse); // < 4
      expect(PinCryptoUtils.isValidPin('1234567'), isFalse); // > 6
      expect(PinCryptoUtils.isValidPin('abcd'), isFalse); // Ký tự chữ

      final hash1 = PinCryptoUtils.hashPin('5678');
      final hash2 = PinCryptoUtils.hashPin('5678');
      expect(hash1, isNot(equals(hash2)), reason: 'Mỗi lần băm phải có salt ngẫu nhiên khác nhau');
      expect(hash1.startsWith('pbkdf2:sha256:10000:'), isTrue);

      expect(PinCryptoUtils.verifyPin('5678', hash1), isTrue);
      expect(PinCryptoUtils.verifyPin('1234', hash1), isFalse);
      expect(PinCryptoUtils.verifyPin('5678', 'invalid_hash_string'), isFalse);
    });

    test('3. Hồ sơ người dùng: Tên mặc định, đổi tên, thống kê tính từ SQLite và ghi activity_log', () async {
      final defaultUser = await profileRepo.getCurrentUser();
      expect(defaultUser?.fullName, 'Người giao hàng');

      // Đổi tên
      await profileRepo.updateDisplayName('Nguyễn Văn Giao');
      final updatedUser = await profileRepo.getCurrentUser();
      expect(updatedUser?.fullName, 'Nguyễn Văn Giao');

      // Tạo dữ liệu mẫu để kiểm tra getMyStats
      final cust = await customerRepo.createCustomer(fullName: 'Khách A', phoneNumber: '0901234567');
      await locationRepo.updateCustomerLocationAndPhoto(
        customerId: cust.id,
        latitude: 10.7769,
        longitude: 106.7009,
        identificationNotes: '123 Lê Lợi',
      );
      await appDb.createShift(shiftCode: 'SHF-20261027-001', workDate: '2026-10-27');

      final stats = await profileRepo.getMyStats();
      expect(stats['savedLocationsCount'], 1);
      expect(stats['createdShiftsCount'], 1);
      expect(stats['customersCount'], 1);

      // Kiểm tra activity_log
      final db = await appDb.database;
      final logs = await db.query('activity_log', where: 'action = ?', whereArgs: ['UPDATE_PROFILE_NAME']);
      expect(logs.isNotEmpty, isTrue);
      expect((logs.first['details_json'] as String).contains('Nguyễn Văn Giao'), isTrue);
    });

    test('4. Quản lý mã PIN: Đặt PIN, xác thực đúng/sai, khóa lũy tiến sau 5 lần sai và reset khi quên PIN', () async {
      expect(await profileRepo.hasPin(), isFalse);

      // Đặt PIN
      await profileRepo.setPin('1234');
      expect(await profileRepo.hasPin(), isTrue);

      // Thử đúng
      final okRes = await profileRepo.verifyPin('1234');
      expect(okRes.success, isTrue);
      expect(okRes.isLocked, isFalse);

      // Thử sai 4 lần
      for (int i = 1; i <= 4; i++) {
        final failRes = await profileRepo.verifyPin('0000');
        expect(failRes.success, isFalse);
        expect(failRes.isLocked, isFalse);
        expect(failRes.failedAttempts, i);
      }

      // Thử sai lần thứ 5 -> Khóa tạm thời 30 giây
      final lockRes = await profileRepo.verifyPin('0000');
      expect(lockRes.success, isFalse);
      expect(lockRes.isLocked, isTrue);
      expect(lockRes.remainingLockoutSeconds, greaterThanOrEqualTo(25));

      // Trong lúc khóa, thử lại bị từ chối ngay lập tức
      final blockedRes = await profileRepo.verifyPin('1234');
      expect(blockedRes.success, isFalse);
      expect(blockedRes.isLocked, isTrue);

      // Quên PIN -> Đặt lại toàn bộ dữ liệu ứng dụng
      await profileRepo.resetAllDataWithWipe();
      expect(await profileRepo.hasPin(), isFalse);
      final resetUser = await profileRepo.getCurrentUser();
      expect(resetUser?.fullName, 'Người giao hàng');
    });

    test('5. Chu kỳ khóa ứng dụng theo thời gian chờ nền (timeout seconds)', () async {
      await profileRepo.setPin('9876');

      // Mặc định timeout 60 giây
      expect(await profileRepo.getPinTimeoutSeconds(), 60);

      // Cấu hình 0 giây (khóa ngay lập tức)
      await profileRepo.setPinTimeoutSeconds(0);
      expect(await profileRepo.getPinTimeoutSeconds(), 0);
      expect(await profileRepo.shouldLockApp(), isTrue);

      // Cấu hình 300 giây (5 phút)
      await profileRepo.setPinTimeoutSeconds(300);
      await profileRepo.recordActiveNow();
      expect(await profileRepo.shouldLockApp(), isFalse);
    });

    test('6. BackupService: Tạo bản sao lưu .zip kèm database.db, photos, manifest.json và checksum SHA-256', () async {
      // Chuẩn bị dữ liệu và ảnh mẫu
      final cust = await customerRepo.createCustomer(fullName: 'Khách Sao Lưu', phoneNumber: '0988776655');
      await locationRepo.updateCustomerLocationAndPhoto(
        customerId: cust.id,
        latitude: 10.8231,
        longitude: 106.6297,
        identificationNotes: 'Tân Bình, TP.HCM',
      );

      final fakeJpgBytes = Uint8List.fromList([
        0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46, 0x00, 0x01,
        ...List.filled(200, 0xAA),
      ]);
      await photoRepo.addCustomerPhoto(cust.id, 'data:image/jpeg;base64,${base64Encode(fakeJpgBytes)}');

      final backupService = BackupService(
        appDb: appDb,
        customBaseDir: tempDir,
        customPhotosDir: Directory('${tempDir.path}/photos'),
      );

      final zipFile = await backupService.createBackup(includePhotos: true);
      expect(zipFile.existsSync(), isTrue);
      expect(zipFile.path.contains('delivery-backup-'), isTrue);
      expect(zipFile.path.endsWith('.zip'), isTrue);

      // Kiểm tra nội dung file zip
      final preview = await backupService.readBackupPreview(zipFile);
      expect(preview.customersCount, 1);
      expect(preview.savedLocationsCount, 1);
      expect(preview.photosCount, 1);
      expect(preview.includePhotos, isTrue);
      expect(preview.schemaVersion, AppDatabase.currentVersion);
    });

    test('7. BackupService: Từ chối file zip bị sửa đổi (checksum không khớp) và chống Path Traversal', () async {
      final backupService = BackupService(
        appDb: appDb,
        customBaseDir: tempDir,
        customPhotosDir: Directory('${tempDir.path}/photos'),
      );

      final zipFile = await backupService.createBackup(includePhotos: false);

      // 1. Giả mạo nội dung database.db trong zip để làm sai checksum
      final archive = ZipDecoder().decodeBytes(zipFile.readAsBytesSync());
      final tamperedArchive = Archive();
      for (final f in archive) {
        if (f.name == 'database.db') {
          tamperedArchive.addFile(ArchiveFile('database.db', 10, utf8.encode('tampered!!')));
        } else {
          tamperedArchive.addFile(f);
        }
      }
      final tamperedZipFile = File('${tempDir.path}/tampered_backup.zip');
      tamperedZipFile.writeAsBytesSync(ZipEncoder().encode(tamperedArchive));

      expect(
        () async => await backupService.readBackupPreview(tamperedZipFile),
        throwsA(isA<FormatException>()),
        reason: 'Phải từ chối file bị sửa đổi checksum',
      );

      // 2. Kiểm tra chống Path Traversal
      final traversalArchive = Archive();
      traversalArchive.addFile(ArchiveFile('../evil_script.sh', 4, utf8.encode('evil')));
      traversalArchive.addFile(ArchiveFile('manifest.json', 2, utf8.encode('{}')));
      final traversalZip = File('${tempDir.path}/traversal.zip');
      traversalZip.writeAsBytesSync(ZipEncoder().encode(traversalArchive));

      expect(
        () async => await backupService.readBackupPreview(traversalZip),
        throwsA(isA<FormatException>()),
        reason: 'Phải từ chối file chứa đường dẫn ../',
      );
    });

    test('8. BackupService Restore: Chế độ Gộp (Merge) giữ nguyên khách trùng SĐT và bổ sung khách mới', () async {
      final backupService = BackupService(
        appDb: appDb,
        customBaseDir: tempDir,
        customPhotosDir: Directory('${tempDir.path}/photos'),
      );

      // Tạo dữ liệu nguồn A
      final custA = await customerRepo.createCustomer(fullName: 'Khách Gốc', phoneNumber: '0911222333');
      await locationRepo.updateCustomerLocationAndPhoto(
        customerId: custA.id,
        latitude: 10.1,
        longitude: 106.1,
        identificationNotes: 'Địa chỉ Gốc',
      );
      final backupFile = await backupService.createBackup(includePhotos: false);

      // Trong app hiện tại: Sửa tên khách trùng SĐT thành 'Khách Đã Đổi Tên' và thêm khách mới B
      await customerRepo.updateCustomer(customerId: custA.id, fullName: 'Khách Đã Đổi Tên', phoneNumber: '0911222333');
      final custB = await customerRepo.createCustomer(fullName: 'Khách Mới B', phoneNumber: '0944555666');

      // Khôi phục Merge từ bản sao lưu
      final res = await backupService.restoreBackup(backupFile, mode: RestoreMode.merge);
      expect(res.mode, RestoreMode.merge);
      expect(res.skippedCustomers, 1, reason: 'Khách trùng SĐT phải được giữ nguyên, không ghi đè');

      final currentCust = await customerRepo.getCustomerDetail(custA.id);
      expect(currentCust.fullName, 'Khách Đã Đổi Tên', reason: 'Dữ liệu hiện có không được ghi đè âm thầm');

      final allCustomersRes = await customerRepo.getCustomersResponse();
      expect(allCustomersRes.items.any((c) => c.id == custB.id), isTrue, reason: 'Khách mới B vẫn còn');
    });

    testWidgets('9. WelcomeOnboardingView: Màn chào mừng lần đầu mở app cho phép nhập tên', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      bool startFinished = false;
      await tester.pumpWidget(
        MaterialApp(
          home: WelcomeOnboardingView(
            onStartFinished: () => startFinished = true,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('CHÀO MỪNG BẠN!'), findsOneWidget);
      expect(find.byKey(const Key('welcome_display_name_input')), findsOneWidget);
      expect(find.byKey(const Key('welcome_start_btn')), findsOneWidget);

      await tester.enterText(find.byKey(const Key('welcome_display_name_input')), 'Trần Shipper');
      await tester.pump();

      await tester.runAsync(() async {
        await tester.tap(find.byKey(const Key('welcome_start_btn')));
        await Future.delayed(const Duration(milliseconds: 500));
      });
      await tester.pump();

      expect(startFinished, isTrue);
      UserModel? user;
      await tester.runAsync(() async {
        user = await profileRepo.getCurrentUser();
      });
      expect(user?.fullName, 'Trần Shipper');

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('10. PinLockScreen: Bàn phím số lớn, nhập PIN và thông báo lỗi khi sai', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.runAsync(() async {
        await profileRepo.setPin('1234');
      });
      bool unlocked = false;

      await tester.pumpWidget(
        MaterialApp(
          home: PinLockScreen(
            onSuccess: () => unlocked = true,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('MÃ PIN KHÓA ỨNG DỤNG'), findsOneWidget);
      expect(find.byKey(const Key('pin_keypad_1')), findsOneWidget);

      // Nhập PIN sai 0-0-0-0
      await tester.tap(find.byKey(const Key('pin_keypad_0')));
      await tester.tap(find.byKey(const Key('pin_keypad_0')));
      await tester.tap(find.byKey(const Key('pin_keypad_0')));
      await tester.tap(find.byKey(const Key('pin_keypad_0')));
      await tester.pump();

      await tester.runAsync(() async {
        await tester.tap(find.byKey(const Key('pin_submit_btn')));
        await Future.delayed(const Duration(milliseconds: 300));
      });
      await tester.pump();

      expect(unlocked, isFalse);
      expect(find.textContaining('Mã PIN không chính xác'), findsOneWidget);

      // Nhập PIN đúng 1-2-3-4
      await tester.tap(find.byKey(const Key('pin_keypad_1')));
      await tester.tap(find.byKey(const Key('pin_keypad_2')));
      await tester.tap(find.byKey(const Key('pin_keypad_3')));
      await tester.tap(find.byKey(const Key('pin_keypad_4')));
      await tester.pump();

      await tester.runAsync(() async {
        await tester.tap(find.byKey(const Key('pin_submit_btn')));
        await Future.delayed(const Duration(milliseconds: 300));
      });
      await tester.pump();

      expect(unlocked, isTrue);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('11. AccountProfileView: Chế độ Local-First hiển thị "Cá nhân", nút đổi tên, mục PIN và Sao lưu', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.runAsync(() async {
        await tester.pumpWidget(
          const MaterialApp(
            home: AccountProfileView(),
          ),
        );
        await Future.delayed(const Duration(milliseconds: 500));
      });
      await tester.pumpAndSettle();

      // Tiêu đề là "Cá nhân"
      expect(find.text('Cá nhân'), findsOneWidget);
      expect(find.text('Chế độ Local-First (Dữ liệu trên máy)'), findsOneWidget);
      expect(find.byKey(const Key('btn_edit_display_name')), findsOneWidget);

      // Các mục bảo mật & sao lưu
      expect(find.byKey(const Key('profile_pin_item')), findsOneWidget);
      expect(find.byKey(const Key('profile_backup_item')), findsOneWidget);

      // Không hiển thị các nút của chế độ Remote
      expect(find.byKey(const Key('profile_areas_card')), findsNothing);
      expect(find.byKey(const Key('profile_change_password_item')), findsNothing);
      expect(find.byKey(const Key('profile_server_config_item')), findsNothing);
      expect(find.byKey(const Key('profile_logout_btn')), findsNothing);

      await tester.pumpWidget(const SizedBox());
    });
  });
}
