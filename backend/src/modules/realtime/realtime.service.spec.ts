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

  const createMockSocket = (readyState = WebSocket.OPEN) => ({
    readyState,
    send: vi.fn(),
    close: vi.fn(),
  });

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
      const socket = createMockSocket() as unknown as WebSocket;
      service.registerClient('user-1', socket);

      expect(service.getConnectedUserCount()).toBe(1);
      expect(service.getActiveSocketCount()).toBe(1);
      expect(socket.send).toHaveBeenCalledTimes(1);
      const sentPayload = JSON.parse((socket.send as any).mock.calls[0][0]);
      expect(sentPayload.type).toBe('CONNECTED');
      expect(sentPayload.userId).toBe('user-1');
    });

    it('should support multiple sockets for the same user', () => {
      const socket1 = createMockSocket() as unknown as WebSocket;
      const socket2 = createMockSocket() as unknown as WebSocket;

      service.registerClient('user-1', socket1);
      service.registerClient('user-1', socket2);

      expect(service.getConnectedUserCount()).toBe(1);
      expect(service.getActiveSocketCount()).toBe(2);
    });

    it('should remove socket upon disconnect', () => {
      const socket1 = createMockSocket() as unknown as WebSocket;
      const socket2 = createMockSocket() as unknown as WebSocket;

      service.registerClient('user-1', socket1);
      service.registerClient('user-1', socket2);

      service.removeClient('user-1', socket1);
      expect(service.getActiveSocketCount()).toBe(1);
      expect(service.getConnectedUserCount()).toBe(1);

      service.removeClient('user-1', socket2);
      expect(service.getActiveSocketCount()).toBe(0);
      expect(service.getConnectedUserCount()).toBe(0);
    });
  });

  describe('Event Emission', () => {
    it('should emit to registered user socket', async () => {
      const socket = createMockSocket() as unknown as WebSocket;
      service.registerClient('user-1', socket);
      (socket.send as any).mockClear();

      await service.emitToUser('user-1', {
        type: RealtimeEventType.CHECK_IN_CONFIRMED,
        userId: 'user-1',
        checkInId: 'chk-1',
        occurredAt: '2026-10-13T12:00:00Z',
      });

      expect(socket.send).toHaveBeenCalledTimes(1);
      const sent = JSON.parse((socket.send as any).mock.calls[0][0]);
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

      const monitorSocket1 = createMockSocket() as unknown as WebSocket;
      const monitorSocket2 = createMockSocket() as unknown as WebSocket;
      service.registerClient('monitor-1', monitorSocket1);
      service.registerClient('monitor-2', monitorSocket2);
      (monitorSocket1.send as any).mockClear();
      (monitorSocket2.send as any).mockClear();

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

      expect(monitorSocket1.send).toHaveBeenCalledTimes(1);
      expect(monitorSocket2.send).toHaveBeenCalledTimes(1);
    });

    it('should emit to both participants of a relationship', async () => {
      mockRelationshipRepo.findOne.mockResolvedValue({
        id: 'rel-1',
        monitorId: 'monitor-1',
        monitoredUserId: 'elder-1',
      });

      const monitorSocket = createMockSocket() as unknown as WebSocket;
      const elderSocket = createMockSocket() as unknown as WebSocket;
      service.registerClient('monitor-1', monitorSocket);
      service.registerClient('elder-1', elderSocket);
      (monitorSocket.send as any).mockClear();
      (elderSocket.send as any).mockClear();

      await service.emitToRelationship('rel-1', {
        type: RealtimeEventType.MONITORING_CONFIG_UPDATED,
        relationshipId: 'rel-1',
        config: {},
      });

      expect(monitorSocket.send).toHaveBeenCalledTimes(1);
      expect(elderSocket.send).toHaveBeenCalledTimes(1);
    });
  });

  describe('Graceful Shutdown', () => {
    it('should close all open sockets on module destroy', async () => {
      const socket = createMockSocket() as unknown as WebSocket;
      service.registerClient('user-1', socket);

      await service.onModuleDestroy();
      expect(socket.close).toHaveBeenCalledWith(1000, 'Server shutting down');
      expect(service.getActiveSocketCount()).toBe(0);
    });
  });
});
