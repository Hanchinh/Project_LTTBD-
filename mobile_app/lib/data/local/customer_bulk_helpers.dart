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

    if (parsed.items.isEmpty) {
      throw ArgumentError('Không tìm thấy số điện thoại nào trong dữ liệu gửi lên');
    }

    if (parsed.uniquePhones.length > 200) {
      throw ArgumentError(
        'Vượt quá giới hạn tối đa 200 số điện thoại cho mỗi lần thêm hàng loạt (nhận được ${parsed.uniquePhones.length} số)',
      );
    }

    return await appDb.transaction<BulkCreateCustomersResult>((txn) async {
      final created = <BulkCustomerItem>[];
      final alreadyExists = <BulkCustomerItem>[];
      final rejected = <RejectedPhoneItem>[];

      // Đưa các số sai định dạng vào rejected
      for (final item in parsed.items) {
        if (!item.isValid) {
          rejected.add(RejectedPhoneItem(
            phone: item.original,
            reason: 'INVALID_FORMAT',
            message: item.reason ?? 'Số điện thoại không đúng định dạng (cần 10 chữ số hợp lệ)',
          ));
        }
      }

      final now = AppDatabase.currentIsoUtc();

      for (final phone in parsed.uniquePhones) {
        final existingRows = await txn.query(
          'customers',
          where: 'phone_number = ? AND deleted_at IS NULL',
          whereArgs: [phone],
          limit: 1,
        );

        if (existingRows.isNotEmpty) {
          final row = existingRows.first;
          final custId = row['id'] as String;

          // Kiểm tra vị trí để gán locationState
          final locRows = await txn.query(
            'saved_locations',
            where: 'customer_id = ?',
            whereArgs: [custId],
            limit: 1,
          );

          LocationStatus locState = locRows.isNotEmpty ? LocationStatus.verified : LocationStatus.noLocation;

          alreadyExists.add(BulkCustomerItem(
            id: custId,
            customerCode: (row['customer_code'] as String?) ?? 'CUST',
            phoneNumber: phone,
            fullName: (row['full_name'] as String?) ?? '',
            addressText: (row['address_text'] as String?) ?? '',
            areaId: defaultAreaId,
            locationState: locState,
          ));
        } else {
          final newId = UuidUtils.generate();
          final displayName = 'Khách $phone';
          const displayAddress = 'Chưa cập nhật địa chỉ';
          final custCode = 'CUST-${phone.substring(phone.length - 4)}';
          final searchText = buildCustomerSearchText(
            fullName: displayName,
            phoneNumber: phone,
            addressText: displayAddress,
          );

          await txn.insert('customers', {
            'id': newId,
            'customer_code': custCode,
            'full_name': displayName,
            'phone_number': phone,
            'address_text': displayAddress,
            'notes': null,
            'search_text': searchText,
            'created_at': now,
            'updated_at': now,
            'deleted_at': null,
          });

          created.add(BulkCustomerItem(
            id: newId,
            customerCode: custCode,
            phoneNumber: phone,
            fullName: displayName,
            addressText: displayAddress,
            areaId: defaultAreaId,
            locationState: LocationStatus.noLocation,
          ));
        }
      }

      // Ghi nhật ký activity_log cho cả lô
      await appDb.logActivity(
        executor: txn,
        action: 'BULK_CREATE_CUSTOMERS',
        entity: 'CUSTOMERS',
        details: {
          'total': parsed.items.length,
          'created': created.length,
          'alreadyExists': alreadyExists.length,
          'rejected': rejected.length,
        },
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

