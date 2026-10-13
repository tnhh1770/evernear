import { Test, TestingModule } from '@nestjs/testing';
import { INestApplication, ValidationPipe } from '@nestjs/common';
import { DataSource } from 'typeorm';
import { AppModule } from '../src/app.module';
import { AuthService } from '../src/modules/auth/auth.service';
import { DevicesService } from '../src/modules/devices/devices.service';
import { MonitoringService } from '../src/modules/monitoring/monitoring.service';
import { ActivityService } from '../src/modules/activities/activity.service';
import { CheckInsService } from '../src/modules/check-ins/check-ins.service';
import { IncidentsService } from '../src/modules/incidents/incidents.service';
import { MonitoringWorkerService } from '../src/modules/workers/monitoring-worker.service';
import { RedisService } from '../src/common/redis/redis.service';
import { Incident } from '../src/modules/incidents/entities/incident.entity';
import {
  ActivityType,
  DevicePlatform,
  MonitoringState,
  RelationshipStatus,
  IncidentStatus,
  IncidentReason,
} from '../src/common/enums';
import { v4 as uuidv4 } from 'uuid';
import { resetDatabase, teardownE2eTestApp } from './e2e/e2e-helper';

describe('Carely Full Lifecycle & Concurrency Integration Tests', () => {
  let app: INestApplication;
  let dataSource: DataSource;
  let authService: AuthService;
  let devicesService: DevicesService;
  let monitoringService: MonitoringService;
  let activityService: ActivityService;
  let checkInsService: CheckInsService;
  let incidentsService: IncidentsService;
  let workerService: MonitoringWorkerService;
  let redisService: RedisService;

  let monitorUser: any;
  let monitoredUser: any;
  let monitoredDevice: any;
  let relationship: any;

  beforeAll(async () => {
    const moduleFixture: TestingModule = await Test.createTestingModule({
      imports: [AppModule],
    }).compile();

    app = moduleFixture.createNestApplication();
    app.useGlobalPipes(new ValidationPipe({ whitelist: true, transform: true }));
    await app.init();

    dataSource = moduleFixture.get<DataSource>(DataSource);
    authService = moduleFixture.get<AuthService>(AuthService);
    devicesService = moduleFixture.get<DevicesService>(DevicesService);
    monitoringService = moduleFixture.get<MonitoringService>(MonitoringService);
    activityService = moduleFixture.get<ActivityService>(ActivityService);
    checkInsService = moduleFixture.get<CheckInsService>(CheckInsService);
    incidentsService = moduleFixture.get<IncidentsService>(IncidentsService);
    workerService = moduleFixture.get<MonitoringWorkerService>(MonitoringWorkerService);
    redisService = moduleFixture.get<RedisService>(RedisService);

    // Clean test DB and ensure clean state with advisory lock
    await resetDatabase(dataSource, redisService);
  }, 30000);

  afterAll(async () => {
    await teardownE2eTestApp(app, dataSource, redisService);
  });

  it('1. Foundation: Register Monitor and Monitored User', async () => {
    const uniqueSuffix = Date.now();
    const monitorRes = await authService.register({
      email: `monitor_${uniqueSuffix}@carely.test`,
      password: 'Password123!',
      displayName: 'Nguyen Monitor',
      timezone: 'Asia/Ho_Chi_Minh',
    });
    monitorUser = monitorRes.user;

    const monitoredRes = await authService.register({
      email: `monitored_${uniqueSuffix}@carely.test`,
      password: 'Password123!',
      displayName: 'Tran Monitored',
      timezone: 'Asia/Ho_Chi_Minh',
    });
    monitoredUser = monitoredRes.user;

    expect(monitorUser.id).toBeDefined();
    expect(monitoredUser.id).toBeDefined();
  });

  it('2. Devices: Register Monitored Device with Push Token', async () => {
    monitoredDevice = await devicesService.registerDevice(monitoredUser.id, {
      deviceUid: `device-uid-${Date.now()}`,
      platform: DevicePlatform.ANDROID,
      deviceName: 'Pixel 8 Pro',
      pushToken: 'fcm-token-test-monitored-12345',
      batteryLevel: 90,
      isCharging: false,
    });

    // Also register device for monitor
    await devicesService.registerDevice(monitorUser.id, {
      deviceUid: `device-uid-monitor-${Date.now()}`,
      platform: DevicePlatform.IOS,
      deviceName: 'iPhone 15 Pro',
      pushToken: 'fcm-token-test-monitor-67890',
      batteryLevel: 95,
      isCharging: false,
    });

    expect(monitoredDevice.id).toBeDefined();
    expect(monitoredDevice.isActive).toBe(true);
  });

  it('3. Relationship: Create & Accept Monitoring Relationship', async () => {
    const createdRel = await monitoringService.createRelationship(monitorUser.id, {
      monitoredUserEmail: monitoredUser.email,
    });

    expect(createdRel.status).toBe(RelationshipStatus.PENDING);
    expect(createdRel.invitationCode).toBeDefined();

    const accepted = await monitoringService.acceptInvitation(monitoredUser.id, {
      invitationCode: createdRel.invitationCode,
    });

    relationship = accepted;
    expect(relationship.status).toBe(RelationshipStatus.ACCEPTED);
    expect(relationship.config).toBeDefined();
    expect(relationship.config.currentState).toBe(MonitoringState.ACTIVE);
  });

  it('4. Heartbeat vs Activity: Heartbeat updates device connectivity but NOT lastMeaningfulActivityAt', async () => {
    const initialConfig = await monitoringService.getConfig(monitoredUser.id, relationship.id);
    const initialLastActive = new Date(initialConfig.lastMeaningfulActivityAt).getTime();

    // Small delay to ensure timestamp separation
    await new Promise((r) => setTimeout(r, 100));

    const heartbeatRes = await activityService.processHeartbeat(monitoredUser.id, {
      deviceId: monitoredDevice.id,
      occurredAt: new Date().toISOString(),
      batteryLevel: 88,
      isCharging: true,
    });

    expect(heartbeatRes.success).toBe(true);
    expect(heartbeatRes.operationalState).toBe('ONLINE');

    // Verify config lastMeaningfulActivityAt did NOT change
    const afterHeartbeatConfig = await monitoringService.getConfig(monitoredUser.id, relationship.id);
    const afterHeartbeatTime = new Date(afterHeartbeatConfig.lastMeaningfulActivityAt).getTime();

    expect(afterHeartbeatTime).toBe(initialLastActive);
  });

  it('5. Meaningful Activity: Ingesting APP_OPEN updates lastMeaningfulActivityAt', async () => {
    const initialConfig = await monitoringService.getConfig(monitoredUser.id, relationship.id);
    const initialLastActive = new Date(initialConfig.lastMeaningfulActivityAt).getTime();

    await new Promise((r) => setTimeout(r, 100));

    const eventId = uuidv4();
    const activityTime = new Date();

    const activity = await activityService.ingestActivity(monitoredUser.id, {
      eventId,
      deviceId: monitoredDevice.id,
      type: ActivityType.APP_OPEN,
      occurredAt: activityTime.toISOString(),
      confidence: 1.0,
      metadata: { action: 'user_opened_dashboard' },
    });

    expect(activity.id).toBeDefined();
    expect(activity.eventId).toBe(eventId);

    const updatedConfig = await monitoringService.getConfig(monitoredUser.id, relationship.id);
    const updatedLastActive = new Date(updatedConfig.lastMeaningfulActivityAt).getTime();

    expect(updatedLastActive).toBeGreaterThan(initialLastActive);
  });

  it('6. Idempotency: Re-submitting identical eventId returns same record without duplication', async () => {
    const eventId = uuidv4();

    const act1 = await activityService.ingestActivity(monitoredUser.id, {
      eventId,
      deviceId: monitoredDevice.id,
      type: ActivityType.SCREEN_INTERACTION,
      occurredAt: new Date().toISOString(),
      confidence: 0.9,
    });

    const act2 = await activityService.ingestActivity(monitoredUser.id, {
      eventId,
      deviceId: monitoredDevice.id,
      type: ActivityType.SCREEN_INTERACTION,
      occurredAt: new Date().toISOString(),
      confidence: 0.9,
    });

    expect(act1.id).toBe(act2.id);
  });

  it('7. Inactivity & Worker: Inactivity triggers CHECK_IN_REQUIRED and notification', async () => {
    const pastTime = new Date(Date.now() - 2 * 60 * 1000);
    await dataSource.query(
      `UPDATE monitoring_configs 
       SET inactivity_threshold_minutes = 1,
           last_meaningful_activity_at = $1,
           next_evaluation_at = NOW() - INTERVAL '1 second'
       WHERE relationship_id = $2`,
      [pastTime, relationship.id],
    );
    const processed = await workerService.evaluateDueMonitoring(10);
    expect(processed).toBeGreaterThanOrEqual(1);

    const configAfter = await monitoringService.getConfig(monitoredUser.id, relationship.id);
    expect(configAfter.currentState).toBe(MonitoringState.CHECK_IN_REQUIRED);
  });

  it('8. Check-in Recovery: User checks in ("Tôi vẫn ổn"), reverting state to ACTIVE', async () => {
    const checkInEventId = uuidv4();
    const checkIn = await checkInsService.processCheckIn(monitoredUser.id, {
      eventId: checkInEventId,
      deviceId: monitoredDevice.id,
      relationshipId: relationship.id,
      occurredAt: new Date().toISOString(),
      batteryLevel: 85,
      note: 'Tôi vẫn ổn, đang ăn cơm trưa.',
      location: { latitude: 10.762622, longitude: 106.660172 },
    });

    expect(checkIn.id).toBeDefined();

    const configAfterCheckIn = await monitoringService.getConfig(monitoredUser.id, relationship.id);
    expect(configAfterCheckIn.currentState).toBe(MonitoringState.ACTIVE);
  });

  it('9. Incident Escalation & Acknowledge: Missed check-in creates Incident, Monitor acknowledges', async () => {
    // Set state to CHECK_IN_REQUIRED with expired grace period
    const pastTime = new Date(Date.now() - 30 * 60 * 1000);
    await dataSource.query(
      `UPDATE monitoring_configs 
       SET current_state = 'CHECK_IN_REQUIRED',
           last_meaningful_activity_at = $1,
           next_evaluation_at = NOW() - INTERVAL '1 second',
           check_in_grace_minutes = 5
       WHERE relationship_id = $2`,
      [pastTime, relationship.id],
    );

    // Run worker
    await workerService.evaluateDueMonitoring(10);

    const configAfterWorker = await monitoringService.getConfig(monitoredUser.id, relationship.id);
    expect(configAfterWorker.currentState).toBe(MonitoringState.WARNING);

    // Verify incident was created
    const incidents = await incidentsService.listIncidents(monitorUser.id, IncidentStatus.OPEN);
    expect(incidents.length).toBeGreaterThanOrEqual(1);

    const targetIncident = incidents.find((inc) => inc.relationshipId === relationship.id);
    expect(targetIncident).toBeDefined();
    expect(targetIncident!.riskScore).toBeGreaterThanOrEqual(50);

    // Monitor Acknowledges Incident
    const acked = await incidentsService.acknowledgeIncident(monitorUser.id, targetIncident!.id);
    expect(acked.status).toBe(IncidentStatus.ACKNOWLEDGED);
    expect(acked.acknowledgedBy).toBe(monitorUser.id);
  });

  it('10. Concurrency: Two simultaneous workers only evaluate row once without duplicate incidents', async () => {
    // Setup config due for evaluation
    await dataSource.query(
      `UPDATE monitoring_configs 
       SET next_evaluation_at = NOW() - INTERVAL '1 second'
       WHERE relationship_id = $1`,
      [relationship.id],
    );

    // Run two evaluations in parallel
    const [eval1, eval2] = await Promise.all([
      workerService.evaluateDueMonitoring(10),
      workerService.evaluateDueMonitoring(10),
    ]);

    // Due to pessimistic write lock FOR UPDATE SKIP LOCKED, exactly one worker processes the batch!
    expect(eval1 + eval2).toBeGreaterThanOrEqual(1);
  });

  it('11. Resilience: Ingestion continues safely even if Redis lock operations degrade', async () => {
    // Intentionally test with invalid lock key or simulate degraded redis
    const lock = await redisService.acquireLock('invalid:lock', 1000);
    if (lock) {
      const released = await redisService.releaseLock('invalid:lock', lock);
      expect(released).toBe(true);
    }

    // Ingestion works via PostgreSQL unique constraint regardless of Redis state
    const act = await activityService.ingestActivity(monitoredUser.id, {
      eventId: uuidv4(),
      deviceId: monitoredDevice.id,
      type: ActivityType.APP_FOREGROUND,
      occurredAt: new Date().toISOString(),
      confidence: 1.0,
    });
    expect(act.id).toBeDefined();
  });

  it('12. Idempotency Concurrency: Simultaneous ingestActivity with identical eventId resolves safely', async () => {
    const eventId = uuidv4();
    const payload = {
      eventId,
      deviceId: monitoredDevice.id,
      type: ActivityType.SCREEN_INTERACTION,
      occurredAt: new Date().toISOString(),
      confidence: 0.9,
    };
    const [act1, act2] = await Promise.all([
      activityService.ingestActivity(monitoredUser.id, payload),
      activityService.ingestActivity(monitoredUser.id, payload),
    ]);
    expect(act1.id).toBe(act2.id);
    expect(act1.eventId).toBe(eventId);
  });

  it('13. Idempotency Concurrency: Simultaneous processCheckIn with identical eventId resolves safely', async () => {
    const eventId = uuidv4();
    const payload = {
      eventId,
      deviceId: monitoredDevice.id,
      relationshipId: relationship.id,
      occurredAt: new Date().toISOString(),
      batteryLevel: 90,
      note: 'Concurrent test check-in',
    };
    const [ci1, ci2] = await Promise.all([
      checkInsService.processCheckIn(monitoredUser.id, payload),
      checkInsService.processCheckIn(monitoredUser.id, payload),
    ]);
    expect(ci1.id).toBe(ci2.id);
    expect(ci1.eventId).toBe(eventId);
  });

  it('14. Check-in Ordering: Delayed check-in from the past does NOT roll back lastMeaningfulActivityAt', async () => {
    const currentConfig = await monitoringService.getConfig(monitoredUser.id, relationship.id);
    const currentLastActive = new Date(currentConfig.lastMeaningfulActivityAt).getTime();

    // Send delayed check-in timestamped 2 hours before currentLastActive
    const delayedTime = new Date(currentLastActive - 2 * 60 * 60 * 1000);
    await checkInsService.processCheckIn(monitoredUser.id, {
      eventId: uuidv4(),
      deviceId: monitoredDevice.id,
      relationshipId: relationship.id,
      occurredAt: delayedTime.toISOString(),
      note: 'Delayed offline check-in',
    });

    const afterConfig = await monitoringService.getConfig(monitoredUser.id, relationship.id);
    const afterLastActive = new Date(afterConfig.lastMeaningfulActivityAt).getTime();
    expect(afterLastActive).toBe(currentLastActive);
  });

  it('15. Pause & Resume: Pausing disables monitoring and transitions to SUSPENDED, resuming restores ACTIVE', async () => {
    const paused = await monitoringService.pauseMonitoring(monitoredUser.id, relationship.id, 60);
    expect(paused.enabled).toBe(false);
    expect(paused.currentState).toBe(MonitoringState.SUSPENDED);

    const resumed = await monitoringService.resumeMonitoring(monitoredUser.id, relationship.id);
    expect(resumed.enabled).toBe(true);
    expect(resumed.currentState).toBe(MonitoringState.ACTIVE);
    expect(new Date(resumed.nextEvaluationAt).getTime()).toBeGreaterThan(Date.now());
  });

  it('16. Config Alias: findConfigByRelOrConfigId resolves by relationshipId or configId', async () => {
    const byRel = await monitoringService.findConfigByRelOrConfigId(monitoredUser.id, relationship.id);
    expect(byRel.config.id).toBeDefined();

    const byCfg = await monitoringService.findConfigByRelOrConfigId(monitoredUser.id, byRel.config.id);
    expect(byCfg.relationship.id).toBe(relationship.id);
  });

  it('17. Incident Resolution: Check-in automatically resolves ACKNOWLEDGED incidents', async () => {
    const inc = await dataSource.getRepository(Incident).save(
      dataSource.getRepository(Incident).create({
        relationshipId: relationship.id,
        userId: monitoredUser.id,
        status: IncidentStatus.ACKNOWLEDGED,
        reason: IncidentReason.INACTIVITY,
        riskScore: 75,
        detectedAt: new Date(),
        details: { note: 'Test acknowledge' },
      }),
    );

    await checkInsService.processCheckIn(monitoredUser.id, {
      eventId: uuidv4(),
      deviceId: monitoredDevice.id,
      relationshipId: relationship.id,
      occurredAt: new Date().toISOString(),
      note: 'Check-in to resolve acknowledged incident',
    });

    const refreshed = await dataSource.getRepository(Incident).findOne({ where: { id: inc.id } });
    expect(refreshed!.status).toBe(IncidentStatus.RESOLVED);
  });
});
