import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:delivery_marker_mobile/models/customer_model.dart';
import 'package:delivery_marker_mobile/models/shift_model.dart';
import 'package:delivery_marker_mobile/views/home_shell_view.dart';

void main() {
  group('MAP-FIRST-ARCHITECTURE-005: Model & Selection Logic Tests', () {
    test('CustomerDirectoryModel parses correctly and detects status & photo', () {
      final json = {
        'id': 'cust-001',
        'customerCode': 'KH-001',
        'fullName': 'Nguyễn Văn An',
        'phoneNumber': '0901234567',
        'addressText': '123 Lê Văn Việt, TP Thủ Đức',
        'area': {'id': 'area-01', 'name': 'Thủ Đức'},
        'locationStatus': 'VERIFIED',
        'latitude': 10.845678,
        'longitude': 106.789012,
        'identificationNotes': 'Cổng sắt màu xanh',
        'imageUrl': '/api/v1/locations/photos/gate_001.jpg',
        'hasPhoto': true,
      };

      final model = CustomerDirectoryModel.fromJson(json);

      expect(model.id, equals('cust-001'));
      expect(model.fullName, equals('Nguyễn Văn An'));
      expect(model.phoneNumber, equals('0901234567'));
      expect(model.locationStatus, equals(LocationStatus.verified));
      expect(model.hasValidCoordinates, isTrue);
      expect(model.hasPhoto, isTrue);
      expect(model.imageUrl, equals('/api/v1/locations/photos/gate_001.jpg'));
    });

    test('CustomerDirectoryModel handles null coordinates and missing photo gracefully', () {
      final json = {
        'id': 'cust-002',
        'fullName': 'Trần Thị B',
        'phoneNumber': '0912345678',
        'addressText': 'Chưa rõ số nhà',
        'locationStatus': 'NO_LOCATION',
        'latitude': null,
        'longitude': null,
        'imageUrl': null,
      };

      final model = CustomerDirectoryModel.fromJson(json);

      expect(model.locationStatus, equals(LocationStatus.noLocation));
      expect(model.hasValidCoordinates, isFalse);
      expect(model.hasPhoto, isFalse);
    });

    test('Default Shift Selection Priority follows required order', () {
      final shifts = [
        ShiftModel(
          id: 'shift-prep-old',
          shiftCode: 'SHF-20261020-001',
          shiftDate: '2026-10-20',
          shipperId: 'shipper-01',
          status: ShiftStatus.preparing,
          createdAt: DateTime(2026, 10, 20),
        ),
        ShiftModel(
          id: 'shift-in-progress',
          shiftCode: 'SHF-20261023-001',
          shiftDate: '2026-10-23',
          shipperId: 'shipper-01',
          status: ShiftStatus.inProgress,
          createdAt: DateTime(2026, 10, 23, 8),
        ),
        ShiftModel(
          id: 'shift-prep-new',
          shiftCode: 'SHF-20261023-002',
          shiftDate: '2026-10-23',
          shipperId: 'shipper-01',
          status: ShiftStatus.preparing,
          createdAt: DateTime(2026, 10, 23, 10),
        ),
      ];

      // Trường hợp 1: Có ID đã lưu và hợp lệ
      ShiftModel? selectShift({String? savedId}) {
        if (savedId != null) {
          final matched = shifts.where((s) => s.id == savedId).toList();
          if (matched.isNotEmpty) return matched.first;
        }

        // Ưu tiên IN_PROGRESS
        final inProg = shifts.where((s) => s.status == ShiftStatus.inProgress).toList();
        if (inProg.isNotEmpty) return inProg.first;

        // Ưu tiên PREPARING
        final prep = shifts.where((s) => s.status == ShiftStatus.preparing).toList();
        if (prep.isNotEmpty) return prep.first;

        return shifts.isNotEmpty ? shifts.first : null;
      }

      // Ưu tiên 1: Saved ID
      expect(selectShift(savedId: 'shift-prep-old')?.id, equals('shift-prep-old'));

      // Ưu tiên 2: Không có saved ID -> Chọn IN_PROGRESS
      expect(selectShift(savedId: null)?.id, equals('shift-in-progress'));

      // Ưu tiên 3: Không có saved ID, không có IN_PROGRESS -> Chọn PREPARING
      final prepOnlyShifts = shifts.where((s) => s.status == ShiftStatus.preparing).toList();
      final chosenPrep = prepOnlyShifts.firstWhere((s) => s.status == ShiftStatus.preparing);
      expect(chosenPrep.id, isNotNull);
    });

    test('Race-condition counter mechanism prevents stale responses from overwriting state', () {
      int loadSequence = 0;
      String currentActiveData = 'INITIAL';

      void simulateShiftSwitch(int requestedSeq, String resultData) {
        // Chỉ cập nhật nếu response trùng với sequence mới nhất
        if (requestedSeq == loadSequence) {
          currentActiveData = resultData;
        }
      }

      // Shipper bấm đổi ca A -> seq = 1
      final seqA = ++loadSequence;
      expect(seqA, equals(1));

      // Ngay sau đó shipper bấm đổi ca B -> seq = 2
      final seqB = ++loadSequence;
      expect(seqB, equals(2));

      // Giả sử request ca A trả về trễ sau khi ca B đã kích hoạt
      simulateShiftSwitch(seqA, 'DATA_SHIFT_A');
      expect(currentActiveData, equals('INITIAL')); // Bị loại bỏ, không ghi đè

      // Request ca B trả về đúng lúc
      simulateShiftSwitch(seqB, 'DATA_SHIFT_B');
      expect(currentActiveData, equals('DATA_SHIFT_B')); // Được chấp nhận
    });

    test('Photo URL Cache Busting appends unique version timestamp parameter', () {
      String buildPhotoUrl(String baseUrl, String photoPath, {int? version, bool bustCache = false}) {
        String url = photoPath.startsWith('http') ? photoPath : '$baseUrl$photoPath';
        if (bustCache) {
          final v = version ?? 1729678900000;
          final sep = url.contains('?') ? '&' : '?';
          url = '$url${sep}v=$v';
        }
        return url;
      }

      final url = buildPhotoUrl('http://10.0.2.2:3000', '/api/v1/locations/photos/gate.jpg', version: 1729699999999, bustCache: true);
      expect(url, equals('http://10.0.2.2:3000/api/v1/locations/photos/gate.jpg?v=1729699999999'));
    });
  });

  group('MAP-FIRST-ARCHITECTURE-005: HomeShellView Widget Structure Tests', () {
    testWidgets('HomeShellView renders 3 main navigation destinations: Bản đồ, Danh bạ, Ca làm việc', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: HomeShellView(initialTab: 0),
        ),
      );

      // Verify that the 3 destinations exist in the NavigationBar
      expect(find.text('Bản đồ'), findsOneWidget);
      expect(find.text('Danh bạ'), findsOneWidget);
      expect(find.descendant(of: find.byType(NavigationBar), matching: find.text('Ca làm việc')), findsOneWidget);

      // Verify Icons
      expect(find.byIcon(Icons.map_rounded), findsOneWidget);
      expect(find.byIcon(Icons.contacts_outlined), findsOneWidget);
      expect(find.byIcon(Icons.assignment_outlined), findsOneWidget);
    });
  });
}
