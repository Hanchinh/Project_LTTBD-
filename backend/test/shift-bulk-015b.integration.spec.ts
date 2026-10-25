process.env.NODE_ENV = 'test';
process.env.DB_NAME = 'test_isolated_seed_db';
process.env.IS_INTEGRATION_TEST = 'true';

import { Pool } from 'pg';
import { pool, ISOLATED_TEST_DB_NAME } from '../src/db';
import {
  createShift,
  getShiftDetail,
  listShifts,
  updateShiftName,
  addBulkPointsToShift,
  parseAndNormalizeBulkPhones,
} from '../src/controllers/shifts.controller';
import { setupIsolatedTestDatabase } from '../scripts/setup-test-db';

describe('TASK: SHIFT-FROM-MAP-AND-BULK-PASTE-015B - Bulk Phone Paste & Shift Name Integration Tests', () => {
  let testPool: Pool;

  const SHIPPER_A_ID = 'd0000000-0000-0000-0000-000000000001'; // Shipper A (Area 1)
  const SHIPPER_B_ID = 'd0000000-0000-0000-0000-000000000002'; // Shipper B (Area 2)
  const ADMIN_ID = 'a0000000-0000-0000-0000-000000000001';
  const AREA_1_ID = 'b0000000-0000-0000-0000-000000000001';
  const AREA_2_ID = 'b0000000-0000-0000-0000-000000000002';

  beforeAll(async () => {
    await setupIsolatedTestDatabase();

    testPool = new Pool({
      host: process.env.DB_HOST || 'localhost',
      port: parseInt(process.env.DB_PORT || '5432'),
      database: ISOLATED_TEST_DB_NAME,
      user: process.env.DB_USER || 'postgres',
      password: process.env.DB_PASSWORD || 'postgres',
    });
  });

  afterAll(async () => {
    if (testPool) {
      await testPool.end();
    }
    await pool.end();
  });

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

  describe('1. Kiểm tra hàm helper parseAndNormalizeBulkPhones', () => {
    it('Tách số theo xuống dòng, phẩy, chấm phẩy, chuẩn hóa +84, khoảng trắng, dấu chấm bên trong', () => {
      const rawText = '0908 911 111, +84 908 911 111; 0908.911.111\n0988000001\r\n0988000002, sai-dinh-dang';
      const result = parseAndNormalizeBulkPhones(rawText);

      // 0908 911 111, +84 908 911 111, 0908.911.111 đều chuẩn hóa thành 0908911111 và được deduplicate
      expect(result.uniquePhones).toContain('0908911111');
      expect(result.uniquePhones).toContain('0988000001');
      expect(result.uniquePhones).toContain('0988000002');

      const invalidItem = result.items.find(i => !i.isValid);
      expect(invalidItem).toBeDefined();
      expect(invalidItem?.original).toBe('sai-dinh-dang');
    });
  });

  describe('2. Tạo ca làm việc có tên và không có tên (shiftName)', () => {
    it('Tạo ca không có tên: shiftName trả về null, hiển thị shiftCode', async () => {
      const req: any = {
        user: { userId: SHIPPER_A_ID, roleName: 'SHIPPER', assignedAreaIds: [AREA_1_ID] },
        body: { workDate: '2026-10-25' },
      };
      const res = createMockResponse();

      await createShift(req, res);

      expect(res.statusCode).toBe(201);
      expect(res.body.success).toBe(true);
      expect(res.body.data.shiftName).toBeNull();
      expect(res.body.data.shiftCode).toMatch(/^SHF-20261025-\d{3}$/);
    });

    it('Tạo ca có tên: lưu shiftName tối đa 100 ký tự cắt khoảng trắng', async () => {
      const req: any = {
        user: { userId: SHIPPER_A_ID, roleName: 'SHIPPER', assignedAreaIds: [AREA_1_ID] },
        body: { workDate: '2026-10-25', shiftName: '  Ca sáng giao nhanh Thủ Đức  ' },
      };
      const res = createMockResponse();

      await createShift(req, res);

      expect(res.statusCode).toBe(201);
      expect(res.body.success).toBe(true);
      expect(res.body.data.shiftName).toBe('Ca sáng giao nhanh Thủ Đức');
    });
  });

  describe('3. Đổi tên ca làm việc (PATCH /api/v1/shifts/:id/name)', () => {
    let createdShiftId: string;

    beforeAll(async () => {
      const req: any = {
        user: { userId: SHIPPER_A_ID, roleName: 'SHIPPER', assignedAreaIds: [AREA_1_ID] },
        body: { workDate: '2026-10-25', shiftName: 'Ca ban đầu' },
      };
      const res = createMockResponse();
      await createShift(req, res);
      createdShiftId = res.body.data.id;
    });

    it('Shipper sở hữu ca đổi tên thành công và ghi audit_logs UPDATE_SHIFT_NAME', async () => {
      const req: any = {
        user: { userId: SHIPPER_A_ID, roleName: 'SHIPPER', assignedAreaIds: [AREA_1_ID] },
        params: { id: createdShiftId },
        body: { shiftName: 'Ca chiều sau đổi tên' },
      };
      const res = createMockResponse();

      await updateShiftName(req, res);

      expect(res.statusCode).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.data.shiftName).toBe('Ca chiều sau đổi tên');

      // Kiểm tra audit_logs
      const auditRes = await testPool.query(
        `SELECT * FROM audit_logs WHERE action = 'UPDATE_SHIFT_NAME' AND entity_id = $1`,
        [createdShiftId]
      );
      expect(auditRes.rows.length).toBeGreaterThanOrEqual(1);
    });

    it('Shipper khác cố đổi tên ca của Shipper A bị từ chối 403 Forbidden', async () => {
      const req: any = {
        user: { userId: SHIPPER_B_ID, roleName: 'SHIPPER', assignedAreaIds: [AREA_2_ID] },
        params: { id: createdShiftId },
        body: { shiftName: 'Hack tên ca' },
      };
      const res = createMockResponse();

      await updateShiftName(req, res);

      expect(res.statusCode).toBe(403);
      expect(res.body.success).toBe(false);
    });

    it('ADMIN có quyền đổi tên ca của bất kỳ shipper nào', async () => {
      const req: any = {
        user: { userId: ADMIN_ID, roleName: 'ADMIN', assignedAreaIds: [] },
        params: { id: createdShiftId },
        body: { shiftName: 'Admin đổi tên ca' },
      };
      const res = createMockResponse();

      await updateShiftName(req, res);

      expect(res.statusCode).toBe(200);
      expect(res.body.data.shiftName).toBe('Admin đổi tên ca');
    });
  });

  describe('4. Thêm hàng loạt điểm giao vào ca (POST /api/v1/shifts/:id/points/bulk)', () => {
    let testShiftId: string;

    beforeEach(async () => {
      const req: any = {
        user: { userId: SHIPPER_A_ID, roleName: 'SHIPPER', assignedAreaIds: [AREA_1_ID] },
        body: { workDate: '2026-10-25', shiftName: 'Ca kiểm thử Bulk Paste' },
      };
      const res = createMockResponse();
      await createShift(req, res);
      testShiftId = res.body.data.id;
    });

    it('Từ chối nếu số lượng SĐT vượt quá giới hạn 200 số', async () => {
      const manyPhones = Array.from({ length: 201 }, (_, i) => `090100${i.toString().padStart(4, '0')}`);
      const req: any = {
        user: { userId: SHIPPER_A_ID, roleName: 'SHIPPER', assignedAreaIds: [AREA_1_ID] },
        params: { id: testShiftId },
        body: { phones: manyPhones },
      };
      const res = createMockResponse();

      await addBulkPointsToShift(req, res);

      expect(res.statusCode).toBe(400);
      expect(res.body.success).toBe(false);
      expect(res.body.message).toContain('Vượt quá giới hạn tối đa 200');
    });

    it('Shipper B không thể thêm điểm vào ca của Shipper A (403 Forbidden)', async () => {
      const req: any = {
        user: { userId: SHIPPER_B_ID, roleName: 'SHIPPER', assignedAreaIds: [AREA_2_ID] },
        params: { id: testShiftId },
        body: { rawText: '0988000001' },
      };
      const res = createMockResponse();

      await addBulkPointsToShift(req, res);

      expect(res.statusCode).toBe(403);
      expect(res.body.success).toBe(false);
    });

    it('Xử lý lô số hỗn hợp: VERIFIED, NO_LOCATION, tạo khách mới, sai định dạng, ngoài khu vực', async () => {
      // 0988000001: Khách đã có vị trí lưu trong Area 1 -> VERIFIED
      // 0988000002: Khách trong Area 1 nhưng chưa có vị trí -> NO_LOCATION
      // 0988000004: Khách trong Area 2 (ngoài khu vực Shipper A) -> REJECTED (OUT_OF_AREA)
      // 0908888777: Khách hoàn toàn mới -> Tạo khách mới trong Area 1 -> NO_LOCATION
      // sai_so_123: Định dạng sai -> REJECTED (INVALID_FORMAT)
      const rawText = '0988000001, 0988000002; 0988000004\n0908888777, sai_so_123';
      const req: any = {
        user: { userId: SHIPPER_A_ID, roleName: 'SHIPPER', assignedAreaIds: [AREA_1_ID] },
        params: { id: testShiftId },
        body: { rawText },
      };
      const res = createMockResponse();

      await addBulkPointsToShift(req, res);

      expect(res.statusCode).toBe(200);
      expect(res.body.success).toBe(true);

      const { added, alreadyInShift, rejected, summary } = res.body.data;

      // 1. Kiểm tra nhóm added (3 số: 0988000001, 0988000002, 0908888777)
      expect(added.length).toBe(3);

      const pt1 = added.find((p: any) => p.customerPhone === '0988000001');
      expect(pt1).toBeDefined();
      expect(pt1.locationStatus).toBe('VERIFIED');
      expect(pt1.latitude).toBeCloseTo(10.842215, 5);

      const pt2 = added.find((p: any) => p.customerPhone === '0988000002');
      expect(pt2).toBeDefined();
      expect(pt2.locationStatus).toBe('NO_LOCATION');
      expect(pt2.latitude).toBeNull();

      const ptNew = added.find((p: any) => p.customerPhone === '0908888777');
      expect(ptNew).toBeDefined();
      expect(ptNew.customerName).toBe('Khách 0908888777');
      expect(ptNew.locationStatus).toBe('NO_LOCATION');

      // 2. Kiểm tra nhóm rejected (2 số: 0988000004 ngoài khu vực và sai_so_123)
      expect(rejected.length).toBe(2);

      const outOfArea = rejected.find((r: any) => r.phone === '0988000004');
      expect(outOfArea).toBeDefined();
      expect(outOfArea.reason).toBe('OUT_OF_AREA');

      const invalid = rejected.find((r: any) => r.phone === 'sai_so_123');
      expect(invalid).toBeDefined();
      expect(invalid.reason).toBe('INVALID_FORMAT');

      // 3. Kiểm tra summary
      expect(summary.addedCount).toBe(3);
      expect(summary.rejectedCount).toBe(2);
      expect(summary.alreadyInShiftCount).toBe(0);

      // 4. Kiểm tra audit_logs BULK_ADD_POINTS
      const auditRes = await testPool.query(
        `SELECT * FROM audit_logs WHERE action = 'BULK_ADD_POINTS' AND entity_id = $1`,
        [testShiftId]
      );
      expect(auditRes.rows.length).toBe(1);
    });

    it('Dán lại số đã có trong ca thì phân vào nhóm alreadyInShift, không thêm trùng lặp', async () => {
      // Lần 1: thêm 0988000001 vào ca
      const req1: any = {
        user: { userId: SHIPPER_A_ID, roleName: 'SHIPPER', assignedAreaIds: [AREA_1_ID] },
        params: { id: testShiftId },
        body: { phones: ['0988000001'] },
      };
      const res1 = createMockResponse();
      await addBulkPointsToShift(req1, res1);
      expect(res1.body.data.added.length).toBe(1);

      // Lần 2: dán lại số 0988000001 kèm số mới 0988000002
      const req2: any = {
        user: { userId: SHIPPER_A_ID, roleName: 'SHIPPER', assignedAreaIds: [AREA_1_ID] },
        params: { id: testShiftId },
        body: { rawText: '0988000001\n0988000002' },
      };
      const res2 = createMockResponse();
      await addBulkPointsToShift(req2, res2);

      expect(res2.statusCode).toBe(200);
      const { added, alreadyInShift } = res2.body.data;
      expect(added.length).toBe(1);
      expect(added[0].customerPhone).toBe('0988000002');

      expect(alreadyInShift.length).toBe(1);
      expect(alreadyInShift[0].phone).toBe('0988000001');
    });

    it('Shipper có nhiều khu vực khi dán số mới mà chưa chọn areaId thì trả lỗi 400 yêu cầu chọn', async () => {
      const req: any = {
        user: {
          userId: SHIPPER_A_ID,
          roleName: 'SHIPPER',
          assignedAreaIds: [AREA_1_ID, AREA_2_ID], // 2 khu vực
        },
        params: { id: testShiftId },
        body: { phones: ['0909112233'] }, // Số mới chưa có trong DB
      };
      const res = createMockResponse();

      await addBulkPointsToShift(req, res);

      expect(res.statusCode).toBe(400);
      expect(res.body.success).toBe(false);
      expect(res.body.requireAreaSelection).toBe(true);
      expect(res.body.message).toContain('Bạn phụ trách nhiều khu vực');
    });

    it('Shipper có nhiều khu vực nhưng đã chọn areaId hợp lệ thì tạo khách thành công', async () => {
      const req: any = {
        user: {
          userId: SHIPPER_A_ID,
          roleName: 'SHIPPER',
          assignedAreaIds: [AREA_1_ID, AREA_2_ID],
        },
        params: { id: testShiftId },
        body: { phones: ['0909112233'], areaId: AREA_1_ID },
      };
      const res = createMockResponse();

      await addBulkPointsToShift(req, res);

      expect(res.statusCode).toBe(200);
      expect(res.body.data.added.length).toBe(1);
      expect(res.body.data.added[0].customerPhone).toBe('0909112233');
    });
  });
});
