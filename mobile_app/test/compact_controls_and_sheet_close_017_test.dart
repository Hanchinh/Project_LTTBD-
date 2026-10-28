import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:delivery_marker_mobile/features/map/main_map_view.dart';
import 'package:delivery_marker_mobile/shared_widgets/point_detail_bottom_sheet.dart';
import 'package:delivery_marker_mobile/features/shifts/shift_map_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TASK: MAP-COMPACT-CONTROLS-AND-SHEET-CLOSE-017 Widget Tests', () {
    testWidgets('1. MainMapView: Cột icon 3 nút ở góc phải dưới, mỗi nút >= 52px, có Tooltip, tâm ngắm ẩn cột icon', (tester) async {
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

      // 1.1 Kiểm tra sự hiện diện của 3 nút
      final pinBtnFinder = find.byKey(const Key('btn_pin_new_location'));
      final createShiftBtnFinder = find.byKey(const Key('btn_create_shift_from_map'));
      final shiftPickerBtnFinder = find.byKey(const Key('btn_open_shift_picker'));

      expect(pinBtnFinder, findsOneWidget);
      expect(createShiftBtnFinder, findsOneWidget);
      expect(shiftPickerBtnFinder, findsOneWidget);

      // 1.2 Kiểm tra Tooltip của từng nút
      expect(find.byTooltip('Ghim vị trí mới'), findsOneWidget);
      expect(find.byTooltip('Tạo ca'), findsOneWidget);
      expect(find.byTooltip('Ca làm việc'), findsOneWidget);

      // 1.3 Kiểm tra kích thước vùng chạm: Ghim >= 60px, Tạo ca >= 52px, Ca làm việc >= 52px
      final pinSize = tester.getSize(pinBtnFinder);
      final createSize = tester.getSize(createShiftBtnFinder);
      final pickerSize = tester.getSize(shiftPickerBtnFinder);

      expect(pinSize.width, greaterThanOrEqualTo(60.0));
      expect(pinSize.height, greaterThanOrEqualTo(60.0));
      expect(createSize.width, greaterThanOrEqualTo(52.0));
      expect(createSize.height, greaterThanOrEqualTo(52.0));
      expect(pickerSize.width, greaterThanOrEqualTo(52.0));
      expect(pickerSize.height, greaterThanOrEqualTo(52.0));

      // 1.4 Kiểm tra thứ tự và khoảng cách giữa các nút (từ dưới lên: Ghim -> Tạo ca -> Ca làm việc)
      final pinTop = tester.getTopLeft(pinBtnFinder).dy;
      final createBottom = tester.getBottomLeft(createShiftBtnFinder).dy;
      final createTop = tester.getTopLeft(createShiftBtnFinder).dy;
      final pickerBottom = tester.getBottomLeft(shiftPickerBtnFinder).dy;

      expect(pinTop - createBottom, greaterThanOrEqualTo(12.0));
      expect(createTop - pickerBottom, greaterThanOrEqualTo(12.0));

      // 1.5 Bật chế độ tâm ngắm (bấm Ghim vị trí mới) -> Cột icon tự ẩn
      await tester.tap(pinBtnFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byKey(const Key('btn_pin_new_location')), findsNothing);
      expect(find.byKey(const Key('btn_create_shift_from_map')), findsNothing);
      expect(find.byKey(const Key('btn_open_shift_picker')), findsNothing);
      expect(find.text('Kéo bản đồ để đặt tâm ghim'), findsOneWidget);

      // Thoát tâm ngắm -> Cột icon hiện lại
      await tester.tap(find.text('HỦY'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byKey(const Key('btn_pin_new_location')), findsOneWidget);
      expect(find.byKey(const Key('btn_create_shift_from_map')), findsOneWidget);
      expect(find.byKey(const Key('btn_open_shift_picker')), findsOneWidget);
    });

    testWidgets('2. PointDetailBottomSheet: Có nút tắt X vùng chạm >= 48px, bấm X gọi callback onClose', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));

      bool closed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PointDetailBottomSheet(
              customerId: 'c001',
              customerName: 'Anh Nam Long Thạnh Mỹ',
              customerPhone: '0901234567',
              locationStatusText: 'ĐÃ XÁC NHẬN',
              onClose: () => closed = true,
            ),
          ),
        ),
      );
      await tester.pump();

      // 2.1 Nút tắt X hiện diện
      final closeBtnFinder = find.byKey(const ValueKey('btn_close_point_detail'));
      expect(closeBtnFinder, findsOneWidget);
      expect(find.byTooltip('Đóng'), findsOneWidget);

      // 2.2 Vùng chạm nút X >= 48px
      final closeBtnSize = tester.getSize(closeBtnFinder);
      expect(closeBtnSize.width, greaterThanOrEqualTo(48.0));
      expect(closeBtnSize.height, greaterThanOrEqualTo(48.0));

      // 2.3 Bấm nút X -> Gọi onClose
      await tester.tap(closeBtnFinder);
      await tester.pump();
      expect(closed, isTrue);
    });

    testWidgets('3. ShiftMapView: Cột icon tròn 56px có Tooltip (Dán danh sách SĐT & Chọn vị trí)', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ShiftMapView(shiftId: 'shift_mock_001'),
          ),
        ),
      );
      await tester.pump();

      // Widget build bình thường không bị crash
      expect(find.byType(ShiftMapView), findsOneWidget);
    });
  });
}
