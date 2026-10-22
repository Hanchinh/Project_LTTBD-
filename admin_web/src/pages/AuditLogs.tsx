import React, { useEffect, useState } from 'react';
import api from '../api/client';
import { History, ShieldAlert } from 'lucide-react';

interface AuditLog {
  id: string;
  action: string;
  entity: string;
  entity_id?: string;
  details?: any;
  user_name?: string;
  user_phone?: string;
  created_at: string;
}

export const AuditLogs: React.FC = () => {
  const [logs, setLogs] = useState<AuditLog[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const fetchLogs = async () => {
      try {
        const res = await api.get('/admin/audit-logs');
        setLogs(res.data.data);
      } catch (err) {
        console.error(err);
      } finally {
        setLoading(false);
      }
    };
    fetchLogs();
  }, []);

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold text-gray-900">Nhật Ký Truy Cập & Thay Đổi Dữ Liệu</h1>
        <p className="text-gray-500 text-sm">Ghi nhận lịch sử thao tác của nhân viên và quản trị viên</p>
      </div>

      <div className="bg-white rounded-xl border border-gray-200 shadow-sm overflow-hidden">
        <table className="w-full text-left border-collapse text-sm">
          <thead>
            <tr className="bg-gray-50 text-gray-600 text-xs uppercase font-semibold border-b border-gray-200">
              <th className="p-4">Thời gian</th>
              <th className="p-4">Người thực hiện</th>
              <th className="p-4">Hành động</th>
              <th className="p-4">Đối tượng</th>
              <th className="p-4">Chi tiết</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-gray-100">
            {logs.map((log) => (
              <tr key={log.id} className="hover:bg-gray-50/50">
                <td className="p-4 text-gray-500 text-xs font-mono">
                  {new Date(log.created_at).toLocaleString('vi-VN')}
                </td>
                <td className="p-4">
                  <div className="font-semibold text-gray-900">{log.user_name || 'Hệ thống'}</div>
                  {log.user_phone && <div className="text-xs text-gray-500">{log.user_phone}</div>}
                </td>
                <td className="p-4">
                  <span className="inline-flex px-2.5 py-1 rounded bg-slate-100 font-mono text-xs font-bold text-slate-800">
                    {log.action}
                  </span>
                </td>
                <td className="p-4 font-mono text-xs text-gray-600">{log.entity}</td>
                <td className="p-4 text-xs text-gray-600 font-mono max-w-md truncate">
                  {JSON.stringify(log.details)}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
};
