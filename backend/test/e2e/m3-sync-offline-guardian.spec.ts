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
  TestUserContext,
} from './e2e-helper';
import {
  ActivityType,
  DevicePlatform,
  IncidentEventType,
  IncidentStatus,
  MonitoringState,
  RelationshipStatus,
} from '../../src/common/enums';
import { MonitoringWorkerService } from '../../src/modules/workers/monitoring-worker.service';

describe('Milestone 3: End-to-End System Synchronization (Live Sync, Offline Replay & Guardian Resolution)', () => {
  let app: INestApplication;
  let dataSource: DataSource;
  let workerService: MonitoringWorkerService;

  let monitorUser: TestUserContext;
  let monitoredUser: TestUserContext;
  let thirdPartyUser: TestUserContext;
  let monitoredDevice: any;
  let monitorDevice: any;
  let relationship: any;
  let incident1Id: string;
  let incident2Id: string;

  beforeAll(async () => {
    const context = await createE2eTestApp();
    app = context.app;
    dataSource = context.dataSource;
    workerService = context.moduleFixture.get<MonitoringWorkerService>(MonitoringWorkerService);

    await resetDatabase(dataSource);
  }, 30000);

  afterAll(async () => {
    await teardownE2eTestApp(app, dataSource);
  });

  // =========================================================================
  // Scenario 1 (Feature 30): Mobile-Backend Contract Synchronization
  // =========================================================================
  describe('Scenario 1 (Feature 30): Mobile Auth, Hardware Enrollment, Pairing & Ingestion', () => {
    it('1.1 Mobile Auth Registration & Login with Contract Harmonization', async () => {
      const emailMonitored = `monitored_m3_${Date.now()}@carely.test`;
      const password = 'Password123!';

      // 1. Monitored user registers sending Flutter mobile contract payload
      // (includes both displayName and fullName, phoneNumber and phone for cross-version compatibility)
      const regRes = await request(app.getHttpServer())
        .post('/api/v1/auth/register')
        .send({
          email: emailMonitored,
          password,
          displayName: 'Nguyễn Văn An',
          fullName: 'Nguyễn Văn An',
          phoneNumber: '+84901234567',
          phone: '+84901234567',
          timezone: 'Asia/Ho_Chi_Minh',
        });

      expect(regRes.status).toBe(201);
      expect(regRes.body.user).toBeDefined();
      expect(regRes.body.user.email).toBe(emailMonitored);
      expect(regRes.body.user.displayName).toBe('Nguyễn Văn An');
      expect(regRes.body.accessToken).toBeDefined();
      expect(regRes.body.refreshToken).toBeDefined();

      monitoredUser = {
        id: regRes.body.user.id,
        email: emailMonitored,
        displayName: regRes.body.user.displayName,
        accessToken: regRes.body.accessToken,
        refreshToken: regRes.body.refreshToken,
      };

      // 2. Guardian user registers
      monitorUser = await registerAndLoginUser(app, 'guardian_m3');
      expect(monitorUser.id).toBeDefined();

      // 3. Third-party intruder user registers for negative security tests
      thirdPartyUser = await registerAndLoginUser(app, 'intruder_m3');
      expect(thirdPartyUser.id).toBeDefined();

      // 4. Monitored user logs in via /auth/login
      const loginRes = await request(app.getHttpServer())
        .post('/api/v1/auth/login')
        .send({
          email: emailMonitored,
          password,
        });

      expect(loginRes.status).toBe(200);
      expect(loginRes.body.accessToken).toBeDefined();

      // 5. Verify profile retrieval via /auth/me and route alias /users/me
      const meAuthRes = await request(app.getHttpServer())
        .get('/api/v1/auth/me')
        .set('Authorization', `Bearer ${monitoredUser.accessToken}`);
      expect(meAuthRes.status).toBe(200);
      expect(meAuthRes.body.displayName).toBe('Nguyễn Văn An');

      const meUsersRes = await request(app.getHttpServer())
        .get('/api/v1/users/me')
        .set('Authorization', `Bearer ${monitoredUser.accessToken}`);
      expect(meUsersRes.status).toBe(200);
      expect(meUsersRes.body.id).toBe(monitoredUser.id);
    });

    it('1.2 Mobile Hardware Device Registration & Push Token Mapping', async () => {
      // Monitored device registration following mobile contract
      const deviceUid = `android-pixel8-${Date.now()}`;
      const devRes = await request(app.getHttpServer())
        .post('/api/v1/devices')
        .set('Authorization', `Bearer ${monitoredUser.accessToken}`)
        .send({
          deviceUid,
          deviceName: 'Pixel 8 Pro (Monitored)',
          platform: DevicePlatform.ANDROID,
          pushToken: 'fcm-token-monitored-m3',
          osVersion: 'Android 14',
          appVersion: '1.0.0',
          batteryLevel: 92,
          isCharging: false,
        });

      expect([200, 201]).toContain(devRes.status);
      expect(devRes.body.id).toBeDefined();
      expect(devRes.body.isActive).toBe(true);
      expect(devRes.body.pushToken).toBe('fcm-token-monitored-m3');
      monitoredDevice = devRes.body;

      // Guardian device registration
      monitorDevice = await registerTestDevice(app, monitorUser.accessToken, {
        platform: DevicePlatform.IOS,
        deviceName: 'iPhone 15 Pro (Guardian)',
        pushToken: 'apns-token-guardian-m3',
        batteryLevel: 100,
      });
      expect(monitorDevice.id).toBeDefined();
    });

    it('1.3 Monitoring Relationship Invitation, Acceptance & Threshold Configuration', async () => {
      // Guardian initiates pairing with monitored user email
      const inviteRes = await request(app.getHttpServer())
        .post('/api/v1/monitoring/relationships')
        .set('Authorization', `Bearer ${monitorUser.accessToken}`)
        .send({ monitoredUserEmail: monitoredUser.email });

      expect(inviteRes.status).toBe(201);
      expect(inviteRes.body.invitationCode).toBeDefined();
      expect(inviteRes.body.status).toBe(RelationshipStatus.PENDING);
      const invitationCode = inviteRes.body.invitationCode;

      // Monitored user accepts invitation code
      const acceptRes = await request(app.getHttpServer())
        .post('/api/v1/monitoring/relationships/accept')
        .set('Authorization', `Bearer ${monitoredUser.accessToken}`)
        .send({ invitationCode });

      expect(acceptRes.status).toBe(200);
      expect(acceptRes.body.status).toBe(RelationshipStatus.ACCEPTED);
      relationship = acceptRes.body;

      // Configure monitoring thresholds (1 min inactivity, 1 min grace, 1 min warning escalation)
      const patchRes = await request(app.getHttpServer())
        .patch(`/api/v1/monitoring/${relationship.id}/config`)
        .set('Authorization', `Bearer ${monitoredUser.accessToken}`)
        .send({
          inactivityThresholdMinutes: 1,
          checkInGraceMinutes: 1,
          warningEscalationMinutes: 1,
          locationEnabled: true,
        });

      expect(patchRes.status).toBe(200);
      expect(patchRes.body.currentState).toBe(MonitoringState.ACTIVE);
      expect(patchRes.body.inactivityThresholdMinutes).toBe(1);
      expect(patchRes.body.checkInGraceMinutes).toBe(1);
      expect(patchRes.body.locationEnabled).toBe(true);
    });

    it('1.4 Reachability Heartbeat (Weight 0.0 Invariant) & Meaningful Activity Ingestion', async () => {
      // Capture baseline lastMeaningfulActivityAt
      const configBefore = await request(app.getHttpServer())
        .get(`/api/v1/monitoring/${relationship.id}/config`)
        .set('Authorization', `Bearer ${monitoredUser.accessToken}`);
      const baselineActivityAt = new Date(configBefore.body.lastMeaningfulActivityAt).getTime();

      // 1. Monitored device sends reachability heartbeat
      const hbRes = await request(app.getHttpServer())
        .post('/api/v1/heartbeat')
        .set('Authorization', `Bearer ${monitoredUser.accessToken}`)
        .send({
          deviceId: monitoredDevice.id,
          occurredAt: new Date().toISOString(),
          batteryLevel: 91,
          isCharging: false,
        });

      expect(hbRes.status).toBe(200);
      expect(hbRes.body.operationalState).toBe('ONLINE');

      // Heartbeat strictly maintains weight 0.0: lastMeaningfulActivityAt MUST NOT CHANGE
      const configAfterHb = await request(app.getHttpServer())
        .get(`/api/v1/monitoring/${relationship.id}/config`)
        .set('Authorization', `Bearer ${monitoredUser.accessToken}`);
      const afterHbActivityAt = new Date(configAfterHb.body.lastMeaningfulActivityAt).getTime();
      expect(afterHbActivityAt).toBe(baselineActivityAt);

      // 2. Monitored device records passive human activity (APP_FOREGROUND, weight >= 0.8)
      await new Promise((resolve) => setTimeout(resolve, 50));
      const activityEventId = uuidv4();
      const actRes = await request(app.getHttpServer())
        .post('/api/v1/activities')
        .set('Authorization', `Bearer ${monitoredUser.accessToken}`)
        .send({
          eventId: activityEventId,
          deviceId: monitoredDevice.id,
          type: ActivityType.APP_FOREGROUND,
          occurredAt: new Date().toISOString(),
          confidence: 0.9,
        });

      expect(actRes.status).toBe(201);
      expect(Number(actRes.body.weight)).toBeGreaterThanOrEqual(0.8);

      // Meaningful activity progresses lastMeaningfulActivityAt forward
      const configAfterAct = await request(app.getHttpServer())
        .get(`/api/v1/monitoring/${relationship.id}/config`)
        .set('Authorization', `Bearer ${monitoredUser.accessToken}`);
      const afterActTime = new Date(configAfterAct.body.lastMeaningfulActivityAt).getTime();
      expect(afterActTime).toBeGreaterThan(baselineActivityAt);
    });
  });

  // =========================================================================
  // Scenario 2 (Feature 31): Inactivity Escalation Cycle & Vietnamese Calm UX
  // =========================================================================
  describe('Scenario 2 (Feature 31): Inactivity Escalation & Vietnamese Calm UX', () => {
    it('2.1 Inactivity Exceeded -> CHECK_IN_REQUIRED with Recipient Isolation & Calm Copy', async () => {
      // Simulate inactivity exceeding threshold (last active 2 mins ago, threshold is 1 min)
      const pastTime = new Date(Date.now() - 2 * 60 * 1000);
      await dataSource.query(
        `UPDATE monitoring_configs 
         SET current_state = 'ACTIVE',
             last_meaningful_activity_at = $1,
             next_evaluation_at = NOW() - INTERVAL '5 seconds'
         WHERE relationship_id = $2`,
        [pastTime, relationship.id],
      );

      // Trigger Inactivity Worker evaluation cycle
      const processed = await workerService.evaluateDueMonitoring(10);
      expect(processed).toBeGreaterThanOrEqual(1);

      // State machine transitioned to CHECK_IN_REQUIRED
      const configRows = await dataSource.query(
        `SELECT current_state FROM monitoring_configs WHERE relationship_id = $1`,
        [relationship.id],
      );
      expect(configRows[0].current_state).toBe(MonitoringState.CHECK_IN_REQUIRED);

      // Recipient Isolation Invariant:
      // Monitored user receives Tier 1 Calm check-in push
      const monitoredDeliveries = await dataSource.query(
        `SELECT template_name, payload FROM notification_deliveries 
         WHERE recipient_user_id = $1 ORDER BY created_at DESC LIMIT 1`,
        [monitoredUser.id],
      );
      expect(monitoredDeliveries.length).toBe(1);
      expect(monitoredDeliveries[0].template_name).toBe('CHECK_IN_PROMPT');
      expect(monitoredDeliveries[0].payload.title).toContain('Carely — Bạn vẫn ổn chứ?');
      expect(monitoredDeliveries[0].payload.body).toContain(
        'Hệ thống chưa nhận thấy hoạt động mới trong khung giờ quy định. Chạm để xác nhận bạn vẫn ổn.',
      );

      // Vietnamese Calm UX check: Zero prohibited panic keywords
      const panicWords = ['chết', 'nguy kịch', 'hôn mê', 'cấp cứu'];
      for (const word of panicWords) {
        expect(monitoredDeliveries[0].payload.title.toLowerCase()).not.toContain(word);
        expect(monitoredDeliveries[0].payload.body.toLowerCase()).not.toContain(word);
      }

      // Guardian MUST NOT receive any notification at CHECK_IN_REQUIRED stage
      const guardianDeliveries = await dataSource.query(
        `SELECT id FROM notification_deliveries 
         WHERE recipient_user_id = $1 AND template_name = 'CHECK_IN_PROMPT'`,
        [monitorUser.id],
      );
      expect(guardianDeliveries.length).toBe(0);
    });

    it('2.2 Grace Period Expiration -> WARNING State, Risk Score & Incident Creation', async () => {
      // Simulate grace period expired without check-in
      await dataSource.query(
        `UPDATE monitoring_configs 
         SET next_evaluation_at = NOW() - INTERVAL '5 seconds'
         WHERE relationship_id = $1`,
        [relationship.id],
      );

      // Run worker evaluation
      await workerService.evaluateDueMonitoring(10);

      // State machine transitioned to WARNING
      const configRows = await dataSource.query(
        `SELECT current_state FROM monitoring_configs WHERE relationship_id = $1`,
        [relationship.id],
      );
      expect(configRows[0].current_state).toBe(MonitoringState.WARNING);

      // Verify Incident was created with status OPEN and risk score >= 50
      const incidents = await dataSource.query(
        `SELECT id, status, risk_score, reason FROM incidents 
         WHERE relationship_id = $1 AND status = 'OPEN'`,
        [relationship.id],
      );
      expect(incidents.length).toBeGreaterThanOrEqual(1);
      incident1Id = incidents[0].id;
      expect(Number(incidents[0].risk_score)).toBeGreaterThanOrEqual(50);

      // Guardian receives Tier 3 calm warning notification
      const guardianDeliveries = await dataSource.query(
        `SELECT template_name, payload FROM notification_deliveries 
         WHERE recipient_user_id = $1 AND template_name = 'MONITOR_INACTIVITY_WARNING'
         ORDER BY created_at DESC LIMIT 1`,
        [monitorUser.id],
      );
      expect(guardianDeliveries.length).toBe(1);
      expect(guardianDeliveries[0].payload.title).toContain('Carely — Thông báo chăm sóc');
      expect(guardianDeliveries[0].payload.body).toContain('Chưa ghi nhận hoạt động hoặc phản hồi');
    });

    it('2.3 Warning Timeout -> Autonomous Escalation to ESCALATED & Incident Status Update', async () => {
      // Advance evaluation past warning escalation window
      await dataSource.query(
        `UPDATE monitoring_configs 
         SET next_evaluation_at = NOW() - INTERVAL '5 seconds'
         WHERE relationship_id = $1`,
        [relationship.id],
      );

      // Run worker
      await workerService.evaluateDueMonitoring(10);

      // Monitoring config is ESCALATED
      const configRows = await dataSource.query(
        `SELECT current_state FROM monitoring_configs WHERE relationship_id = $1`,
        [relationship.id],
      );
      expect(configRows[0].current_state).toBe(MonitoringState.ESCALATED);

      // Incident status updated to ESCALATED and escalated_at is populated
      const incRows = await dataSource.query(
        `SELECT status, escalated_at FROM incidents WHERE id = $1`,
        [incident1Id],
      );
      expect(incRows[0].status).toBe(IncidentStatus.ESCALATED);
      expect(incRows[0].escalated_at).toBeDefined();

      // Incident event ESCALATION_TRIGGERED recorded
      const events = await dataSource.query(
        `SELECT type FROM incident_events WHERE incident_id = $1 AND type = $2`,
        [incident1Id, IncidentEventType.ESCALATION_TRIGGERED],
      );
      expect(events.length).toBeGreaterThanOrEqual(1);

      // Guardian receives Tier 4 escalation notification
      const escDeliveries = await dataSource.query(
        `SELECT template_name, payload FROM notification_deliveries 
         WHERE recipient_user_id = $1 AND template_name = 'MONITOR_ESCALATION'
         ORDER BY created_at DESC LIMIT 1`,
        [monitorUser.id],
      );
      expect(escDeliveries.length).toBe(1);
      expect(escDeliveries[0].payload.title).toContain('Carely — Cần lưu ý');
    });
  });

  // =========================================================================
  // Scenario 3 (Feature 32): Offline Check-in Replay, Monotonic Clock & Batch
  // =========================================================================
  describe('Scenario 3 (Feature 32): Offline Reconnection Replay & Monotonic Clock Protection', () => {
    it('3.1 Offline Check-in Replay with occurredAt = T_offline restores ACTIVE state and auto-resolves incident', async () => {
      // Fetch incident1 creation timestamp
      const inc1Rows = await dataSource.query(
        `SELECT created_at FROM incidents WHERE id = $1`,
        [incident1Id],
      );
      const inc1CreatedAt = new Date(inc1Rows[0].created_at);

      // Simulate client captured check-in offline 1 second after incident was created
      const offlineTime = new Date(inc1CreatedAt.getTime() + 1000);
      const checkInEventId = uuidv4();

      const ciRes = await request(app.getHttpServer())
        .post('/api/v1/check-ins')
        .set('Authorization', `Bearer ${monitoredUser.accessToken}`)
        .send({
          eventId: checkInEventId,
          deviceId: monitoredDevice.id,
          relationshipId: relationship.id,
          occurredAt: offlineTime.toISOString(),
          batteryLevel: 88,
          note: 'Tôi vẫn ổn, đang thưởng thức trà sáng.',
          location: {
            latitude: 10.776889,
            longitude: 106.700806,
            accuracy: 8.5,
          },
        });

      expect([200, 201]).toContain(ciRes.status);
      expect(ciRes.body.note).toBe('Tôi vẫn ổn, đang thưởng thức trà sáng.');

      // Check-in record preserved occurredAt = T_offline
      const ciRows = await dataSource.query(
        `SELECT occurred_at, note FROM check_ins WHERE event_id = $1`,
        [checkInEventId],
      );
      expect(ciRows.length).toBe(1);
      expect(new Date(ciRows[0].occurred_at).getTime()).toBeCloseTo(offlineTime.getTime(), -3);

      // Single-shot GPS location persisted with source = 'CHECK_IN'
      const locRows = await dataSource.query(
        `SELECT latitude, longitude, source FROM locations 
         WHERE user_id = $1 AND source = 'CHECK_IN' ORDER BY created_at DESC LIMIT 1`,
        [monitoredUser.id],
      );
      expect(locRows.length).toBe(1);
      expect(Number(locRows[0].latitude)).toBeCloseTo(10.776889);
      expect(Number(locRows[0].longitude)).toBeCloseTo(106.700806);

      // Monitoring State Machine restored to ACTIVE
      const configRows = await dataSource.query(
        `SELECT current_state, last_meaningful_activity_at FROM monitoring_configs WHERE relationship_id = $1`,
        [relationship.id],
      );
      expect(configRows[0].current_state).toBe(MonitoringState.ACTIVE);

      // Incident automatically resolved by check-in postdating incident creation
      const incRows = await dataSource.query(
        `SELECT status FROM incidents WHERE id = $1`,
        [incident1Id],
      );
      expect(incRows[0].status).toBe(IncidentStatus.RESOLVED);
    });

    it('3.2 Monotonic Activity Clock Protection: Delayed Out-of-Order Check-in NEVER rolls back server clock', async () => {
      // 1. Capture current authoritative server activity timestamp (T_current)
      const currentConfig = await request(app.getHttpServer())
        .get(`/api/v1/monitoring/${relationship.id}/config`)
        .set('Authorization', `Bearer ${monitoredUser.accessToken}`);
      const serverClockBefore = new Date(currentConfig.body.lastMeaningfulActivityAt).getTime();

      // 2. An old delayed check-in packet arrives from a stale offline queue (e.g. 1 hour in the past)
      const staleTime = new Date(serverClockBefore - 60 * 60 * 1000);
      const staleEventId = uuidv4();

      const staleRes = await request(app.getHttpServer())
        .post('/api/v1/check-ins')
        .set('Authorization', `Bearer ${monitoredUser.accessToken}`)
        .send({
          eventId: staleEventId,
          deviceId: monitoredDevice.id,
          relationshipId: relationship.id,
          occurredAt: staleTime.toISOString(),
          note: 'Gói check-in cũ bị trễ',
        });

      // API succeeds and persists the audit record
      expect([200, 201]).toContain(staleRes.status);

      // 3. CRITICAL INVARIANT: Server activity clock MUST NOT roll back to staleTime!
      const afterConfig = await request(app.getHttpServer())
        .get(`/api/v1/monitoring/${relationship.id}/config`)
        .set('Authorization', `Bearer ${monitoredUser.accessToken}`);
      const serverClockAfter = new Date(afterConfig.body.lastMeaningfulActivityAt).getTime();

      expect(serverClockAfter).toBe(serverClockBefore);
      expect(serverClockAfter).toBeGreaterThan(staleTime.getTime());
    });

    it('3.3 Activity Batch Ingestion with Idempotency Replay', async () => {
      const event1 = uuidv4();
      const event2 = uuidv4();
      const event3 = uuidv4();

      // Batch ingestion simulating offline queue flush
      const batchRes = await request(app.getHttpServer())
        .post('/api/v1/activities/batch')
        .set('Authorization', `Bearer ${monitoredUser.accessToken}`)
        .send({
          activities: [
            {
              eventId: event1,
              deviceId: monitoredDevice.id,
              type: ActivityType.STEP_DETECTED,
              occurredAt: new Date(Date.now() - 60000).toISOString(),
              confidence: 0.8,
            },
            {
              eventId: event2,
              deviceId: monitoredDevice.id,
              type: ActivityType.CHARGER_CONNECTED,
              occurredAt: new Date(Date.now() - 40000).toISOString(),
              confidence: 0.9,
            },
            {
              eventId: event3,
              deviceId: monitoredDevice.id,
              type: ActivityType.SCREEN_INTERACTION,
              occurredAt: new Date(Date.now() - 20000).toISOString(),
              confidence: 0.85,
            },
          ],
        });

      expect(batchRes.status).toBe(201);
      expect(Array.isArray(batchRes.body)).toBe(true);
      expect(batchRes.body.length).toBe(3);

      // Replaying same batch: deduplication returns existing records without duplicate insertions
      const replayRes = await request(app.getHttpServer())
        .post('/api/v1/activities/batch')
        .set('Authorization', `Bearer ${monitoredUser.accessToken}`)
        .send({
          activities: [
            {
              eventId: event1,
              deviceId: monitoredDevice.id,
              type: ActivityType.STEP_DETECTED,
              occurredAt: new Date(Date.now() - 60000).toISOString(),
              confidence: 0.8,
            },
            {
              eventId: event2,
              deviceId: monitoredDevice.id,
              type: ActivityType.CHARGER_CONNECTED,
              occurredAt: new Date(Date.now() - 40000).toISOString(),
              confidence: 0.9,
            },
          ],
        });

      expect(replayRes.status).toBe(201);
      expect(Array.isArray(replayRes.body)).toBe(true);
      expect(replayRes.body.length).toBe(2);
      expect(replayRes.body[0].eventId).toBe(event1);
      expect(replayRes.body[1].eventId).toBe(event2);
    });

    it('3.4 Heartbeat Telemetry Isolation: Reachability Pings Never Reset Inactivity & Respect Rate Limits', async () => {
      const configBefore = await request(app.getHttpServer())
        .get(`/api/v1/monitoring/${relationship.id}/config`)
        .set('Authorization', `Bearer ${monitoredUser.accessToken}`);
      const beforeTime = new Date(configBefore.body.lastMeaningfulActivityAt).getTime();

      // Register dedicated reachability device to isolate rate limiter bucket
      const telemetryDevice = await registerTestDevice(app, monitoredUser.accessToken, {
        platform: DevicePlatform.ANDROID,
        deviceName: 'Telemetry Device Test',
        pushToken: 'push-token-telemetry-isolation',
        batteryLevel: 90,
      });

      // Send reachability pings within rate limit (max 2 per 30s)
      const hbRes1 = await request(app.getHttpServer())
        .post('/api/v1/heartbeat')
        .set('Authorization', `Bearer ${monitoredUser.accessToken}`)
        .send({
          deviceId: telemetryDevice.id,
          occurredAt: new Date().toISOString(),
          batteryLevel: 85,
          isCharging: false,
        });
      expect(hbRes1.status).toBe(200);
      expect(hbRes1.body.operationalState).toBe('ONLINE');

      const hbRes2 = await request(app.getHttpServer())
        .post('/api/v1/heartbeat')
        .set('Authorization', `Bearer ${monitoredUser.accessToken}`)
        .send({
          deviceId: telemetryDevice.id,
          occurredAt: new Date().toISOString(),
          batteryLevel: 84,
          isCharging: false,
        });
      expect(hbRes2.status).toBe(200);

      // Third rapid heartbeat within 30s exceeds opportunistic limit -> returns 429
      const hbRes3 = await request(app.getHttpServer())
        .post('/api/v1/heartbeat')
        .set('Authorization', `Bearer ${monitoredUser.accessToken}`)
        .send({
          deviceId: telemetryDevice.id,
          occurredAt: new Date().toISOString(),
          batteryLevel: 83,
          isCharging: false,
        });
      expect(hbRes3.status).toBe(429);

      // Check device battery and reachability updated from the successful heartbeat
      const devRows = await dataSource.query(
        `SELECT battery_level, last_heartbeat_at FROM devices WHERE id = $1`,
        [telemetryDevice.id],
      );
      expect(devRows[0].battery_level).toBe(84);

      // Verify lastMeaningfulActivityAt remains strictly untouched (Weight 0.0 Invariant)
      const configAfter = await request(app.getHttpServer())
        .get(`/api/v1/monitoring/${relationship.id}/config`)
        .set('Authorization', `Bearer ${monitoredUser.accessToken}`);
      const afterTime = new Date(configAfter.body.lastMeaningfulActivityAt).getTime();
      expect(afterTime).toBe(beforeTime);
    });
  });

  // =========================================================================
  // Scenario 4 (Feature 33): Guardian Acknowledgment & Resolution Cycle
  // =========================================================================
  describe('Scenario 4 (Feature 33): Guardian Acknowledgment & Resolution with Monitoring State Restoration', () => {
    it('4.1 Trigger New Incident and advance to ESCALATED for Guardian Resolution Testing', async () => {
      // Advance inactivity so worker creates incident 2
      const pastTime = new Date(Date.now() - 5 * 60 * 1000);
      await dataSource.query(
        `UPDATE monitoring_configs 
         SET current_state = 'CHECK_IN_REQUIRED',
             last_meaningful_activity_at = $1,
             next_evaluation_at = NOW() - INTERVAL '5 seconds'
         WHERE relationship_id = $2`,
        [pastTime, relationship.id],
      );

      // Worker tick 1 -> Transitions to WARNING and creates Incident 2
      await workerService.evaluateDueMonitoring(10);

      const openIncidents = await dataSource.query(
        `SELECT id, status FROM incidents 
         WHERE relationship_id = $1 AND status = 'OPEN' 
         ORDER BY detected_at DESC LIMIT 1`,
        [relationship.id],
      );
      expect(openIncidents.length).toBe(1);
      incident2Id = openIncidents[0].id;

      // Advance evaluation and worker tick 2 -> Transitions to ESCALATED
      await dataSource.query(
        `UPDATE monitoring_configs 
         SET next_evaluation_at = NOW() - INTERVAL '5 seconds'
         WHERE relationship_id = $1`,
        [relationship.id],
      );
      await workerService.evaluateDueMonitoring(10);

      const escIncidents = await dataSource.query(
        `SELECT status FROM incidents WHERE id = $1`,
        [incident2Id],
      );
      expect(escIncidents[0].status).toBe(IncidentStatus.ESCALATED);

      const configRows = await dataSource.query(
        `SELECT current_state FROM monitoring_configs WHERE relationship_id = $1`,
        [relationship.id],
      );
      expect(configRows[0].current_state).toBe(MonitoringState.ESCALATED);
    });

    it('4.2 Guardian Acknowledgment transitions Incident and Monitoring Config to ACKNOWLEDGED', async () => {
      // 1. Negative Test: Intruder cannot acknowledge incident
      const intruderAck = await request(app.getHttpServer())
        .post(`/api/v1/incidents/${incident2Id}/acknowledge`)
        .set('Authorization', `Bearer ${thirdPartyUser.accessToken}`);
      expect(intruderAck.status).toBe(403);

      // 2. Designated Guardian acknowledges receipt
      const ackRes = await request(app.getHttpServer())
        .post(`/api/v1/incidents/${incident2Id}/acknowledge`)
        .set('Authorization', `Bearer ${monitorUser.accessToken}`);

      expect(ackRes.status).toBe(200);
      expect(ackRes.body.status).toBe(IncidentStatus.ACKNOWLEDGED);
      expect(ackRes.body.acknowledgedBy).toBe(monitorUser.id);
      expect(ackRes.body.acknowledgedAt).toBeDefined();

      // Verify incident event recorded
      const events = await dataSource.query(
        `SELECT type, metadata FROM incident_events 
         WHERE incident_id = $1 AND type = $2`,
        [incident2Id, IncidentEventType.MONITOR_ACKNOWLEDGED],
      );
      expect(events.length).toBe(1);

      // CORE FEATURE 33 INVARIANT:
      // MonitoringConfig.currentState synchronized to ACKNOWLEDGED
      const configRows = await dataSource.query(
        `SELECT current_state FROM monitoring_configs WHERE relationship_id = $1`,
        [relationship.id],
      );
      expect(configRows[0].current_state).toBe(MonitoringState.ACKNOWLEDGED);
    });

    it('4.3 Guardian Resolution restores Monitoring Config to ACTIVE and resets evaluation window', async () => {
      // 1. Negative Test: Intruder cannot resolve incident
      const intruderRes = await request(app.getHttpServer())
        .post(`/api/v1/incidents/${incident2Id}/resolve`)
        .set('Authorization', `Bearer ${thirdPartyUser.accessToken}`)
        .send({ note: 'Can thiệp trái phép' });
      expect(intruderRes.status).toBe(403);

      // 2. Guardian resolves incident with reassurance note
      const resolveNote = 'Đã gọi điện trực tiếp, người thân an toàn đang nấu cơm trưa.';
      const resRes = await request(app.getHttpServer())
        .post(`/api/v1/incidents/${incident2Id}/resolve`)
        .set('Authorization', `Bearer ${monitorUser.accessToken}`)
        .send({ note: resolveNote });

      expect(resRes.status).toBe(200);
      expect(resRes.body.status).toBe(IncidentStatus.RESOLVED);
      expect(resRes.body.resolvedBy).toBe(monitorUser.id);
      expect(resRes.body.resolvedAt).toBeDefined();

      // Verify incident event INCIDENT_RESOLVED recorded with note
      const events = await dataSource.query(
        `SELECT type, metadata FROM incident_events 
         WHERE incident_id = $1 AND type = $2`,
        [incident2Id, IncidentEventType.INCIDENT_RESOLVED],
      );
      expect(events.length).toBe(1);
      expect(events[0].metadata.note).toBe(resolveNote);

      // CORE FEATURE 33 STATE RESTORATION INVARIANT:
      // 1. MonitoringConfig.currentState restored to ACTIVE
      // 2. lastMeaningfulActivityAt updated to current time
      // 3. nextEvaluationAt recalculated into the future
      const configRows = await dataSource.query(
        `SELECT current_state, last_meaningful_activity_at, next_evaluation_at, inactivity_threshold_minutes 
         FROM monitoring_configs WHERE relationship_id = $1`,
        [relationship.id],
      );
      const restoredConfig = configRows[0];

      expect(restoredConfig.current_state).toBe(MonitoringState.ACTIVE);

      const nowTime = Date.now();
      const lastActiveTime = new Date(restoredConfig.last_meaningful_activity_at).getTime();
      expect(Math.abs(nowTime - lastActiveTime)).toBeLessThan(10000); // within last 10 seconds

      const nextEvalTime = new Date(restoredConfig.next_evaluation_at).getTime();
      expect(nextEvalTime).toBeGreaterThan(nowTime); // in the future
    });

    it('4.4 Post-Resolution System Stabilization: Zero False Alarms on subsequent worker ticks', async () => {
      // Execute worker evaluation immediately after guardian resolution: zero items due
      const processed = await workerService.evaluateDueMonitoring(10);
      expect(processed).toBe(0);

      // Because nextEvaluationAt was reset forward, this relationship is not due
      const configRows = await dataSource.query(
        `SELECT current_state FROM monitoring_configs WHERE relationship_id = $1`,
        [relationship.id],
      );
      expect(configRows[0].current_state).toBe(MonitoringState.ACTIVE);

      // No new open or warning incidents created
      const activeIncidents = await dataSource.query(
        `SELECT id FROM incidents 
         WHERE relationship_id = $1 AND status IN ('OPEN', 'ESCALATED', 'WARNING')`,
        [relationship.id],
      );
      expect(activeIncidents.length).toBe(0);
    });
  });
});
