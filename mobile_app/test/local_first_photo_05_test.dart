import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:delivery_marker_mobile/data/database/app_database.dart';
import 'package:delivery_marker_mobile/models/customer_photo_model.dart';
import 'package:delivery_marker_mobile/data/customers/customer_repository.dart';
import 'package:delivery_marker_mobile/data/locations/location_repository.dart';
import 'package:delivery_marker_mobile/data/photos/photo_repository.dart';
import 'package:delivery_marker_mobile/data/shifts/shift_repository.dart';
import 'package:delivery_marker_mobile/data/repository_provider.dart';
import 'package:delivery_marker_mobile/core/widgets/authenticated_image.dart';
import 'package:delivery_marker_mobile/features/photos/customer_photos_strip_widget.dart';
import 'package:delivery_marker_mobile/features/photos/fullscreen_image_viewer.dart';

Uint8List createValidJpeg({int width = 80, int height = 80}) {
  final image = img.Image(width: width, height: height);
  img.fill(image, color: img.ColorRgb8(220, 38, 38));
  return Uint8List.fromList(img.encodeJpg(image, quality: 80));
}

Uint8List createValidPng({int width = 80, int height = 80}) {
  final image = img.Image(width: width, height: height);
  img.fill(image, color: img.ColorRgb8(37, 99, 235));
  return Uint8List.fromList(img.encodePng(image));
}

Uint8List createValidLargeJpeg({int width = 2000, int height = 1500}) {
  final image = img.Image(width: width, height: height);
  img.fill(image, color: img.ColorRgb8(22, 163, 74));
  return Uint8List.fromList(img.encodeJpg(image, quality: 90));
}

String toDataUri(Uint8List bytes, String mime) => 'data:$mime;base64,${base64Encode(bytes)}';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Directory tempDir;
  late AppDatabase appDb;
  late LocalPhotoRepository photoRepo;
  late LocalCustomerRepository customerRepo;

  setUp(() async {
    RepositoryProvider.reset();
    tempDir = Directory.systemTemp.createTempSync('delivery_photo_test_');
    appDb = await AppDatabase.openInMemory(factory: databaseFactoryFfi);
    photoRepo = LocalPhotoRepository(appDb: appDb, baseDirectory: tempDir);
    customerRepo = LocalCustomerRepository(appDb: appDb, photoRepo: photoRepo);
  });

  tearDown(() async {
    RepositoryProvider.reset();
    await appDb.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('TASK: LOCAL-FIRST-05-LOCAL-PHOTOS Tests', () {
    test('1. RepositoryProvider mặc định useLocalData=true và trả về LocalPhotoRepository', () {
      RepositoryProvider.reset();
      expect(RepositoryProvider.useLocalData, isTrue);
      expect(RepositoryProvider.photo, isA<LocalPhotoRepository>());
    });
    test('2. Thêm ảnh hợp lệ (JPEG, PNG) - nén cạnh dài <= 1600px, tạo thumbnail ~300px, ghi CSDL và lưu file UUID', () async {
      final cust = await customerRepo.createCustomer(phoneNumber: '0901111222', fullName: 'Anh Nam');
      final custId = cust.id;

      // Thêm ảnh JPEG lớn 2000x1500
      final largeBytes = createValidLargeJpeg(width: 2000, height: 1500);
      final dataUri = toDataUri(largeBytes, 'image/jpeg');

      final photo = await photoRepo.addCustomerPhoto(custId, dataUri);

      expect(photo.id, isNotEmpty);
      expect(photo.customerId, equals(custId));
      expect(photo.imageUrl, isNotEmpty);

      // Kiểm tra file trên đĩa
      final fullFile = File(photo.imageUrl);
      expect(fullFile.existsSync(), isTrue);

      // Tên file phải là UUID, không chứa SĐT hay tên khách
      final fileName = fullFile.uri.pathSegments.last;
      expect(fileName.contains('0901111222'), isFalse);
      expect(fileName.contains('Nam'), isFalse);

      // Kiểm tra ảnh đã được nén cạnh dài <= 1600px
      final decodedFull = img.decodeImage(await fullFile.readAsBytes());
      expect(decodedFull, isNotNull);
      expect(decodedFull!.width, lessThanOrEqualTo(1600));
      expect(decodedFull.height, lessThanOrEqualTo(1600));

      // Kiểm tra thumbnail ~300px
      final thumbsDir = await photoRepo.getThumbsDirectory();
      final thumbFile = File('${thumbsDir.path}/${photo.id}_thumb.jpg');
      expect(thumbFile.existsSync(), isTrue);

      final decodedThumb = img.decodeImage(await thumbFile.readAsBytes());
      expect(decodedThumb, isNotNull);
      expect(decodedThumb!.width, lessThanOrEqualTo(300));
      expect(decodedThumb.height, lessThanOrEqualTo(300));

      // Kiểm tra ghi activity_log
      final db = await appDb.database;
      final logs = await db.query('activity_log', where: "action = 'ADD_CUSTOMER_PHOTO'");
      expect(logs.length, equals(1));
      expect(logs.first['entity_id'], equals(photo.id));
    });

    test('3. Kiểm tra định dạng Magic Bytes: từ chối file sai định dạng', () async {
      final cust = await customerRepo.createCustomer(phoneNumber: '0902222333');
      final custId = cust.id;

      // Dữ liệu giả không có magic bytes của JPG/PNG/WebP
      final dummyBytes = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14]);
      final invalidUri = toDataUri(dummyBytes, 'text/plain');

      expect(
        () => photoRepo.addCustomerPhoto(custId, invalidUri),
        throwsA(isA<ArgumentError>().having((e) => e.message, 'message', contains('Định dạng ảnh không hợp lệ'))),
      );
    });

    test('4. Kiểm tra giới hạn dung lượng tối đa 5MB', () async {
      final cust = await customerRepo.createCustomer(phoneNumber: '0903333444');
      final custId = cust.id;

      // Giả lập file lớn hơn 5MB với magic bytes JPEG
      final hugeBytes = Uint8List(5 * 1024 * 1024 + 1024);
      hugeBytes[0] = 0xFF;
      hugeBytes[1] = 0xD8;
      hugeBytes[2] = 0xFF;
      final hugeUri = toDataUri(hugeBytes, 'image/jpeg');

      expect(
        () => photoRepo.addCustomerPhoto(custId, hugeUri),
        throwsA(isA<ArgumentError>().having((e) => e.message, 'message', contains('vượt quá giới hạn 5MB'))),
      );
    });

    test('5. Giới hạn tối đa 10 ảnh/khách hàng', () async {
      final cust = await customerRepo.createCustomer(phoneNumber: '0904444555');
      final custId = cust.id;

      final sampleBytes = createValidJpeg(width: 20, height: 20);
      final sampleUri = toDataUri(sampleBytes, 'image/jpeg');

      // Thêm 10 ảnh thành công
      for (int i = 0; i < 10; i++) {
        await photoRepo.addCustomerPhoto(custId, sampleUri);
      }

      final photos = await photoRepo.getCustomerPhotos(custId);
      expect(photos.length, equals(10));

      // Thêm ảnh thứ 11 phải bị từ chối
      expect(
        () => photoRepo.addCustomerPhoto(custId, sampleUri),
        throwsA(isA<StateError>().having((e) => e.message, 'message', contains('tối đa 10 ảnh'))),
      );
    });

    test('6. Lỗi ghi DB thì file vừa tạo bị xóa dọn sạch (không để lại file mồ côi)', () async {
      final cust = await customerRepo.createCustomer(phoneNumber: '0905555666');
      final custId = cust.id;

      final db = await appDb.database;

      // Tạo trigger giả lập lỗi DB khi ghi vào customer_photos
      await db.execute('''
        CREATE TRIGGER test_abort_photo_insert BEFORE INSERT ON customer_photos
        BEGIN
          SELECT RAISE(ABORT, 'Simulated SQLite DB failure');
        END;
      ''');

      final sampleBytes = createValidJpeg(width: 30, height: 30);
      final sampleUri = toDataUri(sampleBytes, 'image/jpeg');

      // Thực hiện thêm ảnh, kỳ vọng ném lỗi
      await expectLater(
        photoRepo.addCustomerPhoto(custId, sampleUri),
        throwsA(anything),
      );

      // Kiểm tra thư mục photos và thumbs: tuyệt đối không có file mồ côi sót lại
      final photosDir = await photoRepo.getPhotosDirectory();
      final thumbsDir = await photoRepo.getThumbsDirectory();

      final remainingPhotos = photosDir.listSync().whereType<File>();
      final remainingThumbs = thumbsDir.listSync().whereType<File>();

      expect(remainingPhotos, isEmpty);
      expect(remainingThumbs, isEmpty);
    });

    test('7. Xóa mềm (deleted_at) giữ file; dọn sau 30 ngày xóa sạch file & CSDL', () async {
      final cust = await customerRepo.createCustomer(phoneNumber: '0906666777');
      final custId = cust.id;

      final sampleBytes = createValidJpeg(width: 40, height: 40);
      final sampleUri = toDataUri(sampleBytes, 'image/jpeg');

      final photo = await photoRepo.addCustomerPhoto(custId, sampleUri);
      final fullFile = File(photo.imageUrl);
      final thumbsDir = await photoRepo.getThumbsDirectory();
      final thumbFile = File('${thumbsDir.path}/${photo.id}_thumb.jpg');

      expect(fullFile.existsSync(), isTrue);
      expect(thumbFile.existsSync(), isTrue);

      // 1. Xóa mềm
      await photoRepo.deleteCustomerPhoto(custId, photo.id);

      // getCustomerPhotos không còn trả ảnh này
      final activePhotos = await photoRepo.getCustomerPhotos(custId);
      expect(activePhotos, isEmpty);

      // Nhưng file trên đĩa vẫn còn nguyên (chưa xóa ngay)
      expect(fullFile.existsSync(), isTrue);
      expect(thumbFile.existsSync(), isTrue);

      // 2. Chạy dọn dẹp ảnh xóa mềm quá 30 ngày (hiện tại chưa quá hạn nên không xóa)
      final countUnexpired = await photoRepo.purgeDeletedPhotosOlderThan(olderThan: const Duration(days: 30));
      expect(countUnexpired, equals(0));
      expect(fullFile.existsSync(), isTrue);

      // 3. Cập nhật deleted_at thành 35 ngày trước
      final db = await appDb.database;
      final pastDate = DateTime.now().toUtc().subtract(const Duration(days: 35)).toIso8601String();
      await db.update(
        'customer_photos',
        {'deleted_at': pastDate},
        where: 'id = ?',
        whereArgs: [photo.id],
      );

      // 4. Chạy lại dọn dẹp: ảnh bị dọn sạch cả file và row trong CSDL
      final countExpired = await photoRepo.purgeDeletedPhotosOlderThan(olderThan: const Duration(days: 30));
      expect(countExpired, equals(1));

      expect(fullFile.existsSync(), isFalse);
      expect(thumbFile.existsSync(), isFalse);

      final dbRows = await db.query('customer_photos', where: 'id = ?', whereArgs: [photo.id]);
      expect(dbRows, isEmpty);

      // Kiểm tra ghi activity_log
      final logs = await db.query('activity_log', where: "action = 'PURGE_EXPIRED_PHOTOS'");
      expect(logs.isNotEmpty, isTrue);
    });

    test('8. photoCount và 3 ảnh đầu đúng; hai khách hàng không lẫn ảnh của nhau', () async {
      final custA = await customerRepo.createCustomer(phoneNumber: '0901111111', fullName: 'Khách A');
      final custB = await customerRepo.createCustomer(phoneNumber: '0902222222', fullName: 'Khách B');
      final idA = custA.id;
      final idB = custB.id;

      final sampleBytes = createValidJpeg(width: 30, height: 30);
      final sampleUri = toDataUri(sampleBytes, 'image/jpeg');

      // Khách A có 4 ảnh
      for (int i = 0; i < 4; i++) {
        await photoRepo.addCustomerPhoto(idA, sampleUri);
      }

      // Khách B có 1 ảnh
      await photoRepo.addCustomerPhoto(idB, sampleUri);

      // Tóm tắt ảnh cho khách A: count = 4, top 3 thumbnails
      final summaryA = await photoRepo.getCustomerPhotoSummary(idA, limit: 3);
      expect(summaryA['photoCount'], equals(4));
      final photosA = summaryA['photos'] as List<CustomerPhotoModel>;
      expect(photosA.length, equals(3));
      for (final p in photosA) {
        expect(p.customerId, equals(idA));
        expect(p.imageUrl.contains('_thumb'), isTrue);
      }

      // Tóm tắt ảnh cho khách B: count = 1, top 1 thumbnail
      final summaryB = await photoRepo.getCustomerPhotoSummary(idB, limit: 3);
      expect(summaryB['photoCount'], equals(1));
      final photosB = summaryB['photos'] as List<CustomerPhotoModel>;
      expect(photosB.length, equals(1));
      expect(photosB.first.customerId, equals(idB));

      // getBatchPhotoSummaries đồng thời cho 2 khách
      final batch = await photoRepo.getBatchPhotoSummaries([idA, idB], limit: 3);
      expect(batch[idA]!['photoCount'], equals(4));
      expect((batch[idA]!['photos'] as List).length, equals(3));
      expect(batch[idB]!['photoCount'], equals(1));
      expect((batch[idB]!['photos'] as List).length, equals(1));
    });

    test('9. Đồng bộ photoCount và 3 ảnh đầu sang CustomerRepository, LocationRepository và ShiftRepository', () async {
      final locRepo = LocalLocationRepository(appDb: appDb, photoRepo: photoRepo);
      final shiftRepo = LocalShiftRepository(appDb: appDb, photoRepo: photoRepo);

      final cust = await customerRepo.createCustomer(phoneNumber: '0909999888', fullName: 'Chị Mai');
      final custId = cust.id;

      // Thêm 2 ảnh cho khách
      final sampleBytes = createValidJpeg(width: 40, height: 40);
      final sampleUri = toDataUri(sampleBytes, 'image/jpeg');
      await photoRepo.addCustomerPhoto(custId, sampleUri);
      await photoRepo.addCustomerPhoto(custId, sampleUri);

      // 1. Kiểm tra CustomerRepository (Danh bạ & Chi tiết)
      final dirResp = await customerRepo.getCustomersResponse();
      final dirItem = dirResp.items.firstWhere((c) => c.id == custId);
      expect(dirItem.photoCount, equals(2));
      expect(dirItem.photos.length, equals(2));
      expect(dirItem.firstThumbnailUrl, isNotNull);

      final custDetail = await customerRepo.getCustomerDetail(custId);
      expect(custDetail.photoCount, equals(2));
      expect(custDetail.photos.length, equals(2));

      // 2. Lưu vị trí và kiểm tra LocationRepository (Bản đồ chính)
      await locRepo.updateCustomerLocationAndPhoto(
        customerId: custId,
        latitude: 10.762622,
        longitude: 106.660172,
        identificationNotes: 'Nhà có cổng xanh',
      );

      final savedLocs = await locRepo.getMySavedLocations();
      final locItem = savedLocs.firstWhere((l) => l.customerId == custId);
      expect(locItem.photoCount, equals(2));
      expect(locItem.photos.length, equals(2));
      expect(locItem.imageUrl, isNotNull);

      // 3. Tạo ca và kiểm tra ShiftRepository (Bản đồ ca)
      final shift = await shiftRepo.createShift(shiftName: 'Ca giao chiều');
      await shiftRepo.addPointToShift(shift.id, customerId: custId);

      final shiftDetail = await shiftRepo.getShiftDetail(shift.id);
      final pointItem = shiftDetail.deliveryPoints.firstWhere((p) => p.customerId == custId);
      expect(pointItem.photoCount, equals(2));
      expect(pointItem.photos.length, equals(2));
      expect(pointItem.photoUrl, isNotNull);
    });

    testWidgets('10. Widget AuthenticatedImage hiển thị ảnh cục bộ qua Image.file', (tester) async {
      RepositoryProvider.overrideRepositories(photo: photoRepo);

      final sampleFile = File('${tempDir.path}/test_photo_10.jpg');
      sampleFile.writeAsBytesSync(createValidJpeg(width: 50, height: 50));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AuthenticatedImage(
              photoUrl: sampleFile.path,
              width: 100,
              height: 100,
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Kiểm tra Image widget hiển thị từ file cục bộ
      final imageFinder = find.byType(Image);
      expect(imageFinder, findsOneWidget);

      final imageWidget = tester.widget<Image>(imageFinder);
      final ImageProvider provider = imageWidget.image;
      final fileImage = provider is ResizeImage ? provider.imageProvider as FileImage : provider as FileImage;
      expect(fileImage.file.path, equals(sampleFile.path));
    });

    testWidgets('11. CustomerPhotosStripWidget: Nút thêm ảnh >= 56px, chạm mở camera, hiển thị dải ảnh, chạm xem fullscreen', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));
      RepositoryProvider.overrideRepositories(photo: photoRepo);

      final sampleFile = File('${tempDir.path}/test_photo_11.jpg');
      sampleFile.writeAsBytesSync(createValidJpeg(width: 60, height: 60));

      final photo = CustomerPhotoModel(
        id: 'photo_test_11',
        customerId: 'customer_11',
        imageUrl: sampleFile.path,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomerPhotosStripWidget(
              customerId: 'customer_11',
              customerName: 'Bác Tư',
              initialPhotos: [photo],
              canAddPhoto: true,
              canDeletePhoto: true,
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // 1. Kiểm tra nút THÊM ẢNH có kích thước >= 56px
      final addBtnFinder = find.byKey(const ValueKey('btn_add_photo'));
      expect(addBtnFinder, findsOneWidget);
      final addBtnSize = tester.getSize(addBtnFinder);
      expect(addBtnSize.height, greaterThanOrEqualTo(56.0));

      // 2. Chạm vào ảnh mở FullscreenImageViewer
      final photoFinder = find.byType(AuthenticatedImage);
      expect(photoFinder, findsOneWidget);

      await tester.tap(photoFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(FullscreenImageViewer), findsOneWidget);
      expect(find.textContaining('Bác Tư'), findsOneWidget);

      // Đóng viewer
      await tester.tap(find.byTooltip('Đóng'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(FullscreenImageViewer), findsNothing);

      // 3. Nhấn giữ vào ảnh hiện hộp thoại xác nhận xóa
      await tester.longPress(find.byType(AuthenticatedImage));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Xóa ảnh này?'), findsOneWidget);
      expect(find.text('XÓA ẢNH'), findsOneWidget);

      // Bấm hủy
      await tester.tap(find.text('HỦY'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Xóa ảnh này?'), findsNothing);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Xóa ảnh này?'), findsNothing);
    });
  });
}
