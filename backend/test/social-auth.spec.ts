import { describe, it, expect, beforeAll, afterAll } from 'vitest';
import { INestApplication } from '@nestjs/common';
import { DataSource } from 'typeorm';
import request from 'supertest';
import { createE2eTestApp, resetDatabase, teardownE2eTestApp } from './e2e/e2e-helper';

describe('Social Authentication E2E Tests (Google & Apple Sign-In)', () => {
  let app: INestApplication;
  let dataSource: DataSource;

  beforeAll(async () => {
    const context = await createE2eTestApp();
    app = context.app;
    dataSource = context.dataSource;
    await resetDatabase(dataSource);
  }, 30000);

  afterAll(async () => {
    await teardownE2eTestApp(app, dataSource);
  });

  describe('POST /api/v1/auth/google', () => {
    it('1. should register a new user via Google Sign-In and return 200 with JWT tokens', async () => {
      const unique = Date.now();
      const email = `google_user_${unique}@carely.test`;

      const res = await request(app.getHttpServer())
        .post('/api/v1/auth/google')
        .send({
          idToken: `mock-google-id-${unique}`,
          email,
          displayName: 'Google Explorer User',
          avatarUrl: 'https://carely.app/avatar.png',
        });

      expect(res.status).toBe(200);
      expect(res.body.accessToken).toBeDefined();
      expect(res.body.refreshToken).toBeDefined();
      expect(res.body.user).toBeDefined();
      expect(res.body.user.email).toBe(email);
      expect(res.body.user.displayName).toBe('Google Explorer User');

      // Verify the returned accessToken can access protected routes
      const profileRes = await request(app.getHttpServer())
        .get('/api/v1/auth/me')
        .set('Authorization', `Bearer ${res.body.accessToken}`);

      expect(profileRes.status).toBe(200);
      expect(profileRes.body.id).toBe(res.body.user.id);
    });

    it('2. should automatically link Google account to existing user with matching email', async () => {
      const unique = Date.now();
      const email = `link_test_${unique}@carely.test`;
      const password = 'Password123!';

      // 1. Register local user first
      const registerRes = await request(app.getHttpServer())
        .post('/api/v1/auth/register')
        .send({
          email,
          password,
          displayName: 'Local Register User',
        });
      expect(registerRes.status).toBe(201);
      const localUserId = registerRes.body.user.id;

      // 2. Sign in with Google using the same email
      const googleRes = await request(app.getHttpServer())
        .post('/api/v1/auth/google')
        .send({
          idToken: `mock-google-sub-${unique}`,
          email,
          displayName: 'Google Linked Profile',
        });

      expect(googleRes.status).toBe(200);
      expect(googleRes.body.user.id).toBe(localUserId); // Same account linked!

      // 3. Verify original password still works
      const localLoginRes = await request(app.getHttpServer())
        .post('/api/v1/auth/login')
        .send({ email, password });

      expect(localLoginRes.status).toBe(200);
      expect(localLoginRes.body.user.id).toBe(localUserId);
    });
  });

  describe('POST /api/v1/auth/apple', () => {
    it('1. should register a new user on first Apple Sign-In with email and fullName', async () => {
      const unique = Date.now();
      const email = `apple_first_${unique}@privaterelay.appleid.com`;
      const appleToken = `mock-apple-sub-unique-${unique}`;

      const res = await request(app.getHttpServer())
        .post('/api/v1/auth/apple')
        .send({
          identityToken: appleToken,
          email,
          fullName: { firstName: 'Van', lastName: 'Apple' },
        });

      expect(res.status).toBe(200);
      expect(res.body.accessToken).toBeDefined();
      expect(res.body.user.email).toBe(email);
      expect(res.body.user.displayName).toBe('Van Apple');
    });

    it('2. should handle subsequent Apple Sign-In where email is omitted', async () => {
      const unique = Date.now();
      const email = `apple_subsequent_${unique}@privaterelay.appleid.com`;
      const appleToken = `mock-apple-sub-stable-${unique}`;

      // First sign-in with email
      const firstRes = await request(app.getHttpServer())
        .post('/api/v1/auth/apple')
        .send({
          identityToken: appleToken,
          email,
          fullName: { firstName: 'Lan', lastName: 'Tran' },
        });
      expect(firstRes.status).toBe(200);
      const createdUserId = firstRes.body.user.id;

      // Subsequent sign-in (Apple does not send email or fullName)
      const subsequentRes = await request(app.getHttpServer())
        .post('/api/v1/auth/apple')
        .send({
          identityToken: appleToken,
        });

      expect(subsequentRes.status).toBe(200);
      expect(subsequentRes.body.user.id).toBe(createdUserId);
      expect(subsequentRes.body.user.email).toBe(email);
    });

    it('3. should reject initial Apple Sign-In if email is not provided and user is unknown', async () => {
      const res = await request(app.getHttpServer())
        .post('/api/v1/auth/apple')
        .send({
          identityToken: `mock-apple-unknown-${Date.now()}`,
          // No email provided
        });

      expect(res.status).toBe(400);
      expect(res.body.message).toContain('Email is required');
    });
  });

  describe('Cross-Provider Tri-Auth Account Linking', () => {
    it('should link Local, Google, and Apple logins to the exact same user entity', async () => {
      const unique = Date.now();
      const email = `tri_auth_${unique}@carely.test`;
      const password = 'TriPassword123!';

      // 1. Create with password
      const localRes = await request(app.getHttpServer())
        .post('/api/v1/auth/register')
        .send({ email, password, displayName: 'Tri User' });
      const targetId = localRes.body.user.id;

      // 2. Link with Google
      const googleRes = await request(app.getHttpServer())
        .post('/api/v1/auth/google')
        .send({ idToken: `mock-google-tri-${unique}`, email });
      expect(googleRes.body.user.id).toBe(targetId);

      // 3. Link with Apple
      const appleRes = await request(app.getHttpServer())
        .post('/api/v1/auth/apple')
        .send({ identityToken: `mock-apple-tri-${unique}`, email });
      expect(appleRes.body.user.id).toBe(targetId);

      // All three sign-in vectors yield JWT tokens for the same user
      const meLocal = await request(app.getHttpServer())
        .get('/api/v1/auth/me')
        .set('Authorization', `Bearer ${localRes.body.accessToken}`);
      const meGoogle = await request(app.getHttpServer())
        .get('/api/v1/auth/me')
        .set('Authorization', `Bearer ${googleRes.body.accessToken}`);
      const meApple = await request(app.getHttpServer())
        .get('/api/v1/auth/me')
        .set('Authorization', `Bearer ${appleRes.body.accessToken}`);

      expect(meLocal.body.id).toBe(targetId);
      expect(meGoogle.body.id).toBe(targetId);
      expect(meApple.body.id).toBe(targetId);
    });
  });
});
