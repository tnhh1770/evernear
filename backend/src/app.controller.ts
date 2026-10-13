import { Controller, Get } from '@nestjs/common';
import { DataSource } from 'typeorm';
import { RedisService } from './common/redis/redis.service';

@Controller('api/v1/health')
export class AppController {
  constructor(
    private readonly dataSource: DataSource,
    private readonly redisService: RedisService,
  ) {}

  @Get()
  async checkHealth() {
    let dbStatus = 'DOWN';
    try {
      if (this.dataSource.isInitialized) {
        await this.dataSource.query('SELECT 1');
        dbStatus = 'UP';
      }
    } catch {
      dbStatus = 'DOWN';
    }

    const redisStatus = this.redisService.isReady ? 'UP' : 'DEGRADED';

    return {
      status: dbStatus === 'UP' ? 'OK' : 'DEGRADED',
      timestamp: new Date().toISOString(),
      services: {
        database: dbStatus,
        redis: redisStatus,
      },
    };
  }
}
