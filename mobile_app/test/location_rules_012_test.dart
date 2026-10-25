import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:delivery_marker_mobile/views/crosshair_location_picker_view.dart';
import 'package:delivery_marker_mobile/models/shift_model.dart';
import 'package:delivery_marker_mobile/models/customer_model.dart';

void main() {
  group('TASK: LOCATION-RULES-012 - Flutter UI & Flow Tests', () {
    final mockShiftPoint = ShiftDeliveryPointModel(
      id: 'point-test-012',
      shiftId: 'shift-test-012',
      customerId: 'customer-test-012',
      customerName: 'Khách hàng A',
      customerPhone: '0988000001',
      customerAddress: '123 Đường Test, P. Long Thạnh Mỹ',
      locationStatus: LocationStatus.noLocation,
      latitude: 10.8422,
      longitude: 106.8181,
      locationNotes: 'Nhà có cổng sắt',
    );

    testWidgets('Crosshair picker shows "Lưu vị trí tạm" when opened from shift flow', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CrosshairLocationPickerView(
            point: mockShiftPoint,
            shiftId: 'shift-test-012',
            initialCenter: const LatLng(10.8422, 106.8181),
          ),
        ),
      );

      // Verify that "Xác minh cổng nhà" does NOT exist
      expect(find.text('XÁC MINH CỔNG NHÀ'), findsNothing);
      expect(find.text('Xác minh cổng nhà'), findsNothing);

      // Verify that "Lưu vị trí tạm" is shown
      expect(find.text('Lưu vị trí tạm'), findsOneWidget);
    });

    testWidgets('Crosshair picker shows "Xác nhận vị trí" when opened from Customer Directory flow', (tester) async {
      final mockDirectoryPoint = ShiftDeliveryPointModel(
        id: '',
        shiftId: '',
        customerId: 'customer-test-012',
        customerName: 'Khách hàng B',
        customerPhone: '0988000002',
        customerAddress: '456 Đường Test, P. Tăng Nhơn Phú A',
        locationStatus: LocationStatus.verified,
        latitude: 10.8430,
        longitude: 106.8190,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: CrosshairLocationPickerView(
            point: mockDirectoryPoint,
            shiftId: '', // Empty shiftId = Directory flow
            initialCenter: const LatLng(10.8430, 106.8190),
          ),
        ),
      );

      // Verify that "Lưu vị trí tạm" does NOT exist for directory flow
      expect(find.text('Lưu vị trí tạm'), findsNothing);

      // Verify that "Xác nhận vị trí" is shown
      expect(find.text('Xác nhận vị trí'), findsOneWidget);
    });

    test('Location status semantics: ShiftDeliveryPoint supports TEMPORARY and VERIFIED', () {
      final pointTemp = ShiftDeliveryPointModel.fromJson({
        'pointId': 'p-temp',
        'shiftId': 's-01',
        'customerId': 'c-01',
        'customerName': 'Khách Tạm',
        'locationStatus': 'TEMPORARY',
        'latitude': 10.841,
        'longitude': 106.812,
      });
      expect(pointTemp.locationStatus, LocationStatus.temporary);

      final pointVerified = ShiftDeliveryPointModel.fromJson({
        'pointId': 'p-ver',
        'shiftId': 's-01',
        'customerId': 'c-01',
        'customerName': 'Khách Chuẩn',
        'locationStatus': 'VERIFIED',
        'latitude': 10.842,
        'longitude': 106.818,
      });
      expect(pointVerified.locationStatus, LocationStatus.verified);
    });

    test('CustomerDirectoryModel maintains verified location without redundant status column', () {
      final customerJson = {
        'id': 'cust-012',
        'customerCode': 'KH_012',
        'fullName': 'Khách Chuẩn 012',
        'phoneNumber': '0988000099',
        'addressText': '789 Đường Hoa Lan',
        'latitude': 10.8455,
        'longitude': 106.8166,
        'identificationNotes': 'Cửa kính lớn',
        'imageUrl': '/api/v1/photos/gate.jpg',
      };

      final customer = CustomerDirectoryModel.fromJson(customerJson);
      expect(customer.latitude, 10.8455);
      expect(customer.longitude, 106.8166);
      expect(customer.hasLocation, true);
      expect(customer.identificationNotes, 'Cửa kính lớn');
    });
  });
}
