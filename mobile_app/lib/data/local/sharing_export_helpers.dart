part of 'local_sharing_repository.dart';

/// Các thao tác xuất gói chia sẻ dữ liệu ra file (.dshare) và mã QR nhiều mảnh.
/// Hỗ trợ nén zip, băm SHA-256 checksum, mã hóa AES-256 (nếu có mật khẩu).
extension _SharingExportOps on LocalSharingRepository {
  /// Thu thập danh sách điểm cần xuất theo phạm vi
  Future<List<SharedPointPayload>> _collectPointsForExport({
    required String scope, // 'all', 'shift', 'selected'
    String? shiftId,
    List<String>? customerIds,
    bool includeCustomerInfo = true,
    bool includePhotos = false,
  }) async {
    final db = await _appDb.database;
    final senderName = await _getSenderDisplayName();
    final nowIso = AppDatabase.currentIsoUtc();

    List<Map<String, dynamic>> rawRows = [];

    if (scope == 'all') {
      rawRows = await db.rawQuery('''
        SELECT c.id AS customer_id, c.customer_code, c.full_name, c.phone_number, c.address_text,
               sl.latitude, sl.longitude, sl.gps_accuracy, sl.identification_notes, sl.updated_at
        FROM customers c
        JOIN saved_locations sl ON c.id = sl.customer_id
        WHERE c.deleted_at IS NULL
        ORDER BY sl.updated_at DESC
      ''');
    } else if (scope == 'shift' && shiftId != null) {
      rawRows = await db.rawQuery('''
        SELECT c.id AS customer_id, c.customer_code, c.full_name, c.phone_number, c.address_text,
               sdp.latitude, sdp.longitude, sdp.gps_accuracy, sdp.identification_notes, sdp.updated_at
        FROM shift_delivery_points sdp
        JOIN customers c ON sdp.customer_id = c.id
        WHERE sdp.shift_id = ? 
          AND c.deleted_at IS NULL 
          AND sdp.latitude IS NOT NULL 
          AND sdp.longitude IS NOT NULL
        ORDER BY sdp.delivery_order_index ASC
      ''', [shiftId]);
    } else if (scope == 'selected' && customerIds != null && customerIds.isNotEmpty) {
      final placeholders = List.filled(customerIds.length, '?').join(',');
      rawRows = await db.rawQuery('''
        SELECT c.id AS customer_id, c.customer_code, c.full_name, c.phone_number, c.address_text,
               sl.latitude, sl.longitude, sl.gps_accuracy, sl.identification_notes, sl.updated_at
        FROM customers c
        JOIN saved_locations sl ON c.id = sl.customer_id
        WHERE c.deleted_at IS NULL AND c.id IN ($placeholders)
        ORDER BY sl.updated_at DESC
      ''', customerIds);
    }

    final List<SharedPointPayload> points = [];

    for (final r in rawRows) {
      final custId = r['customer_id'] as String;
      final rawPhone = r['phone_number'] as String? ?? '';
      final normPhone = normalizeCustomerPhone(rawPhone);

      final lat = (r['latitude'] as num?)?.toDouble() ?? 0.0;
      final lng = (r['longitude'] as num?)?.toDouble() ?? 0.0;

      // Lấy danh sách ảnh nếu được yêu cầu
      List<String> photoFiles = [];
      if (includePhotos) {
        final photoRows = await db.query(
          'customer_photos',
          columns: ['file_name'],
          where: 'customer_id = ? AND deleted_at IS NULL',
          whereArgs: [custId],
          limit: 10,
          orderBy: 'created_at DESC',
        );
        photoFiles = photoRows.map((p) => p['file_name'] as String).toList();
      }

      points.add(SharedPointPayload(
        phoneNumber: normPhone,
        fullName: includeCustomerInfo ? (r['full_name'] as String?) : null,
        addressText: includeCustomerInfo ? (r['address_text'] as String?) : null,
        latitude: lat,
        longitude: lng,
        gpsAccuracy: (r['gps_accuracy'] as num?)?.toDouble(),
        identificationNotes: r['identification_notes'] as String?,
        photoFileNames: photoFiles,
        senderName: senderName,
        timestamp: r['updated_at']?.toString() ?? nowIso,
      ));
    }

    return points;
  }

  /// Tạo tệp gói chia sẻ (.dshare)
  Future<File> _exportSharePackage({
    required String scope,
    String? shiftId,
    List<String>? customerIds,
    bool includeCustomerInfo = true,
    bool includePhotos = false,
    String? password,
  }) async {
    final points = await collectPointsForExport(
      scope: scope,
      shiftId: shiftId,
      customerIds: customerIds,
      includeCustomerInfo: includeCustomerInfo,
      includePhotos: includePhotos,
    );

    if (points.isEmpty) {
      throw StateError('Không có điểm nào để tạo gói chia sẻ');
    }

    if (points.length > LocalSharingRepository.maxPointsAllowed) {
      throw StateError('Số lượng điểm vượt quá giới hạn tối đa (${LocalSharingRepository.maxPointsAllowed} điểm)');
    }

    final tempDir = await _getTempDir();
    final photosDir = await _photoRepo.getPhotosDirectory();
    final archive = Archive();
    final Map<String, String> checksums = {};

    // 1. Chuẩn bị ảnh
    final List<Map<String, dynamic>> photoEntries = [];
    if (includePhotos && photosDir.existsSync()) {
      final Set<String> neededPhotos = {};
      for (final p in points) {
        neededPhotos.addAll(p.photoFileNames);
      }

      for (final fileName in neededPhotos) {
        final f = File(p.join(photosDir.path, fileName));
        if (f.existsSync()) {
          final bytes = await f.readAsBytes();
          final hash = sha256.convert(bytes).toString();
          final zipPath = 'photos/$fileName';
          checksums[zipPath] = hash;
          photoEntries.add({'zipPath': zipPath, 'bytes': bytes});
        }
      }
    }

    // 2. Chuẩn bị points.json và mã hóa nếu có mật khẩu
    final pointsJsonText = jsonEncode(points.map((pt) => pt.toJson()).toList());
    final pointsRawBytes = Uint8List.fromList(utf8.encode(pointsJsonText));

    bool isEncrypted = false;
    String? salt;
    String? iv;

    if (password != null && password.trim().isNotEmpty) {
      isEncrypted = true;
      final encResult = ShareCryptoUtils.encryptBytes(pointsRawBytes, password.trim());
      final cipherBytes = encResult['cipher'] as Uint8List;
      salt = encResult['salt'] as String;
      iv = encResult['iv'] as String;

      final pointsHash = sha256.convert(cipherBytes).toString();
      checksums['points.enc'] = pointsHash;
      archive.addFile(ArchiveFile('points.enc', cipherBytes.length, cipherBytes));
    } else {
      final pointsHash = sha256.convert(pointsRawBytes).toString();
      checksums['points.json'] = pointsHash;
      archive.addFile(ArchiveFile('points.json', pointsRawBytes.length, pointsRawBytes));
    }

    // 3. Thêm các ảnh vào archive
    for (final pe in photoEntries) {
      final b = pe['bytes'] as Uint8List;
      archive.addFile(ArchiveFile(pe['zipPath'] as String, b.length, b));
    }

    // 4. Tạo manifest.json
    final nowUtc = DateTime.now().toUtc();
    final senderName = await _getSenderDisplayName();
    final manifest = SharePackageManifest(
      formatVersion: 1,
      type: 'dshare',
      appVersion: '1.0.0+1',
      schemaVersion: AppDatabase.currentVersion,
      createdAt: nowUtc.toIso8601String(),
      senderDisplayName: senderName,
      pointsCount: points.length,
      photosCount: photoEntries.length,
      isEncrypted: isEncrypted,
      salt: salt,
      iv: iv,
      checksums: checksums,
    );

    final manifestBytes = Uint8List.fromList(utf8.encode(jsonEncode(manifest.toJson())));
    archive.addFile(ArchiveFile('manifest.json', manifestBytes.length, manifestBytes));

    // 5. Nén zip
    final zipEncoder = ZipEncoder();
    final encodedZip = zipEncoder.encode(archive);
    if (encodedZip.isEmpty) {
      throw StateError('Không thể tạo file nén .dshare');
    }

    // 6. Đặt tên tệp delivery-share-YYYYMMDD-HHmm.dshare (Giờ VN UTC+7)
    final vnTime = nowUtc.add(const Duration(hours: 7));
    final year = vnTime.year.toString();
    final month = vnTime.month.toString().padLeft(2, '0');
    final day = vnTime.day.toString().padLeft(2, '0');
    final hour = vnTime.hour.toString().padLeft(2, '0');
    final minute = vnTime.minute.toString().padLeft(2, '0');
    final fileName = 'delivery-share-$year$month$day-$hour$minute.dshare';

    final exportFile = File(p.join(tempDir.path, fileName));
    await exportFile.writeAsBytes(encodedZip, flush: true);

    // 7. Ghi activity_log (không chứa SĐT hay tên khách)
    await _appDb.logActivity(
      action: 'EXPORT_SHARE_PACKAGE',
      entity: 'sharing',
      details: {
        'fileName': fileName,
        'scope': scope,
        'pointsCount': points.length,
        'photosCount': photoEntries.length,
        'fileSizeBytes': exportFile.lengthSync(),
        'hasPassword': isEncrypted,
      },
    );

    return exportFile;
  }

  /// Chia sẻ tệp qua Share Sheet hệ thống (Zalo, Drive, Files,...)
  Future<void> _sharePackageFile(File file) async {
    if (!file.existsSync()) {
      throw StateError('Tệp chia sẻ không tồn tại');
    }
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        subject: 'Chia sẻ điểm giao hàng (.dshare)',
        text: 'Gói dữ liệu điểm giao hàng (${p.basename(file.path)})',
      ),
    );
  }

  /// Tạo các mảnh mã QR cho gói chia sẻ (không kèm ảnh)
  Future<List<String>> _exportQrChunks({
    required String scope,
    String? shiftId,
    List<String>? customerIds,
    bool includeCustomerInfo = true,
    String? password,
  }) async {
    final points = await collectPointsForExport(
      scope: scope,
      shiftId: shiftId,
      customerIds: customerIds,
      includeCustomerInfo: includeCustomerInfo,
      includePhotos: false, // QR không bao giờ kèm ảnh
    );

    if (points.isEmpty) {
      throw StateError('Không có điểm nào để tạo mã QR');
    }

    if (points.length > LocalSharingRepository.maxPointsAllowed) {
      throw StateError('Số lượng điểm vượt quá giới hạn tối đa (${LocalSharingRepository.maxPointsAllowed} điểm)');
    }

    final senderName = await _getSenderDisplayName();
    final nowUtc = DateTime.now().toUtc();

    String pointsPayloadString;

    if (password != null && password.trim().isNotEmpty) {
      final rawJson = jsonEncode(points.map((pt) => pt.toJson()).toList());
      final encResult = ShareCryptoUtils.encryptBytes(Uint8List.fromList(utf8.encode(rawJson)), password.trim());
      final envelope = {
        'enc': true,
        'sender': senderName,
        'ts': nowUtc.toIso8601String(),
        'salt': encResult['salt'],
        'iv': encResult['iv'],
        'data': base64.encode(encResult['cipher'] as Uint8List),
      };
      pointsPayloadString = jsonEncode(envelope);
    } else {
      final envelope = {
        'enc': false,
        'sender': senderName,
        'ts': nowUtc.toIso8601String(),
        'points': points.map((pt) => pt.toJson()).toList(),
      };
      pointsPayloadString = jsonEncode(envelope);
    }

    final chunks = ShareCryptoUtils.createQrChunks(pointsPayloadString, maxChunkChars: 1200);

    await _appDb.logActivity(
      action: 'EXPORT_SHARE_QR',
      entity: 'sharing',
      details: {
        'scope': scope,
        'pointsCount': points.length,
        'chunksCount': chunks.length,
        'hasPassword': password != null && password.trim().isNotEmpty,
      },
    );

    return chunks;
  }
}
