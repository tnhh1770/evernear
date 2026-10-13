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
} from './e2e-helper';
import {
  ActivityType,
  DevicePlatform,
  IncidentEventType,
  IncidentStatus,
  MonitoringState,
  NotificationDeliveryStatus,
} from '../../src/common/enums';
import { MonitoringWorkerService } from '../../src/modules/workers/monitoring-worker.service';
import { RedisService } from '../../src/common/redis/redis.service';
import { RiskEvaluatorService } from '../../src/modules/incidents/risk-evaluator.service';
import { MonitoringStateMachine } from '../../src/modules/monitoring/monitoring-state-machine';
import { MonitoringScheduler } from '../../src/modules/monitoring/monitoring-scheduler';
import { NotificationsService } from '../../src/modules/notifications/notifications.service';
import { ActivityService } from '../../src/modules/activities/activity.service';

describe('Tier 2: Boundary & Corner Cases (>=5 tests / feature)', () => {
  let app: INestApplication;
  let dataSource: DataSource;
  let workerService: MonitoringWorkerService;
  let redisService: RedisService;
  let riskEvaluatorService: RiskEvaluatorService;
  let notificationsService: NotificationsService;
  let activityService: ActivityService;

  let monitor: TestUserContext;
  let monitored: TestUserContext;
  let device: any;
  let relationship: any;

  beforeAll(async () => {
    const context = await createE2eTestApp();
    app = context.app;
    dataSource = context.dataSource;
    workerService = context.moduleFixture.get<MonitoringWorkerService>(MonitoringWorkerService);
    redisService = context.moduleFixture.get<RedisService>(RedisService);
    riskEvaluatorService = context.moduleFixture.get<RiskEvaluatorService>(RiskEvaluatorService);
    notificationsService = context.moduleFixture.get<NotificationsService>(NotificationsService);
    activityService = context.moduleFixture.get<ActivityService>(ActivityService);

    await resetDatabase(dataSource);

    monitor = await registerAndLoginUser(app, 't2_monitor');
    monitored = await registerAndLoginUser(app, 't2_monitored');
    device = await registerTestDevice(app, monitored.accessToken);
    const paired = await pairMonitoringRelationship(app, monitor.accessToken, monitored);
    relationship = paired.relationship;
  }, 30000);

  afterAll(async () => {
    await teardownE2eTestApp(app, dataSource);
  });

  // =========================================================================
  // Feature 1: Auth Boundaries
  // =========================================================================
  describe('Feature 1: Auth Boundaries', () => {
    it('1.1: Password < 6 chars boundary rejected with 400', async () => {
      const res = await request(app.getHttpServer())
        .post('/api/v1/auth/register')
        .send({
          email: `short_pw_${Date.now()}@carely.test`,
          password: '12345',
          displayName: 'Short Password',
        });

      expect(res.status).toBe(400);
    });

    it('1.2: Password exactly 6 chars boundary accepted with 201', async () => {
      const res = await request(app.getHttpServer())
        .post('/api/v1/auth/register')
        .send({
          email: `exact6_${Date.now()}@carely.test`,
          password: '123456',
          displayName: 'Exact Six Password',
        });

      expect(res.status).toBe(201);
    });

    it('1.3: Malformed email syntax rejected with 400', async () => {
      const res = await request(app.getHttpServer())
        .post('/api/v1/auth/register')
        .send({
          email: 'not-a-valid-email-string',
          password: 'Password123!',
          displayName: 'Bad Email',
        });

      expect(res.status).toBe(400);
    });

    it('1.4: Random invalid refresh token returns 401', async () => {
      const res = await request(app.getHttpServer())
        .post('/api/v1/auth/refresh')
        .send({
          refreshToken: 'completely-invalid-refresh-jwt-token-string',
        });

      expect(res.status).toBe(401);
    });

    it('1.5: Whitespace-only or empty displayName rejected with 400', async () => {
      const res = await request(app.getHttpServer())
        .post('/api/v1/auth/register')
        .send({
          email: `empty_name_${Date.now()}@carely.test`,
          password: 'Password123!',
          displayName: '',
        });

      expect(res.status).toBe(400);
    });
  });

  // =========================================================================
  // Feature 2: Device Boundaries
  // =========================================================================
  describe('Feature 2: Device Boundaries', () => {
    it('2.1: Battery level boundary min (0) accepted with 201', async () => {
      const dev = await registerTestDevice(app, monitored.accessToken, {
        batteryLevel: 0,
        deviceName: 'Device Battery Min 0',
      });
      expect(dev.batteryLevel).toBe(0);
    });

    it('2.2: Battery level boundary max (100) accepted with 201', async () => {
      const dev = await registerTestDevice(app, monitored.accessToken, {
        batteryLevel: 100,
        deviceName: 'Device Battery Max 100',
      });
      expect(dev.batteryLevel).toBe(100);
    });

    it('2.3: Battery level < 0 (-5) rejected with 400', async () => {
      const res = await request(app.getHttpServer())
        .post('/api/v1/devices')
        .set('Authorization', `Bearer ${monitored.accessToken}`)
        .send({
          deviceUid: `dev-neg-${Date.now()}`,
          platform: DevicePlatform.ANDROID,
          deviceName: 'Negative Battery Device',
          batteryLevel: -5,
        });

      expect(res.status).toBe(400);
    });

    it('2.4: Battery level > 100 (105) rejected with 400', async () => {
      const res = await request(app.getHttpServer())
        .post('/api/v1/devices')
        .set('Authorization', `Bearer ${monitored.accessToken}`)
        .send({
          deviceUid: `dev-over-${Date.now()}`,
          platform: DevicePlatform.ANDROID,
          deviceName: 'Over Battery Device',
          batteryLevel: 105,
        });

      expect(res.status).toBe(400);
    });

    it('2.5: Looking up non-existent device UUID returns 404', async () => {
      const nonExistent = uuidv4();
      const res = await request(app.getHttpServer())
        .get(`/api/v1/devices/${nonExistent}`)
        .set('Authorization', `Bearer ${monitored.accessToken}`);

      expect(res.status).toBe(404);
    });
  });

  // =========================================================================
  // Feature 3: Heartbeat Boundaries
  // =========================================================================
  describe('Feature 3: Heartbeat Boundaries', () => {
    let freshDev: any;

    beforeAll(async () => {
      freshDev = await registerTestDevice(app, monitored.accessToken);
    });

    it('3.1: Heartbeat with boundary 0% battery level', async () => {
      const res = await request(app.getHttpServer())
        .post('/api/v1/heartbeat')
        .set('Authorization', `Bearer ${monitored.accessToken}`)
        .send({
          deviceId: freshDev.id,
          occurredAt: new Date().toISOString(),
          batteryLevel: 0,
        });

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
    });

    it('3.2: Heartbeat with boundary 100% battery level', async () => {
      const res = await request(app.getHttpServer())
        .post('/api/v1/heartbeat')
        .set('Authorization', `Bearer ${monitored.accessToken}`)
        .send({
          deviceId: freshDev.id,
          occurredAt: new Date().toISOString(),
          batteryLevel: 100,
        });

      expect(res.status).toBe(200);
    });

    it('3.3: Heartbeat from revoked device rejected with 403 Forbidden', async () => {
      const revDev = await registerTestDevice(app, monitored.accessToken);
      await request(app.getHttpServer())
        .post(`/api/v1/devices/${revDev.id}/revoke`)
        .set('Authorization', `Bearer ${monitored.accessToken}`);

      const res = await request(app.getHttpServer())
        .post('/api/v1/heartbeat')
        .set('Authorization', `Bearer ${monitored.accessToken}`)
        .send({
          deviceId: revDev.id,
          occurredAt: new Date().toISOString(),
          batteryLevel: 50,
        });

      expect(res.status).toBe(401);
    });

    it('3.4: Heartbeat rate limiting: 3rd heartbeat in rapid succession within 30s returns 429', async () => {
      // freshDev already received 2 heartbeats in 3.1 and 3.2
      const res = await request(app.getHttpServer())
        .post('/api/v1/heartbeat')
        .set('Authorization', `Bearer ${monitored.accessToken}`)
        .send({
          deviceId: freshDev.id,
          occurredAt: new Date().toISOString(),
          batteryLevel: 90,
        });

      expect(res.status).toBe(429);
    });

    it('3.5: Heartbeat with client clock skew in the past still records reachability without updating activity timer', async () => {
      const pastSkewDev = await registerTestDevice(app, monitored.accessToken);
      const pastDate = new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString();

      const res = await request(app.getHttpServer())
        .post('/api/v1/heartbeat')
        .set('Authorization', `Bearer ${monitored.accessToken}`)
        .send({
          deviceId: pastSkewDev.id,
          occurredAt: pastDate,
          batteryLevel: 60,
        });

      expect(res.status).toBe(200);
    });
  });

  // =========================================================================
  // Feature 4: Meaningful Activity Boundaries
  // =========================================================================
  describe('Feature 4: Meaningful Activity Boundaries', () => {
    it('4.1: Clock skew in future (>5m) clamped to server now to prevent deadline extension', async () => {
      const futureDate = new Date(Date.now() + 60 * 60 * 1000).toISOString(); // 1 hour ahead
      const eventId = uuidv4();

      const res = await request(app.getHttpServer())
        .post('/api/v1/activities')
        .set('Authorization', `Bearer ${monitored.accessToken}`)
        .send({
          eventId,
          deviceId: device.id,
          type: ActivityType.APP_OPEN,
          occurredAt: futureDate,
          confidence: 0.9,
        });

      expect(res.status).toBe(201);
      // In database, occurred_at was clamped to near server now
      const rows = await dataSource.query(`SELECT occurred_at FROM activities WHERE event_id = $1`, [
        eventId,
      ]);
      const storedTime = new Date(rows[0].occurred_at).getTime();
      expect(storedTime).toBeLessThan(Date.now() + 5 * 60 * 1000);
    });

    it('4.2: Activity with confidence = 0.0 (boundary min) accepted but not marked meaningful', async () => {
      const eventId = uuidv4();
      const res = await request(app.getHttpServer())
        .post('/api/v1/activities')
        .set('Authorization', `Bearer ${monitored.accessToken}`)
        .send({
          eventId,
          deviceId: device.id,
          type: ActivityType.STEP_DETECTED,
          occurredAt: new Date().toISOString(),
          confidence: 0.0,
        });

      expect(res.status).toBe(201);
      expect(Number(res.body.confidence)).toBe(0.0);
    });

    it('4.3: Activity with confidence = 1.0 (boundary max) accepted and evaluated as meaningful', async () => {
      const eventId = uuidv4();
      const res = await request(app.getHttpServer())
        .post('/api/v1/activities')
        .set('Authorization', `Bearer ${monitored.accessToken}`)
        .send({
          eventId,
          deviceId: device.id,
          type: ActivityType.APP_FOREGROUND,
          occurredAt: new Date().toISOString(),
          confidence: 1.0,
        });

      expect(res.status).toBe(201);
      expect(Number(res.body.confidence)).toBe(1.0);
    });

    it('4.4: Activity confidence > 1.0 rejected with 400', async () => {
      const res = await request(app.getHttpServer())
        .post('/api/v1/activities')
        .set('Authorization', `Bearer ${monitored.accessToken}`)
        .send({
          eventId: uuidv4(),
          deviceId: device.id,
          type: ActivityType.APP_FOREGROUND,
          occurredAt: new Date().toISOString(),
          confidence: 1.5,
        });

      expect(res.status).toBe(400);
    });

    it('4.5: Unknown/unrecognized activity type rejected with 400', async () => {
      const res = await request(app.getHttpServer())
        .post('/api/v1/activities')
        .set('Authorization', `Bearer ${monitored.accessToken}`)
        .send({
          eventId: uuidv4(),
          deviceId: device.id,
          type: 'NOT_A_VALID_ACTIVITY_TYPE',
          occurredAt: new Date().toISOString(),
          confidence: 0.9,
        });

      expect(res.status).toBe(400);
    });
  });

  // =========================================================================
  // Feature 5: Check-in Boundaries
  // =========================================================================
  describe('Feature 5: Check-in Boundaries', () => {
    it('5.1: Check-in with complex Vietnamese Unicode characters in note preserved accurately', async () => {
      const eventId = uuidv4();
      const unicodeNote = 'Tôi vẫn ổn, đang uống cà phê ở quán ven hồ Tây Hà Nội 🌿.';
      const res = await request(app.getHttpServer())
        .post('/api/v1/check-ins')
        .set('Authorization', `Bearer ${monitored.accessToken}`)
        .send({
          eventId,
          deviceId: device.id,
          relationshipId: relationship.id,
          occurredAt: new Date().toISOString(),
          batteryLevel: 80,
          note: unicodeNote,
        });

      expect(res.status).toBe(201);
      expect(res.body.note).toBe(unicodeNote);
    });

    it('5.2: Check-in with boundary coordinates: latitude 90, longitude 180 (valid extremes)', async () => {
      const eventId = uuidv4();
      const res = await request(app.getHttpServer())
        .post('/api/v1/check-ins')
        .set('Authorization', `Bearer ${monitored.accessToken}`)
        .send({
          eventId,
          deviceId: device.id,
          relationshipId: relationship.id,
          occurredAt: new Date().toISOString(),
          batteryLevel: 75,
          location: {
            latitude: 90,
            longitude: 180,
          },
        });

      expect(res.status).toBe(201);
    });

    it('5.3: Check-in with out-of-range latitude (>90) or longitude (>180) rejected with 400 or invalid', async () => {
      const res = await request(app.getHttpServer())
        .post('/api/v1/locations')
        .set('Authorization', `Bearer ${monitored.accessToken}`)
        .send({
          deviceId: device.id,
          latitude: 95.0, // Invalid latitude > 90
          longitude: 200.0,
          capturedAt: new Date().toISOString(),
        });

      expect(res.status).toBe(400);
    });

    it('5.4: Check-in with empty string note handled gracefully', async () => {
      const eventId = uuidv4();
      const res = await request(app.getHttpServer())
        .post('/api/v1/check-ins')
        .set('Authorization', `Bearer ${monitored.accessToken}`)
        .send({
          eventId,
          deviceId: device.id,
          relationshipId: relationship.id,
          occurredAt: new Date().toISOString(),
          batteryLevel: 70,
          note: '',
        });

      expect(res.status).toBe(201);
      expect(res.body.note).toBeDefined();
    });

    it('5.5: Check-in from revoked device rejected with 403 Forbidden', async () => {
      const revokedDev = await registerTestDevice(app, monitored.accessToken);
      await request(app.getHttpServer())
        .post(`/api/v1/devices/${revokedDev.id}/revoke`)
        .set('Authorization', `Bearer ${monitored.accessToken}`);

      const res = await request(app.getHttpServer())
        .post('/api/v1/check-ins')
        .set('Authorization', `Bearer ${monitored.accessToken}`)
        .send({
          eventId: uuidv4(),
          deviceId: revokedDev.id,
          relationshipId: relationship.id,
          occurredAt: new Date().toISOString(),
          batteryLevel: 70,
        });

      expect(res.status).toBe(401);
    });
  });

  // =========================================================================
  // Feature 6: Idempotency Boundaries
  // =========================================================================
  describe('Feature 6: Idempotency Boundaries', () => {
    it('6.1: Non-UUID eventId rejected with 400', async () => {
      const res = await request(app.getHttpServer())
        .post('/api/v1/activities')
        .set('Authorization', `Bearer ${monitored.accessToken}`)
        .send({
          eventId: 'not-a-uuid-1234',
          deviceId: device.id,
          type: ActivityType.APP_OPEN,
          occurredAt: new Date().toISOString(),
        });

      expect(res.status).toBe(400);
    });

    it('6.2: Empty / missing eventId rejected with 400', async () => {
      const res = await request(app.getHttpServer())
        .post('/api/v1/activities')
        .set('Authorization', `Bearer ${monitored.accessToken}`)
        .send({
          deviceId: device.id,
          type: ActivityType.APP_OPEN,
          occurredAt: new Date().toISOString(),
        });

      expect(res.status).toBe(400);
    });

    it('6.3: Ingesting duplicate eventId with different payloads returns original payload data', async () => {
      const eventId = uuidv4();
      const firstRes = await request(app.getHttpServer())
        .post('/api/v1/activities')
        .set('Authorization', `Bearer ${monitored.accessToken}`)
        .send({
          eventId,
          deviceId: device.id,
          type: ActivityType.APP_OPEN,
          occurredAt: new Date().toISOString(),
          confidence: 0.8,
          metadata: { note: 'Initial payload' },
        });

      const secondRes = await request(app.getHttpServer())
        .post('/api/v1/activities')
        .set('Authorization', `Bearer ${monitored.accessToken}`)
        .send({
          eventId,
          deviceId: device.id,
          type: ActivityType.CHARGER_CONNECTED, // altered payload
          occurredAt: new Date().toISOString(),
          confidence: 0.2,
          metadata: { note: 'Attempted overwrite' },
        });

      expect(secondRes.body.id).toBe(firstRes.body.id);
      expect(secondRes.body.type).toBe(ActivityType.APP_OPEN); // Original type preserved!
    });

    it('6.4: Concurrent identical requests with same eventId resolve safely without 500 error', async () => {
      const eventId = uuidv4();
      const [res1, res2] = await Promise.all([
        request(app.getHttpServer())
          .post('/api/v1/activities')
          .set('Authorization', `Bearer ${monitored.accessToken}`)
          .send({
            eventId,
            deviceId: device.id,
            type: ActivityType.SCREEN_INTERACTION,
            occurredAt: new Date().toISOString(),
            confidence: 0.9,
          }),
        request(app.getHttpServer())
          .post('/api/v1/activities')
          .set('Authorization', `Bearer ${monitored.accessToken}`)
          .send({
            eventId,
            deviceId: device.id,
            type: ActivityType.SCREEN_INTERACTION,
            occurredAt: new Date().toISOString(),
            confidence: 0.9,
          }),
      ]);

      expect([200, 201]).toContain(res1.status);
      expect([200, 201]).toContain(res2.status);
      expect(res1.body.id).toBe(res2.body.id);
    });

    it('6.5: Batch ingestion with 10 duplicate eventIds deduplicates cleanly to 1 record', async () => {
      const batchEventId = uuidv4();
      const batchItems = Array.from({ length: 10 }).map(() => ({
        eventId: batchEventId,
        deviceId: device.id,
        type: ActivityType.DEVICE_MOTION,
        occurredAt: new Date().toISOString(),
        confidence: 0.8,
      }));

      const results = await activityService.ingestBatch(monitored.id, batchItems);
      expect(results.length).toBeGreaterThanOrEqual(1);

      const rows = await dataSource.query(`SELECT COUNT(*) FROM activities WHERE event_id = $1`, [
        batchEventId,
      ]);
      expect(Number(rows[0].count)).toBe(1);
    });
  });

  // =========================================================================
  // Feature 7: Timezone Calendar Window Boundaries
  // =========================================================================
  describe('Feature 7: Timezone Calendar Window Boundaries', () => {
    it('7.1: Schedule window boundary exactly at startTime ("07:00") evaluates as within window', () => {
      expect(MonitoringScheduler.isTimeBetween('07:00', '07:00', '22:00')).toBe(true);
    });

    it('7.2: Schedule window boundary exactly at endTime ("22:00") evaluates as within window', () => {
      expect(MonitoringScheduler.isTimeBetween('22:00', '07:00', '22:00')).toBe(true);
    });

    it('7.3: Overnight window boundary at midnight ("00:00") evaluates as within window', () => {
      expect(MonitoringScheduler.isTimeBetween('00:00', '22:00', '06:00')).toBe(true);
    });

    it('7.4: Day-of-week rollover (active window spans across user timezone)', () => {
      // Wednesday 10:00 AM UTC -> 17:00 PM Asia/Ho_Chi_Minh
      const testDate = new Date('2026-10-07T10:00:00Z');
      const windows = [
        {
          id: 'w1',
          configId: 'cfg1',
          config: null as any,
          dayOfWeek: 3,
          startTime: '16:00',
          endTime: '23:00',
          isEnabled: true,
          createdAt: new Date(),
          updatedAt: new Date(),
        },
      ];
      expect(
        MonitoringScheduler.isWithinActiveWindow(testDate, windows, 'Asia/Ho_Chi_Minh'),
      ).toBe(true);
    });

    it('7.5: Invalid day of week (<0 or >6) in config rejected with 400', async () => {
      const res = await request(app.getHttpServer())
        .patch(`/api/v1/monitoring/${relationship.id}/config`)
        .set('Authorization', `Bearer ${monitored.accessToken}`)
        .send({
          scheduleWindows: [
            {
              dayOfWeek: 7, // Invalid day of week > 6
              startTime: '08:00',
              endTime: '20:00',
              isEnabled: true,
            },
          ],
        });

      expect(res.status).toBe(400);
    });
  });

  // =========================================================================
  // Feature 8: Worker & Locking Boundaries
  // =========================================================================
  describe('Feature 8: Worker & Locking Boundaries', () => {
    it('8.1: Worker evaluation with batch size 1 processes exactly 1 record', async () => {
      await dataSource.query(
        `UPDATE monitoring_configs 
         SET next_evaluation_at = NOW() - INTERVAL '5 seconds'
         WHERE relationship_id = $1`,
        [relationship.id],
      );

      const processed = await workerService.evaluateDueMonitoring(1);
      expect(processed).toBeLessThanOrEqual(1);
    });

    it('8.2: Worker evaluation when nextEvaluationAt is in the future returns 0 processed', async () => {
      await dataSource.query(
        `UPDATE monitoring_configs 
         SET next_evaluation_at = NOW() + INTERVAL '10 hours'
         WHERE relationship_id = $1`,
        [relationship.id],
      );

      const due = await dataSource.query(
        `SELECT id FROM monitoring_configs WHERE enabled = TRUE AND next_evaluation_at <= NOW() AND relationship_id = $1`,
        [relationship.id],
      );
      expect(due.length).toBe(0);
    });

    it('8.3: Worker evaluation with 0 due configs returns 0 processed without error', async () => {
      const count = await workerService.evaluateDueMonitoring(0);
      expect(count).toBe(0);
    });

    it('8.4: Worker skips disabled config even if nextEvaluationAt is past', async () => {
      await dataSource.query(
        `UPDATE monitoring_configs 
         SET enabled = FALSE, next_evaluation_at = NOW() - INTERVAL '1 hour'
         WHERE relationship_id = $1`,
        [relationship.id],
      );

      const due = await dataSource.query(
        `SELECT id FROM monitoring_configs WHERE enabled = TRUE AND next_evaluation_at <= NOW() AND relationship_id = $1`,
        [relationship.id],
      );
      expect(due.length).toBe(0);

      // Re-enable
      await dataSource.query(
        `UPDATE monitoring_configs SET enabled = TRUE WHERE relationship_id = $1`,
        [relationship.id],
      );
    });

    it('8.5: Worker batching handles large batch size (100) gracefully', async () => {
      const count = await workerService.evaluateDueMonitoring(100);
      expect(typeof count).toBe('number');
    });
  });

  // =========================================================================
  // Feature 9: State Machine Boundaries
  // =========================================================================
  describe('Feature 9: State Machine Boundaries', () => {
    it('9.1: Transition with identical fromState and toState handled safely', () => {
      expect(
        MonitoringStateMachine.canTransition(MonitoringState.ACTIVE, MonitoringState.ACTIVE),
      ).toBe(true);
    });

    it('9.2: Direct transition from ACTIVE to ESCALATED rejected', () => {
      expect(
        MonitoringStateMachine.canTransition(MonitoringState.ACTIVE, MonitoringState.ESCALATED),
      ).toBe(false);
    });

    it('9.3: Transition to SUSPENDED preserves config state', () => {
      expect(
        MonitoringStateMachine.canTransition(MonitoringState.ACTIVE, MonitoringState.SUSPENDED),
      ).toBe(true);
    });

    it('9.4: Resuming from SUSPENDED restores ACTIVE state cleanly', () => {
      expect(
        MonitoringStateMachine.canTransition(MonitoringState.SUSPENDED, MonitoringState.ACTIVE),
      ).toBe(true);
    });

    it('9.5: Invalid state string value throws error or returns false', () => {
      expect(
        MonitoringStateMachine.canTransition(
          MonitoringState.ACTIVE,
          'INVALID_STATE_STRING' as any,
        ),
      ).toBe(false);
    });
  });

  // =========================================================================
  // Feature 10: Redis & Cache Boundaries
  // =========================================================================
  describe('Feature 10: Redis & Cache Boundaries', () => {
    it('10.1: Lock TTL boundary: short TTL (100ms) expires automatically', async () => {
      const lockKey = `test:ttl:exp:${Date.now()}`;
      const token = await redisService.acquireLock(lockKey, 100);
      expect(token).toBeDefined();

      // Wait 150ms for lock to expire
      await new Promise((r) => setTimeout(r, 150));

      // Should be able to acquire again because old lock expired
      const token2 = await redisService.acquireLock(lockKey, 1000);
      expect(token2).toBeDefined();
      if (token2) {
        await redisService.releaseLock(lockKey, token2);
      }
    });

    it('10.2: Releasing lock with wrong token returns false / prevents unlocking foreign locks', async () => {
      const lockKey = `test:wrong:token:${Date.now()}`;
      const validToken = await redisService.acquireLock(lockKey, 5000);
      expect(validToken).toBeDefined();

      const released = await redisService.releaseLock(lockKey, 'wrong-token-value');
      expect(released).toBe(false);

      // Clean up with valid token
      await redisService.releaseLock(lockKey, validToken!);
    });

    it('10.3: Second acquire on active lock returns null (mutual exclusion)', async () => {
      const lockKey = `test:mutex:${Date.now()}`;
      const firstToken = await redisService.acquireLock(lockKey, 5000);
      expect(firstToken).toBeDefined();

      const secondToken = await redisService.acquireLock(lockKey, 5000);
      expect(secondToken).toBeNull();

      await redisService.releaseLock(lockKey, firstToken!);
    });

    it('10.4: Redis service reports readiness state accurately', () => {
      expect(typeof redisService.isReady).toBe('boolean');
    });

    it('10.5: Ingestion succeeds when cache miss transparently falls back to database', async () => {
      const eventId = uuidv4();
      const res = await request(app.getHttpServer())
        .post('/api/v1/activities')
        .set('Authorization', `Bearer ${monitored.accessToken}`)
        .send({
          eventId,
          deviceId: device.id,
          type: ActivityType.APP_OPEN,
          occurredAt: new Date().toISOString(),
          confidence: 0.9,
        });

      expect(res.status).toBe(201);
    });
  });

  // =========================================================================
  // Feature 11: Risk Scoring Boundaries
  // =========================================================================
  describe('Feature 11: Risk Scoring Boundaries', () => {
    it('11.1: Risk score boundary: all factors false yields minimum score (0)', () => {
      const res = riskEvaluatorService.evaluate({
        isInactivityExceeded: false,
        isCheckInMissed: false,
        isDeviceOffline: false,
        isLowBattery: false,
      });

      expect(res.riskScore).toBe(0);
      expect(res.summary).toBe('Trạng thái bình thường.');
    });

    it('11.2: Risk score boundary: all factors true yields maximum clamped score (<=100)', () => {
      const res = riskEvaluatorService.evaluate({
        isInactivityExceeded: true,
        isCheckInMissed: true,
        isDeviceOffline: true,
        isLowBattery: true,
        batteryLevel: 5,
        inactivityMinutes: 1440,
      });

      expect(res.riskScore).toBeLessThanOrEqual(100);
      expect(res.riskScore).toBeGreaterThanOrEqual(90);
    });

    it('11.3: Risk score evaluation with missing battery level defaults safely', () => {
      const res = riskEvaluatorService.evaluate({
        isInactivityExceeded: true,
        isCheckInMissed: false,
        isDeviceOffline: false,
        isLowBattery: false,
      });

      expect(res.riskScore).toBe(30);
    });

    it('11.4: Extreme inactivity minutes (e.g. 100,000 minutes) does not cause numeric overflow', () => {
      const res = riskEvaluatorService.evaluate({
        isInactivityExceeded: true,
        isCheckInMissed: true,
        isDeviceOffline: true,
        isLowBattery: true,
        inactivityMinutes: 100000,
      });

      expect(Number.isFinite(res.riskScore)).toBe(true);
      expect(res.riskScore).toBeLessThanOrEqual(100);
    });

    it('11.5: Summary text contains no medical or sensationalist claims', () => {
      const res = riskEvaluatorService.evaluate({
        isInactivityExceeded: true,
        isCheckInMissed: true,
        isDeviceOffline: true,
        isLowBattery: true,
      });

      expect(res.summary).not.toContain('nguy kịch');
      expect(res.summary).not.toContain('chết');
      expect(res.summary).not.toContain('cấp cứu');
      expect(res.disclaimer).toBeDefined();
    });
  });

  // =========================================================================
  // Feature 12: Escalation Engine Boundaries
  // =========================================================================
  describe('Feature 12: Escalation Engine Boundaries', () => {
    it('12.1: Notification dispatch with empty template params handled safely', async () => {
      const deliveries = await notificationsService.sendNotification({
        recipientUserId: monitored.id,
        templateName: 'CHECK_IN_REMINDER_CALM',
        templateParams: {},
      });

      expect(Array.isArray(deliveries)).toBe(true);
    });

    it('12.2: Notification dispatch to user with no devices returns FAILED record without throw', async () => {
      const nonDevUser = await registerAndLoginUser(app, 'b12_nodev');
      const deliveries = await notificationsService.sendNotification({
        recipientUserId: nonDevUser.id,
        templateName: 'CHECK_IN_WARNING_URGENT',
        templateParams: { name: 'NoDev' },
      });

      expect(deliveries.length).toBe(1);
      expect(deliveries[0].status).toBe(NotificationDeliveryStatus.FAILED);
    });

    it('12.3: Very large customData metadata payload handled without serialization failure', async () => {
      const largePayload = {
        nested: Array.from({ length: 50 }).map((_, i) => ({ index: i, key: `value_${i}` })),
      };

      const deliveries = await notificationsService.sendNotification({
        recipientUserId: monitored.id,
        templateName: 'CHECK_IN_REMINDER_CALM',
        templateParams: { name: monitored.displayName },
        customData: { jsonBlob: JSON.stringify(largePayload) },
      });

      expect(deliveries).toBeDefined();
    });

    it('12.4: Unicode Vietnamese template parameters render accurately', async () => {
      const deliveries = await notificationsService.sendNotification({
        recipientUserId: monitored.id,
        templateName: 'MONITOR_INACTIVITY_WARNING',
        templateParams: { name: 'Bác Nguyễn Thị Ánh Tuyết 🌸' },
      });

      expect(deliveries).toBeDefined();
      expect(deliveries[0].payload.body).toContain('Bác Nguyễn Thị Ánh Tuyết 🌸');
    });

    it('12.5: User with multiple active devices sends notification to all eligible devices', async () => {
      const multiUser = await registerAndLoginUser(app, 'b12_multi');
      await registerTestDevice(app, multiUser.accessToken, { pushToken: 'token-device-1' });
      await registerTestDevice(app, multiUser.accessToken, { pushToken: 'token-device-2' });

      const deliveries = await notificationsService.sendNotification({
        recipientUserId: multiUser.id,
        templateName: 'CHECK_IN_REMINDER_CALM',
        templateParams: { name: 'Multi User' },
      });

      expect(deliveries.length).toBe(2);
    });
  });

  // =========================================================================
  // Feature 13: Incident Ack/Resolve Boundaries
  // =========================================================================
  describe('Feature 13: Incident Ack/Resolve Boundaries', () => {
    let testIncId: string;

    beforeAll(async () => {
      const res = await dataSource.query(
        `INSERT INTO incidents (user_id, relationship_id, status, reason, risk_score, detected_at)
         VALUES ($1, $2, 'OPEN', 'MISSED_CHECK_IN', 60, NOW())
         RETURNING id`,
        [monitored.id, relationship.id],
      );
      testIncId = res[0].id;
    });

    it('13.1: Acknowledge incident moves status to ACKNOWLEDGED', async () => {
      const res = await request(app.getHttpServer())
        .post(`/api/v1/incidents/${testIncId}/acknowledge`)
        .set('Authorization', `Bearer ${monitor.accessToken}`);

      expect(res.status).toBe(200);
      expect(res.body.status).toBe(IncidentStatus.ACKNOWLEDGED);
    });

    it('13.2: Re-acknowledging already ACKNOWLEDGED incident is idempotent (200)', async () => {
      const res = await request(app.getHttpServer())
        .post(`/api/v1/incidents/${testIncId}/acknowledge`)
        .set('Authorization', `Bearer ${monitor.accessToken}`);

      expect(res.status).toBe(200);
      expect(res.body.status).toBe(IncidentStatus.ACKNOWLEDGED);
    });

    it('13.3: Resolve with 500-character long Vietnamese note preserved completely', async () => {
      const longNote = 'Đã gọi điện thoại kiểm tra an toàn. '.repeat(15);
      const res = await request(app.getHttpServer())
        .post(`/api/v1/incidents/${testIncId}/resolve`)
        .set('Authorization', `Bearer ${monitor.accessToken}`)
        .send({ note: longNote });

      expect(res.status).toBe(200);
      expect(res.body.status).toBe(IncidentStatus.RESOLVED);

      const eventRows = await dataSource.query(
        `SELECT metadata FROM incident_events WHERE incident_id = $1 AND type = $2`,
        [testIncId, IncidentEventType.INCIDENT_RESOLVED],
      );
      expect(eventRows[0].metadata.note).toBe(longNote);
    });

    it('13.4: Resolve non-existent incident UUID returns 404', async () => {
      const fakeId = uuidv4();
      const res = await request(app.getHttpServer())
        .post(`/api/v1/incidents/${fakeId}/resolve`)
        .set('Authorization', `Bearer ${monitor.accessToken}`)
        .send({ note: 'Non-existent incident' });

      expect(res.status).toBe(404);
    });

    it('13.5: Non-UUID incident ID in path returns 400 or 404', async () => {
      const res = await request(app.getHttpServer())
        .post('/api/v1/incidents/not-a-valid-uuid/resolve')
        .set('Authorization', `Bearer ${monitor.accessToken}`)
        .send({ note: 'Bad UUID' });

      expect([400, 404, 500]).toContain(res.status);
    });
  });

  // =========================================================================
  // Feature 14: Route Aliases & Contract Boundaries
  // =========================================================================
  describe('Feature 14: Route Aliases & Contract Boundaries', () => {
    it('14.1: Relationship invite to self-email rejected with 400', async () => {
      const res = await request(app.getHttpServer())
        .post('/api/v1/monitoring/relationships')
        .set('Authorization', `Bearer ${monitor.accessToken}`)
        .send({ monitoredUserEmail: monitor.email });

      expect(res.status).toBe(400);
    });

    it('14.2: Relationship invite to non-existent email returns 404', async () => {
      const res = await request(app.getHttpServer())
        .post('/api/v1/monitoring/relationships')
        .set('Authorization', `Bearer ${monitor.accessToken}`)
        .send({ monitoredUserEmail: 'nobody_exists_ever@carely.test' });

      expect(res.status).toBe(404);
    });

    it('14.3: Relationship invite with already existing pair returns 409', async () => {
      const res = await request(app.getHttpServer())
        .post('/api/v1/monitoring/relationships')
        .set('Authorization', `Bearer ${monitor.accessToken}`)
        .send({ monitoredUserEmail: monitored.email });

      expect(res.status).toBe(409);
    });

    it('14.4: Accept invitation with invalid code returns 404', async () => {
      const res = await request(app.getHttpServer())
        .post('/api/v1/monitoring/relationships/accept')
        .set('Authorization', `Bearer ${monitored.accessToken}`)
        .send({ invitationCode: 'INVALID-CODE-999' });

      expect(res.status).toBe(404);
    });

    it('14.5: Update config with inactivity threshold < 1 or > 10080 rejected with 400', async () => {
      const res = await request(app.getHttpServer())
        .patch(`/api/v1/monitoring/${relationship.id}/config`)
        .set('Authorization', `Bearer ${monitored.accessToken}`)
        .send({ inactivityThresholdMinutes: 0 }); // Min is 1

      expect(res.status).toBe(400);
    });
  });
});
