import {
  Injectable,
  NotFoundException,
  ForbiddenException,
  UnauthorizedException,
  Optional,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, In, IsNull } from 'typeorm';
import { Device } from './entities/device.entity';
import { RegisterDeviceDto } from './dto/device.dto';
import { RedisService } from '../../common/redis/redis.service';

@Injectable()
export class DevicesService {
  constructor(
    @InjectRepository(Device)
    private readonly deviceRepository: Repository<Device>,
    @Optional()
    private readonly redisService?: RedisService,
  ) {}

  private async invalidateDeviceCache(deviceId: string): Promise<void> {
    if (this.redisService && this.redisService.isReady) {
      await Promise.all([
        this.redisService.del(`device:active:${deviceId}`).catch(() => 0),
        this.redisService.del(`device:heartbeat:${deviceId}`).catch(() => 0),
      ]);
    }
  }

  async registerDevice(userId: string, dto: RegisterDeviceDto) {
    let device = await this.deviceRepository.findOne({
      where: { userId, deviceUid: dto.deviceUid },
    });

    if (device) {
      // Re-activate if revoked earlier and updating
      device.deviceName = dto.deviceName;
      device.platform = dto.platform;
      if (dto.pushToken !== undefined) device.pushToken = dto.pushToken;
      if (dto.appVersion !== undefined) device.appVersion = dto.appVersion;
      if (dto.osVersion !== undefined) device.osVersion = dto.osVersion;
      if (dto.batteryLevel !== undefined) device.batteryLevel = dto.batteryLevel;
      if (dto.isCharging !== undefined) device.isCharging = dto.isCharging;
      device.lastSeenAt = new Date();
      device.isActive = true;
      device.revokedAt = null as any;
      const saved = await this.deviceRepository.save(device);
      await this.invalidateDeviceCache(saved.id);
      return saved;
    }

    device = this.deviceRepository.create({
      userId,
      deviceUid: dto.deviceUid,
      platform: dto.platform,
      deviceName: dto.deviceName,
      pushToken: dto.pushToken,
      appVersion: dto.appVersion,
      osVersion: dto.osVersion,
      batteryLevel: dto.batteryLevel,
      isCharging: dto.isCharging ?? false,
      isActive: true,
      lastSeenAt: new Date(),
    });

    const saved = await this.deviceRepository.save(device);
    await this.invalidateDeviceCache(saved.id);
    return saved;
  }

  async listDevices(userId: string) {
    return this.deviceRepository.find({
      where: { userId },
      order: { lastSeenAt: 'DESC' },
    });
  }

  async getDevice(userId: string, deviceId: string) {
    const device = await this.deviceRepository.findOne({
      where: { id: deviceId },
    });
    if (!device) {
      throw new NotFoundException('Device not found');
    }
    if (device.userId !== userId) {
      throw new ForbiddenException('You do not own this device');
    }
    return device;
  }

  async revokeDevice(userId: string, deviceId: string) {
    const device = await this.getDevice(userId, deviceId);
    device.isActive = false;
    device.revokedAt = new Date();
    const saved = await this.deviceRepository.save(device);
    await this.invalidateDeviceCache(deviceId);
    return saved;
  }

  async deleteDevice(userId: string, deviceId: string) {
    const device = await this.getDevice(userId, deviceId);
    await this.deviceRepository.remove(device);
    await this.invalidateDeviceCache(deviceId);
    return { success: true, message: 'Device deleted' };
  }

  async updatePushToken(userId: string, deviceId: string, pushToken: string) {
    const device = await this.getDevice(userId, deviceId);
    device.pushToken = pushToken;
    device.lastSeenAt = new Date();
    const saved = await this.deviceRepository.save(device);
    await this.invalidateDeviceCache(deviceId);
    return saved;
  }

  /**
   * Internal verification: device must exist, belong to user, and be active.
   * Utilizes Redis lookaside cache (device:active:${deviceId}, 5m TTL).
   */
  async verifyActiveDevice(userId: string, deviceId: string): Promise<Device> {
    const cacheKey = `device:active:${deviceId}`;
    if (this.redisService && this.redisService.isReady) {
      try {
        const cached = await this.redisService.get(cacheKey);
        if (cached) {
          const device = JSON.parse(cached) as Device;
          if (device.userId !== userId) {
            throw new ForbiddenException('Device does not belong to the authenticated user');
          }
          if (!device.isActive || device.revokedAt !== null) {
            throw new UnauthorizedException('Device has been revoked. Access denied.');
          }
          return device;
        }
      } catch (err) {
        if (err instanceof ForbiddenException || err instanceof UnauthorizedException) {
          throw err;
        }
        // Fall back to database query on cache miss or parse error
      }
    }

    let device = await this.deviceRepository.findOne({
      where: { id: deviceId },
    });

    if (device && device.userId !== userId) {
      throw new ForbiddenException('Device does not belong to the authenticated user');
    }

    if (!device) {
      // Check if deviceId passed was actually deviceUid
      device = await this.deviceRepository.findOne({
        where: { deviceUid: deviceId, userId },
      });
    }

    if (!device) {
      throw new NotFoundException(`Device ${deviceId} not found`);
    }

    if (!device.isActive || device.revokedAt !== null) {
      throw new UnauthorizedException('Device has been revoked. Access denied.');
    }

    if (this.redisService && this.redisService.isReady) {
      await this.redisService.set(cacheKey, JSON.stringify(device), 300).catch(() => {});
    }

    return device;
  }

  async updateHeartbeatState(
    deviceId: string,
    batteryLevel?: number,
    isCharging?: boolean,
  ) {
    await this.deviceRepository.update(deviceId, {
      lastSeenAt: new Date(),
      lastHeartbeatAt: new Date(),
      ...(batteryLevel !== undefined ? { batteryLevel } : {}),
      ...(isCharging !== undefined ? { isCharging } : {}),
    });
  }

  /**
   * Bulk verify devices for batch ingestion:
   * Uses Redis pipelined mget across device:active:${id} keys in 1 roundtrip,
   * querying PostgreSQL only for cache misses with In(missingIds).
   */
  async verifyActiveDevices(userId: string, deviceIds: string[]): Promise<Device[]> {
    if (!deviceIds || deviceIds.length === 0) return [];

    const foundDevices: Device[] = [];
    const missingIds: string[] = [];

    if (this.redisService && this.redisService.isReady) {
      try {
        const keys = deviceIds.map((id) => `device:active:${id}`);
        const cachedResults = await this.redisService.mget(keys);
        for (let i = 0; i < deviceIds.length; i++) {
          const raw = cachedResults[i];
          if (raw) {
            try {
              const dev = JSON.parse(raw) as Device;
              if (dev.userId === userId && dev.isActive && dev.revokedAt === null) {
                foundDevices.push(dev);
                continue;
              }
            } catch {
              // fallback
            }
          }
          missingIds.push(deviceIds[i]);
        }
      } catch {
        missingIds.push(...deviceIds);
      }
    } else {
      missingIds.push(...deviceIds);
    }

    if (missingIds.length > 0) {
      const dbDevices = await this.deviceRepository.find({
        where: {
          id: In(missingIds),
          userId,
          isActive: true,
          revokedAt: IsNull(),
        },
      });
      foundDevices.push(...dbDevices);

      // Populate Redis cache for fetched devices
      if (this.redisService && this.redisService.isReady && dbDevices.length > 0) {
        const kv: Record<string, string> = {};
        for (const d of dbDevices) {
          kv[`device:active:${d.id}`] = JSON.stringify(d);
        }
        await this.redisService.mset(kv).catch(() => false);
        await Promise.all(
          dbDevices.map((d) => this.redisService!.expire(`device:active:${d.id}`, 300).catch(() => false)),
        );
      }
    }

    return foundDevices;
  }

  /**
   * Single conditional UPDATE on the happy path to verify active device ownership
   * and update last_seen_at, last_heartbeat_at, battery_level, is_charging in 1 roundtrip.
   * Includes Redis write-behind reachability buffer to throttle redundant PostgreSQL writes
   * when device state (battery level & charging status) is unchanged.
   */
  async recordHeartbeatAtomic(
    userId: string,
    deviceId: string,
    batteryLevel?: number,
    isCharging?: boolean,
  ): Promise<{ success: boolean; deviceId: string; lastHeartbeatAt: string; operationalState: string }> {
    const now = new Date();
    const nowIso = now.toISOString();

    // Redis Write-Behind Reachability Buffering
    if (this.redisService && this.redisService.isReady) {
      const bufferKey = `device:heartbeat:${deviceId}`;
      try {
        const cachedBuffer = await this.redisService.hgetall(bufferKey);
        if (
          cachedBuffer &&
          cachedBuffer.userId === userId &&
          cachedBuffer.lastDbWriteAt
        ) {
          const prevBattery =
            cachedBuffer.batteryLevel !== undefined ? Number(cachedBuffer.batteryLevel) : undefined;
          const prevCharging =
            cachedBuffer.isCharging !== undefined ? cachedBuffer.isCharging === 'true' : undefined;
          const lastDbWriteTime = Number(cachedBuffer.lastDbWriteAt);
          const elapsedMs = Date.now() - lastDbWriteTime;

          const batteryChanged =
            batteryLevel !== undefined && prevBattery !== undefined
              ? Math.abs(batteryLevel - prevBattery) >= 1
              : batteryLevel !== prevBattery;

          const chargingChanged =
            isCharging !== undefined && prevCharging !== undefined
              ? isCharging !== prevCharging
              : isCharging !== prevCharging;

          const isUnchanged = !batteryChanged && !chargingChanged;

          // If state is unchanged and last DB write was within 60s, throttle DB write!
          if (isUnchanged && elapsedMs < 60_000) {
            await this.redisService.hset(bufferKey, {
              lastSeenAt: nowIso,
              lastHeartbeatAt: nowIso,
            });
            await this.redisService.expire(bufferKey, 300);

            return {
              success: true,
              deviceId,
              lastHeartbeatAt: nowIso,
              operationalState: 'ONLINE',
            };
          }
        }
      } catch {
        // Fall back to database update on Redis buffer error
      }
    }

    const result = await this.deviceRepository
      .createQueryBuilder()
      .update(Device)
      .set({
        lastSeenAt: now,
        lastHeartbeatAt: now,
        ...(batteryLevel !== undefined ? { batteryLevel } : {}),
        ...(isCharging !== undefined ? { isCharging } : {}),
      })
      .where('id = :deviceId AND user_id = :userId AND is_active = TRUE AND revoked_at IS NULL', {
        deviceId,
        userId,
      })
      .returning(['id'])
      .execute();

    if (result.affected && result.affected > 0) {
      if (this.redisService && this.redisService.isReady) {
        const bufferKey = `device:heartbeat:${deviceId}`;
        const payload: Record<string, string | number> = {
          userId,
          lastSeenAt: nowIso,
          lastHeartbeatAt: nowIso,
          lastDbWriteAt: Date.now(),
        };
        if (batteryLevel !== undefined) payload.batteryLevel = batteryLevel;
        if (isCharging !== undefined) payload.isCharging = String(isCharging);

        await this.redisService.hset(bufferKey, payload).catch(() => false);
        await this.redisService.expire(bufferKey, 300).catch(() => false);
      }

      return {
        success: true,
        deviceId,
        lastHeartbeatAt: nowIso,
        operationalState: 'ONLINE',
      };
    }

    // Slow/error path: verifyActiveDevice to distinguish 404, 403, and 401 exceptions
    await this.verifyActiveDevice(userId, deviceId);
    throw new NotFoundException(`Device ${deviceId} not found or inactive`);
  }
}
