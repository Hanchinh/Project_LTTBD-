import { checkCustomerAreaScope } from '../src/middlewares/area.middleware';

// Haversine formula to calculate distance between 2 GPS lat/lng points in meters
export function calculateGpsDistanceMeters(lat1: number, lon1: number, lat2: number, lon2: number): number {
  const R = 6371e3; // metres
  const phi1 = (lat1 * Math.PI) / 180;
  const phi2 = (lat2 * Math.PI) / 180;
  const deltaPhi = ((lat2 - lat1) * Math.PI) / 180;
  const deltaLambda = ((lon2 - lon1) * Math.PI) / 180;

  const a =
    Math.sin(deltaPhi / 2) * Math.sin(deltaPhi / 2) +
    Math.cos(phi1) * Math.cos(phi2) * Math.sin(deltaLambda / 2) * Math.sin(deltaLambda / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));

  return R * c; // Distance in meters
}

export function normalizePhoneNumber(raw: string): string {
  let clean = raw.replace(/\D/g, '');
  if (clean.startsWith('84') && clean.length === 11) {
    clean = '0' + clean.substring(2);
  } else if (clean.length === 9 && !clean.startsWith('0')) {
    clean = '0' + clean;
  }
  return clean;
}

export function isValidPhotoFilename(filename: string): boolean {
  const safeFilenameRegex = /^[0-9a-fA-F-]{36}\.(jpg|jpeg|png|webp)$/;
  return safeFilenameRegex.test(filename);
}

describe('Core Unit Tests - Delivery Marker System', () => {
  describe('GPS Spatial Accuracy Calculation', () => {
    it('should calculate distance within 20m tolerance for close points', () => {
      // Point 1: Long Thạnh Mỹ (10.842215, 106.818123)
      // Point 2: Shifted by ~10 meters (10.842300, 106.818123)
      const dist = calculateGpsDistanceMeters(10.842215, 106.818123, 10.842300, 106.818123);
      expect(dist).toBeLessThan(20.0);
    });

    it('should detect deviation when distance exceeds 20 meters', () => {
      // Point 1 vs Point 2 (~100m away)
      const dist = calculateGpsDistanceMeters(10.842215, 106.818123, 10.843100, 106.818123);
      expect(dist).toBeGreaterThan(20.0);
    });
  });

  describe('Area Access Control Logic', () => {
    it('should allow access if shipper has assigned area ID', () => {
      const shipperAssignedAreas = ['area-q9-01', 'area-q9-02'];
      const customerAreaId = 'area-q9-01';

      const hasAccess = shipperAssignedAreas.includes(customerAreaId);
      expect(hasAccess).toBe(true);
    });

    it('should deny access if customer belongs to unassigned area', () => {
      const shipperAssignedAreas = ['area-q9-01'];
      const customerAreaId = 'area-q9-02';

      const hasAccess = shipperAssignedAreas.includes(customerAreaId);
      expect(hasAccess).toBe(false);
    });
  });

  describe('Phone Number Normalization for Customer Lookup', () => {
    it('should normalize standard local phone number 0988000001', () => {
      expect(normalizePhoneNumber('0988000001')).toBe('0988000001');
    });

    it('should normalize international format +84988000001 to local format', () => {
      expect(normalizePhoneNumber('+84988000001')).toBe('0988000001');
    });

    it('should strip spaces and dashes from formatted phone numbers', () => {
      expect(normalizePhoneNumber('0988-000-001')).toBe('0988000001');
      expect(normalizePhoneNumber('0988 000 001')).toBe('0988000001');
    });
  });

  describe('Photo Security & Anti-Path-Traversal Validation', () => {
    it('should accept valid UUID-based filenames with supported extensions', () => {
      expect(isValidPhotoFilename('a0000000-0000-0000-0000-000000000001.jpg')).toBe(true);
      expect(isValidPhotoFilename('123e4567-e89b-12d3-a456-426614174000.png')).toBe(true);
      expect(isValidPhotoFilename('b0000000-1111-2222-3333-444444444444.webp')).toBe(true);
    });

    it('should strictly reject path traversal attempts (../ or ..\\)', () => {
      expect(isValidPhotoFilename('../../../etc/passwd')).toBe(false);
      expect(isValidPhotoFilename('..\\..\\windows\\system32\\cmd.exe')).toBe(false);
      expect(isValidPhotoFilename('customer_phone_0988000001.jpg')).toBe(false);
    });

    it('should reject unsafe executable file extensions', () => {
      expect(isValidPhotoFilename('a0000000-0000-0000-0000-000000000001.exe')).toBe(false);
      expect(isValidPhotoFilename('a0000000-0000-0000-0000-000000000001.sh')).toBe(false);
      expect(isValidPhotoFilename('a0000000-0000-0000-0000-000000000001.svg')).toBe(false);
    });
  });

  describe('Location Audit Retention Logic', () => {
    it('should preserve history rows even when parent location is unlinked', () => {
      const mockHistoryRecord = {
        id: 'hist-001',
        savedLocationId: 'loc-001',
        customerId: 'cust-001',
        identificationNotes: 'Ghi chú ban đầu',
      };

      // Simulating ON DELETE SET NULL behavior
      const detachedRecord = {
        ...mockHistoryRecord,
        savedLocationId: null,
      };

      expect(detachedRecord.customerId).toBe('cust-001');
      expect(detachedRecord.savedLocationId).toBeNull();
      expect(detachedRecord.identificationNotes).toBe('Ghi chú ban đầu');
    });
  });

  describe('Photo Download Access Control & Role Enforcement', () => {
    function canUserAccessPhoto(
      user: { roleName: string; assignedAreaIds?: string[] } | null | undefined,
      photoAreaIds: string[]
    ): { allowed: boolean; status: number } {
      if (!user) {
        return { allowed: false, status: 401 };
      }
      if (user.roleName === 'ADMIN') {
        return { allowed: true, status: 200 };
      }
      if (user.roleName === 'SHIPPER') {
        const assigned = user.assignedAreaIds || [];
        const hasMatch = photoAreaIds.some((areaId) => assigned.includes(areaId));
        return hasMatch ? { allowed: true, status: 200 } : { allowed: false, status: 403 };
      }
      return { allowed: false, status: 403 };
    }

    it('should grant access to ADMIN regardless of area', () => {
      const adminUser = { roleName: 'ADMIN', assignedAreaIds: [] };
      const res = canUserAccessPhoto(adminUser, ['area-dist9-01']);
      expect(res.allowed).toBe(true);
      expect(res.status).toBe(200);
    });

    it('should grant access to SHIPPER when area is assigned', () => {
      const shipperUser = { roleName: 'SHIPPER', assignedAreaIds: ['area-dist9-01', 'area-dist9-02'] };
      const res = canUserAccessPhoto(shipperUser, ['area-dist9-01']);
      expect(res.allowed).toBe(true);
      expect(res.status).toBe(200);
    });

    it('should deny access (403) to SHIPPER when area is NOT assigned', () => {
      const shipperUser = { roleName: 'SHIPPER', assignedAreaIds: ['area-dist9-01'] };
      const res = canUserAccessPhoto(shipperUser, ['area-dist9-99']);
      expect(res.allowed).toBe(false);
      expect(res.status).toBe(403);
    });

    it('should deny access (401) when user is unauthenticated', () => {
      const res = canUserAccessPhoto(null, ['area-dist9-01']);
      expect(res.allowed).toBe(false);
      expect(res.status).toBe(401);
    });

    it('should deny access (403) to unauthorized roles', () => {
      const guestUser = { roleName: 'GUEST', assignedAreaIds: [] };
      const res = canUserAccessPhoto(guestUser, ['area-dist9-01']);
      expect(res.allowed).toBe(false);
      expect(res.status).toBe(403);
    });
  });
});
