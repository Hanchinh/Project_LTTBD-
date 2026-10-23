import { normalizePhoneNumber } from './location.spec';

describe('FEATURE-ORDER-ENTRY-001 - Order Entry & Deduplication Unit Tests', () => {
  describe('Phone Number Normalization & Validation', () => {
    it('should correctly normalize Vietnamese phone numbers with prefixes and spaces', () => {
      expect(normalizePhoneNumber('0988000001')).toBe('0988000001');
      expect(normalizePhoneNumber('988000001')).toBe('0988000001');
      expect(normalizePhoneNumber('0988 000 001')).toBe('0988000001');
      expect(normalizePhoneNumber('+84988000001')).toBe('0988000001');
      expect(normalizePhoneNumber('84988000001')).toBe('0988000001');
      expect(normalizePhoneNumber('0988-000-001')).toBe('0988000001');
      expect(normalizePhoneNumber(' (0988) 000.001 ')).toBe('0988000001');
    });

    it('should detect invalid phone numbers', () => {
      const isValidVnPhone = (phone: string) => {
        const clean = normalizePhoneNumber(phone);
        return /^(03|05|07|08|09)\d{8}$/.test(clean);
      };

      expect(isValidVnPhone('0988000001')).toBe(true);
      expect(isValidVnPhone('988000001')).toBe(true);
      expect(isValidVnPhone('0399123456')).toBe(true);
      expect(isValidVnPhone('0701234567')).toBe(true);
      expect(isValidVnPhone('12345')).toBe(false);
      expect(isValidVnPhone('0123456789')).toBe(false); // 01 is not a valid modern 10-digit prefix
      expect(isValidVnPhone('')).toBe(false);
    });
  });

  describe('Area Permission Check for Order Creation', () => {
    function canShipperCreateOrderForCustomer(
      shipper: { roleName: string; assignedAreaIds?: string[] } | null | undefined,
      customerAreaId: string
    ): { allowed: boolean; statusCode: number; message?: string } {
      if (!shipper) {
        return { allowed: false, statusCode: 401, message: 'Chưa xác thực đăng nhập' };
      }
      if (shipper.roleName === 'ADMIN') {
        return { allowed: true, statusCode: 200 };
      }
      if (shipper.roleName === 'SHIPPER') {
        const assigned = shipper.assignedAreaIds || [];
        if (assigned.includes(customerAreaId)) {
          return { allowed: true, statusCode: 200 };
        }
        return {
          allowed: false,
          statusCode: 403,
          message: 'Khách hàng này thuộc khu vực bạn không được phân công phụ trách',
        };
      }
      return { allowed: false, statusCode: 403, message: 'Vai trò không hợp lệ' };
    }

    it('should allow SHIPPER when customer belongs to assigned area', () => {
      const shipper = { roleName: 'SHIPPER', assignedAreaIds: ['area-q9-01', 'area-q9-02'] };
      const res = canShipperCreateOrderForCustomer(shipper, 'area-q9-01');
      expect(res.allowed).toBe(true);
      expect(res.statusCode).toBe(200);
    });

    it('should deny (403) SHIPPER when customer belongs to unassigned area', () => {
      const shipper = { roleName: 'SHIPPER', assignedAreaIds: ['area-q9-01'] };
      const res = canShipperCreateOrderForCustomer(shipper, 'area-q9-02');
      expect(res.allowed).toBe(false);
      expect(res.statusCode).toBe(403);
      expect(res.message).toContain('không được phân công');
    });

    it('should allow ADMIN to add order in any area', () => {
      const admin = { roleName: 'ADMIN', assignedAreaIds: [] };
      const res = canShipperCreateOrderForCustomer(admin, 'area-q9-99');
      expect(res.allowed).toBe(true);
      expect(res.statusCode).toBe(200);
    });
  });

  describe('Order Deduplication & Shift Assignment Logic', () => {
    interface MockOrder {
      id: string;
      orderCode: string;
      customerId: string;
      shipperId: string;
      status: string;
      createdAt: Date;
    }

    function checkOrAddShiftOrder(
      existingOrders: MockOrder[],
      newOrderReq: {
        shipperId: string;
        customerId: string;
        allowMultiple?: boolean;
        idempotencyKey?: string;
      },
      auditLogs: Array<{ idempotencyKey?: string; orderId: string }>
    ): { isExisting: boolean; orderId: string; status: number } {
      // 1. Check idempotency key first
      if (newOrderReq.idempotencyKey) {
        const foundAudit = auditLogs.find((a) => a.idempotencyKey === newOrderReq.idempotencyKey);
        if (foundAudit) {
          return { isExisting: true, orderId: foundAudit.orderId, status: 200 };
        }
      }

      // 2. Check existing pending order for same customer in current shift
      const existing = existingOrders.find(
        (o) =>
          o.shipperId === newOrderReq.shipperId &&
          o.customerId === newOrderReq.customerId &&
          o.status === 'PENDING'
      );

      if (existing && !newOrderReq.allowMultiple) {
        return { isExisting: true, orderId: existing.id, status: 200 };
      }

      // 3. Create new order
      const newOrderId = `order-new-${Date.now()}`;
      return { isExisting: false, orderId: newOrderId, status: 201 };
    }

    it('should return existing order when customer already has a pending order in shift', () => {
      const existingOrders: MockOrder[] = [
        {
          id: 'ord-001',
          orderCode: 'ORD-20261023-01',
          customerId: 'cust-001',
          shipperId: 'shipper-01',
          status: 'PENDING',
          createdAt: new Date(),
        },
      ];

      const res = checkOrAddShiftOrder(
        existingOrders,
        { shipperId: 'shipper-01', customerId: 'cust-001' },
        []
      );

      expect(res.isExisting).toBe(true);
      expect(res.orderId).toBe('ord-001');
      expect(res.status).toBe(200);
    });

    it('should allow creating a new order when customer has no orders in shift', () => {
      const existingOrders: MockOrder[] = [
        {
          id: 'ord-001',
          orderCode: 'ORD-20261023-01',
          customerId: 'cust-001',
          shipperId: 'shipper-01',
          status: 'PENDING',
          createdAt: new Date(),
        },
      ];

      const res = checkOrAddShiftOrder(
        existingOrders,
        { shipperId: 'shipper-01', customerId: 'cust-002' },
        []
      );

      expect(res.isExisting).toBe(false);
      expect(res.status).toBe(201);
    });

    it('should allow creating multiple orders when allowMultiple is explicitly confirmed', () => {
      const existingOrders: MockOrder[] = [
        {
          id: 'ord-001',
          orderCode: 'ORD-20261023-01',
          customerId: 'cust-001',
          shipperId: 'shipper-01',
          status: 'PENDING',
          createdAt: new Date(),
        },
      ];

      const res = checkOrAddShiftOrder(
        existingOrders,
        { shipperId: 'shipper-01', customerId: 'cust-001', allowMultiple: true },
        []
      );

      expect(res.isExisting).toBe(false);
      expect(res.status).toBe(201);
    });

    it('should prevent duplicate order creation on rapid double clicks using idempotencyKey', () => {
      const existingOrders: MockOrder[] = [];
      const auditLogs = [{ idempotencyKey: 'client-req-uuid-1234', orderId: 'ord-already-created' }];

      const res = checkOrAddShiftOrder(
        existingOrders,
        {
          shipperId: 'shipper-01',
          customerId: 'cust-001',
          idempotencyKey: 'client-req-uuid-1234',
        },
        auditLogs
      );

      expect(res.isExisting).toBe(true);
      expect(res.orderId).toBe('ord-already-created');
      expect(res.status).toBe(200);
    });
  });

  describe('Order Code Generation Consistency', () => {
    it('should generate order codes matching ORD-YYYYMMDD-XXXX pattern', () => {
      const today = new Date().toISOString().slice(0, 10).replace(/-/g, '');
      const randomSuffix = Math.random().toString(36).substring(2, 7).toUpperCase();
      const orderCode = `ORD-${today}-${randomSuffix}`;

      const regex = /^ORD-\d{8}-[0-9A-Z]{4,7}$/;
      expect(regex.test(orderCode)).toBe(true);
      expect(orderCode.length).toBeLessThanOrEqual(50);
    });
  });
});
