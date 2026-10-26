process.env.NODE_ENV = 'test';
process.env.DB_NAME = 'test_isolated_seed_db';
process.env.IS_INTEGRATION_TEST = 'true';

import { Pool } from 'pg';
import { pool, ISOLATED_TEST_DB_NAME } from '../src/db';
import { setupIsolatedTestDatabase } from '../scripts/setup-test-db';
import { listCustomers } from '../src/controllers/customers.controller';

describe('TASK: UI-REDESIGN-DIRECTORY-AND-SHIFTS-021 - Backend Integration Tests', () => {
  let testPool: Pool;

  const SHIPPER_A_ID = 'd0000000-0000-0000-0000-000000000001';
  const SHIPPER_B_ID = 'd0000000-0000-0000-0000-000000000002';
  const AREA_1_ID = 'b0000000-0000-0000-0000-000000000001';
  const AREA_2_ID = 'b0000000-0000-0000-0000-000000000002';

  let customerVerifiedId: string;
  let customerTemporaryId: string;
  let customerNoLocationId: string;
  let customerOutsideAreaId: string;

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

    const now = Date.now();

    // 1. Khách 1 (VERIFIED): Có saved_locations VÀ có cả ghim tạm trong ca -> Vẫn phải là VERIFIED
    const cust1 = await testPool.query(
      `INSERT INTO customers (customer_code, phone_number, full_name, address_text, area_id)
       VALUES ($1, $2, 'Khách Đã Xác Minh 021', '123 Đường 1', $3)
       RETURNING id`,
      [`CUST-VER-${now}`, `0901${now.toString().slice(-6)}`, AREA_1_ID]
    );
    customerVerifiedId = cust1.rows[0].id;

    // Gán saved_locations
    await testPool.query(
      `INSERT INTO saved_locations (customer_id, latitude, longitude, geom, identification_notes, created_by)
       VALUES ($1, 10.776, 106.700, ST_SetSRID(ST_MakePoint(106.700, 10.776), 4326), 'Cổng xanh', $2)`,
      [customerVerifiedId, SHIPPER_A_ID]
    );

    // Tạo ca cho Shipper A
    const shiftA = await testPool.query(
      `INSERT INTO shifts (shift_code, shift_name, work_date, shipper_id, status)
       VALUES ($1, 'Ca Test Shipper A 021', CURRENT_DATE, $2, 'PREPARING')
       RETURNING id`,
      [`SHF-A-${now}`, SHIPPER_A_ID]
    );
    const shiftAId = shiftA.rows[0].id;

    // Khách 1 cũng có điểm ghim tạm trong ca A -> Kiểm tra quy tắc ưu tiên VERIFIED
    await testPool.query(
      `INSERT INTO shift_delivery_points (shift_id, customer_id, location_status, latitude, longitude, geom)
       VALUES ($1, $2, 'TEMPORARY', 10.778, 106.702, ST_SetSRID(ST_MakePoint(106.702, 10.778), 4326))`,
      [shiftAId, customerVerifiedId]
    );

    // 2. Khách 2 (TEMPORARY): KHÔNG có saved_locations nhưng có điểm TEMPORARY trong ca của Shipper A
    const cust2 = await testPool.query(
      `INSERT INTO customers (customer_code, phone_number, full_name, address_text, area_id)
       VALUES ($1, $2, 'Khách Ghim Tạm 021', '456 Đường 2', $3)
       RETURNING id`,
      [`CUST-TEMP-${now}`, `0902${now.toString().slice(-6)}`, AREA_1_ID]
    );
    customerTemporaryId = cust2.rows[0].id;

    await testPool.query(
      `INSERT INTO shift_delivery_points (shift_id, customer_id, location_status, latitude, longitude, geom)
       VALUES ($1, $2, 'TEMPORARY', 10.780, 106.705, ST_SetSRID(ST_MakePoint(106.705, 10.780), 4326))`,
      [shiftAId, customerTemporaryId]
    );

    // 3. Khách 3 (NO_LOCATION): KHÔNG có saved_locations và không có ghim tạm trong ca nào
    const cust3 = await testPool.query(
      `INSERT INTO customers (customer_code, phone_number, full_name, address_text, area_id)
       VALUES ($1, $2, 'Khách Chưa Có Vị Trí 021', '789 Đường 3', $3)
       RETURNING id`,
      [`CUST-NOLOC-${now}`, `0903${now.toString().slice(-6)}`, AREA_1_ID]
    );
    customerNoLocationId = cust3.rows[0].id;

    // 4. Khách 4: Nằm ngoài khu vực của Shipper A (thuộc AREA_2)
    const cust4 = await testPool.query(
      `INSERT INTO customers (customer_code, phone_number, full_name, address_text, area_id)
       VALUES ($1, $2, 'Khách Ngoài Vùng 021', '101 Đường 4', $3)
       RETURNING id`,
      [`CUST-OUT-${now}`, `0904${now.toString().slice(-6)}`, AREA_2_ID]
    );
    customerOutsideAreaId = cust4.rows[0].id;
  });

  afterAll(async () => {
    if (testPool) await testPool.end();
    await pool.end();
  });

  test('1. locationState phản ánh đúng 3 trường hợp và ưu tiên VERIFIED', async () => {
    const req: any = {
      user: {
        userId: SHIPPER_A_ID,
        roleName: 'SHIPPER',
        assignedAreaIds: [AREA_1_ID],
      },
      query: {},
    };
    const res = createMockResponse();

    await listCustomers(req, res);

    expect(res.statusCode).toBe(200);
    expect(res.body.success).toBe(true);
    const data = res.body.data;

    // Khách 1: có saved_locations và ghim tạm -> VERIFIED
    const c1 = data.find((c: any) => c.id === customerVerifiedId);
    expect(c1).toBeDefined();
    expect(c1.locationState).toBe('VERIFIED');
    expect(c1.locationStatus).toBe('VERIFIED');

    // Khách 2: không saved_locations, có ghim tạm trong ca Shipper A -> TEMPORARY
    const c2 = data.find((c: any) => c.id === customerTemporaryId);
    expect(c2).toBeDefined();
    expect(c2.locationState).toBe('TEMPORARY');
    expect(c2.locationStatus).toBe('TEMPORARY');

    // Khách 3: không có gì -> NO_LOCATION
    const c3 = data.find((c: any) => c.id === customerNoLocationId);
    expect(c3).toBeDefined();
    expect(c3.locationState).toBe('NO_LOCATION');
    expect(c3.locationStatus).toBe('NO_LOCATION');

    // Không thấy khách ngoài vùng phụ trách AREA_1
    const c4 = data.find((c: any) => c.id === customerOutsideAreaId);
    expect(c4).toBeUndefined();
  });

  test('2. Ghim tạm của shipper khác KHÔNG tính cho shipper hiện tại', async () => {
    // Shipper B phụ trách cả AREA_1 nhưng không có ca nào chứa Khách 2
    const req: any = {
      user: {
        userId: SHIPPER_B_ID,
        roleName: 'SHIPPER',
        assignedAreaIds: [AREA_1_ID],
      },
      query: {},
    };
    const res = createMockResponse();

    await listCustomers(req, res);

    expect(res.statusCode).toBe(200);
    const data = res.body.data;

    // Khách 2 đối với Shipper B phải là NO_LOCATION vì Shipper B không có ghim tạm cho khách này
    const c2 = data.find((c: any) => c.id === customerTemporaryId);
    expect(c2).toBeDefined();
    expect(c2.locationState).toBe('NO_LOCATION');

    // Khách 1 vẫn là VERIFIED vì saved_locations là của toàn hệ thống
    const c1 = data.find((c: any) => c.id === customerVerifiedId);
    expect(c1).toBeDefined();
    expect(c1.locationState).toBe('VERIFIED');
  });

  test('3. Số lượng counts theo từng tab khớp chính xác và hỗ trợ lọc', async () => {
    const req: any = {
      user: {
        userId: SHIPPER_A_ID,
        roleName: 'SHIPPER',
        assignedAreaIds: [AREA_1_ID],
      },
      query: {},
    };
    const res = createMockResponse();

    await listCustomers(req, res);

    expect(res.statusCode).toBe(200);
    const counts = res.body.counts;
    expect(counts).toBeDefined();
    expect(counts.total).toBeGreaterThanOrEqual(3);
    expect(counts.verified).toBeGreaterThanOrEqual(1);
    expect(counts.temporary).toBeGreaterThanOrEqual(1);
    expect(counts.noLocation).toBeGreaterThanOrEqual(1);
    expect(counts.total).toBe(counts.verified + counts.temporary + counts.noLocation);

    // Lọc theo tab TEMPORARY
    const reqTemp: any = {
      user: {
        userId: SHIPPER_A_ID,
        roleName: 'SHIPPER',
        assignedAreaIds: [AREA_1_ID],
      },
      query: { locationState: 'TEMPORARY' },
    };
    const resTemp = createMockResponse();
    await listCustomers(reqTemp, resTemp);

    expect(resTemp.statusCode).toBe(200);
    expect(resTemp.body.data.every((c: any) => c.locationState === 'TEMPORARY')).toBe(true);
    expect(resTemp.body.counts.total).toBe(counts.total); // Counts không bị mất khi lọc
  });

  test('4. Phân trang limit & offset hoạt động chính xác', async () => {
    const req: any = {
      user: {
        userId: SHIPPER_A_ID,
        roleName: 'SHIPPER',
        assignedAreaIds: [AREA_1_ID],
      },
      query: { limit: '2', offset: '0' },
    };
    const res = createMockResponse();

    await listCustomers(req, res);

    expect(res.statusCode).toBe(200);
    expect(res.body.data.length).toBeLessThanOrEqual(2);
    expect(res.body.pagination).toBeDefined();
    expect(res.body.pagination.limit).toBe(2);
    expect(res.body.pagination.offset).toBe(0);
    expect(res.body.pagination.hasMore).toBe(true);
  });
});
