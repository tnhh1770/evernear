import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { CheckIn } from './entities/check-in.entity';
import { Activity } from '../activities/entities/activity.entity';
import { MonitoringConfig } from '../monitoring/entities/monitoring-config.entity';
import { MonitoringRelationship } from '../monitoring/entities/monitoring-relationship.entity';
import { Incident } from '../incidents/entities/incident.entity';
import { IncidentEvent } from '../incidents/entities/incident-event.entity';
import { Location } from '../locations/entities/location.entity';
import { User } from '../users/entities/user.entity';
import { CheckInsService } from './check-ins.service';
import { CheckInsController } from './check-ins.controller';
import { DevicesModule } from '../devices/devices.module';
import { NotificationsModule } from '../notifications/notifications.module';
import { RealtimeModule } from '../realtime/realtime.module';

@Module({
  imports: [
    TypeOrmModule.forFeature([
      CheckIn,
      Activity,
      MonitoringConfig,
      MonitoringRelationship,
      Incident,
      IncidentEvent,
      Location,
      User,
    ]),
    DevicesModule,
    NotificationsModule,
    RealtimeModule,
  ],
  providers: [CheckInsService],
  controllers: [CheckInsController],
  exports: [CheckInsService, TypeOrmModule],
})
export class CheckInsModule {}
