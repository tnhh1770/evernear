import { Test, TestingModule } from '@nestjs/testing';
import { INestApplication, ValidationPipe } from '@nestjs/common';
import { DataSource, QueryRunner } from 'typeorm';
import request from 'supertest';
import Redis from 'ioredis';
import { vi } from 'vitest';
import { AppModule } from '../../src/app.module';
import { DevicePlatform } from '../../src/common/enums';

export interface TestUserContext {
  id: string;
  email: string;
  displayName: string;
  accessToken: string;
  refreshToken: string;
}

export const E2E_DB_RESET_LOCK_ID = 884729103;
export const E2E_SUITE_LOCK_ID = 884729103;

/** Module-level fallback reference to the active QueryRunner holding the advisory lock */
let activeSuiteLockRunner: QueryRunner | null = null;

/**
 * Acquire exclusive PostgreSQL session-level advisory lock for the current test suite.
 * Blocks until any preceding suite releases the lock or terminates.
 */
export async function acquireE2eSessionLock(dataSource: DataSource): Promise<QueryRunner> {
  if (!dataSource || !dataSource.isInitialized) {
    throw new Error('Cannot acquire advisory lock on uninitialized DataSource');
  }

  // Re-entrancy check: return active lock runner if already held on this DataSource
  const dsRunner = (dataSource as any).__e2eLockRunner;
  if (dsRunner && !dsRunner.isReleased) {
    return dsRunner;
  }

  // Clean up any stale activeSuiteLockRunner from prior suite if not already released
  if (activeSuiteLockRunner && !activeSuiteLockRunner.isReleased) {
    try {
      await activeSuiteLockRunner.query(`SELECT pg_advisory_unlock(${E2E_DB_RESET_LOCK_ID});`);
    } catch {
      // Ignore cleanup error
    }
    try {
      await activeSuiteLockRunner.release();
    } catch {
      // Ignore cleanup error
    }
    activeSuiteLockRunner = null;
  }

  const queryRunner = dataSource.createQueryRunner();
  await queryRunner.connect();

  // Session-scoped advisory lock (pg_advisory_lock):
  // Exclusive to this database session, held until pg_advisory_unlock or connection close.
  await queryRunner.query(`SELECT pg_advisory_lock(${E2E_DB_RESET_LOCK_ID});`);

  (dataSource as any).__e2eLockRunner = queryRunner;
  activeSuiteLockRunner = queryRunner;
  return queryRunner;
}

export const acquireE2eSuiteLock = acquireE2eSessionLock;

/**
 * Release exclusive PostgreSQL session-level advisory lock held by the current test suite.
 */
export async function releaseE2eSessionLock(
  dataSourceOrRunner?: DataSource | QueryRunner,
): Promise<void> {
  let queryRunner: QueryRunner | null = null;
  let ds: DataSource | undefined;

  if (dataSourceOrRunner) {
    if (
      'createQueryRunner' in dataSourceOrRunner &&
      typeof (dataSourceOrRunner as DataSource).createQueryRunner === 'function'
    ) {
      ds = dataSourceOrRunner as DataSource;
      queryRunner = (ds as any).__e2eLockRunner || activeSuiteLockRunner;
    } else if ('query' in dataSourceOrRunner && 'release' in dataSourceOrRunner) {
      queryRunner = dataSourceOrRunner as QueryRunner;
    }
  }

  if (!queryRunner) {
    queryRunner = activeSuiteLockRunner;
  }

  if (!queryRunner) return;

  try {
    if (!queryRunner.isReleased) {
      await queryRunner.query(`SELECT pg_advisory_unlock(${E2E_DB_RESET_LOCK_ID});`);
    }
  } catch {
    // Ignore error if connection was already closed
  } finally {
    try {
      if (!queryRunner.isReleased) {
        await queryRunner.release();
      }
    } catch {
      // Ignore error if already released
    }
    if (queryRunner === activeSuiteLockRunner) {
      activeSuiteLockRunner = null;
    }
    if (ds) {
      delete (ds as any).__e2eLockRunner;
    }
  }
}

export const releaseE2eSuiteLock = releaseE2eSessionLock;

export async function createE2eTestApp(): Promise<{
  app: INestApplication;
  moduleFixture: TestingModule;
  dataSource: DataSource;
  suiteLockRunner?: QueryRunner;
}> {
  const moduleFixture: TestingModule = await Test.createTestingModule({
    imports: [AppModule],
  }).compile();

  const app = moduleFixture.createNestApplication();
  app.useGlobalPipes(new ValidationPipe({ whitelist: true, transform: true }));
  await app.init();

  const dataSource = moduleFixture.get<DataSource>(DataSource);

  return { app, moduleFixture, dataSource };
}

export async function setupE2eTestApp(redisClientOrService?: any): Promise<{
  app: INestApplication;
  moduleFixture: TestingModule;
  dataSource: DataSource;
}> {
  const context = await createE2eTestApp();
  await resetDatabase(context.dataSource, redisClientOrService);
  return context;
}

export async function purgeRedis(redisClientOrService?: any): Promise<void> {
  let client: Redis | null = null;
  let ownClient = false;

  if (redisClientOrService) {
    if (redisClientOrService.client && typeof redisClientOrService.client.keys === 'function') {
      client = redisClientOrService.client;
    } else if (typeof redisClientOrService.keys === 'function') {
      client = redisClientOrService as Redis;
    }
  }

  if (!client) {
    try {
      client = new Redis({
        host: process.env.REDIS_HOST || 'localhost',
        port: Number(process.env.REDIS_PORT) || 6379,
        maxRetriesPerRequest: 1,
        connectTimeout: 2000,
        lazyConnect: true,
      });
      await client.connect();
      ownClient = true;
    } catch {
      client = null;
    }
  }

  if (client) {
    try {
      const patterns = [
        'monitoring:lock:*',
        'lock:*',
        'rate:heartbeat:*',
        'rate-limit:*',
        'rate:*',
        'idempotency:*',
      ];
      for (const pattern of patterns) {
        const keys = await client.keys(pattern);
        if (keys.length > 0) {
          await client.del(...keys);
        }
      }
    } catch {
      // Graceful fallback
    } finally {
      if (ownClient && client) {
        await client.quit().catch(() => client?.disconnect());
      }
    }
  }
}

export async function resetDatabase(
  dataSource: DataSource,
  redisClientOrService?: any,
): Promise<void> {
  if (!dataSource.isInitialized) return;

  // 1. Acquire exclusive session-level advisory lock (blocks concurrent suites)
  const lockRunner = await acquireE2eSessionLock(dataSource);

  try {
    // 2. Safe reverse-topological deletion on the dedicated lock runner connection
    const dbName = (dataSource.options as any)?.database;
    if (dbName === 'carely_db' && process.env.NODE_ENV !== 'test_carely_db_force') {
      // Safety guard: Protect development database from full wipe. Only remove test users.
      await lockRunner.query(`
        DELETE FROM notification_deliveries;
        DELETE FROM incident_events;
        DELETE FROM incidents;
        DELETE FROM notification_channels;
        DELETE FROM check_ins;
        DELETE FROM activities;
        DELETE FROM monitoring_schedule_windows;
        DELETE FROM monitoring_configs;
        DELETE FROM monitoring_relationships;
        DELETE FROM pairing_invitations;
        DELETE FROM devices WHERE user_id IN (SELECT id FROM users WHERE email LIKE '%@carely.test' OR email LIKE '%@test.carely' OR email LIKE '%@privaterelay.appleid.com' OR email LIKE '%test%@%');
        DELETE FROM locations WHERE user_id IN (SELECT id FROM users WHERE email LIKE '%@carely.test' OR email LIKE '%@test.carely' OR email LIKE '%@privaterelay.appleid.com' OR email LIKE '%test%@%');
        DELETE FROM users WHERE email LIKE '%@carely.test' OR email LIKE '%@test.carely' OR email LIKE '%@privaterelay.appleid.com' OR email LIKE '%test%@%';
      `);
    } else {
      await lockRunner.query(`
        DELETE FROM notification_deliveries;
        DELETE FROM incident_events;
        DELETE FROM incidents;
        DELETE FROM notification_channels;
        DELETE FROM check_ins;
        DELETE FROM activities;
        DELETE FROM activity_policies;
        DELETE FROM monitoring_schedule_windows;
        DELETE FROM monitoring_configs;
        DELETE FROM monitoring_relationships;
        DELETE FROM pairing_invitations;
        DELETE FROM devices;
        DELETE FROM audit_logs;
        DELETE FROM locations;
        DELETE FROM users;
      `);
    }

    // 3. Re-seed default baseline activity policies
    await lockRunner.query(`
      INSERT INTO activity_policies (relationship_id, activity_type, weight, min_confidence, cooldown_seconds, is_meaningful)
      VALUES
        (NULL, 'CHECK_IN', 1.0, 0.9, 0, TRUE),
        (NULL, 'APP_FOREGROUND', 0.8, 0.8, 60, TRUE),
        (NULL, 'APP_OPEN', 0.8, 0.8, 60, TRUE),
        (NULL, 'SCREEN_INTERACTION', 0.7, 0.7, 60, TRUE),
        (NULL, 'STEP_DETECTED', 0.6, 0.5, 300, TRUE),
        (NULL, 'DEVICE_MOTION', 0.4, 0.5, 300, TRUE),
        (NULL, 'CHARGER_CONNECTED', 0.2, 0.8, 300, TRUE),
        (NULL, 'CHARGER_DISCONNECTED', 0.2, 0.8, 300, TRUE),
        (NULL, 'LOCATION_UPDATE', 0.3, 0.7, 300, TRUE),
        (NULL, 'HEARTBEAT', 0.0, 1.0, 60, FALSE)
      ON CONFLICT DO NOTHING;
    `);
  } catch (err) {
    // If reset queries fail, release lock so subsequent suites aren't deadlocked
    await releaseE2eSessionLock(dataSource);
    throw err;
  }

  // NOTE: lockRunner is intentionally NOT released here.
  // The session lock remains held for the full duration of this suite's test execution.

  // 4. Clean Redis State (distributed locks and rate limiters)
  await purgeRedis(redisClientOrService);
}

export async function teardownE2eTestApp(
  app?: INestApplication,
  dataSource?: DataSource,
  redisClientOrService?: any,
): Promise<void> {
  try {
    vi.restoreAllMocks();
  } catch {
    // Ignore outside vitest runner
  }

  try {
    await purgeRedis(redisClientOrService);
  } catch {
    // Ignore Redis errors
  }

  // Resolve DataSource from argument or NestJS application context
  const resolvedDataSource =
    dataSource || (app ? app.get(DataSource, { strict: false }) : undefined);

  // Release the session-level advisory lock, permitting the next queued test suite to run
  await releaseE2eSessionLock(resolvedDataSource);

  if (app) {
    try {
      await app.close();
    } catch {
      // Ignore app close error
    }
  }
}

export async function registerAndLoginUser(
  app: INestApplication,
  prefix: string,
  customEmail?: string,
): Promise<TestUserContext> {
  const unique = `${prefix}_${Date.now()}_${Math.floor(Math.random() * 10000)}`;
  const email = customEmail || `${unique}@carely.test`;
  const password = 'Password123!';
  const displayName = `User ${prefix}`;

  const res = await request(app.getHttpServer())
    .post('/api/v1/auth/register')
    .send({
      email,
      password,
      displayName,
      timezone: 'Asia/Ho_Chi_Minh',
    });

  if (res.status !== 201) {
    throw new Error(`Failed to register test user: ${res.status} - ${JSON.stringify(res.body)}`);
  }

  return {
    id: res.body.user.id,
    email: res.body.user.email,
    displayName: res.body.user.displayName,
    accessToken: res.body.accessToken,
    refreshToken: res.body.refreshToken,
  };
}

export async function registerTestDevice(
  app: INestApplication,
  accessToken: string,
  options?: {
    platform?: DevicePlatform;
    deviceName?: string;
    pushToken?: string;
    batteryLevel?: number;
    isCharging?: boolean;
    deviceUid?: string;
  },
): Promise<any> {
  const uid = options?.deviceUid || `device-uid-${Date.now()}-${Math.floor(Math.random() * 10000)}`;
  const res = await request(app.getHttpServer())
    .post('/api/v1/devices')
    .set('Authorization', `Bearer ${accessToken}`)
    .send({
      deviceUid: uid,
      platform: options?.platform || DevicePlatform.ANDROID,
      deviceName: options?.deviceName || 'Pixel 8 Pro Test',
      pushToken: options?.pushToken || `push-token-${uid}`,
      batteryLevel: options?.batteryLevel ?? 85,
      isCharging: options?.isCharging ?? false,
    });

  if (res.status !== 201 && res.status !== 200) {
    throw new Error(`Failed to register device: ${res.status} - ${JSON.stringify(res.body)}`);
  }

  return res.body;
}

export async function pairMonitoringRelationship(
  app: INestApplication,
  monitorToken: string,
  monitoredUser: TestUserContext,
): Promise<{ relationship: any; config: any }> {
  const inviteRes = await request(app.getHttpServer())
    .post('/api/v1/monitoring/relationships')
    .set('Authorization', `Bearer ${monitorToken}`)
    .send({ monitoredUserEmail: monitoredUser.email });

  if (inviteRes.status !== 201) {
    throw new Error(`Failed to create relationship invite: ${inviteRes.status} - ${JSON.stringify(inviteRes.body)}`);
  }

  const invitationCode = inviteRes.body.invitationCode;

  const acceptRes = await request(app.getHttpServer())
    .post('/api/v1/monitoring/relationships/accept')
    .set('Authorization', `Bearer ${monitoredUser.accessToken}`)
    .send({ invitationCode });

  if (acceptRes.status !== 200) {
    throw new Error(`Failed to accept invitation: ${acceptRes.status} - ${JSON.stringify(acceptRes.body)}`);
  }

  return {
    relationship: acceptRes.body,
    config: acceptRes.body.config,
  };
}
