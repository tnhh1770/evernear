import { Module } from '@nestjs/common';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { TypeOrmModule } from '@nestjs/typeorm';
import { ScheduleModule } from '@nestjs/schedule';

import { AppController } from './app.controller';
import { RedisModule } from './common/redis/redis.module';
import { AuditModule } from './modules/audit/audit.module';
import { AuthModule } from './modules/auth/auth.module';
import { UsersModule } from './modules/users/users.module';
import { DevicesModule } from './modules/devices/devices.module';
import { MonitoringModule } from './modules/monitoring/monitoring.module';
import { ActivitiesModule } from './modules/activities/activities.module';
import { CheckInsModule } from './modules/check-ins/check-ins.module';
import { LocationsModule } from './modules/locations/locations.module';
import { IncidentsModule } from './modules/incidents/incidents.module';
import { NotificationsModule } from './modules/notifications/notifications.module';
import { MonitoringWorkerModule } from './modules/workers/monitoring-worker.module';
import { RealtimeModule } from './modules/realtime/realtime.module';

// Entities
import { User } from './modules/users/entities/user.entity';
import { Device } from './modules/devices/entities/device.entity';
import { PairingInvitation } from './modules/monitoring/entities/pairing-invitation.entity';
import { MonitoringRelationship } from './modules/monitoring/entities/monitoring-relationship.entity';
import { MonitoringConfig } from './modules/monitoring/entities/monitoring-config.entity';
import { MonitoringScheduleWindow } from './modules/monitoring/entities/monitoring-schedule-window.entity';
import { ActivityPolicy } from './modules/activities/entities/activity-policy.entity';
import { Activity } from './modules/activities/entities/activity.entity';
import { CheckIn } from './modules/check-ins/entities/check-in.entity';
import { Location } from './modules/locations/entities/location.entity';
import { Incident } from './modules/incidents/entities/incident.entity';
import { IncidentEvent } from './modules/incidents/entities/incident-event.entity';
import { NotificationChannel } from './modules/notifications/entities/notification-channel.entity';
import { NotificationDelivery } from './modules/notifications/entities/notification-delivery.entity';
import { AuditLog } from './modules/audit/entities/audit-log.entity';

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
      envFilePath: '.env',
    }),
    ScheduleModule.forRoot(),
    TypeOrmModule.forRootAsync({
      imports: [ConfigModule],
      inject: [ConfigService],
      useFactory: (config: ConfigService) => ({
        type: 'postgres',
        host: config.get<string>('DB_HOST', 'localhost'),
        port: config.get<number>('DB_PORT', 5435),
        username: config.get<string>('DB_USERNAME', 'carely_user'),
        password: config.get<string>('DB_PASSWORD', 'carely_secret_password'),
        database: config.get<string>('DB_NAME', 'carely_db'),
        entities: [
          User,
          Device,
          PairingInvitation,
          MonitoringRelationship,
          MonitoringConfig,
          MonitoringScheduleWindow,
          ActivityPolicy,
          Activity,
          CheckIn,
          Location,
          Incident,
          IncidentEvent,
          NotificationChannel,
          NotificationDelivery,
          AuditLog,
        ],
        synchronize: false, // Use our explicit migrations as single source of truth
        logging: config.get<string>('NODE_ENV') === 'development' ? ['error', 'warn'] : false,
        extra: {
          max: Number(config.get('DB_POOL_MAX', 30)),
          min: Number(config.get('DB_POOL_MIN', 5)),
          idleTimeoutMillis: Number(config.get('DB_POOL_IDLE_TIMEOUT', 30000)),
          connectionTimeoutMillis: Number(config.get('DB_POOL_CONN_TIMEOUT', 5000)),
        },
      }),
    }),
    RedisModule,
    AuditModule,
    AuthModule,
    UsersModule,
    DevicesModule,
    MonitoringModule,
    ActivitiesModule,
    CheckInsModule,
    LocationsModule,
    IncidentsModule,
    NotificationsModule,
    MonitoringWorkerModule,
    RealtimeModule,
  ],
  controllers: [AppController],
})
export class AppModule {}
