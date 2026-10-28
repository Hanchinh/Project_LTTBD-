part of 'local_sharing_repository.dart';

/// Các thao tác giải nén, kiểm tra tính toàn vẹn và nhập dữ liệu chia sẻ vào SQLite.
/// Hỗ trợ kiểm tra Path Traversal, SHA-256 checksum, magic bytes ảnh và phân loại điểm.
extension _SharingImportOps on LocalSharingRepository {
  /// Đọc và kiểm tra tính toàn vẹn của tệp .dshare trước khi cho phép nhập
  Future<SharePackagePreview> _inspectPackageFile(File file, {String? password}) async {
    if (!file.existsSync()) {
      throw ArgumentError('Tệp chia sẻ không tồn tại: ${file.path}');
    }

    // 1. Kiểm tra kích thước tối đa 50MB
    final fileSize = file.lengthSync();
    if (fileSize > LocalSharingRepository.maxFileSizeBytes) {
      throw const FormatException('Gói chia sẻ vượt quá dung lượng cho phép (tối đa 50MB)');
    }

    final bytes = await file.readAsBytes();
    Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes);
    } catch (e) {
      throw const FormatException('Tệp không đúng định dạng zip/dshare hoặc đã bị hỏng');
    }

    // 2. Chống Path Traversal (../, .., /, :)
    for (final f in archive) {
      final name = f.name.replaceAll('\\', '/');
      if (name.contains('../') || name.contains('..') || name.startsWith('/') || name.contains(':')) {
        throw const FormatException('Phát hiện đường dẫn bất thường (Path Traversal) trong gói chia sẻ');
      }
    }

    // 3. Tìm manifest.json
    final manifestFile = archive.findFile('manifest.json');
    if (manifestFile == null) {
      throw const FormatException('Gói chia sẻ không hợp lệ: Thiếu tệp manifest.json');
    }

    SharePackageManifest manifest;
    try {
      final manifestJson = jsonDecode(utf8.decode(manifestFile.content as List<int>)) as Map<String, dynamic>;
      manifest = SharePackageManifest.fromJson(manifestJson);
    } catch (e) {
      throw FormatException('Tệp manifest.json không hợp lệ: $e');
    }

    // 4. Kiểm tra phiên bản schema
    if (manifest.schemaVersion > AppDatabase.currentVersion) {
      throw FormatException(
        'Gói chia sẻ từ phiên bản ứng dụng mới hơn (v${manifest.schemaVersion} > v${AppDatabase.currentVersion}). Vui lòng cập nhật ứng dụng trước khi nhận.',
      );
    }

    // 5. Kiểm tra giới hạn số điểm
    if (manifest.pointsCount > LocalSharingRepository.maxPointsAllowed) {
      throw const FormatException('Gói chia sẻ chứa quá nhiều điểm (tối đa 2000 điểm)');
    }

    // 6. Kiểm tra checksum các file trong zip
    for (final entry in manifest.checksums.entries) {
      final zipEntryName = entry.key;
      final expectedHash = entry.value;
      final entryFile = archive.findFile(zipEntryName);
      if (entryFile == null) {
        throw FormatException('Gói chia sẻ thiếu tệp dữ liệu đã khai báo: $zipEntryName');
      }
      final entryBytes = entryFile.content as List<int>;
      final actualHash = sha256.convert(entryBytes).toString();
      if (actualHash != expectedHash) {
        throw FormatException('Tệp $zipEntryName không khớp mã kiểm tra SHA-256 (có thể bị sửa đổi hoặc hỏng)');
      }
    }

    // 7. Giải mã và đọc danh sách points
    List<SharedPointPayload> points = [];

    if (manifest.isEncrypted) {
      if (password == null || password.trim().isEmpty) {
        throw const FormatException('GÓI_YÊU_CẦU_MẬT_KHẨU');
      }
      final encFile = archive.findFile('points.enc');
      if (encFile == null) {
        throw const FormatException('Thiếu tệp dữ liệu mã hóa points.enc');
      }
      final cipherBytes = Uint8List.fromList(encFile.content as List<int>);
      final decryptedBytes = ShareCryptoUtils.decryptBytes(
        cipherBytes: cipherBytes,
        password: password.trim(),
        saltHex: manifest.salt ?? '',
        ivHex: manifest.iv ?? '',
      );
      final pointsJson = jsonDecode(utf8.decode(decryptedBytes)) as List<dynamic>;
      points = pointsJson.map((e) => SharedPointPayload.fromJson(e as Map<String, dynamic>)).toList();
    } else {
      final pointsFile = archive.findFile('points.json');
      if (pointsFile == null) {
        throw const FormatException('Thiếu tệp dữ liệu points.json');
      }
      final pointsJson = jsonDecode(utf8.decode(pointsFile.content as List<int>)) as List<dynamic>;
      points = pointsJson.map((e) => SharedPointPayload.fromJson(e as Map<String, dynamic>)).toList();
    }

    if (points.length > LocalSharingRepository.maxPointsAllowed) {
      throw const FormatException('Gói chia sẻ chứa quá nhiều điểm (tối đa 2000 điểm)');
    }

    // 8. Thu thập các ảnh đính kèm
    final Map<String, Uint8List> photos = {};
    for (final f in archive) {
      if (f.name.startsWith('photos/') && !f.isDirectory) {
        final relName = f.name.substring('photos/'.length);
        photos[relName] = Uint8List.fromList(f.content as List<int>);
      }
    }

    // 9. Phân loại từng điểm so với CSDL hiện tại
    final classified = await _classifyPoints(points);

    return SharePackagePreview(
      manifest: manifest,
      classifiedPoints: classified,
      photos: photos,
      filePath: file.path,
      isFromQr: false,
    );
  }

  /// Đọc và kiểm tra chuỗi dữ liệu nhận được từ mã QR
  Future<SharePackagePreview> _inspectQrPayload(String rawPayload, {String? password}) async {
    final cleanPayload = rawPayload.trim();
    final jsonMap = jsonDecode(cleanPayload) as Map<String, dynamic>;

    final isEnc = jsonMap['enc'] == true;
    final senderName = jsonMap['sender']?.toString() ?? 'Shipper';
    final ts = jsonMap['ts']?.toString() ?? DateTime.now().toUtc().toIso8601String();

    List<SharedPointPayload> points = [];

    if (isEnc) {
      if (password == null || password.trim().isEmpty) {
        throw const FormatException('GÓI_YÊU_CẦU_MẬT_KHẨU');
      }
      final cipherBytes = base64.decode(jsonMap['data'] as String);
      final salt = jsonMap['salt'] as String;
      final iv = jsonMap['iv'] as String;

      final decryptedBytes = ShareCryptoUtils.decryptBytes(
        cipherBytes: Uint8List.fromList(cipherBytes),
        password: password.trim(),
        saltHex: salt,
        ivHex: iv,
      );
      final rawPointsList = jsonDecode(utf8.decode(decryptedBytes)) as List<dynamic>;
      points = rawPointsList.map((e) => SharedPointPayload.fromJson(e as Map<String, dynamic>)).toList();
    } else {
      final rawPointsList = jsonMap['points'] as List<dynamic>? ?? [];
      points = rawPointsList.map((e) => SharedPointPayload.fromJson(e as Map<String, dynamic>)).toList();
    }

    if (points.length > LocalSharingRepository.maxPointsAllowed) {
      throw const FormatException('Gói chia sẻ chứa quá nhiều điểm (tối đa 2000 điểm)');
    }

    final manifest = SharePackageManifest(
      formatVersion: 1,
      type: 'dshare-qr',
      appVersion: '1.0.0+1',
      schemaVersion: AppDatabase.currentVersion,
      createdAt: ts,
      senderDisplayName: senderName,
      pointsCount: points.length,
      photosCount: 0,
      isEncrypted: isEnc,
      checksums: {},
    );

    final classified = await _classifyPoints(points);

    return SharePackagePreview(
      manifest: manifest,
      classifiedPoints: classified,
      photos: const {},
      isFromQr: true,
    );
  }

  /// Phân loại danh sách điểm so với CSDL máy nhận
  Future<List<ClassifiedSharePoint>> _classifyPoints(List<SharedPointPayload> points) async {
    final db = await _appDb.database;
    final List<ClassifiedSharePoint> classified = [];

    for (final pt in points) {
      // 1. Kiểm tra tính hợp lệ của tọa độ
      if (pt.latitude < -90.0 || pt.latitude > 90.0) {
        classified.add(ClassifiedSharePoint(
          point: pt,
          classification: SharePointClassification.invalid,
          invalidReason: 'Vĩ độ không hợp lệ: ${pt.latitude}',
        ));
        continue;
      }
      if (pt.longitude < -180.0 || pt.longitude > 180.0) {
        classified.add(ClassifiedSharePoint(
          point: pt,
          classification: SharePointClassification.invalid,
          invalidReason: 'Kinh độ không hợp lệ: ${pt.longitude}',
        ));
        continue;
      }

      // 2. Chuẩn hóa số điện thoại
      final normPhone = normalizeCustomerPhone(pt.phoneNumber);
      if (normPhone.isEmpty) {
        classified.add(ClassifiedSharePoint(
          point: pt,
          classification: SharePointClassification.invalid,
          invalidReason: 'Số điện thoại không hợp lệ: ${pt.phoneNumber}',
        ));
        continue;
      }

      // 3. Tra cứu trong bảng customers
      final custRows = await db.query(
        'customers',
        columns: ['id', 'full_name'],
        where: 'phone_number = ? AND deleted_at IS NULL',
        whereArgs: [normPhone],
        limit: 1,
      );

      if (custRows.isEmpty) {
        // Chưa có khách này -> newCustomer
        classified.add(ClassifiedSharePoint(
          point: pt,
          classification: SharePointClassification.newCustomer,
        ));
        continue;
      }

      final existingCustId = custRows.first['id'] as String;
      final existingCustName = custRows.first['full_name'] as String?;

      // 4. Khách đã có, kiểm tra saved_locations
      final locRows = await db.query(
        'saved_locations',
        columns: ['id', 'latitude', 'longitude'],
        where: 'customer_id = ?',
        whereArgs: [existingCustId],
        limit: 1,
      );

      if (locRows.isEmpty) {
        // Khách có nhưng chưa lưu tọa độ -> existingWithoutLocation
        classified.add(ClassifiedSharePoint(
          point: pt,
          classification: SharePointClassification.existingWithoutLocation,
          existingCustomerId: existingCustId,
          existingCustomerName: existingCustName,
        ));
        continue;
      }

      // Khách đã có tọa độ -> existingWithLocation, tính khoảng cách lệch
      final currentLat = (locRows.first['latitude'] as num).toDouble();
      final currentLng = (locRows.first['longitude'] as num).toDouble();
      final distMeters = Geolocator.distanceBetween(
        currentLat,
        currentLng,
        pt.latitude,
        pt.longitude,
      );

      classified.add(ClassifiedSharePoint(
        point: pt,
        classification: SharePointClassification.existingWithLocation,
        existingCustomerId: existingCustId,
        existingCustomerName: existingCustName,
        existingLatitude: currentLat,
        existingLongitude: currentLng,
        distanceMeters: distMeters,
      ));
    }

    return classified;
  }

  /// Kiểm tra magic bytes ảnh an toàn (JPEG, PNG, WEBP)
  bool _isValidImageBytes(Uint8List bytes) {
    if (bytes.length < 12) return false;
    // JPEG: FF D8 FF
    if (bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) return true;
    // PNG: 89 50 4E 47
    if (bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47) return true;
    // WEBP: 52 49 46 46 (RIFF) ... 57 45 42 50 (WEBP)
    if (bytes[0] == 0x52 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x46) return true;
    return false;
  }

  /// Thực hiện nhập dữ liệu từ Preview trong một Transaction duy nhất
  Future<ShareImportResult> _importPackage({
    required SharePackagePreview preview,
    required ShareImportMode mode,
    required Set<int> selectedIndexes,
    bool createShift = false,
    String? shiftName,
  }) async {
    final db = await _appDb.database;
    final nowIso = AppDatabase.currentIsoUtc();
    final nowUtc = DateTime.now().toUtc();
    final vnTime = nowUtc.add(const Duration(hours: 7));
    final nowVnDayMonth = '${vnTime.day.toString().padLeft(2, '0')}/${vnTime.month.toString().padLeft(2, '0')}';
    final workDate = nowIso.split('T').first;

    final photosDir = await _photoRepo.getPhotosDirectory();
    final thumbsDir = await _photoRepo.getThumbsDirectory();
    final List<File> writtenFiles = [];

    int addedCount = 0;
    int replacedCount = 0;
    int skippedCount = 0;
    int errorCount = 0;
    int photosAdded = 0;
    int photosSkipped = 0;
    String? createdShiftId;
    String? finalShiftName;

    try {
      await db.transaction((txn) async {
        // 1. Tạo ca mới nếu được chọn
        int deliveryOrderIndex = 1;
        if (createShift) {
          createdShiftId = UuidUtils.generate();
          finalShiftName = shiftName ?? 'Từ ${preview.manifest.senderDisplayName} $nowVnDayMonth';

          final shiftCode = 'SHIFT-${DateTime.now().millisecondsSinceEpoch % 10000}';
          await txn.insert('shifts', {
            'id': createdShiftId,
            'shift_code': shiftCode,
            'shift_name': finalShiftName,
            'work_date': workDate,
            'status': 'PREPARING',
            'created_at': nowIso,
            'updated_at': nowIso,
          });
        }

        // 2. Lặp qua từng điểm được chọn
        for (int i = 0; i < preview.classifiedPoints.length; i++) {
          if (!selectedIndexes.contains(i)) continue;

          final item = preview.classifiedPoints[i];
          if (item.classification == SharePointClassification.invalid) {
            errorCount++;
            continue;
          }

          final pt = item.point;
          final normPhone = normalizeCustomerPhone(pt.phoneNumber);

          String customerId;
          bool shouldAddPhotos = false;

          if (item.classification == SharePointClassification.newCustomer) {
            // A. Khách hàng mới: tạo khách và tạo vị trí đã lưu
            customerId = UuidUtils.generate();
            final customerCode = 'CUST-${normPhone.substring(normPhone.length > 4 ? normPhone.length - 4 : 0)}';

            await txn.insert('customers', {
              'id': customerId,
              'customer_code': customerCode,
              'full_name': pt.fullName ?? 'Khách hàng',
              'phone_number': normPhone,
              'address_text': pt.addressText ?? '',
              'search_text': '${pt.fullName ?? ''} $normPhone ${pt.addressText ?? ''}'.toLowerCase(),
              'created_at': nowIso,
              'updated_at': nowIso,
            });

            await txn.insert('saved_locations', {
              'id': UuidUtils.generate(),
              'customer_id': customerId,
              'latitude': pt.latitude,
              'longitude': pt.longitude,
              'gps_accuracy': pt.gpsAccuracy,
              'identification_notes': pt.identificationNotes,
              'created_at': nowIso,
              'updated_at': nowIso,
            });

            addedCount++;
            shouldAddPhotos = true;
          } else if (item.classification == SharePointClassification.existingWithoutLocation) {
            // B. Khách trùng SĐT chưa có vị trí: thêm vị trí
            customerId = item.existingCustomerId!;

            await txn.insert('saved_locations', {
              'id': UuidUtils.generate(),
              'customer_id': customerId,
              'latitude': pt.latitude,
              'longitude': pt.longitude,
              'gps_accuracy': pt.gpsAccuracy,
              'identification_notes': pt.identificationNotes,
              'created_at': nowIso,
              'updated_at': nowIso,
            });

            addedCount++;
            shouldAddPhotos = true;
          } else {
            // C. Khách trùng SĐT đã có vị trí
            customerId = item.existingCustomerId!;

            if (mode == ShareImportMode.replaceExisting) {
              // Thay thế vị trí: trigger trg_saved_locations_history sẽ tự động lưu vị trí cũ vào location_history
              await txn.update(
                'saved_locations',
                {
                  'latitude': pt.latitude,
                  'longitude': pt.longitude,
                  'gps_accuracy': pt.gpsAccuracy,
                  'identification_notes': pt.identificationNotes,
                  'updated_at': nowIso,
                },
                where: 'customer_id = ?',
                whereArgs: [customerId],
              );

              replacedCount++;
              shouldAddPhotos = true;
            } else {
              // Bỏ qua điểm trùng
              skippedCount++;
              shouldAddPhotos = false;
            }
          }

          // Thêm điểm vào ca mới (nếu có yêu cầu tạo ca)
          if (createShift && createdShiftId != null) {
            await txn.insert('shift_delivery_points', {
              'id': UuidUtils.generate(),
              'shift_id': createdShiftId,
              'customer_id': customerId,
              'delivery_order_index': deliveryOrderIndex++,
              'location_status': 'VERIFIED',
              'latitude': pt.latitude,
              'longitude': pt.longitude,
              'gps_accuracy': pt.gpsAccuracy,
              'identification_notes': pt.identificationNotes,
              'created_at': nowIso,
              'updated_at': nowIso,
            });
          }

          // Xử lý ảnh đính kèm của điểm
          if (shouldAddPhotos && pt.photoFileNames.isNotEmpty && preview.photos.isNotEmpty) {
            // Đếm số ảnh hiện tại của khách hàng
            final countRows = await txn.rawQuery(
              'SELECT COUNT(*) AS total FROM customer_photos WHERE customer_id = ? AND deleted_at IS NULL',
              [customerId],
            );
            int currentPhotoCount = Sqflite.firstIntValue(countRows) ?? 0;

            for (final photoName in pt.photoFileNames) {
              final photoBytes = preview.photos[photoName];
              if (photoBytes == null) continue;

              // 1. Kiểm tra dung lượng <= 5MB
              if (photoBytes.lengthInBytes > LocalSharingRepository.maxPhotoSizeBytes) {
                photosSkipped++;
                continue;
              }

              // 2. Kiểm tra magic bytes
              if (!_isValidImageBytes(photoBytes)) {
                photosSkipped++;
                continue;
              }

              // 3. Giới hạn tối đa 10 ảnh/khách
              if (currentPhotoCount >= 10) {
                photosSkipped++;
                continue;
              }

              // 4. Lưu ảnh và thumbnail vào đĩa
              final photoId = UuidUtils.generate();
              final targetFileName = '$customerId-$photoId.jpg';
              final fullFile = File(p.join(photosDir.path, targetFileName));
              final thumbFile = File(p.join(thumbsDir.path, targetFileName));

              await fullFile.writeAsBytes(photoBytes, flush: true);
              writtenFiles.add(fullFile);

              await thumbFile.writeAsBytes(photoBytes, flush: true);
              writtenFiles.add(thumbFile);

              // 5. Ghi CSDL
              await txn.insert('customer_photos', {
                'id': photoId,
                'customer_id': customerId,
                'file_name': targetFileName,
                'thumb_file_name': targetFileName,
                'created_at': nowIso,
                'deleted_at': null,
              });

              photosAdded++;
              currentPhotoCount++;
            }
          }
        }
      });
    } catch (e) {
      // Nếu có lỗi giữa chừng, rollback dọn dẹp các file ảnh vừa ghi ra đĩa
      for (final f in writtenFiles) {
        try {
          if (f.existsSync()) f.deleteSync();
        } catch (_) {}
      }
      rethrow;
    }

    // Ghi activity_log tổng hợp (không chứa PII)
    await _appDb.logActivity(
      action: 'IMPORT_SHARED_DATA',
      entity: 'sharing',
      details: {
        'addedCount': addedCount,
        'replacedCount': replacedCount,
        'skippedCount': skippedCount,
        'errorCount': errorCount,
        'photosAdded': photosAdded,
        'photosSkipped': photosSkipped,
        'createdShift': createShift,
        'mode': mode.toString(),
      },
    );

    return ShareImportResult(
      addedCount: addedCount,
      replacedCount: replacedCount,
      skippedCount: skippedCount,
      errorCount: errorCount,
      photosAdded: photosAdded,
      photosSkipped: photosSkipped,
      createdShiftId: createdShiftId,
      createdShiftName: finalShiftName,
      message: 'Nhập thành công: $addedCount điểm mới, $replacedCount đã thay, $skippedCount bỏ qua, $photosAdded ảnh',
    );
  }
}
