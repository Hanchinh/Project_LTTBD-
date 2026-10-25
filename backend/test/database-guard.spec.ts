import { assertSafeDatabaseForTests, PRODUCTION_DB_NAME, ISOLATED_TEST_DB_NAME } from '../src/db';
import { Client } from 'pg';

describe('TASK: FIX-TEST-DATA-011C - Database Test Isolation Guardrail Tests', () => {
  const originalEnv = process.env;

  beforeEach(() => {
    process.env = { ...originalEnv };
  });

  afterAll(() => {
    process.env = originalEnv;
  });

  describe('assertSafeDatabaseForTests Guardrail', () => {
    it('should REJECT and THROW loud error when targetDb is delivery_db in test environment', () => {
      process.env.NODE_ENV = 'test';
      delete process.env.DB_NAME;

      expect(() => {
        assertSafeDatabaseForTests(PRODUCTION_DB_NAME);
      }).toThrow(/\[CRITICAL GUARDRAIL BLOCKED\]: TỪ CHỐI KẾT NỐI VÀ CHẠY TEST TRÊN CSDL CHÍNH/);
    });

    it('should REJECT and THROW when targetDb is not provided and process.env.DB_NAME defaults to delivery_db', () => {
      process.env.NODE_ENV = 'test';
      delete process.env.DB_NAME;

      expect(() => {
        assertSafeDatabaseForTests();
      }).toThrow(/TỪ CHỐI KẾT NỐI VÀ CHẠY TEST TRÊN CSDL CHÍNH/);
    });

    it('should REJECT and THROW when IS_INTEGRATION_TEST=true and targetDb is delivery_db', () => {
      process.env.NODE_ENV = 'development';
      process.env.IS_INTEGRATION_TEST = 'true';

      expect(() => {
        assertSafeDatabaseForTests('delivery_db');
      }).toThrow(/\[CRITICAL GUARDRAIL BLOCKED\]/);
    });

    it('should ALLOW execution when targetDb is test_isolated_seed_db', () => {
      process.env.NODE_ENV = 'test';
      process.env.DB_NAME = ISOLATED_TEST_DB_NAME;

      expect(() => {
        assertSafeDatabaseForTests(ISOLATED_TEST_DB_NAME);
      }).not.toThrow();
    });

    it('should ALLOW execution on any custom isolated test database name', () => {
      process.env.NODE_ENV = 'test';
      const customTestDb = 'temp_test_db_runner_123';

      expect(() => {
        assertSafeDatabaseForTests(customTestDb);
      }).not.toThrow();
    });
  });

  describe('Isolated Test DB Connection Verification', () => {
    it('should be able to connect safely to test_isolated_seed_db without touching delivery_db', async () => {
      const client = new Client({
        host: process.env.DB_HOST || 'localhost',
        port: parseInt(process.env.DB_PORT || '5432'),
        user: process.env.DB_USER || 'postgres',
        password: process.env.DB_PASSWORD || 'postgres',
        database: ISOLATED_TEST_DB_NAME,
      });

      await client.connect();

      // Query current database name to ensure we are 100% on test_isolated_seed_db
      const res = await client.query('SELECT current_database();');
      expect(res.rows[0].current_database).toBe(ISOLATED_TEST_DB_NAME);
      expect(res.rows[0].current_database).not.toBe(PRODUCTION_DB_NAME);

      // Verify seed data exists in isolated test DB
      const countRes = await client.query('SELECT COUNT(*)::int AS count FROM customers;');
      expect(countRes.rows[0].count).toBeGreaterThan(0);

      await client.end();
    });
  });
});
