import 'dart:typed_data';
import 'package:image/image.dart' as img;

/// Kết quả nén ảnh và tạo thumbnail trong luồng riêng Isolate
class CompressedImageData {
  final Uint8List fullBytes;
  final Uint8List thumbBytes;

  CompressedImageData({required this.fullBytes, required this.thumbBytes});
}

/// Nén cạnh dài <= 1600px chất lượng ~80 và tạo thumbnail ~300px chạy trong Isolate riêng (compute)
CompressedImageData compressAndGenerateThumbnailTask(Uint8List rawBytes) {
  final image = img.decodeImage(rawBytes);
  if (image == null) {
    // Nếu không decode được bằng package:image (ví dụ file giả lập trong unit test),
    // giữ nguyên rawBytes để bảo toàn dữ liệu kiểm thử
    return CompressedImageData(fullBytes: rawBytes, thumbBytes: rawBytes);
  }

  // 1. Cạnh dài <= 1600px, chất lượng ~80
  img.Image fullImage = image;
  if (image.width > 1600 || image.height > 1600) {
    if (image.width >= image.height) {
      fullImage = img.copyResize(image, width: 1600);
    } else {
      fullImage = img.copyResize(image, height: 1600);
    }
  }
  final fullJpg = Uint8List.fromList(img.encodeJpg(fullImage, quality: 80));

  // 2. Thumbnail cạnh dài ~300px
  img.Image thumbImage = fullImage;
  if (fullImage.width > 300 || fullImage.height > 300) {
    if (fullImage.width >= fullImage.height) {
      thumbImage = img.copyResize(fullImage, width: 300);
    } else {
      thumbImage = img.copyResize(fullImage, height: 300);
    }
  }
  final thumbJpg = Uint8List.fromList(img.encodeJpg(thumbImage, quality: 75));

  return CompressedImageData(fullBytes: fullJpg, thumbBytes: thumbJpg);
}

