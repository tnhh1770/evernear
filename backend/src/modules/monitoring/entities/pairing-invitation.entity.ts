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

export enum PairingInvitationRole {
  MONITORED = 'MONITORED',
  MONITOR = 'MONITOR',
}

export enum PairingInvitationStatus {
  ACTIVE = 'ACTIVE',
  ACCEPTED = 'ACCEPTED',
  EXPIRED = 'EXPIRED',
}

@Entity('pairing_invitations')
export class PairingInvitation {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'inviter_id' })
  inviterId: string;

  @ManyToOne(() => User, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'inviter_id' })
  inviter: User;

  @Index('idx_pairing_invitations_code', { unique: true })
  @Column({ name: 'invitation_code', length: 32, unique: true })
  invitationCode: string;

  @Column({
    type: 'varchar',
    length: 20,
    default: PairingInvitationRole.MONITORED,
  })
  role: PairingInvitationRole;

  @Column({ type: 'varchar', length: 100, nullable: true })
  label?: string;

  @Index('idx_pairing_invitations_status')
  @Column({
    type: 'varchar',
    length: 20,
    default: PairingInvitationStatus.ACTIVE,
  })
  status: PairingInvitationStatus;

  @Column({ name: 'expires_at', type: 'timestamptz' })
  expiresAt: Date;

  @Column({ type: 'uuid', name: 'accepted_by', nullable: true })
  acceptedById?: string;

  @ManyToOne(() => User, { onDelete: 'SET NULL', nullable: true })
  @JoinColumn({ name: 'accepted_by' })
  acceptedBy?: User;

  @Column({ name: 'accepted_at', type: 'timestamptz', nullable: true })
  acceptedAt?: Date;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at' })
  updatedAt: Date;
}
