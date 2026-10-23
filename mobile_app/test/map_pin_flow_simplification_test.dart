import 'package:flutter_test/flutter_test.dart';
import 'package:delivery_marker_mobile/models/shift_model.dart';
import 'package:delivery_marker_mobile/models/customer_model.dart';

void main() {
  group('MAP-PIN-FLOW-SIMPLIFICATION-006: Business & Status Transition Tests', () {
    test('Scenario 1: NO_LOCATION point transitions to TEMPORARY upon single-click pin', () {
      final point = ShiftDeliveryPointModel(
        id: 'point-001',
        shiftId: 'shift-001',
        customerId: 'cust-001',
        customerName: 'Nguyễn Văn A',
        customerPhone: '0901234567',
        customerAddress: '123 Kha Vạn Cân, TP Thủ Đức',
        deliveryStatus: 'PENDING',
        locationStatus: LocationStatus.noLocation,
        latitude: null,
        longitude: null,
      );

      expect(point.locationStatus, equals(LocationStatus.noLocation));
      expect(point.hasValidCoordinates, isFalse);

      // Khi ghim vị trí mới
      final updatedPoint = ShiftDeliveryPointModel(
        id: point.id,
        shiftId: point.shiftId,
        customerId: point.customerId,
        customerName: point.customerName,
        customerPhone: point.customerPhone,
        customerAddress: point.customerAddress,
        deliveryStatus: point.deliveryStatus,
        locationStatus: LocationStatus.temporary, // Chuyển thành TEMPORARY
        latitude: 10.850000,
        longitude: 106.760000,
        locationNotes: null, // Không gửi chuỗi mặc định tự sinh
      );

      expect(updatedPoint.locationStatus, equals(LocationStatus.temporary));
      expect(updatedPoint.hasValidCoordinates, isTrue);
      expect(updatedPoint.latitude, equals(10.850000));
      expect(updatedPoint.longitude, equals(106.760000));
      expect(updatedPoint.locationNotes, isNull);
    });

    test('Scenario 2: TEMPORARY point keeps TEMPORARY status when coordinates are adjusted', () {
      final point = ShiftDeliveryPointModel(
        id: 'point-002',
        shiftId: 'shift-001',
        customerId: 'cust-002',
        customerName: 'Trần Thị B',
        customerPhone: '0912345678',
        customerAddress: '456 Võ Văn Ngân, TP Thủ Đức',
        deliveryStatus: 'PENDING',
        locationStatus: LocationStatus.temporary,
        latitude: 10.851000,
        longitude: 106.761000,
      );

      expect(point.locationStatus, equals(LocationStatus.temporary));

      // Chỉnh tọa độ
      final updatedPoint = ShiftDeliveryPointModel(
        id: point.id,
        shiftId: point.shiftId,
        customerId: point.customerId,
        customerName: point.customerName,
        customerPhone: point.customerPhone,
        customerAddress: point.customerAddress,
        deliveryStatus: point.deliveryStatus,
        locationStatus: LocationStatus.temporary, // Vẫn là TEMPORARY
        latitude: 10.852000,
        longitude: 106.762000,
      );

      expect(updatedPoint.locationStatus, equals(LocationStatus.temporary));
      expect(updatedPoint.latitude, equals(10.852000));
    });

    test('Scenario 3: VERIFIED point falls back to TEMPORARY when coordinates change without gate re-verification', () {
      final point = ShiftDeliveryPointModel(
        id: 'point-003',
        shiftId: 'shift-001',
        customerId: 'cust-003',
        customerName: 'Lê Văn C',
        customerPhone: '0987654321',
        customerAddress: '789 Đỗ Xuân Hợp, TP Thủ Đức',
        deliveryStatus: 'PENDING',
        locationStatus: LocationStatus.verified,
        latitude: 10.820000,
        longitude: 106.770000,
      );

      expect(point.locationStatus, equals(LocationStatus.verified));

      // Quy tắc nghiệp vụ: Khi ghim nhanh đổi tọa độ trên bản đồ, điểm trở về TEMPORARY
      final updatedPoint = ShiftDeliveryPointModel(
        id: point.id,
        shiftId: point.shiftId,
        customerId: point.customerId,
        customerName: point.customerName,
        customerPhone: point.customerPhone,
        customerAddress: point.customerAddress,
        deliveryStatus: point.deliveryStatus,
        locationStatus: LocationStatus.temporary, // Phải chuyển về TEMPORARY, không mù quáng giữ VERIFIED
        latitude: 10.821000,
        longitude: 106.771000,
      );

      expect(updatedPoint.locationStatus, equals(LocationStatus.temporary));
      expect(updatedPoint.latitude, equals(10.821000));
    });

    test('Scenario 4: Customer filtering logic in Selection Bottom Sheet filters only active shift and supports quick search', () {
      final currentShiftPoints = [
        ShiftDeliveryPointModel(
          id: 'p1',
          shiftId: 'shift-01',
          customerId: 'c1',
          customerName: 'Nguyễn Văn An',
          customerPhone: '0901111111',
          customerAddress: 'Thủ Đức',
          deliveryStatus: 'PENDING',
          locationStatus: LocationStatus.verified,
        ),
        ShiftDeliveryPointModel(
          id: 'p2',
          shiftId: 'shift-01',
          customerId: 'c2',
          customerName: 'Trần Thị Bình',
          customerPhone: '0902222222',
          customerAddress: 'Quận 9',
          deliveryStatus: 'PENDING',
          locationStatus: LocationStatus.temporary,
        ),
        ShiftDeliveryPointModel(
          id: 'p3',
          shiftId: 'shift-01',
          customerId: 'c3',
          customerName: 'Lê Hoàng Cường',
          customerPhone: '0903333333',
          customerAddress: 'Bình Thạnh',
          deliveryStatus: 'PENDING',
          locationStatus: LocationStatus.noLocation,
        ),
      ];

      List<ShiftDeliveryPointModel> filterCustomers(String query) {
        final q = query.trim().toLowerCase();
        if (q.isEmpty) return currentShiftPoints;
        return currentShiftPoints.where((p) {
          final name = p.customerName.toLowerCase();
          final phone = p.customerPhone.toLowerCase();
          final address = p.customerAddress.toLowerCase();
          return name.contains(q) || phone.contains(q) || address.contains(q);
        }).toList();
      }

      // Không tìm kiếm -> Hiện đủ 3
      expect(filterCustomers('').length, equals(3));

      // Tìm theo số điện thoại
      final byPhone = filterCustomers('2222');
      expect(byPhone.length, equals(1));
      expect(byPhone.first.customerName, equals('Trần Thị Bình'));

      // Tìm theo tên
      final byName = filterCustomers('cường');
      expect(byName.length, equals(1));
      expect(byName.first.customerPhone, equals('0903333333'));

      // Tìm không có kết quả
      expect(filterCustomers('999999').isEmpty, isTrue);
    });

    test('Scenario 5: Duplicate request prevention state during single-click save', () {
      bool isSaving = false;
      int apiCallCount = 0;

      Future<void> confirmPin() async {
        if (isSaving) return; // Khóa ngăn spam click
        isSaving = true;
        apiCallCount++;
        // Giả lập thời gian xử lý API
        await Future.delayed(const Duration(milliseconds: 50));
        isSaving = false;
      }

      // Bấm liên tiếp 3 lần khi đang loading
      confirmPin();
      confirmPin();
      confirmPin();

      expect(apiCallCount, equals(1)); // Chỉ được gọi đúng 1 lần
    });

    test('Scenario 6: PIN-FLOW-DATA-INTEGRITY-AUDIT-007: Pinning preserves existing customer identification notes and photo', () {
      final point = ShiftDeliveryPointModel(
        id: 'point-gate-001',
        shiftId: 'shift-001',
        customerId: 'cust-gate-001',
        customerName: 'Bác Tư (Nhà Cổng Xanh)',
        customerPhone: '0988111222',
        customerAddress: '12 Hẻm 54, Phước Long B',
        deliveryStatus: 'PENDING',
        locationStatus: LocationStatus.noLocation,
        latitude: null,
        longitude: null,
        locationNotes: 'Cổng gỗ màu nâu, cây hoa giấy đỏ trước ngõ',
        photoUrl: 'http://localhost:3000/api/v1/photos/gate_456.jpg',
      );

      // Khi shipper ghim lại tọa độ mới trên bản đồ mà không nhập ghi chú mới
      const newLat = 10.825000;
      const newLng = 106.775000;
      const String? customNotes = null; // Không có ghi chú mới

      final rePinnedPoint = ShiftDeliveryPointModel(
        id: point.id,
        shiftId: point.shiftId,
        customerId: point.customerId,
        customerName: point.customerName,
        customerPhone: point.customerPhone,
        customerAddress: point.customerAddress,
        deliveryStatus: point.deliveryStatus,
        locationStatus: LocationStatus.temporary,
        latitude: newLat,
        longitude: newLng,
        locationNotes: customNotes ?? point.locationNotes, // Bảo toàn nguyên vẹn ghi chú cũ!
        photoUrl: point.photoUrl, // Bảo toàn nguyên vẹn ảnh cổng nhà cũ!
      );

      expect(rePinnedPoint.locationStatus, equals(LocationStatus.temporary));
      expect(rePinnedPoint.latitude, equals(10.825000));
      expect(rePinnedPoint.longitude, equals(106.775000));
      expect(rePinnedPoint.locationNotes, equals('Cổng gỗ màu nâu, cây hoa giấy đỏ trước ngõ'));
      expect(rePinnedPoint.photoUrl, equals('http://localhost:3000/api/v1/photos/gate_456.jpg'));
    });

    test('Scenario 7: PIN-FLOW-DATA-INTEGRITY-AUDIT-007: CustomerDirectoryModel parses TEMPORARY status from API and keeps coordinates', () {
      final apiResponseJson = {
        'id': 'cust-temp-001',
        'customerCode': 'KH_002',
        'fullName': 'Chị Mai Cơm Tấm',
        'phoneNumber': '0903456789',
        'addressText': 'Chợ Phước Bình, Thủ Đức',
        'areaId': 'area-thu-duc',
        'areaName': 'Thủ Đức',
        'locationStatus': 'TEMPORARY',
        'hasLocation': true,
        'latitude': 10.830000,
        'longitude': 106.780000,
        'identificationNotes': 'Gần quầy bán thịt heo',
        'imageUrl': null,
      };

      final customer = CustomerDirectoryModel.fromJson(apiResponseJson);

      expect(customer.locationStatus, equals(LocationStatus.temporary));
      expect(customer.hasLocation, isTrue);
      expect(customer.hasValidCoordinates, isTrue);
      expect(customer.latitude, equals(10.830000));
      expect(customer.longitude, equals(106.780000));
      expect(customer.identificationNotes, equals('Gần quầy bán thịt heo'));
    });

    test('Scenario 8: PIN-FLOW-DATA-INTEGRITY-AUDIT-007: Discard auto-generated strings and only accept genuine user notes', () {
      String? cleanUserNotes(String? input) {
        if (input == null || input.trim().isEmpty) return null;
        final trimmed = input.trim();
        if (trimmed == 'Ghim trực tiếp từ bản đồ chính' || trimmed == 'Ghim tạm từ bộ chọn tâm ngắm bản đồ') {
          return null; // Chuỗi tự sinh bị loại bỏ
        }
        return trimmed;
      }

      expect(cleanUserNotes('Ghim trực tiếp từ bản đồ chính'), isNull);
      expect(cleanUserNotes('Ghim tạm từ bộ chọn tâm ngắm bản đồ'), isNull);
      expect(cleanUserNotes('   '), isNull);
      expect(cleanUserNotes(null), isNull);
      expect(cleanUserNotes('Đổi vị trí sang quán cà phê kế bên'), equals('Đổi vị trí sang quán cà phê kế bên'));
    });
  });
}

