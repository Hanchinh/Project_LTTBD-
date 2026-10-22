import bcrypt from 'bcrypt';
import fs from 'fs';
import path from 'path';
import { Request, Response } from 'express';
import { login } from '../src/controllers/auth.controller';
import * as db from '../src/db';

// Mock the database layer to test controller responses in isolation
jest.mock('../src/db', () => ({
  query: jest.fn(),
  pool: { query: jest.fn() },
}));

describe('Authentication & Password Verification Security Tests', () => {
  const DEFAULT_TEST_PASSWORD = 'password123';
  const SEED_HASH = '$2b$10$gtZVjpsj7RCMMyj2TbODL.RvTuTF/cO0BCsFhSLiCZkt/jCJdqMC.';

  describe('1. Bcrypt Cryptographic Verification Logic', () => {
    // Test Case 1: Mật khẩu hợp lệ khớp với hash Bcrypt
    it('should successfully verify when password matches valid bcrypt hash', async () => {
      const password = 'my_secure_password_2026';
      const saltRounds = 10;
      const hash = await bcrypt.hash(password, saltRounds);

      const isMatch = await bcrypt.compare(password, hash);
      expect(isMatch).toBe(true);
    });

    // Test Case 2: Mật khẩu sai bị từ chối
    it('should reject verification when password does not match bcrypt hash', async () => {
      const correctPassword = 'my_secure_password_2026';
      const wrongPassword = 'wrong_password_attempt';
      const hash = await bcrypt.hash(correctPassword, 10);

      const isMatch = await bcrypt.compare(wrongPassword, hash);
      expect(isMatch).toBe(false);
    });

    // Test Case 3: Chống hồi quy - Không cho phép dùng password123 để bypass tài khoản có mật khẩu khác
    it('should strictly reject "password123" when user has a different password hash', async () => {
      const userCustomPassword = 'custom_driver_password_xyz';
      const customHash = await bcrypt.hash(userCustomPassword, 10);

      // Attempting to bypass using the hardcoded "password123"
      const isMatch = await bcrypt.compare(DEFAULT_TEST_PASSWORD, customHash);
      expect(isMatch).toBe(false);
    });

    // Test Case 4: Xác minh tính hợp lệ của hash mẫu trong seed script
    it('should verify that seed data hash correctly resolves default test password', () => {
      // 1. Check known seed hash constant
      const isValid = bcrypt.compareSync(DEFAULT_TEST_PASSWORD, SEED_HASH);
      expect(isValid).toBe(true);

      // 2. Read 01-init-db.sql directly and verify the hashes in the seed file
      const sqlFilePath = path.resolve(__dirname, '../../init-db/01-init-db.sql');
      expect(fs.existsSync(sqlFilePath)).toBe(true);

      const sqlContent = fs.readFileSync(sqlFilePath, 'utf-8');
      const hashMatches = sqlContent.match(/\$2b\$10\$[A-Za-z0-9./]{53}/g);

      expect(hashMatches).not.toBeNull();
      expect(hashMatches!.length).toBeGreaterThanOrEqual(3);

      for (const hash of hashMatches!) {
        const matchesDefault = bcrypt.compareSync(DEFAULT_TEST_PASSWORD, hash);
        expect(matchesDefault).toBe(true);
      }
    });
  });

  describe('2. Auth Controller Login Endpoint Security & Regression', () => {
    let mockReq: Partial<Request>;
    let mockRes: Partial<Response>;
    let statusMock: jest.Mock;
    let jsonMock: jest.Mock;

    beforeEach(() => {
      jsonMock = jest.fn();
      statusMock = jest.fn().mockReturnValue({ json: jsonMock });
      mockRes = {
        status: statusMock,
        json: jsonMock,
      };
      jest.clearAllMocks();
    });

    it('should return 401 when user enters wrong password (AC-3)', async () => {
      const validHash = await bcrypt.hash('correct_password_456', 10);

      // Mock user found in DB with a custom password hash
      (db.query as jest.Mock).mockResolvedValueOnce({
        rows: [
          {
            id: 'u001',
            full_name: 'Test Driver',
            phone_number: '0901234567',
            password_hash: validHash,
            role_id: 2,
            role_name: 'SHIPPER',
            is_active: true,
          },
        ],
      });

      mockReq = {
        body: {
          phoneNumber: '0901234567',
          password: 'definitely_wrong_password',
        },
      };

      await login(mockReq as Request, mockRes as Response);

      expect(statusMock).toHaveBeenCalledWith(401);
      expect(jsonMock).toHaveBeenCalledWith({
        success: false,
        message: 'Số điện thoại hoặc mật khẩu không chính xác',
      });
    });

    it('should strictly return 401 when attempting to bypass with "password123" on an account with different password (AC-4)', async () => {
      const differentPasswordHash = await bcrypt.hash('my_super_secret_password_789', 10);

      (db.query as jest.Mock).mockResolvedValueOnce({
        rows: [
          {
            id: 'admin-001',
            full_name: 'System Admin',
            phone_number: '0900000001',
            password_hash: differentPasswordHash,
            role_id: 1,
            role_name: 'ADMIN',
            is_active: true,
          },
        ],
      });

      // Attacker tries to use "password123" backdoor
      mockReq = {
        body: {
          phoneNumber: '0900000001',
          password: 'password123',
        },
      };

      await login(mockReq as Request, mockRes as Response);

      expect(statusMock).toHaveBeenCalledWith(401);
      expect(jsonMock).toHaveBeenCalledWith({
        success: false,
        message: 'Số điện thoại hoặc mật khẩu không chính xác',
      });
    });

    it('should return 403 when user account is inactive', async () => {
      const validHash = await bcrypt.hash('password123', 10);

      (db.query as jest.Mock).mockResolvedValueOnce({
        rows: [
          {
            id: 'u002',
            full_name: 'Locked Driver',
            phone_number: '0909999999',
            password_hash: validHash,
            role_id: 2,
            role_name: 'SHIPPER',
            is_active: false,
          },
        ],
      });

      mockReq = {
        body: {
          phoneNumber: '0909999999',
          password: 'password123',
        },
      };

      await login(mockReq as Request, mockRes as Response);

      expect(statusMock).toHaveBeenCalledWith(403);
      expect(jsonMock).toHaveBeenCalledWith({
        success: false,
        message: 'Tài khoản của bạn đã bị khóa',
      });
    });

    it('should successfully log in with valid credentials matching seed hash', async () => {
      // Mock user found with valid seed hash
      (db.query as jest.Mock)
        .mockResolvedValueOnce({
          rows: [
            {
              id: 's0000000-0000-0000-0000-000000000001',
              full_name: 'Trần Văn Giao (Shipper A)',
              phone_number: '0901111111',
              password_hash: SEED_HASH,
              role_id: 2,
              role_name: 'SHIPPER',
              is_active: true,
            },
          ],
        })
        // Mock assigned areas
        .mockResolvedValueOnce({
          rows: [{ area_id: 'a0000000-0000-0000-0000-000000000001' }],
        })
        // Mock audit log insert
        .mockResolvedValueOnce({ rows: [] });

      mockReq = {
        body: {
          phoneNumber: '0901111111',
          password: 'password123',
        },
        ip: '127.0.0.1',
      };

      await login(mockReq as Request, mockRes as Response);

      expect(jsonMock).toHaveBeenCalledWith(
        expect.objectContaining({
          success: true,
          message: 'Đăng nhập thành công',
          data: expect.objectContaining({
            token: expect.any(String),
            user: expect.objectContaining({
              phoneNumber: '0901111111',
              role: 'SHIPPER',
            }),
          }),
        })
      );
    });
  });
});
