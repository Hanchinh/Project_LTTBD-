import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:delivery_marker_mobile/models/shift_model.dart';
import 'package:delivery_marker_mobile/widgets/create_shift_dialog.dart';
import 'package:delivery_marker_mobile/widgets/bulk_paste_phone_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TASK: SHIFT-FROM-MAP-AND-BULK-PASTE-015B Widget Tests', () {
    testWidgets('1. CreateShiftBottomSheet: ô nhập tên ca tự focus, nút TẠO CA chiều cao >= 56px', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CreateShiftBottomSheet(),
          ),
        ),
      );
      await tester.pump();

      // Tiêu đề
      expect(find.text('Tạo ca làm việc mới'), findsOneWidget);

      // Ô nhập tên ca
      final textFieldFinder = find.byType(TextField);
      expect(textFieldFinder, findsOneWidget);

      // Nút Tạo ca
      final createBtnFinder = find.byType(ElevatedButton);
      expect(createBtnFinder, findsOneWidget);
      expect(find.text('TẠO CA VÀ MỞ BẢN ĐỒ'), findsOneWidget);

      // Kích thước nút >= 56px
      final btnSize = tester.getSize(createBtnFinder);
      expect(btnSize.height, greaterThanOrEqualTo(56.0));
    });

    testWidgets('2. BulkPastePhoneSheet: nút dán bộ nhớ tạm, đếm số hợp lệ và cảnh báo số sai định dạng, nút Thêm vào ca >= 56px', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BulkPastePhoneSheet(
              shiftId: 's0000000-0000-0000-0000-000000000001',
              onPointsAdded: (_) {},
            ),
          ),
        ),
      );
      await tester.pump();

      // Nút Dán từ bộ nhớ tạm
      expect(find.text('DÁN TỪ BỘ NHỚ TẠM'), findsOneWidget);

      // Nhập danh sách hỗn hợp:
      // "0908 911 111, +84 908 911 111\n0988000001; 12345"
      // -> 0908911111 (trùng lặp deduplicate), 0988000001 -> 2 số hợp lệ
      // -> 12345 -> 1 số sai định dạng
      final textFieldFinder = find.byType(TextField);
      expect(textFieldFinder, findsOneWidget);

      await tester.enterText(textFieldFinder, '0908 911 111, +84 908 911 111\n0988000001; 12345');
      await tester.pump();

      // Kiểm tra preview badge
      expect(find.text('Hợp lệ: 2'), findsOneWidget);
      expect(find.text('Sai định dạng: 1'), findsOneWidget);

      // Nút "THÊM 2 ĐIỂM VÀO CA"
      final submitBtnFinder = find.widgetWithText(ElevatedButton, 'THÊM 2 ĐIỂM VÀO CA');
      expect(submitBtnFinder, findsOneWidget);

      // Kích thước nút >= 56px
      final btnSize = tester.getSize(submitBtnFinder);
      expect(btnSize.height, greaterThanOrEqualTo(56.0));
    });

    testWidgets('3. BulkPastePhoneSheet Kết quả: chia rõ 2 nhóm Đã có vị trí vs Chưa có vị trí, nút GHIM TÂM NGẮM >= 56px', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));

      ShiftDeliveryPointModel? pinnedPoint;

      final testResult = BulkAddPointsResult(
        added: [
          ShiftDeliveryPointModel(
            id: 'p1',
            shiftId: 's1',
            customerId: 'c1',
            customerName: 'Khách Đã Có Vị Trí',
            customerPhone: '0988000001',
            customerAddress: 'Địa chỉ 1',
            locationStatus: LocationStatus.verified,
            latitude: 10.842215,
            longitude: 106.818123,
          ),
          ShiftDeliveryPointModel(
            id: 'p2',
            shiftId: 's1',
            customerId: 'c2',
            customerName: 'Khách Chưa Có Vị Trí',
            customerPhone: '0988000002',
            customerAddress: 'Địa chỉ 2',
            locationStatus: LocationStatus.noLocation,
          ),
        ],
        alreadyInShift: [],
        rejected: [
          RejectedPhoneItem(phone: '0988000004', reason: 'OUT_OF_AREA', message: 'Ngoài khu vực'),
        ],
        summary: BulkAddSummary(total: 3, addedCount: 2, alreadyInShiftCount: 0, rejectedCount: 1),
      );

      // Render BulkPastePhoneSheet với initialResult
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BulkPastePhoneSheet(
              shiftId: 's1',
              initialResult: testResult,
              onPointsAdded: (_) {},
              onPinPointRequested: (pt) {
                pinnedPoint = pt;
              },
            ),
          ),
        ),
      );
      await tester.pump();

      // Kiểm tra 2 nhóm kết quả hiển thị rõ ràng
      expect(find.text('ĐÃ CÓ VỊ TRÍ (1)'), findsOneWidget);
      expect(find.text('Khách Đã Có Vị Trí'), findsOneWidget);
      expect(find.text('ĐÃ CÓ TỌA ĐỘ'), findsOneWidget);

      expect(find.text('CHƯA CÓ VỊ TRÍ - CẦN XÁC NHẬN (1)'), findsOneWidget);
      expect(find.text('Khách Chưa Có Vị Trí'), findsOneWidget);

      // Nút "GHIM TÂM NGẮM"
      final pinBtnFinder = find.widgetWithText(ElevatedButton, 'GHIM TÂM NGẮM');
      expect(pinBtnFinder, findsOneWidget);

      // Kích thước nút >= 56px
      final pinBtnSize = tester.getSize(pinBtnFinder);
      expect(pinBtnSize.height, greaterThanOrEqualTo(56.0));

      // Bấm nút Ghim tâm ngắm
      await tester.ensureVisible(pinBtnFinder);
      await tester.pumpAndSettle();
      await tester.tap(pinBtnFinder);
      await tester.pump();
      expect(pinnedPoint?.id, 'p2');

      // Nhóm bị từ chối
      expect(find.text('BỊ TỪ CHỐI (1)'), findsOneWidget);
      expect(find.text('0988000004'), findsOneWidget);
      expect(find.text('Ngoài khu vực'), findsOneWidget);

      // Nút đóng "XONG · XEM BẢN ĐỒ CA" >= 56px
      final doneBtnFinder = find.widgetWithText(ElevatedButton, 'XONG · XEM BẢN ĐỒ CA');
      expect(doneBtnFinder, findsOneWidget);
      expect(tester.getSize(doneBtnFinder).height, greaterThanOrEqualTo(56.0));
    });
  });
}
