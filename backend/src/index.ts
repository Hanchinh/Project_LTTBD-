import { createApp } from './app';
import dotenv from 'dotenv';

dotenv.config();

const app = createApp();
const PORT = process.env.PORT || 3000;

app.listen(PORT, () => {
  console.log(`🚀 Delivery Marker Backend API server running on port ${PORT}`);
  console.log(`📑 Swagger Documentation available at http://localhost:${PORT}/api/docs`);
});
