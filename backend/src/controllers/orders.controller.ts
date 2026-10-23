import { Response } from 'express';
import { AuthenticatedRequest } from '../middlewares/auth.middleware';
import { query, pool } from '../db';

export const formatOrderRow = (row: any) => ({
  orderId: row.order_id,
  orderCode: row.order_code,
  orderStatus: row.order_status,
  createdAt: row.order_created_at,
  area: {
    id: row.area_id,
    name: row.area_name,
  },
  customer: {
    id: row.customer_id,
    customerCode: row.customer_code,
    fullName: row.customer_name,
    phoneNumber: row.customer_phone,
    addressText: row.customer_address,
    hasSavedLocation: !!row.saved_location_id,
    savedLocation: row.saved_location_id
      ? {
          id: row.saved_location_id,
          latitude: parseFloat(row.latitude),
          longitude: parseFloat(row.longitude),
          gpsAccuracy: parseFloat(row.gps_accuracy),
          identificationNotes: row.identification_notes,
          imageUrl: row.image_url,
          updatedAt: row.location_updated_at,
        }
      : null,
  },
});

export const getMyShiftOrders = async (req: AuthenticatedRequest, res: Response) => {
  const shipperId = req.user?.userId;

  try {
    const ordersRes = await query(
      `SELECT 
        o.id as order_id,
        o.order_code,
        o.status as order_status,
        o.created_at as order_created_at,
        c.id as customer_id,
        c.customer_code,
        c.full_name as customer_name,
        c.phone_number as customer_phone,
        c.address_text as customer_address,
        a.id as area_id,
        a.name as area_name,
        sl.id as saved_location_id,
        sl.latitude,
        sl.longitude,
        sl.gps_accuracy,
        sl.identification_notes,
        sl.image_url,
        sl.updated_at as location_updated_at
       FROM orders o
       JOIN customers c ON c.id = o.customer_id
       JOIN areas a ON a.id = o.area_id
       LEFT JOIN saved_locations sl ON sl.customer_id = c.id
       WHERE o.shipper_id = $1
       ORDER BY o.created_at DESC`,
      [shipperId]
    );

    const formattedOrders = ordersRes.rows.map(formatOrderRow);

    return res.json({
      success: true,
      data: formattedOrders,
    });
  } catch (error: any) {
    return res.status(500).json({ success: false, message: 'Lỗi lấy danh sách đơn hàng', error: error.message });
  }
};

/**
 * Thêm điểm giao (đơn hàng) mới vào ca của shipper
 * Hỗ trợ tra cứu customerId, phân quyền khu vực và chống tạo đơn trùng lặp
 */
export const createShiftOrder = async (req: AuthenticatedRequest, res: Response) => {
  const shipperId = req.user?.userId;
  const { customerId, allowMultiple, idempotencyKey } = req.body;

  if (!customerId) {
    return res.status(400).json({
      success: false,
      message: 'Vui lòng cung cấp mã định danh khách hàng (customerId)',
    });
  }

  // Validate UUID v4
  const uuidRegex = /^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$/;
  if (!uuidRegex.test(customerId)) {
    return res.status(400).json({
      success: false,
      message: 'Định dạng mã khách hàng không hợp lệ (phải là UUID)',
    });
  }

  try {
    // 1. Kiểm tra khách hàng tồn tại trong hệ thống
    const custRes = await query(
      `SELECT c.id, c.customer_code, c.full_name, c.phone_number, c.address_text, c.area_id, a.name as area_name
       FROM customers c
       JOIN areas a ON a.id = c.area_id
       WHERE c.id = $1`,
      [customerId]
    );

    if (custRes.rows.length === 0) {
      return res.status(404).json({
        success: false,
        message: 'Không tìm thấy thông tin khách hàng trong hệ thống',
      });
    }

    const customer = custRes.rows[0];

    // 2. Kiểm tra phân quyền khu vực của shipper
    if (req.user?.roleName === 'SHIPPER') {
      const assigned = req.user.assignedAreaIds || [];
      if (!assigned.includes(customer.area_id)) {
        return res.status(403).json({
          success: false,
          message: 'Khách hàng này thuộc khu vực bạn không được phân công phụ trách',
        });
      }
    }

    // 3. Logic chống trùng: Kiểm tra đơn PENDING đã có trong ca của shipper
    const existingOrderRes = await query(
      `SELECT
        o.id as order_id,
        o.order_code,
        o.status as order_status,
        o.created_at as order_created_at,
        c.id as customer_id,
        c.customer_code,
        c.full_name as customer_name,
        c.phone_number as customer_phone,
        c.address_text as customer_address,
        a.id as area_id,
        a.name as area_name,
        sl.id as saved_location_id,
        sl.latitude,
        sl.longitude,
        sl.gps_accuracy,
        sl.identification_notes,
        sl.image_url,
        sl.updated_at as location_updated_at
       FROM orders o
       JOIN customers c ON c.id = o.customer_id
       JOIN areas a ON a.id = o.area_id
       LEFT JOIN saved_locations sl ON sl.customer_id = c.id
       WHERE o.shipper_id = $1 AND o.customer_id = $2 AND o.status = 'PENDING'
       ORDER BY o.created_at DESC
       LIMIT 1`,
      [shipperId, customerId]
    );

    if (existingOrderRes.rows.length > 0 && !allowMultiple) {
      return res.status(200).json({
        success: true,
        isExisting: true,
        message: 'Khách hàng đã có đơn hàng trong ca giao hiện tại',
        data: formatOrderRow(existingOrderRes.rows[0]),
      });
    }

    // 4. Kiểm tra Idempotency Key để chống tạo đơn trùng khi nhấn liên tục
    if (idempotencyKey) {
      const recentAudit = await query(
        `SELECT entity_id FROM audit_logs
         WHERE user_id = $1 AND action = 'CREATE_ORDER' AND details->>'idempotencyKey' = $2
         LIMIT 1`,
        [shipperId, idempotencyKey]
      );
      if (recentAudit.rows.length > 0) {
        const dupOrderRes = await query(
          `SELECT
            o.id as order_id,
            o.order_code,
            o.status as order_status,
            o.created_at as order_created_at,
            c.id as customer_id,
            c.customer_code,
            c.full_name as customer_name,
            c.phone_number as customer_phone,
            c.address_text as customer_address,
            a.id as area_id,
            a.name as area_name,
            sl.id as saved_location_id,
            sl.latitude,
            sl.longitude,
            sl.gps_accuracy,
            sl.identification_notes,
            sl.image_url,
            sl.updated_at as location_updated_at
           FROM orders o
           JOIN customers c ON c.id = o.customer_id
           JOIN areas a ON a.id = o.area_id
           LEFT JOIN saved_locations sl ON sl.customer_id = c.id
           WHERE o.id = $1`,
          [recentAudit.rows[0].entity_id]
        );
        if (dupOrderRes.rows.length > 0) {
          return res.status(200).json({
            success: true,
            isExisting: true,
            message: 'Yêu cầu lặp lại: Đơn hàng đã được tạo trước đó',
            data: formatOrderRow(dupOrderRes.rows[0]),
          });
        }
      }
    }

    // 5. Khởi tạo đơn mới trong Database Transaction an toàn
    const client = await pool.connect();
    try {
      await client.query('BEGIN');

      const today = new Date().toISOString().slice(0, 10).replace(/-/g, '');
      const randomSuffix = Math.random().toString(36).substring(2, 7).toUpperCase();
      const orderCode = `ORD-${today}-${randomSuffix}`;

      const insertRes = await client.query(
        `INSERT INTO orders (order_code, customer_id, shipper_id, area_id, status)
         VALUES ($1, $2, $3, $4, 'PENDING')
         RETURNING id`,
        [orderCode, customerId, shipperId, customer.area_id]
      );

      const newOrderId = insertRes.rows[0].id;

      // Ghi audit log
      const auditDetails = {
        orderCode,
        customerId,
        areaId: customer.area_id,
        shipperId,
        idempotencyKey: idempotencyKey || null,
        createdVia: 'MOBILE_SEARCH_ADD_POINT',
      };

      await client.query(
        `INSERT INTO audit_logs (user_id, action, entity, entity_id, details, ip_address)
         VALUES ($1, 'CREATE_ORDER', 'orders', $2, $3, $4)`,
        [shipperId, newOrderId, JSON.stringify(auditDetails), req.ip || null]
      );

      await client.query('COMMIT');

      // 6. Truy vấn dữ liệu đơn hoàn chỉnh để trả về
      const completeOrderRes = await query(
        `SELECT
          o.id as order_id,
          o.order_code,
          o.status as order_status,
          o.created_at as order_created_at,
          c.id as customer_id,
          c.customer_code,
          c.full_name as customer_name,
          c.phone_number as customer_phone,
          c.address_text as customer_address,
          a.id as area_id,
          a.name as area_name,
          sl.id as saved_location_id,
          sl.latitude,
          sl.longitude,
          sl.gps_accuracy,
          sl.identification_notes,
          sl.image_url,
          sl.updated_at as location_updated_at
         FROM orders o
         JOIN customers c ON c.id = o.customer_id
         JOIN areas a ON a.id = o.area_id
         LEFT JOIN saved_locations sl ON sl.customer_id = c.id
         WHERE o.id = $1`,
        [newOrderId]
      );

      return res.status(201).json({
        success: true,
        isExisting: false,
        message: 'Thêm điểm giao vào ca thành công',
        data: formatOrderRow(completeOrderRes.rows[0]),
      });
    } catch (dbErr: any) {
      await client.query('ROLLBACK');
      throw dbErr;
    } finally {
      client.release();
    }
  } catch (error: any) {
    return res.status(500).json({
      success: false,
      message: 'Lỗi thêm điểm giao vào ca',
      error: error.message,
    });
  }
};
