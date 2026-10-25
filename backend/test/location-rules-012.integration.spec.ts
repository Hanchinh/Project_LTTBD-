process.env.NODE_ENV = 'test';
process.env.DB_NAME = 'test_isolated_seed_db';
process.env.IS_INTEGRATION_TEST = 'true';

import { Pool } from 'pg';
import { pool, ISOLATED_TEST_DB_NAME } from '../src/db';
import { saveOrUpdateCustomerLocation, deleteCustomerLocation } from '../src/controllers/locations.controller';
import { verifyPointLocation } from '../src/controllers/shifts.controller';
import { setupIsolatedTestDatabase } from '../scripts/setup-test-db';

describe('TASK: LOCATION-RULES-012 & 012B - Location Verification, Deletion & Strict Shipper Isolation Tests', () => {
  let testPool: Pool;

  const SHIPPER_A_ID = 'd0000000-0000-0000-0000-000000000001'; // Shipper A (Area 1)
  const SHIPPER_B_ID = 'd0000000-0000-0000-0000-000000000002'; // Shipper B (Area 2)
  const CUSTOMER_KH002_ID = 'c0000000-0000-0000-0000-000000000002'; // KH_002 (Area 1, initially NO_LOCATION)
  const CUSTOMER_KH004_ID = 'c0000000-0000-0000-0000-000000000004'; // KH_004 (Area 2, initially VERIFIED by Shipper B)

  beforeAll(async () => {
    // 1. Initialize test database with PostGIS schema & seeds
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

  // Helper mock response
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

  describe('Rule 4: Standard Verification Flow (Danh bạ -> Hồ sơ -> Tâm ngắm -> Xác nhận)', () => {
    let createdShiftId: string;
    let shiftPointId: string;

    beforeEach(async () => {
      const uniqueShiftCode = `SHF-012A-${Date.now()}-${Math.floor(Math.random() * 10000)}`;

      // Create a test shift for Shipper A in test_isolated_seed_db
      const shiftRes = await testPool.query(
        `INSERT INTO shifts (shift_code, work_date, shipper_id, status)
         VALUES ($1, CURRENT_DATE, $2, 'PREPARING')
         RETURNING id`,
        [uniqueShiftCode, SHIPPER_A_ID]
      );
      createdShiftId = shiftRes.rows[0].id;

      // Add customer KH_002 to this shift with NO_LOCATION
      const pointRes = await testPool.query(
        `INSERT INTO shift_delivery_points (shift_id, customer_id, location_status)
         VALUES ($1, $2, 'NO_LOCATION')
         RETURNING id`,
        [createdShiftId, CUSTOMER_KH002_ID]
      );
      shiftPointId = pointRes.rows[0].id;
    });

    it('should save location to saved_locations, auto-sync active shift delivery points to VERIFIED, and record updatedShiftPointsCount in audit_logs', async () => {
      const req: any = {
        params: { customerId: CUSTOMER_KH002_ID },
        body: {
          latitude: 10.843350,
          longitude: 106.819950,
          gpsAccuracy: 3.5,
          identificationNotes: 'Nhà 2 tầng cổng trắng có cây hoa sứ',
        },
        user: {
          userId: SHIPPER_A_ID,
          roleName: 'SHIPPER',
        },
      };

      const res = createMockResponse();

      await saveOrUpdateCustomerLocation(req, res);

      expect(res.statusCode).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.data.updatedShiftPointsCount).toBeGreaterThanOrEqual(1);

      // Verify in saved_locations table
      const savedRes = await testPool.query(
        `SELECT latitude, longitude, gps_accuracy, identification_notes, created_by
         FROM saved_locations WHERE customer_id = $1`,
        [CUSTOMER_KH002_ID]
      );
      expect(savedRes.rows.length).toBe(1);
      expect(parseFloat(savedRes.rows[0].latitude)).toBeCloseTo(10.843350);
      expect(parseFloat(savedRes.rows[0].longitude)).toBeCloseTo(106.819950);
      expect(savedRes.rows[0].created_by).toBe(SHIPPER_A_ID);

      // Verify shift_delivery_points was automatically synchronized to VERIFIED
      const pointCheck = await testPool.query(
        `SELECT location_status, latitude, longitude, identification_notes
         FROM shift_delivery_points WHERE id = $1`,
        [shiftPointId]
      );
      expect(pointCheck.rows[0].location_status).toBe('VERIFIED');
      expect(parseFloat(pointCheck.rows[0].latitude)).toBeCloseTo(10.843350);
      expect(parseFloat(pointCheck.rows[0].longitude)).toBeCloseTo(106.819950);

      // Verify audit_logs recorded updatedShiftPointsCount
      const auditRes = await testPool.query(
        `SELECT action, details FROM audit_logs
         WHERE entity = 'SAVED_LOCATION' AND user_id = $1
         ORDER BY created_at DESC LIMIT 1`,
        [SHIPPER_A_ID]
      );
      expect(auditRes.rows[0].action).toBe('CREATE_LOCATION');
      const details = typeof auditRes.rows[0].details === 'string'
        ? JSON.parse(auditRes.rows[0].details)
        : auditRes.rows[0].details;
      expect(details.updatedShiftPointsCount).toBeGreaterThanOrEqual(1);
    });

    it('should NOT touch Shipper B active shifts when Shipper A verifies a customer location', async () => {
      // Create an active shift for Shipper B containing the same customer KH_002
      const shiftBCode = `SHF-012B-ISO-${Date.now()}-${Math.floor(Math.random() * 10000)}`;
      const shiftBRes = await testPool.query(
        `INSERT INTO shifts (shift_code, work_date, shipper_id, status)
         VALUES ($1, CURRENT_DATE, $2, 'PREPARING')
         RETURNING id`,
        [shiftBCode, SHIPPER_B_ID]
      );
      const shiftBId = shiftBRes.rows[0].id;

      const pointBRes = await testPool.query(
        `INSERT INTO shift_delivery_points (shift_id, customer_id, location_status)
         VALUES ($1, $2, 'NO_LOCATION')
         RETURNING id`,
        [shiftBId, CUSTOMER_KH002_ID]
      );
      const pointIdB = pointBRes.rows[0].id;

      // Shipper A verifies location for KH_002 via directory controller
      const req: any = {
        params: { customerId: CUSTOMER_KH002_ID },
        body: {
          latitude: 10.844000,
          longitude: 106.820000,
          gpsAccuracy: 4.0,
          identificationNotes: 'Cổng xanh lá đối diện trường học',
        },
        user: {
          userId: SHIPPER_A_ID,
          roleName: 'SHIPPER',
        },
      };

      const res = createMockResponse();
      await saveOrUpdateCustomerLocation(req, res);

      expect(res.statusCode).toBe(200);

      // Shipper A's shift delivery point must be VERIFIED
      const checkPointA = await testPool.query(
        `SELECT location_status, latitude, longitude FROM shift_delivery_points WHERE id = $1`,
        [shiftPointId]
      );
      expect(checkPointA.rows[0].location_status).toBe('VERIFIED');
      expect(parseFloat(checkPointA.rows[0].latitude)).toBeCloseTo(10.844000);

      // Shipper B's shift delivery point must be UNTOUCHED (still NO_LOCATION with null coordinates)
      const checkPointB = await testPool.query(
        `SELECT location_status, latitude, longitude FROM shift_delivery_points WHERE id = $1`,
        [pointIdB]
      );
      expect(checkPointB.rows[0].location_status).toBe('NO_LOCATION');
      expect(checkPointB.rows[0].latitude).toBeNull();
      expect(checkPointB.rows[0].longitude).toBeNull();
    });
  });

  describe('Rule 5: Shipper DELETE Endpoint for Saved Location', () => {
    let shiftId: string;
    let pointId: string;

    beforeEach(async () => {
      // Ensure KH_002 has a saved location created by Shipper A
      const savedRes = await testPool.query(
        `INSERT INTO saved_locations
         (customer_id, geom, latitude, longitude, gps_accuracy, identification_notes, created_by, updated_by)
         VALUES ($1, ST_SetSRID(ST_MakePoint(106.819950, 10.843350), 4326), 10.843350, 106.819950, 3.5, 'Nhà cổng trắng', $2, $2)
         ON CONFLICT (customer_id) DO UPDATE SET created_by = $2, updated_by = $2
         RETURNING id`,
        [CUSTOMER_KH002_ID, SHIPPER_A_ID]
      );
      const savedLocId = savedRes.rows[0].id;

      // Seed an existing location_history record linked to this saved_location
      await testPool.query(
        `INSERT INTO location_history
         (saved_location_id, customer_id, geom, latitude, longitude, gps_accuracy, identification_notes, changed_by, change_reason)
         VALUES ($1, $2, ST_SetSRID(ST_MakePoint(106.819950, 10.843350), 4326), 10.843350, 106.819950, 3.5, 'Lịch sử ban đầu', $3, 'Khởi tạo')`,
        [savedLocId, CUSTOMER_KH002_ID, SHIPPER_A_ID]
      );

      const uniqueShiftCode = `SHF-012B-${Date.now()}-${Math.floor(Math.random() * 10000)}`;

      // Create an active shift with KH_002 currently VERIFIED
      const shiftRes = await testPool.query(
        `INSERT INTO shifts (shift_code, work_date, shipper_id, status)
         VALUES ($1, CURRENT_DATE, $2, 'PREPARING')
         RETURNING id`,
        [uniqueShiftCode, SHIPPER_A_ID]
      );
      shiftId = shiftRes.rows[0].id;

      const pointRes = await testPool.query(
        `INSERT INTO shift_delivery_points (shift_id, customer_id, location_status, latitude, longitude)
         VALUES ($1, $2, 'VERIFIED', 10.843350, 106.819950)
         RETURNING id`,
        [shiftId, CUSTOMER_KH002_ID]
      );
      pointId = pointRes.rows[0].id;
    });

    it('should REJECT deletion with 403 Forbidden if a shipper tries to delete a location created by another shipper or in another area', async () => {
      // Shipper A tries to delete KH_004 (created by Shipper B in Area 2)
      const req: any = {
        params: { customerId: CUSTOMER_KH004_ID },
        user: {
          userId: SHIPPER_A_ID,
          roleName: 'SHIPPER',
        },
      };

      const res = createMockResponse();
      await deleteCustomerLocation(req, res);

      expect(res.statusCode).toBe(403);
      expect(res.body.success).toBe(false);
      expect(res.body.message).toMatch(/Bạn chỉ có quyền xóa vị trí do chính mình tạo|không thuộc khu vực/);

      // Ensure saved_locations of KH_004 was NOT deleted
      const checkRes = await testPool.query(
        `SELECT 1 FROM saved_locations WHERE customer_id = $1`,
        [CUSTOMER_KH004_ID]
      );
      expect(checkRes.rows.length).toBe(1);
    });

    it('should REJECT deletion with 403 Forbidden if shipper tries to delete a location outside their assigned area (even if created_by matches)', async () => {
      // Artificially set created_by to SHIPPER_A_ID for KH_004 (which is in Area 2, while Shipper A only manages Area 1)
      await testPool.query(
        `UPDATE saved_locations SET created_by = $1, updated_by = $1 WHERE customer_id = $2`,
        [SHIPPER_A_ID, CUSTOMER_KH004_ID]
      );

      const req: any = {
        params: { customerId: CUSTOMER_KH004_ID },
        user: {
          userId: SHIPPER_A_ID,
          roleName: 'SHIPPER',
        },
      };

      const res = createMockResponse();
      await deleteCustomerLocation(req, res);

      expect(res.statusCode).toBe(403);
      expect(res.body.success).toBe(false);
      expect(res.body.message).toMatch(/không thuộc khu vực bạn được phân công phụ trách/);

      // Location must remain intact
      const checkRes = await testPool.query(
        `SELECT 1 FROM saved_locations WHERE customer_id = $1`,
        [CUSTOMER_KH004_ID]
      );
      expect(checkRes.rows.length).toBe(1);
    });

    it('should ALLOW deletion when shipper owns the location and belongs to the area, preserving history and reverting active shift points to NO_LOCATION', async () => {
      const req: any = {
        params: { customerId: CUSTOMER_KH002_ID },
        user: {
          userId: SHIPPER_A_ID,
          roleName: 'SHIPPER',
        },
      };

      const res = createMockResponse();
      await deleteCustomerLocation(req, res);

      expect(res.statusCode).toBe(200);
      expect(res.body.data.revertedShiftPointsCount).toBeGreaterThanOrEqual(1);

      // 1. Verify saved_locations record is deleted
      const savedRes = await testPool.query(
        `SELECT 1 FROM saved_locations WHERE customer_id = $1`,
        [CUSTOMER_KH002_ID]
      );
      expect(savedRes.rows.length).toBe(0);

      // 2. Verify shift_delivery_points reverted to NO_LOCATION with null coordinates
      const pointCheck = await testPool.query(
        `SELECT location_status, latitude, longitude
         FROM shift_delivery_points WHERE id = $1`,
        [pointId]
      );
      expect(pointCheck.rows[0].location_status).toBe('NO_LOCATION');
      expect(pointCheck.rows[0].latitude).toBeNull();
      expect(pointCheck.rows[0].longitude).toBeNull();

      // 3. Verify location_history was preserved (saved_location_id was unlinked)
      const historyCheck = await testPool.query(
        `SELECT COUNT(*) AS count, saved_location_id FROM location_history WHERE customer_id = $1 GROUP BY saved_location_id`,
        [CUSTOMER_KH002_ID]
      );
      expect(parseInt(historyCheck.rows[0].count)).toBeGreaterThanOrEqual(1);
      expect(historyCheck.rows[0].saved_location_id).toBeNull();

      // 4. Verify audit_logs recorded DELETE_LOCATION
      const auditRes = await testPool.query(
        `SELECT action, details FROM audit_logs
         WHERE entity = 'SAVED_LOCATION' AND action = 'DELETE_LOCATION' AND user_id = $1
         ORDER BY created_at DESC LIMIT 1`,
        [SHIPPER_A_ID]
      );
      expect(auditRes.rows.length).toBe(1);
      const details = typeof auditRes.rows[0].details === 'string'
        ? JSON.parse(auditRes.rows[0].details)
        : auditRes.rows[0].details;
      expect(details.revertedShiftPointsCount).toBeGreaterThanOrEqual(1);
    });

    it('should keep TEMPORARY delivery points untouched when deleting saved location', async () => {
      // Set the point for customer KH_002 in Shipper A's shift to TEMPORARY status
      await testPool.query(
        `UPDATE shift_delivery_points
         SET location_status = 'TEMPORARY',
             latitude = 10.841500,
             longitude = 106.812500,
             identification_notes = 'Ghim tạm đầu hẻm'
         WHERE id = $1`,
        [pointId]
      );

      const req: any = {
        params: { customerId: CUSTOMER_KH002_ID },
        user: {
          userId: SHIPPER_A_ID,
          roleName: 'SHIPPER',
        },
      };

      const res = createMockResponse();
      await deleteCustomerLocation(req, res);

      expect(res.statusCode).toBe(200);

      // Verify the TEMPORARY point was KEPT UNTOUCHED
      const tempPointCheck = await testPool.query(
        `SELECT location_status, latitude, longitude, identification_notes
         FROM shift_delivery_points WHERE id = $1`,
        [pointId]
      );
      expect(tempPointCheck.rows[0].location_status).toBe('TEMPORARY');
      expect(parseFloat(tempPointCheck.rows[0].latitude)).toBeCloseTo(10.841500);
      expect(parseFloat(tempPointCheck.rows[0].longitude)).toBeCloseTo(106.812500);
      expect(tempPointCheck.rows[0].identification_notes).toBe('Ghim tạm đầu hẻm');
    });
  });

  describe('Rule 3 & Deprecation of verifyPointLocation', () => {
    it('verifyPointLocation must return 410 Gone and refuse to write to saved_locations from shift flow', async () => {
      const req: any = {
        params: { id: 'dummy-shift-id', pointId: 'dummy-point-id' },
        body: { latitude: 10.8422, longitude: 106.8181 },
        user: { userId: SHIPPER_A_ID, roleName: 'SHIPPER' },
      };

      const res = createMockResponse();
      await verifyPointLocation(req, res);

      expect(res.statusCode).toBe(410);
      expect(res.body.success).toBe(false);
      expect(res.body.errorCode).toBe('ENDPOINT_GONE_USE_DIRECTORY_FLOW');
      expect(res.body.message).toMatch(/410 Gone/);
    });
  });
});
