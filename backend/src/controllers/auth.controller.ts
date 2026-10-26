import { Request, Response } from 'express';
import bcrypt from 'bcrypt';
import jwt from 'jsonwebtoken';
import { query } from '../db';
import { AuthenticatedRequest } from '../middlewares/auth.middleware';

export const login = async (req: Request, res: Response) => {
  const { phoneNumber, password } = req.body;

  if (!phoneNumber || !password) {
    return res.status(400).json({ success: false, message: 'Vui lòng nhập Số điện thoại và Mật khẩu' });
  }

  try {
    const userRes = await query(
      `SELECT u.id, u.full_name, u.phone_number, u.password_hash, u.role_id, u.is_active, r.name as role_name 
       FROM users u 
       JOIN roles r ON r.id = u.role_id 
       WHERE u.phone_number = $1`,
      [phoneNumber]
    );

    if (userRes.rows.length === 0) {
      return res.status(401).json({ success: false, message: 'Số điện thoại hoặc mật khẩu không chính xác' });
    }

    const user = userRes.rows[0];

    if (!user.is_active) {
      return res.status(403).json({ success: false, message: 'Tài khoản của bạn đã bị khóa' });
    }

    // Passwords match check using Bcrypt
    const isMatch = await bcrypt.compare(password, user.password_hash);

    if (!isMatch) {
      return res.status(401).json({ success: false, message: 'Số điện thoại hoặc mật khẩu không chính xác' });
    }

    // Get assigned area IDs
    const areasRes = await query(
      `SELECT area_id FROM user_areas WHERE user_id = $1`,
      [user.id]
    );
    const assignedAreaIds = areasRes.rows.map((row) => row.area_id);

    const payload = {
      userId: user.id,
      fullName: user.full_name,
      phoneNumber: user.phone_number,
      roleId: user.role_id,
      roleName: user.role_name,
      assignedAreaIds,
    };

    const token = jwt.sign(payload, process.env.JWT_SECRET || 'super_secret_delivery_jwt_key_2026_xyz', {
      expiresIn: '7d',
    });

    // Audit log
    await query(
      `INSERT INTO audit_logs (user_id, action, entity, details) VALUES ($1, $2, $3, $4)`,
      [user.id, 'LOGIN', 'USER', JSON.stringify({ ip: req.ip })]
    );

    return res.json({
      success: true,
      message: 'Đăng nhập thành công',
      data: {
        token,
        user: {
          id: user.id,
          fullName: user.full_name,
          phoneNumber: user.phone_number,
          role: user.role_name,
          assignedAreaIds,
        },
      },
    });
  } catch (error: any) {
    return res.status(500).json({ success: false, message: 'Lỗi server khi đăng nhập', error: error.message });
  }
};

/**
 * Thống kê của tôi (TASK: ACCOUNT-PROFILE-AND-LOGIN-REDESIGN-022B)
 * GET /api/v1/auth/me/stats
 * Chỉ tính dữ liệu của chính người dùng đang đăng nhập:
 * - savedLocationsCount: số vị trí đã lưu (created_by hoặc updated_by)
 * - createdShiftsCount: số ca đã tạo (shipper_id)
 * - uploadedPhotosCount: số ảnh đã tải (created_by và deleted_at IS NULL)
 */
export const getMyStats = async (req: AuthenticatedRequest, res: Response) => {
  const userId = req.user?.userId;

  if (!userId) {
    return res.status(401).json({ success: false, message: 'Chưa xác thực người dùng' });
  }

  try {
    // 1. Số vị trí đã lưu
    const savedLocRes = await query(
      `SELECT COUNT(*)::int as count 
       FROM saved_locations 
       WHERE created_by = $1 OR updated_by = $1`,
      [userId]
    );
    const savedLocationsCount = savedLocRes.rows[0]?.count ?? 0;

    // 2. Số ca đã tạo
    const shiftsRes = await query(
      `SELECT COUNT(*)::int as count 
       FROM shifts 
       WHERE shipper_id = $1`,
      [userId]
    );
    const createdShiftsCount = shiftsRes.rows[0]?.count ?? 0;

    // 3. Số ảnh đã tải lên
    const photosRes = await query(
      `SELECT COUNT(*)::int as count 
       FROM customer_photos 
       WHERE created_by = $1 AND deleted_at IS NULL`,
      [userId]
    );
    const uploadedPhotosCount = photosRes.rows[0]?.count ?? 0;

    return res.status(200).json({
      success: true,
      data: {
        savedLocationsCount,
        createdShiftsCount,
        uploadedPhotosCount,
      },
    });
  } catch (error: any) {
    return res.status(500).json({
      success: false,
      message: 'Lỗi server khi lấy thống kê cá nhân',
      error: error.message,
    });
  }
};

// Quản lý giới hạn thử sai mật khẩu: tối đa 5 lần trong 15 phút theo userId
const failedPasswordAttempts = new Map<string, number[]>();
const RATE_LIMIT_WINDOW_MS = 15 * 60 * 1000; // 15 phút
const MAX_FAILED_ATTEMPTS = 5;

/**
 * Hàm helper hỗ trợ kiểm thử reset bộ đếm giới hạn thử sai
 */
export const _clearPasswordRateLimits = (userId?: string) => {
  if (userId) {
    failedPasswordAttempts.delete(userId);
  } else {
    failedPasswordAttempts.clear();
  }
};

/**
 * Đổi mật khẩu tài khoản (TASK: ACCOUNT-PROFILE-AND-LOGIN-REDESIGN-022B)
 * POST /api/v1/auth/change-password
 * Body: { currentPassword, newPassword, confirmPassword? }
 */
export const changePassword = async (req: AuthenticatedRequest, res: Response) => {
  const userId = req.user?.userId;

  if (!userId) {
    return res.status(401).json({ success: false, message: 'Chưa xác thực người dùng' });
  }

  const { currentPassword, newPassword, confirmPassword } = req.body;

  if (!currentPassword || !newPassword) {
    return res.status(400).json({
      success: false,
      message: 'Vui lòng cung cấp mật khẩu hiện tại và mật khẩu mới',
    });
  }

  if (confirmPassword !== undefined && confirmPassword !== newPassword) {
    return res.status(400).json({
      success: false,
      message: 'Mật khẩu xác nhận không khớp với mật khẩu mới',
    });
  }

  if (typeof newPassword !== 'string' || newPassword.length < 8) {
    return res.status(400).json({
      success: false,
      message: 'Mật khẩu mới phải có ít nhất 8 ký tự',
    });
  }

  // 1. Kiểm tra giới hạn số lần thử sai (Rate limiting: 5 lần/15 phút)
  const now = Date.now();
  const currentAttempts = (failedPasswordAttempts.get(userId) || []).filter(
    (timestamp) => now - timestamp < RATE_LIMIT_WINDOW_MS
  );

  if (currentAttempts.length >= MAX_FAILED_ATTEMPTS) {
    return res.status(429).json({
      success: false,
      message: 'Bạn đã nhập sai mật khẩu quá 5 lần. Vui lòng thử lại sau 15 phút.',
    });
  }

  try {
    const userRes = await query(
      `SELECT id, password_hash FROM users WHERE id = $1`,
      [userId]
    );

    if (userRes.rows.length === 0) {
      return res.status(404).json({ success: false, message: 'Không tìm thấy tài khoản người dùng' });
    }

    const user = userRes.rows[0];

    // 2. Xác thực mật khẩu hiện tại bằng bcrypt
    const isCurrentMatch = await bcrypt.compare(currentPassword, user.password_hash);
    if (!isCurrentMatch) {
      currentAttempts.push(now);
      failedPasswordAttempts.set(userId, currentAttempts);
      const remaining = MAX_FAILED_ATTEMPTS - currentAttempts.length;

      return res.status(400).json({
        success: false,
        message: remaining > 0
            ? `Mật khẩu hiện tại không chính xác. Bạn còn ${remaining} lần thử.`
            : 'Mật khẩu hiện tại không chính xác. Bạn đã thử quá số lần cho phép (5 lần). Vui lòng thử lại sau 15 phút.',
        remainingAttempts: Math.max(0, remaining),
      });
    }

    // 3. Mật khẩu mới không được trùng mật khẩu cũ
    const isSamePassword = await bcrypt.compare(newPassword, user.password_hash);
    if (isSamePassword) {
      return res.status(400).json({
        success: false,
        message: 'Mật khẩu mới không được trùng với mật khẩu hiện tại',
      });
    }

    // 4. Băm mật khẩu mới bằng bcrypt salt 10
    const salt = await bcrypt.genSalt(10);
    const newHash = await bcrypt.hash(newPassword, salt);

    // 5. Cập nhật vào CSDL
    await query(
      `UPDATE users SET password_hash = $1 WHERE id = $2`,
      [newHash, userId]
    );

    // Xóa bộ đếm thử sai khi đổi thành công
    failedPasswordAttempts.delete(userId);

    // 6. Ghi audit log (BẢO MẬT: TUYỆT ĐỐI KHÔNG GHI MẬT KHẨU HOẶC HASH)
    const ipAddress = (req.headers['x-forwarded-for'] as string) || req.socket.remoteAddress || req.ip || null;
    await query(
      `INSERT INTO audit_logs (user_id, action, entity, entity_id, details, ip_address) 
       VALUES ($1, $2, $3, $4, $5, $6)`,
      [
        userId,
        'PASSWORD_CHANGE',
        'USER',
        userId,
        JSON.stringify({
          action: 'Đổi mật khẩu người dùng thành công',
          changedAt: new Date().toISOString(),
        }),
        ipAddress,
      ]
    );

    return res.status(200).json({
      success: true,
      message: 'Đổi mật khẩu thành công. Vui lòng sử dụng mật khẩu mới cho các lần đăng nhập tiếp theo.',
    });
  } catch (error: any) {
    return res.status(500).json({
      success: false,
      message: 'Lỗi server khi đổi mật khẩu',
      error: error.message,
    });
  }
};
