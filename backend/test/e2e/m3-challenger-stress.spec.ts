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
  DevicePlatform,
  IncidentStatus,
  MonitoringState,
} from '../../src/common/enums';
import { MonitoringWorkerService } from '../../src/modules/workers/monitoring-worker.service';

describe('Milestone 3 Challenger Empirical Stress Tests: Feature 32 & Feature 33', () => {
  let app: INestApplication;
  let dataSource: DataSource;
  let workerService: MonitoringWorkerService;

  let monitorUser: TestUserContext;
  let monitoredUser: TestUserContext;
  let monitoredDevice: any;
  let relationship: any;

  beforeAll(async () => {
    const context = await createE2eTestApp();
    app = context.app;
    dataSource = context.dataSource;
    workerService = context.moduleFixture.get<MonitoringWorkerService>(MonitoringWorkerService);

    await resetDatabase(dataSource);

    // Setup base users
    monitoredUser = await registerAndLoginUser(app, 'stress_monitored');
    monitorUser = await registerAndLoginUser(app, 'stress_guardian');

    monitoredDevice = await registerTestDevice(app, monitoredUser.accessToken, {
      deviceName: 'Stress Test Device',
      platform: DevicePlatform.ANDROID,
    });

    // Pair relationship
    const inviteRes = await request(app.getHttpServer())
      .post('/api/v1/monitoring/relationships')
      .set('Authorization', `Bearer ${monitorUser.accessToken}`)
      .send({ monitoredUserEmail: monitoredUser.email });
    expect(inviteRes.status).toBe(201);

    const acceptRes = await request(app.getHttpServer())
      .post('/api/v1/monitoring/relationships/accept')
      .set('Authorization', `Bearer ${monitoredUser.accessToken}`)
      .send({ invitationCode: inviteRes.body.invitationCode });
    expect(acceptRes.status).toBe(200);
    relationship = acceptRes.body;

    // Thresholds: 1 min inactivity, 1 min grace, 1 min warning
    await request(app.getHttpServer())
      .patch(`/api/v1/monitoring/${relationship.id}/config`)
      .set('Authorization', `Bearer ${monitoredUser.accessToken}`)
      .send({
        inactivityThresholdMinutes: 1,
        checkInGraceMinutes: 1,
        warningEscalationMinutes: 1,
      });
  }, 30000);

  afterAll(async () => {
    await teardownE2eTestApp(app, dataSource);
  });

  // =========================================================================
  // CHALLENGE 1: Feature 33 Stress Tests (Ack, Resolve, Restoration, Edge Cases)
  // =========================================================================
  describe('Challenge 1: Feature 33 Incident Acknowledgment & Resolution Edge Cases', () => {
    let incidentId: string;

    it('1.1 Trigger incident into ESCALATED state for edge case testing', async () => {
      // Set inactivity
      const past = new Date(Date.now() - 3 * 60 * 1000);
      await dataSource.query(
        `UPDATE monitoring_configs 
         SET current_state = 'ACTIVE',
             last_meaningful_activity_at = $1,
             next_evaluation_at = NOW() - INTERVAL '10 seconds'
         WHERE relationship_id = $2`,
        [past, relationship.id],
      );

      // Tick 1 -> CHECK_IN_REQUIRED
      await workerService.evaluateDueMonitoring(10);
      // Advance to grace timeout
      await dataSource.query(
        `UPDATE monitoring_configs SET next_evaluation_at = NOW() - INTERVAL '10 seconds' WHERE relationship_id = $1`,
        [relationship.id],
      );
      // Tick 2 -> WARNING & Incident created
      await workerService.evaluateDueMonitoring(10);

      const incs = await dataSource.query(
        `SELECT id, status FROM incidents WHERE relationship_id = $1 AND status = 'OPEN'`,
        [relationship.id],
      );
      expect(incs.length).toBe(1);
      incidentId = incs[0].id;

      // Advance to warning escalation
      await dataSource.query(
        `UPDATE monitoring_configs SET next_evaluation_at = NOW() - INTERVAL '10 seconds' WHERE relationship_id = $1`,
        [relationship.id],
      );
      // Tick 3 -> ESCALATED
      await workerService.evaluateDueMonitoring(10);

      const escCheck = await dataSource.query(`SELECT status FROM incidents WHERE id = $1`, [incidentId]);
      expect(escCheck[0].status).toBe(IncidentStatus.ESCALATED);
    });

    it('1.2 Double Acknowledgment stress test', async () => {
      // First acknowledgment
      const ack1 = await request(app.getHttpServer())
        .post(`/api/v1/incidents/${incidentId}/acknowledge`)
        .set('Authorization', `Bearer ${monitorUser.accessToken}`);
      expect(ack1.status).toBe(200);
      expect(ack1.body.status).toBe(IncidentStatus.ACKNOWLEDGED);

      // Config state should be ACKNOWLEDGED
      const cfg1 = await dataSource.query(
        `SELECT current_state FROM monitoring_configs WHERE relationship_id = $1`,
        [relationship.id],
      );
      expect(cfg1[0].current_state).toBe(MonitoringState.ACKNOWLEDGED);

      // Wait 50ms then second acknowledgment
      await new Promise((r) => setTimeout(r, 50));
      const ack2 = await request(app.getHttpServer())
        .post(`/api/v1/incidents/${incidentId}/acknowledge`)
        .set('Authorization', `Bearer ${monitorUser.accessToken}`);

      // Self-transition ACKNOWLEDGED -> ACKNOWLEDGED succeeds without crashing
      expect(ack2.status).toBe(200);
      expect(ack2.body.status).toBe(IncidentStatus.ACKNOWLEDGED);

      // Monitoring config still in ACKNOWLEDGED
      const cfg2 = await dataSource.query(
        `SELECT current_state FROM monitoring_configs WHERE relationship_id = $1`,
        [relationship.id],
      );
      expect(cfg2[0].current_state).toBe(MonitoringState.ACKNOWLEDGED);
    });

    it('1.3 Incident Resolution restores Monitoring Config to ACTIVE with future nextEvaluationAt', async () => {
      const beforeResolve = Date.now();
      const res = await request(app.getHttpServer())
        .post(`/api/v1/incidents/${incidentId}/resolve`)
        .set('Authorization', `Bearer ${monitorUser.accessToken}`)
        .send({ note: 'Resolved by guardian test' });

      expect(res.status).toBe(200);
      expect(res.body.status).toBe(IncidentStatus.RESOLVED);

      // Verify config restoration
      const cfgRows = await dataSource.query(
        `SELECT current_state, last_meaningful_activity_at, next_evaluation_at, inactivity_threshold_minutes 
         FROM monitoring_configs WHERE relationship_id = $1`,
        [relationship.id],
      );
      const cfg = cfgRows[0];
      expect(cfg.current_state).toBe(MonitoringState.ACTIVE);

      const lastActivityTime = new Date(cfg.last_meaningful_activity_at).getTime();
      expect(lastActivityTime).toBeGreaterThanOrEqual(beforeResolve - 1000);

      const nextEvalTime = new Date(cfg.next_evaluation_at).getTime();
      // nextEvaluationAt must be approximately now + 1 min (inactivityThresholdMinutes = 1)
      expect(nextEvalTime).toBeGreaterThan(Date.now());
      expect(nextEvalTime - lastActivityTime).toBe(cfg.inactivity_threshold_minutes * 60 * 1000);
    });

    it('1.4 Acknowledgment on an already RESOLVED incident must be REJECTED (400 Bad Request)', async () => {
      // An incident in RESOLVED state cannot transition back to ACKNOWLEDGED
      const ackOnResolved = await request(app.getHttpServer())
        .post(`/api/v1/incidents/${incidentId}/acknowledge`)
        .set('Authorization', `Bearer ${monitorUser.accessToken}`);

      expect(ackOnResolved.status).toBe(400);
      expect(ackOnResolved.body.message).toContain('Invalid incident transition');
    });

    it('1.5 Resolution on already RESOLVED incident is idempotent without breaking ACTIVE state', async () => {
      const res2 = await request(app.getHttpServer())
        .post(`/api/v1/incidents/${incidentId}/resolve`)
        .set('Authorization', `Bearer ${monitorUser.accessToken}`)
        .send({ note: 'Second resolve attempt' });

      expect(res2.status).toBe(200);
      expect(res2.body.status).toBe(IncidentStatus.RESOLVED);

      const cfgRows = await dataSource.query(
        `SELECT current_state FROM monitoring_configs WHERE relationship_id = $1`,
        [relationship.id],
      );
      expect(cfgRows[0].current_state).toBe(MonitoringState.ACTIVE);
    });

    it('1.6 Acknowledgment or Resolution on CANCELLED incident must be REJECTED (400 Bad Request)', async () => {
      // Create a dummy cancelled incident
      const dummyIncId = uuidv4();
      await dataSource.query(
        `INSERT INTO incidents (id, user_id, relationship_id, status, risk_score, reason, detected_at, created_at, updated_at)
         VALUES ($1, $2, $3, 'CANCELLED', 10, 'MANUAL_ALERT', NOW(), NOW(), NOW())`,
        [dummyIncId, monitoredUser.id, relationship.id],
      );

      // Attempt acknowledge
      const ackRes = await request(app.getHttpServer())
        .post(`/api/v1/incidents/${dummyIncId}/acknowledge`)
        .set('Authorization', `Bearer ${monitorUser.accessToken}`);
      expect(ackRes.status).toBe(400);

      // Attempt resolve
      const resolveRes = await request(app.getHttpServer())
        .post(`/api/v1/incidents/${dummyIncId}/resolve`)
        .set('Authorization', `Bearer ${monitorUser.accessToken}`)
        .send({ note: 'Attempting resolve on cancelled' });
      expect(resolveRes.status).toBe(400);
    });

    it('1.7 Resolution does NOT overwrite SUSPENDED monitoring config state', async () => {
      // Create a new incident while config is suspended
      const dummyInc2Id = uuidv4();
      await dataSource.query(
        `INSERT INTO incidents (id, user_id, relationship_id, status, risk_score, reason, detected_at, created_at, updated_at)
         VALUES ($1, $2, $3, 'OPEN', 60, 'MISSED_CHECK_IN', NOW(), NOW(), NOW())`,
        [dummyInc2Id, monitoredUser.id, relationship.id],
      );

      // Suspend monitoring config
      await dataSource.query(
        `UPDATE monitoring_configs SET current_state = 'SUSPENDED' WHERE relationship_id = $1`,
        [relationship.id],
      );

      // Resolve incident
      const resolveRes = await request(app.getHttpServer())
        .post(`/api/v1/incidents/${dummyInc2Id}/resolve`)
        .set('Authorization', `Bearer ${monitorUser.accessToken}`)
        .send({ note: 'Resolving while suspended' });
      expect(resolveRes.status).toBe(200);

      // Invariant: Monitoring config MUST REMAIN SUSPENDED!
      const cfgRows = await dataSource.query(
        `SELECT current_state FROM monitoring_configs WHERE relationship_id = $1`,
        [relationship.id],
      );
      expect(cfgRows[0].current_state).toBe(MonitoringState.SUSPENDED);

      // Restore config back to ACTIVE for subsequent tests
      await dataSource.query(
        `UPDATE monitoring_configs SET current_state = 'ACTIVE' WHERE relationship_id = $1`,
        [relationship.id],
      );
    });
  });

  // =========================================================================
  // CHALLENGE 2: Feature 32 Stress Tests (Offline Replay & Clock Invariants)
  // =========================================================================
  describe('Challenge 2: Feature 32 Offline Replay, Monotonic Clock & Heartbeat Isolation', () => {
    it('2.1 Historical check-in predating an active incident MUST NOT auto-resolve the incident', async () => {
      // 1. Create an active OPEN incident with detected_at = NOW()
      const incidentTime = new Date();
      const activeIncId = uuidv4();
      await dataSource.query(
        `INSERT INTO incidents (id, user_id, relationship_id, status, risk_score, reason, detected_at, created_at, updated_at)
         VALUES ($1, $2, $3, 'OPEN', 70, 'MISSED_CHECK_IN', $4, $4, $4)`,
        [activeIncId, monitoredUser.id, relationship.id, incidentTime],
      );

      // 2. An offline check-in arrives with occurredAt = incidentTime - 15 minutes (stale packet from queue)
      const staleOccurredAt = new Date(incidentTime.getTime() - 15 * 60 * 1000);
      const staleEventId = uuidv4();

      const ciRes = await request(app.getHttpServer())
        .post('/api/v1/check-ins')
        .set('Authorization', `Bearer ${monitoredUser.accessToken}`)
        .send({
          eventId: staleEventId,
          deviceId: monitoredDevice.id,
          relationshipId: relationship.id,
          occurredAt: staleOccurredAt.toISOString(),
          note: 'Stale offline check-in from 15 minutes ago',
        });

      expect([200, 201]).toContain(ciRes.status);

      // Check-in saved for audit
      const ciAudit = await dataSource.query(`SELECT id FROM check_ins WHERE event_id = $1`, [staleEventId]);
      expect(ciAudit.length).toBe(1);

      // CRITICAL INVARIANT: The active incident MUST NOT be resolved by this stale check-in!
      const incCheck = await dataSource.query(`SELECT status FROM incidents WHERE id = $1`, [activeIncId]);
      expect(incCheck[0].status).toBe(IncidentStatus.OPEN);

      // Clean up test incident
      await dataSource.query(`DELETE FROM incidents WHERE id = $1`, [activeIncId]);
    });

    it('2.2 Out-of-order delayed check-in MUST NOT roll back server lastMeaningfulActivityAt or nextEvaluationAt', async () => {
      // Set current lastMeaningfulActivityAt to T_anchor
      const anchorTime = new Date('2026-10-07T12:00:00.000Z');
      const expectedNextEval = new Date(anchorTime.getTime() + 1 * 60 * 1000);
      await dataSource.query(
        `UPDATE monitoring_configs 
         SET last_meaningful_activity_at = $1,
             next_evaluation_at = $2,
             current_state = 'ACTIVE'
         WHERE relationship_id = $3`,
        [anchorTime, expectedNextEval, relationship.id],
      );

      // Delayed check-in from 1 hour prior arrives (T_delayed = 11:00:00)
      const delayedTime = new Date('2026-10-07T11:00:00.000Z');
      const delayedEventId = uuidv4();

      const res = await request(app.getHttpServer())
        .post('/api/v1/check-ins')
        .set('Authorization', `Bearer ${monitoredUser.accessToken}`)
        .send({
          eventId: delayedEventId,
          deviceId: monitoredDevice.id,
          relationshipId: relationship.id,
          occurredAt: delayedTime.toISOString(),
          note: 'Out-of-order delayed check-in',
        });
      expect([200, 201]).toContain(res.status);

      // Verify server clock did NOT roll back
      const cfg = (
        await dataSource.query(
          `SELECT last_meaningful_activity_at, next_evaluation_at FROM monitoring_configs WHERE relationship_id = $1`,
          [relationship.id],
        )
      )[0];

      const actualLast = new Date(cfg.last_meaningful_activity_at).getTime();
      const actualNext = new Date(cfg.next_evaluation_at).getTime();

      expect(actualLast).toBe(anchorTime.getTime());
      expect(actualNext).toBe(expectedNextEval.getTime());
    });

    it('2.3 Future timestamp clamping: Client clock 1 hour in future is clamped to <= server NOW + 5m', async () => {
      const futureTime = new Date(Date.now() + 60 * 60 * 1000); // +1 hour into future
      const futureEventId = uuidv4();

      const res = await request(app.getHttpServer())
        .post('/api/v1/check-ins')
        .set('Authorization', `Bearer ${monitoredUser.accessToken}`)
        .send({
          eventId: futureEventId,
          deviceId: monitoredDevice.id,
          relationshipId: relationship.id,
          occurredAt: futureTime.toISOString(),
          note: 'Clock skew attack / bad client time',
        });
      expect([200, 201]).toContain(res.status);

      // Check persisted occurred_at in check_ins
      const ci = (
        await dataSource.query(`SELECT occurred_at FROM check_ins WHERE event_id = $1`, [futureEventId])
      )[0];

      const savedOccurredAt = new Date(ci.occurred_at).getTime();
      // Must be clamped to approximately server NOW (within 5 seconds), NOT 1 hour in the future!
      expect(savedOccurredAt).toBeLessThan(Date.now() + 10000);
    });

    it('2.4 Heartbeat (Weight 0.0) telemetry isolation: Continuous heartbeats DO NOT prevent inactivity escalation', async () => {
      // Anchor activity 2 minutes ago (threshold is 1 min)
      const pastTime = new Date(Date.now() - 2 * 60 * 1000);
      await dataSource.query(
        `UPDATE monitoring_configs 
         SET current_state = 'ACTIVE',
             last_meaningful_activity_at = $1,
             next_evaluation_at = NOW() - INTERVAL '5 seconds'
         WHERE relationship_id = $2`,
        [pastTime, relationship.id],
      );

      // Device registers reachability heartbeats
      const hbDevice = await registerTestDevice(app, monitoredUser.accessToken, {
        deviceName: 'Active Ping Device',
        platform: DevicePlatform.ANDROID,
      });

      const hbRes = await request(app.getHttpServer())
        .post('/api/v1/heartbeat')
        .set('Authorization', `Bearer ${monitoredUser.accessToken}`)
        .send({
          deviceId: hbDevice.id,
          occurredAt: new Date().toISOString(),
          batteryLevel: 95,
          isCharging: true,
        });
      expect(hbRes.status).toBe(200);

      // Inactivity Worker tick
      const processed = await workerService.evaluateDueMonitoring(10);
      expect(processed).toBeGreaterThanOrEqual(1);

      // CRITICAL INVARIANT: Monitoring transitioned to CHECK_IN_REQUIRED despite active reachability heartbeats!
      // This empirically proves that reachability (weight 0.0) never resets human inactivity!
      const cfg = (
        await dataSource.query(`SELECT current_state FROM monitoring_configs WHERE relationship_id = $1`, [
          relationship.id,
        ])
      )[0];
      expect(cfg.current_state).toBe(MonitoringState.CHECK_IN_REQUIRED);
    });

    it('2.5 Idempotent check-in re-send returns original check-in with 200/201 and creates NO duplicates', async () => {
      const fixedEventId = uuidv4();
      const payload = {
        eventId: fixedEventId,
        deviceId: monitoredDevice.id,
        relationshipId: relationship.id,
        occurredAt: new Date().toISOString(),
        note: 'Idempotent test note',
      };

      const res1 = await request(app.getHttpServer())
        .post('/api/v1/check-ins')
        .set('Authorization', `Bearer ${monitoredUser.accessToken}`)
        .send(payload);
      expect([200, 201]).toContain(res1.status);

      // Send identical payload again
      const res2 = await request(app.getHttpServer())
        .post('/api/v1/check-ins')
        .set('Authorization', `Bearer ${monitoredUser.accessToken}`)
        .send(payload);
      expect([200, 201]).toContain(res2.status);
      expect(res2.body.id).toBe(res1.body.id);

      // Count check_in records in DB with this eventId
      const count = await dataSource.query(`SELECT COUNT(*)::int as count FROM check_ins WHERE event_id = $1`, [
        fixedEventId,
      ]);
      expect(count[0].count).toBe(1);

      // Count activity records in DB with this eventId
      const actCount = await dataSource.query(`SELECT COUNT(*)::int as count FROM activities WHERE event_id = $1`, [
        fixedEventId,
      ]);
      expect(actCount[0].count).toBe(1);
    });
  });
});
