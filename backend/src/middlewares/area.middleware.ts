import { Response, NextFunction } from 'express';
import { AuthenticatedRequest } from './auth.middleware';
import { query } from '../db';

export const checkCustomerAreaScope = async (req: AuthenticatedRequest, res: Response, next: NextFunction) => {
  if (!req.user) {
    return res.status(401).json({ success: false, message: 'Chưa đăng nhập' });
  }

  // Admin has access to all areas
  if (req.user.roleName === 'ADMIN') {
    return next();
  }

  const customerId = req.params.customerId || req.body.customerId;
  if (!customerId) {
    return res.status(400).json({ success: false, message: 'Thiếu ID khách hàng' });
  }

  try {
    const custResult = await query('SELECT area_id FROM customers WHERE id = $1', [customerId]);
    if (custResult.rows.length === 0) {
      return res.status(404).json({ success: false, message: 'Không tìm thấy khách hàng' });
    }

    const customerAreaId = custResult.rows[0].area_id;

    if (!req.user.assignedAreaIds || !req.user.assignedAreaIds.includes(customerAreaId)) {
      return res.status(403).json({
        success: false,
        message: 'Khách hàng này không thuộc khu vực bạn được phân công phụ trách',
      });
    }

    next();
  } catch (error: any) {
    return res.status(500).json({ success: false, message: 'Lỗi kiểm tra quyền khu vực', error: error.message });
  }
};
