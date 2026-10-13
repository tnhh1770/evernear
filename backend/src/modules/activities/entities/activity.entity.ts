import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  ManyToOne,
  JoinColumn,
  Index,
} from 'typeorm';
import { User } from '../../users/entities/user.entity';
import { Device } from '../../devices/entities/device.entity';
import { ActivityType } from '../../../common/enums';

@Entity('activities')
export class Activity {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'event_id', unique: true })
  @Index('idx_activities_event_id')
  eventId: string;

  @Column({ name: 'user_id' })
  @Index('idx_activities_user_occurred')
  userId: string;

  @ManyToOne(() => User, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'user_id' })
  user: User;

  @Column({ name: 'device_id' })
  deviceId: string;

  @ManyToOne(() => Device, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'device_id' })
  device: Device;

  @Column({ type: 'varchar', length: 50 })
  type: ActivityType;

  @Column({ type: 'numeric', precision: 3, scale: 2, default: 0.0 })
  weight: number;

  @Column({ type: 'numeric', precision: 3, scale: 2, default: 1.0 })
  confidence: number;

  @Column({ name: 'occurred_at', type: 'timestamptz' })
  occurredAt: Date;

  @Column({ name: 'received_at', type: 'timestamptz', default: () => 'NOW()' })
  receivedAt: Date;

  @Column({ default: 'MOBILE' })
  source: string;

  @Column({ type: 'jsonb', default: () => `'{}'::jsonb` })
  metadata: Record<string, any>;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;
}
