import { Pool } from 'pg';
import dotenv from 'dotenv';

dotenv.config();

export const PRODUCTION_DB_NAME = 'delivery_db';
export const ISOLATED_TEST_DB_NAME = 'test_isolated_seed_db';

/**
 * Chốt chặn bảo vệ CSDL kiểm thử (Database Test Isolation Guardrail).
 * Nếu phát hiện đang chạy trong môi trường kiểm thử (NODE_ENV=test hoặc IS_INTEGRATION_TEST=true hoặc JEST_WORKER_ID),
 * TUYỆT ĐỐI KHÔNG cho phép kết nối đến CSDL chính 'delivery_db'.
 */
export function assertSafeDatabaseForTests(targetDb?: string): void {
  const isTestEnvironment =
    process.env.NODE_ENV === 'test' ||
    process.env.IS_INTEGRATION_TEST === 'true' ||
    Boolean(process.env.JEST_WORKER_ID);

  const db = targetDb || process.env.DB_NAME || PRODUCTION_DB_NAME;

  if (isTestEnvironment && db === PRODUCTION_DB_NAME) {
    throw new Error(
      `[CRITICAL GUARDRAIL BLOCKED]: TỪ CHỐI KẾT NỐI VÀ CHẠY TEST TRÊN CSDL CHÍNH!\n` +
      `Hệ thống phát hiện đang chạy trong môi trường kiểm thử (NODE_ENV=${process.env.NODE_ENV || 'test'}), ` +
      `nhưng CSDL đích lại là '${PRODUCTION_DB_NAME}'.\n` +
      `Quy tắc bảo vệ dữ liệu: Mọi test tích hợp có ghi/sửa dữ liệu PHẢI chạy trên DB riêng (như DB_NAME=${ISOLATED_TEST_DB_NAME}).\n` +
      `Vui lòng thiết lập DB_NAME=${ISOLATED_TEST_DB_NAME} hoặc chạy lệnh: npm run test:setup-db && npm run test:integration`
    );
  }
}

const currentDbName = process.env.DB_NAME || PRODUCTION_DB_NAME;

export const pool = new Pool({
  host: process.env.DB_HOST || 'localhost',
  port: parseInt(process.env.DB_PORT || '5432'),
  database: currentDbName,
  user: process.env.DB_USER || 'postgres',
  password: process.env.DB_PASSWORD || 'postgres',
  max: 20,
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 5000,
});

// Guard: Bất kỳ lệnh connect hoặc query nào khi chạy test với delivery_db đều bị từ chối
const originalPoolConnect = pool.connect.bind(pool);
pool.connect = ((callback?: any) => {
  assertSafeDatabaseForTests(process.env.DB_NAME || (pool.options as any)?.database || PRODUCTION_DB_NAME);
  return originalPoolConnect(callback);
}) as any;

export const query = (text: string, params?: any[]) => {
  assertSafeDatabaseForTests(process.env.DB_NAME || (pool.options as any)?.database || PRODUCTION_DB_NAME);
  return pool.query(text, params);
};

