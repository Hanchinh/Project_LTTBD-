import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:delivery_marker_mobile/main.dart';
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
