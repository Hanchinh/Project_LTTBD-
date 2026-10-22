import React, { useEffect, useState } from 'react';
import { MapContainer, TileLayer, Marker, Popup } from 'react-leaflet';
import L from 'leaflet';
import api from '../api/client';
import { Search, MapPin, Trash2, Layers } from 'lucide-react';
import { AuthenticatedImage } from '../components/AuthenticatedImage';

// Custom Leaflet Red Pin Icon
const markerIcon = new L.Icon({
  iconUrl: 'https://raw.githubusercontent.com/pointhi/leaflet-color-markers/master/img/marker-icon-2x-red.png',
  shadowUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/0.7.7/images/marker-shadow.png',
  iconSize: [25, 41],
  iconAnchor: [12, 41],
  popupAnchor: [1, -34],
  shadowSize: [41, 41],
});

interface SavedLocationItem {
  locationId: string;
  customer: {
    id: string;
    code: string;
    name: string;
    phone: string;
    address: string;
  };
  area: {
    id: string;
    name: string;
  };
  latitude: number;
  longitude: number;
  gpsAccuracy: number;
  identificationNotes: string;
  imageUrl?: string;
  updatedBy?: string;
  updatedAt: string;
}

export const Locations: React.FC = () => {
  const [locations, setLocations] = useState<SavedLocationItem[]>([]);
  const [search, setSearch] = useState('');
  const [isSatellite, setIsSatellite] = useState(false);
  const [loading, setLoading] = useState(true);

  const fetchLocations = async () => {
    setLoading(true);
    try {
      const res = await api.get('/admin/locations', {
        params: { search },
      });
      setLocations(res.data.data);
    } catch (err) {
      console.error(err);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchLocations();
  }, [search]);

  const handleDelete = async (locationId: string) => {
    if (!confirm('Bạn có chắc chắn muốn xóa vị trí đã lưu này?')) return;
    try {
      await api.delete(`/admin/locations/${locationId}`);
      fetchLocations();
    } catch (err) {
      alert('Không thể xóa vị trí');
    }
  };

  const centerLat = locations.length > 0 ? locations[0].latitude : 10.842215;
  const centerLng = locations.length > 0 ? locations[0].longitude : 106.818123;

  return (
    <div className="space-y-6">
      <div className="flex justify-between items-center">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">Quản Lý & Tìm Kiếm Vị Trí Khách Hàng</h1>
          <p className="text-gray-500 text-sm">Xem trực quan vị trí thực tế trên bản đồ vệ tinh / OSM</p>
        </div>

        <button
          onClick={() => setIsSatellite(!isSatellite)}
          className="flex items-center space-x-2 px-4 py-2 bg-slate-800 text-white rounded-lg hover:bg-slate-700 transition text-sm font-semibold"
        >
          <Layers className="w-4 h-4" />
          <span>{isSatellite ? 'Xem Bản Đồ Thường' : 'Xem Ảnh Vệ Tinh'}</span>
        </button>
      </div>

      {/* Search Bar */}
      <div className="bg-white p-4 rounded-xl border border-gray-200 shadow-sm flex items-center space-x-4">
        <div className="relative flex-1">
          <Search className="w-5 h-5 text-gray-400 absolute left-3 top-2.5" />
          <input
            type="text"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder="Tìm theo tên KH, SĐT, mã đơn hoặc ghi chú..."
            className="w-full pl-10 pr-4 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:border-blue-500"
          />
        </div>
      </div>

      {/* Map View */}
      <div className="h-[450px] bg-white rounded-xl border border-gray-200 shadow-sm overflow-hidden relative">
        <MapContainer center={[centerLat, centerLng]} zoom={14} scrollWheelZoom={true}>
          <TileLayer
            url={
              isSatellite
                ? 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}'
                : 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png'
            }
          />
          {locations.map((loc) => (
            <Marker
              key={loc.locationId}
              position={[loc.latitude, loc.longitude]}
              icon={markerIcon}
            >
              <Popup>
                <div className="p-1 space-y-1">
                  <h3 className="font-bold text-sm text-blue-600">{loc.customer.name} ({loc.customer.phone})</h3>
                  <p className="text-xs text-gray-600"><b>Hóa đơn:</b> {loc.customer.address}</p>
                  {loc.imageUrl && (
                    <div className="my-1">
                      <AuthenticatedImage
                        src={loc.imageUrl}
                        alt="Cổng nhà"
                        className="w-full h-24 object-cover rounded border border-gray-200"
                      />
                    </div>
                  )}
                  <div className="bg-amber-50 p-2 rounded border border-amber-200 text-xs text-amber-900 my-1">
                    <b>Ghi chú:</b> {loc.identificationNotes}
                  </div>
                  <p className="text-[11px] text-gray-400">Tọa độ: {loc.latitude}, {loc.longitude} (±{loc.gpsAccuracy}m)</p>
                  <p className="text-[11px] text-gray-400">Cập nhật bởi: {loc.updatedBy || 'N/A'}</p>
                </div>
              </Popup>
            </Marker>
          ))}
        </MapContainer>
      </div>

      {/* Data Table */}
      <div className="bg-white rounded-xl border border-gray-200 shadow-sm overflow-hidden">
        <div className="p-4 border-b border-gray-200 font-bold text-gray-900">
          Danh sách vị trí ({locations.length})
        </div>
        <table className="w-full text-left border-collapse text-sm">
          <thead>
            <tr className="bg-gray-50 text-gray-600 text-xs uppercase font-semibold border-b border-gray-200">
              <th className="p-3">Khách hàng</th>
              <th className="p-3">Ảnh nhận diện</th>
              <th className="p-3">Khu vực</th>
              <th className="p-3">Tọa độ (Lat, Lng)</th>
              <th className="p-3">Ghi chú nhận diện</th>
              <th className="p-3">Độ chính xác</th>
              <th className="p-3 text-right">Thao tác</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-gray-100">
            {locations.map((loc) => (
              <tr key={loc.locationId} className="hover:bg-gray-50/50">
                <td className="p-3">
                  <div className="font-semibold text-gray-900">{loc.customer.name}</div>
                  <div className="text-xs text-gray-500">{loc.customer.phone}</div>
                </td>
                <td className="p-3">
                  <AuthenticatedImage
                    src={loc.imageUrl}
                    alt="Ảnh nhà"
                    className="w-12 h-12 object-cover rounded border border-gray-200 hover:scale-105 transition"
                  />
                </td>
                <td className="p-3 text-gray-600">{loc.area.name}</td>
                <td className="p-3 font-mono text-xs text-blue-600">
                  {loc.latitude.toFixed(6)}, {loc.longitude.toFixed(6)}
                </td>
                <td className="p-3 max-w-xs text-gray-800">{loc.identificationNotes}</td>
                <td className="p-3 text-gray-500">±{loc.gpsAccuracy} m</td>
                <td className="p-3 text-right">
                  <button
                    onClick={() => handleDelete(loc.locationId)}
                    className="p-1.5 text-red-600 hover:bg-red-50 rounded transition"
                    title="Xóa vị trí"
                  >
                    <Trash2 className="w-4 h-4" />
                  </button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
};
