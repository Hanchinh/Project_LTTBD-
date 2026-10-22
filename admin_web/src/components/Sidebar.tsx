import React from 'react';
import { NavLink, useNavigate } from 'react-router-dom';
import { LayoutDashboard, Users, Map, MapPin, History, LogOut } from 'lucide-react';

export const Sidebar: React.FC = () => {
  const navigate = useNavigate();

  const handleLogout = () => {
    localStorage.removeItem('jwt_token');
    localStorage.removeItem('admin_user');
    navigate('/login');
  };

  const navItems = [
    { to: '/dashboard', label: 'Tổng quan & Coverage', icon: LayoutDashboard },
    { to: '/locations', label: 'Bản đồ Vị trí Khách', icon: MapPin },
    { to: '/users', label: 'Nhân viên & Khu vực', icon: Users },
    { to: '/areas', label: 'Quản lý Khu vực', icon: Map },
    { to: '/audit-logs', label: 'Nhật ký Hệ thống', icon: History },
  ];

  return (
    <aside className="w-64 bg-slate-900 text-slate-300 flex flex-col border-r border-slate-800">
      <div className="p-6 border-b border-slate-800 flex items-center space-x-3">
        <div className="p-2 bg-blue-600 rounded-lg text-white">
          <MapPin className="w-6 h-6" />
        </div>
        <div>
          <h2 className="font-bold text-white text-base">ADMIN PORTAL</h2>
          <p className="text-xs text-slate-400">Giao hàng & Định vị</p>
        </div>
      </div>

      <nav className="flex-1 p-4 space-y-1">
        {navItems.map((item) => {
          const Icon = item.icon;
          return (
            <NavLink
              key={item.to}
              to={item.to}
              className={({ isActive }) =>
                `flex items-center space-x-3 px-4 py-3 rounded-lg text-sm font-medium transition ${
                  isActive
                    ? 'bg-blue-600 text-white font-semibold shadow-md'
                    : 'hover:bg-slate-800 hover:text-white text-slate-400'
                }`
              }
            >
              <Icon className="w-5 h-5" />
              <span>{item.label}</span>
            </NavLink>
          );
        })}
      </nav>

      <div className="p-4 border-t border-slate-800">
        <button
          onClick={handleLogout}
          className="w-full flex items-center space-x-3 px-4 py-2.5 rounded-lg text-sm font-medium text-red-400 hover:bg-red-500/10 transition"
        >
          <LogOut className="w-5 h-5" />
          <span>Đăng xuất</span>
        </button>
      </div>
    </aside>
  );
};
