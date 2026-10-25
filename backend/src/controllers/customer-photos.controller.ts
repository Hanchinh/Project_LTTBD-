import { Response } from 'express';
import { AuthenticatedRequest } from '../middlewares/auth.middleware';
import { pool, query } from '../db';
import fs from 'fs';
import path from 'path';
import crypto from 'crypto';

const UPLOADS_DIR = path.join(process.cwd(), 'uploads', 'photos');
if (!fs.existsSync(UPLOADS_DIR)) {
  fs.mkdirSync(UPLOADS_DIR, { recursive: true });
}

/**
 * 1. GET /api/v1/customers/:customerId/photos
 * Lấy danh sách ảnh của khách hàng (chỉ các ảnh chưa xóa mềm), mới nhất xếp trước.
 */
export const getCustomerPhotos = async (req: AuthenticatedRequest, res: Response) => {
  const { customerId } = req.params;

  try {
    const result = await query(
      `SELECT
        id,
        customer_id AS "customerId",
        image_url AS "imageUrl",
        created_by AS "createdBy",
        created_at AS "createdAt"
       FROM customer_photos
       WHERE customer_id = $1 AND deleted_at IS NULL
       ORDER BY created_at DESC`,
      [customerId]
    );

    return res.status(200).json({
      success: true,
      data: result.rows,
    });
  } catch (error: any) {
    console.error('Lỗi lấy danh sách ảnh khách hàng:', error);
    return res.status(500).json({
      success: false,
      message: 'Lỗi lấy danh sách ảnh khách hàng',
      error: error.message,
    });
  }
};

/**
 * 2. POST /api/v1/customers/:customerId/photos
 * Thêm 1 ảnh cho khách hàng (imageBase64), tối đa 10 ảnh/khách, dung lượng <= 5MB, định dạng JPG/PNG/WEBP.
 */
export const addCustomerPhoto = async (req: AuthenticatedRequest, res: Response) => {
  const { customerId } = req.params;
  const { imageBase64 } = req.body;
  const userId = req.user?.userId || (req.user as any)?.id;

  if (!imageBase64 || typeof imageBase64 !== 'string' || imageBase64.trim().length === 0) {
    return res.status(400).json({
      success: false,
      message: 'Vui lòng cung cấp dữ liệu ảnh dạng imageBase64',
    });
  }

  // Parse MIME and Base64 buffer
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

  // Check magic bytes to strictly ensure valid JPEG/PNG/WEBP
  const isJpeg = buffer.length > 2 && buffer[0] === 0xFF && buffer[1] === 0xD8;
  const isPng = buffer.length > 4 && buffer[0] === 0x89 && buffer[1] === 0x50 && buffer[2] === 0x4E && buffer[3] === 0x47;
  const isWebp = buffer.length > 12 && buffer.toString('ascii', 0, 4) === 'RIFF' && buffer.toString('ascii', 8, 12) === 'WEBP';

  if (!isJpeg && !isPng && !isWebp) {
    return res.status(400).json({
      success: false,
      message: 'Định dạng ảnh không hợp lệ. Chỉ chấp nhận JPG, PNG, WEBP.',
    });
  }

  if (isPng) ext = 'png';
  else if (isWebp) ext = 'webp';
  else ext = 'jpg';

  // Check max size: 5MB
  if (buffer.length > 5 * 1024 * 1024) {
    return res.status(400).json({
      success: false,
      message: 'Dung lượng ảnh vượt quá giới hạn cho phép (tối đa 5MB)',
    });
  }

  const client = await pool.connect();
  let createdFilePath: string | null = null;

  try {
    await client.query('BEGIN');

    // Check photo count limit: max 10 photos per customer (deleted_at IS NULL)
    const countRes = await client.query(
      `SELECT COUNT(*) AS count FROM customer_photos WHERE customer_id = $1 AND deleted_at IS NULL`,
      [customerId]
    );
    const currentCount = parseInt(countRes.rows[0].count, 10);
    if (currentCount >= 10) {
      await client.query('ROLLBACK');
      return res.status(400).json({
        success: false,
        message: 'Khách hàng này đã đạt giới hạn tối đa 10 ảnh',
      });
    }

    // Generate random UUID filename
    const filename = `${crypto.randomUUID()}.${ext}`;
    const filePath = path.join(UPLOADS_DIR, filename);
    await fs.promises.writeFile(filePath, buffer);
    createdFilePath = filePath;

    const imageUrl = `/api/v1/photos/${filename}`;

    // Insert into customer_photos
    const insertRes = await client.query(
      `INSERT INTO customer_photos (customer_id, image_url, created_by)
       VALUES ($1, $2, $3)
       RETURNING id, customer_id AS "customerId", image_url AS "imageUrl", created_by AS "createdBy", created_at AS "createdAt"`,
      [customerId, imageUrl, userId]
    );
    const photo = insertRes.rows[0];

    // Keep backwards compatibility with saved_locations.image_url if saved_locations exists and has no photo
    await client.query(
      `UPDATE saved_locations
       SET image_url = COALESCE(image_url, $1), updated_at = NOW()
       WHERE customer_id = $2`,
      [imageUrl, customerId]
    );

    // Write audit log: ADD_PHOTO
    await client.query(
      `INSERT INTO audit_logs (user_id, action, entity, entity_id, details)
       VALUES ($1, $2, $3, $4, $5)`,
      [
        userId,
        'ADD_PHOTO',
        'CUSTOMER_PHOTO',
        photo.id,
        JSON.stringify({ customerId, imageUrl, filename }),
      ]
    );

    await client.query('COMMIT');

    return res.status(201).json({
      success: true,
      message: 'Thêm ảnh khách hàng thành công',
      data: photo,
    });
  } catch (error: any) {
    await client.query('ROLLBACK');
    if (createdFilePath && fs.existsSync(createdFilePath)) {
      try {
        await fs.promises.unlink(createdFilePath);
      } catch (_) {}
    }
    console.error('Lỗi thêm ảnh khách hàng:', error);
    return res.status(500).json({
      success: false,
      message: 'Lỗi thêm ảnh khách hàng',
      error: error.message,
    });
  } finally {
    client.release();
  }
};

/**
 * 3. DELETE /api/v1/customers/:customerId/photos/:photoId
 * Xóa MỀM (cập nhật deleted_at = NOW()), chỉ shipper đã tải ảnh hoặc ADMIN, ghi audit_logs, KHÔNG xóa file trên đĩa.
 */
export const deleteCustomerPhoto = async (req: AuthenticatedRequest, res: Response) => {
  const { customerId, photoId } = req.params;
  const user = req.user;

  if (!user) {
    return res.status(401).json({ success: false, message: 'Chưa xác thực' });
  }

  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    // Check photo exists and is not already deleted
    const photoRes = await client.query(
      `SELECT id, customer_id, image_url, created_by, deleted_at
       FROM customer_photos
       WHERE id = $1 AND customer_id = $2 AND deleted_at IS NULL`,
      [photoId, customerId]
    );

    if (photoRes.rows.length === 0) {
      await client.query('ROLLBACK');
      return res.status(404).json({
        success: false,
        message: 'Ảnh không tồn tại hoặc đã bị xóa',
      });
    }

    const photo = photoRes.rows[0];

    const currentUserId = user.userId || (user as any).id;
    const currentRole = user.roleName || (user as any).role;

    // Permission: Only shipper who uploaded the photo or ADMIN can delete
    if (currentRole !== 'ADMIN' && photo.created_by !== currentUserId) {
      await client.query('ROLLBACK');
      return res.status(403).json({
        success: false,
        message: 'Bạn không có quyền xóa ảnh do người khác tải lên',
      });
    }

    // Soft delete: update deleted_at
    await client.query(
      `UPDATE customer_photos
       SET deleted_at = CURRENT_TIMESTAMP
       WHERE id = $1`,
      [photoId]
    );

    // Audit log: DELETE_PHOTO
    await client.query(
      `INSERT INTO audit_logs (user_id, action, entity, entity_id, details)
       VALUES ($1, $2, $3, $4, $5)`,
      [
        currentUserId,
        'DELETE_PHOTO',
        'CUSTOMER_PHOTO',
        photoId,
        JSON.stringify({ customerId, imageUrl: photo.image_url, softDeleted: true }),
      ]
    );

    await client.query('COMMIT');

    return res.status(200).json({
      success: true,
      message: 'Đã xóa ảnh thành công',
    });
  } catch (error: any) {
    await client.query('ROLLBACK');
    console.error('Lỗi xóa ảnh khách hàng:', error);
    return res.status(500).json({
      success: false,
      message: 'Lỗi xóa ảnh khách hàng',
      error: error.message,
    });
  } finally {
    client.release();
  }
};
