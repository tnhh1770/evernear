import { describe, it, expect, beforeAll, afterAll } from 'vitest';
import { INestApplication } from '@nestjs/common';
import { DataSource } from 'typeorm';
import request from 'supertest';
import {
  createE2eTestApp,
  resetDatabase,
  teardownE2eTestApp,
  TestUserContext,
} from './e2e/e2e-helper';
import { AuthService } from '../src/modules/auth/auth.service';
import { PairingInvitation } from '../src/modules/monitoring/entities/pairing-invitation.entity';

describe('Family QR Code Pairing E2E (Features 43 & 44)', () => {
  let app: INestApplication;
  let dataSource: DataSource;
  let authService: AuthService;

  let elderUser: TestUserContext;
  let guardianUser: TestUserContext;
  let thirdPartyUser: TestUserContext;

  beforeAll(async () => {
    const testApp = await createE2eTestApp();
    app = testApp.app;
    dataSource = testApp.dataSource;
    authService = testApp.moduleFixture.get<AuthService>(AuthService);

    await resetDatabase(dataSource);

    const ts = Date.now();
    // 1. Elder User
    const elderAuth = await authService.register({
      email: `elder_${ts}@carely.test`,
      password: 'Password123!',
      displayName: 'Nguyen Thi Ba',
      timezone: 'Asia/Ho_Chi_Minh',
    });
    elderUser = {
      id: elderAuth.user.id,
      email: elderAuth.user.email,
      displayName: elderAuth.user.displayName,
      accessToken: elderAuth.accessToken,
      refreshToken: elderAuth.refreshToken,
    };

    // 2. Guardian User
    const guardianAuth = await authService.register({
      email: `guardian_${ts}@carely.test`,
      password: 'Password123!',
      displayName: 'Nguyen Van Hai',
      timezone: 'Asia/Ho_Chi_Minh',
    });
    guardianUser = {
      id: guardianAuth.user.id,
      email: guardianAuth.user.email,
      displayName: guardianAuth.user.displayName,
      accessToken: guardianAuth.accessToken,
      refreshToken: guardianAuth.refreshToken,
    };

    // 3. Third-party User
    const thirdPartyAuth = await authService.register({
      email: `stranger_${ts}@carely.test`,
      password: 'Password123!',
      displayName: 'Le Van Khach',
      timezone: 'Asia/Ho_Chi_Minh',
    });
    thirdPartyUser = {
      id: thirdPartyAuth.user.id,
      email: thirdPartyAuth.user.email,
      displayName: thirdPartyAuth.user.displayName,
      accessToken: thirdPartyAuth.accessToken,
      refreshToken: thirdPartyAuth.refreshToken,
    };
  }, 30000);

  afterAll(async () => {
    await teardownE2eTestApp(app, dataSource);
  });

  describe('POST /api/v1/monitoring/relationships/invite-code', () => {
    it('requires authentication (401)', async () => {
      const res = await request(app.getHttpServer())
        .post('/api/v1/monitoring/relationships/invite-code')
        .send({});
      expect(res.status).toBe(401);
    });

    it('generates invite code with default MONITORED role (201)', async () => {
      const res = await request(app.getHttpServer())
        .post('/api/v1/monitoring/relationships/invite-code')
        .set('Authorization', `Bearer ${elderUser.accessToken}`)
        .send({ label: 'Gia đình' });

      expect(res.status).toBe(201);
      expect(res.body.invitationCode).toMatch(/^CR-[A-Z0-9]{6}$/);
      expect(res.body.inviteCode).toBe(res.body.invitationCode);
      expect(res.body.qrUri).toBe(`carely://invite?code=${res.body.invitationCode}`);
      expect(res.body.role).toBe('MONITORED');
      expect(res.body.label).toBe('Gia đình');

      const expires = new Date(res.body.expiresAt);
      expect(expires.getTime()).toBeGreaterThan(Date.now() + 47 * 3600 * 1000);
    });

    it('generates invite code with explicit MONITOR role (201)', async () => {
      const res = await request(app.getHttpServer())
        .post('/api/v1/monitoring/relationships/invite-code')
        .set('Authorization', `Bearer ${guardianUser.accessToken}`)
        .send({ role: 'MONITOR', label: 'Bố mẹ' });

      expect(res.status).toBe(201);
      expect(res.body.role).toBe('MONITOR');
      expect(res.body.label).toBe('Bố mẹ');
    });
  });

  describe('POST /api/v1/monitoring/relationships/accept - QR Code Flow', () => {
    it('case 1: Elder invites -> Guardian scans and pairs bidirectional relationship', async () => {
      // 1. Elder generates invite code
      const genRes = await request(app.getHttpServer())
        .post('/api/v1/monitoring/relationships/invite-code')
        .set('Authorization', `Bearer ${elderUser.accessToken}`)
        .send({ role: 'MONITORED', label: 'Con trai Hai' });
      expect(genRes.status).toBe(201);
      const code = genRes.body.invitationCode;

      // 2. Guardian scans QR URI
      const acceptRes = await request(app.getHttpServer())
        .post('/api/v1/monitoring/relationships/accept')
        .set('Authorization', `Bearer ${guardianUser.accessToken}`)
        .send({ invitationCode: `carely://invite?code=${code}` });

      expect(acceptRes.status).toBe(200);
      expect(acceptRes.body.id).toBeDefined();
      expect(acceptRes.body.monitorId).toBe(guardianUser.id);
      expect(acceptRes.body.monitoredUserId).toBe(elderUser.id);
      expect(acceptRes.body.status).toBe('ACCEPTED');
      expect(acceptRes.body.config).toBeDefined();
      expect(acceptRes.body.config.currentState).toBe('ACTIVE');
      expect(acceptRes.body.config.scheduleWindows).toHaveLength(7);

      // Verify listRelationships
      const guardianList = await request(app.getHttpServer())
        .get('/api/v1/monitoring/relationships')
        .set('Authorization', `Bearer ${guardianUser.accessToken}`);
      expect(guardianList.body.monitoring.some((r: any) => r.monitoredUserId === elderUser.id)).toBe(true);

      const elderList = await request(app.getHttpServer())
        .get('/api/v1/monitoring/relationships')
        .set('Authorization', `Bearer ${elderUser.accessToken}`);
      expect(elderList.body.monitoredBy.some((r: any) => r.monitorId === guardianUser.id)).toBe(true);
    });

    it('rejects self-pairing with own invitation code (400)', async () => {
      const genRes = await request(app.getHttpServer())
        .post('/api/v1/monitoring/relationships/invite-code')
        .set('Authorization', `Bearer ${thirdPartyUser.accessToken}`)
        .send({});
      expect(genRes.status).toBe(201);

      const acceptRes = await request(app.getHttpServer())
        .post('/api/v1/monitoring/relationships/accept')
        .set('Authorization', `Bearer ${thirdPartyUser.accessToken}`)
        .send({ invitationCode: genRes.body.invitationCode });

      expect(acceptRes.status).toBe(400);
      expect(acceptRes.body.message).toContain('own invitation code');
    });

    it('rejects double-acceptance of single-use invite code (409)', async () => {
      // Third party generates invite code
      const genRes = await request(app.getHttpServer())
        .post('/api/v1/monitoring/relationships/invite-code')
        .set('Authorization', `Bearer ${thirdPartyUser.accessToken}`)
        .send({ role: 'MONITORED' });
      expect(genRes.status).toBe(201);
      const code = genRes.body.invitationCode;

      // Guardian accepts first
      const firstAccept = await request(app.getHttpServer())
        .post('/api/v1/monitoring/relationships/accept')
        .set('Authorization', `Bearer ${guardianUser.accessToken}`)
        .send({ invitationCode: code });
      expect(firstAccept.status).toBe(200);

      // Elder attempts to accept the same code
      const secondAccept = await request(app.getHttpServer())
        .post('/api/v1/monitoring/relationships/accept')
        .set('Authorization', `Bearer ${elderUser.accessToken}`)
        .send({ invitationCode: code });
      expect(secondAccept.status).toBe(409);
      expect(secondAccept.body.message).toContain('already been accepted');
    });

    it('rejects expired invitation code (400)', async () => {
      const genRes = await request(app.getHttpServer())
        .post('/api/v1/monitoring/relationships/invite-code')
        .set('Authorization', `Bearer ${thirdPartyUser.accessToken}`)
        .send({});
      expect(genRes.status).toBe(201);
      const code = genRes.body.invitationCode;

      // Manually set expiration in past
      await dataSource.getRepository(PairingInvitation).update(
        { invitationCode: code },
        { expiresAt: new Date(Date.now() - 3600 * 1000) },
      );

      const acceptRes = await request(app.getHttpServer())
        .post('/api/v1/monitoring/relationships/accept')
        .set('Authorization', `Bearer ${guardianUser.accessToken}`)
        .send({ invitationCode: code });

      expect(acceptRes.status).toBe(400);
      expect(acceptRes.body.message).toContain('expired');
    });

    it('backward compatibility: legacy email invitation accepted correctly', async () => {
      const stranger2 = await authService.register({
        email: `stranger2_${Date.now()}@carely.test`,
        password: 'Password123!',
        displayName: 'Stranger 2',
      });

      // Legacy create relationship via email
      const legRes = await request(app.getHttpServer())
        .post('/api/v1/monitoring/relationships')
        .set('Authorization', `Bearer ${guardianUser.accessToken}`)
        .send({ monitoredUserEmail: stranger2.user.email });
      expect(legRes.status).toBe(201);
      const legacyCode = legRes.body.invitationCode;

      // Accept with legacy code
      const acceptRes = await request(app.getHttpServer())
        .post('/api/v1/monitoring/relationships/accept')
        .set('Authorization', `Bearer ${stranger2.accessToken}`)
        .send({ invitationCode: legacyCode });

      expect(acceptRes.status).toBe(200);
      expect(acceptRes.body.status).toBe('ACCEPTED');
    });
  });
});
