import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { IncidentEvent } from './entities/incident-event.entity';
import { IncidentEventType } from '../../common/enums';

@Injectable()
export class IncidentEventService {
  constructor(
    @InjectRepository(IncidentEvent)
    private readonly eventRepo: Repository<IncidentEvent>,
  ) {}

  async logEvent(
    incidentId: string,
    type: IncidentEventType,
    metadata: Record<string, any> = {},
  ): Promise<IncidentEvent> {
    const event = this.eventRepo.create({
      incidentId,
      type,
      timestamp: new Date(),
      metadata,
    });
    return this.eventRepo.save(event);
  }

  async getEventsForIncident(incidentId: string): Promise<IncidentEvent[]> {
    return this.eventRepo.find({
      where: { incidentId },
      order: { timestamp: 'ASC' },
    });
  }
}
