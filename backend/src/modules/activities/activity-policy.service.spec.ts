import { Test, TestingModule } from '@nestjs/testing';
import { getRepositoryToken } from '@nestjs/typeorm';
import { ActivityPolicyService } from './activity-policy.service';
import { ActivityPolicy } from './entities/activity-policy.entity';
import { ActivityType } from '../../common/enums';

describe('ActivityPolicyService', () => {
  let service: ActivityPolicyService;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        ActivityPolicyService,
        {
          provide: getRepositoryToken(ActivityPolicy),
          useValue: {
            findOne: vi.fn().mockResolvedValue(null), // fallback to static defaults
          },
        },
      ],
    }).compile();

    service = module.get<ActivityPolicyService>(ActivityPolicyService);
  });

  it('should treat HEARTBEAT with weight 0.0 and isMeaningful = false', async () => {
    const policy = await service.evaluatePolicy(ActivityType.HEARTBEAT);
    expect(policy.weight).toBe(0.0);
    expect(policy.isMeaningful).toBe(false);
    expect(service.isMeaningful(ActivityType.HEARTBEAT, 1.0, policy)).toBe(false);
  });

  it('should treat CHECK_IN with weight 1.0 and isMeaningful = true', async () => {
    const policy = await service.evaluatePolicy(ActivityType.CHECK_IN);
    expect(policy.weight).toBe(1.0);
    expect(policy.isMeaningful).toBe(true);
    expect(service.isMeaningful(ActivityType.CHECK_IN, 1.0, policy)).toBe(true);
  });

  it('should treat APP_FOREGROUND with weight 0.8 and check confidence threshold', async () => {
    const policy = await service.evaluatePolicy(ActivityType.APP_FOREGROUND);
    expect(policy.weight).toBe(0.8);
    expect(policy.isMeaningful).toBe(true);
    // Confidence 0.5 < minConfidence 0.8 -> false
    expect(service.isMeaningful(ActivityType.APP_FOREGROUND, 0.5, policy)).toBe(false);
    // Confidence 0.9 >= minConfidence 0.8 -> true
    expect(service.isMeaningful(ActivityType.APP_FOREGROUND, 0.9, policy)).toBe(true);
  });

  it('should return policy synchronously via getCachedPolicy without database access', () => {
    const cached = service.getCachedPolicy(ActivityType.STEP_DETECTED);
    expect(cached.weight).toBe(0.6);
    expect(cached.minConfidence).toBe(0.5);
    expect(cached.isMeaningful).toBe(true);
  });
});

