import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { Location } from './entities/location.entity';
import { MonitoringRelationship } from '../monitoring/entities/monitoring-relationship.entity';
import { LocationsService } from './locations.service';
import { LocationsController } from './locations.controller';
import { DevicesModule } from '../devices/devices.module';

@Module({
  imports: [
    TypeOrmModule.forFeature([Location, MonitoringRelationship]),
    DevicesModule,
  ],
  providers: [LocationsService],
  controllers: [LocationsController],
  exports: [LocationsService, TypeOrmModule],
})
export class LocationsModule {}
