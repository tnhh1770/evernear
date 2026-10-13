import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
  ManyToOne,
  JoinColumn,
  Unique,
} from 'typeorm';
import { User } from '../../users/entities/user.entity';
import { DevicePlatform } from '../../../common/enums';

@Entity('devices')
@Unique(['userId', 'deviceUid'])
export class Device {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'user_id' })
  userId: string;

  @ManyToOne(() => User, (user) => user.devices, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'user_id' })
  user: User;

  @Column({ name: 'device_uid' })
  deviceUid: string;

  @Column({ type: 'varchar', length: 20 })
  platform: DevicePlatform;

  @Column({ name: 'device_name' })
  deviceName: string;

  @Column({ name: 'push_token', type: 'text', nullable: true })
  pushToken: string;

  @Column({ name: 'app_version', nullable: true })
  appVersion: string;

  @Column({ name: 'os_version', nullable: true })
  osVersion: string;

  @Column({ name: 'last_seen_at', type: 'timestamptz', default: () => 'NOW()' })
  lastSeenAt: Date;

  @Column({ name: 'last_heartbeat_at', type: 'timestamptz', nullable: true })
  lastHeartbeatAt: Date;

  @Column({ name: 'battery_level', type: 'int', nullable: true })
  batteryLevel: number;

  @Column({ name: 'is_charging', default: false })
  isCharging: boolean;

  @Column({ name: 'is_active', default: true })
  isActive: boolean;

  @Column({ name: 'revoked_at', type: 'timestamptz', nullable: true })
  revokedAt: Date;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at' })
  updatedAt: Date;
}
