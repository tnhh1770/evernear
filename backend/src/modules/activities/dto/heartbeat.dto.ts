import {
  IsBoolean,
  IsNotEmpty,
  IsNumber,
  IsOptional,
  IsString,
  IsUUID,
  Max,
  Min,
} from 'class-validator';

export class HeartbeatDto {
  @IsUUID()
  @IsNotEmpty()
  deviceId: string;

  @IsString()
  @IsNotEmpty()
  occurredAt: string;

  @IsOptional()
  @IsString()
  appState?: string; // background, foreground, inactive

  @IsOptional()
  @IsNumber()
  @Min(0)
  @Max(100)
  batteryLevel?: number;

  @IsOptional()
  @IsBoolean()
  isCharging?: boolean;

  @IsOptional()
  location?: {
    latitude: number;
    longitude: number;
    accuracy?: number;
  } | null;
}
