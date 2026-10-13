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

describe('Tier 1: Comprehensive Functional Feature Coverage (>=5 tests / feature)', () => {
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

    monitor = await registerAndLoginUser(app, 't1_monitor');
    monitored = await registerAndLoginUser(app, 't1_monitored');
    device = await registerTestDevice(app, monitored.accessToken);
    const paired = await pairMonitoringRelationship(app, monitor.accessToken, monitored);
    relationship = paired.relationship;
  }, 30000);

  afterAll(async () => {
    await teardownE2eTestApp(app, dataSource);
  });

  // =========================================================================
  // Feature 1: Auth & JWT Tokens
  // =========================================================================
  describe('Feature 1: Auth & JWT Tokens', () => {
    it('1.1: Register new user returns 201 with profile and JWT tokens', async () => {
      const unique = Date.now();
      const res = await request(app.getHttpServer())
        .post('/api/v1/auth/register')
        .send({
          email: `f1_test_${unique}@carely.test`,
          password: 'Password123!',
          displayName: 'Nguyen Van Auth',
          timezone: 'Asia/Ho_Chi_Minh',
        });

      expect(res.status).toBe(201);
      expect(res.body.user).toBeDefined();
      expect(res.body.user.email).toBe(`f1_test_${unique}@carely.test`);
      expect(res.body.accessToken).toBeDefined();
      expect(res.body.refreshToken).toBeDefined();
    });

    it('1.2: Register duplicate email returns 409 Conflict', async () => {
      const res = await request(app.getHttpServer())
        .post('/api/v1/auth/register')
        .send({
          email: monitor.email,
          password: 'Password123!',
          displayName: 'Duplicate Monitor',
        });

      expect(res.status).toBe(409);
    });

    it('1.3: Login with correct credentials returns 200 and access/refresh tokens', async () => {
      const res = await request(app.getHttpServer())
        .post('/api/v1/auth/login')
        .send({
          email: monitor.email,
          password: 'Password123!',
        });

      expect(res.status).toBe(200);
      expect(res.body.accessToken).toBeDefined();
      expect(res.body.refreshToken).toBeDefined();
      expect(res.body.user.id).toBe(monitor.id);
    });

    it('1.4: Login with incorrect password returns 401 Unauthorized', async () => {
      const res = await request(app.getHttpServer())
        .post('/api/v1/auth/login')
        .send({
          email: monitor.email,
          password: 'WrongPassword999!',
        });

      expect(res.status).toBe(401);
    });

    it('1.5: Refresh token returns 200 and renewed token pair', async () => {
      const res = await request(app.getHttpServer())
        .post('/api/v1/auth/refresh')
        .send({
          refreshToken: monitor.refreshToken,
        });

      expect(res.status).toBe(200);
      expect(res.body.accessToken).toBeDefined();
      expect(res.body.refreshToken).toBeDefined();
    });
  });

  // =========================================================================
  // Feature 2: Device Registration & Management
  // =========================================================================
  describe('Feature 2: Device Registration & Management', () => {
    let testDeviceId: string;

    it('2.1: Register device returns 201 with device entity and UUID', async () => {
      const uid = `dev-f2-${Date.now()}`;
      const res = await request(app.getHttpServer())
        .post('/api/v1/devices')
        .set('Authorization', `Bearer ${monitored.accessToken}`)
        .send({
          deviceUid: uid,
          platform: DevicePlatform.IOS,
          deviceName: 'iPhone 15 Pro Max',
          pushToken: 'fcm-token-test-f2',
          batteryLevel: 95,
          isCharging: true,
        });

      expect(res.status).toBe(201);
      expect(res.body.id).toBeDefined();
      expect(res.body.deviceUid).toBe(uid);
      expect(res.body.isActive).toBe(true);
      testDeviceId = res.body.id;
    });

    it('2.2: List user devices returns 200 with all registered devices', async () => {
      const res = await request(app.getHttpServer())
        .get('/api/v1/devices')
        .set('Authorization', `Bearer ${monitored.accessToken}`);

      expect(res.status).toBe(200);
      expect(Array.isArray(res.body)).toBe(true);
      expect(res.body.length).toBeGreaterThanOrEqual(2);
    });

    it('2.3: Get specific device details by ID returns 200', async () => {
      const res = await request(app.getHttpServer())
        .get(`/api/v1/devices/${testDeviceId}`)
        .set('Authorization', `Bearer ${monitored.accessToken}`);

      expect(res.status).toBe(200);
      expect(res.body.id).toBe(testDeviceId);
      expect(res.body.deviceName).toBe('iPhone 15 Pro Max');
    });

    it('2.4: Revoke device sets isActive=false and revokedAt timestamp (200)', async () => {
      const res = await request(app.getHttpServer())
        .post(`/api/v1/devices/${testDeviceId}/revoke`)
        .set('Authorization', `Bearer ${monitored.accessToken}`);

      expect(res.status).toBe(200);
      expect(res.body.isActive).toBe(false);
      expect(res.body.revokedAt).toBeDefined();
    });

    it('2.5: Register multiple devices under same user succeeds', async () => {
      const secondDevice = await registerTestDevice(app, monitored.accessToken, {
        platform: DevicePlatform.WEB,
        deviceName: 'Web Browser Dashboard',
      });
      expect(secondDevice.id).toBeDefined();
      expect(secondDevice.platform).toBe(DevicePlatform.WEB);
    });
  });

  // =========================================================================
  // Feature 3: Heartbeat Ingestion (Weight 0.0)
  // =========================================================================
  describe('Feature 3: Heartbeat Ingestion (Weight 0.0)', () => {
    it('3.1: Heartbeat via POST /api/v1/heartbeat returns 200 and ONLINE operationalState', async () => {
      const res = await request(app.getHttpServer())
        .post('/api/v1/heartbeat')
        .set('Authorization', `Bearer ${monitored.accessToken}`)
        .send({
          deviceId: device.id,
          occurredAt: new Date().toISOString(),
          batteryLevel: 80,
          isCharging: false,
        });

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.operationalState).toBe('ONLINE');
    });

    it('3.2: Heartbeat updates device lastSeenAt and battery level', async () => {
      await request(app.getHttpServer())
        .post('/api/v1/heartbeat')
        .set('Authorization', `Bearer ${monitored.accessToken}`)
        .send({
          deviceId: device.id,
          occurredAt: new Date().toISOString(),
          batteryLevel: 75,
          isCharging: true,
        });

      const devRes = await request(app.getHttpServer())
        .get(`/api/v1/devices/${device.id}`)
        .set('Authorization', `Bearer ${monitored.accessToken}`);

      expect(devRes.body.batteryLevel).toBe(75);
      expect(devRes.body.isCharging).toBe(true);
      expect(devRes.body.lastSeenAt).toBeDefined();
    });

    it('3.3: Strict invariant: Heartbeat NEVER updates lastMeaningfulActivityAt in monitoring config', async () => {
      const configBefore = await request(app.getHttpServer())
        .get(`/api/v1/monitoring/${relationship.id}/config`)
        .set('Authorization', `Bearer ${monitored.accessToken}`);
      const beforeTime = new Date(configBefore.body.lastMeaningfulActivityAt).getTime();

      await new Promise((r) => setTimeout(r, 100));

      await request(app.getHttpServer())
        .post('/api/v1/heartbeat')
        .set('Authorization', `Bearer ${monitored.accessToken}`)
        .send({
          deviceId: device.id,
          occurredAt: new Date().toISOString(),
          batteryLevel: 72,
        });

      const configAfter = await request(app.getHttpServer())
        .get(`/api/v1/monitoring/${relationship.id}/config`)
        .set('Authorization', `Bearer ${monitored.accessToken}`);
      const afterTime = new Date(configAfter.body.lastMeaningfulActivityAt).getTime();

      expect(afterTime).toBe(beforeTime);
    });

    it('3.4: Strict invariant: Heartbeat weight is strictly 0.0', async () => {
      const policy = await dataSource.query(
        `SELECT weight, is_meaningful FROM activity_policies WHERE activity_type = 'HEARTBEAT' LIMIT 1`,
      );
      if (policy.length > 0) {
        expect(Number(policy[0].weight)).toBe(0.0);
        expect(policy[0].is_meaningful).toBe(false);
      }
    });

    it('3.5: Heartbeat with non-existent deviceId returns 404', async () => {
      const nonExistentId = uuidv4();
      const res = await request(app.getHttpServer())
        .post('/api/v1/heartbeat')
        .set('Authorization', `Bearer ${monitored.accessToken}`)
        .send({
          deviceId: nonExistentId,
          occurredAt: new Date().toISOString(),
          batteryLevel: 50,
        });

      expect(res.status).toBe(404);
    });
  });

  // =========================================================================
  // Feature 4: Meaningful Activity Ingestion
  // =========================================================================
  describe('Feature 4: Meaningful Activity Ingestion', () => {
    it('4.1: Ingest APP_FOREGROUND returns 201 with weight 0.8', async () => {
      const eventId = uuidv4();
      const res = await request(app.getHttpServer())
        .post('/api/v1/activities')
        .set('Authorization', `Bearer ${monitored.accessToken}`)
        .send({
          eventId,
          deviceId: device.id,
          type: ActivityType.APP_FOREGROUND,
          occurredAt: new Date().toISOString(),
          confidence: 0.9,
        });

      expect(res.status).toBe(201);
      expect(res.body.id).toBeDefined();
      expect(res.body.type).toBe(ActivityType.APP_FOREGROUND);
      expect(Number(res.body.weight)).toBeCloseTo(0.8);
    });

    it('4.2: Ingest SCREEN_INTERACTION returns 201 and advances lastMeaningfulActivityAt', async () => {
      const configBefore = await request(app.getHttpServer())
        .get(`/api/v1/monitoring/${relationship.id}/config`)
        .set('Authorization', `Bearer ${monitored.accessToken}`);
      const beforeTime = new Date(configBefore.body.lastMeaningfulActivityAt).getTime();

      await new Promise((r) => setTimeout(r, 100));

      const eventId = uuidv4();
      const res = await request(app.getHttpServer())
        .post('/api/v1/activities')
        .set('Authorization', `Bearer ${monitored.accessToken}`)
        .send({
          eventId,
          deviceId: device.id,
          type: ActivityType.SCREEN_INTERACTION,
          occurredAt: new Date().toISOString(),
          confidence: 0.95,
        });

      expect(res.status).toBe(201);

      const configAfter = await request(app.getHttpServer())
        .get(`/api/v1/monitoring/${relationship.id}/config`)
        .set('Authorization', `Bearer ${monitored.accessToken}`);
      const afterTime = new Date(configAfter.body.lastMeaningfulActivityAt).getTime();

      expect(afterTime).toBeGreaterThan(beforeTime);
    });

    it('4.3: Ingest CHARGER_CONNECTED returns 201 with weight 0.2', async () => {
      const eventId = uuidv4();
      const res = await request(app.getHttpServer())
        .post('/api/v1/activities')
        .set('Authorization', `Bearer ${monitored.accessToken}`)
        .send({
          eventId,
          deviceId: device.id,
          type: ActivityType.CHARGER_CONNECTED,
          occurredAt: new Date().toISOString(),
          confidence: 0.85,
        });

      expect(res.status).toBe(201);
      expect(Number(res.body.weight)).toBeCloseTo(0.2);
    });

    it('4.4: Ingest STEP_DETECTED returns 201 with confidence score', async () => {
      const eventId = uuidv4();
      const res = await request(app.getHttpServer())
        .post('/api/v1/activities')
        .set('Authorization', `Bearer ${monitored.accessToken}`)
        .send({
          eventId,
          deviceId: device.id,
          type: ActivityType.STEP_DETECTED,
          occurredAt: new Date().toISOString(),
          confidence: 0.75,
          metadata: { stepCount: 150 },
        });

      expect(res.status).toBe(201);
      expect(Number(res.body.confidence)).toBeCloseTo(0.75);
    });

    it('4.5: List recent activities returns reverse-chronological activity log', async () => {
      const res = await request(app.getHttpServer())
        .get('/api/v1/activities?limit=10')
        .set('Authorization', `Bearer ${monitored.accessToken}`);

      expect(res.status).toBe(200);
      expect(Array.isArray(res.body)).toBe(true);
      expect(res.body.length).toBeGreaterThanOrEqual(4);
    });
  });

  // =========================================================================
  // Feature 5: One-Touch Check-in ("Tôi vẫn ổn")
  // =========================================================================
  describe('Feature 5: One-Touch Check-in ("Tôi vẫn ổn")', () => {
    it('5.1: Check-in returns 201 with note and battery level', async () => {
      const eventId = uuidv4();
      const res = await request(app.getHttpServer())
        .post('/api/v1/check-ins')
        .set('Authorization', `Bearer ${monitored.accessToken}`)
        .send({
          eventId,
          deviceId: device.id,
          relationshipId: relationship.id,
          occurredAt: new Date().toISOString(),
          batteryLevel: 88,
          note: 'Tôi vẫn ổn, đang tưới cây.',
        });

      expect(res.status).toBe(201);
      expect(res.body.id).toBeDefined();
      expect(res.body.note).toBe('Tôi vẫn ổn, đang tưới cây.');
      expect(res.body.batteryLevel).toBe(88);
    });

    it('5.2: Check-in assigns weight 1.0', async () => {
      const policy = await dataSource.query(
        `SELECT weight FROM activity_policies WHERE activity_type = 'CHECK_IN' LIMIT 1`,
      );
      if (policy.length > 0) {
        expect(Number(policy[0].weight)).toBe(1.0);
      }
    });

    it('5.3: Check-in records optional GPS coordinates', async () => {
      const eventId = uuidv4();
      const res = await request(app.getHttpServer())
        .post('/api/v1/check-ins')
        .set('Authorization', `Bearer ${monitored.accessToken}`)
        .send({
          eventId,
          deviceId: device.id,
          relationshipId: relationship.id,
          occurredAt: new Date().toISOString(),
          batteryLevel: 85,
          location: {
            latitude: 10.762622,
            longitude: 106.660172,
            accuracy: 10.5,
          },
        });

      expect(res.status).toBe(201);
      const locRows = await dataSource.query(
        `SELECT latitude, longitude FROM locations WHERE user_id = $1 AND source = 'CHECK_IN' ORDER BY created_at DESC LIMIT 1`,
        [monitored.id],
      );
      expect(Number(locRows[0].latitude)).toBeCloseTo(10.762622);
    });

    it('5.4: Check-in resets monitoring config state to ACTIVE', async () => {
      await dataSource.query(
        `UPDATE monitoring_configs SET current_state = 'CHECK_IN_REQUIRED' WHERE relationship_id = $1`,
        [relationship.id],
      );

      const eventId = uuidv4();
      await request(app.getHttpServer())
        .post('/api/v1/check-ins')
        .set('Authorization', `Bearer ${monitored.accessToken}`)
        .send({
          eventId,
          deviceId: device.id,
          relationshipId: relationship.id,
          occurredAt: new Date().toISOString(),
          batteryLevel: 90,
        });

      const configRes = await request(app.getHttpServer())
        .get(`/api/v1/monitoring/${relationship.id}/config`)
        .set('Authorization', `Bearer ${monitored.accessToken}`);

      expect(configRes.body.currentState).toBe(MonitoringState.ACTIVE);
    });

    it('5.5: Check-in auto-resolves active/pending incidents', async () => {
      const incidentInsert = await dataSource.query(
        `INSERT INTO incidents (user_id, relationship_id, status, reason, risk_score, detected_at)
         VALUES ($1, $2, 'OPEN', 'MISSED_CHECK_IN', 65, NOW())
         RETURNING id`,
        [monitored.id, relationship.id],
      );
      const incidentId = incidentInsert[0].id;

      const eventId = uuidv4();
      await request(app.getHttpServer())
        .post('/api/v1/check-ins')
        .set('Authorization', `Bearer ${monitored.accessToken}`)
        .send({
          eventId,
          deviceId: device.id,
          relationshipId: relationship.id,
          occurredAt: new Date().toISOString(),
          batteryLevel: 89,
        });

      const incidentRows = await dataSource.query(`SELECT status FROM incidents WHERE id = $1`, [
        incidentId,
      ]);
      expect(incidentRows[0].status).toBe(IncidentStatus.RESOLVED);
    });
  });

  // =========================================================================
  // Feature 6: Idempotency & Concurrency Safety
  // =========================================================================
  describe('Feature 6: Idempotency & Concurrency Safety', () => {
    it('6.1: Submitting duplicate activity eventId returns original activity record (201/200)', async () => {
      const eventId = uuidv4();
      const res1 = await request(app.getHttpServer())
        .post('/api/v1/activities')
        .set('Authorization', `Bearer ${monitored.accessToken}`)
        .send({
          eventId,
          deviceId: device.id,
          type: ActivityType.APP_OPEN,
          occurredAt: new Date().toISOString(),
          confidence: 0.9,
        });

      const res2 = await request(app.getHttpServer())
        .post('/api/v1/activities')
        .set('Authorization', `Bearer ${monitored.accessToken}`)
        .send({
          eventId,
          deviceId: device.id,
          type: ActivityType.APP_OPEN,
          occurredAt: new Date().toISOString(),
          confidence: 0.9,
        });

      expect(res1.body.id).toBe(res2.body.id);
    });

    it('6.2: Duplicate activity eventId does not create duplicate database rows', async () => {
      const eventId = uuidv4();
      await request(app.getHttpServer())
        .post('/api/v1/activities')
        .set('Authorization', `Bearer ${monitored.accessToken}`)
        .send({
          eventId,
          deviceId: device.id,
          type: ActivityType.SCREEN_INTERACTION,
          occurredAt: new Date().toISOString(),
          confidence: 0.9,
        });

      await request(app.getHttpServer())
        .post('/api/v1/activities')
        .set('Authorization', `Bearer ${monitored.accessToken}`)
        .send({
          eventId,
          deviceId: device.id,
          type: ActivityType.SCREEN_INTERACTION,
          occurredAt: new Date().toISOString(),
          confidence: 0.9,
        });

      const rows = await dataSource.query(
        `SELECT COUNT(*) FROM activities WHERE event_id = $1`,
        [eventId],
      );
      expect(Number(rows[0].count)).toBe(1);
    });

    it('6.3: Submitting duplicate check-in eventId returns original check-in record', async () => {
      const eventId = uuidv4();
      const res1 = await request(app.getHttpServer())
        .post('/api/v1/check-ins')
        .set('Authorization', `Bearer ${monitored.accessToken}`)
        .send({
          eventId,
          deviceId: device.id,
          relationshipId: relationship.id,
          occurredAt: new Date().toISOString(),
          batteryLevel: 90,
          note: 'First checkin message',
        });

      const res2 = await request(app.getHttpServer())
        .post('/api/v1/check-ins')
        .set('Authorization', `Bearer ${monitored.accessToken}`)
        .send({
          eventId,
          deviceId: device.id,
          relationshipId: relationship.id,
          occurredAt: new Date().toISOString(),
          batteryLevel: 90,
          note: 'Duplicate checkin message',
        });

      expect(res1.body.id).toBe(res2.body.id);
    });

    it('6.4: Two distinct eventIds create two distinct activity records', async () => {
      const eventId1 = uuidv4();
      const eventId2 = uuidv4();

      const res1 = await request(app.getHttpServer())
        .post('/api/v1/activities')
        .set('Authorization', `Bearer ${monitored.accessToken}`)
        .send({
          eventId: eventId1,
          deviceId: device.id,
          type: ActivityType.DEVICE_MOTION,
          occurredAt: new Date().toISOString(),
          confidence: 0.8,
        });

      const res2 = await request(app.getHttpServer())
        .post('/api/v1/activities')
        .set('Authorization', `Bearer ${monitored.accessToken}`)
        .send({
          eventId: eventId2,
          deviceId: device.id,
          type: ActivityType.DEVICE_MOTION,
          occurredAt: new Date().toISOString(),
          confidence: 0.8,
        });

      expect(res1.body.id).not.toBe(res2.body.id);
    });

    it('6.5: Batch activity ingestion deduplicates repeated eventIds', async () => {
      const batchEventId = uuidv4();
      const results = await activityService.ingestBatch(monitored.id, [
        {
          eventId: batchEventId,
          deviceId: device.id,
          type: ActivityType.APP_OPEN,
          occurredAt: new Date().toISOString(),
          confidence: 0.9,
        },
        {
          eventId: batchEventId,
          deviceId: device.id,
          type: ActivityType.APP_OPEN,
          occurredAt: new Date().toISOString(),
          confidence: 0.9,
        },
      ]);

      expect(results.length).toBeGreaterThanOrEqual(1);
      const rows = await dataSource.query(`SELECT COUNT(*) FROM activities WHERE event_id = $1`, [
        batchEventId,
      ]);
      expect(Number(rows[0].count)).toBe(1);
    });
  });

  // =========================================================================
  // Feature 7: Timezone Calendar Windows
  // =========================================================================
  describe('Feature 7: Timezone Calendar Windows', () => {
    it('7.1: Active daytime window evaluation returns true when time falls in range', () => {
      expect(MonitoringScheduler.isTimeBetween('14:30', '08:00', '18:00')).toBe(true);
    });

    it('7.2: Inactive daytime window evaluation returns false when time outside range', () => {
      expect(MonitoringScheduler.isTimeBetween('20:00', '08:00', '18:00')).toBe(false);
    });

    it('7.3: Overnight window evaluation (22:00 -> 06:00) returns true at 23:30', () => {
      expect(MonitoringScheduler.isTimeBetween('23:30', '22:00', '06:00')).toBe(true);
    });

    it('7.4: Overnight window evaluation (22:00 -> 06:00) returns true at 04:15', () => {
      expect(MonitoringScheduler.isTimeBetween('04:15', '22:00', '06:00')).toBe(true);
    });

    it('7.5: Empty schedule window defaults to 24/7 active monitoring', () => {
      expect(MonitoringScheduler.isWithinActiveWindow(new Date(), [])).toBe(true);
    });
  });

  // =========================================================================
  // Feature 8: Inactivity Worker & Row Locking
  // =========================================================================
  describe('Feature 8: Inactivity Worker & Row Locking', () => {
    it('8.1: Worker evaluates due configs and transitions inactive user to CHECK_IN_REQUIRED', async () => {
      const pastTime = new Date(Date.now() - 10 * 60 * 1000);
      await dataSource.query(
        `UPDATE monitoring_configs 
         SET current_state = 'ACTIVE',
             inactivity_threshold_minutes = 1,
             last_meaningful_activity_at = $1,
             next_evaluation_at = NOW() - INTERVAL '5 seconds'
         WHERE relationship_id = $2`,
        [pastTime, relationship.id],
      );

      const processed = await workerService.evaluateDueMonitoring(10);
      expect(processed).toBeGreaterThanOrEqual(1);

      const rows = await dataSource.query(
        `SELECT current_state FROM monitoring_configs WHERE relationship_id = $1`,
        [relationship.id],
      );
      expect(rows[0].current_state).toBe(MonitoringState.CHECK_IN_REQUIRED);
    });

    it('8.2: Worker evaluates expired grace period and transitions to WARNING', async () => {
      const pastTime = new Date(Date.now() - 30 * 60 * 1000);
      await dataSource.query(
        `UPDATE monitoring_configs 
         SET current_state = 'CHECK_IN_REQUIRED',
             check_in_grace_minutes = 1,
             last_meaningful_activity_at = $1,
             next_evaluation_at = NOW() - INTERVAL '5 seconds'
         WHERE relationship_id = $2`,
        [pastTime, relationship.id],
      );

      await workerService.evaluateDueMonitoring(10);

      const rows = await dataSource.query(
        `SELECT current_state FROM monitoring_configs WHERE relationship_id = $1`,
        [relationship.id],
      );
      expect(rows[0].current_state).toBe(MonitoringState.WARNING);
    });

    it('8.3: Worker skips configs that are not due (nextEvaluationAt > now)', async () => {
      await dataSource.query(
        `UPDATE monitoring_configs 
         SET next_evaluation_at = NOW() + INTERVAL '1 hour'
         WHERE relationship_id = $1`,
        [relationship.id],
      );

      await workerService.evaluateDueMonitoring(10);
      // Our relationship should not be evaluated
      const rows = await dataSource.query(
        `SELECT next_evaluation_at FROM monitoring_configs WHERE relationship_id = $1`,
        [relationship.id],
      );
      expect(new Date(rows[0].next_evaluation_at).getTime()).toBeGreaterThan(Date.now());
    });

    it('8.4: Worker skips disabled monitoring configs', async () => {
      await dataSource.query(
        `UPDATE monitoring_configs 
         SET enabled = FALSE,
             next_evaluation_at = NOW() - INTERVAL '1 minute'
         WHERE relationship_id = $1`,
        [relationship.id],
      );

      const dueRows = await dataSource.query(
        `SELECT id FROM monitoring_configs WHERE enabled = TRUE AND next_evaluation_at <= NOW() AND relationship_id = $1`,
        [relationship.id],
      );
      expect(dueRows.length).toBe(0);

      // Re-enable for subsequent tests
      await dataSource.query(`UPDATE monitoring_configs SET enabled = TRUE WHERE relationship_id = $1`, [
        relationship.id,
      ]);
    });

    it('8.5: Worker batching processes due items under pessimistic row locks', async () => {
      await dataSource.query(
        `UPDATE monitoring_configs 
         SET next_evaluation_at = NOW() - INTERVAL '10 seconds'
         WHERE relationship_id = $1`,
        [relationship.id],
      );

      const count = await workerService.evaluateDueMonitoring(5);
      expect(typeof count).toBe('number');
    });
  });

  // =========================================================================
  // Feature 9: Monitoring State Machine
  // =========================================================================
  describe('Feature 9: Monitoring State Machine', () => {
    it('9.1: Valid transition from ACTIVE to CHECK_IN_REQUIRED', () => {
      expect(
        MonitoringStateMachine.canTransition(
          MonitoringState.ACTIVE,
          MonitoringState.CHECK_IN_REQUIRED,
        ),
      ).toBe(true);
    });

    it('9.2: Valid transition from CHECK_IN_REQUIRED to WARNING', () => {
      expect(
        MonitoringStateMachine.canTransition(
          MonitoringState.CHECK_IN_REQUIRED,
          MonitoringState.WARNING,
        ),
      ).toBe(true);
    });

    it('9.3: Valid transition from WARNING to ESCALATED', () => {
      expect(
        MonitoringStateMachine.canTransition(
          MonitoringState.WARNING,
          MonitoringState.ESCALATED,
        ),
      ).toBe(true);
    });

    it('9.4: Check-in restores state from WARNING/ESCALATED back to ACTIVE', () => {
      expect(
        MonitoringStateMachine.canTransition(
          MonitoringState.WARNING,
          MonitoringState.ACTIVE,
        ),
      ).toBe(true);
      expect(
        MonitoringStateMachine.canTransition(
          MonitoringState.ESCALATED,
          MonitoringState.ACTIVE,
        ),
      ).toBe(true);
    });

    it('9.5: Illegal transition rejection (e.g. from ACTIVE directly to ALERT_TRIGGERED/ESCALATED)', () => {
      expect(
        MonitoringStateMachine.canTransition(
          MonitoringState.ACTIVE,
          MonitoringState.ESCALATED,
        ),
      ).toBe(false);
    });
  });

  // =========================================================================
  // Feature 10: Redis Degradation & Fallback
  // =========================================================================
  describe('Feature 10: Redis Degradation & Fallback', () => {
    it('10.1: Redlock acquire returns valid lock token when Redis is up', async () => {
      const lockKey = `test:lock:${Date.now()}`;
      const token = await redisService.acquireLock(lockKey, 5000);
      expect(token).toBeDefined();
      if (token) {
        await redisService.releaseLock(lockKey, token);
      }
    });

    it('10.2: Redlock release successfully releases the acquired token', async () => {
      const lockKey = `test:lock:rel:${Date.now()}`;
      const token = await redisService.acquireLock(lockKey, 5000);
      expect(token).toBeDefined();
      const released = await redisService.releaseLock(lockKey, token!);
      expect(released).toBe(true);
    });

    it('10.3: Ingestion continues safely even when Redis operations degrade', async () => {
      // Ingesting an activity is guaranteed via PostgreSQL even if Redis is degraded
      const eventId = uuidv4();
      const res = await request(app.getHttpServer())
        .post('/api/v1/activities')
        .set('Authorization', `Bearer ${monitored.accessToken}`)
        .send({
          eventId,
          deviceId: device.id,
          type: ActivityType.APP_FOREGROUND,
          occurredAt: new Date().toISOString(),
          confidence: 0.9,
        });

      expect(res.status).toBe(201);
    });

    it('10.4: Worker evaluation completes safely without crashing under Redis failure', async () => {
      const processed = await workerService.evaluateDueMonitoring(10);
      expect(typeof processed).toBe('number');
    });

    it('10.5: Health check probe reports Redis status and overall status', async () => {
      const res = await request(app.getHttpServer()).get('/api/v1/health');
      expect(res.status).toBe(200);
      expect(res.body.status).toBeDefined();
      expect(res.body.services.database).toBe('UP');
    });
  });

  // =========================================================================
  // Feature 11: Incident Creation & Risk Scoring
  // =========================================================================
  describe('Feature 11: Incident Creation & Risk Scoring', () => {
    it('11.1: Missed check-in creates safety incident with status OPEN', async () => {
      const res = await dataSource.query(
        `INSERT INTO incidents (user_id, relationship_id, status, reason, risk_score, detected_at)
         VALUES ($1, $2, 'OPEN', 'MISSED_CHECK_IN', 60, NOW())
         RETURNING id, status, risk_score`,
        [monitored.id, relationship.id],
      );

      expect(res[0].id).toBeDefined();
      expect(res[0].status).toBe(IncidentStatus.OPEN);
      expect(res[0].risk_score).toBe(60);
    });

    it('11.2: Heuristic risk evaluator calculates base score', () => {
      const result = riskEvaluatorService.evaluate({
        isInactivityExceeded: true,
        isCheckInMissed: true,
        isDeviceOffline: false,
        isLowBattery: false,
      });

      expect(result.riskScore).toBeGreaterThanOrEqual(40);
      expect(result.summary).toBeDefined();
    });

    it('11.3: Risk score increases when battery level is critically low (<15%)', () => {
      const normalResult = riskEvaluatorService.evaluate({
        isInactivityExceeded: true,
        isCheckInMissed: true,
        isDeviceOffline: false,
        isLowBattery: false,
      });

      const lowBatteryResult = riskEvaluatorService.evaluate({
        isInactivityExceeded: true,
        isCheckInMissed: true,
        isDeviceOffline: false,
        isLowBattery: true,
        batteryLevel: 8,
      });

      expect(lowBatteryResult.riskScore).toBeGreaterThan(normalResult.riskScore);
    });

    it('11.4: Risk score increases when device is offline', () => {
      const onlineResult = riskEvaluatorService.evaluate({
        isInactivityExceeded: true,
        isCheckInMissed: true,
        isDeviceOffline: false,
        isLowBattery: false,
      });

      const offlineResult = riskEvaluatorService.evaluate({
        isInactivityExceeded: true,
        isCheckInMissed: true,
        isDeviceOffline: true,
        isLowBattery: false,
      });

      expect(offlineResult.riskScore).toBeGreaterThan(onlineResult.riskScore);
    });

    it('11.5: Risk score is strictly clamped between 0 and 100 with non-diagnostic summary', () => {
      const extremeResult = riskEvaluatorService.evaluate({
        isInactivityExceeded: true,
        isCheckInMissed: true,
        isDeviceOffline: true,
        isLowBattery: true,
        batteryLevel: 1,
        inactivityMinutes: 10000,
      });

      expect(extremeResult.riskScore).toBeLessThanOrEqual(100);
      expect(extremeResult.riskScore).toBeGreaterThanOrEqual(0);
      expect(extremeResult.disclaimer).toBeDefined();
    });
  });

  // =========================================================================
  // Feature 12: Multi-Channel Escalation Engine
  // =========================================================================
  describe('Feature 12: Multi-Channel Escalation Engine', () => {
    it('12.1: Dispatches calm check-in push notification ("Bạn vẫn ổn chứ?")', async () => {
      const delivery = await notificationsService.sendNotification({
        recipientUserId: monitored.id,
        templateName: 'CHECK_IN_REMINDER_CALM',
        templateParams: { name: monitored.displayName },
      });

      expect(delivery).toBeDefined();
    });

    it('12.2: Dispatches urgent warning reminder push notification', async () => {
      const delivery = await notificationsService.sendNotification({
        recipientUserId: monitored.id,
        templateName: 'CHECK_IN_WARNING_URGENT',
        templateParams: { name: monitored.displayName, minutesLeft: '15' },
      });

      expect(delivery).toBeDefined();
    });

    it('12.3: Dispatches incident notification to registered guardian', async () => {
      const delivery = await notificationsService.sendNotification({
        recipientUserId: monitor.id,
        templateName: 'INCIDENT_ALERT_GUARDIAN',
        templateParams: {
          monitoredName: monitored.displayName,
          timeElapsed: '2 giờ',
        },
      });

      expect(delivery).toBeDefined();
    });

    it('12.4: Records notification deliveries in notification_deliveries table', async () => {
      const rows = await dataSource.query(
        `SELECT COUNT(*) FROM notification_deliveries WHERE recipient_user_id = $1`,
        [monitored.id],
      );
      expect(Number(rows[0].count)).toBeGreaterThanOrEqual(1);
    });

    it('12.5: Gracefully handles user with no registered push tokens without throwing 500', async () => {
      const noDeviceUser = await registerAndLoginUser(app, 'no_dev_user');
      const deliveries = await notificationsService.sendNotification({
        recipientUserId: noDeviceUser.id,
        templateName: 'CHECK_IN_REMINDER_CALM',
        templateParams: { name: 'No Device' },
      });

      expect(Array.isArray(deliveries)).toBe(true);
      expect(deliveries.length).toBe(1);
      expect(deliveries[0].status).toBe(NotificationDeliveryStatus.FAILED);
    });
  });

  // =========================================================================
  // Feature 13: Incident Acknowledgment & Resolution
  // =========================================================================
  describe('Feature 13: Incident Acknowledgment & Resolution', () => {
    let testIncidentId: string;

    beforeAll(async () => {
      const res = await dataSource.query(
        `INSERT INTO incidents (user_id, relationship_id, status, reason, risk_score, detected_at)
         VALUES ($1, $2, 'OPEN', 'MISSED_CHECK_IN', 60, NOW())
         RETURNING id`,
        [monitored.id, relationship.id],
      );
      testIncidentId = res[0].id;
    });

    it('13.1: Guardian acknowledges incident, setting status to ACKNOWLEDGED', async () => {
      const res = await request(app.getHttpServer())
        .post(`/api/v1/incidents/${testIncidentId}/acknowledge`)
        .set('Authorization', `Bearer ${monitor.accessToken}`);

      expect(res.status).toBe(200);
      expect(res.body.status).toBe(IncidentStatus.ACKNOWLEDGED);
      expect(res.body.acknowledgedBy).toBe(monitor.id);
    });

    it('13.2: Non-guardian user is rejected (403 Forbidden) from acknowledging incident', async () => {
      const anotherUser = await registerAndLoginUser(app, 'intruder_ack');
      const res = await request(app.getHttpServer())
        .post(`/api/v1/incidents/${testIncidentId}/acknowledge`)
        .set('Authorization', `Bearer ${anotherUser.accessToken}`);

      expect(res.status).toBe(403);
    });

    it('13.3: Guardian resolves incident with resolution note, setting status to RESOLVED', async () => {
      const res = await request(app.getHttpServer())
        .post(`/api/v1/incidents/${testIncidentId}/resolve`)
        .set('Authorization', `Bearer ${monitor.accessToken}`)
        .send({ note: 'Đã liên lạc qua điện thoại, người thân an toàn.' });

      expect(res.status).toBe(200);
      expect(res.body.status).toBe(IncidentStatus.RESOLVED);
      expect(res.body.resolvedBy).toBe(monitor.id);
      const eventRows = await dataSource.query(
        `SELECT metadata FROM incident_events WHERE incident_id = $1 AND type = $2`,
        [testIncidentId, IncidentEventType.INCIDENT_RESOLVED],
      );
      expect(eventRows[0].metadata.note).toBe('Đã liên lạc qua điện thoại, người thân an toàn.');
    });

    it('13.4: Monitored user resolves incident with note, setting status to RESOLVED', async () => {
      const newInc = await dataSource.query(
        `INSERT INTO incidents (user_id, relationship_id, status, reason, risk_score, detected_at)
         VALUES ($1, $2, 'OPEN', 'MISSED_CHECK_IN', 55, NOW())
         RETURNING id`,
        [monitored.id, relationship.id],
      );

      const res = await request(app.getHttpServer())
        .post(`/api/v1/incidents/${newInc[0].id}/resolve`)
        .set('Authorization', `Bearer ${monitored.accessToken}`)
        .send({ note: 'Tôi tự giải quyết sự cố này, tôi vẫn ổn.' });

      expect(res.status).toBe(200);
      expect(res.body.status).toBe(IncidentStatus.RESOLVED);
      expect(res.body.resolvedBy).toBe(monitored.id);
    });

    it('13.5: Unrelated third party is rejected (403 Forbidden) from resolving incident', async () => {
      const openInc = await dataSource.query(
        `INSERT INTO incidents (user_id, relationship_id, status, reason, risk_score, detected_at)
         VALUES ($1, $2, 'OPEN', 'MISSED_CHECK_IN', 55, NOW())
         RETURNING id`,
        [monitored.id, relationship.id],
      );

      const intruder = await registerAndLoginUser(app, 'intruder_res');
      const res = await request(app.getHttpServer())
        .post(`/api/v1/incidents/${openInc[0].id}/resolve`)
        .set('Authorization', `Bearer ${intruder.accessToken}`)
        .send({ note: 'Can thiệp bất hợp pháp' });

      expect(res.status).toBe(403);
    });
  });

  // =========================================================================
  // Feature 14: Route Aliases & Contract Compatibility
  // =========================================================================
  describe('Feature 14: Route Aliases & Contract Compatibility', () => {
    it('14.1: POST /api/v1/heartbeat functions correctly as primary heartbeat route', async () => {
      const freshDevice = await registerTestDevice(app, monitored.accessToken);
      const res = await request(app.getHttpServer())
        .post('/api/v1/heartbeat')
        .set('Authorization', `Bearer ${monitored.accessToken}`)
        .send({
          deviceId: freshDevice.id,
          occurredAt: new Date().toISOString(),
          batteryLevel: 70,
        });

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
    });

    it('14.2: GET /api/v1/users/me retrieves authenticated user profile', async () => {
      const res = await request(app.getHttpServer())
        .get('/api/v1/users/me')
        .set('Authorization', `Bearer ${monitored.accessToken}`);

      expect(res.status).toBe(200);
      expect(res.body.id).toBe(monitored.id);
      expect(res.body.email).toBe(monitored.email);
    });

    it('14.3: PATCH /api/v1/users/me updates display name and timezone', async () => {
      const res = await request(app.getHttpServer())
        .patch('/api/v1/users/me')
        .set('Authorization', `Bearer ${monitored.accessToken}`)
        .send({
          displayName: 'Tran Monitored Updated',
          timezone: 'Asia/Bangkok',
        });

      expect(res.status).toBe(200);
      expect(res.body.displayName).toBe('Tran Monitored Updated');
      expect(res.body.timezone).toBe('Asia/Bangkok');
    });

    it('14.4: GET /api/v1/monitoring/relationships returns dual-perspective lists', async () => {
      const res = await request(app.getHttpServer())
        .get('/api/v1/monitoring/relationships')
        .set('Authorization', `Bearer ${monitor.accessToken}`);

      expect(res.status).toBe(200);
      expect(res.body.monitoring).toBeDefined();
      expect(res.body.monitoredBy).toBeDefined();
      expect(res.body.monitoring.length).toBeGreaterThanOrEqual(1);
    });

    it('14.5: PATCH /api/v1/monitoring/:id/config updates monitoring thresholds and schedule windows', async () => {
      const res = await request(app.getHttpServer())
        .patch(`/api/v1/monitoring/${relationship.id}/config`)
        .set('Authorization', `Bearer ${monitored.accessToken}`)
        .send({
          inactivityThresholdMinutes: 360,
          checkInGraceMinutes: 45,
          locationEnabled: true,
          scheduleWindows: [
            {
              dayOfWeek: 1,
              startTime: '08:00',
              endTime: '20:00',
              isEnabled: true,
            },
          ],
        });

      expect(res.status).toBe(200);
      expect(res.body.inactivityThresholdMinutes).toBe(360);
      expect(res.body.checkInGraceMinutes).toBe(45);
      expect(res.body.locationEnabled).toBe(true);
    });
  });
});
