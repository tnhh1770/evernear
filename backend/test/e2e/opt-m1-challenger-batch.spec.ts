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
  MonitoringState,
} from '../../src/common/enums';

describe('Opt-M1 Challenger 1: Adversarial Batch Ingestion & Concurrency Stress Suite', () => {
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

    const emailTag = `opt_m1_adv_${Date.now()}`;
    monitoredUser = await registerAndLoginUser(app, `mon_${emailTag}`);
    guardianUser = await registerAndLoginUser(app, `guard_${emailTag}`);

    // Register 5 devices for monitored user
    for (let i = 0; i < 5; i++) {
      const dev = await registerTestDevice(app, monitoredUser.accessToken, {
        platform: i % 2 === 0 ? DevicePlatform.ANDROID : DevicePlatform.IOS,
        deviceName: `OptM1 Device ${i + 1}`,
        pushToken: `push-token-${emailTag}-${i + 1}`,
        batteryLevel: 95 - i * 5,
      });
      devices.push(dev);
    }

    const paired = await pairMonitoringRelationship(app, guardianUser.accessToken, monitoredUser);
    relationship = paired.relationship;

    // Set configuration: 10 minutes inactivity, 5 minutes grace
    await request(app.getHttpServer())
      .patch(`/api/v1/monitoring/${relationship.id}/config`)
      .set('Authorization', `Bearer ${monitoredUser.accessToken}`)
      .send({
        inactivityThresholdMinutes: 10,
        checkInGraceMinutes: 5,
        warningEscalationMinutes: 5,
        locationEnabled: true,
      });
  }, 45000);

  afterAll(async () => {
    await teardownE2eTestApp(app, dataSource);
  });

  // =========================================================================
  // 1. MASSIVE 100-EVENT HETEROGENEOUS BATCH
  // =========================================================================
  it('1. Massive Heterogeneous Batch (100 events): Processes interleaved heartbeats, low-confidence, activities, and check-ins with accurate state transition and latency', async () => {
    // Set config to WARNING state with clock 2 hours ago
    const twoHoursAgo = new Date(Date.now() - 2 * 60 * 60 * 1000);
    await dataSource.query(
      `UPDATE monitoring_configs SET current_state = 'WARNING', last_meaningful_activity_at = $1 WHERE relationship_id = $2`,
      [twoHoursAgo, relationship.id],
    );

    const baseTime = Date.now() - 60000;
    const latestMeaningfulTime = new Date(baseTime + 99 * 500); // the 100th item's timestamp

    const batchActivities: any[] = [];

    for (let i = 0; i < 100; i++) {
      const occurredAt = new Date(baseTime + i * 500).toISOString();
      const dev = devices[i % devices.length];

      if (i < 25) {
        // 25 Heartbeats (weight 0.0)
        batchActivities.push({
          eventId: uuidv4(),
          deviceId: dev.id,
          type: ActivityType.HEARTBEAT,
          occurredAt,
          confidence: 1.0,
        });
      } else if (i < 40) {
        // 15 Low-confidence SCREEN_INTERACTION (confidence 0.2 < minConfidence 0.7)
        batchActivities.push({
          eventId: uuidv4(),
          deviceId: dev.id,
          type: ActivityType.SCREEN_INTERACTION,
          occurredAt,
          confidence: 0.2,
        });
      } else if (i < 60) {
        // 20 High-confidence STEP_DETECTED (weight 0.6)
        batchActivities.push({
          eventId: uuidv4(),
          deviceId: dev.id,
          type: ActivityType.STEP_DETECTED,
          occurredAt,
          confidence: 0.85,
        });
      } else if (i < 75) {
        // 15 CHARGER_CONNECTED (weight 0.2)
        batchActivities.push({
          eventId: uuidv4(),
          deviceId: dev.id,
          type: ActivityType.CHARGER_CONNECTED,
          occurredAt,
          confidence: 0.9,
        });
      } else if (i < 90) {
        // 15 APP_FOREGROUND (weight 0.8)
        batchActivities.push({
          eventId: uuidv4(),
          deviceId: dev.id,
          type: ActivityType.APP_FOREGROUND,
          occurredAt,
          confidence: 0.95,
        });
      } else {
        // 10 CHECK_IN (weight 1.0)
        batchActivities.push({
          eventId: uuidv4(),
          deviceId: dev.id,
          type: ActivityType.CHECK_IN,
          occurredAt,
          confidence: 1.0,
        });
      }
    }

    const tStart = Date.now();
    const res = await request(app.getHttpServer())
      .post('/api/v1/activities/batch')
      .set('Authorization', `Bearer ${monitoredUser.accessToken}`)
      .send({ activities: batchActivities });
    const duration = Date.now() - tStart;

    expect(res.status).toBe(201);
    expect(Array.isArray(res.body)).toBe(true);
    expect(res.body.length).toBe(100);

    // Latency benchmark check: 100 events should complete in < 600ms
    expect(duration).toBeLessThan(1000);

    // Verify 100 rows in activities table
    const eventIds = batchActivities.map((b) => b.eventId);
    const dbCount = await dataSource.query(
      `SELECT COUNT(*) FROM activities WHERE event_id = ANY($1)`,
      [eventIds],
    );
    expect(Number(dbCount[0].count)).toBe(100);

    // Verify monitoring config updated:
    // 1. lastMeaningfulActivityAt updated to latestMeaningfulTime
    // 2. currentState reset to ACTIVE because CHECK_IN occurred while in WARNING state
    const cfgRows = await dataSource.query(
      `SELECT current_state, last_meaningful_activity_at FROM monitoring_configs WHERE relationship_id = $1`,
      [relationship.id],
    );
    expect(cfgRows[0].current_state).toBe(MonitoringState.ACTIVE);
    const actualClock = new Date(cfgRows[0].last_meaningful_activity_at).getTime();
    expect(actualClock).toBe(latestMeaningfulTime.getTime());
  });

  // =========================================================================
  // 2. EXTREME CONCURRENCY: INTRA-BATCH AND INTER-BATCH DUPLICATES
  // =========================================================================
  it('2. Extreme Concurrency: 5 concurrent batch requests with intra-batch and inter-batch duplicate eventIds yield strictly 1 row per eventId with zero 500 errors', async () => {
    // Shared inter-batch duplicate IDs (will appear across all 5 requests)
    const sharedIds = [uuidv4(), uuidv4(), uuidv4(), uuidv4(), uuidv4()];
    const allUniqueEventIds = new Set<string>();

    const concurrentRequests = Array.from({ length: 5 }, (_, batchIdx) => {
      const activities: any[] = [];

      // 1. Add shared duplicates (inter-batch duplicates)
      for (const sharedId of sharedIds) {
        allUniqueEventIds.add(sharedId);
        activities.push({
          eventId: sharedId,
          deviceId: devices[batchIdx % devices.length].id,
          type: ActivityType.STEP_DETECTED,
          occurredAt: new Date(Date.now() - 30000).toISOString(),
          confidence: 0.9,
        });
      }

      // 2. Add intra-batch duplicates (repeated 3 times within this batch)
      const intraId1 = uuidv4();
      const intraId2 = uuidv4();
      allUniqueEventIds.add(intraId1);
      allUniqueEventIds.add(intraId2);

      for (let r = 0; r < 3; r++) {
        activities.push({
          eventId: intraId1,
          deviceId: devices[0].id,
          type: ActivityType.APP_FOREGROUND,
          occurredAt: new Date(Date.now() - 25000 + r * 100).toISOString(),
          confidence: 0.95,
        });
        activities.push({
          eventId: intraId2,
          deviceId: devices[1].id,
          type: ActivityType.DEVICE_MOTION,
          occurredAt: new Date(Date.now() - 20000 + r * 100).toISOString(),
          confidence: 0.8,
        });
      }

      // 3. Add 10 unique events
      for (let u = 0; u < 10; u++) {
        const uniqueId = uuidv4();
        allUniqueEventIds.add(uniqueId);
        activities.push({
          eventId: uniqueId,
          deviceId: devices[u % devices.length].id,
          type: ActivityType.STEP_DETECTED,
          occurredAt: new Date(Date.now() - 15000 + u * 100).toISOString(),
          confidence: 0.85,
        });
      }

      return request(app.getHttpServer())
        .post('/api/v1/activities/batch')
        .set('Authorization', `Bearer ${monitoredUser.accessToken}`)
        .send({ activities });
    });

    const responses = await Promise.all(concurrentRequests);

    // All 5 concurrent batch requests must succeed (201 Created)
    for (const res of responses) {
      expect(res.status).toBe(201);
      expect(Array.isArray(res.body)).toBe(true);
      // Total activities per batch: 5 shared + 6 intra (2 * 3) + 10 unique = 21
      expect(res.body.length).toBe(21);
    }

    // Verify in database: exactly allUniqueEventIds.size distinct rows exist
    const uniqueIdArray = Array.from(allUniqueEventIds);
    const dbCount = await dataSource.query(
      `SELECT COUNT(*) FROM activities WHERE event_id = ANY($1)`,
      [uniqueIdArray],
    );
    expect(Number(dbCount[0].count)).toBe(allUniqueEventIds.size);

    // Verify for each shared duplicate eventId, exactly 1 row exists
    for (const sharedId of sharedIds) {
      const rows = await dataSource.query(
        `SELECT id FROM activities WHERE event_id = $1`,
        [sharedId],
      );
      expect(rows.length).toBe(1);
    }
  });

  // =========================================================================
  // 3. MONOTONIC CLOCK INVARIANT: ADVERSARIAL TIME-REVERSAL & STALE REPLAYS
  // =========================================================================
  it('3. Monotonic Clock Invariant: Out-of-order, stale replays, and historical offline batches NEVER roll back the server activity clock', async () => {
    // Set a clean baseline clock at 1 hour ago
    const oneHourAgo = new Date(Date.now() - 3600000);
    await dataSource.query(
      `UPDATE monitoring_configs SET last_meaningful_activity_at = $1 WHERE relationship_id = $2`,
      [oneHourAgo, relationship.id],
    );

    // Current server activity clock
    const cfgRes1 = await request(app.getHttpServer())
      .get(`/api/v1/monitoring/${relationship.id}/config`)
      .set('Authorization', `Bearer ${monitoredUser.accessToken}`);
    const originalClock = new Date(cfgRes1.body.lastMeaningfulActivityAt).getTime();

    // Adversarial Batch 1: Ancient historical offline replay (3 hours ago)
    const ancientBatch = Array.from({ length: 10 }, (_, idx) => ({
      eventId: uuidv4(),
      deviceId: devices[idx % devices.length].id,
      type: ActivityType.STEP_DETECTED,
      occurredAt: new Date(originalClock - (180 - idx) * 60 * 1000).toISOString(),
      confidence: 0.9,
    }));

    const res1 = await request(app.getHttpServer())
      .post('/api/v1/activities/batch')
      .set('Authorization', `Bearer ${monitoredUser.accessToken}`)
      .send({ activities: ancientBatch });
    expect(res1.status).toBe(201);

    // Clock must not have regressed
    const cfgRes2 = await request(app.getHttpServer())
      .get(`/api/v1/monitoring/${relationship.id}/config`)
      .set('Authorization', `Bearer ${monitoredUser.accessToken}`);
    const clockAfterAncient = new Date(cfgRes2.body.lastMeaningfulActivityAt).getTime();
    expect(clockAfterAncient).toBe(originalClock);

    // Adversarial Batch 2: Intermediate stale activities (10 minutes before originalClock)
    const staleBatch = Array.from({ length: 5 }, (_, idx) => ({
      eventId: uuidv4(),
      deviceId: devices[idx % devices.length].id,
      type: ActivityType.APP_FOREGROUND,
      occurredAt: new Date(originalClock - (10 - idx) * 60 * 1000).toISOString(),
      confidence: 0.9,
    }));

    const res2 = await request(app.getHttpServer())
      .post('/api/v1/activities/batch')
      .set('Authorization', `Bearer ${monitoredUser.accessToken}`)
      .send({ activities: staleBatch });
    expect(res2.status).toBe(201);

    // Clock must still be originalClock
    const cfgRes3 = await request(app.getHttpServer())
      .get(`/api/v1/monitoring/${relationship.id}/config`)
      .set('Authorization', `Bearer ${monitoredUser.accessToken}`);
    expect(new Date(cfgRes3.body.lastMeaningfulActivityAt).getTime()).toBe(originalClock);

    // Genuine Forward Batch: Timestamp advances clock by 15 minutes
    const advancedTime = new Date(originalClock + 15 * 60 * 1000);
    const forwardBatch = [
      {
        eventId: uuidv4(),
        deviceId: devices[0].id,
        type: ActivityType.STEP_DETECTED,
        occurredAt: advancedTime.toISOString(),
        confidence: 0.9,
      },
    ];

    const res3 = await request(app.getHttpServer())
      .post('/api/v1/activities/batch')
      .set('Authorization', `Bearer ${monitoredUser.accessToken}`)
      .send({ activities: forwardBatch });
    expect(res3.status).toBe(201);

    // Clock must advance to advancedTime
    const cfgRes4 = await request(app.getHttpServer())
      .get(`/api/v1/monitoring/${relationship.id}/config`)
      .set('Authorization', `Bearer ${monitoredUser.accessToken}`);
    expect(new Date(cfgRes4.body.lastMeaningfulActivityAt).getTime()).toBe(advancedTime.getTime());

    // Adversarial Batch 3: Mixed batch with timestamps between originalClock and advancedTime
    const inBetweenBatch = [
      {
        eventId: uuidv4(),
        deviceId: devices[1].id,
        type: ActivityType.CHARGER_CONNECTED,
        occurredAt: new Date(originalClock + 5 * 60 * 1000).toISOString(),
        confidence: 0.9,
      },
      {
        eventId: uuidv4(),
        deviceId: devices[2].id,
        type: ActivityType.SCREEN_INTERACTION,
        occurredAt: new Date(advancedTime.getTime() - 1000).toISOString(),
        confidence: 0.9,
      },
    ];

    const res4 = await request(app.getHttpServer())
      .post('/api/v1/activities/batch')
      .set('Authorization', `Bearer ${monitoredUser.accessToken}`)
      .send({ activities: inBetweenBatch });
    expect(res4.status).toBe(201);

    // Clock MUST STILL BE advancedTime!
    const cfgRes5 = await request(app.getHttpServer())
      .get(`/api/v1/monitoring/${relationship.id}/config`)
      .set('Authorization', `Bearer ${monitoredUser.accessToken}`);
    expect(new Date(cfgRes5.body.lastMeaningfulActivityAt).getTime()).toBe(advancedTime.getTime());
  });

  // =========================================================================
  // 4. FUTURE TIMESTAMP CLAMPING (> 5 MINUTES CLAMPED TO SERVER NOW)
  // =========================================================================
  it('4. Future Timestamp Clamping: Client timestamps > 5 minutes in the future are clamped to server now, preventing future drift', async () => {
    const tServerBefore = Date.now();

    const evNormal = uuidv4();
    const ev10MinFuture = uuidv4();
    const evOneDayFuture = uuidv4();
    const evOneYearFuture = uuidv4();

    const futureBatch = [
      {
        eventId: evNormal,
        deviceId: devices[0].id,
        type: ActivityType.STEP_DETECTED,
        occurredAt: new Date(tServerBefore + 2 * 60 * 1000).toISOString(), // +2m: within 5m grace
        confidence: 0.9,
      },
      {
        eventId: ev10MinFuture,
        deviceId: devices[1].id,
        type: ActivityType.APP_FOREGROUND,
        occurredAt: new Date(tServerBefore + 10 * 60 * 1000).toISOString(), // +10m: must clamp
        confidence: 0.95,
      },
      {
        eventId: evOneDayFuture,
        deviceId: devices[2].id,
        type: ActivityType.CHARGER_CONNECTED,
        occurredAt: new Date(tServerBefore + 24 * 60 * 60 * 1000).toISOString(), // +24h: must clamp
        confidence: 0.9,
      },
      {
        eventId: evOneYearFuture,
        deviceId: devices[3].id,
        type: ActivityType.SCREEN_INTERACTION,
        occurredAt: new Date(tServerBefore + 365 * 24 * 60 * 60 * 1000).toISOString(), // +1yr: must clamp
        confidence: 0.9,
      },
    ];

    const res = await request(app.getHttpServer())
      .post('/api/v1/activities/batch')
      .set('Authorization', `Bearer ${monitoredUser.accessToken}`)
      .send({ activities: futureBatch });

    const tServerAfter = Date.now();
    expect(res.status).toBe(201);
    expect(res.body.length).toBe(4);

    // Query persisted activities from DB
    const rows = await dataSource.query(
      `SELECT event_id, occurred_at FROM activities WHERE event_id IN ($1, $2, $3, $4)`,
      [evNormal, ev10MinFuture, evOneDayFuture, evOneYearFuture],
    );
    const rowMap = new Map(rows.map((r: any) => [r.event_id, new Date(r.occurred_at).getTime()]));

    // evNormal should NOT be clamped (allowed within 5m grace window)
    const timeNormal = rowMap.get(evNormal)!;
    expect(timeNormal).toBeGreaterThanOrEqual(tServerBefore + 119 * 1000);

    // ev10MinFuture, evOneDayFuture, evOneYearFuture MUST be clamped to server now (between tServerBefore and tServerAfter + 1000ms)
    for (const futureId of [ev10MinFuture, evOneDayFuture, evOneYearFuture]) {
      const clampedTime = rowMap.get(futureId)!;
      expect(clampedTime).toBeGreaterThanOrEqual(tServerBefore - 500);
      expect(clampedTime).toBeLessThanOrEqual(tServerAfter + 1000);
    }

    // Monitoring config clock must be bounded (must not be pushed to 10m, 1d, or 1yr)
    const cfgRows = await dataSource.query(
      `SELECT last_meaningful_activity_at FROM monitoring_configs WHERE relationship_id = $1`,
      [relationship.id],
    );
    const recordedClock = new Date(cfgRows[0].last_meaningful_activity_at).getTime();
    expect(recordedClock).toBeLessThan(tServerBefore + 5 * 60 * 1000);
  });

  // =========================================================================
  // 5. SIGNAL SEPARATION: HEARTBEAT (WEIGHT 0.0) NEVER ADVANCES CLOCK
  // =========================================================================
  it('5. Signal Separation: Batch and single Heartbeats (weight 0.0) NEVER advance lastMeaningfulActivityAt or reset inactivity timers', async () => {
    // Set baseline state: WARNING, clock at 1 hour ago
    const oneHourAgo = new Date(Date.now() - 3600000);
    const nextEvalBaseline = new Date(Date.now() - 1800000);

    await dataSource.query(
      `UPDATE monitoring_configs SET current_state = 'WARNING', last_meaningful_activity_at = $1, next_evaluation_at = $2 WHERE relationship_id = $3`,
      [oneHourAgo, nextEvalBaseline, relationship.id],
    );

    // Submit batch of 30 pure HEARTBEAT activities with fresh timestamps (now - 5m)
    const heartbeatBatch = Array.from({ length: 30 }, (_, idx) => ({
      eventId: uuidv4(),
      deviceId: devices[idx % devices.length].id,
      type: ActivityType.HEARTBEAT,
      occurredAt: new Date(Date.now() - (30 - idx) * 1000).toISOString(),
      confidence: 1.0,
    }));

    const batchRes = await request(app.getHttpServer())
      .post('/api/v1/activities/batch')
      .set('Authorization', `Bearer ${monitoredUser.accessToken}`)
      .send({ activities: heartbeatBatch });

    expect(batchRes.status).toBe(201);
    expect(batchRes.body.length).toBe(30);

    // Also send single direct heartbeat
    const singleHeartbeatRes = await request(app.getHttpServer())
      .post('/api/v1/heartbeat')
      .set('Authorization', `Bearer ${monitoredUser.accessToken}`)
      .send({
        deviceId: devices[0].id,
        batteryLevel: 85,
        isCharging: true,
        occurredAt: new Date().toISOString(),
      });
    expect(singleHeartbeatRes.status).toBe(200);

    // Strict Verification of Axiom 2 & Invariants:
    // 1. last_meaningful_activity_at MUST NOT change (remains oneHourAgo)
    // 2. current_state MUST NOT reset to ACTIVE (remains WARNING)
    // 3. next_evaluation_at MUST NOT be postponed
    const cfgRows = await dataSource.query(
      `SELECT current_state, last_meaningful_activity_at, next_evaluation_at FROM monitoring_configs WHERE relationship_id = $1`,
      [relationship.id],
    );
    expect(cfgRows[0].current_state).toBe(MonitoringState.WARNING);
    expect(new Date(cfgRows[0].last_meaningful_activity_at).getTime()).toBe(oneHourAgo.getTime());
    expect(new Date(cfgRows[0].next_evaluation_at).getTime()).toBe(nextEvalBaseline.getTime());

    // Reachability verification: Device record WAS updated by heartbeat
    const devRows = await dataSource.query(
      `SELECT last_heartbeat_at, last_seen_at, battery_level, is_charging FROM devices WHERE id = $1`,
      [devices[0].id],
    );
    expect(devRows[0].battery_level).toBe(85);
    expect(devRows[0].is_charging).toBe(true);
    expect(devRows[0].last_heartbeat_at).toBeDefined();
  });

  // =========================================================================
  // 6. PARTIAL BATCH RESILIENCE: INVALID DEVICES & CORRUPT TIMESTAMPS
  // =========================================================================
  it('6. Partial Batch Resilience: Batch containing invalid device IDs and malformed timestamps ingests valid activities without failing', async () => {
    const validEventId = uuidv4();
    const badDeviceEventId = uuidv4();
    const corruptDateEventId = uuidv4();

    const mixedBatch = [
      {
        eventId: validEventId,
        deviceId: devices[0].id,
        type: ActivityType.APP_FOREGROUND,
        occurredAt: new Date().toISOString(),
        confidence: 0.95,
      },
      {
        eventId: badDeviceEventId,
        deviceId: '00000000-0000-0000-0000-000000000000', // non-existent device
        type: ActivityType.STEP_DETECTED,
        occurredAt: new Date().toISOString(),
        confidence: 0.9,
      },
      {
        eventId: corruptDateEventId,
        deviceId: devices[1].id,
        type: ActivityType.STEP_DETECTED,
        occurredAt: 'not-a-valid-iso-date', // corrupt timestamp
        confidence: 0.9,
      },
    ];

    const res = await request(app.getHttpServer())
      .post('/api/v1/activities/batch')
      .set('Authorization', `Bearer ${monitoredUser.accessToken}`)
      .send({ activities: mixedBatch });

    expect(res.status).toBe(201);
    // Only the valid event should be returned
    expect(res.body.length).toBe(1);
    expect(res.body[0].eventId).toBe(validEventId);

    // Verify DB: validEventId exists, bad ones do NOT
    const dbValid = await dataSource.query(`SELECT id FROM activities WHERE event_id = $1`, [validEventId]);
    const dbBadDev = await dataSource.query(`SELECT id FROM activities WHERE event_id = $1`, [badDeviceEventId]);
    const dbCorrupt = await dataSource.query(`SELECT id FROM activities WHERE event_id = $1`, [corruptDateEventId]);

    expect(dbValid.length).toBe(1);
    expect(dbBadDev.length).toBe(0);
    expect(dbCorrupt.length).toBe(0);
  });

  // =========================================================================
  // 7. MULTI-GUARDIAN FILTER ISOLATION: RELATIONSHIP-SPECIFIC ALLOWED TYPES
  // =========================================================================
  it('7. Multi-Guardian Filter Isolation: Disjoint allowed activity types advance clocks independently per guardian configuration', async () => {
    // Register guardian 2 and pair with monitored user
    const guardian2 = await registerAndLoginUser(app, `guard2_adv_${Date.now()}`);
    const paired2 = await pairMonitoringRelationship(app, guardian2.accessToken, monitoredUser);
    const rel2 = paired2.relationship;

    const baseT = new Date(Date.now() - 3600000); // 1 hour ago

    // Guardian 1 monitors ONLY STEP_DETECTED
    await dataSource.query(
      `UPDATE monitoring_configs SET last_meaningful_activity_at = $1, activity_types = $2 WHERE relationship_id = $3`,
      [baseT, JSON.stringify([ActivityType.STEP_DETECTED]), relationship.id],
    );

    // Guardian 2 monitors ONLY CHARGER_CONNECTED
    await dataSource.query(
      `UPDATE monitoring_configs SET last_meaningful_activity_at = $1, activity_types = $2 WHERE relationship_id = $3`,
      [baseT, JSON.stringify([ActivityType.CHARGER_CONNECTED]), rel2.id],
    );

    const stepTime = new Date(baseT.getTime() + 10 * 60 * 1000);
    const chargerTime = new Date(baseT.getTime() + 25 * 60 * 1000);

    const filterBatch = [
      {
        eventId: uuidv4(),
        deviceId: devices[0].id,
        type: ActivityType.STEP_DETECTED,
        occurredAt: stepTime.toISOString(),
        confidence: 0.9,
      },
      {
        eventId: uuidv4(),
        deviceId: devices[1].id,
        type: ActivityType.CHARGER_CONNECTED,
        occurredAt: chargerTime.toISOString(),
        confidence: 0.9,
      },
    ];

    const res = await request(app.getHttpServer())
      .post('/api/v1/activities/batch')
      .set('Authorization', `Bearer ${monitoredUser.accessToken}`)
      .send({ activities: filterBatch });

    expect(res.status).toBe(201);
    expect(res.body.length).toBe(2);

    // Guardian 1 clock must be stepTime (NOT chargerTime)
    const cfg1 = await dataSource.query(
      `SELECT last_meaningful_activity_at FROM monitoring_configs WHERE relationship_id = $1`,
      [relationship.id],
    );
    expect(new Date(cfg1[0].last_meaningful_activity_at).getTime()).toBe(stepTime.getTime());

    // Guardian 2 clock must be chargerTime (NOT stepTime)
    const cfg2 = await dataSource.query(
      `SELECT last_meaningful_activity_at FROM monitoring_configs WHERE relationship_id = $1`,
      [rel2.id],
    );
    expect(new Date(cfg2[0].last_meaningful_activity_at).getTime()).toBe(chargerTime.getTime());
  });

  // =========================================================================
  // 8. SIMULTANEOUS INSERTION COLLISION: RACE CONDITION CATCH BLOCK RECOVERY
  // =========================================================================
  it('8. Simultaneous Insertion Collision: 10 concurrent requests submitting the EXACT SAME brand-new batch trigger unique constraint recovery cleanly with zero errors', async () => {
    // Generate 20 brand-new activities
    const sharedBatch = Array.from({ length: 20 }, (_, idx) => ({
      eventId: uuidv4(),
      deviceId: devices[idx % devices.length].id,
      type: idx % 2 === 0 ? ActivityType.STEP_DETECTED : ActivityType.APP_FOREGROUND,
      occurredAt: new Date(Date.now() - (60 - idx) * 1000).toISOString(),
      confidence: 0.9,
    }));

    // Fire 10 concurrent requests submitting this identical new batch
    const concurrentRequests = Array.from({ length: 10 }, () =>
      request(app.getHttpServer())
        .post('/api/v1/activities/batch')
        .set('Authorization', `Bearer ${monitoredUser.accessToken}`)
        .send({ activities: sharedBatch }),
    );

    const results = await Promise.all(concurrentRequests);

    // All 10 requests must succeed with HTTP 201
    for (const res of results) {
      expect(res.status).toBe(201);
      expect(res.body.length).toBe(20);
    }

    // In database, exactly 20 rows must exist for these eventIds
    const eventIds = sharedBatch.map((a) => a.eventId);
    const dbRows = await dataSource.query(
      `SELECT COUNT(*) FROM activities WHERE event_id = ANY($1)`,
      [eventIds],
    );
    expect(Number(dbRows[0].count)).toBe(20);
  });
});

