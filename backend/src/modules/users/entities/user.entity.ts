import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
  DeleteDateColumn,
  OneToMany,
} from 'typeorm';
import { Device } from '../../devices/entities/device.entity';
import { MonitoringRelationship } from '../../monitoring/entities/monitoring-relationship.entity';

@Entity('users')
export class User {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ unique: true })
  email: string;

  @Column({ name: 'password_hash', select: false })
  passwordHash: string;

  @Column({ name: 'display_name' })
  displayName: string;

  @Column({ name: 'phone_number', nullable: true })
  phoneNumber: string;

  @Column({ name: 'avatar_url', nullable: true })
  avatarUrl: string;

  @Column({ default: 'Asia/Ho_Chi_Minh' })
  timezone: string;

  @Column({ name: 'preferred_language', default: 'vi' })
  preferredLanguage: string;

  @Column({ type: 'varchar', length: 255, name: 'google_id', nullable: true })
  googleId: string | null;

  @Column({ type: 'varchar', length: 255, name: 'apple_id', nullable: true })
  appleId: string | null;

  @Column({ type: 'varchar', length: 50, name: 'auth_provider', default: 'LOCAL' })
  authProvider: string;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at' })
  updatedAt: Date;

  @DeleteDateColumn({ name: 'deleted_at', nullable: true })
  deletedAt: Date;

  @OneToMany(() => Device, (device) => device.user)
  devices: Device[];

  @OneToMany(() => MonitoringRelationship, (rel) => rel.monitor)
  monitoringList: MonitoringRelationship[];

  @OneToMany(() => MonitoringRelationship, (rel) => rel.monitoredUser)
  monitoredByList: MonitoringRelationship[];
}
