import { Response } from 'express';
import { AuthenticatedRequest } from '../middlewares/auth.middleware';
import { query } from '../db';

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
  const { latitude, longitude, gpsAccuracy, identificationNotes } = req.body;
  const userId = req.user?.userId;

  if (latitude === undefined || longitude === undefined || !identificationNotes) {
    return res.status(400).json({
      success: false,
      message: 'Vui lòng cung cấp đầy đủ latitude, longitude và ghi chú nhận diện',
    });
  }

  try {
    // Check if location exists
    const existing = await query('SELECT id FROM saved_locations WHERE customer_id = $1', [customerId]);

    let resultLocationId = '';

    if (existing.rows.length === 0) {
      // Create new location
      const insertRes = await query(
        `INSERT INTO saved_locations 
         (customer_id, geom, latitude, longitude, gps_accuracy, identification_notes, created_by, updated_by)
         VALUES 
         ($1, ST_SetSRID(ST_MakePoint($3, $2), 4326), $2, $3, $4, $5, $6, $6)
         RETURNING id`,
        [customerId, latitude, longitude, gpsAccuracy || 0, identificationNotes, userId]
      );
      resultLocationId = insertRes.rows[0].id;
    } else {
      // Update existing location (Trigger automatically writes to location_history)
      const updateRes = await query(
        `UPDATE saved_locations 
         SET geom = ST_SetSRID(ST_MakePoint($3, $2), 4326),
             latitude = $2,
             longitude = $3,
             gps_accuracy = $4,
             identification_notes = $5,
             updated_by = $6,
             updated_at = CURRENT_TIMESTAMP
         WHERE customer_id = $1
         RETURNING id`,
        [customerId, latitude, longitude, gpsAccuracy || 0, identificationNotes, userId]
      );
      resultLocationId = updateRes.rows[0].id;
    }

    // Write audit log
    await query(
      `INSERT INTO audit_logs (user_id, action, entity, entity_id, details) VALUES ($1, $2, $3, $4, $5)`,
      [
        userId,
        existing.rows.length === 0 ? 'CREATE_LOCATION' : 'UPDATE_LOCATION',
        'SAVED_LOCATION',
        resultLocationId,
        JSON.stringify({ customerId, latitude, longitude, gpsAccuracy, notes: identificationNotes }),
      ]
    );

    return res.json({
      success: true,
      message: existing.rows.length === 0 ? 'Lưu vị trí khách hàng thành công' : 'Cập nhật vị trí khách hàng thành công',
      data: {
        locationId: resultLocationId,
        customerId,
        latitude,
        longitude,
        gpsAccuracy,
        identificationNotes,
      },
    });
  } catch (error: any) {
    return res.status(500).json({ success: false, message: 'Lỗi lưu vị trí khách hàng', error: error.message });
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
        changeReason: r.change_reason,
        createdAt: r.created_at,
        changedBy: r.changed_by_name,
      })),
    });
  } catch (error: any) {
    return res.status(500).json({ success: false, message: 'Lỗi lấy lịch sử vị trí', error: error.message });
  }
};
