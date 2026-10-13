import {
  Injectable,
  NotFoundException,
  ConflictException,
  ForbiddenException,
  BadRequestException,
  Optional,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import * as crypto from 'crypto';
import { MonitoringRelationship } from './entities/monitoring-relationship.entity';
import { MonitoringConfig } from './entities/monitoring-config.entity';
import { MonitoringScheduleWindow } from './entities/monitoring-schedule-window.entity';
import {
  PairingInvitation,
  PairingInvitationRole,
  PairingInvitationStatus,
} from './entities/pairing-invitation.entity';
import { User } from '../users/entities/user.entity';
import { RelationshipStatus, MonitoringState } from '../../common/enums';
import {
  CreateRelationshipDto,
  GenerateInviteCodeDto,
  AcceptInvitationDto,
  UpdateMonitoringConfigDto,
} from './dto/monitoring.dto';
import { MonitoringStateMachine } from './monitoring-state-machine';
import { RealtimeService } from '../realtime/realtime.service';
import { RealtimeEventType } from '../realtime/realtime.interface';

@Injectable()
export class MonitoringService {
  constructor(
    @InjectRepository(PairingInvitation)
    private readonly pairingInvitationRepo: Repository<PairingInvitation>,
    @InjectRepository(MonitoringRelationship)
    private readonly relationshipRepo: Repository<MonitoringRelationship>,
    @InjectRepository(MonitoringConfig)
    private readonly configRepo: Repository<MonitoringConfig>,
    @InjectRepository(MonitoringScheduleWindow)
    private readonly windowRepo: Repository<MonitoringScheduleWindow>,
    @InjectRepository(User)
    private readonly userRepo: Repository<User>,
    @Optional()
    private readonly realtimeService?: RealtimeService,
  ) {}

  async createRelationship(monitorId: string, dto: CreateRelationshipDto) {
    const monitoredUser = await this.userRepo.findOne({
      where: { email: dto.monitoredUserEmail.toLowerCase().trim() },
    });

    if (!monitoredUser) {
      throw new NotFoundException('User to monitor not found with this email');
    }

    if (monitorId === monitoredUser.id) {
      throw new BadRequestException('You cannot create a monitoring relationship with yourself');
    }

    const existing = await this.relationshipRepo.findOne({
      where: { monitorId, monitoredUserId: monitoredUser.id },
    });

    if (existing) {
      throw new ConflictException('A monitoring relationship between these accounts already exists');
    }

    const invitationCode = Math.random().toString(36).substring(2, 8).toUpperCase();

    const relationship = this.relationshipRepo.create({
      monitorId,
      monitoredUserId: monitoredUser.id,
      status: RelationshipStatus.PENDING,
      invitationCode,
    });

    const savedRel = await this.relationshipRepo.save(relationship);

    // Create default config
    const config = this.configRepo.create({
      relationshipId: savedRel.id,
      enabled: true,
      timezone: monitoredUser.timezone || 'Asia/Ho_Chi_Minh',
      inactivityThresholdMinutes: 480, // 8 hours
      checkInGraceMinutes: 30,
      warningEscalationMinutes: 15,
      requireCheckIn: true,
      locationEnabled: false,
      currentState: MonitoringState.ACTIVE,
      lastMeaningfulActivityAt: new Date(),
      nextEvaluationAt: new Date(Date.now() + 480 * 60 * 1000),
    });

    const savedConfig = await this.configRepo.save(config);

    // Create default schedule windows (07:00 to 22:00 for each day 0-6)
    const windows: MonitoringScheduleWindow[] = [];
    for (let day = 0; day <= 6; day++) {
      windows.push(
        this.windowRepo.create({
          configId: savedConfig.id,
          dayOfWeek: day,
          startTime: '07:00',
          endTime: '22:00',
          isEnabled: true,
        }),
      );
    }
    await this.windowRepo.save(windows);

    const rel = await this.getRelationship(monitorId, savedRel.id);
    if (this.realtimeService) {
      this.realtimeService.emitToRelationship(savedRel.id, {
        type: RealtimeEventType.RELATIONSHIP_UPDATED,
        relationshipId: savedRel.id,
        status: savedRel.status,
      });
    }

    return rel;
  }

  /**
   * Generates a 48-hour two-way QR code pairing invitation.
   */
  async generateInviteCode(userId: string, dto: GenerateInviteCodeDto) {
    const user = await this.userRepo.findOne({ where: { id: userId } });
    if (!user) {
      throw new NotFoundException('User not found');
    }

    const role = dto.role || PairingInvitationRole.MONITORED;
    const expiresAt = new Date(Date.now() + 48 * 60 * 60 * 1000); // 48 hours TTL

    // Generate unique code CR-XXXXXX (alphanumeric, excluding ambiguous chars O, 0, I, 1)
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    let code = '';
    let attempts = 0;

    while (attempts < 10) {
      attempts++;
      const bytes = crypto.randomBytes(6);
      let rand = '';
      for (let i = 0; i < 6; i++) {
        rand += chars[bytes[i] % chars.length];
      }
      const candidate = `CR-${rand}`;
      const existing = await this.pairingInvitationRepo.findOne({
        where: { invitationCode: candidate },
      });
      if (!existing) {
        code = candidate;
        break;
      }
    }

    if (!code) {
      throw new Error('Failed to generate unique invitation code after multiple attempts');
    }

    const invitation = this.pairingInvitationRepo.create({
      inviterId: userId,
      invitationCode: code,
      role,
      label: dto.label?.trim() || undefined,
      status: PairingInvitationStatus.ACTIVE,
      expiresAt,
    });

    const saved = await this.pairingInvitationRepo.save(invitation);

    return {
      invitationCode: saved.invitationCode,
      inviteCode: saved.invitationCode,
      qrUri: `carely://invite?code=${saved.invitationCode}`,
      expiresAt: saved.expiresAt.toISOString(),
      role: saved.role,
      label: saved.label,
    };
  }

  /**
   * Accepts invitation code via QR pairing (or legacy email relationship fallback).
   */
  async acceptInvitation(userId: string, dto: AcceptInvitationDto) {
    let cleanCode = (dto.invitationCode || dto.inviteCode || '').trim();
    if (!cleanCode) {
      throw new BadRequestException('Invitation code is required');
    }

    // Support raw QR code string, URL query, or bare alphanumeric code
    if (cleanCode.includes('code=')) {
      const match = cleanCode.match(/[?&]code=([^&]+)/);
      if (match) {
        cleanCode = match[1];
      }
    }
    cleanCode = cleanCode.toUpperCase();

    // Execute acceptance in atomic transaction with row lock
    const relationship = await this.relationshipRepo.manager.transaction(async (manager) => {
      // 1. Search modern pairing_invitations table
      const invitation = await manager.findOne(PairingInvitation, {
        where: { invitationCode: cleanCode },
        lock: { mode: 'pessimistic_write' },
      });

      if (!invitation) {
        // Fallback: Legacy email-based relationship invitation
        const legacyRel = await manager.findOne(MonitoringRelationship, {
          where: {
            invitationCode: cleanCode,
            monitoredUserId: userId,
          },
        });

        if (!legacyRel) {
          throw new NotFoundException('Invitation code not found or invalid');
        }

        legacyRel.status = RelationshipStatus.ACCEPTED;
        await manager.save(legacyRel);

        await manager.update(
          MonitoringConfig,
          { relationshipId: legacyRel.id },
          {
            enabled: true,
            currentState: MonitoringState.ACTIVE,
          },
        );

        const resultLegacyRel = await manager.findOne(MonitoringRelationship, {
          where: { id: legacyRel.id },
          relations: {
            monitor: true,
            monitoredUser: true,
            config: { scheduleWindows: true },
          },
        });
        if (!resultLegacyRel) {
          throw new NotFoundException('Monitoring relationship not found');
        }
        return resultLegacyRel;
      }

      // 2. Validate Invitation Lifecycle State
      if (invitation.status === PairingInvitationStatus.ACCEPTED) {
        throw new ConflictException('This invitation code has already been accepted');
      }

      const now = new Date();
      if (invitation.status === PairingInvitationStatus.EXPIRED || invitation.expiresAt < now) {
        invitation.status = PairingInvitationStatus.EXPIRED;
        await manager.save(invitation);
        throw new BadRequestException('This invitation code has expired');
      }

      // 3. Prevent Self-Pairing
      if (invitation.inviterId === userId) {
        throw new BadRequestException('You cannot accept your own invitation code');
      }

      // 4. Resolve Bidirectional Relationship Roles
      let monitorId: string;
      let monitoredUserId: string;

      if (invitation.role === PairingInvitationRole.MONITORED) {
        // Inviter is Elder / Monitored User -> Scanner is Monitor / Guardian
        monitorId = userId;
        monitoredUserId = invitation.inviterId;
      } else {
        // Inviter is Monitor / Guardian -> Scanner is Elder / Monitored User
        monitorId = invitation.inviterId;
        monitoredUserId = userId;
      }

      // 5. Check if Directed Relationship already exists
      const existingRel = await manager.findOne(MonitoringRelationship, {
        where: { monitorId, monitoredUserId },
      });

      let relationshipId: string;

      if (existingRel) {
        if (existingRel.status === RelationshipStatus.ACCEPTED) {
          throw new ConflictException('A monitoring relationship between these accounts already exists');
        }

        // Activate existing pending relationship
        existingRel.status = RelationshipStatus.ACCEPTED;
        existingRel.invitationCode = cleanCode;
        await manager.save(existingRel);
        relationshipId = existingRel.id;

        await manager.update(
          MonitoringConfig,
          { relationshipId: existingRel.id },
          {
            enabled: true,
            currentState: MonitoringState.ACTIVE,
          },
        );
      } else {
        // Create new MonitoringRelationship
        const newRel = manager.create(MonitoringRelationship, {
          monitorId,
          monitoredUserId,
          status: RelationshipStatus.ACCEPTED,
          invitationCode: cleanCode,
        });
        const savedRel = await manager.save(newRel);
        relationshipId = savedRel.id;

        // Fetch monitored user timezone
        const monitoredUser = await manager.findOne(User, {
          where: { id: monitoredUserId },
        });

        // Initialize default MonitoringConfig
        const config = manager.create(MonitoringConfig, {
          relationshipId: savedRel.id,
          enabled: true,
          timezone: monitoredUser?.timezone || 'Asia/Ho_Chi_Minh',
          inactivityThresholdMinutes: 480, // 8 hours default
          checkInGraceMinutes: 30,
          warningEscalationMinutes: 15,
          requireCheckIn: true,
          locationEnabled: false,
          currentState: MonitoringState.ACTIVE,
          lastMeaningfulActivityAt: now,
          nextEvaluationAt: new Date(now.getTime() + 480 * 60 * 1000),
        });
        const savedConfig = await manager.save(config);

        // Initialize default 7-day schedule windows (07:00 - 22:00)
        const windows: MonitoringScheduleWindow[] = [];
        for (let day = 0; day <= 6; day++) {
          windows.push(
            manager.create(MonitoringScheduleWindow, {
              configId: savedConfig.id,
              dayOfWeek: day,
              startTime: '07:00',
              endTime: '22:00',
              isEnabled: true,
            }),
          );
        }
        await manager.save(windows);
      }

      // 6. Mark Invitation as Accepted
      invitation.status = PairingInvitationStatus.ACCEPTED;
      invitation.acceptedById = userId;
      invitation.acceptedAt = now;
      await manager.save(invitation);

      // Return relationship with config and user relations loaded
      const resultRel = await manager.findOne(MonitoringRelationship, {
        where: { id: relationshipId },
        relations: {
          monitor: true,
          monitoredUser: true,
          config: { scheduleWindows: true },
        },
      });
      if (!resultRel) {
        throw new NotFoundException('Monitoring relationship not found');
      }
      return resultRel;
    });

    if (this.realtimeService && relationship) {
      this.realtimeService.emitToRelationship(relationship.id, {
        type: RealtimeEventType.RELATIONSHIP_UPDATED,
        relationshipId: relationship.id,
        status: relationship.status,
      });
    }

    return relationship;
  }

  async listRelationships(userId: string) {
    const [asMonitor, asMonitored] = await Promise.all([
      this.relationshipRepo.find({
        where: { monitorId: userId },
        relations: {
          monitoredUser: true,
          config: { scheduleWindows: true },
        },
        order: { createdAt: 'DESC' },
      }),
      this.relationshipRepo.find({
        where: { monitoredUserId: userId },
        relations: {
          monitor: true,
          config: { scheduleWindows: true },
        },
        order: { createdAt: 'DESC' },
      }),
    ]);

    return {
      monitoring: asMonitor,
      monitoredBy: asMonitored,
    };
  }

  async getRelationship(userId: string, id: string) {
    const rel = await this.relationshipRepo.findOne({
      where: { id },
      relations: {
        monitor: true,
        monitoredUser: true,
        config: { scheduleWindows: true },
      },
    });

    if (!rel) {
      throw new NotFoundException('Monitoring relationship not found');
    }

    if (rel.monitorId !== userId && rel.monitoredUserId !== userId) {
      throw new ForbiddenException('Access denied to this relationship');
    }

    return rel;
  }

  async updateRelationshipStatus(
    userId: string,
    id: string,
    status: RelationshipStatus,
  ) {
    const rel = await this.getRelationship(userId, id);
    rel.status = status;
    await this.relationshipRepo.save(rel);

    if (status === RelationshipStatus.SUSPENDED) {
      await this.configRepo.update(rel.config.id, {
        enabled: false,
        currentState: MonitoringState.SUSPENDED,
      });
    } else if (status === RelationshipStatus.ACCEPTED) {
      await this.configRepo.update(rel.config.id, {
        enabled: true,
        currentState: MonitoringState.ACTIVE,
      });
    }

    const updatedRel = await this.getRelationship(userId, id);
    if (this.realtimeService) {
      this.realtimeService.emitToRelationship(id, {
        type: RealtimeEventType.RELATIONSHIP_UPDATED,
        relationshipId: id,
        status: updatedRel.status,
      });
    }

    return updatedRel;
  }

  async getConfig(userId: string, relationshipId: string) {
    const rel = await this.getRelationship(userId, relationshipId);
    return rel.config;
  }

  async updateConfig(
    userId: string,
    relationshipId: string,
    dto: UpdateMonitoringConfigDto,
  ) {
    const rel = await this.getRelationship(userId, relationshipId);
    const config = rel.config;

    if (dto.enabled !== undefined) {
      config.enabled = dto.enabled;
      if (!dto.enabled) {
        config.currentState = MonitoringState.SUSPENDED;
      } else if (config.currentState === MonitoringState.SUSPENDED) {
        config.currentState = MonitoringState.ACTIVE;
      }
    }

    if (dto.timezone !== undefined) config.timezone = dto.timezone;
    if (dto.inactivityThresholdMinutes !== undefined) {
      config.inactivityThresholdMinutes = dto.inactivityThresholdMinutes;
      // Reschedule next evaluation
      const lastActive = config.lastMeaningfulActivityAt || new Date();
      config.nextEvaluationAt = new Date(
        lastActive.getTime() + config.inactivityThresholdMinutes * 60 * 1000,
      );
    }
    if (dto.checkInGraceMinutes !== undefined) {
      config.checkInGraceMinutes = dto.checkInGraceMinutes;
    }
    if (dto.warningEscalationMinutes !== undefined) {
      config.warningEscalationMinutes = dto.warningEscalationMinutes;
    }
    if (dto.requireCheckIn !== undefined) {
      config.requireCheckIn = dto.requireCheckIn;
    }
    if (dto.locationEnabled !== undefined) {
      // Privacy check: only Monitored User can toggle location consent
      if (rel.monitoredUserId !== userId) {
        throw new ForbiddenException('Only the monitored user can grant or revoke location sharing permission');
      }
      config.locationEnabled = dto.locationEnabled;
    }
    if (dto.activityTypes !== undefined) {
      config.activityTypes = dto.activityTypes;
    }

    await this.configRepo.save(config);

    if (dto.scheduleWindows && Array.isArray(dto.scheduleWindows)) {
      await this.windowRepo.delete({ configId: config.id });
      const newWindows = dto.scheduleWindows.map((w) =>
        this.windowRepo.create({
          configId: config.id,
          dayOfWeek: w.dayOfWeek,
          startTime: w.startTime,
          endTime: w.endTime,
          isEnabled: w.isEnabled,
        }),
      );
      await this.windowRepo.save(newWindows);
    }

    const updatedConfig = await this.getConfig(userId, relationshipId);
    if (this.realtimeService) {
      this.realtimeService.emitToRelationship(relationshipId, {
        type: RealtimeEventType.MONITORING_CONFIG_UPDATED,
        relationshipId,
        config: updatedConfig,
      });
    }

    return updatedConfig;
  }

  async transitionState(
    configId: string,
    targetState: MonitoringState,
  ): Promise<MonitoringConfig> {
    const config = await this.configRepo.findOne({ where: { id: configId } });
    if (!config) throw new NotFoundException('Config not found');

    MonitoringStateMachine.assertTransition(config.currentState, targetState);
    config.currentState = targetState;
    const saved = await this.configRepo.save(config);

    if (this.realtimeService && saved.relationshipId) {
      this.realtimeService.emitToRelationship(saved.relationshipId, {
        type: RealtimeEventType.MONITORING_CONFIG_UPDATED,
        relationshipId: saved.relationshipId,
        config: saved,
      });
    }

    return saved;
  }

  /**
   * Helper to locate MonitoringRelationship and associated config by either relationship.id or config.id
   */
  async findConfigByRelOrConfigId(
    userId: string,
    id: string,
  ): Promise<{ relationship: MonitoringRelationship; config: MonitoringConfig }> {
    // 1. Try finding by relationship ID
    let rel = await this.relationshipRepo.findOne({
      where: { id },
      relations: {
        monitor: true,
        monitoredUser: true,
        config: { scheduleWindows: true },
      },
    });

    // 2. Fallback: try finding config by config ID
    if (!rel) {
      const config = await this.configRepo.findOne({
        where: { id },
        relations: {
          relationship: {
            monitor: true,
            monitoredUser: true,
            config: { scheduleWindows: true },
          },
        },
      });
      if (config && config.relationship) {
        rel = config.relationship;
      }
    }

    if (!rel || !rel.config) {
      throw new NotFoundException('Monitoring configuration not found');
    }

    if (rel.monitorId !== userId && rel.monitoredUserId !== userId) {
      throw new ForbiddenException('Access denied to this monitoring configuration');
    }

    return { relationship: rel, config: rel.config };
  }

  /**
   * Pause monitoring: disables active evaluation and transitions state to SUSPENDED
   */
  async pauseMonitoring(
    userId: string,
    id: string,
    durationMinutes?: number,
  ): Promise<MonitoringConfig> {
    const { config } = await this.findConfigByRelOrConfigId(userId, id);

    MonitoringStateMachine.assertTransition(config.currentState, MonitoringState.SUSPENDED);

    config.enabled = false;
    config.currentState = MonitoringState.SUSPENDED;

    if (durationMinutes && durationMinutes > 0) {
      config.nextEvaluationAt = new Date(Date.now() + durationMinutes * 60 * 1000);
    }

    return this.configRepo.save(config);
  }

  /**
   * Resume monitoring: re-enables evaluation, transitions state to ACTIVE, and resets evaluation timer
   */
  async resumeMonitoring(
    userId: string,
    id: string,
  ): Promise<MonitoringConfig> {
    const { config } = await this.findConfigByRelOrConfigId(userId, id);

    MonitoringStateMachine.assertTransition(config.currentState, MonitoringState.ACTIVE);

    const now = new Date();
    config.enabled = true;
    config.currentState = MonitoringState.ACTIVE;
    config.lastMeaningfulActivityAt = now;
    config.nextEvaluationAt = new Date(
      now.getTime() + config.inactivityThresholdMinutes * 60 * 1000,
    );

    return this.configRepo.save(config);
  }
}
