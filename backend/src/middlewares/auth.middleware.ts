import { Request, Response, NextFunction } from 'express';
import jwt from 'jsonwebtoken';

export interface UserPayload {
  userId: string;
  fullName: string;
  phoneNumber: string;
  roleId: number;
  roleName: string;
  assignedAreaIds: string[];
}

export interface AuthenticatedRequest extends Request {
  user?: UserPayload;
}

export const authenticateJwt = (req: AuthenticatedRequest, res: Response, next: NextFunction) => {
  let token: string | undefined;

  const authHeader = req.headers.authorization;
  if (authHeader && authHeader.startsWith('Bearer ')) {
    token = authHeader.split(' ')[1];
  } else if (req.query && req.query.token && typeof req.query.token === 'string') {
    token = req.query.token;
  }

  if (!token) {
    return res.status(401).json({ success: false, message: 'Thiếu hoặc sai định dạng Token xác thực' });
  }

  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET || 'super_secret_delivery_jwt_key_2026_xyz') as UserPayload;
    req.user = decoded;
    next();
  } catch (error) {
    return res.status(401).json({ success: false, message: 'Token không hợp lệ hoặc đã hết hạn' });
  }
};

export const requireRoles = (...allowedRoles: string[]) => {
  return (req: AuthenticatedRequest, res: Response, next: NextFunction) => {
    if (!req.user) {
      return res.status(401).json({ success: false, message: 'Chưa đăng nhập' });
    }

    if (!allowedRoles.includes(req.user.roleName)) {
      return res.status(403).json({ success: false, message: 'Bạn không có quyền thực hiện chức năng này' });
    }

    next();
  };
};
