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

@Entity('locations')
export class Location {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'user_id' })
  @Index('idx_locations_user_captured')
  userId: string;

  @ManyToOne(() => User, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'user_id' })
  user: User;

  @Column({ name: 'device_id' })
  deviceId: string;

  @ManyToOne(() => Device, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'device_id' })
  device: Device;

  @Column({ type: 'numeric', precision: 10, scale: 7 })
  latitude: number;

  @Column({ type: 'numeric', precision: 10, scale: 7 })
  longitude: number;

  @Column({ type: 'numeric', precision: 8, scale: 2, nullable: true })
  accuracy: number;

  @Column({ name: 'captured_at', type: 'timestamptz' })
  capturedAt: Date;

  @Column({ default: 'CHECK_IN' })
  source: string;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;
}
