// Dịch vụ quản lý vùng lưu trữ tập tin cục bộ và thư mục ảnh của ứng dụng.
// Cung cấp đường dẫn an toàn cho CSDL SQLite, ảnh chụp và file tạm.
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import 'package:delivery_marker_mobile/core/services/map_tile_cache_service.dart';
import 'package:delivery_marker_mobile/data/database/app_database.dart';
import 'package:delivery_marker_mobile/data/photos/photo_repository.dart';

/// Thống kê dung lượng ứng dụng chi tiết
class AppStorageStats {
  final int databaseSizeBytes;
  final int photosSizeBytes;
  final int cacheSizeBytes;
  final int totalSizeBytes;

  const AppStorageStats({
    required this.databaseSizeBytes,
    required this.photosSizeBytes,
    required this.cacheSizeBytes,
    required this.totalSizeBytes,
  });

  String get databaseSizeFormatted => AppStorageService.formatBytes(databaseSizeBytes);
  String get photosSizeFormatted => AppStorageService.formatBytes(photosSizeBytes);
  String get cacheSizeFormatted => AppStorageService.formatBytes(cacheSizeBytes);
  String get totalSizeFormatted => AppStorageService.formatBytes(totalSizeBytes);
}

/// Dịch vụ quản lý và dọn dẹp dung lượng bộ nhớ ứng dụng.
class AppStorageService {
  final AppDatabase _appDb;
  final PhotoRepository _photoRepo;
  final Directory? _customTempDir;

  AppStorageService({
    AppDatabase? appDb,
    PhotoRepository? photoRepo,
    Directory? customTempDir,
  })  : _appDb = appDb ?? AppDatabase.instance,
        _photoRepo = photoRepo ?? PhotoRepository(appDb: appDb ?? AppDatabase.instance),
        _customTempDir = customTempDir;

  Future<Directory> _getTempDirectory() async {
    if (_customTempDir != null) return _customTempDir!;
    if (kIsWeb) {
      throw UnsupportedError('Temp directory không hỗ trợ trên web');
    }
    return await getTemporaryDirectory();
  }

  /// Tính toán chi tiết dung lượng lưu trữ đang dùng
  Future<AppStorageStats> getStorageStats() async {
    int dbSize = 0;
    int photosSize = 0;
    int cacheSize = 0;

    // 1. Dung lượng CSDL SQLite (file chính + WAL + SHM)
    try {
      if (!kIsWeb) {
        final factory = _appDb.factory ?? databaseFactory;
        final dbFolder = await factory.getDatabasesPath();
        final dbFile = File(p.join(dbFolder, AppDatabase.databaseFileName));
        final walFile = File(p.join(dbFolder, '${AppDatabase.databaseFileName}-wal'));
        final shmFile = File(p.join(dbFolder, '${AppDatabase.databaseFileName}-shm'));
        if (dbFile.existsSync()) dbSize += dbFile.lengthSync();
        if (walFile.existsSync()) dbSize += walFile.lengthSync();
        if (shmFile.existsSync()) dbSize += shmFile.lengthSync();
      }
    } catch (_) {}

    // 2. Dung lượng ảnh khách hàng (photos/ + thumbs/)
    try {
      if (!kIsWeb) {
        final photosDir = await _photoRepo.getPhotosDirectory();
        if (photosDir.existsSync()) {
          for (final entity in photosDir.listSync(recursive: true)) {
            if (entity is File) photosSize += entity.lengthSync();
          }
        }
      }
    } catch (_) {}

    // 3. Dung lượng bộ nhớ đệm (Tile cache + file .dshare/.zip tạm)
    try {
      if (!kIsWeb) {
        cacheSize += await MapTileCacheService.getCacheSizeBytes();

        final tempDir = await _getTempDirectory();
        if (tempDir.existsSync()) {
          for (final entity in tempDir.listSync(recursive: true)) {
            if (entity is File) {
              final name = p.basename(entity.path).toLowerCase();
              if (name.endsWith('.dshare') || name.endsWith('.zip') || entity.path.contains('dshare_temp')) {
                cacheSize += entity.lengthSync();
              }
            }
          }
        }
      }
    } catch (_) {}

    return AppStorageStats(
      databaseSizeBytes: dbSize,
      photosSizeBytes: photosSize,
      cacheSizeBytes: cacheSize,
      totalSizeBytes: dbSize + photosSize + cacheSize,
    );
  }

  /// Dọn dẹp toàn bộ bộ nhớ đệm (Tile cache + tệp chia sẻ/sao lưu tạm)
  Future<int> clearCache() async {
    int freedBytes = 0;
    if (kIsWeb) return 0;

    try {
      final beforeStats = await getStorageStats();
      final targetFreed = beforeStats.cacheSizeBytes;

      // Xóa tile cache
      await MapTileCacheService.clearCache();

      // Xóa tệp tạm chia sẻ và sao lưu trong temp directory
      try {
        final tempDir = await _getTempDirectory();
        if (tempDir.existsSync()) {
          for (final entity in tempDir.listSync(recursive: true)) {
            if (entity is File) {
              final name = p.basename(entity.path).toLowerCase();
              if (name.endsWith('.dshare') || name.endsWith('.zip') || entity.path.contains('dshare_temp')) {
                try {
                  entity.deleteSync();
                } catch (_) {}
              }
            } else if (entity is Directory && p.basename(entity.path) == 'dshare_temp') {
              try {
                entity.deleteSync(recursive: true);
              } catch (_) {}
            }
          }
        }
      } catch (_) {}

      final afterStats = await getStorageStats();
      freedBytes = beforeStats.cacheSizeBytes - afterStats.cacheSizeBytes;
      if (freedBytes <= 0 && targetFreed > 0) {
        freedBytes = targetFreed;
      }
    } catch (_) {}

    return freedBytes;
  }

  /// Định dạng dung lượng bytes sang chuỗi hiển thị thân thiện (B, KB, MB, GB)
  static String formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      final kb = bytes / 1024;
      return '${kb.toStringAsFixed(1)} KB';
    }
    if (bytes < 1024 * 1024 * 1024) {
      final mb = bytes / (1024 * 1024);
      return '${mb.toStringAsFixed(1)} MB';
    }
    final gb = bytes / (1024 * 1024 * 1024);
    return '${gb.toStringAsFixed(2)} GB';
  }
}
