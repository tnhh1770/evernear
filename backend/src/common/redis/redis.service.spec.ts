import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { ConfigService } from '@nestjs/config';
import { RedisService } from './redis.service';

let capturedRedisOptions: any = null;

vi.mock('ioredis', () => {
  class MockRedis {
    status = 'ready';
    constructor(optsOrUrl: any, maybeOpts?: any) {
      capturedRedisOptions = maybeOpts || optsOrUrl;
    }
    on() {}
    quit() {
      return Promise.resolve('OK');
    }
    disconnect() {}
  }
  return { default: MockRedis };
});

describe('RedisService (Features 52-55 Unit Tests)', () => {
  let service: RedisService;
  let mockConfigService: any;
  let mockRedisClient: any;

  beforeEach(() => {
    mockConfigService = {
      get: vi.fn((key: string, defaultValue?: any) => {
        if (key === 'REDIS_HOST') return '127.0.0.1';
        if (key === 'REDIS_PORT') return 6379;
        if (key === 'REDIS_PASSWORD') return 'secret';
        if (key === 'REDIS_DB') return 1;
        return defaultValue;
      }),
    };

    mockRedisClient = {
      status: 'ready',
      on: vi.fn(),
      quit: vi.fn().mockResolvedValue('OK'),
      disconnect: vi.fn(),
      get: vi.fn(),
      set: vi.fn(),
      del: vi.fn(),
      eval: vi.fn(),
      mget: vi.fn(),
      mset: vi.fn(),
      hset: vi.fn(),
      hgetall: vi.fn(),
      expire: vi.fn(),
      pipeline: vi.fn().mockReturnValue({
        exec: vi.fn().mockResolvedValue([]),
      }),
    };

    service = new RedisService(mockConfigService as unknown as ConfigService);
  });

  afterEach(() => {
    vi.clearAllMocks();
  });

  describe('Feature 52: Resilient Redis Lifecycle & Reconnect', () => {
    it('1. retryStrategy provides continuous exponential backoff capped at 3000ms and never returns null', () => {
      service.onModuleInit();
      expect(capturedRedisOptions).toBeDefined();

      const retryStrategy = capturedRedisOptions.retryStrategy;
      expect(retryStrategy(1)).toBe(500);
      expect(retryStrategy(2)).toBe(1000);
      expect(retryStrategy(5)).toBe(2500);
      expect(retryStrategy(6)).toBe(3000);
      expect(retryStrategy(10)).toBe(3000);
      expect(retryStrategy(100)).toBe(3000);
      expect(retryStrategy(5)).not.toBeNull();
      expect(retryStrategy(6)).not.toBeNull();
    });

    it('2. isReady accurately reflects connection and client readiness status', () => {
      // In default uninitialized state
      expect(service.isReady).toBe(false);

      // Inject mock client with isConnected = true and status = 'ready'
      (service as any).client = mockRedisClient;
      (service as any).isConnected = true;
      expect(service.isReady).toBe(true);

      // When client status is not ready
      mockRedisClient.status = 'reconnecting';
      expect(service.isReady).toBe(false);

      // When isConnected is false
      mockRedisClient.status = 'ready';
      (service as any).isConnected = false;
      expect(service.isReady).toBe(false);
    });

    it('3. onModuleDestroy cleanly disconnects and sets isConnected to false', async () => {
      (service as any).client = mockRedisClient;
      (service as any).isConnected = true;

      await service.onModuleDestroy();

      expect(mockRedisClient.quit).toHaveBeenCalled();
      expect(service.isReady).toBe(false);
      expect(service.getClient()).toBeNull();
    });
  });

  describe('Feature 53: Atomic Rate Limiter via Lua Script', () => {
    beforeEach(() => {
      (service as any).client = mockRedisClient;
      (service as any).isConnected = true;
    });

    it('1. executes atomic Lua script in 1 network roundtrip on rate limit check', async () => {
      mockRedisClient.eval.mockResolvedValueOnce(1);

      const result = await service.checkRateLimit('rate:heartbeat:dev-1', 2, 30);

      expect(result.allowed).toBe(true);
      expect(result.remaining).toBe(1);
      expect(mockRedisClient.eval).toHaveBeenCalledTimes(1);

      const [script, keyCount, key, windowSec] = mockRedisClient.eval.mock.calls[0];
      expect(script).toContain("redis.call('INCR', KEYS[1])");
      expect(script).toContain("redis.call('EXPIRE', KEYS[1], ARGV[1])");
      expect(keyCount).toBe(1);
      expect(key).toBe('rate:heartbeat:dev-1');
      expect(windowSec).toBe(30);
    });

    it('2. blocks when limit is exceeded and calculates remaining as 0', async () => {
      mockRedisClient.eval.mockResolvedValueOnce(3);

      const result = await service.checkRateLimit('rate:heartbeat:dev-1', 2, 30);

      expect(result.allowed).toBe(false);
      expect(result.remaining).toBe(0);
    });

    it('3. falls back gracefully to allow request when Redis is offline or degraded', async () => {
      (service as any).isConnected = false;

      const result = await service.checkRateLimit('rate:heartbeat:dev-1', 2, 30);

      expect(result.allowed).toBe(true);
      expect(result.remaining).toBe(2);
      expect(mockRedisClient.eval).not.toHaveBeenCalled();
    });

    it('4. Lua script contains self-healing check for TTL -1 zombie keys', async () => {
      mockRedisClient.eval.mockResolvedValueOnce(2);

      await service.checkRateLimit('rate:zombie:key', 5, 60);

      const [script] = mockRedisClient.eval.mock.calls[0];
      expect(script).toContain("redis.call('TTL', KEYS[1])");
      expect(script).toContain('if ttl == -1 then');
    });
  });

  describe('Feature 54: Redlock Mutual Exclusion & Disambiguated Returns', () => {
    beforeEach(() => {
      (service as any).client = mockRedisClient;
      (service as any).isConnected = true;
    });

    it('1. acquireLockDetailed returns acquired: true, degraded: false, and token on success', async () => {
      mockRedisClient.set.mockResolvedValueOnce('OK');

      const result = await service.acquireLockDetailed('lock:rel:123', 15000);

      expect(result.acquired).toBe(true);
      expect(result.degraded).toBe(false);
      expect(typeof result.token).toBe('string');
      expect(result.token!.length).toBeGreaterThan(10);
      expect(mockRedisClient.set).toHaveBeenCalledWith(
        'lock:rel:123',
        result.token,
        'PX',
        15000,
        'NX',
      );
    });

    it('2. acquireLockDetailed returns acquired: false, degraded: false on lock contention', async () => {
      mockRedisClient.set.mockResolvedValueOnce(null); // Key already exists (held by another worker)

      const result = await service.acquireLockDetailed('lock:rel:123', 15000);

      expect(result.acquired).toBe(false);
      expect(result.degraded).toBe(false);
      expect(result.token).toBeNull();
    });

    it('3. acquireLockDetailed returns acquired: false, degraded: true when Redis is offline', async () => {
      (service as any).isConnected = false;

      const result = await service.acquireLockDetailed('lock:rel:123', 15000);

      expect(result.acquired).toBe(false);
      expect(result.degraded).toBe(true);
      expect(result.token).toBeNull();
      expect(mockRedisClient.set).not.toHaveBeenCalled();
    });

    it('4. acquireLock maintains backwards-compatibility returning string or null', async () => {
      mockRedisClient.set.mockResolvedValueOnce('OK');
      const token = await service.acquireLock('lock:rel:123', 10000);
      expect(typeof token).toBe('string');

      mockRedisClient.set.mockResolvedValueOnce(null);
      const contentionToken = await service.acquireLock('lock:rel:123', 10000);
      expect(contentionToken).toBeNull();

      (service as any).isConnected = false;
      const degradedToken = await service.acquireLock('lock:rel:123', 10000);
      expect(degradedToken).toBeNull();
    });

    it('5. releaseLock safely checks ownership token via Lua script before deleting', async () => {
      mockRedisClient.eval.mockResolvedValueOnce(1);

      const released = await service.releaseLock('lock:rel:123', 'my-token');

      expect(released).toBe(true);
      expect(mockRedisClient.eval).toHaveBeenCalledWith(
        expect.stringContaining('redis.call("get", KEYS[1]) == ARGV[1]'),
        1,
        'lock:rel:123',
        'my-token',
      );
    });

    it('6. releaseLock returns false if token does not match or key expired', async () => {
      mockRedisClient.eval.mockResolvedValueOnce(0);

      const released = await service.releaseLock('lock:rel:123', 'wrong-token');

      expect(released).toBe(false);
    });
  });

  describe('Feature 55: Redis Pipelining & Multi-key Helpers', () => {
    beforeEach(() => {
      (service as any).client = mockRedisClient;
      (service as any).isConnected = true;
    });

    it('1. pipeline returns ChainableCommander instance when ready', () => {
      const p = service.pipeline();
      expect(p).toBeDefined();
      expect(mockRedisClient.pipeline).toHaveBeenCalled();
    });

    it('2. pipeline returns null when Redis is offline', () => {
      (service as any).isConnected = false;
      const p = service.pipeline();
      expect(p).toBeNull();
    });

    it('3. mget fetches multiple keys in single roundtrip', async () => {
      mockRedisClient.mget.mockResolvedValueOnce(['val1', 'val2', null]);

      const results = await service.mget(['k1', 'k2', 'k3']);

      expect(results).toEqual(['val1', 'val2', null]);
      expect(mockRedisClient.mget).toHaveBeenCalledWith('k1', 'k2', 'k3');
    });

    it('4. mget returns array of nulls when offline without throwing', async () => {
      (service as any).isConnected = false;

      const results = await service.mget(['k1', 'k2']);

      expect(results).toEqual([null, null]);
      expect(mockRedisClient.mget).not.toHaveBeenCalled();
    });

    it('5. mset flattens record and sets multiple keys in single roundtrip', async () => {
      mockRedisClient.mset.mockResolvedValueOnce('OK');

      const success = await service.mset({ k1: 'v1', k2: 'v2' });

      expect(success).toBe(true);
      expect(mockRedisClient.mset).toHaveBeenCalledWith('k1', 'v1', 'k2', 'v2');
    });

    it('6. hset and hgetall manipulate Redis hashes correctly', async () => {
      mockRedisClient.hset.mockResolvedValueOnce(2);
      mockRedisClient.hgetall.mockResolvedValueOnce({ field1: 'val1', field2: 'val2' });

      const setOk = await service.hset('hash:key', { field1: 'val1', field2: 'val2' });
      expect(setOk).toBe(true);
      expect(mockRedisClient.hset).toHaveBeenCalledWith('hash:key', { field1: 'val1', field2: 'val2' });

      const hashData = await service.hgetall('hash:key');
      expect(hashData).toEqual({ field1: 'val1', field2: 'val2' });
      expect(mockRedisClient.hgetall).toHaveBeenCalledWith('hash:key');
    });

    it('7. expire sets TTL on key', async () => {
      mockRedisClient.expire.mockResolvedValueOnce(1);

      const expired = await service.expire('temp:key', 300);

      expect(expired).toBe(true);
      expect(mockRedisClient.expire).toHaveBeenCalledWith('temp:key', 300);
    });
  });
});
