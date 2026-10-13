import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
  ManyToOne,
  JoinColumn,
} from 'typeorm';
import { MonitoringRelationship } from '../../monitoring/entities/monitoring-relationship.entity';
import { ActivityType } from '../../../common/enums';

@Entity('activity_policies')
export class ActivityPolicy {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'relationship_id', nullable: true })
  relationshipId: string | null;

  @ManyToOne(() => MonitoringRelationship, {
    nullable: true,
    onDelete: 'CASCADE',
  })
  @JoinColumn({ name: 'relationship_id' })
  relationship: MonitoringRelationship | null;

  @Column({ name: 'activity_type', type: 'varchar', length: 50 })
  activityType: ActivityType;

  @Column({ type: 'numeric', precision: 3, scale: 2, default: 0.5 })
  weight: number;

  @Column({ name: 'min_confidence', type: 'numeric', precision: 3, scale: 2, default: 0.5 })
  minConfidence: number;

  @Column({ name: 'cooldown_seconds', default: 60 })
  cooldownSeconds: number;

  @Column({ name: 'is_meaningful', default: true })
  isMeaningful: boolean;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at' })
  updatedAt: Date;
}
