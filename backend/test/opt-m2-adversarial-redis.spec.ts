import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { MonitoringWorkerService } from '../src/modules/workers/monitoring-worker.service';
import { DevicesService } from '../src/modules/devices/devices.service';
import { LockResult } from '../src/common/redis/redis.service';
import { MonitoringConfig } from '../src/modules/monitoring/entities/monitoring-config.entity';
import { Device } from '../src/modules/devices/entities/device.entity';
import {
  MonitoringState,
  RelationshipStatus,
  DevicePlatform,
} from '../src/common/enums';
import { ForbiddenException, UnauthorizedException } from '@nestjs/common';

describe('Adversarial Challenger 2: Opt-M2 Redis Concurrency, Redlock & Caching Hardening', () => {
  describe('Adversarial Suite 1: Redlock Mutual Exclusion in MonitoringWorkerService', () => {
    let worker: MonitoringWorkerService;
    let mockDataSource: any;
    let mockQueryRunner: any;
    let mockRedisService: any;
    let mockRiskEvaluator: any;
    let mockIncidentsService: any;
    let mockNotificationsService: any;
    let callSequence: string[];

    beforeEach(() => {
      callSequence = [];

      mockQueryRunner = {
        connect: vi.fn().mockImplementation(async () => {
          callSequence.push('connect');
        }),
        startTransaction: vi.fn().mockImplementation(async () => {
          callSequence.push('startTransaction');
        }),
        commitTransaction: vi.fn().mockImplementation(async () => {
          callSequence.push('commitTransaction');
        }),
        rollbackTransaction: vi.fn().mockImplementation(async () => {
          callSequence.push('rollbackTransaction');
        }),
        release: vi.fn().mockImplementation(async () => {
          callSequence.push('release');
        }),
        manager: {
          createQueryBuilder: vi.fn(),
          find: vi.fn().mockResolvedValue([]),
          save: vi.fn().mockImplementation(async () => {
            callSequence.push('save');
            return [];
          }),
        },
      };

      mockDataSource = {
        createQueryRunner: vi.fn().mockReturnValue(mockQueryRunner),
        getRepository: vi.fn().mockReturnValue({ findOne: vi.fn() }),
      };

      mockRedisService = {
        isReady: true,
        acquireLockDetailed: vi.fn(),
        releaseLock: vi.fn().mockImplementation(async (key: string, token: string) => {
          callSequence.push(`releaseLock:${key}:${token}`);
          return true;
        }),
      };

      mockRiskEvaluator = {
        evaluate: vi.fn().mockReturnValue({ riskScore: 25 }),
      };

      mockIncidentsService = {
        createIncident: vi.fn().mockResolvedValue({ id: 'inc-test-1' }),
      };

      mockNotificationsService = {
        sendNotification: vi.fn().mockResolvedValue(undefined),
      };

      worker = new MonitoringWorkerService(
        mockDataSource,
        mockRedisService,
        mockRiskEvaluator,
        mockIncidentsService,
        mockNotificationsService,
      );
    });

    afterEach(() => {
      vi.clearAllMocks();
    });

    it('1.1 Contention Skip: Skips relationships locked by another worker with zero state mutation', async () => {
      const config1 = {
        id: 'cfg-contended-1',
        relationshipId: 'rel-contended-1',
        enabled: true,
        currentState: MonitoringState.ACTIVE,
        relationship: {
          id: 'rel-contended-1',
          status: RelationshipStatus.ACCEPTED,
          monitoredUserId: 'user-1',
          monitorId: 'monitor-1',
        },
        scheduleWindows: [],
      } as unknown as MonitoringConfig;

      const qb: any = {
        setLock: vi.fn().mockReturnThis(),
        setOnLocked: vi.fn().mockReturnThis(),
        innerJoinAndSelect: vi.fn().mockReturnThis(),
        where: vi.fn().mockReturnThis(),
        andWhere: vi.fn().mockReturnThis(),
        take: vi.fn().mockReturnThis(),
        getMany: vi.fn().mockResolvedValue([config1]),
      };
      mockQueryRunner.manager.createQueryBuilder.mockReturnValue(qb);

      // Simulate lock contention: lock held by another cluster node
      mockRedisService.acquireLockDetailed.mockResolvedValueOnce({
        acquired: false,
        degraded: false,
        token: null,
      } as LockResult);

      const processedCount = await worker.evaluateDueMonitoring(10);

      // Verification: exactly 0 configs processed
      expect(processedCount).toBe(0);
      expect(mockRedisService.acquireLockDetailed).toHaveBeenCalledWith(
        'monitoring:lock:rel-contended-1',
        15000,
      );
      // No save on database
      expect(mockQueryRunner.manager.save).not.toHaveBeenCalled();
      // Transaction committed cleanly (no dangling open transaction)
      expect(mockQueryRunner.commitTransaction).toHaveBeenCalled();
      // releaseLock NEVER called because lock was not acquired
      expect(mockRedisService.releaseLock).not.toHaveBeenCalled();
      expect(mockQueryRunner.release).toHaveBeenCalled();
    });

    it('1.2 Degraded Fallback: Gracefully falls back to DB pessimistic locking when Redis is offline', async () => {
      const config1 = {
        id: 'cfg-degraded-1',
        relationshipId: 'rel-degraded-1',
        enabled: true,
        currentState: MonitoringState.ACTIVE,
        inactivityThresholdMinutes: 60,
        lastMeaningfulActivityAt: new Date(Date.now() - 7200 * 1000), // 2 hours inactive
        requireCheckIn: true,
        checkInGraceMinutes: 15,
        relationship: {
          id: 'rel-degraded-1',
          status: RelationshipStatus.ACCEPTED,
          monitoredUserId: 'user-1',
          monitorId: 'monitor-1',
          monitoredUser: { id: 'user-1', displayName: 'Monitored User' },
          monitor: { id: 'monitor-1', displayName: 'Guardian' },
        },
        scheduleWindows: [],
      } as unknown as MonitoringConfig;

      const qb: any = {
        setLock: vi.fn().mockReturnThis(),
        setOnLocked: vi.fn().mockReturnThis(),
        innerJoinAndSelect: vi.fn().mockReturnThis(),
        where: vi.fn().mockReturnThis(),
        andWhere: vi.fn().mockReturnThis(),
        take: vi.fn().mockReturnThis(),
        getMany: vi.fn().mockResolvedValue([config1]),
      };
      mockQueryRunner.manager.createQueryBuilder.mockReturnValue(qb);

      // Simulate Redis offline/degraded mode
      mockRedisService.acquireLockDetailed.mockResolvedValueOnce({
        acquired: false,
        degraded: true,
        token: null,
      } as LockResult);

      const processedCount = await worker.evaluateDueMonitoring(10);

      // Worker MUST NOT skip in degraded mode: it must process config using DB row lock
      expect(processedCount).toBe(1);
      expect(config1.currentState).toBe(MonitoringState.CHECK_IN_REQUIRED);
      expect(mockQueryRunner.manager.save).toHaveBeenCalled();
      expect(mockQueryRunner.commitTransaction).toHaveBeenCalled();
      // No Redis lock was acquired, so no releaseLock call
      expect(mockRedisService.releaseLock).not.toHaveBeenCalled();
      expect(mockQueryRunner.release).toHaveBeenCalled();
    });

    it('1.3 Post-Commit Lock Release Invariant: Strictly retains locks until AFTER queryRunner.commitTransaction()', async () => {
      const config1 = {
        id: 'cfg-lock-order-1',
        relationshipId: 'rel-lock-order-1',
        enabled: true,
        currentState: MonitoringState.ACTIVE,
        inactivityThresholdMinutes: 60,
        lastMeaningfulActivityAt: new Date(Date.now() - 1000),
        relationship: {
          id: 'rel-lock-order-1',
          status: RelationshipStatus.ACCEPTED,
          monitoredUserId: 'user-1',
          monitorId: 'monitor-1',
          monitoredUser: { id: 'user-1', displayName: 'Monitored User' },
          monitor: { id: 'monitor-1', displayName: 'Guardian' },
        },
        scheduleWindows: [],
      } as unknown as MonitoringConfig;

      const qb: any = {
        setLock: vi.fn().mockReturnThis(),
        setOnLocked: vi.fn().mockReturnThis(),
        innerJoinAndSelect: vi.fn().mockReturnThis(),
        where: vi.fn().mockReturnThis(),
        andWhere: vi.fn().mockReturnThis(),
        take: vi.fn().mockReturnThis(),
        getMany: vi.fn().mockResolvedValue([config1]),
      };
      mockQueryRunner.manager.createQueryBuilder.mockReturnValue(qb);

      const lockToken = 'token-uuid-strict-seq-1234';
      mockRedisService.acquireLockDetailed.mockResolvedValueOnce({
        acquired: true,
        degraded: false,
        token: lockToken,
      } as LockResult);

      await worker.evaluateDueMonitoring(10);

      // Verify strict chronology of operations:
      // commitTransaction MUST happen before releaseLock
      const commitIdx = callSequence.indexOf('commitTransaction');
      const releaseLockIdx = callSequence.findIndex((entry) => entry.startsWith('releaseLock:'));
      const queryRunnerReleaseIdx = callSequence.indexOf('release');

      expect(commitIdx).toBeGreaterThan(-1);
      expect(releaseLockIdx).toBeGreaterThan(-1);
      expect(queryRunnerReleaseIdx).toBeGreaterThan(-1);

      // CRITICAL ASSERTION: commit precedes release
      expect(commitIdx).toBeLessThan(releaseLockIdx);
      expect(releaseLockIdx).toBeLessThan(queryRunnerReleaseIdx);

      expect(mockRedisService.releaseLock).toHaveBeenCalledWith(
        'monitoring:lock:rel-lock-order-1',
        lockToken,
      );
    });

    it('1.4 Batch Mixed Contention: Correctly partitions contended and uncontentious configs in a single batch', async () => {
      const makeConfig = (id: string, relId: string) =>
        ({
          id,
          relationshipId: relId,
          enabled: true,
          currentState: MonitoringState.ACTIVE,
          inactivityThresholdMinutes: 60,
          lastMeaningfulActivityAt: new Date(Date.now() - 1000),
          relationship: {
            id: relId,
            status: RelationshipStatus.ACCEPTED,
            monitoredUserId: `user-${relId}`,
            monitorId: `monitor-${relId}`,
            monitoredUser: { id: `user-${relId}`, displayName: `User ${relId}` },
            monitor: { id: `monitor-${relId}`, displayName: `Guardian ${relId}` },
          },
          scheduleWindows: [],
        }) as unknown as MonitoringConfig;

      const c1 = makeConfig('cfg-1', 'rel-1'); // Acquired
      const c2 = makeConfig('cfg-2', 'rel-2'); // Contention! (Locked by peer)
      const c3 = makeConfig('cfg-3', 'rel-3'); // Acquired
      const c4 = makeConfig('cfg-4', 'rel-4'); // Contention! (Locked by peer)
      const c5 = makeConfig('cfg-5', 'rel-5'); // Acquired

      const qb: any = {
        setLock: vi.fn().mockReturnThis(),
        setOnLocked: vi.fn().mockReturnThis(),
        innerJoinAndSelect: vi.fn().mockReturnThis(),
        where: vi.fn().mockReturnThis(),
        andWhere: vi.fn().mockReturnThis(),
        take: vi.fn().mockReturnThis(),
        getMany: vi.fn().mockResolvedValue([c1, c2, c3, c4, c5]),
      };
      mockQueryRunner.manager.createQueryBuilder.mockReturnValue(qb);

      mockRedisService.acquireLockDetailed
        .mockResolvedValueOnce({ acquired: true, degraded: false, token: 'token-c1' }) // c1
        .mockResolvedValueOnce({ acquired: false, degraded: false, token: null })       // c2 contended
        .mockResolvedValueOnce({ acquired: true, degraded: false, token: 'token-c3' }) // c3
        .mockResolvedValueOnce({ acquired: false, degraded: false, token: null })       // c4 contended
        .mockResolvedValueOnce({ acquired: true, degraded: false, token: 'token-c5' });// c5

      const processedCount = await worker.evaluateDueMonitoring(10);

      // Exactly 3 processed (c1, c3, c5)
      expect(processedCount).toBe(3);

      // Exactly 3 saved
      expect(mockQueryRunner.manager.save).toHaveBeenCalledWith(
        MonitoringConfig,
        expect.arrayContaining([c1, c3, c5]),
      );

      // Exactly 3 locks released in finally
      expect(mockRedisService.releaseLock).toHaveBeenCalledTimes(3);
      expect(mockRedisService.releaseLock).toHaveBeenCalledWith('monitoring:lock:rel-1', 'token-c1');
      expect(mockRedisService.releaseLock).toHaveBeenCalledWith('monitoring:lock:rel-3', 'token-c3');
      expect(mockRedisService.releaseLock).toHaveBeenCalledWith('monitoring:lock:rel-5', 'token-c5');

      // Zero release calls for c2 and c4
      expect(mockRedisService.releaseLock).not.toHaveBeenCalledWith('monitoring:lock:rel-2', expect.anything());
      expect(mockRedisService.releaseLock).not.toHaveBeenCalledWith('monitoring:lock:rel-4', expect.anything());
    });

    it('1.5 Error Resilience: Ensures acquired locks are released even when transaction rollbacks occur', async () => {
      const config1 = {
        id: 'cfg-err-1',
        relationshipId: 'rel-err-1',
        enabled: true,
        currentState: MonitoringState.ACTIVE,
        inactivityThresholdMinutes: 60,
        lastMeaningfulActivityAt: new Date(Date.now() - 1000),
        relationship: {
          id: 'rel-err-1',
          status: RelationshipStatus.ACCEPTED,
          monitoredUserId: 'user-1',
          monitorId: 'monitor-1',
          monitoredUser: { id: 'user-1', displayName: 'Monitored User' },
          monitor: { id: 'monitor-1', displayName: 'Guardian' },
        },
        scheduleWindows: [],
      } as unknown as MonitoringConfig;

      const qb: any = {
        setLock: vi.fn().mockReturnThis(),
        setOnLocked: vi.fn().mockReturnThis(),
        innerJoinAndSelect: vi.fn().mockReturnThis(),
        where: vi.fn().mockReturnThis(),
        andWhere: vi.fn().mockReturnThis(),
        take: vi.fn().mockReturnThis(),
        getMany: vi.fn().mockResolvedValue([config1]),
      };
      mockQueryRunner.manager.createQueryBuilder.mockReturnValue(qb);

      const lockToken = 'token-to-release-on-rollback';
      mockRedisService.acquireLockDetailed.mockResolvedValueOnce({
        acquired: true,
        degraded: false,
        token: lockToken,
      } as LockResult);

      // Inject simulated database save failure causing transaction rollback
      mockQueryRunner.manager.save.mockRejectedValueOnce(new Error('Simulated DB deadlock or disk failure'));

      await expect(worker.evaluateDueMonitoring(10)).rejects.toThrow('Simulated DB deadlock');

      // Verify rollback occurred
      expect(mockQueryRunner.rollbackTransaction).toHaveBeenCalled();
      // CRITICAL ASSERTION: Lock MUST still be released in the finally block
      expect(mockRedisService.releaseLock).toHaveBeenCalledWith('monitoring:lock:rel-err-1', lockToken);
      expect(mockQueryRunner.release).toHaveBeenCalled();
    });
  });

  describe('Adversarial Suite 2: Pipelining, Device Caching & Reachability Buffering in DevicesService', () => {
    let service: DevicesService;
    let mockRepo: any;
    let mockRedis: any;

    beforeEach(() => {
      mockRepo = {
        findOne: vi.fn(),
        find: vi.fn(),
        create: vi.fn((dto) => dto),
        save: vi.fn((entity) => Promise.resolve({ ...entity, id: entity.id || 'dev-saved-id' })),
        update: vi.fn().mockResolvedValue({ affected: 1 }),
        remove: vi.fn().mockResolvedValue({}),
        createQueryBuilder: vi.fn(),
      };

      mockRedis = {
        isReady: true,
        get: vi.fn(),
        set: vi.fn().mockResolvedValue(undefined),
        del: vi.fn().mockResolvedValue(1),
        mget: vi.fn(),
        mset: vi.fn().mockResolvedValue(true),
        hset: vi.fn().mockResolvedValue(true),
        hgetall: vi.fn(),
        expire: vi.fn().mockResolvedValue(true),
      };

      service = new DevicesService(mockRepo, mockRedis);
    });

    afterEach(() => {
      vi.clearAllMocks();
    });

    it('2.1 verifyActiveDevices Pipelining: Uses mget in 1 roundtrip and queries DB only for missing cache entries', async () => {
      const dev1 = { id: 'd-1', userId: 'user-a', isActive: true, revokedAt: null } as Device;
      const dev3 = { id: 'd-3', userId: 'user-a', isActive: true, revokedAt: null } as Device;

      // d-1 and d-3 in cache; d-2 and d-4 are cache misses
      mockRedis.mget.mockResolvedValueOnce([
        JSON.stringify(dev1),
        null,
        JSON.stringify(dev3),
        null,
      ]);

      const dev2Db = { id: 'd-2', userId: 'user-a', isActive: true, revokedAt: null } as Device;
      const dev4Db = { id: 'd-4', userId: 'user-a', isActive: true, revokedAt: null } as Device;
      mockRepo.find.mockResolvedValueOnce([dev2Db, dev4Db]);

      const results = await service.verifyActiveDevices('user-a', ['d-1', 'd-2', 'd-3', 'd-4']);

      expect(results).toHaveLength(4);
      expect(mockRedis.mget).toHaveBeenCalledWith([
        'device:active:d-1',
        'device:active:d-2',
        'device:active:d-3',
        'device:active:d-4',
      ]);

      // DB queried with In filter ONLY for d-2 and d-4
      expect(mockRepo.find).toHaveBeenCalledWith(
        expect.objectContaining({
          where: expect.objectContaining({
            id: expect.anything(),
            userId: 'user-a',
            isActive: true,
          }),
        }),
      );

      // Missing entries written to cache with mset and 300s TTL
      expect(mockRedis.mset).toHaveBeenCalledWith({
        'device:active:d-2': JSON.stringify(dev2Db),
        'device:active:d-4': JSON.stringify(dev4Db),
      });
      expect(mockRedis.expire).toHaveBeenCalledWith('device:active:d-2', 300);
      expect(mockRedis.expire).toHaveBeenCalledWith('device:active:d-4', 300);
    });

    it('2.2 Cache Security & Invalidation: Prevents unauthorized access or revoked device leaks through cache', async () => {
      // Scenario A: Cached device belongs to a different user
      const foreignDevice = {
        id: 'dev-foreign',
        userId: 'other-user',
        isActive: true,
        revokedAt: null,
      };
      mockRedis.get.mockResolvedValueOnce(JSON.stringify(foreignDevice));

      await expect(service.verifyActiveDevice('user-attacker', 'dev-foreign')).rejects.toThrow(
        ForbiddenException,
      );

      // Scenario B: Cached device has revokedAt set
      const revokedDevice = {
        id: 'dev-revoked',
        userId: 'user-victim',
        isActive: false,
        revokedAt: new Date().toISOString(),
      };
      mockRedis.get.mockResolvedValueOnce(JSON.stringify(revokedDevice));

      await expect(service.verifyActiveDevice('user-victim', 'dev-revoked')).rejects.toThrow(
        UnauthorizedException,
      );
    });

    it('2.3 Complete Cache Invalidation: All mutation operations invalidate both active and heartbeat caches', async () => {
      const mockDev = {
        id: 'target-dev-id',
        userId: 'user-x',
        isActive: true,
        revokedAt: null,
        pushToken: 'old-token',
      };
      mockRepo.findOne.mockResolvedValue(mockDev);

      // 1. revokeDevice
      await service.revokeDevice('user-x', 'target-dev-id');
      expect(mockRedis.del).toHaveBeenCalledWith('device:active:target-dev-id');
      expect(mockRedis.del).toHaveBeenCalledWith('device:heartbeat:target-dev-id');

      vi.clearAllMocks();
      mockRepo.findOne.mockResolvedValue(mockDev);

      // 2. updatePushToken
      await service.updatePushToken('user-x', 'target-dev-id', 'new-token');
      expect(mockRedis.del).toHaveBeenCalledWith('device:active:target-dev-id');
      expect(mockRedis.del).toHaveBeenCalledWith('device:heartbeat:target-dev-id');

      vi.clearAllMocks();
      mockRepo.findOne.mockResolvedValue(mockDev);

      // 3. deleteDevice
      await service.deleteDevice('user-x', 'target-dev-id');
      expect(mockRedis.del).toHaveBeenCalledWith('device:active:target-dev-id');
      expect(mockRedis.del).toHaveBeenCalledWith('device:heartbeat:target-dev-id');

      vi.clearAllMocks();
      mockRepo.findOne.mockResolvedValue(mockDev);

      // 4. registerDevice (update existing)
      await service.registerDevice('user-x', {
        deviceUid: 'uid-x',
        platform: DevicePlatform.ANDROID,
        deviceName: 'New Phone',
      });
      expect(mockRedis.del).toHaveBeenCalledWith('device:active:target-dev-id');
      expect(mockRedis.del).toHaveBeenCalledWith('device:heartbeat:target-dev-id');
    });

    it('2.4 Write-Behind Reachability Buffering: Accurately regulates DB write throttling', async () => {
      const qb: any = {
        update: vi.fn().mockReturnThis(),
        set: vi.fn().mockReturnThis(),
        where: vi.fn().mockReturnThis(),
        returning: vi.fn().mockReturnThis(),
        execute: vi.fn().mockResolvedValue({ affected: 1 }),
      };
      mockRepo.createQueryBuilder.mockReturnValue(qb);

      // Test 1: Within 60s and unchanged battery/charging -> THROTTLED (0 DB writes)
      mockRedis.hgetall.mockResolvedValueOnce({
        userId: 'user-heartbeat',
        batteryLevel: '80',
        isCharging: 'false',
        lastDbWriteAt: String(Date.now() - 15_000), // 15 seconds ago
      });

      const res1 = await service.recordHeartbeatAtomic('user-heartbeat', 'dev-hb-1', 80, false);
      expect(res1.success).toBe(true);
      expect(res1.operationalState).toBe('ONLINE');
      expect(qb.execute).not.toHaveBeenCalled(); // Throttled!

      // Test 2: Within 60s BUT battery changed (80 -> 78) -> BYPASS THROTTLE (Executes DB write)
      mockRedis.hgetall.mockResolvedValueOnce({
        userId: 'user-heartbeat',
        batteryLevel: '80',
        isCharging: 'false',
        lastDbWriteAt: String(Date.now() - 15_000),
      });

      const res2 = await service.recordHeartbeatAtomic('user-heartbeat', 'dev-hb-1', 78, false);
      expect(res2.success).toBe(true);
      expect(qb.execute).toHaveBeenCalledTimes(1);

      vi.clearAllMocks();
      mockRepo.createQueryBuilder.mockReturnValue(qb);

      // Test 3: Within 60s BUT charging status changed (false -> true) -> BYPASS THROTTLE (Executes DB write)
      mockRedis.hgetall.mockResolvedValueOnce({
        userId: 'user-heartbeat',
        batteryLevel: '80',
        isCharging: 'false',
        lastDbWriteAt: String(Date.now() - 15_000),
      });

      const res3 = await service.recordHeartbeatAtomic('user-heartbeat', 'dev-hb-1', 80, true);
      expect(res3.success).toBe(true);
      expect(qb.execute).toHaveBeenCalledTimes(1);

      vi.clearAllMocks();
      mockRepo.createQueryBuilder.mockReturnValue(qb);

      // Test 4: Unchanged state BUT > 60s elapsed (75 seconds ago) -> BYPASS THROTTLE (Executes DB write)
      mockRedis.hgetall.mockResolvedValueOnce({
        userId: 'user-heartbeat',
        batteryLevel: '80',
        isCharging: 'false',
        lastDbWriteAt: String(Date.now() - 75_000),
      });

      const res4 = await service.recordHeartbeatAtomic('user-heartbeat', 'dev-hb-1', 80, false);
      expect(res4.success).toBe(true);
      expect(qb.execute).toHaveBeenCalledTimes(1);
    });

    it('2.5 Degraded Redis Resilience: DevicesService functions seamlessly with zero errors when Redis is completely down', async () => {
      // Simulate Redis down
      mockRedis.isReady = false;

      const dbDev = {
        id: 'dev-offline-redis',
        userId: 'user-offline',
        isActive: true,
        revokedAt: null,
      } as Device;
      mockRepo.findOne.mockResolvedValueOnce(dbDev);
      mockRepo.find.mockResolvedValueOnce([dbDev]);

      const qb: any = {
        update: vi.fn().mockReturnThis(),
        set: vi.fn().mockReturnThis(),
        where: vi.fn().mockReturnThis(),
        returning: vi.fn().mockReturnThis(),
        execute: vi.fn().mockResolvedValue({ affected: 1 }),
      };
      mockRepo.createQueryBuilder.mockReturnValue(qb);

      // verifyActiveDevice: falls back directly to DB
      const verified = await service.verifyActiveDevice('user-offline', 'dev-offline-redis');
      expect(verified.id).toBe('dev-offline-redis');
      expect(mockRepo.findOne).toHaveBeenCalled();

      // verifyActiveDevices: queries DB directly
      const bulkVerified = await service.verifyActiveDevices('user-offline', ['dev-offline-redis']);
      expect(bulkVerified).toHaveLength(1);
      expect(mockRepo.find).toHaveBeenCalled();

      // recordHeartbeatAtomic: performs direct DB update without Redis error
      const hbResult = await service.recordHeartbeatAtomic('user-offline', 'dev-offline-redis', 90, true);
      expect(hbResult.success).toBe(true);
      expect(hbResult.operationalState).toBe('ONLINE');
      expect(qb.execute).toHaveBeenCalled();
    });
  });
});
