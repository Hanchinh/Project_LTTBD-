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

      // Synchronize full coordinates, notes, status, and image with active shift_delivery_points
      const userRole = req.user?.roleName;
      let syncCondition = `(s.status = 'PREPARING' OR (s.status = 'IN_PROGRESS' AND s.shipper_id = $9))`;
      if (userRole === 'ADMIN') {
        syncCondition = `(s.status = 'PREPARING' OR s.status = 'IN_PROGRESS')`;
      }

      await client.query(
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

      // If photo was explicitly deleted, ensure all shift delivery points for this customer have image_url = NULL
      if (deletePhoto === true) {
        await client.query(
          `UPDATE shift_delivery_points
           SET image_url = NULL, updated_at = NOW()
           WHERE customer_id = $1`,
          [customerId]
        );
      }

      // Write audit log within the same transaction
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

    const hasSaved = locRes.rows.length > 0;
    const loc = hasSaved ? locRes.rows[0] : null;

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
        location: loc
          ? {
              id: loc.id,
              latitude: parseFloat(loc.latitude),
              longitude: parseFloat(loc.longitude),
              gpsAccuracy: parseFloat(loc.gps_accuracy),
              identificationNotes: loc.identification_notes,
              imageUrl: loc.image_url,
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

  // Strict validation of filename: only uuid + extension, preventing any ../ directory traversal
  const safeFilenameRegex = /^[0-9a-fA-F-]{36}\.(jpg|jpeg|png|webp)$/;
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
