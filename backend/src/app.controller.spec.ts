import { Test, TestingModule } from '@nestjs/testing';
import { DataSource } from 'typeorm';
import { AppController } from './app.controller';
import { RedisService } from './common/redis/redis.service';

describe('AppController', () => {
  let appController: AppController;

  beforeEach(async () => {
    const app: TestingModule = await Test.createTestingModule({
      controllers: [AppController],
      providers: [
        {
          provide: DataSource,
          useValue: {
            isInitialized: true,
            query: vi.fn().mockResolvedValue([{ 1: 1 }]),
          },
        },
        {
          provide: RedisService,
          useValue: {
            isReady: true,
          },
        },
      ],
    }).compile();

    appController = app.get<AppController>(AppController);
  });

  describe('health', () => {
    it('should return health status OK when database and redis are healthy', async () => {
      const res = await appController.checkHealth();
      expect(res.status).toBe('OK');
      expect(res.services.database).toBe('UP');
      expect(res.services.redis).toBe('UP');
    });
  });
});
