import {
  IsInt,
  IsNotEmpty,
  IsOptional,
  IsString,
  IsUUID,
  Max,
  Min,
} from 'class-validator';

export class CreateCheckInDto {
  @IsUUID()
  @IsNotEmpty()
  eventId: string;

  @IsUUID()
  @IsNotEmpty()
  deviceId: string;

  @IsString()
  @IsNotEmpty()
  occurredAt: string;

  @IsOptional()
  @IsUUID()
  relationshipId?: string;

  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(100)
  batteryLevel?: number;

  @IsOptional()
  @IsString()
  note?: string;

  @IsOptional()
  location?: {
    latitude: number;
    longitude: number;
    accuracy?: number;
  };
}
