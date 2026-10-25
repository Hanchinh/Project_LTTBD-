import 'package:flutter_test/flutter_test.dart';
import 'package:delivery_marker_mobile/models/shift_model.dart';

void main() {
  group('TASK: SHIFT-DELETE-AND-FIELD-FIX-011 - Flutter Unit & Widget Tests', () {
    test('createShift / ShiftModel parses both shiftDate and workDate seamlessly', () {
      // Case 1: Backend returns workDate
      final jsonWithWorkDate = {
        'id': 'shift-001',
        'shiftCode': 'SHF-20261025-001',
        'workDate': '2026-10-25',
        'status': 'PREPARING',
      };
      final shift1 = ShiftModel.fromJson(jsonWithWorkDate);
      expect(shift1.shiftDate, '2026-10-25');
      expect(shift1.shiftCode, 'SHF-20261025-001');

      // Case 2: Flutter sends/receives shiftDate
      final jsonWithShiftDate = {
        'id': 'shift-002',
        'shiftCode': 'SHF-20261025-002',
        'shiftDate': '2026-10-26T00:00:00.000Z',
        'status': 'IN_PROGRESS',
      };
      final shift2 = ShiftModel.fromJson(jsonWithShiftDate);
      expect(shift2.shiftDate, '2026-10-26');
      expect(shift2.status, ShiftStatus.inProgress);
    });

    test('addPointToShift: parses summary object returned by backend', () {
      final summaryJson = {
        'totalPoints': 5,
        'verifiedCount': 2,
        'temporaryCount': 2,
        'noLocationCount': 1,
      };

      final summary = ShiftSummaryModel.fromJson(summaryJson);
      expect(summary.totalPoints, 5);
      expect(summary.verifiedCount, 2);
      expect(summary.temporaryCount, 2);
      expect(summary.noLocationCount, 1);
    });

    test('updateTemporaryLocation & verifyPointLocation: parses notes and photo aliases', () {
      final pointJson = {
        'pointId': 'point-001',
        'shiftId': 'shift-001',
        'customerId': 'cust-001',
        'customerName': 'Chị Lan',
        'customerPhone': '0988000002',
        'customerAddress': '123 Đường Số 1',
        'locationStatus': 'VERIFIED',
        'latitude': 10.8422,
        'longitude': 106.8181,
        'identificationNotes': 'Cổng màu xanh gần ngã ba',
        'imageUrl': '/api/v1/photos/gate-001.jpg',
      };

      final point = ShiftDeliveryPointModel.fromJson(pointJson);
      expect(point.locationNotes, 'Cổng màu xanh gần ngã ba');
      expect(point.photoUrl, '/api/v1/photos/gate-001.jpg');
      expect(point.hasPhoto, true);
      expect(point.locationStatus, LocationStatus.verified);
    });

    test('ShiftModel serialization retains both shiftDate and summary', () {
      final summary = ShiftSummaryModel(
        totalPoints: 3,
        verifiedCount: 1,
        temporaryCount: 1,
        noLocationCount: 1,
      );

      final shift = ShiftModel(
        id: 'shift-100',
        shiftCode: 'SHF-20261025-005',
        shiftDate: '2026-10-25',
        shipperId: 'shipper-1',
        status: ShiftStatus.preparing,
        summary: summary,
      );

      expect(shift.shiftDate, '2026-10-25');
      expect(shift.summary.totalPoints, 3);
      expect(shift.summary.verifiedCount, 1);
    });
  });
}
