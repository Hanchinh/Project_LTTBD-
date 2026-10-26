process.env.NODE_ENV = 'test';
process.env.DB_NAME = 'test_isolated_seed_db';
process.env.IS_INTEGRATION_TEST = 'true';

import { Pool } from 'pg';
import path from 'path';
import fs from 'fs';
import { PassThrough } from 'stream';
import { ISOLATED_TEST_DB_NAME, pool } from '../src/db';
import { setupIsolatedTestDatabase } from '../scripts/setup-test-db';
import {
  createShare,
  getIncomingShares,
  getOutgoingShares,
  acceptShare,
  declineShare,
  revokeShare,
  getSharedLocations,
  importSharedLocations,
} from '../src/controllers/shares.controller';
import { servePhoto, getMySavedLocations } from '../src/controllers/locations.controller';

describe('TASK: DATA-SHARING-BETWEEN-SHIPPERS-023 - Backend Integration Tests', () => {
  let testPool: Pool;

  const SHIPPER_A_ID = 'd0000000-0000-0000-0000-000000000001';
  const SHIPPER_A_PHONE = '0901111111';
  const SHIPPER_B_ID = 'd0000000-0000-0000-0000-000000000002';
  const SHIPPER_B_PHONE = '0902222222';
  const SHIPPER_C_ID = 'd0000000-0000-0000-0000-000000000003';
  const SHIPPER_C_PHONE = '0903333333';
  const ADMIN_ID = 'a0000000-0000-0000-0000-000000000001';

  const AREA_1_ID = 'b0000000-0000-0000-0000-000000000001'; // Area 1: Long Thạnh Mỹ
  const AREA_2_ID = 'b0000000-0000-0000-0000-000000000002'; // Area 2: Tân Phú

  const CUSTOMER_1_ID = 'c0000000-0000-0000-0000-000000000001'; // In Area 1
  const CUSTOMER_4_ID = 'c0000000-0000-0000-0000-000000000004'; // In Area 2

  let testPhotoFilename = '00000000-0000-0000-0000-000000000001.jpg';
  let dummyPhotoPath = '';

  const createMockResponse = () => {
    const res: any = new PassThrough();
    res.statusCode = 200;
    res.headers = {};
    res.setHeader = jest.fn((key: string, val: string) => {
      res.headers[key] = val;
    });
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
    // 1. Setup isolated test DB running all migrations 01 - 08
    await setupIsolatedTestDatabase();

    testPool = new Pool({
      host: process.env.DB_HOST || 'localhost',
      port: parseInt(process.env.DB_PORT || '5432'),
      database: ISOLATED_TEST_DB_NAME,
      user: process.env.DB_USER || 'postgres',
      password: process.env.DB_PASSWORD || 'postgres',
    });
    testPool.on('error', () => {});

    // Ensure Shipper C exists
    await testPool.query(
      `INSERT INTO users (id, full_name, phone_number, password_hash, role_id, is_active)
       VALUES ($1, 'Shipper C Test', $2, '$2b$10$gtZVjpsj7RCMMyj2TbODL.RvTuTF/cO0BCsFhSLiCZkt/jCJdqMC.', 2, true)
       ON CONFLICT (id) DO NOTHING`,
      [SHIPPER_C_ID, SHIPPER_C_PHONE]
    );

    // Create dummy photo file on disk for servePhoto tests
    const uploadsDir = path.join(process.cwd(), 'uploads', 'photos');
    if (!fs.existsSync(uploadsDir)) {
      fs.mkdirSync(uploadsDir, { recursive: true });
    }
    dummyPhotoPath = path.join(uploadsDir, testPhotoFilename);
    if (!fs.existsSync(dummyPhotoPath)) {
      fs.writeFileSync(dummyPhotoPath, Buffer.from([0xff, 0xd8, 0xff, 0xe0, 0x00, 0x10, 0x4a, 0x46]));
    }
  });

  afterAll(async () => {
    if (testPool) {
      await testPool.end();
    }
    await pool.end();
  });

  describe('1. POST /api/v1/shares - Tạo lời mời chia sẻ & Bảo mật số điện thoại', () => {
    it('từ chối tự chia sẻ cho chính mình và trả thông báo chung không lộ tài khoản', async () => {
      const req: any = {
        user: { userId: SHIPPER_A_ID, roleName: 'SHIPPER', assignedAreaIds: [AREA_1_ID] },
        body: {
          recipientPhone: SHIPPER_A_PHONE,
          scope: 'ALL_POINTS',
          includePhotos: true,
        },
      };
      const res = createMockResponse();
      await createShare(req, res);

      expect(res.statusCode).toBe(400);
      expect(res.body.success).toBe(false);
      expect(res.body.message).toBe('Không gửi được lời mời, kiểm tra số điện thoại');
    });

    it('từ chối số điện thoại không tồn tại với thông báo chung (không lộ B có tồn tại hay không)', async () => {
      const req: any = {
        user: { userId: SHIPPER_A_ID, roleName: 'SHIPPER', assignedAreaIds: [AREA_1_ID] },
        body: {
          recipientPhone: '0999888777', // Does not exist
          scope: 'ALL_POINTS',
          includePhotos: true,
        },
      };
      const res = createMockResponse();
      await createShare(req, res);

      expect(res.statusCode).toBe(400);
      expect(res.body.success).toBe(false);
      expect(res.body.message).toBe('Không gửi được lời mời, kiểm tra số điện thoại');
    });

    it('từ chối khi chia sẻ ca không thuộc quyền quản lý của shipper', async () => {
      const req: any = {
        user: { userId: SHIPPER_A_ID, roleName: 'SHIPPER', assignedAreaIds: [AREA_1_ID] },
        body: {
          recipientPhone: SHIPPER_B_PHONE,
          scope: 'SHIFT',
          shiftId: '00000000-0000-0000-0000-000000000099', // Not owned
          includePhotos: true,
        },
      };
      const res = createMockResponse();
      await createShare(req, res);

      expect(res.statusCode).toBe(400);
      expect(res.body.success).toBe(false);
      expect(res.body.message).toContain('không thuộc quyền quản lý');
    });

    it('gửi lời mời hợp lệ thành công và ghi audit_log không chứa dữ liệu khách', async () => {
      const req: any = {
        user: { userId: SHIPPER_A_ID, roleName: 'SHIPPER', assignedAreaIds: [AREA_1_ID] },
        body: {
          recipientPhone: SHIPPER_B_PHONE,
          scope: 'ALL_POINTS',
          includePhotos: true,
          expiresInDays: 7,
        },
      };
      const res = createMockResponse();
      await createShare(req, res);

      expect(res.statusCode).toBe(201);
      expect(res.body.success).toBe(true);
      expect(res.body.data.owner_id).toBe(SHIPPER_A_ID);
      expect(res.body.data.recipient_id).toBe(SHIPPER_B_ID);
      expect(res.body.data.status).toBe('PENDING');
      expect(res.body.data.expires_at).toBeTruthy();

      // Check audit_logs
      const auditRes = await testPool.query(
        "SELECT * FROM audit_logs WHERE action = 'SHARE_CREATED' ORDER BY created_at DESC LIMIT 1"
      );
      expect(auditRes.rows.length).toBe(1);
      const details = auditRes.rows[0].details;
      expect(details.shareId).toBe(res.body.data.id);
      expect(details.scope).toBe('ALL_POINTS');
      // Must NOT contain customer info
      expect(JSON.stringify(details)).not.toContain('customer');
      expect(JSON.stringify(details)).not.toContain('KH_001');
    });

    it('từ chối khi gửi trùng 2 lời mời PENDING/ACTIVE (trả thông báo chung)', async () => {
      const req: any = {
        user: { userId: SHIPPER_A_ID, roleName: 'SHIPPER', assignedAreaIds: [AREA_1_ID] },
        body: {
          recipientPhone: SHIPPER_B_PHONE,
          scope: 'ALL_POINTS',
          includePhotos: true,
        },
      };
      const res = createMockResponse();
      await createShare(req, res);

      expect(res.statusCode).toBe(400);
      expect(res.body.success).toBe(false);
      expect(res.body.message).toBe('Không gửi được lời mời, kiểm tra số điện thoại');
    });
  });

  describe('2. GET /api/v1/shares/outgoing & incoming', () => {
    it('Shipper A thấy lời mời vừa gửi trong danh sách outgoing', async () => {
      const req: any = {
        user: { userId: SHIPPER_A_ID, roleName: 'SHIPPER', assignedAreaIds: [AREA_1_ID] },
      };
      const res = createMockResponse();
      await getOutgoingShares(req, res);

      expect(res.statusCode).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.data.length).toBeGreaterThanOrEqual(1);
      const item = res.body.data[0];
      expect(item.recipientPhone).toBe(SHIPPER_B_PHONE);
      expect(item.status).toBe('PENDING');
      expect(item.sharedPointsCount).toBeGreaterThan(0);
    });

    it('Shipper B thấy lời mời được gửi tới trong danh sách incoming', async () => {
      const req: any = {
        user: { userId: SHIPPER_B_ID, roleName: 'SHIPPER', assignedAreaIds: [AREA_2_ID] },
      };
      const res = createMockResponse();
      await getIncomingShares(req, res);

      expect(res.statusCode).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.data.length).toBeGreaterThanOrEqual(1);
      const item = res.body.data[0];
      expect(item.ownerPhone).toBe(SHIPPER_A_PHONE);
      expect(item.status).toBe('PENDING');
    });
  });

  describe('3. Quyền xem điểm và ảnh trước khi chấp nhận lời mời', () => {
    it('B không thấy điểm chia sẻ trong shared-locations khi lời mời còn PENDING', async () => {
      const req: any = {
        user: { userId: SHIPPER_B_ID, roleName: 'SHIPPER', assignedAreaIds: [AREA_1_ID, AREA_2_ID] },
      };
      const res = createMockResponse();
      await getSharedLocations(req, res);

      expect(res.statusCode).toBe(200);
      expect(res.body.data.locations.length).toBe(0);
      expect(res.body.data.totalCount).toBe(0);
    });

    it('B bị 403 khi gọi servePhoto trước khi chấp nhận lời mời', async () => {
      const req: any = {
        params: { filename: testPhotoFilename },
        user: { userId: SHIPPER_B_ID, roleName: 'SHIPPER', assignedAreaIds: [AREA_1_ID, AREA_2_ID] },
      };
      const res = createMockResponse();
      await servePhoto(req, res);

      expect(res.statusCode).toBe(403);
      expect(res.body.success).toBe(false);
      expect(res.body.message).toContain('không có quyền truy cập');
    });
  });

  describe('4. POST /api/v1/shares/:id/accept - Chấp nhận lời mời & Kích hoạt dữ liệu', () => {
    let pendingShareId: string;

    beforeAll(async () => {
      const shareRow = await testPool.query(
        "SELECT id FROM data_shares WHERE owner_id = $1 AND recipient_id = $2 AND status = 'PENDING' LIMIT 1",
        [SHIPPER_A_ID, SHIPPER_B_ID]
      );
      pendingShareId = shareRow.rows[0].id;
    });

    it('người không phải người nhận không thể chấp nhận lời mời (404)', async () => {
      const req: any = {
        params: { id: pendingShareId },
        user: { userId: SHIPPER_C_ID, roleName: 'SHIPPER', assignedAreaIds: [AREA_1_ID] },
      };
      const res = createMockResponse();
      await acceptShare(req, res);

      expect(res.statusCode).toBe(404);
    });

    it('Shipper B chấp nhận lời mời thành công và ghi audit_log', async () => {
      const req: any = {
        params: { id: pendingShareId },
        user: { userId: SHIPPER_B_ID, roleName: 'SHIPPER', assignedAreaIds: [AREA_2_ID] },
      };
      const res = createMockResponse();
      await acceptShare(req, res);

      expect(res.statusCode).toBe(200);
      expect(res.body.success).toBe(true);

      const dbShare = await testPool.query('SELECT status, accepted_at FROM data_shares WHERE id = $1', [pendingShareId]);
      expect(dbShare.rows[0].status).toBe('ACTIVE');
      expect(dbShare.rows[0].accepted_at).toBeTruthy();

      const auditRes = await testPool.query(
        "SELECT * FROM audit_logs WHERE action = 'SHARE_ACCEPTED' AND entity_id = $1",
        [pendingShareId]
      );
      expect(auditRes.rows.length).toBe(1);
    });
  });

  describe('5. Lọc theo khu vực của người nhận (Area Scoping in shared-locations)', () => {
    it('điểm ngoài khu vực của B bị loại và tính đúng skippedOutOfAreaCount', async () => {
      // Shipper B currently only assigned AREA_2_ID
      // Shipper A's points (KH_001) are in AREA_1_ID
      const req: any = {
        user: { userId: SHIPPER_B_ID, roleName: 'SHIPPER', assignedAreaIds: [AREA_2_ID] },
      };
      const res = createMockResponse();
      await getSharedLocations(req, res);

      expect(res.statusCode).toBe(200);
      expect(res.body.success).toBe(true);
      // Because point is in Area 1 and B is only in Area 2, location is skipped
      expect(res.body.data.locations.length).toBe(0);
      expect(res.body.data.skippedOutOfAreaCount).toBeGreaterThan(0);
    });

    it('khi B được phân công khu vực tương ứng, điểm chia sẻ hiển thị đầy đủ thông tin chỉ đọc', async () => {
      // Provide Shipper B with AREA_1_ID
      const req: any = {
        user: { userId: SHIPPER_B_ID, roleName: 'SHIPPER', assignedAreaIds: [AREA_1_ID, AREA_2_ID] },
      };
      const res = createMockResponse();
      await getSharedLocations(req, res);

      expect(res.statusCode).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.data.locations.length).toBeGreaterThan(0);
      const point = res.body.data.locations[0];
      expect(point.customerPhone).toBeTruthy();
      expect(point.latitude).toBeGreaterThan(0);
      expect(point.longitude).toBeGreaterThan(0);
      expect(point.sharedByName).toContain('Trần Văn Giao');
      expect(point.photos).toBeDefined();
    });

    it('servePhoto trả về 200 cho B khi chia sẻ ACTIVE kèm ảnh và trong khu vực', async () => {
      const req: any = {
        params: { filename: testPhotoFilename },
        user: { userId: SHIPPER_B_ID, roleName: 'SHIPPER', assignedAreaIds: [AREA_1_ID, AREA_2_ID] },
      };
      const res = createMockResponse();
      await servePhoto(req, res);

      expect(res.statusCode).toBe(200);
      expect(res.headers['Cache-Control']).toContain('private, no-store');
    });

    it('Shipper thứ ba (C) không thấy dữ liệu chia sẻ giữa A và B', async () => {
      const req: any = {
        user: { userId: SHIPPER_C_ID, roleName: 'SHIPPER', assignedAreaIds: [AREA_1_ID] },
      };
      const res = createMockResponse();
      await getSharedLocations(req, res);

      expect(res.statusCode).toBe(200);
      expect(res.body.data.locations.length).toBe(0);
    });
  });

  describe('6. POST /api/v1/shares/:id/import - Nhập điểm chia sẻ vào vị trí của mình', () => {
    let activeShareId: string;

    beforeAll(async () => {
      const shareRow = await testPool.query(
        "SELECT id FROM data_shares WHERE owner_id = $1 AND recipient_id = $2 AND status = 'ACTIVE' LIMIT 1",
        [SHIPPER_A_ID, SHIPPER_B_ID]
      );
      activeShareId = shareRow.rows[0].id;
    });

    it('bỏ qua điểm nếu khách hàng đã có vị trí và không bật replaceExisting', async () => {
      // CUSTOMER_1_ID already has saved location (created by A)
      const req: any = {
        params: { id: activeShareId },
        user: { userId: SHIPPER_B_ID, roleName: 'SHIPPER', assignedAreaIds: [AREA_1_ID] },
        body: { all: true, replaceExisting: false },
      };
      const res = createMockResponse();
      await importSharedLocations(req, res);

      expect(res.statusCode).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.data.skippedCount).toBeGreaterThan(0);
      expect(res.body.data.importedCount).toBe(0);

      // Verify audit_log
      const auditRes = await testPool.query(
        "SELECT * FROM audit_logs WHERE action = 'SHARE_IMPORT' AND entity_id = $1 ORDER BY created_at DESC LIMIT 1",
        [activeShareId]
      );
      expect(auditRes.rows.length).toBe(1);
      expect(auditRes.rows[0].details.skippedCount).toBeGreaterThan(0);
      // No customer PII
      expect(JSON.stringify(auditRes.rows[0].details)).not.toContain('0988000001');
    });

    it('cập nhật vị trí khi replaceExisting = true và lưu vết vào location_history', async () => {
      // Create a shift for Shipper A with an updated delivery point for Customer 1
      const shiftRes = await testPool.query(
        `INSERT INTO shifts (shift_code, work_date, shipper_id, status)
         VALUES ($1, CURRENT_DATE, $2, 'PREPARING')
         RETURNING id`,
        [`SHF-IMPORT-${Date.now()}`, SHIPPER_A_ID]
      );
      const shiftId = shiftRes.rows[0].id;
      await testPool.query(
        `INSERT INTO shift_delivery_points (shift_id, customer_id, latitude, longitude, identification_notes, location_status)
         VALUES ($1, $2, 10.8430000, 106.8190000, 'Điểm giao cập nhật mới từ ca của A', 'VERIFIED')`,
        [shiftId, CUSTOMER_1_ID]
      );

      // Create and accept an active share for this shift
      const shareRes = await testPool.query(
        `INSERT INTO data_shares (owner_id, recipient_id, scope, shift_id, include_photos, status)
         VALUES ($1, $2, 'SHIFT', $3, true, 'ACTIVE')
         RETURNING id`,
        [SHIPPER_A_ID, SHIPPER_B_ID, shiftId]
      );
      const shiftShareId = shareRes.rows[0].id;

      const req: any = {
        params: { id: shiftShareId },
        user: { userId: SHIPPER_B_ID, roleName: 'SHIPPER', assignedAreaIds: [AREA_1_ID] },
        body: { all: true, replaceExisting: true },
      };
      const res = createMockResponse();
      await importSharedLocations(req, res);

      expect(res.statusCode).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.data.importedCount).toBeGreaterThan(0);

      // Verify saved_locations has updated_by set to Shipper B and updated notes
      const locRes = await testPool.query(
        'SELECT updated_by, identification_notes FROM saved_locations WHERE customer_id = $1',
        [CUSTOMER_1_ID]
      );
      expect(locRes.rows[0].updated_by).toBe(SHIPPER_B_ID);
      expect(locRes.rows[0].identification_notes).toContain('Điểm giao cập nhật mới từ ca của A');

      // Verify trigger saved previous location in location_history
      const historyRes = await testPool.query(
        'SELECT * FROM location_history WHERE customer_id = $1',
        [CUSTOMER_1_ID]
      );
      expect(historyRes.rows.length).toBeGreaterThan(0);
      expect(historyRes.rows.some((r: any) => r.identification_notes?.includes('Hai Thu'))).toBe(true);
    });

    it('vị trí gốc của A không bị xóa và my-saved-locations của A vẫn trả dữ liệu', async () => {
      const req: any = {
        user: { userId: SHIPPER_A_ID, roleName: 'SHIPPER', assignedAreaIds: [AREA_1_ID] },
      };
      const res = createMockResponse();
      await getMySavedLocations(req, res);

      expect(res.statusCode).toBe(200);
      expect(res.body.success).toBe(true);
      const points = res.body.data;
      expect(points.some((p: any) => p.customerId === CUSTOMER_1_ID)).toBe(true);
    });
  });

  describe('7. Thu hồi chia sẻ (Revoke) & Hết hạn (Expiration)', () => {
    let activeShareId: string;

    beforeAll(async () => {
      // Clean up temporary shift shares from test 6
      await testPool.query("DELETE FROM data_shares WHERE scope = 'SHIFT'");
      // Revert saved_locations.updated_by so B is not an owner of Customer 1
      await testPool.query('UPDATE saved_locations SET updated_by = created_by WHERE customer_id = $1', [CUSTOMER_1_ID]);

      const shareRow = await testPool.query(
        "SELECT id FROM data_shares WHERE owner_id = $1 AND recipient_id = $2 AND status = 'ACTIVE' LIMIT 1",
        [SHIPPER_A_ID, SHIPPER_B_ID]
      );
      activeShareId = shareRow.rows[0].id;
    });

    it('Shipper A dừng chia sẻ thành công và ghi audit_logs', async () => {
      const req: any = {
        params: { id: activeShareId },
        user: { userId: SHIPPER_A_ID, roleName: 'SHIPPER', assignedAreaIds: [AREA_1_ID] },
      };
      const res = createMockResponse();
      await revokeShare(req, res);

      expect(res.statusCode).toBe(200);
      expect(res.body.success).toBe(true);

      const dbShare = await testPool.query('SELECT status, revoked_at FROM data_shares WHERE id = $1', [activeShareId]);
      expect(dbShare.rows[0].status).toBe('REVOKED');
      expect(dbShare.rows[0].revoked_at).toBeTruthy();
    });

    it('sau khi dừng chia sẻ, Shipper B lập tức mất quyền xem điểm và ảnh (403)', async () => {
      // B calls shared-locations
      const locReq: any = {
        user: { userId: SHIPPER_B_ID, roleName: 'SHIPPER', assignedAreaIds: [AREA_1_ID, AREA_2_ID] },
      };
      const locRes = createMockResponse();
      await getSharedLocations(locReq, locRes);

      expect(locRes.statusCode).toBe(200);
      expect(locRes.body.data.locations.length).toBe(0);

      // B calls servePhoto
      const photoReq: any = {
        params: { filename: testPhotoFilename },
        user: { userId: SHIPPER_B_ID, roleName: 'SHIPPER', assignedAreaIds: [AREA_1_ID, AREA_2_ID] },
      };
      const photoRes = createMockResponse();
      await servePhoto(photoReq, photoRes);

      expect(photoRes.statusCode).toBe(403);
      expect(photoRes.body.success).toBe(false);
    });

    it('lời mời hết hạn tự động mất quyền xem', async () => {
      // Create an expired active share
      const expRes = await testPool.query(
        `INSERT INTO data_shares (owner_id, recipient_id, scope, include_photos, status, expires_at)
         VALUES ($1, $2, 'ALL_POINTS', true, 'ACTIVE', NOW() - INTERVAL '1 hour')
         RETURNING id`,
        [SHIPPER_A_ID, SHIPPER_B_ID]
      );
      const expiredShareId = expRes.rows[0].id;

      const locReq: any = {
        user: { userId: SHIPPER_B_ID, roleName: 'SHIPPER', assignedAreaIds: [AREA_1_ID, AREA_2_ID] },
      };
      const locRes = createMockResponse();
      await getSharedLocations(locReq, locRes);

      expect(locRes.statusCode).toBe(200);
      expect(locRes.body.data.locations.length).toBe(0);

      // Cleanup expired test share
      await testPool.query('DELETE FROM data_shares WHERE id = $1', [expiredShareId]);
    });
  });

  describe('8. Quyền ảnh khi includePhotos = false', () => {
    let noPhotoShareId: string;

    beforeAll(async () => {
      // Clean up previous shares between A and B
      await testPool.query('DELETE FROM data_shares WHERE owner_id = $1 AND recipient_id = $2', [SHIPPER_A_ID, SHIPPER_B_ID]);
      // Ensure B is not an owner
      await testPool.query('UPDATE saved_locations SET updated_by = created_by WHERE customer_id = $1', [CUSTOMER_1_ID]);

      const res = await testPool.query(
        `INSERT INTO data_shares (owner_id, recipient_id, scope, include_photos, status)
         VALUES ($1, $2, 'ALL_POINTS', false, 'ACTIVE')
         RETURNING id`,
        [SHIPPER_A_ID, SHIPPER_B_ID]
      );
      noPhotoShareId = res.rows[0].id;
    });

    it('shared-locations trả về imageUrl null và photos rỗng khi includePhotos = false', async () => {
      const locReq: any = {
        user: { userId: SHIPPER_B_ID, roleName: 'SHIPPER', assignedAreaIds: [AREA_1_ID, AREA_2_ID] },
      };
      const locRes = createMockResponse();
      await getSharedLocations(locReq, locRes);

      expect(locRes.statusCode).toBe(200);
      expect(locRes.body.data.locations.length).toBeGreaterThan(0);
      const pt = locRes.body.data.locations[0];
      expect(pt.imageUrl).toBeNull();
      expect(pt.photos).toEqual([]);
      expect(pt.photoCount).toBe(0);
    });

    it('servePhoto chặn B bằng mã 403 khi includePhotos = false', async () => {
      const photoReq: any = {
        params: { filename: testPhotoFilename },
        user: { userId: SHIPPER_B_ID, roleName: 'SHIPPER', assignedAreaIds: [AREA_1_ID, AREA_2_ID] },
      };
      const photoRes = createMockResponse();
      await servePhoto(photoReq, photoRes);

      expect(photoRes.statusCode).toBe(403);
    });
  });
});
