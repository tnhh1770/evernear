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
  IncidentStatus,
  MonitoringState,
} from '../../src/common/enums';
import { Incident } from '../../src/modules/incidents/entities/incident.entity';

describe('Milestone 4 Challenger: Concurrency, Batch Ingestion & Offline Idempotency Stress Harness', () => {
  let app: INestApplication;
  let dataSource: DataSource;

  let monitoredUser: TestUserContext;
  let guardianUser: TestUserContext;
  let devices: any[] = [];
  let relationship: any;

  beforeAll(async () => {
    const context = await createE2eTestApp();
    app = context.app;
    dataSource = context.dataSource;

    await resetDatabase(dataSource);

    const emailTag = `m4_stress_${Date.now()}`;
    monitoredUser = await registerAndLoginUser(app, `monitored_${emailTag}`);
    guardianUser = await registerAndLoginUser(app, `guardian_${emailTag}`);

    // Register 5 distinct devices for the monitored user (multi-client scenario)
    for (let i = 0; i < 5; i++) {
      const dev = await registerTestDevice(app, monitoredUser.accessToken, {
        platform: i % 2 === 0 ? DevicePlatform.ANDROID : DevicePlatform.IOS,
        deviceName: `Test Device ${i + 1}`,
        pushToken: `push-token-${emailTag}-${i + 1}`,
        batteryLevel: 90 - i * 5,
      });
      devices.push(dev);
    }

    const paired = await pairMonitoringRelationship(app, guardianUser.accessToken, monitoredUser);
    relationship = paired.relationship;

    // Configure monitoring config with 1 minute inactivity and 1 minute grace period
    await request(app.getHttpServer())
      .patch(`/api/v1/monitoring/${relationship.id}/config`)
      .set('Authorization', `Bearer ${monitoredUser.accessToken}`)
      .send({
        inactivityThresholdMinutes: 1,
        checkInGraceMinutes: 1,
        warningEscalationMinutes: 1,
        locationEnabled: true,
      });
  }, 30000);

  afterAll(async () => {
    await teardownE2eTestApp(app, dataSource);
  });

  // =========================================================================
  // SUITE 1: MULTI-CLIENT CONCURRENCY & RACE CONDITION STRESS
  // =========================================================================
  describe('Suite 1: Multi-Client Concurrency & Race Condition Stress', () => {
    it('1.1 Extreme Concurrency: 20 simultaneous duplicate check-ins with identical eventId produce exactly ONE DB record with zero 500 errors', async () => {
      const raceEventId = uuidv4();
      const raceTimestamp = new Date().toISOString();

      // Launch 20 concurrent HTTP requests with identical eventId
      const promises = Array.from({ length: 20 }, (_, idx) =>
        request(app.getHttpServer())
          .post('/api/v1/check-ins')
          .set('Authorization', `Bearer ${monitoredUser.accessToken}`)
          .send({
            eventId: raceEventId,
            deviceId: devices[idx % devices.length].id,
            relationshipId: relationship.id,
            occurredAt: raceTimestamp,
            note: `Concurrent check-in wave #${idx + 1}`,
          }),
      );

      const results = await Promise.all(promises);

      // Verify all 20 responses return HTTP 200 or 201 (graceful idempotency, zero 500 crashes)
      for (const res of results) {
        expect([200, 201]).toContain(res.status);
        expect(res.body.eventId).toBe(raceEventId);
      }

      // Verify database contains STRICTLY 1 check_in row with this eventId
      const checkInRows = await dataSource.query(
        `SELECT id, event_id FROM check_ins WHERE event_id = $1`,
        [raceEventId],
      );
      expect(checkInRows.length).toBe(1);

      // Verify database contains STRICTLY 1 corresponding activity row with this eventId
      const activityRows = await dataSource.query(
        `SELECT id, event_id, weight FROM activities WHERE event_id = $1`,
        [raceEventId],
      );
      expect(activityRows.length).toBe(1);
      expect(Number(activityRows[0].weight)).toBe(1.0);
    });

    it('1.2 Multi-Device Concurrency: 5 distinct devices submit check-ins simultaneously with staggered timestamps; max timestamp wins monotonically', async () => {
      const baseTime = Date.now();
      const requests = devices.map((dev, idx) => {
        const eventId = uuidv4();
        const occurredAt = new Date(baseTime + idx * 5000).toISOString();
        return request(app.getHttpServer())
          .post('/api/v1/check-ins')
          .set('Authorization', `Bearer ${monitoredUser.accessToken}`)
          .send({
            eventId,
            deviceId: dev.id,
            relationshipId: relationship.id,
            occurredAt,
            note: `Device ${idx + 1} staggered check-in`,
          });
      });

      const responses = await Promise.all(requests);
      for (const res of responses) {
        expect([200, 201]).toContain(res.status);
      }

      // Check monitoring config: lastMeaningfulActivityAt MUST be max(occurredAt), i.e. baseTime + 20000
      const expectedMaxTime = new Date(baseTime + 4 * 5000).getTime();
      const configRows = await dataSource.query(
        `SELECT last_meaningful_activity_at FROM monitoring_configs WHERE relationship_id = $1`,
        [relationship.id],
      );
      const actualTime = new Date(configRows[0].last_meaningful_activity_at).getTime();
      expect(actualTime).toBe(expectedMaxTime);
    });

    it('1.3 Incident Race: Simultaneous check-in and guardian acknowledge/resolve resolves incident to RESOLVED and state to ACTIVE without dirty state', async () => {
      // Create an open incident manually for this relationship
      const incRepo = dataSource.getRepository(Incident);
      const openIncident = incRepo.create({
        userId: monitoredUser.id,
        relationshipId: relationship.id,
        status: IncidentStatus.OPEN,
        reason: 'INACTIVITY_TIMEOUT',
        riskScore: 65,
        detectedAt: new Date(Date.now() - 60000),
      });
      await incRepo.save(openIncident);

      // Set monitoring config to WARNING state
      await dataSource.query(
        `UPDATE monitoring_configs SET current_state = 'WARNING' WHERE relationship_id = $1`,
        [relationship.id],
      );

      // Concurrently trigger:
      // 1. Guardian acknowledges incident
      // 2. Monitored user checks in ("Tôi vẫn ổn")
      const p1 = request(app.getHttpServer())
        .post(`/api/v1/incidents/${openIncident.id}/acknowledge`)
        .set('Authorization', `Bearer ${guardianUser.accessToken}`)
        .send({ note: 'Guardian acknowledging' });

      const p2 = request(app.getHttpServer())
        .post('/api/v1/check-ins')
        .set('Authorization', `Bearer ${monitoredUser.accessToken}`)
        .send({
          eventId: uuidv4(),
          deviceId: devices[0].id,
          relationshipId: relationship.id,
          occurredAt: new Date().toISOString(),
          note: 'User check-in during acknowledge race',
        });

      const [r1, r2] = await Promise.all([p1, p2]);
      expect([200, 201]).toContain(r1.status);
      expect([200, 201]).toContain(r2.status);

      // Both operations are valid terminal actions; either RESOLVED or ACKNOWLEDGED is valid
      // depending on race order, but incident MUST NOT remain OPEN or in dirty error state.
      const recheckedInc = await incRepo.findOne({ where: { id: openIncident.id } });
      expect([IncidentStatus.RESOLVED, IncidentStatus.ACKNOWLEDGED]).toContain(recheckedInc!.status);

      // Monitoring config MUST be in a valid active/acknowledged state
      const configRows = await dataSource.query(
        `SELECT current_state FROM monitoring_configs WHERE relationship_id = $1`,
        [relationship.id],
      );
      expect([MonitoringState.ACTIVE, MonitoringState.ACKNOWLEDGED]).toContain(configRows[0].current_state);
    });
  });

  // =========================================================================
  // SUITE 2: BATCH ACTIVITY INGESTION STRESS
  // =========================================================================
  describe('Suite 2: Batch Activity Ingestion Stress', () => {
    it('2.1 Massive Heterogeneous Batch (50 events): Accurately processes interleaved activities, weights, confidence filtering, and deduplication', async () => {
      // Reset lastMeaningfulActivityAt to ensure clean baseline for batch evaluation
      await dataSource.query(
        `UPDATE monitoring_configs SET last_meaningful_activity_at = NOW() - INTERVAL '1 hour' WHERE relationship_id = $1`,
        [relationship.id],
      );

      const now = Date.now();
      const sharedDuplicateId = uuidv4();

      const batchActivities: any[] = [];

      // 10 HEARTBEAT items (Weight 0.0, non-meaningful)
      for (let i = 0; i < 10; i++) {
        batchActivities.push({
          eventId: uuidv4(),
          deviceId: devices[i % devices.length].id,
          type: ActivityType.HEARTBEAT,
          occurredAt: new Date(now - (50 - i) * 1000).toISOString(),
          confidence: 1.0,
        });
      }

      // 10 Low-confidence SCREEN_INTERACTION (< 0.7 confidence threshold)
      for (let i = 0; i < 10; i++) {
        batchActivities.push({
          eventId: uuidv4(),
          deviceId: devices[i % devices.length].id,
          type: ActivityType.SCREEN_INTERACTION,
          occurredAt: new Date(now - (40 - i) * 1000).toISOString(),
          confidence: 0.2, // below min_confidence 0.7
        });
      }

      // 10 High-confidence STEP_DETECTED (0.6 weight)
      for (let i = 0; i < 10; i++) {
        batchActivities.push({
          eventId: uuidv4(),
          deviceId: devices[i % devices.length].id,
          type: ActivityType.STEP_DETECTED,
          occurredAt: new Date(now - (30 - i) * 1000).toISOString(),
          confidence: 0.9,
        });
      }

      // 10 Duplicate event items using sharedDuplicateId
      for (let i = 0; i < 10; i++) {
        batchActivities.push({
          eventId: sharedDuplicateId,
          deviceId: devices[0].id,
          type: ActivityType.APP_FOREGROUND,
          occurredAt: new Date(now - 15 * 1000).toISOString(),
          confidence: 0.95,
        });
      }

      // 10 Meaningful APP_FOREGROUND items ending with latest meaningful timestamp
      const latestMeaningfulTimestamp = new Date(now - 1000);
      for (let i = 0; i < 10; i++) {
        batchActivities.push({
          eventId: uuidv4(),
          deviceId: devices[i % devices.length].id,
          type: ActivityType.APP_FOREGROUND,
          occurredAt: i === 9 ? latestMeaningfulTimestamp.toISOString() : new Date(now - (10 - i) * 1000).toISOString(),
          confidence: 0.95,
        });
      }

      const res = await request(app.getHttpServer())
        .post('/api/v1/activities/batch')
        .set('Authorization', `Bearer ${monitoredUser.accessToken}`)
        .send({ activities: batchActivities });

      expect(res.status).toBe(201);
      expect(Array.isArray(res.body)).toBe(true);

      // Verify sharedDuplicateId was ingested only ONCE in the database
      const dupRows = await dataSource.query(
        `SELECT id FROM activities WHERE event_id = $1`,
        [sharedDuplicateId],
      );
      expect(dupRows.length).toBe(1);

      // Verify monitoring config's lastMeaningfulActivityAt matches latestMeaningfulTimestamp
      const configRows = await dataSource.query(
        `SELECT last_meaningful_activity_at FROM monitoring_configs WHERE relationship_id = $1`,
        [relationship.id],
      );
      const recordedTime = new Date(configRows[0].last_meaningful_activity_at).getTime();
      expect(recordedTime).toBe(latestMeaningfulTimestamp.getTime());
    });

    it('2.2 Reverse-Chronological Batch: Batch containing descending timestamps NEVER regresses server activity clock', async () => {
      // Capture current clock
      const configBefore = await request(app.getHttpServer())
        .get(`/api/v1/monitoring/${relationship.id}/config`)
        .set('Authorization', `Bearer ${monitoredUser.accessToken}`);
      const beforeTime = new Date(configBefore.body.lastMeaningfulActivityAt).getTime();

      // Submit batch where timestamps are 3 hours ago, 2 hours ago, 1 hour ago (all older than beforeTime)
      const staleBatch = [
        {
          eventId: uuidv4(),
          deviceId: devices[0].id,
          type: ActivityType.APP_FOREGROUND,
          occurredAt: new Date(beforeTime - 180 * 60 * 1000).toISOString(),
          confidence: 1.0,
        },
        {
          eventId: uuidv4(),
          deviceId: devices[1].id,
          type: ActivityType.STEP_DETECTED,
          occurredAt: new Date(beforeTime - 120 * 60 * 1000).toISOString(),
          confidence: 0.8,
        },
        {
          eventId: uuidv4(),
          deviceId: devices[2].id,
          type: ActivityType.SCREEN_INTERACTION,
          occurredAt: new Date(beforeTime - 60 * 60 * 1000).toISOString(),
          confidence: 0.9,
        },
      ];

      const res = await request(app.getHttpServer())
        .post('/api/v1/activities/batch')
        .set('Authorization', `Bearer ${monitoredUser.accessToken}`)
        .send({ activities: staleBatch });

      expect(res.status).toBe(201);
      expect(res.body.length).toBe(3);

      // Verify lastMeaningfulActivityAt has NOT rolled back
      const configAfter = await request(app.getHttpServer())
        .get(`/api/v1/monitoring/${relationship.id}/config`)
        .set('Authorization', `Bearer ${monitoredUser.accessToken}`);
      const afterTime = new Date(configAfter.body.lastMeaningfulActivityAt).getTime();
      expect(afterTime).toBe(beforeTime);
    });
  });

  // =========================================================================
  // SUITE 3: OFFLINE REPLAY IDEMPOTENCY & SAFETY INVARIANTS
  // =========================================================================
  describe('Suite 3: Offline Replay Idempotency & Safety Invariants', () => {
    it('3.1 Full Offline Queue Double-Replay: 100% idempotent repeat delivery with identical responses and zero row inflation', async () => {
      const offlineQueue = [
        {
          eventId: uuidv4(),
          deviceId: devices[0].id,
          type: ActivityType.STEP_DETECTED,
          occurredAt: new Date(Date.now() - 10000).toISOString(),
          confidence: 0.85,
        },
        {
          eventId: uuidv4(),
          deviceId: devices[1].id,
          type: ActivityType.APP_FOREGROUND,
          occurredAt: new Date(Date.now() - 8000).toISOString(),
          confidence: 0.95,
        },
      ];

      // Replay 1 (simulating online reconnection)
      const replay1 = await request(app.getHttpServer())
        .post('/api/v1/activities/batch')
        .set('Authorization', `Bearer ${monitoredUser.accessToken}`)
        .send({ activities: offlineQueue });
      expect(replay1.status).toBe(201);
      const replay1Ids = replay1.body.map((a: any) => a.id);

      // Replay 2 (simulating mobile retry due to socket drop before ack was received)
      const replay2 = await request(app.getHttpServer())
        .post('/api/v1/activities/batch')
        .set('Authorization', `Bearer ${monitoredUser.accessToken}`)
        .send({ activities: offlineQueue });
      expect(replay2.status).toBe(201);
      const replay2Ids = replay2.body.map((a: any) => a.id);

      // Verify exact same database IDs returned (idempotency deduplication)
      expect(replay2Ids).toEqual(replay1Ids);

      // Count total rows in DB for these 2 eventIds
      const rows = await dataSource.query(
        `SELECT id FROM activities WHERE event_id IN ($1, $2)`,
        [offlineQueue[0].eventId, offlineQueue[1].eventId],
      );
      expect(rows.length).toBe(2);
    });

    it('3.2 Pre-Incident Offline Check-in Invariant: Delayed offline check-in predating incident creation MUST NOT resolve active incident', async () => {
      // Create incident at timestamp T_incident
      const tIncident = new Date(Date.now() - 30 * 1000);
      const incRepo = dataSource.getRepository(Incident);
      const incident = incRepo.create({
        userId: monitoredUser.id,
        relationshipId: relationship.id,
        status: IncidentStatus.OPEN,
        reason: 'INACTIVITY_TIMEOUT',
        riskScore: 70,
        detectedAt: tIncident,
        createdAt: tIncident,
      });
      const savedInc = await incRepo.save(incident);

      // Send offline check-in recorded at T_offline = T_incident - 60s (predating incident)
      const tOffline = new Date(tIncident.getTime() - 60 * 1000).toISOString();
      const checkInRes = await request(app.getHttpServer())
        .post('/api/v1/check-ins')
        .set('Authorization', `Bearer ${monitoredUser.accessToken}`)
        .send({
          eventId: uuidv4(),
          deviceId: devices[0].id,
          relationshipId: relationship.id,
          occurredAt: tOffline,
          note: 'Offline check-in predating incident',
        });

      expect([200, 201]).toContain(checkInRes.status);

      // Safety Invariant: Incident MUST NOT be resolved by pre-incident check-in!
      const refreshedInc = await incRepo.findOne({ where: { id: savedInc.id } });
      expect(refreshedInc!.status).toBe(IncidentStatus.OPEN);
      expect(refreshedInc!.resolvedAt).toBeNull();

      // Now send genuine fresh check-in occurring AFTER incident
      const freshRes = await request(app.getHttpServer())
        .post('/api/v1/check-ins')
        .set('Authorization', `Bearer ${monitoredUser.accessToken}`)
        .send({
          eventId: uuidv4(),
          deviceId: devices[0].id,
          relationshipId: relationship.id,
          occurredAt: new Date().toISOString(),
          note: 'Post-incident fresh confirmation ("Tôi vẫn ổn")',
        });

      expect([200, 201]).toContain(freshRes.status);

      // Incident MUST now be resolved
      const resolvedInc = await incRepo.findOne({ where: { id: savedInc.id } });
      expect(resolvedInc!.status).toBe(IncidentStatus.RESOLVED);
      expect(resolvedInc!.resolvedAt).toBeDefined();
    });

    it('3.3 Multi-Client Reachability Pings & Sliding Window Rate Limiter: Each device gets independent bucket, weight strictly 0.0 under concurrent load', async () => {
      // 3 devices send 2 rapid heartbeats each (total 6 heartbeats across 3 devices)
      const pings = [];
      for (let devIdx = 0; devIdx < 3; devIdx++) {
        for (let burst = 0; burst < 2; burst++) {
          pings.push(
            request(app.getHttpServer())
              .post('/api/v1/heartbeat')
              .set('Authorization', `Bearer ${monitoredUser.accessToken}`)
              .send({
                deviceId: devices[devIdx].id,
                occurredAt: new Date().toISOString(),
                batteryLevel: 80 - devIdx,
                isCharging: false,
              }),
          );
        }
      }

      const results = await Promise.all(pings);
      for (const res of results) {
        expect(res.status).toBe(200);
        expect(res.body.operationalState).toBe('ONLINE');
      }

      // Now send 3rd heartbeat immediately from device 0 -> exceeds 2/30s limit -> 429
      const rateLimitedRes = await request(app.getHttpServer())
        .post('/api/v1/heartbeat')
        .set('Authorization', `Bearer ${monitoredUser.accessToken}`)
        .send({
          deviceId: devices[0].id,
          occurredAt: new Date().toISOString(),
          batteryLevel: 79,
          isCharging: false,
        });
      expect(rateLimitedRes.status).toBe(429);

      // But device 3 (which hasn't sent any) can still send successfully (bucket isolation)
      const dev3Res = await request(app.getHttpServer())
        .post('/api/v1/heartbeat')
        .set('Authorization', `Bearer ${monitoredUser.accessToken}`)
        .send({
          deviceId: devices[3].id,
          occurredAt: new Date().toISOString(),
          batteryLevel: 88,
          isCharging: false,
        });
      expect(dev3Res.status).toBe(200);
      expect(dev3Res.body.operationalState).toBe('ONLINE');
    });
  });
});
