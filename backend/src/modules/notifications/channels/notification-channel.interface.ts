import { NotificationChannelType } from '../../../common/enums';

export interface NotificationPayload {
  recipientUserId: string;
  recipientTarget: string; // FCM token, phone number, telegram chat ID, etc.
  title: string;
  body: string;
  data?: Record<string, string>;
  incidentId?: string;
}

export interface NotificationResult {
  success: boolean;
  messageId?: string;
  error?: string;
  errorCode?: string;
  tokenInvalid?: boolean;
}

export interface INotificationChannel {
  readonly channelType: NotificationChannelType;
  send(payload: NotificationPayload): Promise<NotificationResult>;
}
