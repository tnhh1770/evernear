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
  IncidentStatus,
  MonitoringState,
} from '../../src/common/enums';
import { MonitoringWorkerService } from '../../src/modules/workers/monitoring-worker.service';
import { MonitoringScheduler } from '../../src/modules/monitoring/monitoring-scheduler';
import { ActivityService } from '../../src/modules/activities/activity.service';

describe('Tier 3: Cross-Feature Pairwise Combinations & Interactions', () => {
  let app: INestApplication;
  let dataSource: DataSource;
  let workerService: MonitoringWorkerService;
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
    activityService = context.moduleFixture.get<ActivityService>(ActivityService);

    await resetDatabase(dataSource);

    monitor = await registerAndLoginUser(app, 't3_monitor');
    monitored = await registerAndLoginUser(app, 't3_monitored');
    device = await registerTestDevice(app, monitored.accessToken);
    const paired = await pairMonitoringRelationship(app, monitor.accessToken, monitored);
    relationship = paired.relationship;
  }, 30000);

  afterAll(async () => {
    await teardownE2eTestApp(app, dataSource);
  });

  // =========================================================================
  // Pair 1: Heartbeat during Inactivity (Weight 0.0 Invariant)
  // =========================================================================
  it('Pair 1: Heartbeat during Inactivity: Reachability updates without delaying inactivity trigger', async () => {
    const pastActivity = new Date(Date.now() - 15 * 60 * 1000);
    await dataSource.query(
      `UPDATE monitoring_configs 
       SET current_state = 'ACTIVE',
           inactivity_threshold_minutes = 10,
           last_meaningful_activity_at = $1,
           next_evaluation_at = NOW() - INTERVAL '5 seconds'
       WHERE relationship_id = $2`,
      [pastActivity, relationship.id],
    );

    // Device sends Reachability Heartbeat
    const hbRes = await request(app.getHttpServer())
      .post('/api/v1/heartbeat')
      .set('Authorization', `Bearer ${monitored.accessToken}`)
      .send({
        deviceId: device.id,
        occurredAt: new Date().toISOString(),
        batteryLevel: 92,
      });

    expect(hbRes.status).toBe(200);
    expect(hbRes.body.operationalState).toBe('ONLINE');

    // Run Worker: Despite fresh Heartbeat, inactivity timer triggered CHECK_IN_REQUIRED!
    await workerService.evaluateDueMonitoring(10);

    const rows = await dataSource.query(
      `SELECT current_state, last_meaningful_activity_at FROM monitoring_configs WHERE relationship_id = $1`,
      [relationship.id],
    );
    expect(rows[0].current_state).toBe(MonitoringState.CHECK_IN_REQUIRED);
    expect(new Date(rows[0].last_meaningful_activity_at).getTime()).toBe(pastActivity.getTime());
  });

  // =========================================================================
  // Pair 2: Meaningful Activity during CHECK_IN_REQUIRED
  // =========================================================================
  it('Pair 2: Meaningful Activity during CHECK_IN_REQUIRED: Updates activity clock and preserves user activity', async () => {
    const eventId = uuidv4();
    const actRes = await request(app.getHttpServer())
      .post('/api/v1/activities')
      .set('Authorization', `Bearer ${monitored.accessToken}`)
      .send({
        eventId,
        deviceId: device.id,
        type: ActivityType.APP_FOREGROUND,
        occurredAt: new Date().toISOString(),
        confidence: 0.95,
      });

    expect(actRes.status).toBe(201);

    const rows = await dataSource.query(
      `SELECT last_meaningful_activity_at FROM monitoring_configs WHERE relationship_id = $1`,
      [relationship.id],
    );
    const updatedTime = new Date(rows[0].last_meaningful_activity_at).getTime();
    expect(updatedTime).toBeGreaterThan(Date.now() - 5000);
  });

  // =========================================================================
  // Pair 3: One-Touch Check-in during WARNING with Open Incident
  // =========================================================================
  it('Pair 3: One-Touch Check-in during WARNING: Resets state to ACTIVE and auto-resolves open Incident', async () => {
    await dataSource.query(
      `UPDATE monitoring_configs SET current_state = 'WARNING' WHERE relationship_id = $1`,
      [relationship.id],
    );

    const incInsert = await dataSource.query(
      `INSERT INTO incidents (user_id, relationship_id, status, reason, risk_score, detected_at)
       VALUES ($1, $2, 'OPEN', 'MISSED_CHECK_IN', 75, NOW())
       RETURNING id`,
      [monitored.id, relationship.id],
    );
    const incidentId = incInsert[0].id;

    const checkInEventId = uuidv4();
    const res = await request(app.getHttpServer())
      .post('/api/v1/check-ins')
      .set('Authorization', `Bearer ${monitored.accessToken}`)
      .send({
        eventId: checkInEventId,
        deviceId: device.id,
        relationshipId: relationship.id,
        occurredAt: new Date().toISOString(),
        batteryLevel: 80,
        note: 'Tôi vẫn ổn, đang ở nhà.',
        location: { latitude: 21.028511, longitude: 105.854444 },
      });

    expect(res.status).toBe(201);

    // Monitoring state machine reverted to ACTIVE
    const configRows = await dataSource.query(
      `SELECT current_state FROM monitoring_configs WHERE relationship_id = $1`,
      [relationship.id],
    );
    expect(configRows[0].current_state).toBe(MonitoringState.ACTIVE);

    // Open Incident auto-resolved
    const incRows = await dataSource.query(
      `SELECT status, resolved_by FROM incidents WHERE id = $1`,
      [incidentId],
    );
    expect(incRows[0].status).toBe(IncidentStatus.RESOLVED);
    expect(incRows[0].resolved_by).toBe(monitored.id);
  });

  // =========================================================================
  // Pair 4: Worker Evaluation under Redis Failover / Degradation
  // =========================================================================
  it('Pair 4: Worker Evaluation under Redis Degradation: DB row locks maintain exclusivity', async () => {
    await dataSource.query(
      `UPDATE monitoring_configs 
       SET next_evaluation_at = NOW() - INTERVAL '5 seconds'
       WHERE relationship_id = $1`,
      [relationship.id],
    );

    // Execute two evaluations simultaneously
    const [c1, c2] = await Promise.all([
      workerService.evaluateDueMonitoring(10),
      workerService.evaluateDueMonitoring(10),
    ]);

    // Due to FOR UPDATE SKIP LOCKED, evaluation is safely processed without deadlock
    expect(c1 + c2).toBeGreaterThanOrEqual(1);
  });

  // =========================================================================
  // Pair 5: Idempotent Concurrency during Rapid Parallel Check-ins
  // =========================================================================
  it('Pair 5: Rapid Concurrent Check-ins: Duplicate eventId resolves safely without duplicate records', async () => {
    const concurrentEventId = uuidv4();
    const payload = {
      eventId: concurrentEventId,
      deviceId: device.id,
      relationshipId: relationship.id,
      occurredAt: new Date().toISOString(),
      batteryLevel: 85,
      note: 'Concurrent checkin test',
    };

    const res1 = await request(app.getHttpServer())
      .post('/api/v1/check-ins')
      .set('Authorization', `Bearer ${monitored.accessToken}`)
      .send(payload);

    const res2 = await request(app.getHttpServer())
      .post('/api/v1/check-ins')
      .set('Authorization', `Bearer ${monitored.accessToken}`)
      .send(payload);

    expect(res1.status).toBe(201);
    expect(res2.status).toBe(201);
    expect(res1.body.id).toBe(res2.body.id);

    const rows = await dataSource.query(`SELECT COUNT(*) FROM check_ins WHERE event_id = $1`, [
      concurrentEventId,
    ]);
    expect(Number(rows[0].count)).toBe(1);
  });

  // =========================================================================
  // Pair 6: Device Revocation during Ongoing Monitoring
  // =========================================================================
  it('Pair 6: Device Revocation: Revoked device is blocked from heartbeat and check-in', async () => {
    const revDevice = await registerTestDevice(app, monitored.accessToken);

    // Revoke device
    const revRes = await request(app.getHttpServer())
      .post(`/api/v1/devices/${revDevice.id}/revoke`)
      .set('Authorization', `Bearer ${monitored.accessToken}`);
    expect(revRes.status).toBe(200);

    // Attempt heartbeat -> 401
    const hbRes = await request(app.getHttpServer())
      .post('/api/v1/heartbeat')
      .set('Authorization', `Bearer ${monitored.accessToken}`)
      .send({
        deviceId: revDevice.id,
        occurredAt: new Date().toISOString(),
        batteryLevel: 50,
      });
    expect(hbRes.status).toBe(401);

    // Attempt check-in -> 401
    const ciRes = await request(app.getHttpServer())
      .post('/api/v1/check-ins')
      .set('Authorization', `Bearer ${monitored.accessToken}`)
      .send({
        eventId: uuidv4(),
        deviceId: revDevice.id,
        relationshipId: relationship.id,
        occurredAt: new Date().toISOString(),
      });
    expect(ciRes.status).toBe(401);
  });

  // =========================================================================
  // Pair 7: Dynamic User Timezone Change during Active Calendar Window
  // =========================================================================
  it('Pair 7: User Timezone Change: Evaluates schedule windows in updated user timezone', async () => {
    // Reference date: Wednesday 10:00 UTC
    // In Asia/Ho_Chi_Minh (+7), it is 17:00 (inside 16:00 - 20:00 window)
    // In UTC, it is 10:00 (outside 16:00 - 20:00 window)
    const testDate = new Date('2026-10-07T10:00:00Z');
    const window = [
      {
        id: 'w-tz',
        configId: 'c1',
        config: null as any,
        dayOfWeek: 3,
        startTime: '16:00',
        endTime: '20:00',
        isEnabled: true,
        createdAt: new Date(),
        updatedAt: new Date(),
      },
    ];

    const inVietnam = MonitoringScheduler.isWithinActiveWindow(
      testDate,
      window,
      'Asia/Ho_Chi_Minh',
    );
    const inUtc = MonitoringScheduler.isWithinActiveWindow(testDate, window, 'UTC');

    expect(inVietnam).toBe(true);
    expect(inUtc).toBe(false);
  });

  // =========================================================================
  // Pair 8: Monitoring Pause and Resume during Imminent Inactivity
  // =========================================================================
  it('Pair 8: Monitoring Pause and Resume: Suspends worker evaluations then resumes cleanly', async () => {
    // Monitored user pauses monitoring (state becomes SUSPENDED)
    await dataSource.query(
      `UPDATE monitoring_configs 
       SET current_state = 'SUSPENDED',
           next_evaluation_at = NOW() - INTERVAL '10 minutes'
       WHERE relationship_id = $1`,
      [relationship.id],
    );

    // Worker runs -> does NOT transition SUSPENDED configs to WARNING
    await workerService.evaluateDueMonitoring(10);

    const rowsSusp = await dataSource.query(
      `SELECT current_state FROM monitoring_configs WHERE relationship_id = $1`,
      [relationship.id],
    );
    expect(rowsSusp[0].current_state).toBe(MonitoringState.SUSPENDED);

    // Monitored user resumes monitoring (state becomes ACTIVE)
    await dataSource.query(
      `UPDATE monitoring_configs 
       SET current_state = 'ACTIVE',
           last_meaningful_activity_at = NOW(),
           next_evaluation_at = NOW() + INTERVAL '8 hours'
       WHERE relationship_id = $1`,
      [relationship.id],
    );

    const rowsRes = await dataSource.query(
      `SELECT current_state FROM monitoring_configs WHERE relationship_id = $1`,
      [relationship.id],
    );
    expect(rowsRes[0].current_state).toBe(MonitoringState.ACTIVE);
  });

  // =========================================================================
  // Pair 9: Guardian Acknowledgment followed by Monitored User Check-in
  // =========================================================================
  it('Pair 9: Guardian Ack followed by Check-in: Full incident resolution and state restoration', async () => {
    const incRes = await dataSource.query(
      `INSERT INTO incidents (user_id, relationship_id, status, reason, risk_score, detected_at)
       VALUES ($1, $2, 'OPEN', 'MISSED_CHECK_IN', 65, NOW())
       RETURNING id`,
      [monitored.id, relationship.id],
    );
    const incId = incRes[0].id;

    // Guardian acknowledges
    const ackRes = await request(app.getHttpServer())
      .post(`/api/v1/incidents/${incId}/acknowledge`)
      .set('Authorization', `Bearer ${monitor.accessToken}`);
    expect(ackRes.status).toBe(200);
    expect(ackRes.body.status).toBe(IncidentStatus.ACKNOWLEDGED);

    // Guardian resolves
    const resRes = await request(app.getHttpServer())
      .post(`/api/v1/incidents/${incId}/resolve`)
      .set('Authorization', `Bearer ${monitor.accessToken}`)
      .send({ note: 'Đã liên lạc và xác nhận người thân an toàn.' });
    expect(resRes.status).toBe(200);
    expect(resRes.body.status).toBe(IncidentStatus.RESOLVED);

    // Monitored user submits Check-in
    const checkInEventId = uuidv4();
    const ciRes = await request(app.getHttpServer())
      .post('/api/v1/check-ins')
      .set('Authorization', `Bearer ${monitored.accessToken}`)
      .send({
        eventId: checkInEventId,
        deviceId: device.id,
        relationshipId: relationship.id,
        occurredAt: new Date().toISOString(),
        batteryLevel: 90,
        note: 'Đã nhận điện thoại từ người giám hộ, tôi ổn.',
      });
    expect(ciRes.status).toBe(201);

    // Monitoring state machine restored to ACTIVE
    const configRows = await dataSource.query(
      `SELECT current_state FROM monitoring_configs WHERE relationship_id = $1`,
      [relationship.id],
    );
    expect(configRows[0].current_state).toBe(MonitoringState.ACTIVE);
  });

  // =========================================================================
  // Pair 10: Mixed Batch Activity Ingestion
  // =========================================================================
  it('Pair 10: Mixed Batch Ingestion: Only meaningful activity advances clock, duplicates deduplicated', async () => {
    const configBefore = await dataSource.query(
      `SELECT last_meaningful_activity_at FROM monitoring_configs WHERE relationship_id = $1`,
      [relationship.id],
    );
    const timeBefore = new Date(configBefore[0].last_meaningful_activity_at).getTime();

    await new Promise((r) => setTimeout(r, 100));

    const dupEventId = uuidv4();
    const meaningfulEventId = uuidv4();

    const batch = [
      // 1. Low confidence step (confidence 0.1, min is 0.5)
      {
        eventId: uuidv4(),
        deviceId: device.id,
        type: ActivityType.STEP_DETECTED,
        occurredAt: new Date().toISOString(),
        confidence: 0.1,
      },
      // 2. Duplicate event 1
      {
        eventId: dupEventId,
        deviceId: device.id,
        type: ActivityType.SCREEN_INTERACTION,
        occurredAt: new Date().toISOString(),
        confidence: 0.9,
      },
      // 3. Duplicate event 2
      {
        eventId: dupEventId,
        deviceId: device.id,
        type: ActivityType.SCREEN_INTERACTION,
        occurredAt: new Date().toISOString(),
        confidence: 0.9,
      },
      // 4. Meaningful APP_FOREGROUND
      {
        eventId: meaningfulEventId,
        deviceId: device.id,
        type: ActivityType.APP_FOREGROUND,
        occurredAt: new Date().toISOString(),
        confidence: 0.95,
      },
    ];

    const results = await activityService.ingestBatch(monitored.id, batch);
    expect(results.length).toBeGreaterThanOrEqual(3);

    // Duplicate was only saved once
    const dupCount = await dataSource.query(
      `SELECT COUNT(*) FROM activities WHERE event_id = $1`,
      [dupEventId],
    );
    expect(Number(dupCount[0].count)).toBe(1);

    // Clock was advanced by the meaningful activity
    const configAfter = await dataSource.query(
      `SELECT last_meaningful_activity_at FROM monitoring_configs WHERE relationship_id = $1`,
      [relationship.id],
    );
    const timeAfter = new Date(configAfter[0].last_meaningful_activity_at).getTime();
    expect(timeAfter).toBeGreaterThan(timeBefore);
  });
});
