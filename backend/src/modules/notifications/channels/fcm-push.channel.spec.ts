import { describe, it, expect, vi, beforeEach } from 'vitest';
import { ConfigService } from '@nestjs/config';
import { FcmPushChannel } from './fcm-push.channel';
import { NotificationChannelType } from '../../../common/enums';

describe('FcmPushChannel Unit Tests', () => {
  let channel: FcmPushChannel;
  let configService: ConfigService;

  beforeEach(() => {
    configService = new ConfigService({
      FCM_PROJECT_ID: 'carely-test-project',
      FCM_CLIENT_EMAIL: 'test@carely.iam.gserviceaccount.com',
      FCM_PRIVATE_KEY: '',
    });
    channel = new FcmPushChannel(configService);
  });

  it('1. should identify channelType as FCM', () => {
    expect(channel.channelType).toBe(NotificationChannelType.FCM);
  });

  it('2. should reject when recipientTarget is empty or NO_ACTIVE_DEVICE_TOKEN', async () => {
    const res1 = await channel.send({
      recipientUserId: 'u1',
      recipientTarget: '',
      title: 'Test',
      body: 'Test body',
    });
    expect(res1.success).toBe(false);
    expect(res1.errorCode).toBe('INVALID_TARGET');

    const res2 = await channel.send({
      recipientUserId: 'u1',
      recipientTarget: 'NO_ACTIVE_DEVICE_TOKEN',
      title: 'Test',
      body: 'Test body',
    });
    expect(res2.success).toBe(false);
    expect(res2.errorCode).toBe('INVALID_TARGET');
  });

  it('3. should return simulated success in mock mode for standard test token', async () => {
    const res = await channel.send({
      recipientUserId: 'u1',
      recipientTarget: 'mock-token-xyz-123',
      title: 'Bạn vẫn ổn chứ?',
      body: 'Đã khá lâu chưa thấy bạn dùng điện thoại.',
      data: {
        templateName: 'CHECK_IN_REQUEST',
        incidentId: 'inc-123',
      },
    });

    expect(res.success).toBe(true);
    expect(res.messageId).toBeDefined();
    expect(res.messageId).toContain('mock-fcm-');
  });

  it('4. should identify expired/unregistered token and flag tokenInvalid in mock mode', async () => {
    const res = await channel.send({
      recipientUserId: 'u1',
      recipientTarget: 'mock-token-expired-unregistered',
      title: 'Alert',
      body: 'Alert body',
    });

    expect(res.success).toBe(false);
    expect(res.tokenInvalid).toBe(true);
    expect(res.errorCode).toBe('messaging/registration-token-not-registered');
  });

  it('5. should dispatch message through live Firebase Admin messaging when configured', async () => {
    const sendMock = vi.fn().mockResolvedValue('projects/carely/messages/live-msg-id-123');
    channel.setCustomMessaging({ send: sendMock });

    const res = await channel.send({
      recipientUserId: 'u1',
      recipientTarget: 'real-fcm-device-token-abc',
      title: 'Thông báo từ Evernear',
      body: 'Không nhận được xác nhận từ người thân.',
      data: {
        templateName: 'ALERT_TRIGGERED',
        incidentId: 'inc-456',
        priority: 'high',
      },
    });

    expect(res.success).toBe(true);
    expect(res.messageId).toBe('projects/carely/messages/live-msg-id-123');
    expect(sendMock).toHaveBeenCalledTimes(1);

    const callArgs = sendMock.mock.calls[0][0];
    expect(callArgs.token).toBe('real-fcm-device-token-abc');
    expect(callArgs.notification.title).toBe('Thông báo từ Evernear');
    expect(callArgs.notification.body).toBe('Không nhận được xác nhận từ người thân.');
    expect(callArgs.android.priority).toBe('high');
    expect(callArgs.android.notification.channelId).toBe('evernear_alerts_channel');
    expect(callArgs.data.incidentId).toBe('inc-456');
  });

  it('6. should catch Firebase Admin unregistered token error and set tokenInvalid', async () => {
    const sendMock = vi.fn().mockRejectedValue({
      code: 'messaging/registration-token-not-registered',
      message: 'The registration token is not registered with FCM.',
    });
    channel.setCustomMessaging({ send: sendMock });

    const res = await channel.send({
      recipientUserId: 'u1',
      recipientTarget: 'dead-token-123',
      title: 'Alert',
      body: 'Body',
    });

    expect(res.success).toBe(false);
    expect(res.tokenInvalid).toBe(true);
    expect(res.errorCode).toBe('messaging/registration-token-not-registered');
  });

  it('7. should handle network/service errors gracefully without crashing', async () => {
    const sendMock = vi.fn().mockRejectedValue(new Error('FCM 503 Service Unavailable'));
    channel.setCustomMessaging({ send: sendMock });

    const res = await channel.send({
      recipientUserId: 'u1',
      recipientTarget: 'token-503',
      title: 'Alert',
      body: 'Body',
    });

    expect(res.success).toBe(false);
    expect(res.tokenInvalid).toBe(false);
    expect(res.error).toContain('FCM 503 Service Unavailable');
  });
});
