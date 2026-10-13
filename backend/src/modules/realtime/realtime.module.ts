import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { RedisModule } from '../../common/redis/redis.module';
import { AuthModule } from '../auth/auth.module';
import { MonitoringRelationship } from '../monitoring/entities/monitoring-relationship.entity';
import { RealtimeService } from './realtime.service';
import { RealtimeGateway } from './realtime.gateway';
import { RealtimeController } from './realtime.controller';

@Module({
  imports: [
    TypeOrmModule.forFeature([MonitoringRelationship]),
    RedisModule,
    AuthModule,
  ],
  providers: [RealtimeService, RealtimeGateway],
  controllers: [RealtimeController],
  exports: [RealtimeService],
})
export class RealtimeModule {}
