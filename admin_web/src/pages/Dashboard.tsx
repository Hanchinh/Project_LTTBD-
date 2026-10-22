import React, { useEffect, useState } from 'react';
import api from '../api/client';
import { MapPin, Users, CheckCircle2, TrendingUp } from 'lucide-react';

interface CoverageStat {
  areaId: string;
  areaCode: string;
  areaName: string;
  totalCustomers: number;
  savedLocationsCount: number;
  coveragePercentage: number;
}

export const Dashboard: React.FC = () => {
  const [stats, setStats] = useState<CoverageStat[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const fetchStats = async () => {
      try {
        const res = await api.get('/admin/stats/coverage');
        setStats(res.data.data);
      } catch (err) {
        console.error(err);
      } finally {
        setLoading(false);
      }
    };
    fetchStats();
  }, []);

  const totalCust = stats.reduce((acc, curr) => acc + curr.totalCustomers, 0);
  const totalSaved = stats.reduce((acc, curr) => acc + curr.savedLocationsCount, 0);
  const avgCoverage = totalCust > 0 ? ((totalSaved / totalCust) * 100).toFixed(1) : 0;

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold text-gray-900">Tổng quan Hệ thống & Tỷ lệ Phủ Vị trí</h1>
        <p className="text-gray-500 text-sm">Thống kê mức độ phủ vị trí thực tế của khách hàng theo từng khu vực</p>
      </div>

      {/* Metric Cards */}
      <div className="grid grid-cols-1 md:grid-cols-4 gap-6">
        <div className="bg-white p-6 rounded-xl border border-gray-200 shadow-sm flex items-center space-x-4">
          <div className="p-3 bg-blue-100 text-blue-600 rounded-lg">
            <Users className="w-6 h-6" />
          </div>
          <div>
            <p className="text-xs font-semibold text-gray-500 uppercase">Tổng Khách Hàng</p>
            <h3 className="text-2xl font-bold text-gray-900">{totalCust}</h3>
          </div>
        </div>

        <div className="bg-white p-6 rounded-xl border border-gray-200 shadow-sm flex items-center space-x-4">
          <div className="p-3 bg-emerald-100 text-emerald-600 rounded-lg">
            <CheckCircle2 className="w-6 h-6" />
          </div>
          <div>
            <p className="text-xs font-semibold text-gray-500 uppercase">Vị trí đã lưu</p>
            <h3 className="text-2xl font-bold text-gray-900">{totalSaved}</h3>
          </div>
        </div>

        <div className="bg-white p-6 rounded-xl border border-gray-200 shadow-sm flex items-center space-x-4">
          <div className="p-3 bg-indigo-100 text-indigo-600 rounded-lg">
            <TrendingUp className="w-6 h-6" />
          </div>
          <div>
            <p className="text-xs font-semibold text-gray-500 uppercase">Tỷ lệ phủ TB</p>
            <h3 className="text-2xl font-bold text-gray-900">{avgCoverage}%</h3>
          </div>
        </div>

        <div className="bg-white p-6 rounded-xl border border-gray-200 shadow-sm flex items-center space-x-4">
          <div className="p-3 bg-purple-100 text-purple-600 rounded-lg">
            <MapPin className="w-6 h-6" />
          </div>
          <div>
            <p className="text-xs font-semibold text-gray-500 uppercase">Tổng Khu vực</p>
            <h3 className="text-2xl font-bold text-gray-900">{stats.length}</h3>
          </div>
        </div>
      </div>

      {/* Coverage Table */}
      <div className="bg-white rounded-xl border border-gray-200 shadow-sm overflow-hidden">
        <div className="p-6 border-b border-gray-200">
          <h2 className="text-lg font-bold text-gray-900">Chi tiết Tỷ lệ phủ vị trí theo Khu vực</h2>
        </div>

        {loading ? (
          <div className="p-8 text-center text-gray-500">Đang tải dữ liệu thống kê...</div>
        ) : (
          <table className="w-full text-left border-collapse">
            <thead>
              <tr className="bg-gray-50 text-gray-600 text-xs uppercase font-semibold border-b border-gray-200">
                <th className="p-4">Mã KV</th>
                <th className="p-4">Tên Khu vực</th>
                <th className="p-4">Tổng số khách</th>
                <th className="p-4">Khách đã lưu vị trí</th>
                <th className="p-4">Tiến độ Phủ (%)</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-100 text-sm">
              {stats.map((row) => (
                <tr key={row.areaId} className="hover:bg-gray-50/50">
                  <td className="p-4 font-mono font-semibold text-blue-600">{row.areaCode}</td>
                  <td className="p-4 font-medium text-gray-900">{row.areaName}</td>
                  <td className="p-4 text-gray-600">{row.totalCustomers}</td>
                  <td className="p-4 text-gray-600 font-semibold">{row.savedLocationsCount}</td>
                  <td className="p-4">
                    <div className="flex items-center space-x-3">
                      <div className="w-32 bg-gray-200 rounded-full h-2.5 overflow-hidden">
                        <div
                          className="bg-emerald-500 h-2.5 rounded-full"
                          style={{ width: `${Math.min(row.coveragePercentage, 100)}%` }}
                        ></div>
                      </div>
                      <span className="font-semibold text-gray-700">{row.coveragePercentage}%</span>
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>
    </div>
  );
};
