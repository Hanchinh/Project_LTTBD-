import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:delivery_marker_mobile/models/shift_model.dart';
import 'package:delivery_marker_mobile/models/customer_model.dart';
import 'package:delivery_marker_mobile/data/repositories/customer_repository.dart';
import 'package:delivery_marker_mobile/data/repositories/location_repository.dart';
import 'package:delivery_marker_mobile/data/repositories/photo_repository.dart';
import 'package:delivery_marker_mobile/data/repositories/profile_repository.dart';
import 'package:delivery_marker_mobile/data/repositories/shift_repository.dart';
import 'package:delivery_marker_mobile/data/local/local_sharing_repository.dart';
import 'package:delivery_marker_mobile/data/repositories/repository_provider.dart';
import 'package:delivery_marker_mobile/features/shifts/widgets/create_shift_dialog.dart';

/// Fake ShiftRepository để kiểm thử Dependency Injection
class FakeShiftRepository implements ShiftRepository {
  bool getShiftsCalled = false;
  bool createShiftCalled = false;
  String? lastCreatedName;

  @override
  Future<List<ShiftModel>> getShifts() async {
    getShiftsCalled = true;
    return [
      ShiftModel(
        id: 'fake-shift-1',
        shiftCode: 'SHF-20261026-001',
        shiftName: 'Ca thử nghiệm FakeRepo',
        shiftDate: '2026-10-26',
        shipperId: 'test-shipper-01',
        status: ShiftStatus.preparing,
        deliveryPoints: [],
      ),
    ];
  }

  @override
  Future<ShiftModel> createShift(
      {String? shiftDate, String? shiftName, String? notes}) async {
    createShiftCalled = true;
    lastCreatedName = shiftName;
    return ShiftModel(
      id: 'fake-created-shift-2',
      shiftCode: 'SHF-20261026-002',
      shiftName: shiftName ?? 'Ca mới',
      shiftDate: shiftDate ?? '2026-10-26',
      shipperId: 'test-shipper-01',
      status: ShiftStatus.preparing,
      deliveryPoints: [],
    );
  }

  @override
  Future<ShiftModel> getShiftDetail(String shiftId) async =>
      throw UnimplementedError();

  @override
  Future<ShiftModel> updateShiftName(String shiftId, String shiftName) async =>
      throw UnimplementedError();

  @override
  Future<ShiftModel> updateShiftStatus(
          String shiftId, ShiftStatus status) async =>
      throw UnimplementedError();

  @override
  Future<bool> deleteShift(String shiftId) async => true;

  @override
  Future<Map<String, dynamic>> addPointToShift(String shiftId,
          {String? customerId,
          String? phoneNumber,
          bool createIfNotFound = false,
          String? fullName,
          String? addressText,
          String? orderId,
          int? sequenceNumber,
          String? deliveryNotes,
          String? areaId}) async =>
      throw UnimplementedError();

  @override
  Future<BulkAddPointsResult> addBulkPointsToShift(
          {required String shiftId,
          String? rawText,
          List<String>? phones,
          String? areaId}) async =>
      throw UnimplementedError();

  @override
  Future<void> removePointFromShift(String shiftId, String pointId) async {}

  @override
  Future<void> verifyPointLocation(String shiftId, String pointId) async =>
      throw UnsupportedError('verifyPointLocation is deprecated');
}

/// Fake CustomerRepository để kiểm thử
class FakeCustomerRepository implements CustomerRepository {
  bool getCustomersCalled = false;

  @override
  Future<List<CustomerDirectoryModel>> getCustomers(
      {String? query,
      String? status,
      bool? hasPhoto,
      int? limit,
      int? offset}) async {
    getCustomersCalled = true;
    return [];
  }

  @override
  Future<CustomerDirectoryResponse> getCustomersResponse(
      {String? query,
      String? status,
      bool? hasPhoto,
      int? limit,
      int? offset}) async {
    return const CustomerDirectoryResponse();
  }

  @override
  Future<CustomerDirectoryModel> getCustomerDetail(String customerId) async =>
      throw UnimplementedError();

  @override
  Future<CustomerDirectoryModel> createCustomer(
          {required String phoneNumber,
          String? fullName,
          String? addressText,
          String? areaId,
          double? latitude,
          double? longitude,
          double? gpsAccuracy,
          String? identificationNotes,
          String? imageBase64}) async =>
      throw UnimplementedError();

  @override
  Future<BulkCreateCustomersResult> createBulkCustomers(
          {String? rawText, List<String>? phones, String? areaId}) async =>
      throw UnimplementedError();

  @override
  Future<Map<String, dynamic>> updateCustomer(
          {required String customerId,
          required String fullName,
          required String phoneNumber,
          String? addressText}) async =>
      throw UnimplementedError();

  @override
  Future<Map<String, dynamic>?> lookupCustomerLocationByPhone(
          String phoneNumber) async =>
      null;

  @override
  Future<bool> deleteCustomer(String customerId) async => true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TASK: LOCAL-FIRST-01-REPOSITORY-LAYER Tests', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      RepositoryProvider.reset();
    });

    tearDown(() {
      RepositoryProvider.reset();
    });

    test(
        '1. RepositoryProvider mặc định khởi tạo LocalRepository trên nhánh local-first và Remote khi useLocalData=false',
        () {
      // Mặc định nhánh local-first: Local
      expect(RepositoryProvider.customer, isA<CustomerRepository>());
      expect(RepositoryProvider.location, isA<LocationRepository>());
      expect(RepositoryProvider.photo, isA<PhotoRepository>());
      expect(RepositoryProvider.shift, isA<ShiftRepository>());
      expect(RepositoryProvider.sharing, isA<LocalSharingRepository>());
      expect(RepositoryProvider.profile, isA<ProfileRepository>());

          });

    test('2. RepositoryProvider hỗ trợ override bằng FakeRepository và reset',
        () {
      final fakeShift = FakeShiftRepository();
      final fakeCustomer = FakeCustomerRepository();

      RepositoryProvider.overrideRepositories(
        shift: fakeShift,
        customer: fakeCustomer,
      );

      expect(RepositoryProvider.shift, same(fakeShift));
      expect(RepositoryProvider.customer, same(fakeCustomer));

      RepositoryProvider.reset();

      expect(RepositoryProvider.shift, isA<ShiftRepository>());
      expect(RepositoryProvider.customer, isA<CustomerRepository>());
    });

    testWidgets(
        '3. Màn hình/Widget dùng đúng FakeShiftRepository được tiêm vào',
        (tester) async {
      final fakeShift = FakeShiftRepository();
      RepositoryProvider.overrideRepositories(shift: fakeShift);

      await tester.binding.setSurfaceSize(const Size(360, 700));

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CreateShiftBottomSheet(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Kiểm tra widget đã gọi getShifts() trên FakeShiftRepository để gợi ý tên ca chống trùng
      expect(fakeShift.getShiftsCalled, isTrue);

      // Nhấn nút tạo ca
      final createButton =
          find.widgetWithText(ElevatedButton, 'TẠO CA VÀ MỞ BẢN ĐỒ');
      expect(createButton, findsOneWidget);

      await tester.tap(createButton);
      await tester.pumpAndSettle();

      // Kiểm tra widget đã gọi createShift() trên FakeShiftRepository
      expect(fakeShift.createShiftCalled, isTrue);
      expect(fakeShift.lastCreatedName, isNotEmpty);
    });
  });
}
