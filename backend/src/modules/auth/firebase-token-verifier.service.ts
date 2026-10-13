import {
  Injectable,
  UnauthorizedException,
  Logger,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import * as crypto from 'crypto';

export interface VerifiedFirebaseToken {
  uid: string;
  email?: string;
  emailVerified?: boolean;
  name?: string;
  picture?: string;
  provider: string; // 'google.com', 'apple.com', or custom
  googleId?: string;
  appleId?: string;
}

@Injectable()
export class FirebaseTokenVerifierService {
  private readonly logger = new Logger(FirebaseTokenVerifierService.name);
  private certificatesCache: Record<string, string> | null = null;
  private certificatesExpiresAt: number = 0;

  private readonly CERT_URL =
    'https://www.googleapis.com/robot/v1/metadata/x509/securetoken@system.gserviceaccount.com';

  constructor(private readonly configService: ConfigService) {}

  /**
   * Verifies a Firebase ID token using Google's public x509 certificates (RS256 OIDC)
   * Completely zero-dependency: uses standard Node.js crypto and fetch.
   */
  async verifyIdToken(idToken: string): Promise<VerifiedFirebaseToken> {
    const token = idToken?.trim();
    if (!token) {
      throw new UnauthorizedException('Firebase ID token is required');
    }

    // 1. Dual Live / Mock Support for CI, Automated Testing, and Local Development
    const isMock =
      process.env.NODE_ENV !== 'production' &&
      (token.startsWith('mock-firebase-') ||
        token.startsWith('test-firebase-') ||
        token.startsWith('firebase-test-'));

    if (isMock) {
      return this.handleMockToken(token);
    }

    // 2. Parse JWT parts (Header, Payload, Signature)
    const parts = token.split('.');
    if (parts.length !== 3) {
      throw new UnauthorizedException('Invalid Firebase ID token format');
    }

    const [headerB64, payloadB64, signatureB64] = parts;

    let header: { alg?: string; kid?: string };
    let payload: any;

    try {
      header = JSON.parse(Buffer.from(headerB64, 'base64url').toString('utf8'));
      payload = JSON.parse(Buffer.from(payloadB64, 'base64url').toString('utf8'));
    } catch {
      throw new UnauthorizedException('Malformed Firebase ID token payload');
    }

    // 3. Header validation
    if (header.alg !== 'RS256') {
      throw new UnauthorizedException(
        `Firebase ID token algorithm must be RS256, received: ${header.alg}`,
      );
    }
    if (!header.kid) {
      throw new UnauthorizedException('Firebase ID token missing "kid" in header');
    }

    // 4. Retrieve Google Public Certificate for this kid
    let cert = await this.getCertificate(header.kid);
    if (!cert) {
      // Refresh cache once in case Google rotated keys
      this.certificatesCache = null;
      cert = await this.getCertificate(header.kid);
      if (!cert) {
        throw new UnauthorizedException(
          `No public certificate found for Firebase token kid: ${header.kid}`,
        );
      }
    }

    // 5. Verify cryptographic RSA signature
    try {
      const verifier = crypto.createVerify('RSA-SHA256');
      verifier.update(`${headerB64}.${payloadB64}`);
      const isValid = verifier.verify(cert, Buffer.from(signatureB64, 'base64url'));
      if (!isValid) {
        throw new UnauthorizedException('Firebase ID token signature verification failed');
      }
    } catch (err: any) {
      if (err instanceof UnauthorizedException) throw err;
      throw new UnauthorizedException(
        `Failed to verify Firebase token signature: ${err?.message || err}`,
      );
    }

    // 6. Verify standard OIDC Claims (iat, exp, iss, aud, sub)
    const now = Math.floor(Date.now() / 1000);

    if (typeof payload.exp !== 'number' || payload.exp < now) {
      throw new UnauthorizedException('Firebase ID token has expired');
    }

    // Allow 5 minutes clock skew for iat
    if (typeof payload.iat !== 'number' || payload.iat > now + 300) {
      throw new UnauthorizedException('Firebase ID token issued in the future');
    }

    if (!payload.sub || typeof payload.sub !== 'string' || payload.sub.length > 128) {
      throw new UnauthorizedException('Firebase ID token has invalid "sub" claim');
    }

    const expectedProjectId = this.configService.get<string>('FIREBASE_PROJECT_ID')?.trim();
    if (expectedProjectId) {
      if (payload.aud !== expectedProjectId) {
        throw new UnauthorizedException(
          `Firebase token audience (${payload.aud}) does not match configured project ID (${expectedProjectId})`,
        );
      }
      if (payload.iss !== `https://securetoken.google.com/${expectedProjectId}`) {
        throw new UnauthorizedException(
          `Firebase token issuer (${payload.iss}) does not match expected project ID (${expectedProjectId})`,
        );
      }
    } else {
      // If FIREBASE_PROJECT_ID is not configured yet, ensure iss matches aud
      if (payload.iss !== `https://securetoken.google.com/${payload.aud}`) {
        throw new UnauthorizedException('Firebase token issuer mismatch with audience');
      }
    }

    // 7. Extract Provider and Identity info
    const firebaseClaim = payload.firebase || {};
    const provider = firebaseClaim.sign_in_provider || 'google.com';
    const identities = firebaseClaim.identities || {};

    const googleId = identities['google.com']?.[0];
    const appleId = identities['apple.com']?.[0];

    return {
      uid: payload.sub,
      email: payload.email?.toLowerCase().trim(),
      emailVerified: Boolean(payload.email_verified),
      name: payload.name,
      picture: payload.picture,
      provider,
      googleId,
      appleId,
    };
  }

  /**
   * Fetches Google x509 certificates with caching according to Cache-Control
   */
  private async getCertificate(kid: string): Promise<string | null> {
    const now = Date.now();
    if (this.certificatesCache && this.certificatesExpiresAt > now) {
      return this.certificatesCache[kid] || null;
    }

    try {
      const response = await fetch(this.CERT_URL, {
        signal: AbortSignal.timeout(5000),
      });

      if (!response.ok) {
        this.logger.error(`Failed to fetch Google x509 certs: ${response.statusText}`);
        return null;
      }

      // Parse Cache-Control header max-age
      const cacheControl = response.headers.get('cache-control') || '';
      const match = cacheControl.match(/max-age=(\d+)/i);
      const maxAgeSeconds = match ? parseInt(match[1], 10) : 3600 * 6; // default 6h

      this.certificatesCache = (await response.json()) as Record<string, string>;
      this.certificatesExpiresAt = now + maxAgeSeconds * 1000;

      return this.certificatesCache[kid] || null;
    } catch (err: any) {
      this.logger.error(`Error fetching Google public certificates: ${err?.message || err}`);
      return null;
    }
  }

  /**
   * Deterministic mock handler for Vitest / E2E test suites
   */
  private handleMockToken(token: string): VerifiedFirebaseToken {
    // If the mock token has standard JWT structure (base64 payload), decode it
    if (token.includes('.')) {
      try {
        const [, payloadB64] = token.split('.');
        const decoded = JSON.parse(Buffer.from(payloadB64, 'base64url').toString('utf8'));
        if (decoded && (decoded.sub || decoded.email)) {
          return {
            uid: decoded.sub || `firebase-${token.slice(0, 16)}`,
            email: decoded.email?.toLowerCase().trim(),
            emailVerified: true,
            name: decoded.name || 'Firebase Test User',
            picture: decoded.picture,
            provider: decoded.firebase?.sign_in_provider || 'google.com',
            googleId: decoded.firebase?.identities?.['google.com']?.[0],
            appleId: decoded.firebase?.identities?.['apple.com']?.[0],
          };
        }
      } catch {
        // Fall back to string extraction
      }
    }

    const clean = token.replace(/^(mock|test)-firebase-/, '');
    const isApple = token.includes('apple');
    const email = clean.includes('@') ? clean : `${clean}@carely-firebase.test`;
    const provider = isApple ? 'apple.com' : 'google.com';

    return {
      uid: `firebase-uid-${clean}`,
      email: email.toLowerCase().trim(),
      emailVerified: true,
      name: isApple ? 'Apple Firebase User' : 'Google Firebase User',
      picture: 'https://carely.test/avatar.png',
      provider,
      googleId: isApple ? undefined : `google-id-${clean}`,
      appleId: isApple ? `apple-sub-${clean}` : undefined,
    };
  }
}
