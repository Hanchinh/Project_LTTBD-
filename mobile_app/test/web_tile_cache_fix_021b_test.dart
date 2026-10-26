import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:delivery_marker_mobile/services/map_tile_cache_service.dart';
import 'package:delivery_marker_mobile/views/main_map_view.dart';
import 'package:delivery_marker_mobile/views/shift_map_view.dart';
import 'package:delivery_marker_mobile/views/crosshair_location_picker_view.dart';
import 'package:delivery_marker_mobile/models/shift_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TASK: WEB-TILE-CACHE-FIX-021B - Cross-Platform Tile Provider Tests', () {
    test('1. createPlatformTileProvider trả về đúng Provider theo nền tảng', () {
      final provider = createPlatformTileProvider();
      if (kIsWeb) {
        expect(provider, isA<NetworkTileProvider>());
      } else {
        expect(provider, isA<CancellableDiskCachedTileProvider>());
      }
    });

    test('2. Quy tắc lọc URL bản đồ và chống cache ảnh khách hàng giữ nguyên 100%', () {
      // Tile URLs hợp lệ
      expect(MapTileCacheService.isMapTileUrl('https://tile.openstreetmap.org/10/100/200.png'), isTrue);
      expect(MapTileCacheService.isMapTileUrl('https://mt0.google.com/vt/lyrs=m&x=1&y=2&z=3'), isTrue);
      expect(MapTileCacheService.isMapTileUrl('https://a.basemaps.cartocdn.com/rastertiles/voyager/1/2/3.png'), isTrue);

      // Chặn ảnh khách hàng tuyệt đối
      expect(MapTileCacheService.isMapTileUrl('https://api.vn/photos/house_front.jpg'), isFalse);
      expect(MapTileCacheService.isMapTileUrl('https://api.vn/uploads/gate_photo.png'), isFalse);
      expect(MapTileCacheService.isMapTileUrl('https://api.vn/customer/photo_123.jpg'), isFalse);
      expect(MapTileCacheService.isMapTileUrl('https://api.vn/avatar/user.png'), isFalse);
      expect(MapTileCacheService.isMapTileUrl('https://api.vn/profile/img.jpg'), isFalse);

      expect(MapTileCacheService.containsCustomerPhoto('https://api.vn/uploads/house.jpg'), isTrue);
      expect(MapTileCacheService.containsCustomerPhoto('https://tile.openstreetmap.org/1/2/3.png'), isFalse);
    });

    test('3. CancellableDiskCachedTileProvider có phòng vệ đa tầng cho Web', () {
      final provider = CancellableDiskCachedTileProvider(
        headers: {'User-Agent': 'TestClient'},
      );

      const coordinates = TileCoordinates(1, 2, 3);
      final options = TileLayer(
        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      );

      final imageProvider = provider.getImage(coordinates, options);
      expect(imageProvider, isNotNull);
      // Trên VM native (test runner), trả về FileImage hoặc CancellableTileImageProvider
      if (kIsWeb) {
        expect(imageProvider, isA<NetworkImage>());
      } else {
        expect(
          imageProvider is CancellableTileImageProvider || imageProvider is FileImage,
          isTrue,
        );
      }
    });

    testWidgets('4. MainMapView khởi tạo và sử dụng TileProvider an toàn đa nền tảng', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MainMapView(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // FlutterMap và TileLayer render thành công
      final flutterMap = find.byType(FlutterMap);
      expect(flutterMap, findsOneWidget);
    });

    testWidgets('5. ShiftMapView khởi tạo và sử dụng TileProvider an toàn đa nền tảng', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ShiftMapView(
              shiftId: 'shift-mock-021b',
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(ShiftMapView), findsOneWidget);
    });

    testWidgets('6. CrosshairLocationPickerView khởi tạo và sử dụng TileProvider an toàn đa nền tảng', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));

      final testPoint = ShiftDeliveryPointModel(
        id: 'point-test-1',
        shiftId: 'shift-1',
        customerId: 'cust-1',
        customerName: 'Anh Hùng',
        customerPhone: '0912345678',
        customerAddress: '123 Lê Duẩn, Q.1',
        locationStatus: LocationStatus.temporary,
        latitude: 10.78,
        longitude: 106.70,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: CrosshairLocationPickerView(
            point: testPoint,
            shiftId: 'shift-1',
            initialCenter: const LatLng(10.78, 106.70),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(FlutterMap), findsOneWidget);
    });
  });
}
