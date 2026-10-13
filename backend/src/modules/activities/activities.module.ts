import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { Activity } from './entities/activity.entity';
import { ActivityPolicy } from './entities/activity-policy.entity';
import { MonitoringConfig } from '../monitoring/entities/monitoring-config.entity';
import { MonitoringRelationship } from '../monitoring/entities/monitoring-relationship.entity';
import { ActivityService } from './activity.service';
import { ActivityPolicyService } from './activity-policy.service';
import { ActivitiesController } from './activities.controller';
import { DevicesModule } from '../devices/devices.module';
import { RealtimeModule } from '../realtime/realtime.module';

@Module({
  imports: [
    TypeOrmModule.forFeature([
      Activity,
      ActivityPolicy,
      MonitoringConfig,
      MonitoringRelationship,
    ]),
    DevicesModule,
    RealtimeModule,
  ],
  providers: [ActivityService, ActivityPolicyService],
  controllers: [ActivitiesController],
  exports: [ActivityService, ActivityPolicyService, TypeOrmModule],
})
export class ActivitiesModule {}
