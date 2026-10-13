import {
  IsEmail,
  IsNotEmpty,
  IsOptional,
  IsString,
  MinLength,
  ValidateNested,
} from 'class-validator';
import { Type } from 'class-transformer';

export class RegisterDto {
  @IsEmail()
  email: string;

  @IsString()
  @MinLength(6)
  password: string;

  @IsString()
  @IsNotEmpty()
  displayName: string;

  @IsOptional()
  @IsString()
  phoneNumber?: string;

  @IsOptional()
  @IsString()
  timezone?: string;

  @IsOptional()
  @IsString()
  preferredLanguage?: string;
}

export class LoginDto {
  @IsEmail()
  email: string;

  @IsString()
  @IsNotEmpty()
  password: string;
}

export class RefreshTokenDto {
  @IsString()
  @IsNotEmpty()
  refreshToken: string;
}

export class GoogleAuthDto {
  @IsString()
  @IsNotEmpty()
  idToken: string;

  @IsOptional()
  @IsEmail()
  email?: string;

  @IsOptional()
  @IsString()
  displayName?: string;

  @IsOptional()
  @IsString()
  avatarUrl?: string;

  @IsOptional()
  @IsString()
  preferredLanguage?: string;
}

export class AppleFullNameDto {
  @IsOptional()
  @IsString()
  firstName?: string;

  @IsOptional()
  @IsString()
  lastName?: string;
}

export class AppleAuthDto {
  @IsString()
  @IsNotEmpty()
  identityToken: string;

  @IsOptional()
  @IsString()
  authorizationCode?: string;

  @IsOptional()
  @IsEmail()
  email?: string;

  @IsOptional()
  @ValidateNested()
  @Type(() => AppleFullNameDto)
  fullName?: AppleFullNameDto;

  @IsOptional()
  @IsString()
  displayName?: string;

  @IsOptional()
  @IsString()
  preferredLanguage?: string;
}

export class ChangePasswordDto {
  @IsString()
  @IsNotEmpty()
  oldPassword: string;

  @IsString()
  @MinLength(6)
  newPassword: string;
}

export class FirebaseAuthDto {
  @IsString()
  @IsNotEmpty()
  idToken: string;

  @IsOptional()
  @IsString()
  preferredLanguage?: string;
}

