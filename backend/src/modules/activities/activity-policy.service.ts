import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, IsNull } from 'typeorm';
import { ActivityPolicy } from './entities/activity-policy.entity';
import { ActivityType } from '../../common/enums';

export interface EvaluatedPolicy {
  weight: number;
  minConfidence: number;
  cooldownSeconds: number;
  isMeaningful: boolean;
}

@Injectable()
export class ActivityPolicyService implements OnModuleInit {
  private readonly logger = new Logger(ActivityPolicyService.name);

  // Fallback defaults as specified in requirements
  private static readonly SYSTEM_DEFAULTS: Record<ActivityType, EvaluatedPolicy> = {
    [ActivityType.CHECK_IN]: {
      weight: 1.0,
      minConfidence: 0.8,
      cooldownSeconds: 0,
      isMeaningful: true,
    },
    [ActivityType.APP_FOREGROUND]: {
      weight: 0.8,
      minConfidence: 0.8,
      cooldownSeconds: 60,
      isMeaningful: true,
    },
    [ActivityType.APP_OPEN]: {
      weight: 0.8,
      minConfidence: 0.8,
      cooldownSeconds: 60,
      isMeaningful: true,
    },
    [ActivityType.SCREEN_INTERACTION]: {
      weight: 0.7,
      minConfidence: 0.7,
      cooldownSeconds: 60,
      isMeaningful: true,
    },
    [ActivityType.STEP_DETECTED]: {
      weight: 0.6,
      minConfidence: 0.5,
      cooldownSeconds: 300,
      isMeaningful: true,
    },
    [ActivityType.DEVICE_MOTION]: {
      weight: 0.4,
      minConfidence: 0.5,
      cooldownSeconds: 300,
      isMeaningful: true,
    },
    [ActivityType.CHARGER_CONNECTED]: {
      weight: 0.2,
      minConfidence: 0.8,
      cooldownSeconds: 300,
      isMeaningful: true,
    },
    [ActivityType.CHARGER_DISCONNECTED]: {
      weight: 0.2,
      minConfidence: 0.8,
      cooldownSeconds: 300,
      isMeaningful: true,
    },
    [ActivityType.LOCATION_UPDATE]: {
      weight: 0.3,
      minConfidence: 0.7,
      cooldownSeconds: 300,
      isMeaningful: true,
    },
    [ActivityType.HEARTBEAT]: {
      weight: 0.0,
      minConfidence: 1.0,
      cooldownSeconds: 60,
      isMeaningful: false, // TUYỆT ĐỐI không đồng nhất heartbeat = activity!
    },
  };

  private readonly defaultPolicyCache = new Map<ActivityType, EvaluatedPolicy>();

  constructor(
    @InjectRepository(ActivityPolicy)
    private readonly policyRepo: Repository<ActivityPolicy>,
  ) {
    // Pre-populate with system defaults
    for (const [type, policy] of Object.entries(ActivityPolicyService.SYSTEM_DEFAULTS)) {
      this.defaultPolicyCache.set(type as ActivityType, policy);
    }
  }

  async onModuleInit() {
    await this.warmDefaultPolicies();
  }

  async warmDefaultPolicies(): Promise<void> {
    try {
      if (this.policyRepo && typeof this.policyRepo.find === 'function') {
        const dbDefaults = await this.policyRepo.find({
          where: { relationshipId: IsNull() },
        });
        if (dbDefaults && dbDefaults.length > 0) {
          for (const p of dbDefaults) {
            this.defaultPolicyCache.set(p.activityType, {
              weight: Number(p.weight),
              minConfidence: Number(p.minConfidence),
              cooldownSeconds: p.cooldownSeconds,
              isMeaningful: p.isMeaningful,
            });
          }
        }
      }
    } catch {
      // Graceful fallback to pre-populated system defaults
    }
  }

  getCachedPolicy(type: ActivityType): EvaluatedPolicy {
    return (
      this.defaultPolicyCache.get(type) ||
      ActivityPolicyService.SYSTEM_DEFAULTS[type] || {
        weight: 0.1,
        minConfidence: 0.5,
        cooldownSeconds: 60,
        isMeaningful: false,
      }
    );
  }

  async evaluatePolicy(
    type: ActivityType,
    relationshipId?: string,
  ): Promise<EvaluatedPolicy> {
    // Check for relationship override first
    if (relationshipId) {
      const customPolicy = await this.policyRepo.findOne({
        where: { relationshipId, activityType: type },
      });
      if (customPolicy) {
        return {
          weight: Number(customPolicy.weight),
          minConfidence: Number(customPolicy.minConfidence),
          cooldownSeconds: customPolicy.cooldownSeconds,
          isMeaningful: customPolicy.isMeaningful,
        };
      }
    }

    // Fast path: cached system-level policy (0 DB roundtrips)
    return this.getCachedPolicy(type);
  }

  isMeaningful(type: ActivityType, confidence: number, policy: EvaluatedPolicy): boolean {
    if (!policy.isMeaningful || policy.weight <= 0.0) {
      return false;
    }
    return confidence >= policy.minConfidence;
  }
}

