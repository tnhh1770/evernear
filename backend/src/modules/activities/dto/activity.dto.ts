import {
  IsArray,
  IsEnum,
  IsNotEmpty,
  IsNumber,
  IsObject,
  IsOptional,
  IsString,
  IsUUID,
  Max,
  Min,
  ValidateNested,
} from 'class-validator';
import { Type } from 'class-transformer';
import { ActivityType } from '../../../common/enums';

export class IngestActivityDto {
  @IsUUID()
  @IsNotEmpty()
  eventId: string;

  @IsUUID()
  @IsNotEmpty()
  deviceId: string;

  @IsEnum(ActivityType)
  type: ActivityType;

  @IsString()
  @IsNotEmpty()
  occurredAt: string;

  @IsOptional()
  @IsString()
  source?: string;

  @IsOptional()
  @IsNumber()
  @Min(0)
  @Max(1)
  confidence?: number;

  @IsOptional()
  @IsObject()
  metadata?: Record<string, any>;
}

export class BatchIngestActivitiesDto {
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => IngestActivityDto)
  activities: IngestActivityDto[];
}
