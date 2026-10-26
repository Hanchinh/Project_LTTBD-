process.env.NODE_ENV = 'test';
process.env.DB_NAME = 'test_isolated_seed_db';
process.env.IS_INTEGRATION_TEST = 'true';

import { Pool } from 'pg';
import { pool, ISOLATED_TEST_DB_NAME } from '../src/db';
import { setupIsolatedTestDatabase } from '../scripts/setup-test-db';
import { createBulkCustomers } from '../src/controllers/customers.controller';

describe('TASK: DIRECTORY-BULK-SHIFT-NAME-BLACK-BUTTONS-022A - Backend Bulk Customer Integration Tests', () => {
  let testPool: Pool;

  const SHIPPER_ID = 'd0000000-0000-0000-0000-000000000001'; // Shipper A
  const AREA_1_ID = 'b0000000-0000-0000-0000-000000000001';
  const AREA_2_ID = 'b0000000-0000-0000-0000-000000000002';
  const AREA_OTHER_ID = 'b0000000-0000-0000-0000-000000000099';

  const existingPhoneVerified = '0901111222';
  const existingPhoneTemporary = '0903333444';
  const existingPhoneNoLocation = '0905555666';
  const existingPhoneOutOfArea = '0907777888';

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

    // 1. Tạo khu vực ngoài AREA_OTHER_ID
    await testPool.query(
      `INSERT INTO areas (id, code, name)
       VALUES ($1, 'AREA_OTHER_99', 'Khu Vực Ngoài')
       ON CONFLICT (id) DO NOTHING`,
      [AREA_OTHER_ID]
    );

    // 2. Khách 1: Đã xác minh (VERIFIED) thuộc AREA_1_ID
    const c1 = await testPool.query(
      `INSERT INTO customers (customer_code, phone_number, full_name, address_text, area_id)
       VALUES ('CUST-BULK-VER', $1, 'Khách Đã Xác Minh', '123 Nguyễn Huệ', $2)
       RETURNING id`,
      [existingPhoneVerified, AREA_1_ID]
    );
    await testPool.query(
      `INSERT INTO saved_locations (customer_id, latitude, longitude, geom, gps_accuracy, identification_notes)
       VALUES ($1, 10.776, 106.700, ST_SetSRID(ST_MakePoint(106.700, 10.776), 4326), 5.0, 'Cổng sắt màu xanh')`,
      [c1.rows[0].id]
    );

    // 3. Khách 2: Vị trí tạm (TEMPORARY) trong ca đang mở của SHIPPER_ID
    const c2 = await testPool.query(
      `INSERT INTO customers (customer_code, phone_number, full_name, address_text, area_id)
       VALUES ('CUST-BULK-TEMP', $1, 'Khách Ghim Tạm', '456 Lê Lợi', $2)
       RETURNING id`,
      [existingPhoneTemporary, AREA_1_ID]
    );
    const s1 = await testPool.query(
      `INSERT INTO shifts (shift_code, shift_name, shipper_id, work_date, status)
       VALUES ('SHF-TEMP-022A', 'Ca Test Tạm 022A', $1, CURRENT_DATE, 'IN_PROGRESS')
       RETURNING id`,
      [SHIPPER_ID]
    );
    await testPool.query(
      `INSERT INTO shift_delivery_points (shift_id, customer_id, delivery_order_index, location_status, latitude, longitude, geom)
       VALUES ($1, $2, 1, 'TEMPORARY', 10.777, 106.701, ST_SetSRID(ST_MakePoint(106.701, 10.777), 4326))`,
      [s1.rows[0].id, c2.rows[0].id]
    );

    // 4. Khách 3: Chưa có vị trí (NO_LOCATION) thuộc AREA_1_ID
    await testPool.query(
      `INSERT INTO customers (customer_code, phone_number, full_name, address_text, area_id)
       VALUES ('CUST-BULK-NOLOC', $1, 'Khách Chưa Có Vị Trí', '789 Hàm Nghi', $2)`,
      [existingPhoneNoLocation, AREA_1_ID]
    );

    // 5. Khách 4: Thuộc khu vực ngoài AREA_OTHER_ID mà Shipper không phụ trách
    await testPool.query(
      `INSERT INTO customers (customer_code, phone_number, full_name, address_text, area_id)
       VALUES ('CUST-BULK-OUT', $1, 'Khách Ngoài Khu Vực', '999 Xa Lộ', $2)`,
      [existingPhoneOutOfArea, AREA_OTHER_ID]
    );
  });

  afterAll(async () => {
    if (testPool) {
      await testPool.end();
    }
    await pool.end();
  });

  test('1. Tách số nhiều dạng, lọc trùng, tạo mới và phân loại 3 nhóm chính xác', async () => {
    const rawText = `
      0901 111 222
      +84 903.333.444, 0905-555-666;
      0988 123 456
      84988123456
      0988 000 999
      invalid-phone-abc
      0123
    `;

    const req: any = {
      user: {
        userId: SHIPPER_ID,
        roleName: 'SHIPPER',
        assignedAreaIds: [AREA_1_ID],
      },
      body: {
        rawText,
      },
    };

    const res = createMockResponse();
    await createBulkCustomers(req, res);

    expect(res.statusCode).toBe(200);
    expect(res.body.success).toBe(true);

    const data = res.body.data;
    expect(data).toBeDefined();

    // 1. Nhóm created: các số mới (0988123456, 0988000999)
    // Chú ý: +84 988 123 456 và 84988123456 đã được lọc trùng chỉ còn 1 số
    expect(data.created.length).toBe(2);
    const createdPhones = data.created.map((c: any) => c.phoneNumber);
    expect(createdPhones).toContain('0988123456');
    expect(createdPhones).toContain('0988000999');
    expect(data.created[0].fullName).toBe(`Khách ${data.created[0].phoneNumber}`);
    expect(data.created[0].addressText).toBe('Chưa cập nhật địa chỉ');
    expect(data.created[0].areaId).toBe(AREA_1_ID);
    expect(data.created[0].locationState).toBe('NO_LOCATION');

    // 2. Nhóm alreadyExists: 3 số đã tồn tại (0901111222 VERIFIED, 0903333444 TEMPORARY, 0905555666 NO_LOCATION)
    expect(data.alreadyExists.length).toBe(3);
    const ver = data.alreadyExists.find((c: any) => c.phoneNumber === existingPhoneVerified);
    expect(ver).toBeDefined();
    expect(ver.locationState).toBe('VERIFIED');

    const temp = data.alreadyExists.find((c: any) => c.phoneNumber === existingPhoneTemporary);
    expect(temp).toBeDefined();
    expect(temp.locationState).toBe('TEMPORARY');

    const noLoc = data.alreadyExists.find((c: any) => c.phoneNumber === existingPhoneNoLocation);
    expect(noLoc).toBeDefined();
    expect(noLoc.locationState).toBe('NO_LOCATION');

    // 3. Nhóm rejected: invalid-phone-abc, 0123
    expect(data.rejected.length).toBe(2);
    expect(data.rejected.some((r: any) => r.phone === 'invalid-phone-abc')).toBe(true);
    expect(data.rejected.some((r: any) => r.phone === '0123')).toBe(true);

    // 4. Kiểm tra 1 dòng audit_logs duy nhất được ghi
    const auditRes = await testPool.query(
      `SELECT * FROM audit_logs WHERE action = 'BULK_CREATE_CUSTOMERS' ORDER BY created_at DESC LIMIT 1`
    );
    expect(auditRes.rows.length).toBe(1);
    const details = typeof auditRes.rows[0].details === 'string' ? JSON.parse(auditRes.rows[0].details) : auditRes.rows[0].details;
    expect(details.createdCount).toBe(2);
    expect(details.alreadyExistsCount).toBe(3);
    expect(details.rejectedCount).toBe(2);
  });

  test('2. Từ chối yêu cầu vượt quá 200 số điện thoại', async () => {
    const phones: string[] = [];
    for (let i = 0; i < 205; i++) {
      phones.push(`098${i.toString().padStart(7, '0')}`);
    }

    const req: any = {
      user: {
        userId: SHIPPER_ID,
        roleName: 'SHIPPER',
        assignedAreaIds: [AREA_1_ID],
      },
      body: {
        phones,
      },
    };

    const res = createMockResponse();
    await createBulkCustomers(req, res);

    expect(res.statusCode).toBe(400);
    expect(res.body.success).toBe(false);
    expect(res.body.message).toContain('Vượt quá giới hạn tối đa 200 số điện thoại');
  });

  test('3. Shipper nhiều khu vực bắt buộc chọn khu vực nếu chưa chọn', async () => {
    const req: any = {
      user: {
        userId: SHIPPER_ID,
        roleName: 'SHIPPER',
        assignedAreaIds: [AREA_1_ID, AREA_2_ID], // Nhiều hơn 1 khu vực
      },
      body: {
        rawText: '0977 111 222',
      },
    };

    const res = createMockResponse();
    await createBulkCustomers(req, res);

    expect(res.statusCode).toBe(400);
    expect(res.body.success).toBe(false);
    expect(res.body.requireAreaSelection).toBe(true);
    expect(res.body.message).toContain('Bạn phụ trách nhiều khu vực');
  });

  test('4. Từ chối khách hàng thuộc khu vực ngoài quyền phụ trách của shipper', async () => {
    const req: any = {
      user: {
        userId: SHIPPER_ID,
        roleName: 'SHIPPER',
        assignedAreaIds: [AREA_1_ID],
      },
      body: {
        rawText: existingPhoneOutOfArea, // Khách thuộc AREA_OTHER_ID
      },
    };

    const res = createMockResponse();
    await createBulkCustomers(req, res);

    expect(res.statusCode).toBe(200);
    expect(res.body.data.alreadyExists.length).toBe(0);
    expect(res.body.data.rejected.length).toBe(1);
    expect(res.body.data.rejected[0].reason).toBe('OUT_OF_AREA');
    expect(res.body.data.rejected[0].phone).toBe(existingPhoneOutOfArea);
  });
});
