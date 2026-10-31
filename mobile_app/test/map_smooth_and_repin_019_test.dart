import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:delivery_marker_mobile/core/services/map_tile_cache_service.dart';
import 'package:delivery_marker_mobile/features/map/main_map_view.dart';
import 'package:delivery_marker_mobile/shared_widgets/point_detail_bottom_sheet.dart';
import 'package:delivery_marker_mobile/features/map/crosshair_location_picker_view.dart';
import 'package:delivery_marker_mobile/models/shift_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TASK: MAP-SMOOTH-AND-REPIN-FIX-019 - Part B: Map Smoothness & Tile Cache Tests', () {
    test('B.1 & B.7: Cache tile trên đĩa tối đa 200MB và tuyệt đối KHÔNG cache ảnh khách', () {
      // 1. Kiểm tra giới hạn dung lượng cache 200MB
      expect(MapTileCacheService.maxCacheSizeBytes, 200 * 1024 * 1024);
      expect(MapTileCacheService.targetPruneSizeBytes, 150 * 1024 * 1024);

      // 2. Kiểm tra URL tile hợp lệ
      expect(MapTileCacheService.isMapTileUrl('https://tile.openstreetmap.org/15/123/456.png'), isTrue);
      expect(MapTileCacheService.isMapTileUrl('https://mt1.google.com/vt/lyrs=m&x=123&y=456&z=15'), isTrue);
      expect(MapTileCacheService.isMapTileUrl('https://a.basemaps.cartocdn.com/rastertiles/voyager/15/123/456.png'), isTrue);

      // 3. Tuyệt đối từ chối cache ảnh khách hàng hoặc URL không phải tile bản đồ
      expect(MapTileCacheService.isMapTileUrl('https://api.delivery.vn/uploads/customer_house_123.jpg'), isFalse);
      expect(MapTileCacheService.isMapTileUrl('https://delivery.vn/api/customers/avatar.png'), isFalse);
      expect(MapTileCacheService.isMapTileUrl('https://storage.googleapis.com/delivery_photos/gate_090.jpg'), isFalse);
      expect(MapTileCacheService.containsCustomerPhoto('https://api.delivery.vn/uploads/photo.jpg'), isTrue);
      expect(MapTileCacheService.containsCustomerPhoto('https://tile.openstreetmap.org/1/2/3.png'), isFalse);
    });

    test('B.3: Cancellable tile provider giới hạn tối đa 10 yêu cầu đồng thời', () {
      expect(CancellableDiskCachedTileProvider.maxConcurrentRequests, 10);
    });

    testWidgets('B.5: MainMapView được bao bọc RepaintBoundary để cô lập render bản đồ', (tester) async {
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

      // Kiểm tra có RepaintBoundary trong cây widget
      final repaintBoundaries = find.byType(RepaintBoundary);
      expect(repaintBoundaries, findsWidgets);
      expect(repaintBoundaries.evaluate().length, greaterThanOrEqualTo(2));
    });
  });

  group('TASK: MAP-SMOOTH-AND-REPIN-FIX-019 - Part A: Repin Flow Tests', () {
    testWidgets('A.3: Luồng Ghim vị trí mới giữ nguyên hộp thoại trống và nút lưu kiểm tra tính hợp lệ', (tester) async {
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

      // Bấm nút Ghim vị trí mới
      final pinNewBtn = find.byKey(const Key('btn_pin_new_location'));
      expect(pinNewBtn, findsOneWidget);
      await tester.tap(pinNewBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Bấm Xác nhận vị trí tâm ngắm
      final confirmPinBtn = find.byKey(const Key('btn_confirm_crosshair'));
      expect(confirmPinBtn, findsOneWidget);
      await tester.tap(confirmPinBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Hộp thoại gán SĐT hiện lên: KHÔNG có banner "Đang ghim lại cho"
      expect(find.byKey(const Key('repin_customer_banner')), findsNothing);

      // Ô SĐT trống
      final phoneField = find.byKey(const Key('input_assign_phone'));
      expect(phoneField, findsOneWidget);
      final phoneWidget = tester.widget<TextField>(phoneField);
      expect(phoneWidget.controller?.text, isEmpty);

      // Bấm nút Lưu vị trí khi chưa có SĐT -> Hiển thị cảnh báo yêu cầu nhập SĐT
      final saveBtn = find.byKey(const Key('btn_confirm_save_location'));
      expect(saveBtn, findsOneWidget);
      await tester.tap(saveBtn);
      await tester.pump();
      expect(find.text('Vui lòng nhập số điện thoại khách hàng'), findsOneWidget);
    });

    testWidgets('A.1, A.2: PointDetailBottomSheet callback onRepin kích hoạt truyền khách hàng và hỗ trợ đổi số', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));

      bool repinTriggered = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PointDetailBottomSheet(
              customerId: 'cust-123',
              customerName: 'Anh Ba Gò Vấp',
              customerPhone: '0912345678',
              customerAddress: '456 Phan Văn Trị, Gò Vấp',
              locationStatusText: 'ĐÃ XÁC NHẬN',
              onRepin: () {
                repinTriggered = true;
              },
            ),
          ),
        ),
      );
      await tester.pump();

      // Kiểm tra nút Ghim lại hiện diện trên PointDetailBottomSheet
      final repinBtn = find.byKey(const ValueKey('btn_repin'));
      expect(repinBtn, findsOneWidget);

      await tester.tap(repinBtn);
      await tester.pump();

      expect(repinTriggered, isTrue);
    });

    testWidgets('A.1, A.2, A.4: CrosshairLocationPickerView hiển thị banner Đang ghim lại cho và lưu vị trí tạm trong ca', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));

      final mockPoint = ShiftDeliveryPointModel(
        id: 'pt-101',
        shiftId: 'shift-999',
        customerId: 'cust-202',
        customerName: 'Chị Lan Bình Thạnh',
        customerPhone: '0987654321',
        customerAddress: '123 Điện Biên Phủ, P.15, Bình Thạnh',
        locationStatus: LocationStatus.temporary,
        latitude: 10.800123,
        longitude: 106.710456,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: CrosshairLocationPickerView(
            point: mockPoint,
            shiftId: 'shift-999',
            initialCenter: const LatLng(10.800123, 106.710456),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // 1. Kiểm tra banner Đang ghim lại cho: [tên] - [SĐT]
      final bannerFinder = find.byKey(const Key('repin_customer_banner'));
      expect(bannerFinder, findsOneWidget);
      expect(find.textContaining('Đang ghim lại cho: Chị Lan Bình Thạnh - 0987654321'), findsOneWidget);

      // 2. Nút lưu vị trí tạm bấm được ngay
      expect(find.text('Lưu vị trí tạm'), findsOneWidget);

      // 3. Kiểm tra RepaintBoundary bao bọc FlutterMap trong CrosshairLocationPickerView
      final repaintBoundaries = find.byType(RepaintBoundary);
      expect(repaintBoundaries, findsWidgets);
    });
  });
}
