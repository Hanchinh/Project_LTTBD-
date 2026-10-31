// Widget dải ảnh ngang hiển thị các góc chụp thực địa mặt tiền nhà khách hàng.
// Hỗ trợ chụp ảnh trực tiếp từ camera, chọn ảnh từ thư viện và mở xem phóng to.
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:delivery_marker_mobile/models/customer_photo_model.dart';
import 'package:delivery_marker_mobile/data/repository_provider.dart';
import 'package:delivery_marker_mobile/features/photos/photo_strip_item.dart';

class CustomerPhotosStripWidget extends StatefulWidget {
  final String customerId;
  final String customerName;
  final List<CustomerPhotoModel> initialPhotos;
  final String? legacyImageUrl;
  final ValueChanged<List<CustomerPhotoModel>>? onPhotosUpdated;
  final bool canAddPhoto;
  final bool canDeletePhoto;
  final double height;
  final EdgeInsetsGeometry padding;

  const CustomerPhotosStripWidget({
    super.key,
    required this.customerId,
    this.customerName = 'Khách hàng',
    this.initialPhotos = const [],
    this.legacyImageUrl,
    this.onPhotosUpdated,
    this.canAddPhoto = true,
    this.canDeletePhoto = true,
    this.height = 140,
    this.padding = EdgeInsets.zero,
  });

  @override
  State<CustomerPhotosStripWidget> createState() => _CustomerPhotosStripWidgetState();
}

class _CustomerPhotosStripWidgetState extends State<CustomerPhotosStripWidget> {
  final _picker = ImagePicker();
  List<CustomerPhotoModel> _photos = [];
  bool _isLoading = false;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _initPhotos();
    _loadPhotosFromApi();
  }

  @override
  void didUpdateWidget(covariant CustomerPhotosStripWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.customerId != widget.customerId) {
      _initPhotos();
      _loadPhotosFromApi();
    }
  }

  void _initPhotos() {
    _photos = List.from(widget.initialPhotos);
    if (_photos.isEmpty && widget.legacyImageUrl != null && widget.legacyImageUrl!.trim().isNotEmpty) {
      _photos.add(CustomerPhotoModel(id: 'legacy', customerId: widget.customerId, imageUrl: widget.legacyImageUrl!.trim()));
    }
  }

  Future<void> _loadPhotosFromApi() async {
    if (widget.customerId.isEmpty) return;
    setState(() => _isLoading = true);
    try {
      final remote = await RepositoryProvider.photo.getCustomerPhotos(widget.customerId);
      if (mounted) {
        setState(() { _photos = remote; _isLoading = false; });
        widget.onPhotosUpdated?.call(_photos);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showPhotoSourceSheet() async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 12), decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2))),
              const Text('Thêm ảnh mặt tiền nhà', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
              const SizedBox(height: 16),
              ListTile(
                leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.camera_alt_rounded, color: Color(0xFF2563EB))),
                title: const Text('Chụp ảnh mới bằng Camera', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Chụp rõ số nhà, màu cổng, biển hiệu'),
                onTap: () { Navigator.pop(ctx); _pickAndUploadPhoto(ImageSource.camera); },
              ),
              const Divider(height: 1),
              ListTile(
                leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.photo_library_rounded, color: Color(0xFF475569))),
                title: const Text('Chọn từ Thư viện ảnh', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Tải ảnh có sẵn trong máy'),
                onTap: () { Navigator.pop(ctx); _pickAndUploadPhoto(ImageSource.gallery); },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickAndUploadPhoto(ImageSource source) async {
    try {
      final file = await _picker.pickImage(source: source, maxWidth: 1600, maxHeight: 1600, imageQuality: 80);
      if (file == null) return;
      setState(() => _isUploading = true);

      final bytes = await file.readAsBytes();
      final ext = file.name.split('.').last.toLowerCase();
      final mime = (ext == 'png') ? 'image/png' : (ext == 'webp' ? 'image/webp' : 'image/jpeg');
      final newPhoto = await RepositoryProvider.photo.addCustomerPhoto(widget.customerId, 'data:$mime;base64,${base64Encode(bytes)}');

      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
      if (!mounted) return;
      setState(() { _photos.insert(0, newPhoto); _isUploading = false; });
      widget.onPhotosUpdated?.call(_photos);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã tải ảnh lên thành công! Bác tài có thể chụp thêm.'), backgroundColor: Color(0xFF16A34A), duration: Duration(seconds: 3)));
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUploading = false);
      final msg = e.toString().replaceAll('Exception:', '').trim();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg.isNotEmpty ? msg : 'Lỗi tải ảnh lên!'), backgroundColor: const Color(0xFFDC2626)));
    }
  }

  Future<void> _confirmDeletePhoto(CustomerPhotoModel photo) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [Icon(Icons.delete_outline_rounded, color: Color(0xFFDC2626)), SizedBox(width: 8), Text('Xóa ảnh này?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18))]),
        content: const Text('Ảnh sẽ được gỡ khỏi hồ sơ khách hàng trên mọi màn hình.\n(Hệ thống vẫn bảo toàn lưu trữ đối soát đầy đủ).', style: TextStyle(fontSize: 14, height: 1.4)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dlgCtx, false), child: const Text('HỦY', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold))),
          ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626), foregroundColor: Colors.white), onPressed: () => Navigator.pop(dlgCtx, true), child: const Text('XÓA ẢNH', style: TextStyle(fontWeight: FontWeight.bold))),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await RepositoryProvider.photo.deleteCustomerPhoto(widget.customerId, photo.id);
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
      if (!mounted) return;
      setState(() => _photos.removeWhere((p) => p.id == photo.id));
      widget.onPhotosUpdated?.call(_photos);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã gỡ ảnh thành công'), backgroundColor: Color(0xFF16A34A)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceAll('Exception:', '').trim()), backgroundColor: const Color(0xFFDC2626)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: widget.padding,
      child: Container(
        height: widget.height,
        width: double.infinity,
        decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE2E8F0))),
        child: Stack(
          children: [
            _photos.isEmpty ? _buildEmptySlot() : _buildPhotoList(),
            if (_isLoading)
              const Positioned(top: 0, left: 16, right: 16, child: ClipRRect(borderRadius: BorderRadius.vertical(top: Radius.circular(16)), child: LinearProgressIndicator(minHeight: 2.5, color: Color(0xFF2563EB)))),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptySlot() {
    return Container(
      key: const ValueKey('empty_photo_slot'),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Center(
        child: _isUploading
            ? const Column(mainAxisSize: MainAxisSize.min, children: [CircularProgressIndicator(color: Color(0xFF2563EB)), SizedBox(height: 8), Text('Đang nén & tải ảnh lên...', style: TextStyle(fontSize: 12, color: Color(0xFF64748B)))])
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.add_a_photo_outlined, size: 20, color: Color(0xFF64748B)), SizedBox(width: 6), Flexible(child: Text('Chưa có ảnh - Thêm ảnh', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF475569)), maxLines: 1, overflow: TextOverflow.ellipsis))]),
                  const SizedBox(height: 10),
                  if (widget.canAddPhoto) _buildAddButton(compact: false),
                ],
              ),
      ),
    );
  }

  Widget _buildPhotoList() {
    return ListView.separated(
      key: const ValueKey('customer_photos_list_view'),
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      itemCount: _photos.length + (widget.canAddPhoto ? 1 : 0),
      separatorBuilder: (_, __) => const SizedBox(width: 10),
      itemBuilder: (ctx, idx) {
        if (widget.canAddPhoto && idx == 0) return _buildAddButton(compact: true);
        final pIdx = widget.canAddPhoto ? idx - 1 : idx;
        final photo = _photos[pIdx];
        return PhotoStripItem(
          photo: photo,
          index: pIdx,
          totalPhotos: _photos.length,
          customerName: widget.customerName,
          allPhotoUrls: _photos.map((p) => p.imageUrl).toList(),
          canDeletePhoto: widget.canDeletePhoto,
          onDelete: () => _confirmDeletePhoto(photo),
        );
      },
    );
  }

  Widget _buildAddButton({required bool compact}) {
    return Container(
      key: const ValueKey('btn_add_photo'),
      height: 56,
      constraints: const BoxConstraints(minHeight: 56),
      child: Material(
        color: const Color(0xFF2563EB),
        borderRadius: BorderRadius.circular(12),
        elevation: 2,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: _isUploading ? null : () => _pickAndUploadPhoto(ImageSource.camera),
          onLongPress: _isUploading ? null : _showPhotoSourceSheet,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_isUploading)
                  const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                else ...[
                  const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 22),
                  const SizedBox(width: 6),
                  const Flexible(child: Text('+ THÊM ẢNH', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
