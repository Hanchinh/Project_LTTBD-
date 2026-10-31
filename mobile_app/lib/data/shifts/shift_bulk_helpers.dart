import 'package:sqflite/sqflite.dart';
import 'package:delivery_marker_mobile/core/utils/phone_utils.dart';
import 'package:delivery_marker_mobile/core/utils/uuid_utils.dart';
import 'package:delivery_marker_mobile/core/utils/vietnamese_utils.dart';
import 'package:delivery_marker_mobile/data/database/app_database.dart';
import 'package:delivery_marker_mobile/models/shift_model.dart';

/// Helper thực thi thêm hàng loạt số điện thoại vào ca làm việc (Bulk Add Points)
class ShiftBulkHelpers {
  /// Thực thi thêm danh sách số điện thoại vào ca trong 1 Transaction duy nhất.
  /// Tự động phân loại 3 nhóm: Added (Thêm mới), AlreadyInShift (Đã có), Rejected (Sai định dạng).
  static Future<BulkAddPointsResult> executeBulkAdd({
    required Database db,
    required AppDatabase appDb,
    required String shiftId,
    String? rawText,
    List<String>? phones,
    required String defaultAreaId,
    required String defaultAreaName,
  }) async {
    String textToParse = '';
    if (rawText != null && rawText.isNotEmpty) {
      textToParse = rawText;
    } else if (phones != null && phones.isNotEmpty) {
      textToParse = phones.join('\n');
    }

    if (textToParse.trim().isEmpty) {
      return BulkAddPointsResult(
        added: [],
        alreadyInShift: [],
        rejected: [],
        summary: BulkAddSummary(),
      );
    }

    final parsed = parseAndNormalizeBulkPhones(rawText: textToParse);

    if (parsed.isExceededLimit) {
      throw ArgumentError(
        'Danh sách vượt quá giới hạn 200 số điện thoại (có ${parsed.totalCount} số). Vui lòng chia nhỏ danh sách.',
      );
    }

    return await db.transaction<BulkAddPointsResult>((txn) async {
      final shiftRows = await txn.query(
        'shifts',
        where: 'id = ?',
        whereArgs: [shiftId],
        limit: 1,
      );
      if (shiftRows.isEmpty) {
        throw Exception('Không tìm thấy ca làm việc');
      }

      final existingPoints = await txn.rawQuery('''
        SELECT 
          sdp.id, sdp.customer_id, sdp.location_status,
          c.phone_number, c.full_name
        FROM shift_delivery_points sdp
        JOIN customers c ON sdp.customer_id = c.id
        WHERE sdp.shift_id = ?
      ''', [shiftId]);

      final shiftPhonesMap = <String, Map<String, dynamic>>{};
      for (final p in existingPoints) {
        final phone = p['phone_number'] as String?;
        if (phone != null) {
          shiftPhonesMap[phone] = p;
        }
      }

      final maxIndexRows = await txn.rawQuery(
        'SELECT MAX(delivery_order_index) AS max_idx FROM shift_delivery_points WHERE shift_id = ?',
        [shiftId],
      );
      int currentOrderIndex = (maxIndexRows.first['max_idx'] as int?) ?? 0;

      final added = <ShiftDeliveryPointModel>[];
      final alreadyInShift = <AlreadyInShiftItem>[];
      final rejected = <RejectedPhoneItem>[];

      final nowIso = AppDatabase.currentIsoUtc();

      for (final item in parsed.items) {
        if (!item.isValid) {
          rejected.add(RejectedPhoneItem(
            phone: item.rawInput,
            reason: 'INVALID_FORMAT',
            message: 'Số điện thoại không đúng định dạng VN (10 chữ số)',
          ));
          continue;
        }

        final normPhone = item.normalizedPhone;

        if (shiftPhonesMap.containsKey(normPhone)) {
          final p = shiftPhonesMap[normPhone]!;
          alreadyInShift.add(AlreadyInShiftItem(
            phone: normPhone,
            pointId: p['id'] as String,
            customerId: p['customer_id'] as String,
            customerName: (p['full_name'] as String?) ?? '',
            locationStatus: (p['location_status'] as String?) ?? 'NO_LOCATION',
          ));
          continue;
        }

        final custRows = await txn.query(
          'customers',
          where: 'phone_number = ? AND deleted_at IS NULL',
          whereArgs: [normPhone],
          limit: 1,
        );

        String custId;
        String custName;
        String custAddress;
        if (custRows.isNotEmpty) {
          final c = custRows.first;
          custId = c['id'] as String;
          custName = (c['full_name'] as String?) ?? 'Khách $normPhone';
          custAddress = (c['address_text'] as String?) ?? 'Chưa cập nhật địa chỉ';
        } else {
          custId = UuidUtils.generate();
          custName = 'Khách $normPhone';
          custAddress = 'Chưa cập nhật địa chỉ';
          final searchText = buildCustomerSearchText(
            fullName: custName,
            phoneNumber: normPhone,
            addressText: custAddress,
          );
          await txn.insert('customers', {
            'id': custId,
            'customer_code': null,
            'full_name': custName,
            'phone_number': normPhone,
            'address_text': custAddress,
            'notes': null,
            'search_text': searchText,
            'created_at': nowIso,
            'updated_at': nowIso,
            'deleted_at': null,
          });
        }

        final savedLocRows = await txn.query(
          'saved_locations',
          where: 'customer_id = ?',
          whereArgs: [custId],
          limit: 1,
        );

        LocationStatus locStatus = LocationStatus.noLocation;
        double? lat;
        double? lng;
        double? gps;
        String? notes;
        if (savedLocRows.isNotEmpty) {
          final sl = savedLocRows.first;
          locStatus = LocationStatus.verified;
          lat = (sl['latitude'] as num?)?.toDouble();
          lng = (sl['longitude'] as num?)?.toDouble();
          gps = (sl['gps_accuracy'] as num?)?.toDouble();
          notes = sl['identification_notes'] as String?;
        }

        currentOrderIndex++;
        final pointId = UuidUtils.generate();

        await txn.insert('shift_delivery_points', {
          'id': pointId,
          'shift_id': shiftId,
          'customer_id': custId,
          'delivery_order_index': currentOrderIndex,
          'location_status': locStatus.toApiString(),
          'latitude': lat,
          'longitude': lng,
          'gps_accuracy': gps,
          'identification_notes': notes,
          'created_at': nowIso,
          'updated_at': nowIso,
        });

        final pointModel = ShiftDeliveryPointModel(
          id: pointId,
          shiftId: shiftId,
          customerId: custId,
          customerName: custName,
          customerPhone: normPhone,
          customerAddress: custAddress,
          areaId: defaultAreaId,
          areaName: defaultAreaName,
          sequenceNumber: currentOrderIndex,
          deliveryStatus: 'PENDING',
          locationStatus: locStatus,
          latitude: lat,
          longitude: lng,
          locationNotes: notes,
          createdAt: DateTime.tryParse(nowIso),
          updatedAt: DateTime.tryParse(nowIso),
        );

        added.add(pointModel);

        shiftPhonesMap[normPhone] = {
          'id': pointId,
          'customer_id': custId,
          'full_name': custName,
          'location_status': locStatus.toApiString(),
        };
      }

      final summary = BulkAddSummary(
        total: parsed.items.length,
        addedCount: added.length,
        alreadyInShiftCount: alreadyInShift.length,
        rejectedCount: rejected.length,
      );

      await appDb.logActivity(
        action: 'BULK_ADD_POINTS',
        entity: 'shifts',
        entityId: shiftId,
        details: {
          'total': summary.total,
          'addedCount': summary.addedCount,
          'alreadyInShiftCount': summary.alreadyInShiftCount,
          'rejectedCount': summary.rejectedCount,
        },
        executor: txn,
      );

      return BulkAddPointsResult(
        added: added,
        alreadyInShift: alreadyInShift,
        rejected: rejected,
        summary: summary,
      );
    });
  }
}

