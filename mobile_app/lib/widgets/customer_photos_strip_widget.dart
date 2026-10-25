import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/customer_photo_model.dart';
import '../services/api_service.dart';
import 'authenticated_image.dart';
import 'fullscreen_image_viewer.dart';

/// Widget dùng chung hiển thị dải nhiều ảnh khách hàng từ `customer_photos`
/// Sử dụng thống nhất tại:
/// 1. Danh bạ (CustomerDirectoryView)
/// 2. Hồ sơ khách hàng (CustomerDetailEditView)
/// 3. Thẻ điểm chi tiết (PointDetailBottomSheet) trên Bản đồ chính & Bản đồ ca
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
  final ImagePicker _picker = ImagePicker();
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
      _photos.add(
        CustomerPhotoModel(
          id: 'legacy',
          customerId: widget.customerId,
          imageUrl: widget.legacyImageUrl!.trim(),
        ),
      );
    }
  }

  Future<void> _loadPhotosFromApi() async {
    if (widget.customerId.isEmpty) return;
    setState(() => _isLoading = true);
    try {
      final remotePhotos = await ApiService.getCustomerPhotos(widget.customerId);
      if (mounted) {
        setState(() {
          _photos = remotePhotos;
          _isLoading = false;
        });
        widget.onPhotosUpdated?.call(_photos);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _showPhotoSourceSheet() async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Text(
                'Thêm ảnh mặt tiền nhà',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.camera_alt_rounded, color: Color(0xFF2563EB)),
                ),
                title: const Text('Chụp ảnh mới bằng Camera', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Chụp rõ số nhà, màu cổng, biển hiệu'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndUploadPhoto(ImageSource.camera);
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.photo_library_rounded, color: Color(0xFF475569)),
                ),
                title: const Text('Chọn từ Thư viện ảnh', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Tải ảnh có sẵn trong máy'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndUploadPhoto(ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickAndUploadPhoto(ImageSource source) async {
    try {
      final XFile? file = await _picker.pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 80,
      );

      if (file == null) return;

      setState(() => _isUploading = true);

      final bytes = await file.readAsBytes();
      final ext = file.name.split('.').last.toLowerCase();
      final mime = (ext == 'png') ? 'image/png' : (ext == 'webp' ? 'image/webp' : 'image/jpeg');
      final base64String = 'data:$mime;base64,${base64Encode(bytes)}';

      final newPhoto = await ApiService.addCustomerPhoto(widget.customerId, base64String);

      // Xóa cache ảnh để toàn bộ app nạp ảnh mới lập tức
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();

      if (!mounted) return;

      setState(() {
        _photos.insert(0, newPhoto);
        _isUploading = false;
      });

      widget.onPhotosUpdated?.call(_photos);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã tải ảnh lên thành công! Bác tài có thể chụp thêm.'),
          backgroundColor: Color(0xFF16A34A),
          duration: Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUploading = false);

      final errorMsg = e.toString().replaceAll('Exception:', '').trim();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  errorMsg.isNotEmpty ? errorMsg : 'Lỗi tải ảnh lên, vui lòng kiểm tra kết nối mạng!',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFFDC2626),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  Future<void> _confirmDeletePhoto(CustomerPhotoModel photo) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.delete_outline_rounded, color: Color(0xFFDC2626)),
            SizedBox(width: 8),
            Text('Xóa ảnh này?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: const Text(
          'Ảnh sẽ được gỡ khỏi hồ sơ khách hàng trên mọi màn hình.\n(Hệ thống vẫn bảo toàn lưu trữ đối soát đầy đủ).',
          style: TextStyle(fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dlgCtx, false),
            child: const Text('HỦY', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(dlgCtx, true),
            child: const Text('XÓA ẢNH', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await ApiService.deleteCustomerPhoto(widget.customerId, photo.id);

      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();

      if (!mounted) return;
      setState(() {
        _photos.removeWhere((p) => p.id == photo.id);
      });
      widget.onPhotosUpdated?.call(_photos);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã gỡ ảnh thành công'),
          backgroundColor: Color(0xFF16A34A),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final errorMsg = e.toString().replaceAll('Exception:', '').trim();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMsg.isNotEmpty ? errorMsg : 'Không thể xóa ảnh'),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: widget.padding,
      child: Container(
        height: widget.height,
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Stack(
          children: [
            if (_photos.isEmpty)
              _buildEmptySlot()
            else
              _buildPhotoList(),
            if (_isLoading)
              const Positioned(
                top: 0,
                left: 16,
                right: 16,
                child: ClipRRect(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                  child: LinearProgressIndicator(minHeight: 2.5, color: Color(0xFF2563EB)),
                ),
              ),
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
            ? const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Color(0xFF2563EB)),
                  SizedBox(height: 8),
                  Text('Đang nén & tải ảnh lên...', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_a_photo_outlined, size: 20, color: Color(0xFF64748B)),
                      SizedBox(width: 6),
                      Text(
                        'Chưa có ảnh - Thêm ảnh',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF475569),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (widget.canAddPhoto)
                    _buildAddPhotoButton(compact: false),
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
        if (widget.canAddPhoto && idx == 0) {
          return _buildAddPhotoButton(compact: true);
        }

        final photoIndex = widget.canAddPhoto ? idx - 1 : idx;
        final photo = _photos[photoIndex];
        return _buildPhotoItem(photo, photoIndex);
      },
    );
  }

  /// Nút "+ THÊM ẢNH" lớn >= 56px dùng chung
  Widget _buildAddPhotoButton({required bool compact}) {
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
          onTap: _isUploading ? null : _showPhotoSourceSheet,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_isUploading)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                else ...[
                  const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 22),
                  const SizedBox(width: 6),
                  const Text(
                    '+ THÊM ẢNH',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoItem(CustomerPhotoModel photo, int index) {
    return Container(
      width: 130,
      margin: EdgeInsets.only(right: index == _photos.length - 1 && !widget.canAddPhoto ? 0 : 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFCBD5E1)),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          fit: StackFit.expand,
          children: [
            GestureDetector(
              onTap: () {
                FullscreenImageViewer.show(
                  context,
                  photoUrl: photo.imageUrl,
                  title: '${widget.customerName} (Ảnh ${index + 1}/${_photos.length})',
                );
              },
              onLongPress: widget.canDeletePhoto && photo.id != 'legacy' ? () => _confirmDeletePhoto(photo) : null,
              child: AuthenticatedImage(
                photoUrl: photo.imageUrl,
                fit: BoxFit.cover,
                errorWidget: Container(
                  color: const Color(0xFFF1F5F9),
                  child: const Center(
                    child: Icon(Icons.broken_image_rounded, color: Color(0xFF94A3B8)),
                  ),
                ),
              ),
            ),
            // Số thứ tự ảnh góc trên trái
            Positioned(
              top: 6,
              left: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${index + 1}/${_photos.length}',
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            // Nút xóa ảnh góc trên phải (nếu cho phép xóa)
            if (widget.canDeletePhoto && photo.id != 'legacy')
              Positioned(
                top: 4,
                right: 4,
                child: GestureDetector(
                  onTap: () => _confirmDeletePhoto(photo),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close_rounded, color: Colors.white, size: 14),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
