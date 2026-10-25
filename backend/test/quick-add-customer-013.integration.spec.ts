process.env.NODE_ENV = 'test';
process.env.DB_NAME = 'test_isolated_seed_db';
process.env.IS_INTEGRATION_TEST = 'true';

import { Pool } from 'pg';
import { pool, ISOLATED_TEST_DB_NAME } from '../src/db';
import { createCustomer } from '../src/controllers/customers.controller';
import { getMyAreas } from '../src/controllers/admin.controller';
import { addPointToShift } from '../src/controllers/shifts.controller';
import { setupIsolatedTestDatabase } from '../scripts/setup-test-db';

describe('TASK: QUICK-ADD-CUSTOMER-013 - Quick Add Customer Integration Tests on Isolated DB', () => {
  let testPool: Pool;

  const SHIPPER_A_ID = 'd0000000-0000-0000-0000-000000000001'; // Shipper A (Area 1: Khu vực Quận 9)
  const AREA_1_ID = 'b0000000-0000-0000-0000-000000000001';
  const AREA_2_ID = 'b0000000-0000-0000-0000-000000000002'; // Area 2 (Assigned to Shipper B, NOT Shipper A)

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

  describe('1. Chỉ bắt buộc số điện thoại: Tên & Địa chỉ tự động nhận giá trị mặc định chuẩn', () => {
    it('khi chỉ gửi phoneNumber, tên mặc định "Khách [SĐT]" và địa chỉ mặc định "Chưa cập nhật địa chỉ"', async () => {
      const uniquePhone = `0911${Math.floor(100000 + Math.random() * 900000)}`;
      const req: any = {
        body: {
          phoneNumber: uniquePhone,
        },
        user: {
          userId: SHIPPER_A_ID,
          roleName: 'SHIPPER',
          assignedAreaIds: [AREA_1_ID],
        },
      };
      const res = createMockResponse();

      await createCustomer(req, res);

      expect(res.statusCode).toBe(201);
      expect(res.body.success).toBe(true);
      expect(res.body.data).toBeDefined();
      expect(res.body.data.phoneNumber).toBe(uniquePhone);
      expect(res.body.data.fullName).toBe(`Khách ${uniquePhone}`);
      expect(res.body.data.addressText).toBe('Chưa cập nhật địa chỉ');
      expect(res.body.data.areaId).toBe(AREA_1_ID);

      // Xác minh trực tiếp trong CSDL cô lập test_isolated_seed_db
      const dbRes = await testPool.query(
        'SELECT id, full_name, phone_number, address_text, area_id FROM customers WHERE phone_number = $1',
        [uniquePhone]
      );
      expect(dbRes.rows.length).toBe(1);
      expect(dbRes.rows[0].full_name).toBe(`Khách ${uniquePhone}`);
      expect(dbRes.rows[0].addressText || dbRes.rows[0].address_text).toBe('Chưa cập nhật địa chỉ');
    });

    it('khi người dùng nhập đầy đủ tên và địa chỉ tùy chọn, backend lưu đúng giá trị người dùng nhập', async () => {
      const uniquePhone = `0922${Math.floor(100000 + Math.random() * 900000)}`;
      const customName = 'Bác Ba Phi';
      const customAddress = 'Số 456 Đường Nguyễn Văn Tăng, P. Long Thạnh Mỹ';
      const customNotes = 'Cổng gỗ màu nâu, đối diện trường học';

      const req: any = {
        body: {
          phoneNumber: uniquePhone,
          fullName: customName,
          addressText: customAddress,
          identificationNotes: customNotes,
        },
        user: {
          userId: SHIPPER_A_ID,
          roleName: 'SHIPPER',
          assignedAreaIds: [AREA_1_ID],
        },
      };
      const res = createMockResponse();

      await createCustomer(req, res);

      expect(res.statusCode).toBe(201);
      expect(res.body.success).toBe(true);
      expect(res.body.data.fullName).toBe(customName);
      expect(res.body.data.addressText).toBe(customAddress);
    });
  });

  describe('2. Số đã tồn tại: Không tạo trùng lặp, trả về 200 OK kèm hồ sơ khách hàng hiện hữu', () => {
    it('khi gọi tạo khách hàng với số điện thoại đã có sẵn, trả về isExisting: true và mở hồ sơ', async () => {
      const existingPhone = '0988000001'; // KH_001 đã có trong seed database
      const req: any = {
        body: {
          phoneNumber: existingPhone,
        },
        user: {
          userId: SHIPPER_A_ID,
          roleName: 'SHIPPER',
          assignedAreaIds: [AREA_1_ID],
        },
      };
      const res = createMockResponse();

      await createCustomer(req, res);

      expect(res.statusCode).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.isExisting).toBe(true);
      expect(res.body.data).toBeDefined();
      expect(res.body.data.phoneNumber).toBe(existingPhone);
      expect(res.body.data.fullName).toBe('Anh Hoàng (Tạp hóa Hai Thu)');

      // Đảm bảo không tạo thêm bất kỳ dòng trùng lặp nào trong DB
      const countRes = await testPool.query(
        'SELECT COUNT(*) as count FROM customers WHERE phone_number = $1',
        [existingPhone]
      );
      expect(parseInt(countRes.rows[0].count)).toBe(1);
    });
  });

  describe('3. Khu vực lấy theo khu vực shipper phụ trách', () => {
    it('getMyAreas trả về đúng danh sách khu vực được phân công của shipper', async () => {
      const req: any = {
        user: {
          userId: SHIPPER_A_ID,
          roleName: 'SHIPPER',
        },
      };
      const res = createMockResponse();

      await getMyAreas(req, res);

      expect(res.statusCode).toBe(200);
      expect(res.body.success).toBe(true);
      expect(Array.isArray(res.body.data)).toBe(true);
      expect(res.body.data.length).toBeGreaterThanOrEqual(1);
      expect(res.body.data[0].id).toBe(AREA_1_ID);
    });
  });

  describe('4. TASK: QUICK-ADD-013B - Kiểm tra quyền khu vực (403 Forbidden)', () => {
    it('createCustomer: trả 403 nếu areaId gửi lên không thuộc khu vực shipper phụ trách, không âm thầm đổi sang khu vực khác', async () => {
      const newPhone = `0933${Math.floor(100000 + Math.random() * 900000)}`;
      const req: any = {
        body: {
          phoneNumber: newPhone,
          areaId: AREA_2_ID, // Khu vực 2 không thuộc phân công của Shipper A
        },
        user: {
          userId: SHIPPER_A_ID,
          roleName: 'SHIPPER',
          assignedAreaIds: [AREA_1_ID],
        },
      };
      const res = createMockResponse();

      await createCustomer(req, res);

      expect(res.statusCode).toBe(403);
      expect(res.body.success).toBe(false);
      expect(res.body.message).toContain('Khu vực được chỉ định không thuộc khu vực bạn được phân công phụ trách');

      // Đảm bảo không tạo khách hàng nào trong DB
      const checkCust = await testPool.query('SELECT id FROM customers WHERE phone_number = $1', [newPhone]);
      expect(checkCust.rows.length).toBe(0);
    });

    it('addPointToShift: trả 403 nếu areaId gửi lên không thuộc khu vực shipper phụ trách', async () => {
      // Tạo một ca làm việc cho Shipper A trong test_isolated_seed_db
      const shiftRes = await testPool.query(
        `INSERT INTO shifts (shift_code, work_date, shipper_id, status)
         VALUES ($1, CURRENT_DATE, $2, 'PREPARING')
         RETURNING id`,
        [`SHF-TEST-013B-${Date.now()}`, SHIPPER_A_ID]
      );
      const testShiftId = shiftRes.rows[0].id;
      const newPhone = `0944${Math.floor(100000 + Math.random() * 900000)}`;

      const req: any = {
        params: { id: testShiftId },
        body: {
          phoneNumber: newPhone,
          createIfNotFound: true,
          areaId: AREA_2_ID, // Không thuộc phân công
        },
        user: {
          userId: SHIPPER_A_ID,
          roleName: 'SHIPPER',
          assignedAreaIds: [AREA_1_ID],
        },
      };
      const res = createMockResponse();

      await addPointToShift(req, res);

      expect(res.statusCode).toBe(403);
      expect(res.body.success).toBe(false);
      expect(res.body.message).toContain('Khu vực được chỉ định không thuộc khu vực bạn được phân công phụ trách');
    });
  });

  describe('5. TASK: QUICK-ADD-013B - Số điện thoại đã tồn tại nhập ở màn chuẩn bị ca', () => {
    it('thêm số điện thoại đã tồn tại vào ca thành công, lưu điểm giao và cập nhật thống kê ca', async () => {
      // Tạo ca mới cho Shipper A
      const shiftRes = await testPool.query(
        `INSERT INTO shifts (shift_code, work_date, shipper_id, status)
         VALUES ($1, CURRENT_DATE, $2, 'PREPARING')
         RETURNING id`,
        [`SHF-TEST-EXISTING-${Date.now()}`, SHIPPER_A_ID]
      );
      const testShiftId = shiftRes.rows[0].id;

      // 0988000001 (KH_001) đã có trong CSDL thuộc AREA_1_ID
      const existingPhone = '0988000001';
      const req: any = {
        params: { id: testShiftId },
        body: {
          phoneNumber: existingPhone,
        },
        user: {
          userId: SHIPPER_A_ID,
          roleName: 'SHIPPER',
          assignedAreaIds: [AREA_1_ID],
        },
      };
      const res = createMockResponse();

      await addPointToShift(req, res);

      expect(res.statusCode).toBe(201);
      expect(res.body.success).toBe(true);
      expect(res.body.data).toBeDefined();
      expect(res.body.data.customerPhone).toBe(existingPhone);
      expect(res.body.data.customerName).toBe('Anh Hoàng (Tạp hóa Hai Thu)');
      expect(res.body.data.locationStatus).toBe('VERIFIED'); // KH_001 đã có saved_locations
      expect(res.body.summary).toBeDefined();
      expect(res.body.summary.totalPoints).toBe(1);
      expect(res.body.summary.verifiedCount).toBe(1);

      // Xác minh trong DB test_isolated_seed_db
      const pointInDb = await testPool.query(
        'SELECT id, shift_id, customer_id, location_status FROM shift_delivery_points WHERE shift_id = $1',
        [testShiftId]
      );
      expect(pointInDb.rows.length).toBe(1);
      expect(pointInDb.rows[0].location_status).toBe('VERIFIED');

      // Nếu thêm lại chính số đó vào cùng ca: Trả về 200 OK kèm isExisting: true
      const duplicateRes = createMockResponse();
      await addPointToShift(req, duplicateRes);

      expect(duplicateRes.statusCode).toBe(200);
      expect(duplicateRes.body.success).toBe(true);
      expect(duplicateRes.body.isExisting).toBe(true);
      expect(duplicateRes.body.message).toContain('đã có');
    });

    it('từ chối thêm khách hàng có SĐT thuộc khu vực shipper không được phân công (403)', async () => {
      // KH_004 (0988000004) thuộc AREA_2_ID (Thủ Đức, không thuộc Shipper A)
      // Thêm trước KH_004 vào AREA_2_ID nếu chưa có
      await testPool.query(
        `INSERT INTO customers (id, customer_code, full_name, phone_number, address_text, area_id)
         VALUES ('c0000000-0000-0000-0000-000000000099', 'KH_AREA2_TEST', 'Khách Khu Vực 2', '0988999999', 'Địa chỉ KV2', $1)
         ON CONFLICT (phone_number) DO NOTHING`,
        [AREA_2_ID]
      );

      const shiftRes = await testPool.query(
        `INSERT INTO shifts (shift_code, work_date, shipper_id, status)
         VALUES ($1, CURRENT_DATE, $2, 'PREPARING')
         RETURNING id`,
        [`SHF-TEST-FORBIDDEN-${Date.now()}`, SHIPPER_A_ID]
      );
      const testShiftId = shiftRes.rows[0].id;

      const req: any = {
        params: { id: testShiftId },
        body: {
          phoneNumber: '0988999999',
        },
        user: {
          userId: SHIPPER_A_ID,
          roleName: 'SHIPPER',
          assignedAreaIds: [AREA_1_ID],
        },
      };
      const res = createMockResponse();

      await addPointToShift(req, res);

      expect(res.statusCode).toBe(403);
      expect(res.body.success).toBe(false);
      expect(res.body.message).toContain('Khách hàng này thuộc khu vực bạn không được phân công phụ trách');
    });
  });
});
