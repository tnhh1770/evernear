import {
  Injectable,
  Logger,
  BadRequestException,
  HttpException,
  HttpStatus,
  Optional,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, In } from 'typeorm';
import { Activity } from './entities/activity.entity';
import { IngestActivityDto } from './dto/activity.dto';
import { HeartbeatDto } from './dto/heartbeat.dto';
import { DevicesService } from '../devices/devices.service';
import { ActivityPolicyService } from './activity-policy.service';
import { MonitoringConfig } from '../monitoring/entities/monitoring-config.entity';
import { MonitoringRelationship } from '../monitoring/entities/monitoring-relationship.entity';
import { RedisService } from '../../common/redis/redis.service';
import { ActivityType, MonitoringState, RelationshipStatus } from '../../common/enums';
import { RealtimeService } from '../realtime/realtime.service';
import { RealtimeEventType } from '../realtime/realtime.interface';

@Injectable()
export class ActivityService {
  private readonly logger = new Logger(ActivityService.name);

  constructor(
    @InjectRepository(Activity)
    private readonly activityRepo: Repository<Activity>,
    @InjectRepository(MonitoringConfig)
    private readonly configRepo: Repository<MonitoringConfig>,
    @InjectRepository(MonitoringRelationship)
    private readonly relationshipRepo: Repository<MonitoringRelationship>,
    private readonly devicesService: DevicesService,
    private readonly policyService: ActivityPolicyService,
    private readonly redisService: RedisService,
    @Optional()
    private readonly realtimeService?: RealtimeService,
  ) {}

  private isUniqueConstraintViolation(err: any): boolean {
    return (
      err?.code === '23505' ||
      err?.driverError?.code === '23505' ||
      (typeof err?.message === 'string' && err.message.includes('duplicate key'))
    );
  }

  /**
   * Process Heartbeat:
   * Confirms device connectivity without equating it to meaningful human activity!
   * Streamlined: executes single conditional UPDATE on happy path.
   */
  async processHeartbeat(userId: string, dto: HeartbeatDto) {
    // 1. Rate limit: max 1 heartbeat per 30 seconds per device
    const rateLimitKey = `rate-limit:heartbeat:${dto.deviceId}`;
    const rateCheck = await this.redisService.checkRateLimit(rateLimitKey, 2, 30);
    if (!rateCheck.allowed) {
      throw new HttpException(
        'Too many heartbeats. Opportunistic interval exceeded.',
        HttpStatus.TOO_MANY_REQUESTS,
      );
    }

    // 2. Atomic device verification and heartbeat state update in 1 roundtrip
    return this.devicesService.recordHeartbeatAtomic(
      userId,
      dto.deviceId,
      dto.batteryLevel,
      dto.isCharging,
    );
  }

  /**
   * Ingest Activity:
   * Handles idempotency, policy evaluation, timestamp sanity, and meaningful activity calculation.
   */
  async ingestActivity(userId: string, dto: IngestActivityDto): Promise<Activity> {
    // 1. Verify active device
    const device = await this.devicesService.verifyActiveDevice(userId, dto.deviceId);

    // 2. Idempotency Check via DB unique eventId constraint
    const existing = await this.activityRepo.findOne({
      where: { eventId: dto.eventId },
    });
    if (existing) {
      this.logger.debug(`Idempotent hit for eventId: ${dto.eventId}`);
      return existing;
    }

    // 3. Timestamp Sanity: Do not trust client time blindly
    let occurredAt = new Date(dto.occurredAt);
    if (isNaN(occurredAt.getTime())) {
      throw new BadRequestException('Invalid occurredAt timestamp format');
    }
    const now = new Date();
    // If client clock is > 5 minutes in the future, clamp to server now
    if (occurredAt.getTime() > now.getTime() + 5 * 60 * 1000) {
      this.logger.warn(`Clamping future client timestamp from ${occurredAt.toISOString()} to ${now.toISOString()}`);
      occurredAt = now;
    }

    // 4. Evaluate Activity Policy
    const policy = await this.policyService.evaluatePolicy(dto.type);
    const confidence = dto.confidence !== undefined ? dto.confidence : 1.0;
    const isMeaningful = this.policyService.isMeaningful(dto.type, confidence, policy);

    // 5. Create and persist Activity record
    const activity = this.activityRepo.create({
      eventId: dto.eventId,
      userId,
      deviceId: device.id,
      type: dto.type,
      weight: policy.weight,
      confidence,
      occurredAt,
      receivedAt: now,
      source: dto.source || 'MOBILE',
      metadata: dto.metadata || {},
    });

    let savedActivity: Activity;
    try {
      savedActivity = await this.activityRepo.save(activity);
    } catch (err: any) {
      if (this.isUniqueConstraintViolation(err)) {
        this.logger.debug(`Concurrent activity insert race caught for eventId: ${dto.eventId}`);
        const existingRecord = await this.activityRepo.findOne({
          where: { eventId: dto.eventId },
        });
        if (existingRecord) {
          return existingRecord;
        }
      }
      throw err;
    }

    // 6. If meaningful, update monitoring configurations for all relationships where user is monitored
    if (isMeaningful) {
      await this.updateMeaningfulActivityForUser(userId, occurredAt, dto.type);
    }

    return savedActivity;
  }

  /**
   * High-Throughput Batch Ingestion:
   * Uses in-memory deduplication, set-based bulk device verification,
   * in-memory cached policy evaluation, bulk insert, and a single
   * aggregate clock update across relationships.
   */
  async ingestBatch(userId: string, activities: IngestActivityDto[]): Promise<Activity[]> {
    if (!activities || !Array.isArray(activities) || activities.length === 0) {
      return [];
    }

    // 1. In-memory deduplication by eventId within the batch (preserve first occurrence)
    const uniqueMap = new Map<string, IngestActivityDto>();
    for (const act of activities) {
      if (!act?.eventId) continue;
      if (!uniqueMap.has(act.eventId)) {
        uniqueMap.set(act.eventId, act);
      }
    }
    const uniqueActivities = Array.from(uniqueMap.values());
    if (uniqueActivities.length === 0) return [];

    const eventIds = uniqueActivities.map((a) => a.eventId);

    // 2. Bulk verify devices
    const deviceIds = Array.from(new Set(uniqueActivities.map((a) => a.deviceId).filter(Boolean)));
    const validDevices = await this.devicesService.verifyActiveDevices(userId, deviceIds);
    const validDeviceMap = new Map(validDevices.map((d) => [d.id, d]));

    // 3. Bulk idempotency check
    const existingRecords = await this.activityRepo.find({
      where: { eventId: In(eventIds) },
    });
    const existingMap = new Map(existingRecords.map((r) => [r.eventId, r]));

    const now = new Date();
    const toInsert: Activity[] = [];
    const meaningfulItems: { type: ActivityType; occurredAt: Date }[] = [];

    for (const dto of uniqueActivities) {
      if (existingMap.has(dto.eventId)) continue;
      const device = validDeviceMap.get(dto.deviceId);
      if (!device) {
        this.logger.warn(`Device ${dto.deviceId} not found or inactive for activity ${dto.eventId}`);
        continue;
      }

      let occurredAt = new Date(dto.occurredAt);
      if (isNaN(occurredAt.getTime())) {
        this.logger.warn(`Invalid occurredAt timestamp for activity ${dto.eventId}`);
        continue;
      }
      if (occurredAt.getTime() > now.getTime() + 5 * 60 * 1000) {
        occurredAt = now;
      }

      const policy = this.policyService.getCachedPolicy(dto.type);
      const confidence = dto.confidence !== undefined ? dto.confidence : 1.0;
      const isMeaningful = this.policyService.isMeaningful(dto.type, confidence, policy);

      toInsert.push(
        this.activityRepo.create({
          eventId: dto.eventId,
          userId,
          deviceId: device.id,
          type: dto.type,
          weight: policy.weight,
          confidence,
          occurredAt,
          receivedAt: now,
          source: dto.source || 'MOBILE',
          metadata: dto.metadata || {},
        }),
      );

      if (isMeaningful) {
        meaningfulItems.push({ type: dto.type, occurredAt });
      }
    }

    // 4. Bulk insert new activities with concurrency race fallback
    let savedActivities: Activity[] = [];
    if (toInsert.length > 0) {
      try {
        savedActivities = await this.activityRepo.save(toInsert);
      } catch (err: any) {
        if (this.isUniqueConstraintViolation(err)) {
          this.logger.debug('Concurrent activity batch insert race caught');
          const refetched = await this.activityRepo.find({
            where: { eventId: In(eventIds) },
          });
          const refetchedMap = new Map(refetched.map((r) => [r.eventId, r]));
          const remainingToInsert = toInsert.filter((a) => !refetchedMap.has(a.eventId));
          if (remainingToInsert.length > 0) {
            try {
              const extra = await this.activityRepo.save(remainingToInsert);
              savedActivities = [...refetched, ...extra];
            } catch {
              savedActivities = await this.activityRepo.find({
                where: { eventId: In(eventIds) },
              });
            }
          } else {
            savedActivities = refetched;
          }
        } else {
          throw err;
        }
      }
    }

    // 5. Aggregate meaningful activity update (Single query per relationship for the MAX timestamp)
    if (meaningfulItems.length > 0) {
      await this.updateBatchMeaningfulActivityForUser(userId, meaningfulItems);
    }

    // Combine existing hits and newly saved activities preserving batch order
    const resultMap = new Map<string, Activity>();
    for (const e of existingRecords) resultMap.set(e.eventId, e);
    for (const s of savedActivities) resultMap.set(s.eventId, s);

    return activities
      .map((a) => resultMap.get(a.eventId))
      .filter((a): a is Activity => !!a);
  }

  /**
   * Aggregate clock update across active relationships for a batch of meaningful activities
   */
  private async updateBatchMeaningfulActivityForUser(
    userId: string,
    meaningfulItems: { type: ActivityType; occurredAt: Date }[],
  ) {
    if (!meaningfulItems || meaningfulItems.length === 0) return;

    const relationships = await this.relationshipRepo.find({
      where: {
        monitoredUserId: userId,
        status: RelationshipStatus.ACCEPTED,
      },
      relations: { config: true },
    });

    for (const rel of relationships) {
      if (!rel.config || !rel.config.enabled) continue;

      const allowedTypes = rel.config.activityTypes || [];
      const matchingItems =
        allowedTypes.length > 0
          ? meaningfulItems.filter((m) => allowedTypes.includes(m.type))
          : meaningfulItems;

      if (matchingItems.length === 0) continue;

      // Find the maximum occurredAt among matching activities
      const maxOccurredAt = new Date(
        Math.max(...matchingItems.map((m) => m.occurredAt.getTime())),
      );

      const config = rel.config;
      const currentLast = config.lastMeaningfulActivityAt
        ? new Date(config.lastMeaningfulActivityAt)
        : new Date(0);

      if (maxOccurredAt.getTime() > currentLast.getTime()) {
        const nextEval = new Date(
          maxOccurredAt.getTime() + config.inactivityThresholdMinutes * 60 * 1000,
        );

        let targetState: MonitoringState | undefined;
        const hasCheckIn = matchingItems.some((m) => m.type === ActivityType.CHECK_IN);
        if (
          hasCheckIn &&
          (config.currentState === MonitoringState.CHECK_IN_REQUIRED ||
            config.currentState === MonitoringState.CHECK_IN_PENDING ||
            config.currentState === MonitoringState.WARNING)
        ) {
          targetState = MonitoringState.ACTIVE;
        }

        await this.configRepo
          .createQueryBuilder()
          .update(MonitoringConfig)
          .set({
            lastMeaningfulActivityAt: maxOccurredAt,
            nextEvaluationAt: nextEval,
            ...(targetState ? { currentState: targetState } : {}),
          })
          .where(
            'id = :id AND (last_meaningful_activity_at IS NULL OR last_meaningful_activity_at < :occurredAt)',
            {
              id: config.id,
              occurredAt: maxOccurredAt,
            },
          )
          .execute();
      }
    }

    if (this.realtimeService && meaningfulItems.length > 0) {
      const latest = meaningfulItems[meaningfulItems.length - 1];
      this.realtimeService
        .emitToMonitorsOf(userId, {
          type: RealtimeEventType.ACTIVITY_RECORDED,
          userId,
          activityType: latest.type,
          occurredAt: latest.occurredAt.toISOString(),
        })
        .catch(() => {});
    }
  }

  /**
   * Update lastMeaningfulActivityAt and nextEvaluationAt across active relationships (single item)
   */
  private async updateMeaningfulActivityForUser(
    userId: string,
    occurredAt: Date,
    activityType: ActivityType,
  ) {
    const relationships = await this.relationshipRepo.find({
      where: {
        monitoredUserId: userId,
        status: RelationshipStatus.ACCEPTED,
      },
      relations: { config: true },
    });

    for (const rel of relationships) {
      if (!rel.config || !rel.config.enabled) continue;

      // Check if this activity type is monitored by this relationship
      const allowedTypes = rel.config.activityTypes || [];
      if (allowedTypes.length > 0 && !allowedTypes.includes(activityType)) {
        continue;
      }

      const config = rel.config;
      const currentLast = config.lastMeaningfulActivityAt
        ? new Date(config.lastMeaningfulActivityAt)
        : new Date(0);

      if (occurredAt.getTime() > currentLast.getTime()) {
        const nextEval = new Date(
          occurredAt.getTime() + config.inactivityThresholdMinutes * 60 * 1000,
        );

        let targetState: MonitoringState | undefined;
        // If user was in CHECK_IN_REQUIRED or CHECK_IN_PENDING and performs CHECK_IN, reset to ACTIVE
        if (
          activityType === ActivityType.CHECK_IN &&
          (config.currentState === MonitoringState.CHECK_IN_REQUIRED ||
            config.currentState === MonitoringState.CHECK_IN_PENDING ||
            config.currentState === MonitoringState.WARNING)
        ) {
          targetState = MonitoringState.ACTIVE;
        }

        await this.configRepo
          .createQueryBuilder()
          .update(MonitoringConfig)
          .set({
            lastMeaningfulActivityAt: occurredAt,
            nextEvaluationAt: nextEval,
            ...(targetState ? { currentState: targetState } : {}),
          })
          .where(
            'id = :id AND (last_meaningful_activity_at IS NULL OR last_meaningful_activity_at < :occurredAt)',
            {
              id: config.id,
              occurredAt,
            },
          )
          .execute();
      }
    }

    if (this.realtimeService) {
      this.realtimeService
        .emitToMonitorsOf(userId, {
          type: RealtimeEventType.ACTIVITY_RECORDED,
          userId,
          activityType,
          occurredAt: occurredAt.toISOString(),
        })
        .catch(() => {});
    }
  }

  async listRecentActivities(userId: string, limit: number = 50) {
    return this.activityRepo.find({
      where: { userId },
      order: { occurredAt: 'DESC' },
      take: Math.min(limit, 100),
    });
  }
}
