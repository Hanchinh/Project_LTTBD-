import express, { Express } from 'express';
import cors from 'cors';
import { setupSwagger } from './swagger';
import { login } from './controllers/auth.controller';
import { getMyShiftOrders, createShiftOrder } from './controllers/orders.controller';
import {
  getCustomerLocation,
  saveOrUpdateCustomerLocation,
  getLocationHistory,
  lookupCustomerByPhone,
  servePhoto,
} from './controllers/locations.controller';
import {
  getAreas,
  createArea,
  getUsers,
  createUser,
  assignUserAreas,
  getAllLocations,
  deleteLocation,
  getLocationCoverageStats,
  getAuditLogs,
} from './controllers/admin.controller';
import { authenticateJwt, requireRoles } from './middlewares/auth.middleware';
import { checkCustomerAreaScope } from './middlewares/area.middleware';

import {
  listShifts,
  createShift,
  getShiftDetail,
  updateShiftStatus,
  addPointToShift,
  removePointFromShift,
  updateTemporaryLocation,
  verifyPointLocation,
} from './controllers/shifts.controller';
import { searchAddress } from './controllers/geocoding.controller';
import {
  listCustomers,
  createCustomer,
  getCustomerDetail,
  updateCustomer,
} from './controllers/customers.controller';

export const createApp = (): Express => {
  const app = express();

  app.use(cors());
  app.use(express.json({ limit: '10mb' }));

  // Swagger Documentation
  setupSwagger(app);

  const router = express.Router();

  // AUTH ROUTES
  router.post('/auth/login', login);

  // SHIFT MANAGEMENT ROUTES (FEATURE-SHIFT-001)
  router.get('/shifts', authenticateJwt, requireRoles('SHIPPER', 'ADMIN'), listShifts);
  router.post('/shifts', authenticateJwt, requireRoles('SHIPPER', 'ADMIN'), createShift);
  router.get('/shifts/:id', authenticateJwt, requireRoles('SHIPPER', 'ADMIN'), getShiftDetail);
  router.patch('/shifts/:id/status', authenticateJwt, requireRoles('SHIPPER', 'ADMIN'), updateShiftStatus);
  router.post('/shifts/:id/points', authenticateJwt, requireRoles('SHIPPER', 'ADMIN'), addPointToShift);
  router.delete('/shifts/:id/points/:pointId', authenticateJwt, requireRoles('SHIPPER', 'ADMIN'), removePointFromShift);
  router.put('/shifts/:id/points/:pointId/temporary-location', authenticateJwt, requireRoles('SHIPPER', 'ADMIN'), updateTemporaryLocation);
  router.post('/shifts/:id/points/:pointId/verify-location', authenticateJwt, requireRoles('SHIPPER', 'ADMIN'), verifyPointLocation);

  // GEOCODING & ADDRESS SEARCH (Giai đoạn C)
  router.get('/geocoding/search', authenticateJwt, searchAddress);

  // CUSTOMER DIRECTORY & MANAGEMENT ROUTES (MAP-FIRST-ARCHITECTURE-005)
  router.get('/customers', authenticateJwt, requireRoles('SHIPPER', 'ADMIN'), listCustomers);
  router.post('/customers', authenticateJwt, requireRoles('SHIPPER', 'ADMIN'), createCustomer);
  router.get('/customers/:id', authenticateJwt, requireRoles('SHIPPER', 'ADMIN'), getCustomerDetail);
  router.put('/customers/:id', authenticateJwt, requireRoles('SHIPPER', 'ADMIN'), updateCustomer);

  // SHIPPER MOBILE ROUTES
  router.get('/orders/my-shift', authenticateJwt, requireRoles('SHIPPER', 'ADMIN'), getMyShiftOrders);
  router.post('/orders/my-shift', authenticateJwt, requireRoles('SHIPPER', 'ADMIN'), createShiftOrder);
  router.get(
    '/customers/by-phone/:phoneNumber/location',
    authenticateJwt,
    lookupCustomerByPhone
  );
  router.get(
    '/customers/:customerId/location',
    authenticateJwt,
    checkCustomerAreaScope,
    getCustomerLocation
  );
  router.post(
    '/customers/:customerId/location',
    authenticateJwt,
    checkCustomerAreaScope,
    saveOrUpdateCustomerLocation
  );
  router.get(
    '/customers/:customerId/location/history',
    authenticateJwt,
    checkCustomerAreaScope,
    getLocationHistory
  );
  router.get(
    '/photos/:filename',
    authenticateJwt,
    servePhoto
  );

  // ADMIN ROUTES
  router.get('/admin/areas', authenticateJwt, requireRoles('ADMIN'), getAreas);
  router.post('/admin/areas', authenticateJwt, requireRoles('ADMIN'), createArea);

  router.get('/admin/users', authenticateJwt, requireRoles('ADMIN'), getUsers);
  router.post('/admin/users', authenticateJwt, requireRoles('ADMIN'), createUser);
  router.post('/admin/users/:userId/assign-area', authenticateJwt, requireRoles('ADMIN'), assignUserAreas);

  router.get('/admin/locations', authenticateJwt, requireRoles('ADMIN'), getAllLocations);
  router.delete('/admin/locations/:locationId', authenticateJwt, requireRoles('ADMIN'), deleteLocation);

  router.get('/admin/stats/coverage', authenticateJwt, requireRoles('ADMIN'), getLocationCoverageStats);
  router.get('/admin/audit-logs', authenticateJwt, requireRoles('ADMIN'), getAuditLogs);

  app.use('/api/v1', router);

  return app;
};
