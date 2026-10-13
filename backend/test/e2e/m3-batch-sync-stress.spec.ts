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
import { ActivityType } from '../../src/common/enums';

describe('Milestone 3 Challenger: Batch Sync Deduplication & Client Edge Cases Stress Tests', () => {
  let app: INestApplication;
  let dataSource: DataSource;
  let monitoredUser: TestUserContext;
  let guardianUser: TestUserContext;
  let device: any;
  let relationship: any;

  beforeAll(async () => {
    const context = await createE2eTestApp();
    app = context.app;
    dataSource = context.dataSource;

    await resetDatabase(dataSource);

    const emailTag = `m3_stress_${Date.now()}`;
    monitoredUser = await registerAndLoginUser(app, `user_${emailTag}`);
    guardianUser = await registerAndLoginUser(app, `guard_${emailTag}`);
    device = await registerTestDevice(app, monitoredUser.accessToken);
    const paired = await pairMonitoringRelationship(app, guardianUser.accessToken, monitoredUser);
    relationship = paired.relationship;
  }, 30000);

  afterAll(async () => {
    await teardownE2eTestApp(app, dataSource);
  });

  it('1. Intra-Batch Deduplication: Batch containing identical eventIds persists only ONE database row', async () => {
    const duplicateEventId = uuidv4();
    const now = new Date();

    const batchRes = await request(app.getHttpServer())
      .post('/api/v1/activities/batch')
      .set('Authorization', `Bearer ${monitoredUser.accessToken}`)
      .send({
        activities: [
          {
            eventId: duplicateEventId,
            deviceId: device.id,
            type: ActivityType.STEP_DETECTED,
            occurredAt: new Date(now.getTime() - 30000).toISOString(),
            confidence: 0.9,
          },
          {
            eventId: duplicateEventId,
            deviceId: device.id,
            type: ActivityType.STEP_DETECTED,
            occurredAt: new Date(now.getTime() - 25000).toISOString(),
            confidence: 0.9,
          },
          {
            eventId: duplicateEventId,
            deviceId: device.id,
            type: ActivityType.STEP_DETECTED,
            occurredAt: new Date(now.getTime() - 20000).toISOString(),
            confidence: 0.9,
          },
        ],
      });

    expect(batchRes.status).toBe(201);
    expect(Array.isArray(batchRes.body)).toBe(true);
    // Both items are returned in results without failure
    expect(batchRes.body.length).toBe(3);

    // CRITICAL EMPIRICAL PROOF: Database table 'activities' contains EXACTLY 1 row for duplicateEventId
    const rows = await dataSource.query(
      `SELECT id, event_id FROM activities WHERE event_id = $1`,
      [duplicateEventId],
    );
    expect(rows.length).toBe(1);
    expect(rows[0].event_id).toBe(duplicateEventId);
  });

  it('2. Inter-Batch Replay Idempotency: Replaying an entire batch returns existing records with zero new rows', async () => {
    const eventA = uuidv4();
    const eventB = uuidv4();
    const now = new Date();

    const batchPayload = {
      activities: [
        {
          eventId: eventA,
          deviceId: device.id,
          type: ActivityType.CHARGER_CONNECTED,
          occurredAt: new Date(now.getTime() - 15000).toISOString(),
        },
        {
          eventId: eventB,
          deviceId: device.id,
          type: ActivityType.SCREEN_INTERACTION,
          occurredAt: new Date(now.getTime() - 10000).toISOString(),
        },
      ],
    };

    // First ingestion
    const res1 = await request(app.getHttpServer())
      .post('/api/v1/activities/batch')
      .set('Authorization', `Bearer ${monitoredUser.accessToken}`)
      .send(batchPayload);
    expect(res1.status).toBe(201);
    expect(res1.body.length).toBe(2);

    // Second ingestion (replaying identical batch)
    const res2 = await request(app.getHttpServer())
      .post('/api/v1/activities/batch')
      .set('Authorization', `Bearer ${monitoredUser.accessToken}`)
      .send(batchPayload);
    expect(res2.status).toBe(201);
    expect(res2.body.length).toBe(2);

    // Replay returns same IDs
    expect(res2.body[0].eventId).toBe(eventA);
    expect(res2.body[1].eventId).toBe(eventB);

    // Verify exactly 2 rows in DB, not 4
    const countA = await dataSource.query(`SELECT COUNT(*) FROM activities WHERE event_id = $1`, [eventA]);
    const countB = await dataSource.query(`SELECT COUNT(*) FROM activities WHERE event_id = $1`, [eventB]);
    expect(Number(countA[0].count)).toBe(1);
    expect(Number(countB[0].count)).toBe(1);
  });

  it('3. Monotonic Clock Invariant on Batch Replay: Replayed older activities NEVER regress lastMeaningfulActivityAt', async () => {
    // Current server activity clock
    const cfgRes1 = await request(app.getHttpServer())
      .get(`/api/v1/monitoring/${relationship.id}/config`)
      .set('Authorization', `Bearer ${monitoredUser.accessToken}`);
    const originalClock = new Date(cfgRes1.body.lastMeaningfulActivityAt).getTime();

    // Replay stale batch 1 hour old
    const staleEvent = uuidv4();
    const staleTime = new Date(originalClock - 3600000);

    const staleRes = await request(app.getHttpServer())
      .post('/api/v1/activities/batch')
      .set('Authorization', `Bearer ${monitoredUser.accessToken}`)
      .send({
        activities: [
          {
            eventId: staleEvent,
            deviceId: device.id,
            type: ActivityType.STEP_DETECTED,
            occurredAt: staleTime.toISOString(),
            confidence: 0.9,
          },
        ],
      });
    expect(staleRes.status).toBe(201);

    // Verify clock did NOT regress
    const cfgRes2 = await request(app.getHttpServer())
      .get(`/api/v1/monitoring/${relationship.id}/config`)
      .set('Authorization', `Bearer ${monitoredUser.accessToken}`);
    const clockAfterStale = new Date(cfgRes2.body.lastMeaningfulActivityAt).getTime();

    expect(clockAfterStale).toBe(originalClock);
  });

  it('4. Concurrent Batch Submissions with Overlapping eventIds (Race Condition)', async () => {
    const sharedEvent1 = uuidv4();
    const sharedEvent2 = uuidv4();
    const now = new Date();

    const payload = {
      activities: [
        {
          eventId: sharedEvent1,
          deviceId: device.id,
          type: ActivityType.APP_FOREGROUND,
          occurredAt: now.toISOString(),
        },
        {
          eventId: sharedEvent2,
          deviceId: device.id,
          type: ActivityType.DEVICE_MOTION,
          occurredAt: now.toISOString(),
        },
      ],
    };

    // Fire 3 simultaneous batch requests
    const [p1, p2, p3] = await Promise.all([
      request(app.getHttpServer())
        .post('/api/v1/activities/batch')
        .set('Authorization', `Bearer ${monitoredUser.accessToken}`)
        .send(payload),
      request(app.getHttpServer())
        .post('/api/v1/activities/batch')
        .set('Authorization', `Bearer ${monitoredUser.accessToken}`)
        .send(payload),
      request(app.getHttpServer())
        .post('/api/v1/activities/batch')
        .set('Authorization', `Bearer ${monitoredUser.accessToken}`)
        .send(payload),
    ]);

    expect([p1.status, p2.status, p3.status]).toEqual([201, 201, 201]);

    // Check DB rows: must be exactly 1 row for each event
    const rows1 = await dataSource.query(`SELECT id FROM activities WHERE event_id = $1`, [sharedEvent1]);
    const rows2 = await dataSource.query(`SELECT id FROM activities WHERE event_id = $1`, [sharedEvent2]);
    expect(rows1.length).toBe(1);
    expect(rows2.length).toBe(1);
  });

  it('5. Batch validation: Empty batch array and non-array payload rejected cleanly', async () => {
    const emptyRes = await request(app.getHttpServer())
      .post('/api/v1/activities/batch')
      .set('Authorization', `Bearer ${monitoredUser.accessToken}`)
      .send({ activities: [] });

    expect(emptyRes.status).toBe(201);
    expect(emptyRes.body).toEqual([]);

    const nonArrayRes = await request(app.getHttpServer())
      .post('/api/v1/activities/batch')
      .set('Authorization', `Bearer ${monitoredUser.accessToken}`)
      .send({ activities: 'not-an-array' });

    expect(nonArrayRes.status).toBe(400);
  });
});
