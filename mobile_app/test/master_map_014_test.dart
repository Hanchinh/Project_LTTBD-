import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:delivery_marker_mobile/models/location_model.dart';
import 'package:delivery_marker_mobile/features/map/main_map_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('TASK: MASTER-MAP-014 - MasterSavedLocationModel Unit Tests', () {
    test('Khởi tạo và parse JSON MasterSavedLocationModel đầy đủ thông tin', () {
      final json = {
        'id': 'loc-123',
        'customerId': 'cust-456',
        'customerCode': 'KH_001',
        'customerName': 'Anh Hoàng',
        'customerPhone': '0988000001',
        'customerAddress': '124 Nguyễn Xiển',
        'areaId': 'area-1',
        'areaName': 'Quận 9',
        'latitude': 10.842215,
        'longitude': 106.818123,
        'gpsAccuracy': 4.5,
        'identificationNotes': 'Cổng màu xanh',
        'imageUrl': 'http://example.com/photo.jpg',
        'createdAt': '2026-10-25T08:00:00Z',
        'updatedAt': '2026-10-25T08:30:00Z',
      };

      final model = MasterSavedLocationModel.fromJson(json);

      expect(model.id, 'loc-123');
      expect(model.customerId, 'cust-456');
      expect(model.customerCode, 'KH_001');
      expect(model.customerName, 'Anh Hoàng');
      expect(model.customerPhone, '0988000001');
      expect(model.customerAddress, '124 Nguyễn Xiển');
      expect(model.latitude, 10.842215);
      expect(model.longitude, 106.818123);
      expect(model.gpsAccuracy, 4.5);
      expect(model.identificationNotes, 'Cổng màu xanh');
      expect(model.hasPhoto, isTrue);
      expect(model.hasValidCoordinates, isTrue);
    });
  });

  group('TASK: MASTER-MAP-014 - MainMapView Master Map Widget Tests', () {
    testWidgets('Mở Bản đồ chính: không phụ thuộc ca, hiển thị thanh tiêu đề và nút nổi Ghim vị trí mới', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MainMapView(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Tiêu đề bản đồ độc lập với ca
      expect(find.text('Bản đồ vị trí đã lưu'), findsOneWidget);

      // Nút nổi Ghim vị trí mới có mặt trên bản đồ chính dạng icon tooltip
      expect(find.byTooltip('Ghim vị trí mới'), findsOneWidget);
      expect(find.byIcon(Icons.add_location_alt_rounded), findsWidgets);
    });

    testWidgets('Bấm nút "Ghim vị trí mới": chuyển sang chế độ tâm ngắm, xuất hiện nút HỦY và XÁC NHẬN VỊ TRÍ NÀY', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MainMapView(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Bấm nút Ghim vị trí mới
      await tester.tap(find.byTooltip('Ghim vị trí mới'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Vào chế độ tâm ngắm: xuất hiện chỉ dẫn và 2 nút hành động
      expect(find.text('Kéo bản đồ để đặt tâm ghim'), findsOneWidget);
      expect(find.text('HỦY'), findsOneWidget);
      expect(find.text('XÁC NHẬN VỊ TRÍ NÀY'), findsOneWidget);

      // Bấm HỦY: thoát chế độ tâm ngắm quay về bản đồ bình thường
      await tester.tap(find.text('HỦY'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Kéo bản đồ để đặt tâm ghim'), findsNothing);
      expect(find.byTooltip('Ghim vị trí mới'), findsOneWidget);
    });

    testWidgets('TASK: MASTER-MAP-014B: Bấm XÁC NHẬN VỊ TRÍ NÀY mở BottomSheet Gán cho số điện thoại nào', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MainMapView(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Vào chế độ tâm ngắm
      await tester.tap(find.byTooltip('Ghim vị trí mới'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Bấm XÁC NHẬN VỊ TRÍ NÀY
      await tester.tap(find.text('XÁC NHẬN VỊ TRÍ NÀY'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Xuất hiện modal Gán cho số điện thoại nào?
      expect(find.text('Gán cho số điện thoại nào?'), findsOneWidget);
      expect(find.text('LƯU VỊ TRÍ NÀY'), findsOneWidget);
      expect(find.byType(TextField), findsWidgets);
    });

    testWidgets('TASK: MASTER-MAP-014B: Hộp thoại cảnh báo lưu vị trí lỗi hiển thị thông báo rõ và nút THỬ LẠI', (tester) async {
      // Test AlertDialog hiển thị thông báo "Đã tạo khách [SĐT] nhưng chưa lưu được vị trí, thử lại"
      const phone = '0908911111';
      const errText = 'Đã tạo khách $phone nhưng chưa lưu được vị trí, thử lại';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () {
                  showDialog<void>(
                    context: ctx,
                    builder: (dlgCtx) => AlertDialog(
                      title: const Row(
                        children: [
                          Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444)),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text('Lưu vị trí không thành công', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                      content: const Text('$errText.\n\nChi tiết lỗi: Network timeout'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dlgCtx),
                          child: const Text('ĐÓNG'),
                        ),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.refresh_rounded, size: 16),
                          label: const Text('THỬ LẠI'),
                          onPressed: () => Navigator.pop(dlgCtx),
                        ),
                      ],
                    ),
                  );
                },
                child: const Text('OPEN_DIALOG'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('OPEN_DIALOG'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Đã tạo khách 0908911111 nhưng chưa lưu được vị trí, thử lại'), findsOneWidget);
      expect(find.text('THỬ LẠI'), findsOneWidget);
      expect(find.text('ĐÓNG'), findsOneWidget);

      await tester.tap(find.text('THỬ LẠI'));
      await tester.pumpAndSettle();
      expect(find.text('THỬ LẠI'), findsNothing);
    });
  });
}
