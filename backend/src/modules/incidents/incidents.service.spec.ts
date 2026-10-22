import { describe, it, expect, beforeEach, vi } from 'vitest';
import { NotFoundException, ForbiddenException } from '@nestjs/common';
import { IncidentsService } from './incidents.service';
import { IncidentEvent } from './entities/incident-event.entity';

describe('IncidentsService - Deletion & Clear All (Unit)', () => {
  let service: IncidentsService;
  let mockIncidentRepo: any;
  let mockRelationshipRepo: any;
  let mockConfigRepo: any;
  let mockEventService: any;
  let mockRealtimeService: any;

  beforeEach(() => {
    mockIncidentRepo = {
      findOne: vi.fn(),
      find: vi.fn(),
      delete: vi.fn().mockResolvedValue({ affected: 1 }),
      manager: {
        delete: vi.fn().mockResolvedValue({ affected: 1 }),
      },
    };
    mockRelationshipRepo = {
      find: vi.fn(),
    };
    mockConfigRepo = {
      findOne: vi.fn(),
      save: vi.fn(),
    };
    mockEventService = {
      logEvent: vi.fn(),
    };
    mockRealtimeService = {
      emitToRelationship: vi.fn().mockResolvedValue(undefined),
    };

    service = new IncidentsService(
      mockIncidentRepo,
      mockRelationshipRepo,
      mockConfigRepo,
      mockEventService,
      mockRealtimeService,
    );
  });

  describe('deleteIncident', () => {
    it('should throw NotFoundException if incident not found', async () => {
      mockIncidentRepo.findOne.mockResolvedValue(null);
      await expect(service.deleteIncident('user-1', 'inc-1')).rejects.toThrow(
        NotFoundException,
      );
    });

    it('should throw ForbiddenException if user is neither monitored user nor monitor', async () => {
      mockIncidentRepo.findOne.mockResolvedValue({
        id: 'inc-1',
        userId: 'monitored-1',
        relationship: {
          monitorId: 'monitor-1',
        },
      });

      await expect(service.deleteIncident('intruder', 'inc-1')).rejects.toThrow(
        ForbiddenException,
      );
    });

    it('should delete incident and cascade delete events when authorized', async () => {
      mockIncidentRepo.findOne.mockResolvedValue({
        id: 'inc-1',
        userId: 'monitored-1',
        relationshipId: 'rel-1',
        relationship: {
          monitorId: 'monitor-1',
        },
      });

      const res = await service.deleteIncident('monitored-1', 'inc-1');
      expect(res).toEqual({ success: true, message: 'Incident deleted' });
      expect(mockIncidentRepo.manager.delete).toHaveBeenCalledWith(IncidentEvent, {
        incidentId: 'inc-1',
      });
      expect(mockIncidentRepo.delete).toHaveBeenCalledWith('inc-1');
    });
  });

  describe('clearAllIncidents', () => {
    it('should return count 0 if user has no relationships', async () => {
      mockRelationshipRepo.find.mockResolvedValue([]);
      const res = await service.clearAllIncidents('user-1');
      expect(res).toEqual({ success: true, count: 0 });
    });

    it('should return count 0 if relationships have no incidents', async () => {
      mockRelationshipRepo.find.mockResolvedValue([{ id: 'rel-1' }]);
      mockIncidentRepo.find.mockResolvedValue([]);
      const res = await service.clearAllIncidents('user-1');
      expect(res).toEqual({ success: true, count: 0 });
    });

    it('should delete all incidents and events across relationships', async () => {
      mockRelationshipRepo.find.mockResolvedValue([{ id: 'rel-1' }, { id: 'rel-2' }]);
      mockIncidentRepo.find.mockResolvedValue([
        { id: 'inc-1', relationshipId: 'rel-1' },
        { id: 'inc-2', relationshipId: 'rel-2' },
      ]);

      const res = await service.clearAllIncidents('user-1');
      expect(res).toEqual({ success: true, count: 2 });
      expect(mockIncidentRepo.manager.delete).toHaveBeenCalledWith(
        IncidentEvent,
        expect.anything(),
      );
      expect(mockIncidentRepo.delete).toHaveBeenCalled();
    });
  });
});
