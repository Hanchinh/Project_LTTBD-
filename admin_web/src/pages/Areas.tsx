import React, { useEffect, useState } from 'react';
import api from '../api/client';
import { Plus, Map } from 'lucide-react';

interface Area {
  id: string;
  code: string;
  name: string;
  created_at: string;
}

export const Areas: React.FC = () => {
  const [areas, setAreas] = useState<Area[]>([]);
  const [code, setCode] = useState('');
  const [name, setName] = useState('');
  const [showModal, setShowModal] = useState(false);

  const fetchAreas = async () => {
    try {
      const res = await api.get('/admin/areas');
      setAreas(res.data.data);
    } catch (err) {
      console.error(err);
    }
  };

  useEffect(() => {
    fetchAreas();
  }, []);

  const handleCreateArea = async (e: React.FormEvent) => {
    e.preventDefault();
    try {
      await api.post('/admin/areas', { code, name });
      setCode('');
      setName('');
      setShowModal(false);
      fetchAreas();
    } catch (err) {
      alert('Không thể tạo khu vực');
    }
  };

  return (
    <div className="space-y-6">
      <div className="flex justify-between items-center">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">Quản Lý Danh Sách Khu Vực</h1>
          <p className="text-gray-500 text-sm">Danh mục khu vực giao hàng trong hệ thống</p>
        </div>

        <button
          onClick={() => setShowModal(true)}
          className="flex items-center space-x-2 px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-500 transition text-sm font-semibold shadow"
        >
          <Plus className="w-4 h-4" />
          <span>Thêm Khu Vực Mới</span>
        </button>
      </div>

      <div className="bg-white rounded-xl border border-gray-200 shadow-sm overflow-hidden">
        <table className="w-full text-left border-collapse text-sm">
          <thead>
            <tr className="bg-gray-50 text-gray-600 text-xs uppercase font-semibold border-b border-gray-200">
              <th className="p-4">Mã Khu Vực</th>
              <th className="p-4">Tên Khu Vực</th>
              <th className="p-4">Ngày tạo</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-gray-100">
            {areas.map((a) => (
              <tr key={a.id} className="hover:bg-gray-50/50">
                <td className="p-4 font-mono font-bold text-blue-600">{a.code}</td>
                <td className="p-4 font-medium text-gray-900">{a.name}</td>
                <td className="p-4 text-gray-500">{new Date(a.created_at).toLocaleDateString('vi-VN')}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      {showModal && (
        <div className="fixed inset-0 bg-black/50 flex items-center justify-center p-4 z-50">
          <form onSubmit={handleCreateArea} className="bg-white rounded-xl max-w-md w-full p-6 space-y-4">
            <h2 className="text-lg font-bold text-gray-900">Tạo Khu Vực Mới</h2>
            <div>
              <label className="block text-xs font-semibold text-gray-600 mb-1">Mã Khu vực (Ví dụ: AREA_Q9_03)</label>
              <input
                type="text"
                value={code}
                onChange={(e) => setCode(e.target.value)}
                className="w-full border border-gray-300 rounded-lg p-2.5 text-sm focus:outline-none focus:border-blue-500"
                required
              />
            </div>

            <div>
              <label className="block text-xs font-semibold text-gray-600 mb-1">Tên Khu vực</label>
              <input
                type="text"
                value={name}
                onChange={(e) => setName(e.target.value)}
                className="w-full border border-gray-300 rounded-lg p-2.5 text-sm focus:outline-none focus:border-blue-500"
                required
              />
            </div>

            <div className="flex justify-end space-x-3 pt-2">
              <button
                type="button"
                onClick={() => setShowModal(false)}
                className="px-4 py-2 bg-gray-100 text-gray-700 text-sm font-semibold rounded-lg hover:bg-gray-200"
              >
                Hủy
              </button>
              <button
                type="submit"
                className="px-4 py-2 bg-blue-600 text-white text-sm font-semibold rounded-lg hover:bg-blue-500 shadow"
              >
                Tạo Khu Vực
              </button>
            </div>
          </form>
        </div>
      )}
    </div>
  );
};
