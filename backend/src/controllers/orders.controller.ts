import { Response } from 'express';
import { AuthenticatedRequest } from '../middlewares/auth.middleware';
import { query } from '../db';

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

    const formattedOrders = ordersRes.rows.map((row) => ({
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
    }));

    return res.json({
      success: true,
      data: formattedOrders,
    });
  } catch (error: any) {
    return res.status(500).json({ success: false, message: 'Lỗi lấy danh sách đơn hàng', error: error.message });
  }
};
