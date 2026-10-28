import 'package:flutter/material.dart';
import 'package:delivery_marker_mobile/models/customer_model.dart';
import 'package:delivery_marker_mobile/models/shift_model.dart';
import 'package:delivery_marker_mobile/data/repositories/repository_provider.dart';
import 'package:delivery_marker_mobile/features/directory/widgets/customer_detail_location_card.dart';
import 'package:delivery_marker_mobile/features/photos/customer_photos_strip_widget.dart';
import 'package:delivery_marker_mobile/features/sharing/data_share_send_sheet.dart';
import 'package:delivery_marker_mobile/features/map/crosshair_location_picker_view.dart';

class CustomerDetailEditView extends StatefulWidget {
  final CustomerDirectoryModel customer;
  final Function(CustomerDirectoryModel)? onCustomerUpdated;

  const CustomerDetailEditView({super.key, required this.customer, this.onCustomerUpdated});

  @override
  State<CustomerDetailEditView> createState() => _CustomerDetailEditViewState();
}

class _CustomerDetailEditViewState extends State<CustomerDetailEditView> {
  late CustomerDirectoryModel _customer;
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _notesController = TextEditingController();

  double? _currentLat;
  double? _currentLng;
  String? _currentPhotoUrl;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _customer = widget.customer;
    _nameController.text = _customer.fullName;
    _phoneController.text = _customer.phoneNumber;
    _addressController.text = _customer.addressText;
    _notesController.text = _customer.identificationNotes ?? '';
    _currentLat = _customer.latitude;
    _currentLng = _customer.longitude;
    _currentPhotoUrl = _customer.imageUrl;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _confirmAndDeleteLocation() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận xóa vị trí đã lưu?'),
        content: Text('Vị trí cổng nhà đã lưu của khách hàng "${_nameController.text.trim()}" sẽ bị xóa khỏi hồ sơ hệ thống.\n\nCác điểm giao trong ca đang chạy của khách này sẽ quay về trạng thái "Chưa có vị trí".\n\nLịch sử đối soát trước đây vẫn được lưu trữ an toàn trong hệ thống.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444), foregroundColor: Colors.white), onPressed: () => Navigator.pop(ctx, true), child: const Text('Xóa vị trí')),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _isSaving = true);
    try {
      await RepositoryProvider.location.deleteCustomerLocation(_customer.id);
      setState(() { _currentLat = null; _currentLng = null; _currentPhotoUrl = null; });
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã xóa vị trí đã lưu thành công (lịch sử đối soát được bảo toàn)'), backgroundColor: Color(0xFF10B981)));
      final updated = await RepositoryProvider.customer.getCustomerDetail(_customer.id);
      widget.onCustomerUpdated?.call(updated);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e'), backgroundColor: const Color(0xFFEF4444)));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _openCrosshairPicker() async {
    final dummy = ShiftDeliveryPointModel(
      id: 'dir-${_customer.id}',
      shiftId: '',
      customerId: _customer.id,
      customerName: _nameController.text.trim(),
      customerPhone: _phoneController.text.trim(),
      customerAddress: _addressController.text.trim(),
      locationStatus: _customer.locationStatus,
      latitude: _currentLat,
      longitude: _currentLng,
      locationNotes: _notesController.text.trim(),
    );
    final res = await Navigator.push<CrosshairLocationPickerResult>(
      context,
      MaterialPageRoute(builder: (_) => CrosshairLocationPickerView(point: dummy, shiftId: '')),
    );
    if (res != null) setState(() { _currentLat = res.latitude; _currentLng = res.longitude; });
  }

  Future<void> _handleSave() async {
    final name = _nameController.text.trim(), phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Số điện thoại không được để trống'), backgroundColor: Colors.red));
      return;
    }
    setState(() => _isSaving = true);
    try {
      await RepositoryProvider.customer.updateCustomer(customerId: _customer.id, fullName: name, phoneNumber: phone, addressText: _addressController.text.trim());
      if (_currentLat != null && _currentLng != null) {
        final notes = _notesController.text.trim();
        await RepositoryProvider.location.updateCustomerLocationAndPhoto(
          customerId: _customer.id,
          latitude: _currentLat!,
          longitude: _currentLng!,
          identificationNotes: notes.isNotEmpty ? notes : 'Vị trí đã lưu',
        );
        PaintingBinding.instance.imageCache.clear();
        PaintingBinding.instance.imageCache.clearLiveImages();
      }
      final updated = await RepositoryProvider.customer.getCustomerDetail(_customer.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã cập nhật hồ sơ khách hàng thành công!'), backgroundColor: Color(0xFF10B981)));
      widget.onCustomerUpdated?.call(updated);
      Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi lưu: $e'), backgroundColor: const Color(0xFFEF4444)));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: colorScheme.onSurface),
          tooltip: 'Quay lại',
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Hồ sơ & Vị trí khách hàng',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18, color: colorScheme.onSurface),
        ),
        actions: [
          IconButton(
            key: const Key('btn_share_customer_detail'),
            icon: Icon(Icons.share_outlined, color: colorScheme.onSurface),
            tooltip: 'Chia sẻ điểm này',
            onPressed: () => DataShareSendSheet.show(
              context,
              initialCustomerIds: [_customer.id],
              singleCustomerName: _nameController.text.trim().isNotEmpty ? _nameController.text.trim() : _customer.fullName,
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: theme.dividerTheme.color ?? const Color(0xFFE2E8F0)),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.dividerTheme.color ?? const Color(0xFFE2E8F0)),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Icon(Icons.photo_camera_rounded, size: 20, color: Color(0xFF2563EB)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Ảnh mặt tiền / cổng nhà',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: colorScheme.onSurface),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Tối đa 10 ảnh',
                        style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  CustomerPhotosStripWidget(
                    customerId: _customer.id,
                    customerName: _customer.fullName,
                    initialPhotos: _customer.photos,
                    legacyImageUrl: _customer.imageUrl,
                    height: 145,
                    canAddPhoto: true,
                    canDeletePhoto: true,
                    onPhotosUpdated: (photos) {
                      setState(() {
                        _currentPhotoUrl = photos.isNotEmpty ? photos.first.imageUrl : null;
                        _customer = _customer.copyWith(photos: photos, photoCount: photos.length, imageUrl: _currentPhotoUrl);
                      });
                      widget.onCustomerUpdated?.call(_customer);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Container(
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.dividerTheme.color ?? const Color(0xFFE2E8F0)),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('THÔNG TIN LIÊN HỆ', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: colorScheme.onSurface)),
                  const SizedBox(height: 12),
                  Text('TÊN KHÁCH HÀNG', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 6),
                  TextField(controller: _nameController, decoration: _inputDeco(context)),
                  const SizedBox(height: 12),
                  Text('SỐ ĐIỆN THOẠI *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 6),
                  TextField(controller: _phoneController, keyboardType: TextInputType.phone, decoration: _inputDeco(context)),
                  const SizedBox(height: 12),
                  Text('ĐỊA CHỈ KHÁCH HÀNG', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 6),
                  TextField(controller: _addressController, maxLines: 2, decoration: _inputDeco(context)),
                ],
              ),
            ),
            const SizedBox(height: 14),
            CustomerDetailLocationCard(
              latitude: _currentLat,
              longitude: _currentLng,
              notesController: _notesController,
              isSaving: _isSaving,
              onPickOnMap: _openCrosshairPicker,
              onDeleteLocation: _confirmAndDeleteLocation,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: _isSaving
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.save_rounded, size: 20),
                label: Text(
                  _isSaving ? 'ĐANG LƯU HỒ SƠ...' : 'LƯU TẤT CẢ THAY ĐỔI',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
                onPressed: _isSaving ? null : _handleSave,
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDeco(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return InputDecoration(
      filled: true,
      fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: theme.dividerTheme.color ?? const Color(0xFFCBD5E1)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: theme.dividerTheme.color ?? const Color(0xFFCBD5E1)),
      ),
    );
  }
}
