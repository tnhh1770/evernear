import { Test, TestingModule } from '@nestjs/testing';
import { INestApplication } from '@nestjs/common';
import request from 'supertest';
import { AppModule } from './../src/app.module';

describe('AppController Health E2E', () => {
  let app: INestApplication;

  beforeAll(async () => {
    const moduleFixture: TestingModule = await Test.createTestingModule({
      imports: [AppModule],
    }).compile();

    app = moduleFixture.createNestApplication();
    await app.init();
  });

  it('GET /api/v1/health should return 200 with service health statuses', async () => {
    const response = await request(app.getHttpServer())
      .get('/api/v1/health')
      .expect(200);

    expect(response.body).toBeDefined();
    expect(response.body.status).toMatch(/^(OK|DEGRADED)$/);
    expect(response.body.timestamp).toBeDefined();
    expect(response.body.services).toBeDefined();
    expect(response.body.services.database).toMatch(/^(UP|DOWN)$/);
    expect(response.body.services.redis).toMatch(/^(UP|DEGRADED)$/);
  });

  afterAll(async () => {
    if (app) {
      await app.close();
    }
  });
});
