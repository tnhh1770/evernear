import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { WebSocket } from 'ws';
import { RealtimeService } from './realtime.service';
import { RelationshipStatus } from '../../common/enums';
import { RealtimeEventType } from './realtime.interface';

describe('RealtimeService', () => {
  let service: RealtimeService;
  let mockRelationshipRepo: {
    find: any;
    findOne: any;
  };

  const createMockSocket = (readyState = WebSocket.OPEN) => {
    const send = vi.fn();
    const close = vi.fn();
    return {
      readyState,
      send,
      close,
      sendMock: send,
      closeMock: close,
    };
  };

  beforeEach(() => {
    mockRelationshipRepo = {
      find: vi.fn(),
      findOne: vi.fn(),
    };

    service = new RealtimeService(mockRelationshipRepo as any);
  });

  afterEach(async () => {
    await service.onModuleDestroy();
    vi.clearAllMocks();
  });

  describe('Client Registration & Lifecycle', () => {
    it('should register client and send CONNECTED ack', () => {
      const socket = createMockSocket();
      service.registerClient('user-1', socket as unknown as WebSocket);

      expect(service.getConnectedUserCount()).toBe(1);
      expect(service.getActiveSocketCount()).toBe(1);
      expect(socket.sendMock).toHaveBeenCalledTimes(1);
      const sentPayload = JSON.parse(socket.sendMock.mock.calls[0][0]);
      expect(sentPayload.type).toBe('CONNECTED');
      expect(sentPayload.userId).toBe('user-1');
    });

    it('should support multiple sockets for the same user', () => {
      const socket1 = createMockSocket();
      const socket2 = createMockSocket();

      service.registerClient('user-1', socket1 as unknown as WebSocket);
      service.registerClient('user-1', socket2 as unknown as WebSocket);

      expect(service.getConnectedUserCount()).toBe(1);
      expect(service.getActiveSocketCount()).toBe(2);
    });

    it('should remove socket upon disconnect', () => {
      const socket1 = createMockSocket();
      const socket2 = createMockSocket();

      service.registerClient('user-1', socket1 as unknown as WebSocket);
      service.registerClient('user-1', socket2 as unknown as WebSocket);

      service.removeClient('user-1', socket1 as unknown as WebSocket);
      expect(service.getActiveSocketCount()).toBe(1);
      expect(service.getConnectedUserCount()).toBe(1);

      service.removeClient('user-1', socket2 as unknown as WebSocket);
      expect(service.getActiveSocketCount()).toBe(0);
      expect(service.getConnectedUserCount()).toBe(0);
    });
  });

  describe('Event Emission', () => {
    it('should emit to registered user socket', async () => {
      const socket = createMockSocket();
      service.registerClient('user-1', socket as unknown as WebSocket);
      socket.sendMock.mockClear();

      await service.emitToUser('user-1', {
        type: RealtimeEventType.CHECK_IN_CONFIRMED,
        userId: 'user-1',
        checkInId: 'chk-1',
        occurredAt: '2026-10-13T12:00:00Z',
      });

      expect(socket.sendMock).toHaveBeenCalledTimes(1);
      const sent = JSON.parse(socket.sendMock.mock.calls[0][0]);
      expect(sent.type).toBe(RealtimeEventType.CHECK_IN_CONFIRMED);
      expect(sent.userId).toBe('user-1');
      expect(sent.timestamp).toBeDefined();
    });

    it('should not throw if user has no active sockets', async () => {
      await expect(
        service.emitToUser('offline-user', {
          type: RealtimeEventType.CHECK_IN_CONFIRMED,
          userId: 'offline-user',
          checkInId: 'chk-offline',
          occurredAt: '2026-10-13T12:00:00Z',
        }),
      ).resolves.not.toThrow();
    });

    it('should emit to monitors of a given user', async () => {
      mockRelationshipRepo.find.mockResolvedValue([
        { monitorId: 'monitor-1', status: RelationshipStatus.ACCEPTED },
        { monitorId: 'monitor-2', status: RelationshipStatus.ACCEPTED },
      ]);

      const monitorSocket1 = createMockSocket();
      const monitorSocket2 = createMockSocket();
      service.registerClient('monitor-1', monitorSocket1 as unknown as WebSocket);
      service.registerClient('monitor-2', monitorSocket2 as unknown as WebSocket);
      monitorSocket1.sendMock.mockClear();
      monitorSocket2.sendMock.mockClear();

      await service.emitToMonitorsOf('elder-user', {
        type: RealtimeEventType.ACTIVITY_RECORDED,
        userId: 'elder-user',
        activityType: 'DEVICE_UNLOCK',
        occurredAt: '2026-10-13T12:00:00Z',
      });

      expect(mockRelationshipRepo.find).toHaveBeenCalledWith({
        where: {
          monitoredUserId: 'elder-user',
          status: RelationshipStatus.ACCEPTED,
        },
      });

      expect(monitorSocket1.sendMock).toHaveBeenCalledTimes(1);
      expect(monitorSocket2.sendMock).toHaveBeenCalledTimes(1);
    });

    it('should emit to both participants of a relationship', async () => {
      mockRelationshipRepo.findOne.mockResolvedValue({
        id: 'rel-1',
        monitorId: 'monitor-1',
        monitoredUserId: 'elder-1',
      });

      const monitorSocket = createMockSocket();
      const elderSocket = createMockSocket();
      service.registerClient('monitor-1', monitorSocket as unknown as WebSocket);
      service.registerClient('elder-1', elderSocket as unknown as WebSocket);
      monitorSocket.sendMock.mockClear();
      elderSocket.sendMock.mockClear();

      await service.emitToRelationship('rel-1', {
        type: RealtimeEventType.MONITORING_CONFIG_UPDATED,
        relationshipId: 'rel-1',
        config: {},
      });

      expect(monitorSocket.sendMock).toHaveBeenCalledTimes(1);
      expect(elderSocket.sendMock).toHaveBeenCalledTimes(1);
    });
  });

  describe('Redis Pub/Sub Echo Filtering & Error Handling', () => {
    it('should ignore incoming Redis messages originating from its own instanceId (loopback filter)', () => {
      const socket = createMockSocket();
      service.registerClient('user-loopback', socket as unknown as WebSocket);
      socket.sendMock.mockClear();

      const listeners: Record<string, (channel: string, message: string) => void> = {};
      const mockSubscriber = {
        subscribe: vi.fn(),
        on: vi.fn((event: string, cb: any) => {
          listeners[event] = cb;
        }),
      };
      const mockClient = {
        duplicate: vi.fn().mockReturnValue(mockSubscriber),
      };

      (service as any).redisSubscriber = null;
      (service as any).attachSubscriber(mockClient);

      // 1. Simulate Redis message with the same instanceId (loopback)
      listeners['message'](
        'carely:realtime:events',
        JSON.stringify({
          instanceId: service.instanceId,
          recipientUserId: 'user-loopback',
          event: { type: RealtimeEventType.CHECK_IN_CONFIRMED, userId: 'user-loopback' },
        }),
      );

      // Must be filtered out - not dispatched to local socket
      expect(socket.sendMock).not.toHaveBeenCalled();

      // 2. Simulate Redis message with a different instanceId
      listeners['message'](
        'carely:realtime:events',
        JSON.stringify({
          instanceId: 'remote-instance-other-uuid',
          recipientUserId: 'user-loopback',
          event: { type: RealtimeEventType.CHECK_IN_CONFIRMED, userId: 'user-loopback' },
        }),
      );

      // Must be delivered locally
      expect(socket.sendMock).toHaveBeenCalledTimes(1);
    });

    it('should attach an error listener on redisSubscriber to prevent unhandled error crashes', () => {
      const listeners: Record<string, (err: any) => void> = {};
      const mockSubscriber = {
        subscribe: vi.fn(),
        on: vi.fn((event: string, cb: any) => {
          listeners[event] = cb;
        }),
      };
      const mockClient = {
        duplicate: vi.fn().mockReturnValue(mockSubscriber),
      };

      (service as any).redisSubscriber = null;
      (service as any).attachSubscriber(mockClient);

      expect(mockSubscriber.on).toHaveBeenCalledWith('error', expect.any(Function));
      // Trigger error event to confirm it does not crash
      expect(() => {
        listeners['error'](new Error('Connection reset by peer'));
      }).not.toThrow();
    });
  });

  describe('Graceful Shutdown', () => {
    it('should close all open sockets on module destroy', async () => {
      const socket = createMockSocket();
      service.registerClient('user-1', socket as unknown as WebSocket);

      await service.onModuleDestroy();
      expect(socket.closeMock).toHaveBeenCalledWith(1000, 'Server shutting down');
      expect(service.getActiveSocketCount()).toBe(0);
    });
  });
});
