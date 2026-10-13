import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
  ManyToOne,
  OneToOne,
  JoinColumn,
  Unique,
} from 'typeorm';
import { User } from '../../users/entities/user.entity';
import { RelationshipStatus } from '../../../common/enums';
import { MonitoringConfig } from './monitoring-config.entity';

@Entity('monitoring_relationships')
@Unique(['monitorId', 'monitoredUserId'])
export class MonitoringRelationship {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'monitor_id' })
  monitorId: string;

  @ManyToOne(() => User, (user) => user.monitoringList, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'monitor_id' })
  monitor: User;

  @Column({ name: 'monitored_user_id' })
  monitoredUserId: string;

  @ManyToOne(() => User, (user) => user.monitoredByList, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'monitored_user_id' })
  monitoredUser: User;

  @Column({
    type: 'varchar',
    length: 50,
    default: RelationshipStatus.PENDING,
  })
  status: RelationshipStatus;

  @Column({ name: 'invitation_code', nullable: true, length: 32 })
  invitationCode: string;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at' })
  updatedAt: Date;

  @OneToOne(() => MonitoringConfig, (config) => config.relationship)
  config: MonitoringConfig;
}
