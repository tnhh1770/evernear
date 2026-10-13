import { describe, it, expect, beforeAll, afterAll } from 'vitest';
import { Test, TestingModule } from '@nestjs/testing';
import { INestApplication, ValidationPipe } from '@nestjs/common';
import { DataSource } from 'typeorm';
import request from 'supertest';
import { AppModule } from '../src/app.module';
import { AuthService } from '../src/modules/auth/auth.service';
import { DevicesService } from '../src/modules/devices/devices.service';
import { MonitoringService } from '../src/modules/monitoring/monitoring.service';
import { ActivityService } from '../src/modules/activities/activity.service';
import { CheckInsService } from '../src/modules/check-ins/check-ins.service';
import { MonitoringScheduler } from '../src/modules/monitoring/monitoring-scheduler';
import { MonitoringConfig } from '../src/modules/monitoring/entities/monitoring-config.entity';
import { MonitoringScheduleWindow } from '../src/modules/monitoring/entities/monitoring-schedule-window.entity';
import { Incident } from '../src/modules/incidents/entities/incident.entity';
import { Activity } from '../src/modules/activities/entities/activity.entity';
import { CheckIn } from '../src/modules/check-ins/entities/check-in.entity';
import {
  ActivityType,
  DevicePlatform,
  MonitoringState,
  IncidentStatus,
  IncidentReason,
} from '../src/common/enums';
import { v4 as uuidv4 } from 'uuid';
import { resetDatabase, teardownE2eTestApp } from './e2e/e2e-helper';

describe('M1 Challenger Empirical Stress Harness', () => {
  let app: INestApplication;
  let dataSource: DataSource;
  let authService: AuthService;
  let devicesService: DevicesService;
  let monitoringService: MonitoringService;
  let activityService: ActivityService;
  let checkInsService: CheckInsService;

  let monitorUser: any;
  let monitoredUser: any;
  let monitoredAccessToken: string;
  let monitoredDevice: any;
  let relationship: any;

  beforeAll(async () => {
    const moduleFixture: TestingModule = await Test.createTestingModule({
      imports: [AppModule],
    }).compile();

    app = moduleFixture.createNestApplication();
    app.useGlobalPipes(new ValidationPipe({ whitelist: true, transform: true }));
    await app.init();

    dataSource = moduleFixture.get<DataSource>(DataSource);
    authService = moduleFixture.get<AuthService>(AuthService);
    devicesService = moduleFixture.get<DevicesService>(DevicesService);
    monitoringService = moduleFixture.get<MonitoringService>(MonitoringService);
    activityService = moduleFixture.get<ActivityService>(ActivityService);
    checkInsService = moduleFixture.get<CheckInsService>(CheckInsService);

    await resetDatabase(dataSource);

    const uniqueSuffix = Date.now();
    const monitorRes = await authService.register({
      email: `m1_stress_mon_${uniqueSuffix}@carely.test`,
      password: 'Password123!',
      displayName: 'Monitor Stress',
      timezone: 'Asia/Ho_Chi_Minh',
    });
    monitorUser = monitorRes.user;

    const monitoredRes = await authService.register({
      email: `m1_stress_monitored_${uniqueSuffix}@carely.test`,
      password: 'Password123!',
      displayName: 'Monitored Stress',
      timezone: 'Asia/Ho_Chi_Minh',
    });
    monitoredUser = monitoredRes.user;
    monitoredAccessToken = monitoredRes.accessToken;

    monitoredDevice = await devicesService.registerDevice(monitoredUser.id, {
      deviceUid: `m1-stress-dev-${Date.now()}`,
      platform: DevicePlatform.ANDROID,
      deviceName: 'Stress Pixel',
      pushToken: 'fcm-push-stress-token',
      batteryLevel: 90,
      isCharging: false,
    });

    const createdRel = await monitoringService.createRelationship(monitorUser.id, {
      monitoredUserEmail: monitoredUser.email,
    });
    relationship = await monitoringService.acceptInvitation(monitoredUser.id, {
      invitationCode: createdRel.invitationCode,
    });
  }, 30000);

  afterAll(async () => {
    await teardownE2eTestApp(app, dataSource);
  });

  // =========================================================================
  // TARGET 1: TIMEZONE CALCULATION IN MonitoringScheduler
  // =========================================================================
  describe('Target 1: Timezone Calculation in MonitoringScheduler', () => {
    it('1.1. Extreme Timezone - UTC (0 offset): Calculates exact UTC opening timestamp', () => {
      // Wednesday 2026-10-07 10:00:00Z. Window Wednesday 14:00 -> 18:00 UTC.
      const testDate = new Date('2026-10-07T10:00:00Z');
      const windows: MonitoringScheduleWindow[] = [
        {
          id: 'w-utc',
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
      const next = MonitoringScheduler.getNextActiveWindowStart(testDate, windows, 'UTC');
      expect(next.toISOString()).toBe('2026-10-07T14:00:00.000Z');
    });

    it('1.2. Extreme Timezone - Pacific/Auckland (+13 NZDT DST): Calculates accurate next-day window in UTC', () => {
      // In October, Auckland is UTC+13.
      // Wednesday 2026-10-07 10:00:00Z = Auckland 23:00 Wednesday.
      // Thursday window opens at Auckland 08:00 = Wednesday 19:00:00Z.
      const testDate = new Date('2026-10-07T10:00:00Z');
      const windows: MonitoringScheduleWindow[] = [
        {
          id: 'w-akl',
          configId: 'cfg-1',
          config: null as any,
          dayOfWeek: 4,
          startTime: '08:00',
          endTime: '17:00',
          isEnabled: true,
          createdAt: new Date(),
          updatedAt: new Date(),
        },
      ];
      const next = MonitoringScheduler.getNextActiveWindowStart(testDate, windows, 'Pacific/Auckland');
      expect(next.toISOString()).toBe('2026-10-07T19:00:00.000Z');
    });

    it('1.3. Extreme Timezone - Pacific/Honolulu (-10 HST): Calculates accurate same-day window in UTC', () => {
      // 2026-10-07 10:00:00Z = Honolulu 00:00 (Midnight Wednesday).
      // Window Wednesday 09:00 -> 17:00 HST = Wednesday 19:00:00Z.
      const testDate = new Date('2026-10-07T10:00:00Z');
      const windows: MonitoringScheduleWindow[] = [
        {
          id: 'w-hnl',
          configId: 'cfg-1',
          config: null as any,
          dayOfWeek: 3,
          startTime: '09:00',
          endTime: '17:00',
          isEnabled: true,
          createdAt: new Date(),
          updatedAt: new Date(),
        },
      ];
      const next = MonitoringScheduler.getNextActiveWindowStart(testDate, windows, 'Pacific/Honolulu');
      expect(next.toISOString()).toBe('2026-10-07T19:00:00.000Z');
    });

    it('1.4. Fractional Offset Timezone - Asia/Kathmandu (+05:45): Accurately accounts for 45-minute offset', () => {
      // 2026-10-07 03:00:00Z = Kathmandu 08:45 NPT.
      // Window Wednesday 10:30 -> 18:00 NPT = 10:30 - 5h45m = 04:45:00Z.
      const testDate = new Date('2026-10-07T03:00:00Z');
      const windows: MonitoringScheduleWindow[] = [
        {
          id: 'w-ktm',
          configId: 'cfg-1',
          config: null as any,
          dayOfWeek: 3,
          startTime: '10:30',
          endTime: '18:00',
          isEnabled: true,
          createdAt: new Date(),
          updatedAt: new Date(),
        },
      ];
      const next = MonitoringScheduler.getNextActiveWindowStart(testDate, windows, 'Asia/Kathmandu');
      expect(next.toISOString()).toBe('2026-10-07T04:45:00.000Z');
    });

    it('1.5. DST Boundary - America/New_York across Spring Forward: Accurately shifts to UTC-4', () => {
      // Saturday 2026-03-07 23:00 EST = 2026-03-08 04:00:00Z.
      // Sunday 2026-03-08 08:00 EDT (DST begins at 02:00) = 08:00 + 4h = 12:00:00Z.
      const testDate = new Date('2026-03-08T04:00:00Z');
      const windows: MonitoringScheduleWindow[] = [
        {
          id: 'w-ny',
          configId: 'cfg-1',
          config: null as any,
          dayOfWeek: 0,
          startTime: '08:00',
          endTime: '17:00',
          isEnabled: true,
          createdAt: new Date(),
          updatedAt: new Date(),
        },
      ];
      const next = MonitoringScheduler.getNextActiveWindowStart(testDate, windows, 'America/New_York');
      expect(next.toISOString()).toBe('2026-03-08T12:00:00.000Z');
    });

    it('1.6. Overnight Window (23:00 -> 07:00): Evaluated at 15:00 VN returns tonight at 23:00 (16:00 UTC)', () => {
      // Wednesday 15:00 VN (08:00 UTC)
      const testDate = new Date('2026-10-07T08:00:00Z');
      const windows: MonitoringScheduleWindow[] = [
        {
          id: 'w-overnight',
          configId: 'cfg-1',
          config: null as any,
          dayOfWeek: 3,
          startTime: '23:00',
          endTime: '07:00',
          isEnabled: true,
          createdAt: new Date(),
          updatedAt: new Date(),
        },
      ];
      const next = MonitoringScheduler.getNextActiveWindowStart(testDate, windows, 'Asia/Ho_Chi_Minh');
      expect(next.toISOString()).toBe('2026-10-07T16:00:00.000Z');
    });

    it('1.7. Weekend Gap: Friday 18:00 VN after closing jumps across weekend to Monday 08:00 VN (01:00 UTC)', () => {
      // Friday 2026-10-09 18:00 VN (11:00 UTC)
      const testDate = new Date('2026-10-09T11:00:00Z');
      const windows: MonitoringScheduleWindow[] = [
        { id: '1', configId: '1', config: null as any, dayOfWeek: 1, startTime: '08:00', endTime: '17:00', isEnabled: true, createdAt: new Date(), updatedAt: new Date() },
        { id: '2', configId: '1', config: null as any, dayOfWeek: 2, startTime: '08:00', endTime: '17:00', isEnabled: true, createdAt: new Date(), updatedAt: new Date() },
        { id: '3', configId: '1', config: null as any, dayOfWeek: 3, startTime: '08:00', endTime: '17:00', isEnabled: true, createdAt: new Date(), updatedAt: new Date() },
        { id: '4', configId: '1', config: null as any, dayOfWeek: 4, startTime: '08:00', endTime: '17:00', isEnabled: true, createdAt: new Date(), updatedAt: new Date() },
        { id: '5', configId: '1', config: null as any, dayOfWeek: 5, startTime: '08:00', endTime: '17:00', isEnabled: true, createdAt: new Date(), updatedAt: new Date() },
      ];
      const next = MonitoringScheduler.getNextActiveWindowStart(testDate, windows, 'Asia/Ho_Chi_Minh');
      expect(next.toISOString()).toBe('2026-10-12T01:00:00.000Z');
    });

    it('1.8. Invalid timezone falls back safely to default timezone without throwing RangeError', () => {
      // Wednesday 2026-10-07 10:00:00Z = 17:00 VN. Window Wednesday 14:00 -> 18:00
      const testDate = new Date('2026-10-07T10:00:00Z');
      const windows: MonitoringScheduleWindow[] = [
        {
          id: '1',
          configId: '1',
          config: null as any,
          dayOfWeek: 3,
          startTime: '14:00',
          endTime: '18:00',
          isEnabled: true,
          createdAt: new Date(),
          updatedAt: new Date(),
        },
      ];

      expect(() => {
        const inWindow = MonitoringScheduler.isWithinActiveWindow(
          testDate,
          windows,
          'Invalid/Unrecognized_Timezone',
        );
        expect(inWindow).toBe(true);
      }).not.toThrow();
    });

    it('1.9. Midnight transition maintains continuous active state across overnight window', () => {
      // Monday 22:00 -> 06:00 window
      const windows: MonitoringScheduleWindow[] = [
        {
          id: '1',
          configId: '1',
          config: null as any,
          dayOfWeek: 1, // Monday
          startTime: '22:00',
          endTime: '06:00',
          isEnabled: true,
          createdAt: new Date(),
          updatedAt: new Date(),
        },
      ];

      // Monday 23:59:59 VN (16:59:59Z) -> inside window: TRUE
      const mondayNight = new Date('2026-10-05T16:59:59Z');
      expect(MonitoringScheduler.isWithinActiveWindow(mondayNight, windows, 'Asia/Ho_Chi_Minh')).toBe(true);

      // Tuesday 00:00:00 VN (17:00:00Z) -> exactly 1 second later: still inside overnight window: TRUE
      const tuesdayMidnight = new Date('2026-10-05T17:00:00Z');
      expect(MonitoringScheduler.isWithinActiveWindow(tuesdayMidnight, windows, 'Asia/Ho_Chi_Minh')).toBe(true);

      // Tuesday 05:59:59 VN (22:59:59Z) -> inside window: TRUE
      const tuesdayMorning = new Date('2026-10-05T22:59:59Z');
      expect(MonitoringScheduler.isWithinActiveWindow(tuesdayMorning, windows, 'Asia/Ho_Chi_Minh')).toBe(true);

      // Tuesday 06:01:00 VN (23:01:00Z) -> outside window: FALSE
      const tuesdayPastWindow = new Date('2026-10-05T23:01:00Z');
      expect(MonitoringScheduler.isWithinActiveWindow(tuesdayPastWindow, windows, 'Asia/Ho_Chi_Minh')).toBe(false);

      // Monday 04:00:00 VN (Sunday 21:00:00Z) -> Monday morning BEFORE Monday night's window: FALSE
      const mondayPreWindow = new Date('2026-10-04T21:00:00Z');
      expect(MonitoringScheduler.isWithinActiveWindow(mondayPreWindow, windows, 'Asia/Ho_Chi_Minh')).toBe(false);
    });
  });

  // =========================================================================
  // TARGET 2: HIGH-CONCURRENCY DUPLICATE EVENT_ID INSERTION
  // =========================================================================
  describe('Target 2: High-Concurrency Duplicate eventId Insertion', () => {
    it('2.1. Service-Level Concurrency on /activities: 30 concurrent requests with identical eventId produce 0 errors and exactly 1 DB row', async () => {
      const fixedEventId = uuidv4();
      const concurrencyLevel = 30;
      const activityRepo = dataSource.getRepository(Activity);

      const countBefore = await activityRepo.count({ where: { eventId: fixedEventId } });
      expect(countBefore).toBe(0);

      const promises = Array.from({ length: concurrencyLevel }, (_, idx) =>
        activityService.ingestActivity(monitoredUser.id, {
          eventId: fixedEventId,
          deviceId: monitoredDevice.id,
          type: ActivityType.SCREEN_INTERACTION,
          occurredAt: new Date().toISOString(),
          confidence: 0.8,
          metadata: { concurrentIndex: idx },
        }),
      );

      const results = await Promise.allSettled(promises);

      // Verify zero rejections (no 23505 unhandled crashes)
      const rejected = results.filter((r) => r.status === 'rejected');
      expect(rejected.length).toBe(0);

      const fulfilled = results.filter(
        (r): r is PromiseFulfilledResult<Activity> => r.status === 'fulfilled',
      );
      expect(fulfilled.length).toBe(concurrencyLevel);

      const firstId = fulfilled[0].value.id;
      for (const res of fulfilled) {
        expect(res.value.eventId).toBe(fixedEventId);
        expect(res.value.id).toBe(firstId); // Genuine idempotent return
      }

      // Verify exactly ONE record exists in the database
      const countAfter = await activityRepo.count({ where: { eventId: fixedEventId } });
      expect(countAfter).toBe(1);
    });

    it('2.2. Service-Level Concurrency on /check-ins: 30 concurrent requests with identical eventId produce 0 errors and exactly 1 DB row', async () => {
      const fixedEventId = uuidv4();
      const concurrencyLevel = 30;
      const checkInRepo = dataSource.getRepository(CheckIn);
      const activityRepo = dataSource.getRepository(Activity);

      const countBefore = await checkInRepo.count({ where: { eventId: fixedEventId } });
      expect(countBefore).toBe(0);

      const promises = Array.from({ length: concurrencyLevel }, (_, idx) =>
        checkInsService.processCheckIn(monitoredUser.id, {
          eventId: fixedEventId,
          deviceId: monitoredDevice.id,
          relationshipId: relationship.id,
          occurredAt: new Date().toISOString(),
          note: `Concurrent check-in ${idx}`,
          batteryLevel: 85,
        }),
      );

      const results = await Promise.allSettled(promises);

      // Verify zero rejections (no 23505 unique constraint crashes)
      const rejected = results.filter((r) => r.status === 'rejected');
      expect(rejected.length).toBe(0);

      const fulfilled = results.filter(
        (r): r is PromiseFulfilledResult<CheckIn> => r.status === 'fulfilled',
      );
      expect(fulfilled.length).toBe(concurrencyLevel);

      const firstId = fulfilled[0].value.id;
      for (const res of fulfilled) {
        expect(res.value.eventId).toBe(fixedEventId);
        expect(res.value.id).toBe(firstId);
      }

      // Exactly 1 check-in row
      const countCheckIns = await checkInRepo.count({ where: { eventId: fixedEventId } });
      expect(countCheckIns).toBe(1);

      // Exactly 1 activity row of type CHECK_IN
      const countActivities = await activityRepo.count({ where: { eventId: fixedEventId } });
      expect(countActivities).toBe(1);
    });

    it('2.3. Live HTTP Supertest Parallel Ingestion on POST /api/v1/activities: 20 parallel HTTP requests produce 0 500s and exactly 1 DB row', async () => {
      const httpEventId = uuidv4();
      const activityRepo = dataSource.getRepository(Activity);

      const promises = Array.from({ length: 20 }, () =>
        request(app.getHttpServer())
          .post('/api/v1/activities')
          .set('Authorization', `Bearer ${monitoredAccessToken}`)
          .send({
            eventId: httpEventId,
            deviceId: monitoredDevice.id,
            type: ActivityType.APP_FOREGROUND,
            occurredAt: new Date().toISOString(),
            confidence: 0.9,
          }),
      );

      const responses = await Promise.all(promises);

      // Verify zero 500 errors
      for (const res of responses) {
        expect([200, 201]).toContain(res.status);
        expect(res.body.eventId).toBe(httpEventId);
      }

      const dbRows = await activityRepo.count({ where: { eventId: httpEventId } });
      expect(dbRows).toBe(1);
    });

    it('2.4. Live HTTP Supertest Parallel Ingestion on POST /api/v1/check-ins: 20 parallel HTTP requests produce 0 500s and exactly 1 DB row', async () => {
      const httpCheckInEventId = uuidv4();
      const checkInRepo = dataSource.getRepository(CheckIn);

      const promises = Array.from({ length: 20 }, () =>
        request(app.getHttpServer())
          .post('/api/v1/check-ins')
          .set('Authorization', `Bearer ${monitoredAccessToken}`)
          .send({
            eventId: httpCheckInEventId,
            deviceId: monitoredDevice.id,
            relationshipId: relationship.id,
            occurredAt: new Date().toISOString(),
            note: 'HTTP Parallel Tôi vẫn ổn',
          }),
      );

      const responses = await Promise.all(promises);

      for (const res of responses) {
        expect([200, 201]).toContain(res.status);
        expect(res.body.eventId).toBe(httpCheckInEventId);
      }

      const dbRows = await checkInRepo.count({ where: { eventId: httpCheckInEventId } });
      expect(dbRows).toBe(1);
    });
  });

  // =========================================================================
  // TARGET 3: TIMESTAMP ORDERING & OUT-OF-ORDER DELAYED CHECK-INS
  // =========================================================================
  describe('Target 3: Timestamp Ordering & Out-of-Order Delayed Check-ins', () => {
    let configRepo: any;

    beforeAll(() => {
      configRepo = dataSource.getRepository(MonitoringConfig);
    });

    it('3.1. Out-of-Order Delayed Check-in does NOT roll back lastMeaningfulActivityAt', async () => {
      // 1. Establish initial baseline: T1 = now - 30 minutes
      const t1 = new Date(Date.now() - 30 * 60 * 1000);
      await configRepo.update(
        { relationshipId: relationship.id },
        {
          currentState: MonitoringState.ACTIVE,
          inactivityThresholdMinutes: 60,
          lastMeaningfulActivityAt: t1,
          nextEvaluationAt: new Date(t1.getTime() + 60 * 60 * 1000),
        },
      );

      const configBefore = await configRepo.findOne({
        where: { relationshipId: relationship.id },
      });
      expect(new Date(configBefore.lastMeaningfulActivityAt).getTime()).toBe(
        t1.getTime(),
      );

      // 2. Delayed check-in from 15 minutes before T1 (T_delayed = now - 45 minutes)
      const tDelayed = new Date(Date.now() - 45 * 60 * 1000);
      const delayedEventId = uuidv4();
      const savedCheckIn = await checkInsService.processCheckIn(monitoredUser.id, {
        eventId: delayedEventId,
        deviceId: monitoredDevice.id,
        relationshipId: relationship.id,
        occurredAt: tDelayed.toISOString(),
        note: 'Delayed check-in from offline replay',
      });

      expect(savedCheckIn).toBeDefined();
      expect(savedCheckIn.eventId).toBe(delayedEventId);

      // 3. Verify config clock was NOT rolled back to 45m ago!
      const configAfter = await configRepo.findOne({
        where: { relationshipId: relationship.id },
      });
      expect(new Date(configAfter.lastMeaningfulActivityAt).getTime()).toBe(
        t1.getTime(),
      );
      expect(new Date(configAfter.nextEvaluationAt).getTime()).toBe(
        t1.getTime() + 60 * 60 * 1000,
      );
    });

    it('3.2. Ancient Delayed Check-in (3 days old) does NOT roll back lastMeaningfulActivityAt', async () => {
      const cfgBefore = await configRepo.findOne({ where: { relationshipId: relationship.id } });
      const beforeTime = new Date(cfgBefore.lastMeaningfulActivityAt).getTime();

      const tAncient = new Date(Date.now() - 3 * 24 * 60 * 60 * 1000);
      await checkInsService.processCheckIn(monitoredUser.id, {
        eventId: uuidv4(),
        deviceId: monitoredDevice.id,
        relationshipId: relationship.id,
        occurredAt: tAncient.toISOString(),
        note: 'Ancient delayed check-in',
      });

      const cfgAfter = await configRepo.findOne({ where: { relationshipId: relationship.id } });
      expect(new Date(cfgAfter.lastMeaningfulActivityAt).getTime()).toBe(beforeTime);
    });

    it('3.3. Subsequent newer Check-in successfully advances lastMeaningfulActivityAt', async () => {
      // Forward check-in at now - 10 minutes (newer than t1 = now - 30m)
      const t2 = new Date(Date.now() - 10 * 60 * 1000);
      await checkInsService.processCheckIn(monitoredUser.id, {
        eventId: uuidv4(),
        deviceId: monitoredDevice.id,
        relationshipId: relationship.id,
        occurredAt: t2.toISOString(),
        note: 'Newer forward check-in',
      });

      const cfg = await configRepo.findOne({ where: { relationshipId: relationship.id } });
      expect(new Date(cfg.lastMeaningfulActivityAt).getTime()).toBe(t2.getTime());
      expect(new Date(cfg.nextEvaluationAt).getTime()).toBe(
        t2.getTime() + 60 * 60 * 1000,
      );
    });

    it('3.4. Rapid interleaved sequence with mixed timestamps preserves monotonic maximum', async () => {
      const baseNow = Date.now();
      // Timestamps: -20m, -25m, -15m, -18m, -5m, -8m
      const offsetsMinutes = [-20, -25, -15, -18, -5, -8];
      let runningMax = -Infinity;

      // Seed baseline to -30m
      const baseline = new Date(baseNow - 30 * 60 * 1000);
      await configRepo.update(
        { relationshipId: relationship.id },
        { lastMeaningfulActivityAt: baseline },
      );
      runningMax = baseline.getTime();

      for (const offset of offsetsMinutes) {
        const stepTime = new Date(baseNow + offset * 60 * 1000);
        runningMax = Math.max(runningMax, stepTime.getTime());

        await checkInsService.processCheckIn(monitoredUser.id, {
          eventId: uuidv4(),
          deviceId: monitoredDevice.id,
          relationshipId: relationship.id,
          occurredAt: stepTime.toISOString(),
          note: `Step offset ${offset}m`,
        });

        const currentCfg = await configRepo.findOne({
          where: { relationshipId: relationship.id },
        });
        expect(new Date(currentCfg.lastMeaningfulActivityAt).getTime()).toBe(runningMax);
      }
    });

    it('3.5. Future timestamp (> 5 minutes ahead) is clamped to server now and does not explode nextEvaluationAt', async () => {
      // First set baseline to now - 10m
      const baseline = new Date(Date.now() - 10 * 60 * 1000);
      await configRepo.update(
        { relationshipId: relationship.id },
        { lastMeaningfulActivityAt: baseline },
      );

      const farFuture = new Date(Date.now() + 24 * 60 * 60 * 1000); // +24 hours
      const serverBefore = Date.now();

      await checkInsService.processCheckIn(monitoredUser.id, {
        eventId: uuidv4(),
        deviceId: monitoredDevice.id,
        relationshipId: relationship.id,
        occurredAt: farFuture.toISOString(),
        note: 'Malicious / desynchronized clock from far future',
      });

      const serverAfter = Date.now();

      const cfg = await configRepo.findOne({ where: { relationshipId: relationship.id } });
      const lastMeaningfulMs = new Date(cfg.lastMeaningfulActivityAt).getTime();

      // Inactivity clock must be clamped to server now (within execution window)
      expect(lastMeaningfulMs).toBeGreaterThanOrEqual(serverBefore - 1000);
      expect(lastMeaningfulMs).toBeLessThanOrEqual(serverAfter + 1000);
    });

    it('3.6. Delayed check-in occurring prior to incident creation does NOT resolve the incident', async () => {
      const incidentRepo = dataSource.getRepository(Incident);
      const now = new Date();

      // Create an open incident at now
      const incident = await incidentRepo.save(
        incidentRepo.create({
          relationshipId: relationship.id,
          userId: monitoredUser.id,
          status: IncidentStatus.OPEN,
          reason: IncidentReason.MISSED_CHECK_IN,
          riskScore: 70,
          detectedAt: now,
          createdAt: now,
        }),
      );

      // Check-in occurred 20 minutes before incident
      const preIncidentTime = new Date(now.getTime() - 20 * 60 * 1000);
      await checkInsService.processCheckIn(monitoredUser.id, {
        eventId: uuidv4(),
        deviceId: monitoredDevice.id,
        relationshipId: relationship.id,
        occurredAt: preIncidentTime.toISOString(),
        note: 'Delayed check-in predating incident',
      });

      const refreshed = await incidentRepo.findOne({ where: { id: incident.id } });
      expect(refreshed!.status).toBe(IncidentStatus.OPEN);
      expect(refreshed!.resolvedAt).toBeNull();

      // Now send a fresh check-in occurring after incident creation
      const postIncidentTime = new Date(now.getTime() + 1000);
      await checkInsService.processCheckIn(monitoredUser.id, {
        eventId: uuidv4(),
        deviceId: monitoredDevice.id,
        relationshipId: relationship.id,
        occurredAt: postIncidentTime.toISOString(),
        note: 'Genuine post-incident confirmation',
      });

      const resolved = await incidentRepo.findOne({ where: { id: incident.id } });
      expect(resolved!.status).toBe(IncidentStatus.RESOLVED);
      expect(resolved!.resolvedAt).toBeDefined();

      await incidentRepo.delete(incident.id);
    });
  });
});
