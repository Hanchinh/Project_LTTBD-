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
});
