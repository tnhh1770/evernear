import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { Incident } from './entities/incident.entity';
import { IncidentEvent } from './entities/incident-event.entity';
import { MonitoringRelationship } from '../monitoring/entities/monitoring-relationship.entity';
import { MonitoringConfig } from '../monitoring/entities/monitoring-config.entity';
import { IncidentsService } from './incidents.service';
import { IncidentEventService } from './incident-event.service';
import { RiskEvaluatorService } from './risk-evaluator.service';
import { IncidentsController } from './incidents.controller';
import { RealtimeModule } from '../realtime/realtime.module';
import { NotificationsModule } from '../notifications/notifications.module';

@Module({
  imports: [
    TypeOrmModule.forFeature([
      Incident,
      IncidentEvent,
      MonitoringRelationship,
      MonitoringConfig,
    ]),
    RealtimeModule,
    NotificationsModule,
  ],
  providers: [IncidentsService, IncidentEventService, RiskEvaluatorService],
  controllers: [IncidentsController],
  exports: [
    IncidentsService,
    IncidentEventService,
    RiskEvaluatorService,
    TypeOrmModule,
  ],
})
export class IncidentsModule {}
