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

@Entity('audit_logs')
export class AuditLog {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'user_id', nullable: true })
  @Index('idx_audit_logs_user_action')
  userId: string | null;

  @ManyToOne(() => User, { nullable: true, onDelete: 'SET NULL' })
  @JoinColumn({ name: 'user_id' })
  user: User | null;

  @Column({ length: 100 })
  action: string;

  @Column({ name: 'resource_type', length: 100 })
  resourceType: string;

  @Column({ name: 'resource_id', nullable: true })
  resourceId: string;

  @Column({ name: 'ip_address', nullable: true, length: 50 })
  ipAddress: string;

  @Column({ name: 'user_agent', type: 'text', nullable: true })
  userAgent: string;

  @Column({ type: 'jsonb', default: () => `'{}'::jsonb` })
  details: Record<string, any>;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;
}
