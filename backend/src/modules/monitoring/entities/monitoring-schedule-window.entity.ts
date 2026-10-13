import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
  ManyToOne,
  JoinColumn,
} from 'typeorm';
import { MonitoringConfig } from './monitoring-config.entity';

@Entity('monitoring_schedule_windows')
export class MonitoringScheduleWindow {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'config_id' })
  configId: string;

  @ManyToOne(() => MonitoringConfig, (config) => config.scheduleWindows, {
    onDelete: 'CASCADE',
  })
  @JoinColumn({ name: 'config_id' })
  config: MonitoringConfig;

  @Column({ name: 'day_of_week', type: 'int' })
  dayOfWeek: number; // 0 = Sunday, 1 = Monday, ... 6 = Saturday

  @Column({ name: 'start_time', length: 5 })
  startTime: string; // HH:mm e.g. 07:00

  @Column({ name: 'end_time', length: 5 })
  endTime: string; // HH:mm e.g. 22:00

  @Column({ name: 'is_enabled', default: true })
  isEnabled: boolean;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at' })
  updatedAt: Date;
}
