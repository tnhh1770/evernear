import {
  Injectable,
  NotFoundException,
  ForbiddenException,
  BadRequestException,
  Logger,
  Optional,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, In } from 'typeorm';
import { Incident } from './entities/incident.entity';
import { IncidentEvent } from './entities/incident-event.entity';
import { IncidentEventService } from './incident-event.service';
import { IncidentStateMachine } from './incident-state-machine';
import { MonitoringRelationship } from '../monitoring/entities/monitoring-relationship.entity';
import { MonitoringConfig } from '../monitoring/entities/monitoring-config.entity';
import { MonitoringStateMachine } from '../monitoring/monitoring-state-machine';
import { RealtimeService } from '../realtime/realtime.service';
import { NotificationsService } from '../notifications/notifications.service';
import {
  IncidentStatus,
  IncidentReason,
  IncidentEventType,
  MonitoringState,
  RelationshipStatus,
} from '../../common/enums';

@Injectable()
export class IncidentsService {
  private readonly logger = new Logger(IncidentsService.name);

  constructor(
    @InjectRepository(Incident)
    private readonly incidentRepo: Repository<Incident>,
    @InjectRepository(MonitoringRelationship)
    private readonly relationshipRepo: Repository<MonitoringRelationship>,
    @InjectRepository(MonitoringConfig)
    private readonly configRepo: Repository<MonitoringConfig>,
    private readonly eventService: IncidentEventService,
    @Optional()
    private readonly realtimeService?: RealtimeService,
    @Optional()
    private readonly notificationsService?: NotificationsService,
  ) {}

  async createIncident(params: {
    userId: string;
    relationshipId: string;
    reason: IncidentReason;
    riskScore: number;
    lastActivityAt?: Date;
    lastHeartbeatAt?: Date;
    lastLocationId?: string;
    checkInDeadline?: Date;
    triggeredByUserId?: string;
    note?: string;
  }): Promise<Incident> {
    const now = new Date();
    const incident = this.incidentRepo.create({
      userId: params.userId,
      relationshipId: params.relationshipId,
      status: IncidentStatus.OPEN,
      reason: params.reason,
      riskScore: params.riskScore,
      detectedAt: now,
      lastActivityAt: params.lastActivityAt,
      lastHeartbeatAt: params.lastHeartbeatAt,
      lastLocationId: params.lastLocationId || null,
      checkInDeadline: params.checkInDeadline,
      nextActionAt: new Date(now.getTime() + 15 * 60 * 1000), // Next stage in 15 mins
    });

    const saved = await this.incidentRepo.save(incident);

    await this.eventService.logEvent(saved.id, IncidentEventType.INCIDENT_CREATED, {
      reason: params.reason,
      riskScore: params.riskScore,
      ...(params.triggeredByUserId ? { triggeredByUserId: params.triggeredByUserId } : {}),
      ...(params.note ? { note: params.note } : {}),
    });

    if (this.realtimeService) {
      this.realtimeService
        .emitToRelationship(saved.relationshipId, {
          type: 'INCIDENT_CREATED',
          incident: saved,
        })
        .catch(() => {});
    }

    return saved;
  }

  async getIncident(requestingUserId: string, incidentId: string) {
    const incident = await this.incidentRepo.findOne({
      where: { id: incidentId },
      relations: {
        user: true,
        relationship: {
          monitor: true,
          monitoredUser: true,
        },
        lastLocation: true,
        acknowledgedByUser: true,
        resolvedByUser: true,
        events: true,
      },
    });

    if (!incident) {
      throw new NotFoundException('Incident not found');
    }

    // Authorization check: Must be the monitored user or the monitor
    const isMonitoredUser = incident.userId === requestingUserId;
    const isMonitor = incident.relationship.monitorId === requestingUserId;

    if (!isMonitoredUser && !isMonitor) {
      throw new ForbiddenException('You are not authorized to view this incident');
    }

    return incident;
  }

  async listIncidents(
    requestingUserId: string,
    status?: IncidentStatus,
    limit: number = 50,
    offset: number = 0,
  ) {
    // Find all relationships where requestingUserId is either monitor or monitoredUser
    const relationships = await this.relationshipRepo.find({
      where: [
        { monitorId: requestingUserId },
        { monitoredUserId: requestingUserId },
      ],
    });

    if (relationships.length === 0) {
      return [];
    }

    const relationshipIds = relationships.map((r) => r.id);

    const query = this.incidentRepo
      .createQueryBuilder('incident')
      .leftJoinAndSelect('incident.user', 'user')
      .leftJoinAndSelect('incident.relationship', 'relationship')
      .leftJoinAndSelect('relationship.monitor', 'monitor')
      .where('incident.relationshipId IN (:...relationshipIds)', {
        relationshipIds,
      });

    if (status) {
      query.andWhere('incident.status = :status', { status });
    }

    query.orderBy('incident.detectedAt', 'DESC');
    query.take(Math.min(Number(limit) || 50, 100));
    if (offset && Number(offset) > 0) {
      query.skip(Number(offset));
    }

    return query.getMany();
  }

  async acknowledgeIncident(actorIdOrIncidentId: string, incidentIdOrActorId: string): Promise<Incident> {
    // Support both (actorId, incidentId) and (incidentId, actorId)
    let incident = await this.incidentRepo.findOne({
      where: { id: incidentIdOrActorId },
      relations: { relationship: true },
    });
    let actorId = actorIdOrIncidentId;

    if (!incident) {
      incident = await this.incidentRepo.findOne({
        where: { id: actorIdOrIncidentId },
        relations: { relationship: true },
      });
      actorId = incidentIdOrActorId;
    }

    if (!incident) {
      throw new NotFoundException('Incident not found');
    }

    // Strict RBAC: Only the monitor (guardian) can acknowledge an incident
    const isMonitor = incident.relationship?.monitorId === actorId;

    if (!isMonitor) {
      throw new ForbiddenException('Only guardians/monitors can acknowledge this incident');
    }

    IncidentStateMachine.assertTransition(incident.status, IncidentStatus.ACKNOWLEDGED);

    const now = new Date();
    incident.status = IncidentStatus.ACKNOWLEDGED;
    incident.acknowledgedAt = now;
    incident.acknowledgedBy = actorId;

    const saved = await this.incidentRepo.save(incident);

    // Synchronize monitoring config state to ACKNOWLEDGED if allowed
    try {
      const config = await this.configRepo.findOne({
        where: { relationshipId: incident.relationshipId },
      });
      if (
        config &&
        config.currentState !== MonitoringState.SUSPENDED &&
        MonitoringStateMachine.canTransition(config.currentState, MonitoringState.ACKNOWLEDGED)
      ) {
        config.currentState = MonitoringState.ACKNOWLEDGED;
        await this.configRepo.save(config);
      }
    } catch (err) {
      this.logger.warn(`Failed to sync monitoring config state on acknowledge: ${String(err)}`);
    }

    await this.eventService.logEvent(
      incident.id,
      IncidentEventType.MONITOR_ACKNOWLEDGED,
      { acknowledgedBy: actorId, timestamp: now.toISOString() },
    );

    if (this.realtimeService) {
      this.realtimeService
        .emitToRelationship(saved.relationshipId, {
          type: 'INCIDENT_ACKNOWLEDGED',
          incidentId: saved.id,
          acknowledgedBy: actorId,
          acknowledgedAt: now.toISOString(),
        })
        .catch(() => {});
    }

    return saved;
  }

  async resolveIncident(
    userIdOrIncidentId: string,
    incidentIdOrUserId: string,
    note?: string,
  ): Promise<Incident> {
    // Support both (userId, incidentId) and (incidentId, userId)
    let incident = await this.incidentRepo.findOne({
      where: { id: incidentIdOrUserId },
      relations: { relationship: true },
    });
    let userId = userIdOrIncidentId;

    if (!incident) {
      incident = await this.incidentRepo.findOne({
        where: { id: userIdOrIncidentId },
        relations: { relationship: true },
      });
      userId = incidentIdOrUserId;
    }

    if (!incident) {
      throw new NotFoundException('Incident not found');
    }

    const isMonitoredUser = incident.userId === userId;
    const isMonitor = incident.relationship?.monitorId === userId;

    if (!isMonitoredUser && !isMonitor) {
      throw new ForbiddenException('Unauthorized to resolve this incident');
    }

    IncidentStateMachine.assertTransition(incident.status, IncidentStatus.RESOLVED);

    const now = new Date();
    incident.status = IncidentStatus.RESOLVED;
    incident.resolvedAt = now;
    incident.resolvedBy = userId;

    const saved = await this.incidentRepo.save(incident);

    // Restore monitoring config state to ACTIVE, update lastMeaningfulActivityAt and reset nextEvaluationAt
    try {
      const config = await this.configRepo.findOne({
        where: { relationshipId: incident.relationshipId },
      });
      if (
        config &&
        config.currentState !== MonitoringState.SUSPENDED &&
        MonitoringStateMachine.canTransition(config.currentState, MonitoringState.ACTIVE)
      ) {
        config.currentState = MonitoringState.ACTIVE;
        config.lastMeaningfulActivityAt = now;
        config.nextEvaluationAt = new Date(
          now.getTime() + config.inactivityThresholdMinutes * 60 * 1000,
        );
        await this.configRepo.save(config);
      }
    } catch (err) {
      this.logger.warn(`Failed to restore monitoring config state on resolve: ${String(err)}`);
    }

    await this.eventService.logEvent(
      incident.id,
      IncidentEventType.INCIDENT_RESOLVED,
      {
        resolvedBy: userId,
        note: note || 'Resolved by user',
        timestamp: now.toISOString(),
      },
    );

    if (this.realtimeService) {
      this.realtimeService
        .emitToRelationship(saved.relationshipId, {
          type: 'INCIDENT_RESOLVED',
          incidentId: saved.id,
          resolvedBy: userId,
          resolvedAt: now.toISOString(),
          resolutionNote: note || 'Resolved by user',
        })
        .catch(() => {});
    }

    return saved;
  }

  async deleteIncident(
    userId: string,
    id: string,
  ): Promise<{ success: boolean; message: string }> {
    const incident = await this.incidentRepo.findOne({
      where: { id },
      relations: { relationship: true },
    });

    if (!incident) {
      throw new NotFoundException('Incident not found');
    }

    // Authorization check: Must be the monitored user or the monitor/guardian
    const isMonitoredUser = incident.userId === userId;
    const isMonitor = incident.relationship?.monitorId === userId;

    if (!isMonitoredUser && !isMonitor) {
      throw new ForbiddenException('You are not authorized to delete this incident');
    }

    // Clean up associated incident events (cascading cleanup)
    await this.incidentRepo.manager.delete(IncidentEvent, { incidentId: id });

    // Delete incident
    await this.incidentRepo.delete(id);

    // Optional realtime notification
    if (this.realtimeService && incident.relationshipId) {
      this.realtimeService
        .emitToRelationship(incident.relationshipId, {
          type: 'INCIDENT_DELETED',
          incidentId: id,
        })
        .catch(() => {});
    }

    return {
      success: true,
      message: 'Incident deleted',
    };
  }

  async clearAllIncidents(
    userId: string,
  ): Promise<{ success: boolean; count: number }> {
    // Find all relationships where requesting user is either monitor or monitoredUser
    const relationships = await this.relationshipRepo.find({
      where: [
        { monitorId: userId },
        { monitoredUserId: userId },
      ],
    });

    if (relationships.length === 0) {
      return { success: true, count: 0 };
    }

    const relationshipIds = relationships.map((r) => r.id);

    const incidents = await this.incidentRepo.find({
      where: { relationshipId: In(relationshipIds) },
      select: { id: true, relationshipId: true },
    });

    if (incidents.length === 0) {
      return { success: true, count: 0 };
    }

    const incidentIds = incidents.map((i) => i.id);

    // Clean up associated incident events
    await this.incidentRepo.manager.delete(IncidentEvent, {
      incidentId: In(incidentIds),
    });

    // Delete incidents
    await this.incidentRepo.delete({ id: In(incidentIds) });

    // Optional realtime notifications
    if (this.realtimeService) {
      for (const relId of relationshipIds) {
        this.realtimeService
          .emitToRelationship(relId, {
            type: 'INCIDENTS_CLEARED',
            count: incidentIds.length,
          })
          .catch(() => {});
      }
    }

    return {
      success: true,
      count: incidentIds.length,
    };
  }
}
