import { Response } from 'express';
import { AuthenticatedRequest } from '../middlewares/auth.middleware';
import { pool, query } from '../db';
import fs from 'fs';
import path from 'path';
import crypto from 'crypto';

// Ensure persistent uploads directory exists
const UPLOADS_DIR = path.join(process.cwd(), 'uploads', 'photos');
if (!fs.existsSync(UPLOADS_DIR)) {
  fs.mkdirSync(UPLOADS_DIR, { recursive: true });
}

export const getCustomerLocation = async (req: AuthenticatedRequest, res: Response) => {
  const { customerId } = req.params;

  try {
    const locRes = await query(
      `SELECT 
        sl.id,
        sl.customer_id,
        sl.latitude,
        sl.longitude,
        sl.gps_accuracy,
        sl.identification_notes,
        sl.image_url,
        sl.created_at,
        sl.updated_at,
        u1.full_name as created_by_name,
        u2.full_name as updated_by_name
       FROM saved_locations sl
       LEFT JOIN users u1 ON u1.id = sl.created_by
       LEFT JOIN users u2 ON u2.id = sl.updated_by
       WHERE sl.customer_id = $1`,
      [customerId]
    );

    if (locRes.rows.length === 0) {
      return res.status(404).json({
        success: false,
        message: 'Khách hàng này chưa có vị trí lưu',
        hasSavedLocation: false,
      });
    }

    const row = locRes.rows[0];
    return res.json({
      success: true,
      hasSavedLocation: true,
      data: {
        id: row.id,
        customerId: row.customer_id,
        latitude: parseFloat(row.latitude),
        longitude: parseFloat(row.longitude),
        gpsAccuracy: parseFloat(row.gps_accuracy),
        identificationNotes: row.identification_notes,
        imageUrl: row.image_url,
        createdBy: row.created_by_name,
        updatedBy: row.updated_by_name,
        createdAt: row.created_at,
        updatedAt: row.updated_at,
      },
    });
  } catch (error: any) {
    return res.status(500).json({ success: false, message: 'Lỗi lấy vị trí khách hàng', error: error.message });
  }
};

export const saveOrUpdateCustomerLocation = async (req: AuthenticatedRequest, res: Response) => {
  const { customerId } = req.params;
  const { latitude, longitude, gpsAccuracy, identificationNotes, imageUrl, imageBase64, deletePhoto } = req.body;
  const userId = req.user?.userId;

  let targetLat = latitude !== undefined && latitude !== null ? Number(latitude) : undefined;
  let targetLng = longitude !== undefined && longitude !== null ? Number(longitude) : undefined;
  let targetNotes = (identificationNotes !== undefined && identificationNotes !== null) ? String(identificationNotes).trim() : '';

  // If lat/lng missing or notes missing, attempt to fetch from existing location
  if (targetLat === undefined || targetLng === undefined || targetNotes.length === 0) {
    const existingBefore = await query(
      'SELECT latitude, longitude, gps_accuracy, identification_notes, image_url FROM saved_locations WHERE customer_id = $1',
      [customerId]
    );
    if (existingBefore.rows.length > 0) {
      if (targetLat === undefined) targetLat = Number(existingBefore.rows[0].latitude);
      if (targetLng === undefined) targetLng = Number(existingBefore.rows[0].longitude);
      if (targetNotes.length === 0) targetNotes = existingBefore.rows[0].identification_notes || 'Vị trí đã lưu';
    }
  }

  if (targetLat === undefined || targetLng === undefined || isNaN(targetLat) || isNaN(targetLng)) {
    return res.status(400).json({
      success: false,
      message: 'Vui lòng cung cấp tọa độ latitude, longitude hợp lệ',
    });
  }

  if (!targetNotes) {
    targetNotes = 'Vị trí đã lưu';
  }

  let createdFilePath: string | null = null;

  try {
    let finalImageUrl: string | null = imageUrl || null;
    if (deletePhoto === true) {
      finalImageUrl = null;
    }

    // Process base64 photo if provided
    if (imageBase64 && typeof imageBase64 === 'string') {
      const matches = imageBase64.match(/^data:([A-Za-z-+\/]+);base64,(.+)$/);
      let buffer: Buffer;
      let ext = 'jpg';

      if (matches && matches.length === 3) {
        const mimeType = matches[1].toLowerCase();
        if (mimeType.includes('png')) ext = 'png';
        else if (mimeType.includes('webp')) ext = 'webp';
        else if (!mimeType.includes('jpeg') && !mimeType.includes('jpg')) {
          return res.status(400).json({
            success: false,
            message: 'Định dạng ảnh không hợp lệ. Chỉ chấp nhận JPG, PNG, WEBP.',
          });
        }
        buffer = Buffer.from(matches[2], 'base64');
      } else {
        buffer = Buffer.from(imageBase64, 'base64');
      }

      // Check max size: 5MB
      if (buffer.length > 5 * 1024 * 1024) {
        return res.status(400).json({
          success: false,
          message: 'Dung lượng ảnh vượt quá giới hạn cho phép (tối đa 5MB)',
        });
      }

      // Generate randomized filename: never using customer name or phone
      const filename = `${crypto.randomUUID()}.${ext}`;
      const filePath = path.join(UPLOADS_DIR, filename);
      await fs.promises.writeFile(filePath, buffer);
      createdFilePath = filePath;

      finalImageUrl = `/api/v1/photos/${filename}`;
    }

    // Execute database operations in a strict single-client transaction
    const client = await pool.connect();
    try {
      await client.query('BEGIN');

      // Check if location exists
      const existing = await client.query('SELECT id, latitude, longitude, gps_accuracy, identification_notes, image_url FROM saved_locations WHERE customer_id = $1', [customerId]);

      let resultLocationId = '';

      if (existing.rows.length === 0) {
        // Create new location
        const insertRes = await client.query(
          `INSERT INTO saved_locations
           (customer_id, geom, latitude, longitude, gps_accuracy, identification_notes, image_url, created_by, updated_by)
           VALUES
           ($1, ST_SetSRID(ST_MakePoint($3, $2), 4326), $2, $3, $4, $5, $6, $7, $7)
           RETURNING id`,
          [customerId, targetLat, targetLng, gpsAccuracy || 0, targetNotes, finalImageUrl, userId]
        );
        resultLocationId = insertRes.rows[0].id;
      } else {
        // If no new image was uploaded and not explicitly deleted, preserve existing image_url
        if (!finalImageUrl && deletePhoto !== true) {
          finalImageUrl = existing.rows[0].image_url;
        }

        // Safe physical file cleanup when deletePhoto is explicitly requested
        if (deletePhoto === true && existing.rows[0].image_url) {
          const oldImg = existing.rows[0].image_url;
          const oldFilename = path.basename(oldImg);
          const refCheck = await client.query(
            `SELECT 1 FROM (
               SELECT image_url, customer_id FROM saved_locations
               UNION ALL
               SELECT image_url, customer_id FROM shift_delivery_points
             ) u
             WHERE u.customer_id != $1 AND u.image_url LIKE '%' || $2
             LIMIT 1`,
            [customerId, oldFilename]
          );
          if (refCheck.rows.length === 0) {
            const diskPath = path.join(UPLOADS_DIR, oldFilename);
            if (fs.existsSync(diskPath)) {
              try {
                await fs.promises.unlink(diskPath);
              } catch (unlinkErr) {
                console.error('Không thể dọn dẹp file ảnh cũ:', unlinkErr);
              }
            }
          }
        }

        // Update existing location (Trigger automatically writes to location_history)
        const updateRes = await client.query(
          `UPDATE saved_locations
           SET geom = ST_SetSRID(ST_MakePoint($4, $3), 4326),
               latitude = $1,
               longitude = $2,
               gps_accuracy = $5,
               identification_notes = $6,
               image_url = $7,
               updated_by = $8,
               updated_at = CURRENT_TIMESTAMP
           WHERE customer_id = $9
           RETURNING id`,
          [targetLat, targetLng, targetLat, targetLng, gpsAccuracy || 0, targetNotes, finalImageUrl, userId, customerId]
        );
        resultLocationId = updateRes.rows[0].id;
      }

      // Synchronize photo with customer_photos if a new photo was uploaded
      if (finalImageUrl && imageBase64) {
        await client.query(
          `INSERT INTO customer_photos (customer_id, image_url, created_by)
           VALUES ($1, $2, $3)`,
          [customerId, finalImageUrl, userId]
        );
      }

      // Synchronize full coordinates, notes, status, and image with active shift_delivery_points of confirming shipper
      const userRole = req.user?.roleName;
      let syncCondition = `s.shipper_id = $9 AND (s.status = 'PREPARING' OR s.status = 'IN_PROGRESS')`;
      if (userRole === 'ADMIN') {
        syncCondition = `(s.status = 'PREPARING' OR s.status = 'IN_PROGRESS')`;
      }

      const syncRes = await client.query(
        `UPDATE shift_delivery_points sdp
         SET latitude = $1,
             longitude = $2,
             geom = ST_SetSRID(ST_MakePoint($4, $3), 4326),
             gps_accuracy = $5,
             identification_notes = $6,
             location_status = 'VERIFIED',
             image_url = $7,
             updated_at = NOW()
         FROM shifts s
         WHERE sdp.shift_id = s.id
           AND sdp.customer_id = $8
           AND ${syncCondition}`,
        [targetLat, targetLng, targetLat, targetLng, gpsAccuracy || 0, targetNotes, finalImageUrl, customerId, userId]
      );

      const updatedShiftPointsCount = syncRes.rowCount || 0;

      // If photo was explicitly deleted, ensure matching active shift delivery points have image_url = NULL
      if (deletePhoto === true) {
        await client.query(
          `UPDATE shift_delivery_points sdp
           SET image_url = NULL, updated_at = NOW()
           FROM shifts s
           WHERE sdp.shift_id = s.id
             AND sdp.customer_id = $1
             AND ${syncCondition}`,
          userRole === 'ADMIN' ? [customerId] : [customerId, userId]
        );
      }

      // Write audit log within the same transaction (AGENTS.md rule 2.5 - Audit Integrity)
      await client.query(
        `INSERT INTO audit_logs (user_id, action, entity, entity_id, details) VALUES ($1, $2, $3, $4, $5)`,
        [
          userId,
          existing.rows.length === 0 ? 'CREATE_LOCATION' : 'UPDATE_LOCATION',
          'SAVED_LOCATION',
          resultLocationId,
          JSON.stringify({
            customerId,
            latitude: targetLat,
            longitude: targetLng,
            gpsAccuracy: gpsAccuracy || 0,
            notes: targetNotes,
            hasPhoto: !!finalImageUrl,
            updatedShiftPointsCount,
          }),
        ]
      );

      await client.query('COMMIT');

      return res.json({
        success: true,
        message: existing.rows.length === 0 ? 'Lưu vị trí khách hàng thành công' : 'Cập nhật vị trí khách hàng thành công',
        data: {
          locationId: resultLocationId,
          customerId,
          latitude: targetLat,
          longitude: targetLng,
          gpsAccuracy: gpsAccuracy || 0,
          identificationNotes: targetNotes,
          imageUrl: finalImageUrl,
          updatedShiftPointsCount,
        },
      });
    } catch (dbError: any) {
      await client.query('ROLLBACK');

      // If a new photo file was created on disk in this request, clean it up to prevent orphaned files
      if (createdFilePath && fs.existsSync(createdFilePath)) {
        try {
          await fs.promises.unlink(createdFilePath);
        } catch (unlinkErr) {
          console.error('Không thể dọn dẹp file ảnh mới tạo sau khi rollback CSDL:', unlinkErr);
        }
      }

      throw dbError; // Rethrow to outer catch, preserving original error
    } finally {
      client.release();
    }
  } catch (error: any) {
    console.error('Lỗi lưu vị trí khách hàng stack:', error);
    return res.status(500).json({ success: false, message: 'Lỗi lưu vị trí khách hàng', error: error.message });
  }
};

/**
 * Tra cứu hồ sơ vị trí khách hàng bằng số điện thoại
 */
export const lookupCustomerByPhone = async (req: AuthenticatedRequest, res: Response) => {
  const { phoneNumber } = req.params;

  if (!phoneNumber) {
    return res.status(400).json({ success: false, message: 'Vui lòng cung cấp số điện thoại tra cứu' });
  }

  // Normalize phone number: strip non-digits and standardize
  let cleanPhone = phoneNumber.replace(/\D/g, '');
  if (cleanPhone.startsWith('84') && cleanPhone.length === 11) {
    cleanPhone = '0' + cleanPhone.substring(2);
  } else if (cleanPhone.length === 9 && !cleanPhone.startsWith('0')) {
    cleanPhone = '0' + cleanPhone;
  }

  try {
    const custRes = await query(
      `SELECT c.id, c.customer_code, c.full_name, c.phone_number, c.address_text, c.area_id, a.name as area_name
       FROM customers c
       JOIN areas a ON a.id = c.area_id
       WHERE c.phone_number = $1 OR c.phone_number = $2`,
      [cleanPhone, phoneNumber]
    );

    if (custRes.rows.length === 0) {
      return res.status(404).json({
        success: false,
        message: 'Không tìm thấy khách hàng nào với số điện thoại này',
        hasSavedLocation: false,
      });
    }

    const customer = custRes.rows[0];

    // Check scope: if user is SHIPPER, verify assigned area
    if (req.user?.roleName === 'SHIPPER') {
      const assigned = req.user.assignedAreaIds || [];
      if (!assigned.includes(customer.area_id)) {
        return res.status(403).json({
          success: false,
          message: 'Khách hàng này thuộc khu vực bạn không được phân công phụ trách',
        });
      }
    }

    // Lookup saved location
    const locRes = await query(
      `SELECT
        sl.id,
        sl.latitude,
        sl.longitude,
        sl.gps_accuracy,
        sl.identification_notes,
        sl.image_url,
        sl.created_at,
        sl.updated_at,
        u.full_name as updated_by_name
       FROM saved_locations sl
       LEFT JOIN users u ON u.id = sl.updated_by
       WHERE sl.customer_id = $1`,
      [customer.id]
    );

    // Lookup customer photos (up to 3 first, and total count)
    const photosRes = await query(
      `SELECT id, image_url as "imageUrl", created_at as "createdAt"
       FROM customer_photos
       WHERE customer_id = $1 AND deleted_at IS NULL
       ORDER BY created_at DESC`,
      [customer.id]
    );

    const hasSaved = locRes.rows.length > 0;
    const loc = hasSaved ? locRes.rows[0] : null;

    let photoCount = photosRes.rows.length;
    let photos = photosRes.rows.slice(0, 3);
    if (photoCount === 0 && loc?.image_url) {
      photoCount = 1;
      photos = [{ id: 'legacy', imageUrl: loc.image_url, createdAt: loc.created_at }];
    }

    return res.json({
      success: true,
      hasSavedLocation: hasSaved,
      data: {
        customer: {
          id: customer.id,
          customerCode: customer.customer_code,
          fullName: customer.full_name,
          phoneNumber: customer.phone_number,
          addressText: customer.address_text,
          area: {
            id: customer.area_id,
            name: customer.area_name,
          },
        },
        hasSavedLocation: hasSaved,
        photoCount,
        photos,
        location: loc
          ? {
              id: loc.id,
              latitude: parseFloat(loc.latitude),
              longitude: parseFloat(loc.longitude),
              gpsAccuracy: parseFloat(loc.gps_accuracy),
              identificationNotes: loc.identification_notes,
              imageUrl: loc.image_url,
              photoCount,
              photos,
              updatedBy: loc.updated_by_name,
              updatedAt: loc.updated_at,
            }
          : null,
      },
    });
  } catch (error: any) {
    return res.status(500).json({ success: false, message: 'Lỗi tra cứu khách hàng bằng số điện thoại', error: error.message });
  }
};

/**
 * Phục vụ ảnh có kiểm soát xác thực JWT, phân quyền khu vực và an toàn chống path traversal
 */
export const servePhoto = async (req: AuthenticatedRequest, res: Response) => {
  const { filename } = req.params;
  const user = req.user;

  if (!user) {
    return res.status(401).json({ success: false, message: 'Yêu cầu xác thực tài khoản' });
  }

  // Strict validation of filename: only uuid or cust-photo-uuid + extension, preventing any ../ directory traversal
  const safeFilenameRegex = /^(cust-photo-)?[0-9a-fA-F-]{36}\.(jpg|jpeg|png|webp)$/;
  if (!safeFilenameRegex.test(filename)) {
    return res.status(400).json({ success: false, message: 'Tên tệp không hợp lệ' });
  }

  const filePath = path.join(UPLOADS_DIR, filename);

  if (!fs.existsSync(filePath)) {
    return res.status(404).json({ success: false, message: 'Ảnh không tồn tại' });
  }

  try {
    // Check relation between photo, location, customer and area
    // Handles both current saved_locations and location_history (even if current location was deleted)
    const accessRes = await query(
      `SELECT DISTINCT c.area_id
       FROM (
         SELECT customer_id FROM saved_locations WHERE image_url LIKE '%' || $1
         UNION
         SELECT customer_id FROM location_history WHERE image_url LIKE '%' || $1
         UNION
         SELECT customer_id FROM shift_delivery_points WHERE image_url LIKE '%' || $1
         UNION
         SELECT customer_id FROM customer_photos WHERE image_url LIKE '%' || $1 AND deleted_at IS NULL
       ) photo_refs
       JOIN customers c ON c.id = photo_refs.customer_id`,
      [filename]
    );

    if (accessRes.rows.length === 0) {
      return res.status(404).json({
        success: false,
        message: 'Ảnh không tồn tại hoặc không gắn với hồ sơ vị trí hợp lệ',
      });
    }

    // Role-based area scope enforcement
    if (user.roleName === 'ADMIN') {
      // Admin has permission across all areas
    } else if (user.roleName === 'SHIPPER') {
      const photoAreaIds = accessRes.rows.map((r: any) => r.area_id);
      const userAreas = user.assignedAreaIds || [];
      const hasAccess = photoAreaIds.some((areaId: string) => userAreas.includes(areaId));

      if (!hasAccess) {
        return res.status(403).json({
          success: false,
          message: 'Bạn không có quyền truy cập ảnh của khách hàng thuộc khu vực này',
        });
      }
    } else {
      return res.status(403).json({
        success: false,
        message: 'Vai trò người dùng không có quyền truy cập ảnh',
      });
    }

    const ext = path.extname(filename).toLowerCase();
    const mimeMap: Record<string, string> = {
      '.jpg': 'image/jpeg',
      '.jpeg': 'image/jpeg',
      '.png': 'image/png',
      '.webp': 'image/webp',
    };

    res.setHeader('Content-Type', mimeMap[ext] || 'application/octet-stream');
    res.setHeader('Cache-Control', 'private, no-store, no-cache, must-revalidate');
    res.setHeader('Pragma', 'no-cache');
    const stream = fs.createReadStream(filePath);
    stream.on('error', () => {
      if (!res.headersSent) {
        res.status(500).json({ success: false, message: 'Lỗi đọc tệp ảnh' });
      }
    });
    stream.pipe(res);
  } catch (error: any) {
    // Never leak filesystem path or internal stack in error response
    return res.status(500).json({ success: false, message: 'Lỗi trong quá trình kiểm tra quyền truy cập ảnh' });
  }
};

export const getLocationHistory = async (req: AuthenticatedRequest, res: Response) => {
  const { customerId } = req.params;

  try {
    const historyRes = await query(
      `SELECT 
        lh.id,
        lh.latitude,
        lh.longitude,
        lh.gps_accuracy,
        lh.identification_notes,
        lh.image_url,
        lh.change_reason,
        lh.created_at,
        u.full_name as changed_by_name
       FROM location_history lh
       LEFT JOIN users u ON u.id = lh.changed_by
       WHERE lh.customer_id = $1
       ORDER BY lh.created_at DESC`,
      [customerId]
    );

    return res.json({
      success: true,
      data: historyRes.rows.map((r) => ({
        id: r.id,
        latitude: parseFloat(r.latitude),
        longitude: parseFloat(r.longitude),
        gpsAccuracy: parseFloat(r.gps_accuracy),
        identificationNotes: r.identification_notes,
        imageUrl: r.image_url,
        changeReason: r.change_reason,
        createdAt: r.created_at,
        changedBy: r.changed_by_name,
      })),
    });
  } catch (error: any) {
    return res.status(500).json({ success: false, message: 'Lỗi lấy lịch sử vị trí', error: error.message });
  }
};

// 7. DELETE /api/v1/customers/:customerId/location - Shipper/Admin xóa vị trí đã lưu của khách hàng
export const deleteCustomerLocation = async (req: AuthenticatedRequest, res: Response) => {
  const { customerId } = req.params;
  const userId = req.user?.userId;
  const userRole = req.user?.roleName;

  if (!userId) {
    return res.status(401).json({ success: false, message: 'Chưa xác thực người dùng' });
  }

  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    // 1. Kiểm tra vị trí đã lưu có tồn tại không
    const locRes = await client.query(
      `SELECT sl.id, sl.customer_id, sl.image_url, sl.created_by, sl.updated_by, c.area_id
       FROM saved_locations sl
       JOIN customers c ON c.id = sl.customer_id
       WHERE sl.customer_id = $1`,
      [customerId]
    );

    if (locRes.rows.length === 0) {
      await client.query('ROLLBACK');
      return res.status(404).json({ success: false, message: 'Khách hàng này chưa có vị trí đã lưu' });
    }

    const loc = locRes.rows[0];
    const locationId = loc.id;
    const customerAreaId = loc.area_id;

    // 2. Phân quyền:
    // ADMIN được xóa mọi vị trí.
    // SHIPPER chỉ được xóa vị trí do chính mình lưu (created_by hoặc updated_by) VÀ thuộc khu vực mình phụ trách.
    if (userRole === 'SHIPPER') {
      const isOwner = loc.created_by === userId || loc.updated_by === userId;
      if (!isOwner) {
        await client.query('ROLLBACK');
        return res.status(403).json({
          success: false,
          message: 'Bạn chỉ có quyền xóa vị trí do chính mình tạo hoặc cập nhật',
        });
      }

      // Kiểm tra khu vực phụ trách
      const areaCheck = await client.query(
        `SELECT 1 FROM user_areas WHERE user_id = $1 AND area_id = $2`,
        [userId, customerAreaId]
      );
      if (areaCheck.rows.length === 0) {
        await client.query('ROLLBACK');
        return res.status(403).json({
          success: false,
          message: 'Khách hàng không thuộc khu vực bạn được phân công phụ trách',
        });
      }
    }

    // 3. Bảo toàn kiểm toán: Tách liên kết saved_location_id trong location_history trước khi xóa
    await client.query(
      `UPDATE location_history SET saved_location_id = NULL WHERE saved_location_id = $1`,
      [locationId]
    );

    // 4. Xóa bản ghi trong saved_locations
    await client.query(`DELETE FROM saved_locations WHERE id = $1`, [locationId]);

    // 5. Điểm giao trong các ca đang chuẩn bị hoặc đang chạy của khách đó quay về NO_LOCATION
    // QUY TẮC MỚI (TASK 012B):
    // a. Chỉ đưa về NO_LOCATION những điểm giao đang VERIFIED. Điểm giao TEMPORARY phải được GIỮ NGUYÊN.
    // b. Giới hạn theo ca của chính shipper đang xóa (và ca PREPARING/IN_PROGRESS).
    let shiftRevertCondition = `s.shipper_id = $2 AND (s.status = 'PREPARING' OR s.status = 'IN_PROGRESS')`;
    if (userRole === 'ADMIN') {
      shiftRevertCondition = `(s.status = 'PREPARING' OR s.status = 'IN_PROGRESS')`;
    }

    const revertRes = await client.query(
      `UPDATE shift_delivery_points sdp
       SET location_status = 'NO_LOCATION',
           latitude = NULL,
           longitude = NULL,
           geom = NULL,
           gps_accuracy = 0,
           identification_notes = NULL,
           image_url = NULL,
           updated_at = NOW()
       FROM shifts s
       WHERE sdp.shift_id = s.id
         AND sdp.customer_id = $1
         AND sdp.location_status = 'VERIFIED'
         AND ${shiftRevertCondition}`,
      userRole === 'ADMIN' ? [customerId] : [customerId, userId]
    );

    const revertedShiftPointsCount = revertRes.rowCount || 0;

    // 6. Ghi nhật ký audit_logs (AGENTS.md rule 2.5 - Audit Integrity)
    await client.query(
      `INSERT INTO audit_logs (user_id, action, entity, entity_id, details)
       VALUES ($1, 'DELETE_LOCATION', 'SAVED_LOCATION', $2, $3)`,
      [
        userId,
        locationId,
        JSON.stringify({
          customerId,
          deletedByRole: userRole,
          revertedShiftPointsCount,
        }),
      ]
    );

    await client.query('COMMIT');

    return res.status(200).json({
      success: true,
      message: 'Xóa vị trí đã lưu thành công (lịch sử đối soát được bảo toàn)',
      data: {
        locationId,
        customerId,
        revertedShiftPointsCount,
      },
    });
  } catch (error: any) {
    await client.query('ROLLBACK');
    return res.status(500).json({
      success: false,
      message: 'Lỗi máy chủ khi xóa vị trí khách hàng',
      error: error.message,
    });
  } finally {
    client.release();
  }
};

/**
 * TASK: MASTER-MAP-014: Lấy danh sách toàn bộ vị trí đã lưu do chính shipper đăng nhập tạo/cập nhật
 * Trả về danh sách điểm kèm tên, SĐT, ảnh, ghi chú để vẽ marker trên bản đồ chính độc lập với ca.
 */
export const getMySavedLocations = async (req: AuthenticatedRequest, res: Response) => {
  const userId = req.user?.userId;
  const roleName = req.user?.roleName;

  try {
    let queryText = `
      SELECT 
        sl.id as location_id,
        sl.latitude,
        sl.longitude,
        sl.gps_accuracy,
        sl.identification_notes,
        sl.image_url,
        sl.created_at,
        sl.updated_at,
        c.id as customer_id,
        c.customer_code,
        c.full_name as customer_name,
        c.phone_number as customer_phone,
        c.address_text as customer_address,
        a.id as area_id,
        a.name as area_name,
        COALESCE(cp_agg.photo_count, 0) as photo_count,
        COALESCE(cp_agg.photos, '[]'::json) as photos
      FROM saved_locations sl
      JOIN customers c ON c.id = sl.customer_id
      JOIN areas a ON a.id = c.area_id
      LEFT JOIN LATERAL (
        SELECT 
          COUNT(*)::int as photo_count,
          (
            SELECT COALESCE(json_agg(photo_item), '[]'::json)
            FROM (
              SELECT id, image_url as "imageUrl", created_at as "createdAt"
              FROM customer_photos
              WHERE customer_id = sl.customer_id AND deleted_at IS NULL
              ORDER BY created_at DESC
              LIMIT 3
            ) photo_item
          ) as photos
        FROM customer_photos
        WHERE customer_id = sl.customer_id AND deleted_at IS NULL
      ) cp_agg ON true
    `;

    const params: any[] = [];
    if (roleName !== 'ADMIN') {
      params.push(userId);
      queryText += ` WHERE (sl.created_by = $1 OR sl.updated_by = $1)`;
    }

    queryText += ` ORDER BY sl.updated_at DESC`;

    const result = await query(queryText, params);

    return res.status(200).json({
      success: true,
      data: result.rows.map((row) => ({
        id: row.location_id,
        customerId: row.customer_id,
        customerCode: row.customer_code,
        customerName: row.customer_name,
        customerPhone: row.customer_phone,
        customerAddress: row.customer_address,
        areaId: row.area_id,
        areaName: row.area_name,
        latitude: parseFloat(row.latitude),
        longitude: parseFloat(row.longitude),
        gpsAccuracy: parseFloat(row.gps_accuracy) || 0.0,
        identificationNotes: row.identification_notes || '',
        imageUrl: row.image_url || null,
        photoCount: parseInt(row.photo_count, 10) || (row.image_url ? 1 : 0),
        photos: (row.photos && row.photos.length > 0)
          ? row.photos
          : (row.image_url ? [{ id: 'legacy', imageUrl: row.image_url, createdAt: row.created_at }] : []),
        createdAt: row.created_at,
        updatedAt: row.updated_at,
      })),
    });
  } catch (error: any) {
    return res.status(500).json({
      success: false,
      message: 'Lỗi lấy danh sách vị trí đã lưu của shipper',
      error: error.message,
    });
  }
};

