import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:delivery_marker_mobile/data/local/app_database.dart';
import 'package:delivery_marker_mobile/models/location_model.dart';
import 'package:delivery_marker_mobile/models/shift_model.dart';
import 'package:delivery_marker_mobile/data/local/local_customer_repository.dart';
import 'package:delivery_marker_mobile/data/local/local_location_repository.dart';
import 'package:delivery_marker_mobile/data/local/local_shift_repository.dart';
import 'package:delivery_marker_mobile/data/remote/remote_shift_repository.dart';
import 'package:delivery_marker_mobile/data/repositories/repository_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late AppDatabase appDb;
  late Database db;
  late LocalShiftRepository shiftRepo;
  late LocalCustomerRepository customerRepo;
  late LocalLocationRepository locationRepo;

  setUp(() async {
    RepositoryProvider.reset();
    appDb = await AppDatabase.openInMemory(factory: databaseFactoryFfi);
    db = await appDb.database;
    shiftRepo = LocalShiftRepository(appDb: appDb);
    customerRepo = LocalCustomerRepository(appDb: appDb);
    locationRepo = LocalLocationRepository(appDb: appDb);
  });

  tearDown(() async {
    await appDb.close();
    RepositoryProvider.reset();
  });

  group('TASK: LOCAL-FIRST-04-LOCAL-SHIFTS-AND-BULK Tests', () {
    test('1. RepositoryProvider toggle useLocalData chuyển đổi chính xác ShiftRepository sang LocalShiftRepository', () {
      expect(RepositoryProvider.useLocalData, isTrue);
      expect(RepositoryProvider.shift, isA<LocalShiftRepository>());

      RepositoryProvider.useLocalData = false;
      expect(RepositoryProvider.useLocalData, isFalse);
      expect(RepositoryProvider.shift, isA<RemoteShiftRepository>());

      RepositoryProvider.reset();
      expect(RepositoryProvider.useLocalData, isTrue);
      expect(RepositoryProvider.shift, isA<LocalShiftRepository>());
    });

    test('2. Tạo ca có tên (trim, max 100 ký tự) và tạo ca không tên tự gợi ý "Ca sáng/chiều/tối dd/MM"', () async {
      final longName = '   ${'A' * 120}   ';
      final shift1 = await shiftRepo.createShift(
        shiftDate: '2026-10-27',
        shiftName: longName,
      );

      expect(shift1.shiftName, equals('A' * 100));
      expect(shift1.shiftName!.length, equals(100));
      expect(shift1.status, equals(ShiftStatus.preparing));

      // Tạo ca không truyền tên -> tự động sinh theo mẫu
      final shift2 = await shiftRepo.createShift(
        shiftDate: '2026-10-27',
        shiftName: null,
      );
      expect(shift2.shiftName, isNotNull);
      expect(shift2.shiftName, contains('27/10'));
    });

    test('3. Mã ca tăng đúng (SHF-YYYYMMDD-001, 002), reset khi sang ngày khác; trùng tên trong ngày thêm (2), (3)', () async {
      // Ngày 2026-10-27
      final s1 = await shiftRepo.createShift(shiftDate: '2026-10-27');
      expect(s1.shiftCode, equals('SHF-20261027-001'));

      final s2 = await shiftRepo.createShift(shiftDate: '2026-10-27');
      expect(s2.shiftCode, equals('SHF-20261027-002'));
      // Trùng tên trong cùng ngày tự động thêm (2)
      expect(s2.shiftName, contains('(2)'));

      final s3 = await shiftRepo.createShift(shiftDate: '2026-10-27');
      expect(s3.shiftCode, equals('SHF-20261027-003'));
      expect(s3.shiftName, contains('(3)'));

      // Chuyển sang ngày hôm sau 2026-10-28 -> Mã ca phải reset về 001
      final sNextDay = await shiftRepo.createShift(shiftDate: '2026-10-28');
      expect(sNextDay.shiftCode, equals('SHF-20261028-001'));
      expect(sNextDay.shiftDate, equals('2026-10-28'));
      expect(sNextDay.shiftName, contains('28/10'));
      expect(sNextDay.shiftName, isNot(contains('(2)')));
    });

    test('4. getShifts & getShiftDetail: danh sách ca kèm summary, mới nhất trước; chi tiết ca đầy đủ điểm giao', () async {
      await shiftRepo.createShift(shiftDate: '2026-10-26', shiftName: 'Ca hôm qua');
      final s2 = await shiftRepo.createShift(shiftDate: '2026-10-27', shiftName: 'Ca hôm nay');

      // Thêm 1 điểm vào s2
      await shiftRepo.addPointToShift(
        s2.id,
        phoneNumber: '0901234567',
        fullName: 'Nguyễn Văn A',
      );

      final list = await shiftRepo.getShifts();
      expect(list.length, equals(2));
      // Sắp xếp mới nhất trước (s2 đứng đầu)
      expect(list.first.id, equals(s2.id));
      expect(list.first.summary.totalPoints, equals(1));
      expect(list.first.summary.noLocationCount, equals(1));

      // Chi tiết ca
      final detail = await shiftRepo.getShiftDetail(s2.id);
      expect(detail.id, equals(s2.id));
      expect(detail.deliveryPoints.length, equals(1));
      expect(detail.deliveryPoints.first.customerPhone, equals('0901234567'));
      expect(detail.summary.totalPoints, equals(1));
    });

    test('5. updateShiftName: Đổi tên ca thành công, từ chối tên rỗng, cập nhật CSDL và ghi activity_log', () async {
      final s = await shiftRepo.createShift(shiftDate: '2026-10-27', shiftName: 'Tên ban đầu');

      expect(() async => await shiftRepo.updateShiftName(s.id, '   '), throwsA(isA<ArgumentError>()));

      final updated = await shiftRepo.updateShiftName(s.id, 'Ca chiều quận 1');
      expect(updated.shiftName, equals('Ca chiều quận 1'));

      final logs = await db.query('activity_log', where: "action = 'UPDATE_SHIFT_NAME'");
      expect(logs.length, equals(1));
      expect(logs.first['entity_id'], equals(s.id));
    });

    test('6. updateShiftStatus: chuyển trạng thái đúng thứ tự PREPARING -> IN_PROGRESS -> COMPLETED, chặn sai thứ tự', () async {
      final s = await shiftRepo.createShift(shiftDate: '2026-10-27');
      expect(s.status, equals(ShiftStatus.preparing));
      expect(s.startedAt, isNull);
      expect(s.completedAt, isNull);

      // Chặn chuyển thẳng từ PREPARING sang COMPLETED
      expect(
        () async => await shiftRepo.updateShiftStatus(s.id, ShiftStatus.completed),
        throwsA(isA<Exception>()),
      );

      // Chuyển sang IN_PROGRESS thành công -> started_at được ghi nhận
      final inProgress = await shiftRepo.updateShiftStatus(s.id, ShiftStatus.inProgress);
      expect(inProgress.status, equals(ShiftStatus.inProgress));
      expect(inProgress.startedAt, isNotNull);
      expect(inProgress.completedAt, isNull);

      // Chặn chuyển ngược từ IN_PROGRESS về PREPARING
      expect(
        () async => await shiftRepo.updateShiftStatus(s.id, ShiftStatus.preparing),
        throwsA(isA<Exception>()),
      );

      // Chuyển sang COMPLETED thành công -> completed_at được ghi nhận
      final completed = await shiftRepo.updateShiftStatus(s.id, ShiftStatus.completed);
      expect(completed.status, equals(ShiftStatus.completed));
      expect(completed.completedAt, isNotNull);

      // Chặn đổi trạng thái khi đã COMPLETED
      expect(
        () async => await shiftRepo.updateShiftStatus(s.id, ShiftStatus.inProgress),
        throwsA(isA<Exception>()),
      );
    });

    test('7. deleteShift: xóa ca cascade xóa điểm giao; TUYỆT ĐỐI KHÔNG xóa khách hay vị trí; ca IN_PROGRESS vẫn xóa được', () async {
      final s = await shiftRepo.createShift(shiftDate: '2026-10-27');
      await shiftRepo.updateShiftStatus(s.id, ShiftStatus.inProgress);

      // Tạo khách có vị trí đã xác nhận
      final cust = await customerRepo.createCustomer(
        phoneNumber: '0988000111',
        fullName: 'Chị Lan',
      );
      await locationRepo.saveCustomerLocation(
        SavedLocationModel(
          customerId: cust.id,
          latitude: 10.7765,
          longitude: 106.7009,
          gpsAccuracy: 4.5,
          identificationNotes: 'Cổng vàng',
        ),
      );

      // Thêm vào ca đang IN_PROGRESS
      await shiftRepo.addPointToShift(s.id, customerId: cust.id);

      // Kiểm tra điểm giao đã có trong CSDL
      final pointsBefore = await db.query('shift_delivery_points', where: 'shift_id = ?', whereArgs: [s.id]);
      expect(pointsBefore.length, equals(1));

      // Xóa ca đang IN_PROGRESS
      final deleteSuccess = await shiftRepo.deleteShift(s.id);
      expect(deleteSuccess, isTrue);

      // Ca và điểm giao của ca đã bị xóa
      final shiftsAfter = await db.query('shifts', where: 'id = ?', whereArgs: [s.id]);
      expect(shiftsAfter, isEmpty);
      final pointsAfter = await db.query('shift_delivery_points', where: 'shift_id = ?', whereArgs: [s.id]);
      expect(pointsAfter, isEmpty);

      // Khách hàng và vị trí đã lưu vẫn còn NGUYÊN VẸN 100%
      final custAfter = await db.query('customers', where: 'id = ?', whereArgs: [cust.id]);
      expect(custAfter.length, equals(1));
      final locAfter = await db.query('saved_locations', where: 'customer_id = ?', whereArgs: [cust.id]);
      expect(locAfter.length, equals(1));

      // Kiểm tra activity_log có ghi nhận DELETE_SHIFT
      final logs = await db.query('activity_log', where: "action = 'DELETE_SHIFT'");
      expect(logs.length, equals(1));
    });

    test('8. addPointToShift: 3 trường hợp (khách có vị trí -> VERIFIED, chưa có vị trí -> NO_LOCATION, SĐT mới -> tự tạo khách)', () async {
      final s = await shiftRepo.createShift(shiftDate: '2026-10-27');

      // Khách 1: đã có vị trí đã lưu
      final c1 = await customerRepo.createCustomer(phoneNumber: '0911000111', fullName: 'Khách 1');
      await locationRepo.saveCustomerLocation(
        SavedLocationModel(customerId: c1.id, latitude: 10.80, longitude: 106.70, gpsAccuracy: 5.0, identificationNotes: 'Gần chợ'),
      );
      final res1 = await shiftRepo.addPointToShift(s.id, customerId: c1.id);
      final p1 = res1['point'] as ShiftDeliveryPointModel;
      expect(p1.locationStatus, equals(LocationStatus.verified));
      expect(p1.latitude, equals(10.80));

      // Khách 2: chưa có vị trí đã lưu
      final c2 = await customerRepo.createCustomer(phoneNumber: '0911000222', fullName: 'Khách 2');
      final res2 = await shiftRepo.addPointToShift(s.id, customerId: c2.id);
      final p2 = res2['point'] as ShiftDeliveryPointModel;
      expect(p2.locationStatus, equals(LocationStatus.noLocation));
      expect(p2.latitude, isNull);

      // Khách 3: SĐT mới toanh chưa có trong danh bạ
      final res3 = await shiftRepo.addPointToShift(s.id, phoneNumber: '0988 999 888');
      final p3 = res3['point'] as ShiftDeliveryPointModel;
      expect(p3.customerPhone, equals('0988999888'));
      expect(p3.customerName, equals('Khách 0988999888'));
      expect(p3.locationStatus, equals(LocationStatus.noLocation));

      // Kiểm tra delivery_order_index tăng dần 1, 2, 3
      expect(p1.sequenceNumber, equals(1));
      expect(p2.sequenceNumber, equals(2));
      expect(p3.sequenceNumber, equals(3));
    });

    test('9. addPointToShift: chống trùng lặp trả isExisting=true và không tạo dòng mới', () async {
      final s = await shiftRepo.createShift(shiftDate: '2026-10-27');
      final c = await customerRepo.createCustomer(phoneNumber: '0933111222');

      final firstAdd = await shiftRepo.addPointToShift(s.id, customerId: c.id);
      expect(firstAdd['isExisting'], isFalse);

      final secondAdd = await shiftRepo.addPointToShift(s.id, customerId: c.id);
      expect(secondAdd['isExisting'], isTrue);

      final points = await db.query('shift_delivery_points', where: 'shift_id = ?', whereArgs: [s.id]);
      expect(points.length, equals(1));
    });

    test('10. updateTemporaryLocation: ghim tạm chỉ ghi vào shift_delivery_points, KHÔNG ghi saved_locations', () async {
      final s = await shiftRepo.createShift(shiftDate: '2026-10-27');
      final c = await customerRepo.createCustomer(phoneNumber: '0944111222');

      // Ban đầu khách có vị trí VERIFIED tại (10.1, 106.1)
      await locationRepo.saveCustomerLocation(
        SavedLocationModel(customerId: c.id, latitude: 10.1, longitude: 106.1, gpsAccuracy: 3.0, identificationNotes: 'Gốc'),
      );

      final addRes = await shiftRepo.addPointToShift(s.id, customerId: c.id);
      final point = addRes['point'] as ShiftDeliveryPointModel;
      expect(point.locationStatus, equals(LocationStatus.verified));

      // Shipper ghim tạm tọa độ mới trong ca này tại (10.99, 106.99)
      final tempPoint = await locationRepo.updateTemporaryLocation(
        s.id,
        point.id,
        latitude: 10.99,
        longitude: 106.99,
        identificationNotes: 'Ghim tạm cổng phụ',
      );
      expect(tempPoint.locationStatus, equals(LocationStatus.temporary));
      expect(tempPoint.latitude, equals(10.99));

      // Điểm giao trong ca chuyển thành TEMPORARY
      final pointInDb = await db.query('shift_delivery_points', where: 'id = ?', whereArgs: [point.id]);
      expect(pointInDb.first['location_status'], equals('TEMPORARY'));
      expect(pointInDb.first['latitude'], equals(10.99));

      // Bảng saved_locations giữ NGUYÊN VẸN tọa độ gốc và ghi chú gốc!
      final savedLocInDb = await db.query('saved_locations', where: 'customer_id = ?', whereArgs: [c.id]);
      expect(savedLocInDb.first['latitude'], equals(10.1));
      expect(savedLocInDb.first['identification_notes'], equals('Gốc'));
    });

    test('11. addBulkPointsToShift: tách số đa định dạng, lọc trùng, chặn > 200 số, trả đủ 4 nhóm, ghi 1 activity_log', () async {
      final s = await shiftRepo.createShift(shiftDate: '2026-10-27');

      // Chuẩn bị 1 khách đã có vị trí
      final cVerified = await customerRepo.createCustomer(phoneNumber: '0908111222', fullName: 'Anh Ba');
      await locationRepo.saveCustomerLocation(
        SavedLocationModel(customerId: cVerified.id, latitude: 10.77, longitude: 106.69, gpsAccuracy: 4.0, identificationNotes: 'Hẻm 12'),
      );

      // Chuẩn bị 1 khách đã có trong ca
      await shiftRepo.addPointToShift(s.id, phoneNumber: '0908333444');

      const rawInput = '''
        0908 111 222
        +84 908.333.444, 0908555666; 0908-111-222
        091234 (so ngan sai)
      ''';

      final bulkResult = await shiftRepo.addBulkPointsToShift(
        shiftId: s.id,
        rawText: rawInput,
      );

      // 1. Số 0908111222: thêm mới, có vị trí -> VERIFIED
      // 2. Số 0908555666: số mới toanh -> tạo khách nhanh, chưa có vị trí -> NO_LOCATION
      expect(bulkResult.added.length, equals(2));
      final pVerified = bulkResult.added.firstWhere((p) => p.customerPhone == '0908111222');
      expect(pVerified.locationStatus, equals(LocationStatus.verified));
      final pNoLoc = bulkResult.added.firstWhere((p) => p.customerPhone == '0908555666');
      expect(pNoLoc.locationStatus, equals(LocationStatus.noLocation));

      // 3. Số 0908333444: đã có trong ca
      expect(bulkResult.alreadyInShift.length, equals(1));
      expect(bulkResult.alreadyInShift.first.phone, equals('0908333444'));

      // 4. Số sai định dạng (091234)
      expect(bulkResult.rejected.length, equals(1));
      expect(bulkResult.rejected.first.reason, equals('INVALID_FORMAT'));

      // Thống kê summary
      expect(bulkResult.summary.addedCount, equals(2));
      expect(bulkResult.summary.alreadyInShiftCount, equals(1));
      expect(bulkResult.summary.rejectedCount, equals(1));

      // Ghi ĐÚNG 1 dòng activity_log cho cả lô
      final logs = await db.query('activity_log', where: "action = 'BULK_ADD_POINTS'");
      expect(logs.length, equals(1));

      // Chặn danh sách > 200 số
      final hugeList = List.generate(205, (i) => '0901${i.toString().padLeft(6, '0')}').join('\n');
      expect(
        () async => await shiftRepo.addBulkPointsToShift(shiftId: s.id, rawText: hugeList),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('12. addBulkPointsToShift: tính toàn vẹn transaction (lỗi giữa lô rollback 100%, không để lại dữ liệu nửa vời)', () async {
      // Gọi với shiftId không tồn tại -> phải lỗi và không tạo khách hàng nào
      const rawInput = '0987111222, 0987333444';
      expect(
        () async => await shiftRepo.addBulkPointsToShift(
          shiftId: 'non-existing-shift-id',
          rawText: rawInput,
        ),
        throwsA(isA<Exception>()),
      );

      final custs = await db.query('customers', where: "phone_number LIKE '0987%'");
      expect(custs, isEmpty);
    });

    test('13. removePointFromShift (Hoàn tác): xóa đúng điểm vừa thêm và cập nhật summary chính xác', () async {
      final s = await shiftRepo.createShift(shiftDate: '2026-10-27');
      final addRes = await shiftRepo.addPointToShift(s.id, phoneNumber: '0977111222');
      final point = addRes['point'] as ShiftDeliveryPointModel;

      var detail = await shiftRepo.getShiftDetail(s.id);
      expect(detail.deliveryPoints.length, equals(1));
      expect(detail.summary.totalPoints, equals(1));

      // Hoàn tác
      await shiftRepo.removePointFromShift(s.id, point.id);

      detail = await shiftRepo.getShiftDetail(s.id);
      expect(detail.deliveryPoints, isEmpty);
      expect(detail.summary.totalPoints, equals(0));

      final logs = await db.query('activity_log', where: "action = 'REMOVE_POINT_FROM_SHIFT'");
      expect(logs.length, equals(1));
    });

    test('14. verifyPointLocation: ném UnsupportedError thông báo chuyển hướng sang Danh bạ', () async {
      expect(
        () async => await shiftRepo.verifyPointLocation('shift-1', 'point-1'),
        throwsA(isA<UnsupportedError>()),
      );
    });

    test('15. Compatibility: getMyShiftOrders và addOrderToShift ánh xạ mượt mà từ SQLite sang OrderModel', () async {
      final s = await shiftRepo.createShift(shiftDate: '2026-10-27');
      await shiftRepo.updateShiftStatus(s.id, ShiftStatus.inProgress);

      final c = await customerRepo.createCustomer(phoneNumber: '0912999888', fullName: 'Chú Bảy');
      await locationRepo.saveCustomerLocation(
        SavedLocationModel(customerId: c.id, latitude: 10.82, longitude: 106.68, gpsAccuracy: 3.5, identificationNotes: 'Cổng gỗ'),
      );

      // Gọi addOrderToShift
      final orderRes = await shiftRepo.addOrderToShift(customerId: c.id);
      expect(orderRes['isExisting'], isFalse);
      final order = orderRes['order'];
      expect(order.customerPhone, equals('0912999888'));
      expect(order.hasSavedLocation, isTrue);

      // Gọi getMyShiftOrders
      final orders = await shiftRepo.getMyShiftOrders();
      expect(orders.length, equals(1));
      expect(orders.first.customerId, equals(c.id));
      expect(orders.first.customerName, equals('Chú Bảy'));
    });
  });
}
