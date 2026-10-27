import 'dart:io';
import 'package:flutter/material.dart';
import '../repositories/repository_provider.dart';

class AuthenticatedImage extends StatelessWidget {
  final String photoUrl;
  final BoxFit fit;
  final double? width;
  final double? height;
  final Widget? placeholder;
  final Widget? errorWidget;
  final int? cacheVersion;
  final bool bustCache;
  final BorderRadius? borderRadius;

  const AuthenticatedImage({
    super.key,
    required this.photoUrl,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.placeholder,
    this.errorWidget,
    this.cacheVersion,
    this.bustCache = false,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    Widget imageContent = FutureBuilder<Map<String, String>>(
      future: RepositoryProvider.photo.getPhotoAuthInfo(
        photoUrl,
        cacheVersion: cacheVersion,
        bustCache: bustCache,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return placeholder ??
              Container(
                width: width,
                height: height,
                color: Colors.grey.shade200,
                child: const Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              );
        }

        if (!snapshot.hasData || snapshot.hasError) {
          return errorWidget ??
              Container(
                width: width,
                height: height,
                color: Colors.grey.shade300,
                child: const Icon(Icons.broken_image, color: Colors.grey),
              );
        }

        final photoInfo = snapshot.data!;
        final url = photoInfo['url'] ?? '';
        final isLocal = photoInfo['isLocal'] == 'true' ||
            photoInfo['filePath'] != null ||
            url.startsWith('file://');

        if (isLocal) {
          final filePath = photoInfo['filePath'] ?? url.replaceFirst('file://', '');
          return Image.file(
            File(filePath),
            width: width,
            height: height,
            fit: fit,
            cacheWidth: width != null && width! > 0 ? (width! * 2).toInt() : null,
            cacheHeight: height != null && height! > 0 ? (height! * 2).toInt() : null,
            errorBuilder: (context, error, stackTrace) {
              return errorWidget ??
                  Container(
                    width: width,
                    height: height,
                    color: Colors.grey.shade300,
                    child: const Icon(Icons.broken_image, color: Colors.grey),
                  );
            },
          );
        }

        final token = photoInfo['token'];

        return Image.network(
          url,
          width: width,
          height: height,
          fit: fit,
          headers: {
            if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
          },
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return placeholder ??
                Container(
                  width: width,
                  height: height,
                  color: Colors.grey.shade100,
                  child: Center(
                    child: CircularProgressIndicator(
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                              loadingProgress.expectedTotalBytes!
                          : null,
                      strokeWidth: 2,
                    ),
                  ),
                );
          },
          errorBuilder: (context, error, stackTrace) {
            return errorWidget ??
                Container(
                  width: width,
                  height: height,
                  color: Colors.grey.shade300,
                  child: const Icon(Icons.broken_image, color: Colors.grey),
                );
          },
        );
      },
    );

    if (borderRadius != null) {
      return ClipRRect(
        borderRadius: borderRadius!,
        child: imageContent,
      );
    }
    return imageContent;
  }
}
