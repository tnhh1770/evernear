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
  RelationshipStatus,
} from '../../src/common/enums';
import { MonitoringWorkerService } from '../../src/modules/workers/monitoring-worker.service';

describe('Tier 4: Full Real-World Application Lifecycle (E2E Scenario)', () => {
  let app: INestApplication;
  let dataSource: DataSource;
  let workerService: MonitoringWorkerService;

  let monitorUser: TestUserContext;
  let monitoredUser: TestUserContext;
  let monitoredDevice: any;
  let monitorDevice: any;
  let relationship: any;
  let incidentId: string;

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
  // Stage 1: System Enrollment & Hardware Pairing
  // =========================================================================
  it('Stage 1: System Enrollment & Pairing: Register users, devices, and configure monitoring', async () => {
    // 1. Register Monitor (Guardian)
    monitorUser = await registerAndLoginUser(app, 'guardian_t4');
    expect(monitorUser.id).toBeDefined();

    // 2. Register Monitored User
    monitoredUser = await registerAndLoginUser(app, 'monitored_t4');
    expect(monitoredUser.id).toBeDefined();

    // 3. Register Monitored Device
    monitoredDevice = await registerTestDevice(app, monitoredUser.accessToken, {
      platform: DevicePlatform.ANDROID,
      deviceName: 'Pixel 8 Pro Monitored',
      pushToken: 'fcm-push-token-monitored-t4',
      batteryLevel: 95,
      isCharging: false,
    });
    expect(monitoredDevice.id).toBeDefined();
    expect(monitoredDevice.isActive).toBe(true);

    // 4. Register Monitor Device
    monitorDevice = await registerTestDevice(app, monitorUser.accessToken, {
      platform: DevicePlatform.IOS,
      deviceName: 'iPhone 15 Pro Guardian',
      pushToken: 'fcm-push-token-guardian-t4',
      batteryLevel: 100,
    });
    expect(monitorDevice.id).toBeDefined();

    // 5. Establish & Accept Monitoring Relationship
    const paired = await pairMonitoringRelationship(app, monitorUser.accessToken, monitoredUser);
    relationship = paired.relationship;
    expect(relationship.status).toBe(RelationshipStatus.ACCEPTED);

    // 6. Configure Monitoring Parameters (Threshold: 1 min, Grace: 1 min, Location: true)
    const patchRes = await request(app.getHttpServer())
      .patch(`/api/v1/monitoring/${relationship.id}/config`)
      .set('Authorization', `Bearer ${monitoredUser.accessToken}`)
      .send({
        inactivityThresholdMinutes: 1,
        checkInGraceMinutes: 1,
        locationEnabled: true,
      });
    expect(patchRes.status).toBe(200);
    expect(patchRes.body.currentState).toBe(MonitoringState.ACTIVE);
  });

  // =========================================================================
  // Stage 2: Routine Reachability Reporting (Heartbeat Phase)
  // =========================================================================
  it('Stage 2: Routine Reachability: Monitored device sends periodic Heartbeats without resetting timer', async () => {
    const configBefore = await request(app.getHttpServer())
      .get(`/api/v1/monitoring/${relationship.id}/config`)
      .set('Authorization', `Bearer ${monitoredUser.accessToken}`);
    const initialLastActive = new Date(configBefore.body.lastMeaningfulActivityAt).getTime();

    // Phone reports background reachability
    const hbRes = await request(app.getHttpServer())
      .post('/api/v1/heartbeat')
      .set('Authorization', `Bearer ${monitoredUser.accessToken}`)
      .send({
        deviceId: monitoredDevice.id,
        occurredAt: new Date().toISOString(),
        batteryLevel: 94,
        isCharging: false,
      });

    expect(hbRes.status).toBe(200);
    expect(hbRes.body.operationalState).toBe('ONLINE');

    // Verify lastMeaningfulActivityAt did NOT change
    const configAfter = await request(app.getHttpServer())
      .get(`/api/v1/monitoring/${relationship.id}/config`)
      .set('Authorization', `Bearer ${monitoredUser.accessToken}`);
    const afterLastActive = new Date(configAfter.body.lastMeaningfulActivityAt).getTime();

    expect(afterLastActive).toBe(initialLastActive);
  });

  // =========================================================================
  // Stage 3: Passive Daytime Human Activity
  // =========================================================================
  it('Stage 3: Passive Human Activity: User interacts with phone, resetting inactivity clock', async () => {
    const configBefore = await request(app.getHttpServer())
      .get(`/api/v1/monitoring/${relationship.id}/config`)
      .set('Authorization', `Bearer ${monitoredUser.accessToken}`);
    const initialLastActive = new Date(configBefore.body.lastMeaningfulActivityAt).getTime();

    await new Promise((r) => setTimeout(r, 100));

    // User unlocks and opens app
    const actEventId = uuidv4();
    const actRes = await request(app.getHttpServer())
      .post('/api/v1/activities')
      .set('Authorization', `Bearer ${monitoredUser.accessToken}`)
      .send({
        eventId: actEventId,
        deviceId: monitoredDevice.id,
        type: ActivityType.APP_FOREGROUND,
        occurredAt: new Date().toISOString(),
        confidence: 0.9,
      });

    expect(actRes.status).toBe(201);
    expect(Number(actRes.body.weight)).toBeGreaterThanOrEqual(0.8);

    // Verify inactivity timer was reset forward
    const configAfter = await request(app.getHttpServer())
      .get(`/api/v1/monitoring/${relationship.id}/config`)
      .set('Authorization', `Bearer ${monitoredUser.accessToken}`);
    const afterLastActive = new Date(configAfter.body.lastMeaningfulActivityAt).getTime();

    expect(afterLastActive).toBeGreaterThan(initialLastActive);
  });

  // =========================================================================
  // Stage 4 & 5: Inactivity Elapse -> Worker Triggers CHECK_IN_REQUIRED
  // =========================================================================
  it('Stage 4 & 5: Inactivity Timeout: Worker detects inactivity, transitions to CHECK_IN_REQUIRED and queues Calm Push', async () => {
    // Simulate elapsed time: 2 minutes since last meaningful activity (threshold is 1 min)
    const pastTime = new Date(Date.now() - 2 * 60 * 1000);
    await dataSource.query(
      `UPDATE monitoring_configs 
       SET current_state = 'ACTIVE',
           last_meaningful_activity_at = $1,
           next_evaluation_at = NOW() - INTERVAL '5 seconds'
       WHERE relationship_id = $2`,
      [pastTime, relationship.id],
    );

    // Inactivity Worker evaluation cycle
    const processed = await workerService.evaluateDueMonitoring(10);
    expect(processed).toBeGreaterThanOrEqual(1);

    // Verify State Machine transitioned to CHECK_IN_REQUIRED
    const configRows = await dataSource.query(
      `SELECT current_state FROM monitoring_configs WHERE relationship_id = $1`,
      [relationship.id],
    );
    expect(configRows[0].current_state).toBe(MonitoringState.CHECK_IN_REQUIRED);

    // Verify Tier 1 Calm Check-in Push notification was recorded
    const deliveries = await dataSource.query(
      `SELECT template_name, status FROM notification_deliveries WHERE recipient_user_id = $1 ORDER BY created_at DESC LIMIT 1`,
      [monitoredUser.id],
    );
    expect(deliveries.length).toBeGreaterThanOrEqual(1);
  });

  // =========================================================================
  // Stage 6: Missed Check-in -> Transition to WARNING & Incident Creation
  // =========================================================================
  it('Stage 6: Missed Check-in: Grace period expires -> WARNING state, Risk Score, and Safety Incident created', async () => {
    // Simulate check-in grace period expired (1 minute past deadline)
    const pastTime = new Date(Date.now() - 5 * 60 * 1000);
    await dataSource.query(
      `UPDATE monitoring_configs 
       SET current_state = 'CHECK_IN_REQUIRED',
           last_meaningful_activity_at = $1,
           next_evaluation_at = NOW() - INTERVAL '5 seconds'
       WHERE relationship_id = $2`,
      [pastTime, relationship.id],
    );

    // Run worker evaluation
    await workerService.evaluateDueMonitoring(10);

    // Verify State Machine transitioned to WARNING
    const configRows = await dataSource.query(
      `SELECT current_state FROM monitoring_configs WHERE relationship_id = $1`,
      [relationship.id],
    );
    expect(configRows[0].current_state).toBe(MonitoringState.WARNING);

    // Verify safety Incident was created with status OPEN and calculated risk score
    const incidents = await dataSource.query(
      `SELECT id, status, risk_score, user_id, relationship_id FROM incidents WHERE relationship_id = $1 AND status = 'OPEN'`,
      [relationship.id],
    );
    expect(incidents.length).toBeGreaterThanOrEqual(1);
    incidentId = incidents[0].id;
    expect(Number(incidents[0].risk_score)).toBeGreaterThanOrEqual(50);
  });

  // =========================================================================
  // Stage 7: Autonomous Escalation to ESCALATED
  // =========================================================================
  it('Stage 7: Autonomous Escalation: Incident advances to ESCALATED as time elapses without response', async () => {
    // Advance config next_evaluation_at into the past so worker evaluates WARNING state
    await dataSource.query(
      `UPDATE monitoring_configs 
       SET next_evaluation_at = NOW() - INTERVAL '1 second'
       WHERE relationship_id = $1`,
      [relationship.id],
    );

    // Run worker
    await workerService.evaluateDueMonitoring(10);

    // Verify incident transitioned to ESCALATED
    const incRows = await dataSource.query(
      `SELECT status, escalated_at FROM incidents WHERE id = $1`,
      [incidentId],
    );
    expect(incRows[0].status).toBe(IncidentStatus.ESCALATED);
    expect(incRows[0].escalated_at).toBeDefined();
  });

  // =========================================================================
  // Stage 8: Guardian Incident Review & Acknowledgment
  // =========================================================================
  it('Stage 8: Guardian Acknowledgment: Guardian receives alert, inspects incident, and acknowledges receipt', async () => {
    // Guardian fetches incident details
    const getRes = await request(app.getHttpServer())
      .get(`/api/v1/incidents/${incidentId}`)
      .set('Authorization', `Bearer ${monitorUser.accessToken}`);
    expect(getRes.status).toBe(200);
    expect(getRes.body.id).toBe(incidentId);

    // Guardian acknowledges receipt ("Xác nhận đã liên hệ")
    const ackRes = await request(app.getHttpServer())
      .post(`/api/v1/incidents/${incidentId}/acknowledge`)
      .set('Authorization', `Bearer ${monitorUser.accessToken}`);

    expect(ackRes.status).toBe(200);
    expect(ackRes.body.status).toBe(IncidentStatus.ACKNOWLEDGED);
    expect(ackRes.body.acknowledgedBy).toBe(monitorUser.id);
  });

  // =========================================================================
  // Stage 9: Monitored User Safety Recovery ("Tôi vẫn ổn")
  // =========================================================================
  it('Stage 9: Safety Recovery: User submits "Tôi vẫn ổn" check-in with GPS, restoring ACTIVE state and resolving incident', async () => {
    // User submits Check-in with location and reassurance note
    const checkInEventId = uuidv4();
    const ciRes = await request(app.getHttpServer())
      .post('/api/v1/check-ins')
      .set('Authorization', `Bearer ${monitoredUser.accessToken}`)
      .send({
        eventId: checkInEventId,
        deviceId: monitoredDevice.id,
        relationshipId: relationship.id,
        occurredAt: new Date().toISOString(),
        batteryLevel: 91,
        note: 'Tôi vừa chợp mắt, tôi hoàn toàn khỏe mạnh.',
        location: {
          latitude: 10.762622,
          longitude: 106.660172,
          accuracy: 10.0,
        },
      });

    expect(ciRes.status).toBe(201);
    expect(ciRes.body.note).toBe('Tôi vừa chợp mắt, tôi hoàn toàn khỏe mạnh.');

    // Verify single-shot location was captured in locations table
    const locRows = await dataSource.query(
      `SELECT latitude, longitude FROM locations WHERE user_id = $1 AND source = 'CHECK_IN' ORDER BY created_at DESC LIMIT 1`,
      [monitoredUser.id],
    );
    expect(Number(locRows[0].latitude)).toBeCloseTo(10.762622);

    // Verify Monitoring state machine reverted to ACTIVE
    const configRows = await dataSource.query(
      `SELECT current_state FROM monitoring_configs WHERE relationship_id = $1`,
      [relationship.id],
    );
    expect(configRows[0].current_state).toBe(MonitoringState.ACTIVE);

    // Guardian or User resolves acknowledged incident
    const resRes = await request(app.getHttpServer())
      .post(`/api/v1/incidents/${incidentId}/resolve`)
      .set('Authorization', `Bearer ${monitoredUser.accessToken}`)
      .send({ note: 'Người dùng đã xác nhận an toàn qua nút Tôi vẫn ổn.' });
    expect(resRes.status).toBe(200);
    expect(resRes.body.status).toBe(IncidentStatus.RESOLVED);
  });

  // =========================================================================
  // Stage 10: Post-Recovery Audit & System Stabilization
  // =========================================================================
  it('Stage 10: System Stabilization: Verification of audit events and absence of false alarms', async () => {
    // 1. Verify immutable timeline of incident events recorded
    const events = await dataSource.query(
      `SELECT type FROM incident_events WHERE incident_id = $1 ORDER BY created_at ASC`,
      [incidentId],
    );
    const eventTypes = events.map((e: any) => e.type);

    expect(eventTypes).toContain(IncidentEventType.INCIDENT_CREATED);
    expect(eventTypes).toContain(IncidentEventType.MONITOR_ACKNOWLEDGED);
    expect(eventTypes).toContain(IncidentEventType.INCIDENT_RESOLVED);

    // 2. Run Worker again: Verifies no false alarms triggered while in ACTIVE state
    const processed = await workerService.evaluateDueMonitoring(10);
    expect(typeof processed).toBe('number');

    const finalConfig = await dataSource.query(
      `SELECT current_state FROM monitoring_configs WHERE relationship_id = $1`,
      [relationship.id],
    );
    expect(finalConfig[0].current_state).toBe(MonitoringState.ACTIVE);
  });
});
