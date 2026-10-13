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

describe('Ext-M3 Backend Adversarial Stress Test (Challenger 2)', () => {
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

    monitor = await registerAndLoginUser(app, 'adv_m3_monitor');
    monitored = await registerAndLoginUser(app, 'adv_m3_monitored');
    device = await registerTestDevice(app, monitored.accessToken);
    const paired = await pairMonitoringRelationship(app, monitor.accessToken, monitored);
    relationship = paired.relationship;
  }, 30000);

  afterAll(async () => {
    await teardownE2eTestApp(app, dataSource);
  });

  // =========================================================================
  // 1. Time Format Regex Validation Fuzzing (startTime & endTime)
  // =========================================================================
  describe('1. Time Format Regex Fuzzing & DTO Validation', () => {
    const invalidFuzzTimes = [
      '24:00',
      '24:01',
      '25:00',
      '99:00',
      '-01:00',
      '12:60',
      '00:61',
      '23:99',
      '7:00',
      '07:0',
      '7:0',
      '07:000',
      '007:00',
      '12:00:00',
      'abc',
      '12:ab',
      'ab:12',
      '--:--',
      '1234',
      '12.30',
      '12-30',
      '12 30',
      ' 12:00',
      '12:00 ',
      '\n12:00',
      '',
      ': ',
      '::',
    ];

    for (const badTime of invalidFuzzTimes) {
      it(`should reject invalid startTime fuzz payload "${badTime}" with 400 Bad Request`, async () => {
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
        expect(res.body.message).toBeDefined();
      });

      it(`should reject invalid endTime fuzz payload "${badTime}" with 400 Bad Request`, async () => {
        const res = await request(app.getHttpServer())
          .patch(`/api/v1/monitoring/${relationship.id}/config`)
          .set('Authorization', `Bearer ${monitored.accessToken}`)
          .send({
            scheduleWindows: [
              {
                dayOfWeek: 1,
                startTime: '07:00',
                endTime: badTime,
                isEnabled: true,
              },
            ],
          });

        expect(res.status).toBe(400);
        expect(res.body.message).toBeDefined();
      });
    }

    it('should reject non-string and malformed types for startTime and endTime', async () => {
      // startTime as number
      const resNum = await request(app.getHttpServer())
        .patch(`/api/v1/monitoring/${relationship.id}/config`)
        .set('Authorization', `Bearer ${monitored.accessToken}`)
        .send({
          scheduleWindows: [
            {
              dayOfWeek: 1,
              startTime: 700 as any,
              endTime: '22:00',
              isEnabled: true,
            },
          ],
        });
      expect(resNum.status).toBe(400);

      // endTime as null
      const resNull = await request(app.getHttpServer())
        .patch(`/api/v1/monitoring/${relationship.id}/config`)
        .set('Authorization', `Bearer ${monitored.accessToken}`)
        .send({
          scheduleWindows: [
            {
              dayOfWeek: 1,
              startTime: '07:00',
              endTime: null as any,
              isEnabled: true,
            },
          ],
        });
      expect(resNull.status).toBe(400);

      // endTime as object
      const resObj = await request(app.getHttpServer())
        .patch(`/api/v1/monitoring/${relationship.id}/config`)
        .set('Authorization', `Bearer ${monitored.accessToken}`)
        .send({
          scheduleWindows: [
            {
              dayOfWeek: 1,
              startTime: '07:00',
              endTime: { time: '22:00' } as any,
              isEnabled: true,
            },
          ],
        });
      expect(resObj.status).toBe(400);
    });

    it('should reject invalid dayOfWeek out of 0..6 boundary', async () => {
      const invalidDays = [-1, 7, 10, 1.5];
      for (const badDay of invalidDays) {
        const res = await request(app.getHttpServer())
          .patch(`/api/v1/monitoring/${relationship.id}/config`)
          .set('Authorization', `Bearer ${monitored.accessToken}`)
          .send({
            scheduleWindows: [
              {
                dayOfWeek: badDay,
                startTime: '07:00',
                endTime: '22:00',
                isEnabled: true,
              },
            ],
          });
        expect(res.status).toBe(400);
      }
    });
  });

  // =========================================================================
  // 2. Inactivity Threshold Minutes Boundary & Type Enforcement
  // =========================================================================
  describe('2. Inactivity Threshold Minutes Boundary & Type Enforcement', () => {
    const invalidBoundaries = [
      0,
      -1,
      -5,
      -100,
      -99999,
      10081,
      10082,
      20000,
      99999,
    ];

    for (const badVal of invalidBoundaries) {
      it(`should reject boundary violation inactivityThresholdMinutes = ${badVal} with 400 Bad Request`, async () => {
        const res = await request(app.getHttpServer())
          .patch(`/api/v1/monitoring/${relationship.id}/config`)
          .set('Authorization', `Bearer ${monitored.accessToken}`)
          .send({ inactivityThresholdMinutes: badVal });

        expect(res.status).toBe(400);
      });
    }

    it('should reject non-integer float values (1.5, 0.5, 45.999)', async () => {
      const floats = [1.5, 0.5, 45.999, -0.5];
      for (const fl of floats) {
        const res = await request(app.getHttpServer())
          .patch(`/api/v1/monitoring/${relationship.id}/config`)
          .set('Authorization', `Bearer ${monitored.accessToken}`)
          .send({ inactivityThresholdMinutes: fl });

        expect(res.status).toBe(400);
      }
    });

    it('should reject string representation of numbers ("120", "abc")', async () => {
      const resStr = await request(app.getHttpServer())
        .patch(`/api/v1/monitoring/${relationship.id}/config`)
        .set('Authorization', `Bearer ${monitored.accessToken}`)
        .send({ inactivityThresholdMinutes: '120' as any });

      expect(resStr.status).toBe(400);
    });

    it('should accept valid minimum boundary 1 and maximum boundary 10080', async () => {
      // Min boundary: 1 minute
      const resMin = await request(app.getHttpServer())
        .patch(`/api/v1/monitoring/${relationship.id}/config`)
        .set('Authorization', `Bearer ${monitored.accessToken}`)
        .send({ inactivityThresholdMinutes: 1 });
      expect(resMin.status).toBe(200);
      expect(resMin.body.inactivityThresholdMinutes).toBe(1);

      // Max boundary: 10080 minutes (7 days)
      const resMax = await request(app.getHttpServer())
        .patch(`/api/v1/monitoring/${relationship.id}/config`)
        .set('Authorization', `Bearer ${monitored.accessToken}`)
        .send({ inactivityThresholdMinutes: 10080 });
      expect(resMax.status).toBe(200);
      expect(resMax.body.inactivityThresholdMinutes).toBe(10080);
    });

    it('should accept all standard preset values (15, 30, 60, 120, 240, 480, 720, 1440)', async () => {
      const presets = [15, 30, 60, 120, 240, 480, 720, 1440];
      for (const preset of presets) {
        const res = await request(app.getHttpServer())
          .patch(`/api/v1/monitoring/${relationship.id}/config`)
          .set('Authorization', `Bearer ${monitored.accessToken}`)
          .send({ inactivityThresholdMinutes: preset });
        expect(res.status).toBe(200);
        expect(res.body.inactivityThresholdMinutes).toBe(preset);
      }
    });
  });

  // =========================================================================
  // 3. Quiet Hours Cron Ticks Under Stress (Zero False Alarms)
  // =========================================================================
  describe('3. InactivityWorker Quiet Hours Simulation (Zero False Alarms)', () => {
    it('should ensure zero false alarms across multiple quiet hours cron ticks (23:30, 02:00, 06:59)', async () => {
      // Configure relationship with UTC timezone and daytime active window Monday 07:00 to 22:00
      // Quiet hours are 22:00 to 07:00 (following day)
      await request(app.getHttpServer())
        .patch(`/api/v1/monitoring/${relationship.id}/config`)
        .set('Authorization', `Bearer ${monitored.accessToken}`)
        .send({
          timezone: 'UTC',
          inactivityThresholdMinutes: 60,
          requireCheckIn: true,
          checkInGraceMinutes: 30,
          scheduleWindows: [
            {
              dayOfWeek: 1, // Monday
              startTime: '07:00',
              endTime: '22:00',
              isEnabled: true,
            },
          ],
        });

      // We will simulate various night timestamps outside the active window
      // 2026-10-05 was Monday.
      // Quiet hours test points:
      // Point 1: Monday 22:30 UTC
      // Point 2: Monday 23:59 UTC
      // Point 3: Tuesday 02:00 UTC
      // Point 4: Tuesday 04:30 UTC
      // Point 5: Tuesday 06:59 UTC (1 minute before wake)
      const quietHourPoints = [
        new Date('2026-10-05T22:30:00.000Z'),
        new Date('2026-10-05T23:59:00.000Z'),
        new Date('2026-10-06T02:00:00.000Z'),
        new Date('2026-10-06T04:30:00.000Z'),
        new Date('2026-10-06T06:59:00.000Z'),
      ];

      for (const simulatedNow of quietHourPoints) {
        // Verify scheduler recognizes simulatedNow as outside active window
        const isInside = MonitoringScheduler.isWithinActiveWindow(
          simulatedNow,
          [
            {
              dayOfWeek: 1,
              startTime: '07:00',
              endTime: '22:00',
              isEnabled: true,
            } as any,
          ],
          'UTC',
        );
        expect(isInside).toBe(false);

        // Calculate expected wake time deferral
        const nextStart = MonitoringScheduler.getNextActiveWindowStart(
          simulatedNow,
          [
            {
              dayOfWeek: 1,
              startTime: '07:00',
              endTime: '22:00',
              isEnabled: true,
            } as any,
          ],
          'UTC',
        );
        // Should defer forward to next Monday 07:00 UTC
        expect(nextStart.toISOString()).toBe('2026-10-12T07:00:00.000Z');
      }

      // Now test live worker service execution with database state
      // Set active window to tomorrow only so that whatever today is, right now is quiet hours
      const now = new Date();
      const tomorrowDay = (now.getUTCDay() + 1) % 7;

      await request(app.getHttpServer())
        .patch(`/api/v1/monitoring/${relationship.id}/config`)
        .set('Authorization', `Bearer ${monitored.accessToken}`)
        .send({
          timezone: 'UTC',
          inactivityThresholdMinutes: 30,
          requireCheckIn: true,
          scheduleWindows: [
            {
              dayOfWeek: tomorrowDay,
              startTime: '07:00',
              endTime: '22:00',
              isEnabled: true,
            },
          ],
        });

      // Simulate 5 consecutive cron cycles with prolonged stillness (past inactivity = 10 hours ago)
      for (let cycle = 1; cycle <= 5; cycle++) {
        // Reset config to overdue evaluation
        await dataSource.query(
          `UPDATE monitoring_configs 
           SET current_state = 'ACTIVE',
               last_meaningful_activity_at = NOW() - INTERVAL '10 hours',
               next_evaluation_at = NOW() - INTERVAL '5 minutes'
           WHERE relationship_id = $1`,
          [relationship.id],
        );

        // Worker ticks
        await workerService.evaluateDueMonitoring(10);

        // Verify config remains strictly ACTIVE (zero false alarms: NO CHECK_IN_REQUIRED, NO WARNING)
        const rows = await dataSource.query(
          `SELECT current_state, next_evaluation_at FROM monitoring_configs WHERE relationship_id = $1`,
          [relationship.id],
        );

        expect(rows[0].current_state).toBe(MonitoringState.ACTIVE);

        // Verify next_evaluation_at was deferred into the future
        const nextEval = new Date(rows[0].next_evaluation_at).getTime();
        expect(nextEval).toBeGreaterThan(Date.now());

        // Verify zero incidents created in DB
        const incidents = await dataSource.query(
          `SELECT COUNT(*)::int AS count FROM incidents WHERE relationship_id = $1`,
          [relationship.id],
        );
        expect(incidents[0].count).toBe(0);
      }
    });
  });

  // =========================================================================
  // 4. Overnight Telemetry & Charging Ingestion During Quiet Hours
  // =========================================================================
  describe('4. Overnight Charging Telemetry & Deferral Under Stress', () => {
    it('should ingest rapid sequence of heartbeats and charging events overnight without panic', async () => {
      // 1. Ingest normal heartbeat
      const hbRes = await request(app.getHttpServer())
        .post('/api/v1/heartbeat')
        .set('Authorization', `Bearer ${monitored.accessToken}`)
        .send({
          deviceId: device.id,
          batteryLevel: 45,
          isCharging: true,
          occurredAt: new Date().toISOString(),
        });

      expect(hbRes.status).toBe(200);
      expect(hbRes.body.operationalState).toBe('ONLINE');

      // 2. Ingest CHARGER_CONNECTED event
      const chargingEventId1 = uuidv4();
      const chargeRes1 = await request(app.getHttpServer())
        .post('/api/v1/activities')
        .set('Authorization', `Bearer ${monitored.accessToken}`)
        .send({
          eventId: chargingEventId1,
          type: ActivityType.CHARGER_CONNECTED,
          deviceId: device.id,
          occurredAt: new Date().toISOString(),
          confidence: 0.95,
          metadata: { batteryLevel: 50, chargingSource: 'WIRELESS' },
        });

      expect(chargeRes1.status).toBe(201);
      expect(chargeRes1.body.type).toBe(ActivityType.CHARGER_CONNECTED);
      expect(Number(chargeRes1.body.weight)).toBe(0.2);

      // 3. Ingest CHARGER_DISCONNECTED event
      const chargingEventId2 = uuidv4();
      const chargeRes2 = await request(app.getHttpServer())
        .post('/api/v1/activities')
        .set('Authorization', `Bearer ${monitored.accessToken}`)
        .send({
          eventId: chargingEventId2,
          type: ActivityType.CHARGER_DISCONNECTED,
          deviceId: device.id,
          occurredAt: new Date().toISOString(),
          confidence: 0.9,
          metadata: { batteryLevel: 98 },
        });

      expect(chargeRes2.status).toBe(201);
      expect(chargeRes2.body.type).toBe(ActivityType.CHARGER_DISCONNECTED);
      expect(Number(chargeRes2.body.weight)).toBe(0.2);

      // 4. Verify idempotent replay of same eventId
      const replayRes = await request(app.getHttpServer())
        .post('/api/v1/activities')
        .set('Authorization', `Bearer ${monitored.accessToken}`)
        .send({
          eventId: chargingEventId2,
          type: ActivityType.CHARGER_DISCONNECTED,
          deviceId: device.id,
          occurredAt: new Date().toISOString(),
          confidence: 0.9,
        });

      expect(replayRes.status).toBe(201);
      expect(replayRes.body.eventId).toBe(chargingEventId2);

      // 5. Worker execution while outside window still defers cleanly
      await dataSource.query(
        `UPDATE monitoring_configs 
         SET next_evaluation_at = NOW() - INTERVAL '2 minutes'
         WHERE relationship_id = $1`,
        [relationship.id],
      );

      await workerService.evaluateDueMonitoring(10);

      const rows = await dataSource.query(
        `SELECT current_state, next_evaluation_at FROM monitoring_configs WHERE relationship_id = $1`,
        [relationship.id],
      );
      expect(rows[0].current_state).toBe(MonitoringState.ACTIVE);
      expect(new Date(rows[0].next_evaluation_at).getTime()).toBeGreaterThan(Date.now());
    });
  });

  // =========================================================================
  // 5. Transition to Wake Time & Calm UX Resume
  // =========================================================================
  describe('5. Wake Time Transition & Morning Check-In Flow', () => {
    it('should prompt CHECK_IN_REQUIRED with grace period at wake time if inactive, avoiding direct incident panic', async () => {
      // Configure schedule window to be active ALL 7 days, 00:00 to 23:59 (so current time IS within window)
      const allDays = [0, 1, 2, 3, 4, 5, 6].map((day) => ({
        dayOfWeek: day,
        startTime: '00:00',
        endTime: '23:59',
        isEnabled: true,
      }));

      await request(app.getHttpServer())
        .patch(`/api/v1/monitoring/${relationship.id}/config`)
        .set('Authorization', `Bearer ${monitored.accessToken}`)
        .send({
          timezone: 'UTC',
          inactivityThresholdMinutes: 60,
          requireCheckIn: true,
          checkInGraceMinutes: 30,
          scheduleWindows: allDays,
        });

      // Simulate wake time condition: user was inactive all night (last active 8 hours ago)
      await dataSource.query(
        `UPDATE monitoring_configs 
         SET current_state = 'ACTIVE',
             last_meaningful_activity_at = NOW() - INTERVAL '8 hours',
             next_evaluation_at = NOW() - INTERVAL '1 minute'
         WHERE relationship_id = $1`,
        [relationship.id],
      );

      // Worker runs at wake time
      await workerService.evaluateDueMonitoring(10);

      // Verify that system transitions to CHECK_IN_REQUIRED (prompting elder "Are you okay?"),
      // and NOT straight to WARNING or creating an incident!
      const rows = await dataSource.query(
        `SELECT current_state, next_evaluation_at FROM monitoring_configs WHERE relationship_id = $1`,
        [relationship.id],
      );

      expect(rows[0].current_state).toBe(MonitoringState.CHECK_IN_REQUIRED);

      // Verify grace period: next_evaluation_at is set to approximately now + 30 minutes
      const nextEval = new Date(rows[0].next_evaluation_at).getTime();
      const expectedEval = Date.now() + 30 * 60 * 1000;
      expect(Math.abs(nextEval - expectedEval)).toBeLessThan(60 * 1000); // within 1 minute

      // 0 incidents created yet (calm UX: no false alarm sent to guardians during grace period)
      const incidentCount = await dataSource.query(
        `SELECT COUNT(*)::int AS count FROM incidents WHERE relationship_id = $1`,
        [relationship.id],
      );
      expect(incidentCount[0].count).toBe(0);

      // Now simulate user one-tap check-in "Tôi vẫn ổn"
      const checkInEventId = uuidv4();
      const checkInRes = await request(app.getHttpServer())
        .post('/api/v1/activities')
        .set('Authorization', `Bearer ${monitored.accessToken}`)
        .send({
          eventId: checkInEventId,
          type: ActivityType.CHECK_IN,
          deviceId: device.id,
          occurredAt: new Date().toISOString(),
          confidence: 1.0,
        });

      expect(checkInRes.status).toBe(201);
      expect(checkInRes.body.type).toBe(ActivityType.CHECK_IN);

      // Config must return safely to ACTIVE state
      const restoredConfig = await dataSource.query(
        `SELECT current_state FROM monitoring_configs WHERE relationship_id = $1`,
        [relationship.id],
      );
      expect(restoredConfig[0].current_state).toBe(MonitoringState.ACTIVE);
    });
  });

  // =========================================================================
  // 6. MonitoringScheduler Unit Boundary & Timezone Robustness
  // =========================================================================
  describe('6. MonitoringScheduler Boundary Stress & Extreme Timezones', () => {
    it('should evaluate overnight windows correctly across midnight boundary', () => {
      // Overnight window: 22:00 to 06:00
      expect(MonitoringScheduler.isTimeBetween('21:59', '22:00', '06:00')).toBe(false);
      expect(MonitoringScheduler.isTimeBetween('22:00', '22:00', '06:00')).toBe(true);
      expect(MonitoringScheduler.isTimeBetween('23:30', '22:00', '06:00')).toBe(true);
      expect(MonitoringScheduler.isTimeBetween('00:00', '22:00', '06:00')).toBe(true);
      expect(MonitoringScheduler.isTimeBetween('05:59', '22:00', '06:00')).toBe(true);
      expect(MonitoringScheduler.isTimeBetween('06:00', '22:00', '06:00')).toBe(true);
      expect(MonitoringScheduler.isTimeBetween('06:01', '22:00', '06:00')).toBe(false);
    });

    it('should safely fall back to Asia/Ho_Chi_Minh on invalid timezone strings without throwing', () => {
      const invalidTzs = ['Invalid/Timezone', 'NoSuchZone', '', '   '];
      const windows = [
        {
          dayOfWeek: 1,
          startTime: '07:00',
          endTime: '22:00',
          isEnabled: true,
        } as any,
      ];

      for (const badTz of invalidTzs) {
        expect(() => {
          MonitoringScheduler.isWithinActiveWindow(new Date(), windows, badTz);
        }).not.toThrow();

        expect(() => {
          MonitoringScheduler.getNextActiveWindowStart(new Date(), windows, badTz);
        }).not.toThrow();
      }
    });

    it('should return true 24/7 if no windows are configured or array is empty', () => {
      expect(MonitoringScheduler.isWithinActiveWindow(new Date(), [], 'UTC')).toBe(true);
      expect(MonitoringScheduler.isWithinActiveWindow(new Date(), null as any, 'UTC')).toBe(true);
    });

    it('should return false if all windows are disabled', () => {
      const disabledWindows = [
        {
          dayOfWeek: 1,
          startTime: '07:00',
          endTime: '22:00',
          isEnabled: false,
        } as any,
      ];
      expect(MonitoringScheduler.isWithinActiveWindow(new Date(), disabledWindows, 'UTC')).toBe(false);
    });
  });
});
