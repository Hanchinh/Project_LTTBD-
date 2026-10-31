import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:delivery_marker_mobile/models/shift_model.dart';
import 'package:delivery_marker_mobile/models/customer_model.dart';
import 'package:delivery_marker_mobile/core/widgets/bulk_paste_phone_sheet.dart';
import 'package:delivery_marker_mobile/core/widgets/quick_add_customer_sheet.dart';
import 'package:delivery_marker_mobile/features/shifts/widgets/create_shift_dialog.dart';
import 'package:delivery_marker_mobile/features/directory/customer_directory_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TASK: UI-OVERFLOW-FIX-024 Widget Tests', () {
    // -------------------------------------------------------------------------
    // LỖI 1: Tràn ngang thẻ TỌA ĐỘ & GHI CHÚ VỊ TRÍ (CustomerDetailEditView)
    // -------------------------------------------------------------------------
    testWidgets('1.1 CustomerDetailEditView: màn hình hẹp 320dp + textScale 1.5 không còn overflow', (tester) async {
      final customer = CustomerDirectoryModel(
        id: 'cust-001',
        customerCode: 'KH_001',
        fullName: 'Anh Hoàng (Tạp hóa Hai Thu)',
        phoneNumber: '0988000001',
        addressText: 'Số 123 đường Long Thạnh Mỹ, TP. Thủ Đức',
        areaId: 'area-1',
        areaName: 'P. Long Thạnh Mỹ',
        locationStatus: LocationStatus.verified,
        hasLocation: true,
        latitude: 10.842215,
        longitude: 106.818123,
        identificationNotes: 'Nhà cổng sắt màu xanh lá',
        photoCount: 0,
        photos: [],
      );

      await tester.binding.setSurfaceSize(const Size(320, 800));

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 800),
              textScaler: TextScaler.linear(1.5),
            ),
            child: CustomerDetailEditView(customer: customer),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Kiểm tra tuyệt đối không có RenderFlex overflow exception
      expect(tester.takeException(), isNull);

      // Tiêu đề tọa độ
      expect(find.text('TỌA ĐỘ & GHI CHÚ VỊ TRÍ'), findsOneWidget);

      // 2 nút: Xóa vị trí và Chọn trên bản đồ
      final deleteBtnFinder = find.byKey(const Key('btn_delete_customer_location'));
      final pickBtnFinder = find.byKey(const Key('btn_pick_location_map'));

      expect(deleteBtnFinder, findsOneWidget);
      expect(pickBtnFinder, findsOneWidget);

      // Chiều cao vùng chạm >= 48px
      expect(tester.getSize(deleteBtnFinder).height, greaterThanOrEqualTo(48.0));
      expect(tester.getSize(pickBtnFinder).height, greaterThanOrEqualTo(48.0));

      // Nút Xóa vị trí theo tông đen/trung tính của 022A (không đỏ trực tiếp trên card)
      final deleteBtn = tester.widget<OutlinedButton>(deleteBtnFinder);
      expect(deleteBtn.style?.side?.resolve({})?.color, const Color(0xFF0F172A));

      // Bấm Xóa vị trí -> Hộp thoại AlertDialog hiện lên, nút Xóa vị trí trong dialog mới là màu đỏ
      await tester.ensureVisible(deleteBtnFinder);
      await tester.pump(const Duration(milliseconds: 200));
      await tester.tap(deleteBtnFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Xác nhận xóa vị trí đã lưu?'), findsOneWidget);
      final confirmDeleteBtnFinder = find.widgetWithText(ElevatedButton, 'Xóa vị trí');
      expect(confirmDeleteBtnFinder, findsOneWidget);
      final confirmDeleteBtn = tester.widget<ElevatedButton>(confirmDeleteBtnFinder);
      expect(confirmDeleteBtn.style?.backgroundColor?.resolve({}), const Color(0xFFEF4444));

      // Đóng dialog
      await tester.tap(find.text('Hủy'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.takeException(), isNull);
    });

    testWidgets('1.2 CustomerDetailEditView khi chưa có vị trí (lat/lng null): màn hình 320dp + textScale 1.5 không overflow', (tester) async {
      final customerNoLoc = CustomerDirectoryModel(
        id: 'cust-002',
        customerCode: 'KH_002',
        fullName: 'Chị Lan',
        phoneNumber: '0988000002',
        addressText: 'Chân cầu Long Thạnh Mỹ',
        areaId: 'area-1',
        areaName: 'P. Long Thạnh Mỹ',
        locationStatus: LocationStatus.noLocation,
        hasLocation: false,
        latitude: null,
        longitude: null,
        identificationNotes: '',
        photoCount: 0,
        photos: [],
      );

      await tester.binding.setSurfaceSize(const Size(320, 800));

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 800),
              textScaler: TextScaler.linear(1.5),
            ),
            child: CustomerDetailEditView(customer: customerNoLoc),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(tester.takeException(), isNull);
      expect(find.text('Khách hàng chưa có tọa độ ghim cổng nhà.'), findsOneWidget);
      expect(find.byKey(const Key('btn_pick_location_map')), findsOneWidget);
      expect(find.byKey(const Key('btn_delete_customer_location')), findsNothing);
    });

    // -------------------------------------------------------------------------
    // LỖI 2: Ô nhập SĐT bị co/đè khi bàn phím mở (BulkPastePhoneSheet)
    // -------------------------------------------------------------------------
    testWidgets('2.1 BulkPastePhoneSheet với viewInsets.bottom = 300 (bàn phím mở): không overflow, TextField cao >= 100px và không đè nút', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 750));

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(400, 750),
              viewInsets: EdgeInsets.only(bottom: 300.0), // Giả lập bàn phím mở
            ),
            child: Scaffold(
              body: BulkPastePhoneSheet(
                shiftId: 'shift-mock-001',
                isDirectoryMode: false,
                onPointsAdded: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Không có exception nào xảy ra
      expect(tester.takeException(), isNull);

      // 2. TextField tồn tại và chiều cao >= 100px (không bị squish về 0)
      final textFieldFinder = find.byType(TextField);
      expect(textFieldFinder, findsOneWidget);
      final textFieldSize = tester.getSize(textFieldFinder);
      expect(textFieldSize.height, greaterThanOrEqualTo(100.0));

      // 3. Nút "DÁN TỪ BỘ NHỚ TẠM" nằm trên TextField với khoảng cách >= 12px
      final pasteBtnFinder = find.widgetWithText(OutlinedButton, 'DÁN TỪ BỘ NHỚ TẠM');
      expect(pasteBtnFinder, findsOneWidget);

      final pasteBtnBottom = tester.getBottomLeft(pasteBtnFinder).dy;
      final textFieldTop = tester.getTopLeft(textFieldFinder).dy;
      expect(textFieldTop - pasteBtnBottom, greaterThanOrEqualTo(12.0));

      // 4. Nút hành động chính "THÊM ... ĐIỂM VÀO CA" luôn hiển thị được phía trên bàn phím
      final submitBtnFinder = find.byType(ElevatedButton);
      expect(submitBtnFinder, findsOneWidget);
      expect(tester.getSize(submitBtnFinder).height, greaterThanOrEqualTo(56.0));

      // 5. Nhập nội dung danh sách số, con trỏ và text không bị lỗi, các chip xem trước cập nhật đúng
      await tester.enterText(textFieldFinder, '0901 111 222\n0902 333 444');
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Hợp lệ: 2'), findsOneWidget);
    });

    testWidgets('2.2 QuickAddCustomerSheet với viewInsets.bottom = 300: không overflow, cuộn mượt', (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 700));

      await tester.pumpWidget(
        const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: Size(360, 700),
              viewInsets: EdgeInsets.only(bottom: 300.0),
            ),
            child: Scaffold(
              body: QuickAddCustomerSheet(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Thêm nhanh khách hàng'), findsOneWidget);
      expect(find.text('SỐ ĐIỆN THOẠI *'), findsOneWidget);
    });

    testWidgets('2.3 CreateShiftBottomSheet với viewInsets.bottom = 300: không overflow', (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 700));

      await tester.pumpWidget(
        const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: Size(360, 700),
              viewInsets: EdgeInsets.only(bottom: 300.0),
            ),
            child: Scaffold(
              body: CreateShiftBottomSheet(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Tạo ca làm việc mới'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'TẠO CA VÀ MỞ BẢN ĐỒ'), findsOneWidget);
    });
  });
}
