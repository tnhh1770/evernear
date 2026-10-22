import { describe, it, expect, beforeAll, afterAll } from 'vitest';
import { INestApplication } from '@nestjs/common';
import { DataSource } from 'typeorm';
import request from 'supertest';
import { v4 as uuidv4 } from 'uuid';
import {
  createE2eTestApp,
  resetDatabase,
  teardownE2eTestApp,
  registerAndLoginUser,
  registerTestDevice,
  pairMonitoringRelationship,
  TestUserContext,
} from './e2e/e2e-helper';
import { ActivityType, MonitoringState } from '../src/common/enums';
import { MonitoringWorkerService } from '../src/modules/workers/monitoring-worker.service';
import { MonitoringScheduler } from '../src/modules/monitoring/monitoring-scheduler';

describe('Inactivity Threshold & Sleep/Quiet Hours E2E (Features 45 & 46)', () => {
  let app: INestApplication;
  let dataSource: DataSource;
  let workerService: MonitoringWorkerService;

  let monitor: TestUserContext;
  let monitored: TestUserContext;
  let device: any;
  let relationship: any;

  beforeAll(async () => {
    const context = await createE2eTestApp();
    app = context.app;
    dataSource = context.dataSource;
    workerService = context.moduleFixture.get<MonitoringWorkerService>(MonitoringWorkerService);

    await resetDatabase(dataSource);

    monitor = await registerAndLoginUser(app, 'threshold_monitor');
    monitored = await registerAndLoginUser(app, 'threshold_monitored');
    device = await registerTestDevice(app, monitored.accessToken);
    const paired = await pairMonitoringRelationship(app, monitor.accessToken, monitored);
    relationship = paired.relationship;
  }, 30000);

  afterAll(async () => {
    await teardownE2eTestApp(app, dataSource);
  });

  // =========================================================================
  // 1. Inactivity Threshold Presets (15m, 30m, 1h, 2h, 4h, 8h, 12h, 24h)
  // =========================================================================
  describe('Inactivity Threshold Presets (Feature 45)', () => {
    const presets = [
      { name: '15 minutes (15m)', minutes: 15 },
      { name: '30 minutes (30m)', minutes: 30 },
      { name: '1 hour (60m)', minutes: 60 },
      { name: '2 hours (120m)', minutes: 120 },
      { name: '4 hours (240m)', minutes: 240 },
      { name: '8 hours (480m)', minutes: 480 },
      { name: '12 hours (720m)', minutes: 720 },
      { name: '24 hours (1440m)', minutes: 1440 },
    ];

    for (const preset of presets) {
      it(`should accept and persist preset threshold: ${preset.name}`, async () => {
        const res = await request(app.getHttpServer())
          .patch(`/api/v1/monitoring/${relationship.id}/config`)
          .set('Authorization', `Bearer ${monitored.accessToken}`)
          .send({
            inactivityThresholdMinutes: preset.minutes,
          });

        expect(res.status).toBe(200);
        expect(res.body.inactivityThresholdMinutes).toBe(preset.minutes);

        // Verify database persistence
        const rows = await dataSource.query(
          `SELECT inactivity_threshold_minutes FROM monitoring_configs WHERE relationship_id = $1`,
          [relationship.id],
        );
        expect(rows[0].inactivity_threshold_minutes).toBe(preset.minutes);
      });
    }

    it('should support updating config via route alias /api/v1/monitoring/configs/:id', async () => {
      const configRows = await dataSource.query(
        `SELECT id FROM monitoring_configs WHERE relationship_id = $1`,
        [relationship.id],
      );
      const configId = configRows[0].id;

      const res = await request(app.getHttpServer())
        .patch(`/api/v1/monitoring/configs/${configId}`)
        .set('Authorization', `Bearer ${monitored.accessToken}`)
        .send({
          inactivityThresholdMinutes: 120,
        });

      expect(res.status).toBe(200);
      expect(res.body.inactivityThresholdMinutes).toBe(120);
    });
  });

  // =========================================================================
  // 2. Custom Numeric Threshold Values
  // =========================================================================
  describe('Custom Numeric Inactivity Threshold (Feature 45)', () => {
    const customValues = [45, 90, 180, 360, 500, 1000];

    for (const mins of customValues) {
      it(`should accept custom numeric threshold: ${mins} minutes`, async () => {
        const res = await request(app.getHttpServer())
          .patch(`/api/v1/monitoring/${relationship.id}/config`)
          .set('Authorization', `Bearer ${monitored.accessToken}`)
          .send({
            inactivityThresholdMinutes: mins,
          });

        expect(res.status).toBe(200);
        expect(res.body.inactivityThresholdMinutes).toBe(mins);
      });
    }

    it('should accept boundary values 1 minute and 10080 minutes (7 days)', async () => {
      // 1 minute (minimum boundary)
      const resMin = await request(app.getHttpServer())
        .patch(`/api/v1/monitoring/${relationship.id}/config`)
        .set('Authorization', `Bearer ${monitored.accessToken}`)
        .send({ inactivityThresholdMinutes: 1 });
      expect(resMin.status).toBe(200);
      expect(resMin.body.inactivityThresholdMinutes).toBe(1);

      // 10080 minutes (maximum boundary)
      const resMax = await request(app.getHttpServer())
        .patch(`/api/v1/monitoring/${relationship.id}/config`)
        .set('Authorization', `Bearer ${monitored.accessToken}`)
        .send({ inactivityThresholdMinutes: 10080 });
      expect(resMax.status).toBe(200);
      expect(resMax.body.inactivityThresholdMinutes).toBe(10080);
    });
  });

  // =========================================================================
  // 3. Out-of-Bounds & Time Format Validation
  // =========================================================================
  describe('Validation & Boundary Enforcement', () => {
    it('should reject inactivityThresholdMinutes < 1 with 400 Bad Request', async () => {
      const res0 = await request(app.getHttpServer())
        .patch(`/api/v1/monitoring/${relationship.id}/config`)
        .set('Authorization', `Bearer ${monitored.accessToken}`)
        .send({ inactivityThresholdMinutes: 0 });
      expect(res0.status).toBe(400);

      const resNeg = await request(app.getHttpServer())
        .patch(`/api/v1/monitoring/${relationship.id}/config`)
        .set('Authorization', `Bearer ${monitored.accessToken}`)
        .send({ inactivityThresholdMinutes: -30 });
      expect(resNeg.status).toBe(400);
    });

    it('should reject inactivityThresholdMinutes > 10080 with 400 Bad Request', async () => {
      const res = await request(app.getHttpServer())
        .patch(`/api/v1/monitoring/${relationship.id}/config`)
        .set('Authorization', `Bearer ${monitored.accessToken}`)
        .send({ inactivityThresholdMinutes: 10081 });
      expect(res.status).toBe(400);
    });

    it('should reject non-integer inactivityThresholdMinutes with 400 Bad Request', async () => {
      const res = await request(app.getHttpServer())
        .patch(`/api/v1/monitoring/${relationship.id}/config`)
        .set('Authorization', `Bearer ${monitored.accessToken}`)
        .send({ inactivityThresholdMinutes: 45.5 });
      expect(res.status).toBe(400);
    });

    it('should reject invalid schedule window time formats with 400 Bad Request', async () => {
      const invalidTimes = [
        '24:00', // Invalid hour 24
        '25:00', // Invalid hour 25
        '12:60', // Invalid minute 60
        '7:00',  // Missing leading zero
        '07:5',  // Missing trailing minute digit
        'abc',   // Non-time string
        '1234',  // Missing colon
        '12:345' // Too many digits
      ];

      for (const badTime of invalidTimes) {
        const res = await request(app.getHttpServer())
          .patch(`/api/v1/monitoring/${relationship.id}/config`)
          .set('Authorization', `Bearer ${monitored.accessToken}`)
          .send({
            scheduleWindows: [
              {
                dayOfWeek: 1,
                startTime: badTime,
                endTime: '22:00',
                isEnabled: true,
              },
            ],
          });
        expect(res.status).toBe(400);
      }
    });

    it('should accept valid 24-hour HH:mm schedule window times', async () => {
      const validWindows = [
        { startTime: '00:00', endTime: '06:00' },
        { startTime: '07:30', endTime: '22:00' },
        { startTime: '22:00', endTime: '23:59' },
      ];

      for (const win of validWindows) {
        const res = await request(app.getHttpServer())
          .patch(`/api/v1/monitoring/${relationship.id}/config`)
          .set('Authorization', `Bearer ${monitored.accessToken}`)
          .send({
            scheduleWindows: [
              {
                dayOfWeek: 1,
                startTime: win.startTime,
                endTime: win.endTime,
                isEnabled: true,
              },
            ],
          });
        expect(res.status).toBe(200);
      }
    });
  });

  // =========================================================================
  // 4. Quiet Hours / Sleep Schedule Deferral (Zero False Alarms) (Feature 46)
  // =========================================================================
  describe('Quiet Hours Deferral & Zero False Alarms (Feature 46)', () => {
    it('should defer next evaluation to wake time when outside active window, producing zero alarms', async () => {
      // Configure schedule window such that current time is guaranteed outside the active window
      // Current day and time:
      const now = new Date();
      const currentDayOfWeek = now.getUTCDay();

      // Configure active window to be only during a narrow window far from now (e.g. 03:00 to 03:01 UTC)
      // or active only on tomorrow's dayOfWeek
      const tomorrowDayOfWeek = (currentDayOfWeek + 1) % 7;
      await request(app.getHttpServer())
        .patch(`/api/v1/monitoring/${relationship.id}/config`)
        .set('Authorization', `Bearer ${monitored.accessToken}`)
        .send({
          timezone: 'UTC',
          inactivityThresholdMinutes: 60,
          requireCheckIn: true,
          scheduleWindows: [
            {
              dayOfWeek: tomorrowDayOfWeek,
              startTime: '07:00',
              endTime: '22:00',
              isEnabled: true,
            },
          ],
        });

      // Force config into due state with past lastMeaningfulActivityAt (> inactivityThreshold)
      const pastActivity = new Date(Date.now() - 5 * 3600 * 1000); // 5 hours ago
      await dataSource.query(
        `UPDATE monitoring_configs 
         SET current_state = 'ACTIVE',
             last_meaningful_activity_at = $1,
             next_evaluation_at = NOW() - INTERVAL '5 minutes'
         WHERE relationship_id = $2`,
        [pastActivity, relationship.id],
      );

      // Run worker evaluation
      await workerService.evaluateDueMonitoring(10);

      // Verify that config stayed ACTIVE (zero false alarms: NO CHECK_IN_REQUIRED, NO WARNING)
      const rows = await dataSource.query(
        `SELECT current_state, next_evaluation_at FROM monitoring_configs WHERE relationship_id = $1`,
        [relationship.id],
      );

      expect(rows[0].current_state).toBe(MonitoringState.ACTIVE);

      // Verify that next_evaluation_at was deferred into the future (start of next active window)
      const nextEval = new Date(rows[0].next_evaluation_at).getTime();
      expect(nextEval).toBeGreaterThan(Date.now());
    });

    it('should verify MonitoringScheduler correctly calculates wake time deferral across days', () => {
      // Given active window Monday (1) 07:00 to 22:00 UTC
      const windows = [
        {
          dayOfWeek: 1,
          startTime: '07:00',
          endTime: '22:00',
          isEnabled: true,
        },
      ];

      // Test point during quiet hours: Monday 23:00 UTC (after bedtime 22:00)
      // 2026-10-05 was Monday
      const nightTime = new Date('2026-10-05T23:00:00.000Z');
      const isInWindow = MonitoringScheduler.isWithinActiveWindow(nightTime, windows, 'UTC');
      expect(isInWindow).toBe(false);

      const nextStart = MonitoringScheduler.getNextActiveWindowStart(nightTime, windows, 'UTC');
      // Next opening window should be next Monday at 07:00 UTC
      expect(nextStart.toISOString()).toBe('2026-10-12T07:00:00.000Z');
    });
  });

  // =========================================================================
  // 5. Overnight Telemetry & Charging Ingestion Without False Alarms
  // =========================================================================
  describe('Overnight Charging & Telemetry Ingestion (Feature 46)', () => {
    it('should ingest heartbeat (weight 0.0) overnight without mutating lastMeaningfulActivityAt', async () => {
      const configBefore = await dataSource.query(
        `SELECT last_meaningful_activity_at FROM monitoring_configs WHERE relationship_id = $1`,
        [relationship.id],
      );
      const originalActivity = configBefore[0].last_meaningful_activity_at;

      // Send reachability heartbeat
      const hbRes = await request(app.getHttpServer())
        .post('/api/v1/heartbeat')
        .set('Authorization', `Bearer ${monitored.accessToken}`)
        .send({
          deviceId: device.id,
          batteryLevel: 85,
          isCharging: true,
          occurredAt: new Date().toISOString(),
        });

      expect(hbRes.status).toBe(200);
      expect(hbRes.body.success).toBe(true);
      expect(hbRes.body.operationalState).toBe('ONLINE');

      // Verify last_meaningful_activity_at is NOT modified by weight 0.0 heartbeat
      const configAfter = await dataSource.query(
        `SELECT last_meaningful_activity_at FROM monitoring_configs WHERE relationship_id = $1`,
        [relationship.id],
      );
      expect(
        new Date(configAfter[0].last_meaningful_activity_at).getTime(),
      ).toBe(new Date(originalActivity).getTime());
    });

    it('should ingest CHARGER_CONNECTED (weight 0.2) safely overnight without triggering alarm during quiet hours', async () => {
      // Ingest CHARGER_CONNECTED event
      const chargingEventId = uuidv4();
      const actRes = await request(app.getHttpServer())
        .post('/api/v1/activities')
        .set('Authorization', `Bearer ${monitored.accessToken}`)
        .send({
          eventId: chargingEventId,
          type: ActivityType.CHARGER_CONNECTED,
          deviceId: device.id,
          occurredAt: new Date().toISOString(),
          confidence: 0.9,
          metadata: { batteryLevel: 90, chargingSource: 'AC' },
        });

      expect(actRes.status).toBe(201);
      expect(actRes.body.type).toBe(ActivityType.CHARGER_CONNECTED);
      expect(Number(actRes.body.weight)).toBe(0.2);

      // Verify meaningful activity updated
      const configAfterCharging = await dataSource.query(
        `SELECT last_meaningful_activity_at FROM monitoring_configs WHERE relationship_id = $1`,
        [relationship.id],
      );
      expect(configAfterCharging[0].last_meaningful_activity_at).toBeDefined();

      // Ensure that worker evaluation during quiet hours still keeps config in ACTIVE state
      // Set schedule to quiet hours (tomorrow only)
      const now = new Date();
      const tomorrowDayOfWeek = (now.getUTCDay() + 1) % 7;
      await request(app.getHttpServer())
        .patch(`/api/v1/monitoring/${relationship.id}/config`)
        .set('Authorization', `Bearer ${monitored.accessToken}`)
        .send({
          timezone: 'UTC',
          scheduleWindows: [
            {
              dayOfWeek: tomorrowDayOfWeek,
              startTime: '07:00',
              endTime: '22:00',
              isEnabled: true,
            },
          ],
        });

      // Force evaluation to be due
      await dataSource.query(
        `UPDATE monitoring_configs 
         SET next_evaluation_at = NOW() - INTERVAL '1 minute'
         WHERE relationship_id = $1`,
        [relationship.id],
      );

      // Worker runs
      await workerService.evaluateDueMonitoring(10);

      // Config must remain ACTIVE with next evaluation deferred to wake time
      const finalConfig = await dataSource.query(
        `SELECT current_state, next_evaluation_at FROM monitoring_configs WHERE relationship_id = $1`,
        [relationship.id],
      );
      expect(finalConfig[0].current_state).toBe(MonitoringState.ACTIVE);
      expect(new Date(finalConfig[0].next_evaluation_at).getTime()).toBeGreaterThan(Date.now());
    });
  });

  // =========================================================================
  // 6. Guardian Monitoring Settings Permissions (Feature 2 / R1)
  // =========================================================================
  describe('Guardian Monitoring Settings Permissions (Feature 2 / R1)', () => {
    it('should allow Guardian (monitor) to update relative thresholds and schedules when locationEnabled is unchanged', async () => {
      // Guardian updates inactivityThresholdMinutes and checkInGraceMinutes, passing locationEnabled: false (same as existing)
      const res = await request(app.getHttpServer())
        .patch(`/api/v1/monitoring/${relationship.id}/config`)
        .set('Authorization', `Bearer ${monitor.accessToken}`)
        .send({
          inactivityThresholdMinutes: 240,
          checkInGraceMinutes: 45,
          locationEnabled: false,
        });

      expect(res.status).toBe(200);
      expect(res.body.inactivityThresholdMinutes).toBe(240);
      expect(res.body.checkInGraceMinutes).toBe(45);
    });

    it('should reject Guardian (monitor) with 403 Forbidden when attempting to alter locationEnabled', async () => {
      // Guardian attempts to change locationEnabled from false to true
      const res = await request(app.getHttpServer())
        .patch(`/api/v1/monitoring/${relationship.id}/config`)
        .set('Authorization', `Bearer ${monitor.accessToken}`)
        .send({
          locationEnabled: true,
        });

      expect(res.status).toBe(403);
      expect(res.body.message).toContain('Only the monitored user can grant or revoke location sharing permission');
    });

    it('should allow Monitored user to alter locationEnabled without 403', async () => {
      // Monitored user toggles locationEnabled to true
      const res = await request(app.getHttpServer())
        .patch(`/api/v1/monitoring/${relationship.id}/config`)
        .set('Authorization', `Bearer ${monitored.accessToken}`)
        .send({
          locationEnabled: true,
        });

      expect(res.status).toBe(200);
      expect(res.body.locationEnabled).toBe(true);

      // Revert back to false
      await request(app.getHttpServer())
        .patch(`/api/v1/monitoring/${relationship.id}/config`)
        .set('Authorization', `Bearer ${monitored.accessToken}`)
        .send({ locationEnabled: false });
    });

    it('should freeze inactivity timer across quiet hours so morning evaluation does not trigger false check-in prompt', async () => {
      // Configure active window 07:00-22:00 everyday with 180 min threshold (3 hours)
      const allDaysWindows = [0, 1, 2, 3, 4, 5, 6].map((day) => ({
        dayOfWeek: day,
        startTime: '07:00',
        endTime: '22:00',
        isEnabled: true,
      }));

      // Senior was active at 21:00 VN yesterday (1 hour before quiet hours 22:00).
      // Now is 07:05 VN today (5 minutes after wake time 07:00).
      // Wall-clock elapsed = 10 hours 5 minutes = 605 minutes.
      // Active elapsed = 60m (21:00-22:00) + 5m (07:00-07:05) = 65m.
      // 65m < 180m threshold -> config must remain ACTIVE!
      const lastActive = new Date('2026-10-05T14:00:00Z'); // 21:00 VN Mon
      const now = new Date('2026-10-06T00:05:00Z'); // 07:05 VN Tue
      const activeMinutes = MonitoringScheduler.calculateActiveInactiveMinutes(
        lastActive,
        now,
        allDaysWindows as any,
        'Asia/Ho_Chi_Minh',
      );
      expect(activeMinutes).toBe(65);
    });
  });
});
