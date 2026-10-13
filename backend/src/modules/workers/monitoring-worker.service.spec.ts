import { describe, it, expect, vi, beforeEach } from 'vitest';
import { MonitoringWorkerService } from './monitoring-worker.service';
import { MonitoringConfig } from '../monitoring/entities/monitoring-config.entity';
import { MonitoringState, RelationshipStatus } from '../../common/enums';

describe('MonitoringWorkerService (Redlock Mutual Exclusion Unit Tests)', () => {
  let worker: MonitoringWorkerService;
  let mockDataSource: any;
  let mockQueryRunner: any;
  let mockRedisService: any;
  let mockRiskEvaluator: any;
  let mockIncidentsService: any;
  let mockNotificationsService: any;

  beforeEach(() => {
    mockQueryRunner = {
      connect: vi.fn().mockResolvedValue(undefined),
      startTransaction: vi.fn().mockResolvedValue(undefined),
      commitTransaction: vi.fn().mockResolvedValue(undefined),
      rollbackTransaction: vi.fn().mockResolvedValue(undefined),
      release: vi.fn().mockResolvedValue(undefined),
      manager: {
        createQueryBuilder: vi.fn(),
        find: vi.fn().mockResolvedValue([]),
        save: vi.fn().mockResolvedValue([]),
      },
    };

    mockDataSource = {
      createQueryRunner: vi.fn().mockReturnValue(mockQueryRunner),
      getRepository: vi.fn().mockReturnValue({ findOne: vi.fn() }),
    };

    mockRedisService = {
      isReady: true,
      acquireLockDetailed: vi.fn(),
      releaseLock: vi.fn().mockResolvedValue(true),
    };

    mockRiskEvaluator = {
      evaluateRiskScore: vi.fn().mockReturnValue(10),
    };

    mockIncidentsService = {
      createIncident: vi.fn().mockResolvedValue({ id: 'inc-1' }),
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

  it('1. skips configuration evaluation when lock is held by another cluster worker (contention)', async () => {
    const config1 = {
      id: 'cfg-1',
      relationshipId: 'rel-1',
      enabled: true,
      currentState: MonitoringState.ACTIVE,
      relationship: {
        id: 'rel-1',
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

    // Lock contention from another worker node!
    mockRedisService.acquireLockDetailed.mockResolvedValueOnce({
      acquired: false,
      degraded: false,
      token: null,
    });

    const processed = await worker.evaluateDueMonitoring(10);

    expect(processed).toBe(0);
    expect(mockRedisService.acquireLockDetailed).toHaveBeenCalledWith('monitoring:lock:rel-1', 15000);
    // Config was skipped: no evaluate, no save
    expect(mockQueryRunner.manager.save).not.toHaveBeenCalled();
    // Commit transaction executed cleanly
    expect(mockQueryRunner.commitTransaction).toHaveBeenCalled();
    // No lock to release
    expect(mockRedisService.releaseLock).not.toHaveBeenCalled();
    expect(mockQueryRunner.release).toHaveBeenCalled();
  });

  it('2. acquires lock, processes config, and releases lock in finally block after transaction commit', async () => {
    const config1 = {
      id: 'cfg-1',
      relationshipId: 'rel-1',
      enabled: true,
      currentState: MonitoringState.ACTIVE,
      inactivityThresholdMinutes: 60,
      checkInGracePeriodMinutes: 15,
      lastMeaningfulActivityAt: new Date(Date.now() - 3600 * 1000),
      relationship: {
        id: 'rel-1',
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

    // Lock successfully acquired
    mockRedisService.acquireLockDetailed.mockResolvedValueOnce({
      acquired: true,
      degraded: false,
      token: 'valid-lock-token-123',
    });

    // Mock evaluateSingleConfig
    vi.spyOn(worker as any, 'evaluateSingleConfig').mockResolvedValueOnce(null);

    const processed = await worker.evaluateDueMonitoring(10);

    expect(processed).toBe(1);
    expect(mockQueryRunner.manager.save).toHaveBeenCalled();
    expect(mockQueryRunner.commitTransaction).toHaveBeenCalled();
    // Lock released AFTER commit
    expect(mockRedisService.releaseLock).toHaveBeenCalledWith(
      'monitoring:lock:rel-1',
      'valid-lock-token-123',
    );
    expect(mockQueryRunner.release).toHaveBeenCalled();
  });

  it('3. processes config in degraded mode without skipping when Redis is offline', async () => {
    const config1 = {
      id: 'cfg-1',
      relationshipId: 'rel-1',
      enabled: true,
      currentState: MonitoringState.ACTIVE,
      relationship: {
        id: 'rel-1',
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

    // Degraded mode: Redis offline
    mockRedisService.acquireLockDetailed.mockResolvedValueOnce({
      acquired: false,
      degraded: true,
      token: null,
    });

    vi.spyOn(worker as any, 'evaluateSingleConfig').mockResolvedValueOnce(null);

    const processed = await worker.evaluateDueMonitoring(10);

    // Degraded mode proceeds relying on DB pessimistic lock!
    expect(processed).toBe(1);
    expect(mockQueryRunner.manager.save).toHaveBeenCalled();
    expect(mockQueryRunner.commitTransaction).toHaveBeenCalled();
    // No lock was acquired, so no release call
    expect(mockRedisService.releaseLock).not.toHaveBeenCalled();
  });
});
