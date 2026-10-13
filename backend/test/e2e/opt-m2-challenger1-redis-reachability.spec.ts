import { describe, it, expect, beforeAll, afterAll } from 'vitest';
import { INestApplication } from '@nestjs/common';
import { DataSource, Repository } from 'typeorm';
import request from 'supertest';
import { v4 as uuidv4 } from 'uuid';
import Redis from 'ioredis';
import {
  createE2eTestApp,
  resetDatabase,
  teardownE2eTestApp,
  registerAndLoginUser,
  registerTestDevice,
  pairMonitoringRelationship,
  TestUserContext,
} from './e2e-helper';
import { RedisService } from '../../src/common/redis/redis.service';
import { DevicesService } from '../../src/modules/devices/devices.service';
import { Device } from '../../src/modules/devices/entities/device.entity';
import { MonitoringConfig } from '../../src/modules/monitoring/entities/monitoring-config.entity';
import { ActivityType, DevicePlatform } from '../../src/common/enums';

describe('Opt-M2 Challenger 1: Adversarial Redis Lua Rate Limiter & Reachability Buffer Suite', () => {
  let app: INestApplication;
  let dataSource: DataSource;
  let redisService: RedisService;
  let devicesService: DevicesService;
  let deviceRepo: Repository<Device>;
  let monitoringConfigRepo: Repository<MonitoringConfig>;
  let directRedis: Redis;

  let monitoredUser: TestUserContext;
  let guardianUser: TestUserContext;
  let testDevice: any;
  let relationship: any;

  beforeAll(async () => {
    const context = await createE2eTestApp();
    app = context.app;
    dataSource = context.dataSource;

    await resetDatabase(dataSource);

    redisService = app.get<RedisService>(RedisService);
    devicesService = app.get<DevicesService>(DevicesService);
    deviceRepo = (devicesService as any).deviceRepository || dataSource.getRepository(Device);
    monitoringConfigRepo = dataSource.getRepository(MonitoringConfig);

    // Direct ioredis connection to verify raw keys and manipulate TTLs
    directRedis = new Redis({
      host: process.env.REDIS_HOST || '127.0.0.1',
      port: Number(process.env.REDIS_PORT) || 6379,
      password: process.env.REDIS_PASSWORD || undefined,
      lazyConnect: true,
      maxRetriesPerRequest: 2,
    });
    await directRedis.connect();

    const emailTag = `opt_m2_adv_${Date.now()}`;
    monitoredUser = await registerAndLoginUser(app, `mon_${emailTag}`);
    guardianUser = await registerAndLoginUser(app, `guard_${emailTag}`);

    testDevice = await registerTestDevice(app, monitoredUser.accessToken, {
      platform: DevicePlatform.ANDROID,
      deviceName: 'Challenger Primary Phone',
      batteryLevel: 85,
      isCharging: false,
    });

    const paired = await pairMonitoringRelationship(app, guardianUser.accessToken, monitoredUser);
    relationship = paired.relationship;

    // Configure monitoring config with 15 minutes inactivity threshold
    await request(app.getHttpServer())
      .patch(`/api/v1/monitoring/${relationship.id}/config`)
      .set('Authorization', `Bearer ${monitoredUser.accessToken}`)
      .send({
        inactivityThresholdMinutes: 15,
        checkInGraceMinutes: 5,
        warningEscalationMinutes: 5,
        locationEnabled: true,
      });
  }, 45000);

  afterAll(async () => {
    if (directRedis) {
      await directRedis.quit().catch(() => directRedis.disconnect());
    }
    await teardownE2eTestApp(app, dataSource);
  });

  // =========================================================================
  // TASK 1: ATOMIC LUA RATE LIMITER (ZOMBIE KEYS, HIGH CONCURRENCY, DEGRADED)
  // =========================================================================
  describe('Task 1: Adversarial Atomic Lua Rate Limiter', () => {
    it('1.1 High-Concurrency Spam: 100 parallel requests strictly enforce limit=10 with zero drift', async () => {
      const rateKey = `rate:adversarial:spam:${uuidv4()}`;
      const limit = 10;
      const windowSec = 10;

      // Fire 100 concurrent requests simultaneously
      const spamRequests = Array.from({ length: 100 }, () =>
        redisService.checkRateLimit(rateKey, limit, windowSec),
      );

      const results = await Promise.all(spamRequests);

      const allowedCount = results.filter((r) => r.allowed).length;
      const rejectedCount = results.filter((r) => !r.allowed).length;

      // Exactly limit (10) allowed, exactly 90 blocked
      expect(allowedCount).toBe(10);
      expect(rejectedCount).toBe(90);

      // Remaining values for allowed results must be within [0, 9]
      for (const res of results.filter((r) => r.allowed)) {
        expect(res.remaining).toBeGreaterThanOrEqual(0);
        expect(res.remaining).toBeLessThan(10);
      }

      // Remaining for all blocked results must be 0
      for (const res of results.filter((r) => !r.allowed)) {
        expect(res.remaining).toBe(0);
      }

      // Check raw Redis key: counter must be exactly 100
      const rawCount = await directRedis.get(rateKey);
      expect(rawCount).toBe('100');

      // Check TTL: must be between 1 and 10 seconds
      const ttl = await directRedis.ttl(rateKey);
      expect(ttl).toBeGreaterThan(0);
      expect(ttl).toBeLessThanOrEqual(windowSec);

      await directRedis.del(rateKey);
    });

    it('1.2 High-Concurrency Spike: 250 parallel requests strictly enforce limit=25 without race conditions', async () => {
      const rateKey = `rate:adversarial:spike:${uuidv4()}`;
      const limit = 25;
      const windowSec = 15;

      const spikeRequests = Array.from({ length: 250 }, () =>
        redisService.checkRateLimit(rateKey, limit, windowSec),
      );

      const results = await Promise.all(spikeRequests);

      const allowedCount = results.filter((r) => r.allowed).length;
      const rejectedCount = results.filter((r) => !r.allowed).length;

      expect(allowedCount).toBe(25);
      expect(rejectedCount).toBe(225);

      const rawCount = await directRedis.get(rateKey);
      expect(rawCount).toBe('250');

      await directRedis.del(rateKey);
    });

    it('1.3 Zombie Key Self-Healing: pre-existing key with TTL -1 is detected, incremented, and assigned TTL', async () => {
      const zombieKey = `rate:adversarial:zombie:${uuidv4()}`;
      const windowSec = 60;
      const limit = 10;

      // Intentionally forge a zombie key without expiration in Redis (TTL = -1)
      await directRedis.set(zombieKey, '5');
      const ttlBefore = await directRedis.ttl(zombieKey);
      expect(ttlBefore).toBe(-1); // Infinite persistence (zombie hazard)

      // Execute rate limit check with self-healing Lua script
      const result = await redisService.checkRateLimit(zombieKey, limit, windowSec);

      expect(result.allowed).toBe(true);
      expect(result.remaining).toBe(4); // 10 - 6 = 4

      // Empirically verify that Redis key was healed: TTL is now positive and <= windowSec
      const ttlAfter = await directRedis.ttl(zombieKey);
      expect(ttlAfter).toBeGreaterThan(0);
      expect(ttlAfter).toBeLessThanOrEqual(windowSec);

      // Verify counter value
      const count = await directRedis.get(zombieKey);
      expect(count).toBe('6');

      await directRedis.del(zombieKey);
    });

    it('1.4 Zombie Key Self-Healing When Over Limit: pre-existing key >= limit with TTL -1 is healed and blocked', async () => {
      const zombieOverKey = `rate:adversarial:zombie_over:${uuidv4()}`;
      const windowSec = 45;
      const limit = 10;

      // Forged zombie key with counter already at limit and no TTL
      await directRedis.set(zombieOverKey, '10');
      const ttlBefore = await directRedis.ttl(zombieOverKey);
      expect(ttlBefore).toBe(-1);

      const result = await redisService.checkRateLimit(zombieOverKey, limit, windowSec);

      expect(result.allowed).toBe(false);
      expect(result.remaining).toBe(0);

      // Verify self-healing assigned TTL even though request was blocked!
      const ttlAfter = await directRedis.ttl(zombieOverKey);
      expect(ttlAfter).toBeGreaterThan(0);
      expect(ttlAfter).toBeLessThanOrEqual(windowSec);

      const count = await directRedis.get(zombieOverKey);
      expect(count).toBe('11');

      await directRedis.del(zombieOverKey);
    });

    it('1.5 Degraded Fallback: allows requests gracefully when Redis is disconnected or client errors', async () => {
      // Mock disconnected client on redisService
      const originalIsReady = Object.getOwnPropertyDescriptor(
        Object.getPrototypeOf(redisService),
        'isReady',
      );

      // Temporarily simulate degraded / offline Redis
      Object.defineProperty(redisService, 'isReady', {
        get: () => false,
        configurable: true,
      });

      const degradedResult = await redisService.checkRateLimit('rate:offline:test', 5, 30);
      expect(degradedResult.allowed).toBe(true);
      expect(degradedResult.remaining).toBe(5);

      // Restore redisService
      if (originalIsReady) {
        Object.defineProperty(redisService, 'isReady', originalIsReady);
      }
    });
  });

  // =========================================================================
  // TASK 2: WRITE-BEHIND REACHABILITY BUFFER (THROTTLING VS BATTERY FLUSH)
  // =========================================================================
  describe('Task 2: Adversarial Write-Behind Reachability Buffer', () => {
    it('2.1 Send 50 Rapid Heartbeats with Identical Battery: throttles database writes to exactly 1 DB UPDATE', async () => {
      const bufferKey = `device:heartbeat:${testDevice.id}`;
      await directRedis.del(bufferKey);

      const qbSpy = vi.spyOn(deviceRepo, 'createQueryBuilder');

      try {
        // Heartbeat 1: First arrival -> Must execute PostgreSQL update and seed Redis hash
        const firstResult = await devicesService.recordHeartbeatAtomic(
          monitoredUser.id,
          testDevice.id,
          85,
          false,
        );
        expect(firstResult.success).toBe(true);
        expect(firstResult.operationalState).toBe('ONLINE');
        expect(qbSpy).toHaveBeenCalledTimes(1);

        // Verify Redis buffer was initialized
        const bufferState = await directRedis.hgetall(bufferKey);
        expect(bufferState.userId).toBe(monitoredUser.id);
        expect(bufferState.batteryLevel).toBe('85');
        expect(bufferState.isCharging).toBe('false');
        expect(bufferState.lastDbWriteAt).toBeDefined();

        // Heartbeats 2 to 50: 49 rapid heartbeats with identical battery 85 and charging false
        for (let i = 2; i <= 50; i++) {
          const res = await devicesService.recordHeartbeatAtomic(
            monitoredUser.id,
            testDevice.id,
            85,
            false,
          );
          expect(res.success).toBe(true);
          expect(res.operationalState).toBe('ONLINE');
        }

        // DB update count must remain strictly 1! (49 writes eliminated, 98% I/O reduction)
        expect(qbSpy).toHaveBeenCalledTimes(1);

        // Verify Redis buffer still holds fresh timestamps
        const updatedBuffer = await directRedis.hgetall(bufferKey);
        expect(updatedBuffer.lastSeenAt).toBeDefined();
        expect(updatedBuffer.lastHeartbeatAt).toBeDefined();
      } finally {
        qbSpy.mockRestore();
      }
    });

    it('2.2 Change Battery Level by 10%: immediately executes database update and flushes buffer', async () => {
      const bufferKey = `device:heartbeat:${testDevice.id}`;
      const qbSpy = vi.spyOn(deviceRepo, 'createQueryBuilder');

      try {
        // Device battery drops from 85% to 75% (10% drop)
        const result = await devicesService.recordHeartbeatAtomic(
          monitoredUser.id,
          testDevice.id,
          75,
          false,
        );

        expect(result.success).toBe(true);
        expect(result.operationalState).toBe('ONLINE');

        // Must immediately bypass throttle and execute DB write
        expect(qbSpy).toHaveBeenCalledTimes(1);

        // Verify DB row in PostgreSQL has updated battery level
        const updatedDevice = await deviceRepo.findOneBy({ id: testDevice.id });
        expect(updatedDevice?.batteryLevel).toBe(75);

        // Verify Redis buffer updated batteryLevel
        const bufferState = await directRedis.hgetall(bufferKey);
        expect(bufferState.batteryLevel).toBe('75');

        // Subsequent identical heartbeat at 75% is throttled again
        await devicesService.recordHeartbeatAtomic(
          monitoredUser.id,
          testDevice.id,
          75,
          false,
        );
        expect(qbSpy).toHaveBeenCalledTimes(1); // No new DB call
      } finally {
        qbSpy.mockRestore();
      }
    });

    it('2.3 Change Charging Status: immediately executes database update and flushes buffer', async () => {
      const qbSpy = vi.spyOn(deviceRepo, 'createQueryBuilder');

      try {
        // Plug in charger: isCharging changes from false to true
        const result = await devicesService.recordHeartbeatAtomic(
          monitoredUser.id,
          testDevice.id,
          75,
          true,
        );

        expect(result.success).toBe(true);
        expect(qbSpy).toHaveBeenCalledTimes(1);

        const updatedDevice = await deviceRepo.findOneBy({ id: testDevice.id });
        expect(updatedDevice?.isCharging).toBe(true);

        // Subsequent identical heartbeat at charging: true is throttled
        await devicesService.recordHeartbeatAtomic(
          monitoredUser.id,
          testDevice.id,
          75,
          true,
        );
        expect(qbSpy).toHaveBeenCalledTimes(1);
      } finally {
        qbSpy.mockRestore();
      }
    });

    it('2.4 Elapsed Window Expiry: DB write executes when > 60 seconds have elapsed even with identical state', async () => {
      const bufferKey = `device:heartbeat:${testDevice.id}`;

      // Simulate 65 seconds having elapsed since last DB write
      const simulatedPast = Date.now() - 65_000;
      await directRedis.hset(bufferKey, 'lastDbWriteAt', simulatedPast);

      const qbSpy = vi.spyOn(deviceRepo, 'createQueryBuilder');

      try {
        const result = await devicesService.recordHeartbeatAtomic(
          monitoredUser.id,
          testDevice.id,
          75,
          true,
        );

        expect(result.success).toBe(true);
        // Because elapsedMs >= 60,000, DB write must be triggered
        expect(qbSpy).toHaveBeenCalledTimes(1);

        // Verify lastDbWriteAt was updated to recent time in Redis
        const bufferState = await directRedis.hgetall(bufferKey);
        expect(Number(bufferState.lastDbWriteAt)).toBeGreaterThan(simulatedPast);
      } finally {
        qbSpy.mockRestore();
      }
    });

    it('2.5 Axiom 2 Strict Compliance: Heartbeat weight is strictly 0.0 (never updates lastMeaningfulActivityAt)', async () => {
      // 1. Fetch current monitoring config for the relationship
      const configBefore = await monitoringConfigRepo.findOneBy({ relationshipId: relationship.id });
      expect(configBefore).toBeDefined();
      const initialLastMeaningful = configBefore!.lastMeaningfulActivityAt.toISOString();

      // Clear heartbeat rate limiter to avoid 429
      await directRedis.del(`rate-limit:heartbeat:${testDevice.id}`);

      // 2. Send heartbeat via HTTP API
      const hbRes = await request(app.getHttpServer())
        .post('/api/v1/heartbeat')
        .set('Authorization', `Bearer ${monitoredUser.accessToken}`)
        .send({
          deviceId: testDevice.id,
          occurredAt: new Date().toISOString(),
          batteryLevel: 70,
          isCharging: true,
        });
      expect(hbRes.status).toBe(200);

      // 3. Verify that MonitoringConfig.lastMeaningfulActivityAt was NOT modified!
      const configAfterHeartbeat = await monitoringConfigRepo.findOneBy({ relationshipId: relationship.id });
      expect(configAfterHeartbeat!.lastMeaningfulActivityAt.toISOString()).toBe(initialLastMeaningful);

      // 4. Contrast: send a meaningful activity (weight > 0)
      const activityRes = await request(app.getHttpServer())
        .post('/api/v1/activities')
        .set('Authorization', `Bearer ${monitoredUser.accessToken}`)
        .send({
          eventId: uuidv4(),
          deviceId: testDevice.id,
          type: ActivityType.APP_FOREGROUND,
          occurredAt: new Date().toISOString(),
          confidence: 0.9,
        });
      expect(activityRes.status).toBe(201);

      // 5. Verify that MonitoringConfig.lastMeaningfulActivityAt WAS updated by meaningful activity
      const configAfterActivity = await monitoringConfigRepo.findOneBy({ relationshipId: relationship.id });
      expect(configAfterActivity!.lastMeaningfulActivityAt.getTime()).toBeGreaterThan(
        configBefore!.lastMeaningfulActivityAt.getTime(),
      );
    });
  });

  // =========================================================================
  // TASK 3: DISTRIBUTED REDLOCK MUTUAL EXCLUSION & RECOVERY (FEATURE 54)
  // =========================================================================
  describe('Task 3: Adversarial Distributed Redlock & Recovery', () => {
    it('3.1 Enforces strict mutual exclusion between competing workers', async () => {
      const lockKey = `lock:adversarial:test:${uuidv4()}`;

      // Worker 1 acquires lock
      const lock1 = await redisService.acquireLockDetailed(lockKey, 10000);
      expect(lock1.acquired).toBe(true);
      expect(lock1.degraded).toBe(false);
      expect(typeof lock1.token).toBe('string');

      // Worker 2 attempts to acquire same lock -> contention, must fail
      const lock2 = await redisService.acquireLockDetailed(lockKey, 10000);
      expect(lock2.acquired).toBe(false);
      expect(lock2.degraded).toBe(false);
      expect(lock2.token).toBeNull();

      // Release with wrong token -> must return false and NOT release
      const releaseRogue = await redisService.releaseLock(lockKey, 'rogue-token-123');
      expect(releaseRogue).toBe(false);

      // Worker 2 still cannot acquire
      const lock2Retry = await redisService.acquireLockDetailed(lockKey, 10000);
      expect(lock2Retry.acquired).toBe(false);

      // Worker 1 releases with legitimate token
      const releaseSuccess = await redisService.releaseLock(lockKey, lock1.token!);
      expect(releaseSuccess).toBe(true);

      // Now Worker 2 can acquire lock successfully
      const lock2After = await redisService.acquireLockDetailed(lockKey, 10000);
      expect(lock2After.acquired).toBe(true);
      expect(lock2After.token).not.toBeNull();

      // Cleanup
      await redisService.releaseLock(lockKey, lock2After.token!);
    });
  });
});
