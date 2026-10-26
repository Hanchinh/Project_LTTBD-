import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:delivery_marker_mobile/views/account_profile_view.dart';
import 'package:delivery_marker_mobile/views/change_password_view.dart';
import 'package:delivery_marker_mobile/views/login_view.dart';
import 'package:delivery_marker_mobile/views/home_shell_view.dart';
import 'package:delivery_marker_mobile/services/api_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TASK: ACCOUNT-PROFILE-AND-LOGIN-REDESIGN-022B Widget & UI Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({
        'jwt_token': 'mock-valid-jwt-token-022b',
        'user_profile': jsonEncode({
          'id': 'd0000000-0000-0000-0000-000000000001',
          'fullName': 'Trần Văn Giao',
          'phoneNumber': '0901111111',
          'role': 'SHIPPER',
          'assignedAreaIds': ['b0000000-0000-0000-0000-000000000001'],
        }),
        'saved_login_phone': '0901111111',
        'custom_api_base_url': 'http://127.0.0.1:3000/api/v1',
      });
    });

    // -------------------------------------------------------------------------
    // A. TAB TÀI KHOẢN (AccountProfileView)
    // -------------------------------------------------------------------------
    testWidgets('A1. AccountProfileView hiển thị đầy đủ avatar chữ cái, tên, SĐT, vai trò tiếng Việt', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: AccountProfileView(),
        ),
      );
      await tester.pumpAndSettle();

      // Kiểm tra tiêu đề appbar
      expect(find.text('Tài khoản'), findsOneWidget);

      // Kiểm tra avatar initials ("TG" từ "Trần Văn Giao")
      expect(find.byKey(const Key('user_avatar_initials')), findsOneWidget);
      expect(find.text('TG'), findsOneWidget);

      // Kiểm tra họ tên
      expect(find.byKey(const Key('user_full_name')), findsOneWidget);
      expect(find.text('Trần Văn Giao'), findsOneWidget);

      // Kiểm tra SĐT đã định dạng
      expect(find.byKey(const Key('user_phone_number')), findsOneWidget);
      expect(find.text('0901 111 111'), findsOneWidget);

      // Kiểm tra vai trò hiển thị tiếng Việt "Nhân viên giao hàng"
      expect(find.byKey(const Key('user_role_badge')), findsOneWidget);
      expect(find.text('Nhân viên giao hàng'), findsOneWidget);
    });

    testWidgets('A2. AccountProfileView hiển thị các khối: Khu vực phụ trách, Thống kê của tôi, Đổi mật khẩu, Cài đặt máy chủ', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: AccountProfileView(),
        ),
      );
      await tester.pumpAndSettle();

      // Khối khu vực phụ trách
      expect(find.byKey(const Key('profile_areas_card')), findsOneWidget);
      expect(find.text('Khu vực phụ trách'), findsOneWidget);

      // Khối thống kê của tôi
      expect(find.byKey(const Key('profile_stats_card')), findsOneWidget);
      expect(find.text('Thống kê của tôi'), findsOneWidget);
      expect(find.text('Vị trí đã lưu'), findsOneWidget);
      expect(find.text('Ca đã tạo'), findsOneWidget);
      expect(find.text('Ảnh đã tải'), findsOneWidget);

      // Khối đổi mật khẩu
      expect(find.byKey(const Key('profile_change_password_item')), findsOneWidget);
      expect(find.text('Đổi mật khẩu'), findsOneWidget);

      // Khối cấu hình máy chủ & phiên bản app
      expect(find.byKey(const Key('profile_server_config_item')), findsOneWidget);
      expect(find.text('Địa chỉ máy chủ'), findsOneWidget);
      expect(find.text('Phiên bản ứng dụng'), findsOneWidget);
      expect(find.text('v1.0.0 (Build 1)'), findsOneWidget);

      // Nút Đăng xuất
      expect(find.byKey(const Key('profile_logout_btn')), findsOneWidget);
      expect(find.text('ĐĂNG XUẤT'), findsOneWidget);
    });

    testWidgets('A3. Hộp thoại Đăng xuất có xác nhận trước khi xóa phiên', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: AccountProfileView(),
        ),
      );
      await tester.pumpAndSettle();

      final logoutBtnFinder = find.byKey(const Key('profile_logout_btn'));
      await tester.ensureVisible(logoutBtnFinder);
      await tester.tap(logoutBtnFinder);
      await tester.pumpAndSettle();

      // Kiểm tra dialog xác nhận xuất hiện
      expect(find.text('Xác nhận đăng xuất'), findsOneWidget);
      expect(find.text('Bạn có chắc chắn muốn đăng xuất khỏi ứng dụng không? Phiên làm việc hiện tại sẽ kết thúc.'), findsOneWidget);
      expect(find.byKey(const Key('cancel_logout_btn')), findsOneWidget);
      expect(find.byKey(const Key('confirm_logout_btn')), findsOneWidget);

      // Nhấn Hủy -> Hộp thoại đóng, phiên vẫn còn
      await tester.tap(find.byKey(const Key('cancel_logout_btn')));
      await tester.pumpAndSettle();
      expect(find.text('Xác nhận đăng xuất'), findsNothing);

      final token = await ApiService.getToken();
      expect(token, 'mock-valid-jwt-token-022b');
    });

    testWidgets('A4. HomeShellView có tab thứ 4 "Tài khoản" với icon người', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: HomeShellView(initialTab: 3),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Kiểm tra 4 tab hiển thị trên bottom navigation
      expect(find.text('Bản đồ'), findsOneWidget);
      expect(find.text('Danh bạ'), findsOneWidget);
      expect(find.text('Ca làm việc'), findsOneWidget);
      expect(find.text('Tài khoản'), findsNWidgets(2)); // 1 ở AppBar, 1 ở bottom nav
      expect(find.byIcon(Icons.person_rounded), findsOneWidget);

      // Kiểm tra nội dung AccountProfileView đang được hiển thị ở tab 3
      expect(find.byKey(const Key('profile_header_card')), findsOneWidget);
    });

    // -------------------------------------------------------------------------
    // B. MÀN HÌNH ĐỔI MẬT KHẨU (ChangePasswordView)
    // -------------------------------------------------------------------------
    testWidgets('B1. ChangePasswordView có 3 ô mật khẩu, ẩn/hiện mật khẩu và kiểm tra độ dài tối thiểu 8 ký tự', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: ChangePasswordView(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Đổi mật khẩu'), findsOneWidget);
      expect(find.byKey(const Key('current_password_input')), findsOneWidget);
      expect(find.byKey(const Key('new_password_input')), findsOneWidget);
      expect(find.byKey(const Key('confirm_password_input')), findsOneWidget);
      expect(find.byKey(const Key('change_password_submit_btn')), findsOneWidget);

      final submitBtn = find.byKey(const Key('change_password_submit_btn'));

      // Nhấn Đổi mật khẩu khi form trống -> Báo lỗi
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      expect(find.text('Vui lòng nhập mật khẩu hiện tại'), findsOneWidget);

      // Nhập mật khẩu hiện tại nhưng mật khẩu mới < 8 ký tự
      await tester.enterText(find.byKey(const Key('current_password_input')), 'currentPass123');
      await tester.enterText(find.byKey(const Key('new_password_input')), 'short7');
      await tester.enterText(find.byKey(const Key('confirm_password_input')), 'short7');
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      expect(find.text('Mật khẩu mới phải có ít nhất 8 ký tự'), findsOneWidget);

      // Kiểm tra mật khẩu mới trùng mật khẩu hiện tại
      await tester.enterText(find.byKey(const Key('new_password_input')), 'currentPass123');
      await tester.enterText(find.byKey(const Key('confirm_password_input')), 'currentPass123');
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      expect(find.text('Mật khẩu mới không được trùng với mật khẩu hiện tại.'), findsOneWidget);
    });

    testWidgets('B2. ChangePasswordView kiểm tra nút ẩn/hiện mật khẩu hoạt động', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: ChangePasswordView(),
        ),
      );
      await tester.pumpAndSettle();

      // Kiểm tra ban đầu cả 3 trường đều ẩn (obscureText = true)
      final textFieldsBefore = tester.widgetList<TextField>(find.byType(TextField)).toList();
      for (final tf in textFieldsBefore) {
        expect(tf.obscureText, isTrue);
      }

      // Nhấn nút toggle của ô mật khẩu mới
      await tester.tap(find.byKey(const Key('toggle_new_password_visibility')));
      await tester.pumpAndSettle();

      final textFieldsAfter = tester.widgetList<TextField>(find.byType(TextField)).toList();
      // Ô thứ 2 (mật khẩu mới) hiện rõ (obscureText = false)
      expect(textFieldsAfter[1].obscureText, isFalse);
    });

    // -------------------------------------------------------------------------
    // C. MÀN HÌNH ĐĂNG NHẬP REDESIGN (LoginView)
    // -------------------------------------------------------------------------
    testWidgets('C1. LoginView giao diện gọn, nút ĐĂNG NHẬP đen rộng đầy chiều ngang có chiều cao >= 56px', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: LoginView(),
        ),
      );
      await tester.pumpAndSettle();

      // Kiểm tra logo và tên app
      expect(find.text('Định Vị Giao Hàng'), findsOneWidget);
      expect(find.byIcon(Icons.local_shipping_rounded), findsOneWidget);
      expect(find.text('Đăng nhập'), findsOneWidget);

      // Kiểm tra ô SĐT và mật khẩu
      expect(find.byKey(const Key('login_phone_input')), findsOneWidget);
      expect(find.byKey(const Key('login_password_input')), findsOneWidget);

      // Kiểm tra nút ĐĂNG NHẬP có chiều cao >= 56px
      final submitBtnFinder = find.byKey(const Key('login_submit_btn'));
      expect(submitBtnFinder, findsOneWidget);
      final btnSize = tester.getSize(submitBtnFinder);
      expect(btnSize.height, greaterThanOrEqualTo(56.0));

      // Kiểm tra link Cấu hình máy chủ ở chân trang
      expect(find.byKey(const Key('login_server_config_link')), findsOneWidget);
      expect(find.text('Cấu hình máy chủ'), findsOneWidget);
    });

    testWidgets('C2. LoginView nhớ SĐT từ lần trước nhưng KHÔNG nhớ mật khẩu', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // SharedPreferences đã seed 'saved_login_phone': '0901111111'
      await tester.pumpWidget(
        const MaterialApp(
          home: LoginView(),
        ),
      );
      await tester.pumpAndSettle();

      // Ô SĐT tự điền số điện thoại lưu từ phiên trước
      final phoneField = tester.widget<TextField>(
        find.descendant(
          of: find.byKey(const Key('login_phone_input')),
          matching: find.byType(TextField),
        ),
      );
      expect(phoneField.controller?.text, '0901111111');

      // Ô mật khẩu PHẢI HOÀN TOÀN TRỐNG
      final passwordField = tester.widget<TextField>(
        find.descendant(
          of: find.byKey(const Key('login_password_input')),
          matching: find.byType(TextField),
        ),
      );
      expect(passwordField.controller?.text, isEmpty);
    });

    testWidgets('C3. LoginView có nút ẩn/hiện mật khẩu hoạt động chuẩn xác', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: LoginView(),
        ),
      );
      await tester.pumpAndSettle();

      TextField getPasswordField() => tester.widget<TextField>(
            find.descendant(
              of: find.byKey(const Key('login_password_input')),
              matching: find.byType(TextField),
            ),
          );

      // Ban đầu mật khẩu bị ẩn
      expect(getPasswordField().obscureText, isTrue);

      // Nhấn toggle button
      await tester.tap(find.byKey(const Key('login_password_toggle_btn')));
      await tester.pumpAndSettle();

      // Sau khi toggle, mật khẩu hiện rõ
      expect(getPasswordField().obscureText, isFalse);
    });

    testWidgets('C4. LoginView hiển thị hộp lỗi tiếng Việt với nút "Thử lại"', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: LoginView(),
        ),
      );
      await tester.pumpAndSettle();

      // Nhập mật khẩu sai và nhấn đăng nhập
      await tester.enterText(find.byKey(const Key('login_password_input')), 'wrongpass');
      await tester.tap(find.byKey(const Key('login_submit_btn')));
      await tester.pump(); // Start request

      // Chờ hoàn tất request lỗi (trong test môi trường không có server -> báo lỗi kết nối hoặc lỗi)
      await tester.pumpAndSettle();

      // Hộp lỗi hiển thị ngay dưới form
      expect(find.byKey(const Key('login_error_container')), findsOneWidget);
      expect(find.byKey(const Key('login_retry_btn')), findsOneWidget);
      expect(find.text('Thử lại'), findsOneWidget);
    });

    testWidgets('C5. Nhấn "Cấu hình máy chủ" mở dialog cho phép đổi base URL', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: LoginView(),
        ),
      );
      await tester.pumpAndSettle();

      final configLink = find.byKey(const Key('login_server_config_link'));
      await tester.ensureVisible(configLink);
      await tester.tap(configLink);
      await tester.pumpAndSettle();

      // Có 2 widget "Cấu hình máy chủ": 1 trên link chân trang, 1 trên tiêu đề dialog
      expect(find.text('Cấu hình máy chủ'), findsNWidgets(2));
      expect(find.byKey(const Key('login_server_url_input')), findsOneWidget);
      expect(find.byKey(const Key('login_server_url_save_btn')), findsOneWidget);
      expect(find.text('Mặc định'), findsOneWidget);

      // Đóng dialog bằng nút Mặc định
      await tester.tap(find.text('Mặc định'));
      await tester.pumpAndSettle();

      // Sau khi đóng, chỉ còn 1 widget text "Cấu hình máy chủ" ở chân trang
      expect(find.text('Cấu hình máy chủ'), findsOneWidget);
    });
  });
}
