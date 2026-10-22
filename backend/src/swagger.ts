import swaggerUi from 'swagger-ui-express';
import { Express } from 'express';

const swaggerDocument = {
  openapi: '3.0.0',
  info: {
    title: 'Delivery Location Marker System API',
    version: '1.0.0',
    description: 'API Backend hỗ trợ ghi nhớ vị trí giao hàng thực tế bằng PostGIS & Flutter',
  },
  servers: [
    {
      url: 'http://localhost:3000/api/v1',
      description: 'Local Development Server',
    },
  ],
  components: {
    securitySchemes: {
      bearerAuth: {
        type: 'http',
        scheme: 'bearer',
        bearerFormat: 'JWT',
      },
    },
  },
  paths: {
    '/auth/login': {
      post: {
        summary: 'Đăng nhập người dùng (Shipper & Admin)',
        requestBody: {
          required: true,
          content: {
            'application/json': {
              schema: {
                type: 'object',
                properties: {
                  phoneNumber: { type: 'string', example: '0901111111' },
                  password: { type: 'string', example: 'password123' },
                },
              },
            },
          },
        },
        responses: { 200: { description: 'Đăng nhập thành công và trả về JWT Token' } },
      },
    },
    '/orders/my-shift': {
      get: {
        summary: 'Lấy danh sách đơn hàng trong ca của Shipper',
        security: [{ bearerAuth: [] }],
        responses: { 200: { description: 'Danh sách đơn hàng' } },
      },
    },
    '/customers/{customerId}/location': {
      get: {
        summary: 'Lấy vị trí đã lưu của Khách hàng',
        security: [{ bearerAuth: [] }],
        parameters: [{ name: 'customerId', in: 'path', required: true, schema: { type: 'string' } }],
        responses: { 200: { description: 'Chi tiết vị trí PostGIS' } },
      },
      post: {
        summary: 'Lưu hoặc cập nhật vị trí giao hàng thực tế của khách hàng',
        security: [{ bearerAuth: [] }],
        parameters: [{ name: 'customerId', in: 'path', required: true, schema: { type: 'string' } }],
        requestBody: {
          required: true,
          content: {
            'application/json': {
              schema: {
                type: 'object',
                properties: {
                  latitude: { type: 'number', example: 10.842215 },
                  longitude: { type: 'number', example: 106.818123 },
                  gpsAccuracy: { type: 'number', example: 4.5 },
                  identificationNotes: { type: 'string', example: 'Hẻm 124, cổng xanh da trời' },
                },
              },
            },
          },
        },
        responses: { 200: { description: 'Lưu vị trí thành công' } },
      },
    },
    '/admin/stats/coverage': {
      get: {
        summary: 'Thống kê tỷ lệ phủ vị trí theo từng khu vực',
        security: [{ bearerAuth: [] }],
        responses: { 200: { description: 'Tỷ lệ % phủ vị trí' } },
      },
    },
  },
};

export const setupSwagger = (app: Express) => {
  app.use('/api/docs', swaggerUi.serve, swaggerUi.setup(swaggerDocument));
};
