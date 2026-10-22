import axios from 'axios';

const api = axios.create({
  baseURL: import.meta.env.VITE_API_BASE_URL || 'http://localhost:3000/api/v1',
  headers: {
    'Content-Type': 'application/json',
  },
});

api.interceptors.request.use((config) => {
  const token = localStorage.getItem('jwt_token');
  if (token) {
    config.headers.Authorization = `Bearer ${token}`;
  }
  return config;
});

export const getPhotoBlobUrl = async (imageUrl: string): Promise<string> => {
  if (!imageUrl) throw new Error('Không có đường dẫn ảnh');
  if (imageUrl.startsWith('blob:') || imageUrl.startsWith('data:')) {
    return imageUrl;
  }

  // Strip duplicate /api/v1 if present because api.defaults.baseURL already includes /api/v1
  let endpoint = imageUrl;
  if (endpoint.startsWith('http://') || endpoint.startsWith('https://')) {
    try {
      const parsed = new URL(endpoint);
      endpoint = parsed.pathname;
    } catch {
      // ignore
    }
  }

  if (endpoint.startsWith('/api/v1/')) {
    endpoint = endpoint.substring('/api/v1'.length);
  } else if (endpoint.startsWith('/api/v1')) {
    endpoint = endpoint.substring('/api/v1'.length);
  }

  const response = await api.get(endpoint, {
    responseType: 'blob',
  });

  return URL.createObjectURL(response.data);
};

export default api;
