import { describe, it, expect, vi, beforeEach } from 'vitest';
import { AuthService } from './auth.service';
import { BadRequestException } from '@nestjs/common';
import { AuthProvider } from '../../common/enums';

describe('AuthService (Social Authentication Unit Tests)', () => {
  let authService: AuthService;
  let userRepo: any;
  let jwtService: any;
  let redisService: any;
  let firebaseVerifier: any;

  beforeEach(() => {
    userRepo = {
      findOne: vi.fn(),
      create: vi.fn((data) => ({ ...data, id: 'user-mock-uuid' })),
      save: vi.fn((entity) => Promise.resolve({ ...entity, id: entity.id || 'user-mock-uuid' })),
    };
    jwtService = {
      sign: vi.fn((payload) => `signed_jwt_${payload.sub}`),
      decode: vi.fn(),
    };
    redisService = {
      del: vi.fn().mockResolvedValue(1),
    };
    firebaseVerifier = {
      verifyIdToken: vi.fn(),
    };

    authService = new AuthService(userRepo, jwtService, redisService, firebaseVerifier);
  });

  describe('googleLogin', () => {
    it('1. should create new user with secure password hash when neither googleId nor email exists', async () => {
      userRepo.findOne.mockResolvedValue(null);

      const res = await authService.googleLogin({
        idToken: 'mock-google-112233',
        email: 'newuser@google.test',
        displayName: 'Google New User',
        avatarUrl: 'https://avatar.google/1.jpg',
      });

      expect(userRepo.create).toHaveBeenCalledWith(
        expect.objectContaining({
          email: 'newuser@google.test',
          googleId: '112233',
          authProvider: AuthProvider.GOOGLE,
          displayName: 'Google New User',
          avatarUrl: 'https://avatar.google/1.jpg',
        }),
      );
      expect(res.user.email).toBe('newuser@google.test');
      expect(res.accessToken).toBe('signed_jwt_user-mock-uuid');
    });

    it('2. should link googleId to existing user when email matches without altering passwordHash', async () => {
      const existingLocalUser = {
        id: 'existing-uuid',
        email: 'local@carely.test',
        passwordHash: '$2b$10$originalPasswordHashValue',
        displayName: 'Local User',
        googleId: null,
        authProvider: 'LOCAL',
      };

      // First findOne (by googleId) -> null; Second findOne (by email) -> existingLocalUser
      userRepo.findOne
        .mockResolvedValueOnce(null)
        .mockResolvedValueOnce(existingLocalUser);

      const res = await authService.googleLogin({
        idToken: 'mock-google-998877',
        email: 'local@carely.test',
        displayName: 'Google Display Name',
      });

      expect(existingLocalUser.googleId).toBe('998877');
      expect(existingLocalUser.passwordHash).toBe('$2b$10$originalPasswordHashValue'); // Untouched
      expect(userRepo.save).toHaveBeenCalledWith(existingLocalUser);
      expect(res.user.id).toBe('existing-uuid');
    });

    it('3. should return existing user immediately if googleId matches', async () => {
      const existingGoogleUser = {
        id: 'google-user-uuid',
        email: 'user@google.test',
        googleId: 'google-sub-445566',
        authProvider: 'GOOGLE',
      };

      userRepo.findOne.mockResolvedValueOnce(existingGoogleUser);

      const res = await authService.googleLogin({
        idToken: 'mock-google-445566',
      });

      expect(res.user.id).toBe('google-user-uuid');
      expect(userRepo.create).not.toHaveBeenCalled();
    });
  });

  describe('appleLogin', () => {
    it('1. should create new user when appleId and email are provided', async () => {
      userRepo.findOne.mockResolvedValue(null);

      const res = await authService.appleLogin({
        identityToken: 'mock-apple-sub-apple123',
        email: 'appleuser@icloud.test',
        fullName: { firstName: 'Nguyen', lastName: 'Apple' },
      });

      expect(userRepo.create).toHaveBeenCalledWith(
        expect.objectContaining({
          email: 'appleuser@icloud.test',
          appleId: 'apple-sub-subapple123',
          authProvider: AuthProvider.APPLE,
          displayName: 'Nguyen Apple',
        }),
      );
      expect(res.user.email).toBe('appleuser@icloud.test');
      expect(res.accessToken).toBe('signed_jwt_user-mock-uuid');
    });

    it('2. should reject first-time Apple login when email is missing', async () => {
      userRepo.findOne.mockResolvedValue(null);

      await expect(
        authService.appleLogin({
          identityToken: 'mock-apple-sub-no-email',
        }),
      ).rejects.toThrow(BadRequestException);
    });

    it('3. should succeed on subsequent login without email when appleId already exists', async () => {
      const existingAppleUser = {
        id: 'apple-existing-uuid',
        email: 'appleprivaterelay@appleid.com',
        appleId: 'apple-sub-returning',
        displayName: 'Apple Returning',
      };

      userRepo.findOne.mockResolvedValueOnce(existingAppleUser);

      const res = await authService.appleLogin({
        identityToken: 'mock-apple-sub-returning', // No email or fullName in subsequent login
      });

      expect(res.user.id).toBe('apple-existing-uuid');
      expect(userRepo.create).not.toHaveBeenCalled();
    });

    it('4. should link appleId to existing email account', async () => {
      const existingUser = {
        id: 'email-uuid',
        email: 'shared@domain.test',
        passwordHash: '$2b$10$existingHash',
        appleId: null,
      };

      userRepo.findOne
        .mockResolvedValueOnce(null) // not found by appleId
        .mockResolvedValueOnce(existingUser); // found by email

      const res = await authService.appleLogin({
        identityToken: 'mock-apple-shared-sub',
        email: 'shared@domain.test',
      });

      expect(existingUser.appleId).toBe('apple-sub-sharedsub');
      expect(existingUser.passwordHash).toBe('$2b$10$existingHash');
      expect(res.user.id).toBe('email-uuid');
    });
  });

  describe('firebaseLogin', () => {
    it('1. should register a new Google user through Firebase ID token without firebase-admin', async () => {
      firebaseVerifier.verifyIdToken.mockResolvedValue({
        uid: 'fb-google-uid-123',
        email: 'fb_google@test.carely',
        name: 'Firebase Google User',
        picture: 'https://test.carely/fb-avatar.png',
        provider: 'google.com',
        googleId: 'google-sub-999',
      });
      userRepo.findOne.mockResolvedValue(null);

      const res = await authService.firebaseLogin({
        idToken: 'mock-firebase-google-token',
      });

      expect(userRepo.create).toHaveBeenCalledWith(
        expect.objectContaining({
          email: 'fb_google@test.carely',
          displayName: 'Firebase Google User',
          avatarUrl: 'https://test.carely/fb-avatar.png',
          googleId: 'google-sub-999',
          authProvider: AuthProvider.GOOGLE,
        }),
      );
      expect(res.user.email).toBe('fb_google@test.carely');
      expect(res.accessToken).toBe('signed_jwt_user-mock-uuid');
    });

    it('2. should register a new Apple user through Firebase ID token', async () => {
      firebaseVerifier.verifyIdToken.mockResolvedValue({
        uid: 'fb-apple-uid-456',
        email: 'fb_apple@privaterelay.appleid.com',
        name: 'Firebase Apple User',
        provider: 'apple.com',
        appleId: 'apple-sub-888',
      });
      userRepo.findOne.mockResolvedValue(null);

      const res = await authService.firebaseLogin({
        idToken: 'mock-firebase-apple-token',
      });

      expect(userRepo.create).toHaveBeenCalledWith(
        expect.objectContaining({
          email: 'fb_apple@privaterelay.appleid.com',
          displayName: 'Firebase Apple User',
          appleId: 'apple-sub-888',
          authProvider: AuthProvider.APPLE,
        }),
      );
      expect(res.user.email).toBe('fb_apple@privaterelay.appleid.com');
    });

    it('3. should automatically link Firebase identity to existing local user with matching email', async () => {
      const existingUser = {
        id: 'local-existing-uuid',
        email: 'existing@carely.test',
        passwordHash: '$2b$10$secretHashUnchanged',
        googleId: null,
      };

      firebaseVerifier.verifyIdToken.mockResolvedValue({
        uid: 'fb-uid-link',
        email: 'existing@carely.test',
        name: 'Linked Google User',
        provider: 'google.com',
        googleId: 'google-sub-link',
      });

      userRepo.findOne
        .mockResolvedValueOnce(null) // not found by googleId
        .mockResolvedValueOnce(existingUser); // found by email

      const res = await authService.firebaseLogin({
        idToken: 'mock-firebase-link-token',
      });

      expect(existingUser.googleId).toBe('google-sub-link');
      expect(existingUser.passwordHash).toBe('$2b$10$secretHashUnchanged');
      expect(res.user.id).toBe('local-existing-uuid');
    });
  });

  describe('register', () => {
    it('should throw ConflictException if email is already registered', async () => {
      userRepo.findOne.mockResolvedValueOnce({ id: 'existing-id', email: 'test@carely.com' });
      await expect(
        authService.register({
          email: 'test@carely.com',
          password: 'password123',
          displayName: 'Test User',
        }),
      ).rejects.toThrow('Email already registered');
    });

    it('should throw ConflictException if phone number is already registered', async () => {
      userRepo.findOne
        .mockResolvedValueOnce(null) // email check
        .mockResolvedValueOnce({ id: 'existing-id', phoneNumber: '+84912345678' }); // phone check

      await expect(
        authService.register({
          email: 'newuser@carely.com',
          password: 'password123',
          displayName: 'New User',
          phoneNumber: '+84912345678',
        }),
      ).rejects.toThrow('Phone number already registered');
    });

    it('should register successfully when email and phone are unique', async () => {
      userRepo.findOne
        .mockResolvedValueOnce(null) // email check
        .mockResolvedValueOnce(null); // phone check

      const res = await authService.register({
        email: 'unique@carely.com',
        password: 'password123',
        displayName: 'Unique User',
        phoneNumber: '+84999999999',
      });

      expect(res.user.email).toBe('unique@carely.com');
      expect(userRepo.create).toHaveBeenCalledWith(
        expect.objectContaining({
          email: 'unique@carely.com',
          phoneNumber: '+84999999999',
        }),
      );
    });
  });
});

