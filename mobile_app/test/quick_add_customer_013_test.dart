import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:delivery_marker_mobile/data/repositories/repository_provider.dart';
import 'package:delivery_marker_mobile/shared_widgets/quick_add_customer_sheet.dart';

void main() {
  setUp(() {
    RepositoryProvider.useLocalData = false;
  });

  tearDown(() {
    RepositoryProvider.reset();
  });
  group('TASK: QUICK-ADD-CUSTOMER-013 - Phone Normalization Unit Tests', () {
    test('Chuẩn hóa các định dạng số điện thoại phổ biến về 10 chữ số chuẩn', () {
      // Khoảng trắng và dấu gạch ngang
      expect(normalizeCustomerPhone('090 123 4567'), '0901234567');
      expect(normalizeCustomerPhone('090-123-4567'), '0901234567');
      expect(normalizeCustomerPhone('(090) 123.4567'), '0901234567');

      // Đầu số quốc tế 84 (11 chữ số -> 10 chữ số)
      expect(normalizeCustomerPhone('+84 901 234 567'), '0901234567');
      expect(normalizeCustomerPhone('84901234567'), '0901234567');

      // Thiếu số 0 ở đầu (9 chữ số -> thêm 0 thành 10 chữ số)
      expect(normalizeCustomerPhone('901234567'), '0901234567');

      // Số đã chuẩn 10 chữ số giữ nguyên
      expect(normalizeCustomerPhone('0988000001'), '0988000001');

      // Số ngắn bất thường (dưới 10 số) giữ nguyên để cảnh báo
      expect(normalizeCustomerPhone('090123'), '090123');

      // Số dài bất thường giữ nguyên để cảnh báo
      expect(normalizeCustomerPhone('090123456789'), '090123456789');
    });
  });

  group('TASK: QUICK-ADD-CUSTOMER-013 - Flutter Quick Add Customer UI Tests', () {
    testWidgets('Chỉ bắt buộc 1 ô SĐT: autofocus, keyboardType phone, mục thông tin tùy chọn ban đầu bị ẩn', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: QuickAddCustomerSheet(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Kiểm tra tiêu đề
      expect(find.text('Thêm nhanh khách hàng'), findsOneWidget);

      // Ô SĐT bắt buộc duy nhất
      expect(find.text('SỐ ĐIỆN THOẠI *'), findsOneWidget);

      // Tìm TextField nhập SĐT và kiểm tra cấu hình
      final phoneFieldFinder = find.byType(TextField);
      expect(phoneFieldFinder, findsOneWidget);

      final TextField phoneField = tester.widget(phoneFieldFinder);
      expect(phoneField.autofocus, isTrue);
      expect(phoneField.keyboardType, TextInputType.phone);
      expect(phoneField.textInputAction, TextInputAction.done);

      // Kiểm tra mục "Thêm thông tin" ban đầu bị ẩn
      expect(find.text('Thêm thông tin (Tên, địa chỉ, ghi chú)'), findsOneWidget);
      expect(find.text('TÊN KHÁCH HÀNG (TÙY CHỌN)'), findsNothing);
      expect(find.text('ĐỊA CHỈ GIAO HÀNG (TÙY CHỌN)'), findsNothing);
      expect(find.text('GHI CHÚ VỊ TRÍ (TÙY CHỌN)'), findsNothing);

      // Nút TẠO có mặt
      expect(find.text('TẠO'), findsOneWidget);
    });

    testWidgets('Mở rộng mục "Thêm thông tin" hiển thị đầy đủ các trường tùy chọn', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: QuickAddCustomerSheet(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Bấm vào nút mở rộng "Thêm thông tin"
      await tester.tap(find.text('Thêm thông tin (Tên, địa chỉ, ghi chú)'));
      await tester.pumpAndSettle();

      // Mục đã mở rộng
      expect(find.text('Ẩn thông tin tùy chọn'), findsOneWidget);
      expect(find.text('TÊN KHÁCH HÀNG (TÙY CHỌN)'), findsOneWidget);
      expect(find.text('ĐỊA CHỈ GIAO HÀNG (TÙY CHỌN)'), findsOneWidget);
      expect(find.text('GHI CHÚ VỊ TRÍ (TÙY CHỌN)'), findsOneWidget);

      // Gợi ý mặc định rõ ràng
      expect(find.text('Mặc định: Khách [SĐT]'), findsOneWidget);
      expect(find.text('Mặc định: Chưa cập nhật địa chỉ'), findsOneWidget);
    });

    testWidgets('Gõ SĐT hiển thị ngay số đã chuẩn hóa live', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: QuickAddCustomerSheet(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Nhập số điện thoại có dấu cách
      await tester.enterText(find.byType(TextField).first, '090 123 4567');
      await tester.pumpAndSettle();

      // Kiểm tra nhãn hiển thị số đã chuẩn hóa
      expect(find.text('Số đã chuẩn hóa: 0901234567 (10 số)'), findsOneWidget);
    });

    testWidgets('Cảnh báo khi số không đủ 10 chữ số trước khi tạo để tránh tạo khách rác', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: QuickAddCustomerSheet(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Nhập số chỉ có 6 chữ số
      await tester.enterText(find.byType(TextField).first, '090123');
      await tester.pumpAndSettle();

      // Bấm nút "TẠO"
      await tester.tap(find.text('TẠO'));
      await tester.pumpAndSettle();

      // Kiểm tra xuất hiện AlertDialog cảnh báo
      expect(find.text('Cảnh báo số điện thoại'), findsOneWidget);
      expect(find.text('Số này có 6 chữ số (090123), bạn có chắc?'), findsOneWidget);
      final dialogCancelBtn = find.descendant(of: find.byType(AlertDialog), matching: find.text('HỦY'));
      final dialogContinueBtn = find.descendant(of: find.byType(AlertDialog), matching: find.text('TIẾP TỤC'));
      expect(dialogCancelBtn, findsOneWidget);
      expect(dialogContinueBtn, findsOneWidget);

      // Bấm HỦY đóng dialog
      await tester.tap(dialogCancelBtn);
      await tester.pumpAndSettle();

      expect(find.text('Cảnh báo số điện thoại'), findsNothing);
    });

    testWidgets('Báo lỗi SnackBar nếu để trống ô SĐT và bấm TẠO', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: QuickAddCustomerSheet(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Bấm TẠO khi chưa nhập gì
      await tester.tap(find.text('TẠO'));
      await tester.pumpAndSettle();

      // Xuất hiện SnackBar
      expect(find.text('Vui lòng nhập số điện thoại'), findsOneWidget);
    });
  });
}
