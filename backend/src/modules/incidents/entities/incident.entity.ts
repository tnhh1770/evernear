import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
  ManyToOne,
  OneToMany,
  JoinColumn,
  Index,
} from 'typeorm';
import { User } from '../../users/entities/user.entity';
import { MonitoringRelationship } from '../../monitoring/entities/monitoring-relationship.entity';
import { Location } from '../../locations/entities/location.entity';
import { IncidentEvent } from './incident-event.entity';
import { IncidentStatus, IncidentReason } from '../../../common/enums';

@Entity('incidents')
@Index('idx_incidents_user_status', ['userId', 'status'])
@Index('idx_incidents_status_next_action', ['status', 'nextActionAt'])
export class Incident {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'user_id' })
  userId: string;

  @ManyToOne(() => User, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'user_id' })
  user: User;

  @Column({ name: 'relationship_id' })
  relationshipId: string;

  @ManyToOne(() => MonitoringRelationship, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'relationship_id' })
  relationship: MonitoringRelationship;

  @Column({
    type: 'varchar',
    length: 50,
    default: IncidentStatus.OPEN,
  })
  status: IncidentStatus;

  @Column({
    type: 'varchar',
    length: 50,
  })
  reason: IncidentReason;

  @Column({ name: 'risk_score', default: 0 })
  riskScore: number;

  @Column({ name: 'detected_at', type: 'timestamptz' })
  detectedAt: Date;

  @Column({ name: 'last_activity_at', type: 'timestamptz', nullable: true })
  lastActivityAt: Date;

  @Column({ name: 'last_heartbeat_at', type: 'timestamptz', nullable: true })
  lastHeartbeatAt: Date;

  @Column({ name: 'last_location_id', nullable: true })
  lastLocationId: string | null;

  @ManyToOne(() => Location, { nullable: true, onDelete: 'SET NULL' })
  @JoinColumn({ name: 'last_location_id' })
  lastLocation: Location | null;

  @Column({ name: 'check_in_deadline', type: 'timestamptz', nullable: true })
  checkInDeadline: Date;

  @Column({ name: 'escalated_at', type: 'timestamptz', nullable: true })
  escalatedAt: Date;

  @Column({ name: 'acknowledged_at', type: 'timestamptz', nullable: true })
  acknowledgedAt: Date;

  @Column({ name: 'acknowledged_by', nullable: true })
  acknowledgedBy: string | null;

  @ManyToOne(() => User, { nullable: true, onDelete: 'SET NULL' })
  @JoinColumn({ name: 'acknowledged_by' })
  acknowledgedByUser: User | null;

  @Column({ name: 'resolved_at', type: 'timestamptz', nullable: true })
  resolvedAt: Date;

  @Column({ name: 'resolved_by', nullable: true })
  resolvedBy: string | null;

  @ManyToOne(() => User, { nullable: true, onDelete: 'SET NULL' })
  @JoinColumn({ name: 'resolved_by' })
  resolvedByUser: User | null;

  @Column({ name: 'next_action_at', type: 'timestamptz', nullable: true })
  nextActionAt: Date;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at' })
  updatedAt: Date;

  @OneToMany(() => IncidentEvent, (event) => event.incident, { cascade: true })
  events: IncidentEvent[];
}
