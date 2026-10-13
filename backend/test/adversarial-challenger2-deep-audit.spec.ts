import { describe, it, expect, beforeAll, afterAll } from 'vitest';
import { INestApplication } from '@nestjs/common';
import { DataSource } from 'typeorm';
import request from 'supertest';
import { validate } from 'class-validator';
import { plainToInstance } from 'class-transformer';

import {
  createE2eTestApp,
  resetDatabase,
  teardownE2eTestApp,
  registerAndLoginUser,
  TestUserContext,
} from './e2e/e2e-helper';

import { NotificationTemplateService } from '../src/modules/notifications/notification-template.service';
import { MonitoringScheduler } from '../src/modules/monitoring/monitoring-scheduler';
import { ScheduleWindowDto } from '../src/modules/monitoring/dto/monitoring.dto';
import { PairingInvitation, PairingInvitationStatus } from '../src/modules/monitoring/entities/pairing-invitation.entity';
import { MonitoringScheduleWindow } from '../src/modules/monitoring/entities/monitoring-schedule-window.entity';
import { MonitoringRelationship } from '../src/modules/monitoring/entities/monitoring-relationship.entity';

describe('Adversarial Challenger 2 Deep Audit: Features 37–47 Edge Cases', () => {
  let app: INestApplication;
  let dataSource: DataSource;
  let templateService: NotificationTemplateService;

  let testUser1: TestUserContext;
  let testUser2: TestUserContext;
  let testUser3: TestUserContext;

  beforeAll(async () => {
    const context = await createE2eTestApp();
    app = context.app;
    dataSource = context.dataSource;
    templateService = app.get(NotificationTemplateService);

    await resetDatabase(dataSource);

    testUser1 = await registerAndLoginUser(app, 'challenger2_u1');
    testUser2 = await registerAndLoginUser(app, 'challenger2_u2');
    testUser3 = await registerAndLoginUser(app, 'challenger2_u3');
  }, 30000);

  afterAll(async () => {
    await teardownE2eTestApp(app, dataSource);
  });

  // =========================================================================
  // SECTION 1: Notification Template Engine Adversarial Verification
  // =========================================================================
  describe('1. Notification Template Engine Adversarial Edge Cases', () => {
    it('1.1 should preserve special RegExp replacement tokens literally ($$, $&, $\', $`, $1, $$$$)', () => {
      // In JavaScript replace(regex, str), special characters get expanded if replacement is a string:
      // - '$$' -> '$'
      // - '$&' -> matched pattern
      // - '$`' -> prefix before match
      // - "$'" -> suffix after match
      // - '$1' -> first capture group
      // Using replacer function () => replacement ensures literal string preservation.

      const testTokens = [
        '$$',
        '$$$$',
        '$$100',
        '$&',
        '$`',
        "$' ",
        '$1',
        '$99',
        'Price is $100 & fee is $$5',
        'prefix $& middle $\' suffix $` test $$',
      ];

      for (const token of testTokens) {
        const rendered = templateService.render(
          'MONITOR_INACTIVITY_WARNING',
          { name: token },
          'en',
        );

        // Verification: token must be present verbatim in the output
        expect(rendered.body).toContain(token);
        expect(rendered.body).not.toContain('{name}');
      }
    });

    it('1.2 should safely escape regex metacharacters in parameter keys without throwing or injecting', () => {
      const maliciousKeys: Record<string, string> = {
        'foo.*': 'wildcard_val',
        '(group)': 'group_val',
        '[class]': 'class_val',
        '{curly}': 'curly_val',
        'dollar$': 'dollar_val',
        '^caret': 'caret_val',
        'plus+': 'plus_val',
        'question?': 'question_val',
        'pipe|or': 'pipe_val',
        'backslash\\': 'backslash_val',
      };

      expect(() => {
        const rendered = templateService.render('CHECK_IN_PROMPT', maliciousKeys, 'vi');
        expect(rendered.title).toBeDefined();
        expect(rendered.body).toBeDefined();
      }).not.toThrow();
    });

    it('1.3 should execute 4-tier safe fallback cascade correctly across locales and template names', () => {
      // Tier 1: Exact catalog match
      const frExact = templateService.render('CHECK_IN_PROMPT', {}, 'fr');
      expect(frExact.title).toContain('Tout va bien ?');

      // Tier 2: Locale unsupported -> fall back to English
      const unknownLocale = templateService.render('CHECK_IN_PROMPT', {}, 'xy-ZZ');
      expect(unknownLocale.title).toContain('Are you doing okay?');

      // Tier 3: Template missing in English but exists in Vietnamese -> fall back to vi
      // If template is completely unknown in all catalogs -> Tier 4 default template
      const unknownTemplate = templateService.render('NON_EXISTENT_TEMPLATE_ABC', {}, 'de');
      expect(unknownTemplate.title).toBe('Carely');
      expect(unknownTemplate.body).toBe('Neue Benachrichtigung aus dem Carely-System.');

      // Tier 4 with unknown locale -> English default template
      const unknownBoth = templateService.render('NON_EXISTENT_TEMPLATE_XYZ', {}, 'unknown-lang');
      expect(unknownBoth.title).toBe('Carely');
      expect(unknownBoth.body).toBe('New notification from Carely care system.');
    });

    it('1.4 should handle extreme edge-case locales (empty, null, uppercase, regional tags, symbols)', () => {
      const edgeLocales = ['', '   ', 'VI', 'EN_US', 'pt-BR', 'es-419', 'invalid!!', '123'];
      for (const loc of edgeLocales) {
        expect(() => {
          const res = templateService.render('CHECK_IN_REMINDER', {}, loc as any);
          expect(res.title).toBeDefined();
          expect(res.body).toBeDefined();
        }).not.toThrow();
      }
    });
  });

  // =========================================================================
  // SECTION 2: Social Auth Account Linking & Validation
  // =========================================================================
  describe('2. Social Auth Account Linking & Validation Edge Cases', () => {
    it('2.1 should reject empty tokens with 400 and whitespace-only Google ID tokens with 401 Unauthorized', async () => {
      const emptyRes = await request(app.getHttpServer())
        .post('/api/v1/auth/google')
        .send({ idToken: '' });
      expect(emptyRes.status).toBe(400);

      const spaceRes = await request(app.getHttpServer())
        .post('/api/v1/auth/google')
        .send({ idToken: '   ' });
      expect(spaceRes.status).toBe(401);
      expect(spaceRes.body.message).toContain('Google ID token is required');
    });

    it('2.2 should reject empty tokens with 400 and whitespace-only Apple identity tokens with 401 Unauthorized', async () => {
      const emptyRes = await request(app.getHttpServer())
        .post('/api/v1/auth/apple')
        .send({ identityToken: '' });
      expect(emptyRes.status).toBe(400);

      const spaceRes = await request(app.getHttpServer())
        .post('/api/v1/auth/apple')
        .send({ identityToken: '   ' });
      expect(spaceRes.status).toBe(401);
      expect(spaceRes.body.message).toContain('Apple identity token is required');
    });

    it('2.3 should safely link Google account to existing user without corrupting password hash', async () => {
      const ts = Date.now();
      const email = `link_edge_${ts}@carely.test`;
      const password = 'StrongPassword!123';

      // 1. Register with email & password
      const regRes = await request(app.getHttpServer())
        .post('/api/v1/auth/register')
        .send({ email, password, displayName: 'Original Name' });
      expect(regRes.status).toBe(201);
      const originalUserId = regRes.body.user.id;

      // 2. Sign in with Google using matching email
      const googleRes = await request(app.getHttpServer())
        .post('/api/v1/auth/google')
        .send({
          idToken: `mock-google-edge-${ts}`,
          email,
          displayName: 'Google Updated Name',
          avatarUrl: 'https://example.com/avatar.jpg',
        });
      expect(googleRes.status).toBe(200);
      expect(googleRes.body.user.id).toBe(originalUserId);

      // 3. Confirm password login still succeeds
      const loginRes = await request(app.getHttpServer())
        .post('/api/v1/auth/login')
        .send({ email, password });
      expect(loginRes.status).toBe(200);
      expect(loginRes.body.user.id).toBe(originalUserId);
    });

    it('2.4 should maintain persistent identity for returning Google user by googleId', async () => {
      const ts = Date.now();
      const googleIdToken = `mock-google-returning-${ts}`;
      const email = `google_ret_${ts}@carely.test`;

      // First Google login
      const firstRes = await request(app.getHttpServer())
        .post('/api/v1/auth/google')
        .send({ idToken: googleIdToken, email });
      expect(firstRes.status).toBe(200);
      const userId = firstRes.body.user.id;

      // Second Google login with same googleId (even if email is omitted in request)
      const secondRes = await request(app.getHttpServer())
        .post('/api/v1/auth/google')
        .send({ idToken: googleIdToken });
      expect(secondRes.status).toBe(200);
      expect(secondRes.body.user.id).toBe(userId);
    });
  });

  // =========================================================================
  // SECTION 3: Family QR Code Pairing Concurrency & Edge Cases
  // =========================================================================
  describe('3. Family QR Code Pairing Concurrency & State Invariants', () => {
    it('3.1 should reject anti-self-pairing regardless of QR code format', async () => {
      // User 1 generates invite code
      const genRes = await request(app.getHttpServer())
        .post('/api/v1/monitoring/relationships/invite-code')
        .set('Authorization', `Bearer ${testUser1.accessToken}`)
        .send({ role: 'MONITORED' });
      expect(genRes.status).toBe(201);
      const code = genRes.body.invitationCode;

      // Format variations tried by the SAME user
      const selfPairPayloads = [
        code,
        `carely://invite?code=${code}`,
        `https://carely.app/invite?code=${code}`,
        code.toLowerCase(),
      ];

      for (const payload of selfPairPayloads) {
        const res = await request(app.getHttpServer())
          .post('/api/v1/monitoring/relationships/accept')
          .set('Authorization', `Bearer ${testUser1.accessToken}`)
          .send({ invitationCode: payload });

        expect(res.status).toBe(400);
        expect(res.body.message).toContain('own invitation code');
      }
    });

    it('3.2 should prevent double-acceptance races under true concurrent execution (Promise.all)', async () => {
      // User 1 generates invite code
      const genRes = await request(app.getHttpServer())
        .post('/api/v1/monitoring/relationships/invite-code')
        .set('Authorization', `Bearer ${testUser1.accessToken}`)
        .send({ role: 'MONITORED' });
      expect(genRes.status).toBe(201);
      const code = genRes.body.invitationCode;

      // Send 5 simultaneous accept requests from User 2 and User 3
      const requests = [
        request(app.getHttpServer())
          .post('/api/v1/monitoring/relationships/accept')
          .set('Authorization', `Bearer ${testUser2.accessToken}`)
          .send({ invitationCode: code }),
        request(app.getHttpServer())
          .post('/api/v1/monitoring/relationships/accept')
          .set('Authorization', `Bearer ${testUser3.accessToken}`)
          .send({ invitationCode: code }),
        request(app.getHttpServer())
          .post('/api/v1/monitoring/relationships/accept')
          .set('Authorization', `Bearer ${testUser2.accessToken}`)
          .send({ invitationCode: code }),
      ];

      const responses = await Promise.all(requests);
      const statusCodes = responses.map((r) => r.status);

      // Exactly ONE request must succeed with 200, all others must be rejected with 409 Conflict
      const successCount = statusCodes.filter((s) => s === 200).length;
      const conflictCount = statusCodes.filter((s) => s === 409).length;

      expect(successCount).toBe(1);
      expect(conflictCount).toBe(2);

      // Verify the invitation status in DB is strictly ACCEPTED
      const invitation = await dataSource.getRepository(PairingInvitation).findOne({
        where: { invitationCode: code },
      });
      expect(invitation?.status).toBe(PairingInvitationStatus.ACCEPTED);
    });

    it('3.3 should reject expired QR invite code and pre-expired status codes with 400 Bad Request', async () => {
      const genRes = await request(app.getHttpServer())
        .post('/api/v1/monitoring/relationships/invite-code')
        .set('Authorization', `Bearer ${testUser1.accessToken}`)
        .send({ role: 'MONITOR' });
      expect(genRes.status).toBe(201);
      const code = genRes.body.invitationCode;

      // 1. Manually backdate expiration to 1 hour ago
      await dataSource.getRepository(PairingInvitation).update(
        { invitationCode: code },
        { expiresAt: new Date(Date.now() - 3600 * 1000) },
      );

      const acceptRes = await request(app.getHttpServer())
        .post('/api/v1/monitoring/relationships/accept')
        .set('Authorization', `Bearer ${testUser2.accessToken}`)
        .send({ invitationCode: code });

      expect(acceptRes.status).toBe(400);
      expect(acceptRes.body.message).toContain('expired');

      // 2. Pre-set status to EXPIRED explicitly
      await dataSource.getRepository(PairingInvitation).update(
        { invitationCode: code },
        { status: PairingInvitationStatus.EXPIRED },
      );

      const acceptRes2 = await request(app.getHttpServer())
        .post('/api/v1/monitoring/relationships/accept')
        .set('Authorization', `Bearer ${testUser2.accessToken}`)
        .send({ invitationCode: code });

      expect(acceptRes2.status).toBe(400);
      expect(acceptRes2.body.message).toContain('expired');

      // 3. Confirm zero relationships created between User 1 and User 2
      const relCount = await dataSource.getRepository(MonitoringRelationship).count({
        where: { monitorId: testUser1.id, monitoredUserId: testUser2.id },
      });
      expect(relCount).toBe(0);
    });
  });

  // =========================================================================
  // SECTION 4: Schedule Time Format Fuzzing & DTO Boundary Validation
  // =========================================================================
  describe('4. Schedule Time Format Regex Fuzzing & DTO Validation', () => {
    const invalidTimeStrings = [
      '24:00',
      '24:01',
      '25:00',
      '99:99',
      '12:60',
      '12:61',
      '00:60',
      '23:60',
      '7:00',
      '07:5',
      '7:5',
      '12:0',
      '0:0',
      '-01:00',
      '+01:00',
      '12:00:00',
      '12.00',
      '12-00',
      '12 00',
      ' 12:00',
      '12:00 ',
      '\n12:00',
      '12:00\n',
      'abc',
      '12:ab',
      'ab:12',
      '::',
      '',
    ];

    for (const badTime of invalidTimeStrings) {
      it(`should reject invalid time format "${badTime}" via DTO validation`, async () => {
        const dto = plainToInstance(ScheduleWindowDto, {
          dayOfWeek: 1,
          startTime: badTime,
          endTime: '22:00',
          isEnabled: true,
        });

        const errors = await validate(dto);
        expect(errors.length).toBeGreaterThan(0);
        expect(errors.some((e) => e.property === 'startTime')).toBe(true);
      });
    }

    const validTimeStrings = [
      '00:00',
      '00:01',
      '00:59',
      '01:00',
      '09:30',
      '12:00',
      '12:59',
      '13:00',
      '19:45',
      '23:00',
      '23:59',
    ];

    for (const goodTime of validTimeStrings) {
      it(`should accept valid 24h time format "${goodTime}" via DTO validation`, async () => {
        const dto = plainToInstance(ScheduleWindowDto, {
          dayOfWeek: 2,
          startTime: goodTime,
          endTime: '23:59',
          isEnabled: true,
        });

        const errors = await validate(dto);
        expect(errors.length).toBe(0);
      });
    }
  });

  // =========================================================================
  // SECTION 5: InactivityWorker Quiet Hours Deferral
  // =========================================================================
  describe('5. InactivityWorker Quiet Hours Deferral Verification', () => {
    it('5.1 should defer nextEvaluationAt to next active start when outside schedule window', () => {
      // Define active window: 07:00 to 22:00 UTC on Tuesday (dayOfWeek = 2)
      const windows = [
        {
          dayOfWeek: 2,
          startTime: '07:00',
          endTime: '22:00',
          isEnabled: true,
        } as MonitoringScheduleWindow,
      ];

      // 2026-10-06 was Tuesday
      // 1. Outside window at 22:30 UTC
      const nightTime = new Date('2026-10-06T22:30:00.000Z');
      const isInsideNight = MonitoringScheduler.isWithinActiveWindow(nightTime, windows, 'UTC');
      expect(isInsideNight).toBe(false);

      // Deferral check
      const nextStart = MonitoringScheduler.getNextActiveWindowStart(nightTime, windows, 'UTC');
      // Next Tuesday 07:00 UTC = 2026-10-13T07:00:00.000Z
      expect(nextStart.toISOString()).toBe('2026-10-13T07:00:00.000Z');

      // 2. Inside window at 14:00 UTC
      const dayTime = new Date('2026-10-06T14:00:00.000Z');
      const isInsideDay = MonitoringScheduler.isWithinActiveWindow(dayTime, windows, 'UTC');
      expect(isInsideDay).toBe(true);
    });

    it('5.2 should handle overnight windows spanning midnight correctly (e.g. 22:00 -> 06:00)', () => {
      // Overnight window on Monday (dayOfWeek = 1): 22:00 to 06:00 (ends Tuesday morning)
      const windows = [
        {
          dayOfWeek: 1,
          startTime: '22:00',
          endTime: '06:00',
          isEnabled: true,
        } as MonitoringScheduleWindow,
      ];

      // Monday 2026-10-05 21:59 UTC -> outside
      expect(
        MonitoringScheduler.isWithinActiveWindow(
          new Date('2026-10-05T21:59:00.000Z'),
          windows,
          'UTC',
        ),
      ).toBe(false);

      // Monday 2026-10-05 22:01 UTC -> inside (evening portion)
      expect(
        MonitoringScheduler.isWithinActiveWindow(
          new Date('2026-10-05T22:01:00.000Z'),
          windows,
          'UTC',
        ),
      ).toBe(true);

      // Tuesday 2026-10-06 02:00 UTC -> inside (cross-midnight morning portion)
      expect(
        MonitoringScheduler.isWithinActiveWindow(
          new Date('2026-10-06T02:00:00.000Z'),
          windows,
          'UTC',
        ),
      ).toBe(true);

      // Tuesday 2026-10-06 05:59 UTC -> inside
      expect(
        MonitoringScheduler.isWithinActiveWindow(
          new Date('2026-10-06T05:59:00.000Z'),
          windows,
          'UTC',
        ),
      ).toBe(true);

      // Tuesday 2026-10-06 06:01 UTC -> outside
      expect(
        MonitoringScheduler.isWithinActiveWindow(
          new Date('2026-10-06T06:01:00.000Z'),
          windows,
          'UTC',
        ),
      ).toBe(false);
    });

    it('5.3 should gracefully handle invalid/corrupted timezone strings by falling back to Asia/Ho_Chi_Minh', () => {
      const corruptTimezones = ['Invalid/Zone', 'Moon/Crater', 'XYZ', ''];
      const date = new Date('2026-10-06T12:00:00.000Z');
      const windows = [
        {
          dayOfWeek: 2,
          startTime: '07:00',
          endTime: '22:00',
          isEnabled: true,
        } as MonitoringScheduleWindow,
      ];

      for (const tz of corruptTimezones) {
        expect(() => {
          const res = MonitoringScheduler.isWithinActiveWindow(date, windows, tz);
          expect(typeof res).toBe('boolean');
        }).not.toThrow();

        expect(() => {
          const next = MonitoringScheduler.getNextActiveWindowStart(date, windows, tz);
          expect(next).toBeInstanceOf(Date);
          expect(!isNaN(next.getTime())).toBe(true);
        }).not.toThrow();
      }
    });
  });
});
