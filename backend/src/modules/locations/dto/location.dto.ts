import {
  IsNotEmpty,
  IsNumber,
  IsOptional,
  IsString,
  IsUUID,
  Max,
  Min,
} from 'class-validator';

export class IngestLocationDto {
  @IsUUID()
  @IsNotEmpty()
  deviceId: string;

  @IsNumber()
  @Min(-90)
  @Max(90)
  latitude: number;

  @IsNumber()
  @Min(-180)
  @Max(180)
  longitude: number;

  @IsOptional()
  @IsNumber()
  accuracy?: number;

  @IsString()
  @IsNotEmpty()
  capturedAt: string;

  @IsOptional()
  @IsString()
  source?: string; // CHECK_IN, INCIDENT, MANUAL, ACTIVITY
}
