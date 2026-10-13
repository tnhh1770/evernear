import { describe, it, expect, vi, beforeEach } from 'vitest';
import { UnauthorizedException } from '@nestjs/common';
import { JwtStrategy } from './jwt.strategy';
import { User } from '../users/entities/user.entity';

describe('JwtStrategy (User Claims Cache Unit Tests)', () => {
  let strategy: JwtStrategy;
  let userRepo: any;
  let configService: any;

  beforeEach(() => {
    JwtStrategy.clearCache();
    userRepo = {
      findOne: vi.fn(),
    };
    configService = {
      get: vi.fn().mockReturnValue('test-jwt-secret-key-32characters-long!'),
    };
    strategy = new JwtStrategy(configService, userRepo);
  });

  it('1. should query database on cache miss and store user in cache', async () => {
    const mockUser = {
      id: 'user-uuid-1',
      email: 'user1@carely.test',
      displayName: 'User One',
    } as User;

    userRepo.findOne.mockResolvedValueOnce(mockUser);

    const user = await strategy.validate({ sub: 'user-uuid-1', email: 'user1@carely.test' });
    expect(user).toBe(mockUser);
    expect(userRepo.findOne).toHaveBeenCalledTimes(1);

    // Second call with same sub should hit cache with ZERO extra DB queries
    const cachedUser = await strategy.validate({ sub: 'user-uuid-1', email: 'user1@carely.test' });
    expect(cachedUser).toBe(mockUser);
    expect(userRepo.findOne).toHaveBeenCalledTimes(1); // Still 1!
  });

  it('2. should re-query database after cache invalidation', async () => {
    const mockUser = {
      id: 'user-uuid-2',
      email: 'user2@carely.test',
      displayName: 'User Two',
    } as User;

    userRepo.findOne.mockResolvedValue(mockUser);

    await strategy.validate({ sub: 'user-uuid-2', email: 'user2@carely.test' });
    expect(userRepo.findOne).toHaveBeenCalledTimes(1);

    // Invalidate cache (e.g. on logout or password change)
    JwtStrategy.invalidateUserCache('user-uuid-2');

    // Next request should hit database again
    await strategy.validate({ sub: 'user-uuid-2', email: 'user2@carely.test' });
    expect(userRepo.findOne).toHaveBeenCalledTimes(2);
  });

  it('3. should throw UnauthorizedException and delete cached entry if user not found', async () => {
    userRepo.findOne.mockResolvedValueOnce(null);

    await expect(
      strategy.validate({ sub: 'non-existent-user', email: 'missing@carely.test' }),
    ).rejects.toThrow(UnauthorizedException);
  });
});
