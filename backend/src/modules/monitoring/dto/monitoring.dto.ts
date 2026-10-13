import {
  IsArray,
  IsBoolean,
  IsEmail,
  IsEnum,
  IsInt,
  IsNotEmpty,
  IsOptional,
  IsString,
  Matches,
  Max,
  Min,
  ValidateNested,
} from 'class-validator';
import { Type } from 'class-transformer';
import { RelationshipStatus } from '../../../common/enums';
import { PairingInvitationRole } from '../entities/pairing-invitation.entity';

export class CreateRelationshipDto {
  @IsEmail()
  @IsNotEmpty()
  monitoredUserEmail: string;
}

export class GenerateInviteCodeDto {
  @IsOptional()
  @IsEnum(PairingInvitationRole)
  role?: PairingInvitationRole;

  @IsOptional()
  @IsString()
  label?: string;
}

export class AcceptInvitationDto {
  @IsOptional()
  @IsString()
  invitationCode?: string;

  @IsOptional()
  @IsString()
  inviteCode?: string;
}

export class UpdateRelationshipDto {
  @IsEnum(RelationshipStatus)
  status: RelationshipStatus;
}

export class ScheduleWindowDto {
  @IsInt()
  @Min(0)
  @Max(6)
  dayOfWeek: number;

  @IsString()
  @Matches(/^([01]\d|2[0-3]):[0-5]\d$/, {
    message: 'Time must be in 24-hour HH:mm format',
  })
  startTime: string; // HH:mm

  @IsString()
  @Matches(/^([01]\d|2[0-3]):[0-5]\d$/, {
    message: 'Time must be in 24-hour HH:mm format',
  })
  endTime: string; // HH:mm

  @IsBoolean()
  isEnabled: boolean;
}

export class UpdateMonitoringConfigDto {
  @IsOptional()
  @IsBoolean()
  enabled?: boolean;

  @IsOptional()
  @IsString()
  timezone?: string;

  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(10080)
  inactivityThresholdMinutes?: number;

  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(1440)
  checkInGraceMinutes?: number;

  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(1440)
  warningEscalationMinutes?: number;

  @IsOptional()
  @IsBoolean()
  requireCheckIn?: boolean;

  @IsOptional()
  @IsBoolean()
  locationEnabled?: boolean;

  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  activityTypes?: string[];

  @IsOptional()
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => ScheduleWindowDto)
  scheduleWindows?: ScheduleWindowDto[];
}

export class PauseMonitoringDto {
  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(10080)
  durationMinutes?: number;
}
