import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:delivery_marker_mobile/models/customer_photo_model.dart';
import 'package:delivery_marker_mobile/core/widgets/point_detail_bottom_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TASK: MULTI-PHOTO-AND-THUMB-UI-015A Widget Tests', () {
    testWidgets('1. Thẻ điểm luôn có khu vực ảnh kể cả 0 ảnh, kích thước nút >= 56px, nút Thêm ảnh hiện đủ', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PointDetailBottomSheet(
              customerId: 'c0000000-0000-0000-0000-000000000001',
              customerName: 'Anh Hoàng (Tạp hóa Hai Thu)',
              customerPhone: '0988000001',
              customerAddress: 'Hẻm 124 Nguyễn Xiển, P. Long Thạnh Mỹ',
              locationStatusText: 'ĐÃ XÁC NHẬN',
              initialPhotos: [], // 0 ảnh
            ),
          ),
        ),
      );
      await tester.pump();

      // 1.1 Khu vực ảnh LUÔN hiện diện (kể cả 0 ảnh)
      expect(find.byKey(const ValueKey('point_detail_photo_area')), findsOneWidget);
      expect(find.byKey(const ValueKey('empty_photo_slot')), findsOneWidget);
      expect(find.text('Chưa có ảnh - Thêm ảnh'), findsOneWidget);

      // 1.2 Nút "+ Thêm ảnh" hiện đủ
      final addPhotoFinder = find.byKey(const ValueKey('btn_add_photo'));
      expect(addPhotoFinder, findsOneWidget);
      expect(find.text('+ THÊM ẢNH'), findsOneWidget);

      // 1.3 Kích thước nút Thêm ảnh >= 56px
      final addPhotoSize = tester.getSize(addPhotoFinder);
      expect(addPhotoSize.height, greaterThanOrEqualTo(56.0));

      // 1.4 Hàng 3 nút: GỌI | CHỈ ĐƯỜNG | GHIM LẠI
      final callBtnFinder = find.byKey(const ValueKey('btn_call'));
      final dirBtnFinder = find.byKey(const ValueKey('btn_directions'));
      final repinBtnFinder = find.byKey(const ValueKey('btn_repin'));

      expect(callBtnFinder, findsOneWidget);
      expect(dirBtnFinder, findsOneWidget);
      expect(repinBtnFinder, findsOneWidget);

      // 1.5 Cỡ chạm tối thiểu >= 56px
      final callSize = tester.getSize(callBtnFinder);
      final dirSize = tester.getSize(dirBtnFinder);
      final repinSize = tester.getSize(repinBtnFinder);

      expect(callSize.height, greaterThanOrEqualTo(56.0));
      expect(dirSize.height, greaterThanOrEqualTo(56.0));
      expect(repinSize.height, greaterThanOrEqualTo(56.0));

      // 1.6 Khoảng cách giữa các nút >= 12px
      final callRect = tester.getRect(callBtnFinder);
      final dirRect = tester.getRect(dirBtnFinder);
      final repinRect = tester.getRect(repinBtnFinder);

      expect(dirRect.left - callRect.right, greaterThanOrEqualTo(12.0));
      expect(repinRect.left - dirRect.right, greaterThanOrEqualTo(12.0));

      // 1.7 Cỡ chữ >= 16sp
      final callText = tester.widget<Text>(find.text('GỌI'));
      expect(callText.style?.fontSize, greaterThanOrEqualTo(16.0));

      final dirText = tester.widget<Text>(find.text('CHỈ ĐƯỜNG'));
      expect(dirText.style?.fontSize, greaterThanOrEqualTo(16.0));

      final repinText = tester.widget<Text>(find.text('GHIM LẠI'));
      expect(repinText.style?.fontSize, greaterThanOrEqualTo(16.0));
    });

    testWidgets('2. Thẻ điểm với nhiều ảnh: dải ảnh cuộn ngang, hiện số thứ tự, nút bấm kích hoạt callback', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));

      bool callTriggered = false;
      bool dirTriggered = false;
      bool repinTriggered = false;

      final testPhotos = [
        CustomerPhotoModel(
          id: 'photo-1',
          customerId: 'c0000000-0000-0000-0000-000000000001',
          imageUrl: '/api/v1/photos/sample-1.jpg',
        ),
        CustomerPhotoModel(
          id: 'photo-2',
          customerId: 'c0000000-0000-0000-0000-000000000001',
          imageUrl: '/api/v1/photos/sample-2.jpg',
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PointDetailBottomSheet(
              customerId: 'c0000000-0000-0000-0000-000000000001',
              customerName: 'Chị Lan (Sữa đá chân cầu)',
              customerPhone: '0988000002',
              customerAddress: 'Đường Phước Thiện',
              locationStatusText: 'VỊ TRÍ TẠM',
              initialPhotos: testPhotos,
              onCall: () => callTriggered = true,
              onDirections: () => dirTriggered = true,
              onRepin: () => repinTriggered = true,
            ),
          ),
        ),
      );
      await tester.pump();

      // Dải ảnh có mặt, nút "+ THÊM ẢNH" luôn có mặt
      expect(find.byKey(const ValueKey('point_detail_photo_area')), findsOneWidget);
      expect(find.byKey(const ValueKey('btn_add_photo')), findsOneWidget);
      expect(find.text('1/2'), findsOneWidget);

      // Thử bấm các nút thao tác
      await tester.tap(find.byKey(const ValueKey('btn_call')));
      expect(callTriggered, isTrue);

      await tester.tap(find.byKey(const ValueKey('btn_directions')));
      expect(dirTriggered, isTrue);

      await tester.tap(find.byKey(const ValueKey('btn_repin')));
      expect(repinTriggered, isTrue);
    });
  });
}
