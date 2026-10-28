import 'package:delivery_marker_mobile/core/utils/phone_utils.dart';
import 'package:delivery_marker_mobile/core/utils/uuid_utils.dart';
import 'package:delivery_marker_mobile/core/utils/vietnamese_utils.dart';
import 'package:delivery_marker_mobile/data/local/app_database.dart';
import 'package:delivery_marker_mobile/data/local/local_customer_repository.dart';
import 'package:delivery_marker_mobile/models/customer_model.dart';
import 'package:delivery_marker_mobile/models/shift_model.dart';

/// Helper thực thi thêm khách hàng hàng loạt từ văn bản hoặc danh sách SĐT trong một Transaction SQLite duy nhất
class CustomerBulkHelpers {
  static Future<BulkCreateCustomersResult> executeBulkCreate({
    required AppDatabase appDb,
    String? rawText,
    List<String>? phones,
    String? areaId,
    String defaultAreaId = LocalCustomerRepository.defaultAreaId,
  }) async {
    final parsed = parseAndNormalizeBulkPhones(rawText: rawText, phones: phones);
    if (parsed.items.isEmpty) throw ArgumentError('Không tìm thấy số điện thoại nào trong dữ liệu gửi lên');
    if (parsed.uniquePhones.length > 200) {
      throw ArgumentError('Vượt quá giới hạn tối đa 200 số điện thoại cho mỗi lần thêm hàng loạt (nhận được ${parsed.uniquePhones.length} số)');
    }

    return await appDb.transaction<BulkCreateCustomersResult>((txn) async {
      final created = <BulkCustomerItem>[];
      final alreadyExists = <BulkCustomerItem>[];
      final rejected = parsed.items
          .where((it) => !it.isValid)
          .map((it) => RejectedPhoneItem(
                phone: it.original,
                reason: 'INVALID_FORMAT',
                message: it.reason ?? 'Số điện thoại không đúng định dạng (cần 10 chữ số hợp lệ)',
              ))
          .toList();

      final now = AppDatabase.currentIsoUtc();

      for (final phone in parsed.uniquePhones) {
        final exRows = await txn.query('customers', where: 'phone_number = ? AND deleted_at IS NULL', whereArgs: [phone], limit: 1);
        if (exRows.isNotEmpty) {
          final row = exRows.first;
          final cid = row['id'] as String;
          final locs = await txn.query('saved_locations', where: 'customer_id = ?', whereArgs: [cid], limit: 1);
          alreadyExists.add(BulkCustomerItem(
            id: cid,
            customerCode: (row['customer_code'] as String?) ?? 'CUST',
            phoneNumber: phone,
            fullName: (row['full_name'] as String?) ?? '',
            addressText: (row['address_text'] as String?) ?? '',
            areaId: defaultAreaId,
            locationState: locs.isNotEmpty ? LocationStatus.verified : LocationStatus.noLocation,
          ));
        } else {
          final newId = UuidUtils.generate();
          final name = 'Khách $phone';
          const addr = 'Chưa cập nhật địa chỉ';
          final custCode = 'CUST-${phone.substring(phone.length - 4)}';
          final searchText = buildCustomerSearchText(fullName: name, phoneNumber: phone, addressText: addr);

          await txn.insert('customers', {
            'id': newId,
            'customer_code': custCode,
            'full_name': name,
            'phone_number': phone,
            'address_text': addr,
            'search_text': searchText,
            'created_at': now,
            'updated_at': now,
          });

          created.add(BulkCustomerItem(
            id: newId,
            customerCode: custCode,
            phoneNumber: phone,
            fullName: name,
            addressText: addr,
            areaId: defaultAreaId,
            locationState: LocationStatus.noLocation,
          ));
        }
      }

      await appDb.logActivity(
        executor: txn,
        action: 'BULK_CREATE_CUSTOMERS',
        entity: 'CUSTOMERS',
        details: {'total': parsed.items.length, 'created': created.length, 'alreadyExists': alreadyExists.length, 'rejected': rejected.length},
      );

      return BulkCreateCustomersResult(
        created: created,
        alreadyExists: alreadyExists,
        rejected: rejected,
        total: parsed.items.length,
        createdCount: created.length,
        alreadyExistsCount: alreadyExists.length,
        rejectedCount: rejected.length,
      );
    });
  }
}
