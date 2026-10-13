import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
  OneToOne,
  OneToMany,
  JoinColumn,
} from 'typeorm';
import { MonitoringRelationship } from './monitoring-relationship.entity';
import { MonitoringScheduleWindow } from './monitoring-schedule-window.entity';
import { MonitoringState } from '../../../common/enums';

@Entity('monitoring_configs')
export class MonitoringConfig {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'relationship_id', unique: true })
  relationshipId: string;

  @OneToOne(() => MonitoringRelationship, (rel) => rel.config, {
    onDelete: 'CASCADE',
  })
  @JoinColumn({ name: 'relationship_id' })
  relationship: MonitoringRelationship;

  @Column({ default: true })
  enabled: boolean;

  @Column({ default: 'Asia/Ho_Chi_Minh' })
  timezone: string;

  @Column({ name: 'inactivity_threshold_minutes', default: 480 })
  inactivityThresholdMinutes: number;

  @Column({ name: 'check_in_grace_minutes', default: 30 })
  checkInGraceMinutes: number;

  @Column({ name: 'warning_escalation_minutes', default: 15 })
  warningEscalationMinutes: number;

  @Column({ name: 'require_check_in', default: true })
  requireCheckIn: boolean;

  @Column({ name: 'location_enabled', default: false })
  locationEnabled: boolean;

  @Column({
    name: 'activity_types',
    type: 'jsonb',
    default: () => `'["APP_OPEN", "APP_FOREGROUND", "CHECK_IN", "STEP_DETECTED", "SCREEN_INTERACTION"]'`,
  })
  activityTypes: string[];

  @Column({
    name: 'escalation_policy',
    type: 'jsonb',
    default: () =>
      `'{"stages": [{"delayMinutes": 0, "action": "CHECK_IN_PUSH"}, {"delayMinutes": 15, "action": "REMINDER_PUSH"}, {"delayMinutes": 30, "action": "NOTIFY_MONITOR"}]}'`,
  })
  escalationPolicy: Record<string, any>;

  @Column({
    name: 'current_state',
    type: 'varchar',
    length: 50,
    default: MonitoringState.ACTIVE,
  })
  currentState: MonitoringState;

  @Column({
    name: 'last_meaningful_activity_at',
    type: 'timestamptz',
    default: () => 'NOW()',
  })
  lastMeaningfulActivityAt: Date;

  @Column({
    name: 'next_evaluation_at',
    type: 'timestamptz',
    default: () => `NOW() + INTERVAL '480 minutes'`,
  })
  nextEvaluationAt: Date;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at' })
  updatedAt: Date;

  @OneToMany(() => MonitoringScheduleWindow, (w) => w.config, {
    cascade: true,
  })
  scheduleWindows: MonitoringScheduleWindow[];
}
