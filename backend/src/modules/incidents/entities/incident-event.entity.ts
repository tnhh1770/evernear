import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  ManyToOne,
  JoinColumn,
  Index,
} from 'typeorm';
import { Incident } from './incident.entity';
import { IncidentEventType } from '../../../common/enums';

@Entity('incident_events')
export class IncidentEvent {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'incident_id' })
  @Index('idx_incident_events_incident')
  incidentId: string;

  @ManyToOne(() => Incident, (incident) => incident.events, {
    onDelete: 'CASCADE',
  })
  @JoinColumn({ name: 'incident_id' })
  incident: Incident;

  @Column({ type: 'varchar', length: 50 })
  type: IncidentEventType;

  @Column({ type: 'timestamptz', default: () => 'NOW()' })
  timestamp: Date;

  @Column({ type: 'jsonb', default: () => `'{}'::jsonb` })
  metadata: Record<string, any>;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;
}
