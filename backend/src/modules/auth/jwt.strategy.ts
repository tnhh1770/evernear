import { Injectable, UnauthorizedException } from '@nestjs/common';
import { PassportStrategy } from '@nestjs/passport';
import { ExtractJwt, Strategy } from 'passport-jwt';
import { ConfigService } from '@nestjs/config';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { User } from '../users/entities/user.entity';

interface CachedUserEntry {
  user: User;
  expiresAt: number;
}

@Injectable()
export class JwtStrategy extends PassportStrategy(Strategy) {
  private static readonly userCache = new Map<string, CachedUserEntry>();
  private static readonly CACHE_TTL_MS = 60 * 1000; // 60s

  static invalidateUserCache(userId: string): void {
    JwtStrategy.userCache.delete(userId);
  }

  static clearCache(): void {
    JwtStrategy.userCache.clear();
  }

  constructor(
    private readonly configService: ConfigService,
    @InjectRepository(User)
    private readonly userRepository: Repository<User>,
  ) {
    super({
      jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(),
      ignoreExpiration: false,
      secretOrKey: configService.get<string>(
        'JWT_SECRET',
        'super_carely_jwt_secret_key_production_grade_32chars',
      ),
    });
  }

  async validate(payload: { sub: string; email: string }) {
    const now = Date.now();
    const cached = JwtStrategy.userCache.get(payload.sub);
    if (cached && cached.expiresAt > now) {
      return cached.user;
    }

    const user = await this.userRepository.findOne({
      where: { id: payload.sub },
    });
    if (!user) {
      JwtStrategy.userCache.delete(payload.sub);
      throw new UnauthorizedException('User not found or deactivated');
    }

    // Periodically prune stale entries if cache grows
    if (JwtStrategy.userCache.size > 2000) {
      for (const [key, entry] of JwtStrategy.userCache.entries()) {
        if (entry.expiresAt <= now) {
          JwtStrategy.userCache.delete(key);
        }
      }
    }

    JwtStrategy.userCache.set(payload.sub, {
      user,
      expiresAt: now + JwtStrategy.CACHE_TTL_MS,
    });

    return user;
  }
}

