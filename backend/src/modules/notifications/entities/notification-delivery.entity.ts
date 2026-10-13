import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
  ManyToOne,
  JoinColumn,
  Index,
} from 'typeorm';
import { User } from '../../users/entities/user.entity';
import { Incident } from '../../incidents/entities/incident.entity';
import {
  NotificationChannelType,
  NotificationDeliveryStatus,
} from '../../../common/enums';

@Entity('notification_deliveries')
@Index('idx_notification_deliveries_status', ['status', 'createdAt'])
export class NotificationDelivery {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'incident_id', nullable: true })
  incidentId: string | null;

  @ManyToOne(() => Incident, { nullable: true, onDelete: 'SET NULL' })
  @JoinColumn({ name: 'incident_id' })
  incident: Incident | null;

  @Column({ name: 'recipient_user_id' })
  recipientUserId: string;

  @ManyToOne(() => User, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'recipient_user_id' })
  recipientUser: User;

  @Column({
    type: 'varchar',
    length: 50,
  })
  channel: NotificationChannelType;

  @Column({ name: 'template_name', length: 100 })
  templateName: string;

  @Column({ name: 'recipient_target', type: 'text' })
  recipientTarget: string;

  @Column({ type: 'jsonb', default: () => `'{}'::jsonb` })
  payload: Record<string, any>;

  @Column({
    type: 'varchar',
    length: 50,
    default: NotificationDeliveryStatus.PENDING,
  })
  status: NotificationDeliveryStatus;

  @Column({ name: 'attempt_count', default: 0 })
  attemptCount: number;

  @Column({ name: 'max_attempts', default: 3 })
  maxAttempts: number;

  @Column({ name: 'sent_at', type: 'timestamptz', nullable: true })
  sentAt: Date;

  @Column({ name: 'delivered_at', type: 'timestamptz', nullable: true })
  deliveredAt: Date;

  @Column({ name: 'failed_at', type: 'timestamptz', nullable: true })
  failedAt: Date;

  @Column({ name: 'last_error', type: 'text', nullable: true })
  lastError: string;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at' })
  updatedAt: Date;
}
