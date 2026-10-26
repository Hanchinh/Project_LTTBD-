import { Response } from 'express';
import { AuthenticatedRequest } from '../middlewares/auth.middleware';
import { query } from '../db';

/**
 * Chuẩn hóa số điện thoại Việt Nam
 */
function normalizePhone(rawPhone?: string): string {
  if (!rawPhone) return '';
  let clean = rawPhone.trim().replace(/\D/g, '');
  if (clean.startsWith('84') && clean.length === 11) {
    clean = '0' + clean.substring(2);
  } else if (clean.length === 9 && !clean.startsWith('0')) {
    clean = '0' + clean;
  }
  return clean;
}

/**
 * 1. POST /api/v1/shares
 * Tạo lời mời chia sẻ dữ liệu vị trí cho shipper khác
 */
export const createShare = async (req: AuthenticatedRequest, res: Response) => {
  const userId = req.user?.userId;
  const { recipientPhone, scope, shiftId, includePhotos, expiresInDays } = req.body;

  if (!userId) {
    return res.status(401).json({ success: false, message: 'Yêu cầu xác thực tài khoản' });
  }

  // Chuẩn hóa số điện thoại
  const normalizedPhone = normalizePhone(recipientPhone);
  if (!normalizedPhone) {
    return res.status(400).json({
      success: false,
      message: 'Không gửi được lời mời, kiểm tra số điện thoại',
    });
  }

  // Giới hạn tần suất: tối đa 10 lời mời / giờ / người dùng
  const rateRes = await query(
    `SELECT COUNT(*)::int as count 
     FROM data_shares 
     WHERE owner_id = $1 AND created_at > NOW() - INTERVAL '1 hour'`,
    [userId]
  );
  if (rateRes.rows[0]?.count >= 10) {
    return res.status(429).json({
      success: false,
      message: 'Bạn đã đạt giới hạn gửi lời mời trong 1 giờ. Vui lòng thử lại sau.',
    });
  }

  // Tra cứu người nhận: không phân biệt lỗi để tránh lộ việc số điện thoại có tồn tại hay không
  const recipientRes = await query(
    'SELECT id, full_name, is_active FROM users WHERE phone_number = $1 OR phone_number = $2',
    [normalizedPhone, recipientPhone]
  );

  if (recipientRes.rows.length === 0 || !recipientRes.rows[0].is_active) {
    return res.status(400).json({
      success: false,
      message: 'Không gửi được lời mời, kiểm tra số điện thoại',
    });
  }

  const recipient = recipientRes.rows[0];

  // Từ chối tự chia sẻ cho chính mình
  if (recipient.id === userId) {
    return res.status(400).json({
      success: false,
      message: 'Không gửi được lời mời, kiểm tra số điện thoại',
    });
  }

  // Kiểm tra scope hợp lệ
  if (scope !== 'ALL_POINTS' && scope !== 'SHIFT') {
    return res.status(400).json({
      success: false,
      message: 'Phạm vi chia sẻ không hợp lệ (chỉ chấp nhận ALL_POINTS hoặc SHIFT)',
    });
  }

  // Kiểm tra quyền đối với ca làm việc nếu scope = 'SHIFT'
  let targetShiftId: string | null = null;
  if (scope === 'SHIFT') {
    if (!shiftId) {
      return res.status(400).json({
        success: false,
        message: 'Vui lòng chọn ca làm việc cần chia sẻ',
      });
    }

    const shiftRes = await query(
      'SELECT id FROM shifts WHERE id = $1 AND shipper_id = $2',
      [shiftId, userId]
    );

    if (shiftRes.rows.length === 0) {
      return res.status(400).json({
        success: false,
        message: 'Ca làm việc không hợp lệ hoặc không thuộc quyền quản lý của bạn',
      });
    }

    targetShiftId = shiftId;
  }

  // Kiểm tra không có 2 lời mời PENDING hoặc ACTIVE trùng nhau
  const dupCheck = await query(
    `SELECT id FROM data_shares
     WHERE owner_id = $1 
       AND recipient_id = $2 
       AND scope = $3 
       AND (shift_id = $4 OR (shift_id IS NULL AND $4 IS NULL))
       AND status IN ('PENDING', 'ACTIVE')`,
    [userId, recipient.id, scope, targetShiftId]
  );

  if (dupCheck.rows.length > 0) {
    return res.status(400).json({
      success: false,
      message: 'Không gửi được lời mời, kiểm tra số điện thoại',
    });
  }

  // Tính thời điểm hết hạn
  let expiresAt: Date | null = null;
  if (expiresInDays !== undefined && expiresInDays !== null) {
    const days = parseInt(String(expiresInDays), 10);
    if (!isNaN(days) && days > 0) {
      expiresAt = new Date(Date.now() + days * 24 * 60 * 60 * 1000);
    }
  }

  try {
    const insertRes = await query(
      `INSERT INTO data_shares (
         owner_id, recipient_id, scope, shift_id, include_photos, status, expires_at
       ) VALUES ($1, $2, $3, $4, $5, 'PENDING', $6)
       RETURNING id, owner_id, recipient_id, scope, shift_id, include_photos, status, created_at, expires_at`,
      [userId, recipient.id, scope, targetShiftId, !!includePhotos, expiresAt]
    );

    const share = insertRes.rows[0];

    // Ghi nhật ký kiểm toán (không ghi thông tin cá nhân khách hàng)
    await query(
      `INSERT INTO audit_logs (user_id, action, entity, entity_id, details)
       VALUES ($1, 'SHARE_CREATED', 'DATA_SHARE', $2, $3)`,
      [
        userId,
        share.id,
        JSON.stringify({
          shareId: share.id,
          recipientId: recipient.id,
          scope,
          shiftId: targetShiftId,
          includePhotos: !!includePhotos,
          expiresInDays: expiresInDays ? parseInt(String(expiresInDays), 10) : null,
        }),
      ]
    );

    return res.status(201).json({
      success: true,
      message: 'Gửi lời mời chia sẻ thành công',
      data: share,
    });
  } catch (error: any) {
    return res.status(500).json({
      success: false,
      message: 'Lỗi khi gửi lời mời chia sẻ dữ liệu',
      error: error.message,
    });
  }
};

/**
 * 2. GET /api/v1/shares/outgoing
 * Danh sách lời mời do chính shipper gửi đi
 */
export const getOutgoingShares = async (req: AuthenticatedRequest, res: Response) => {
  const userId = req.user?.userId;
  if (!userId) {
    return res.status(401).json({ success: false, message: 'Yêu cầu xác thực tài khoản' });
  }

  try {
    const result = await query(
      `SELECT 
         ds.id,
         ds.owner_id,
         ds.recipient_id,
         u.full_name as recipient_name,
         u.phone_number as recipient_phone,
         ds.scope,
         ds.shift_id,
         s.shift_code,
         s.work_date,
         ds.include_photos,
         ds.status,
         ds.created_at,
         ds.accepted_at,
         ds.revoked_at,
         ds.expires_at,
         CASE
           WHEN ds.scope = 'SHIFT' THEN (
             SELECT COUNT(*)::int FROM shift_delivery_points WHERE shift_id = ds.shift_id
           )
           ELSE (
             SELECT COUNT(*)::int FROM saved_locations WHERE created_by = ds.owner_id OR updated_by = ds.owner_id
           )
         END as shared_points_count
       FROM data_shares ds
       JOIN users u ON u.id = ds.recipient_id
       LEFT JOIN shifts s ON s.id = ds.shift_id
       WHERE ds.owner_id = $1
       ORDER BY ds.created_at DESC`,
      [userId]
    );

    return res.json({
      success: true,
      data: result.rows.map((row: any) => ({
        id: row.id,
        ownerId: row.owner_id,
        recipientId: row.recipient_id,
        recipientName: row.recipient_name,
        recipientPhone: row.recipient_phone,
        scope: row.scope,
        shiftId: row.shift_id,
        shiftCode: row.shift_code,
        workDate: row.work_date,
        includePhotos: row.include_photos,
        status: row.status,
        createdAt: row.created_at,
        acceptedAt: row.accepted_at,
        revokedAt: row.revoked_at,
        expiresAt: row.expires_at,
        sharedPointsCount: row.shared_points_count || 0,
      })),
    });
  } catch (error: any) {
    return res.status(500).json({
      success: false,
      message: 'Lỗi tải danh sách lời mời đã gửi',
      error: error.message,
    });
  }
};

/**
 * 2. GET /api/v1/shares/incoming
 * Danh sách lời mời gửi tới cho shipper hiện tại
 */
export const getIncomingShares = async (req: AuthenticatedRequest, res: Response) => {
  const userId = req.user?.userId;
  if (!userId) {
    return res.status(401).json({ success: false, message: 'Yêu cầu xác thực tài khoản' });
  }

  try {
    const result = await query(
      `SELECT 
         ds.id,
         ds.owner_id,
         u.full_name as owner_name,
         u.phone_number as owner_phone,
         ds.recipient_id,
         ds.scope,
         ds.shift_id,
         s.shift_code,
         s.work_date,
         ds.include_photos,
         ds.status,
         ds.created_at,
         ds.accepted_at,
         ds.revoked_at,
         ds.expires_at,
         CASE
           WHEN ds.scope = 'SHIFT' THEN (
             SELECT COUNT(*)::int FROM shift_delivery_points WHERE shift_id = ds.shift_id
           )
           ELSE (
             SELECT COUNT(*)::int FROM saved_locations WHERE created_by = ds.owner_id OR updated_by = ds.owner_id
           )
         END as shared_points_count
       FROM data_shares ds
       JOIN users u ON u.id = ds.owner_id
       LEFT JOIN shifts s ON s.id = ds.shift_id
       WHERE ds.recipient_id = $1
       ORDER BY ds.created_at DESC`,
      [userId]
    );

    return res.json({
      success: true,
      data: result.rows.map((row: any) => ({
        id: row.id,
        ownerId: row.owner_id,
        ownerName: row.owner_name,
        ownerPhone: row.owner_phone,
        recipientId: row.recipient_id,
        scope: row.scope,
        shiftId: row.shift_id,
        shiftCode: row.shift_code,
        workDate: row.work_date,
        includePhotos: row.include_photos,
        status: row.status,
        createdAt: row.created_at,
        acceptedAt: row.accepted_at,
        revokedAt: row.revoked_at,
        expiresAt: row.expires_at,
        sharedPointsCount: row.shared_points_count || 0,
      })),
    });
  } catch (error: any) {
    return res.status(500).json({
      success: false,
      message: 'Lỗi tải danh sách lời mời nhận được',
      error: error.message,
    });
  }
};

/**
 * 3. POST /api/v1/shares/:id/accept
 * Người nhận chấp nhận lời mời chia sẻ
 */
export const acceptShare = async (req: AuthenticatedRequest, res: Response) => {
  const userId = req.user?.userId;
  const { id } = req.params;

  if (!userId) {
    return res.status(401).json({ success: false, message: 'Yêu cầu xác thực tài khoản' });
  }

  try {
    const shareRes = await query(
      'SELECT * FROM data_shares WHERE id = $1 AND recipient_id = $2',
      [id, userId]
    );

    if (shareRes.rows.length === 0) {
      return res.status(404).json({ success: false, message: 'Không tìm thấy lời mời chia sẻ' });
    }

    const share = shareRes.rows[0];
    if (share.status !== 'PENDING') {
      return res.status(400).json({
        success: false,
        message: 'Lời mời không ở trạng thái chờ chấp nhận',
      });
    }

    await query(
      `UPDATE data_shares 
       SET status = 'ACTIVE', accepted_at = NOW() 
       WHERE id = $1`,
      [id]
    );

    await query(
      `INSERT INTO audit_logs (user_id, action, entity, entity_id, details)
       VALUES ($1, 'SHARE_ACCEPTED', 'DATA_SHARE', $2, $3)`,
      [userId, id, JSON.stringify({ shareId: id, ownerId: share.owner_id })]
    );

    return res.json({
      success: true,
      message: 'Đã chấp nhận lời mời chia sẻ dữ liệu',
    });
  } catch (error: any) {
    return res.status(500).json({
      success: false,
      message: 'Lỗi khi chấp nhận lời mời chia sẻ',
      error: error.message,
    });
  }
};

/**
 * 3. POST /api/v1/shares/:id/decline
 * Người nhận từ chối lời mời chia sẻ
 */
export const declineShare = async (req: AuthenticatedRequest, res: Response) => {
  const userId = req.user?.userId;
  const { id } = req.params;

  if (!userId) {
    return res.status(401).json({ success: false, message: 'Yêu cầu xác thực tài khoản' });
  }

  try {
    const shareRes = await query(
      'SELECT * FROM data_shares WHERE id = $1 AND recipient_id = $2',
      [id, userId]
    );

    if (shareRes.rows.length === 0) {
      return res.status(404).json({ success: false, message: 'Không tìm thấy lời mời chia sẻ' });
    }

    const share = shareRes.rows[0];
    if (share.status !== 'PENDING') {
      return res.status(400).json({
        success: false,
        message: 'Lời mời không ở trạng thái chờ chấp nhận',
      });
    }

    await query(
      `UPDATE data_shares 
       SET status = 'DECLINED' 
       WHERE id = $1`,
      [id]
    );

    await query(
      `INSERT INTO audit_logs (user_id, action, entity, entity_id, details)
       VALUES ($1, 'SHARE_DECLINED', 'DATA_SHARE', $2, $3)`,
      [userId, id, JSON.stringify({ shareId: id, ownerId: share.owner_id })]
    );

    return res.json({
      success: true,
      message: 'Đã từ chối lời mời chia sẻ',
    });
  } catch (error: any) {
    return res.status(500).json({
      success: false,
      message: 'Lỗi khi từ chối lời mời chia sẻ',
      error: error.message,
    });
  }
};

/**
 * 3. POST /api/v1/shares/:id/revoke
 * Người chia sẻ hoặc ADMIN dừng/thu hồi chia sẻ
 */
export const revokeShare = async (req: AuthenticatedRequest, res: Response) => {
  const userId = req.user?.userId;
  const userRole = req.user?.roleName;
  const { id } = req.params;

  if (!userId) {
    return res.status(401).json({ success: false, message: 'Yêu cầu xác thực tài khoản' });
  }

  try {
    let shareRes;
    if (userRole === 'ADMIN') {
      shareRes = await query('SELECT * FROM data_shares WHERE id = $1', [id]);
    } else {
      shareRes = await query('SELECT * FROM data_shares WHERE id = $1 AND owner_id = $2', [id, userId]);
    }

    if (shareRes.rows.length === 0) {
      return res.status(404).json({ success: false, message: 'Không tìm thấy lời mời chia sẻ' });
    }

    const share = shareRes.rows[0];
    if (share.status === 'REVOKED' || share.status === 'DECLINED') {
      return res.status(400).json({
        success: false,
        message: 'Lời mời chia sẻ đã kết thúc hoặc bị hủy trước đó',
      });
    }

    await query(
      `UPDATE data_shares 
       SET status = 'REVOKED', revoked_at = NOW() 
       WHERE id = $1`,
      [id]
    );

    await query(
      `INSERT INTO audit_logs (user_id, action, entity, entity_id, details)
       VALUES ($1, 'SHARE_REVOKED', 'DATA_SHARE', $2, $3)`,
      [userId, id, JSON.stringify({ shareId: id, recipientId: share.recipient_id })]
    );

    return res.json({
      success: true,
      message: 'Đã dừng chia sẻ dữ liệu thành công',
    });
  } catch (error: any) {
    return res.status(500).json({
      success: false,
      message: 'Lỗi khi dừng chia sẻ dữ liệu',
      error: error.message,
    });
  }
};

/**
 * 4. GET /api/v1/shares/shared-locations
 * Lấy các điểm được chia sẻ qua các lời mời ACTIVE còn hạn dành cho tôi
 * LỌC THEO KHU VỰC của người nhận: điểm ngoài khu vực bị loại, trả số lượng bị bỏ qua.
 */
export const getSharedLocations = async (req: AuthenticatedRequest, res: Response) => {
  const userId = req.user?.userId;
  const userRole = req.user?.roleName;
  const assignedAreas = req.user?.assignedAreaIds || [];

  if (!userId) {
    return res.status(401).json({ success: false, message: 'Yêu cầu xác thực tài khoản' });
  }

  try {
    // 1. Tìm các lời mời ACTIVE còn hạn dành cho tôi
    const sharesRes = await query(
      `SELECT 
         ds.id,
         ds.owner_id,
         u.full_name as owner_name,
         ds.scope,
         ds.shift_id,
         ds.include_photos,
         ds.expires_at
       FROM data_shares ds
       JOIN users u ON u.id = ds.owner_id
       WHERE ds.recipient_id = $1 
         AND ds.status = 'ACTIVE'
         AND (ds.expires_at IS NULL OR ds.expires_at > NOW())
       ORDER BY ds.created_at DESC`,
      [userId]
    );

    if (sharesRes.rows.length === 0) {
      return res.json({
        success: true,
        data: {
          locations: [],
          totalCount: 0,
          skippedOutOfAreaCount: 0,
        },
      });
    }

    let rawLocations: any[] = [];

    for (const share of sharesRes.rows) {
      if (share.scope === 'ALL_POINTS') {
        const locs = await query(
          `SELECT 
             sl.id as location_id,
             sl.customer_id,
             sl.latitude,
             sl.longitude,
             sl.gps_accuracy,
             sl.identification_notes,
             sl.image_url,
             c.customer_code,
             c.full_name as customer_name,
             c.phone_number as customer_phone,
             c.address_text as customer_address,
             c.area_id,
             a.name as area_name,
             $1::uuid as share_id,
             $2::text as shared_by_name,
             $3::boolean as include_photos,
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
           WHERE (sl.created_by = $4 OR sl.updated_by = $4)`,
          [share.id, share.owner_name, share.include_photos, share.owner_id]
        );
        rawLocations.push(...locs.rows);
      } else if (share.scope === 'SHIFT' && share.shift_id) {
        const locs = await query(
          `SELECT 
             sdp.id as location_id,
             sdp.customer_id,
             sdp.latitude,
             sdp.longitude,
             sdp.gps_accuracy,
             sdp.identification_notes,
             sdp.image_url,
             c.customer_code,
             c.full_name as customer_name,
             c.phone_number as customer_phone,
             c.address_text as customer_address,
             c.area_id,
             a.name as area_name,
             $1::uuid as share_id,
             $2::text as shared_by_name,
             $3::boolean as include_photos,
             COALESCE(cp_agg.photo_count, 0) as photo_count,
             COALESCE(cp_agg.photos, '[]'::json) as photos
           FROM shift_delivery_points sdp
           JOIN customers c ON c.id = sdp.customer_id
           JOIN areas a ON a.id = c.area_id
           LEFT JOIN LATERAL (
             SELECT 
               COUNT(*)::int as photo_count,
               (
                 SELECT COALESCE(json_agg(photo_item), '[]'::json)
                 FROM (
                   SELECT id, image_url as "imageUrl", created_at as "createdAt"
                   FROM customer_photos
                   WHERE customer_id = sdp.customer_id AND deleted_at IS NULL
                   ORDER BY created_at DESC
                   LIMIT 3
                 ) photo_item
               ) as photos
             FROM customer_photos
             WHERE customer_id = sdp.customer_id AND deleted_at IS NULL
           ) cp_agg ON true
           WHERE sdp.shift_id = $4 AND sdp.latitude IS NOT NULL AND sdp.longitude IS NOT NULL`,
          [share.id, share.owner_name, share.include_photos, share.shift_id]
        );
        rawLocations.push(...locs.rows);
      }
    }

    // Deduplicate theo customer_id nếu trùng
    const seenCustomers = new Set<string>();
    const uniqueRaw: any[] = [];
    for (const item of rawLocations) {
      if (!seenCustomers.has(item.customer_id)) {
        seenCustomers.add(item.customer_id);
        uniqueRaw.push(item);
      }
    }

    // Lọc theo khu vực của người nhận
    let filteredLocations: any[] = [];
    let skippedOutOfAreaCount = 0;

    for (const item of uniqueRaw) {
      const inArea = userRole === 'ADMIN' || assignedAreas.includes(item.area_id);
      if (!inArea) {
        skippedOutOfAreaCount++;
        continue;
      }

      // Xử lý ảnh: nếu include_photos = false thì không trả về ảnh
      const allowPhotos = !!item.include_photos;
      filteredLocations.push({
        id: item.location_id,
        customerId: item.customer_id,
        customerCode: item.customer_code,
        customerName: item.customer_name,
        customerPhone: item.customer_phone,
        customerAddress: item.customer_address,
        areaId: item.area_id,
        areaName: item.area_name,
        latitude: parseFloat(item.latitude),
        longitude: parseFloat(item.longitude),
        gpsAccuracy: parseFloat(item.gps_accuracy || 0),
        identificationNotes: item.identification_notes,
        imageUrl: allowPhotos ? item.image_url : null,
        photoCount: allowPhotos ? item.photo_count : 0,
        photos: allowPhotos ? item.photos : [],
        sharedByName: item.shared_by_name,
        shareId: item.share_id,
      });
    }

    return res.json({
      success: true,
      data: {
        locations: filteredLocations,
        totalCount: filteredLocations.length,
        skippedOutOfAreaCount,
      },
    });
  } catch (error: any) {
    return res.status(500).json({
      success: false,
      message: 'Lỗi tải danh sách điểm được chia sẻ',
      error: error.message,
    });
  }
};

/**
 * 6. POST /api/v1/shares/:id/import
 * Nhập điểm được chia sẻ thành vị trí đã lưu của người nhận
 * Ghi saved_locations qua đúng luồng xác nhận, lịch sử cũ giữ nguyên (trigger), ghi created_by/updated_by là người nhận.
 * Khách đã có vị trí: mặc định BỎ QUA, chỉ thay khi replaceExisting = true.
 * Không sao chép ảnh nếu includePhotos = false.
 */
export const importSharedLocations = async (req: AuthenticatedRequest, res: Response) => {
  const userId = req.user?.userId;
  const userRole = req.user?.roleName;
  const assignedAreas = req.user?.assignedAreaIds || [];
  const { id } = req.params;
  const { customerIds, all, replaceExisting } = req.body;

  if (!userId) {
    return res.status(401).json({ success: false, message: 'Yêu cầu xác thực tài khoản' });
  }

  try {
    // 1. Kiểm tra lời mời chia sẻ hợp lệ và còn hiệu lực
    const shareRes = await query(
      `SELECT * FROM data_shares 
       WHERE id = $1 
         AND recipient_id = $2 
         AND status = 'ACTIVE' 
         AND (expires_at IS NULL OR expires_at > NOW())`,
      [id, userId]
    );

    if (shareRes.rows.length === 0) {
      return res.status(404).json({
        success: false,
        message: 'Lời mời chia sẻ không tồn tại, chưa được chấp nhận hoặc đã hết hạn',
      });
    }

    const share = shareRes.rows[0];

    // 2. Thu thập danh sách các điểm trong phạm vi lời mời
    let candidatePoints: any[] = [];

    if (share.scope === 'ALL_POINTS') {
      const ptsRes = await query(
        `SELECT 
           sl.id,
           sl.customer_id,
           sl.latitude,
           sl.longitude,
           sl.gps_accuracy,
           sl.identification_notes,
           sl.image_url,
           c.full_name as customer_name,
           c.area_id
         FROM saved_locations sl
         JOIN customers c ON c.id = sl.customer_id
         WHERE (sl.created_by = $1 OR sl.updated_by = $1)`,
        [share.owner_id]
      );
      candidatePoints = ptsRes.rows;
    } else if (share.scope === 'SHIFT' && share.shift_id) {
      const ptsRes = await query(
        `SELECT 
           sdp.id,
           sdp.customer_id,
           sdp.latitude,
           sdp.longitude,
           sdp.gps_accuracy,
           sdp.identification_notes,
           sdp.image_url,
           c.full_name as customer_name,
           c.area_id
         FROM shift_delivery_points sdp
         JOIN customers c ON c.id = sdp.customer_id
         WHERE sdp.shift_id = $1 AND sdp.latitude IS NOT NULL AND sdp.longitude IS NOT NULL`,
        [share.shift_id]
      );
      candidatePoints = ptsRes.rows;
    }

    // Lọc theo customerIds nếu có yêu cầu
    if (Array.isArray(customerIds) && customerIds.length > 0 && !all) {
      candidatePoints = candidatePoints.filter((pt) => customerIds.includes(pt.customer_id));
    }

    let importedCount = 0;
    let skippedCount = 0;
    let outOfAreaCount = 0;
    const details: any[] = [];

    for (const pt of candidatePoints) {
      // Kiểm tra khu vực phân công
      const inArea = userRole === 'ADMIN' || assignedAreas.includes(pt.area_id);
      if (!inArea) {
        outOfAreaCount++;
        details.push({
          customerId: pt.customer_id,
          customerName: pt.customer_name,
          status: 'OUT_OF_AREA',
          reason: 'Ngoài khu vực phân công của bạn',
        });
        continue;
      }

      // Kiểm tra xem khách hàng này đã có vị trí lưu chưa
      const existingLocRes = await query(
        'SELECT id, created_by FROM saved_locations WHERE customer_id = $1',
        [pt.customer_id]
      );

      const photoToImport = share.include_photos ? (pt.image_url || null) : null;
      const targetNotes = pt.identification_notes || 'Vị trí đã lưu (Nhập từ chia sẻ)';

      if (existingLocRes.rows.length > 0) {
        // Đã có vị trí: mặc định bỏ qua nếu không yêu cầu ghi đè
        if (replaceExisting !== true) {
          skippedCount++;
          details.push({
            customerId: pt.customer_id,
            customerName: pt.customer_name,
            status: 'SKIPPED',
            reason: 'Khách hàng đã có vị trí đã lưu',
          });
          continue;
        }

        // Ghi đè vị trí cũ: cập nhật và trigger tự động lưu lịch sử cũ vào location_history
        await query(
          `UPDATE saved_locations
           SET geom = ST_SetSRID(ST_MakePoint($1, $2), 4326),
               latitude = $2,
               longitude = $1,
               gps_accuracy = $3,
               identification_notes = $4,
               image_url = COALESCE($5, image_url),
               updated_by = $6,
               updated_at = NOW()
           WHERE customer_id = $7`,
          [
            parseFloat(pt.longitude),
            parseFloat(pt.latitude),
            parseFloat(pt.gps_accuracy || 0),
            targetNotes,
            photoToImport,
            userId,
            pt.customer_id,
          ]
        );

        importedCount++;
        details.push({
          customerId: pt.customer_id,
          customerName: pt.customer_name,
          status: 'IMPORTED',
          reason: 'Ghi đè vị trí thành công',
        });
      } else {
        // Chưa có vị trí: thêm mới vị trí với created_by/updated_by là người nhận
        await query(
          `INSERT INTO saved_locations (
             customer_id, geom, latitude, longitude, gps_accuracy, identification_notes, image_url, created_by, updated_by
           ) VALUES (
             $1, ST_SetSRID(ST_MakePoint($2, $3), 4326), $3, $2, $4, $5, $6, $7, $7
           )`,
          [
            pt.customer_id,
            parseFloat(pt.longitude),
            parseFloat(pt.latitude),
            parseFloat(pt.gps_accuracy || 0),
            targetNotes,
            photoToImport,
            userId,
          ]
        );

        importedCount++;
        details.push({
          customerId: pt.customer_id,
          customerName: pt.customer_name,
          status: 'IMPORTED',
          reason: 'Nhập vị trí thành công',
        });
      }
    }

    // Ghi nhật ký kiểm toán (không ghi thông tin cá nhân khách hàng vào log)
    await query(
      `INSERT INTO audit_logs (user_id, action, entity, entity_id, details)
       VALUES ($1, 'SHARE_IMPORT', 'DATA_SHARE', $2, $3)`,
      [
        userId,
        id,
        JSON.stringify({
          shareId: id,
          total: candidatePoints.length,
          importedCount,
          skippedCount,
          outOfAreaCount,
          replaceExisting: !!replaceExisting,
        }),
      ]
    );

    return res.json({
      success: true,
      message: 'Hoàn tất nhập dữ liệu vị trí',
      data: {
        total: candidatePoints.length,
        importedCount,
        skippedCount,
        outOfAreaCount,
        details,
      },
    });
  } catch (error: any) {
    return res.status(500).json({
      success: false,
      message: 'Lỗi khi nhập dữ liệu vị trí chia sẻ',
      error: error.message,
    });
  }
};
