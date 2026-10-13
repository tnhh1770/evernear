import {
  Injectable,
  OnModuleInit,
  OnModuleDestroy,
  Logger,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import Redis, { RedisOptions, ChainableCommander } from 'ioredis';
import { v4 as uuidv4 } from 'uuid';

export interface LockResult {
  acquired: boolean;
  degraded: boolean;
  token: string | null;
}

@Injectable()
export class RedisService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(RedisService.name);
  private client: Redis | null = null;
  private isConnected = false;

  constructor(private readonly configService: ConfigService) {}

  onModuleInit() {
    const redisUrl = this.configService.get<string>('REDIS_URL');
    const host = this.configService.get<string>('REDIS_HOST', 'localhost');
    const port = Number(this.configService.get<number | string>('REDIS_PORT', 6379));
    const password = this.configService.get<string>('REDIS_PASSWORD');
    const db = Number(this.configService.get<number | string>('REDIS_DB', 0));
    const tlsConfig = this.configService.get<string | boolean>('REDIS_TLS');

    try {
      const options: RedisOptions = {
        retryStrategy: (times) => {
          const delay = Math.min(times * 500, 3000);
          this.logger.warn(`Redis reconnection attempt #${times}, retrying in ${delay}ms`);
          return delay;
        },
        maxRetriesPerRequest: 2,
        enableOfflineQueue: false,
      };

      if (password) {
        options.password = password;
      }
      if (db) {
        options.db = db;
      }
      if (tlsConfig === true || tlsConfig === 'true') {
        options.tls = {};
      }

      if (redisUrl) {
        this.client = new Redis(redisUrl, options);
      } else {
        this.client = new Redis({
          host,
          port,
          ...options,
        });
      }

      this.client.on('connect', () => {
        this.isConnected = true;
        this.logger.log(`Connecting to Redis...`);
      });

      this.client.on('ready', () => {
        this.isConnected = true;
        this.logger.log(`Redis client ready at ${host}:${port}`);
      });

      this.client.on('reconnecting', (delay?: number) => {
        this.isConnected = false;
        this.logger.warn(`Redis client reconnecting in ${delay}ms...`);
      });

      this.client.on('close', () => {
        this.isConnected = false;
        this.logger.warn('Redis connection closed.');
      });

      this.client.on('error', (err) => {
        this.isConnected = false;
        this.logger.warn(`Redis connection error: ${err.message}. Degraded mode active.`);
      });
    } catch (err: any) {
      this.logger.warn(`Failed to initialize Redis: ${err.message}. Operating in fallback mode.`);
      this.client = null;
      this.isConnected = false;
    }
  }

  async onModuleDestroy() {
    if (this.client) {
      try {
        await this.client.quit();
      } catch {
        this.client.disconnect();
      } finally {
        this.isConnected = false;
        this.client = null;
      }
    }
  }

  get isReady(): boolean {
    return this.isConnected && this.client !== null && this.client.status === 'ready';
  }

  getClient(): Redis | null {
    return this.client;
  }

  async get(key: string): Promise<string | null> {
    if (!this.isReady || !this.client) return null;
    try {
      return await this.client.get(key);
    } catch (err: any) {
      this.logger.warn(`Redis get error on ${key}: ${err.message}`);
      return null;
    }
  }

  async set(key: string, value: string, ttlSeconds?: number): Promise<void> {
    if (!this.isReady || !this.client) return;
    try {
      if (ttlSeconds && ttlSeconds > 0) {
        await this.client.set(key, value, 'EX', ttlSeconds);
      } else {
        await this.client.set(key, value);
      }
    } catch (err: any) {
      this.logger.warn(`Redis set error on ${key}: ${err.message}`);
    }
  }

  async del(key: string): Promise<number> {
    if (!this.isReady || !this.client) return 0;
    try {
      return await this.client.del(key);
    } catch (err: any) {
      this.logger.warn(`Redis del error on ${key}: ${err.message}`);
      return 0;
    }
  }

  /**
   * Acquire a distributed lock with detailed result (acquired, degraded, token).
   * Distinguishes lock contention from degraded mode.
   */
  async acquireLockDetailed(
    lockKey: string,
    ttlMs: number = 10000,
  ): Promise<LockResult> {
    if (!this.isReady || !this.client) {
      // Degraded mode: redis is down, callers should rely on DB lock
      return { acquired: false, degraded: true, token: null };
    }
    const token = uuidv4();
    try {
      const result = await this.client.set(lockKey, token, 'PX', ttlMs, 'NX');
      if (result === 'OK') {
        return { acquired: true, degraded: false, token };
      }
      return { acquired: false, degraded: false, token: null };
    } catch (err: any) {
      this.logger.warn(`Redis acquireLock error on ${lockKey}: ${err.message}`);
      return { acquired: false, degraded: true, token: null };
    }
  }

  /**
   * Acquire a distributed lock using Redlock pattern (SET NX PX)
   * Backwards-compatible return: string token if acquired, null if not acquired or degraded
   */
  async acquireLock(lockKey: string, ttlMs: number = 10000): Promise<string | null> {
    const result = await this.acquireLockDetailed(lockKey, ttlMs);
    return result.token;
  }

  /**
   * Release a distributed lock securely using Lua script to verify token ownership
   */
  async releaseLock(lockKey: string, token: string): Promise<boolean> {
    if (!this.isReady || !this.client) return false;
    const luaScript = `
      if redis.call("get", KEYS[1]) == ARGV[1] then
        return redis.call("del", KEYS[1])
      else
        return 0
      end
    `;
    try {
      const result = await this.client.eval(luaScript, 1, lockKey, token);
      return result === 1;
    } catch (err: any) {
      this.logger.warn(`Redis releaseLock error on ${lockKey}: ${err.message}`);
      return false;
    }
  }

  /**
   * Check rate limit atomically using a single-roundtrip Lua script.
   * Eliminates the zombie key hazard (TTL -1) and prevents race conditions.
   */
  async checkRateLimit(
    key: string,
    limit: number,
    windowSeconds: number,
  ): Promise<{ allowed: boolean; remaining: number }> {
    if (!this.isReady || !this.client) {
      // If Redis is down, allow request so as not to block legitimate device traffic
      return { allowed: true, remaining: limit };
    }

    const luaScript = `
      local current = redis.call('INCR', KEYS[1])
      if current == 1 then
        redis.call('EXPIRE', KEYS[1], ARGV[1])
      else
        local ttl = redis.call('TTL', KEYS[1])
        if ttl == -1 then
          redis.call('EXPIRE', KEYS[1], ARGV[1])
        end
      end
      return current
    `;

    try {
      const current = Number(await this.client.eval(luaScript, 1, key, windowSeconds));
      const allowed = current <= limit;
      return {
        allowed,
        remaining: Math.max(0, limit - current),
      };
    } catch (err: any) {
      this.logger.warn(`Redis checkRateLimit error on ${key}: ${err.message}`);
      return { allowed: true, remaining: limit };
    }
  }

  /**
   * Create a Redis pipeline for batching multiple operations in a single network roundtrip.
   */
  pipeline(): ChainableCommander | null {
    if (!this.isReady || !this.client) return null;
    return this.client.pipeline();
  }

  /**
   * Multi-key get in a single roundtrip.
   */
  async mget(keys: string[]): Promise<(string | null)[]> {
    if (!keys || keys.length === 0) return [];
    if (!this.isReady || !this.client) return keys.map(() => null);
    try {
      return await this.client.mget(...keys);
    } catch (err: any) {
      this.logger.warn(`Redis mget error: ${err.message}`);
      return keys.map(() => null);
    }
  }

  /**
   * Multi-key set in a single roundtrip.
   */
  async mset(keyValues: Record<string, string>): Promise<boolean> {
    const entries = Object.entries(keyValues);
    if (entries.length === 0) return true;
    if (!this.isReady || !this.client) return false;
    try {
      const flat: string[] = [];
      for (const [k, v] of entries) {
        flat.push(k, v);
      }
      await this.client.mset(...flat);
      return true;
    } catch (err: any) {
      this.logger.warn(`Redis mset error: ${err.message}`);
      return false;
    }
  }

  /**
   * Set hash field values.
   */
  async hset(key: string, fieldValues: Record<string, string | number>): Promise<boolean> {
    if (!this.isReady || !this.client) return false;
    try {
      await this.client.hset(key, fieldValues);
      return true;
    } catch (err: any) {
      this.logger.warn(`Redis hset error on ${key}: ${err.message}`);
      return false;
    }
  }

  /**
   * Retrieve all hash fields.
   */
  async hgetall(key: string): Promise<Record<string, string> | null> {
    if (!this.isReady || !this.client) return null;
    try {
      const result = await this.client.hgetall(key);
      return result && Object.keys(result).length > 0 ? result : null;
    } catch (err: any) {
      this.logger.warn(`Redis hgetall error on ${key}: ${err.message}`);
      return null;
    }
  }

  /**
   * Set TTL in seconds on a key.
   */
  async expire(key: string, seconds: number): Promise<boolean> {
    if (!this.isReady || !this.client) return false;
    try {
      const result = await this.client.expire(key, seconds);
      return result === 1;
    } catch (err: any) {
      this.logger.warn(`Redis expire error on ${key}: ${err.message}`);
      return false;
    }
  }
}

