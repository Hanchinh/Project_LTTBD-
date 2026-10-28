import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:delivery_marker_mobile/data/local/app_database.dart';
import 'package:delivery_marker_mobile/models/location_model.dart';
import 'package:delivery_marker_mobile/models/shift_model.dart';
import 'package:delivery_marker_mobile/data/local/local_customer_repository.dart';
import 'package:delivery_marker_mobile/data/local/local_location_repository.dart';
import 'package:delivery_marker_mobile/data/remote/remote_customer_repository.dart';
import 'package:delivery_marker_mobile/data/remote/remote_location_repository.dart';
import 'package:delivery_marker_mobile/data/repositories/repository_provider.dart';
import 'package:delivery_marker_mobile/core/utils/phone_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late AppDatabase appDb;
  late Database db;
  late LocalCustomerRepository customerRepo;
  late LocalLocationRepository locationRepo;

  setUp(() async {
    RepositoryProvider.reset();
    appDb = await AppDatabase.openInMemory(factory: databaseFactoryFfi);
    db = await appDb.database;
    customerRepo = LocalCustomerRepository(appDb: appDb);
    locationRepo = LocalLocationRepository(appDb: appDb);
  });

  tearDown(() async {
    await appDb.close();
    RepositoryProvider.reset();
  });

  group('TASK: LOCAL-FIRST-03-LOCAL-REPOSITORY-CUSTOMER-LOCATION Tests', () {
    test('1. RepositoryProvider toggle useLocalData chuyển đổi chính xác giữa Remote và Local', () {
      // Mặc định nhánh local-first: true -> Local
      expect(RepositoryProvider.useLocalData, isTrue);
      expect(RepositoryProvider.customer, isA<LocalCustomerRepository>());
      expect(RepositoryProvider.location, isA<LocalLocationRepository>());

      // Chuyển sang Remote: useLocalData = false -> Remote
      RepositoryProvider.useLocalData = false;
      expect(RepositoryProvider.useLocalData, isFalse);
      expect(RepositoryProvider.customer, isA<RemoteCustomerRepository>());
      expect(RepositoryProvider.location, isA<RemoteLocationRepository>());

      // Reset
      RepositoryProvider.reset();
      expect(RepositoryProvider.useLocalData, isTrue);
    });

    test('2. Tạo khách chỉ cần SĐT, tự đặt tên/địa chỉ mặc định, và KHÔNG tạo trùng khi SĐT đã có', () async {
      // 1. Tạo mới chỉ với SĐT chưa chuẩn hóa
      final cust1 = await customerRepo.createCustomer(
        phoneNumber: '+84 901 234 567',
      );

      expect(cust1.phoneNumber, '0901234567');
      expect(cust1.fullName, 'Khách 0901234567');
      expect(cust1.addressText, 'Chưa cập nhật địa chỉ');
      expect(cust1.areaName, 'Của tôi');
      expect(cust1.isExisting, isFalse);
      expect(cust1.hasLocation, isFalse);

      // 2. Thử tạo lại cùng số điện thoại dạng khác: (090) 123.4567
      final cust2 = await customerRepo.createCustomer(
        phoneNumber: '(090) 123.4567',
        fullName: 'Tên Không Được Ghi Đè',
      );

      expect(cust2.id, cust1.id);
      expect(cust2.phoneNumber, '0901234567');
      expect(cust2.fullName, 'Khách 0901234567'); // Giữ tên cũ
      expect(cust2.isExisting, isTrue);

      // Đảm bảo trong CSDL chỉ có 1 dòng khách hàng
      final allCusts = await db.query('customers', where: 'deleted_at IS NULL');
      expect(allCusts.length, 1);
    });

    test('3. Sửa thông tin, chặn trùng SĐT, và xóa mềm kèm quy tắc chặn xóa khách trong ca đang mở', () async {
      final custA = await customerRepo.createCustomer(
        phoneNumber: '0901111111',
        fullName: 'Khách A',
      );
      final custB = await customerRepo.createCustomer(
        phoneNumber: '0902222222',
        fullName: 'Khách B',
      );

      // 1. Cập nhật thông tin hợp lệ
      final updateRes = await customerRepo.updateCustomer(
        customerId: custA.id,
        fullName: 'Khách A Đã Đổi Tên',
        phoneNumber: '0901111111',
        addressText: '123 Phố Mới',
      );
      expect(updateRes['success'], isTrue);

      final detail = await customerRepo.getCustomerDetail(custA.id);
      expect(detail.fullName, 'Khách A Đã Đổi Tên');
      expect(detail.addressText, '123 Phố Mới');

      // 2. Thử cập nhật SĐT của A thành SĐT của B -> Báo lỗi trùng
      final dupRes = await customerRepo.updateCustomer(
        customerId: custA.id,
        fullName: 'Khách A Đổi SĐT Trùng',
        phoneNumber: '0902222222',
      );
      expect(dupRes['success'], isFalse);

      // 3. Xóa mềm khi KHÔNG có trong ca -> Thành công
      final delSuccess = await customerRepo.deleteCustomer(custB.id);
      expect(delSuccess, isTrue);
      final checkB = await db.query('customers', where: 'id = ? AND deleted_at IS NULL', whereArgs: [custB.id]);
      expect(checkB, isEmpty);

      // 4. Đưa khách A vào ca PREPARING -> Thử xóa mềm -> Ném lỗi
      final shiftId = await appDb.createShift(shiftCode: 'SHF-TEST-DEL', workDate: '2026-10-26', status: 'PREPARING');
      await appDb.addShiftDeliveryPoint(shiftId: shiftId, customerId: custA.id);

      expect(
        () async => await customerRepo.deleteCustomer(custA.id),
        throwsA(isA<Exception>()),
      );
    });

    test('4. Danh bạ: Phân trang (limit/offset), Tìm không dấu unaccent, và tính Counts', () async {
      await customerRepo.createCustomer(
        phoneNumber: '0909112233',
        fullName: 'Nguyễn Xiển',
        addressText: 'Số 120 Đường Nguyễn Xiển, Thanh Xuân',
      );
      await customerRepo.createCustomer(
        phoneNumber: '0988554433',
        fullName: 'Trần Văn Long',
        addressText: 'Đường Giải Phóng, Hai Bà Trưng',
      );
      await customerRepo.createCustomer(
        phoneNumber: '0912334455',
        fullName: 'Lê Văn Hùng',
        addressText: 'Cầu Giấy, Hà Nội',
      );

      // 1. Tìm không dấu "Nguyen Xien"
      final searchRes = await customerRepo.getCustomersResponse(query: 'Nguyen Xien');
      expect(searchRes.items.length, 1);
      expect(searchRes.items.first.fullName, 'Nguyễn Xiển');

      // 2. Tìm theo SĐT có khoảng cách "0909 112 233"
      final phoneRes = await customerRepo.getCustomersResponse(query: '0909 112 233');
      expect(phoneRes.items.length, 1);
      expect(phoneRes.items.first.fullName, 'Nguyễn Xiển');

      // 3. Phân trang
      final page1 = await customerRepo.getCustomersResponse(limit: 2, offset: 0);
      expect(page1.items.length, 2);
      expect(page1.pagination.hasMore, isTrue);
      expect(page1.counts.total, 3);
      expect(page1.counts.noLocation, 3);

      final page2 = await customerRepo.getCustomersResponse(limit: 2, offset: 2);
      expect(page2.items.length, 1);
      expect(page2.pagination.hasMore, isFalse);
    });

    test('5. locationState phản ánh đầy đủ 3 trạng thái: VERIFIED, TEMPORARY, NO_LOCATION', () async {
      // Khách 1: Có saved_locations -> VERIFIED
      final cust1 = await customerRepo.createCustomer(phoneNumber: '0901000001', fullName: 'Khách Verified');
      await locationRepo.updateCustomerLocationAndPhoto(
        customerId: cust1.id,
        latitude: 21.01,
        longitude: 105.85,
        identificationNotes: 'Nhà có cổng sắt xanh',
      );

      // Khách 2: Chưa có saved_locations, nhưng có điểm giao TEMPORARY trong ca IN_PROGRESS -> TEMPORARY
      final cust2 = await customerRepo.createCustomer(phoneNumber: '0902000002', fullName: 'Khách Temporary');
      final shiftId = await appDb.createShift(shiftCode: 'SHF-ACTIVE', workDate: '2026-10-26', status: 'IN_PROGRESS');
      final pointId = await appDb.addShiftDeliveryPoint(shiftId: shiftId, customerId: cust2.id, locationStatus: 'NO_LOCATION');
      await locationRepo.updateTemporaryLocation(
        shiftId,
        pointId,
        latitude: 21.05,
        longitude: 105.80,
        identificationNotes: 'Ghim tạm góc ngõ 50',
      );

      // Khách 3: Không có gì -> NO_LOCATION
      await customerRepo.createCustomer(phoneNumber: '0903000003', fullName: 'Khách NoLocation');

      // Truy vấn danh bạ và kiểm tra
      final response = await customerRepo.getCustomersResponse();
      expect(response.counts.total, 3);
      expect(response.counts.verified, 1);
      expect(response.counts.temporary, 1);
      expect(response.counts.noLocation, 1);

      // Lọc theo tab VERIFIED
      final verifiedTab = await customerRepo.getCustomersResponse(status: 'VERIFIED');
      expect(verifiedTab.items.length, 1);
      expect(verifiedTab.items.first.fullName, 'Khách Verified');
      expect(verifiedTab.items.first.locationState, LocationStatus.verified);

      // Lọc theo tab TEMPORARY
      final temporaryTab = await customerRepo.getCustomersResponse(status: 'TEMPORARY');
      expect(temporaryTab.items.length, 1);
      expect(temporaryTab.items.first.fullName, 'Khách Temporary');
      expect(temporaryTab.items.first.locationState, LocationStatus.temporary);

      // Lọc theo tab NO_LOCATION
      final noLocTab = await customerRepo.getCustomersResponse(status: 'NO_LOCATION');
      expect(noLocTab.items.length, 1);
      expect(noLocTab.items.first.fullName, 'Khách NoLocation');
      expect(noLocTab.items.first.locationState, LocationStatus.noLocation);
    });

    test('6. Bulk tạo hàng loạt SĐT: tách số các dạng, trùng lặp, trên 200 số, trong 1 transaction', () async {
      // 1. Kiểm tra parseAndNormalizeBulkPhones độc lập
      const rawInput = '0908 911 111\n+84 908 911 111, 0908.911.111; 0988000001; 12345; 0908-911-111';
      final parsed = parseAndNormalizeBulkPhones(rawText: rawInput);

      expect(parsed.uniquePhones.length, 2); // 0908911111 và 0988000001
      expect(parsed.uniquePhones, contains('0908911111'));
      expect(parsed.uniquePhones, contains('0988000001'));
      expect(parsed.items.any((i) => !i.isValid && i.original == '12345'), isTrue);

      // 2. Tạo trước 1 khách trong DB
      await customerRepo.createCustomer(phoneNumber: '0908911111', fullName: 'Đã Có Sẵn');

      // 3. Thực thi createBulkCustomers
      final bulkResult = await customerRepo.createBulkCustomers(rawText: rawInput);
      expect(bulkResult.createdCount, 1); // 0988000001 mới tạo
      expect(bulkResult.alreadyExistsCount, 1); // 0908911111 đã có
      expect(bulkResult.rejectedCount, 1); // 12345 sai định dạng
      expect(bulkResult.alreadyExists.first.phoneNumber, '0908911111');
      expect(bulkResult.created.first.phoneNumber, '0988000001');

      // 4. Kiểm tra danh sách vượt quá 200 số bị từ chối
      final over200List = List.generate(205, (i) => '090${i.toString().padLeft(7, '0')}');
      expect(
        () async => await customerRepo.createBulkCustomers(phones: over200List),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('7. Ghim vị trí mới gán cho SĐT bất kỳ: Tự tạo khách và vị trí trong CÙNG 1 transaction', () async {
      // Ghim vị trí cho một SĐT mới toanh '0977889900'
      final result = await locationRepo.updateCustomerLocationAndPhoto(
        customerId: '0977889900', // Truyền SĐT thay vì ID
        latitude: 10.7769,
        longitude: 106.7009,
        identificationNotes: 'Ghim trực tiếp từ tâm ngắm',
      );
      expect(result['success'], isTrue);

      // Khách hàng đã được tự động tạo và liên kết với vị trí
      final cust = await customerRepo.lookupCustomerLocationByPhone('0977889900');
      expect(cust, isNotNull);
      expect(cust!['fullName'], 'Khách 0977889900');
      expect(cust['hasLocation'], isTrue);
      expect(cust['latitude'], 10.7769);
      expect(cust['locationState'], 'VERIFIED');

      // Thử ghim vị trí với tọa độ không hợp lệ (latitude = 999.0) -> Transaction rollback
      expect(
        () async => await locationRepo.updateCustomerLocationAndPhoto(
          customerId: '0933445566',
          latitude: 999.0, // Sai tọa độ
          longitude: 106.70,
          identificationNotes: 'Tọa độ sai',
        ),
        throwsA(isA<ArgumentError>()),
      );

      // Đảm bảo không bị lưu khách mồ côi '0933445566'
      final orphan = await customerRepo.lookupCustomerLocationByPhone('0933445566');
      expect(orphan, isNull);
    });

    test('8. Xóa vị trí: Giữ lịch sử, chuyển điểm VERIFIED trong ca về NO_LOCATION, điểm TEMPORARY giữ nguyên', () async {
      final cust = await customerRepo.createCustomer(phoneNumber: '0901239999');
      final custId = cust.id;

      // Lưu vị trí VERIFIED
      await locationRepo.updateCustomerLocationAndPhoto(
        customerId: custId,
        latitude: 16.05,
        longitude: 108.20,
        identificationNotes: 'Nhà có giàn hoa giấy',
      );

      // Cập nhật đổi tọa độ để trigger sinh lịch sử
      await locationRepo.updateCustomerLocationAndPhoto(
        customerId: custId,
        latitude: 16.08,
        longitude: 108.22,
        identificationNotes: 'Cổng mới màu vàng',
      );

      // Tạo ca 1 có điểm VERIFIED của khách
      final shift1 = await appDb.createShift(shiftCode: 'SHF-VER', workDate: '2026-10-26', status: 'IN_PROGRESS');
      final pt1 = await appDb.addShiftDeliveryPoint(shiftId: shift1, customerId: custId, locationStatus: 'VERIFIED', latitude: 16.08, longitude: 108.22);

      // Tạo ca 2 có điểm TEMPORARY riêng của khách
      final shift2 = await appDb.createShift(shiftCode: 'SHF-TMP', workDate: '2026-10-26', status: 'PREPARING');
      final pt2 = await appDb.addShiftDeliveryPoint(shiftId: shift2, customerId: custId, locationStatus: 'TEMPORARY', latitude: 16.10, longitude: 108.25);

      // XÓA VỊ TRÍ
      await locationRepo.deleteCustomerLocation(custId);

      // 1. saved_locations đã bị xóa
      final loc = await appDb.getSavedLocationByCustomerId(custId);
      expect(loc, isNull);

      // 2. location_history VẪN CÒN, saved_location_id = NULL
      final history = await locationRepo.getLocationHistory(custId);
      expect(history.length, 1);
      expect(history.first['saved_location_id'], isNull);

      // 3. Điểm giao ca 1 từ VERIFIED chuyển về NO_LOCATION
      final pt1Check = await db.query('shift_delivery_points', where: 'id = ?', whereArgs: [pt1]);
      expect(pt1Check.first['location_status'], 'NO_LOCATION');
      expect(pt1Check.first['latitude'], isNull);

      // 4. Điểm giao ca 2 TEMPORARY giữ nguyên tọa độ ghim tạm
      final pt2Check = await db.query('shift_delivery_points', where: 'id = ?', whereArgs: [pt2]);
      expect(pt2Check.first['location_status'], 'TEMPORARY');
      expect(pt2Check.first['latitude'], 16.10);
    });

    test('9. Quy tắc LOCATION-RULES-012: Xác nhận vị trí qua Danh bạ tự đồng bộ điểm trong ca', () async {
      final cust = await customerRepo.createCustomer(phoneNumber: '0988112233');

      // Thêm khách vào ca với NO_LOCATION
      final shiftId = await appDb.createShift(shiftCode: 'SHF-012', workDate: '2026-10-26', status: 'IN_PROGRESS');
      final pointId = await appDb.addShiftDeliveryPoint(shiftId: shiftId, customerId: cust.id, locationStatus: 'NO_LOCATION');

      // Xác nhận vị trí qua updateCustomerLocationAndPhoto
      final res = await locationRepo.updateCustomerLocationAndPhoto(
        customerId: cust.id,
        latitude: 10.8433,
        longitude: 106.8199,
        identificationNotes: 'Nhà 2 tầng cổng trắng',
      );

      expect(res['success'], isTrue);
      expect(res['updatedShiftPointsCount'], 1);

      // Kiểm tra điểm giao trong ca đã tự động cập nhật sang VERIFIED kèm tọa độ mới
      final pointCheck = await db.query('shift_delivery_points', where: 'id = ?', whereArgs: [pointId]);
      expect(pointCheck.first['location_status'], 'VERIFIED');
      expect((pointCheck.first['latitude'] as num).toDouble(), closeTo(10.8433, 0.0001));
    });

    test('10. Dữ liệu bản đồ chính & Lọc theo Bounding Box (bbox)', () async {
      // 1. Tạo 2 vị trí: Hà Nội (lat ~21.0, lng ~105.8) và Sài Gòn (lat ~10.7, lng ~106.7)
      final custHn = await customerRepo.createCustomer(phoneNumber: '0901000001', fullName: 'Khách Hà Nội');
      await locationRepo.updateCustomerLocationAndPhoto(customerId: custHn.id, latitude: 21.0285, longitude: 105.8542, identificationNotes: 'Hà Nội');

      final custSg = await customerRepo.createCustomer(phoneNumber: '0902000002', fullName: 'Khách Sài Gòn');
      await locationRepo.updateCustomerLocationAndPhoto(customerId: custSg.id, latitude: 10.7769, longitude: 106.7009, identificationNotes: 'Sài Gòn');

      // getMySavedLocations trả về cả 2
      final allLocations = await locationRepo.getMySavedLocations();
      expect(allLocations.length, 2);
      expect(allLocations.every((l) => l.areaName == 'Của tôi'), isTrue);

      // getSavedLocationsInBounds cho khung nhìn Hà Nội (minLat 20.0, maxLat 22.0, minLng 105.0, maxLng 106.0)
      final hnLocations = await locationRepo.getSavedLocationsInBounds(
        minLat: 20.0,
        maxLat: 22.0,
        minLng: 105.0,
        maxLng: 106.0,
      );
      expect(hnLocations.length, 1);
      expect(hnLocations.first.customerName, 'Khách Hà Nội');
    });

    test('11. Kiểm tra tính tương thích dữ liệu Model với UI', () async {
      final cust = await customerRepo.createCustomer(
        phoneNumber: '+84908333166',
        fullName: 'Nguyễn Văn Test',
      );
      await locationRepo.saveCustomerLocation(SavedLocationModel(
        customerId: cust.id,
        latitude: 21.0,
        longitude: 105.8,
        gpsAccuracy: 3.0,
        identificationNotes: 'Nhà có cổng vòm',
      ));

      final detail = await customerRepo.getCustomerDetail(cust.id);
      // Kiểm tra các getter của CustomerDirectoryModel
      expect(detail.formattedPhoneNumber, '0908 333 166');
      expect(detail.hasValidCoordinates, isTrue);
      expect(detail.latLng, isNotNull);
      expect(detail.hasLocation, isTrue);

      final masterList = await locationRepo.getMySavedLocations();
      final master = masterList.first;
      expect(master.hasValidCoordinates, isTrue);
      expect(master.hasPhoto, isFalse);
    });
  });
}
