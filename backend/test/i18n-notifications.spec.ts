import { describe, it, expect, vi, beforeEach } from 'vitest';
import * as bcrypt from 'bcrypt';
import { NotificationsService } from '../src/modules/notifications/notifications.service';
import { NotificationTemplateService } from '../src/modules/notifications/notification-template.service';
import { UsersService } from '../src/modules/users/users.service';
import { AuthService } from '../src/modules/auth/auth.service';
import {
  NotificationChannelType,
  NotificationDeliveryStatus,
} from '../src/common/enums';

describe('i18n Notifications & Backend User Language (Ext-M1)', () => {
  let notificationsService: NotificationsService;
  let templateService: NotificationTemplateService;
  let deliveryRepo: any;
  let deviceRepo: any;
  let userRepo: any;
  let fcmChannel: any;
  let smsChannel: any;
  let telegramChannel: any;

  beforeEach(() => {
    deliveryRepo = {
      create: vi.fn((dto) => ({
        ...dto,
        id: 'del-uuid',
        attemptCount: dto.attemptCount || 0,
        maxAttempts: 3,
      })),
      save: vi.fn((entity) => Promise.resolve({ ...entity })),
      find: vi.fn(),
    };
    deviceRepo = {
      find: vi.fn(),
    };
    userRepo = {
      findOne: vi.fn(),
      create: vi.fn((dto) => ({ ...dto, id: 'user-uuid' })),
      save: vi.fn((entity) => Promise.resolve({ ...entity })),
      softRemove: vi.fn(),
    };
    fcmChannel = {
      send: vi.fn(),
    };
    smsChannel = {
      send: vi.fn(),
    };
    telegramChannel = {
      send: vi.fn(),
    };
    templateService = new NotificationTemplateService();

    notificationsService = new NotificationsService(
      deliveryRepo,
      deviceRepo,
      userRepo,
      fcmChannel,
      smsChannel,
      telegramChannel,
      templateService,
    );
  });

  describe('User Profile & Auth Language Handling', () => {
    it('1. should register user with preferredLanguage default to vi if omitted', async () => {
      const jwtService: any = { sign: vi.fn().mockReturnValue('jwt-token') };
      const configService: any = { get: vi.fn().mockReturnValue('secret') };
      const authService = new AuthService(userRepo, jwtService, configService);

      const result = await authService.register({
        email: 'test@carely.app',
        password: 'password123',
        displayName: 'Test User',
      });

      expect(userRepo.create).toHaveBeenCalledWith(
        expect.objectContaining({
          preferredLanguage: 'vi',
        }),
      );
      expect(result.user.preferredLanguage).toBe('vi');
    });

    it('2. should register user with explicit preferredLanguage normalized to lowercase', async () => {
      const jwtService: any = { sign: vi.fn().mockReturnValue('jwt-token') };
      const configService: any = { get: vi.fn().mockReturnValue('secret') };
      const authService = new AuthService(userRepo, jwtService, configService);

      const result = await authService.register({
        email: 'global@carely.app',
        password: 'password123',
        displayName: 'Global User',
        preferredLanguage: 'JA',
      });

      expect(userRepo.create).toHaveBeenCalledWith(
        expect.objectContaining({
          preferredLanguage: 'ja',
        }),
      );
      expect(result.user.preferredLanguage).toBe('ja');
    });

    it('2b. should login user and return preferredLanguage from DB', async () => {
      const jwtService: any = { sign: vi.fn().mockReturnValue('jwt-token') };
      const redisService: any = { get: vi.fn(), set: vi.fn(), del: vi.fn() };
      const firebaseVerifier: any = {};
      const authService = new AuthService(userRepo, jwtService, redisService, firebaseVerifier);

      const fakeUser = {
        id: 'u-login',
        email: 'login@carely.app',
        passwordHash: await bcrypt.hash('password123', 10),
        displayName: 'Login User',
        timezone: 'Asia/Ho_Chi_Minh',
        phoneNumber: '+84912345678',
        preferredLanguage: 'de',
        authProvider: 'LOCAL',
      };

      const qb: any = {
        addSelect: vi.fn().mockReturnThis(),
        where: vi.fn().mockReturnThis(),
        getOne: vi.fn().mockResolvedValue(fakeUser),
      };
      userRepo.createQueryBuilder = vi.fn().mockReturnValue(qb);

      const result = await authService.login({
        email: 'login@carely.app',
        password: 'password123',
      });

      expect(result.user.preferredLanguage).toBe('de');
      expect(result.user.id).toBe('u-login');
      expect(result.accessToken).toBe('jwt-token');
    });

    it('3. should update user preferredLanguage via UsersService.updateProfile', async () => {
      const usersService = new UsersService(userRepo);
      const existingUser = {
        id: 'u-1',
        email: 'user1@carely.app',
        displayName: 'User One',
        preferredLanguage: 'vi',
      };
      userRepo.findOne.mockResolvedValue(existingUser);

      const updated = await usersService.updateProfile('u-1', {
        preferredLanguage: 'FR',
      });

      expect(updated.preferredLanguage).toBe('fr');
      expect(userRepo.save).toHaveBeenCalledWith(
        expect.objectContaining({
          preferredLanguage: 'fr',
        }),
      );
    });
  });

  describe('Localized Notification Dispatch', () => {
    it('4. should dispatch localized push in English when recipient preferredLanguage is en', async () => {
      userRepo.findOne.mockResolvedValue({
        id: 'user-en',
        preferredLanguage: 'en',
      });
      deviceRepo.find.mockResolvedValue([
        { id: 'dev-en', userId: 'user-en', isActive: true, pushToken: 'push-token-en' },
      ]);
      fcmChannel.send.mockResolvedValue({ success: true, messageId: 'msg-en' });

      const deliveries = await notificationsService.sendNotification({
        recipientUserId: 'user-en',
        templateName: 'CHECK_IN_PROMPT',
      });

      expect(deliveries).toHaveLength(1);
      expect(deliveries[0].payload.title).toBe('Evernear — Are you doing okay?');
      expect(deliveries[0].payload.body).toContain('Tap to confirm you are okay');
      expect(fcmChannel.send).toHaveBeenCalledWith(
        expect.objectContaining({
          title: 'Evernear — Are you doing okay?',
        }),
      );
    });

    it('5. should dispatch localized push in Japanese when recipient preferredLanguage is ja', async () => {
      userRepo.findOne.mockResolvedValue({
        id: 'user-ja',
        preferredLanguage: 'ja',
      });
      deviceRepo.find.mockResolvedValue([
        { id: 'dev-ja', userId: 'user-ja', isActive: true, pushToken: 'push-token-ja' },
      ]);
      fcmChannel.send.mockResolvedValue({ success: true, messageId: 'msg-ja' });

      const deliveries = await notificationsService.sendNotification({
        recipientUserId: 'user-ja',
        templateName: 'CHECK_IN_PROMPT',
      });

      expect(deliveries).toHaveLength(1);
      expect(deliveries[0].payload.title).toBe('Evernear — 大丈夫ですか？');
      expect(deliveries[0].payload.body).toContain('タップして無事を確認してください');
    });

    it('6. should override recipient preferredLanguage when explicit language param is provided', async () => {
      userRepo.findOne.mockResolvedValue({
        id: 'user-override',
        preferredLanguage: 'vi',
      });
      deviceRepo.find.mockResolvedValue([
        { id: 'dev-1', userId: 'user-override', isActive: true, pushToken: 'push-token' },
      ]);
      fcmChannel.send.mockResolvedValue({ success: true, messageId: 'msg-1' });

      const deliveries = await notificationsService.sendNotification({
        recipientUserId: 'user-override',
        templateName: 'CHECK_IN_PROMPT',
        language: 'de',
      });

      expect(deliveries).toHaveLength(1);
      expect(deliveries[0].payload.title).toBe('Evernear — Geht es Ihnen gut?');
      expect(deliveries[0].payload.body).toContain('Tippen Sie hier');
    });

    it('7. should dispatch localized SMS in Spanish when SMS channel is chosen', async () => {
      userRepo.findOne.mockResolvedValue({
        id: 'user-es',
        preferredLanguage: 'es',
        phoneNumber: '+34612345678',
      });
      smsChannel.send.mockResolvedValue({ success: true, messageId: 'sms-es' });

      const deliveries = await notificationsService.sendNotification({
        recipientUserId: 'user-es',
        templateName: 'MONITOR_INACTIVITY_WARNING',
        channel: NotificationChannelType.SMS,
      });

      expect(deliveries).toHaveLength(1);
      expect(deliveries[0].payload.title).toBe('Evernear — Aviso de atención');
      expect(deliveries[0].payload.body).toContain('No se ha registrado actividad o respuesta');
    });

    it('8. should safely fall back to English then Vietnamese for rare/unknown recipient language', async () => {
      userRepo.findOne.mockResolvedValue({
        id: 'user-unknown',
        preferredLanguage: 'xx',
      });
      deviceRepo.find.mockResolvedValue([
        { id: 'dev-1', userId: 'user-unknown', isActive: true, pushToken: 'push-token' },
      ]);
      fcmChannel.send.mockResolvedValue({ success: true, messageId: 'msg-1' });

      const deliveries = await notificationsService.sendNotification({
        recipientUserId: 'user-unknown',
        templateName: 'CHECK_IN_PROMPT',
      });

      expect(deliveries).toHaveLength(1);
      expect(deliveries[0].payload.title).toBe('Evernear — Are you doing okay?');
    });

    it('9. should cascade to localized SMS using recipient user record from DB when explicit language override is provided and FCM has no active devices', async () => {
      userRepo.findOne.mockResolvedValue({
        id: 'user-override-cascade',
        preferredLanguage: 'vi',
        phoneNumber: '+84912345678',
      });
      deviceRepo.find.mockResolvedValue([]); // No devices -> trigger cascade
      smsChannel.send.mockResolvedValue({ success: true, messageId: 'sms-cascaded-de' });

      const deliveries = await notificationsService.sendNotification({
        recipientUserId: 'user-override-cascade',
        templateName: 'CHECK_IN_PROMPT',
        language: 'de',
      });

      expect(deliveries).toHaveLength(2);
      expect(deliveries[0].channel).toBe(NotificationChannelType.FCM);
      expect(deliveries[0].status).toBe(NotificationDeliveryStatus.FAILED);

      expect(deliveries[1].channel).toBe(NotificationChannelType.SMS);
      expect(deliveries[1].status).toBe(NotificationDeliveryStatus.SENT);
      expect(deliveries[1].recipientTarget).toBe('+84912345678');
      expect(deliveries[1].payload.title).toBe('Evernear — Geht es Ihnen gut?');
      expect(deliveries[1].payload.body).toContain('Tippen Sie hier');
      expect(smsChannel.send).toHaveBeenCalled();
    });
  });
});
