import { Response } from 'express';
import { AuthenticatedRequest } from '../middlewares/auth.middleware';
import { query } from '../db';
import bcrypt from 'bcrypt';

// AREAS MANAGEMENT
export const getAreas = async (req: AuthenticatedRequest, res: Response) => {
  try {
    const result = await query('SELECT id, code, name, created_at FROM areas ORDER BY created_at DESC');
    return res.json({ success: true, data: result.rows });
  } catch (error: any) {
    return res.status(500).json({ success: false, message: 'Lỗi lấy danh sách khu vực', error: error.message });
  }
};

export const createArea = async (req: AuthenticatedRequest, res: Response) => {
  const { code, name } = req.body;
  if (!code || !name) {
    return res.status(400).json({ success: false, message: 'Vui lòng cung cấp mã và tên khu vực' });
  }

  try {
    const result = await query('INSERT INTO areas (code, name) VALUES ($1, $2) RETURNING *', [code, name]);
    return res.json({ success: true, message: 'Tạo khu vực thành công', data: result.rows[0] });
  } catch (error: any) {
    return res.status(500).json({ success: false, message: 'Lỗi tạo khu vực', error: error.message });
  }
};

// USERS & SHIPPERS MANAGEMENT
export const getUsers = async (req: AuthenticatedRequest, res: Response) => {
  try {
    const usersRes = await query(
      `SELECT 
        u.id, u.full_name, u.phone_number, u.is_active, u.created_at, r.name as role_name,
        COALESCE(
          json_agg(json_build_object('id', a.id, 'name', a.name, 'code', a.code)) FILTER (WHERE a.id IS NOT NULL), '[]'
        ) as assigned_areas
       FROM users u
       JOIN roles r ON r.id = u.role_id
       LEFT JOIN user_areas ua ON ua.user_id = u.id
       LEFT JOIN areas a ON a.id = ua.area_id
       GROUP BY u.id, r.name
       ORDER BY u.created_at DESC`
    );

    return res.json({ success: true, data: usersRes.rows });
  } catch (error: any) {
    return res.status(500).json({ success: false, message: 'Lỗi lấy danh sách người dùng', error: error.message });
  }
};

export const createUser = async (req: AuthenticatedRequest, res: Response) => {
  const { fullName, phoneNumber, password, roleId, areaIds } = req.body;

  if (!fullName || !phoneNumber || !password || !roleId) {
    return res.status(400).json({ success: false, message: 'Thiếu thông tin người dùng bắt buộc' });
  }

  try {
    const salt = await bcrypt.genSalt(10);
    const passwordHash = await bcrypt.hash(password, salt);

    const userRes = await query(
      `INSERT INTO users (full_name, phone_number, password_hash, role_id) VALUES ($1, $2, $3, $4) RETURNING id, full_name, phone_number`,
      [fullName, phoneNumber, passwordHash, roleId]
    );

    const newUser = userRes.rows[0];

    if (areaIds && Array.isArray(areaIds) && areaIds.length > 0) {
      for (const areaId of areaIds) {
        await query(`INSERT INTO user_areas (user_id, area_id) VALUES ($1, $2)`, [newUser.id, areaId]);
      }
    }

    return res.json({ success: true, message: 'Tạo tài khoản người dùng thành công', data: newUser });
  } catch (error: any) {
    return res.status(500).json({ success: false, message: 'Lỗi tạo người dùng', error: error.message });
  }
};

export const assignUserAreas = async (req: AuthenticatedRequest, res: Response) => {
  const { userId } = req.params;
  const { areaIds } = req.body; // Array of area UUIDs

  if (!Array.isArray(areaIds)) {
    return res.status(400).json({ success: false, message: 'areaIds phải là một mảng' });
  }

  try {
    // Clear old assignments
    await query('DELETE FROM user_areas WHERE user_id = $1', [userId]);

    // Insert new assignments
    for (const areaId of areaIds) {
      await query('INSERT INTO user_areas (user_id, area_id) VALUES ($1, $2)', [userId, areaId]);
    }

    return res.json({ success: true, message: 'Gán khu vực cho shipper thành công' });
  } catch (error: any) {
    return res.status(500).json({ success: false, message: 'Lỗi gán khu vực', error: error.message });
  }
};

// LOCATIONS MANAGEMENT & SEARCH
export const getAllLocations = async (req: AuthenticatedRequest, res: Response) => {
  const { areaId, search } = req.query;

  try {
    let queryText = `
      SELECT 
        sl.id as location_id,
        sl.latitude,
        sl.longitude,
        sl.gps_accuracy,
        sl.identification_notes,
        sl.created_at,
        sl.updated_at,
        c.id as customer_id,
        c.customer_code,
        c.full_name as customer_name,
        c.phone_number as customer_phone,
        c.address_text,
        a.id as area_id,
        a.name as area_name,
        u.full_name as updated_by_name
      FROM saved_locations sl
      JOIN customers c ON c.id = sl.customer_id
      JOIN areas a ON a.id = c.area_id
      LEFT JOIN users u ON u.id = sl.updated_by
      WHERE 1=1
    `;

    const queryParams: any[] = [];

    if (areaId) {
      queryParams.push(areaId);
      queryText += ` AND c.area_id = $${queryParams.length}`;
    }

    if (search) {
      queryParams.push(`%${search}%`);
      queryText += ` AND (c.full_name ILIKE $${queryParams.length} OR c.phone_number ILIKE $${queryParams.length} OR c.customer_code ILIKE $${queryParams.length} OR sl.identification_notes ILIKE $${queryParams.length})`;
    }

    queryText += ` ORDER BY sl.updated_at DESC`;

    const result = await query(queryText, queryParams);

    return res.json({
      success: true,
      data: result.rows.map((row) => ({
        locationId: row.location_id,
        customer: {
          id: row.customer_id,
          code: row.customer_code,
          name: row.customer_name,
          phone: row.customer_phone,
          address: row.address_text,
        },
        area: {
          id: row.area_id,
          name: row.area_name,
        },
        latitude: parseFloat(row.latitude),
        longitude: parseFloat(row.longitude),
        gpsAccuracy: parseFloat(row.gps_accuracy),
        identificationNotes: row.identification_notes,
        updatedBy: row.updated_by_name,
        updatedAt: row.updated_at,
      })),
    });
  } catch (error: any) {
    return res.status(500).json({ success: false, message: 'Lỗi lấy danh sách vị trí', error: error.message });
  }
};

export const deleteLocation = async (req: AuthenticatedRequest, res: Response) => {
  const { locationId } = req.params;
  const userId = req.user?.userId;

  try {
    await query('DELETE FROM saved_locations WHERE id = $1', [locationId]);
    await query(
      'INSERT INTO audit_logs (user_id, action, entity, entity_id) VALUES ($1, $2, $3, $4)',
      [userId, 'DELETE_LOCATION', 'SAVED_LOCATION', locationId]
    );

    return res.json({ success: true, message: 'Xóa vị trí khách hàng thành công' });
  } catch (error: any) {
    return res.status(500).json({ success: false, message: 'Lỗi xóa vị trí', error: error.message });
  }
};

// COVERAGE STATS
export const getLocationCoverageStats = async (req: AuthenticatedRequest, res: Response) => {
  try {
    const result = await query(
      `SELECT 
        a.id as area_id,
        a.code as area_code,
        a.name as area_name,
        COUNT(c.id) as total_customers,
        COUNT(sl.id) as saved_locations_count,
        ROUND(
          CASE WHEN COUNT(c.id) > 0 
               THEN (COUNT(sl.id)::decimal / COUNT(c.id)::decimal) * 100 
               ELSE 0 
          END, 2
        ) as coverage_percentage
       FROM areas a
       LEFT JOIN customers c ON c.area_id = a.id
       LEFT JOIN saved_locations sl ON sl.customer_id = c.id
       GROUP BY a.id, a.code, a.name
       ORDER BY a.name ASC`
    );

    return res.json({
      success: true,
      data: result.rows.map((row) => ({
        areaId: row.area_id,
        areaCode: row.area_code,
        areaName: row.area_name,
        totalCustomers: parseInt(row.total_customers),
        savedLocationsCount: parseInt(row.saved_locations_count),
        coveragePercentage: parseFloat(row.coverage_percentage),
      })),
    });
  } catch (error: any) {
    return res.status(500).json({ success: false, message: 'Lỗi tính toán thống kê phủ vị trí', error: error.message });
  }
};

// AUDIT LOGS
export const getAuditLogs = async (req: AuthenticatedRequest, res: Response) => {
  try {
    const result = await query(
      `SELECT 
        al.id,
        al.action,
        al.entity,
        al.entity_id,
        al.details,
        al.ip_address,
        al.created_at,
        u.full_name as user_name,
        u.phone_number as user_phone
       FROM audit_logs al
       LEFT JOIN users u ON u.id = al.user_id
       ORDER BY al.created_at DESC
       LIMIT 100`
    );

    return res.json({ success: true, data: result.rows });
  } catch (error: any) {
    return res.status(500).json({ success: false, message: 'Lỗi lấy nhật ký hệ thống', error: error.message });
  }
};
