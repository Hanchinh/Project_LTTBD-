process.env.NODE_ENV = 'test';
process.env.DB_NAME = 'test_isolated_seed_db';
process.env.IS_INTEGRATION_TEST = 'true';

import { Pool } from 'pg';
import { pool, ISOLATED_TEST_DB_NAME } from '../src/db';
import { setupIsolatedTestDatabase } from '../scripts/setup-test-db';
import {
  getCustomerPhotos,
  addCustomerPhoto,
  deleteCustomerPhoto,
} from '../src/controllers/customer-photos.controller';
import {
  listCustomers,
  getCustomerDetail,
} from '../src/controllers/customers.controller';

describe('TASK: PHOTO-SYNC-SHIFT-PICKER-BULK-016 - Photo Synchronization Integration Tests', () => {
  let testPool: Pool;

  const SHIPPER_A_ID = 'd0000000-0000-0000-0000-000000000001';
  const AREA_1_ID = 'b0000000-0000-0000-0000-000000000001';
  let targetCustomerId: string;
  let testShiftId: string;

  // Minimal valid PNG buffer
  const pngBuffer = Buffer.from([
    0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 0x00, 0x00, 0x00, 0x0d,
    0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
    0x08, 0x06, 0x00, 0x00, 0x00, 0x1f, 0x15, 0xc4, 0x89
  ]);
  const pngBase64 = `data:image/png;base64,${pngBuffer.toString('base64')}`;

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

    // Create a unique customer for photo sync test
    const code = `CUST-SYNC-${Date.now()}`;
    const custRes = await testPool.query(
      `INSERT INTO customers (customer_code, phone_number, full_name, address_text, area_id)
       VALUES ($1, $2, $3, $4, $5)
       RETURNING id`,
      [code, `0987${Date.now().toString().slice(-6)}`, 'Khách Test Sync 016', '123 Đường Test 016', AREA_1_ID]
    );
    targetCustomerId = custRes.rows[0].id;

    // Create a shift and add point for this customer (without saved location, e.g. NO_LOCATION)
    const shiftRes = await testPool.query(
      `INSERT INTO shifts (shift_code, shift_name, work_date, shipper_id, status)
       VALUES ($1, $2, CURRENT_DATE, $3, 'PREPARING')
       RETURNING id`,
      [`SHF-SYNC-${Date.now()}`, 'Ca Test Sync 016', SHIPPER_A_ID]
    );
    testShiftId = shiftRes.rows[0].id;

    await testPool.query(
      `INSERT INTO shift_delivery_points (shift_id, customer_id, location_status)
       VALUES ($1, $2, 'NO_LOCATION')`,
      [testShiftId, targetCustomerId]
    );
  });

  afterAll(async () => {
    if (testPool) {
      await testPool.end();
    }
    await pool.end();
  });

  it('1. Ban đầu khách chưa có ảnh: photoCount = 0 trong listCustomers và getCustomerDetail', async () => {
    const req: any = {
      user: { id: SHIPPER_A_ID, role: 'SHIPPER', areaId: AREA_1_ID },
      query: { search: 'Test Sync 016' },
      params: { id: targetCustomerId },
    };
    const resList = createMockResponse();
    await listCustomers(req, resList);
    expect(resList.statusCode).toBe(200);
    const found = resList.body.data.find((c: any) => c.id === targetCustomerId);
    expect(found).toBeDefined();
    expect(found.photoCount).toBe(0);
    expect(found.photos).toEqual([]);

    const resDetail = createMockResponse();
    await getCustomerDetail(req, resDetail);
    expect(resDetail.statusCode).toBe(200);
    expect(resDetail.body.data.photoCount).toBe(0);
    expect(resDetail.body.data.photos).toEqual([]);
  });

  it('2. Thêm ảnh qua addCustomerPhoto (từ thẻ điểm của ca): xuất hiện trong Danh bạ (listCustomers) và Hồ sơ (getCustomerDetail)', async () => {
    const addReq: any = {
      user: { id: SHIPPER_A_ID, role: 'SHIPPER', areaId: AREA_1_ID },
      params: { customerId: targetCustomerId },
      body: { imageBase64: pngBase64 },
    };
    const addRes = createMockResponse();
    await addCustomerPhoto(addReq, addRes);
    expect(addRes.statusCode).toBe(201);
    expect(addRes.body.success).toBe(true);
    const addedPhoto = addRes.body.data;
    expect(addedPhoto.id).toBeDefined();
    expect(addedPhoto.imageUrl).toBeDefined();

    // Kiểm tra Danh bạ (listCustomers)
    const listReq: any = {
      user: { id: SHIPPER_A_ID, role: 'SHIPPER', areaId: AREA_1_ID },
      query: { search: 'Test Sync 016' },
    };
    const listRes = createMockResponse();
    await listCustomers(listReq, listRes);
    expect(listRes.statusCode).toBe(200);
    const foundInList = listRes.body.data.find((c: any) => c.id === targetCustomerId);
    expect(foundInList).toBeDefined();
    expect(foundInList.photoCount).toBe(1);
    expect(foundInList.imageUrl).toBe(addedPhoto.imageUrl);
    expect(foundInList.photos.length).toBe(1);
    expect(foundInList.photos[0].id).toBe(addedPhoto.id);

    // Kiểm tra lọc hasPhoto=true
    const filterReq: any = {
      user: { id: SHIPPER_A_ID, role: 'SHIPPER', areaId: AREA_1_ID },
      query: { search: 'Test Sync 016', hasPhoto: 'true' },
    };
    const filterRes = createMockResponse();
    await listCustomers(filterReq, filterRes);
    expect(filterRes.statusCode).toBe(200);
    const matchFilter = filterRes.body.data.find((c: any) => c.id === targetCustomerId);
    expect(matchFilter).toBeDefined();

    // Kiểm tra Hồ sơ khách (getCustomerDetail)
    const detailReq: any = {
      user: { id: SHIPPER_A_ID, role: 'SHIPPER', areaId: AREA_1_ID },
      params: { id: targetCustomerId },
    };
    const detailRes = createMockResponse();
    await getCustomerDetail(detailReq, detailRes);
    expect(detailRes.statusCode).toBe(200);
    expect(detailRes.body.data.photoCount).toBe(1);
    expect(detailRes.body.data.photos.length).toBe(1);
    expect(detailRes.body.data.photos[0].id).toBe(addedPhoto.id);
  });

  it('3. Thêm ảnh thứ 2: photoCount = 2, imageUrl ưu tiên ảnh mới nhất', async () => {
    const addReq: any = {
      user: { id: SHIPPER_A_ID, role: 'SHIPPER', areaId: AREA_1_ID },
      params: { customerId: targetCustomerId },
      body: { imageBase64: pngBase64 },
    };
    const addRes = createMockResponse();
    await addCustomerPhoto(addReq, addRes);
    expect(addRes.statusCode).toBe(201);
    const secondPhoto = addRes.body.data;

    const detailReq: any = {
      user: { id: SHIPPER_A_ID, role: 'SHIPPER', areaId: AREA_1_ID },
      params: { id: targetCustomerId },
    };
    const detailRes = createMockResponse();
    await getCustomerDetail(detailReq, detailRes);
    expect(detailRes.statusCode).toBe(200);
    expect(detailRes.body.data.photoCount).toBe(2);
    expect(detailRes.body.data.photos.length).toBe(2);
    expect(detailRes.body.data.photos[0].id).toBe(secondPhoto.id);
  });

  it('4. Xóa mềm ảnh: biến mất khỏi getCustomerPhotos, listCustomers và getCustomerDetail', async () => {
    // Lấy danh sách ảnh hiện tại
    const getPhotosReq: any = {
      user: { id: SHIPPER_A_ID, role: 'SHIPPER', areaId: AREA_1_ID },
      params: { customerId: targetCustomerId },
    };
    const getPhotosRes = createMockResponse();
    await getCustomerPhotos(getPhotosReq, getPhotosRes);
    expect(getPhotosRes.statusCode).toBe(200);
    const photos = getPhotosRes.body.data;
    expect(photos.length).toBe(2);

    // Xóa ảnh đầu tiên
    const deleteReq1: any = {
      user: { id: SHIPPER_A_ID, role: 'SHIPPER', areaId: AREA_1_ID },
      params: { customerId: targetCustomerId, photoId: photos[0].id },
    };
    const deleteRes1 = createMockResponse();
    await deleteCustomerPhoto(deleteReq1, deleteRes1);
    expect(deleteRes1.statusCode).toBe(200);
    expect(deleteRes1.body.success).toBe(true);

    // Kiểm tra getCustomerPhotos còn 1 ảnh
    const afterDeleteRes = createMockResponse();
    await getCustomerPhotos(getPhotosReq, afterDeleteRes);
    expect(afterDeleteRes.body.data.length).toBe(1);
    expect(afterDeleteRes.body.data[0].id).toBe(photos[1].id);

    // Xóa ảnh còn lại
    const deleteReq2: any = {
      user: { id: SHIPPER_A_ID, role: 'SHIPPER', areaId: AREA_1_ID },
      params: { customerId: targetCustomerId, photoId: photos[1].id },
    };
    const deleteRes2 = createMockResponse();
    await deleteCustomerPhoto(deleteReq2, deleteRes2);
    expect(deleteRes2.statusCode).toBe(200);

    // Kiểm tra lại Danh bạ (listCustomers): photoCount trở về 0
    const listReq: any = {
      user: { id: SHIPPER_A_ID, role: 'SHIPPER', areaId: AREA_1_ID },
      query: { search: 'Test Sync 016' },
    };
    const listRes = createMockResponse();
    await listCustomers(listReq, listRes);
    const foundAfter = listRes.body.data.find((c: any) => c.id === targetCustomerId);
    expect(foundAfter.photoCount).toBe(0);
    expect(foundAfter.photos).toEqual([]);

    // Kiểm tra Hồ sơ (getCustomerDetail): photoCount = 0
    const detailReq: any = {
      user: { id: SHIPPER_A_ID, role: 'SHIPPER', areaId: AREA_1_ID },
      params: { id: targetCustomerId },
    };
    const detailRes = createMockResponse();
    await getCustomerDetail(detailReq, detailRes);
    expect(detailRes.body.data.photoCount).toBe(0);
    expect(detailRes.body.data.photos).toEqual([]);

    // Kiểm tra tính toàn vẹn kiểm toán (Audit Integrity): Record vẫn tồn tại trong CSDL với deleted_at IS NOT NULL
    const auditCheck = await testPool.query(
      `SELECT count(*)::int as count FROM customer_photos WHERE customer_id = $1 AND deleted_at IS NOT NULL`,
      [targetCustomerId]
    );
    expect(auditCheck.rows[0].count).toBe(2);
  });
});
