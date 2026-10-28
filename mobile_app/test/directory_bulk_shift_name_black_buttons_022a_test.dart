import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:delivery_marker_mobile/models/shift_model.dart';
import 'package:delivery_marker_mobile/core/theme/app_buttons.dart';
import 'package:delivery_marker_mobile/shared_widgets/point_detail_bottom_sheet.dart';
import 'package:delivery_marker_mobile/shared_widgets/bulk_paste_phone_sheet.dart';
import 'package:delivery_marker_mobile/features/directory/customer_directory_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TASK: DIRECTORY-BULK-SHIFT-NAME-BLACK-BUTTONS-022A Unit & Widget Tests', () {
    // -------------------------------------------------------------------------
    // PHẦN B: TÊN CA NHẤT QUÁN & SUY DIỄN / GỢI Ý TÊN CA
    // -------------------------------------------------------------------------
    test('B1. ShiftModel.formatVnDate: dd/MM trong năm hiện tại, dd/MM/yyyy khác năm', () {
      final now = DateTime.now();
      final dateSameYear = DateTime(now.year, 4, 15);
      final dateOtherYear = DateTime(2023, 11, 20);

      expect(ShiftModel.formatVnDate(dateSameYear), '15/04');
      expect(ShiftModel.formatVnDate(dateOtherYear), '20/11/2023');
    });

    test('B2. ShiftModel.inferShiftName: ca sáng (<12h), chiều (12-18h), tối (>=18h) theo giờ VN (GMT+7)', () {
      final currentYear = DateTime.now().year;

      // 08:30 UTC+7 (01:30 UTC)
      final morningUtc = DateTime.utc(currentYear, 5, 10, 1, 30);
      expect(ShiftModel.inferShiftName(morningUtc), 'Ca sáng 10/05');

      // 14:15 UTC+7 (07:15 UTC)
      final afternoonUtc = DateTime.utc(currentYear, 5, 10, 7, 15);
      expect(ShiftModel.inferShiftName(afternoonUtc), 'Ca chiều 10/05');

      // 20:00 UTC+7 (13:00 UTC)
      final eveningUtc = DateTime.utc(currentYear, 5, 10, 13, 0);
      expect(ShiftModel.inferShiftName(eveningUtc), 'Ca tối 10/05');
    });

    test('B3. ShiftModel.suggestShiftName: gợi ý tự động và chống trùng lặp đuôi (2), (3)', () {
      final currentYear = DateTime.now().year;
      final afternoonTime = DateTime.utc(currentYear, 8, 20, 8, 0); // 15:00 VN

      // 1. Chưa có ca nào trong ngày
      final suggestion1 = ShiftModel.suggestShiftName(
        dateTime: afternoonTime,
        existingNames: [],
      );
      expect(suggestion1, 'Ca chiều 20/08');

      // 2. Đã có 1 ca cùng tên trong ngày -> thêm " (2)"
      final suggestion2 = ShiftModel.suggestShiftName(
        dateTime: afternoonTime,
        existingNames: ['Ca chiều 20/08'],
      );
      expect(suggestion2, 'Ca chiều 20/08 (2)');

      // 3. Đã có 2 ca cùng tên -> thêm " (3)"
      final suggestion3 = ShiftModel.suggestShiftName(
        dateTime: afternoonTime,
        existingNames: ['Ca chiều 20/08', 'Ca chiều 20/08 (2)'],
      );
      expect(suggestion3, 'Ca chiều 20/08 (3)');
    });

    test('B4. ShiftModel.displayTitle: ưu tiên shiftName thật, nếu rỗng suy diễn theo giờ VN', () {
      final currentYear = DateTime.now().year;
      final shiftWithCustomName = ShiftModel(
        id: 's1',
        shiftCode: 'SHF-001',
        shiftName: 'Ca giao Quận 1',
        shiftDate: '2026-09-01',
        shipperId: 'shp1',
        status: ShiftStatus.inProgress,
        createdAt: DateTime.utc(currentYear, 9, 1, 2, 0),
      );
      expect(shiftWithCustomName.displayTitle, 'Ca giao Quận 1');

      final shiftWithoutName = ShiftModel(
        id: 's2',
        shiftCode: 'SHF-002',
        shiftName: null,
        shiftDate: '2026-09-01',
        shipperId: 'shp1',
        status: ShiftStatus.preparing,
        createdAt: DateTime.utc(currentYear, 9, 1, 2, 0), // 09:00 VN -> Ca sáng
      );
      expect(shiftWithoutName.displayTitle, 'Ca sáng 01/09');
    });

    // -------------------------------------------------------------------------
    // PHẦN C: NÚT HÀNH ĐỘNG TÔNG XANH ĐEN / ĐEN #0F172A
    // -------------------------------------------------------------------------
    test('C1. AppButtons theme: primary và secondary chuẩn #0F172A, touch target >= 48px / >= 56px', () {
      expect(AppButtons.navy, const Color(0xFF0F172A));
      expect(AppButtons.primaryColor, const Color(0xFF0F172A));

      // Primary style check
      final primary = AppButtons.primary();
      expect(primary.backgroundColor?.resolve({}), const Color(0xFF0F172A));
      expect(primary.foregroundColor?.resolve({}), Colors.white);
      expect(primary.minimumSize?.resolve({})?.height, greaterThanOrEqualTo(48.0));

      // Primary large style check
      final primaryLarge = AppButtons.primaryLarge();
      expect(primaryLarge.backgroundColor?.resolve({}), const Color(0xFF0F172A));
      expect(primaryLarge.minimumSize?.resolve({})?.height, greaterThanOrEqualTo(56.0));

      // Secondary style check
      final secondary = AppButtons.secondary();
      expect(secondary.backgroundColor?.resolve({}), Colors.white);
      expect(secondary.foregroundColor?.resolve({}), const Color(0xFF0F172A));
      expect(secondary.side?.resolve({})?.color, const Color(0xFF0F172A));
      expect(secondary.minimumSize?.resolve({})?.height, greaterThanOrEqualTo(48.0));
    });

    testWidgets('C2. PointDetailBottomSheet: GỌI, CHỈ ĐƯỜNG, GHIM LẠI chuẩn #0F172A và >= 56px', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PointDetailBottomSheet(
              customerId: 'c1',
              customerName: 'Nguyễn Văn Test',
              customerPhone: '0908123456',
              customerAddress: '123 Test Street, Q1',
              locationStatusText: 'Đã xác thực',
              statusBadgeBg: const Color(0xFFDCFCE7),
              statusBadgeTextColor: const Color(0xFF15803D),
              statusBadgeIcon: Icons.verified_rounded,
              onCall: () {},
              onDirections: () {},
              onRepin: () {},
            ),
          ),
        ),
      );
      await tester.pump();

      // Tìm 3 nút
      final callBtnFinder = find.byKey(const ValueKey('btn_call'));
      final dirBtnFinder = find.byKey(const ValueKey('btn_directions'));
      final repinBtnFinder = find.byKey(const ValueKey('btn_repin'));

      expect(callBtnFinder, findsOneWidget);
      expect(dirBtnFinder, findsOneWidget);
      expect(repinBtnFinder, findsOneWidget);

      // Kích thước chiều cao >= 56px
      expect(tester.getSize(callBtnFinder).height, greaterThanOrEqualTo(56.0));
      expect(tester.getSize(dirBtnFinder).height, greaterThanOrEqualTo(56.0));
      expect(tester.getSize(repinBtnFinder).height, greaterThanOrEqualTo(56.0));

      // Màu nền Navy #0F172A
      final callBtn = tester.widget<ElevatedButton>(callBtnFinder);
      expect(callBtn.style?.backgroundColor?.resolve({}), const Color(0xFF0F172A));
      final dirBtn = tester.widget<ElevatedButton>(dirBtnFinder);
      expect(dirBtn.style?.backgroundColor?.resolve({}), const Color(0xFF0F172A));
      final repinBtn = tester.widget<ElevatedButton>(repinBtnFinder);
      expect(repinBtn.style?.backgroundColor?.resolve({}), const Color(0xFF0F172A));

      // Icon và text phân biệt rõ ràng
      expect(find.byIcon(Icons.phone_in_talk_rounded), findsOneWidget);
      expect(find.byIcon(Icons.directions_rounded), findsOneWidget);
      expect(find.byIcon(Icons.edit_location_alt_rounded), findsOneWidget);
      expect(find.text('GỌI'), findsOneWidget);
      expect(find.text('CHỈ ĐƯỜNG'), findsOneWidget);
      expect(find.text('GHIM LẠI'), findsOneWidget);
    });

    // -------------------------------------------------------------------------
    // PHẦN A: DANH BẠ THÊM SỐ HÀNG LOẠT & GIAO DIỆN CHẾ ĐỘ DANH BẠ
    // -------------------------------------------------------------------------
    testWidgets('A1. BulkPastePhoneSheet trong chế độ danh bạ (isDirectoryMode: true): tiêu đề, nút hành động >= 56px', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BulkPastePhoneSheet(
              isDirectoryMode: true,
              onCustomersAdded: (_) {},
            ),
          ),
        ),
      );
      await tester.pump();

      // Tiêu đề chế độ danh bạ
      expect(find.text('Dán danh sách SĐT vào danh bạ'), findsOneWidget);

      // Nhập danh sách 3 số (trong đó có số trùng và số sai)
      final textFieldFinder = find.byType(TextField);
      expect(textFieldFinder, findsOneWidget);

      await tester.enterText(textFieldFinder, '0908 111 222\n+84 908 111 222\n0988 333 444\n01234');
      await tester.pump();

      // Đếm hợp lệ (2 số duy nhất) và sai định dạng (1 số)
      expect(find.text('Hợp lệ: 2'), findsOneWidget);
      expect(find.text('Sai định dạng: 1'), findsOneWidget);

      // Nút "THÊM 2 SỐ VÀO DANH BẠ"
      final submitBtnFinder = find.widgetWithText(ElevatedButton, 'THÊM 2 SỐ VÀO DANH BẠ');
      expect(submitBtnFinder, findsOneWidget);

      // Kích thước nút >= 56px
      expect(tester.getSize(submitBtnFinder).height, greaterThanOrEqualTo(56.0));

      // Màu nền #0F172A
      final submitBtn = tester.widget<ElevatedButton>(submitBtnFinder);
      expect(submitBtn.style?.backgroundColor?.resolve({}), const Color(0xFF0F172A));
    });

    testWidgets('A2. CustomerDirectoryView: có nút "Dán nhiều số" (>= 48px) cạnh "+ Thêm số" (>= 48px)', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));

      await tester.pumpWidget(
        const MaterialApp(
          home: CustomerDirectoryView(),
        ),
      );
      await tester.pump();

      // Nút "Dán nhiều số" và "Thêm số"
      final bulkBtnFinder = find.byKey(const ValueKey('btn_bulk_paste_directory'));
      final addBtnFinder = find.byKey(const ValueKey('btn_add_single_customer'));

      expect(bulkBtnFinder, findsOneWidget);
      expect(addBtnFinder, findsOneWidget);

      // Chiều cao >= 48px
      expect(tester.getSize(bulkBtnFinder).height, greaterThanOrEqualTo(48.0));
      expect(tester.getSize(addBtnFinder).height, greaterThanOrEqualTo(48.0));

      // Style: Dán nhiều số là OutlinedButton với viền #0F172A, Thêm số là ElevatedButton với nền #0F172A
      final bulkBtn = tester.widget<OutlinedButton>(bulkBtnFinder);
      expect(bulkBtn.style?.side?.resolve({})?.color, const Color(0xFF0F172A));

      final addBtn = tester.widget<ElevatedButton>(addBtnFinder);
      expect(addBtn.style?.backgroundColor?.resolve({}), const Color(0xFF0F172A));
    });
  });
}
