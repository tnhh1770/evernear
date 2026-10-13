import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { NotificationChannel } from './entities/notification-channel.entity';
import { NotificationDelivery } from './entities/notification-delivery.entity';
import { Device } from '../devices/entities/device.entity';
import { User } from '../users/entities/user.entity';
import { NotificationsService } from './notifications.service';
import { NotificationTemplateService } from './notification-template.service';
import { FcmPushChannel } from './channels/fcm-push.channel';
import { SmsChannel, TelegramChannel } from './channels/stubs.channel';

@Module({
  imports: [
    TypeOrmModule.forFeature([
      NotificationChannel,
      NotificationDelivery,
      Device,
      User,
    ]),
  ],
  providers: [
    NotificationsService,
    NotificationTemplateService,
    FcmPushChannel,
    SmsChannel,
    TelegramChannel,
  ],
  exports: [NotificationsService, NotificationTemplateService, TypeOrmModule],
})
export class NotificationsModule {}
