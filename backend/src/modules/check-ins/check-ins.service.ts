import {
  Injectable,
  Logger,
  BadRequestException,
  NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, In } from 'typeorm';
import { CheckIn } from './entities/check-in.entity';
import { CreateCheckInDto } from './dto/check-in.dto';
import { DevicesService } from '../devices/devices.service';
import { Device } from '../devices/entities/device.entity';
import { Activity } from '../activities/entities/activity.entity';
import { MonitoringConfig } from '../monitoring/entities/monitoring-config.entity';
import { MonitoringRelationship } from '../monitoring/entities/monitoring-relationship.entity';
import { Incident } from '../incidents/entities/incident.entity';
import { IncidentEvent } from '../incidents/entities/incident-event.entity';
import { Location } from '../locations/entities/location.entity';
import { User } from '../users/entities/user.entity';
import { NotificationsService } from '../notifications/notifications.service';
import { RealtimeService } from '../realtime/realtime.service';
import {
  ActivityType,
  MonitoringState,
  RelationshipStatus,
  IncidentStatus,
  IncidentEventType,
} from '../../common/enums';
import { MonitoringStateMachine } from '../monitoring/monitoring-state-machine';

@Injectable()
export class CheckInsService {
  private readonly logger = new Logger(CheckInsService.name);

  constructor(
    @InjectRepository(CheckIn)
    private readonly checkInRepo: Repository<CheckIn>,
    @InjectRepository(Activity)
    private readonly activityRepo: Repository<Activity>,
    @InjectRepository(MonitoringConfig)
    private readonly configRepo: Repository<MonitoringConfig>,
    @InjectRepository(MonitoringRelationship)
    private readonly relationshipRepo: Repository<MonitoringRelationship>,
    @InjectRepository(Incident)
    private readonly incidentRepo: Repository<Incident>,
    @InjectRepository(IncidentEvent)
    private readonly eventRepo: Repository<IncidentEvent>,
    @InjectRepository(Location)
    private readonly locationRepo: Repository<Location>,
    @InjectRepository(User)
    private readonly userRepo: Repository<User>,
    private readonly devicesService: DevicesService,
    private readonly notificationsService: NotificationsService,
    private readonly realtimeService?: RealtimeService,
  ) {}

  private isUniqueConstraintViolation(err: any): boolean {
    return (
      err?.code === '23505' ||
      err?.driverError?.code === '23505' ||
      (typeof err?.message === 'string' && err.message.includes('duplicate key'))
    );
  }

  async processCheckIn(
    userId: string,
    dto: CreateCheckInDto,
    userDisplayName?: string,
  ): Promise<CheckIn> {
    // 1. Verify active device with life-safety fallback
    let device: Device;
    try {
      device = await this.devicesService.verifyActiveDevice(userId, dto.deviceId);
    } catch (err) {
      if (err instanceof NotFoundException) {
        // Fallback: check if user already has an active device registered
        const userDevices = await this.devicesService.listDevices(userId);
        const activeDev = userDevices.find((d: Device) => d.isActive && !d.revokedAt);
        if (activeDev) {
          device = activeDev;
        } else {
          // Life-safety axiom: Auto-register active device for authenticated user so check-in never drops
          device = await this.devicesService.registerDevice(userId, {
            deviceUid: dto.deviceId || `device-${userId.slice(0, 8)}`,
            platform: 'ANDROID' as any,
            deviceName: 'Active Client Device',
          });
        }
      } else {
        throw err;
      }
    }

    // 2. Idempotency Check
    const existing = await this.checkInRepo.findOne({
      where: { eventId: dto.eventId },
    });
    if (existing) {
      this.logger.debug(`Idempotent check-in hit for eventId: ${dto.eventId}`);
      return existing;
    }

    let occurredAt = new Date(dto.occurredAt);
    if (isNaN(occurredAt.getTime())) {
      throw new BadRequestException('Invalid occurredAt timestamp');
    }
    const now = new Date();
    if (occurredAt.getTime() > now.getTime() + 5 * 60 * 1000) {
      occurredAt = now;
    }

    // 3. Save Check-In Record
    const checkIn = this.checkInRepo.create({
      eventId: dto.eventId,
      userId,
      deviceId: device.id,
      relationshipId: dto.relationshipId || null,
      occurredAt,
      receivedAt: now,
      batteryLevel: dto.batteryLevel,
      note: dto.note || 'Tôi vẫn ổn',
    });

    let savedCheckIn: CheckIn;
    try {
      savedCheckIn = await this.checkInRepo.save(checkIn);
    } catch (err: any) {
      if (this.isUniqueConstraintViolation(err)) {
        this.logger.debug(`Concurrent check-in insert race caught for eventId: ${dto.eventId}`);
        const existingRecord = await this.checkInRepo.findOne({
          where: { eventId: dto.eventId },
        });
        if (existingRecord) {
          return existingRecord;
        }
      }
      throw err;
    }

    // 4. Save Location if supplied
    if (dto.location && dto.location.latitude && dto.location.longitude) {
      const loc = this.locationRepo.create({
        userId,
        deviceId: device.id,
        latitude: dto.location.latitude,
        longitude: dto.location.longitude,
        accuracy: dto.location.accuracy,
        capturedAt: occurredAt,
        source: 'CHECK_IN',
      });
      await this.locationRepo.save(loc);
    }

    // 5. Ingest CHECK_IN Activity (Weight = 1.0)
    const existingActivity = await this.activityRepo.findOne({
      where: { eventId: dto.eventId },
    });
    if (!existingActivity) {
      const activity = this.activityRepo.create({
        eventId: dto.eventId,
        userId,
        deviceId: device.id,
        type: ActivityType.CHECK_IN,
        weight: 1.0,
        confidence: 1.0,
        occurredAt,
        receivedAt: now,
        source: 'MOBILE',
        metadata: {
          note: dto.note,
          batteryLevel: dto.batteryLevel,
        },
      });
      try {
        await this.activityRepo.save(activity);
      } catch (err: any) {
        if (!this.isUniqueConstraintViolation(err)) {
          throw err;
        }
        this.logger.debug(`Activity already saved for check-in eventId: ${dto.eventId}`);
      }
    }

    // 6. Update all active monitoring relationships for this user
    const relationships = await this.relationshipRepo.find({
      where: {
        monitoredUserId: userId,
        status: RelationshipStatus.ACCEPTED,
      },
      relations: { config: true },
    });

    for (const rel of relationships) {
      if (!rel.config || !rel.config.enabled) continue;

      const config = rel.config;
      const currentLast = config.lastMeaningfulActivityAt
        ? new Date(config.lastMeaningfulActivityAt)
        : new Date(0);

      // Invariant: Never allow an out-of-order delayed check-in to roll back the activity clock!
      if (occurredAt.getTime() > currentLast.getTime()) {
        const nextEval = new Date(
          occurredAt.getTime() + config.inactivityThresholdMinutes * 60 * 1000,
        );

        // Revert state back to ACTIVE if allowed by StateMachine
        const shouldResetState =
          config.currentState !== MonitoringState.SUSPENDED &&
          MonitoringStateMachine.canTransition(config.currentState, MonitoringState.ACTIVE);

        await this.configRepo
          .createQueryBuilder()
          .update(MonitoringConfig)
          .set({
            lastMeaningfulActivityAt: occurredAt,
            nextEvaluationAt: nextEval,
            ...(shouldResetState ? { currentState: MonitoringState.ACTIVE } : {}),
          })
          .where(
            'id = :id AND (last_meaningful_activity_at IS NULL OR last_meaningful_activity_at < :occurredAt)',
            {
              id: config.id,
              occurredAt,
            },
          )
          .execute();
      } else {
        this.logger.debug(
          `Ignoring out-of-order check-in timestamp rollback: occurredAt (${occurredAt.toISOString()}) <= currentLast (${currentLast.toISOString()}) for relationship ${rel.id}`,
        );
      }
    }

    // 7. Resolve any active (OPEN, ESCALATED, ACKNOWLEDGED) incidents automatically
    const incidentsToResolve = await this.incidentRepo.find({
      where: {
        userId,
        status: In([
          IncidentStatus.OPEN,
          IncidentStatus.ESCALATED,
          IncidentStatus.ACKNOWLEDGED,
        ]),
      },
    });
    const incidentsToSave: Incident[] = [];
    const eventsToSave: IncidentEvent[] = [];

    for (const inc of incidentsToResolve) {
      // Safety invariant: A historical check-in from before the incident started cannot resolve it!
      if (occurredAt.getTime() < inc.createdAt.getTime()) {
        this.logger.warn(
          `Skipping auto-resolution of incident ${inc.id}: check-in occurredAt (${occurredAt.toISOString()}) predates incident createdAt (${inc.createdAt.toISOString()})`,
        );
        continue;
      }

      inc.status = IncidentStatus.RESOLVED;
      inc.resolvedAt = now;
      inc.resolvedBy = userId;
      incidentsToSave.push(inc);

      eventsToSave.push(
        this.eventRepo.create({
          incidentId: inc.id,
          type: IncidentEventType.INCIDENT_RESOLVED,
          timestamp: now,
          metadata: {
            note: 'User confirmed safety with Check-in ("Tôi vẫn ổn")',
            checkInId: savedCheckIn.id,
          },
        }),
      );
    }

    if (incidentsToSave.length > 0) {
      await this.incidentRepo.save(incidentsToSave);
      await this.eventRepo.save(eventsToSave);
    }

    // 8. Notify all active supervisors / guardians that the monitored person checked in safely
    try {
      let userName = userDisplayName;
      if (!userName) {
        const user = await this.userRepo.findOne({ where: { id: userId } });
        userName = user?.displayName || 'Người thân';
      }
      const batteryStr = dto.batteryLevel !== undefined ? `${dto.batteryLevel}` : '100';
      const noteStr = dto.note ? ` (${dto.note})` : '';

      for (const rel of relationships) {
        if (!rel.monitorId) continue;
        await this.notificationsService
          .sendNotification({
            recipientUserId: rel.monitorId,
            templateName: 'CHECK_IN_CONFIRMED',
            templateParams: {
              name: userName,
              battery: batteryStr,
              note: noteStr,
            },
            customData: {
              type: 'CHECK_IN_CONFIRMED',
              userId,
              checkInId: savedCheckIn.id,
              occurredAt: occurredAt.toISOString(),
            },
          })
          .catch((notifErr) => {
            this.logger.warn(
              `Failed to dispatch check-in notification to supervisor ${rel.monitorId}: ${notifErr?.message || notifErr}`,
            );
          });
      }
    } catch (notifDispatchErr: any) {
      this.logger.warn(
        `Error dispatching check-in notifications: ${notifDispatchErr?.message || notifDispatchErr}`,
      );
    }

    // 9. Real-time Multi-Device Synchronization
    if (this.realtimeService) {
      const checkInPayload = {
        type: 'CHECK_IN_CONFIRMED' as const,
        userId,
        checkInId: savedCheckIn.id,
        occurredAt: occurredAt.toISOString(),
        batteryLevel: dto.batteryLevel,
        note: dto.note || 'Tôi vẫn ổn',
        userDisplayName: userDisplayName || 'Người thân',
      };

      // Emit to user's other devices
      this.realtimeService.emitToUser(userId, checkInPayload).catch(() => {});
      // Emit to all monitors monitoring this user
      this.realtimeService.emitToMonitorsOf(userId, checkInPayload).catch(() => {});

      // If open incidents were auto-resolved by this check-in, notify monitors in real-time
      for (const inc of incidentsToSave) {
        this.realtimeService
          .emitToRelationship(inc.relationshipId, {
            type: 'INCIDENT_RESOLVED',
            incidentId: inc.id,
            resolvedBy: userId,
            resolvedAt: inc.resolvedAt?.toISOString() || new Date().toISOString(),
            resolutionNote: 'User confirmed safety with Check-in ("Tôi vẫn ổn")',
          })
          .catch(() => {});
      }
    }

    return savedCheckIn;
  }

  async listCheckIns(userId: string, limit: number = 20): Promise<CheckIn[]> {
    const relationships = await this.relationshipRepo.find({
      where: [{ monitoredUserId: userId }, { monitorId: userId }],
    });
    const userIds = [
      userId,
      ...relationships.map((r) => r.monitoredUserId),
      ...relationships.map((r) => r.monitorId),
    ];
    const uniqueUserIds = [...new Set(userIds.filter(Boolean))];

    return this.checkInRepo.find({
      where: { userId: In(uniqueUserIds) },
      relations: { user: true },
      order: { occurredAt: 'DESC' },
      take: Math.min(limit, 50),
    });
  }
}
