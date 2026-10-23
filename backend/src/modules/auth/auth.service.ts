import {
  Injectable,
  ConflictException,
  UnauthorizedException,
  BadRequestException,
  NotFoundException,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import * as bcrypt from 'bcrypt';
import * as crypto from 'crypto';
import { v4 as uuidv4 } from 'uuid';
import { User } from '../users/entities/user.entity';
import {
  RegisterDto,
  LoginDto,
  GoogleAuthDto,
  AppleAuthDto,
  ChangePasswordDto,
  FirebaseAuthDto,
} from './dto/auth.dto';
import { RedisService } from '../../common/redis/redis.service';
import { AuthProvider } from '../../common/enums';
import { FirebaseTokenVerifierService } from './firebase-token-verifier.service';
import { JwtStrategy } from './jwt.strategy';

@Injectable()
export class AuthService {
  private appleJwksCache: Record<string, any> | null = null;
  private appleJwksExpiresAt = 0;

  constructor(
    @InjectRepository(User)
    private readonly userRepository: Repository<User>,
    private readonly jwtService: JwtService,
    private readonly redisService: RedisService,
    private readonly firebaseVerifier: FirebaseTokenVerifierService,
  ) {}

  async register(dto: RegisterDto) {
    const existing = await this.userRepository.findOne({
      where: { email: dto.email.toLowerCase().trim() },
    });
    if (existing) {
      throw new ConflictException('Email already registered');
    }

    if (dto.phoneNumber && dto.phoneNumber.trim().length > 0) {
      const cleanPhone = dto.phoneNumber.trim();
      const existingPhone = await this.userRepository.findOne({
        where: { phoneNumber: cleanPhone },
      });
      if (existingPhone) {
        throw new ConflictException('Phone number already registered');
      }
    }

    const salt = await bcrypt.genSalt(10);
    const passwordHash = await bcrypt.hash(dto.password, salt);

    const user = this.userRepository.create({
      email: dto.email.toLowerCase().trim(),
      passwordHash,
      displayName: dto.displayName.trim(),
      phoneNumber: dto.phoneNumber?.trim() || null as any,
      timezone: dto.timezone || 'Asia/Ho_Chi_Minh',
      preferredLanguage: dto.preferredLanguage?.trim().toLowerCase() || 'vi',
    });

    const saved = await this.userRepository.save(user);
    return this.buildAuthResponse(saved);
  }

  async login(dto: LoginDto) {
    const user = await this.userRepository
      .createQueryBuilder('user')
      .addSelect('user.passwordHash')
      .where('user.email = :email', { email: dto.email.toLowerCase().trim() })
      .getOne();

    if (!user) {
      throw new UnauthorizedException('Invalid credentials');
    }

    const match = await bcrypt.compare(dto.password, user.passwordHash);
    if (!match) {
      throw new UnauthorizedException('Invalid credentials');
    }

    return this.buildAuthResponse(user);
  }

  async refreshToken(refreshToken: string) {
    try {
      const payload = this.jwtService.verify(refreshToken);
      const user = await this.userRepository.findOne({
        where: { id: payload.sub },
      });
      if (!user) {
        throw new UnauthorizedException('User not found');
      }
      return await this.generateTokens(user);
    } catch {
      throw new UnauthorizedException('Invalid or expired refresh token');
    }
  }

  async logout(userId: string) {
    // Invalidate user sessions in redis if cached
    await this.redisService.del(`user:session:${userId}`);
    JwtStrategy.invalidateUserCache(userId);
    return { success: true };
  }

  async getProfile(userId: string) {
    const user = await this.userRepository.findOne({
      where: { id: userId },
    });
    if (!user) {
      throw new UnauthorizedException('User not found');
    }
    return user;
  }

  async changePassword(userId: string, dto: ChangePasswordDto) {
    const user = await this.userRepository
      .createQueryBuilder('user')
      .addSelect('user.passwordHash')
      .where('user.id = :id', { id: userId })
      .getOne();

    if (!user) {
      throw new NotFoundException('User not found');
    }

    if (!user.passwordHash) {
      throw new BadRequestException('Social accounts do not use a separate password');
    }

    const isMatch = await bcrypt.compare(dto.oldPassword, user.passwordHash);
    if (!isMatch) {
      throw new UnauthorizedException('Current password is incorrect');
    }

    const salt = await bcrypt.genSalt(10);
    user.passwordHash = await bcrypt.hash(dto.newPassword, salt);
    await this.userRepository.save(user);
    JwtStrategy.invalidateUserCache(userId);

    return { success: true, message: 'Password changed successfully' };
  }

  /**
   * Google Sign-In & Account Linking
   */
  async googleLogin(dto: GoogleAuthDto) {
    const verified = await this.verifyGoogleToken(dto);
    const googleId = verified.googleId;
    const email = verified.email.toLowerCase().trim();

    // 1. Check if user already exists by googleId (Returning Google User)
    let user = await this.userRepository.findOne({
      where: { googleId },
    });

    if (user) {
      if (verified.picture && !user.avatarUrl) {
        user.avatarUrl = verified.picture;
        await this.userRepository.save(user);
      }
      return this.buildAuthResponse(user);
    }

    // 2. Check if user already exists by verified email (Account Linking)
    user = await this.userRepository.findOne({
      where: { email },
    });

    if (user) {
      // Auto-link Google ID without overwriting existing password hash
      user.googleId = googleId;
      if (verified.picture && !user.avatarUrl) {
        user.avatarUrl = verified.picture;
      }
      user = await this.userRepository.save(user);
      return this.buildAuthResponse(user);
    }

    // 3. New User Registration via Google
    const randomPassword = uuidv4();
    const salt = await bcrypt.genSalt(10);
    const passwordHash = await bcrypt.hash(randomPassword, salt);

    user = this.userRepository.create({
      email,
      passwordHash,
      displayName: verified.name || email.split('@')[0],
      avatarUrl: verified.picture || undefined,
      googleId,
      appleId: undefined,
      authProvider: AuthProvider.GOOGLE,
      timezone: 'Asia/Ho_Chi_Minh',
      preferredLanguage: dto.preferredLanguage?.trim().toLowerCase() || 'vi',
    });

    const saved = await this.userRepository.save(user);
    return this.buildAuthResponse(saved);
  }

  /**
   * Apple Sign-In & Account Linking
   */
  async appleLogin(dto: AppleAuthDto) {
    const verified = await this.verifyAppleToken(dto);
    const appleId = verified.appleId;

    // 1. Check if user already exists by appleId (Returning Apple User)
    // In subsequent Apple logins, Apple does not resend the user's email; match on appleId
    let user = await this.userRepository.findOne({
      where: { appleId },
    });

    if (user) {
      return this.buildAuthResponse(user);
    }

    // 2. First-time Apple Sign-In: Email is required
    const email = (verified.email || dto.email)?.toLowerCase().trim();
    if (!email) {
      throw new BadRequestException(
        'Email is required for initial Apple account registration',
      );
    }

    // Check if user already exists by email (Account Linking)
    user = await this.userRepository.findOne({
      where: { email },
    });

    if (user) {
      // Auto-link Apple ID without overwriting existing password hash
      user.appleId = appleId;
      if (verified.name && (!user.displayName || user.displayName === email.split('@')[0])) {
        user.displayName = verified.name;
      }
      user = await this.userRepository.save(user);
      return this.buildAuthResponse(user);
    }

    // 3. New User Registration via Apple
    const randomPassword = uuidv4();
    const salt = await bcrypt.genSalt(10);
    const passwordHash = await bcrypt.hash(randomPassword, salt);

    user = this.userRepository.create({
      email,
      passwordHash,
      displayName: verified.name || email.split('@')[0],
      googleId: undefined,
      appleId,
      authProvider: AuthProvider.APPLE,
      timezone: 'Asia/Ho_Chi_Minh',
      preferredLanguage: dto.preferredLanguage?.trim().toLowerCase() || 'vi',
    });

    const saved = await this.userRepository.save(user);
    return this.buildAuthResponse(saved);
  }

  /**
   * Firebase Sign-In & Account Linking (Google & Apple via Firebase OIDC)
   * Completely zero-admin-dependency: validates Google public certs
   */
  async firebaseLogin(dto: FirebaseAuthDto) {
    const verified = await this.firebaseVerifier.verifyIdToken(dto.idToken);
    const isApple = verified.provider.includes('apple') || Boolean(verified.appleId);
    const providerEnum = isApple ? AuthProvider.APPLE : AuthProvider.GOOGLE;
    const providerId = verified.appleId || verified.googleId || verified.uid;

    // 1. Check if user already exists by appleId or googleId
    let user: User | null = null;
    if (isApple && verified.appleId) {
      user = await this.userRepository.findOne({
        where: { appleId: verified.appleId },
      });
    } else if (!isApple && verified.googleId) {
      user = await this.userRepository.findOne({
        where: { googleId: verified.googleId },
      });
    }

    if (user) {
      if (verified.picture && !user.avatarUrl) {
        user.avatarUrl = verified.picture;
        await this.userRepository.save(user);
      }
      return this.buildAuthResponse(user);
    }

    // 2. Check if user already exists by verified email (Account Linking)
    const email = verified.email?.toLowerCase().trim();
    if (!email) {
      throw new BadRequestException('Email is required for initial social registration');
    }

    user = await this.userRepository.findOne({
      where: { email },
    });

    if (user) {
      // Auto-link social identity without corrupting existing password hash
      if (isApple) {
        user.appleId = verified.appleId || providerId;
      } else {
        user.googleId = verified.googleId || providerId;
      }
      if (verified.picture && !user.avatarUrl) {
        user.avatarUrl = verified.picture;
      }
      if (verified.name && (!user.displayName || user.displayName === email.split('@')[0])) {
        user.displayName = verified.name;
      }
      user = await this.userRepository.save(user);
      return this.buildAuthResponse(user);
    }

    // 3. New User Registration via Firebase
    const randomPassword = uuidv4();
    const salt = await bcrypt.genSalt(10);
    const passwordHash = await bcrypt.hash(randomPassword, salt);

    user = this.userRepository.create({
      email,
      passwordHash,
      displayName: verified.name || email.split('@')[0],
      avatarUrl: verified.picture || undefined,
      googleId: isApple ? undefined : (verified.googleId || providerId),
      appleId: isApple ? (verified.appleId || providerId) : undefined,
      authProvider: providerEnum,
      timezone: 'Asia/Ho_Chi_Minh',
      preferredLanguage: dto.preferredLanguage?.trim().toLowerCase() || 'vi',
    });

    const saved = await this.userRepository.save(user);
    return this.buildAuthResponse(saved);
  }

  /**
   * Helper to build uniform Carely Auth Response
   */
  private async buildAuthResponse(user: User) {
    const tokens = await this.generateTokens(user);
    return {
      user: {
        id: user.id,
        email: user.email,
        displayName: user.displayName,
        timezone: user.timezone,
        phoneNumber: user.phoneNumber,
        avatarUrl: user.avatarUrl,
        preferredLanguage: user.preferredLanguage,
        authProvider: user.authProvider,
      },
      ...tokens,
    };
  }

  /**
   * Validate Google ID Token with dual live/mock support
   */
  private async verifyGoogleToken(dto: GoogleAuthDto): Promise<{
    googleId: string;
    email: string;
    name?: string;
    picture?: string;
  }> {
    const token = dto.idToken?.trim();
    if (!token) {
      throw new UnauthorizedException('Google ID token is required');
    }

    const isTest =
      process.env.NODE_ENV !== 'production' &&
      (token.startsWith('mock-google-') || token.startsWith('google-test-') || token.startsWith('google-'));

    if (isTest) {
      if (token.includes('.')) {
        try {
          const decoded = this.jwtService.decode(token) as any;
          if (decoded && (decoded.sub || decoded.email)) {
            return {
              googleId: decoded.sub || `google-${token.slice(0, 16)}`,
              email: (decoded.email || dto.email || 'mock-google@carely.test').toLowerCase().trim(),
              name: decoded.name || decoded.displayName || dto.displayName || 'Google User',
              picture: decoded.picture || decoded.avatarUrl || dto.avatarUrl,
            };
          }
        } catch {
          // Fall through to string extraction
        }
      }

      const cleanToken = token.replace(/^(mock|test)-google-/, '');
      const isEmail = cleanToken.includes('@');
      const mockEmail = (dto.email || (isEmail ? cleanToken : `${cleanToken}@gmail.test`)).toLowerCase().trim();
      const mockGoogleId = isEmail
        ? `google-${cleanToken.replace(/[^a-zA-Z0-9]/g, '')}`
        : cleanToken;

      return {
        googleId: mockGoogleId || `mock-google-id-${Date.now()}`,
        email: mockEmail,
        name: dto.displayName || 'Google User',
        picture: dto.avatarUrl,
      };
    }

    // Live token verification with Google OAuth2 API
    try {
      const response = await fetch(
        `https://oauth2.googleapis.com/tokeninfo?id_token=${encodeURIComponent(token)}`,
        { signal: AbortSignal.timeout(5000) },
      );
      if (!response.ok) {
        throw new UnauthorizedException('Invalid Google ID token');
      }
      const data = (await response.json()) as any;
      if (!data.sub || !data.email) {
        throw new UnauthorizedException('Google ID token missing required claims');
      }
      const configuredClientId = process.env.GOOGLE_CLIENT_ID?.trim();
      if (configuredClientId && data.aud && data.aud !== configuredClientId) {
        throw new UnauthorizedException('Google ID token audience mismatch with configured GOOGLE_CLIENT_ID');
      }
      return {
        googleId: data.sub,
        email: data.email.toLowerCase().trim(),
        name: data.name || dto.displayName,
        picture: data.picture || dto.avatarUrl,
      };
    } catch (err: any) {
      if (err instanceof UnauthorizedException) throw err;
      throw new UnauthorizedException(`Failed to verify Google token: ${err?.message || err}`);
    }
  }

  /**
   * Validate Apple Identity Token
   */
  private async verifyAppleToken(dto: AppleAuthDto): Promise<{
    appleId: string;
    email?: string;
    name?: string;
  }> {
    const token = dto.identityToken?.trim();
    if (!token) {
      throw new UnauthorizedException('Apple identity token is required');
    }

    let resolvedName: string | undefined = undefined;
    if (dto.fullName) {
      const parts = [dto.fullName.firstName, dto.fullName.lastName].filter(Boolean);
      if (parts.length > 0) resolvedName = parts.join(' ').trim();
    }
    if (!resolvedName && dto.displayName) {
      resolvedName = dto.displayName.trim();
    }

    const isTest =
      (process.env.NODE_ENV === 'test' || process.env.NODE_ENV !== 'production') &&
      (token.startsWith('mock-apple-') ||
        token.startsWith('apple-test-') ||
        (process.env.NODE_ENV === 'test' && token.startsWith('apple-')));

    if (isTest) {
      if (token.includes('.')) {
        try {
          const decoded = this.jwtService.decode(token) as any;
          if (decoded && (decoded.sub || decoded.email)) {
            return {
              appleId: decoded.sub || `apple-${token.slice(0, 16)}`,
              email: (decoded.email || dto.email)?.toLowerCase().trim(),
              name: resolvedName || decoded.name || 'Apple User',
            };
          }
        } catch {
          // Fall through
        }
      }

      const cleanToken = token.replace(/^(mock|test)-apple-/, '');
      const isEmail = cleanToken.includes('@');
      const mockEmail = (dto.email || (isEmail ? cleanToken : undefined))?.toLowerCase().trim();
      const mockAppleId = `apple-sub-${cleanToken.replace(/[^a-zA-Z0-9]/g, '')}`;

      return {
        appleId: mockAppleId || `mock-apple-id-${Date.now()}`,
        email: mockEmail,
        name: resolvedName || 'Apple User',
      };
    }

    // Live token verification for Apple
    try {
      const parts = token.split('.');
      if (parts.length !== 3) {
        throw new UnauthorizedException('Malformed Apple identity token structure');
      }

      let header: any;
      try {
        header = JSON.parse(Buffer.from(parts[0], 'base64url').toString('utf8'));
      } catch {
        throw new UnauthorizedException('Invalid Apple token header');
      }

      if (header?.alg && header.alg !== 'RS256') {
        throw new UnauthorizedException(`Unsupported Apple token algorithm: ${header.alg}`);
      }

      // Cryptographic RS256 verification against Apple's public JWKS (https://appleid.apple.com/auth/keys)
      if (process.env.NODE_ENV === 'production' || header?.kid) {
        if (!header?.kid) {
          throw new UnauthorizedException('Apple identity token missing "kid" in header');
        }
        const jwk = await this.getApplePublicKey(header.kid);
        if (jwk) {
          const publicKey = crypto.createPublicKey({ key: jwk, format: 'jwk' });
          const verifier = crypto.createVerify('RSA-SHA256');
          verifier.update(`${parts[0]}.${parts[1]}`);
          const isValid = verifier.verify(publicKey, Buffer.from(parts[2], 'base64url'));
          if (!isValid) {
            throw new UnauthorizedException('Apple identity token RSA signature verification failed');
          }
        } else if (process.env.NODE_ENV === 'production') {
          throw new UnauthorizedException(`No matching Apple public key found for kid: ${header.kid}`);
        }
      }

      const decoded = this.jwtService.decode(token) as any;
      if (!decoded || !decoded.sub || typeof decoded.sub !== 'string') {
        throw new UnauthorizedException('Invalid Apple identity token payload: missing or invalid sub claim');
      }
      if (decoded.iss !== 'https://appleid.apple.com') {
        throw new UnauthorizedException('Invalid Apple token issuer');
      }
      if (!decoded.exp || typeof decoded.exp !== 'number' || decoded.exp * 1000 < Date.now()) {
        throw new UnauthorizedException('Apple identity token has expired or is missing expiration claim');
      }
      const configuredAppleId = process.env.APPLE_CLIENT_ID?.trim() || process.env.APPLE_BUNDLE_ID?.trim();
      if (configuredAppleId && decoded.aud && decoded.aud !== configuredAppleId) {
        throw new UnauthorizedException('Apple identity token audience mismatch with configured APPLE_CLIENT_ID');
      }
      return {
        appleId: decoded.sub,
        email: (decoded.email || dto.email)?.toLowerCase().trim(),
        name: resolvedName || decoded.name,
      };
    } catch (err: any) {
      if (err instanceof UnauthorizedException) throw err;
      throw new UnauthorizedException(`Failed to verify Apple token: ${err?.message || err}`);
    }
  }

  private async getApplePublicKey(kid: string): Promise<any | null> {
    const now = Date.now();
    if (this.appleJwksCache && this.appleJwksExpiresAt > now && this.appleJwksCache[kid]) {
      return this.appleJwksCache[kid];
    }

    try {
      const response = await fetch('https://appleid.apple.com/auth/keys', {
        signal: AbortSignal.timeout(5000),
      });
      if (!response.ok) return null;
      const body = (await response.json()) as { keys?: any[] };
      if (!Array.isArray(body?.keys)) return null;

      const map: Record<string, any> = {};
      for (const k of body.keys) {
        if (k?.kid) {
          map[k.kid] = k;
        }
      }
      this.appleJwksCache = map;
      this.appleJwksExpiresAt = now + 6 * 3600 * 1000; // Cache 6 hours
      return map[kid] || null;
    } catch {
      return null;
    }
  }

  private async generateTokens(user: User) {
    const payload = { sub: user.id, email: user.email };
    const accessToken = this.jwtService.sign(payload, { expiresIn: '7d' });
    const refreshToken = this.jwtService.sign(payload, { expiresIn: '30d' });
    return {
      accessToken,
      refreshToken,
      tokenType: 'Bearer',
      expiresIn: 7 * 24 * 3600,
    };
  }
}
