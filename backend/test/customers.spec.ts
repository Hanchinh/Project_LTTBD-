import { normalizePhoneNumber } from '../src/controllers/customers.controller';

describe('MAP-FIRST-ARCHITECTURE-005 - Customer Directory & Location Management Unit Tests', () => {
  describe('Customer Phone Normalization & Validation', () => {
    it('should normalize Vietnam phone number with leading 0', () => {
      expect(normalizePhoneNumber('0901234567')).toBe('0901234567');
      expect(normalizePhoneNumber('+84901234567')).toBe('0901234567');
      expect(normalizePhoneNumber('84901234567')).toBe('0901234567');
      expect(normalizePhoneNumber('090-123-4567')).toBe('0901234567');
      expect(normalizePhoneNumber('090 123 4567')).toBe('0901234567');
    });

    it('should reject invalid or too short phone numbers', () => {
      const clean = normalizePhoneNumber('123');
      expect(clean.length < 9).toBe(true);
    });
  });

  describe('Directory Search & Filter Logic', () => {
    const mockCustomers = [
      {
        id: 'c1',
        fullName: 'Anh Hoàng (Tạp hóa Hai Thu)',
        phoneNumber: '0988000001',
        addressText: 'Hẻm 124 Nguyễn Xiển, P. Long Thạnh Mỹ',
        locationStatus: 'VERIFIED',
        latitude: 10.842215,
        longitude: 106.818123,
        imageUrl: '/api/v1/photos/gate-1.jpg',
      },
      {
        id: 'c2',
        fullName: 'Chị Lan Cơm Tấm',
        phoneNumber: '0988000002',
        addressText: 'Đường D1, KCNC',
        locationStatus: 'TEMPORARY',
        latitude: 10.851000,
        longitude: 106.772000,
        imageUrl: null,
      },
      {
        id: 'c3',
        fullName: 'Bác Ba Sửa Xe',
        phoneNumber: '0988000003',
        addressText: 'Ngã tư Thủ Đức',
        locationStatus: 'NO_LOCATION',
        latitude: null,
        longitude: null,
        imageUrl: null,
      },
    ];

    it('should filter customers by status (VERIFIED, TEMPORARY, NO_LOCATION)', () => {
      const verified = mockCustomers.filter((c) => c.locationStatus === 'VERIFIED');
      expect(verified.length).toBe(1);
      expect(verified[0].fullName).toContain('Anh Hoàng');

      const temp = mockCustomers.filter((c) => c.locationStatus === 'TEMPORARY');
      expect(temp.length).toBe(1);
      expect(temp[0].fullName).toContain('Chị Lan');

      const noLoc = mockCustomers.filter((c) => c.locationStatus === 'NO_LOCATION');
      expect(noLoc.length).toBe(1);
      expect(noLoc[0].fullName).toContain('Bác Ba');
    });

    it('should filter customers with and without photo', () => {
      const withPhoto = mockCustomers.filter((c) => !!c.imageUrl);
      expect(withPhoto.length).toBe(1);
      expect(withPhoto[0].id).toBe('c1');

      const withoutPhoto = mockCustomers.filter((c) => !c.imageUrl);
      expect(withoutPhoto.length).toBe(2);
    });

    it('should perform text search matching name, phone, or address', () => {
      const search = (query: string) => {
        const q = query.toLowerCase();
        return mockCustomers.filter(
          (c) =>
            c.fullName.toLowerCase().includes(q) ||
            c.phoneNumber.includes(q) ||
            c.addressText.toLowerCase().includes(q)
        );
      };

      expect(search('0988000002').length).toBe(1);
      expect(search('Nguyễn Xiển').length).toBe(1);
      expect(search('Thủ Đức').length).toBe(1);
      expect(search('Hai Thu').length).toBe(1);
      expect(search('KhongTonTai').length).toBe(0);
    });
  });

  describe('Photo URL Versioning & Cache Busting Logic', () => {
    it('should build cache-busted photo URL with timestamp version', () => {
      const baseUrl = 'http://localhost:3000';
      const photoPath = '/api/v1/photos/uuid-photo-123.jpg';
      const version = 1729699200000;

      const cacheBustedUrl = `${baseUrl}${photoPath}?v=${version}`;
      expect(cacheBustedUrl).toContain('?v=1729699200000');
      expect(cacheBustedUrl.startsWith('http://localhost:3000/api/v1/photos/')).toBe(true);
    });

    it('should handle photo deletion by updating imageUrl to null', () => {
      let location = {
        id: 'loc-1',
        imageUrl: '/api/v1/photos/old-photo.jpg' as string | null,
        deletePhotoRequested: true,
      };

      if (location.deletePhotoRequested) {
        location.imageUrl = null;
      }

      expect(location.imageUrl).toBeNull();
    });
  });
});
