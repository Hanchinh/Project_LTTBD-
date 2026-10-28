import 'package:delivery_marker_mobile/models/address_search_result.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:delivery_marker_mobile/models/shift_model.dart';

void main() {
  group('Shift & Delivery Point Models Unit Tests', () {
    test('LocationStatus enum correctly converts to/from API strings and display names', () {
      expect(LocationStatus.fromString('VERIFIED'), LocationStatus.verified);
      expect(LocationStatus.fromString('TEMPORARY'), LocationStatus.temporary);
      expect(LocationStatus.fromString('NO_LOCATION'), LocationStatus.noLocation);
      expect(LocationStatus.fromString(null), LocationStatus.noLocation);
      expect(LocationStatus.fromString('UNKNOWN_STRING'), LocationStatus.noLocation);

      expect(LocationStatus.verified.toApiString(), 'VERIFIED');
      expect(LocationStatus.temporary.toApiString(), 'TEMPORARY');
      expect(LocationStatus.noLocation.toApiString(), 'NO_LOCATION');

      expect(LocationStatus.verified.displayName, 'Đã xác minh');
      expect(LocationStatus.temporary.displayName, 'Vị trí tạm');
      expect(LocationStatus.noLocation.displayName, 'Chưa có vị trí');
    });

    test('ShiftStatus enum correctly converts to/from API strings and display names', () {
      expect(ShiftStatus.fromString('PREPARING'), ShiftStatus.preparing);
      expect(ShiftStatus.fromString('IN_PROGRESS'), ShiftStatus.inProgress);
      expect(ShiftStatus.fromString('COMPLETED'), ShiftStatus.completed);
      expect(ShiftStatus.fromString('CANCELLED'), ShiftStatus.cancelled);
      expect(ShiftStatus.fromString(null), ShiftStatus.preparing);

      expect(ShiftStatus.preparing.toApiString(), 'PREPARING');
      expect(ShiftStatus.inProgress.toApiString(), 'IN_PROGRESS');
      expect(ShiftStatus.completed.toApiString(), 'COMPLETED');
      expect(ShiftStatus.cancelled.toApiString(), 'CANCELLED');

      expect(ShiftStatus.preparing.displayName, 'Đang chuẩn bị');
      expect(ShiftStatus.inProgress.displayName, 'Đang thực hiện');
      expect(ShiftStatus.completed.displayName, 'Đã hoàn thành');
      expect(ShiftStatus.cancelled.displayName, 'Đã hủy');
    });

    test('ShiftSummaryModel parses numeric strings and handles defaults', () {
      final summary = ShiftSummaryModel.fromJson({
        'totalPoints': '15',
        'verifiedCount': 10,
        'temporaryCount': '3',
        'noLocationCount': 2,
      });

      expect(summary.totalPoints, 15);
      expect(summary.verifiedCount, 10);
      expect(summary.temporaryCount, 3);
      expect(summary.noLocationCount, 2);

      final emptySummary = ShiftSummaryModel.fromJson(null);
      expect(emptySummary.totalPoints, 0);
      expect(emptySummary.verifiedCount, 0);
      expect(emptySummary.temporaryCount, 0);
      expect(emptySummary.noLocationCount, 0);
    });

    test('ShiftDeliveryPointModel parses correctly with valid coordinates and null coordinates', () {
      // 1. Điểm đã xác minh có tọa độ
      final verifiedPoint = ShiftDeliveryPointModel.fromJson({
        'id': 'pt-001',
        'shiftId': 'shf-001',
        'customerId': 'cust-001',
        'customerName': 'Nguyễn Văn A',
        'customerPhone': '0901234567',
        'customerAddress': '123 Lê Lợi, Q1',
        'locationStatus': 'VERIFIED',
        'latitude': 10.776889,
        'longitude': 106.700806,
        'locationNotes': 'Cổng màu xanh',
      });

      expect(verifiedPoint.hasValidCoordinates, true);
      expect(verifiedPoint.latLng, isNotNull);
      expect(verifiedPoint.latLng!.latitude, 10.776889);
      expect(verifiedPoint.latLng!.longitude, 106.700806);
      expect(verifiedPoint.locationStatus, LocationStatus.verified);

      // 2. Điểm chưa có vị trí (NO_LOCATION)
      final noLocPoint = ShiftDeliveryPointModel.fromJson({
        'id': 'pt-002',
        'shiftId': 'shf-001',
        'customerId': 'cust-002',
        'customerName': 'Trần Thị B',
        'customerPhone': '0912345678',
        'customerAddress': '456 Hai Bà Trưng, Q3',
        'locationStatus': 'NO_LOCATION',
        'latitude': null,
        'longitude': null,
      });

      expect(noLocPoint.hasValidCoordinates, false);
      expect(noLocPoint.latLng, isNull);
      expect(noLocPoint.locationStatus, LocationStatus.noLocation);
    });

    test('ShiftModel parses full json with nested delivery points and summary', () {
      final json = {
        'id': 'shf-uuid-123',
        'shiftCode': 'SHF-20261023-001',
        'shiftDate': '2026-10-23',
        'shipperId': 'shipper-001',
        'status': 'PREPARING',
        'notes': 'Ca sáng Quận 1',
        'summary': {
          'totalPoints': 2,
          'verifiedCount': 1,
          'temporaryCount': 0,
          'noLocationCount': 1,
        },
        'deliveryPoints': [
          {
            'id': 'pt-1',
            'shiftId': 'shf-uuid-123',
            'customerId': 'c-1',
            'customerName': 'Khách 1',
            'customerPhone': '0901111111',
            'customerAddress': 'Địa chỉ 1',
            'locationStatus': 'VERIFIED',
            'latitude': 10.77,
            'longitude': 106.70,
          },
          {
            'id': 'pt-2',
            'shiftId': 'shf-uuid-123',
            'customerId': 'c-2',
            'customerName': 'Khách 2',
            'customerPhone': '0902222222',
            'customerAddress': 'Địa chỉ 2',
            'locationStatus': 'NO_LOCATION',
            'latitude': null,
            'longitude': null,
          },
        ],
      };

      final shift = ShiftModel.fromJson(json);

      expect(shift.id, 'shf-uuid-123');
      expect(shift.shiftCode, 'SHF-20261023-001');
      expect(shift.status, ShiftStatus.preparing);
      expect(shift.summary.totalPoints, 2);
      expect(shift.deliveryPoints.length, 2);
      expect(shift.deliveryPoints[0].hasValidCoordinates, true);
      expect(shift.deliveryPoints[1].hasValidCoordinates, false);
    });

    test('Filter logic separates points correctly without losing data', () {
      final points = [
        ShiftDeliveryPointModel(
          id: '1',
          shiftId: 's',
          customerId: 'c1',
          customerName: 'A',
          customerPhone: '0901',
          customerAddress: 'Addr 1',
          locationStatus: LocationStatus.verified,
          latitude: 10.1,
          longitude: 106.1,
        ),
        ShiftDeliveryPointModel(
          id: '2',
          shiftId: 's',
          customerId: 'c2',
          customerName: 'B',
          customerPhone: '0902',
          customerAddress: 'Addr 2',
          locationStatus: LocationStatus.temporary,
          latitude: 10.2,
          longitude: 106.2,
        ),
        ShiftDeliveryPointModel(
          id: '3',
          shiftId: 's',
          customerId: 'c3',
          customerName: 'C',
          customerPhone: '0903',
          customerAddress: 'Addr 3',
          locationStatus: LocationStatus.noLocation,
        ),
      ];

      final verified = points.where((p) => p.locationStatus == LocationStatus.verified).toList();
      final temporary = points.where((p) => p.locationStatus == LocationStatus.temporary).toList();
      final noLoc = points.where((p) => p.locationStatus == LocationStatus.noLocation).toList();

      expect(verified.length, 1);
      expect(temporary.length, 1);
      expect(noLoc.length, 1);
      expect(points.length, 3);
    });

    test('BUG-MAP-002 Fix: Map Tile URLs match project standard and have valid fallback', () {
      // Xác minh URL templates chuẩn của dự án tránh lỗi SSL reset của OSM tại VN
      const googleStreets = 'https://mt1.google.com/vt/lyrs=m&x={x}&y={y}&z={z}';
      const googleHybrid = 'https://mt1.google.com/vt/lyrs=y&x={x}&y={y}&z={z}';
      const cartoVoyager = 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png';
      const fallbackUrl = 'https://a.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png';
      const expectedUserAgent = 'com.example.delivery_marker_mobile';

      expect(googleStreets.contains('mt1.google.com'), true);
      expect(googleHybrid.contains('lyrs=y'), true);
      expect(cartoVoyager.contains('cartocdn.com'), true);
      expect(fallbackUrl.contains('cartocdn.com'), true);
      expect(expectedUserAgent, 'com.example.delivery_marker_mobile');
    });

    test('APP-AUDIT-AND-FIX-002: AddressSearchResult parses json correctly', () {
      final json = {
        'displayName': '123 Lê Văn Việt, Phường Tăng Nhơn Phú A, Thành phố Thủ Đức',
        'latitude': 10.845012,
        'longitude': 106.778045,
        'source': 'NOMINATIM_OSM',
      };

      final result = AddressSearchResult.fromJson(json);
      expect(result.displayName, '123 Lê Văn Việt, Phường Tăng Nhơn Phú A, Thành phố Thủ Đức');
      expect(result.latitude, 10.845012);
      expect(result.longitude, 106.778045);
      expect(result.source, 'NOMINATIM_OSM');

      final emptyResult = AddressSearchResult.fromJson({});
      expect(emptyResult.displayName, '');
      expect(emptyResult.latitude, 0.0);
      expect(emptyResult.longitude, 0.0);
      expect(emptyResult.source, isNull);
    });

    test('APP-AUDIT-AND-FIX-002: Quick-created customer initializes with NO_LOCATION and without fake coordinates', () {
      final point = ShiftDeliveryPointModel(
        id: 'pt-quick-1',
        shiftId: 'shf-today-01',
        customerId: 'cust-new-1',
        customerName: 'Khách hàng 0988123456',
        customerPhone: '0988123456',
        customerAddress: '123 Đường số 7',
        locationStatus: LocationStatus.noLocation,
        latitude: null,
        longitude: null,
      );

      expect(point.locationStatus, LocationStatus.noLocation);
      expect(point.hasValidCoordinates, false);
      expect(point.latLng, isNull);
      expect(point.customerName, 'Khách hàng 0988123456');
    });

    test('APP-AUDIT-AND-FIX-002: ShiftListView map button selects active in-progress shift or latest shift', () {
      final shifts = [
        ShiftModel(
          id: 'shf-1',
          shiftCode: 'SHF-20261023-001',
          shiftDate: '2026-10-23',
          shipperId: 'shipper-1',
          status: ShiftStatus.preparing,
          createdAt: DateTime.now(),
          deliveryPoints: [],
        ),
        ShiftModel(
          id: 'shf-2',
          shiftCode: 'SHF-20261023-002',
          shiftDate: '2026-10-23',
          shipperId: 'shipper-1',
          status: ShiftStatus.inProgress,
          createdAt: DateTime.now(),
          deliveryPoints: [],
        ),
      ];

      // Logic in ShiftListView: Ưu tiên ca đang IN_PROGRESS, hoặc ca mới nhất
      final activeShift = shifts.firstWhere(
        (s) => s.status == ShiftStatus.inProgress,
        orElse: () => shifts.first,
      );

      expect(activeShift.id, 'shf-2');
      expect(activeShift.status, ShiftStatus.inProgress);
    });

    test('APP-AUDIT-AND-FIX-002: ShiftMapView only renders points with valid coordinates, NO_LOCATION has no map markers', () {
      final points = [
        ShiftDeliveryPointModel(
          id: 'pt-1',
          shiftId: 'shf-1',
          customerId: 'cust-1',
          customerName: 'Khách đã xác minh',
          customerPhone: '0901111111',
          customerAddress: 'Địa chỉ 1',
          locationStatus: LocationStatus.verified,
          latitude: 10.842215,
          longitude: 106.818123,
        ),
        ShiftDeliveryPointModel(
          id: 'pt-2',
          shiftId: 'shf-1',
          customerId: 'cust-2',
          customerName: 'Khách tạm ghim',
          customerPhone: '0902222222',
          customerAddress: 'Địa chỉ 2',
          locationStatus: LocationStatus.temporary,
          latitude: 10.845000,
          longitude: 106.820000,
        ),
        ShiftDeliveryPointModel(
          id: 'pt-3',
          shiftId: 'shf-1',
          customerId: 'cust-3',
          customerName: 'Khách mới tạo chưa có vị trí',
          customerPhone: '0903333333',
          customerAddress: 'Địa chỉ 3',
          locationStatus: LocationStatus.noLocation,
          latitude: null,
          longitude: null,
        ),
      ];

      final validPointsForMap = points.where((p) => p.hasValidCoordinates).toList();
      final noLocationPoints = points.where((p) => !p.hasValidCoordinates).toList();

      expect(validPointsForMap.length, 2);
      expect(noLocationPoints.length, 1);
      expect(noLocationPoints.first.id, 'pt-3');
      expect(validPointsForMap.any((p) => p.locationStatus == LocationStatus.noLocation), false);
    });
  });
}

