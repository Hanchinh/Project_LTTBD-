// Thành phần hiển thị một ảnh thu nhỏ (thumbnail) trong dải ảnh thực địa.
// Xử lý tải ảnh nhanh từ bộ nhớ máy và bắt sự kiện chạm để xem chi tiết.
import 'package:flutter/material.dart';
import 'package:delivery_marker_mobile/models/customer_photo_model.dart';
import 'package:delivery_marker_mobile/core/widgets/authenticated_image.dart';
import 'package:delivery_marker_mobile/features/photos/fullscreen_image_viewer.dart';

class PhotoStripItem extends StatelessWidget {
  final CustomerPhotoModel photo;
  final int index;
  final int totalPhotos;
  final String customerName;
  final List<String> allPhotoUrls;
  final bool canDeletePhoto;
  final VoidCallback onDelete;

  const PhotoStripItem({
    super.key,
    required this.photo,
    required this.index,
    required this.totalPhotos,
    required this.customerName,
    required this.allPhotoUrls,
    required this.canDeletePhoto,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final allowDelete = canDeletePhoto && photo.id != 'legacy';

    return Container(
      width: 130,
      margin: EdgeInsets.only(right: index == totalPhotos - 1 ? 0 : 8),
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
                FullscreenImageViewer.showGallery(
                  context,
                  photoUrls: allPhotoUrls,
                  initialIndex: index,
                  title: '$customerName (Ảnh ${index + 1}/$totalPhotos)',
                );
              },
              onLongPress: allowDelete ? onDelete : null,
              child: AuthenticatedImage(
                cacheWidth: 300,
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
                  '${index + 1}/$totalPhotos',
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            // Nút xóa ảnh góc trên phải (nếu cho phép xóa)
            if (allowDelete)
              Positioned(
                top: 0,
                right: 0,
                child: Tooltip(
                  message: 'Xóa ảnh này',
                  child: GestureDetector(
                    onTap: onDelete,
                    child: Container(
                      width: 48,
                      height: 48,
                      alignment: Alignment.center,
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
                ),
              ),
          ],
        ),
      ),
    );
  }
}

