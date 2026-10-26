process.env.NODE_ENV = 'test';
process.env.DB_NAME = 'test_isolated_seed_db';
process.env.IS_INTEGRATION_TEST = 'true';

import { Pool } from 'pg';
import bcrypt from 'bcrypt';
import { ISOLATED_TEST_DB_NAME } from '../src/db';
import { setupIsolatedTestDatabase } from '../scripts/setup-test-db';
import { getMyStats, changePassword, login, _clearPasswordRateLimits } from '../src/controllers/auth.controller';

describe('TASK: ACCOUNT-PROFILE-AND-LOGIN-REDESIGN-022B - Backend Auth Profile & Change Password Integration Tests', () => {
  let testPool: Pool;

  const SHIPPER_A_ID = 'd0000000-0000-0000-0000-000000000001'; // Shipper A (0901111111)
  const SHIPPER_A_PHONE = '0901111111';
  const SHIPPER_B_ID = 'd0000000-0000-0000-0000-000000000002'; // Shipper B (0908333167)
  const INITIAL_PASSWORD = 'password123';

  const createMockResponse = () => {
    const res: any = {};
    res.statusCode = 200;
    res.status = jest.fn((code: number) => {
      res.statusCode = code;
      return res;
    });
    res.json = jest.fn((data: any) => {
      res.body = data;
      return res;
    });
    return res;
  };

  beforeAll(async () => {
    await setupIsolatedTestDatabase();

    testPool = new Pool({
      host: process.env.DB_HOST || 'localhost',
      port: parseInt(process.env.DB_PORT || '5432'),
      database: ISOLATED_TEST_DB_NAME,
      user: process.env.DB_USER || 'postgres',
      password: process.env.DB_PASSWORD || 'postgres',
    });
    testPool.on('error', () => {});

    // Tạo Shipper B nếu chưa có trong DB
    const hash = await bcrypt.hash(INITIAL_PASSWORD, 10);
    await testPool.query(
      `INSERT INTO users (id, full_name, phone_number, password_hash, role_id, is_active)
       VALUES ($1, 'Shipper B Test', '0908333167', $2, 2, true)
       ON CONFLICT (id) DO UPDATE SET password_hash = $2`,
      [SHIPPER_B_ID, hash]
    );

    // Gán lại mật khẩu gốc cho Shipper A
    await testPool.query(
      `UPDATE users SET password_hash = $1 WHERE id = $2`,
      [hash, SHIPPER_A_ID]
    );
  });

  afterAll(async () => {
    await testPool.end();
  });

  beforeEach(() => {
    _clearPasswordRateLimits();
  });

  describe('1. GET /api/v1/auth/me/stats - Thống kê chỉ của chính người dùng', () => {
    it('chỉ đếm đúng số vị trí đã lưu, số ca đã tạo và số ảnh đã tải của chính shipper', async () => {
      // 1. Tạo dữ liệu cho Shipper A
      // Tạo 1 ca làm việc cho Shipper A
      await testPool.query(
        `INSERT INTO shifts (id, shift_code, work_date, shipper_id, status)
         VALUES ('a0000000-0000-0000-0000-000000000001', 'SHF-TEST-A1', CURRENT_DATE, $1, 'COMPLETED')
         ON CONFLICT (id) DO NOTHING`,
        [SHIPPER_A_ID]
      );
      // Tạo 1 ca làm việc cho Shipper B
      await testPool.query(
        `INSERT INTO shifts (id, shift_code, work_date, shipper_id, status)
         VALUES ('a0000000-0000-0000-0000-000000000002', 'SHF-TEST-B1', CURRENT_DATE, $1, 'COMPLETED')
         ON CONFLICT (id) DO NOTHING`,
        [SHIPPER_B_ID]
      );

      // Tạo 1 ảnh cho Shipper A
      const customerRes = await testPool.query(`SELECT id FROM customers LIMIT 1`);
      const customerId = customerRes.rows[0].id;

      await testPool.query(
        `INSERT INTO customer_photos (id, customer_id, image_url, created_by)
         VALUES ('e0000000-0000-0000-0000-000000000001', $1, 'http://test.com/photoA.jpg', $2)
         ON CONFLICT (id) DO NOTHING`,
        [customerId, SHIPPER_A_ID]
      );

      // Tạo 1 ảnh cho Shipper B
      await testPool.query(
        `INSERT INTO customer_photos (id, customer_id, image_url, created_by)
         VALUES ('e0000000-0000-0000-0000-000000000002', $1, 'http://test.com/photoB.jpg', $2)
         ON CONFLICT (id) DO NOTHING`,
        [customerId, SHIPPER_B_ID]
      );

      // Gọi getMyStats cho Shipper A
      const reqA: any = {
        user: {
          userId: SHIPPER_A_ID,
          roleName: 'SHIPPER',
        },
      };
      const resA = createMockResponse();
      await getMyStats(reqA, resA);

      expect(resA.statusCode).toBe(200);
      expect(resA.body.success).toBe(true);
      expect(resA.body.data).toBeDefined();

      const statsA = resA.body.data;
      expect(statsA.createdShiftsCount).toBe(1);
      expect(statsA.uploadedPhotosCount).toBeGreaterThanOrEqual(1);

      // Gọi getMyStats cho Shipper B
      const reqB: any = {
        user: {
          userId: SHIPPER_B_ID,
          roleName: 'SHIPPER',
        },
      };
      const resB = createMockResponse();
      await getMyStats(reqB, resB);

      expect(resB.statusCode).toBe(200);
      expect(resB.body.success).toBe(true);
      const statsB = resB.body.data;
      expect(statsB.createdShiftsCount).toBe(1);
      expect(statsB.uploadedPhotosCount).toBe(1);
    });

    it('từ chối 401 khi không có thông tin xác thực', async () => {
      const req: any = {};
      const res = createMockResponse();
      await getMyStats(req, res);

      expect(res.statusCode).toBe(401);
      expect(res.body.success).toBe(false);
    });
  });

  describe('2. POST /api/v1/auth/change-password - Nghiệp vụ & Bảo mật Đổi mật khẩu', () => {
    it('từ chối khi thiếu mật khẩu hiện tại hoặc mật khẩu mới', async () => {
      const req: any = {
        user: { userId: SHIPPER_A_ID },
        body: { currentPassword: '' },
      };
      const res = createMockResponse();
      await changePassword(req, res);

      expect(res.statusCode).toBe(400);
      expect(res.body.message).toContain('Vui lòng cung cấp');
    });

    it('từ chối khi mật khẩu mới dưới 8 ký tự', async () => {
      const req: any = {
        user: { userId: SHIPPER_A_ID },
        body: {
          currentPassword: INITIAL_PASSWORD,
          newPassword: 'short',
        },
      };
      const res = createMockResponse();
      await changePassword(req, res);

      expect(res.statusCode).toBe(400);
      expect(res.body.message).toContain('ít nhất 8 ký tự');
    });

    it('từ chối khi mật khẩu xác nhận không khớp', async () => {
      const req: any = {
        user: { userId: SHIPPER_A_ID },
        body: {
          currentPassword: INITIAL_PASSWORD,
          newPassword: 'newValidPassword123',
          confirmPassword: 'differentPassword456',
        },
      };
      const res = createMockResponse();
      await changePassword(req, res);

      expect(res.statusCode).toBe(400);
      expect(res.body.message).toContain('không khớp');
    });

    it('từ chối khi nhập sai mật khẩu hiện tại và giảm số lần thử còn lại', async () => {
      const req: any = {
        user: { userId: SHIPPER_A_ID },
        body: {
          currentPassword: 'wrong_password_xyz',
          newPassword: 'newValidPassword123',
        },
      };
      const res = createMockResponse();
      await changePassword(req, res);

      expect(res.statusCode).toBe(400);
      expect(res.body.success).toBe(false);
      expect(res.body.message).toContain('không chính xác');
      expect(res.body.remainingAttempts).toBe(4);
    });

    it('kích hoạt Rate Limiting (429) sau 5 lần nhập sai trong 15 phút', async () => {
      const req: any = {
        user: { userId: SHIPPER_A_ID },
        body: {
          currentPassword: 'wrong_password_test',
          newPassword: 'newValidPassword123',
        },
      };

      // Thử sai 5 lần
      for (let i = 1; i <= 5; i++) {
        const res = createMockResponse();
        await changePassword(req, res);
        expect(res.statusCode).toBe(400);
      }

      // Lần thứ 6 phải trả về 429 Too Many Requests
      const resBlocked = createMockResponse();
      await changePassword(req, resBlocked);
      expect(resBlocked.statusCode).toBe(429);
      expect(resBlocked.body.message).toContain('quá 5 lần');
    });

    it('từ chối khi mật khẩu mới trùng với mật khẩu cũ', async () => {
      _clearPasswordRateLimits(SHIPPER_A_ID);

      const req: any = {
        user: { userId: SHIPPER_A_ID },
        body: {
          currentPassword: INITIAL_PASSWORD,
          newPassword: INITIAL_PASSWORD, // Trùng
        },
      };
      const res = createMockResponse();
      await changePassword(req, res);

      expect(res.statusCode).toBe(400);
      expect(res.body.message).toContain('không được trùng');
    });

    it('đổi mật khẩu thành công: băm Bcrypt, đăng nhập được bằng mật khẩu mới và ghi audit_logs không lộ mật khẩu', async () => {
      _clearPasswordRateLimits(SHIPPER_A_ID);
      const NEW_PASSWORD = 'superSecretShipper2026!';

      const req: any = {
        user: { userId: SHIPPER_A_ID },
        headers: { 'x-forwarded-for': '127.0.0.1' },
        body: {
          currentPassword: INITIAL_PASSWORD,
          newPassword: NEW_PASSWORD,
          confirmPassword: NEW_PASSWORD,
        },
      };
      const res = createMockResponse();
      await changePassword(req, res);

      expect(res.statusCode).toBe(200);
      expect(res.body.success).toBe(true);

      // 1. Kiểm tra CSDL: hash đã đổi và khớp với NEW_PASSWORD
      const userRes = await testPool.query(`SELECT password_hash FROM users WHERE id = $1`, [SHIPPER_A_ID]);
      const newHash = userRes.rows[0].password_hash;
      expect(await bcrypt.compare(NEW_PASSWORD, newHash)).toBe(true);
      expect(await bcrypt.compare(INITIAL_PASSWORD, newHash)).toBe(false);

      // 2. Kiểm tra đăng nhập với mật khẩu mới thành công
      const loginReq: any = {
        body: {
          phoneNumber: SHIPPER_A_PHONE,
          password: NEW_PASSWORD,
        },
      };
      const loginRes = createMockResponse();
      await login(loginReq, loginRes);
      expect(loginRes.statusCode).toBe(200);
      expect(loginRes.body.success).toBe(true);
      expect(loginRes.body.data.token).toBeDefined();

      // 3. Đăng nhập với mật khẩu cũ thất bại
      const oldLoginReq: any = {
        body: {
          phoneNumber: SHIPPER_A_PHONE,
          password: INITIAL_PASSWORD,
        },
      };
      const oldLoginRes = createMockResponse();
      await login(oldLoginReq, oldLoginRes);
      expect(oldLoginRes.statusCode).toBe(401);

      // 4. Kiểm tra audit_logs: TUYỆT ĐỐI KHÔNG CHỨA MẬT KHẨU HOẶC HASH
      const auditRes = await testPool.query(
        `SELECT action, entity, details FROM audit_logs 
         WHERE user_id = $1 AND action = 'PASSWORD_CHANGE' 
         ORDER BY created_at DESC LIMIT 1`,
        [SHIPPER_A_ID]
      );
      expect(auditRes.rows.length).toBe(1);
      const auditRow = auditRes.rows[0];
      expect(auditRow.action).toBe('PASSWORD_CHANGE');
      expect(auditRow.entity).toBe('USER');

      const detailsStr = JSON.stringify(auditRow.details);
      expect(detailsStr).not.toContain(INITIAL_PASSWORD);
      expect(detailsStr).not.toContain(NEW_PASSWORD);
      expect(detailsStr).not.toContain(newHash);
    });
  });
});
