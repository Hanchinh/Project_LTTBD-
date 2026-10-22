import express, { Express } from 'express';
import cors from 'cors';
import { setupSwagger } from './swagger';
import { login } from './controllers/auth.controller';
import { getMyShiftOrders } from './controllers/orders.controller';
import {
  getCustomerLocation,
  saveOrUpdateCustomerLocation,
  getLocationHistory,
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

export const createApp = (): Express => {
  const app = express();

  app.use(cors());
  app.use(express.json());

  // Swagger Documentation
  setupSwagger(app);

  const router = express.Router();

  // AUTH ROUTES
  router.post('/auth/login', login);

  // SHIPPER MOBILE ROUTES
  router.get('/orders/my-shift', authenticateJwt, requireRoles('SHIPPER', 'ADMIN'), getMyShiftOrders);
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
