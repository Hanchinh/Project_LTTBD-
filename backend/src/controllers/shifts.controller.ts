import { Response } from 'express';
import { AuthenticatedRequest } from '../middlewares/auth.middleware';
import { query, pool } from '../db';
import path from 'path';
import fs from 'fs';
import crypto from 'crypto';

const UPLOADS_DIR = path.join(process.cwd(), 'uploads');

// Helper to normalize VN phone numbers
export function normalizePhoneNumber(raw: string): string {
  let clean = raw.replace(/\D/g, '');
  if (clean.startsWith('84') && clean.length === 11) {
    clean = '0' + clean.substring(2);
  } else if (clean.length === 9 && !clean.startsWith('0')) {
    clean = '0' + clean;
  }
  return clean;
}

import { parseAndNormalizeBulkPhones } from '../utils/phone.helper';
export { parseAndNormalizeBulkPhones };

// 1. GET /api/v1/shifts - Danh sách ca làm của shipper kèm tổng kết
export const listShifts = async (req: AuthenticatedRequest, res: Response) => {
  const shipperId = req.user?.userId;

  try {
    const result = await query(
      `SELECT s.id, s.shift_code, s.shift_name, s.work_date, s.status, s.started_at, s.completed_at, s.created_at, s.updated_at,
              COUNT(p.id)::int as total_points,
              COUNT(CASE WHEN p.location_status = 'VERIFIED' THEN 1 END)::int as verified_count,
              COUNT(CASE WHEN p.location_status = 'TEMPORARY' THEN 1 END)::int as temporary_count,
              COUNT(CASE WHEN p.location_status = 'NO_LOCATION' THEN 1 END)::int as no_location_count
       FROM shifts s
       LEFT JOIN shift_delivery_points p ON p.shift_id = s.id
       WHERE s.shipper_id = $1
       GROUP BY s.id
       ORDER BY s.work_date DESC, s.created_at DESC`,
      [shipperId]
    );

    const shifts = result.rows.map((row) => ({
      id: row.id,
      shiftCode: row.shift_code,
      shiftName: row.shift_name || null,
      workDate: row.work_date,
      status: row.status,
      startedAt: row.started_at,
      completedAt: row.completed_at,
      createdAt: row.created_at,
      updatedAt: row.updated_at,
      summary: {
        totalPoints: row.total_points,
        verifiedCount: row.verified_count,
        temporaryCount: row.temporary_count,
        noLocationCount: row.no_location_count,
      },
    }));

    return res.status(200).json({
      success: true,
      data: shifts,
    });
  } catch (error: any) {
    return res.status(500).json({
      success: false,
      message: 'Lỗi lấy danh sách ca làm việc',
      error: error.message,
    });
  }
};

// 2. POST /api/v1/shifts - Tạo ca làm mới
export const createShift = async (req: AuthenticatedRequest, res: Response) => {
  const shipperId = req.user?.userId;
  const { workDate, shiftDate, shiftName } = req.body;

  // Work date in Asia/Ho_Chi_Minh: YYYY-MM-DD
  const rawDate = workDate || shiftDate;
  const effectiveDate = (typeof rawDate === 'string' && rawDate.trim().length > 0)
    ? rawDate.trim()
    : new Date().toLocaleDateString('en-CA', { timeZone: 'Asia/Ho_Chi_Minh' });

  // Optional shift name (max 100 chars, trimmed)
  const cleanShiftName = (typeof shiftName === 'string' && shiftName.trim().length > 0)
    ? shiftName.trim().substring(0, 100)
    : null;

  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    // Count shifts on that date to generate sequence: SHF-YYYYMMDD-XXX
    const dateFormatted = effectiveDate.replace(/-/g, '');
    const countRes = await client.query(
      `SELECT COUNT(*)::int as count FROM shifts WHERE work_date = $1`,
      [effectiveDate]
    );
    const seq = (countRes.rows[0].count + 1).toString().padStart(3, '0');
    const shiftCode = `SHF-${dateFormatted}-${seq}`;

    const insertRes = await client.query(
      `INSERT INTO shifts (shift_code, shift_name, work_date, shipper_id, status)
       VALUES ($1, $2, $3, $4, 'PREPARING')
       RETURNING id, shift_code, shift_name, work_date, status, created_at, updated_at`,
      [shiftCode, cleanShiftName, effectiveDate, shipperId]
    );

    const shift = insertRes.rows[0];

    // Log audit
    await client.query(
      `INSERT INTO audit_logs (user_id, action, entity, entity_id, details)
       VALUES ($1, 'CREATE_SHIFT', 'shifts', $2, $3)`,
      [shipperId, shift.id, JSON.stringify({ shiftCode, shiftName: cleanShiftName, workDate: effectiveDate })]
    );

    await client.query('COMMIT');

    return res.status(201).json({
      success: true,
      message: 'Tạo ca làm việc mới thành công',
      data: {
        id: shift.id,
        shiftCode: shift.shift_code,
        shiftName: shift.shift_name || null,
        workDate: shift.work_date,
        shiftDate: shift.work_date,
        status: shift.status,
        createdAt: shift.created_at,
        updatedAt: shift.updated_at,
        summary: {
          totalPoints: 0,
          verifiedCount: 0,
          temporaryCount: 0,
          noLocationCount: 0,
        },
      },
    });
  } catch (error: any) {
    await client.query('ROLLBACK');
    return res.status(500).json({
      success: false,
      message: 'Lỗi tạo ca làm việc mới',
      error: error.message,
    });
  } finally {
    client.release();
  }
};

// 3. GET /api/v1/shifts/:id - Chi tiết ca làm và các điểm giao
export const getShiftDetail = async (req: AuthenticatedRequest, res: Response) => {
  const shipperId = req.user?.userId;
  const roleName = req.user?.roleName;
  const { id } = req.params;

  try {
    const shiftRes = await query(
      `SELECT s.id, s.shift_code, s.shift_name, s.work_date, s.status, s.shipper_id, s.started_at, s.completed_at, s.created_at, s.updated_at,
              u.full_name as shipper_name, u.phone_number as shipper_phone
       FROM shifts s
       JOIN users u ON u.id = s.shipper_id
       WHERE s.id = $1`,
      [id]
    );

    if (shiftRes.rows.length === 0) {
      return res.status(404).json({
        success: false,
        message: 'Không tìm thấy ca làm việc yêu cầu',
      });
    }

    const shift = shiftRes.rows[0];
    if (roleName === 'SHIPPER' && shift.shipper_id !== shipperId) {
      return res.status(403).json({
        success: false,
        message: 'Bạn không có quyền truy cập ca làm việc của shipper khác',
      });
    }

    // Query delivery points with customer info
    const pointsRes = await query(
      `SELECT p.id as point_id, p.shift_id, p.delivery_order_index, p.location_status,
              p.latitude, p.longitude, p.gps_accuracy, p.identification_notes, p.image_url,
              p.created_at as point_created_at, p.updated_at as point_updated_at,
              c.id as customer_id, c.customer_code, c.full_name as customer_name,
              c.phone_number as customer_phone, c.address_text as customer_address,
              a.id as area_id, a.name as area_name,
              sl.id as saved_location_id, sl.image_url as saved_image_url,
              COALESCE(cp_agg.photo_count, 0) as photo_count,
              COALESCE(cp_agg.photos, '[]'::json) as photos
       FROM shift_delivery_points p
       JOIN customers c ON c.id = p.customer_id
       JOIN areas a ON a.id = c.area_id
       LEFT JOIN saved_locations sl ON sl.customer_id = c.id
       LEFT JOIN LATERAL (
         SELECT 
           COUNT(*)::int as photo_count,
           (
             SELECT COALESCE(json_agg(photo_item), '[]'::json)
             FROM (
               SELECT id, image_url as "imageUrl", created_at as "createdAt"
               FROM customer_photos
               WHERE customer_id = c.id AND deleted_at IS NULL
               ORDER BY created_at DESC
               LIMIT 3
             ) photo_item
           ) as photos
         FROM customer_photos
         WHERE customer_id = c.id AND deleted_at IS NULL
       ) cp_agg ON true
       WHERE p.shift_id = $1
       ORDER BY p.delivery_order_index ASC, p.created_at ASC`,
      [id]
    );

    let verifiedCount = 0;
    let temporaryCount = 0;
    let noLocationCount = 0;

    const points = pointsRes.rows.map((row) => {
      const locStatus = row.location_status;
      if (locStatus === 'VERIFIED') verifiedCount++;
      else if (locStatus === 'TEMPORARY') temporaryCount++;
      else noLocationCount++;

      const pImg = (typeof row.image_url === 'string' && row.image_url.trim().length > 0) ? row.image_url.trim() : null;
      const sImg = (typeof row.saved_image_url === 'string' && row.saved_image_url.trim().length > 0) ? row.saved_image_url.trim() : null;
      const resolvedImg = pImg || sImg || null;

      const pCount = parseInt(row.photo_count, 10) || 0;
      let photoList = Array.isArray(row.photos) ? row.photos : [];
      if (photoList.length === 0 && resolvedImg) {
        photoList = [{ id: 'legacy', imageUrl: resolvedImg, createdAt: row.point_created_at }];
      }

      return {
        pointId: row.point_id,
        deliveryOrderIndex: row.delivery_order_index,
        locationStatus: row.location_status,
        latitude: row.latitude ? parseFloat(row.latitude) : null,
        longitude: row.longitude ? parseFloat(row.longitude) : null,
        gpsAccuracy: row.gps_accuracy ? parseFloat(row.gps_accuracy) : 0.0,
        identificationNotes: row.identification_notes,
        imageUrl: resolvedImg,
        photoCount: pCount > 0 ? pCount : (resolvedImg ? 1 : 0),
        photos: photoList,
        createdAt: row.point_created_at,
        updatedAt: row.point_updated_at,
        customer: {
          id: row.customer_id,
          customerCode: row.customer_code,
          fullName: row.customer_name,
          phoneNumber: row.customer_phone,
          addressText: row.customer_address,
          area: {
            id: row.area_id,
            name: row.area_name,
          },
        },
      };
    });

    return res.status(200).json({
      success: true,
      data: {
        id: shift.id,
        shiftCode: shift.shift_code,
        shiftName: shift.shift_name || null,
        workDate: shift.work_date,
        status: shift.status,
        shipper: {
          id: shift.shipper_id,
          fullName: shift.shipper_name,
          phoneNumber: shift.shipper_phone,
        },
        startedAt: shift.started_at,
        completedAt: shift.completed_at,
        createdAt: shift.created_at,
        updatedAt: shift.updated_at,
        summary: {
          totalPoints: points.length,
          verifiedCount,
          temporaryCount,
          noLocationCount,
        },
        points,
      },
    });
  } catch (error: any) {
    return res.status(500).json({
      success: false,
      message: 'Lỗi lấy chi tiết ca làm việc',
      error: error.message,
    });
  }
};

// 4. PATCH /api/v1/shifts/:id/status - Cập nhật trạng thái ca
export const updateShiftStatus = async (req: AuthenticatedRequest, res: Response) => {
  const shipperId = req.user?.userId;
  const roleName = req.user?.roleName;
  const { id } = req.params;
  const { status } = req.body;

  if (!['PREPARING', 'IN_PROGRESS', 'COMPLETED'].includes(status)) {
    return res.status(400).json({
      success: false,
      message: 'Trạng thái ca không hợp lệ (PREPARING, IN_PROGRESS, COMPLETED)',
    });
  }

  try {
    const shiftRes = await query(`SELECT id, shipper_id, status FROM shifts WHERE id = $1`, [id]);
    if (shiftRes.rows.length === 0) {
      return res.status(404).json({ success: false, message: 'Không tìm thấy ca làm việc' });
    }

    if (roleName === 'SHIPPER' && shiftRes.rows[0].shipper_id !== shipperId) {
      return res.status(403).json({ success: false, message: 'Bạn không có quyền cập nhật ca này' });
    }

    let startedAtClause = '';
    let completedAtClause = '';
    if (status === 'IN_PROGRESS') {
      startedAtClause = ', started_at = COALESCE(started_at, NOW())';
    } else if (status === 'COMPLETED') {
      completedAtClause = ', completed_at = NOW()';
    }

    const updateRes = await query(
      `UPDATE shifts
       SET status = $1, updated_at = NOW() ${startedAtClause} ${completedAtClause}
       WHERE id = $2
       RETURNING id, shift_code, shift_name, status, started_at, completed_at, updated_at`,
      [status, id]
    );

    return res.status(200).json({
      success: true,
      message: `Đã cập nhật trạng thái ca thành ${status}`,
      data: {
        id: updateRes.rows[0].id,
        shiftCode: updateRes.rows[0].shift_code,
        shiftName: updateRes.rows[0].shift_name || null,
        status: updateRes.rows[0].status,
        startedAt: updateRes.rows[0].started_at,
        completedAt: updateRes.rows[0].completed_at,
        updatedAt: updateRes.rows[0].updated_at,
      },
    });
  } catch (error: any) {
    return res.status(500).json({
      success: false,
      message: 'Lỗi cập nhật trạng thái ca',
      error: error.message,
    });
  }
};

// 5. POST /api/v1/shifts/:id/points - Thêm điểm giao vào ca qua SĐT hoặc CustomerId (hỗ trợ tạo nhanh khách mới)
export const addPointToShift = async (req: AuthenticatedRequest, res: Response) => {
  const shipperId = req.user?.userId;
  const roleName = req.user?.roleName;
  const assignedAreaIds = req.user?.assignedAreaIds || [];
  const { id: shiftId } = req.params;
  const { customerId, phoneNumber, createIfNotFound, fullName, addressText, notes, areaId } = req.body;

  if (!customerId && !phoneNumber) {
    return res.status(400).json({
      success: false,
      message: 'Vui lòng cung cấp customerId hoặc phoneNumber của khách hàng',
    });
  }

  let cleanPhone = '';
  if (phoneNumber) {
    cleanPhone = normalizePhoneNumber(phoneNumber);
    if (!cleanPhone || cleanPhone.length < 9 || cleanPhone.length > 12) {
      return res.status(400).json({
        success: false,
        message: 'Số điện thoại không đúng định dạng (cần 10 chữ số hợp lệ)',
      });
    }
  }

  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    // TASK: QUICK-ADD-013B: Nếu areaId gửi lên không thuộc khu vực shipper được phân công thì trả 403, không âm thầm đổi sang khu vực khác
    if (areaId && roleName !== 'ADMIN' && !assignedAreaIds.includes(areaId)) {
      await client.query('ROLLBACK');
      return res.status(403).json({
        success: false,
        message: 'Khu vực được chỉ định không thuộc khu vực bạn được phân công phụ trách',
      });
    }

    // Verify shift exists and belongs to shipper
    const shiftRes = await client.query(`SELECT id, shipper_id, status FROM shifts WHERE id = $1`, [shiftId]);
    if (shiftRes.rows.length === 0) {
      await client.query('ROLLBACK');
      return res.status(404).json({ success: false, message: 'Không tìm thấy ca làm việc' });
    }

    if (roleName === 'SHIPPER' && shiftRes.rows[0].shipper_id !== shipperId) {
      await client.query('ROLLBACK');
      return res.status(403).json({ success: false, message: 'Bạn không có quyền sửa ca làm việc này' });
    }

    // Lookup customer
    let custRes;
    if (customerId) {
      custRes = await client.query(
        `SELECT c.id, c.customer_code, c.full_name, c.phone_number, c.address_text, c.area_id, a.name as area_name
         FROM customers c
         JOIN areas a ON a.id = c.area_id
         WHERE c.id = $1`,
        [customerId]
      );
    } else {
      custRes = await client.query(
        `SELECT c.id, c.customer_code, c.full_name, c.phone_number, c.address_text, c.area_id, a.name as area_name
         FROM customers c
         JOIN areas a ON a.id = c.area_id
         WHERE c.phone_number = $1 OR c.phone_number = $2`,
        [cleanPhone, phoneNumber]
      );
    }

    let customer: any;

    if (custRes.rows.length === 0) {
      // Trường hợp 2: Khách chưa tồn tại
      if (!createIfNotFound && !fullName && !addressText) {
        await client.query('ROLLBACK');
        return res.status(404).json({
          success: false,
          message: 'Không tìm thấy hồ sơ khách hàng trong hệ thống CSDL.',
        });
      }

      // Shipper hoặc hệ thống yêu cầu tạo nhanh hồ sơ khách hàng mới (Giai đoạn B)
      let targetAreaId: string | null = null;
      if (areaId) {
        targetAreaId = areaId;
      } else if (assignedAreaIds.length > 0) {
        targetAreaId = assignedAreaIds[0];
      } else if (roleName === 'ADMIN') {
        const areaQuery = await client.query('SELECT id FROM areas ORDER BY created_at ASC LIMIT 1');
        targetAreaId = areaQuery.rows[0]?.id || null;
      }

      if (!targetAreaId) {
        await client.query('ROLLBACK');
        return res.status(400).json({
          success: false,
          message: 'Không xác định được khu vực phân công để tạo hồ sơ khách hàng',
        });
      }

      // TASK: QUICK-ADD-CUSTOMER-013: Mặc định tên "Khách [SĐT]", địa chỉ "Chưa cập nhật địa chỉ"
      const custName = (fullName && fullName.trim()) ? fullName.trim() : `Khách ${cleanPhone}`;
      const custAddress = (addressText && addressText.trim()) ? addressText.trim() : 'Chưa cập nhật địa chỉ';
      const custCode = `KH_${cleanPhone.slice(-6)}_${Date.now().toString().slice(-4)}`;

      // Insert customer với ON CONFLICT (phone_number) bảo đảm an toàn khi gọi đồng thời
      const newCustRes = await client.query(
        `INSERT INTO customers (customer_code, full_name, phone_number, address_text, area_id)
         VALUES ($1, $2, $3, $4, $5)
         ON CONFLICT (phone_number) DO UPDATE
         SET full_name = CASE WHEN EXCLUDED.full_name IS NOT NULL AND EXCLUDED.full_name != '' THEN EXCLUDED.full_name ELSE customers.full_name END
         RETURNING id, customer_code, full_name, phone_number, address_text, area_id`,
        [custCode, custName, cleanPhone, custAddress, targetAreaId]
      );

      customer = newCustRes.rows[0];
      const areaNameRes = await client.query('SELECT name FROM areas WHERE id = $1', [customer.area_id]);
      customer.area_name = areaNameRes.rows[0]?.name || 'Khu vực được phân công';
    } else {
      customer = custRes.rows[0];
    }

    // Verify area assignment
    if (roleName === 'SHIPPER' && !assignedAreaIds.includes(customer.area_id)) {
      await client.query('ROLLBACK');
      return res.status(403).json({
        success: false,
        message: 'Khách hàng này thuộc khu vực bạn không được phân công phụ trách',
      });
    }

    // Check if customer is already in this shift
    const existingPointRes = await client.query(
      `SELECT p.id, p.location_status, p.latitude, p.longitude
       FROM shift_delivery_points p
       WHERE p.shift_id = $1 AND p.customer_id = $2`,
      [shiftId, customer.id]
    );

    if (existingPointRes.rows.length > 0) {
      const summaryRes = await client.query(
        `SELECT COUNT(p.id)::int as total_points,
                COUNT(CASE WHEN p.location_status = 'VERIFIED' THEN 1 END)::int as verified_count,
                COUNT(CASE WHEN p.location_status = 'TEMPORARY' THEN 1 END)::int as temporary_count,
                COUNT(CASE WHEN p.location_status = 'NO_LOCATION' THEN 1 END)::int as no_location_count
         FROM shift_delivery_points p
         WHERE p.shift_id = $1`,
        [shiftId]
      );
      await client.query('ROLLBACK');
      const existing = existingPointRes.rows[0];
      const sumRow = summaryRes.rows[0] || {};
      const summary = {
        totalPoints: sumRow.total_points || 0,
        verifiedCount: sumRow.verified_count || 0,
        temporaryCount: sumRow.temporary_count || 0,
        noLocationCount: sumRow.no_location_count || 0,
      };

      return res.status(200).json({
        success: true,
        message: 'Khách hàng này đã có trong danh sách ca làm việc!',
        isExisting: true,
        data: {
          pointId: existing.id,
          customerId: customer.id,
          customerName: customer.full_name,
          locationStatus: existing.location_status,
          latitude: existing.latitude ? parseFloat(existing.latitude) : null,
          longitude: existing.longitude ? parseFloat(existing.longitude) : null,
        },
        summary,
      });
    }

    // Check if customer has a verified saved_locations in DB
    const savedLocRes = await client.query(
      `SELECT id, latitude, longitude, gps_accuracy, identification_notes, image_url
       FROM saved_locations
       WHERE customer_id = $1`,
      [customer.id]
    );

    let locationStatus = 'NO_LOCATION';
    let lat: number | null = null;
    let lng: number | null = null;
    let accuracy = 0.0;
    let finalNotes: string | null = (notes && typeof notes === 'string' && notes.trim()) ? notes.trim() : (req.body.deliveryNotes || null);
    let imgUrl: string | null = null;

    if (savedLocRes.rows.length > 0) {
      const loc = savedLocRes.rows[0];
      locationStatus = 'VERIFIED';
      lat = parseFloat(loc.latitude);
      lng = parseFloat(loc.longitude);
      accuracy = parseFloat(loc.gps_accuracy) || 0.0;
      finalNotes = loc.identification_notes || finalNotes;
      imgUrl = loc.image_url;
    }

    // Get next delivery order index
    const countIndexRes = await client.query(
      `SELECT COALESCE(MAX(delivery_order_index), 0) + 1 as next_idx
       FROM shift_delivery_points
       WHERE shift_id = $1`,
      [shiftId]
    );
    const nextIdx = countIndexRes.rows[0].next_idx;

    // Insert delivery point
    const insertPointRes = await client.query(
      `INSERT INTO shift_delivery_points
       (shift_id, customer_id, delivery_order_index, location_status, geom, latitude, longitude, gps_accuracy, identification_notes, image_url)
       VALUES
       ($1, $2, $3, $4, 
        CASE WHEN $5::numeric IS NOT NULL AND $6::numeric IS NOT NULL THEN ST_SetSRID(ST_MakePoint($6::numeric, $5::numeric), 4326) ELSE NULL END,
        $5, $6, $7, $8, $9)
       RETURNING id, delivery_order_index, location_status, latitude, longitude, gps_accuracy, identification_notes, image_url, created_at`,
      [shiftId, customer.id, nextIdx, locationStatus, lat, lng, accuracy, finalNotes, imgUrl]
    );

    const point = insertPointRes.rows[0];

    // Compute updated shift summary
    const summaryRes = await client.query(
      `SELECT COUNT(p.id)::int as total_points,
              COUNT(CASE WHEN p.location_status = 'VERIFIED' THEN 1 END)::int as verified_count,
              COUNT(CASE WHEN p.location_status = 'TEMPORARY' THEN 1 END)::int as temporary_count,
              COUNT(CASE WHEN p.location_status = 'NO_LOCATION' THEN 1 END)::int as no_location_count
       FROM shift_delivery_points p
       WHERE p.shift_id = $1`,
      [shiftId]
    );
    const sumRow = summaryRes.rows[0] || {};
    const summary = {
      totalPoints: sumRow.total_points || 0,
      verifiedCount: sumRow.verified_count || 0,
      temporaryCount: sumRow.temporary_count || 0,
      noLocationCount: sumRow.no_location_count || 0,
    };

    // Log audit
    await client.query(
      `INSERT INTO audit_logs (user_id, action, entity, entity_id, details)
       VALUES ($1, 'ADD_SHIFT_POINT', 'shift_delivery_points', $2, $3)`,
      [shipperId, point.id, JSON.stringify({ shiftId, customerId: customer.id, locationStatus })]
    );

    await client.query('COMMIT');

    return res.status(201).json({
      success: true,
      message: 'Đã thêm điểm giao vào ca làm việc thành công',
      isExisting: false,
      data: {
        pointId: point.id,
        customerId: customer.id,
        customerName: customer.full_name,
        customerPhone: customer.phone_number,
        customerAddress: customer.address_text,
        deliveryOrderIndex: point.delivery_order_index,
        locationStatus: point.location_status,
        latitude: point.latitude ? parseFloat(point.latitude) : null,
        longitude: point.longitude ? parseFloat(point.longitude) : null,
        gpsAccuracy: point.gps_accuracy ? parseFloat(point.gps_accuracy) : 0.0,
        identificationNotes: point.identification_notes,
        locationNotes: point.identification_notes,
        imageUrl: point.image_url,
        photoUrl: point.image_url,
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
      },
      summary,
    });
  } catch (error: any) {
    await client.query('ROLLBACK');
    return res.status(500).json({
      success: false,
      message: 'Lỗi thêm điểm giao vào ca làm việc',
      error: error.message,
    });
  } finally {
    client.release();
  }
};

// 6. DELETE /api/v1/shifts/:id/points/:pointId - Xóa điểm giao khỏi ca
export const removePointFromShift = async (req: AuthenticatedRequest, res: Response) => {
  const shipperId = req.user?.userId;
  const roleName = req.user?.roleName;
  const { id: shiftId, pointId } = req.params;

  try {
    const shiftRes = await query(`SELECT id, shipper_id FROM shifts WHERE id = $1`, [shiftId]);
    if (shiftRes.rows.length === 0) {
      return res.status(404).json({ success: false, message: 'Không tìm thấy ca làm việc' });
    }

    if (roleName === 'SHIPPER' && shiftRes.rows[0].shipper_id !== shipperId) {
      return res.status(403).json({ success: false, message: 'Bạn không có quyền sửa ca này' });
    }

    const delRes = await query(
      `DELETE FROM shift_delivery_points WHERE id = $1 AND shift_id = $2 RETURNING id`,
      [pointId, shiftId]
    );

    if (delRes.rows.length === 0) {
      return res.status(404).json({ success: false, message: 'Không tìm thấy điểm giao trong ca' });
    }

    return res.status(200).json({
      success: true,
      message: 'Đã xóa điểm giao khỏi ca làm việc',
    });
  } catch (error: any) {
    return res.status(500).json({
      success: false,
      message: 'Lỗi xóa điểm giao khỏi ca',
      error: error.message,
    });
  }
};

// 7. PUT /api/v1/shifts/:id/points/:pointId/temporary-location - Ghim vị trí tạm qua bộ chọn tâm ngắm
export const updateTemporaryLocation = async (req: AuthenticatedRequest, res: Response) => {
  const shipperId = req.user?.userId;
  const roleName = req.user?.roleName;
  const { id: shiftId, pointId } = req.params;
  const { latitude, longitude, locationNotes, identificationNotes } = req.body;

  if (latitude === undefined || longitude === undefined) {
    return res.status(400).json({
      success: false,
      message: 'Vui lòng cung cấp tọa độ latitude và longitude',
    });
  }

  const lat = Number(latitude);
  const lng = Number(longitude);
  if (isNaN(lat) || isNaN(lng) || lat < -90 || lat > 90 || lng < -180 || lng > 180) {
    return res.status(400).json({
      success: false,
      message: 'Tọa độ WGS84 không hợp lệ',
    });
  }

  // Loại bỏ các chuỗi ghi chú mặc định tự sinh để không ghi đè ghi chú nhận diện thực tế của khách
  const incomingNotes = (typeof identificationNotes === 'string' && identificationNotes.trim())
    ? identificationNotes.trim()
    : (typeof locationNotes === 'string' && locationNotes.trim())
    ? locationNotes.trim()
    : null;

  const isDefaultString = incomingNotes === 'Ghim trực tiếp từ bản đồ chính' || 
                          incomingNotes === 'Ghim tạm từ bộ chọn tâm ngắm bản đồ';
  const customNotes = (!isDefaultString && incomingNotes) ? incomingNotes : null;

  try {
    const shiftRes = await query(`SELECT id, shipper_id FROM shifts WHERE id = $1`, [shiftId]);
    if (shiftRes.rows.length === 0) {
      return res.status(404).json({ success: false, message: 'Không tìm thấy ca làm việc' });
    }

    if (roleName === 'SHIPPER' && shiftRes.rows[0].shipper_id !== shipperId) {
      return res.status(403).json({ success: false, message: 'Bạn không có quyền sửa ca này' });
    }

    // Update point to TEMPORARY status with spatial PostGIS point ST_SetSRID(ST_MakePoint(lng, lat), 4326)
    // Bảo toàn nguyên vẹn ghi chú và bổ sung ảnh từ saved_locations/history nếu điểm giao chưa có ảnh
    const updateRes = await query(
      `UPDATE shift_delivery_points
       SET location_status = 'TEMPORARY',
           latitude = $1,
           longitude = $2,
           geom = ST_SetSRID(ST_MakePoint($4, $3), 4326),
           identification_notes = CASE 
             WHEN $5::text IS NOT NULL AND $5::text != '' THEN $5::text 
             ELSE identification_notes 
           END,
           image_url = COALESCE(
             image_url,
             (SELECT image_url FROM saved_locations WHERE customer_id = shift_delivery_points.customer_id LIMIT 1)
           ),
           updated_at = NOW()
       WHERE id = $6 AND shift_id = $7
       RETURNING id, customer_id, location_status, latitude, longitude, identification_notes, image_url, updated_at`,
      [lat, lng, lat, lng, customNotes, pointId, shiftId]
    );

    if (updateRes.rows.length === 0) {
      return res.status(404).json({ success: false, message: 'Không tìm thấy điểm giao trong ca' });
    }

    const customerId = updateRes.rows[0].customer_id;
    const resolvedImageUrl = updateRes.rows[0].image_url || null;

    if (customerId) {
      // Đồng bộ tọa độ và ảnh của khách hàng này trong những ca PREPARING, hoặc IN_PROGRESS của chính shipper này
      // Tuyệt đối không sửa các ca COMPLETED và không can thiệp vào ca IN_PROGRESS của shipper khác
      await query(
        `UPDATE shift_delivery_points sdp
         SET location_status = 'TEMPORARY',
             latitude = $1,
             longitude = $2,
             geom = ST_SetSRID(ST_MakePoint($4, $3), 4326),
             identification_notes = CASE 
               WHEN $5::text IS NOT NULL AND $5::text != '' THEN $5::text 
               ELSE sdp.identification_notes 
             END,
             image_url = COALESCE(sdp.image_url, $9),
             updated_at = NOW()
         FROM shifts s
         WHERE sdp.shift_id = s.id
           AND sdp.customer_id = $6
           AND sdp.id != $7
           AND (s.status = 'PREPARING' OR (s.status = 'IN_PROGRESS' AND s.shipper_id = $8))`,
        [lat, lng, lat, lng, customNotes, customerId, pointId, shipperId, resolvedImageUrl]
      );
    }

    // Ghi audit log bảo đảm toàn vẹn kiểm toán (AGENTS.md rule 2.5)
    await query(
      `INSERT INTO audit_logs (user_id, action, entity, entity_id, details)
       VALUES ($1, 'PIN_TEMPORARY_LOCATION', 'shift_delivery_points', $2, $3)`,
      [shipperId, pointId, JSON.stringify({ shiftId, customerId, latitude: lat, longitude: lng })]
    );

    return res.status(200).json({
      success: true,
      message: 'Đã ghim vị trí tạm thời cho điểm giao thành công',
      data: {
        pointId: updateRes.rows[0].id,
        customerId,
        locationStatus: updateRes.rows[0].location_status,
        latitude: parseFloat(updateRes.rows[0].latitude),
        longitude: parseFloat(updateRes.rows[0].longitude),
        identificationNotes: updateRes.rows[0].identification_notes,
        locationNotes: updateRes.rows[0].identification_notes,
        imageUrl: resolvedImageUrl,
        photoUrl: resolvedImageUrl,
        updatedAt: updateRes.rows[0].updated_at,
      },
    });
  } catch (error: any) {
    return res.status(500).json({
      success: false,
      message: 'Lỗi cập nhật vị trí tạm thời',
      error: error.message,
    });
  }
};

// 8. POST /api/v1/shifts/:id/points/:pointId/verify-location - ĐÃ NGỪNG HOẠT ĐỘNG (410 Gone)
export const verifyPointLocation = async (req: AuthenticatedRequest, res: Response) => {
  return res.status(410).json({
    success: false,
    message: 'Endpoint xác minh vị trí trong ca đã ngừng hoạt động (410 Gone). Theo quy chuẩn LOCATION-RULES-012, vị trí chuẩn chỉ được xác nhận qua luồng Danh bạ -> Hồ sơ khách -> Xác nhận vị trí.',
    errorCode: 'ENDPOINT_GONE_USE_DIRECTORY_FLOW',
  });
};

// 9. DELETE /api/v1/shifts/:id - Xóa ca làm việc và các điểm giao của ca
export const deleteShift = async (req: AuthenticatedRequest, res: Response) => {
  const shipperId = req.user?.userId;
  const roleName = req.user?.roleName;
  const { id } = req.params;

  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    // 1. Kiểm tra ca làm việc tồn tại
    const shiftRes = await client.query(
      `SELECT id, shift_code, shipper_id, status FROM shifts WHERE id = $1`,
      [id]
    );

    if (shiftRes.rows.length === 0) {
      await client.query('ROLLBACK');
      return res.status(404).json({
        success: false,
        message: 'Không tìm thấy ca làm việc yêu cầu',
      });
    }

    const shift = shiftRes.rows[0];

    // 2. Phân quyền: Shipper chỉ được xóa ca của mình, ADMIN xóa được mọi ca
    if (roleName === 'SHIPPER' && shift.shipper_id !== shipperId) {
      await client.query('ROLLBACK');
      return res.status(403).json({
        success: false,
        message: 'Bạn không có quyền xóa ca làm việc của shipper khác',
      });
    }

    // 3. Đếm số điểm giao sẽ bị hủy để ghi audit
    const countPointsRes = await client.query(
      `SELECT COUNT(*)::int as count FROM shift_delivery_points WHERE shift_id = $1`,
      [id]
    );
    const deletedPointsCount = countPointsRes.rows[0]?.count || 0;

    // 4. Xóa các điểm giao thuộc ca (shift_delivery_points)
    // TUYỆT ĐỐI KHÔNG đụng customers, saved_locations, location_history
    await client.query(
      `DELETE FROM shift_delivery_points WHERE shift_id = $1`,
      [id]
    );

    // 5. Xóa ca làm việc (shifts)
    await client.query(
      `DELETE FROM shifts WHERE id = $1`,
      [id]
    );

    // 6. Ghi audit log với hành động DELETE_SHIFT
    await client.query(
      `INSERT INTO audit_logs (user_id, action, entity, entity_id, details)
       VALUES ($1, 'DELETE_SHIFT', 'shifts', $2, $3)`,
      [
        shipperId,
        id,
        JSON.stringify({
          shiftCode: shift.shift_code,
          status: shift.status,
          deletedPointsCount,
        }),
      ]
    );

    await client.query('COMMIT');

    return res.status(200).json({
      success: true,
      message: `Đã xóa ca làm việc ${shift.shift_code} thành công`,
      data: {
        id: shift.id,
        shiftCode: shift.shift_code,
        deletedPointsCount,
      },
    });
  } catch (error: any) {
    await client.query('ROLLBACK');
    return res.status(500).json({
      success: false,
      message: 'Lỗi xóa ca làm việc',
      error: error.message,
    });
  } finally {
    client.release();
  }
};

// 10. PATCH /api/v1/shifts/:id/name - Đổi tên ca làm việc
export const updateShiftName = async (req: AuthenticatedRequest, res: Response) => {
  const shipperId = req.user?.userId;
  const roleName = req.user?.roleName;
  const { id } = req.params;
  const { shiftName } = req.body;

  try {
    const shiftRes = await query(`SELECT id, shipper_id, shift_code, shift_name FROM shifts WHERE id = $1`, [id]);
    if (shiftRes.rows.length === 0) {
      return res.status(404).json({ success: false, message: 'Không tìm thấy ca làm việc' });
    }

    if (roleName === 'SHIPPER' && shiftRes.rows[0].shipper_id !== shipperId) {
      return res.status(403).json({ success: false, message: 'Bạn không có quyền đổi tên ca làm việc của shipper khác' });
    }

    const cleanShiftName = (typeof shiftName === 'string' && shiftName.trim().length > 0)
      ? shiftName.trim().substring(0, 100)
      : null;

    const updateRes = await query(
      `UPDATE shifts SET shift_name = $1, updated_at = NOW() WHERE id = $2 RETURNING id, shift_code, shift_name, updated_at`,
      [cleanShiftName, id]
    );

    await query(
      `INSERT INTO audit_logs (user_id, action, entity, entity_id, details)
       VALUES ($1, 'UPDATE_SHIFT_NAME', 'shifts', $2, $3)`,
      [shipperId, id, JSON.stringify({ shiftCode: shiftRes.rows[0].shift_code, oldName: shiftRes.rows[0].shift_name, newName: cleanShiftName })]
    );

    return res.status(200).json({
      success: true,
      message: 'Đổi tên ca làm việc thành công',
      data: {
        id: updateRes.rows[0].id,
        shiftCode: updateRes.rows[0].shift_code,
        shiftName: updateRes.rows[0].shift_name || null,
        updatedAt: updateRes.rows[0].updated_at,
      },
    });
  } catch (error: any) {
    return res.status(500).json({
      success: false,
      message: 'Lỗi đổi tên ca làm việc',
      error: error.message,
    });
  }
};

// 11. POST /api/v1/shifts/:id/points/bulk - Thêm hàng loạt điểm giao vào ca
export const addBulkPointsToShift = async (req: AuthenticatedRequest, res: Response) => {
  const shipperId = req.user?.userId;
  const roleName = req.user?.roleName;
  const assignedAreaIds = req.user?.assignedAreaIds || [];
  const { id: shiftId } = req.params;
  const { rawText, phones, areaId } = req.body;

  if (!rawText && (!phones || !Array.isArray(phones) || phones.length === 0)) {
    return res.status(400).json({
      success: false,
      message: 'Vui lòng cung cấp danh sách số điện thoại (phones) hoặc đoạn văn bản (rawText)',
    });
  }

  // Parse and normalize
  const parsed = parseAndNormalizeBulkPhones(rawText, phones);

  if (parsed.items.length === 0) {
    return res.status(400).json({
      success: false,
      message: 'Không tìm thấy số điện thoại nào trong dữ liệu gửi lên',
    });
  }

  if (parsed.uniquePhones.length > 200) {
    return res.status(400).json({
      success: false,
      message: `Vượt quá giới hạn tối đa 200 số điện thoại cho mỗi lần thêm hàng loạt (nhận được ${parsed.uniquePhones.length} số)`,
    });
  }

  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    // 1. Verify shift exists and belongs to shipper
    const shiftRes = await client.query(`SELECT id, shipper_id, status FROM shifts WHERE id = $1`, [shiftId]);
    if (shiftRes.rows.length === 0) {
      await client.query('ROLLBACK');
      return res.status(404).json({ success: false, message: 'Không tìm thấy ca làm việc' });
    }

    if (roleName === 'SHIPPER' && shiftRes.rows[0].shipper_id !== shipperId) {
      await client.query('ROLLBACK');
      return res.status(403).json({ success: false, message: 'Bạn không có quyền sửa ca làm việc của shipper khác' });
    }

    // 2. Validate requested areaId if specified
    if (areaId && roleName !== 'ADMIN' && !assignedAreaIds.includes(areaId)) {
      await client.query('ROLLBACK');
      return res.status(403).json({
        success: false,
        message: 'Khu vực được chỉ định không thuộc khu vực bạn được phân công phụ trách',
      });
    }

    // Prepare result arrays
    const added: any[] = [];
    const alreadyInShift: any[] = [];
    const rejected: any[] = [];

    // Push initially invalid items into rejected
    for (const item of parsed.items) {
      if (!item.isValid) {
        rejected.push({
          phone: item.original,
          reason: 'INVALID_FORMAT',
          message: item.reason || 'Số điện thoại không đúng định dạng (cần 10 chữ số hợp lệ)',
        });
      }
    }

    // 3. For all valid unique phones, query DB to see existing customers & existing shift points
    const validPhones = parsed.uniquePhones;

    // Existing points in this shift for these phones
    const existingPointsRes = await client.query(
      `SELECT p.id as point_id, p.location_status, p.latitude, p.longitude,
              c.id as customer_id, c.full_name as customer_name, c.phone_number as customer_phone
       FROM shift_delivery_points p
       JOIN customers c ON c.id = p.customer_id
       WHERE p.shift_id = $1 AND c.phone_number = ANY($2::varchar[])`,
      [shiftId, validPhones]
    );

    const existingPointsMap = new Map<string, any>();
    for (const row of existingPointsRes.rows) {
      existingPointsMap.set(row.customer_phone, row);
    }

    // Existing customers in DB for these phones
    const existingCustRes = await client.query(
      `SELECT c.id, c.customer_code, c.full_name, c.phone_number, c.address_text, c.area_id, a.name as area_name
       FROM customers c
       JOIN areas a ON a.id = c.area_id
       WHERE c.phone_number = ANY($1::varchar[])`,
      [validPhones]
    );

    const existingCustomersMap = new Map<string, any>();
    for (const cust of existingCustRes.rows) {
      existingCustomersMap.set(cust.phone_number, cust);
    }

    // Existing saved locations for these existing customers
    const existingCustomerIds = Array.from(existingCustomersMap.values()).map(c => c.id);
    const savedLocationsMap = new Map<string, any>();
    if (existingCustomerIds.length > 0) {
      const savedLocRes = await client.query(
        `SELECT id, customer_id, latitude, longitude, gps_accuracy, identification_notes, image_url
         FROM saved_locations
         WHERE customer_id = ANY($1::uuid[])`,
        [existingCustomerIds]
      );
      for (const loc of savedLocRes.rows) {
        savedLocationsMap.set(loc.customer_id, loc);
      }
    }

    // Check which phones need to be newly created as customers
    const phonesNeedingNewCustomer: string[] = [];
    for (const phone of validPhones) {
      if (existingPointsMap.has(phone)) {
        continue;
      }
      if (!existingCustomersMap.has(phone)) {
        phonesNeedingNewCustomer.push(phone);
      }
    }

    // If new customers need to be created, determine default area
    let targetAreaId: string | null = null;
    if (phonesNeedingNewCustomer.length > 0) {
      if (areaId) {
        targetAreaId = areaId;
      } else if (roleName === 'ADMIN') {
        const areaQuery = await client.query('SELECT id FROM areas ORDER BY created_at ASC LIMIT 1');
        targetAreaId = areaQuery.rows[0]?.id || null;
      } else if (roleName === 'SHIPPER') {
        if (assignedAreaIds.length === 1) {
          targetAreaId = assignedAreaIds[0];
        } else if (assignedAreaIds.length > 1) {
          await client.query('ROLLBACK');
          return res.status(400).json({
            success: false,
            message: 'Bạn phụ trách nhiều khu vực. Vui lòng chọn khu vực áp dụng cho các khách hàng mới trước khi thêm danh sách SĐT',
            requireAreaSelection: true,
          });
        } else {
          await client.query('ROLLBACK');
          return res.status(400).json({
            success: false,
            message: 'Shipper chưa được phân công khu vực phụ trách',
          });
        }
      }
    }

    // Get current max delivery_order_index in this shift
    const countIndexRes = await client.query(
      `SELECT COALESCE(MAX(delivery_order_index), 0)::int as max_idx FROM shift_delivery_points WHERE shift_id = $1`,
      [shiftId]
    );
    let currentOrderIdx = countIndexRes.rows[0].max_idx;

    // Process each valid phone
    for (const phone of validPhones) {
      // 1. Check if already in shift
      if (existingPointsMap.has(phone)) {
        const pt = existingPointsMap.get(phone);
        alreadyInShift.push({
          phone,
          pointId: pt.point_id,
          customerId: pt.customer_id,
          customerName: pt.customer_name,
          locationStatus: pt.location_status,
        });
        continue;
      }

      // 2. Check if customer exists in DB
      let customer = existingCustomersMap.get(phone);

      if (customer) {
        // Customer exists: check area scope
        if (roleName === 'SHIPPER' && !assignedAreaIds.includes(customer.area_id)) {
          rejected.push({
            phone,
            reason: 'OUT_OF_AREA',
            message: 'Khách hàng thuộc khu vực bạn không được phân công phụ trách',
          });
          continue;
        }
      } else {
        // Create new customer fast
        const custName = `Khách ${phone}`;
        const custAddress = 'Chưa cập nhật địa chỉ';
        const custCode = `KH_${phone.slice(-6)}_${Date.now().toString().slice(-4)}`;

        const newCustRes = await client.query(
          `INSERT INTO customers (customer_code, full_name, phone_number, address_text, area_id)
           VALUES ($1, $2, $3, $4, $5)
           ON CONFLICT (phone_number) DO UPDATE
           SET full_name = CASE WHEN EXCLUDED.full_name IS NOT NULL AND EXCLUDED.full_name != '' THEN EXCLUDED.full_name ELSE customers.full_name END
           RETURNING id, customer_code, full_name, phone_number, address_text, area_id`,
          [custCode, custName, phone, custAddress, targetAreaId]
        );
        customer = newCustRes.rows[0];
      }

      // Check if customer has verified saved location
      const savedLoc = savedLocationsMap.get(customer.id);
      let locationStatus = 'NO_LOCATION';
      let lat: number | null = null;
      let lng: number | null = null;
      let accuracy = 0.0;
      let notes: string | null = null;
      let imgUrl: string | null = null;

      if (savedLoc) {
        locationStatus = 'VERIFIED';
        lat = parseFloat(savedLoc.latitude);
        lng = parseFloat(savedLoc.longitude);
        accuracy = parseFloat(savedLoc.gps_accuracy) || 0.0;
        notes = savedLoc.identification_notes || null;
        imgUrl = savedLoc.image_url || null;
      }

      currentOrderIdx++;

      // Insert into shift_delivery_points
      const insertPointRes = await client.query(
        `INSERT INTO shift_delivery_points
         (shift_id, customer_id, delivery_order_index, location_status, geom, latitude, longitude, gps_accuracy, identification_notes, image_url)
         VALUES
         ($1, $2, $3, $4,
          CASE WHEN $5::numeric IS NOT NULL AND $6::numeric IS NOT NULL THEN ST_SetSRID(ST_MakePoint($6::numeric, $5::numeric), 4326) ELSE NULL END,
          $5, $6, $7, $8, $9)
         RETURNING id, delivery_order_index, location_status, latitude, longitude, gps_accuracy, identification_notes, image_url, created_at`,
        [shiftId, customer.id, currentOrderIdx, locationStatus, lat, lng, accuracy, notes, imgUrl]
      );

      const pt = insertPointRes.rows[0];

      added.push({
        pointId: pt.id,
        customerId: customer.id,
        customerName: customer.full_name,
        customerPhone: customer.phone_number,
        customerAddress: customer.address_text,
        deliveryOrderIndex: pt.delivery_order_index,
        locationStatus: pt.location_status,
        latitude: pt.latitude ? parseFloat(pt.latitude) : null,
        longitude: pt.longitude ? parseFloat(pt.longitude) : null,
        gpsAccuracy: pt.gps_accuracy ? parseFloat(pt.gps_accuracy) : 0.0,
        identificationNotes: pt.identification_notes,
        imageUrl: pt.image_url,
        photoCount: pt.image_url ? 1 : 0,
        photos: pt.image_url ? [{ id: 'legacy', imageUrl: pt.image_url, createdAt: pt.created_at }] : [],
      });
    }

    // Summary calculation
    const summary = {
      total: parsed.items.length,
      addedCount: added.length,
      alreadyInShiftCount: alreadyInShift.length,
      rejectedCount: rejected.length,
    };

    // Log audit
    await client.query(
      `INSERT INTO audit_logs (user_id, action, entity, entity_id, details)
       VALUES ($1, 'BULK_ADD_POINTS', 'shifts', $2, $3)`,
      [shipperId, shiftId, JSON.stringify(summary)]
    );

    await client.query('COMMIT');

    return res.status(200).json({
      success: true,
      message: `Đã xử lý danh sách SĐT: ${added.length} đã thêm, ${alreadyInShift.length} đã có trong ca, ${rejected.length} bị từ chối`,
      data: {
        added,
        alreadyInShift,
        rejected,
        summary,
      },
    });
  } catch (error: any) {
    await client.query('ROLLBACK');
    return res.status(500).json({
      success: false,
      message: 'Lỗi thêm hàng loạt điểm giao vào ca làm việc',
      error: error.message,
    });
  } finally {
    client.release();
  }
};
