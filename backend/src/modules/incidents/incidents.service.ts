import {
  Injectable,
  NotFoundException,
  ForbiddenException,
  Logger,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Incident } from './entities/incident.entity';
import { IncidentEventService } from './incident-event.service';
import { IncidentStateMachine } from './incident-state-machine';
import { MonitoringRelationship } from '../monitoring/entities/monitoring-relationship.entity';
import { MonitoringConfig } from '../monitoring/entities/monitoring-config.entity';
import { MonitoringStateMachine } from '../monitoring/monitoring-state-machine';
import { RealtimeService } from '../realtime/realtime.service';
import {
  IncidentStatus,
  IncidentReason,
  IncidentEventType,
  MonitoringState,
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
    private readonly realtimeService?: RealtimeService,
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

  async listIncidents(requestingUserId: string, status?: IncidentStatus) {
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

    return query.getMany();
  }

  async acknowledgeIncident(monitorIdOrIncidentId: string, incidentIdOrMonitorId: string): Promise<Incident> {
    // Support both (monitorId, incidentId) and (incidentId, monitorId)
    let incident = await this.incidentRepo.findOne({
      where: { id: incidentIdOrMonitorId },
      relations: { relationship: true },
    });
    let monitorId = monitorIdOrIncidentId;

    if (!incident) {
      incident = await this.incidentRepo.findOne({
        where: { id: monitorIdOrIncidentId },
        relations: { relationship: true },
      });
      monitorId = incidentIdOrMonitorId;
    }

    if (!incident) {
      throw new NotFoundException('Incident not found');
    }

    // Only monitor can acknowledge
    if (incident.relationship.monitorId !== monitorId) {
      throw new ForbiddenException('Only the designated monitor can acknowledge this incident');
    }

    IncidentStateMachine.assertTransition(incident.status, IncidentStatus.ACKNOWLEDGED);

    const now = new Date();
    incident.status = IncidentStatus.ACKNOWLEDGED;
    incident.acknowledgedAt = now;
    incident.acknowledgedBy = monitorId;

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
      { acknowledgedBy: monitorId, timestamp: now.toISOString() },
    );

    if (this.realtimeService) {
      this.realtimeService
        .emitToRelationship(saved.relationshipId, {
          type: 'INCIDENT_ACKNOWLEDGED',
          incidentId: saved.id,
          acknowledgedBy: monitorId,
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
    const isMonitor = incident.relationship.monitorId === userId;

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
}
