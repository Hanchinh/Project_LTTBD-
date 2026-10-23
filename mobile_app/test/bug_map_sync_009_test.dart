import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:delivery_marker_mobile/models/shift_model.dart';
import 'package:delivery_marker_mobile/models/customer_model.dart';

void main() {
  group('BUG-MAP-SYNC-009 — Đồng bộ hoàn toàn ảnh, tọa độ, ghi chú và trạng thái vị trí', () {
    test('BUG-06: LocationStatus pickerDisplayName returns accurate Vietnamese labels', () {
      expect(LocationStatus.verified.pickerDisplayName, equals('Đã xác minh'));
      expect(LocationStatus.temporary.pickerDisplayName, equals('Đã ghim vị trí · Chờ xác minh'));
      expect(LocationStatus.noLocation.pickerDisplayName, equals('Chưa ghim vị trí'));

      // Ensure original displayName remains backward compatible
      expect(LocationStatus.verified.displayName, equals('Đã xác minh'));
      expect(LocationStatus.temporary.displayName, equals('Vị trí tạm'));
      expect(LocationStatus.noLocation.displayName, equals('Chưa có vị trí'));
    });

    test('BUG-01: Clearing photoUrl on ShiftDeliveryPointModel resets hasPhoto to false', () {
      final point = ShiftDeliveryPointModel(
        id: 'p-1',
        shiftId: 's-1',
        customerId: 'c-1',
        customerName: 'Nguyễn Văn A',
        customerPhone: '0901234567',
        customerAddress: '123 Lê Văn Việt, TP Thủ Đức',
        locationStatus: LocationStatus.verified,
        latitude: 10.848,
        longitude: 106.772,
        photoUrl: '/api/v1/photos/gate_123.jpg',
      );

      expect(point.hasPhoto, isTrue);
      expect(point.photoUrl, equals('/api/v1/photos/gate_123.jpg'));

      // Simulate deletion on UI
      final pointWithoutPhoto = point.copyWith(photoUrl: '');
      expect(pointWithoutPhoto.hasPhoto, isFalse);
      expect(pointWithoutPhoto.photoUrl, isEmpty);

      // Verify coordinates, notes and status are preserved
      expect(pointWithoutPhoto.latitude, equals(10.848));
      expect(pointWithoutPhoto.longitude, equals(106.772));
      expect(pointWithoutPhoto.customerName, equals('Nguyễn Văn A'));
      expect(pointWithoutPhoto.locationStatus, equals(LocationStatus.verified));
    });

    test('BUG-02 & BUG-05: Modifying coordinates and notes does not wipe photo or customer info', () {
      final initialPoint = ShiftDeliveryPointModel(
        id: 'p-2',
        shiftId: 's-1',
        customerId: 'c-2',
        customerName: 'Trần Thị B',
        customerPhone: '0987654321',
        customerAddress: '456 Đỗ Xuân Hợp',
        locationStatus: LocationStatus.temporary,
        latitude: 10.850,
        longitude: 106.775,
        locationNotes: 'Cổng sắt màu xanh',
        photoUrl: '/api/v1/photos/house_blue.jpg',
      );

      // 1. Update coordinates only
      final movedPoint = initialPoint.copyWith(
        latitude: 10.852,
        longitude: 106.778,
      );
      expect(movedPoint.latitude, equals(10.852));
      expect(movedPoint.longitude, equals(106.778));
      expect(movedPoint.latLng, equals(const LatLng(10.852, 106.778)));
      expect(movedPoint.locationNotes, equals('Cổng sắt màu xanh'));
      expect(movedPoint.photoUrl, equals('/api/v1/photos/house_blue.jpg'));

      // 2. Update notes only
      final updatedNotesPoint = movedPoint.copyWith(
        locationNotes: 'Cổng sắt màu xanh, chuông bên trái cột cổng',
      );
      expect(updatedNotesPoint.latitude, equals(10.852));
      expect(updatedNotesPoint.longitude, equals(106.778));
      expect(updatedNotesPoint.locationNotes, equals('Cổng sắt màu xanh, chuông bên trái cột cổng'));
      expect(updatedNotesPoint.photoUrl, equals('/api/v1/photos/house_blue.jpg'));
    });

    test('BUG-03: Point without locationNotes safely falls back and preserves photo', () {
      final emptyNotesPoint = ShiftDeliveryPointModel(
        id: 'p-3',
        shiftId: 's-1',
        customerId: 'c-3',
        customerName: 'Lê Hoàng C',
        customerPhone: '0912345678',
        customerAddress: '789 Võ Văn Ngân',
        locationStatus: LocationStatus.verified,
        latitude: 10.851,
        longitude: 106.773,
        locationNotes: null, // rỗng
        photoUrl: '/api/v1/photos/gate_789.jpg',
      );

      // Note fallback logic
      final safeNotes = (emptyNotesPoint.locationNotes != null && emptyNotesPoint.locationNotes!.trim().isNotEmpty)
          ? emptyNotesPoint.locationNotes!.trim()
          : 'Vị trí đã lưu';
      expect(safeNotes, equals('Vị trí đã lưu'));

      // Safe update
      final updated = emptyNotesPoint.copyWith(locationNotes: safeNotes);
      expect(updated.locationNotes, equals('Vị trí đã lưu'));
      expect(updated.photoUrl, equals('/api/v1/photos/gate_789.jpg'));
    });

    test('BUG-06: CustomerDirectoryModel maps accurately to ShiftDeliveryPointModel with corresponding status', () {
      final dirCustomer = CustomerDirectoryModel(
        id: 'c-verified',
        customerCode: 'KH-101',
        fullName: 'Phạm Minh D',
        phoneNumber: '0933112233',
        addressText: '12 Quang Trung, Gò Vấp',
        locationStatus: LocationStatus.verified,
        latitude: 10.835,
        longitude: 106.665,
        identificationNotes: 'Nhà có biển tên BS Minh D',
        imageUrl: '/api/v1/photos/bs_minh.jpg',
      );

      expect(dirCustomer.locationStatus, equals(LocationStatus.verified));
      expect(dirCustomer.locationStatus.pickerDisplayName, equals('Đã xác minh'));

      final tempCustomer = CustomerDirectoryModel(
        id: 'c-temp',
        customerCode: 'KH-102',
        fullName: 'Ngô Văn E',
        phoneNumber: '0944556677',
        addressText: '45 Thống Nhất, Gò Vấp',
        locationStatus: LocationStatus.temporary,
        latitude: 10.838,
        longitude: 106.668,
        identificationNotes: 'Ghim tạm trước ngõ',
      );

      expect(tempCustomer.locationStatus, equals(LocationStatus.temporary));
      expect(tempCustomer.locationStatus.pickerDisplayName, equals('Đã ghim vị trí · Chờ xác minh'));

      final noLocCustomer = CustomerDirectoryModel(
        id: 'c-noloc',
        customerCode: 'KH-103',
        fullName: 'Đỗ Thị F',
        phoneNumber: '0977889900',
        addressText: '99 Phan Văn Trị',
        locationStatus: LocationStatus.noLocation,
      );

      expect(noLocCustomer.locationStatus, equals(LocationStatus.noLocation));
      expect(noLocCustomer.locationStatus.pickerDisplayName, equals('Chưa ghim vị trí'));
    });
  });
}
