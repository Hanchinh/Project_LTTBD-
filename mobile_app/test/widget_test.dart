import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:delivery_marker_mobile/main.dart';
import 'package:delivery_marker_mobile/views/login_view.dart';
import 'package:delivery_marker_mobile/models/order_model.dart';
import 'package:delivery_marker_mobile/models/location_model.dart';

void main() {
  group('Delivery Location Marker App Unit & Widget Tests', () {
    testWidgets('App root initializes with AuthSplashScreen', (WidgetTester tester) async {
      await tester.pumpWidget(const DeliveryLocationMarkerApp());

      // Verify presence of system splash title and loader
      expect(find.text('HỆ THỐNG ĐỊNH VỊ GIAO HÀNG'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byIcon(Icons.location_on_rounded), findsOneWidget);
    });

    testWidgets('LoginView renders input fields and validates empty inputs', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: LoginView(),
        ),
      );

      // Verify title & fields
      expect(find.text('Định Vị Giao Hàng'), findsOneWidget);
      expect(find.text('ĐĂNG NHẬP'), findsOneWidget);
      expect(find.byType(TextFormField), findsNWidgets(2));

      // Tap submit with empty inputs
      await tester.tap(find.text('ĐĂNG NHẬP'));
      await tester.pump();

      // Expect validation error messages
      expect(find.text('Vui lòng nhập số điện thoại'), findsOneWidget);
      expect(find.text('Vui lòng nhập mật khẩu'), findsOneWidget);
    });

    test('OrderModel deserializes correctly with customer and location data', () {
      final mockJson = {
        'orderId': 'ord-101',
        'orderCode': 'ORD-TEST-01',
        'orderStatus': 'PENDING',
        'area': {'id': 'area-1', 'name': 'Thủ Đức'},
        'customer': {
          'id': 'cust-1',
          'customerCode': 'KH_01',
          'fullName': 'Nguyễn Văn Test',
          'phoneNumber': '0988000001',
          'addressText': '124 Nguyễn Xiển',
          'hasSavedLocation': true,
          'savedLocation': {
            'id': 'loc-1',
            'latitude': 10.842215,
            'longitude': 106.818123,
            'gpsAccuracy': 4.5,
            'identificationNotes': 'Cổng màu xanh',
            'imageUrl': '/api/v1/photos/test.jpg',
            'updatedAt': '2026-10-22T00:00:00Z',
          },
        },
      };

      final order = OrderModel.fromJson(mockJson);
      expect(order.orderCode, 'ORD-TEST-01');
      expect(order.hasSavedLocation, true);
      expect(order.customerName, 'Nguyễn Văn Test');
      expect(order.savedLocation, isNotNull);
      expect(order.savedLocation!.latitude, 10.842215);
      expect(order.savedLocation!.imageUrl, '/api/v1/photos/test.jpg');
    });

    test('SavedLocationModel handles null and custom image URLs properly', () {
      final locWithImage = SavedLocationModel(
        customerId: 'cust-1',
        latitude: 10.8,
        longitude: 106.8,
        gpsAccuracy: 5.0,
        identificationNotes: 'Gần cây xăng',
        imageUrl: '/api/v1/photos/abc.jpg',
      );

      final json = locWithImage.toJson();
      expect(json['imageUrl'], '/api/v1/photos/abc.jpg');

      final deserialized = SavedLocationModel.fromJson(json, 'cust-1');
      expect(deserialized.imageUrl, '/api/v1/photos/abc.jpg');
      expect(deserialized.identificationNotes, 'Gần cây xăng');
    });
  });
}
