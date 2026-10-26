import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:delivery_marker_mobile/local/app_database.dart';
import 'package:delivery_marker_mobile/utils/phone_utils.dart';
import 'package:delivery_marker_mobile/utils/vietnamese_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late AppDatabase appDb;
  late Database db;

  setUp(() async {
    appDb = await AppDatabase.openInMemory(factory: databaseFactoryFfi);
    db = await appDb.database;
  });

  tearDown(() async {
    await appDb.close();
  });

  group('TASK: LOCAL-FIRST-02-SQLITE-SCHEMA Tests', () {
    test('1. Tạo DB sạch đủ tất cả các bảng và trigger', () async {
      final tablesResult = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name;",
      );
      final tableNames = tablesResult.map((r) => r['name'] as String).toList();

      expect(tableNames, contains('customers'));
      expect(tableNames, contains('saved_locations'));
      expect(tableNames, contains('location_history'));
      expect(tableNames, contains('customer_photos'));
      expect(tableNames, contains('shifts'));
      expect(tableNames, contains('shift_delivery_points'));
      expect(tableNames, contains('app_profile'));
      expect(tableNames, contains('app_meta'));
      expect(tableNames, contains('activity_log'));

      // Kiểm tra trigger lịch sử
      final triggersResult = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='trigger' AND name='trg_saved_locations_history';",
      );
      expect(triggersResult, isNotEmpty);
      expect(triggersResult.first['name'], 'trg_saved_locations_history');
    });

    test('2. Migration chạy lại (re-run) không bị lỗi', () async {
      // Chạy lại trực tiếp hàm migrationV1 trên DB đã có schema
      await AppDatabase.migrationV1(db);
      final tables = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table';");
      expect(tables, isNotEmpty);
    });

    test('3. Trigger lịch sử sinh dòng khi đổi tọa độ hoặc ghi chú (UPDATE)', () async {
      // Tạo khách hàng
      final custId = await appDb.insertCustomer(
        fullName: 'Nguyễn Văn A',
        phoneNumber: '0901234567',
        addressText: '123 Phố Huế, Hà Nội',
      );

      // Lưu vị trí ban đầu
      final locId = await appDb.setSavedLocation(
        customerId: custId,
        latitude: 21.0123,
        longitude: 105.8501,
        gpsAccuracy: 5.0,
        identificationNotes: 'Cổng màu xanh ngọc',
      );

      // Lịch sử ban đầu chưa có dòng cập nhật nào
      var history = await appDb.getLocationHistory(custId);
      expect(history.length, 0);

      // Cập nhật tọa độ và ghi chú mới
      await db.update(
        'saved_locations',
        {
          'latitude': 21.0150,
          'longitude': 105.8550,
          'identification_notes': 'Đã đổi thành cổng màu trắng',
          'updated_at': AppDatabase.currentIsoUtc(),
        },
        where: 'id = ?',
        whereArgs: [locId],
      );

      // Kiểm tra trigger đã tự động ghi lại tọa độ CŨ vào location_history
      history = await appDb.getLocationHistory(custId);
      expect(history.length, 1);
      final entry = history.first;
      expect(entry['saved_location_id'], locId);
      expect(entry['customer_id'], custId);
      expect(entry['latitude'], 21.0123);
      expect(entry['longitude'], 105.8501);
      expect(entry['identification_notes'], 'Cổng màu xanh ngọc');
      expect(entry['change_reason'], contains('Cập nhật'));
    });

    test('4. Xóa vị trí giữ lịch sử (saved_location_id đặt NULL, không xóa dòng lịch sử)', () async {
      final custId = await appDb.insertCustomer(
        fullName: 'Trần Thị B',
        phoneNumber: '0912345678',
      );

      final locId = await appDb.setSavedLocation(
        customerId: custId,
        latitude: 10.7769,
        longitude: 106.7009,
        identificationNotes: 'Nhà có cửa cuốn',
      );

      // Tạo một cập nhật để trigger ghi vào lịch sử
      await db.update(
        'saved_locations',
        {
          'latitude': 10.7780,
          'identification_notes': 'Cửa kính cường lực',
          'updated_at': AppDatabase.currentIsoUtc(),
        },
        where: 'id = ?',
        whereArgs: [locId],
      );

      expect((await appDb.getLocationHistory(custId)).length, 1);

      // Xóa vị trí đã lưu
      await appDb.deleteSavedLocation(locId);

      // Vị trí chính đã bị xóa
      final loc = await appDb.getSavedLocationByCustomerId(custId);
      expect(loc, isNull);

      // Lịch sử VẪN CÒN, saved_location_id được đặt thành NULL bởi ON DELETE SET NULL
      final historyAfterDelete = await appDb.getLocationHistory(custId);
      expect(historyAfterDelete.length, 1);
      expect(historyAfterDelete.first['saved_location_id'], isNull);
      expect(historyAfterDelete.first['customer_id'], custId);
      expect(historyAfterDelete.first['latitude'], 10.7769);

      // Khách hàng vẫn hoàn toàn nguyên vẹn
      final cust = await appDb.getCustomerById(custId);
      expect(cust, isNotNull);
    });

    test('5. Xóa ca KHÔNG xóa khách hàng hay vị trí', () async {
      final custId = await appDb.insertCustomer(
        fullName: 'Lê Hoàng C',
        phoneNumber: '0988776655',
      );
      final locId = await appDb.setSavedLocation(
        customerId: custId,
        latitude: 16.0544,
        longitude: 108.2022,
      );

      final shiftId = await appDb.createShift(
        shiftCode: 'SHF-20261026-001',
        shiftName: 'Ca giao chiều',
        workDate: '2026-10-26',
      );

      // Thêm điểm giao vào ca
      final pointId = await appDb.addShiftDeliveryPoint(
        shiftId: shiftId,
        customerId: custId,
        deliveryOrderIndex: 1,
        locationStatus: 'VERIFIED',
      );

      // Kiểm tra điểm giao đã có trong ca
      var points = await appDb.getShiftDeliveryPoints(shiftId);
      expect(points.length, 1);
      expect(points.first['id'], pointId);

      // Xóa ca
      await appDb.deleteShift(shiftId);

      // Điểm giao trong ca bị xóa theo (CASCADE)
      final rawPoints = await db.query(
        'shift_delivery_points',
        where: 'shift_id = ?',
        whereArgs: [shiftId],
      );
      expect(rawPoints, isEmpty);

      // Khách hàng và vị trí đã lưu của khách hàng KHÔNG bị xóa
      final cust = await appDb.getCustomerById(custId);
      expect(cust, isNotNull);
      expect(cust!['id'], custId);

      final savedLoc = await appDb.getSavedLocationByCustomerId(custId);
      expect(savedLoc, isNotNull);
      expect(savedLoc!['id'], locId);
    });

    test('6. UNIQUE(shift_id, customer_id) chặn thêm khách trùng vào một ca', () async {
      final custId = await appDb.insertCustomer(
        fullName: 'Phạm Văn D',
        phoneNumber: '0933221100',
      );

      final shiftId = await appDb.createShift(
        shiftCode: 'SHF-20261026-002',
        workDate: '2026-10-26',
      );

      // Lần 1 thêm thành công
      await appDb.addShiftDeliveryPoint(
        shiftId: shiftId,
        customerId: custId,
        deliveryOrderIndex: 1,
      );

      // Lần 2 thêm trùng cùng (shift_id, customer_id) -> ném lỗi UNIQUE constraint
      expect(
        () async => await appDb.addShiftDeliveryPoint(
          shiftId: shiftId,
          customerId: custId,
          deliveryOrderIndex: 2,
        ),
        throwsA(isA<DatabaseException>()),
      );
    });

    test('7. CHECK ràng buộc trạng thái chặn giá trị sai', () async {
      // shifts.status chỉ nhận 'PREPARING', 'IN_PROGRESS', 'COMPLETED'
      expect(
        () async => await db.insert('shifts', {
          'id': AppDatabase.generateId(),
          'shift_code': 'SHF-FAIL-01',
          'work_date': '2026-10-26',
          'status': 'INVALID_STATUS',
          'created_at': AppDatabase.currentIsoUtc(),
          'updated_at': AppDatabase.currentIsoUtc(),
        }),
        throwsA(isA<DatabaseException>()),
      );

      final custId = await appDb.insertCustomer(
        fullName: 'Khách Check',
        phoneNumber: '0977112233',
      );
      final shiftId = await appDb.createShift(
        shiftCode: 'SHF-CHECK-01',
        workDate: '2026-10-26',
      );

      // shift_delivery_points.location_status chỉ nhận 'NO_LOCATION', 'TEMPORARY', 'VERIFIED'
      expect(
        () async => await db.insert('shift_delivery_points', {
          'id': AppDatabase.generateId(),
          'shift_id': shiftId,
          'customer_id': custId,
          'delivery_order_index': 1,
          'location_status': 'PENDING', // Sai giá trị
          'created_at': AppDatabase.currentIsoUtc(),
          'updated_at': AppDatabase.currentIsoUtc(),
        }),
        throwsA(isA<DatabaseException>()),
      );

      // app_profile.id chỉ nhận duy nhất id = 1
      expect(
        () async => await db.insert('app_profile', {
          'id': 2, // Sai id
          'display_name': 'Profile 2',
          'created_at': AppDatabase.currentIsoUtc(),
          'updated_at': AppDatabase.currentIsoUtc(),
        }),
        throwsA(isA<DatabaseException>()),
      );
    });

    test('8. Tìm kiếm không dấu: "Nguyen Xien" khớp "Nguyễn Xiển"', () async {
      expect(removeVietnameseDiacritics('Nguyễn Xiển'), 'Nguyen Xien');
      expect(normalizeSearchQuery('  NGUYỄN  XIỂN  '), 'nguyen  xien');

      await appDb.insertCustomer(
        fullName: 'Nguyễn Xiển',
        phoneNumber: '0909112233',
        addressText: 'Số 120 Đường Nguyễn Xiển, Thanh Xuân, Hà Nội',
        notes: 'Giao giờ hành chính',
      );

      await appDb.insertCustomer(
        fullName: 'Trần Văn Long',
        phoneNumber: '0988554433',
        addressText: 'Đường Giải Phóng, Hai Bà Trưng',
      );

      // 1. Tìm không dấu "Nguyen Xien" khớp với "Nguyễn Xiển"
      var results = await appDb.searchCustomers('Nguyen Xien');
      expect(results.length, 1);
      expect(results.first['full_name'], 'Nguyễn Xiển');

      // 2. Tìm chữ thường không dấu "nguyen xien"
      results = await appDb.searchCustomers('nguyen xien');
      expect(results.length, 1);
      expect(results.first['full_name'], 'Nguyễn Xiển');

      // 3. Tìm có dấu chính xác "Nguyễn Xiển"
      results = await appDb.searchCustomers('Nguyễn Xiển');
      expect(results.length, 1);
      expect(results.first['full_name'], 'Nguyễn Xiển');

      // 4. Tìm địa chỉ không dấu "Thanh Xuan"
      results = await appDb.searchCustomers('Thanh Xuan');
      expect(results.length, 1);
      expect(results.first['full_name'], 'Nguyễn Xiển');

      // 5. Tìm theo số điện thoại
      results = await appDb.searchCustomers('0909112233');
      expect(results.length, 1);
      expect(results.first['full_name'], 'Nguyễn Xiển');

      // 6. Tìm SĐT có khoảng cách "0909 112 233"
      results = await appDb.searchCustomers('0909 112 233');
      expect(results.length, 1);
      expect(results.first['full_name'], 'Nguyễn Xiển');
    });

    test('9. Chuẩn hóa SĐT và chặn trùng lặp khách hàng', () async {
      expect(normalizeCustomerPhone('090 123 4567'), '0901234567');
      expect(normalizeCustomerPhone('+84901234567'), '0901234567');
      expect(normalizeCustomerPhone('84901234567'), '0901234567');
      expect(normalizeCustomerPhone('901234567'), '0901234567');
      expect(normalizeCustomerPhone('(090) 123-4567'), '0901234567');

      // Thêm khách hàng với SĐT chưa chuẩn hóa
      final custId = await appDb.insertCustomer(
        fullName: 'Khách Test Phone',
        phoneNumber: '+84 901 234 567',
      );

      // Tra cứu bằng SĐT dạng khác
      final found = await appDb.getCustomerByPhone('(090) 123.4567');
      expect(found, isNotNull);
      expect(found!['id'], custId);
      expect(found['phone_number'], '0901234567');

      // Thêm khách hàng thứ hai cùng số điện thoại đã chuẩn hóa -> ném lỗi UNIQUE
      expect(
        () async => await appDb.insertCustomer(
          fullName: 'Khách Trùng',
          phoneNumber: '0901234567',
        ),
        throwsA(isA<DatabaseException>()),
      );
    });

    test('10. App Profile, App Meta và Activity Log hoạt động chính xác', () async {
      // 1. App Profile
      await appDb.setAppProfile(displayName: 'Shipper Nam', pinHash: 'hash123');
      var profile = await appDb.getAppProfile();
      expect(profile, isNotNull);
      expect(profile!['display_name'], 'Shipper Nam');
      expect(profile['pin_hash'], 'hash123');

      // Cập nhật đè lên id = 1
      await appDb.setAppProfile(displayName: 'Shipper Nam Cập Nhật');
      profile = await appDb.getAppProfile();
      expect(profile!['display_name'], 'Shipper Nam Cập Nhật');

      // 2. App Meta
      await appDb.setMeta('map_theme', 'dark');
      expect(await appDb.getMeta('map_theme'), 'dark');
      await appDb.setMeta('map_theme', 'light');
      expect(await appDb.getMeta('map_theme'), 'light');

      // 3. Activity Log
      final logId = await appDb.logActivity(
        action: 'VERIFY_GATE',
        entity: 'LOCATION',
        entityId: 'loc-test-1',
        details: {'lat': 21.0, 'lng': 105.8, 'password': 'SECRET_SHOULD_BE_REMOVED'},
      );
      final logs = await db.query('activity_log', where: 'id = ?', whereArgs: [logId]);
      expect(logs.length, 1);
      final logJson = logs.first['details_json'] as String;
      expect(logJson, contains('lat'));
      expect(logJson, isNot(contains('SECRET_SHOULD_BE_REMOVED')));
    });
  });
}
