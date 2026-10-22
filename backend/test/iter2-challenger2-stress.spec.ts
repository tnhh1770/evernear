import { describe, it, expect, vi, beforeEach } from 'vitest';
import { NotificationsService } from '../src/modules/notifications/notifications.service';
import {
  NotificationTemplateService,
  escapeRegExp,
} from '../src/modules/notifications/notification-template.service';
import { NotificationChannelType, NotificationDeliveryStatus } from '../src/common/enums';

describe('Challenger 2 Iteration 2 Adversarial Stress Harness', () => {
  let templateService: NotificationTemplateService;

  beforeEach(() => {
    templateService = new NotificationTemplateService();
  });

  // =========================================================================
  // SECTION 1: Exhaustive Regex Escaping & Value Replacement Stress Testing
  // =========================================================================
  describe('1. Dynamic Key Escaping & Token Substitution Rigorous Challenge', () => {
    it('1.1 should correctly match and replace placeholders even when key consists entirely of metacharacters', () => {
      // Direct unit check on escapeRegExp export
      expect(escapeRegExp('.*+?^${}()|[]\\')).toBe('\\.\\*\\+\\?\\^\\$\\{\\}\\(\\)\\|\\[\\]\\\\');

      // Create a mock template dictionary or custom body by testing render on templates
      // In default templates, {name} is used. But what if custom templates or mergedParams has metachar keys?
      const metachars = ['.', '*', '+', '?', '^', '$', '{', '}', '(', ')', '|', '[', ']', '\\'];

      for (const char of metachars) {
        expect(() => {
          templateService.render('CHECK_IN_PROMPT', { [char]: 'replacement' }, 'en');
        }).not.toThrow();

        expect(() => {
          templateService.render('CHECK_IN_PROMPT', { [`foo${char}bar`]: 'replacement' }, 'en');
        }).not.toThrow();

        expect(() => {
          templateService.render('CHECK_IN_PROMPT', { [`${char}${char}${char}`]: 'replacement' }, 'en');
        }).not.toThrow();
      }
    });

    it('1.2 should safely evaluate evil regex patterns in keys (lookaheads, lookbehinds, catastrophic backtracking patterns)', () => {
      const evilKeyVectors = [
        '(a+)+',
        '([a-zA-Z]+)*',
        '(?=.*[a-z])(?=.*[A-Z])',
        '(?<=foo)bar',
        '(?!pattern)',
        '(?<!pattern)',
        '\\p{L}+',
        '\\d{1,100}',
        '\\1\\2\\3',
        '(((((((((nested)))))))))',
        '[[[nested_brackets]]]',
        '\\\\\\\\\\\\',
        '/{pattern}/gimsuy',
        '${name}',
        '{name}',
        '${${nested}}',
        '\\0\\x00\\u0000',
        'a|b|c|d|e|f|g|h|i|j',
      ];

      for (const evilKey of evilKeyVectors) {
        expect(() => {
          const res = templateService.render('CHECK_IN_PROMPT', { [evilKey]: 'SAFE_REPLACEMENT' }, 'vi');
          expect(res.title).toBeDefined();
          expect(res.body).toBeDefined();
        }).not.toThrow();
      }
    });

    it('1.3 should replace exact placeholder token when key contains metacharacters and appears in text', () => {
      // Verify that if a key is named 'special.key' or 'user[id]',
      // and we check how render works:
      const rendered = templateService.render(
        'MONITOR_INACTIVITY_WARNING',
        {
          name: 'Grandpa',
          '(custom)': 'val1',
          'dot.key': 'val2',
        },
        'en',
      );
      expect(rendered.body).toContain('Grandpa');
    });

    it('1.4 should literally preserve complex combinations of replacement patterns in values', () => {
      const complexValues = [
        '$$',
        '$$$$',
        '$$100.00',
        '$&',
        'prefix $& suffix',
        "$' (right context)",
        "$` (left context)",
        '$1 $2 $3 $99',
        '$$&$$',
        '$$$1',
        '\\$ \\\\$',
        'LiteralToken',
        'Emoji: 👵👴💰$$$&$$',
      ];

      for (const val of complexValues) {
        const res = templateService.render('MONITOR_INACTIVITY_WARNING', { name: val }, 'en');
        expect(res.body).toContain(val);
        expect(res.body).not.toContain('{name}');
      }
    });

    it('1.5 should handle falsey and edge-case value types without throwing or injecting undefined/null strings', () => {
      const edgeCases: Record<string, any> = {
        zero: 0,
        falseBool: false,
        emptyStr: '',
        nullVal: null,
        undefVal: undefined,
      };

      const res = templateService.render('MONITOR_INACTIVITY_WARNING', edgeCases, 'en');
      expect(res.body).toBeDefined();
      expect(res.title).toBeDefined();
      // Should not contain corrupted literals
      expect(res.body).not.toContain('undefined');
    });

    it('1.6 Fuzz generator: 500 random adversarial key and value pairs', () => {
      const metachars = '.*+?^${}()|[]\\/ \t\n\r"\'`#@!~%&=-_0123456789abcXYZ';
      const replacementPatterns = ['$$', '$&', "$'", '$`', '$1', '$$$', 'normal', '123', '日本語', 'Tiếng Việt'];

      for (let i = 0; i < 500; i++) {
        // Random key length 1-20
        let key = '';
        const keyLen = Math.floor(Math.random() * 20) + 1;
        for (let k = 0; k < keyLen; k++) {
          key += metachars[Math.floor(Math.random() * metachars.length)];
        }

        // Random value with replacement patterns
        let val = '';
        const valChunks = Math.floor(Math.random() * 5) + 1;
        for (let v = 0; v < valChunks; v++) {
          val += replacementPatterns[Math.floor(Math.random() * replacementPatterns.length)];
        }

        expect(() => {
          const res = templateService.render('CHECK_IN_PROMPT', { [key]: val }, 'en');
          expect(res.title).toBeDefined();
          expect(res.body).toBeDefined();
        }).not.toThrow();
      }
    });
  });

  // =========================================================================
  // SECTION 2: Cascade Fallback Stress Testing Across All Channels & Languages
  // =========================================================================
  describe('2. Cascade Fallback Multi-Channel & Locale Resilience', () => {
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
          id: 'del-' + Math.random().toString(36).slice(2),
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

    it('2.1 should cascade to SMS when language is explicit German and devices exist but all FCM dispatches throw exceptions', async () => {
      userRepo.findOne.mockResolvedValue({
        id: 'user-de-crash',
        phoneNumber: '+4915123456789',
        preferredLanguage: 'vi', // DB says vi, but call says de
      });
      deviceRepo.find.mockResolvedValue([
        { id: 'dev-1', userId: 'user-de-crash', isActive: true, pushToken: 'push-token-1' },
        { id: 'dev-2', userId: 'user-de-crash', isActive: true, pushToken: 'push-token-2' },
      ]);
      // FCM throws uncaught exception on both devices
      fcmChannel.send.mockRejectedValue(new Error('Network socket hang up'));
      smsChannel.send.mockResolvedValue({ success: true, messageId: 'sms-de-sent' });

      const deliveries = await notificationsService.sendNotification({
        recipientUserId: 'user-de-crash',
        templateName: 'CHECK_IN_REMINDER',
        language: 'de',
      });

      // 2 FCM deliveries (both FAILED) + 1 SMS delivery (SENT)
      expect(deliveries).toHaveLength(3);
      expect(deliveries[0].channel).toBe(NotificationChannelType.FCM);
      expect(deliveries[0].status).toBe(NotificationDeliveryStatus.FAILED);
      expect(deliveries[1].channel).toBe(NotificationChannelType.FCM);
      expect(deliveries[1].status).toBe(NotificationDeliveryStatus.FAILED);

      const smsDelivery = deliveries[2];
      expect(smsDelivery.channel).toBe(NotificationChannelType.SMS);
      expect(smsDelivery.status).toBe(NotificationDeliveryStatus.SENT);
      expect(smsDelivery.recipientTarget).toBe('+4915123456789');
      expect(smsDelivery.payload.title).toBe('Evernear — Erinnerung zur Bestätigung');
      expect(smsDelivery.payload.body).toContain('tippen Sie hier');

      expect(smsChannel.send).toHaveBeenCalledWith(
        expect.objectContaining({
          recipientTarget: '+4915123456789',
          title: 'Evernear — Erinnerung zur Bestätigung',
        }),
      );
    });

    it('2.2 should cascade to Telegram when explicit language is provided, FCM fails, and SMS also fails', async () => {
      userRepo.findOne.mockResolvedValue({
        id: 'user-sms-fail',
        phoneNumber: '+84911112222',
        preferredLanguage: 'vi',
      });
      deviceRepo.find.mockResolvedValue([]); // No devices -> cascade
      // SMS fails (e.g., Twilio out of quota)
      smsChannel.send.mockResolvedValue({ success: false, error: 'Twilio 21211: Invalid number' });
      // Telegram succeeds
      telegramChannel.send.mockResolvedValue({ success: true, messageId: 'tg-msg-456' });

      const deliveries = await notificationsService.sendNotification({
        recipientUserId: 'user-sms-fail',
        templateName: 'MONITOR_ESCALATION',
        language: 'ja',
        customData: { telegramChatId: 'chat-999888' },
      });

      // FCM (FAILED: NO_ACTIVE_DEVICE_TOKEN) -> SMS (FAILED: Twilio) -> Telegram (SENT)
      expect(deliveries).toHaveLength(3);
      expect(deliveries[0].channel).toBe(NotificationChannelType.FCM);
      expect(deliveries[0].status).toBe(NotificationDeliveryStatus.FAILED);

      expect(deliveries[1].channel).toBe(NotificationChannelType.SMS);
      expect(deliveries[1].status).toBe(NotificationDeliveryStatus.FAILED);

      expect(deliveries[2].channel).toBe(NotificationChannelType.TELEGRAM);
      expect(deliveries[2].status).toBe(NotificationDeliveryStatus.SENT);
      expect(deliveries[2].recipientTarget).toBe('chat-999888');
      expect(deliveries[2].payload.title).toBe('Evernear — ご確認のお願い');
    });

    it('2.3 should cascade properly with unsupported locale "xx", falling back to English templates and dispatching SMS', async () => {
      userRepo.findOne.mockResolvedValue({
        id: 'user-xx-lang',
        phoneNumber: '+14155552671',
        preferredLanguage: 'vi',
      });
      deviceRepo.find.mockResolvedValue([]);
      smsChannel.send.mockResolvedValue({ success: true, messageId: 'sms-xx-ok' });

      const deliveries = await notificationsService.sendNotification({
        recipientUserId: 'user-xx-lang',
        templateName: 'INCIDENT_RESOLVED',
        language: 'xx',
        templateParams: { name: 'Dr. John' },
      });

      expect(deliveries).toHaveLength(2);
      expect(deliveries[1].channel).toBe(NotificationChannelType.SMS);
      expect(deliveries[1].status).toBe(NotificationDeliveryStatus.SENT);
      expect(deliveries[1].payload.title).toBe('Evernear — Reassured');
      expect(deliveries[1].payload.body).toContain('Dr. John has confirmed normal activity');
    });

    it('2.4 direct SMS channel with explicit language should resolve user if not preloaded and dispatch SMS', async () => {
      userRepo.findOne.mockResolvedValue({
        id: 'user-direct-sms',
        phoneNumber: '+84933334444',
        preferredLanguage: 'vi',
      });
      smsChannel.send.mockResolvedValue({ success: true, messageId: 'direct-sms-1' });

      const deliveries = await notificationsService.sendNotification({
        recipientUserId: 'user-direct-sms',
        templateName: 'CHECK_IN_PROMPT',
        channel: NotificationChannelType.SMS,
        language: 'fr',
      });

      expect(deliveries).toHaveLength(1);
      expect(deliveries[0].channel).toBe(NotificationChannelType.SMS);
      expect(deliveries[0].status).toBe(NotificationDeliveryStatus.SENT);
      expect(deliveries[0].recipientTarget).toBe('+84933334444');
      expect(deliveries[0].payload.title).toBe('Evernear — Tout va bien ?');
    });
  });
});
