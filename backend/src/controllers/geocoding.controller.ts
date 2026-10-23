import { Response } from 'express';
import { AuthenticatedRequest } from '../middlewares/auth.middleware';
import { query } from '../db';
import https from 'https';

export interface GeocodingResultItem {
  displayName: string;
  latitude: number;
  longitude: number;
  source?: string;
}

/**
 * Helper to query Photon (OpenStreetMap data) with fallback to Nominatim
 */
async function fetchFromPhoton(searchQuery: string): Promise<GeocodingResultItem[]> {
  return new Promise((resolve) => {
    const encoded = encodeURIComponent(searchQuery);
    const url = `https://photon.komoot.io/api/?q=${encoded}&limit=5`;
    const req = https.get(
      url,
      {
        headers: {
          'User-Agent': 'DeliveryLocationMarker/1.0 (contact: admin@deliverymarker.local)',
          'Accept': 'application/json',
        },
        timeout: 3500,
      },
      (res) => {
        if (res.statusCode !== 200) {
          resolve([]);
          return;
        }

        let rawData = '';
        res.on('data', (chunk) => {
          rawData += chunk;
        });

        res.on('end', () => {
          try {
            const parsed = JSON.parse(rawData);
            const features = parsed.features || [];
            const items: GeocodingResultItem[] = features
              .map((f: any) => {
                const p = f.properties || {};
                const parts = [p.name, p.street, p.district, p.city || p.county, p.state].filter(Boolean);
                const uniqueParts = parts.filter((val: string, idx: number, arr: string[]) => arr.indexOf(val) === idx);
                const displayName = uniqueParts.length > 0 ? uniqueParts.join(', ') : (p.name || searchQuery);
                const [lon, lat] = f.geometry?.coordinates || [0, 0];
                return {
                  displayName,
                  latitude: parseFloat(lat),
                  longitude: parseFloat(lon),
                  source: 'OSM_PHOTON',
                };
              })
              .filter(
                (item: GeocodingResultItem) =>
                  !isNaN(item.latitude) &&
                  !isNaN(item.longitude) &&
                  (item.latitude !== 0 || item.longitude !== 0)
              );

            resolve(items);
          } catch (_) {
            resolve([]);
          }
        });
      }
    );

    req.on('timeout', () => {
      req.destroy();
      resolve([]);
    });

    req.on('error', () => {
      resolve([]);
    });
  });
}

/**
 * Helper to query external geocoding provider (Google, Goong, Photon or Nominatim) with strict timeout
 */
export async function fetchExternalGeocoding(searchQuery: string): Promise<GeocodingResultItem[]> {
  const apiKey = process.env.GEOCODING_API_KEY;
  const provider = (process.env.GEOCODING_PROVIDER || 'osm').toLowerCase();

  // 1. Nếu có cấu hình Google Maps Geocoding API
  if (apiKey && provider === 'google') {
    return new Promise((resolve) => {
      const encoded = encodeURIComponent(searchQuery);
      const url = `https://maps.googleapis.com/maps/api/geocode/json?address=${encoded}&components=country:VN&key=${apiKey}`;
      const req = https.get(url, { timeout: 3500 }, (res) => {
        if (res.statusCode !== 200) { resolve([]); return; }
        let raw = '';
        res.on('data', c => raw += c);
        res.on('end', () => {
          try {
            const json = JSON.parse(raw);
            const items: GeocodingResultItem[] = (json.results || []).map((r: any) => ({
              displayName: r.formatted_address || searchQuery,
              latitude: r.geometry?.location?.lat,
              longitude: r.geometry?.location?.lng,
              source: 'GOOGLE_MAPS',
            }));
            resolve(items);
          } catch (_) { resolve([]); }
        });
      });
      req.on('error', () => resolve([]));
      req.on('timeout', () => { req.destroy(); resolve([]); });
    });
  }

  // 2. Mặc định dùng Photon (OSM-based Geocoding engine tối ưu cho search autocomplete)
  const photonResults = await fetchFromPhoton(searchQuery);
  if (photonResults.length > 0) {
    return photonResults;
  }

  // 3. Fallback sang Nominatim OSM
  return new Promise((resolve) => {
    const encoded = encodeURIComponent(searchQuery);
    const url = `https://nominatim.openstreetmap.org/search?q=${encoded}&format=json&countrycodes=vn&limit=5&addressdetails=1`;

    const req = https.get(
      url,
      {
        headers: {
          'User-Agent': 'DeliveryLocationMarker/1.0 (contact: admin@deliverymarker.local)',
          'Accept': 'application/json',
        },
        timeout: 2500,
      },
      (res) => {
        if (res.statusCode !== 200) {
          resolve([]);
          return;
        }

        let rawData = '';
        res.on('data', (chunk) => {
          rawData += chunk;
        });

        res.on('end', () => {
          try {
            const parsed = JSON.parse(rawData);
            if (!Array.isArray(parsed)) {
              resolve([]);
              return;
            }

            const items: GeocodingResultItem[] = parsed.map((item: any) => ({
              displayName: item.display_name || item.name || searchQuery,
              latitude: parseFloat(item.lat),
              longitude: parseFloat(item.lon),
              source: 'NOMINATIM_OSM',
            }));

            resolve(items);
          } catch (_) {
            resolve([]);
          }
        });
      }
    );

    req.on('timeout', () => {
      req.destroy();
      resolve([]);
    });

    req.on('error', () => {
      resolve([]);
    });
  });
}

/**
 * GET /api/v1/geocoding/search?q=...
 * Tra cứu địa chỉ sang tọa độ địa lý (Geocoding)
 * Hỗ trợ tìm kiếm địa chỉ đường phố, kết hợp dữ liệu điểm giao thực tế trong CSDL
 */
export const searchAddress = async (req: AuthenticatedRequest, res: Response) => {
  const q = req.query.q as string;

  if (!q || q.trim().length < 2) {
    return res.status(400).json({
      success: false,
      message: 'Từ khóa tìm kiếm địa chỉ phải có ít nhất 2 ký tự',
    });
  }

  const queryStr = q.trim();

  try {
    // 1. Tìm kiếm trong CSDL cục bộ (Khách hàng & Vị trí đã lưu phù hợp, có hỗ trợ không dấu unaccent)
    let localRes;
    try {
      localRes = await query(
        `SELECT c.full_name, c.address_text, sl.latitude, sl.longitude, sl.identification_notes
         FROM customers c
         JOIN saved_locations sl ON sl.customer_id = c.id
         WHERE unaccent(COALESCE(c.address_text, '')) ILIKE unaccent($1) 
            OR unaccent(COALESCE(sl.identification_notes, '')) ILIKE unaccent($1) 
            OR unaccent(c.full_name) ILIKE unaccent($1)
         UNION ALL
         SELECT c.full_name, c.address_text, sdp.latitude, sdp.longitude, sdp.identification_notes
         FROM shift_delivery_points sdp
         JOIN customers c ON c.id = sdp.customer_id
         WHERE sdp.latitude IS NOT NULL AND sdp.longitude IS NOT NULL
           AND (unaccent(COALESCE(c.address_text, '')) ILIKE unaccent($1) 
                OR unaccent(COALESCE(sdp.identification_notes, '')) ILIKE unaccent($1) 
                OR unaccent(c.full_name) ILIKE unaccent($1))
         LIMIT 6`,
        [`%${queryStr}%`]
      );
    } catch (_) {
      // Fallback nếu extension unaccent chưa có trong môi trường test
      localRes = await query(
        `SELECT c.full_name, c.address_text, sl.latitude, sl.longitude, sl.identification_notes
         FROM customers c
         JOIN saved_locations sl ON sl.customer_id = c.id
         WHERE c.address_text ILIKE $1 OR sl.identification_notes ILIKE $1 OR c.full_name ILIKE $1
         LIMIT 6`,
        [`%${queryStr}%`]
      );
    }

    const localResults: GeocodingResultItem[] = localRes.rows.map((row) => ({
      displayName: `${row.address_text || row.full_name} (${row.full_name}${row.identification_notes ? ' - ' + row.identification_notes : ''})`,
      latitude: parseFloat(row.latitude),
      longitude: parseFloat(row.longitude),
      source: 'LOCAL_DATABASE',
    }));

    // 2. Tra cứu dịch vụ Geocoding bên ngoài (Nominatim OSM)
    const externalResults = await fetchExternalGeocoding(queryStr);

    // 3. Hợp nhất kết quả và khử trùng lặp theo bán kính tọa độ
    const combined = [...localResults, ...externalResults];
    const uniqueResults: GeocodingResultItem[] = [];

    for (const item of combined) {
      if (isNaN(item.latitude) || isNaN(item.longitude)) continue;
      const duplicate = uniqueResults.some(
        (u) => Math.abs(u.latitude - item.latitude) < 0.0002 && Math.abs(u.longitude - item.longitude) < 0.0002
      );
      if (!duplicate) {
        uniqueResults.push(item);
      }
    }

    return res.status(200).json({
      success: true,
      data: uniqueResults.slice(0, 8),
    });
  } catch (error: any) {
    return res.status(500).json({
      success: false,
      message: 'Lỗi trong quá trình tra cứu địa chỉ',
      error: error.message,
    });
  }
};
