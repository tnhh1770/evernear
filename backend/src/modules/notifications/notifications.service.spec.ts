import { describe, it, expect, vi, beforeEach } from 'vitest';
import { NotificationsService } from './notifications.service';
import { NotificationTemplateService } from './notification-template.service';
import {
  NotificationChannelType,
  NotificationDeliveryStatus,
} from '../../common/enums';

describe('NotificationsService (Unit Tests)', () => {
  let service: NotificationsService;
  let deliveryRepo: any;
  let deviceRepo: any;
  let userRepo: any;
  let fcmChannel: any;
  let smsChannel: any;
  let telegramChannel: any;
  let templateService: NotificationTemplateService;

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

    service = new NotificationsService(
      deliveryRepo,
      deviceRepo,
      userRepo,
      fcmChannel,
      smsChannel,
      telegramChannel,
      templateService,
    );
  });

  it('1. should deliver FCM push when user has active devices with token', async () => {
    deviceRepo.find.mockResolvedValue([
      { id: 'dev-1', userId: 'user-1', isActive: true, pushToken: 'token-abc' },
    ]);
    fcmChannel.send.mockResolvedValue({ success: true, messageId: 'msg-1' });

    const deliveries = await service.sendNotification({
      recipientUserId: 'user-1',
      templateName: 'CHECK_IN_PROMPT',
    });

    expect(deliveries).toHaveLength(1);
    expect(deliveries[0].channel).toBe(NotificationChannelType.FCM);
    expect(deliveries[0].status).toBe(NotificationDeliveryStatus.SENT);
    expect(fcmChannel.send).toHaveBeenCalledWith(
      expect.objectContaining({ recipientTarget: 'token-abc' }),
    );
    expect(smsChannel.send).not.toHaveBeenCalled();
  });

  it('2. should cascade to SMS when user has no active devices with token', async () => {
    deviceRepo.find.mockResolvedValue([]);
    userRepo.findOne.mockResolvedValue({
      id: 'user-1',
      phoneNumber: '+84912345678',
    });
    smsChannel.send.mockResolvedValue({ success: true, messageId: 'sms-1' });

    const deliveries = await service.sendNotification({
      recipientUserId: 'user-1',
      templateName: 'CHECK_IN_PROMPT',
    });

    expect(deliveries).toHaveLength(2);
    // First record: failed FCM audit
    expect(deliveries[0].channel).toBe(NotificationChannelType.FCM);
    expect(deliveries[0].status).toBe(NotificationDeliveryStatus.FAILED);
    // Second record: successful SMS fallback
    expect(deliveries[1].channel).toBe(NotificationChannelType.SMS);
    expect(deliveries[1].status).toBe(NotificationDeliveryStatus.SENT);
    expect(deliveries[1].recipientTarget).toBe('+84912345678');
    expect(smsChannel.send).toHaveBeenCalled();
  });

  it('3. should cascade to Telegram when user has no device tokens and no phone number', async () => {
    deviceRepo.find.mockResolvedValue([]);
    userRepo.findOne.mockResolvedValue({
      id: 'user-1',
      phoneNumber: null,
    });
    telegramChannel.send.mockResolvedValue({ success: true, messageId: 'tg-1' });

    const deliveries = await service.sendNotification({
      recipientUserId: 'user-1',
      templateName: 'MONITOR_ESCALATION',
      customData: { telegramChatId: 'tg-123456' },
    });

    expect(deliveries).toHaveLength(2);
    expect(deliveries[0].channel).toBe(NotificationChannelType.FCM);
    expect(deliveries[0].status).toBe(NotificationDeliveryStatus.FAILED);
    expect(deliveries[1].channel).toBe(NotificationChannelType.TELEGRAM);
    expect(deliveries[1].status).toBe(NotificationDeliveryStatus.SENT);
    expect(telegramChannel.send).toHaveBeenCalled();
  });

  it('4. should cascade to Telegram when FCM fails and SMS fallback also fails', async () => {
    deviceRepo.find.mockResolvedValue([
      { id: 'dev-1', userId: 'user-1', isActive: true, pushToken: 'token-bad' },
    ]);
    fcmChannel.send.mockResolvedValue({ success: false, error: 'Token expired' });
    userRepo.findOne.mockResolvedValue({ id: 'user-1', phoneNumber: '+84912345678' });
    smsChannel.send.mockResolvedValue({ success: false, error: 'Carrier gateway down' });
    telegramChannel.send.mockResolvedValue({ success: true, messageId: 'tg-ok' });

    const deliveries = await service.sendNotification({
      recipientUserId: 'user-1',
      templateName: 'CHECK_IN_PROMPT',
    });

    expect(deliveries).toHaveLength(3);
    expect(deliveries[0].channel).toBe(NotificationChannelType.FCM);
    expect(deliveries[0].status).toBe(NotificationDeliveryStatus.FAILED);
    expect(deliveries[1].channel).toBe(NotificationChannelType.SMS);
    expect(deliveries[1].status).toBe(NotificationDeliveryStatus.FAILED);
    expect(deliveries[2].channel).toBe(NotificationChannelType.TELEGRAM);
    expect(deliveries[2].status).toBe(NotificationDeliveryStatus.SENT);
  });

  it('5. should dispatch directly via SMS when channel is explicitly SMS', async () => {
    userRepo.findOne.mockResolvedValue({ id: 'user-1', phoneNumber: '+84988888888' });
    smsChannel.send.mockResolvedValue({ success: true, messageId: 'sms-direct' });

    const deliveries = await service.sendNotification({
      recipientUserId: 'user-1',
      templateName: 'MONITOR_ESCALATION',
      channel: NotificationChannelType.SMS,
    });

    expect(deliveries).toHaveLength(1);
    expect(deliveries[0].channel).toBe(NotificationChannelType.SMS);
    expect(deliveries[0].status).toBe(NotificationDeliveryStatus.SENT);
    expect(smsChannel.send).toHaveBeenCalledWith(
      expect.objectContaining({ recipientTarget: '+84988888888' }),
    );
    expect(deviceRepo.find).not.toHaveBeenCalled();
  });

  it('6. should retry failed deliveries and respect maxAttempts', async () => {
    const failedFCM = {
      id: 'del-retry-1',
      recipientUserId: 'user-1',
      recipientTarget: 'token-valid',
      channel: NotificationChannelType.FCM,
      status: NotificationDeliveryStatus.FAILED,
      attemptCount: 1,
      maxAttempts: 3,
      failedAt: new Date(Date.now() - 60000), // 1 min ago
      payload: { title: 'T', body: 'B' },
    };

    deliveryRepo.find.mockResolvedValue([failedFCM]);
    fcmChannel.send.mockResolvedValue({ success: true, messageId: 'msg-retry-ok' });

    const retriedCount = await service.processRetries(10);

    expect(retriedCount).toBe(1);
    expect(failedFCM.status).toBe(NotificationDeliveryStatus.SENT);
    expect(failedFCM.attemptCount).toBe(2);
    expect(deliveryRepo.save).toHaveBeenCalled();
  });

  it('7. should catch FCM rejection and cascade smoothly to SMS without throwing', async () => {
    deviceRepo.find.mockResolvedValue([
      { id: 'dev-1', userId: 'user-1', isActive: true, pushToken: 'token-err' },
    ]);
    fcmChannel.send.mockRejectedValue(new Error('FCM connection reset by peer'));
    userRepo.findOne.mockResolvedValue({ id: 'user-1', phoneNumber: '+84912345678' });
    smsChannel.send.mockResolvedValue({ success: true, messageId: 'sms-ok' });

    const deliveries = await service.sendNotification({
      recipientUserId: 'user-1',
      templateName: 'CHECK_IN_PROMPT',
    });

    expect(deliveries).toHaveLength(2);
    expect(deliveries[0].channel).toBe(NotificationChannelType.FCM);
    expect(deliveries[0].status).toBe(NotificationDeliveryStatus.FAILED);
    expect(deliveries[0].lastError).toContain('FCM connection reset by peer');

    expect(deliveries[1].channel).toBe(NotificationChannelType.SMS);
    expect(deliveries[1].status).toBe(NotificationDeliveryStatus.SENT);
  });

  it('8. should catch both FCM and SMS rejections and cascade smoothly to Telegram', async () => {
    deviceRepo.find.mockResolvedValue([
      { id: 'dev-1', userId: 'user-1', isActive: true, pushToken: 'token-err' },
    ]);
    fcmChannel.send.mockRejectedValue(new Error('FCM socket hang up'));
    userRepo.findOne.mockResolvedValue({ id: 'user-1', phoneNumber: '+84912345678' });
    smsChannel.send.mockRejectedValue(new Error('SMS gateway timeout 504'));
    telegramChannel.send.mockResolvedValue({ success: true, messageId: 'tg-ok' });

    const deliveries = await service.sendNotification({
      recipientUserId: 'user-1',
      templateName: 'CHECK_IN_PROMPT',
      customData: { telegramChatId: 'tg-chat-123' },
    });

    expect(deliveries).toHaveLength(3);
    expect(deliveries[0].channel).toBe(NotificationChannelType.FCM);
    expect(deliveries[0].status).toBe(NotificationDeliveryStatus.FAILED);

    expect(deliveries[1].channel).toBe(NotificationChannelType.SMS);
    expect(deliveries[1].status).toBe(NotificationDeliveryStatus.FAILED);
    expect(deliveries[1].lastError).toContain('SMS gateway timeout 504');

    expect(deliveries[2].channel).toBe(NotificationChannelType.TELEGRAM);
    expect(deliveries[2].status).toBe(NotificationDeliveryStatus.SENT);
  });

  it('9. should cascade to SMS when user has no active devices and explicit language is specified', async () => {
    deviceRepo.find.mockResolvedValue([]);
    userRepo.findOne.mockResolvedValue({
      id: 'user-reg-1',
      phoneNumber: '+84912345678',
      preferredLanguage: 'vi',
    });
    smsChannel.send.mockResolvedValue({ success: true, messageId: 'sms-override' });

    const deliveries = await service.sendNotification({
      recipientUserId: 'user-reg-1',
      templateName: 'CHECK_IN_PROMPT',
      language: 'en',
    });

    expect(deliveries).toHaveLength(2);
    expect(deliveries[0].channel).toBe(NotificationChannelType.FCM);
    expect(deliveries[0].status).toBe(NotificationDeliveryStatus.FAILED);

    expect(deliveries[1].channel).toBe(NotificationChannelType.SMS);
    expect(deliveries[1].status).toBe(NotificationDeliveryStatus.SENT);
    expect(deliveries[1].recipientTarget).toBe('+84912345678');
    expect(deliveries[1].payload.title).toBe('Evernear — Are you doing okay?');
    expect(smsChannel.send).toHaveBeenCalled();
  });

  it('10. should cascade to SMS when FCM push rejects and explicit language is specified', async () => {
    deviceRepo.find.mockResolvedValue([
      { id: 'dev-1', userId: 'user-reg-2', isActive: true, pushToken: 'token-bad' },
    ]);
    fcmChannel.send.mockRejectedValue(new Error('FCM Connection Reset'));
    userRepo.findOne.mockResolvedValue({
      id: 'user-reg-2',
      phoneNumber: '+84912345678',
      preferredLanguage: 'vi',
    });
    smsChannel.send.mockResolvedValue({ success: true, messageId: 'sms-fcm-fail' });

    const deliveries = await service.sendNotification({
      recipientUserId: 'user-reg-2',
      templateName: 'MONITOR_ESCALATION',
      language: 'ja',
    });

    expect(deliveries).toHaveLength(2);
    expect(deliveries[0].channel).toBe(NotificationChannelType.FCM);
    expect(deliveries[0].status).toBe(NotificationDeliveryStatus.FAILED);

    expect(deliveries[1].channel).toBe(NotificationChannelType.SMS);
    expect(deliveries[1].status).toBe(NotificationDeliveryStatus.SENT);
    expect(deliveries[1].recipientTarget).toBe('+84912345678');
    expect(deliveries[1].payload.title).toBe('Evernear — ご確認のお願い');
    expect(smsChannel.send).toHaveBeenCalled();
  });

  it('11. should cascade to Telegram when explicit language is provided and user has no phone number', async () => {
    deviceRepo.find.mockResolvedValue([]);
    userRepo.findOne.mockResolvedValue({
      id: 'user-reg-3',
      phoneNumber: null,
      preferredLanguage: 'vi',
    });
    telegramChannel.send.mockResolvedValue({ success: true, messageId: 'tg-lang-override' });

    const deliveries = await service.sendNotification({
      recipientUserId: 'user-reg-3',
      templateName: 'CHECK_IN_PROMPT',
      language: 'fr',
      customData: { telegramChatId: 'tg-chat-reg-3' },
    });

    expect(deliveries).toHaveLength(2);
    expect(deliveries[0].channel).toBe(NotificationChannelType.FCM);
    expect(deliveries[0].status).toBe(NotificationDeliveryStatus.FAILED);

    expect(deliveries[1].channel).toBe(NotificationChannelType.TELEGRAM);
    expect(deliveries[1].status).toBe(NotificationDeliveryStatus.SENT);
    expect(deliveries[1].recipientTarget).toBe('tg-chat-reg-3');
    expect(deliveries[1].payload.title).toBe('Evernear — Tout va bien ?');
    expect(telegramChannel.send).toHaveBeenCalled();
  });

  it('12. should mark delivery as EXHAUSTED when retry attempt count reaches maxAttempts', async () => {
    const deadDelivery = {
      id: 'del-exhausted-1',
      recipientUserId: 'user-1',
      recipientTarget: 'token-valid',
      channel: NotificationChannelType.FCM,
      status: NotificationDeliveryStatus.FAILED,
      attemptCount: 2,
      maxAttempts: 3,
      failedAt: new Date(Date.now() - 120000),
      payload: { title: 'T', body: 'B' },
    };

    const mockQb: any = {
      where: vi.fn().mockReturnThis(),
      andWhere: vi.fn().mockReturnThis(),
      orderBy: vi.fn().mockReturnThis(),
      take: vi.fn().mockReturnThis(),
      getMany: vi.fn().mockResolvedValue([deadDelivery]),
    };
    deliveryRepo.createQueryBuilder = vi.fn().mockReturnValue(mockQb);
    fcmChannel.send.mockResolvedValue({ success: false, error: 'Token unregistered' });

    const retriedCount = await service.processRetries(10);

    expect(retriedCount).toBe(1);
    expect(deadDelivery.attemptCount).toBe(3);
    expect(deadDelivery.status).toBe(NotificationDeliveryStatus.EXHAUSTED);
    expect(deliveryRepo.save).toHaveBeenCalledWith(deadDelivery);
    expect(mockQb.where).toHaveBeenCalledWith('delivery.status = :status', {
      status: NotificationDeliveryStatus.FAILED,
    });
    expect(mockQb.andWhere).toHaveBeenCalledWith('delivery.attempt_count < delivery.max_attempts');
  });
});
