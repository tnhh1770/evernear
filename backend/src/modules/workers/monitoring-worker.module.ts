import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { MonitoringConfig } from '../monitoring/entities/monitoring-config.entity';
import { MonitoringRelationship } from '../monitoring/entities/monitoring-relationship.entity';
import { Device } from '../devices/entities/device.entity';
import { MonitoringWorkerService } from './monitoring-worker.service';
import { IncidentsModule } from '../incidents/incidents.module';
import { NotificationsModule } from '../notifications/notifications.module';
import { RealtimeModule } from '../realtime/realtime.module';

@Module({
  imports: [
    TypeOrmModule.forFeature([
      MonitoringConfig,
      MonitoringRelationship,
      Device,
    ]),
    IncidentsModule,
    NotificationsModule,
    RealtimeModule,
  ],
  providers: [MonitoringWorkerService],
  exports: [MonitoringWorkerService],
})
export class MonitoringWorkerModule {}
