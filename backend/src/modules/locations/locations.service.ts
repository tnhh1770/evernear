import {
  Injectable,
  ForbiddenException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Location } from './entities/location.entity';
import { IngestLocationDto } from './dto/location.dto';
import { DevicesService } from '../devices/devices.service';
import { MonitoringRelationship } from '../monitoring/entities/monitoring-relationship.entity';
import { RelationshipStatus } from '../../common/enums';

@Injectable()
export class LocationsService {
  constructor(
    @InjectRepository(Location)
    private readonly locationRepo: Repository<Location>,
    @InjectRepository(MonitoringRelationship)
    private readonly relationshipRepo: Repository<MonitoringRelationship>,
    private readonly devicesService: DevicesService,
  ) {}

  async recordLocation(userId: string, dto: IngestLocationDto): Promise<Location> {
    const device = await this.devicesService.verifyActiveDevice(userId, dto.deviceId);

    const location = this.locationRepo.create({
      userId,
      deviceId: device.id,
      latitude: dto.latitude,
      longitude: dto.longitude,
      accuracy: dto.accuracy,
      capturedAt: new Date(dto.capturedAt),
      source: dto.source || 'MANUAL',
    });

    return this.locationRepo.save(location);
  }

  async getLatestLocation(requestingUserId: string, targetUserId: string): Promise<Location | null> {
    // If requesting own location
    if (requestingUserId === targetUserId) {
      return this.locationRepo.findOne({
        where: { userId: targetUserId },
        order: { capturedAt: 'DESC' },
      });
    }

    // Verify monitoring relationship with locationEnabled = true
    const rel = await this.relationshipRepo.findOne({
      where: {
        monitorId: requestingUserId,
        monitoredUserId: targetUserId,
        status: RelationshipStatus.ACCEPTED,
      },
      relations: { config: true },
    });

    if (!rel) {
      throw new ForbiddenException('No active monitoring relationship with this user');
    }

    if (!rel.config || !rel.config.locationEnabled) {
      throw new ForbiddenException('Location sharing is disabled in the monitoring policy for this relationship');
    }

    return this.locationRepo.findOne({
      where: { userId: targetUserId },
      order: { capturedAt: 'DESC' },
    });
  }
}
