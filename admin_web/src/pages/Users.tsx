import React, { useEffect, useState } from 'react';
import api from '../api/client';
import { UserPlus, Shield, MapPin } from 'lucide-react';

interface Area {
  id: string;
  code: string;
  name: string;
}

interface UserItem {
  id: string;
  full_name: string;
  phone_number: string;
  is_active: boolean;
  role_name: string;
  assigned_areas: Area[];
}

export const Users: React.FC = () => {
  const [users, setUsers] = useState<UserItem[]>([]);
  const [areas, setAreas] = useState<Area[]>([]);
  const [selectedUser, setSelectedUser] = useState<UserItem | null>(null);
  const [selectedAreaIds, setSelectedAreaIds] = useState<string[]>([]);
  const [loading, setLoading] = useState(true);
  const [showCreateModal, setShowCreateModal] = useState(false);
  const [newFullName, setNewFullName] = useState('');
  const [newPhone, setNewPhone] = useState('');
  const [newPassword, setNewPassword] = useState('');
  const [newRoleId, setNewRoleId] = useState(2); // 2: SHIPPER, 1: ADMIN
  const [createLoading, setCreateLoading] = useState(false);

  const fetchData = async () => {
    setLoading(true);
    try {
      const [uRes, aRes] = await Promise.all([
        api.get('/admin/users'),
        api.get('/admin/areas'),
      ]);
      setUsers(uRes.data.data);
      setAreas(aRes.data.data);
    } catch (err) {
      console.error(err);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchData();
  }, []);

  const openAssignModal = (user: UserItem) => {
    setSelectedUser(user);
    setSelectedAreaIds(user.assigned_areas.map((a) => a.id));
  };

  const handleSaveAssignment = async () => {
    if (!selectedUser) return;
    try {
      await api.post(`/admin/users/${selectedUser.id}/assign-area`, {
        areaIds: selectedAreaIds,
      });
      alert('Đã bàn giao khu vực thành công!');
      setSelectedUser(null);
      fetchData();
    } catch (err) {
      alert('Không thể bàn giao khu vực');
    }
  };

  const handleCreateUser = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!newFullName || !newPhone || !newPassword) {
      alert('Vui lòng điền đầy đủ thông tin');
      return;
    }
    setCreateLoading(true);
    try {
      await api.post('/admin/users', {
        fullName: newFullName,
        phoneNumber: newPhone,
        password: newPassword,
        roleId: newRoleId,
      });
      alert('Tạo người dùng mới thành công!');
      setShowCreateModal(false);
      setNewFullName('');
      setNewPhone('');
      setNewPassword('');
      fetchData();
    } catch (err: any) {
      alert(err.response?.data?.message || 'Không thể tạo người dùng');
    } finally {
      setCreateLoading(false);
    }
  };

  return (
    <div className="space-y-6">
      <div className="flex justify-between items-center">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">Quản Lý Nhân Viên & Phân Công Khu Vực</h1>
          <p className="text-gray-500 text-sm">Gán, đổi và bàn giao khu vực giao hàng cho nhân viên shipper</p>
        </div>

        <button
          onClick={() => setShowCreateModal(true)}
          className="flex items-center space-x-2 px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-500 transition text-sm font-semibold shadow"
        >
          <UserPlus className="w-4 h-4" />
          <span>Thêm Nhân Viên Mới</span>
        </button>
      </div>

      <div className="bg-white rounded-xl border border-gray-200 shadow-sm overflow-hidden">
        <table className="w-full text-left border-collapse text-sm">
          <thead>
            <tr className="bg-gray-50 text-gray-600 text-xs uppercase font-semibold border-b border-gray-200">
              <th className="p-4">Họ và Tên</th>
              <th className="p-4">Số điện thoại</th>
              <th className="p-4">Vai trò</th>
              <th className="p-4">Khu vực phụ trách</th>
              <th className="p-4 text-right">Thao tác</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-gray-100">
            {users.map((user) => (
              <tr key={user.id} className="hover:bg-gray-50/50">
                <td className="p-4 font-bold text-gray-900">{user.full_name}</td>
                <td className="p-4 text-gray-600">{user.phone_number}</td>
                <td className="p-4">
                  <span
                    className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-semibold ${
                      user.role_name === 'ADMIN'
                        ? 'bg-purple-100 text-purple-800'
                        : 'bg-blue-100 text-blue-800'
                    }`}
                  >
                    {user.role_name}
                  </span>
                </td>
                <td className="p-4">
                  <div className="flex flex-wrap gap-1">
                    {user.assigned_areas.map((a) => (
                      <span
                        key={a.id}
                        className="bg-gray-100 border border-gray-200 text-gray-700 px-2 py-1 rounded text-xs"
                      >
                        {a.name}
                      </span>
                    ))}
                    {user.assigned_areas.length === 0 && (
                      <span className="text-xs text-gray-400 italic">Chưa bàn giao KV</span>
                    )}
                  </div>
                </td>
                <td className="p-4 text-right">
                  {user.role_name === 'SHIPPER' && (
                    <button
                      onClick={() => openAssignModal(user)}
                      className="px-3 py-1.5 bg-blue-50 text-blue-600 font-semibold rounded-lg hover:bg-blue-100 transition text-xs"
                    >
                      Bàn giao khu vực
                    </button>
                  )}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      {/* Area Assignment Modal */}
      {selectedUser && (
        <div className="fixed inset-0 bg-black/50 flex items-center justify-center p-4 z-50">
          <div className="bg-white rounded-xl max-w-md w-full p-6 space-y-4">
            <h2 className="text-lg font-bold text-gray-900">
              Phân công Khu vực: {selectedUser.full_name}
            </h2>
            <p className="text-xs text-gray-500">Chọn các khu vực shipper này sẽ phụ trách:</p>

            <div className="space-y-2 max-h-60 overflow-y-auto border border-gray-200 rounded-lg p-3">
              {areas.map((area) => {
                const checked = selectedAreaIds.includes(area.id);
                return (
                  <label
                    key={area.id}
                    className="flex items-center space-x-3 p-2 hover:bg-gray-50 rounded cursor-pointer text-sm"
                  >
                    <input
                      type="checkbox"
                      checked={checked}
                      onChange={(e) => {
                        if (e.target.checked) {
                          setSelectedAreaIds([...selectedAreaIds, area.id]);
                        } else {
                          setSelectedAreaIds(selectedAreaIds.filter((id) => id !== area.id));
                        }
                      }}
                      className="rounded text-blue-600"
                    />
                    <span className="font-medium text-gray-800">{area.name} ({area.code})</span>
                  </label>
                );
              })}
            </div>

            <div className="flex justify-end space-x-3 pt-2">
              <button
                onClick={() => setSelectedUser(null)}
                className="px-4 py-2 bg-gray-100 text-gray-700 text-sm font-semibold rounded-lg hover:bg-gray-200"
              >
                Hủy
              </button>
              <button
                onClick={handleSaveAssignment}
                className="px-4 py-2 bg-blue-600 text-white text-sm font-semibold rounded-lg hover:bg-blue-500 shadow"
              >
                Lưu Phân Công
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Create User Modal */}
      {showCreateModal && (
        <div className="fixed inset-0 bg-black/50 flex items-center justify-center p-4 z-50">
          <div className="bg-white rounded-xl max-w-md w-full p-6 space-y-4">
            <h2 className="text-lg font-bold text-gray-900">Thêm Người Dùng Mới</h2>
            <form onSubmit={handleCreateUser} className="space-y-4">
              <div>
                <label className="block text-xs font-semibold text-gray-700 mb-1">Họ và Tên</label>
                <input
                  type="text"
                  required
                  value={newFullName}
                  onChange={(e) => setNewFullName(e.target.value)}
                  placeholder="VD: Nguyễn Văn Shipper"
                  className="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:border-blue-500"
                />
              </div>

              <div>
                <label className="block text-xs font-semibold text-gray-700 mb-1">Số Điện Thoại</label>
                <input
                  type="text"
                  required
                  value={newPhone}
                  onChange={(e) => setNewPhone(e.target.value)}
                  placeholder="VD: 0903333333"
                  className="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:border-blue-500"
                />
              </div>

              <div>
                <label className="block text-xs font-semibold text-gray-700 mb-1">Mật Khẩu Ban Đầu</label>
                <input
                  type="password"
                  required
                  value={newPassword}
                  onChange={(e) => setNewPassword(e.target.value)}
                  placeholder="Nhập mật khẩu an toàn"
                  className="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:border-blue-500"
                />
              </div>

              <div>
                <label className="block text-xs font-semibold text-gray-700 mb-1">Vai Trò</label>
                <select
                  value={newRoleId}
                  onChange={(e) => setNewRoleId(Number(e.target.value))}
                  className="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:border-blue-500"
                >
                  <option value={2}>Nhân viên Giao hàng (SHIPPER)</option>
                  <option value={1}>Quản trị viên (ADMIN)</option>
                </select>
              </div>

              <div className="flex justify-end space-x-3 pt-3 border-t border-gray-100">
                <button
                  type="button"
                  onClick={() => setShowCreateModal(false)}
                  className="px-4 py-2 bg-gray-100 text-gray-700 text-sm font-semibold rounded-lg hover:bg-gray-200"
                >
                  Hủy
                </button>
                <button
                  type="submit"
                  disabled={createLoading}
                  className="px-4 py-2 bg-blue-600 text-white text-sm font-semibold rounded-lg hover:bg-blue-500 shadow disabled:opacity-50"
                >
                  {createLoading ? 'Đang tạo...' : 'Tạo Tài Khoản'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
};
