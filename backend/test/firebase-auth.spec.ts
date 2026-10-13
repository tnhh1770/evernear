import { describe, it, expect, beforeAll, afterAll } from 'vitest';
import { INestApplication } from '@nestjs/common';
import { DataSource } from 'typeorm';
import request from 'supertest';
import { createE2eTestApp, resetDatabase, teardownE2eTestApp } from './e2e/e2e-helper';

describe('Firebase Authentication E2E Tests (Zero-Admin OIDC Google & Apple)', () => {
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

  describe('POST /api/v1/auth/firebase', () => {
    it('1. should register a new user via Firebase Google ID token and return 200 with JWT tokens', async () => {
      const unique = Date.now();
      const mockToken = `mock-firebase-google-${unique}@carely.test`;

      const res = await request(app.getHttpServer())
        .post('/api/v1/auth/firebase')
        .send({
          idToken: mockToken,
        });

      expect(res.status).toBe(200);
      expect(res.body.accessToken).toBeDefined();
      expect(res.body.refreshToken).toBeDefined();
      expect(res.body.user).toBeDefined();
      expect(res.body.user.email).toBe(`google-${unique}@carely.test`);
      expect(res.body.user.displayName).toBe('Google Firebase User');

      // Verify the returned accessToken works with protected routes
      const profileRes = await request(app.getHttpServer())
        .get('/api/v1/auth/me')
        .set('Authorization', `Bearer ${res.body.accessToken}`);

      expect(profileRes.status).toBe(200);
      expect(profileRes.body.id).toBe(res.body.user.id);
    });

    it('2. should register a new user via Firebase Apple ID token', async () => {
      const unique = Date.now();
      const mockToken = `mock-firebase-apple-${unique}@privaterelay.appleid.com`;

      const res = await request(app.getHttpServer())
        .post('/api/v1/auth/firebase')
        .send({
          idToken: mockToken,
        });

      expect(res.status).toBe(200);
      expect(res.body.accessToken).toBeDefined();
      expect(res.body.user.email).toBe(`apple-${unique}@privaterelay.appleid.com`);
      expect(res.body.user.displayName).toBe('Apple Firebase User');
      expect(res.body.user.authProvider).toBe('APPLE');
    });

    it('3. should automatically link Firebase login to existing local user with matching email', async () => {
      const unique = Date.now();
      const email = `link_firebase_${unique}@carely.test`;
      const password = 'Password123!';

      // 1. Register local account
      const registerRes = await request(app.getHttpServer())
        .post('/api/v1/auth/register')
        .send({
          email,
          password,
          displayName: 'Original Local User',
        });
      expect(registerRes.status).toBe(201);
      const localUserId = registerRes.body.user.id;

      // 2. Sign in with Firebase using the same email
      const firebaseRes = await request(app.getHttpServer())
        .post('/api/v1/auth/firebase')
        .send({
          idToken: `mock-firebase-${email}`,
        });

      expect(firebaseRes.status).toBe(200);
      expect(firebaseRes.body.user.id).toBe(localUserId); // Same account linked!

      // 3. Verify original password still works
      const localLoginRes = await request(app.getHttpServer())
        .post('/api/v1/auth/login')
        .send({ email, password });

      expect(localLoginRes.status).toBe(200);
      expect(localLoginRes.body.user.id).toBe(localUserId);
    });

    it('4. should reject request with empty or missing idToken', async () => {
      const res = await request(app.getHttpServer())
        .post('/api/v1/auth/firebase')
        .send({});

      expect(res.status).toBe(400);
    });
  });
});
