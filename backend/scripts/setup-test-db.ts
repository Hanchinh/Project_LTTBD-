import { Client } from 'pg';
import fs from 'fs';
import path from 'path';
import dotenv from 'dotenv';

dotenv.config();

const DB_HOST = process.env.DB_HOST || 'localhost';
const DB_PORT = parseInt(process.env.DB_PORT || '5432');
const DB_USER = process.env.DB_USER || 'postgres';
const DB_PASSWORD = process.env.DB_PASSWORD || 'postgres';
const TEST_DB_NAME = 'test_isolated_seed_db';

const INIT_DB_DIR = path.resolve(__dirname, '../../init-db');

const SQL_FILES = [
  '01-init-db.sql',
  '02-add-photo-and-fix-history.sql',
  '03-seed-demo-data.sql',
  '04-create-shifts-and-delivery-points.sql',
  '05-add-customers-updated-at.sql',
  '06-create-customer-photos.sql',
  '07-add-shift-name.sql',
  '08-create-data-shares.sql',
];

export async function setupIsolatedTestDatabase(): Promise<void> {
  console.log(`[TEST-DB-SETUP] Đang kết nối tới PostgreSQL (${DB_HOST}:${DB_PORT})...`);

  // 1. Kết nối vào database quản trị 'postgres' để khởi tạo CSDL test
  const adminClient = new Client({
    host: DB_HOST,
    port: DB_PORT,
    user: DB_USER,
    password: DB_PASSWORD,
    database: 'postgres',
  });

  try {
    await adminClient.connect();

    // Ngắt các kết nối đang mở vào test_isolated_seed_db nếu có
    await adminClient.query(`
      SELECT pg_terminate_backend(pid)
      FROM pg_stat_activity
      WHERE datname = $1 AND pid <> pg_backend_pid();
    `, [TEST_DB_NAME]);

    // Xóa database cũ nếu tồn tại
    console.log(`[TEST-DB-SETUP] Làm sạch CSDL '${TEST_DB_NAME}' cũ...`);
    await adminClient.query(`DROP DATABASE IF EXISTS ${TEST_DB_NAME};`);

    // Tạo mới CSDL test độc lập
    console.log(`[TEST-DB-SETUP] Tạo mới CSDL '${TEST_DB_NAME}'...`);
    await adminClient.query(`CREATE DATABASE ${TEST_DB_NAME};`);
  } finally {
    await adminClient.end();
  }

  // 2. Kết nối trực tiếp vào test_isolated_seed_db để chạy migration & nạp seed
  const testDbClient = new Client({
    host: DB_HOST,
    port: DB_PORT,
    user: DB_USER,
    password: DB_PASSWORD,
    database: TEST_DB_NAME,
  });

  try {
    await testDbClient.connect();
    console.log(`[TEST-DB-SETUP] Đang nạp schema PostGIS và seed ban đầu vào '${TEST_DB_NAME}'...`);

    for (const sqlFile of SQL_FILES) {
      const filePath = path.join(INIT_DB_DIR, sqlFile);
      if (fs.existsSync(filePath)) {
        console.log(`[TEST-DB-SETUP] -> Thực thi ${sqlFile}...`);
        const sqlContent = fs.readFileSync(filePath, 'utf-8');
        await testDbClient.query(sqlContent);
      } else {
        console.warn(`[TEST-DB-SETUP] Cảnh báo: Không tìm thấy ${filePath}`);
      }
    }

    // 3. Kiểm tra tính sẵn sàng của PostGIS và dữ liệu
    const checkRes = await testDbClient.query(`
      SELECT 
        (SELECT COUNT(*) FROM customers) AS customers_count,
        (SELECT COUNT(*) FROM saved_locations) AS locations_count,
        (SELECT COUNT(*) FROM shifts) AS shifts_count,
        (SELECT COUNT(*) FROM customer_photos) AS photos_count,
        (SELECT PostGIS_Version()) AS postgis_ver;
    `);

    const { customers_count, locations_count, shifts_count, photos_count, postgis_ver } = checkRes.rows[0];
    console.log(`[TEST-DB-SETUP] THÀNH CÔNG!`);
    console.log(`  - PostGIS Version: ${postgis_ver}`);
    console.log(`  - Khách hàng (Customers): ${customers_count}`);
    console.log(`  - Vị trí đã lưu (Saved Locations): ${locations_count}`);
    console.log(`  - Ca làm việc (Shifts): ${shifts_count}`);
    console.log(`  - Ảnh khách hàng (Customer Photos): ${photos_count}`);
    console.log(`[TEST-DB-SETUP] CSDL '${TEST_DB_NAME}' đã sẵn sàng cho kiểm thử tích hợp!`);
  } finally {
    await testDbClient.end();
  }
}

if (require.main === module) {
  setupIsolatedTestDatabase()
    .then(() => process.exit(0))
    .catch((err) => {
      console.error(`[TEST-DB-SETUP ERROR]:`, err);
      process.exit(1);
    });
}
