import { describe, it, expect, vi, beforeEach } from 'vitest';
import { NotFoundException, ForbiddenException, UnauthorizedException } from '@nestjs/common';
import { DevicesService } from './devices.service';
import { Device } from './entities/device.entity';

describe('DevicesService (Optimized Ingestion & Verification Unit Tests)', () => {
  let service: DevicesService;
  let deviceRepo: any;

  beforeEach(() => {
    deviceRepo = {
      findOne: vi.fn(),
      find: vi.fn(),
      create: vi.fn((dto) => dto),
      save: vi.fn((entity) => Promise.resolve({ ...entity, id: entity.id || 'dev-id' })),
      update: vi.fn().mockResolvedValue({ affected: 1 }),
      createQueryBuilder: vi.fn(),
    };
    service = new DevicesService(deviceRepo);
  });

  describe('verifyActiveDevices (Bulk Device Verification)', () => {
    it('1. should return empty array for empty deviceIds input', async () => {
      const result = await service.verifyActiveDevices('user-1', []);
      expect(result).toEqual([]);
      expect(deviceRepo.find).not.toHaveBeenCalled();
    });

    it('2. should query repository with In filter and active/non-revoked conditions', async () => {
      const mockDevices = [
        { id: 'dev-1', userId: 'user-1', isActive: true, revokedAt: null },
        { id: 'dev-2', userId: 'user-1', isActive: true, revokedAt: null },
      ] as Device[];
      deviceRepo.find.mockResolvedValueOnce(mockDevices);

      const result = await service.verifyActiveDevices('user-1', ['dev-1', 'dev-2']);
      expect(result).toEqual(mockDevices);
      expect(deviceRepo.find).toHaveBeenCalledWith(
        expect.objectContaining({
          where: expect.objectContaining({
            userId: 'user-1',
            isActive: true,
          }),
        }),
      );
    });
  });

  describe('recordHeartbeatAtomic (Streamlined Single-Query Heartbeat)', () => {
    it('1. should update and return ONLINE status in a single roundtrip on happy path', async () => {
      const qb: any = {
        update: vi.fn().mockReturnThis(),
        set: vi.fn().mockReturnThis(),
        where: vi.fn().mockReturnThis(),
        returning: vi.fn().mockReturnThis(),
        execute: vi.fn().mockResolvedValue({ affected: 1 }),
      };
      deviceRepo.createQueryBuilder.mockReturnValue(qb);

      const result = await service.recordHeartbeatAtomic('user-1', 'dev-1', 95, false);

      expect(result.success).toBe(true);
      expect(result.deviceId).toBe('dev-1');
      expect(result.operationalState).toBe('ONLINE');
      expect(result.lastHeartbeatAt).toBeDefined();
      expect(deviceRepo.findOne).not.toHaveBeenCalled(); // 0 extra SELECT queries!
    });

    it('2. should fall back to detailed verification and throw NotFoundException if device does not exist', async () => {
      const qb: any = {
        update: vi.fn().mockReturnThis(),
        set: vi.fn().mockReturnThis(),
        where: vi.fn().mockReturnThis(),
        returning: vi.fn().mockReturnThis(),
        execute: vi.fn().mockResolvedValue({ affected: 0 }),
      };
      deviceRepo.createQueryBuilder.mockReturnValue(qb);
      deviceRepo.findOne.mockResolvedValueOnce(null);

      await expect(
        service.recordHeartbeatAtomic('user-1', 'missing-dev'),
      ).rejects.toThrow(NotFoundException);
    });

    it('3. should fall back to detailed verification and throw ForbiddenException if user does not own device', async () => {
      const qb: any = {
        update: vi.fn().mockReturnThis(),
        set: vi.fn().mockReturnThis(),
        where: vi.fn().mockReturnThis(),
        returning: vi.fn().mockReturnThis(),
        execute: vi.fn().mockResolvedValue({ affected: 0 }),
      };
      deviceRepo.createQueryBuilder.mockReturnValue(qb);
      deviceRepo.findOne.mockResolvedValueOnce({
        id: 'foreign-dev',
        userId: 'other-user',
        isActive: true,
        revokedAt: null,
      });

      await expect(
        service.recordHeartbeatAtomic('user-1', 'foreign-dev'),
      ).rejects.toThrow(ForbiddenException);
    });

    it('4. should fall back to detailed verification and throw UnauthorizedException if device is revoked', async () => {
      const qb: any = {
        update: vi.fn().mockReturnThis(),
        set: vi.fn().mockReturnThis(),
        where: vi.fn().mockReturnThis(),
        returning: vi.fn().mockReturnThis(),
        execute: vi.fn().mockResolvedValue({ affected: 0 }),
      };
      deviceRepo.createQueryBuilder.mockReturnValue(qb);
      deviceRepo.findOne.mockResolvedValueOnce({
        id: 'revoked-dev',
        userId: 'user-1',
        isActive: false,
        revokedAt: new Date(),
      });

      await expect(
        service.recordHeartbeatAtomic('user-1', 'revoked-dev'),
      ).rejects.toThrow(UnauthorizedException);
    });
  });

  describe('Feature 55: Redis Device Caching & Write-Behind Reachability Buffering', () => {
    let mockRedis: any;
    let redisAwareService: DevicesService;

    beforeEach(() => {
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
      redisAwareService = new DevicesService(deviceRepo, mockRedis);
    });

    it('1. verifyActiveDevice returns cached device on cache hit without hitting PostgreSQL', async () => {
      const cachedDevice: Partial<Device> = {
        id: 'dev-1',
        userId: 'user-1',
        isActive: true,
        revokedAt: null,
        deviceName: 'Pixel 9',
      };
      mockRedis.get.mockResolvedValueOnce(JSON.stringify(cachedDevice));

      const result = await redisAwareService.verifyActiveDevice('user-1', 'dev-1');

      expect(result.id).toBe('dev-1');
      expect(result.deviceName).toBe('Pixel 9');
      expect(mockRedis.get).toHaveBeenCalledWith('device:active:dev-1');
      expect(deviceRepo.findOne).not.toHaveBeenCalled(); // 0 DB queries!
    });

    it('2. verifyActiveDevice queries DB on cache miss and writes to Redis cache with 300s TTL', async () => {
      mockRedis.get.mockResolvedValueOnce(null);
      const dbDevice = {
        id: 'dev-1',
        userId: 'user-1',
        isActive: true,
        revokedAt: null,
      };
      deviceRepo.findOne.mockResolvedValueOnce(dbDevice);

      const result = await redisAwareService.verifyActiveDevice('user-1', 'dev-1');

      expect(result.id).toBe('dev-1');
      expect(deviceRepo.findOne).toHaveBeenCalledWith({ where: { id: 'dev-1' } });
      expect(mockRedis.set).toHaveBeenCalledWith(
        'device:active:dev-1',
        JSON.stringify(dbDevice),
        300,
      );
    });

    it('3. verifyActiveDevices uses mget and queries DB only for missing cache entries', async () => {
      const cachedDev = { id: 'dev-1', userId: 'user-1', isActive: true, revokedAt: null };
      // dev-1 is cached, dev-2 is miss
      mockRedis.mget.mockResolvedValueOnce([JSON.stringify(cachedDev), null]);

      const dbDev = { id: 'dev-2', userId: 'user-1', isActive: true, revokedAt: null };
      deviceRepo.find.mockResolvedValueOnce([dbDev]);

      const result = await redisAwareService.verifyActiveDevices('user-1', ['dev-1', 'dev-2']);

      expect(result).toHaveLength(2);
      expect(mockRedis.mget).toHaveBeenCalledWith(['device:active:dev-1', 'device:active:dev-2']);
      // DB only queried for dev-2!
      expect(deviceRepo.find).toHaveBeenCalledWith(
        expect.objectContaining({
          where: expect.objectContaining({
            id: expect.anything(),
            userId: 'user-1',
          }),
        }),
      );
      expect(mockRedis.mset).toHaveBeenCalled();
    });

    it('4. recordHeartbeatAtomic throttles DB write when device state is unchanged and within 60s', async () => {
      // Simulate recent DB write with identical battery & charging
      mockRedis.hgetall.mockResolvedValueOnce({
        userId: 'user-1',
        batteryLevel: '85',
        isCharging: 'false',
        lastDbWriteAt: String(Date.now() - 10_000), // 10s ago (<60s)
      });

      const qb: any = {
        update: vi.fn().mockReturnThis(),
        set: vi.fn().mockReturnThis(),
        where: vi.fn().mockReturnThis(),
        returning: vi.fn().mockReturnThis(),
        execute: vi.fn(),
      };
      deviceRepo.createQueryBuilder.mockReturnValue(qb);

      const result = await redisAwareService.recordHeartbeatAtomic('user-1', 'dev-1', 85, false);

      expect(result.success).toBe(true);
      expect(result.operationalState).toBe('ONLINE');
      // DB update was throttled!
      expect(qb.execute).not.toHaveBeenCalled();
      // Redis buffer was updated with new timestamp
      expect(mockRedis.hset).toHaveBeenCalledWith(
        'device:heartbeat:dev-1',
        expect.objectContaining({
          lastSeenAt: expect.any(String),
          lastHeartbeatAt: expect.any(String),
        }),
      );
    });

    it('5. recordHeartbeatAtomic executes DB update when battery level changes', async () => {
      // Previous battery was 85, now 80 (delta >= 1)
      mockRedis.hgetall.mockResolvedValueOnce({
        userId: 'user-1',
        batteryLevel: '85',
        isCharging: 'false',
        lastDbWriteAt: String(Date.now() - 10_000),
      });

      const qb: any = {
        update: vi.fn().mockReturnThis(),
        set: vi.fn().mockReturnThis(),
        where: vi.fn().mockReturnThis(),
        returning: vi.fn().mockReturnThis(),
        execute: vi.fn().mockResolvedValue({ affected: 1 }),
      };
      deviceRepo.createQueryBuilder.mockReturnValue(qb);

      const result = await redisAwareService.recordHeartbeatAtomic('user-1', 'dev-1', 80, false);

      expect(result.success).toBe(true);
      // DB update WAS executed!
      expect(qb.execute).toHaveBeenCalledTimes(1);
      // Redis buffer refreshed
      expect(mockRedis.hset).toHaveBeenCalledWith(
        'device:heartbeat:dev-1',
        expect.objectContaining({
          userId: 'user-1',
          batteryLevel: 80,
        }),
      );
    });

    it('6. revokeDevice invalidates active device and heartbeat buffer caches', async () => {
      deviceRepo.findOne.mockResolvedValueOnce({
        id: 'dev-1',
        userId: 'user-1',
        isActive: true,
        revokedAt: null,
      });

      await redisAwareService.revokeDevice('user-1', 'dev-1');

      expect(mockRedis.del).toHaveBeenCalledWith('device:active:dev-1');
      expect(mockRedis.del).toHaveBeenCalledWith('device:heartbeat:dev-1');
    });
  });
});
