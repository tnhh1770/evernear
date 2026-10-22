import {
  IsBoolean,
  IsEnum,
  IsNotEmpty,
  IsNumber,
  IsOptional,
  IsString,
  Max,
  Min,
} from 'class-validator';
import { DevicePlatform } from '../../../common/enums';

export class RegisterDeviceDto {
  @IsString()
  @IsNotEmpty()
  deviceUid: string;

  @IsEnum(DevicePlatform)
  platform: DevicePlatform;

  @IsString()
  @IsNotEmpty()
  deviceName: string;

  @IsOptional()
  @IsString()
  pushToken?: string;

  @IsOptional()
  @IsString()
  fcmToken?: string;

  @IsOptional()
  @IsString()
  appVersion?: string;

  @IsOptional()
  @IsString()
  osVersion?: string;

  @IsOptional()
  @IsNumber()
  @Min(0)
  @Max(100)
  batteryLevel?: number;

  @IsOptional()
  @IsBoolean()
  isCharging?: boolean;
}

export class UpdateDeviceTokenDto {
  @IsOptional()
  @IsString()
  pushToken?: string;

  @IsOptional()
  @IsString()
  fcmToken?: string;
}
