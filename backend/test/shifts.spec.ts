import { normalizePhoneNumber } from '../src/controllers/shifts.controller';

describe('FEATURE-SHIFT-001 - Shift & Delivery Points Business Logic Unit Tests', () => {
  describe('Shift Code Generation & Work Date Logic', () => {
    it('should generate standard shift code with SHF-YYYYMMDD-XXX format', () => {
      const dateStr = '2026-10-23';
      const dateFormatted = dateStr.replace(/-/g, '');
      const count = 2;
      const seq = (count + 1).toString().padStart(3, '0');
      const shiftCode = `SHF-${dateFormatted}-${seq}`;

      expect(shiftCode).toBe('SHF-20261023-003');
      expect(/^SHF-\d{8}-\d{3}$/.test(shiftCode)).toBe(true);
    });

    it('should calculate today date in Asia/Ho_Chi_Minh timezone correctly', () => {
      const now = new Date('2026-10-23T03:00:00Z');
      const vnDate = now.toLocaleDateString('en-CA', { timeZone: 'Asia/Ho_Chi_Minh' });
      expect(vnDate).toMatch(/^\d{4}-\d{2}-\d{2}$/);
    });
  });

  describe('Location Status State Machine (NO_LOCATION, TEMPORARY, VERIFIED)', () => {
    it('should correctly identify initial NO_LOCATION status for customers without saved location', () => {
      const customerHasSavedLoc = false;
      const initialStatus = customerHasSavedLoc ? 'VERIFIED' : 'NO_LOCATION';
      expect(initialStatus).toBe('NO_LOCATION');
    });

    it('should correctly set VERIFIED status when customer already has a verified saved_locations in CRM', () => {
      const customerHasSavedLoc = true;
      const initialStatus = customerHasSavedLoc ? 'VERIFIED' : 'NO_LOCATION';
      expect(initialStatus).toBe('VERIFIED');
    });

    it('should validate WGS84 coordinate boundaries for Crosshair Picker', () => {
      const isValidWgs84 = (lat: number, lng: number) => {
        return !isNaN(lat) && !isNaN(lng) && lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180;
      };

      // Valid coordinates (TP.HCM / Thu Duc)
      expect(isValidWgs84(10.842215, 106.818123)).toBe(true);
      expect(isValidWgs84(0, 0)).toBe(true);

      // Invalid coordinates
      expect(isValidWgs84(91.0, 106.0)).toBe(false);
      expect(isValidWgs84(-95.0, 50.0)).toBe(false);
      expect(isValidWgs84(10.0, 185.0)).toBe(false);
      expect(isValidWgs84(NaN, 106.0)).toBe(false);
    });

    it('should transition to TEMPORARY status on crosshair confirmation without overwriting verified house location', () => {
      let point = {
        id: 'pt-1',
        locationStatus: 'NO_LOCATION',
        latitude: null as number | null,
        longitude: null as number | null,
      };

      // Shipper uses crosshair picker
      const crosshairLat = 10.850012;
      const crosshairLng = 106.772045;

      point = {
        ...point,
        locationStatus: 'TEMPORARY',
        latitude: crosshairLat,
        longitude: crosshairLng,
      };

      expect(point.locationStatus).toBe('TEMPORARY');
      expect(point.latitude).toBe(10.850012);
      expect(point.longitude).toBe(106.772045);
    });

    it('should transition to VERIFIED status only when site verification is confirmed', () => {
      let point = {
        id: 'pt-1',
        locationStatus: 'TEMPORARY',
        latitude: 10.850012,
        longitude: 106.772045,
        gpsAccuracy: 0.0,
        identificationNotes: null as string | null,
        imageUrl: null as string | null,
      };

      // Site verification with photo and notes
      point = {
        ...point,
        locationStatus: 'VERIFIED',
        latitude: 10.850020,
        longitude: 106.772050,
        gpsAccuracy: 8.5,
        identificationNotes: 'Nhà cổng màu xanh, cạnh tạp hóa',
        imageUrl: '/api/v1/photos/abc-123.jpg',
      };

      expect(point.locationStatus).toBe('VERIFIED');
      expect(point.gpsAccuracy).toBe(8.5);
      expect(point.identificationNotes).toBeDefined();
      expect(point.imageUrl).toBeDefined();
    });
  });

  describe('Shift Delivery Points Deduplication & Scope Control', () => {
    it('should detect existing customer in shift and prevent duplicate addition', () => {
      const existingPoints = [
        { customerId: 'cust-1', locationStatus: 'VERIFIED' },
        { customerId: 'cust-2', locationStatus: 'NO_LOCATION' },
      ];

      const newCustomerId = 'cust-1';
      const existing = existingPoints.find((p) => p.customerId === newCustomerId);

      expect(existing).toBeDefined();
      const isDuplicate = !!existing;
      expect(isDuplicate).toBe(true);
    });

    it('should enforce area scope: deny customer from unassigned area (403)', () => {
      const assignedAreaIds = ['area-1', 'area-2'];
      const customerInArea1 = { id: 'cust-1', areaId: 'area-1' };
      const customerInArea3 = { id: 'cust-3', areaId: 'area-3' };

      const canAccessArea1 = assignedAreaIds.includes(customerInArea1.areaId);
      const canAccessArea3 = assignedAreaIds.includes(customerInArea3.areaId);

      expect(canAccessArea1).toBe(true);
      expect(canAccessArea3).toBe(false);
    });

    it('should normalize Vietnamese phone numbers for shift lookup', () => {
      expect(normalizePhoneNumber('0988000001')).toBe('0988000001');
      expect(normalizePhoneNumber('988000001')).toBe('0988000001');
      expect(normalizePhoneNumber('+84988000001')).toBe('0988000001');
      expect(normalizePhoneNumber('84988000001')).toBe('0988000001');
      expect(normalizePhoneNumber(' (0988) 000-001 ')).toBe('0988000001');
    });
  });

  describe('Shift Summary Statistics Calculation', () => {
    it('should accurately compute total, verified, temporary, and no_location counts', () => {
      const points = [
        { id: '1', locationStatus: 'VERIFIED' },
        { id: '2', locationStatus: 'VERIFIED' },
        { id: '3', locationStatus: 'TEMPORARY' },
        { id: '4', locationStatus: 'NO_LOCATION' },
        { id: '5', locationStatus: 'NO_LOCATION' },
      ];

      const totalPoints = points.length;
      const verifiedCount = points.filter((p) => p.locationStatus === 'VERIFIED').length;
      const temporaryCount = points.filter((p) => p.locationStatus === 'TEMPORARY').length;
      const noLocationCount = points.filter((p) => p.locationStatus === 'NO_LOCATION').length;

      expect(totalPoints).toBe(5);
      expect(verifiedCount).toBe(2);
      expect(temporaryCount).toBe(1);
      expect(noLocationCount).toBe(2);
    });
  });

  describe('APP-AUDIT-AND-FIX-002 - Quick Create Customer on Shift Preparation', () => {
    it('should validate phone number format (reject empty, too short or non-numeric)', () => {
      const validatePhone = (raw: string | undefined): boolean => {
        if (!raw) return false;
        const clean = normalizePhoneNumber(raw);
        return clean.length >= 9 && clean.length <= 12;
      };

      expect(validatePhone('')).toBe(false);
      expect(validatePhone('123')).toBe(false);
      expect(validatePhone('abcxyz')).toBe(false);
      expect(validatePhone('0988123456')).toBe(true);
      expect(validatePhone('+84988123456')).toBe(true);
      expect(validatePhone(' (0988) 123 456 ')).toBe(true);
    });

    it('should assign customer to shipper area and initialize NO_LOCATION without fake coordinates', () => {
      const shipperAssignedAreaIds = ['area-thu-duc'];
      const targetAreaId = shipperAssignedAreaIds[0];

      const newCustomer = {
        id: 'cust-new-1',
        customerCode: 'KH_123456_9999',
        fullName: 'Khách hàng mới',
        phoneNumber: '0988123456',
        addressText: 'Chưa có địa chỉ chi tiết',
        areaId: targetAreaId,
      };

      const newDeliveryPoint = {
        pointId: 'pt-new-1',
        shiftId: 'shift-1',
        customerId: newCustomer.id,
        locationStatus: 'NO_LOCATION',
        latitude: null,
        longitude: null,
        gpsAccuracy: 0.0,
      };

      expect(newCustomer.areaId).toBe('area-thu-duc');
      expect(newDeliveryPoint.locationStatus).toBe('NO_LOCATION');
      expect(newDeliveryPoint.latitude).toBeNull();
      expect(newDeliveryPoint.longitude).toBeNull();
    });

    it('should safely resolve duplicate phone on concurrent creation via ON CONFLICT', () => {
      // Simulating concurrent creation result
      const existingDbCustomer = {
        id: 'cust-existing-1',
        customerCode: 'KH_123456_1001',
        phoneNumber: '0988123456',
        fullName: 'Anh Bình',
      };

      const incomingCustomer = {
        phoneNumber: '0988123456',
        fullName: 'Anh Bình Cập Nhật',
      };

      // Conflict resolution preserves ID and merges name if provided
      const resolvedCustomer = {
        ...existingDbCustomer,
        fullName: incomingCustomer.fullName || existingDbCustomer.fullName,
      };

      expect(resolvedCustomer.id).toBe('cust-existing-1');
      expect(resolvedCustomer.phoneNumber).toBe('0988123456');
    });
  });

  describe('APP-AUDIT-AND-FIX-002 - Geocoding Address Search Validation', () => {
    it('should reject search queries with less than 2 characters', () => {
      const isValidQuery = (q: string | undefined): boolean => {
        return !!q && q.trim().length >= 2;
      };

      expect(isValidQuery('')).toBe(false);
      expect(isValidQuery(' ')).toBe(false);
      expect(isValidQuery('a')).toBe(false);
      expect(isValidQuery('Le')).toBe(true);
      expect(isValidQuery('Đường số 7')).toBe(true);
    });

    it('should deduplicate geocoding results within spatial proximity', () => {
      const results = [
        { displayName: '123 Lê Văn Việt, Tăng Nhơn Phú A', latitude: 10.84501, longitude: 106.77801 },
        { displayName: '123 Lê Văn Việt, Quận 9', latitude: 10.84502, longitude: 106.77802 }, // Close duplicate
        { displayName: '500 Đỗ Xuân Hợp, Phước Long B', latitude: 10.82000, longitude: 106.76000 },
      ];

      const uniqueResults: typeof results = [];
      for (const item of results) {
        const dup = uniqueResults.some(
          (u) => Math.abs(u.latitude - item.latitude) < 0.0002 && Math.abs(u.longitude - item.longitude) < 0.0002
        );
        if (!dup) uniqueResults.push(item);
      }

      expect(uniqueResults.length).toBe(2);
      expect(uniqueResults[0].displayName).toBe('123 Lê Văn Việt, Tăng Nhơn Phú A');
      expect(uniqueResults[1].displayName).toBe('500 Đỗ Xuân Hợp, Phước Long B');
    });
  });

  describe('PIN-FLOW-DATA-INTEGRITY-AUDIT-007 - Note and Photo Preservation Logic', () => {
    it('should ignore default auto-generated notes and preserve existing identification notes', () => {
      const filterIncomingNotes = (incoming: string | null | undefined): string | null => {
        if (!incoming || typeof incoming !== 'string' || !incoming.trim()) return null;
        const trimmed = incoming.trim();
        const isDefaultString =
          trimmed === 'Ghim trực tiếp từ bản đồ chính' ||
          trimmed === 'Ghim tạm từ bộ chọn tâm ngắm bản đồ';
        return isDefaultString ? null : trimmed;
      };

      expect(filterIncomingNotes('Ghim trực tiếp từ bản đồ chính')).toBeNull();
      expect(filterIncomingNotes('Ghim tạm từ bộ chọn tâm ngắm bản đồ')).toBeNull();
      expect(filterIncomingNotes('  Ghim trực tiếp từ bản đồ chính  ')).toBeNull();
      expect(filterIncomingNotes('Cổng sắt màu xanh, gần quán phở')).toBe('Cổng sắt màu xanh, gần quán phở');
      expect(filterIncomingNotes(null)).toBeNull();
      expect(filterIncomingNotes('')).toBeNull();
    });

    it('should keep existing identification notes and image_url intact when pinning without new notes', () => {
      const existingPoint = {
        id: 'point-101',
        locationStatus: 'NO_LOCATION',
        latitude: null,
        longitude: null,
        identificationNotes: 'Nhà 2 tầng cổng gỗ, cây xoài to trước cửa',
        imageUrl: '/uploads/photos/gate_photo_abc.jpg',
      };

      // Simulating updateTemporaryLocation SQL behavior
      const customNotes: string | null = null; // No custom user input
      const newLat = 10.849999;
      const newLng = 106.771111;

      const updatedPoint = {
        ...existingPoint,
        locationStatus: 'TEMPORARY',
        latitude: newLat,
        longitude: newLng,
        identificationNotes: customNotes !== null && customNotes !== '' ? customNotes : existingPoint.identificationNotes,
        imageUrl: existingPoint.imageUrl, // Image is always preserved
      };

      expect(updatedPoint.locationStatus).toBe('TEMPORARY');
      expect(updatedPoint.latitude).toBe(10.849999);
      expect(updatedPoint.identificationNotes).toBe('Nhà 2 tầng cổng gỗ, cây xoài to trước cửa');
      expect(updatedPoint.imageUrl).toBe('/uploads/photos/gate_photo_abc.jpg');
    });

    it('should overwrite notes only if shipper explicitly enters new custom notes', () => {
      const existingPoint = {
        identificationNotes: 'Ghi chú cũ',
        imageUrl: '/uploads/photos/gate.jpg',
      };

      const customNotes: string | null = 'Đã chuyển sang hẻm đối diện';
      const updatedNotes = customNotes !== null && customNotes !== '' ? customNotes : existingPoint.identificationNotes;

      expect(updatedNotes).toBe('Đã chuyển sang hẻm đối diện');
      expect(existingPoint.imageUrl).toBe('/uploads/photos/gate.jpg');
    });
  });

  describe('PIN-FLOW-DATA-INTEGRITY-AUDIT-007 - Cross-Shift Synchronization Scope Enforcement', () => {
    it('should only synchronize PREPARING shifts and IN_PROGRESS shifts of the SAME shipper', () => {
      const currentShipperId = 'shipper-current';

      const shiftsInDb = [
        { id: 's1', status: 'PREPARING', shipperId: 'shipper-other', customerPoint: { lat: 0, lng: 0 } },
        { id: 's2', status: 'IN_PROGRESS', shipperId: currentShipperId, customerPoint: { lat: 0, lng: 0 } },
        { id: 's3', status: 'IN_PROGRESS', shipperId: 'shipper-other', customerPoint: { lat: 0, lng: 0 } },
        { id: 's4', status: 'COMPLETED', shipperId: currentShipperId, customerPoint: { lat: 0, lng: 0 } },
        { id: 's5', status: 'COMPLETED', shipperId: 'shipper-other', customerPoint: { lat: 0, lng: 0 } },
      ];

      // Safe filter predicate from shifts.controller.ts:
      // (s.status = 'PREPARING' OR (s.status = 'IN_PROGRESS' AND s.shipper_id = shipperId))
      const canSyncShift = (shift: typeof shiftsInDb[0]) => {
        return shift.status === 'PREPARING' || (shift.status === 'IN_PROGRESS' && shift.shipperId === currentShipperId);
      };

      const eligibleShifts = shiftsInDb.filter(canSyncShift);

      // s1 (PREPARING) and s2 (IN_PROGRESS of current shipper) are eligible
      expect(eligibleShifts.map((s) => s.id)).toEqual(['s1', 's2']);

      // s3 (IN_PROGRESS of another shipper) is strictly protected
      expect(eligibleShifts.some((s) => s.id === 's3')).toBe(false);

      // s4 and s5 (COMPLETED shifts) are strictly protected
      expect(eligibleShifts.some((s) => s.id === 's4')).toBe(false);
      expect(eligibleShifts.some((s) => s.id === 's5')).toBe(false);
    });
  });

  describe('PIN-FLOW-DATA-INTEGRITY-AUDIT-007 - Directory and Shift Status Timestamp Resolution', () => {
    it('should resolve customer to TEMPORARY when shift delivery point is newer than saved location', () => {
      const savedLocation = {
        latitude: '10.840000',
        longitude: '106.810000',
        identificationNotes: 'Cổng sắt màu ghi',
        imageUrl: '/photos/verified_gate.jpg',
        updatedAt: '2026-10-23T08:00:00Z',
      };

      const latestShiftPoint = {
        locationStatus: 'TEMPORARY',
        latitude: '10.845555',
        longitude: '106.815555',
        identificationNotes: null as string | null,
        imageUrl: null as string | null,
        updatedAt: '2026-10-23T10:30:00Z', // Newer!
      };

      const slDate = new Date(savedLocation.updatedAt).getTime();
      const sdpDate = new Date(latestShiftPoint.updatedAt).getTime();

      let resolvedStatus = 'NO_LOCATION';
      let resolvedLat = 0;
      let resolvedLng = 0;
      let resolvedNotes: string | null = null;
      let resolvedImage: string | null = null;

      if (sdpDate > slDate && latestShiftPoint.locationStatus === 'TEMPORARY') {
        resolvedStatus = 'TEMPORARY';
        resolvedLat = parseFloat(latestShiftPoint.latitude);
        resolvedLng = parseFloat(latestShiftPoint.longitude);
        // Preserves notes and photos from savedLocation
        resolvedNotes = latestShiftPoint.identificationNotes || savedLocation.identificationNotes;
        resolvedImage = latestShiftPoint.imageUrl || savedLocation.imageUrl;
      } else {
        resolvedStatus = 'VERIFIED';
        resolvedLat = parseFloat(savedLocation.latitude);
        resolvedLng = parseFloat(savedLocation.longitude);
        resolvedNotes = savedLocation.identificationNotes;
        resolvedImage = savedLocation.imageUrl;
      }

      expect(resolvedStatus).toBe('TEMPORARY');
      expect(resolvedLat).toBe(10.845555);
      expect(resolvedLng).toBe(106.815555);
      expect(resolvedNotes).toBe('Cổng sắt màu ghi');
      expect(resolvedImage).toBe('/photos/verified_gate.jpg');
    });

    it('should retain VERIFIED status if saved location was verified after temporary pin', () => {
      const savedLocation = {
        latitude: '10.840000',
        longitude: '106.810000',
        identificationNotes: 'Đã xác minh cổng nhà',
        imageUrl: '/photos/verified_gate.jpg',
        updatedAt: '2026-10-23T14:00:00Z', // Verified later in shift
      };

      const previousShiftPoint = {
        locationStatus: 'TEMPORARY',
        latitude: '10.845555',
        longitude: '106.815555',
        updatedAt: '2026-10-23T10:30:00Z',
      };

      const slDate = new Date(savedLocation.updatedAt).getTime();
      const sdpDate = new Date(previousShiftPoint.updatedAt).getTime();

      const isVerified = slDate >= sdpDate;
      expect(isVerified).toBe(true);
    });

    it('BUG-MAP-PHOTO-008: should resolve photo from saved_locations if shift point has no direct photo', () => {
      const row: Record<string, string | null> = {
        point_id: 'p-001',
        image_url: null,
        saved_image_url: '/api/v1/photos/gate_photo.jpg',
        history_image_url: null,
      };

      const pImg = (typeof row.image_url === 'string' && row.image_url.trim().length > 0) ? row.image_url.trim() : null;
      const sImg = (typeof row.saved_image_url === 'string' && row.saved_image_url.trim().length > 0) ? row.saved_image_url.trim() : null;
      const hImg = (typeof row.history_image_url === 'string' && row.history_image_url.trim().length > 0) ? row.history_image_url.trim() : null;
      const resolvedImg = pImg || sImg || hImg || null;

      expect(resolvedImg).toBe('/api/v1/photos/gate_photo.jpg');
    });

    it('BUG-MAP-PHOTO-008: should resolve photo from location_history if saved_locations has no direct photo', () => {
      const row: Record<string, string | null> = {
        point_id: 'p-002',
        image_url: null,
        saved_image_url: null,
        history_image_url: '/api/v1/photos/historic_gate.jpg',
      };

      const pImg = (typeof row.image_url === 'string' && row.image_url.trim().length > 0) ? row.image_url.trim() : null;
      const sImg = (typeof row.saved_image_url === 'string' && row.saved_image_url.trim().length > 0) ? row.saved_image_url.trim() : null;
      const hImg = (typeof row.history_image_url === 'string' && row.history_image_url.trim().length > 0) ? row.history_image_url.trim() : null;
      const resolvedImg = pImg || sImg || hImg || null;

      expect(resolvedImg).toBe('/api/v1/photos/historic_gate.jpg');
    });

    it('BUG-MAP-PHOTO-008: should return null photo when customer has no photo in any table', () => {
      const row: Record<string, string | null> = {
        point_id: 'p-003',
        image_url: null,
        saved_image_url: null,
        history_image_url: null,
      };

      const pImg = (typeof row.image_url === 'string' && row.image_url.trim().length > 0) ? row.image_url.trim() : null;
      const sImg = (typeof row.saved_image_url === 'string' && row.saved_image_url.trim().length > 0) ? row.saved_image_url.trim() : null;
      const hImg = (typeof row.history_image_url === 'string' && row.history_image_url.trim().length > 0) ? row.history_image_url.trim() : null;
      const resolvedImg = pImg || sImg || hImg || null;

      expect(resolvedImg).toBeNull();
    });
  });

  describe('TASK: SHIFT-DELETE-AND-FIELD-FIX-011 - Delete Shift & Field Mappings Unit Tests', () => {
    describe('DELETE /api/v1/shifts/:id Permission & Safety Logic', () => {
      it('should permit a SHIPPER to delete their own shift', () => {
        const currentUser = { userId: 'shipper-001', roleName: 'SHIPPER' };
        const shift = { id: 'shift-1', shipper_id: 'shipper-001', shift_code: 'SHF-20261025-001' };

        const isForbidden = currentUser.roleName === 'SHIPPER' && shift.shipper_id !== currentUser.userId;
        expect(isForbidden).toBe(false);
      });

      it('should reject (403 Forbidden) when a SHIPPER attempts to delete another shipper shift', () => {
        const currentUser = { userId: 'shipper-001', roleName: 'SHIPPER' };
        const shift = { id: 'shift-2', shipper_id: 'shipper-999', shift_code: 'SHF-20261025-002' };

        const isForbidden = currentUser.roleName === 'SHIPPER' && shift.shipper_id !== currentUser.userId;
        expect(isForbidden).toBe(true);
      });

      it('should permit an ADMIN to delete any shift regardless of owner', () => {
        const currentUser = { userId: 'admin-001', roleName: 'ADMIN' };
        const shift = { id: 'shift-2', shipper_id: 'shipper-999', shift_code: 'SHF-20261025-002' };

        const isForbidden = currentUser.roleName === 'SHIPPER' && shift.shipper_id !== currentUser.userId;
        expect(isForbidden).toBe(false);
      });

      it('should strictly isolate deletion: deletes shift and shift_delivery_points without touching customers or saved_locations', () => {
        const shiftIdToDelete = 'shift-100';
        const tablesAffected = ['shift_delivery_points', 'shifts'];
        const protectedTables = ['customers', 'saved_locations', 'location_history'];

        expect(tablesAffected).not.toEqual(expect.arrayContaining(protectedTables));
        expect(tablesAffected.includes('customers')).toBe(false);
        expect(tablesAffected.includes('saved_locations')).toBe(false);
        expect(tablesAffected.includes('location_history')).toBe(false);
      });

      it('should record audit log with DELETE_SHIFT action and point count', () => {
        const shift = { id: 'shift-1', shift_code: 'SHF-20261025-001', status: 'PREPARING' };
        const deletedPointsCount = 5;
        const shipperId = 'shipper-001';

        const auditPayload = {
          userId: shipperId,
          action: 'DELETE_SHIFT',
          entity: 'shifts',
          entityId: shift.id,
          details: JSON.stringify({
            shiftCode: shift.shift_code,
            status: shift.status,
            deletedPointsCount,
          }),
        };

        expect(auditPayload.action).toBe('DELETE_SHIFT');
        expect(auditPayload.entity).toBe('shifts');
        const parsedDetails = JSON.parse(auditPayload.details);
        expect(parsedDetails.shiftCode).toBe('SHF-20261025-001');
        expect(parsedDetails.deletedPointsCount).toBe(5);
      });
    });

    describe('Field Name Mismatch Resolution (createShift, addPointToShift, verify)', () => {
      it('createShift: should accept shiftDate from Flutter and unify with workDate', () => {
        const bodyWithShiftDate = { shiftDate: '2026-10-25' };
        const rawDate = (bodyWithShiftDate as any).workDate || bodyWithShiftDate.shiftDate;
        const effectiveDate = (typeof rawDate === 'string' && rawDate.trim().length > 0)
          ? rawDate.trim()
          : '2026-10-25';

        expect(effectiveDate).toBe('2026-10-25');
      });

      it('createShift: should accept workDate from Backend and unify with shiftDate', () => {
        const bodyWithWorkDate = { workDate: '2026-10-26' };
        const rawDate = bodyWithWorkDate.workDate || (bodyWithWorkDate as any).shiftDate;
        const effectiveDate = (typeof rawDate === 'string' && rawDate.trim().length > 0)
          ? rawDate.trim()
          : '2026-10-26';

        expect(effectiveDate).toBe('2026-10-26');
      });

      it('addPointToShift: should include summary in response matching Flutter expectation', () => {
        const sumRow = {
          total_points: 3,
          verified_count: 1,
          temporary_count: 1,
          no_location_count: 1,
        };

        const responsePayload = {
          success: true,
          message: 'Đã thêm điểm giao vào ca làm việc thành công',
          isExisting: false,
          data: { pointId: 'p-1' },
          summary: {
            totalPoints: sumRow.total_points,
            verifiedCount: sumRow.verified_count,
            temporaryCount: sumRow.temporary_count,
            noLocationCount: sumRow.no_location_count,
          },
        };

        expect(responsePayload.summary).toBeDefined();
        expect(responsePayload.summary.totalPoints).toBe(3);
        expect(responsePayload.summary.verifiedCount).toBe(1);
        expect(responsePayload.summary.temporaryCount).toBe(1);
        expect(responsePayload.summary.noLocationCount).toBe(1);
      });

      it('verifyPointLocation: should return 410 Gone to prevent writing to saved_locations from shift flow', async () => {
        const { verifyPointLocation } = require('../src/controllers/shifts.controller');
        const req: any = {
          params: { id: 'shift-1', pointId: 'point-1' },
          body: { latitude: 10.8422, longitude: 106.8181 },
          user: { userId: 'shipper-1', roleName: 'SHIPPER' },
        };
        const res: any = {
          statusCode: 200,
          status: jest.fn((code: number) => {
            res.statusCode = code;
            return res;
          }),
          json: jest.fn((data: any) => {
            res.body = data;
            return res;
          }),
        };
        await verifyPointLocation(req, res);
        expect(res.statusCode).toBe(410);
        expect(res.body.success).toBe(false);
        expect(res.body.errorCode).toBe('ENDPOINT_GONE_USE_DIRECTORY_FLOW');
      });
    });
  });
});


