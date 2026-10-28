import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;

TileProvider createPlatformTileProvider({Map<String, String>? headers, http.Client? customClient}) {
  if (kIsWeb) return NetworkTileProvider(headers: headers ?? const {});
  return CancellableDiskCachedTileProvider(headers: headers, customClient: customClient);
}

class MapTileCacheService {
  static const int maxCacheSizeBytes = 200 * 1024 * 1024;
  static const int targetPruneSizeBytes = 150 * 1024 * 1024;
  static Directory? _customDirectory;

  static void setCustomCacheDirectory(Directory? dir) => _customDirectory = dir;

  static Directory get cacheDirectory {
    if (kIsWeb) throw UnsupportedError('MapTileCacheService.cacheDirectory không được hỗ trợ trên nền tảng Web');
    if (_customDirectory != null) {
      if (!_customDirectory!.existsSync()) _customDirectory!.createSync(recursive: true);
      return _customDirectory!;
    }
    final dir = Directory('${Directory.systemTemp.path}/delivery_marker_map_tiles');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  static bool isMapTileUrl(String url) {
    final l = url.toLowerCase();
    if (['/photos/', '/uploads/', 'customer', 'avatar', 'profile'].any(l.contains)) return false;
    return ['tile', '/vt/', 'openstreetmap', 'cartocdn', 'google.com/vt'].any(l.contains);
  }

  static String getFileNameForUrl(String url) {
    final s = url.replaceAll(RegExp(r'https?://'), '').replaceAll(RegExp(r'[^\w\.-]'), '_');
    return s.length > 120 ? '${s.substring(0, 100)}_${url.hashCode.toRadixString(16)}.tile' : '$s.tile';
  }

  static File? getCachedTileFile(String url) {
    if (kIsWeb || !isMapTileUrl(url)) return null;
    final f = File('${cacheDirectory.path}/${getFileNameForUrl(url)}');
    return f.existsSync() ? f : null;
  }

  static Future<void> cacheTileBytes(String url, Uint8List bytes) async {
    if (kIsWeb || !isMapTileUrl(url)) return;
    try {
      final f = File('${cacheDirectory.path}/${getFileNameForUrl(url)}');
      await f.writeAsBytes(bytes, flush: true);
      await _checkAndPruneCache();
    } catch (_) {}
  }

  static Future<int> getCacheSizeBytes() async {
    if (kIsWeb) return 0;
    try {
      final dir = cacheDirectory;
      if (!dir.existsSync()) return 0;
      return dir.listSync().whereType<File>().fold<int>(0, (sum, f) => sum + f.lengthSync());
    } catch (_) {
      return 0;
    }
  }

  static Future<void> _checkAndPruneCache() async {
    if (kIsWeb) return;
    try {
      final currentSize = await getCacheSizeBytes();
      if (currentSize <= maxCacheSizeBytes) return;
      final files = cacheDirectory.listSync().whereType<File>().toList()
        ..sort((a, b) => a.lastModifiedSync().compareTo(b.lastModifiedSync()));
      int remaining = currentSize;
      for (final f in files) {
        if (remaining <= targetPruneSizeBytes) break;
        final len = f.lengthSync();
        f.deleteSync();
        remaining -= len;
      }
    } catch (_) {}
  }

  static Future<void> clearCache() async {
    if (kIsWeb) return;
    try {
      if (cacheDirectory.existsSync()) {
        for (final e in cacheDirectory.listSync()) {
          if (e is File) e.deleteSync();
        }
      }
    } catch (_) {}
  }

  static bool containsCustomerPhoto(String url) => !isMapTileUrl(url);
}

class CancellableDiskCachedTileProvider extends TileProvider {
  static const int maxConcurrentRequests = 10;
  static int _activeRequests = 0;
  static final Queue<Completer<void>> _requestQueue = Queue();
  final http.Client? customClient;

  CancellableDiskCachedTileProvider({super.headers, this.customClient});

  static Future<void> _acquireSlot() async {
    if (_activeRequests < maxConcurrentRequests) {
      _activeRequests++;
      return;
    }
    final c = Completer<void>();
    _requestQueue.add(c);
    await c.future;
  }

  static void _releaseSlot() {
    if (_requestQueue.isNotEmpty) {
      _requestQueue.removeFirst().complete();
    } else if (_activeRequests > 0) {
      _activeRequests--;
    }
  }

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    final url = getTileUrl(coordinates, options);
    if (kIsWeb) return NetworkImage(url, headers: headers);
    final cached = MapTileCacheService.getCachedTileFile(url);
    if (cached != null) return FileImage(cached);
    return CancellableTileImageProvider(url: url, headers: headers, customClient: customClient);
  }
}

class CancellableTileImageProvider extends ImageProvider<CancellableTileImageProvider> {
  final String url;
  final Map<String, String> headers;
  final http.Client? customClient;

  const CancellableTileImageProvider({required this.url, this.headers = const {}, this.customClient});

  @override
  Future<CancellableTileImageProvider> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture<CancellableTileImageProvider>(this);

  @override
  ImageStreamCompleter loadImage(CancellableTileImageProvider key, ImageDecoderCallback decode) =>
      MultiFrameImageStreamCompleter(
        codec: _loadAsync(key, decode),
        scale: 1.0,
        informationCollector: () sync* {
          yield DiagnosticsProperty<String>('Tile URL', url);
        },
      );

  Future<ui.Codec> _loadAsync(CancellableTileImageProvider key, ImageDecoderCallback decode) async {
    final cachedFile = MapTileCacheService.getCachedTileFile(url);
    if (cachedFile != null) {
      final bytes = await cachedFile.readAsBytes();
      return decode(await ui.ImmutableBuffer.fromUint8List(bytes));
    }

    await CancellableDiskCachedTileProvider._acquireSlot();
    http.Client? localClient;
    try {
      localClient = customClient ?? http.Client();
      final res = await localClient.get(Uri.parse(url), headers: headers);
      if (res.statusCode == 200 && res.bodyBytes.isNotEmpty) {
        unawaited(MapTileCacheService.cacheTileBytes(url, res.bodyBytes));
        return await decode(await ui.ImmutableBuffer.fromUint8List(res.bodyBytes));
      }
      throw Exception('Tile HTTP status ${res.statusCode}');
    } catch (_) {
      return _createTransparent1x1Codec(decode);
    } finally {
      CancellableDiskCachedTileProvider._releaseSlot();
      if (customClient == null && localClient != null) localClient.close();
    }
  }

  Future<ui.Codec> _createTransparent1x1Codec(ImageDecoderCallback decode) async {
    const png = [
      0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
      0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
      0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
      0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
      0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
      0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
    ];
    return decode(await ui.ImmutableBuffer.fromUint8List(Uint8List.fromList(png)));
  }

  @override
  bool operator ==(Object other) => identical(this, other) || other is CancellableTileImageProvider && url == other.url;
  @override
  int get hashCode => url.hashCode;
}
