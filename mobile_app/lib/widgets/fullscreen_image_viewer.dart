import 'package:flutter/material.dart';
import '../services/api_service.dart';

class FullscreenImageViewer extends StatelessWidget {
  final String photoUrl;
  final String? title;
  final int? cacheVersion;

  const FullscreenImageViewer({
    super.key,
    required this.photoUrl,
    this.title,
    this.cacheVersion,
  });

  static void show(
    BuildContext context, {
    required String photoUrl,
    String? title,
    int? cacheVersion,
  }) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black87,
        barrierDismissible: true,
        pageBuilder: (ctx, anim1, anim2) => FullscreenImageViewer(
          photoUrl: photoUrl,
          title: title,
          cacheVersion: cacheVersion,
        ),
        transitionsBuilder: (ctx, anim, _, child) {
          return FadeTransition(opacity: anim, child: child);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: 0.95),
      body: SafeArea(
        child: Stack(
          children: [
            // Interactive viewer for pinch-to-zoom
            Center(
              child: FutureBuilder<Map<String, String>>(
                future: ApiService.getPhotoAuthInfo(
                  photoUrl,
                  cacheVersion: cacheVersion,
                  bustCache: cacheVersion == null,
                ),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    );
                  }

                  if (!snapshot.hasData || snapshot.hasError) {
                    return const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.broken_image_rounded, color: Colors.white60, size: 48),
                        SizedBox(height: 12),
                        Text(
                          'Không thể tải ảnh thực tế',
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                      ],
                    );
                  }

                  final photoInfo = snapshot.data!;
                  final url = photoInfo['url']!;
                  final token = photoInfo['token'];

                  return InteractiveViewer(
                    minScale: 0.8,
                    maxScale: 5.0,
                    child: Image.network(
                      url,
                      headers: {
                        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
                      },
                      fit: BoxFit.contain,
                      loadingBuilder: (ctx, child, progress) {
                        if (progress == null) return child;
                        return const Center(
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        );
                      },
                      errorBuilder: (ctx, err, stack) => const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.broken_image_rounded, color: Colors.white60, size: 48),
                          SizedBox(height: 12),
                          Text(
                            'Lỗi hiển thị tệp ảnh',
                            style: TextStyle(color: Colors.white70, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            // Top Bar with title and Close Button
            Positioned(
              top: 10,
              left: 16,
              right: 16,
              child: Row(
                children: [
                  if (title != null && title!.isNotEmpty)
                    Expanded(
                      child: Text(
                        title!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    )
                  else
                    const Spacer(),
                  IconButton(
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black45,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.close_rounded, size: 24),
                    tooltip: 'Đóng',
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
