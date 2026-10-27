import 'dart:io';
import 'package:flutter/material.dart';
import '../repositories/repository_provider.dart';

class FullscreenImageViewer extends StatefulWidget {
  final List<String> photoUrls;
  final int initialIndex;
  final String? title;
  final int? cacheVersion;

  const FullscreenImageViewer({
    super.key,
    required this.photoUrls,
    this.initialIndex = 0,
    this.title,
    this.cacheVersion,
  });

  static void show(
    BuildContext context, {
    required String photoUrl,
    String? title,
    int? cacheVersion,
  }) {
    showGallery(
      context,
      photoUrls: [photoUrl],
      initialIndex: 0,
      title: title,
      cacheVersion: cacheVersion,
    );
  }

  static void showGallery(
    BuildContext context, {
    required List<String> photoUrls,
    int initialIndex = 0,
    String? title,
    int? cacheVersion,
  }) {
    if (photoUrls.isEmpty) return;
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black87,
        barrierDismissible: true,
        pageBuilder: (ctx, anim1, anim2) => FullscreenImageViewer(
          photoUrls: photoUrls,
          initialIndex: initialIndex,
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
  State<FullscreenImageViewer> createState() => _FullscreenImageViewerState();
}

class _FullscreenImageViewerState extends State<FullscreenImageViewer> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, widget.photoUrls.length - 1);
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasMultiple = widget.photoUrls.length > 1;

    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: 0.95),
      body: SafeArea(
        child: Stack(
          children: [
            // PageView for swipeable photos
            PageView.builder(
              controller: _pageController,
              itemCount: widget.photoUrls.length,
              onPageChanged: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },
              itemBuilder: (context, index) {
                final photoUrl = widget.photoUrls[index];
                return Center(
                  child: FutureBuilder<Map<String, String>>(
                    future: RepositoryProvider.photo.getPhotoAuthInfo(
                      photoUrl,
                      cacheVersion: widget.cacheVersion,
                      bustCache: widget.cacheVersion == null,
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
                      final url = photoInfo['url'] ?? '';
                      final isLocal = photoInfo['isLocal'] == 'true' ||
                          photoInfo['filePath'] != null ||
                          url.startsWith('file://');

                      if (isLocal) {
                        final filePath = photoInfo['filePath'] ?? url.replaceFirst('file://', '');
                        return InteractiveViewer(
                          minScale: 0.8,
                          maxScale: 5.0,
                          child: Image.file(
                            File(filePath),
                            fit: BoxFit.contain,
                            errorBuilder: (ctx, err, stack) => const Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.broken_image_rounded, color: Colors.white60, size: 48),
                                SizedBox(height: 12),
                                Text(
                                  'Lỗi hiển thị tệp ảnh cục bộ',
                                  style: TextStyle(color: Colors.white70, fontSize: 14),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

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
                );
              },
            ),

            // Top Bar with title, index indicator, and Close Button
            Positioned(
              top: 10,
              left: 16,
              right: 16,
              child: Row(
                children: [
                  if (widget.title != null && widget.title!.isNotEmpty)
                    Expanded(
                      child: Text(
                        hasMultiple
                            ? '${widget.title!} (${_currentIndex + 1}/${widget.photoUrls.length})'
                            : widget.title!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    )
                  else if (hasMultiple)
                    Expanded(
                      child: Text(
                        '${_currentIndex + 1} / ${widget.photoUrls.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
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
