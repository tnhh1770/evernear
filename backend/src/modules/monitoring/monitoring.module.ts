import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { MonitoringRelationship } from './entities/monitoring-relationship.entity';
import { MonitoringConfig } from './entities/monitoring-config.entity';
import { MonitoringScheduleWindow } from './entities/monitoring-schedule-window.entity';
import { PairingInvitation } from './entities/pairing-invitation.entity';
import { User } from '../users/entities/user.entity';
import { MonitoringService } from './monitoring.service';
import { MonitoringController } from './monitoring.controller';
import { RealtimeModule } from '../realtime/realtime.module';

@Module({
  imports: [
    TypeOrmModule.forFeature([
      PairingInvitation,
      MonitoringRelationship,
      MonitoringConfig,
      MonitoringScheduleWindow,
      User,
    ]),
    RealtimeModule,
  ],
  providers: [MonitoringService],
  controllers: [MonitoringController],
  exports: [MonitoringService, TypeOrmModule],
})
export class MonitoringModule {}
