import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:delivery_marker_mobile/data/local/app_database.dart';
import 'package:delivery_marker_mobile/models/local_share_models.dart';
import 'package:delivery_marker_mobile/models/location_model.dart';
import 'package:delivery_marker_mobile/models/shift_model.dart';
import 'package:delivery_marker_mobile/data/local/local_customer_repository.dart';
import 'package:delivery_marker_mobile/data/local/local_location_repository.dart';
import 'package:delivery_marker_mobile/data/local/local_photo_repository.dart';
import 'package:delivery_marker_mobile/data/local/local_profile_repository.dart';
import 'package:delivery_marker_mobile/data/local/local_sharing_repository.dart';
import 'package:delivery_marker_mobile/data/local/local_shift_repository.dart';
import 'package:delivery_marker_mobile/data/repositories/repository_provider.dart';
import 'package:delivery_marker_mobile/core/utils/share_crypto_utils.dart';
import 'package:delivery_marker_mobile/features/profile/account_profile_view.dart';
import 'package:delivery_marker_mobile/features/sharing/data_share_qr_view.dart';
import 'package:delivery_marker_mobile/features/sharing/data_share_send_sheet.dart';
import 'package:delivery_marker_mobile/shared_widgets/point_detail_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('TASK: LOCAL-FIRST-07-SHARE-BY-FILE-AND-QR Tests', () {
    late Directory dirA;
    late Directory dirB;
    late AppDatabase dbA;
    late AppDatabase dbB;
    late LocalCustomerRepository custRepoA;
    late LocalLocationRepository locRepoA;
    late LocalPhotoRepository photoRepoA;
    late LocalShiftRepository shiftRepoA;
    late LocalProfileRepository profileRepoA;
    late LocalSharingRepository sharingRepoA;

    late LocalCustomerRepository custRepoB;
    late LocalLocationRepository locRepoB;
    late LocalPhotoRepository photoRepoB;
    late LocalShiftRepository shiftRepoB;
    late LocalSharingRepository sharingRepoB;

    setUp(() async {
      // 1. Tạo môi trường máy A
      dirA = Directory.systemTemp.createTempSync('share_test_a_');
      final dbPathA = '${dirA.path}/local_a.db';
      dbA = AppDatabase(factory: databaseFactoryFfi, customPath: dbPathA);
      await dbA.database;
      await dbA.setAppProfile(displayName: 'Shipper A', pinHash: 'dummy_hash');

      photoRepoA = LocalPhotoRepository(appDb: dbA, baseDirectory: dirA);
      custRepoA = LocalCustomerRepository(appDb: dbA, photoRepo: photoRepoA);
      locRepoA = LocalLocationRepository(appDb: dbA, photoRepo: photoRepoA);
      shiftRepoA = LocalShiftRepository(appDb: dbA, photoRepo: photoRepoA);
      profileRepoA = LocalProfileRepository(appDb: dbA);
      sharingRepoA = LocalSharingRepository(appDb: dbA, photoRepo: photoRepoA, customBaseDir: dirA);

      // 2. Tạo môi trường máy B (trống)
      dirB = Directory.systemTemp.createTempSync('share_test_b_');
      final dbPathB = '${dirB.path}/local_b.db';
      dbB = AppDatabase(factory: databaseFactoryFfi, customPath: dbPathB);
      await dbB.database;
      await dbB.setAppProfile(displayName: 'Shipper B', pinHash: 'dummy_hash');

      photoRepoB = LocalPhotoRepository(appDb: dbB, baseDirectory: dirB);
      custRepoB = LocalCustomerRepository(appDb: dbB, photoRepo: photoRepoB);
      locRepoB = LocalLocationRepository(appDb: dbB, photoRepo: photoRepoB);
      shiftRepoB = LocalShiftRepository(appDb: dbB, photoRepo: photoRepoB);
      sharingRepoB = LocalSharingRepository(appDb: dbB, photoRepo: photoRepoB, customBaseDir: dirB);

      RepositoryProvider.useLocalData = true;
      RepositoryProvider.overrideRepositories(
        customer: custRepoA,
        location: locRepoA,
        photo: photoRepoA,
        shift: shiftRepoA,
        profile: profileRepoA,
        sharing: sharingRepoA,
      );
    });

    tearDown(() async {
      RepositoryProvider.reset();
      await dbA.close();
      await dbB.close();
      try {
        if (dirA.existsSync()) dirA.deleteSync(recursive: true);
        if (dirB.existsSync()) dirB.deleteSync(recursive: true);
      } catch (_) {}
    });

    // Helper tạo dữ liệu mẫu trên máy A: 1 khách hàng + 1 vị trí đã lưu + 1 ảnh JPEG
    Future<String> seedSamplePointOnDeviceA({
      String name = 'Nguyễn Văn A',
      String phone = '0912345678',
      String address = '123 Phố Huế, Hai Bà Trưng, Hà Nội',
      double lat = 21.012345,
      double lng = 105.854321,
    }) async {
      final cust = await custRepoA.createCustomer(
        fullName: name,
        phoneNumber: phone,
        addressText: address,
      );

      await locRepoA.saveCustomerLocation(
        SavedLocationModel(
          customerId: cust.id,
          latitude: lat,
          longitude: lng,
          gpsAccuracy: 5.0,
          identificationNotes: 'Cổng sắt màu xanh',
        ),
      );

      // Thêm ảnh JPEG hợp lệ
      final sampleJpgBytes = Uint8List.fromList([
        0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46, 0x00, 0x01,
        0x01, 0x01, 0x00, 0x48, 0x00, 0x48, 0x00, 0x00, 0xFF, 0xDB, 0x00, 0x43,
        0x00, 0xFF, 0xD9,
      ]);
      final base64Img = base64Encode(sampleJpgBytes);
      await photoRepoA.addCustomerPhoto(cust.id, base64Img);

      return cust.id;
    }

    test('1. Tạo gói chia sẻ đầy đủ và nhập vào máy B (DB trống): đủ điểm, ảnh, đúng tọa độ', () async {
      await seedSamplePointOnDeviceA();

      // 1. Máy A xuất file .dshare có kèm ảnh
      final shareFile = await sharingRepoA.exportSharePackage(
        scope: 'all',
        includeCustomerInfo: true,
        includePhotos: true,
      );
      expect(shareFile.existsSync(), isTrue);
      expect(shareFile.path.endsWith('.dshare'), isTrue);

      // 2. Máy B kiểm tra và xem trước gói
      final preview = await sharingRepoB.inspectPackageFile(shareFile);
      expect(preview.validPointsCount, 1);
      expect(preview.newCount, 1);
      expect(preview.manifest.senderDisplayName, 'Shipper A');
      expect(preview.photos.length, 1);

      // 3. Máy B thực hiện nhập dữ liệu
      final result = await sharingRepoB.importPackage(
        preview: preview,
        mode: ShareImportMode.addOnly,
        selectedIndexes: {0},
      );

      expect(result.addedCount, 1);
      expect(result.photosAdded, 1);
      expect(result.replacedCount, 0);
      expect(result.skippedCount, 0);

      // 4. Kiểm tra CSDL máy B
      final customersB = await custRepoB.getCustomers();
      expect(customersB.length, 1);
      expect(customersB.first.phoneNumber, '0912345678');
      expect(customersB.first.fullName, 'Nguyễn Văn A');
      expect(customersB.first.addressText, '123 Phố Huế, Hai Bà Trưng, Hà Nội');

      final locsB = await locRepoB.getMySavedLocations();
      expect(locsB.length, 1);
      expect(locsB.first.latitude, closeTo(21.012345, 0.000001));
      expect(locsB.first.longitude, closeTo(105.854321, 0.000001));
      expect(locsB.first.identificationNotes, 'Cổng sắt màu xanh');

      final photosB = await photoRepoB.getCustomerPhotos(customersB.first.id);
      expect(photosB.length, 1);
    });

    test('2. Các phạm vi chia sẻ: tất cả, 1 ca, các điểm chọn', () async {
      final custId1 = await seedSamplePointOnDeviceA(phone: '0911111111', name: 'Khách 1');
      final custId2 = await seedSamplePointOnDeviceA(phone: '0922222222', name: 'Khách 2');

      // Tạo một ca làm việc chứa riêng khách 1
      final shift = await shiftRepoA.createShift(shiftName: 'Ca Chiều', shiftDate: '2026-10-27');
      await shiftRepoA.addPointToShift(shift.id, customerId: custId1);

      // A. Scope: all
      final allPoints = await sharingRepoA.collectPointsForExport(scope: 'all');
      expect(allPoints.length, 2);

      // B. Scope: shift
      final shiftPoints = await sharingRepoA.collectPointsForExport(scope: 'shift', shiftId: shift.id);
      expect(shiftPoints.length, 1);
      expect(shiftPoints.first.phoneNumber, '0911111111');

      // C. Scope: selected
      final selectedPoints = await sharingRepoA.collectPointsForExport(
        scope: 'selected',
        customerIds: [custId2],
      );
      expect(selectedPoints.length, 1);
      expect(selectedPoints.first.phoneNumber, '0922222222');
    });

    test('3. Các công tắc riêng tư: tắt ảnh, tắt tên & địa chỉ', () async {
      await seedSamplePointOnDeviceA(name: 'Bác Ba Phi', phone: '0933333333', address: 'Cà Mau');

      // Tắt tên & địa chỉ, tắt ảnh
      final points = await sharingRepoA.collectPointsForExport(
        scope: 'all',
        includeCustomerInfo: false,
        includePhotos: false,
      );

      expect(points.length, 1);
      expect(points.first.phoneNumber, '0933333333');
      expect(points.first.fullName, isNull);
      expect(points.first.addressText, isNull);
      expect(points.first.photoFileNames, isEmpty);
    });

    test('4. Mã hóa bằng mật khẩu (AES-GCM): đúng mở được, sai từ chối rõ ràng', () async {
      await seedSamplePointOnDeviceA();

      final encryptedFile = await sharingRepoA.exportSharePackage(
        scope: 'all',
        password: 'Password@123',
      );

      // Mở không có mật khẩu -> FormatException yêu cầu mật khẩu
      expect(
        () => sharingRepoB.inspectPackageFile(encryptedFile),
        throwsA(predicate((e) => e is FormatException && e.message.contains('GÓI_YÊU_CẦU_MẬT_KHẨU'))),
      );

      // Mở với sai mật khẩu -> FormatException báo mật khẩu sai
      expect(
        () => sharingRepoB.inspectPackageFile(encryptedFile, password: 'WrongPassword'),
        throwsA(predicate((e) => e is FormatException && e.message.contains('Mật khẩu không chính xác'))),
      );

      // Mở đúng mật khẩu -> Thành công
      final preview = await sharingRepoB.inspectPackageFile(encryptedFile, password: 'Password@123');
      expect(preview.validPointsCount, 1);
      expect(preview.classifiedPoints.first.point.phoneNumber, '0912345678');
    });

    test('5. Mã QR: chia mảnh 1/N, ghép đủ thì nhập được, thiếu mảnh báo thiếu', () async {
      // Tạo danh sách điểm đủ dài để buộc chia mảnh (> 1.4KB sau khi nén gzip)
      final List<Map<String, dynamic>> dummyPoints = [];
      for (int i = 0; i < 70; i++) {
        dummyPoints.add({
          'phone': '09${i.toString().padLeft(8, '0')}',
          'name': 'Khách hàng thử nghiệm dài tên số $i',
          'address': 'Địa chỉ số $i ngõ 123 đường Giải Phóng, phường Phương Liệt, quận Thanh Xuân, Hà Nội - Thông tin chi tiết để nén',
          'lat': 21.0 + (i * 0.001),
          'lng': 105.8 + (i * 0.001),
          'notes': 'Ghi chú chi tiết cổng sau số $i, bấm chuông 2 lần hoặc gọi trước 15 phút khi đến',
          'ts': DateTime.now().toIso8601String(),
        });
      }

      final jsonPayload = jsonEncode({'enc': false, 'sender': 'Shipper A', 'points': dummyPoints});
      final chunks = ShareCryptoUtils.createQrChunks(jsonPayload, maxChunkChars: 500);

      expect(chunks.length, greaterThan(1));
      expect(chunks.first.startsWith('DSHARE:1:${chunks.length}:'), isTrue);

      final collector = QrChunkCollector();

      // Quét mảnh 1
      final status1 = collector.addRawCode(chunks[0]);
      expect(status1.isComplete, isFalse);
      expect(status1.scannedCount, 1);
      expect(status1.missingIndexes, contains(2));

      // Quét thiếu: thử giải nén khi chưa đủ -> quăng StateError
      expect(() => collector.assembleAndDecode(), throwsStateError);

      // Quét các mảnh còn lại
      for (int i = 1; i < chunks.length; i++) {
        collector.addRawCode(chunks[i]);
      }

      expect(collector.isComplete, isTrue);
      expect(collector.missingIndexes, isEmpty);

      // Ghép nối hoàn chỉnh
      final reconstructed = collector.assembleAndDecode();
      final decodedMap = jsonDecode(reconstructed) as Map<String, dynamic>;
      expect(decodedMap['sender'], 'Shipper A');
      expect((decodedMap['points'] as List).length, 70);
    });

    test('6. Gói giả mạo / lỗi: path traversal "../", sai checksum, schema mới hơn, tọa độ ngoài dải', () async {
      // 6.1. File zip chứa đường dẫn bất thường "../hack.txt"
      final badArchive = Archive();
      final manifestBytes = utf8.encode('{"formatVersion":1,"schemaVersion":1,"checksums":{}}');
      badArchive.addFile(ArchiveFile('manifest.json', manifestBytes.length, manifestBytes));
      badArchive.addFile(ArchiveFile('../hack.txt', 4, utf8.encode('hack')));
      final badZipBytes = ZipEncoder().encode(badArchive);

      final badFile = File('${dirA.path}/path_traversal.dshare');
      await badFile.writeAsBytes(badZipBytes);

      expect(
        () => sharingRepoB.inspectPackageFile(badFile),
        throwsA(predicate((e) => e is FormatException && e.message.contains('Path Traversal'))),
      );

      // 6.2. Schema version mới hơn app (schemaVersion = 99)
      final newerArchive = Archive();
      final newerManifestBytes = utf8.encode(jsonEncode({
        'formatVersion': 1,
        'schemaVersion': 99,
        'senderDisplayName': 'Shipper Future',
        'pointsCount': 1,
        'checksums': {},
      }));
      newerArchive.addFile(ArchiveFile('manifest.json', newerManifestBytes.length, newerManifestBytes));
      final newerZipBytes = ZipEncoder().encode(newerArchive);

      final newerFile = File('${dirA.path}/newer_schema.dshare');
      await newerFile.writeAsBytes(newerZipBytes);

      expect(
        () => sharingRepoB.inspectPackageFile(newerFile),
        throwsA(predicate((e) => e is FormatException && e.message.contains('phiên bản ứng dụng mới hơn'))),
      );

      // 6.3. Checksum SHA-256 bị sửa đổi
      final tamperedArchive = Archive();
      final fakePointsBytes = utf8.encode('[{"phone":"0912345678","lat":21.0,"lng":105.8,"ts":""}]');
      final tamperedManifestBytes = utf8.encode(jsonEncode({
        'formatVersion': 1,
        'schemaVersion': 1,
        'senderDisplayName': 'Shipper Test',
        'pointsCount': 1,
        'checksums': {'points.json': '0000000000000000000000000000000000000000000000000000000000000000'},
      }));
      tamperedArchive.addFile(ArchiveFile('manifest.json', tamperedManifestBytes.length, tamperedManifestBytes));
      tamperedArchive.addFile(ArchiveFile('points.json', fakePointsBytes.length, fakePointsBytes));
      final tamperedZipBytes = ZipEncoder().encode(tamperedArchive);

      final tamperedFile = File('${dirA.path}/tampered.dshare');
      await tamperedFile.writeAsBytes(tamperedZipBytes);

      expect(
        () => sharingRepoB.inspectPackageFile(tamperedFile),
        throwsA(predicate((e) => e is FormatException && e.message.contains('không khớp mã kiểm tra'))),
      );

      // 6.4. Tọa độ ngoài dải [-90, 90] và [-180, 180] -> đánh dấu invalid và bỏ qua an toàn
      final invalidCoordsPayload = jsonEncode({
        'enc': false,
        'sender': 'Shipper Test',
        'points': [
          {'phone': '0912345678', 'lat': 120.0, 'lng': 105.8, 'ts': ''}, // Lat sai
          {'phone': '0987654321', 'lat': 21.0, 'lng': 200.0, 'ts': ''}, // Lng sai
          {'phone': '0911223344', 'lat': 21.0, 'lng': 105.8, 'ts': ''}, // Hợp lệ
        ],
      });

      final previewCoords = await sharingRepoB.inspectQrPayload(invalidCoordsPayload);
      expect(previewCoords.totalPoints, 3);
      expect(previewCoords.invalidCount, 2);
      expect(previewCoords.validPointsCount, 1);
      expect(previewCoords.classifiedPoints[0].classification, SharePointClassification.invalid);
      expect(previewCoords.classifiedPoints[1].classification, SharePointClassification.invalid);
      expect(previewCoords.classifiedPoints[2].classification, SharePointClassification.newCustomer);
    });

    test('7. Xung đột dữ liệu: trùng SĐT có vị trí (khoảng cách), chế độ thay thế vs bỏ qua', () async {
      // 1. Máy B đã có khách 0912345678 tại tọa độ (21.000000, 105.800000)
      final custB = await custRepoB.createCustomer(fullName: 'Khách B', phoneNumber: '0912345678');
      await locRepoB.saveCustomerLocation(
        SavedLocationModel(
          customerId: custB.id,
          latitude: 21.000000,
          longitude: 105.800000,
          gpsAccuracy: 5.0,
          identificationNotes: 'Nhà cũ',
        ),
      );

      // 2. Nhận điểm cùng SĐT 0912345678 nhưng tọa độ mới (21.000500, 105.800500)
      final payload = jsonEncode({
        'enc': false,
        'sender': 'Shipper A',
        'points': [
          {'phone': '0912345678', 'name': 'Khách A Mới', 'lat': 21.000500, 'lng': 105.800500, 'ts': ''},
        ],
      });

      final preview = await sharingRepoB.inspectQrPayload(payload);
      expect(preview.existingWithLocCount, 1);
      final item = preview.classifiedPoints.first;
      expect(item.classification, SharePointClassification.existingWithLocation);
      expect(item.distanceMeters, greaterThan(0));
      expect(item.formattedDistance, isNotEmpty);

      // A. Nhập với chế độ addOnly: BỎ QUA không ghi đè
      final resAddOnly = await sharingRepoB.importPackage(
        preview: preview,
        mode: ShareImportMode.addOnly,
        selectedIndexes: {0},
      );
      expect(resAddOnly.skippedCount, 1);
      expect(resAddOnly.replacedCount, 0);

      var locAfterAddOnly = (await locRepoB.getMySavedLocations()).first;
      expect(locAfterAddOnly.latitude, closeTo(21.000000, 0.00001));

      // B. Nhập với chế độ replaceExisting: THAY VỊ TRÍ và kiểm tra lịch sử được lưu
      final resReplace = await sharingRepoB.importPackage(
        preview: preview,
        mode: ShareImportMode.replaceExisting,
        selectedIndexes: {0},
      );
      expect(resReplace.replacedCount, 1);

      var locAfterReplace = (await locRepoB.getMySavedLocations()).first;
      expect(locAfterReplace.latitude, closeTo(21.000500, 0.00001));

      // Kiểm tra vị trí cũ được trigger lưu vào location_history
      final history = await locRepoB.getLocationHistory(custB.id);
      expect(history.length, greaterThanOrEqualTo(1));
      expect((history.first['latitude'] as num).toDouble(), closeTo(21.000000, 0.00001));
    });

    test('8. Nhập thành một ca mới: tạo ca đúng tên, các điểm vào ca đúng trạng thái VERIFIED', () async {
      final payload = jsonEncode({
        'enc': false,
        'sender': 'Tuấn Shipper',
        'points': [
          {'phone': '0988888888', 'name': 'Khách Ca 1', 'lat': 21.01, 'lng': 105.81, 'ts': ''},
          {'phone': '0999999999', 'name': 'Khách Ca 2', 'lat': 21.02, 'lng': 105.82, 'ts': ''},
        ],
      });

      final preview = await sharingRepoB.inspectQrPayload(payload);

      final result = await sharingRepoB.importPackage(
        preview: preview,
        mode: ShareImportMode.addOnly,
        selectedIndexes: {0, 1},
        createShift: true,
        shiftName: 'Từ Tuấn 27/10',
      );

      expect(result.createdShiftId, isNotNull);
      expect(result.createdShiftName, 'Từ Tuấn 27/10');
      expect(result.addedCount, 2);

      final shifts = await shiftRepoB.getShifts();
      expect(shifts.length, 1);
      expect(shifts.first.shiftName, 'Từ Tuấn 27/10');

      final shiftDetail = await shiftRepoB.getShiftDetail(result.createdShiftId!);
      expect(shiftDetail.deliveryPoints.length, 2);
      expect(shiftDetail.deliveryPoints[0].locationStatus, LocationStatus.verified);
      expect(shiftDetail.deliveryPoints[1].locationStatus, LocationStatus.verified);
    });

    testWidgets('9. Widget test: Tab Cá nhân có mục Chia sẻ dữ liệu với 2 nút GỬI DỮ LIỆU và NHẬN DỮ LIỆU', (tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.runAsync(() async {
        await profileRepoA.updateDisplayName('Bác Tài A');
        await tester.pumpWidget(
          const MaterialApp(
            home: AccountProfileView(),
          ),
        );
        await Future.delayed(const Duration(milliseconds: 500));
      });
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(const Key('profile_btn_send_share')));
      expect(find.byKey(const Key('profile_btn_send_share')), findsOneWidget);
      expect(find.byKey(const Key('profile_btn_receive_share')), findsOneWidget);
      expect(find.text('GỬI DỮ LIỆU'), findsOneWidget);
      expect(find.text('NHẬN DỮ LIỆU'), findsOneWidget);
    });

    testWidgets('10. Widget test: DataShareSendSheet hiển thị dòng cảnh báo cố định không thu hồi được', (tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.runAsync(() async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: SizedBox(
                height: 1200,
                width: 500,
                child: DataShareSendSheet(),
              ),
            ),
          ),
        );
        await Future.delayed(const Duration(milliseconds: 500));
      });
      await tester.pumpAndSettle();

      // Khẳng định dòng cảnh báo bắt buộc tồn tại
      expect(find.byKey(const Key('share_warning_banner')), findsOneWidget);
      expect(
        find.textContaining('Dữ liệu chứa số điện thoại và địa chỉ khách. Đã gửi thì không thu hồi được.'),
        findsOneWidget,
      );

      // Cuộn để thấy các nút chia sẻ
      await tester.ensureVisible(find.byKey(const Key('btn_export_file_and_send')));
      expect(find.byKey(const Key('btn_export_file_and_send')), findsOneWidget);

      await tester.ensureVisible(find.byKey(const Key('btn_export_qr_code')));
      expect(find.byKey(const Key('btn_export_qr_code')), findsOneWidget);
    });

    testWidgets('11. Widget test: PointDetailBottomSheet hiển thị nút chia sẻ nhanh điểm', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 800,
              width: 500,
              child: PointDetailBottomSheet(
                customerId: 'cust-123',
                customerName: 'Trần Văn B',
                customerPhone: '0901234567',
                customerAddress: 'Số 10 Hàng Đào, Hà Nội',
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byKey(const Key('btn_quick_share_point')), findsOneWidget);
    });

    testWidgets('12. Widget test: DataShareQrView hiển thị mã QR và nút điều hướng mảnh', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: DataShareQrView(
            qrChunks: ['DSHARE:1:2:12345678:CHUNK1', 'DSHARE:2:2:12345678:CHUNK2'],
            pointsCount: 10,
            senderName: 'Shipper Tuấn',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('MÃ 1 / 2'), findsOneWidget);
      expect(find.text('10 điểm giao từ Shipper Tuấn'), findsOneWidget);
      expect(find.byKey(const Key('qr_btn_next')), findsOneWidget);
      expect(find.byKey(const Key('qr_btn_prev')), findsOneWidget);
    });
  });
}
