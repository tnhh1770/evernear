import { Injectable, Logger } from '@nestjs/common';
import { Cron, CronExpression } from '@nestjs/schedule';
import { DataSource, In } from 'typeorm';
import { MonitoringConfig } from '../monitoring/entities/monitoring-config.entity';
import { MonitoringScheduleWindow } from '../monitoring/entities/monitoring-schedule-window.entity';
import { Device } from '../devices/entities/device.entity';
import { Incident } from '../incidents/entities/incident.entity';
import { IncidentEvent } from '../incidents/entities/incident-event.entity';
import { MonitoringScheduler } from '../monitoring/monitoring-scheduler';
import { RiskEvaluatorService } from '../incidents/risk-evaluator.service';
import { IncidentsService } from '../incidents/incidents.service';
import { NotificationsService } from '../notifications/notifications.service';
import { RedisService } from '../../common/redis/redis.service';
import {
  MonitoringState,
  RelationshipStatus,
  IncidentReason,
  IncidentStatus,
  IncidentEventType,
} from '../../common/enums';

interface DeferredAction {
  type: 'CHECK_IN_PROMPT' | 'INCIDENT_CREATED' | 'ESCALATED';
  recipientUserId: string;
  templateName: string;
  templateParams: Record<string, string>;
  customData: Record<string, string>;
  incidentParams?: {
    userId: string;
    relationshipId: string;
    reason: IncidentReason;
    riskScore: number;
    lastActivityAt?: Date;
    lastHeartbeatAt?: Date;
    checkInDeadline?: Date;
  };
  openIncidentIdToEscalate?: string;
}

@Injectable()
export class MonitoringWorkerService {
  private readonly logger = new Logger(MonitoringWorkerService.name);
  private isRunning = false;

  constructor(
    private readonly dataSource: DataSource,
    private readonly redisService: RedisService,
    private readonly riskEvaluator: RiskEvaluatorService,
    private readonly incidentsService: IncidentsService,
    private readonly notificationsService: NotificationsService,
  ) {}

  /**
   * Run every 30 seconds to evaluate due monitoring relationships
   */
  @Cron(CronExpression.EVERY_30_SECONDS)
  async handleCron() {
    if (
      process.env.DISABLE_WORKER_CRON === 'true' ||
      process.env.NODE_ENV === 'test' ||
      process.env.VITEST
    ) {
      return;
    }

    if (this.isRunning) {
      this.logger.debug('Monitoring worker evaluation already in progress, skipping tick.');
      return;
    }

    this.isRunning = true;
    try {
      await this.evaluateDueMonitoring();
    } catch (err: any) {
      this.logger.error(`Worker error during monitoring cycle: ${err.message}`, err.stack);
    } finally {
      this.isRunning = false;
    }
  }

  /**
   * Core Evaluation Cycle:
   * Uses FOR UPDATE SKIP LOCKED and Redis distributed lock to avoid concurrent processing.
   * Commits database changes BEFORE performing external notifications to avoid deadlocks.
   */
  async evaluateDueMonitoring(batchSize: number = 25): Promise<number> {
    const queryRunner = this.dataSource.createQueryRunner();
    await queryRunner.connect();

    let processedCount = 0;
    const deferredActions: DeferredAction[] = [];
    const acquiredLocks: Array<{ key: string; token: string }> = [];

    try {
      await queryRunner.startTransaction();

      // Query only configs that are enabled and due for evaluation
      const dueConfigs = await queryRunner.manager
        .createQueryBuilder(MonitoringConfig, 'config')
        .setLock('pessimistic_write')
        .setOnLocked('skip_locked')
        .innerJoinAndSelect('config.relationship', 'relationship')
        .innerJoinAndSelect('relationship.monitoredUser', 'monitoredUser')
        .innerJoinAndSelect('relationship.monitor', 'monitor')
        .where('config.enabled = true')
        .andWhere('relationship.status = :relStatus', {
          relStatus: RelationshipStatus.ACCEPTED,
        })
        .andWhere('config.next_evaluation_at <= NOW()')
        .take(batchSize)
        .getMany();

      if (dueConfigs.length === 0) {
        await queryRunner.commitTransaction();
        return 0;
      }

      // Populate schedule windows cleanly in bulk
      const configIds = dueConfigs.map((c) => c.id);
      const windows = await queryRunner.manager.find(MonitoringScheduleWindow, {
        where: { configId: In(configIds) },
      });
      for (const c of dueConfigs) {
        c.scheduleWindows = windows.filter((w) => w.configId === c.id);
      }

      // Bulk-fetch active devices for all monitored users in the batch in 1 query
      const monitoredUserIds = Array.from(
        new Set(dueConfigs.map((c) => c.relationship?.monitoredUserId).filter(Boolean)),
      );
      const allDevices =
        monitoredUserIds.length > 0
          ? await queryRunner.manager.find(Device, {
              where: { userId: In(monitoredUserIds), isActive: true },
              order: { lastSeenAt: 'DESC' },
            })
          : [];
      const devicesByUser = new Map<string, Device[]>();
      for (const dev of allDevices) {
        const list = devicesByUser.get(dev.userId) || [];
        list.push(dev);
        devicesByUser.set(dev.userId, list);
      }

      // Bulk-fetch open incidents for all relationships in the batch in 1 query
      const relationshipIds = Array.from(
        new Set(dueConfigs.map((c) => c.relationshipId).filter(Boolean)),
      );
      const allOpenIncidents =
        relationshipIds.length > 0
          ? await queryRunner.manager.find(Incident, {
              where: { relationshipId: In(relationshipIds), status: IncidentStatus.OPEN },
              order: { detectedAt: 'DESC' },
            })
          : [];
      const openIncidentsByRel = new Map<string, Incident>();
      for (const inc of allOpenIncidents) {
        if (!openIncidentsByRel.has(inc.relationshipId)) {
          openIncidentsByRel.set(inc.relationshipId, inc);
        }
      }

      const modifiedConfigs: MonitoringConfig[] = [];

      for (const config of dueConfigs) {
        const lockKey = `monitoring:lock:${config.relationshipId}`;
        const lockResult = await this.redisService.acquireLockDetailed(lockKey, 15000);

        if (!lockResult.acquired && !lockResult.degraded) {
          // Lock contention: another worker node is actively processing this relationship! Skip safely.
          this.logger.debug(
            `Skipping config ${config.id} (relationship: ${config.relationshipId}): locked by another cluster worker.`,
          );
          continue;
        }

        if (lockResult.token) {
          acquiredLocks.push({ key: lockKey, token: lockResult.token });
        }

        try {
          const action = await this.evaluateSingleConfig(
            queryRunner,
            config,
            devicesByUser,
            openIncidentsByRel,
            false,
          );
          modifiedConfigs.push(config);
          if (action) {
            deferredActions.push(action);
          }
          processedCount++;
        } catch (itemErr: any) {
          this.logger.error(
            `Failed evaluating config ${config.id}: ${itemErr.message}`,
            itemErr.stack,
          );
        }
      }

      // Batch save modified configs in 1 query
      if (modifiedConfigs.length > 0) {
        await queryRunner.manager.save(MonitoringConfig, modifiedConfigs);
      }

      // Commit all DB state updates before dispatching notifications
      await queryRunner.commitTransaction();
    } catch (err: any) {
      await queryRunner.rollbackTransaction();
      this.logger.error(`Transaction rollback in worker: ${err.message}`);
      throw err;
    } finally {
      if (acquiredLocks.length > 0) {
        await Promise.all(
          acquiredLocks.map((lock) =>
            this.redisService.releaseLock(lock.key, lock.token).catch((err) => {
              this.logger.warn(`Failed releasing lock ${lock.key}: ${err.message}`);
            }),
          ),
        );
      }
      await queryRunner.release();
    }

    // Execute deferred actions (Incidents and Notifications) outside the transaction
    for (const act of deferredActions) {
      try {
        if (act.type === 'CHECK_IN_PROMPT') {
          await this.notificationsService.sendNotification({
            recipientUserId: act.recipientUserId,
            templateName: act.templateName,
            templateParams: act.templateParams,
            customData: act.customData,
          });
        } else if (act.type === 'INCIDENT_CREATED' && act.incidentParams) {
          const incident = await this.incidentsService.createIncident(act.incidentParams);
          await this.notificationsService.sendNotification({
            recipientUserId: act.recipientUserId,
            templateName: act.templateName,
            incidentId: incident.id,
            templateParams: act.templateParams,
            customData: {
              ...act.customData,
              incidentId: incident.id,
            },
          });
        } else if (act.type === 'ESCALATED') {
          if (act.openIncidentIdToEscalate) {
            const inc = await this.dataSource.getRepository(Incident).findOne({
              where: { id: act.openIncidentIdToEscalate },
            });
            if (inc) {
              inc.status = IncidentStatus.ESCALATED;
              inc.escalatedAt = new Date();
              await this.dataSource.getRepository(Incident).save(inc);

              const event = this.dataSource.getRepository(IncidentEvent).create({
                incidentId: inc.id,
                type: IncidentEventType.ESCALATION_TRIGGERED,
                timestamp: inc.escalatedAt,
                metadata: {
                  previousStatus: IncidentStatus.OPEN,
                  recipientUserId: act.recipientUserId,
                  escalatedAt: inc.escalatedAt.toISOString(),
                },
              });
              await this.dataSource.getRepository(IncidentEvent).save(event);
            }
          }
          await this.notificationsService.sendNotification({
            recipientUserId: act.recipientUserId,
            templateName: act.templateName,
            incidentId: act.openIncidentIdToEscalate,
            templateParams: act.templateParams,
            customData: act.customData,
          });
        }
      } catch (actErr: any) {
        this.logger.error(`Failed executing deferred action: ${actErr.message}`);
      }
    }

    return processedCount;
  }

  /**
   * Evaluate a single relationship configuration and return any deferred notification actions
   */
  private async evaluateSingleConfig(
    queryRunner: any,
    config: MonitoringConfig,
    devicesByUser?: Map<string, Device[]>,
    openIncidentsByRel?: Map<string, Incident>,
    saveImmediately: boolean = false,
  ): Promise<DeferredAction | null> {
    const now = new Date();
    const rel = config.relationship;
    const monitoredUser = rel.monitoredUser;
    const monitor = rel.monitor;
    const windows = config.scheduleWindows || [];
    const timezone = config.timezone || monitoredUser?.timezone || 'Asia/Ho_Chi_Minh';

    // 1. Timezone-aware Active Schedule Window Check
    const isInWindow = MonitoringScheduler.isWithinActiveWindow(now, windows, timezone);

    if (!isInWindow) {
      // Outside active window (e.g. night hours 22:00 -> 07:00).
      // Reschedule evaluation to start of next active window.
      const nextStart = MonitoringScheduler.getNextActiveWindowStart(now, windows, timezone);
      config.nextEvaluationAt = nextStart;
      if (saveImmediately) {
        await queryRunner.manager.save(config);
      }
      return null;
    }

    // 2. Check inactivity duration
    const lastActive = config.lastMeaningfulActivityAt
      ? new Date(config.lastMeaningfulActivityAt)
      : new Date(0);

    const minutesInactive = Math.floor((now.getTime() - lastActive.getTime()) / (60 * 1000));

    // 3. State-based branching
    switch (config.currentState) {
      case MonitoringState.ACTIVE: {
        if (minutesInactive >= config.inactivityThresholdMinutes) {
          if (config.requireCheckIn) {
            config.currentState = MonitoringState.CHECK_IN_REQUIRED;
            config.nextEvaluationAt = new Date(now.getTime() + config.checkInGraceMinutes * 60 * 1000);
            if (saveImmediately) {
              await queryRunner.manager.save(config);
            }

            return {
              type: 'CHECK_IN_PROMPT',
              recipientUserId: monitoredUser.id,
              templateName: 'CHECK_IN_PROMPT',
              templateParams: { name: monitoredUser.displayName },
              customData: {
                relationshipId: rel.id,
                action: 'CHECK_IN',
              },
            };
          } else {
            config.currentState = MonitoringState.WARNING;
            config.nextEvaluationAt = new Date(now.getTime() + config.warningEscalationMinutes * 60 * 1000);
            if (saveImmediately) {
              await queryRunner.manager.save(config);
            }
            return null;
          }
        } else {
          // Still active, reschedule to remaining time
          const remainingMinutes = Math.max(1, config.inactivityThresholdMinutes - minutesInactive);
          config.nextEvaluationAt = new Date(now.getTime() + remainingMinutes * 60 * 1000);
          if (saveImmediately) {
            await queryRunner.manager.save(config);
          }
          return null;
        }
      }

      case MonitoringState.CHECK_IN_REQUIRED:
      case MonitoringState.CHECK_IN_PENDING: {
        // User has not responded within the grace period!
        const devices =
          devicesByUser?.get(monitoredUser.id) ??
          (await queryRunner.manager.find(Device, {
            where: { userId: monitoredUser.id, isActive: true },
            order: { lastSeenAt: 'DESC' },
          }));

        const latestDevice = devices.length > 0 ? devices[0] : null;
        const lastHeartbeat = latestDevice?.lastHeartbeatAt
          ? new Date(latestDevice.lastHeartbeatAt)
          : null;

        const isDeviceOffline =
          !lastHeartbeat || now.getTime() - lastHeartbeat.getTime() > 2 * 60 * 60 * 1000;
        const isLowBattery =
          latestDevice?.batteryLevel !== null &&
          latestDevice?.batteryLevel !== undefined &&
          latestDevice.batteryLevel < 15;

        const riskResult = this.riskEvaluator.evaluate({
          isInactivityExceeded: true,
          isCheckInMissed: true,
          isDeviceOffline,
          isLowBattery,
          batteryLevel: latestDevice?.batteryLevel ?? undefined,
          inactivityMinutes: minutesInactive,
        });

        config.currentState = MonitoringState.WARNING;
        config.nextEvaluationAt = new Date(now.getTime() + config.warningEscalationMinutes * 60 * 1000);
        if (saveImmediately) {
          await queryRunner.manager.save(config);
        }

        return {
          type: 'INCIDENT_CREATED',
          recipientUserId: monitor.id,
          templateName: 'MONITOR_INACTIVITY_WARNING',
          templateParams: { name: monitoredUser.displayName },
          customData: {
            relationshipId: rel.id,
          },
          incidentParams: {
            userId: monitoredUser.id,
            relationshipId: rel.id,
            reason: isDeviceOffline ? IncidentReason.DEVICE_OFFLINE : IncidentReason.MISSED_CHECK_IN,
            riskScore: riskResult.riskScore,
            lastActivityAt: lastActive,
            lastHeartbeatAt: lastHeartbeat || undefined,
            checkInDeadline: config.nextEvaluationAt,
          },
        };
      }

      case MonitoringState.WARNING: {
        config.currentState = MonitoringState.ESCALATED;
        config.nextEvaluationAt = new Date(now.getTime() + config.warningEscalationMinutes * 60 * 1000);
        if (saveImmediately) {
          await queryRunner.manager.save(config);
        }

        const openIncident =
          openIncidentsByRel?.get(rel.id) ??
          (await queryRunner.manager.findOne(Incident, {
            where: { relationshipId: rel.id, status: IncidentStatus.OPEN },
            order: { detectedAt: 'DESC' },
          }));

        return {
          type: 'ESCALATED',
          recipientUserId: monitor.id,
          templateName: 'MONITOR_ESCALATION',
          templateParams: { name: monitoredUser.displayName },
          customData: {
            relationshipId: rel.id,
            incidentId: openIncident?.id || '',
          },
          openIncidentIdToEscalate: openIncident?.id,
        };
      }

      case MonitoringState.ESCALATED: {
        config.nextEvaluationAt = new Date(now.getTime() + 60 * 60 * 1000);
        if (saveImmediately) {
          await queryRunner.manager.save(config);
        }
        return null;
      }

      default: {
        config.nextEvaluationAt = new Date(now.getTime() + 60 * 60 * 1000);
        if (saveImmediately) {
          await queryRunner.manager.save(config);
        }
        return null;
      }
    }
  }
}
