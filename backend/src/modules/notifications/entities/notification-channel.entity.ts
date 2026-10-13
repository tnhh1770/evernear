import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
} from 'typeorm';
import { NotificationChannelType } from '../../../common/enums';

@Entity('notification_channels')
export class NotificationChannel {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({
    type: 'varchar',
    length: 50,
    unique: true,
  })
  name: NotificationChannelType;

  @Column({ name: 'is_active', default: true })
  isActive: boolean;

  @Column({ type: 'jsonb', default: () => `'{}'::jsonb` })
  config: Record<string, any>;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;
}
