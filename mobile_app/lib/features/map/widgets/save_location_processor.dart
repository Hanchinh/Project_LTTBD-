// Bộ xử lý lưu trữ vị trí ghim và đồng bộ dữ liệu khách hàng sau khi xác nhận.
// Thực hiện ghi tọa độ vào SQLite, chụp ảnh thực địa và cập nhật trạng thái.
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:delivery_marker_mobile/data/repository_provider.dart';
import 'package:delivery_marker_mobile/core/theme/app_buttons.dart';

class SaveLocationProcessor {
  static Future<bool> processSaveLocation({
    required BuildContext context,
    required String phone,
    required String fullName,
    required String notes,
    required LatLng targetCoord,
    String? knownCustomerId,
  }) async {
    String? customerId = knownCustomerId;
    String customerDisplayName = fullName.isNotEmpty ? fullName : 'Khách $phone';
    bool isNewlyCreated = false;

    try {
      if (customerId == null) {
        // 1. Tra cứu khách hàng theo SĐT xem đã có trong CSDL chưa
        final lookup = await RepositoryProvider.customer.lookupCustomerLocationByPhone(phone);

        if (lookup != null && lookup['customer'] != null) {
          final cust = lookup['customer'] as Map<String, dynamic>;
          customerId = cust['id']?.toString() ?? '';
          customerDisplayName = cust['fullName']?.toString() ?? customerDisplayName;

          final hasOldLocation = lookup['hasSavedLocation'] == true;

          if (hasOldLocation) {
            if (!context.mounted) return false;
            final confirmReplace = await showDialog<bool>(
              context: context,
              builder: (dlgCtx) => AlertDialog(
                title: const Row(
                  children: [
                    Icon(Icons.help_outline_rounded, color: Color(0xFF2563EB)),
                    SizedBox(width: 8),
                    Text('Thay vị trí cũ bằng vị trí này?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ],
                ),
                content: Text(
                  'Khách hàng $customerDisplayName ($phone) đã có vị trí đã lưu trước đó.\n\n'
                  'Bạn có chắc muốn thay thế vị trí cũ bằng vị trí này không?\n'
                  '(Lịch sử vị trí cũ vẫn được lưu trữ đối soát đầy đủ).',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dlgCtx, false),
                    child: const Text('HỦY', style: TextStyle(color: Color(0xFF64748B))),
                  ),
                  ElevatedButton(
                    style: AppButtons.primary(),
                    onPressed: () => Navigator.pop(dlgCtx, true),
                    child: const Text('THAY VỊ TRÍ CŨ'),
                  ),
                ],
              ),
            );

            if (confirmReplace != true) {
              return false;
            }
          }
        } else {
          final preferredAreaId = await RepositoryProvider.profile.getPreferredAreaId();
          final newCust = await RepositoryProvider.customer.createCustomer(
            phoneNumber: phone,
            fullName: fullName.isNotEmpty ? fullName : null,
            areaId: preferredAreaId,
          );
          customerId = newCust.id;
          customerDisplayName = newCust.fullName;
          isNewlyCreated = true;
        }
      }

      await RepositoryProvider.location.updateCustomerLocationAndPhoto(
        customerId: customerId,
        latitude: targetCoord.latitude,
        longitude: targetCoord.longitude,
        gpsAccuracy: 0.0,
        identificationNotes: notes.isNotEmpty ? notes : 'Ghim trực tiếp từ Bản đồ chính',
      );

      if (!context.mounted) return true;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã ghim vị trí ĐÃ XÁC NHẬN cho $customerDisplayName!'),
          backgroundColor: const Color(0xFF10B981),
          duration: const Duration(seconds: 4),
        ),
      );
      return true;
    } catch (e) {
      if (!context.mounted) return false;

      if (isNewlyCreated || knownCustomerId != null) {
        final errText = 'Đã tạo khách $phone nhưng chưa lưu được vị trí, thử lại';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errText),
            backgroundColor: const Color(0xFFEF4444),
            duration: const Duration(seconds: 12),
            action: SnackBarAction(
              label: 'THỬ LẠI',
              textColor: Colors.white,
              onPressed: () {
                processSaveLocation(
                  context: context,
                  phone: phone,
                  fullName: fullName,
                  notes: notes,
                  targetCoord: targetCoord,
                  knownCustomerId: customerId,
                );
              },
            ),
          ),
        );

        await showDialog<void>(
          context: context,
          builder: (dlgCtx) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444)),
                SizedBox(width: 8),
                Expanded(
                  child: Text('Lưu vị trí không thành công', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            content: Text('$errText.\n\nChi tiết lỗi: $e'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dlgCtx),
                child: const Text('ĐÓNG', style: TextStyle(color: Color(0xFF64748B))),
              ),
              ElevatedButton.icon(
                style: AppButtons.primary(),
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('THỬ LẠI'),
                onPressed: () {
                  Navigator.pop(dlgCtx);
                  processSaveLocation(
                    context: context,
                    phone: phone,
                    fullName: fullName,
                    notes: notes,
                    targetCoord: targetCoord,
                    knownCustomerId: customerId,
                  );
                },
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi lưu vị trí: $e'),
            backgroundColor: const Color(0xFFEF4444),
            duration: const Duration(seconds: 4),
          ),
        );
      }
      return false;
    }
  }
}
