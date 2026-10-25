process.env.NODE_ENV = 'test';
process.env.DB_NAME = 'test_isolated_seed_db';
process.env.IS_INTEGRATION_TEST = 'true';

import { Pool } from 'pg';
import { pool, ISOLATED_TEST_DB_NAME } from '../src/db';
import { getMySavedLocations, saveOrUpdateCustomerLocation } from '../src/controllers/locations.controller';
import { createCustomer } from '../src/controllers/customers.controller';
import { setupIsolatedTestDatabase } from '../scripts/setup-test-db';

describe('TASK: MASTER-MAP-014 - Master Map & My Saved Locations Integration Tests', () => {
  let testPool: Pool;

  const SHIPPER_A_ID = 'd0000000-0000-0000-0000-000000000001'; // Shipper A (Area 1)
  const SHIPPER_B_ID = 'd0000000-0000-0000-0000-000000000002'; // Shipper B (Area 2)
  const AREA_1_ID = 'b0000000-0000-0000-0000-000000000001';

  beforeAll(async () => {
    // Khởi tạo CSDL kiểm thử cô lập test_isolated_seed_db
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

  describe('1. API getMySavedLocations trả về đúng các điểm do chính shipper đăng nhập lưu', () => {
    it('Shipper A đăng nhập: chỉ thấy các điểm do chính Shipper A lưu (KH_001), không thấy điểm của Shipper B (KH_004)', async () => {
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
      expect(res.body.success).toBe(true);
      expect(Array.isArray(res.body.data)).toBe(true);

      const items = res.body.data;
      expect(items.length).toBeGreaterThanOrEqual(1);

      // KH_001 do Shipper A lưu phải có mặt
      const kh001 = items.find((i: any) => i.customerPhone === '0988000001');
      expect(kh001).toBeDefined();
      expect(kh001.customerName).toBe('Anh Hoàng (Tạp hóa Hai Thu)');
      expect(kh001.latitude).toBeCloseTo(10.842215, 5);
      expect(kh001.longitude).toBeCloseTo(106.818123, 5);
      expect(kh001.identificationNotes).toContain('tiệm tạp hóa Hai Thu');

      // Điểm của Shipper B (KH_004 - 0988000004) TUYỆT ĐỐI không có trong danh sách của Shipper A
      const kh004 = items.find((i: any) => i.customerPhone === '0988000004');
      expect(kh004).toBeUndefined();
    });

    it('Shipper B đăng nhập: chỉ thấy các điểm do chính Shipper B lưu (KH_004)', async () => {
      const req: any = {
        user: {
          userId: SHIPPER_B_ID,
          roleName: 'SHIPPER',
          assignedAreaIds: ['b0000000-0000-0000-0000-000000000002'],
        },
      };
      const res = createMockResponse();

      await getMySavedLocations(req, res);

      expect(res.statusCode).toBe(200);
      expect(res.body.success).toBe(true);
      const items = res.body.data;
      const kh004 = items.find((i: any) => i.customerPhone === '0988000004');
      expect(kh004).toBeDefined();
      expect(kh004.customerName).toBe('Bác Hùng (Nhà gỗ)');

      // Không thấy điểm của Shipper A
      const kh001 = items.find((i: any) => i.customerPhone === '0988000001');
      expect(kh001).toBeUndefined();
    });
  });

  describe('2. Luồng ghim vị trí mới từ Bản đồ chính: Tự tạo khách nếu số mới rồi lưu vị trí ĐÃ XÁC NHẬN', () => {
    it('nhập số mới 0908911111: tạo khách hàng và lưu vị trí, sau đó getMySavedLocations trả về điểm mới này', async () => {
      const newPhone = '0908911111';
      const createReq: any = {
        body: {
          phoneNumber: newPhone,
          areaId: AREA_1_ID,
        },
        user: {
          userId: SHIPPER_A_ID,
          roleName: 'SHIPPER',
          assignedAreaIds: [AREA_1_ID],
        },
      };
      const createRes = createMockResponse();

      await createCustomer(createReq, createRes);

      expect(createRes.statusCode).toBe(201);
      expect(createRes.body.data.id).toBeDefined();
      const customerId = createRes.body.data.id;

      // Lưu vị trí cho khách hàng vừa tạo bằng tâm ngắm (crosshair)
      const saveLocReq: any = {
        params: { customerId },
        body: {
          latitude: 10.845500,
          longitude: 106.820100,
          gpsAccuracy: 3.5,
          identificationNotes: 'Cổng sắt màu xám, đối diện bách hóa',
        },
        user: {
          userId: SHIPPER_A_ID,
          roleName: 'SHIPPER',
          assignedAreaIds: [AREA_1_ID],
        },
      };
      const saveLocRes = createMockResponse();

      await saveOrUpdateCustomerLocation(saveLocReq, saveLocRes);

      expect(saveLocRes.statusCode).toBe(200);
      expect(saveLocRes.body.success).toBe(true);

      // Gọi getMySavedLocations xác nhận điểm mới xuất hiện ngay
      const myLocsReq: any = {
        user: {
          userId: SHIPPER_A_ID,
          roleName: 'SHIPPER',
          assignedAreaIds: [AREA_1_ID],
        },
      };
      const myLocsRes = createMockResponse();

      await getMySavedLocations(myLocsReq, myLocsRes);

      const foundNew = myLocsRes.body.data.find((i: any) => i.customerPhone === newPhone);
      expect(foundNew).toBeDefined();
      expect(foundNew.customerName).toBe(`Khách ${newPhone}`);
      expect(foundNew.latitude).toBeCloseTo(10.845500, 5);
      expect(foundNew.longitude).toBeCloseTo(106.820100, 5);
      expect(foundNew.identificationNotes).toBe('Cổng sắt màu xám, đối diện bách hóa');
    });

    it('thay vị trí cũ bằng vị trí mới: cập nhật saved_locations và bảo toàn lịch sử trong location_history', async () => {
      // KH_001 đã có vị trí cũ trong seed database
      const custRes = await testPool.query("SELECT id FROM customers WHERE phone_number = '0988000001'");
      const customerId = custRes.rows[0].id;

      // Đếm lịch sử trước khi cập nhật
      const histBefore = await testPool.query("SELECT COUNT(*) as count FROM location_history WHERE customer_id = $1", [customerId]);
      const countBefore = parseInt(histBefore.rows[0].count);

      // Cập nhật vị trí mới
      const updateReq: any = {
        params: { customerId },
        body: {
          latitude: 10.843333,
          longitude: 106.819999,
          gpsAccuracy: 2.0,
          identificationNotes: 'Vị trí mới sau khi cập nhật tâm ngắm',
        },
        user: {
          userId: SHIPPER_A_ID,
          roleName: 'SHIPPER',
          assignedAreaIds: [AREA_1_ID],
        },
      };
      const updateRes = createMockResponse();

      await saveOrUpdateCustomerLocation(updateReq, updateRes);

      expect(updateRes.statusCode).toBe(200);

      // Kiểm tra saved_locations đã nhận tọa độ mới
      const locAfter = await testPool.query("SELECT latitude, longitude, identification_notes FROM saved_locations WHERE customer_id = $1", [customerId]);
      expect(parseFloat(locAfter.rows[0].latitude)).toBeCloseTo(10.843333, 5);
      expect(locAfter.rows[0].identification_notes).toBe('Vị trí mới sau khi cập nhật tâm ngắm');

      // Kiểm tra trigger CSDL đã tự động ghi thêm 1 bản ghi vào location_history
      const histAfter = await testPool.query("SELECT COUNT(*) as count FROM location_history WHERE customer_id = $1", [customerId]);
      const countAfter = parseInt(histAfter.rows[0].count);
      expect(countAfter).toBe(countBefore + 1);
    });
  });
});
