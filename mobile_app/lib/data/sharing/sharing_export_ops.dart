part of 'sharing_repository.dart';

extension _SharingExportOps on SharingRepository {
  Future<List<SharedPointPayload>> _collectPointsForExport({
    required String scope,
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
      rawRows = await db.rawQuery(
        'SELECT c.id AS customer_id, c.customer_code, c.full_name, c.phone_number, c.address_text, '
        'sl.latitude, sl.longitude, sl.gps_accuracy, sl.identification_notes, sl.updated_at '
        'FROM customers c JOIN saved_locations sl ON c.id = sl.customer_id '
        'WHERE c.deleted_at IS NULL ORDER BY sl.updated_at DESC',
      );
    } else if (scope == 'shift' && shiftId != null) {
      rawRows = await db.rawQuery(
        'SELECT c.id AS customer_id, c.customer_code, c.full_name, c.phone_number, c.address_text, '
        'sdp.latitude, sdp.longitude, sdp.gps_accuracy, sdp.identification_notes, sdp.updated_at '
        'FROM shift_delivery_points sdp JOIN customers c ON sdp.customer_id = c.id '
        'WHERE sdp.shift_id = ? AND c.deleted_at IS NULL AND sdp.latitude IS NOT NULL AND sdp.longitude IS NOT NULL '
        'ORDER BY sdp.delivery_order_index ASC',
        [shiftId],
      );
    } else if (scope == 'selected' && customerIds != null && customerIds.isNotEmpty) {
      final ph = List.filled(customerIds.length, '?').join(',');
      rawRows = await db.rawQuery(
        'SELECT c.id AS customer_id, c.customer_code, c.full_name, c.phone_number, c.address_text, '
        'sl.latitude, sl.longitude, sl.gps_accuracy, sl.identification_notes, sl.updated_at '
        'FROM customers c JOIN saved_locations sl ON c.id = sl.customer_id '
        'WHERE c.deleted_at IS NULL AND c.id IN ($ph) ORDER BY sl.updated_at DESC',
        customerIds,
      );
    }

    final List<SharedPointPayload> points = [];
    for (final r in rawRows) {
      final cId = r['customer_id'] as String;
      List<String> photoFiles = [];
      if (includePhotos) {
        final pRows = await db.query(
          'customer_photos',
          columns: ['file_name'],
          where: 'customer_id = ? AND deleted_at IS NULL',
          whereArgs: [cId],
          limit: 10,
          orderBy: 'created_at DESC',
        );
        photoFiles = pRows.map((p) => p['file_name'] as String).toList();
      }
      points.add(SharedPointPayload(
        phoneNumber: normalizeCustomerPhone(r['phone_number'] as String? ?? ''),
        fullName: includeCustomerInfo ? (r['full_name'] as String?) : null,
        addressText: includeCustomerInfo ? (r['address_text'] as String?) : null,
        latitude: (r['latitude'] as num?)?.toDouble() ?? 0.0,
        longitude: (r['longitude'] as num?)?.toDouble() ?? 0.0,
        gpsAccuracy: (r['gps_accuracy'] as num?)?.toDouble(),
        identificationNotes: r['identification_notes'] as String?,
        photoFileNames: photoFiles,
        senderName: senderName,
        timestamp: r['updated_at']?.toString() ?? nowIso,
      ));
    }
    return points;
  }

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
    if (points.isEmpty) throw StateError('Không có điểm nào để tạo gói chia sẻ');
    if (points.length > SharingRepository.maxPointsAllowed) {
      throw StateError('Số lượng điểm vượt quá giới hạn tối đa (${SharingRepository.maxPointsAllowed} điểm)');
    }

    final tempDir = await _getTempDir();
    final pDir = await _photoRepo.getPhotosDirectory();
    final archive = Archive();
    final checksums = <String, String>{};
    final List<Map<String, dynamic>> photoEntries = [];

    if (includePhotos && pDir.existsSync()) {
      final needed = points.expand((p) => p.photoFileNames).toSet();
      for (final fn in needed) {
        final f = File(p.join(pDir.path, fn));
        if (f.existsSync()) {
          final b = await f.readAsBytes();
          final zipP = 'photos/$fn';
          checksums[zipP] = sha256.convert(b).toString();
          photoEntries.add({'zipPath': zipP, 'bytes': b});
        }
      }
    }

    final pJson = jsonEncode(points.map((pt) => pt.toJson()).toList());
    final rawBytes = Uint8List.fromList(utf8.encode(pJson));
    bool isEnc = false;
    String? salt;
    String? iv;

    if (password?.trim().isNotEmpty == true) {
      isEnc = true;
      final enc = ShareCryptoUtils.encryptBytes(rawBytes, password!.trim());
      final cipher = enc['cipher'] as Uint8List;
      salt = enc['salt'] as String;
      iv = enc['iv'] as String;
      checksums['points.enc'] = sha256.convert(cipher).toString();
      archive.addFile(ArchiveFile('points.enc', cipher.length, cipher));
    } else {
      checksums['points.json'] = sha256.convert(rawBytes).toString();
      archive.addFile(ArchiveFile('points.json', rawBytes.length, rawBytes));
    }

    for (final pe in photoEntries) {
      final b = pe['bytes'] as Uint8List;
      archive.addFile(ArchiveFile(pe['zipPath'] as String, b.length, b));
    }

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
      isEncrypted: isEnc,
      salt: salt,
      iv: iv,
      checksums: checksums,
    );
    final mBytes = utf8.encode(jsonEncode(manifest.toJson()));
    archive.addFile(ArchiveFile('manifest.json', mBytes.length, mBytes));

    final zipData = ZipEncoder().encode(archive);
    if (zipData.isEmpty) throw StateError('Không thể tạo file nén .dshare');

    final vn = nowUtc.add(const Duration(hours: 7));
    String pad(int n) => n.toString().padLeft(2, '0');
    final fileName = 'delivery-share-${vn.year}${pad(vn.month)}${pad(vn.day)}-${pad(vn.hour)}${pad(vn.minute)}.dshare';
    final exportFile = File(p.join(tempDir.path, fileName));
    await exportFile.writeAsBytes(zipData, flush: true);

    await _appDb.logActivity(
      action: 'EXPORT_SHARE_PACKAGE',
      entity: 'sharing',
      details: {
        'fileName': fileName,
        'scope': scope,
        'pointsCount': points.length,
        'photosCount': photoEntries.length,
        'fileSizeBytes': exportFile.lengthSync(),
        'hasPassword': isEnc,
      },
    );
    return exportFile;
  }

  Future<void> _sharePackageFile(File file) async {
    if (!file.existsSync()) throw StateError('Tệp chia sẻ không tồn tại');
    await SharePlus.instance.share(ShareParams(
      files: [XFile(file.path)],
      subject: 'Chia sẻ điểm giao hàng (.dshare)',
      text: 'Gói dữ liệu điểm giao hàng (${p.basename(file.path)})',
    ));
  }

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
      includePhotos: false,
    );
    if (points.isEmpty) throw StateError('Không có điểm nào để tạo mã QR');
    if (points.length > SharingRepository.maxPointsAllowed) {
      throw StateError('Số lượng điểm vượt quá giới hạn tối đa (${SharingRepository.maxPointsAllowed} điểm)');
    }

    final senderName = await _getSenderDisplayName();
    final nowUtc = DateTime.now().toUtc();
    String payload;

    if (password?.trim().isNotEmpty == true) {
      final raw = jsonEncode(points.map((pt) => pt.toJson()).toList());
      final enc = ShareCryptoUtils.encryptBytes(Uint8List.fromList(utf8.encode(raw)), password!.trim());
      payload = jsonEncode({
        'enc': true,
        'sender': senderName,
        'ts': nowUtc.toIso8601String(),
        'salt': enc['salt'],
        'iv': enc['iv'],
        'data': base64.encode(enc['cipher'] as Uint8List),
      });
    } else {
      payload = jsonEncode({
        'enc': false,
        'sender': senderName,
        'ts': nowUtc.toIso8601String(),
        'points': points.map((p) => p.toJson()).toList(),
      });
    }

    final chunks = ShareCryptoUtils.createQrChunks(payload, maxChunkChars: 1200);
    await _appDb.logActivity(
      action: 'EXPORT_SHARE_QR',
      entity: 'sharing',
      details: {
        'scope': scope,
        'pointsCount': points.length,
        'chunksCount': chunks.length,
        'hasPassword': password?.trim().isNotEmpty == true,
      },
    );
    return chunks;
  }
}

