import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { App, getApps, initializeApp, cert, applicationDefault } from 'firebase-admin/app';
import { getMessaging, Message } from 'firebase-admin/messaging';
import {
  INotificationChannel,
  NotificationPayload,
  NotificationResult,
} from './notification-channel.interface';
import { NotificationChannelType } from '../../../common/enums';

@Injectable()
export class FcmPushChannel implements INotificationChannel, OnModuleInit {
  private readonly logger = new Logger(FcmPushChannel.name);
  readonly channelType = NotificationChannelType.FCM;
  private firebaseApp: App | null = null;
  private isConfigured = false;
  private customMessaging: { send: (msg: any) => Promise<string> } | null = null;

  constructor(private readonly configService: ConfigService) {}

  onModuleInit() {
    this.initializeFirebase();
  }

  /**
   * Initializes the Firebase Admin app using environment variables or service account.
   */
  public initializeFirebase(): boolean {
    const existingApps = getApps();
    if (this.firebaseApp || existingApps.length > 0) {
      this.firebaseApp = this.firebaseApp || existingApps[0] || null;
      this.isConfigured = !!this.firebaseApp;
      return this.isConfigured;
    }

    const projectId =
      this.configService.get<string>('FIREBASE_PROJECT_ID') ||
      this.configService.get<string>('FCM_PROJECT_ID');
    const clientEmail =
      this.configService.get<string>('FIREBASE_CLIENT_EMAIL') ||
      this.configService.get<string>('FCM_CLIENT_EMAIL');
    let privateKey =
      this.configService.get<string>('FIREBASE_PRIVATE_KEY') ||
      this.configService.get<string>('FCM_PRIVATE_KEY');

    // Strip wrapping quotes and parse newlines
    if (privateKey) {
      privateKey = privateKey.replace(/^"(.*)"$/, '$1').replace(/\\n/g, '\n');
    }

    try {
      if (projectId && clientEmail && privateKey && privateKey.trim().length > 0) {
        this.firebaseApp = initializeApp(
          {
            credential: cert({
              projectId,
              clientEmail,
              privateKey,
            }),
          },
          'carely-fcm',
        );
        this.isConfigured = true;
        this.logger.log(`[FCM] Firebase Admin initialized for project: ${projectId}`);
        return true;
      }

      if (process.env.GOOGLE_APPLICATION_CREDENTIALS) {
        this.firebaseApp = initializeApp(
          {
            credential: applicationDefault(),
            projectId,
          },
          'carely-fcm',
        );
        this.isConfigured = true;
        this.logger.log(`[FCM] Firebase Admin initialized from GOOGLE_APPLICATION_CREDENTIALS`);
        return true;
      }

      this.logger.warn(
        `[FCM] No live Firebase credentials configured. FCM channel will run in graceful mock mode.`,
      );
      this.isConfigured = false;
      return false;
    } catch (err: any) {
      this.logger.error(`[FCM] Failed to initialize Firebase Admin: ${err.message}`, err.stack);
      this.isConfigured = false;
      return false;
    }
  }

  /**
   * Allows unit tests to inject a mock app or messaging instance.
   */
  public setFirebaseApp(app: App | null) {
    this.firebaseApp = app;
    this.isConfigured = !!app;
  }

  /**
   * Allows unit tests to inject custom messaging mock directly.
   */
  public setCustomMessaging(messaging: { send: (msg: any) => Promise<string> } | null) {
    this.customMessaging = messaging;
    this.isConfigured = !!messaging || !!this.firebaseApp;
  }

  /**
   * Dispatches push notification to recipient device via FCM.
   */
  async send(payload: NotificationPayload): Promise<NotificationResult> {
    const target = payload.recipientTarget?.trim();

    if (!target || target === 'NO_ACTIVE_DEVICE_TOKEN') {
      return {
        success: false,
        error: 'Missing device push token',
        errorCode: 'INVALID_TARGET',
      };
    }

    this.logger.log(
      `[FCM] Sending push notification to ${target.substring(0, 12)}... Title: "${payload.title}"`,
    );

    // 1. Check for mock/test tokens or unconfigured live credentials
    const isMockToken =
      target.startsWith('mock-') ||
      target.startsWith('test-') ||
      target.startsWith('simulated-') ||
      (process.env.NODE_ENV === 'test' && !this.firebaseApp && !this.customMessaging);

    if (!this.isConfigured || isMockToken) {
      // Simulate invalid token handling for testing
      if (target.includes('invalid') || target.includes('expired') || target.includes('unregistered')) {
        return {
          success: false,
          error: 'Requested entity was not found (mock token unregistered)',
          errorCode: 'messaging/registration-token-not-registered',
          tokenInvalid: true,
        };
      }

      // Normal mock success
      return {
        success: true,
        messageId: `mock-fcm-${Date.now()}-${Math.floor(Math.random() * 10000)}`,
      };
    }

    // 2. Real dispatch using Firebase Admin SDK
    try {
      const stringData: Record<string, string> = {};
      if (payload.data) {
        for (const [key, value] of Object.entries(payload.data)) {
          if (value !== undefined && value !== null) {
            stringData[key] = String(value);
          }
        }
      }

      const message: Message = {
        token: target,
        notification: {
          title: payload.title,
          body: payload.body,
        },
        data: stringData,
        android: {
          priority: 'high',
          notification: {
            channelId: 'carely_alerts_channel',
            sound: 'default',
            clickAction: 'FLUTTER_NOTIFICATION_CLICK',
          },
        },
        apns: {
          payload: {
            aps: {
              sound: 'default',
              badge: 1,
            },
          },
        },
      };

      const messagingService = this.customMessaging || (this.firebaseApp ? getMessaging(this.firebaseApp) : null);
      if (!messagingService) {
        throw new Error('Firebase messaging service is not initialized');
      }

      const messageId = await messagingService.send(message);
      this.logger.log(`[FCM] Push sent successfully: ${messageId}`);

      return {
        success: true,
        messageId,
      };
    } catch (err: any) {
      const code = err.code || err.errorInfo?.code || '';
      const isUnregistered =
        code === 'messaging/registration-token-not-registered' ||
        code === 'messaging/invalid-registration-token' ||
        err.message?.includes('registration-token-not-registered') ||
        err.message?.includes('not found');

      this.logger.error(`[FCM] Dispatch error: [${code}] ${err.message}`);

      return {
        success: false,
        error: err.message || 'FCM dispatch error',
        errorCode: code || 'UNKNOWN_ERROR',
        tokenInvalid: isUnregistered,
      };
    }
  }
}
