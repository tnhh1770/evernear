import { Module } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { PassportModule } from '@nestjs/passport';
import { TypeOrmModule } from '@nestjs/typeorm';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { AuthService } from './auth.service';
import { AuthController } from './auth.controller';
import { JwtStrategy } from './jwt.strategy';
import { FirebaseTokenVerifierService } from './firebase-token-verifier.service';
import { User } from '../users/entities/user.entity';

@Module({
  imports: [
    TypeOrmModule.forFeature([User]),
    PassportModule.register({ defaultStrategy: 'jwt' }),
    JwtModule.registerAsync({
      imports: [ConfigModule],
      inject: [ConfigService],
      useFactory: (config: ConfigService) => ({
        secret: config.get<string>(
          'JWT_SECRET',
          'super_carely_jwt_secret_key_production_grade_32chars',
        ),
        signOptions: {
          expiresIn: (config.get<string>('JWT_EXPIRATION', '7d') as any),
        },
      }),
    }),
  ],
  providers: [AuthService, JwtStrategy, FirebaseTokenVerifierService],
  controllers: [AuthController],
  exports: [AuthService, JwtStrategy, FirebaseTokenVerifierService, PassportModule, JwtModule],
})
export class AuthModule {}
