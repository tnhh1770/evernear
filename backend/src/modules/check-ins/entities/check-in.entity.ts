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
import { MonitoringRelationship } from '../../monitoring/entities/monitoring-relationship.entity';

@Entity('check_ins')
export class CheckIn {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'event_id', unique: true })
  eventId: string;

  @Column({ name: 'user_id' })
  @Index('idx_check_ins_user_occurred')
  userId: string;

  @ManyToOne(() => User, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'user_id' })
  user: User;

  @Column({ name: 'device_id' })
  deviceId: string;

  @ManyToOne(() => Device, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'device_id' })
  device: Device;

  @Column({ name: 'relationship_id', nullable: true })
  relationshipId: string | null;

  @ManyToOne(() => MonitoringRelationship, {
    nullable: true,
    onDelete: 'SET NULL',
  })
  @JoinColumn({ name: 'relationship_id' })
  relationship: MonitoringRelationship | null;

  @Column({ name: 'occurred_at', type: 'timestamptz' })
  occurredAt: Date;

  @Column({ name: 'received_at', type: 'timestamptz', default: () => 'NOW()' })
  receivedAt: Date;

  @Column({ name: 'battery_level', type: 'int', nullable: true })
  batteryLevel: number;

  @Column({ type: 'text', nullable: true })
  note: string;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;
}
