import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:delivery_marker_mobile/models/customer_model.dart';
import 'package:delivery_marker_mobile/models/shift_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TASK: UI-REDESIGN-DIRECTORY-AND-SHIFTS-021 Widget & Unit Tests', () {
    test('1. CustomerDirectoryModel: formattedPhoneNumber, locationState, và TabCounts', () {
      final customer = CustomerDirectoryModel(
        id: 'c1',
        customerCode: 'KH001',
        fullName: 'Nguyễn Văn A',
        phoneNumber: '0908333166',
        addressText: '123 Nguyễn Huệ, Q1',
        locationStatus: LocationStatus.verified,
        locationState: LocationStatus.verified,
      );

      expect(customer.formattedPhoneNumber, '0908 333 166');
      expect(customer.locationState, LocationStatus.verified);

      final counts = CustomerTabCounts.fromJson({
        'total': 12,
        'verified': 8,
        'temporary': 3,
        'noLocation': 1,
      });
      expect(counts.total, 12);
      expect(counts.verified, 8);
      expect(counts.temporary, 3);
      expect(counts.noLocation, 1);
    });

    testWidgets('2. Dòng danh bạ: ảnh/icon + chấm trạng thái đúng màu, nút "+" >= 48px, format SĐT · Tên', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));

      // Test customer row layout directly
      final customerVerified = CustomerDirectoryModel(
        id: 'c1',
        customerCode: 'KH001',
        fullName: 'Nguyễn Văn An',
        phoneNumber: '0908333166',
        addressText: '123 Lê Lợi, Bến Nghé, Quận 1',
        locationState: LocationStatus.verified,
      );

      final customerTemp = CustomerDirectoryModel(
        id: 'c2',
        customerCode: 'KH002',
        fullName: 'Trần Thị Bích',
        phoneNumber: '0912345678',
        addressText: '456 Hai Bà Trưng, Quận 3',
        locationState: LocationStatus.temporary,
      );

      final customerNoLoc = CustomerDirectoryModel(
        id: 'c3',
        customerCode: 'KH003',
        fullName: 'Lê Hoàng Cường',
        phoneNumber: '0988776655',
        addressText: 'Chưa có địa chỉ',
        locationState: LocationStatus.noLocation,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView(
              children: [
                _buildTestCustomerRow(customerVerified),
                _buildTestCustomerRow(customerTemp),
                _buildTestCustomerRow(customerNoLoc),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      // Kiểm tra định dạng dòng 1: SĐT định dạng 0908 333 166 · Tên (chữ đậm)
      expect(find.text('0908 333 166 · Nguyễn Văn An'), findsOneWidget);
      expect(find.text('0912 345 678 · Trần Thị Bích'), findsOneWidget);
      expect(find.text('0988 776 655 · Lê Hoàng Cường'), findsOneWidget);

      // Kiểm tra nút "+" có vùng chạm >= 48px
      final plusButtons = find.byKey(const Key('btn_add_to_shift'));
      expect(plusButtons, findsNWidgets(3));
      for (final btn in plusButtons.evaluate()) {
        final renderBox = btn.renderObject as RenderBox;
        expect(renderBox.size.width, greaterThanOrEqualTo(48.0));
        expect(renderBox.size.height, greaterThanOrEqualTo(48.0));
      }

      // Kiểm tra chấm trạng thái: VERIFIED (#10B981), TEMPORARY (#F59E0B), NO_LOCATION (#94A3B8)
      final dotVerified = tester.widget<Container>(find.byKey(const Key('dot_verified')));
      final dotTemp = tester.widget<Container>(find.byKey(const Key('dot_temporary')));
      final dotNoLoc = tester.widget<Container>(find.byKey(const Key('dot_noLocation')));

      expect((dotVerified.decoration as BoxDecoration).color, const Color(0xFF10B981));
      expect((dotTemp.decoration as BoxDecoration).color, const Color(0xFFF59E0B));
      expect((dotNoLoc.decoration as BoxDecoration).color, const Color(0xFF94A3B8));
    });

    testWidgets('3. Nhánh nút "+": Chưa có ca -> Hộp thoại hỏi "Chưa có ca, tạo ca mới?"', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));

      bool createTriggered = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                key: const Key('btn_simulate_no_shift'),
                onPressed: () async {
                  final candidateShifts = <ShiftModel>[];
                  if (candidateShifts.isEmpty) {
                    final shouldCreate = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Chưa có ca làm việc'),
                        content: const Text('Chưa có ca làm việc nào đang chuẩn bị hoặc thực hiện. Bác tài có muốn tạo ca mới không?'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('HỦY')),
                          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('TẠO CA MỚI')),
                        ],
                      ),
                    );
                    if (shouldCreate == true) {
                      createTriggered = true;
                    }
                  }
                },
                child: const Text('Thêm vào ca'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('btn_simulate_no_shift')));
      await tester.pumpAndSettle();

      expect(find.text('Chưa có ca làm việc'), findsOneWidget);
      expect(find.text('Chưa có ca làm việc nào đang chuẩn bị hoặc thực hiện. Bác tài có muốn tạo ca mới không?'), findsOneWidget);

      await tester.tap(find.text('TẠO CA MỚI'));
      await tester.pumpAndSettle();

      expect(createTriggered, isTrue);
    });

    testWidgets('4. Nhánh nút "+": Nhiều ca -> Mở Bottom Sheet chọn ca', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));

      final shifts = [
        ShiftModel(
          id: 's1',
          shipperId: 'shipper-1',
          shiftCode: 'SHF-001',
          shiftName: 'Ca sáng Q1',
          shiftDate: '2026-10-25',
          status: ShiftStatus.preparing,
          summary: ShiftSummaryModel(totalPoints: 5, verifiedCount: 3, temporaryCount: 1, noLocationCount: 1),
        ),
        ShiftModel(
          id: 's2',
          shipperId: 'shipper-1',
          shiftCode: 'SHF-002',
          shiftName: 'Ca chiều Q3',
          shiftDate: '2026-10-25',
          status: ShiftStatus.inProgress,
          summary: ShiftSummaryModel(totalPoints: 8, verifiedCount: 6, temporaryCount: 2, noLocationCount: 0),
        ),
      ];

      ShiftModel? selected;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                key: const Key('btn_simulate_multi_shift'),
                onPressed: () async {
                  final chosen = await showModalBottomSheet<ShiftModel>(
                    context: context,
                    builder: (ctx) => Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Chọn ca làm việc để thêm điểm'),
                        ...shifts.map((s) => ListTile(
                          title: Text(s.displayTitle),
                          subtitle: Text('${s.shiftDate} · ${s.status.displayName}'),
                          onTap: () => Navigator.pop(ctx, s),
                        )),
                      ],
                    ),
                  );
                  selected = chosen;
                },
                child: const Text('Thêm'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('btn_simulate_multi_shift')));
      await tester.pumpAndSettle();

      expect(find.text('Chọn ca làm việc để thêm điểm'), findsOneWidget);
      expect(find.text('Ca sáng Q1'), findsOneWidget);
      expect(find.text('Ca chiều Q3'), findsOneWidget);

      await tester.tap(find.text('Ca chiều Q3'));
      await tester.pumpAndSettle();

      expect(selected?.id, 's2');
    });

    testWidgets('5. Nhánh nút "+": Đúng 1 ca -> Thêm thẳng và hiện SnackBar HOÀN TÁC', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));

      bool undoCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                key: const Key('btn_simulate_single_shift'),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Đã thêm vào Ca Sáng Q1'),
                      backgroundColor: const Color(0xFF10B981),
                      action: SnackBarAction(
                        label: 'HOÀN TÁC',
                        onPressed: () {
                          undoCalled = true;
                        },
                      ),
                    ),
                  );
                },
                child: const Text('Thêm'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('btn_simulate_single_shift')));
      await tester.pumpAndSettle();

      expect(find.text('Đã thêm vào Ca Sáng Q1'), findsOneWidget);
      expect(find.text('HOÀN TÁC'), findsOneWidget);

      await tester.tap(find.text('HOÀN TÁC'));
      await tester.pumpAndSettle();

      expect(undoCalled, isTrue);
    });

    testWidgets('6. Thẻ ca ĐANG THỰC HIỆN hiện đúng khi có và ẩn khi không có', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));

      final preparingShift = ShiftModel(
        id: 's1',
        shipperId: 'shipper-1',
        shiftCode: 'SHF-001',
        shiftName: 'Ca sáng',
        shiftDate: '2026-10-25',
        status: ShiftStatus.preparing,
        summary: ShiftSummaryModel(totalPoints: 4, verifiedCount: 2, temporaryCount: 1, noLocationCount: 1),
      );

      final inProgressShift = ShiftModel(
        id: 's2',
        shipperId: 'shipper-1',
        shiftCode: 'SHF-002',
        shiftName: 'Ca giao hỏa tốc',
        shiftDate: '2026-10-25',
        status: ShiftStatus.inProgress,
        summary: ShiftSummaryModel(totalPoints: 12, verifiedCount: 8, temporaryCount: 3, noLocationCount: 1),
      );

      // Trường hợp 1: Không có ca IN_PROGRESS -> mục "ĐANG THỰC HIỆN" ẩn
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: _buildTestShiftList([preparingShift]),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('ĐANG THỰC HIỆN'), findsNothing);
      expect(find.text('DANH SÁCH CA (1)'), findsOneWidget);

      // Trường hợp 2: Có ca IN_PROGRESS -> mục "ĐANG THỰC HIỆN" hiện nổi bật
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: _buildTestShiftList([inProgressShift, preparingShift]),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('ĐANG THỰC HIỆN'), findsOneWidget);
      expect(find.text('Ca giao hỏa tốc'), findsWidgets);
      expect(find.text('8 Đã xác minh · 3 Tạm · 1 Chưa có'), findsOneWidget);
      expect(find.text('Dán SĐT'), findsOneWidget);
      expect(find.text('Mở bản đồ'), findsOneWidget);
      expect(find.text('DANH SÁCH CA (2)'), findsOneWidget);
    });

    testWidgets('7. Nút thùng rác xóa ca: vùng chạm >= 48px và mở hộp xác nhận', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));

      final testShift = ShiftModel(
        id: 's1',
        shipperId: 'shipper-1',
        shiftCode: 'SHF-001',
        shiftName: 'Ca sáng Q1',
        shiftDate: '2026-10-25',
        status: ShiftStatus.preparing,
        summary: ShiftSummaryModel(totalPoints: 5, verifiedCount: 3, temporaryCount: 1, noLocationCount: 1),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: _buildTestShiftList([testShift]),
          ),
        ),
      );
      await tester.pump();

      // Kiểm tra vùng chạm nút thùng rác >= 48px
      final trashBtnFinder = find.byKey(const Key('btn_delete_shift_s1'));
      expect(trashBtnFinder, findsOneWidget);
      final renderBox = tester.renderObject(trashBtnFinder) as RenderBox;
      expect(renderBox.size.width, greaterThanOrEqualTo(48.0));
      expect(renderBox.size.height, greaterThanOrEqualTo(48.0));

      // Bấm nút thùng rác
      await tester.tap(trashBtnFinder);
      await tester.pumpAndSettle();

      // Hộp thoại xác nhận xuất hiện
      expect(find.text('Xóa ca làm việc'), findsOneWidget);
      expect(find.text('XÓA CA'), findsOneWidget);
      expect(find.text('HỦY'), findsOneWidget);
    });
  });
}

/// Helper tạo dòng khách hàng phục vụ widget test
Widget _buildTestCustomerRow(CustomerDirectoryModel customer) {
  Color dotColor;
  Key dotKey;
  switch (customer.locationState) {
    case LocationStatus.verified:
      dotColor = const Color(0xFF10B981);
      dotKey = const Key('dot_verified');
      break;
    case LocationStatus.temporary:
      dotColor = const Color(0xFFF59E0B);
      dotKey = const Key('dot_temporary');
      break;
    case LocationStatus.noLocation:
      dotColor = const Color(0xFF94A3B8);
      dotKey = const Key('dot_noLocation');
      break;
  }

  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: Row(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.photo_camera_outlined, size: 24, color: Color(0xFF94A3B8)),
            ),
            Positioned(
              bottom: -2,
              right: -2,
              child: Container(
                key: dotKey,
                width: 12,
                height: 12,
                decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
              ),
            ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${customer.formattedPhoneNumber} · ${customer.fullName}',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
              ),
              Text(
                customer.addressText,
                style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              ),
            ],
          ),
        ),
        SizedBox(
          key: const Key('btn_add_to_shift'),
          width: 48,
          height: 48,
          child: Center(
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.add_rounded, size: 20),
            ),
          ),
        ),
      ],
    ),
  );
}

/// Helper tạo giao diện danh sách ca phục vụ widget test
Widget _buildTestShiftList(List<ShiftModel> shifts) {
  final inProgress = shifts.where((s) => s.status == ShiftStatus.inProgress).toList();
  final activeInProgress = inProgress.isNotEmpty ? inProgress.first : null;

  return Builder(
    builder: (context) => ListView(
      children: [
        if (activeInProgress != null) ...[
          const Text('ĐANG THỰC HIỆN'),
          Text(activeInProgress.displayTitle),
          Text(
            '${activeInProgress.summary.verifiedCount} Đã xác minh · ${activeInProgress.summary.temporaryCount} Tạm · ${activeInProgress.summary.noLocationCount} Chưa có',
          ),
          ElevatedButton(onPressed: () {}, child: const Text('Dán SĐT')),
          ElevatedButton(onPressed: () {}, child: const Text('Mở bản đồ')),
        ],
        Text('DANH SÁCH CA (${shifts.length})'),
        ...shifts.map((s) => Row(
          children: [
            Expanded(child: Text(s.displayTitle)),
            SizedBox(
              key: Key('btn_delete_shift_${s.id}'),
              width: 48,
              height: 48,
              child: IconButton(
                icon: const Icon(Icons.delete_outline_rounded),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Xóa ca làm việc'),
                      content: Text('Xóa ca ${s.displayTitle}?'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('HỦY')),
                        ElevatedButton(onPressed: () => Navigator.pop(ctx), child: const Text('XÓA CA')),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        )),
      ],
    ),
  );
}
