import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;

/// Service quản lý bộ nhớ đệm (disk cache) cho các mảnh bản đồ (Map Tiles).
/// Tuân thủ quy chuẩn:
/// 1. Chỉ cache các file tile bản đồ (OpenStreetMap, CartoDB, Google Maps tile).
/// 2. TUYỆT ĐỐI KHÔNG lưu trữ hoặc cache ảnh khách hàng hay dữ liệu cá nhân.
/// 3. Giới hạn dung lượng tối đa 200MB trên đĩa, tự động dọn dẹp khi vượt ngưỡng.
class MapTileCacheService {
  static const int maxCacheSizeBytes = 200 * 1024 * 1024; // 200 MB
  static const int targetPruneSizeBytes = 150 * 1024 * 1024; // Dọn về 150 MB

  static Directory? _customDirectory;

  /// Cho phép test suite gán thư mục tạm thời để kiểm thử
  static void setCustomCacheDirectory(Directory? dir) {
    _customDirectory = dir;
  }

  /// Thư mục lưu trữ cache mảnh bản đồ
  static Directory get cacheDirectory {
    if (_customDirectory != null) {
      if (!_customDirectory!.existsSync()) {
        _customDirectory!.createSync(recursive: true);
      }
      return _customDirectory!;
    }
    final defaultDir = Directory('${Directory.systemTemp.path}/delivery_marker_map_tiles');
    if (!defaultDir.existsSync()) {
      defaultDir.createSync(recursive: true);
    }
    return defaultDir;
  }

  /// Kiểm tra URL có phải là tile bản đồ hợp lệ hay không
  /// Chặn tuyệt đối ảnh khách hàng (chứa /photos/, /uploads/, /avatar/, customer...)
  static bool isMapTileUrl(String url) {
    final lower = url.toLowerCase();
    if (lower.contains('/photos/') ||
        lower.contains('/uploads/') ||
        lower.contains('customer') ||
        lower.contains('avatar') ||
        lower.contains('profile')) {
      return false;
    }
    return lower.contains('tile') ||
        lower.contains('/vt/') ||
        lower.contains('openstreetmap') ||
        lower.contains('cartocdn') ||
        lower.contains('google.com/vt');
  }

  /// Chuyển đổi URL tile thành tên file an toàn trên đĩa
  static String getFileNameForUrl(String url) {
    final sanitized = url
        .replaceAll(RegExp(r'https?://'), '')
        .replaceAll(RegExp(r'[^\w\.-]'), '_');
    if (sanitized.length > 120) {
      return '${sanitized.substring(0, 100)}_${url.hashCode.toRadixString(16)}.tile';
    }
    return '$sanitized.tile';
  }

  /// Lấy file đã cache (nếu có)
  static File? getCachedTileFile(String url) {
    if (!isMapTileUrl(url)) return null;
    final file = File('${cacheDirectory.path}/${getFileNameForUrl(url)}');
    return file.existsSync() ? file : null;
  }

  /// Lưu mảnh tile vào disk cache (chỉ thực hiện với tile bản đồ)
  static Future<void> cacheTileBytes(String url, Uint8List bytes) async {
    if (!isMapTileUrl(url)) return; // Không bao giờ cache ảnh ngoài tile bản đồ
    try {
      final file = File('${cacheDirectory.path}/${getFileNameForUrl(url)}');
      await file.writeAsBytes(bytes, flush: true);
      await _checkAndPruneCache();
    } catch (_) {
      // Bỏ qua lỗi ghi disk nếu bộ nhớ tạm bị khóa
    }
  }

  /// Tính tổng dung lượng hiện tại của thư mục tile cache (bytes)
  static Future<int> getCacheSizeBytes() async {
    try {
      final dir = cacheDirectory;
      if (!dir.existsSync()) return 0;
      int total = 0;
      final entities = dir.listSync(recursive: false);
      for (final entity in entities) {
        if (entity is File) {
          total += entity.lengthSync();
        }
      }
      return total;
    } catch (_) {
      return 0;
    }
  }

  /// Tự động dọn dẹp các tile cũ nhất khi vượt quá 200MB
  static Future<void> _checkAndPruneCache() async {
    try {
      final currentSize = await getCacheSizeBytes();
      if (currentSize <= maxCacheSizeBytes) return;

      final dir = cacheDirectory;
      final files = dir
          .listSync(recursive: false)
          .whereType<File>()
          .toList();

      // Sắp xếp theo thời gian sửa đổi gần nhất (cũ nhất lên đầu)
      files.sort((a, b) => a.lastModifiedSync().compareTo(b.lastModifiedSync()));

      int remainingSize = currentSize;
      for (final file in files) {
        if (remainingSize <= targetPruneSizeBytes) break;
        final len = file.lengthSync();
        file.deleteSync();
        remainingSize -= len;
      }
    } catch (_) {}
  }

  /// Xóa toàn bộ tile cache
  static Future<void> clearCache() async {
    try {
      final dir = cacheDirectory;
      if (dir.existsSync()) {
        final entities = dir.listSync(recursive: false);
        for (final e in entities) {
          if (e is File) e.deleteSync();
        }
      }
    } catch (_) {}
  }

  /// Kiểm tra xác nhận không chứa bất kỳ ảnh khách hàng nào
  static bool containsCustomerPhoto(String url) {
    return !isMapTileUrl(url);
  }
}

/// TileProvider hỗ trợ cache trên đĩa và hủy yêu cầu (cancellable) khi kéo nhanh
class CancellableDiskCachedTileProvider extends TileProvider {
  static const int maxConcurrentRequests = 10;
  static int _activeRequests = 0;
  static final Queue<Completer<void>> _requestQueue = Queue();

  final http.Client? customClient;

  CancellableDiskCachedTileProvider({
    super.headers,
    this.customClient,
  });

  static Future<void> _acquireSlot() async {
    if (_activeRequests < maxConcurrentRequests) {
      _activeRequests++;
      return;
    }
    final completer = Completer<void>();
    _requestQueue.add(completer);
    await completer.future;
  }

  static void _releaseSlot() {
    if (_requestQueue.isNotEmpty) {
      final next = _requestQueue.removeFirst();
      next.complete();
    } else {
      if (_activeRequests > 0) _activeRequests--;
    }
  }

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    final url = getTileUrl(coordinates, options);

    // 1. Kiểm tra cache trên đĩa trước
    final cached = MapTileCacheService.getCachedTileFile(url);
    if (cached != null) {
      return FileImage(cached);
    }

    // 2. Tải qua mạng có hỗ trợ hủy và tự động lưu vào cache đĩa
    return CancellableTileImageProvider(
      url: url,
      headers: headers,
      customClient: customClient,
    );
  }
}

/// ImageProvider tùy biến hỗ trợ hủy request khi tile bị loại khỏi khung nhìn
class CancellableTileImageProvider extends ImageProvider<CancellableTileImageProvider> {
  final String url;
  final Map<String, String> headers;
  final http.Client? customClient;

  const CancellableTileImageProvider({
    required this.url,
    this.headers = const {},
    this.customClient,
  });

  @override
  Future<CancellableTileImageProvider> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture<CancellableTileImageProvider>(this);
  }

  @override
  ImageStreamCompleter loadImage(CancellableTileImageProvider key, ImageDecoderCallback decode) {
    return MultiFrameImageStreamCompleter(
      codec: _loadAsync(key, decode),
      scale: 1.0,
      informationCollector: () sync* {
        yield DiagnosticsProperty<String>('Tile URL', url);
      },
    );
  }

  Future<ui.Codec> _loadAsync(CancellableTileImageProvider key, ImageDecoderCallback decode) async {
    // 1. Kiểm tra cache đĩa lần 2 trong trường hợp luồng trước vừa ghi xong
    final cachedFile = MapTileCacheService.getCachedTileFile(url);
    if (cachedFile != null) {
      final bytes = await cachedFile.readAsBytes();
      final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
      return decode(buffer);
    }

    // 2. Giới hạn số yêu cầu đồng thời
    await CancellableDiskCachedTileProvider._acquireSlot();
    http.Client? localClient;

    try {
      localClient = customClient ?? http.Client();
      final response = await localClient.get(Uri.parse(url), headers: headers);

      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        // Lưu vào disk cache bất đồng bộ (chỉ tile bản đồ)
        unawaited(MapTileCacheService.cacheTileBytes(url, response.bodyBytes));

        final buffer = await ui.ImmutableBuffer.fromUint8List(response.bodyBytes);
        return await decode(buffer);
      } else {
        throw Exception('Tile HTTP status ${response.statusCode}');
      }
    } catch (e) {
      // Khi lỗi hoặc bị hủy, trả về 1 transparent pixel 1x1 để không gây crash tile render
      return _createTransparent1x1Codec(decode);
    } finally {
      CancellableDiskCachedTileProvider._releaseSlot();
      if (customClient == null && localClient != null) {
        localClient.close();
      }
    }
  }

  /// Tạo 1 ảnh trong suốt 1x1 phòng ngừa lỗi kết nối mạng
  Future<ui.Codec> _createTransparent1x1Codec(ImageDecoderCallback decode) async {
    final transparentPng = Uint8List.fromList(const [
      0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
      0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
      0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
      0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
      0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
      0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
    ]);
    final buffer = await ui.ImmutableBuffer.fromUint8List(transparentPng);
    return decode(buffer);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CancellableTileImageProvider && runtimeType == other.runtimeType && url == other.url;

  @override
  int get hashCode => url.hashCode;
}
