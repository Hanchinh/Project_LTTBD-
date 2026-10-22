import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import api from '../api/client';
import { MapPin, Lock, Phone } from 'lucide-react';

export const Login: React.FC = () => {
  const [phoneNumber, setPhoneNumber] = useState('0900000001');
  const [password, setPassword] = useState('password123');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);
  const navigate = useNavigate();

  const handleLogin = async (e: React.FormEvent) => {
    e.preventDefault();
    setError('');
    setLoading(true);

    try {
      const res = await api.post('/auth/login', { phoneNumber, password });
      if (res.data.success) {
        if (res.data.data.user.role !== 'ADMIN') {
          setError('Tài khoản này không có quyền truy cập Website Admin');
          setLoading(false);
          return;
        }

        localStorage.setItem('jwt_token', res.data.data.token);
        localStorage.setItem('admin_user', JSON.stringify(res.data.data.user));
        navigate('/dashboard');
      }
    } catch (err: any) {
      setError(err.response?.data?.message || 'Đăng nhập thất bại');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-screen bg-slate-900 flex items-center justify-center p-4">
      <div className="max-w-md w-full bg-slate-800 rounded-2xl shadow-2xl border border-slate-700 p-8">
        <div className="text-center mb-8">
          <div className="inline-flex p-3 bg-blue-600/20 text-blue-500 rounded-xl mb-3">
            <MapPin className="w-10 h-10" />
          </div>
          <h1 className="text-2xl font-bold text-white">Quản Lý Vận Hành Giao Hàng</h1>
          <p className="text-slate-400 text-sm mt-1">Đăng nhập tài khoản Quản trị hệ thống</p>
        </div>

        {error && (
          <div className="bg-red-500/10 border border-red-500/50 text-red-400 p-3 rounded-lg text-sm mb-6">
            {error}
          </div>
        )}

        <form onSubmit={handleLogin} className="space-y-5">
          <div>
            <label className="block text-xs font-semibold text-slate-300 uppercase tracking-wider mb-2">
              Số điện thoại
            </label>
            <div className="relative">
              <Phone className="w-5 h-5 text-slate-400 absolute left-3 top-3" />
              <input
                type="text"
                value={phoneNumber}
                onChange={(e) => setPhoneNumber(e.target.value)}
                className="w-full bg-slate-900 border border-slate-700 rounded-lg pl-10 pr-4 py-2.5 text-white placeholder-slate-500 focus:outline-none focus:border-blue-500"
                placeholder="0900000001"
                required
              />
            </div>
          </div>

          <div>
            <label className="block text-xs font-semibold text-slate-300 uppercase tracking-wider mb-2">
              Mật khẩu
            </label>
            <div className="relative">
              <Lock className="w-5 h-5 text-slate-400 absolute left-3 top-3" />
              <input
                type="password"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                className="w-full bg-slate-900 border border-slate-700 rounded-lg pl-10 pr-4 py-2.5 text-white placeholder-slate-500 focus:outline-none focus:border-blue-500"
                placeholder="••••••••"
                required
              />
            </div>
          </div>

          <button
            type="submit"
            disabled={loading}
            className="w-full bg-blue-600 hover:bg-blue-500 text-white font-semibold py-3 rounded-lg shadow-lg transition duration-200 disabled:opacity-50"
          >
            {loading ? 'Đang xác thực...' : 'ĐĂNG NHẬP ADMIN'}
          </button>
        </form>
      </div>
    </div>
  );
};
