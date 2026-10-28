import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:delivery_marker_mobile/main.dart';
import 'package:delivery_marker_mobile/models/order_model.dart';
import 'package:delivery_marker_mobile/models/location_model.dart';
import 'package:delivery_marker_mobile/models/shift_model.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Delivery Location Marker App Unit & Widget Tests', () {
    testWidgets('App root initializes with AuthSplashScreen', (WidgetTester tester) async {
      await tester.pumpWidget(const DeliveryLocationMarkerApp());
      await tester.pump();

      // Kiểm tra thành phần trên màn hình Splash
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byIcon(Icons.location_on_rounded), findsOneWidget);

      // Đợi hoàn tất các timer bất đồng bộ
      await tester.pump(const Duration(milliseconds: 500));
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

    test('Order filtering correctly separates verified location vs unlocated orders', () {
      final orderWithLoc = OrderModel(
        orderId: 'o-1',
        orderCode: 'ORD-01',
        orderStatus: 'PENDING',
        areaName: 'Thủ Đức',
        customerId: 'c-1',
        customerName: 'Anh Minh',
        customerPhone: '0901000001',
        customerAddress: '123 Đặng Văn Bi',
        hasSavedLocation: true,
        savedLocation: SavedLocationModel(
          customerId: 'c-1',
          latitude: 10.85,
          longitude: 106.77,
          gpsAccuracy: 3.5,
          identificationNotes: 'Nhà có cửa cuốn màu xám',
        ),
      );

      final orderWithoutLoc = OrderModel(
        orderId: 'o-2',
        orderCode: 'ORD-02',
        orderStatus: 'PENDING',
        areaName: 'Thủ Đức',
        customerId: 'c-2',
        customerName: 'Chị Lan',
        customerPhone: '0902000002',
        customerAddress: '456 Võ Văn Ngân',
        hasSavedLocation: false,
      );

      final orders = [orderWithLoc, orderWithoutLoc];
      final located = orders.where((o) => o.hasSavedLocation && o.savedLocation != null).toList();
      final unlocated = orders.where((o) => !o.hasSavedLocation || o.savedLocation == null).toList();

      expect(located.length, 1);
      expect(located.first.orderCode, 'ORD-01');
      expect(unlocated.length, 1);
      expect(unlocated.first.orderCode, 'ORD-02');
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
  });
}
