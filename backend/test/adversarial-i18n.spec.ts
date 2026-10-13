import { describe, it, expect, vi, beforeEach } from 'vitest';
import { NotificationsService } from '../src/modules/notifications/notifications.service';
import { NotificationTemplateService } from '../src/modules/notifications/notification-template.service';
import { NotificationChannelType, NotificationDeliveryStatus } from '../src/common/enums';

describe('Adversarial Backend i18n Stress Harness (Challenger 2)', () => {
  let templateService: NotificationTemplateService;

  beforeEach(() => {
    templateService = new NotificationTemplateService();
  });

  // =========================================================================
  // SUITE 1: NotificationTemplateService Stress Testing
  // =========================================================================
  describe('NotificationTemplateService Adversarial Tests', () => {
    it('1.1 should safely handle unknown template names and fall back to default template in requested language if supported', () => {
      // In German
      const resDe = templateService.render('UNKNOWN_EVENT_123', {}, 'de');
      expect(resDe.title).toBe('Carely');
      expect(resDe.body).toBe('Neue Benachrichtigung aus dem Carely-System.');

      // In French
      const resFr = templateService.render('ANOTHER_NON_EXISTENT', {}, 'fr');
      expect(resFr.title).toBe('Carely');
      expect(resFr.body).toBe('Nouvelle notification du système de suivi Carely.');

      // In Vietnamese
      const resVi = templateService.render('RANDOM_FOO_BAR', {}, 'vi');
      expect(resVi.title).toBe('Carely');
      expect(resVi.body).toBe('Thông báo mới từ hệ thống chăm sóc Carely.');
    });

    it('1.2 should fall back to English default template when template name is unknown AND locale is unsupported', () => {
      const resXx = templateService.render('UNKNOWN_EVENT', {}, 'xx');
      expect(resXx.title).toBe('Carely');
      expect(resXx.body).toBe('New notification from Carely care system.');

      const resInvalid = templateService.render('MYSTERY_CODE', {}, 'invalid-locale-xyz');
      expect(resInvalid.title).toBe('Carely');
      expect(resInvalid.body).toBe('New notification from Carely care system.');
    });

    it('1.3 should safely handle edge-case locale formats (empty string, null, undefined, mixed case, regional subtags)', () => {
      // Empty string
      const resEmpty = templateService.render('CHECK_IN_PROMPT', {}, '');
      expect(resEmpty.title).toBe('Carely — Bạn vẫn ổn chứ?');

      // Null or undefined cast
      const resNull = templateService.render('CHECK_IN_PROMPT', {}, null as any);
      expect(resNull.title).toBe('Carely — Bạn vẫn ổn chứ?');

      const resUndef = templateService.render('CHECK_IN_PROMPT', {}, undefined);
      expect(resUndef.title).toBe('Carely — Bạn vẫn ổn chứ?');

      // Uppercase regional codes
      const resUS = templateService.render('CHECK_IN_PROMPT', {}, 'EN-US');
      expect(resUS.title).toBe('Carely — Are you doing okay?');

      const resBR = templateService.render('CHECK_IN_PROMPT', {}, 'pt_BR');
      expect(resBR.title).toBe('Carely — Está tudo bem?');

      const resES = templateService.render('CHECK_IN_PROMPT', {}, 'es-419');
      expect(resES.title).toBe('Carely — ¿Todo va bien?');
    });

    it('1.4 should handle empty, undefined, or missing parameter maps without crashing', () => {
      const resDefault = templateService.render('MONITOR_INACTIVITY_WARNING');
      expect(resDefault.body).toContain('Người thân');

      const resEmptyMap = templateService.render('MONITOR_INACTIVITY_WARNING', {});
      expect(resEmptyMap.body).toContain('Người thân');

      const resEnEmptyMap = templateService.render('MONITOR_INACTIVITY_WARNING', {}, 'en');
      expect(resEnEmptyMap.body).toContain('Loved one');

      const resJaEmptyMap = templateService.render('MONITOR_INACTIVITY_WARNING', {}, 'ja');
      expect(resJaEmptyMap.body).toContain('ご家族');

      const resArEmptyMap = templateService.render('MONITOR_INACTIVITY_WARNING', {}, 'ar');
      expect(resArEmptyMap.body).toContain('القريب');
    });

    it('1.5 should handle special character parameter values (emojis, unicode, HTML tags, quotes, newlines)', () => {
      const specialValues = {
        name: '👵 Cụ Lê Thị Hoa (95t) & <script>alert("xss")</script> 🚀',
      };
      const res = templateService.render('INCIDENT_RESOLVED', specialValues, 'vi');
      expect(res.body).toContain('👵 Cụ Lê Thị Hoa (95t) & <script>alert("xss")</script> 🚀');
      expect(res.body).toContain('đã xác nhận hoạt động bình thường');

      // Arabic name
      const resAr = templateService.render('INCIDENT_RESOLVED', { name: 'الجدة فاطمة' }, 'ar');
      expect(resAr.body).toContain('الجدة فاطمة');

      // Japanese name
      const resJa = templateService.render('INCIDENT_RESOLVED', { name: '山本 太郎' }, 'ja');
      expect(resJa.body).toContain('山本 太郎 様');
    });

    it('1.6 [VERIFIED] special replacement tokens ($$, $&, $`, $\') in parameter values are preserved literally', () => {
      const resDollar = templateService.render('MONITOR_INACTIVITY_WARNING', { name: '$$100' }, 'en');
      // Replacer function guarantees '$$100' does not collapse to '$100'
      expect(resDollar.body).toContain('$$100');

      const resAmp = templateService.render('MONITOR_INACTIVITY_WARNING', { name: '$&' }, 'en');
      // Replacer function guarantees '$&' is not replaced with the matched pattern '{name}'
      expect(resAmp.body).toContain('$&');
      expect(resAmp.body).not.toContain('{name}');

      const resQuote = templateService.render('MONITOR_INACTIVITY_WARNING', { name: "test$'end" }, 'en');
      expect(resQuote.body).toContain("test$'end");
    });

    it('1.7 [VERIFIED] regex metacharacters in parameter keys are safely escaped without throwing SyntaxError', () => {
      const evilKeys = {
        '(evil)': 'bad',
        'foo(?bar)': 'group',
        '[bracket]': 'bracketed',
        'dot.*star': 'wildcard',
        'plus+': 'plus',
      };

      expect(() => {
        const res = templateService.render('CHECK_IN_PROMPT', evilKeys, 'vi');
        expect(res.title).toBeDefined();
        expect(res.body).toBeDefined();
      }).not.toThrow();
    });
  });

  // =========================================================================
  // SUITE 2: NotificationsService Adversarial Language Resolution & Cascading
  // =========================================================================
  describe('NotificationsService Recipient Language Resolution & Dispatch', () => {
    let notificationsService: NotificationsService;
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
          id: 'del-uuid-' + Math.random(),
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
      };
      fcmChannel = { send: vi.fn() };
      smsChannel = { send: vi.fn() };
      telegramChannel = { send: vi.fn() };

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

    it('2.1 should resolve default "vi" when recipient user does not exist in repository', async () => {
      userRepo.findOne.mockResolvedValue(null);
      deviceRepo.find.mockResolvedValue([]);
      smsChannel.send.mockResolvedValue({ success: true, messageId: 'sms-1' });

      const deliveries = await notificationsService.sendNotification({
        recipientUserId: 'non-existent-user-id',
        templateName: 'CHECK_IN_PROMPT',
      });

      // FCM fails (no devices) -> cascades to SMS (no phone) -> Telegram (recipientUserId target)
      expect(userRepo.findOne).toHaveBeenCalledWith({ where: { id: 'non-existent-user-id' } });
      const fcmDelivery = deliveries.find((d) => d.channel === NotificationChannelType.FCM);
      expect(fcmDelivery?.payload.title).toBe('Carely — Bạn vẫn ổn chứ?');
    });

    it('2.2 should resolve default "vi" when user has preferredLanguage as null or undefined', async () => {
      userRepo.findOne.mockResolvedValue({
        id: 'u-null-lang',
        preferredLanguage: null,
        phoneNumber: '+84912345678',
      });
      deviceRepo.find.mockResolvedValue([
        { id: 'dev-1', userId: 'u-null-lang', isActive: true, pushToken: 'push-token' },
      ]);
      fcmChannel.send.mockResolvedValue({ success: true, messageId: 'fcm-1' });

      const deliveries = await notificationsService.sendNotification({
        recipientUserId: 'u-null-lang',
        templateName: 'CHECK_IN_PROMPT',
      });

      expect(deliveries[0].payload.title).toBe('Carely — Bạn vẫn ổn chứ?');
      expect(deliveries[0].payload.body).toContain('Hệ thống chưa nhận thấy hoạt động mới');
    });

    it('2.3 should honor explicit language override even if user preferredLanguage is different', async () => {
      userRepo.findOne.mockResolvedValue({
        id: 'u-fr',
        preferredLanguage: 'vi',
      });
      deviceRepo.find.mockResolvedValue([
        { id: 'dev-1', userId: 'u-fr', isActive: true, pushToken: 'push-token' },
      ]);
      fcmChannel.send.mockResolvedValue({ success: true, messageId: 'fcm-1' });

      const deliveries = await notificationsService.sendNotification({
        recipientUserId: 'u-fr',
        templateName: 'CHECK_IN_PROMPT',
        language: 'fr',
      });

      expect(deliveries[0].payload.title).toBe('Carely — Tout va bien ?');
    });

    it('2.4 [VERIFIED] cascadeFallback dispatches SMS & Telegram when explicit language is provided', async () => {
      // Scenario:
      // A user with a registered phone number in DB needs a notification with an explicit language override (e.g. language: 'en').
      // FCM has no active devices (or FCM push fails), which should automatically cascade to SMS fallback.
      userRepo.findOne.mockResolvedValue({
        id: 'user-with-phone',
        phoneNumber: '+84988776655',
        preferredLanguage: 'vi',
      });
      deviceRepo.find.mockResolvedValue([]); // No devices -> triggers cascadeFallback
      smsChannel.send.mockResolvedValue({ success: true, messageId: 'sms-success' });

      const deliveries = await notificationsService.sendNotification({
        recipientUserId: 'user-with-phone',
        templateName: 'MONITOR_INACTIVITY_WARNING',
        language: 'en',
      });

      // Verify user lookup was performed because preloadedUser was null
      expect(userRepo.findOne).toHaveBeenCalledWith({
        where: { id: 'user-with-phone' },
      });

      // Verify SMS delivery record and dispatch
      const smsDelivery = deliveries.find((d) => d.channel === NotificationChannelType.SMS);
      expect(smsDelivery).toBeDefined();
      expect(smsDelivery!.channel).toBe(NotificationChannelType.SMS);
      expect(smsDelivery!.status).toBe(NotificationDeliveryStatus.SENT);
      expect(smsDelivery!.recipientTarget).toBe('+84988776655');
      expect(smsDelivery!.payload.title).toBe('Carely — Care Notice');

      expect(smsChannel.send).toHaveBeenCalledWith(
        expect.objectContaining({
          recipientTarget: '+84988776655',
          title: 'Carely — Care Notice',
        }),
      );
    });

    it('2.5 [VERIFIED] cascadeFallback after FCM push failure dispatches SMS when explicit language is provided', async () => {
      // Scenario:
      // User has an active device, but FCM push fails (network timeout).
      // Cascade fallback should then kick in to SMS.
      userRepo.findOne.mockResolvedValue({
        id: 'user-with-device-and-phone',
        phoneNumber: '+84988776655',
        preferredLanguage: 'vi',
      });
      deviceRepo.find.mockResolvedValue([
        { id: 'dev-1', userId: 'user-with-device-and-phone', isActive: true, pushToken: 'bad-token' },
      ]);
      fcmChannel.send.mockResolvedValue({ success: false, error: 'FCM 500 Server Error' });
      smsChannel.send.mockResolvedValue({ success: true, messageId: 'sms-ok' });

      const deliveries = await notificationsService.sendNotification({
        recipientUserId: 'user-with-device-and-phone',
        templateName: 'MONITOR_ESCALATION',
        language: 'ja',
      });

      expect(userRepo.findOne).toHaveBeenCalledWith({
        where: { id: 'user-with-device-and-phone' },
      });

      const fcmDelivery = deliveries.find((d) => d.channel === NotificationChannelType.FCM);
      expect(fcmDelivery!.status).toBe(NotificationDeliveryStatus.FAILED);

      const smsDelivery = deliveries.find((d) => d.channel === NotificationChannelType.SMS);
      expect(smsDelivery).toBeDefined();
      expect(smsDelivery!.channel).toBe(NotificationChannelType.SMS);
      expect(smsDelivery!.status).toBe(NotificationDeliveryStatus.SENT);
      expect(smsDelivery!.recipientTarget).toBe('+84988776655');
      expect(smsDelivery!.payload.title).toBe('Carely — ご確認のお願い');

      expect(smsChannel.send).toHaveBeenCalled();
    });
  });
});
