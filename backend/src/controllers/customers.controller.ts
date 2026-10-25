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

export function normalizePhoneNumber(phone: string): string {
  if (!phone) return '';
  let cleaned = phone.replace(/[^\d+]/g, '');
  if (cleaned.startsWith('+84')) {
    cleaned = '0' + cleaned.substring(3);
  } else if (cleaned.startsWith('84') && cleaned.length > 9) {
    cleaned = '0' + cleaned.substring(2);
  }
  return cleaned;
}

// 1. GET /api/v1/customers - Danh bạ khách hàng độc lập kèm vị trí & trạng thái ảnh
export const listCustomers = async (req: AuthenticatedRequest, res: Response) => {
  const user = req.user;
  if (!user) return res.status(401).json({ success: false, message: 'Chưa xác thực' });

  const { q, status, hasPhoto } = req.query;
  const assignedAreaIds = user.assignedAreaIds || [];

  try {
    let whereClauses: string[] = [];
    let params: any[] = [];
    let paramIndex = 1;

    // RBAC: Shipper chỉ thấy khách hàng trong khu vực phụ trách
    if (user.roleName === 'SHIPPER') {
      if (assignedAreaIds.length === 0) {
        return res.status(200).json({ success: true, data: [] });
      }
      whereClauses.push(`c.area_id = ANY($${paramIndex})`);
      params.push(assignedAreaIds);
      paramIndex++;
    }

    // Tìm kiếm không dấu (unaccent) theo SĐT, Tên, Địa chỉ, hoặc Ghi chú nhận diện
    if (q && typeof q === 'string' && q.trim().length > 0) {
      const searchTerm = `%${q.trim()}%`;
      whereClauses.push(`(
        unaccent(c.phone_number) ILIKE unaccent($${paramIndex}) OR
        unaccent(c.full_name) ILIKE unaccent($${paramIndex}) OR
        unaccent(c.address_text) ILIKE unaccent($${paramIndex}) OR
        (sl.identification_notes IS NOT NULL AND unaccent(sl.identification_notes) ILIKE unaccent($${paramIndex}))
      )`);
      params.push(searchTerm);
      paramIndex++;
    }

    // Lọc theo trạng thái ảnh (kiểm tra cả customer_photos và saved_locations)
    if (hasPhoto === 'true') {
      whereClauses.push(`(
        EXISTS (SELECT 1 FROM customer_photos cp WHERE cp.customer_id = c.id AND cp.deleted_at IS NULL)
        OR (sl.image_url IS NOT NULL AND sl.image_url != '')
        OR (latest_sdp.image_url IS NOT NULL AND latest_sdp.image_url != '')
      )`);
    } else if (hasPhoto === 'false') {
      whereClauses.push(`(
        NOT EXISTS (SELECT 1 FROM customer_photos cp WHERE cp.customer_id = c.id AND cp.deleted_at IS NULL)
        AND (sl.image_url IS NULL OR sl.image_url = '')
        AND (latest_sdp.image_url IS NULL OR latest_sdp.image_url = '')
      )`);
    }

    const whereSQL = whereClauses.length > 0 ? `WHERE ${whereClauses.join(' AND ')}` : '';

    const sql = `
      SELECT 
        c.id,
        c.customer_code,
        c.full_name,
        c.phone_number,
        c.address_text,
        c.area_id,
        c.created_at,
        c.updated_at,
        a.name as area_name,
        sl.id as saved_location_id,
        sl.latitude,
        sl.longitude,
        sl.gps_accuracy,
        sl.identification_notes,
        sl.image_url,
        sl.updated_at as location_updated_at,
        latest_sdp.location_status as sdp_status,
        latest_sdp.latitude as sdp_latitude,
        latest_sdp.longitude as sdp_longitude,
        latest_sdp.identification_notes as sdp_notes,
        latest_sdp.image_url as sdp_image_url,
        latest_sdp.updated_at as sdp_updated_at,
        cp_stats.photo_count,
        cp_stats.latest_photo_url,
        cp_stats.photos_json
      FROM customers c
      JOIN areas a ON a.id = c.area_id
      LEFT JOIN saved_locations sl ON sl.customer_id = c.id
      LEFT JOIN LATERAL (
        SELECT sdp.location_status, sdp.latitude, sdp.longitude, sdp.identification_notes, sdp.image_url, sdp.updated_at
        FROM shift_delivery_points sdp
        WHERE sdp.customer_id = c.id
        ORDER BY sdp.updated_at DESC
        LIMIT 1
      ) latest_sdp ON true
      LEFT JOIN LATERAL (
        SELECT 
          COUNT(*)::int as photo_count,
          (ARRAY_AGG(cp.image_url ORDER BY cp.created_at DESC))[1] as latest_photo_url,
          JSON_AGG(
            JSON_BUILD_OBJECT(
              'id', cp.id,
              'customerId', cp.customer_id,
              'imageUrl', cp.image_url,
              'createdBy', cp.created_by,
              'createdAt', cp.created_at
            ) ORDER BY cp.created_at DESC
          ) FILTER (WHERE cp.id IS NOT NULL) as photos_json
        FROM customer_photos cp
        WHERE cp.customer_id = c.id AND cp.deleted_at IS NULL
      ) cp_stats ON true
      ${whereSQL}
      ORDER BY c.updated_at DESC, c.created_at DESC
    `;

    const result = await query(sql, params);

    const data = result.rows.map((row) => {
      let locationStatus = 'NO_LOCATION';
      let lat: number | null = null;
      let lng: number | null = null;
      let notes: string | null = null;
      let photoUrl: string | null = null;
      let locId: string | null = null;

      const hasSl = row.saved_location_id && row.latitude !== null && row.longitude !== null;
      const hasSdp = row.sdp_status === 'TEMPORARY' && row.sdp_latitude !== null && row.sdp_longitude !== null;

      if (hasSl && hasSdp) {
        const slDate = new Date(row.location_updated_at).getTime();
        const sdpDate = new Date(row.sdp_updated_at).getTime();
        if (sdpDate > slDate) {
          // Vị trí ghim tạm mới hơn vị trí đã lưu trước đó -> Phản ánh TEMPORARY
          locationStatus = 'TEMPORARY';
          lat = parseFloat(row.sdp_latitude);
          lng = parseFloat(row.sdp_longitude);
          // Giữ nguyên ghi chú nhận diện và ảnh cổng nhà đã lưu nếu sdp không có ghi chú riêng
          notes = row.sdp_notes || row.identification_notes;
          photoUrl = row.sdp_image_url || row.image_url;
          locId = row.saved_location_id;
        } else {
          locationStatus = 'VERIFIED';
          lat = parseFloat(row.latitude);
          lng = parseFloat(row.longitude);
          notes = row.identification_notes;
          photoUrl = row.image_url;
          locId = row.saved_location_id;
        }
      } else if (hasSl) {
        locationStatus = 'VERIFIED';
        lat = parseFloat(row.latitude);
        lng = parseFloat(row.longitude);
        notes = row.identification_notes;
        photoUrl = row.image_url;
        locId = row.saved_location_id;
      } else if (hasSdp) {
        locationStatus = 'TEMPORARY';
        lat = parseFloat(row.sdp_latitude);
        lng = parseFloat(row.sdp_longitude);
        notes = row.sdp_notes;
        photoUrl = row.sdp_image_url;
      }

      const activePhotos = row.photos_json || [];
      const cpPhotoCount = parseInt(row.photo_count, 10) || 0;
      // Ưu tiên ảnh mới nhất từ customer_photos, nếu không có mới dùng sdp_image_url hoặc saved_locations image_url
      const effectivePhotoUrl = row.latest_photo_url || photoUrl;
      const totalPhotoCount = cpPhotoCount > 0 ? cpPhotoCount : (effectivePhotoUrl ? 1 : 0);

      return {
        id: row.id,
        customerCode: row.customer_code,
        fullName: row.full_name,
        phoneNumber: row.phone_number,
        addressText: row.address_text,
        areaId: row.area_id,
        areaName: row.area_name,
        locationStatus,
        hasLocation: lat !== null && lng !== null,
        latitude: lat,
        longitude: lng,
        identificationNotes: notes,
        imageUrl: effectivePhotoUrl,
        photoCount: totalPhotoCount,
        photos: activePhotos,
        savedLocationId: locId,
        createdAt: row.created_at,
        updatedAt: row.updated_at,
      };
    });

    // Lọc theo status nếu có (VERIFIED, TEMPORARY, NO_LOCATION)
    let filteredData = data;
    if (status && typeof status === 'string' && status !== 'ALL') {
      const targetStatus = status.toUpperCase();
      filteredData = data.filter((c) => c.locationStatus === targetStatus);
    }

    return res.status(200).json({
      success: true,
      data: filteredData,
      total: filteredData.length,
    });
  } catch (error: any) {
    return res.status(500).json({
      success: false,
      message: 'Lỗi lấy danh bạ khách hàng',
      error: error.message,
    });
  }
};

// 2. GET /api/v1/customers/:id - Chi tiết khách hàng kèm lịch sử vị trí
export const getCustomerDetail = async (req: AuthenticatedRequest, res: Response) => {
  const user = req.user;
  const { id } = req.params;

  try {
    const custRes = await query(
      `SELECT c.id, c.customer_code, c.full_name, c.phone_number, c.address_text, c.area_id, c.created_at, c.updated_at,
              a.name as area_name
       FROM customers c
       JOIN areas a ON a.id = c.area_id
       WHERE c.id = $1`,
      [id]
    );

    if (custRes.rows.length === 0) {
      return res.status(404).json({ success: false, message: 'Không tìm thấy khách hàng' });
    }

    const customer = custRes.rows[0];

    // Kiểm tra quyền khu vực của Shipper
    if (user?.roleName === 'SHIPPER') {
      const assigned = user.assignedAreaIds || [];
      if (!assigned.includes(customer.area_id)) {
        return res.status(403).json({
          success: false,
          message: 'Khách hàng này thuộc khu vực bạn không được phân công phụ trách',
        });
      }
    }

    // Lấy vị trí đã lưu chính thức (VERIFIED)
    const locRes = await query(
      `SELECT sl.id, sl.latitude, sl.longitude, sl.gps_accuracy, sl.identification_notes, sl.image_url,
              sl.created_at, sl.updated_at, u.full_name as updated_by_name
       FROM saved_locations sl
       LEFT JOIN users u ON u.id = sl.updated_by
       WHERE sl.customer_id = $1`,
      [id]
    );

    // Lấy điểm giao tạm thời mới nhất từ ca làm việc (TEMPORARY)
    const sdpRes = await query(
      `SELECT sdp.id, sdp.location_status, sdp.latitude, sdp.longitude, sdp.gps_accuracy,
              sdp.identification_notes, sdp.image_url, sdp.created_at, sdp.updated_at
       FROM shift_delivery_points sdp
       WHERE sdp.customer_id = $1
       ORDER BY sdp.updated_at DESC
       LIMIT 1`,
      [id]
    );

    // Lấy danh sách ảnh từ customer_photos
    const photosRes = await query(
      `SELECT id, customer_id as "customerId", image_url as "imageUrl", created_by as "createdBy", created_at as "createdAt"
       FROM customer_photos
       WHERE customer_id = $1 AND deleted_at IS NULL
       ORDER BY created_at DESC`,
      [id]
    );
    const activePhotos = photosRes.rows;

    const hasSaved = locRes.rows.length > 0;
    const loc = hasSaved ? locRes.rows[0] : null;

    const hasSdp = sdpRes.rows.length > 0 && sdpRes.rows[0].location_status === 'TEMPORARY' && sdpRes.rows[0].latitude !== null && sdpRes.rows[0].longitude !== null;
    const sdp = hasSdp ? sdpRes.rows[0] : null;

    let locationStatus = 'NO_LOCATION';
    let activeLoc: any = null;

    if (loc && sdp) {
      const slDate = new Date(loc.updated_at).getTime();
      const sdpDate = new Date(sdp.updated_at).getTime();
      if (sdpDate > slDate) {
        locationStatus = 'TEMPORARY';
        activeLoc = {
          id: loc.id,
          pointId: sdp.id,
          status: 'TEMPORARY',
          latitude: parseFloat(sdp.latitude),
          longitude: parseFloat(sdp.longitude),
          gpsAccuracy: sdp.gps_accuracy ? parseFloat(sdp.gps_accuracy) : (loc.gps_accuracy ? parseFloat(loc.gps_accuracy) : 0),
          identificationNotes: sdp.identification_notes || loc.identification_notes,
          imageUrl: (activePhotos.length > 0 ? activePhotos[0].imageUrl : (sdp.image_url || loc.image_url)),
          createdAt: sdp.created_at,
          updatedAt: sdp.updated_at,
          updatedByName: loc.updated_by_name,
        };
      } else {
        locationStatus = 'VERIFIED';
        activeLoc = {
          id: loc.id,
          status: 'VERIFIED',
          latitude: parseFloat(loc.latitude),
          longitude: parseFloat(loc.longitude),
          gpsAccuracy: loc.gps_accuracy ? parseFloat(loc.gps_accuracy) : 0,
          identificationNotes: loc.identification_notes,
          imageUrl: (activePhotos.length > 0 ? activePhotos[0].imageUrl : loc.image_url),
          createdAt: loc.created_at,
          updatedAt: loc.updated_at,
          updatedByName: loc.updated_by_name,
        };
      }
    } else if (loc) {
      locationStatus = 'VERIFIED';
      activeLoc = {
        id: loc.id,
        status: 'VERIFIED',
        latitude: parseFloat(loc.latitude),
        longitude: parseFloat(loc.longitude),
        gpsAccuracy: loc.gps_accuracy ? parseFloat(loc.gps_accuracy) : 0,
        identificationNotes: loc.identification_notes,
        imageUrl: (activePhotos.length > 0 ? activePhotos[0].imageUrl : loc.image_url),
        createdAt: loc.created_at,
        updatedAt: loc.updated_at,
        updatedByName: loc.updated_by_name,
      };
    } else if (sdp) {
      locationStatus = 'TEMPORARY';
      activeLoc = {
        id: sdp.id,
        pointId: sdp.id,
        status: 'TEMPORARY',
        latitude: parseFloat(sdp.latitude),
        longitude: parseFloat(sdp.longitude),
        gpsAccuracy: sdp.gps_accuracy ? parseFloat(sdp.gps_accuracy) : 0,
        identificationNotes: sdp.identification_notes,
        imageUrl: (activePhotos.length > 0 ? activePhotos[0].imageUrl : sdp.image_url),
        createdAt: sdp.created_at,
        updatedAt: sdp.updated_at,
        updatedByName: null,
      };
    }

    // Lấy lịch sử vị trí
    const histRes = await query(
      `SELECT lh.id, lh.latitude, lh.longitude, lh.gps_accuracy, lh.identification_notes, lh.image_url,
              lh.change_reason, lh.created_at, u.full_name as changed_by_name
       FROM location_history lh
       LEFT JOIN users u ON u.id = lh.changed_by
       WHERE lh.customer_id = $1
       ORDER BY lh.created_at DESC`,
      [id]
    );

    return res.status(200).json({
      success: true,
      data: {
        customer: {
          id: customer.id,
          customerCode: customer.customer_code,
          fullName: customer.full_name,
          phoneNumber: customer.phone_number,
          addressText: customer.address_text,
          areaId: customer.area_id,
          areaName: customer.area_name,
          createdAt: customer.created_at,
          updatedAt: customer.updated_at,
          photoCount: activePhotos.length,
          photos: activePhotos,
          imageUrl: activePhotos.length > 0 ? activePhotos[0].imageUrl : (activeLoc ? activeLoc.imageUrl : null),
        },
        photos: activePhotos,
        photoCount: activePhotos.length,
        locationStatus,
        savedLocation: activeLoc,
        locationHistory: histRes.rows.map((r) => ({
          id: r.id,
          latitude: parseFloat(r.latitude),
          longitude: parseFloat(r.longitude),
          gpsAccuracy: parseFloat(r.gps_accuracy),
          identificationNotes: r.identification_notes,
          imageUrl: r.image_url,
          changeReason: r.change_reason,
          createdAt: r.created_at,
          changedByName: r.changed_by_name,
        })),
      },
    });
  } catch (error: any) {
    return res.status(500).json({
      success: false,
      message: 'Lỗi lấy thông tin khách hàng',
      error: error.message,
    });
  }
};

// 3. POST /api/v1/customers - Tạo mới khách hàng trực tiếp từ Danh bạ
export const createCustomer = async (req: AuthenticatedRequest, res: Response) => {
  const user = req.user;
  const userId = user?.userId;
  const assignedAreaIds = user?.assignedAreaIds || [];

  const {
    phoneNumber,
    fullName,
    addressText,
    areaId,
    latitude,
    longitude,
    gpsAccuracy,
    identificationNotes,
    imageBase64,
    isVerified,
  } = req.body;

  if (!phoneNumber || !phoneNumber.trim()) {
    return res.status(400).json({ success: false, message: 'Vui lòng cung cấp số điện thoại khách hàng' });
  }

  const cleanPhone = normalizePhoneNumber(phoneNumber);
  if (!cleanPhone || cleanPhone.length < 9 || cleanPhone.length > 12) {
    return res.status(400).json({ success: false, message: 'Số điện thoại không hợp lệ (cần 10 chữ số chuẩn)' });
  }

  const client = await pool.connect();
  let createdFilePath: string | null = null;

  try {
    await client.query('BEGIN');

    // TASK: QUICK-ADD-013B: Nếu areaId gửi lên không thuộc khu vực shipper được phân công thì trả 403, không âm thầm đổi sang khu vực khác
    if (areaId && user?.roleName !== 'ADMIN' && !assignedAreaIds.includes(areaId)) {
      await client.query('ROLLBACK');
      return res.status(403).json({
        success: false,
        message: 'Khu vực được chỉ định không thuộc khu vực bạn được phân công phụ trách',
      });
    }

    // Kiểm tra số điện thoại đã tồn tại chưa
    const existingRes = await client.query(
      `SELECT c.id, c.customer_code, c.full_name, c.phone_number, c.address_text, c.area_id, c.created_at, c.updated_at,
              sl.id as saved_location_id, sl.latitude, sl.longitude, sl.identification_notes, sl.image_url,
              a.name as area_name
       FROM customers c
       LEFT JOIN saved_locations sl ON sl.customer_id = c.id
       LEFT JOIN areas a ON a.id = c.area_id
       WHERE c.phone_number = $1`,
      [cleanPhone]
    );

    if (existingRes.rows.length > 0) {
      await client.query('COMMIT');
      const existing = existingRes.rows[0];
      return res.status(200).json({
        success: true,
        isExisting: true,
        message: `Số điện thoại ${cleanPhone} đã tồn tại (Khách hàng: ${existing.full_name})`,
        data: {
          id: existing.id,
          customerCode: existing.customer_code,
          fullName: existing.full_name,
          phoneNumber: existing.phone_number,
          addressText: existing.address_text,
          areaId: existing.area_id,
          areaName: existing.area_name || '',
          locationStatus: (existing.latitude && existing.longitude) ? 'VERIFIED' : 'NO_LOCATION',
          hasLocation: !!(existing.latitude && existing.longitude),
          latitude: existing.latitude ? parseFloat(existing.latitude) : null,
          longitude: existing.longitude ? parseFloat(existing.longitude) : null,
          identificationNotes: existing.identification_notes,
          imageUrl: existing.image_url,
          savedLocationId: existing.saved_location_id,
          createdAt: existing.created_at,
          updatedAt: existing.updated_at,
        },
      });
    }

    // Xác định khu vực hợp lệ
    let targetAreaId: string | null = null;
    if (areaId) {
      targetAreaId = areaId;
    } else if (assignedAreaIds.length > 0) {
      targetAreaId = assignedAreaIds[0];
    } else if (user?.roleName === 'ADMIN') {
      const areaQ = await client.query('SELECT id FROM areas ORDER BY created_at ASC LIMIT 1');
      targetAreaId = areaQ.rows[0]?.id || null;
    }

    if (!targetAreaId) {
      await client.query('ROLLBACK');
      return res.status(400).json({ success: false, message: 'Không xác định được khu vực phân công' });
    }

    // TASK: QUICK-ADD-CUSTOMER-013: Mặc định tên "Khách [SĐT]", địa chỉ "Chưa cập nhật địa chỉ"
    const custName = (fullName && fullName.trim()) ? fullName.trim() : `Khách ${cleanPhone}`;
    const custAddress = (addressText && addressText.trim()) ? addressText.trim() : 'Chưa cập nhật địa chỉ';
    const custCode = `KH_${cleanPhone.slice(-6)}_${Date.now().toString().slice(-4)}`;

    const newCustRes = await client.query(
      `INSERT INTO customers (customer_code, full_name, phone_number, address_text, area_id)
       VALUES ($1, $2, $3, $4, $5)
       RETURNING id, customer_code, full_name, phone_number, address_text, area_id, created_at, updated_at`,
      [custCode, custName, cleanPhone, custAddress, targetAreaId]
    );

    const customer = newCustRes.rows[0];

    // Xử lý ảnh nếu có
    let finalImageUrl: string | null = null;
    if (imageBase64 && typeof imageBase64 === 'string') {
      const matches = imageBase64.match(/^data:([A-Za-z-+\/]+);base64,(.+)$/);
      let buffer: Buffer;
      let ext = 'jpg';

      if (matches && matches.length === 3) {
        const mimeType = matches[1].toLowerCase();
        if (mimeType.includes('png')) ext = 'png';
        else if (mimeType.includes('webp')) ext = 'webp';
        buffer = Buffer.from(matches[2], 'base64');
      } else {
        buffer = Buffer.from(imageBase64, 'base64');
      }

      if (buffer.length <= 5 * 1024 * 1024) {
        const filename = `${crypto.randomUUID()}.${ext}`;
        const filePath = path.join(UPLOADS_DIR, filename);
        await fs.promises.writeFile(filePath, buffer);
        createdFilePath = filePath;
        finalImageUrl = `/api/v1/photos/${filename}`;
      }
    }

    // Nếu có tọa độ, lưu vị trí
    let savedLocation: any = null;
    if (latitude !== undefined && longitude !== undefined && latitude !== null && longitude !== null) {
      const notes = identificationNotes && identificationNotes.trim() ? identificationNotes.trim() : 'Vị trí ghim từ danh bạ';
      const locRes = await client.query(
        `INSERT INTO saved_locations
         (customer_id, geom, latitude, longitude, gps_accuracy, identification_notes, image_url, created_by, updated_by)
         VALUES ($1, ST_SetSRID(ST_MakePoint($3, $2), 4326), $2, $3, $4, $5, $6, $7, $7)
         RETURNING id, latitude, longitude, gps_accuracy, identification_notes, image_url, created_at, updated_at`,
        [customer.id, latitude, longitude, gpsAccuracy || 0, notes, finalImageUrl, userId]
      );
      savedLocation = locRes.rows[0];
    }

    // Ghi audit log
    await client.query(
      `INSERT INTO audit_logs (user_id, action, entity, entity_id, details) VALUES ($1, $2, $3, $4, $5)`,
      [
        userId,
        'CREATE_CUSTOMER',
        'CUSTOMER',
        customer.id,
        JSON.stringify({
          phone: cleanPhone,
          name: custName,
          hasLocation: !!savedLocation,
          hasPhoto: !!finalImageUrl,
        }),
      ]
    );

    await client.query('COMMIT');

    const areaRes = await query('SELECT name FROM areas WHERE id = $1', [customer.area_id]);

    return res.status(201).json({
      success: true,
      message: 'Tạo khách hàng mới thành công',
      data: {
        id: customer.id,
        customerCode: customer.customer_code,
        fullName: customer.full_name,
        phoneNumber: customer.phone_number,
        addressText: customer.address_text,
        areaId: customer.area_id,
        areaName: areaRes.rows[0]?.name || '',
        locationStatus: savedLocation ? 'VERIFIED' : 'NO_LOCATION',
        hasLocation: !!savedLocation,
        latitude: savedLocation ? parseFloat(savedLocation.latitude) : null,
        longitude: savedLocation ? parseFloat(savedLocation.longitude) : null,
        identificationNotes: savedLocation ? savedLocation.identification_notes : null,
        imageUrl: savedLocation ? savedLocation.image_url : null,
        createdAt: customer.created_at,
        updatedAt: customer.updated_at,
      },
    });
  } catch (error: any) {
    await client.query('ROLLBACK');
    if (createdFilePath && fs.existsSync(createdFilePath)) {
      try { await fs.promises.unlink(createdFilePath); } catch (_) {}
    }
    return res.status(500).json({
      success: false,
      message: 'Lỗi tạo khách hàng',
      error: error.message,
    });
  } finally {
    client.release();
  }
};

// 4. PUT /api/v1/customers/:id - Chỉnh sửa thông tin khách hàng (Tên, SĐT, Địa chỉ)
export const updateCustomer = async (req: AuthenticatedRequest, res: Response) => {
  const user = req.user;
  const userId = user?.userId;
  const { id } = req.params;
  const { fullName, phoneNumber, addressText } = req.body;

  try {
    const custRes = await query(`SELECT id, area_id, phone_number, full_name, address_text FROM customers WHERE id = $1`, [id]);
    if (custRes.rows.length === 0) {
      return res.status(404).json({ success: false, message: 'Không tìm thấy khách hàng' });
    }

    const customer = custRes.rows[0];

    // Kiểm tra quyền khu vực
    if (user?.roleName === 'SHIPPER') {
      const assigned = user.assignedAreaIds || [];
      if (!assigned.includes(customer.area_id)) {
        return res.status(403).json({ success: false, message: 'Bạn không có quyền sửa khách hàng thuộc khu vực này' });
      }
    }

    let cleanPhone = customer.phone_number;
    if (phoneNumber && phoneNumber.trim()) {
      cleanPhone = normalizePhoneNumber(phoneNumber);
      if (!cleanPhone || cleanPhone.length < 9 || cleanPhone.length > 12) {
        return res.status(400).json({ success: false, message: 'Số điện thoại không hợp lệ' });
      }

      // Kiểm tra trùng SĐT với khách hàng khác
      if (cleanPhone !== customer.phone_number) {
        const dupRes = await query('SELECT id FROM customers WHERE phone_number = $1 AND id != $2', [cleanPhone, id]);
        if (dupRes.rows.length > 0) {
          return res.status(409).json({ success: false, message: `Số điện thoại ${cleanPhone} đã được dùng cho khách hàng khác` });
        }
      }
    }

    const updatedName = fullName && fullName.trim() ? fullName.trim() : customer.full_name;
    const updatedAddress = addressText !== undefined ? addressText.trim() : customer.address_text;

    const updateRes = await query(
      `UPDATE customers
       SET full_name = $1, phone_number = $2, address_text = $3, updated_at = CURRENT_TIMESTAMP
       WHERE id = $4
       RETURNING id, customer_code, full_name, phone_number, address_text, area_id, updated_at`,
      [updatedName, cleanPhone, updatedAddress, id]
    );

    // Ghi audit log
    await query(
      `INSERT INTO audit_logs (user_id, action, entity, entity_id, details) VALUES ($1, $2, $3, $4, $5)`,
      [
        userId,
        'UPDATE_CUSTOMER',
        'CUSTOMER',
        id,
        JSON.stringify({
          oldPhone: customer.phone_number,
          newPhone: cleanPhone,
          oldName: customer.full_name,
          newName: updatedName,
        }),
      ]
    );

    return res.status(200).json({
      success: true,
      message: 'Cập nhật thông tin khách hàng thành công',
      data: updateRes.rows[0],
    });
  } catch (error: any) {
    return res.status(500).json({
      success: false,
      message: 'Lỗi cập nhật khách hàng',
      error: error.message,
    });
  }
};
