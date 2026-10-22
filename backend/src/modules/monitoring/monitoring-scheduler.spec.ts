import { MonitoringScheduler } from './monitoring-scheduler';
import { MonitoringScheduleWindow } from './entities/monitoring-schedule-window.entity';

describe('MonitoringScheduler', () => {
  it('should return true for empty windows (24/7 monitoring)', () => {
    expect(MonitoringScheduler.isWithinActiveWindow(new Date(), [])).toBe(true);
  });

  it('should correctly evaluate daytime time ranges', () => {
    expect(MonitoringScheduler.isTimeBetween('08:00', '07:00', '22:00')).toBe(true);
    expect(MonitoringScheduler.isTimeBetween('23:00', '07:00', '22:00')).toBe(false);
    expect(MonitoringScheduler.isTimeBetween('06:59', '07:00', '22:00')).toBe(false);
  });

  it('should correctly evaluate overnight time ranges', () => {
    expect(MonitoringScheduler.isTimeBetween('23:30', '22:00', '06:00')).toBe(true);
    expect(MonitoringScheduler.isTimeBetween('04:15', '22:00', '06:00')).toBe(true);
    expect(MonitoringScheduler.isTimeBetween('12:00', '22:00', '06:00')).toBe(false);
  });

  it('should check day-of-week and active windows', () => {
    // Fixed reference date: Wednesday 2026-10-07 10:00 AM UTC (17:00 in Asia/Ho_Chi_Minh)
    const testDate = new Date('2026-10-07T10:00:00Z');
    const dayOfWeek = 3; // Wednesday

    const windows: MonitoringScheduleWindow[] = [
      {
        id: '1',
        configId: 'cfg-1',
        config: null as any,
        dayOfWeek,
        startTime: '07:00',
        endTime: '22:00',
        isEnabled: true,
        createdAt: new Date(),
        updatedAt: new Date(),
      },
    ];

    expect(
      MonitoringScheduler.isWithinActiveWindow(testDate, windows, 'Asia/Ho_Chi_Minh'),
    ).toBe(true);
  });

  describe('getNextActiveWindowStart', () => {
    it('should calculate next day window start converted accurately to UTC', () => {
      // Wednesday 23:00 VN (16:00 UTC)
      const testDate = new Date('2026-10-07T16:00:00Z');
      const windows: MonitoringScheduleWindow[] = [
        {
          id: '1',
          configId: 'cfg-1',
          config: null as any,
          dayOfWeek: 4, // Thursday
          startTime: '07:00',
          endTime: '22:00',
          isEnabled: true,
          createdAt: new Date(),
          updatedAt: new Date(),
        },
      ];

      const next = MonitoringScheduler.getNextActiveWindowStart(
        testDate,
        windows,
        'Asia/Ho_Chi_Minh',
      );
      // Thursday 07:00 VN is Thursday 00:00 UTC
      expect(next.toISOString()).toBe('2026-10-08T00:00:00.000Z');
    });

    it('should calculate same day upcoming window start in UTC', () => {
      // Wednesday 05:00 VN (Tuesday 22:00 UTC)
      const testDate = new Date('2026-10-06T22:00:00Z');
      const windows: MonitoringScheduleWindow[] = [
        {
          id: '1',
          configId: 'cfg-1',
          config: null as any,
          dayOfWeek: 3, // Wednesday
          startTime: '07:00',
          endTime: '22:00',
          isEnabled: true,
          createdAt: new Date(),
          updatedAt: new Date(),
        },
      ];

      const next = MonitoringScheduler.getNextActiveWindowStart(
        testDate,
        windows,
        'Asia/Ho_Chi_Minh',
      );
      // Wednesday 07:00 VN is Wednesday 00:00 UTC
      expect(next.toISOString()).toBe('2026-10-07T00:00:00.000Z');
    });

    it('should calculate next window in same day after gap', () => {
      // Wednesday 12:00 VN (05:00 UTC)
      const testDate = new Date('2026-10-07T05:00:00Z');
      const windows: MonitoringScheduleWindow[] = [
        {
          id: '1',
          configId: 'cfg-1',
          config: null as any,
          dayOfWeek: 3,
          startTime: '07:00',
          endTime: '11:00',
          isEnabled: true,
          createdAt: new Date(),
          updatedAt: new Date(),
        },
        {
          id: '2',
          configId: 'cfg-1',
          config: null as any,
          dayOfWeek: 3,
          startTime: '14:00',
          endTime: '18:00',
          isEnabled: true,
          createdAt: new Date(),
          updatedAt: new Date(),
        },
      ];

      const next = MonitoringScheduler.getNextActiveWindowStart(
        testDate,
        windows,
        'Asia/Ho_Chi_Minh',
      );
      // Wednesday 14:00 VN is Wednesday 07:00 UTC
      expect(next.toISOString()).toBe('2026-10-07T07:00:00.000Z');
    });

    it('should jump across weekend gap to next week opening window', () => {
      // Friday 2026-10-09 23:00 VN (16:00 UTC)
      const testDate = new Date('2026-10-09T16:00:00Z');
      const windows: MonitoringScheduleWindow[] = [
        {
          id: '1',
          configId: 'cfg-1',
          config: null as any,
          dayOfWeek: 1, // Monday
          startTime: '08:00',
          endTime: '17:00',
          isEnabled: true,
          createdAt: new Date(),
          updatedAt: new Date(),
        },
      ];

      const next = MonitoringScheduler.getNextActiveWindowStart(
        testDate,
        windows,
        'Asia/Ho_Chi_Minh',
      );
      // Monday 2026-10-12 08:00 VN is Monday 01:00 UTC
      expect(next.toISOString()).toBe('2026-10-12T01:00:00.000Z');
    });

    it('should fallback to 1 hour ahead when no windows enabled', () => {
      const testDate = new Date('2026-10-07T10:00:00Z');
      const next = MonitoringScheduler.getNextActiveWindowStart(
        testDate,
        [],
        'Asia/Ho_Chi_Minh',
      );
      expect(next.getTime()).toBe(testDate.getTime() + 60 * 60 * 1000);
    });
  });

  describe('Timezone Fallback & Overnight Windows', () => {
    it('should safely fallback to Asia/Ho_Chi_Minh on invalid timezone without throwing', () => {
      const testDate = new Date('2026-10-07T10:00:00Z'); // 17:00 VN
      const windows: MonitoringScheduleWindow[] = [
        {
          id: '1',
          configId: 'cfg-1',
          config: null as any,
          dayOfWeek: 3, // Wednesday
          startTime: '08:00',
          endTime: '18:00',
          isEnabled: true,
          createdAt: new Date(),
          updatedAt: new Date(),
        },
      ];

      expect(() => {
        const result = MonitoringScheduler.isWithinActiveWindow(
          testDate,
          windows,
          'Invalid/Timezone_Name',
        );
        expect(result).toBe(true);
      }).not.toThrow();
    });

    it('should maintain active status across midnight for overnight window', () => {
      const windows: MonitoringScheduleWindow[] = [
        {
          id: '1',
          configId: 'cfg-1',
          config: null as any,
          dayOfWeek: 1, // Monday
          startTime: '22:00',
          endTime: '06:00',
          isEnabled: true,
          createdAt: new Date(),
          updatedAt: new Date(),
        },
      ];

      // Monday 23:00 VN = 16:00 UTC
      expect(
        MonitoringScheduler.isWithinActiveWindow(
          new Date('2026-10-05T16:00:00Z'),
          windows,
          'Asia/Ho_Chi_Minh',
        ),
      ).toBe(true);

      // Tuesday 02:00 VN = Monday 19:00 UTC
      expect(
        MonitoringScheduler.isWithinActiveWindow(
          new Date('2026-10-05T19:00:00Z'),
          windows,
          'Asia/Ho_Chi_Minh',
        ),
      ).toBe(true);

      // Tuesday 06:30 VN = Monday 23:30 UTC (Closed)
      expect(
        MonitoringScheduler.isWithinActiveWindow(
          new Date('2026-10-05T23:30:00Z'),
          windows,
          'Asia/Ho_Chi_Minh',
        ),
      ).toBe(false);
    });

    it('should handle overnight window across Sunday-Monday boundary', () => {
      const windows: MonitoringScheduleWindow[] = [
        {
          id: '1',
          configId: 'cfg-1',
          config: null as any,
          dayOfWeek: 0, // Sunday
          startTime: '21:00',
          endTime: '05:00',
          isEnabled: true,
          createdAt: new Date(),
          updatedAt: new Date(),
        },
      ];

      // Sunday 22:00 VN (15:00 UTC) -> inside: TRUE
      expect(
        MonitoringScheduler.isWithinActiveWindow(
          new Date('2026-10-11T15:00:00Z'),
          windows,
          'Asia/Ho_Chi_Minh',
        ),
      ).toBe(true);

      // Monday 03:00 VN (Sunday 20:00 UTC) -> inside: TRUE
      expect(
        MonitoringScheduler.isWithinActiveWindow(
          new Date('2026-10-11T20:00:00Z'),
          windows,
          'Asia/Ho_Chi_Minh',
        ),
      ).toBe(true);

      // Monday 05:30 VN (Sunday 22:30 UTC) -> closed: FALSE
      expect(
        MonitoringScheduler.isWithinActiveWindow(
          new Date('2026-10-11T22:30:00Z'),
          windows,
          'Asia/Ho_Chi_Minh',
        ),
      ).toBe(false);
    });

    it('should handle overnight window across Saturday-Sunday boundary', () => {
      const windows: MonitoringScheduleWindow[] = [
        {
          id: '1',
          configId: 'cfg-1',
          config: null as any,
          dayOfWeek: 6, // Saturday
          startTime: '23:00',
          endTime: '07:00',
          isEnabled: true,
          createdAt: new Date(),
          updatedAt: new Date(),
        },
      ];

      // Saturday 23:30 VN (16:30 UTC) -> inside: TRUE
      expect(
        MonitoringScheduler.isWithinActiveWindow(
          new Date('2026-10-10T16:30:00Z'),
          windows,
          'Asia/Ho_Chi_Minh',
        ),
      ).toBe(true);

      // Sunday 04:00 VN (Saturday 21:00 UTC) -> inside: TRUE
      expect(
        MonitoringScheduler.isWithinActiveWindow(
          new Date('2026-10-10T21:00:00Z'),
          windows,
          'Asia/Ho_Chi_Minh',
        ),
      ).toBe(true);

      // Sunday 07:15 VN (Sunday 00:15 UTC) -> closed: FALSE
      expect(
        MonitoringScheduler.isWithinActiveWindow(
          new Date('2026-10-11T00:15:00Z'),
          windows,
          'Asia/Ho_Chi_Minh',
        ),
      ).toBe(false);
    });
  });

  describe('calculateActiveInactiveMinutes', () => {
    it('should return 0 if lastActive is invalid or in the future', () => {
      const now = new Date('2026-10-06T10:00:00Z');
      expect(MonitoringScheduler.calculateActiveInactiveMinutes(null as any, now, [])).toBe(0);
      expect(MonitoringScheduler.calculateActiveInactiveMinutes(new Date(NaN), now, [])).toBe(0);
      expect(
        MonitoringScheduler.calculateActiveInactiveMinutes(
          new Date('2026-10-06T11:00:00Z'),
          now,
          [],
        ),
      ).toBe(0);
    });

    it('should return wall-clock minutes when windows array is empty (24/7 monitoring)', () => {
      const lastActive = new Date('2026-10-06T08:00:00Z');
      const now = new Date('2026-10-06T10:30:00Z'); // 150 minutes later
      expect(MonitoringScheduler.calculateActiveInactiveMinutes(lastActive, now, [])).toBe(150);
    });

    it('should return 0 when all schedule windows are disabled', () => {
      const lastActive = new Date('2026-10-06T08:00:00Z');
      const now = new Date('2026-10-06T10:30:00Z');
      const windows: MonitoringScheduleWindow[] = [
        {
          id: '1',
          configId: 'cfg-1',
          config: null as any,
          dayOfWeek: 2,
          startTime: '07:00',
          endTime: '22:00',
          isEnabled: false,
          createdAt: new Date(),
          updatedAt: new Date(),
        },
      ];
      expect(MonitoringScheduler.calculateActiveInactiveMinutes(lastActive, now, windows)).toBe(0);
    });

    it('should freeze inactivity timer across overnight quiet hours (zero false alarms upon waking)', () => {
      // Monday 2026-10-05: active window 07:00 to 22:00 VN
      // Tuesday 2026-10-06: active window 07:00 to 22:00 VN
      const windows: MonitoringScheduleWindow[] = [
        {
          id: '1',
          configId: 'cfg-1',
          config: null as any,
          dayOfWeek: 1, // Monday
          startTime: '07:00',
          endTime: '22:00',
          isEnabled: true,
          createdAt: new Date(),
          updatedAt: new Date(),
        },
        {
          id: '2',
          configId: 'cfg-1',
          config: null as any,
          dayOfWeek: 2, // Tuesday
          startTime: '07:00',
          endTime: '22:00',
          isEnabled: true,
          createdAt: new Date(),
          updatedAt: new Date(),
        },
      ];

      // Senior was active at 21:00 VN Monday (14:00 UTC) -> 1 hour before quiet hours
      const lastActive = new Date('2026-10-05T14:00:00Z');
      // Senior wakes up at 07:05 VN Tuesday (00:05 UTC) -> 5 min after active window reopens
      const now = new Date('2026-10-06T00:05:00Z');

      // Total wall-clock elapsed: 10 hours 5 minutes = 605 minutes.
      // Active awake elapsed: 60 minutes (21:00-22:00) + 5 minutes (07:00-07:05) = 65 minutes!
      const activeMinutes = MonitoringScheduler.calculateActiveInactiveMinutes(
        lastActive,
        now,
        windows,
        'Asia/Ho_Chi_Minh',
      );
      expect(activeMinutes).toBe(65);
    });

    it('should correctly calculate active minutes for overnight active window', () => {
      // Active window is overnight: Monday 22:00 to 06:00 VN
      const windows: MonitoringScheduleWindow[] = [
        {
          id: '1',
          configId: 'cfg-1',
          config: null as any,
          dayOfWeek: 1, // Monday
          startTime: '22:00',
          endTime: '06:00',
          isEnabled: true,
          createdAt: new Date(),
          updatedAt: new Date(),
        },
      ];

      // Last active: Monday 21:00 VN (14:00 UTC)
      // Now: Tuesday 04:00 VN (Monday 21:00 UTC)
      // Active between 22:00 and 04:00 = 6 hours = 360 minutes
      const lastActive = new Date('2026-10-05T14:00:00Z');
      const now = new Date('2026-10-05T21:00:00Z');

      const activeMinutes = MonitoringScheduler.calculateActiveInactiveMinutes(
        lastActive,
        now,
        windows,
        'Asia/Ho_Chi_Minh',
      );
      expect(activeMinutes).toBe(360);
    });
  });
});
