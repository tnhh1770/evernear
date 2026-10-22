import { Injectable, Logger } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Cron, CronExpression } from '@nestjs/schedule';
import { NotificationDelivery } from './entities/notification-delivery.entity';
import { Device } from '../devices/entities/device.entity';
import { User } from '../users/entities/user.entity';
import { FcmPushChannel } from './channels/fcm-push.channel';
import { SmsChannel, TelegramChannel } from './channels/stubs.channel';
import { NotificationResult } from './channels/notification-channel.interface';
import { NotificationTemplateService } from './notification-template.service';
import {
  NotificationChannelType,
  NotificationDeliveryStatus,
} from '../../common/enums';

@Injectable()
export class NotificationsService {
  private readonly logger = new Logger(NotificationsService.name);

  constructor(
    @InjectRepository(NotificationDelivery)
    private readonly deliveryRepo: Repository<NotificationDelivery>,
    @InjectRepository(Device)
    private readonly deviceRepo: Repository<Device>,
    @InjectRepository(User)
    private readonly userRepo: Repository<User>,
    private readonly fcmChannel: FcmPushChannel,
    private readonly smsChannel: SmsChannel,
    private readonly telegramChannel: TelegramChannel,
    private readonly templateService: NotificationTemplateService,
  ) {}

  /**
   * Dispatch a notification to a specific user across active devices or channels,
   * cascading automatically to SMS and Telegram if FCM push fails or is unavailable.
   */
  async sendNotification(params: {
    recipientUserId: string;
    templateName: string;
    incidentId?: string;
    templateParams?: Record<string, string>;
    customData?: Record<string, string>;
    channel?: NotificationChannelType;
    language?: string;
  }): Promise<NotificationDelivery[]> {
    const channelType = params.channel || NotificationChannelType.FCM;

    // Resolve recipient user and preferred language
    let recipientUser: User | null = null;
    let lang = params.language;

    if (!lang) {
      recipientUser = await this.userRepo.findOne({
        where: { id: params.recipientUserId },
      });
      lang = recipientUser?.preferredLanguage || 'vi';
    }

    const rendered = this.templateService.render(
      params.templateName,
      params.templateParams,
      lang,
    );

    const deliveries: NotificationDelivery[] = [];

    // Direct SMS dispatch
    if (channelType === NotificationChannelType.SMS) {
      if (!recipientUser) {
        recipientUser = await this.userRepo.findOne({
          where: { id: params.recipientUserId },
        });
      }
      const user = recipientUser;
      if (user?.phoneNumber) {
        const d = await this.dispatchSms({
          recipientUserId: params.recipientUserId,
          incidentId: params.incidentId,
          phoneNumber: user.phoneNumber,
          rendered,
          customData: params.customData,
          templateName: params.templateName,
        });
        deliveries.push(d);
      } else {
        const failedDelivery = this.deliveryRepo.create({
          recipientUserId: params.recipientUserId,
          incidentId: params.incidentId || null,
          channel: NotificationChannelType.SMS,
          templateName: params.templateName,
          recipientTarget: 'NO_PHONE_NUMBER',
          payload: { title: rendered.title, body: rendered.body },
          status: NotificationDeliveryStatus.FAILED,
          lastError: 'User has no phone number registered',
          failedAt: new Date(),
        });
        deliveries.push(await this.deliveryRepo.save(failedDelivery));
      }
      return deliveries;
    }

    // Direct Telegram dispatch
    if (channelType === NotificationChannelType.TELEGRAM) {
      if (!recipientUser) {
        recipientUser = await this.userRepo.findOne({
          where: { id: params.recipientUserId },
        });
      }
      const user = recipientUser;
      const telegramTarget =
        params.customData?.telegramChatId ||
        user?.phoneNumber ||
        params.recipientUserId;

      const d = await this.dispatchTelegram({
        recipientUserId: params.recipientUserId,
        incidentId: params.incidentId,
        telegramTarget,
        rendered,
        customData: params.customData,
        templateName: params.templateName,
      });
      deliveries.push(d);
      return deliveries;
    }

    // Default: FCM with cascading fallback
    if (channelType === NotificationChannelType.FCM) {
      const devices = await this.deviceRepo.find({
        where: {
          userId: params.recipientUserId,
          isActive: true,
        },
      });

      const eligibleDevices = devices.filter((d) => !!d.pushToken);

      if (eligibleDevices.length === 0) {
        this.logger.warn(
          `No active devices with push token found for user ${params.recipientUserId}. Cascading to fallback channels.`,
        );

        // Record failed FCM attempt for visibility & audit trail
        const failedFcm = this.deliveryRepo.create({
          recipientUserId: params.recipientUserId,
          incidentId: params.incidentId || null,
          channel: NotificationChannelType.FCM,
          templateName: params.templateName,
          recipientTarget: 'NO_ACTIVE_DEVICE_TOKEN',
          payload: { title: rendered.title, body: rendered.body },
          status: NotificationDeliveryStatus.FAILED,
          lastError: 'No active device with push token registered for user',
          failedAt: new Date(),
        });
        deliveries.push(await this.deliveryRepo.save(failedFcm));

        // Cascade to SMS -> Telegram
        if (!recipientUser) {
          recipientUser = await this.userRepo.findOne({
            where: { id: params.recipientUserId },
          });
        }
        const fallbacks = await this.cascadeFallback({
          recipientUserId: params.recipientUserId,
          incidentId: params.incidentId,
          rendered,
          customData: params.customData,
          templateName: params.templateName,
          preloadedUser: recipientUser,
        });
        deliveries.push(...fallbacks);

        return deliveries;
      }

      // Dispatch FCM to all eligible devices
      for (const dev of eligibleDevices) {
        const delivery = this.deliveryRepo.create({
          recipientUserId: params.recipientUserId,
          incidentId: params.incidentId || null,
          channel: NotificationChannelType.FCM,
          templateName: params.templateName,
          recipientTarget: dev.pushToken!,
          payload: {
            title: rendered.title,
            body: rendered.body,
            data: {
              ...params.customData,
              templateName: params.templateName,
              incidentId: params.incidentId || '',
            },
          },
          status: NotificationDeliveryStatus.PENDING,
          attemptCount: 1,
        });

        const saved = await this.deliveryRepo.save(delivery);

        let result: NotificationResult;
        try {
          result = await this.fcmChannel.send({
            recipientUserId: params.recipientUserId,
            recipientTarget: dev.pushToken!,
            title: rendered.title,
            body: rendered.body,
            data: {
              ...params.customData,
              templateName: params.templateName,
              incidentId: params.incidentId || '',
            },
            incidentId: params.incidentId,
          });
        } catch (err: any) {
          this.logger.error(
            `FCM dispatch exception for user ${params.recipientUserId} on device ${dev.deviceUid}: ${err.message}`,
            err.stack,
          );
          result = {
            success: false,
            error: err.message || 'FCM dispatch thrown error',
          };
        }

        if (result.success) {
          saved.status = NotificationDeliveryStatus.SENT;
          saved.sentAt = new Date();
        } else {
          saved.status = NotificationDeliveryStatus.FAILED;
          saved.failedAt = new Date();
          saved.lastError = result.error || 'Unknown FCM dispatch error';

          // Dead-lettering: Deactivate unregistered or invalid token per NOTIFICATION.md section 4
          if (result.tokenInvalid) {
            dev.isActive = false;
            dev.pushToken = null as any;
            await this.deviceRepo.save(dev);
            this.logger.warn(
              `Deactivated invalid FCM push token on device ${dev.deviceUid} for user ${params.recipientUserId}`,
            );
          }
        }

        deliveries.push(await this.deliveryRepo.save(saved));
      }

      // Check if all FCM push attempts failed
      const anyFcmSuccess = deliveries.some(
        (d) =>
          d.channel === NotificationChannelType.FCM &&
          d.status === NotificationDeliveryStatus.SENT,
      );

      if (!anyFcmSuccess) {
        this.logger.warn(
          `All FCM push attempts failed for user ${params.recipientUserId}. Cascading to fallback channels.`,
        );
        if (!recipientUser) {
          recipientUser = await this.userRepo.findOne({
            where: { id: params.recipientUserId },
          });
        }
        const fallbacks = await this.cascadeFallback({
          recipientUserId: params.recipientUserId,
          incidentId: params.incidentId,
          rendered,
          customData: params.customData,
          templateName: params.templateName,
          preloadedUser: recipientUser,
        });
        deliveries.push(...fallbacks);
      }
    }

    return deliveries;
  }

  /**
   * Cascade alert to SMS, then to Telegram if SMS is unavailable or fails.
   */
  private async cascadeFallback(params: {
    recipientUserId: string;
    incidentId?: string;
    rendered: { title: string; body: string };
    customData?: Record<string, string>;
    templateName: string;
    preloadedUser?: User | null;
  }): Promise<NotificationDelivery[]> {
    const fallbackDeliveries: NotificationDelivery[] = [];
    const user =
      params.preloadedUser ||
      (await this.userRepo.findOne({
        where: { id: params.recipientUserId },
      }));

    let smsSuccess = false;
    if (user?.phoneNumber) {
      this.logger.log(
        `Cascading alert to SMS for user ${params.recipientUserId} (${user.phoneNumber})`,
      );
      const smsDelivery = await this.dispatchSms({
        recipientUserId: params.recipientUserId,
        incidentId: params.incidentId,
        phoneNumber: user.phoneNumber,
        rendered: params.rendered,
        customData: params.customData,
        templateName: params.templateName,
      });
      fallbackDeliveries.push(smsDelivery);
      smsSuccess = smsDelivery.status === NotificationDeliveryStatus.SENT;
    } else {
      this.logger.warn(
        `Cannot cascade to SMS: user ${params.recipientUserId} has no phone number`,
      );
    }

    // Cascade to Telegram if SMS failed or user had no phone number, provided a telegram target exists
    if (!smsSuccess) {
      const telegramTarget =
        params.customData?.telegramChatId ||
        (user as any)?.telegramChatId ||
        (user?.phoneNumber ? `tg_${user.phoneNumber}` : null);

      if (telegramTarget) {
        this.logger.log(
          `Cascading alert to Telegram for user ${params.recipientUserId} (${telegramTarget})`,
        );
        const tgDelivery = await this.dispatchTelegram({
          recipientUserId: params.recipientUserId,
          incidentId: params.incidentId,
          telegramTarget,
          rendered: params.rendered,
          customData: params.customData,
          templateName: params.templateName,
        });
        fallbackDeliveries.push(tgDelivery);
      } else {
        this.logger.warn(
          `Cannot cascade to Telegram: user ${params.recipientUserId} has no telegram target`,
        );
      }
    }

    return fallbackDeliveries;
  }

  /**
   * Helper to dispatch SMS and record status
   */
  private async dispatchSms(params: {
    recipientUserId: string;
    incidentId?: string;
    phoneNumber: string;
    rendered: { title: string; body: string };
    customData?: Record<string, string>;
    templateName: string;
  }): Promise<NotificationDelivery> {
    const delivery = this.deliveryRepo.create({
      recipientUserId: params.recipientUserId,
      incidentId: params.incidentId || null,
      channel: NotificationChannelType.SMS,
      templateName: params.templateName,
      recipientTarget: params.phoneNumber,
      payload: {
        title: params.rendered.title,
        body: params.rendered.body,
        data: {
          ...params.customData,
          templateName: params.templateName,
          incidentId: params.incidentId || '',
        },
      },
      status: NotificationDeliveryStatus.PENDING,
      attemptCount: 1,
    });

    const saved = await this.deliveryRepo.save(delivery);

    let result: NotificationResult;
    try {
      result = await this.smsChannel.send({
        recipientUserId: params.recipientUserId,
        recipientTarget: params.phoneNumber,
        title: params.rendered.title,
        body: params.rendered.body,
        data: {
          ...params.customData,
          templateName: params.templateName,
          incidentId: params.incidentId || '',
        },
        incidentId: params.incidentId,
      });
    } catch (err: any) {
      this.logger.error(
        `SMS dispatch exception for user ${params.recipientUserId} to ${params.phoneNumber}: ${err.message}`,
        err.stack,
      );
      result = {
        success: false,
        error: err.message || 'SMS dispatch thrown error',
      };
    }

    if (result.success) {
      saved.status = NotificationDeliveryStatus.SENT;
      saved.sentAt = new Date();
    } else {
      saved.status = NotificationDeliveryStatus.FAILED;
      saved.failedAt = new Date();
      saved.lastError = result.error || 'SMS dispatch failed';
    }

    return this.deliveryRepo.save(saved);
  }

  /**
   * Helper to dispatch Telegram and record status
   */
  private async dispatchTelegram(params: {
    recipientUserId: string;
    incidentId?: string;
    telegramTarget: string;
    rendered: { title: string; body: string };
    customData?: Record<string, string>;
    templateName: string;
  }): Promise<NotificationDelivery> {
    const delivery = this.deliveryRepo.create({
      recipientUserId: params.recipientUserId,
      incidentId: params.incidentId || null,
      channel: NotificationChannelType.TELEGRAM,
      templateName: params.templateName,
      recipientTarget: params.telegramTarget,
      payload: {
        title: params.rendered.title,
        body: params.rendered.body,
        data: {
          ...params.customData,
          templateName: params.templateName,
          incidentId: params.incidentId || '',
        },
      },
      status: NotificationDeliveryStatus.PENDING,
      attemptCount: 1,
    });

    const saved = await this.deliveryRepo.save(delivery);

    let result: NotificationResult;
    try {
      result = await this.telegramChannel.send({
        recipientUserId: params.recipientUserId,
        recipientTarget: params.telegramTarget,
        title: params.rendered.title,
        body: params.rendered.body,
        data: {
          ...params.customData,
          templateName: params.templateName,
          incidentId: params.incidentId || '',
        },
        incidentId: params.incidentId,
      });
    } catch (err: any) {
      this.logger.error(
        `Telegram dispatch exception for user ${params.recipientUserId} to ${params.telegramTarget}: ${err.message}`,
        err.stack,
      );
      result = {
        success: false,
        error: err.message || 'Telegram dispatch thrown error',
      };
    }

    if (result.success) {
      saved.status = NotificationDeliveryStatus.SENT;
      saved.sentAt = new Date();
    } else {
      saved.status = NotificationDeliveryStatus.FAILED;
      saved.failedAt = new Date();
      saved.lastError = result.error || 'Telegram dispatch failed';
    }

    return this.deliveryRepo.save(saved);
  }

  /**
   * Programmatic retry runner for failed notification deliveries.
   * Matches deliveries where status = FAILED and attemptCount < maxAttempts.
   * Applies exponential backoff: delay = min(300s, 2^attempt * 10s).
   */
  async processRetries(limit = 50): Promise<number> {
    let failedDeliveries: NotificationDelivery[];
    if (typeof this.deliveryRepo.createQueryBuilder === 'function') {
      failedDeliveries = await this.deliveryRepo
        .createQueryBuilder('delivery')
        .where('delivery.status = :status', {
          status: NotificationDeliveryStatus.FAILED,
        })
        .andWhere('delivery.attempt_count < delivery.max_attempts')
        .orderBy('delivery.failed_at', 'ASC')
        .take(limit)
        .getMany();
    } else {
      failedDeliveries = await this.deliveryRepo.find({
        where: {
          status: NotificationDeliveryStatus.FAILED,
        },
        order: { failedAt: 'ASC' },
        take: limit,
      });
    }

    const eligible = failedDeliveries.filter(
      (d) => d.attemptCount < d.maxAttempts,
    );

    if (eligible.length === 0) {
      return 0;
    }

    let retriedCount = 0;
    const now = new Date();

    for (const delivery of eligible) {
      const backoffMs =
        Math.min(300, Math.pow(2, delivery.attemptCount) * 10) * 1000;
      if (
        delivery.failedAt &&
        now.getTime() - new Date(delivery.failedAt).getTime() < backoffMs
      ) {
        continue;
      }

      delivery.attemptCount += 1;
      let sendResult: { success: boolean; error?: string } = { success: false };

      try {
        if (delivery.channel === NotificationChannelType.FCM) {
          let token = delivery.recipientTarget;
          if (token === 'NO_ACTIVE_DEVICE_TOKEN') {
            const devices = await this.deviceRepo.find({
              where: { userId: delivery.recipientUserId, isActive: true },
            });
            const valid = devices.find((d) => !!d.pushToken);
            if (valid) {
              token = valid.pushToken!;
              delivery.recipientTarget = token;
            }
          }

          if (token && token !== 'NO_ACTIVE_DEVICE_TOKEN') {
            sendResult = await this.fcmChannel.send({
              recipientUserId: delivery.recipientUserId,
              recipientTarget: token,
              title: delivery.payload?.title || '',
              body: delivery.payload?.body || '',
              data: delivery.payload?.data,
              incidentId: delivery.incidentId || undefined,
            });
          } else {
            sendResult = {
              success: false,
              error: 'Still no active device token available',
            };
          }
        } else if (delivery.channel === NotificationChannelType.SMS) {
          if (
            delivery.recipientTarget &&
            delivery.recipientTarget !== 'NO_PHONE_NUMBER'
          ) {
            sendResult = await this.smsChannel.send({
              recipientUserId: delivery.recipientUserId,
              recipientTarget: delivery.recipientTarget,
              title: delivery.payload?.title || '',
              body: delivery.payload?.body || '',
              data: delivery.payload?.data,
              incidentId: delivery.incidentId || undefined,
            });
          } else {
            const user = await this.userRepo.findOne({
              where: { id: delivery.recipientUserId },
            });
            if (user?.phoneNumber) {
              delivery.recipientTarget = user.phoneNumber;
              sendResult = await this.smsChannel.send({
                recipientUserId: delivery.recipientUserId,
                recipientTarget: user.phoneNumber,
                title: delivery.payload?.title || '',
                body: delivery.payload?.body || '',
                data: delivery.payload?.data,
                incidentId: delivery.incidentId || undefined,
              });
            } else {
              sendResult = {
                success: false,
                error: 'User still has no phone number',
              };
            }
          }
        } else if (delivery.channel === NotificationChannelType.TELEGRAM) {
          sendResult = await this.telegramChannel.send({
            recipientUserId: delivery.recipientUserId,
            recipientTarget: delivery.recipientTarget,
            title: delivery.payload?.title || '',
            body: delivery.payload?.body || '',
            data: delivery.payload?.data,
            incidentId: delivery.incidentId || undefined,
          });
        }

        if (sendResult.success) {
          delivery.status = NotificationDeliveryStatus.SENT;
          delivery.sentAt = new Date();
          delivery.lastError = null as any;
        } else {
          delivery.failedAt = new Date();
          delivery.lastError = sendResult.error || 'Retry attempt failed';
          if (delivery.attemptCount >= delivery.maxAttempts) {
            delivery.status = NotificationDeliveryStatus.EXHAUSTED;
          } else {
            delivery.status = NotificationDeliveryStatus.FAILED;
          }
        }

        await this.deliveryRepo.save(delivery);
        retriedCount++;
      } catch (err: any) {
        this.logger.error(
          `Error retrying delivery ${delivery.id}: ${err.message}`,
        );
        delivery.failedAt = new Date();
        delivery.lastError = err.message;
        if (delivery.attemptCount >= delivery.maxAttempts) {
          delivery.status = NotificationDeliveryStatus.EXHAUSTED;
        } else {
          delivery.status = NotificationDeliveryStatus.FAILED;
        }
        await this.deliveryRepo.save(delivery);
      }
    }

    return retriedCount;
  }

  /**
   * Cron handler running every minute to process retries of failed deliveries.
   */
  @Cron(CronExpression.EVERY_MINUTE)
  async handleRetryCron() {
    if (
      process.env.DISABLE_WORKER_CRON === 'true' ||
      process.env.NODE_ENV === 'test'
    ) {
      return;
    }
    try {
      const count = await this.processRetries();
      if (count > 0) {
        this.logger.log(`Retried ${count} failed notification deliveries`);
      }
    } catch (err: any) {
      this.logger.error(`Error in notification retry cron: ${err.message}`);
    }
  }
}
