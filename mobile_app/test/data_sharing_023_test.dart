import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:delivery_marker_mobile/views/data_sharing_view.dart';
import 'package:delivery_marker_mobile/views/account_profile_view.dart';
import 'package:delivery_marker_mobile/views/main_map_view.dart';
import 'package:delivery_marker_mobile/models/data_share_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TASK: DATA-SHARING-BETWEEN-SHIPPERS-023 Widget & UI Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({
        'jwt_token': 'mock-valid-jwt-token-023',
        'user_profile': jsonEncode({
          'id': 'd0000000-0000-0000-0000-000000000001',
          'fullName': 'Nguyễn Văn A',
          'phoneNumber': '0901111111',
          'role': 'SHIPPER',
          'assignedAreaIds': ['b0000000-0000-0000-0000-000000000001'],
        }),
        'custom_api_base_url': 'http://127.0.0.1:3000/api/v1',
      });
    });

    // -------------------------------------------------------------------------
    // 1. DATA SHARING VIEW (Màn hình quản lý chia sẻ)
    // -------------------------------------------------------------------------
    testWidgets('1.1. DataSharingView hiển thị 2 tab "Tôi chia sẻ" và "Chia sẻ cho tôi" cùng nút tạo lời mời', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: DataSharingView(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Chia sẻ dữ liệu'), findsOneWidget);
      expect(find.text('Tôi chia sẻ'), findsOneWidget);
      expect(find.text('Chia sẻ cho tôi'), findsOneWidget);
      expect(find.byKey(const Key('btn_open_create_share_sheet')), findsOneWidget);
    });

    testWidgets('1.2. Mở BottomSheet tạo lời mời chia sẻ dữ liệu với đầy đủ các trường', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: DataSharingView(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Bấm nút tạo lời mời
      await tester.tap(find.byKey(const Key('btn_open_create_share_sheet')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Kiểm tra tiêu đề và các trường trong sheet
      expect(find.text('Tạo lời mời chia sẻ dữ liệu'), findsOneWidget);
      expect(find.byKey(const Key('input_recipient_phone')), findsOneWidget);
      expect(find.byKey(const Key('chip_scope_all_points')), findsOneWidget);
      expect(find.byKey(const Key('chip_scope_shift')), findsOneWidget);
      expect(find.byKey(const Key('chip_expires_7_days')), findsOneWidget);
      expect(find.byKey(const Key('chip_expires_unlimited')), findsOneWidget);
      expect(find.byKey(const Key('switch_include_photos')), findsOneWidget);
      expect(find.byKey(const Key('btn_submit_create_share')), findsOneWidget);
    });

    testWidgets('1.3. Kiểm tra validation khi số điện thoại nhận trống', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: DataSharingView(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.byKey(const Key('btn_open_create_share_sheet')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Bấm nút gửi mà chưa nhập SĐT
      await tester.tap(find.byKey(const Key('btn_submit_create_share')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Vui lòng nhập số điện thoại người nhận'), findsOneWidget);
    });

    // -------------------------------------------------------------------------
    // 2. ACCOUNT PROFILE VIEW (Liên kết vào chia sẻ dữ liệu)
    // -------------------------------------------------------------------------
    testWidgets('2.1. AccountProfileView hiển thị mục "Chia sẻ dữ liệu" và mở DataSharingView khi nhấn', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: AccountProfileView(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final shareItemFinder = find.byKey(const Key('profile_data_sharing_item'));
      expect(shareItemFinder, findsOneWidget);
      expect(find.text('Chia sẻ dữ liệu'), findsOneWidget);
      expect(find.text('Chia sẻ vị trí & ca làm việc với shipper khác'), findsOneWidget);

      await tester.tap(shareItemFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(DataSharingView), findsOneWidget);
    });

    // -------------------------------------------------------------------------
    // 3. MAIN MAP VIEW (Bản đồ chính với điểm chia sẻ)
    // -------------------------------------------------------------------------
    testWidgets('3.1. MainMapView có nút bật/tắt "Điểm được chia sẻ" và mặc định tắt', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MainMapView(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final toggleFinder = find.byKey(const Key('toggle_shared_locations'));
      expect(toggleFinder, findsOneWidget);

      // Mặc định không hiển thị Legend hay Banner cảnh báo
      expect(find.text('Được chia sẻ'), findsNothing);
      expect(find.byKey(const Key('banner_out_of_area_warning')), findsNothing);
    });

    testWidgets('3.2. Bật nút chia sẻ hiển thị Legend màu sắc (Xanh: Của tôi, Tím: Được chia sẻ)', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MainMapView(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final toggleFinder = find.byKey(const Key('toggle_shared_locations'));
      await tester.tap(toggleFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Legend xuất hiện
      expect(find.text('Của tôi'), findsOneWidget);
      expect(find.text('Được chia sẻ'), findsOneWidget);
    });

    testWidgets('3.3. Banner cảnh báo ngoài khu vực hiển thị khi có điểm bị lọc và có thể đóng', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final GlobalKey<MainMapViewState> mapKey = GlobalKey<MainMapViewState>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MainMapView(key: mapKey),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Giả lập có 3 điểm ngoài khu vực
      mapKey.currentState?.setOutOfAreaWarningForTesting(3);
      await tester.pump();

      // Kiểm tra banner hiển thị đúng thông điệp
      expect(find.byKey(const Key('banner_out_of_area_warning')), findsOneWidget);
      expect(find.text('3 điểm không hiển thị vì ngoài khu vực của bạn'), findsOneWidget);

      // Đóng banner
      final closeBtn = find.byKey(const Key('btn_close_out_of_area_banner'));
      expect(closeBtn, findsOneWidget);
      await tester.tap(closeBtn);
      await tester.pump();

      expect(find.byKey(const Key('banner_out_of_area_warning')), findsNothing);
    });

    testWidgets('3.4. Bottom sheet chi tiết điểm chia sẻ hiển thị badge tím, thông tin, các nút và KHÔNG có Ghim lại/Xóa', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final GlobalKey<MainMapViewState> mapKey = GlobalKey<MainMapViewState>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MainMapView(key: mapKey),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final sharedPoint = SharedLocationPointModel(
        id: 'pt-001',
        customerId: 'c-001',
        customerCode: 'KH-001',
        customerName: 'Chị Mai Hoa',
        customerPhone: '0908888888',
        customerAddress: '123 Lê Văn Việt, Phước Long B, Thủ Đức',
        areaId: 'area-1',
        areaName: 'Thủ Đức',
        latitude: 10.8422,
        longitude: 106.8181,
        gpsAccuracy: 5.0,
        identificationNotes: 'Cổng sắt màu xám, chuông bên phải',
        sharedByName: 'Shipper Nam',
        shareId: 'ds-001',
      );

      // Kích hoạt hiển thị bottom sheet của điểm chia sẻ
      mapKey.currentState?.setSelectedSharedLocationForTesting(sharedPoint);
      await tester.pump();

      // Kiểm tra badge người chia sẻ
      expect(find.text('Chia sẻ từ Shipper Nam'), findsOneWidget);

      // Kiểm tra thông tin khách
      expect(find.text('Chị Mai Hoa'), findsOneWidget);
      expect(find.text('0908888888'), findsOneWidget);
      expect(find.text('123 Lê Văn Việt, Phước Long B, Thủ Đức'), findsOneWidget);
      expect(find.text('Cổng sắt màu xám, chuông bên phải'), findsOneWidget);

      // Kiểm tra các nút hành động cho điểm chia sẻ
      expect(find.byKey(const Key('btn_call_shared_point')), findsOneWidget);
      expect(find.byKey(const Key('btn_directions_shared_point')), findsOneWidget);
      expect(find.byKey(const Key('btn_import_shared_point_to_mine')), findsOneWidget);
      expect(find.text('NHẬP VÀO CỦA TÔI'), findsOneWidget);

      // Đảm bảo TUYỆT ĐỐI KHÔNG có nút Ghim lại và KHÔNG có nút Xóa
      expect(find.text('Ghim lại'), findsNothing);
      expect(find.text('XÓA'), findsNothing);
      expect(find.text('Xóa vị trí'), findsNothing);

      // Các nút nổi FAB của bản đồ phải bị ẩn khi thẻ chi tiết đang mở
      expect(find.byKey(const Key('btn_pin_new_location')), findsNothing);
    });

    testWidgets('3.5. Bấm "NHẬP VÀO CỦA TÔI" mở hộp thoại xác nhận kèm công tắc ghi đè', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final GlobalKey<MainMapViewState> mapKey = GlobalKey<MainMapViewState>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MainMapView(key: mapKey),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final sharedPoint = SharedLocationPointModel(
        id: 'pt-001',
        customerId: 'c-001',
        customerCode: 'KH-001',
        customerName: 'Chị Mai Hoa',
        customerPhone: '0908888888',
        customerAddress: '123 Lê Văn Việt',
        areaId: 'area-1',
        areaName: 'Thủ Đức',
        latitude: 10.8422,
        longitude: 106.8181,
        gpsAccuracy: 5.0,
        identificationNotes: 'Cổng sắt',
        sharedByName: 'Shipper Nam',
        shareId: 'ds-001',
      );

      mapKey.currentState?.setSelectedSharedLocationForTesting(sharedPoint);
      await tester.pump();

      // Bấm nút Nhập vào của tôi
      await tester.tap(find.byKey(const Key('btn_import_shared_point_to_mine')));
      await tester.pump();

      // Kiểm tra hộp thoại xác nhận hiện ra
      expect(find.text('Nhập vị trí vào của tôi'), findsOneWidget);
      expect(find.byKey(const Key('switch_replace_existing_single')), findsOneWidget);
      expect(find.byKey(const Key('btn_confirm_import_single_point')), findsOneWidget);

      // Hủy hộp thoại
      await tester.tap(find.text('HỦY'));
      await tester.pump();
      expect(find.text('Nhập vị trí vào của tôi'), findsNothing);
    });

    // -------------------------------------------------------------------------
    // 4. MODEL PARSING TESTS
    // -------------------------------------------------------------------------
    test('4.1. DataShareModel JSON parsing và helper getters hoạt động chuẩn', () {
      final json = {
        'id': 'ds-001',
        'owner_id': 'u-001',
        'owner_name': 'Shipper A',
        'owner_phone': '0901111111',
        'recipient_id': 'u-002',
        'recipient_name': 'Shipper B',
        'recipient_phone': '0902222222',
        'scope': 'ALL_POINTS',
        'include_photos': true,
        'status': 'ACTIVE',
        'created_at': DateTime.now().toIso8601String(),
        'shared_points_count': 15,
      };

      final model = DataShareModel.fromJson(json);
      expect(model.id, 'ds-001');
      expect(model.ownerName, 'Shipper A');
      expect(model.recipientName, 'Shipper B');
      expect(model.scope, 'ALL_POINTS');
      expect(model.includePhotos, isTrue);
      expect(model.isActive, isTrue);
      expect(model.isPending, isFalse);
      expect(model.sharedPointsCount, 15);
      expect(model.statusLabel, 'Đang chia sẻ');
    });

    test('4.2. SharedLocationPointModel JSON parsing đầy đủ thông tin điểm chia sẻ', () {
      final json = {
        'id': 'pt-001',
        'customer_id': 'c-001',
        'customer_code': 'KH-001',
        'customer_name': 'Chị Hoa',
        'customer_phone': '0908888888',
        'customer_address': '123 Lê Văn Việt, Tăng Nhơn Phú B, TP Thủ Đức',
        'area_id': 'area-001',
        'area_name': 'Thủ Đức',
        'latitude': 10.8422,
        'longitude': 106.8181,
        'gps_accuracy': 5.0,
        'identification_notes': 'Cổng sắt màu xám, chuông bên phải',
        'shared_by_name': 'Nguyễn Văn A',
        'share_id': 'ds-001',
        'photo_count': 0,
        'photos': [],
      };

      final point = SharedLocationPointModel.fromJson(json);
      expect(point.customerName, 'Chị Hoa');
      expect(point.customerPhone, '0908888888');
      expect(point.identificationNotes, 'Cổng sắt màu xám, chuông bên phải');
      expect(point.sharedByName, 'Nguyễn Văn A');
      expect(point.latitude, 10.8422);
      expect(point.longitude, 106.8181);
    });
  });
}
