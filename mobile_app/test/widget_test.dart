import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:delivery_marker_mobile/main.dart';
import 'package:delivery_marker_mobile/views/login_view.dart';
import 'package:delivery_marker_mobile/views/delivery_map_view.dart';
import 'package:delivery_marker_mobile/models/order_model.dart';
import 'package:delivery_marker_mobile/models/location_model.dart';
import 'package:delivery_marker_mobile/models/shift_model.dart';
import 'package:delivery_marker_mobile/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

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

    testWidgets('DeliveryMapView initializes with map, header card, and action buttons', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: DeliveryMapView(),
        ),
      );
      await tester.pump();

      // Verify presence of header title, FABs, and bottom sheet summary
      expect(find.text('Bản Đồ Giao Hàng'), findsOneWidget);
      expect(find.byIcon(Icons.zoom_out_map), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsWidgets);
      expect(find.textContaining('Danh Sách Đơn Trong Ca'), findsOneWidget);
    });

    test('Order filtering correctly separates verified location vs unlocated orders', () {
      final orderWithLoc = OrderModel(
        orderId: 'o-1',
        orderCode: 'ORD-01',
        orderStatus: 'PENDING',
        areaName: 'Thủ Đức',
        customerId: 'c-1',
        customerName: 'Anh Minh',
        customerPhone: '0901234567',
        customerAddress: '123 Đỗ Xuân Hợp',
        hasSavedLocation: true,
        savedLocation: SavedLocationModel(
          customerId: 'c-1',
          latitude: 10.83,
          longitude: 106.77,
          gpsAccuracy: 3.2,
          identificationNotes: 'Cổng màu trắng',
        ),
      );

      final orderWithoutLoc = OrderModel(
        orderId: 'o-2',
        orderCode: 'ORD-02',
        orderStatus: 'PENDING',
        areaName: 'Thủ Đức',
        customerId: 'c-2',
        customerName: 'Chị Lan',
        customerPhone: '0909876543',
        customerAddress: '456 Lê Văn Việt',
        hasSavedLocation: false,
        savedLocation: null,
      );

      final orders = [orderWithLoc, orderWithoutLoc];
      final located = orders.where((o) => o.hasSavedLocation && o.savedLocation != null).toList();
      final unlocated = orders.where((o) => !o.hasSavedLocation || o.savedLocation == null).toList();

      expect(located.length, 1);
      expect(located.first.orderCode, 'ORD-01');
      expect(unlocated.length, 1);
      expect(unlocated.first.orderCode, 'ORD-02');
    });

    testWidgets('DeliveryMapView displays phone search bar and TÌM KHÁCH button (FEATURE-ORDER-ENTRY-001)', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: DeliveryMapView(),
        ),
      );
      await tester.pump();

      // Verify phone search field and action button
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Nhập SĐT khách hàng...'), findsOneWidget);
      expect(find.text('TÌM KHÁCH'), findsOneWidget);
      expect(find.byIcon(Icons.search), findsOneWidget);
    });

    test('Vietnamese Phone Normalization logic cleans formats correctly', () {
      String normalizePhone(String raw) {
        var clean = raw.replaceAll(RegExp(r'\D'), '');
        if (clean.startsWith('84') && clean.length == 11) {
          clean = '0${clean.substring(2)}';
        }
        return clean;
      }

      expect(normalizePhone('0988 000 001'), '0988000001');
      expect(normalizePhone('+84988000001'), '0988000001');
      expect(normalizePhone('84988000001'), '0988000001');
      expect(normalizePhone('0988-000-001'), '0988000001');
      expect(normalizePhone('0988.000.001'), '0988000001');
      expect(normalizePhone('(0988) 000 001'), '0988000001');
    });

    test('Shift Order Deduplication logic detects existing customer order', () {
      final existingOrders = [
        OrderModel(
          orderId: 'ord-101',
          orderCode: 'ORD-20261023-01',
          orderStatus: 'PENDING',
          areaName: 'Thủ Đức',
          customerId: 'cust-uuid-1',
          customerName: 'Nguyễn Văn A',
          customerPhone: '0988000001',
          customerAddress: '123 Đặng Văn Bi',
          hasSavedLocation: true,
        ),
      ];

      // Customer 1 already in shift
      final match1 = existingOrders.where((o) => o.customerId == 'cust-uuid-1').toList();
      expect(match1.isNotEmpty, true);
      expect(match1.first.orderCode, 'ORD-20261023-01');

      // Customer 2 not in shift
      final match2 = existingOrders.where((o) => o.customerId == 'cust-uuid-2').toList();
      expect(match2.isEmpty, true);
    });

    test('BUG-MAP-PHOTO-008: ShiftDeliveryPointModel parses photoUrl and imageUrl identically', () {
      final jsonWithImageUrl = {
        'pointId': 'p-1',
        'shiftId': 's-1',
        'customerId': 'c-1',
        'customerName': 'Nguyễn Văn B',
        'customerPhone': '0901234567',
        'customerAddress': '456 Lê Văn Việt',
        'locationStatus': 'TEMPORARY',
        'latitude': 10.84,
        'longitude': 106.81,
        'imageUrl': '/api/v1/photos/gate_image.jpg',
      };

      final point1 = ShiftDeliveryPointModel.fromJson(jsonWithImageUrl);
      expect(point1.photoUrl, '/api/v1/photos/gate_image.jpg');
      expect(point1.photoUrl != null && point1.photoUrl!.isNotEmpty, isTrue);

      final jsonWithPhotoUrl = {
        'id': 'p-2',
        'shift_id': 's-1',
        'customerId': 'c-2',
        'customerName': 'Trần Văn C',
        'customerPhone': '0901234568',
        'customerAddress': '789 Đỗ Xuân Hợp',
        'locationStatus': 'VERIFIED',
        'latitude': 10.85,
        'longitude': 106.82,
        'photoUrl': '/api/v1/photos/verified_image.jpg',
      };

      final point2 = ShiftDeliveryPointModel.fromJson(jsonWithPhotoUrl);
      expect(point2.photoUrl, '/api/v1/photos/verified_image.jpg');
      expect(point2.photoUrl != null && point2.photoUrl!.isNotEmpty, isTrue);

      final jsonWithoutPhoto = {
        'pointId': 'p-3',
        'shiftId': 's-1',
        'customerId': 'c-3',
        'customerName': 'Lê Văn D',
        'customerPhone': '0901234569',
        'customerAddress': '12 Nguyễn Duy Trinh',
        'locationStatus': 'NO_LOCATION',
      };

      final point3 = ShiftDeliveryPointModel.fromJson(jsonWithoutPhoto);
      expect(point3.photoUrl, isNull);
      expect(point3.photoUrl != null && point3.photoUrl!.isNotEmpty, isFalse);
    });

    test('BUG-MAP-PHOTO-008: ApiService.getPhotoAuthInfo formats token in query param and headers for Web/Mobile', () async {
      SharedPreferences.setMockInitialValues({});
      await ApiService.saveToken('test_jwt_token_12345');
      await ApiService.setCustomBaseUrl('http://localhost:3000/api/v1');

      final authInfo = await ApiService.getPhotoAuthInfo(
        '/api/v1/photos/customer_house.jpg',
        cacheVersion: 9999,
      );

      expect(authInfo['token'], 'test_jwt_token_12345');
      final url = authInfo['url']!;
      expect(url, startsWith('http://localhost:3000/api/v1/photos/customer_house.jpg'));
      expect(url, contains('v=9999'));
      expect(url, contains('token=test_jwt_token_12345'));
    });
  });
}
