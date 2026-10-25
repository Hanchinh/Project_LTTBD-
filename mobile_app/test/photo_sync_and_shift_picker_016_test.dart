import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:delivery_marker_mobile/models/shift_model.dart';
import 'package:delivery_marker_mobile/models/customer_model.dart';
import 'package:delivery_marker_mobile/models/customer_photo_model.dart';
import 'package:delivery_marker_mobile/widgets/customer_photos_strip_widget.dart';
import 'package:delivery_marker_mobile/views/shift_preparation_view.dart';
import 'package:delivery_marker_mobile/views/main_map_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TASK: PHOTO-SYNC-SHIFT-PICKER-BULK-016 Widget Tests', () {
    testWidgets('1. CustomerPhotosStripWidget: hiển thị dải ảnh dùng chung, ô + Thêm ảnh, và badge số thứ tự', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));

      final testPhotos = [
        CustomerPhotoModel(id: 'p1', customerId: 'c1', imageUrl: 'http://localhost:3000/api/v1/photos/p1.jpg'),
        CustomerPhotoModel(id: 'p2', customerId: 'c1', imageUrl: 'http://localhost:3000/api/v1/photos/p2.jpg'),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomerPhotosStripWidget(
              customerId: 'c1',
              customerName: 'Nguyễn Văn Test',
              initialPhotos: testPhotos,
              canAddPhoto: true,
              canDeletePhoto: true,
            ),
          ),
        ),
      );
      await tester.pump();

      // Ô "+ Thêm ảnh" xuất hiện
      expect(find.text('+ THÊM ẢNH'), findsOneWidget);

      // 2 ảnh xuất hiện với badge số thứ tự
      expect(find.text('1/2'), findsOneWidget);
      expect(find.text('2/2'), findsOneWidget);
    });

    testWidgets('2. MainMapView: nút "Ca làm việc" (>= 56px) vùng ngón cái không chồng nút "Ghim vị trí mới" và "Tạo ca"', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MainMapView(),
          ),
        ),
      );
      await tester.pump();

      // Nút "Ca làm việc" xuất hiện
      final shiftPickerBtnFinder = find.byKey(const Key('btn_open_shift_picker'));
      expect(shiftPickerBtnFinder, findsOneWidget);
      expect(find.byTooltip('Ca làm việc'), findsOneWidget);

      // Nút "Tạo ca" xuất hiện
      final createShiftBtnFinder = find.byKey(const Key('btn_create_shift_from_map'));
      expect(createShiftBtnFinder, findsOneWidget);
      expect(find.byTooltip('Tạo ca'), findsOneWidget);

      // Nút "Ghim vị trí mới" xuất hiện
      final pinBtnFinder = find.byKey(const Key('btn_pin_new_location'));
      expect(pinBtnFinder, findsOneWidget);
      expect(find.byTooltip('Ghim vị trí mới'), findsOneWidget);

      // Kiểm tra chiều cao cả 3 nút đều >= 52px (Ghim 60px, Tạo ca 52px, Ca làm việc 52px)
      expect(tester.getSize(shiftPickerBtnFinder).height, greaterThanOrEqualTo(52.0));
      expect(tester.getSize(createShiftBtnFinder).height, greaterThanOrEqualTo(52.0));
      expect(tester.getSize(pinBtnFinder).height, greaterThanOrEqualTo(60.0));

      // Kiểm tra không chồng chéo: Nút Ghim vị trí ở dưới, Tạo ca ở giữa, Ca làm việc ở trên
      final pinTop = tester.getTopLeft(pinBtnFinder).dy;
      final createBottom = tester.getBottomLeft(createShiftBtnFinder).dy;
      final pickerBottom = tester.getBottomLeft(shiftPickerBtnFinder).dy;
      expect(pinTop, greaterThanOrEqualTo(createBottom));
      expect(createBottom, greaterThanOrEqualTo(pickerBottom));
    });

    testWidgets('3. ShiftPreparationView: nút lớn "NHẬP HÀNG LOẠT SĐT" (>= 56px) cạnh ô nhập một số', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));

      final testShift = ShiftModel(
        id: 's001',
        shiftCode: 'SHF-TEST-001',
        shiftName: 'Ca Sáng Quận 9',
        shiftDate: '2026-10-25',
        shipperId: 'd001',
        status: ShiftStatus.preparing,
        summary: ShiftSummaryModel(totalPoints: 0, verifiedCount: 0, temporaryCount: 0, noLocationCount: 0),
        deliveryPoints: [],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ShiftPreparationView(shift: testShift),
          ),
        ),
      );
      await tester.pump();

      // Nút lớn "NHẬP HÀNG LOẠT SĐT" xuất hiện
      final bulkBtnFinder = find.byKey(const Key('btn_bulk_paste_phones'));
      expect(bulkBtnFinder, findsOneWidget);
      expect(find.text('NHẬP HÀNG LOẠT SĐT'), findsOneWidget);
      expect(tester.getSize(bulkBtnFinder).height, greaterThanOrEqualTo(56.0));

      // Vẫn giữ ô nhập một số và nút Thêm
      expect(find.byKey(const Key('btn_add_single_phone')), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('HOẶC THÊM TỪNG SỐ'), findsOneWidget);
    });

    testWidgets('4. CustomerModel: hỗ trợ photoCount và danh sách photos', (tester) async {
      final json = {
        'id': 'c1',
        'customerCode': 'KH001',
        'fullName': 'Trần Văn A',
        'phoneNumber': '0901234567',
        'addressText': '123 Test St',
        'locationStatus': 'VERIFIED',
        'photoCount': 3,
        'imageUrl': 'http://localhost:3000/api/v1/photos/latest.jpg',
        'photos': [
          {'id': 'p1', 'customerId': 'c1', 'imageUrl': 'http://localhost:3000/api/v1/photos/p1.jpg'},
          {'id': 'p2', 'customerId': 'c1', 'imageUrl': 'http://localhost:3000/api/v1/photos/p2.jpg'},
          {'id': 'p3', 'customerId': 'c1', 'imageUrl': 'http://localhost:3000/api/v1/photos/p3.jpg'},
        ],
      };

      final customer = CustomerDirectoryModel.fromJson(json);
      expect(customer.photoCount, 3);
      expect(customer.photos.length, 3);
      expect(customer.hasPhoto, isTrue);
      expect(customer.imageUrl, 'http://localhost:3000/api/v1/photos/latest.jpg');
    });
  });
}
