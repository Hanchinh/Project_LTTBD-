part of 'sharing_repository.dart';

extension _SharingImportOps on SharingRepository {
  Future<SharePackagePreview> _inspectPackageFile(File file, {String? password}) async {
    if (!file.existsSync()) throw ArgumentError('Tệp chia sẻ không tồn tại: ${file.path}');
    if (file.lengthSync() > SharingRepository.maxFileSizeBytes) {
      throw const FormatException('Gói chia sẻ vượt quá dung lượng cho phép (tối đa 50MB)');
    }

    final bytes = await file.readAsBytes();
    Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes);
    } catch (_) {
      throw const FormatException('Tệp không đúng định dạng zip/dshare hoặc đã bị hỏng');
    }

    for (final f in archive) {
      final n = f.name.replaceAll('\\', '/');
      if (n.contains('../') || n.contains('..') || n.startsWith('/') || n.contains(':')) {
        throw const FormatException('Phát hiện đường dẫn bất thường (Path Traversal) trong gói chia sẻ');
      }
    }

    final mFile = archive.findFile('manifest.json');
    if (mFile == null) throw const FormatException('Gói chia sẻ không hợp lệ: Thiếu tệp manifest.json');
    final manifest = SharePackageManifest.fromJson(jsonDecode(utf8.decode(mFile.content as List<int>)) as Map<String, dynamic>);

    if (manifest.schemaVersion > AppDatabase.currentVersion) {
      throw FormatException('Gói chia sẻ từ phiên bản ứng dụng mới hơn (v${manifest.schemaVersion} > v${AppDatabase.currentVersion}). Vui lòng cập nhật ứng dụng.');
    }
    if (manifest.pointsCount > SharingRepository.maxPointsAllowed) {
      throw const FormatException('Gói chia sẻ chứa quá nhiều điểm (tối đa 2000 điểm)');
    }

    for (final entry in manifest.checksums.entries) {
      final entryFile = archive.findFile(entry.key);
      if (entryFile == null) throw FormatException('Gói chia sẻ thiếu tệp dữ liệu đã khai báo: ${entry.key}');
      if (sha256.convert(entryFile.content as List<int>).toString() != entry.value) {
        throw FormatException('Tệp ${entry.key} không khớp mã kiểm tra SHA-256 (có thể bị sửa đổi hoặc hỏng)');
      }
    }

    List<SharedPointPayload> points = [];
    if (manifest.isEncrypted) {
      if (password?.trim().isNotEmpty != true) throw const FormatException('GÓI_YÊU_CẦU_MẬT_KHẨU');
      final encFile = archive.findFile('points.enc');
      if (encFile == null) throw const FormatException('Thiếu tệp dữ liệu mã hóa points.enc');
      final decBytes = ShareCryptoUtils.decryptBytes(
        cipherBytes: Uint8List.fromList(encFile.content as List<int>),
        password: password!.trim(),
        saltHex: manifest.salt ?? '',
        ivHex: manifest.iv ?? '',
      );
      points = (jsonDecode(utf8.decode(decBytes)) as List).map((e) => SharedPointPayload.fromJson(e as Map<String, dynamic>)).toList();
    } else {
      final pFile = archive.findFile('points.json');
      if (pFile == null) throw const FormatException('Thiếu tệp dữ liệu points.json');
      points = (jsonDecode(utf8.decode(pFile.content as List<int>)) as List).map((e) => SharedPointPayload.fromJson(e as Map<String, dynamic>)).toList();
    }

    if (points.length > SharingRepository.maxPointsAllowed) {
      throw const FormatException('Gói chia sẻ chứa quá nhiều điểm (tối đa 2000 điểm)');
    }

    final photos = <String, Uint8List>{};
    for (final f in archive) {
      if (f.name.startsWith('photos/') && !f.isDirectory) {
        photos[f.name.substring('photos/'.length)] = Uint8List.fromList(f.content as List<int>);
      }
    }

    return SharePackagePreview(
      manifest: manifest,
      classifiedPoints: await _classifyPoints(points),
      photos: photos,
      filePath: file.path,
      isFromQr: false,
    );
  }

  Future<SharePackagePreview> _inspectQrPayload(String rawPayload, {String? password}) async {
    final j = jsonDecode(rawPayload.trim()) as Map<String, dynamic>;
    final isEnc = j['enc'] == true;
    final ts = j['ts']?.toString() ?? DateTime.now().toUtc().toIso8601String();

    List<SharedPointPayload> points = [];
    if (isEnc) {
      if (password?.trim().isNotEmpty != true) throw const FormatException('GÓI_YÊU_CẦU_MẬT_KHẨU');
      final dec = ShareCryptoUtils.decryptBytes(
        cipherBytes: Uint8List.fromList(base64.decode(j['data'] as String)),
        password: password!.trim(),
        saltHex: j['salt'] as String,
        ivHex: j['iv'] as String,
      );
      points = (jsonDecode(utf8.decode(dec)) as List).map((e) => SharedPointPayload.fromJson(e as Map<String, dynamic>)).toList();
    } else {
      points = (j['points'] as List? ?? []).map((e) => SharedPointPayload.fromJson(e as Map<String, dynamic>)).toList();
    }

    if (points.length > SharingRepository.maxPointsAllowed) {
      throw const FormatException('Gói chia sẻ chứa quá nhiều điểm (tối đa 2000 điểm)');
    }

    final manifest = SharePackageManifest(
      formatVersion: 1,
      type: 'dshare-qr',
      appVersion: '1.0.0+1',
      schemaVersion: AppDatabase.currentVersion,
      createdAt: ts,
      senderDisplayName: j['sender']?.toString() ?? 'Shipper',
      pointsCount: points.length,
      photosCount: 0,
      isEncrypted: isEnc,
      checksums: {},
    );

    return SharePackagePreview(
      manifest: manifest,
      classifiedPoints: await _classifyPoints(points),
      photos: const {},
      isFromQr: true,
    );
  }

  Future<List<ClassifiedSharePoint>> _classifyPoints(List<SharedPointPayload> points) async {
    final db = await _appDb.database;
    final List<ClassifiedSharePoint> list = [];

    for (final pt in points) {
      if (pt.latitude < -90.0 || pt.latitude > 90.0) {
        list.add(ClassifiedSharePoint(point: pt, classification: SharePointClassification.invalid, invalidReason: 'Vĩ độ không hợp lệ: ${pt.latitude}'));
        continue;
      }
      if (pt.longitude < -180.0 || pt.longitude > 180.0) {
        list.add(ClassifiedSharePoint(point: pt, classification: SharePointClassification.invalid, invalidReason: 'Kinh độ không hợp lệ: ${pt.longitude}'));
        continue;
      }
      final norm = normalizeCustomerPhone(pt.phoneNumber);
      if (norm.isEmpty) {
        list.add(ClassifiedSharePoint(point: pt, classification: SharePointClassification.invalid, invalidReason: 'Số điện thoại không hợp lệ: ${pt.phoneNumber}'));
        continue;
      }

      final custs = await db.query('customers', columns: ['id', 'full_name'], where: 'phone_number = ? AND deleted_at IS NULL', whereArgs: [norm], limit: 1);
      if (custs.isEmpty) {
        list.add(ClassifiedSharePoint(point: pt, classification: SharePointClassification.newCustomer));
        continue;
      }

      final cId = custs.first['id'] as String, cName = custs.first['full_name'] as String?;
      final locs = await db.query('saved_locations', columns: ['id', 'latitude', 'longitude'], where: 'customer_id = ?', whereArgs: [cId], limit: 1);
      if (locs.isEmpty) {
        list.add(ClassifiedSharePoint(point: pt, classification: SharePointClassification.existingWithoutLocation, existingCustomerId: cId, existingCustomerName: cName));
        continue;
      }

      final curLat = (locs.first['latitude'] as num).toDouble(), curLng = (locs.first['longitude'] as num).toDouble();
      final dist = Geolocator.distanceBetween(curLat, curLng, pt.latitude, pt.longitude);
      list.add(ClassifiedSharePoint(
        point: pt,
        classification: SharePointClassification.existingWithLocation,
        existingCustomerId: cId,
        existingCustomerName: cName,
        existingLatitude: curLat,
        existingLongitude: curLng,
        distanceMeters: dist,
      ));
    }
    return list;
  }

  bool _isValidImageBytes(Uint8List b) {
    if (b.length < 12) return false;
    return (b[0] == 0xFF && b[1] == 0xD8 && b[2] == 0xFF) ||
        (b[0] == 0x89 && b[1] == 0x50 && b[2] == 0x4E && b[3] == 0x47) ||
        (b[0] == 0x52 && b[1] == 0x49 && b[2] == 0x46 && b[3] == 0x46);
  }

  Future<ShareImportResult> _importPackage({
    required SharePackagePreview preview,
    required ShareImportMode mode,
    required Set<int> selectedIndexes,
    bool createShift = false,
    String? shiftName,
  }) async {
    final db = await _appDb.database;
    final nowIso = AppDatabase.currentIsoUtc(), nowUtc = DateTime.now().toUtc();
    final vn = nowUtc.add(const Duration(hours: 7));
    String pad(int n) => n.toString().padLeft(2, '0');
    final workDate = nowIso.split('T').first;

    final pDir = await _photoRepo.getPhotosDirectory();
    final tDir = await _photoRepo.getThumbsDirectory();
    final List<File> writtenFiles = [];

    int added = 0, replaced = 0, skipped = 0, errors = 0, photosAdded = 0, photosSkipped = 0;
    String? shiftId, finalShiftName;

    try {
      await db.transaction((txn) async {
        int orderIdx = 1;
        if (createShift) {
          shiftId = UuidUtils.generate();
          finalShiftName = shiftName ?? 'Từ ${preview.manifest.senderDisplayName} ${pad(vn.day)}/${pad(vn.month)}';
          await txn.insert('shifts', {
            'id': shiftId,
            'shift_code': 'SHIFT-${DateTime.now().millisecondsSinceEpoch % 10000}',
            'shift_name': finalShiftName,
            'work_date': workDate,
            'status': 'PREPARING',
            'created_at': nowIso,
            'updated_at': nowIso,
          });
        }

        for (int i = 0; i < preview.classifiedPoints.length; i++) {
          if (!selectedIndexes.contains(i)) continue;
          final item = preview.classifiedPoints[i];
          if (item.classification == SharePointClassification.invalid) {
            errors++;
            continue;
          }

          final pt = item.point, norm = normalizeCustomerPhone(pt.phoneNumber);
          String custId;
          bool addPhotos = false;

          if (item.classification == SharePointClassification.newCustomer) {
            custId = UuidUtils.generate();
            final code = 'CUST-${norm.substring(norm.length > 4 ? norm.length - 4 : 0)}';
            await txn.insert('customers', {
              'id': custId,
              'customer_code': code,
              'full_name': pt.fullName ?? 'Khách hàng',
              'phone_number': norm,
              'address_text': pt.addressText ?? '',
              'search_text': '${pt.fullName ?? ''} $norm ${pt.addressText ?? ''}'.toLowerCase(),
              'created_at': nowIso,
              'updated_at': nowIso,
            });
            await txn.insert('saved_locations', {
              'id': UuidUtils.generate(),
              'customer_id': custId,
              'latitude': pt.latitude,
              'longitude': pt.longitude,
              'gps_accuracy': pt.gpsAccuracy,
              'identification_notes': pt.identificationNotes,
              'created_at': nowIso,
              'updated_at': nowIso,
            });
            added++;
            addPhotos = true;
          } else if (item.classification == SharePointClassification.existingWithoutLocation) {
            custId = item.existingCustomerId!;
            await txn.insert('saved_locations', {
              'id': UuidUtils.generate(),
              'customer_id': custId,
              'latitude': pt.latitude,
              'longitude': pt.longitude,
              'gps_accuracy': pt.gpsAccuracy,
              'identification_notes': pt.identificationNotes,
              'created_at': nowIso,
              'updated_at': nowIso,
            });
            added++;
            addPhotos = true;
          } else {
            custId = item.existingCustomerId!;
            if (mode == ShareImportMode.replaceExisting) {
              await txn.update('saved_locations', {
                'latitude': pt.latitude,
                'longitude': pt.longitude,
                'gps_accuracy': pt.gpsAccuracy,
                'identification_notes': pt.identificationNotes,
                'updated_at': nowIso,
              }, where: 'customer_id = ?', whereArgs: [custId]);
              replaced++;
              addPhotos = true;
            } else {
              skipped++;
              addPhotos = false;
            }
          }

          if (createShift && shiftId != null) {
            await txn.insert('shift_delivery_points', {
              'id': UuidUtils.generate(),
              'shift_id': shiftId,
              'customer_id': custId,
              'delivery_order_index': orderIdx++,
              'location_status': 'VERIFIED',
              'latitude': pt.latitude,
              'longitude': pt.longitude,
              'gps_accuracy': pt.gpsAccuracy,
              'identification_notes': pt.identificationNotes,
              'created_at': nowIso,
              'updated_at': nowIso,
            });
          }

          if (addPhotos && pt.photoFileNames.isNotEmpty && preview.photos.isNotEmpty) {
            final cRows = await txn.rawQuery('SELECT COUNT(*) AS total FROM customer_photos WHERE customer_id = ? AND deleted_at IS NULL', [custId]);
            int curPhotos = Sqflite.firstIntValue(cRows) ?? 0;

            for (final pName in pt.photoFileNames) {
              final pBytes = preview.photos[pName];
              if (pBytes == null || pBytes.lengthInBytes > SharingRepository.maxPhotoSizeBytes || !_isValidImageBytes(pBytes) || curPhotos >= 10) {
                photosSkipped++;
                continue;
              }
              final photoId = UuidUtils.generate();
              final targetName = '$custId-$photoId.jpg';
              final fullF = File(p.join(pDir.path, targetName));
              final thumbF = File(p.join(tDir.path, targetName));
              await fullF.writeAsBytes(pBytes, flush: true);
              writtenFiles.add(fullF);
              await thumbF.writeAsBytes(pBytes, flush: true);
              writtenFiles.add(thumbF);

              await txn.insert('customer_photos', {
                'id': photoId,
                'customer_id': custId,
                'file_name': targetName,
                'thumb_file_name': targetName,
                'created_at': nowIso,
                'deleted_at': null,
              });
              photosAdded++;
              curPhotos++;
            }
          }
        }
      });
    } catch (_) {
      for (final f in writtenFiles) {
        try {
          if (f.existsSync()) f.deleteSync();
        } catch (_) {}
      }
      rethrow;
    }

    await _appDb.logActivity(
      action: 'IMPORT_SHARED_DATA',
      entity: 'sharing',
      details: {
        'addedCount': added,
        'replacedCount': replaced,
        'skippedCount': skipped,
        'errorCount': errors,
        'photosAdded': photosAdded,
        'photosSkipped': photosSkipped,
        'createdShift': createShift,
        'mode': mode.toString(),
      },
    );

    return ShareImportResult(
      addedCount: added,
      replacedCount: replaced,
      skippedCount: skipped,
      errorCount: errors,
      photosAdded: photosAdded,
      photosSkipped: photosSkipped,
      createdShiftId: shiftId,
      createdShiftName: finalShiftName,
      message: 'Nhập thành công: $added điểm mới, $replaced đã thay, $skipped bỏ qua, $photosAdded ảnh',
    );
  }
}

