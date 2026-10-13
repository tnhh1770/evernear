import { Injectable, Logger } from '@nestjs/common';
import {
  INotificationChannel,
  NotificationPayload,
  NotificationResult,
} from './notification-channel.interface';
import { NotificationChannelType } from '../../../common/enums';

@Injectable()
export class SmsChannel implements INotificationChannel {
  private readonly logger = new Logger(SmsChannel.name);
  readonly channelType = NotificationChannelType.SMS;

  async send(payload: NotificationPayload): Promise<NotificationResult> {
    this.logger.log(`[SMS Stub] Sending SMS to ${payload.recipientTarget}: ${payload.body}`);
    return {
      success: true,
      messageId: `sms-msg-${Date.now()}`,
    };
  }
}

@Injectable()
export class TelegramChannel implements INotificationChannel {
  private readonly logger = new Logger(TelegramChannel.name);
  readonly channelType = NotificationChannelType.TELEGRAM;

  async send(payload: NotificationPayload): Promise<NotificationResult> {
    this.logger.log(`[Telegram Stub] Sending message to chat ${payload.recipientTarget}: ${payload.body}`);
    return {
      success: true,
      messageId: `tg-msg-${Date.now()}`,
    };
  }
}
