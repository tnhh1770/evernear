import { describe, it, expect, vi, beforeEach } from 'vitest';
import { Test, TestingModule } from '@nestjs/testing';
import { getRepositoryToken } from '@nestjs/typeorm';
import {
  NotFoundException,
  ConflictException,
  BadRequestException,
} from '@nestjs/common';
import { MonitoringService } from './monitoring.service';
import {
  PairingInvitation,
  PairingInvitationRole,
  PairingInvitationStatus,
} from './entities/pairing-invitation.entity';
import { MonitoringRelationship } from './entities/monitoring-relationship.entity';
import { MonitoringConfig } from './entities/monitoring-config.entity';
import { MonitoringScheduleWindow } from './entities/monitoring-schedule-window.entity';
import { User } from '../users/entities/user.entity';
import { RelationshipStatus } from '../../common/enums';

describe('MonitoringService - QR Pairing & Invitations', () => {
  let service: MonitoringService;
  let pairingRepo: any;
  let relRepo: any;
  let userRepo: any;

  const mockUser = {
    id: 'user-elder-1',
    email: 'elder@carely.test',
    displayName: 'Nguyen Elder',
    timezone: 'Asia/Ho_Chi_Minh',
  };

  const mockScanner = {
    id: 'user-guardian-1',
    email: 'guardian@carely.test',
    displayName: 'Tran Guardian',
  };

  beforeEach(async () => {
    pairingRepo = {
      create: vi.fn((data) => ({ ...data, id: 'inv-uuid-1' })),
      save: vi.fn(async (data) => data),
      findOne: vi.fn(),
    };

    relRepo = {
      findOne: vi.fn(),
      create: vi.fn((data) => ({ ...data, id: 'rel-uuid-1' })),
      save: vi.fn(async (data) => data),
      manager: {
        transaction: vi.fn(async (cb) => {
          const fakeManager = {
            findOne: vi.fn(),
            save: vi.fn(async (d) => d),
            create: vi.fn((entity, d) => ({ ...d, id: 'uuid-gen' })),
            update: vi.fn(),
          };
          return cb(fakeManager);
        }),
      },
    };

    userRepo = {
      findOne: vi.fn(),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        MonitoringService,
        { provide: getRepositoryToken(PairingInvitation), useValue: pairingRepo },
        { provide: getRepositoryToken(MonitoringRelationship), useValue: relRepo },
        { provide: getRepositoryToken(MonitoringConfig), useValue: {} },
        { provide: getRepositoryToken(MonitoringScheduleWindow), useValue: {} },
        { provide: getRepositoryToken(User), useValue: userRepo },
      ],
    }).compile();

    service = module.get<MonitoringService>(MonitoringService);
  });

  describe('generateInviteCode', () => {
    it('generates a valid code CR-XXXXXX with 48-hour expiration and default MONITORED role', async () => {
      userRepo.findOne.mockResolvedValue(mockUser);
      pairingRepo.findOne.mockResolvedValue(null); // No collision

      const result = await service.generateInviteCode(mockUser.id, { label: 'Gia đình' });

      expect(result.invitationCode).toMatch(/^CR-[A-Z0-9]{6}$/);
      expect(result.inviteCode).toBe(result.invitationCode);
      expect(result.qrUri).toBe(`carely://invite?code=${result.invitationCode}`);
      expect(result.role).toBe(PairingInvitationRole.MONITORED);
      expect(result.label).toBe('Gia đình');

      const expiresAtDate = new Date(result.expiresAt);
      const expectedDate = new Date(Date.now() + 48 * 60 * 60 * 1000);
      expect(Math.abs(expiresAtDate.getTime() - expectedDate.getTime())).toBeLessThan(5000);
    });

    it('generates invite code with explicit MONITOR role', async () => {
      userRepo.findOne.mockResolvedValue(mockScanner);
      pairingRepo.findOne.mockResolvedValue(null);

      const result = await service.generateInviteCode(mockScanner.id, {
        role: PairingInvitationRole.MONITOR,
      });

      expect(result.role).toBe(PairingInvitationRole.MONITOR);
    });

    it('throws NotFoundException if user is not found', async () => {
      userRepo.findOne.mockResolvedValue(null);
      await expect(service.generateInviteCode('non-existent', {})).rejects.toThrow(
        NotFoundException,
      );
    });
  });

  describe('acceptInvitation - validation & bidirectional pairing', () => {
    it('rejects self-pairing when inviterId equals scanner userId', async () => {
      const code = 'CR-SELF01';
      relRepo.manager.transaction = vi.fn(async (cb) => {
        const mgr = {
          findOne: vi.fn().mockImplementation((entity) => {
            if (entity === PairingInvitation) {
              return {
                id: 'inv-1',
                invitationCode: code,
                inviterId: mockUser.id, // same as scanner
                status: PairingInvitationStatus.ACTIVE,
                expiresAt: new Date(Date.now() + 100000),
                role: PairingInvitationRole.MONITORED,
              };
            }
            return null;
          }),
          save: vi.fn(),
        };
        return cb(mgr);
      });

      await expect(
        service.acceptInvitation(mockUser.id, { invitationCode: code }),
      ).rejects.toThrow(BadRequestException);
    });

    it('rejects expired invitation code', async () => {
      const code = 'CR-EXPIRE';
      relRepo.manager.transaction = vi.fn(async (cb) => {
        const mgr = {
          findOne: vi.fn().mockImplementation((entity) => {
            if (entity === PairingInvitation) {
              return {
                id: 'inv-2',
                invitationCode: code,
                inviterId: mockUser.id,
                status: PairingInvitationStatus.ACTIVE,
                expiresAt: new Date(Date.now() - 1000), // Expired 1s ago
                role: PairingInvitationRole.MONITORED,
              };
            }
            return null;
          }),
          save: vi.fn(),
        };
        return cb(mgr);
      });

      await expect(
        service.acceptInvitation(mockScanner.id, { invitationCode: code }),
      ).rejects.toThrow('This invitation code has expired');
    });

    it('rejects already accepted invitation code', async () => {
      const code = 'CR-USEDONCE';
      relRepo.manager.transaction = vi.fn(async (cb) => {
        const mgr = {
          findOne: vi.fn().mockImplementation((entity) => {
            if (entity === PairingInvitation) {
              return {
                id: 'inv-3',
                invitationCode: code,
                inviterId: mockUser.id,
                status: PairingInvitationStatus.ACCEPTED,
                expiresAt: new Date(Date.now() + 100000),
                role: PairingInvitationRole.MONITORED,
              };
            }
            return null;
          }),
          save: vi.fn(),
        };
        return cb(mgr);
      });

      await expect(
        service.acceptInvitation(mockScanner.id, { invitationCode: code }),
      ).rejects.toThrow(ConflictException);
    });

    it('rejects when relationship already exists between the accounts', async () => {
      const code = 'CR-DUPEREL';
      relRepo.manager.transaction = vi.fn(async (cb) => {
        const mgr = {
          findOne: vi.fn().mockImplementation((entity) => {
            if (entity === PairingInvitation) {
              return {
                id: 'inv-4',
                invitationCode: code,
                inviterId: mockUser.id,
                status: PairingInvitationStatus.ACTIVE,
                expiresAt: new Date(Date.now() + 100000),
                role: PairingInvitationRole.MONITORED,
              };
            }
            if (entity === MonitoringRelationship) {
              return {
                id: 'rel-existing',
                monitorId: mockScanner.id,
                monitoredUserId: mockUser.id,
                status: RelationshipStatus.ACCEPTED,
              };
            }
            return null;
          }),
          save: vi.fn(),
        };
        return cb(mgr);
      });

      await expect(
        service.acceptInvitation(mockScanner.id, { invitationCode: code }),
      ).rejects.toThrow(ConflictException);
    });

    it('falls back to legacy monitoring_relationships when not in pairing_invitations', async () => {
      const legacyCode = 'LEGACY01';
      const legacyRecord = {
        id: 'rel-legacy-1',
        invitationCode: legacyCode,
        monitoredUserId: mockScanner.id,
        status: RelationshipStatus.PENDING,
      };

      relRepo.manager.transaction = vi.fn(async (cb) => {
        const mgr = {
          findOne: vi.fn().mockImplementation((entity) => {
            if (entity === PairingInvitation) return null; // Not found
            if (entity === MonitoringRelationship) {
              return legacyRecord;
            }
            return null;
          }),
          save: vi.fn((e) => {
            if (e && e.id === legacyRecord.id) {
              legacyRecord.status = e.status;
            }
            return Promise.resolve(e);
          }),
          update: vi.fn(),
        };
        return cb(mgr);
      });

      const res = await service.acceptInvitation(mockScanner.id, {
        invitationCode: legacyCode,
      });
      expect(res.status).toBe(RelationshipStatus.ACCEPTED);
    });
  });
});
