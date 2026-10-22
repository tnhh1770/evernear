import {
  Injectable,
  Logger,
  OnModuleInit,
  OnModuleDestroy,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { WebSocket } from 'ws';
import { randomUUID } from 'crypto';
import { RedisService } from '../../common/redis/redis.service';
import { MonitoringRelationship } from '../monitoring/entities/monitoring-relationship.entity';
import { RelationshipStatus } from '../../common/enums';
import { RealtimeEvent } from './realtime.interface';

const REALTIME_REDIS_CHANNEL = 'carely:realtime:events';

interface RedisRealtimeMessage {
  instanceId?: string;
  recipientUserId: string;
  event: RealtimeEvent;
}

@Injectable()
export class RealtimeService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(RealtimeService.name);
  readonly instanceId = randomUUID();
  private readonly userSockets = new Map<string, Set<WebSocket>>();
  private redisSubscriber: any = null;

  constructor(
    @InjectRepository(MonitoringRelationship)
    private readonly relationshipRepo: Repository<MonitoringRelationship>,
    private readonly redisService?: RedisService,
  ) {}

  async onModuleInit() {
    this.setupRedisSubscriber();
  }

  async onModuleDestroy() {
    if (this.redisSubscriber) {
      try {
        if (typeof this.redisSubscriber.quit === 'function') {
          await this.redisSubscriber.quit();
        } else if (typeof this.redisSubscriber.disconnect === 'function') {
          this.redisSubscriber.disconnect();
        }
      } catch {
        if (typeof this.redisSubscriber.disconnect === 'function') {
          this.redisSubscriber.disconnect();
        }
      } finally {
        this.redisSubscriber = null;
      }
    }
    // Close remaining sockets gracefully
    for (const sockets of this.userSockets.values()) {
      for (const ws of sockets) {
        try {
          ws.close(1000, 'Server shutting down');
        } catch {
          // Ignore
        }
      }
    }
    this.userSockets.clear();
  }

  private setupRedisSubscriber() {
    const redis = this.redisService;
    if (!redis) {
      return;
    }

    const tryInit = () => {
      try {
        const client = redis.getClient();
        if (!client) {
          setTimeout(tryInit, 500);
          return;
        }

        if (client.status === 'ready') {
          this.attachSubscriber(client);
        } else {
          client.once('ready', () => this.attachSubscriber(client));
        }
      } catch (e: any) {
        this.logger.warn(`Redis subscriber init error: ${e.message}. Using in-memory fallback.`);
      }
    };

    tryInit();
  }

  private attachSubscriber(client: any) {
    if (this.redisSubscriber) return;
    try {
      this.redisSubscriber = client.duplicate({ enableOfflineQueue: true });
      this.redisSubscriber.on('error', (err: any) => {
        this.logger.warn(`Redis subscriber connection error: ${err.message}`);
      });
      this.redisSubscriber.subscribe(REALTIME_REDIS_CHANNEL, (err: any) => {
        if (err) {
          this.logger.warn(`Failed to subscribe to Redis channel: ${err.message}`);
          return;
        }
        this.logger.log(`Subscribed to Redis realtime channel: ${REALTIME_REDIS_CHANNEL}`);
      });

      this.redisSubscriber.on('message', (channel: string, messageStr: string) => {
        if (channel !== REALTIME_REDIS_CHANNEL) return;
        try {
          let payload = JSON.parse(messageStr);
          if (typeof payload === 'string') {
            payload = JSON.parse(payload);
          }
          // Filter loopback messages from own instance to eliminate duplicate 2x event delivery
          if (payload?.instanceId === this.instanceId) {
            return;
          }
          if (payload?.recipientUserId && payload?.event) {
            this.sendLocal(payload.recipientUserId, payload.event);
          }
        } catch (e: any) {
          this.logger.warn(`Failed to parse realtime Redis message: ${e.message}`);
        }
      });
    } catch (e: any) {
      this.logger.warn(`Redis attachSubscriber error: ${e.message}`);
    }
  }

  /**
   * Register an authenticated WebSocket client for a user.
   */
  registerClient(userId: string, ws: WebSocket) {
    if (!this.userSockets.has(userId)) {
      this.userSockets.set(userId, new Set<WebSocket>());
    }
    this.userSockets.get(userId)!.add(ws);
    this.logger.debug(`Registered WebSocket for user ${userId}. Total sockets for user: ${this.userSockets.get(userId)!.size}`);

    // Send connection ack
    this.sendToSocket(ws, {
      type: 'CONNECTED',
      userId,
      timestamp: new Date().toISOString(),
    });
  }

  /**
   * Remove a WebSocket client upon disconnect.
   */
  removeClient(userId: string, ws: WebSocket) {
    const sockets = this.userSockets.get(userId);
    if (sockets) {
      sockets.delete(ws);
      if (sockets.size === 0) {
        this.userSockets.delete(userId);
      }
      this.logger.debug(`Removed WebSocket for user ${userId}. Remaining sockets: ${sockets.size}`);
    }
  }

  getConnectedUserCount(): number {
    return this.userSockets.size;
  }

  getActiveSocketCount(): number {
    let total = 0;
    for (const sockets of this.userSockets.values()) {
      total += sockets.size;
    }
    return total;
  }

  /**
   * Direct in-memory dispatch to local sockets for a given user.
   */
  private sendLocal(userId: string, event: RealtimeEvent) {
    const sockets = this.userSockets.get(userId);
    if (!sockets || sockets.size === 0) return;

    for (const ws of sockets) {
      this.sendToSocket(ws, event);
    }
  }

  private sendToSocket(ws: WebSocket, payload: any) {
    if (ws.readyState === WebSocket.OPEN) {
      try {
        ws.send(JSON.stringify(payload));
      } catch (err: any) {
        this.logger.warn(`WebSocket send error: ${err.message}`);
      }
    }
  }

  /**
   * Emit an event to a specific user.
   * If Redis is ready, publishes to Redis for multi-instance distribution.
   * Also sends locally immediately.
   */
  async emitToUser(userId: string, event: RealtimeEvent): Promise<void> {
    const enrichedEvent: RealtimeEvent = {
      ...event,
      timestamp: event.timestamp || new Date().toISOString(),
    };

    // 1. Send locally
    this.sendLocal(userId, enrichedEvent);

    // 2. Publish to Redis if available
    if (this.redisService && this.redisService.isReady) {
      const client = this.redisService.getClient();
      if (client) {
        const payload: RedisRealtimeMessage = {
          instanceId: this.instanceId,
          recipientUserId: userId,
          event: enrichedEvent,
        };
        client.publish(REALTIME_REDIS_CHANNEL, JSON.stringify(payload)).catch(() => {});
      }
    }
  }

  /**
   * Emit an event to multiple users concurrently.
   */
  async emitToUsers(userIds: string[], event: RealtimeEvent): Promise<void> {
    const uniqueIds = Array.from(new Set(userIds.filter(Boolean)));
    await Promise.all(uniqueIds.map((id) => this.emitToUser(id, event)));
  }

  /**
   * Emit an event to all monitors of a given monitored user.
   */
  async emitToMonitorsOf(monitoredUserId: string, event: RealtimeEvent): Promise<void> {
    try {
      const relationships = await this.relationshipRepo.find({
        where: {
          monitoredUserId,
          status: RelationshipStatus.ACCEPTED,
        },
      });

      const monitorIds = relationships
        .map((r) => r.monitorId)
        .filter((id): id is string => Boolean(id));

      if (monitorIds.length > 0) {
        await this.emitToUsers(monitorIds, event);
      }
    } catch (err: any) {
      this.logger.warn(`Failed to emit event to monitors of ${monitoredUserId}: ${err.message}`);
    }
  }

  /**
   * Emit an event to both participants of a monitoring relationship.
   */
  async emitToRelationship(relationshipId: string, event: RealtimeEvent): Promise<void> {
    try {
      const rel = await this.relationshipRepo.findOne({
        where: { id: relationshipId },
      });
      if (rel) {
        const recipients = [rel.monitorId, rel.monitoredUserId].filter(Boolean);
        await this.emitToUsers(recipients, event);
      }
    } catch (err: any) {
      this.logger.warn(`Failed to emit event to relationship ${relationshipId}: ${err.message}`);
    }
  }
}
