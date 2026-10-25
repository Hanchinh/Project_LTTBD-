process.env.NODE_ENV = 'test';
process.env.DB_NAME = 'test_isolated_seed_db';
process.env.IS_INTEGRATION_TEST = 'true';

import fs from 'fs';
import path from 'path';
import { PassThrough } from 'stream';
import { Pool } from 'pg';
import { pool, query, ISOLATED_TEST_DB_NAME } from '../src/db';
import { setupIsolatedTestDatabase } from '../scripts/setup-test-db';
import {
  getCustomerPhotos,
  addCustomerPhoto,
  deleteCustomerPhoto,
} from '../src/controllers/customer-photos.controller';
import {
  servePhoto,
  getMySavedLocations,
  lookupCustomerByPhone,
} from '../src/controllers/locations.controller';
import { getShiftDetail } from '../src/controllers/shifts.controller';
import { checkCustomerAreaScope } from '../src/middlewares/area.middleware';

describe('TASK: MULTI-PHOTO-AND-THUMB-UI-015A - Multi-Photo & Thumb Integration Tests', () => {
  let testPool: Pool;

  const SHIPPER_A_ID = 'd0000000-0000-0000-0000-000000000001'; // Shipper A (Area 1)
  const SHIPPER_B_ID = 'd0000000-0000-0000-0000-000000000002'; // Shipper B (Area 2)
  const ADMIN_ID = 'a0000000-0000-0000-0000-000000000001';
  const AREA_1_ID = 'b0000000-0000-0000-0000-000000000001';
  const AREA_2_ID = 'b0000000-0000-0000-0000-000000000002';
  const CUSTOMER_1_ID = 'c0000000-0000-0000-0000-000000000001'; // In Area 1
  let testShiftId: string;

  // Minimal valid image buffers
  const jpegBuffer = Buffer.from([0xff, 0xd8, 0xff, 0xe0, 0x00, 0x10, 0x4a, 0x46, 0x49, 0x46, 0x00, 0x01, 0x01, 0x01, 0x00, 0x48, 0x00, 0x48, 0x00, 0x00, 0xff, 0xd9]);
  const pngBuffer = Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 0x00, 0x00, 0x00, 0x0d, 0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x06, 0x00, 0x00, 0x00, 0x1f, 0x15, 0xc4, 0x89]);
  const webpBuffer = Buffer.from([0x52, 0x49, 0x46, 0x46, 0x18, 0x00, 0x00, 0x00, 0x57, 0x45, 0x42, 0x50, 0x56, 0x50, 0x38, 0x20, 0x0c, 0x00, 0x00, 0x00, 0x30, 0x01, 0x00, 0x9d, 0x01, 0x2a, 0x01, 0x00, 0x01, 0x00, 0x02, 0x00]);

  const jpegBase64 = `data:image/jpeg;base64,${jpegBuffer.toString('base64')}`;
  const pngBase64 = `data:image/png;base64,${pngBuffer.toString('base64')}`;
  const webpBase64 = `data:image/webp;base64,${webpBuffer.toString('base64')}`;

  beforeAll(async () => {
    await setupIsolatedTestDatabase();

    testPool = new Pool({
      host: process.env.DB_HOST || 'localhost',
      port: parseInt(process.env.DB_PORT || '5432'),
      database: ISOLATED_TEST_DB_NAME,
      user: process.env.DB_USER || 'postgres',
      password: process.env.DB_PASSWORD || 'postgres',
    });

    // Create a test shift for getShiftDetail test
    const shiftRes = await testPool.query(
      `INSERT INTO shifts (shift_code, work_date, shipper_id, status)
       VALUES ($1, CURRENT_DATE, $2, 'PREPARING')
       RETURNING id`,
      [`SHF-015-${Date.now()}`, SHIPPER_A_ID]
    );
    testShiftId = shiftRes.rows[0].id;

    await testPool.query(
      `INSERT INTO shift_delivery_points (shift_id, customer_id, location_status)
       VALUES ($1, $2, 'VERIFIED')`,
      [testShiftId, CUSTOMER_1_ID]
    );
  });

  afterAll(async () => {
    if (testPool) {
      await testPool.end();
    }
    await pool.end();
  });

  const createMockResponse = () => {
    const res: any = new PassThrough();
    res.statusCode = 200;
    res.headers = {};
    res.status = jest.fn((code: number) => {
      res.statusCode = code;
      return res;
    });
    res.json = jest.fn((data: any) => {
      res.body = data;
      return res;
    });
    res.setHeader = jest.fn((name: string, value: string) => {
      res.headers[name] = value;
      return res;
    });
    return res;
  };

  describe('1. Migration Idempotency', () => {
    it('Chạy lại migration 06-create-customer-photos.sql không nhân đôi ảnh cũ', async () => {
      const countBefore = await query('SELECT COUNT(*)::int as count FROM customer_photos');
      const numBefore = countBefore.rows[0].count;
      expect(numBefore).toBeGreaterThanOrEqual(1);

      // Run migration 06 again
      const migrationSql = fs.readFileSync(
        path.resolve(__dirname, '../../init-db/06-create-customer-photos.sql'),
        'utf8'
      );
      await query(migrationSql);

      const countAfter = await query('SELECT COUNT(*)::int as count FROM customer_photos');
      const numAfter = countAfter.rows[0].count;

      expect(numAfter).toBe(numBefore);
    });
  });

  describe('2. Thêm ảnh và kiểm tra giới hạn', () => {
    it('Thêm 3 ảnh hợp lệ (JPEG, PNG, WEBP) cho khách hàng thành công và ghi audit_logs ADD_PHOTO', async () => {
      // Clear photos for customer 1 first for clean state
      await query('DELETE FROM customer_photos WHERE customer_id = $1', [CUSTOMER_1_ID]);

      const formats = [jpegBase64, pngBase64, webpBase64];
      for (let i = 0; i < formats.length; i++) {
        const req: any = {
          params: { customerId: CUSTOMER_1_ID },
          body: { imageBase64: formats[i] },
          user: {
            userId: SHIPPER_A_ID,
            roleName: 'SHIPPER',
            assignedAreaIds: [AREA_1_ID],
          },
        };
        const res = createMockResponse();
        await addCustomerPhoto(req, res);

        expect(res.statusCode).toBe(201);
        expect(res.body.success).toBe(true);
        expect(res.body.data.id).toBeDefined();
        expect(res.body.data.imageUrl).toBeDefined();
        expect(res.body.data.customerId).toBe(CUSTOMER_1_ID);
      }

      // Check DB customer_photos
      const dbPhotos = await query(
        'SELECT * FROM customer_photos WHERE customer_id = $1 AND deleted_at IS NULL ORDER BY created_at DESC',
        [CUSTOMER_1_ID]
      );
      expect(dbPhotos.rows.length).toBe(3);

      // Check audit_logs
      const audit = await query(
        "SELECT * FROM audit_logs WHERE action = 'ADD_PHOTO' AND details->>'customerId' = $1",
        [CUSTOMER_1_ID]
      );
      expect(audit.rows.length).toBe(3);
    });

    it('Vượt giới hạn 10 ảnh: cố tình thêm ảnh thứ 11 trả về lỗi 400', async () => {
      // Currently has 3 photos, add 7 more to reach 10
      for (let i = 4; i <= 10; i++) {
        const req: any = {
          params: { customerId: CUSTOMER_1_ID },
          body: { imageBase64: jpegBase64 },
          user: {
            userId: SHIPPER_A_ID,
            roleName: 'SHIPPER',
            assignedAreaIds: [AREA_1_ID],
          },
        };
        const res = createMockResponse();
        await addCustomerPhoto(req, res);
        expect(res.statusCode).toBe(201);
      }

      // Try 11th photo
      const req11: any = {
        params: { customerId: CUSTOMER_1_ID },
        body: { imageBase64: jpegBase64 },
        user: {
          userId: SHIPPER_A_ID,
          roleName: 'SHIPPER',
          assignedAreaIds: [AREA_1_ID],
        },
      };
      const res11 = createMockResponse();
      await addCustomerPhoto(req11, res11);

      expect(res11.statusCode).toBe(400);
      expect(res11.body.success).toBe(false);
      expect(res11.body.message).toContain('tối đa 10 ảnh');
    });

    it('Sai định dạng MIME: gửi payload không phải jpg/png/webp trả về lỗi 400', async () => {
      const invalidBuffer = Buffer.from('PDF_OR_TEXT_INVALID_MAGIC_BYTES_12345');
      const invalidBase64 = `data:text/plain;base64,${invalidBuffer.toString('base64')}`;

      const req: any = {
        params: { customerId: CUSTOMER_1_ID },
        body: { imageBase64: invalidBase64 },
        user: {
          userId: SHIPPER_A_ID,
          roleName: 'SHIPPER',
          assignedAreaIds: [AREA_1_ID],
        },
      };
      const res = createMockResponse();
      await addCustomerPhoto(req, res);

      expect(res.statusCode).toBe(400);
      expect(res.body.success).toBe(false);
      expect(res.body.message).toContain('Định dạng ảnh không hợp lệ');
    });

    it('Quá dung lượng 5MB: gửi payload vượt 5MB trả về lỗi 400', async () => {
      // 5.2MB buffer
      const hugeBuffer = Buffer.alloc(5.2 * 1024 * 1024);
      hugeBuffer[0] = 0xff;
      hugeBuffer[1] = 0xd8;
      hugeBuffer[2] = 0xff;
      const hugeBase64 = `data:image/jpeg;base64,${hugeBuffer.toString('base64')}`;

      const req: any = {
        params: { customerId: CUSTOMER_1_ID },
        body: { imageBase64: hugeBase64 },
        user: {
          userId: SHIPPER_A_ID,
          roleName: 'SHIPPER',
          assignedAreaIds: [AREA_1_ID],
        },
      };
      const res = createMockResponse();
      await addCustomerPhoto(req, res);

      expect(res.statusCode).toBe(400);
      expect(res.body.success).toBe(false);
      expect(res.body.message).toContain('5MB');
    });
  });

  describe('3. Xóa mềm (Soft Delete) và Quyền hạn', () => {
    it('Xóa mềm thành công bởi shipper đã tải lên, không xóa file vật lý trên đĩa, ghi audit_logs', async () => {
      // Pick one photo uploaded by SHIPPER_A
      const photoRow = await query(
        'SELECT * FROM customer_photos WHERE customer_id = $1 AND created_by = $2 AND deleted_at IS NULL LIMIT 1',
        [CUSTOMER_1_ID, SHIPPER_A_ID]
      );
      expect(photoRow.rows.length).toBe(1);
      const photo = photoRow.rows[0];

      const req: any = {
        params: {
          customerId: CUSTOMER_1_ID,
          photoId: photo.id,
        },
        user: {
          userId: SHIPPER_A_ID,
          roleName: 'SHIPPER',
          assignedAreaIds: [AREA_1_ID],
        },
      };
      const res = createMockResponse();
      await deleteCustomerPhoto(req, res);

      expect(res.statusCode).toBe(200);
      expect(res.body.success).toBe(true);

      // Verify DB: deleted_at IS NOT NULL
      const checkDb = await query('SELECT * FROM customer_photos WHERE id = $1', [photo.id]);
      expect(checkDb.rows[0].deleted_at).not.toBeNull();

      // Check physical file still exists on disk
      const filename = path.basename(photo.image_url);
      const filePath = path.join(process.cwd(), 'uploads', 'photos', filename);
      expect(fs.existsSync(filePath)).toBe(true);

      // Verify audit log
      const audit = await query(
        "SELECT * FROM audit_logs WHERE action = 'DELETE_PHOTO' AND details->>'customerId' = $1",
        [CUSTOMER_1_ID]
      );
      expect(audit.rows.length).toBeGreaterThanOrEqual(1);
    });

    it('Shipper khác cố tình xóa ảnh do Shipper A tải bị chặn 403', async () => {
      const photoRow = await query(
        'SELECT * FROM customer_photos WHERE customer_id = $1 AND created_by = $2 AND deleted_at IS NULL LIMIT 1',
        [CUSTOMER_1_ID, SHIPPER_A_ID]
      );
      expect(photoRow.rows.length).toBe(1);
      const photo = photoRow.rows[0];

      // Shipper B tries to delete Shipper A's photo
      const req: any = {
        params: {
          customerId: CUSTOMER_1_ID,
          photoId: photo.id,
        },
        user: {
          userId: SHIPPER_B_ID,
          roleName: 'SHIPPER',
          assignedAreaIds: [AREA_1_ID, AREA_2_ID], // even if in area
        },
      };
      const res = createMockResponse();
      await deleteCustomerPhoto(req, res);

      expect(res.statusCode).toBe(403);
      expect(res.body.success).toBe(false);
      expect(res.body.message).toContain('người khác');
    });

    it('ADMIN có quyền xóa mềm ảnh của bất kỳ ai', async () => {
      const photoRow = await query(
        'SELECT * FROM customer_photos WHERE customer_id = $1 AND created_by = $2 AND deleted_at IS NULL LIMIT 1',
        [CUSTOMER_1_ID, SHIPPER_A_ID]
      );
      expect(photoRow.rows.length).toBe(1);
      const photo = photoRow.rows[0];

      const req: any = {
        params: {
          customerId: CUSTOMER_1_ID,
          photoId: photo.id,
        },
        user: {
          userId: ADMIN_ID,
          roleName: 'ADMIN',
          assignedAreaIds: [],
        },
      };
      const res = createMockResponse();
      await deleteCustomerPhoto(req, res);

      expect(res.statusCode).toBe(200);
      expect(res.body.success).toBe(true);
    });
  });

  describe('4. Phân quyền khu vực (checkCustomerAreaScope) và servePhoto', () => {
    it('Shipper khác khu vực gọi checkCustomerAreaScope bị 403', async () => {
      const req: any = {
        params: { customerId: CUSTOMER_1_ID }, // Customer 1 is in Area 1
        user: {
          userId: SHIPPER_B_ID,
          roleName: 'SHIPPER',
          assignedAreaIds: [AREA_2_ID], // Only Area 2
        },
      };
      const res = createMockResponse();
      let nextCalled = false;
      const next = () => { nextCalled = true; };

      await checkCustomerAreaScope(req, res, next);

      expect(res.statusCode).toBe(403);
      expect(res.body.success).toBe(false);
      expect(nextCalled).toBe(false);
    });

    it('servePhoto trả về 200 cho ảnh còn hiệu lực của khách hàng trong khu vực', async () => {
      const photoRow = await query(
        'SELECT * FROM customer_photos WHERE customer_id = $1 AND deleted_at IS NULL LIMIT 1',
        [CUSTOMER_1_ID]
      );
      expect(photoRow.rows.length).toBe(1);
      const filename = path.basename(photoRow.rows[0].image_url);

      const req: any = {
        params: { filename },
        user: {
          userId: SHIPPER_A_ID,
          roleName: 'SHIPPER',
          assignedAreaIds: [AREA_1_ID],
        },
      };
      const res = createMockResponse();
      await servePhoto(req, res);

      expect(res.statusCode).toBe(200);
      expect(res.headers['Cache-Control']).toContain('private, no-store');
    });

    it('servePhoto chấp nhận tên file có tiền tố cust-photo- và trả về 200', async () => {
      const custPhotoFilename = 'cust-photo-00000000-0000-0000-0000-000000000001.jpg';
      const custPhotoPath = path.join(process.cwd(), 'uploads', 'photos', custPhotoFilename);
      // Create test dummy file
      fs.writeFileSync(custPhotoPath, Buffer.from([0xFF, 0xD8, 0xFF, 0xDB]));

      // Link to customer 1 in database
      await query(
        `INSERT INTO customer_photos (customer_id, image_url, created_by)
         VALUES ($1, $2, $3)`,
        [CUSTOMER_1_ID, `/api/v1/photos/${custPhotoFilename}`, SHIPPER_A_ID]
      );

      const req: any = {
        params: { filename: custPhotoFilename },
        user: {
          userId: SHIPPER_A_ID,
          roleName: 'SHIPPER',
          assignedAreaIds: [AREA_1_ID],
        },
      };
      const res = createMockResponse();
      await servePhoto(req, res);

      expect(res.statusCode).toBe(200);
      expect(res.headers['Content-Type']).toBe('image/jpeg');

      // Cleanup
      if (fs.existsSync(custPhotoPath)) {
        fs.unlinkSync(custPhotoPath);
      }
    });

    it('servePhoto trả về 403 cho ảnh hợp lệ nhưng ngoài khu vực phân công của shipper', async () => {
      const photoRow = await query(
        'SELECT * FROM customer_photos WHERE customer_id = $1 AND deleted_at IS NULL LIMIT 1',
        [CUSTOMER_1_ID]
      );
      const filename = path.basename(photoRow.rows[0].image_url);

      const req: any = {
        params: { filename },
        user: {
          userId: SHIPPER_B_ID,
          roleName: 'SHIPPER',
          assignedAreaIds: [AREA_2_ID], // Only Area 2
        },
      };
      const res = createMockResponse();
      await servePhoto(req, res);

      expect(res.statusCode).toBe(403);
      expect(res.body.success).toBe(false);
    });

    it('servePhoto trả về 404 cho ảnh đã xóa mềm (nếu không còn reference hợp lệ nào khác)', async () => {
      // First find a soft deleted photo
      const softDelRow = await query(
        'SELECT * FROM customer_photos WHERE customer_id = $1 AND deleted_at IS NOT NULL LIMIT 1',
        [CUSTOMER_1_ID]
      );
      expect(softDelRow.rows.length).toBe(1);
      const filename = path.basename(softDelRow.rows[0].image_url);

      // Ensure no saved_locations or shift_delivery_points reference this filename
      await query("UPDATE saved_locations SET image_url = NULL WHERE image_url LIKE '%' || $1", [filename]);
      await query("UPDATE location_history SET image_url = NULL WHERE image_url LIKE '%' || $1", [filename]);
      await query("UPDATE shift_delivery_points SET image_url = NULL WHERE image_url LIKE '%' || $1", [filename]);

      const req: any = {
        params: { filename },
        user: {
          userId: SHIPPER_A_ID,
          roleName: 'SHIPPER',
          assignedAreaIds: [AREA_1_ID],
        },
      };
      const res = createMockResponse();
      await servePhoto(req, res);

      expect(res.statusCode).toBe(404);
      expect(res.body.success).toBe(false);
    });

    it('servePhoto chặn tấn công path traversal với mã 400', async () => {
      const req: any = {
        params: { filename: '../../etc/passwd' },
        user: {
          userId: SHIPPER_A_ID,
          roleName: 'SHIPPER',
          assignedAreaIds: [AREA_1_ID],
        },
      };
      const res = createMockResponse();
      await servePhoto(req, res);

      expect(res.statusCode).toBe(400);
      expect(res.body.message).toContain('không hợp lệ');
    });
  });

  describe('5. Các API trả điểm trả về photoCount và mảng photos (tối đa 3 ảnh)', () => {
    it('getCustomerPhotos trả danh sách ảnh mới nhất trước', async () => {
      const req: any = {
        params: { customerId: CUSTOMER_1_ID },
        user: {
          userId: SHIPPER_A_ID,
          roleName: 'SHIPPER',
          assignedAreaIds: [AREA_1_ID],
        },
      };
      const res = createMockResponse();
      await getCustomerPhotos(req, res);

      expect(res.statusCode).toBe(200);
      expect(res.body.success).toBe(true);
      expect(Array.isArray(res.body.data)).toBe(true);
      expect(res.body.data.length).toBeGreaterThanOrEqual(1);

      // Dates sorted descending
      const photos = res.body.data;
      for (let i = 0; i < photos.length - 1; i++) {
        const d1 = new Date(photos[i].createdAt).getTime();
        const d2 = new Date(photos[i + 1].createdAt).getTime();
        expect(d1).toBeGreaterThanOrEqual(d2);
      }
    });

    it('getMySavedLocations trả photoCount và photos (tối đa 3)', async () => {
      const req: any = {
        user: {
          userId: SHIPPER_A_ID,
          roleName: 'SHIPPER',
          assignedAreaIds: [AREA_1_ID],
        },
      };
      const res = createMockResponse();
      await getMySavedLocations(req, res);

      expect(res.statusCode).toBe(200);
      const points = res.body.data;
      const point1 = points.find((p: any) => p.customerId === CUSTOMER_1_ID);
      expect(point1).toBeDefined();
      expect(point1.photoCount).toBeGreaterThanOrEqual(1);
      expect(Array.isArray(point1.photos)).toBe(true);
      expect(point1.photos.length).toBeLessThanOrEqual(3);
    });

    it('lookupCustomerByPhone trả photoCount và photos', async () => {
      const req: any = {
        params: { phoneNumber: '0988000001' },
        user: {
          userId: SHIPPER_A_ID,
          roleName: 'SHIPPER',
          assignedAreaIds: [AREA_1_ID],
        },
      };
      const res = createMockResponse();
      await lookupCustomerByPhone(req, res);

      expect(res.statusCode).toBe(200);
      expect(res.body.data.photoCount).toBeGreaterThanOrEqual(1);
      expect(Array.isArray(res.body.data.photos)).toBe(true);
      expect(res.body.data.photos.length).toBeLessThanOrEqual(3);
      if (res.body.data.location) {
        expect(res.body.data.location.photoCount).toBeGreaterThanOrEqual(1);
        expect(Array.isArray(res.body.data.location.photos)).toBe(true);
      }
    });

    it('getShiftDetail trả photoCount và photos cho từng điểm giao', async () => {
      const req: any = {
        params: { id: testShiftId },
        user: {
          userId: SHIPPER_A_ID,
          roleName: 'SHIPPER',
          assignedAreaIds: [AREA_1_ID],
        },
      };
      const res = createMockResponse();
      await getShiftDetail(req, res);

      expect(res.statusCode).toBe(200);
      const points = res.body.data.points;
      expect(Array.isArray(points)).toBe(true);
      expect(points.length).toBeGreaterThanOrEqual(1);
      for (const p of points) {
        expect(typeof p.photoCount).toBe('number');
        expect(Array.isArray(p.photos)).toBe(true);
        expect(p.photos.length).toBeLessThanOrEqual(3);
      }
    });
  });
});
