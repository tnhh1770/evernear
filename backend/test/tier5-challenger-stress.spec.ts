import { describe, it, expect, beforeAll, afterAll, beforeEach, vi } from 'vitest';
import { Test, TestingModule } from '@nestjs/testing';
import { INestApplication, ValidationPipe } from '@nestjs/common';
import { DataSource } from 'typeorm';
import { AppModule } from '../src/app.module';
import { AuthService } from '../src/modules/auth/auth.service';
import { DevicesService } from '../src/modules/devices/devices.service';
import { MonitoringService } from '../src/modules/monitoring/monitoring.service';
import { ActivityService } from '../src/modules/activities/activity.service';
import { CheckInsService } from '../src/modules/check-ins/check-ins.service';
import { MonitoringWorkerService } from '../src/modules/workers/monitoring-worker.service';
import { NotificationsService } from '../src/modules/notifications/notifications.service';
import { FcmPushChannel } from '../src/modules/notifications/channels/fcm-push.channel';
import { SmsChannel, TelegramChannel } from '../src/modules/notifications/channels/stubs.channel';
import { RedisService } from '../src/common/redis/redis.service';
import { Incident } from '../src/modules/incidents/entities/incident.entity';
import { IncidentEvent } from '../src/modules/incidents/entities/incident-event.entity';
import { NotificationDelivery } from '../src/modules/notifications/entities/notification-delivery.entity';
import { MonitoringConfig } from '../src/modules/monitoring/entities/monitoring-config.entity';
import { User } from '../src/modules/users/entities/user.entity';
import { Device } from '../src/modules/devices/entities/device.entity';
import { resetDatabase, teardownE2eTestApp } from './e2e/e2e-helper';
import {
  ActivityType,
  DevicePlatform,
  MonitoringState,
  IncidentStatus,
  IncidentReason,
  IncidentEventType,
  NotificationChannelType,
  NotificationDeliveryStatus,
} from '../src/common/enums';
import { v4 as uuidv4 } from 'uuid';

describe('Tier 5 Adversarial Stress & Challenger Harness', () => {
  let app: INestApplication;
  let dataSource: DataSource;
  let authService: AuthService;
  let devicesService: DevicesService;
  let monitoringService: MonitoringService;
  let activityService: ActivityService;
  let checkInsService: CheckInsService;
  let workerService: MonitoringWorkerService;
  let notificationsService: NotificationsService;
  let fcmChannel: FcmPushChannel;
  let smsChannel: SmsChannel;
  let telegramChannel: TelegramChannel;
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
    workerService = moduleFixture.get<MonitoringWorkerService>(MonitoringWorkerService);
    notificationsService = moduleFixture.get<NotificationsService>(NotificationsService);
    fcmChannel = moduleFixture.get<FcmPushChannel>(FcmPushChannel);
    smsChannel = moduleFixture.get<SmsChannel>(SmsChannel);
    telegramChannel = moduleFixture.get<TelegramChannel>(TelegramChannel);
    redisService = moduleFixture.get<RedisService>(RedisService);

    // Reset database to pristine state with advisory lock
    await resetDatabase(dataSource, redisService);

    // Setup base users
    const uniqueSuffix = Date.now();
    const monitorRes = await authService.register({
      email: `challenger_monitor_${uniqueSuffix}@carely.test`,
      password: 'Password123!',
      displayName: 'Monitor Challenger',
      timezone: 'Asia/Ho_Chi_Minh',
    });
    monitorUser = monitorRes.user;

    const monitoredRes = await authService.register({
      email: `challenger_monitored_${uniqueSuffix}@carely.test`,
      password: 'Password123!',
      displayName: 'Monitored Challenger',
      timezone: 'Asia/Ho_Chi_Minh',
    });
    monitoredUser = monitoredRes.user;

    // Attach phone number to monitored user for SMS fallback tests
    await dataSource.getRepository(User).update(monitoredUser.id, {
      phoneNumber: '+84988776655',
    });

    // Register active device
    monitoredDevice = await devicesService.registerDevice(monitoredUser.id, {
      deviceUid: `challenger-dev-${Date.now()}`,
      platform: DevicePlatform.ANDROID,
      deviceName: 'Challenger Pixel',
      pushToken: 'fcm-push-valid-token-initial',
      batteryLevel: 95,
      isCharging: false,
    });

    // Pair relationship
    const createdRel = await monitoringService.createRelationship(monitorUser.id, {
      monitoredUserEmail: monitoredUser.email,
    });
    relationship = await monitoringService.acceptInvitation(monitoredUser.id, {
      invitationCode: createdRel.invitationCode,
    });
  }, 30000);

  afterAll(async () => {
    await teardownE2eTestApp(app, dataSource, redisService);
  });

  // =========================================================================
  // SCOPE 1: MULTI-CHANNEL CASCADING FALLBACK & RETRY ENGINE
  // =========================================================================
  describe('Scope 1: Multi-Channel Cascading Fallback & Retry Engine', () => {
    it('1.1. Zero Push Tokens: User with 0 active push tokens cascades immediately to SMS', async () => {
      // Create user without devices/tokens
      const zeroTokenUserRes = await authService.register({
        email: `zero_tokens_${Date.now()}@carely.test`,
        password: 'Password123!',
        displayName: 'Zero Tokens Monitored',
        timezone: 'Asia/Ho_Chi_Minh',
      });
      const zeroTokenUser = zeroTokenUserRes.user;
      await dataSource.getRepository(User).update(zeroTokenUser.id, {
        phoneNumber: '+84909123456',
      });

      const smsSpy = vi.spyOn(smsChannel, 'send');

      const deliveries = await notificationsService.sendNotification({
        recipientUserId: zeroTokenUser.id,
        templateName: 'CHECK_IN_PROMPT',
      });

      expect(deliveries.length).toBe(2);

      // 1st delivery: Failed FCM attempt recorded for audit visibility
      const fcmDelivery = deliveries.find((d) => d.channel === NotificationChannelType.FCM);
      expect(fcmDelivery).toBeDefined();
      expect(fcmDelivery!.status).toBe(NotificationDeliveryStatus.FAILED);
      expect(fcmDelivery!.recipientTarget).toBe('NO_ACTIVE_DEVICE_TOKEN');

      // 2nd delivery: Cascaded SMS
      const smsDelivery = deliveries.find((d) => d.channel === NotificationChannelType.SMS);
      expect(smsDelivery).toBeDefined();
      expect(smsDelivery!.status).toBe(NotificationDeliveryStatus.SENT);
      expect(smsDelivery!.recipientTarget).toBe('+84909123456');
      expect(smsSpy).toHaveBeenCalled();
    });

    it('1.2. FCM Soft Push Failure: Unsuccessful FCM dispatch cascades immediately to SMS', async () => {
      // Monitored user has device with push token, but FCM gateway returns success: false
      const fcmSpy = vi.spyOn(fcmChannel, 'send').mockResolvedValueOnce({
        success: false,
        error: 'messaging/registration-token-not-registered',
      });
      const smsSpy = vi.spyOn(smsChannel, 'send');

      const deliveries = await notificationsService.sendNotification({
        recipientUserId: monitoredUser.id,
        templateName: 'CHECK_IN_PROMPT',
      });

      expect(fcmSpy).toHaveBeenCalled();
      expect(smsSpy).toHaveBeenCalled();

      const fcmDel = deliveries.find((d) => d.channel === NotificationChannelType.FCM);
      expect(fcmDel!.status).toBe(NotificationDeliveryStatus.FAILED);
      expect(fcmDel!.lastError).toContain('registration-token-not-registered');

      const smsDel = deliveries.find((d) => d.channel === NotificationChannelType.SMS);
      expect(smsDel!.status).toBe(NotificationDeliveryStatus.SENT);
      expect(smsDel!.recipientTarget).toBe('+84988776655');
    });

    it('1.3. FCM Failure + SMS Failure: Cascades immediately to Telegram', async () => {
      vi.spyOn(fcmChannel, 'send').mockResolvedValueOnce({
        success: false,
        error: 'FCM device quota exceeded',
      });
      vi.spyOn(smsChannel, 'send').mockResolvedValueOnce({
        success: false,
        error: 'Telco SMS gateway unavailable',
      });
      const tgSpy = vi.spyOn(telegramChannel, 'send');

      const deliveries = await notificationsService.sendNotification({
        recipientUserId: monitoredUser.id,
        templateName: 'MONITOR_ESCALATION',
        customData: {
          telegramChatId: 'tg_chat_carely_999',
        },
      });

      expect(deliveries.length).toBe(3);
      expect(deliveries[0].channel).toBe(NotificationChannelType.FCM);
      expect(deliveries[0].status).toBe(NotificationDeliveryStatus.FAILED);

      expect(deliveries[1].channel).toBe(NotificationChannelType.SMS);
      expect(deliveries[1].status).toBe(NotificationDeliveryStatus.FAILED);

      expect(deliveries[2].channel).toBe(NotificationChannelType.TELEGRAM);
      expect(deliveries[2].status).toBe(NotificationDeliveryStatus.SENT);
      expect(deliveries[2].recipientTarget).toBe('tg_chat_carely_999');
      expect(tgSpy).toHaveBeenCalled();
    });

    it('1.4. FCM Unhandled Rejection: Defensive try/catch survives socket hangup and cascades to SMS', async () => {
      const delRepo = dataSource.getRepository(NotificationDelivery);
      const smsCountBefore = await delRepo.count({
        where: { recipientUserId: monitoredUser.id, channel: NotificationChannelType.SMS },
      });

      // Simulate third-party network crash throwing an unhandled rejection
      vi.spyOn(fcmChannel, 'send').mockRejectedValueOnce(
        new Error('FCM network socket hang up unexpectedly'),
      );

      const smsSpy = vi.spyOn(smsChannel, 'send');

      let caughtError: any = null;
      let deliveries: any[] = [];
      try {
        deliveries = await notificationsService.sendNotification({
          recipientUserId: monitoredUser.id,
          templateName: 'CHECK_IN_PROMPT',
        });
      } catch (err) {
        caughtError = err;
      }

      // 1. Verify no unhandled rejection escaped sendNotification:
      expect(caughtError).toBeNull();
      expect(deliveries.length).toBe(2);

      // 2. Verify that the FCM record transitioned cleanly to FAILED (not abandoned in PENDING):
      const pendingFCM = await delRepo.findOne({
        where: {
          recipientUserId: monitoredUser.id,
          channel: NotificationChannelType.FCM,
          status: NotificationDeliveryStatus.PENDING,
        },
      });
      expect(pendingFCM).toBeNull();

      const failedFCM = deliveries.find((d) => d.channel === NotificationChannelType.FCM);
      expect(failedFCM).toBeDefined();
      expect(failedFCM!.status).toBe(NotificationDeliveryStatus.FAILED);
      expect(failedFCM!.lastError).toContain('FCM network socket hang up unexpectedly');

      // 3. Verify that SMS fallback was triggered and succeeded:
      const smsCountAfter = await delRepo.count({
        where: { recipientUserId: monitoredUser.id, channel: NotificationChannelType.SMS },
      });
      expect(smsCountAfter).toBe(smsCountBefore + 1);

      const smsDel = deliveries.find((d) => d.channel === NotificationChannelType.SMS);
      expect(smsDel).toBeDefined();
      expect(smsDel!.status).toBe(NotificationDeliveryStatus.SENT);
      expect(smsDel!.recipientTarget).toBe('+84988776655');
      expect(smsSpy).toHaveBeenCalled();
    });

    it('1.5. processRetries: Exponential backoff timing and maxAttempts enforcement', async () => {
      const delRepo = dataSource.getRepository(NotificationDelivery);
      const now = Date.now();

      // Case A: attemptCount = 1, backoff = 2^1 * 10s = 20s. Failed 5s ago (NOT eligible yet)
      const d1 = await delRepo.save(
        delRepo.create({
          recipientUserId: monitoredUser.id,
          channel: NotificationChannelType.FCM,
          templateName: 'TEST_BACKOFF',
          recipientTarget: 'token-active',
          payload: { title: 'T', body: 'B' },
          status: NotificationDeliveryStatus.FAILED,
          attemptCount: 1,
          maxAttempts: 3,
          failedAt: new Date(now - 5000), // 5s ago
        }),
      );

      // Case B: attemptCount = 1, backoff = 20s. Failed 25s ago (ELIGIBLE)
      const d2 = await delRepo.save(
        delRepo.create({
          recipientUserId: monitoredUser.id,
          channel: NotificationChannelType.FCM,
          templateName: 'TEST_BACKOFF',
          recipientTarget: 'token-active',
          payload: { title: 'T', body: 'B' },
          status: NotificationDeliveryStatus.FAILED,
          attemptCount: 1,
          maxAttempts: 3,
          failedAt: new Date(now - 25000), // 25s ago
        }),
      );

      // Case C: attemptCount = 2, backoff = 2^2 * 10s = 40s. Failed 30s ago (NOT eligible yet)
      const d3 = await delRepo.save(
        delRepo.create({
          recipientUserId: monitoredUser.id,
          channel: NotificationChannelType.FCM,
          templateName: 'TEST_BACKOFF',
          recipientTarget: 'token-active',
          payload: { title: 'T', body: 'B' },
          status: NotificationDeliveryStatus.FAILED,
          attemptCount: 2,
          maxAttempts: 3,
          failedAt: new Date(now - 30000), // 30s ago
        }),
      );

      // Case D: attemptCount = 3, maxAttempts = 3 (EXHAUSTED, never retried)
      const d4 = await delRepo.save(
        delRepo.create({
          recipientUserId: monitoredUser.id,
          channel: NotificationChannelType.FCM,
          templateName: 'TEST_BACKOFF',
          recipientTarget: 'token-active',
          payload: { title: 'T', body: 'B' },
          status: NotificationDeliveryStatus.FAILED,
          attemptCount: 3,
          maxAttempts: 3,
          failedAt: new Date(now - 600000), // 10m ago
        }),
      );

      // Run retries
      vi.spyOn(fcmChannel, 'send').mockResolvedValue({ success: true, messageId: 'retry-ok' });
      const retriedCount = await notificationsService.processRetries(50);
      expect(retriedCount).toBe(1);

      // Exactly d2 should be retried!
      const refreshedD1 = await delRepo.findOne({ where: { id: d1.id } });
      const refreshedD2 = await delRepo.findOne({ where: { id: d2.id } });
      const refreshedD3 = await delRepo.findOne({ where: { id: d3.id } });
      const refreshedD4 = await delRepo.findOne({ where: { id: d4.id } });

      expect(refreshedD1!.status).toBe(NotificationDeliveryStatus.FAILED);
      expect(refreshedD1!.attemptCount).toBe(1);

      expect(refreshedD2!.status).toBe(NotificationDeliveryStatus.SENT);
      expect(refreshedD2!.attemptCount).toBe(2);

      expect(refreshedD3!.status).toBe(NotificationDeliveryStatus.FAILED);
      expect(refreshedD3!.attemptCount).toBe(2);

      expect(refreshedD4!.status).toBe(NotificationDeliveryStatus.FAILED);
      expect(refreshedD4!.attemptCount).toBe(3);
    });

    it('1.6. processRetries: Recovers delivery when newly registered device token becomes available', async () => {
      const delRepo = dataSource.getRepository(NotificationDelivery);
      const devRepo = dataSource.getRepository(Device);

      // Create a user who originally had no device tokens
      const recoverUserRes = await authService.register({
        email: `recover_user_${Date.now()}@carely.test`,
        password: 'Password123!',
        displayName: 'Recover User',
        timezone: 'Asia/Ho_Chi_Minh',
      });
      const recoverUser = recoverUserRes.user;

      const failedDel = await delRepo.save(
        delRepo.create({
          recipientUserId: recoverUser.id,
          channel: NotificationChannelType.FCM,
          templateName: 'CHECK_IN_PROMPT',
          recipientTarget: 'NO_ACTIVE_DEVICE_TOKEN',
          payload: { title: 'T', body: 'B' },
          status: NotificationDeliveryStatus.FAILED,
          attemptCount: 1,
          maxAttempts: 3,
          failedAt: new Date(Date.now() - 30000), // 30s ago (> 20s backoff)
        }),
      );

      // Now user registers a fresh device
      await devRepo.save(
        devRepo.create({
          userId: recoverUser.id,
          deviceUid: `rec-dev-${Date.now()}`,
          platform: DevicePlatform.IOS,
          deviceName: 'New iPhone',
          pushToken: 'fcm-recovered-token-999',
          isActive: true,
        }),
      );

      vi.spyOn(fcmChannel, 'send').mockResolvedValueOnce({
        success: true,
        messageId: 'recovered-msg-123',
      });

      await notificationsService.processRetries(50);

      const refreshed = await delRepo.findOne({ where: { id: failedDel.id } });
      expect(refreshed!.status).toBe(NotificationDeliveryStatus.SENT);
      expect(refreshed!.recipientTarget).toBe('fcm-recovered-token-999');
    });
  });

  // =========================================================================
  // SCOPE 2: INCIDENT AUTO-RESOLUTION & RACE CONDITIONS
  // =========================================================================
  describe('Scope 2: Incident Auto-Resolution & Race Conditions', () => {
    let incidentRepo: any;
    let eventRepo: any;

    beforeEach(() => {
      incidentRepo = dataSource.getRepository(Incident);
      eventRepo = dataSource.getRepository(IncidentEvent);
    });

    it('2.1. Auto-Resolution: Resolves OPEN incident when occurredAt >= createdAt', async () => {
      const now = new Date();
      const inc = await incidentRepo.save(
        incidentRepo.create({
          relationshipId: relationship.id,
          userId: monitoredUser.id,
          status: IncidentStatus.OPEN,
          reason: IncidentReason.INACTIVITY,
          riskScore: 60,
          detectedAt: now,
          createdAt: new Date(now.getTime() - 5000), // Created 5s ago
        }),
      );

      const checkInEventId = uuidv4();
      await checkInsService.processCheckIn(monitoredUser.id, {
        eventId: checkInEventId,
        deviceId: monitoredDevice.id,
        relationshipId: relationship.id,
        occurredAt: new Date(now.getTime() + 1000).toISOString(), // occurredAt > createdAt
        note: 'Tôi vẫn ổn',
      });

      const updated = await incidentRepo.findOne({ where: { id: inc.id } });
      expect(updated!.status).toBe(IncidentStatus.RESOLVED);
      expect(updated!.resolvedAt).toBeDefined();
      expect(updated!.resolvedBy).toBe(monitoredUser.id);

      const events = await eventRepo.find({ where: { incidentId: inc.id } });
      const resolveEvent = events.find((e: any) => e.type === IncidentEventType.INCIDENT_RESOLVED);
      expect(resolveEvent).toBeDefined();
    });

    it('2.2. Auto-Resolution: Resolves ESCALATED incident when occurredAt >= createdAt', async () => {
      const now = new Date();
      const inc = await incidentRepo.save(
        incidentRepo.create({
          relationshipId: relationship.id,
          userId: monitoredUser.id,
          status: IncidentStatus.ESCALATED,
          reason: IncidentReason.MISSED_CHECK_IN,
          riskScore: 80,
          detectedAt: now,
          escalatedAt: now,
          createdAt: new Date(now.getTime() - 10000),
        }),
      );

      await checkInsService.processCheckIn(monitoredUser.id, {
        eventId: uuidv4(),
        deviceId: monitoredDevice.id,
        relationshipId: relationship.id,
        occurredAt: new Date(now.getTime()).toISOString(), // occurredAt >= createdAt
        note: 'Giải quyết sự cố leo thang',
      });

      const updated = await incidentRepo.findOne({ where: { id: inc.id } });
      expect(updated!.status).toBe(IncidentStatus.RESOLVED);
    });

    it('2.3. Auto-Resolution: Resolves ACKNOWLEDGED incident when occurredAt >= createdAt', async () => {
      const now = new Date();
      const inc = await incidentRepo.save(
        incidentRepo.create({
          relationshipId: relationship.id,
          userId: monitoredUser.id,
          status: IncidentStatus.ACKNOWLEDGED,
          reason: IncidentReason.INACTIVITY,
          riskScore: 70,
          detectedAt: now,
          acknowledgedAt: now,
          acknowledgedBy: monitorUser.id,
          createdAt: new Date(now.getTime() - 15000),
        }),
      );

      await checkInsService.processCheckIn(monitoredUser.id, {
        eventId: uuidv4(),
        deviceId: monitoredDevice.id,
        relationshipId: relationship.id,
        occurredAt: new Date(now.getTime()).toISOString(),
        note: 'Xác nhận an toàn sau khi người thân chú ý',
      });

      const updated = await incidentRepo.findOne({ where: { id: inc.id } });
      expect(updated!.status).toBe(IncidentStatus.RESOLVED);
    });

    it('2.4. Safety Invariant: Historical check-in (occurredAt < createdAt) does NOT clear active incident', async () => {
      const incidentCreatedAt = new Date();
      const inc = await incidentRepo.save(
        incidentRepo.create({
          relationshipId: relationship.id,
          userId: monitoredUser.id,
          status: IncidentStatus.OPEN,
          reason: IncidentReason.MISSED_CHECK_IN,
          riskScore: 75,
          detectedAt: incidentCreatedAt,
          createdAt: incidentCreatedAt,
        }),
      );

      // Delayed check-in from 30 minutes in the past
      const historicalTime = new Date(incidentCreatedAt.getTime() - 30 * 60 * 1000);
      await checkInsService.processCheckIn(monitoredUser.id, {
        eventId: uuidv4(),
        deviceId: monitoredDevice.id,
        relationshipId: relationship.id,
        occurredAt: historicalTime.toISOString(),
        note: 'Check-in offline gửi chậm từ quá khứ',
      });

      // Crucial verification: Incident MUST remain OPEN!
      const refreshed = await incidentRepo.findOne({ where: { id: inc.id } });
      expect(refreshed!.status).toBe(IncidentStatus.OPEN);
      expect(refreshed!.resolvedAt).toBeNull();

      // No resolve event should have been appended
      const events = await eventRepo.find({ where: { incidentId: inc.id } });
      expect(events.filter((e: any) => e.type === IncidentEventType.INCIDENT_RESOLVED).length).toBe(0);

      // Clean up for next tests
      await incidentRepo.delete(inc.id);
    });

    it('2.5. Split Boundary Resolution: Resolves older incident but preserves newer incident', async () => {
      const baseTime = Date.now();
      const t1 = new Date(baseTime - 60 * 60 * 1000); // 1 hour ago
      const t2 = new Date(baseTime - 10 * 60 * 1000); // 10 minutes ago
      const checkInTime = new Date(baseTime - 30 * 60 * 1000); // 30 minutes ago

      // Incident 1 created 1 hour ago (older than checkInTime)
      const incOlder = await incidentRepo.save(
        incidentRepo.create({
          relationshipId: relationship.id,
          userId: monitoredUser.id,
          status: IncidentStatus.OPEN,
          reason: IncidentReason.INACTIVITY,
          riskScore: 55,
          detectedAt: t1,
          createdAt: t1,
        }),
      );

      // Incident 2 created 10 minutes ago (newer than checkInTime)
      const incNewer = await incidentRepo.save(
        incidentRepo.create({
          relationshipId: relationship.id,
          userId: monitoredUser.id,
          status: IncidentStatus.ESCALATED,
          reason: IncidentReason.DEVICE_OFFLINE,
          riskScore: 85,
          detectedAt: t2,
          createdAt: t2,
        }),
      );

      // Submit check-in at t = 30m ago
      await checkInsService.processCheckIn(monitoredUser.id, {
        eventId: uuidv4(),
        deviceId: monitoredDevice.id,
        relationshipId: relationship.id,
        occurredAt: checkInTime.toISOString(),
        note: 'Check-in ở giữa 2 sự cố',
      });

      const refreshedOlder = await incidentRepo.findOne({ where: { id: incOlder.id } });
      const refreshedNewer = await incidentRepo.findOne({ where: { id: incNewer.id } });

      // Older incident was created before check-in -> MUST be RESOLVED
      expect(refreshedOlder!.status).toBe(IncidentStatus.RESOLVED);

      // Newer incident was created after check-in -> MUST remain ESCALATED
      expect(refreshedNewer!.status).toBe(IncidentStatus.ESCALATED);

      // Clean up
      await incidentRepo.delete([incOlder.id, incNewer.id]);
    });

    it('2.6. Exact Equality Boundary: occurredAt === createdAt resolves incident', async () => {
      // Save incident and retrieve its genuine DB-persisted createdAt
      const inc = await incidentRepo.save(
        incidentRepo.create({
          relationshipId: relationship.id,
          userId: monitoredUser.id,
          status: IncidentStatus.OPEN,
          reason: IncidentReason.INACTIVITY,
          riskScore: 60,
          detectedAt: new Date(),
        }),
      );

      // Force a precise known createdAt in DB in the past (to avoid future clamping)
      const exactTime = new Date(Date.now() - 10000);
      await dataSource.query(`UPDATE incidents SET created_at = $1 WHERE id = $2`, [
        exactTime,
        inc.id,
      ]);

      await checkInsService.processCheckIn(monitoredUser.id, {
        eventId: uuidv4(),
        deviceId: monitoredDevice.id,
        relationshipId: relationship.id,
        occurredAt: exactTime.toISOString(),
        note: 'Exact timestamp equality',
      });

      const updated = await incidentRepo.findOne({ where: { id: inc.id } });
      expect(updated!.status).toBe(IncidentStatus.RESOLVED);
    });

    it('2.7. State Machine Invariant: Check-in reverts WARNING to ACTIVE, but preserves SUSPENDED', async () => {
      const configRepo = dataSource.getRepository(MonitoringConfig);

      // Set baseline lastMeaningfulActivityAt 15m ago so check-in is forward-moving
      const pastActivity = new Date(Date.now() - 15 * 60 * 1000);

      // Test WARNING -> ACTIVE
      await configRepo.update(
        { relationshipId: relationship.id },
        {
          currentState: MonitoringState.WARNING,
          lastMeaningfulActivityAt: pastActivity,
        },
      );

      await checkInsService.processCheckIn(monitoredUser.id, {
        eventId: uuidv4(),
        deviceId: monitoredDevice.id,
        relationshipId: relationship.id,
        occurredAt: new Date().toISOString(),
        note: 'Reset from WARNING',
      });

      let cfg = await configRepo.findOne({ where: { relationshipId: relationship.id } });
      expect(cfg!.currentState).toBe(MonitoringState.ACTIVE);

      // Test SUSPENDED -> stays SUSPENDED
      await configRepo.update(
        { relationshipId: relationship.id },
        {
          currentState: MonitoringState.SUSPENDED,
          lastMeaningfulActivityAt: pastActivity,
        },
      );

      await checkInsService.processCheckIn(monitoredUser.id, {
        eventId: uuidv4(),
        deviceId: monitoredDevice.id,
        relationshipId: relationship.id,
        occurredAt: new Date().toISOString(),
        note: 'Check-in during SUSPENDED monitoring',
      });

      cfg = await configRepo.findOne({ where: { relationshipId: relationship.id } });
      expect(cfg!.currentState).toBe(MonitoringState.SUSPENDED);

      // Restore ACTIVE
      await configRepo.update(
        { relationshipId: relationship.id },
        { currentState: MonitoringState.ACTIVE },
      );
    });
  });

  // =========================================================================
  // SCOPE 3: HEARTBEAT WEIGHT 0.0 INVARIANT & INACTIVITY TIMER
  // =========================================================================
  describe('Scope 3: Heartbeat Weight 0.0 Invariant & Inactivity Timer', () => {
    it('3.1. Burst of 50 Heartbeats: Inactivity clock (lastMeaningfulActivityAt) is strictly untouched', async () => {
      const configRepo = dataSource.getRepository(MonitoringConfig);

      // 1. Establish an unambiguous baseline lastMeaningfulActivityAt 30 minutes in the past
      const baselineActivityTime = new Date(Date.now() - 30 * 60 * 1000);
      await configRepo.update(
        { relationshipId: relationship.id },
        {
          currentState: MonitoringState.ACTIVE,
          inactivityThresholdMinutes: 20,
          checkInGraceMinutes: 5,
          lastMeaningfulActivityAt: baselineActivityTime,
          nextEvaluationAt: new Date(Date.now() - 5000), // Due for evaluation
          enabled: true,
        },
      );

      const beforeConfig = await configRepo.findOne({ where: { relationshipId: relationship.id } });
      const beforeTimestamp = new Date(beforeConfig!.lastMeaningfulActivityAt).getTime();

      // 2. Dispatch a rapid burst of 50 heartbeats
      // We clear the Redis rate-limit key before each heartbeat call to stress the service layer directly
      for (let i = 1; i <= 50; i++) {
        await redisService.del(`rate-limit:heartbeat:${monitoredDevice.id}`);
        const result = await activityService.processHeartbeat(monitoredUser.id, {
          deviceId: monitoredDevice.id,
          batteryLevel: 90 - (i % 10),
          isCharging: i % 2 === 0,
          occurredAt: new Date().toISOString(),
        });
        expect(result.success).toBe(true);
        expect(result.operationalState).toBe('ONLINE');
      }

      // 3. Inspect device: lastHeartbeatAt must be recent (now)
      const dev = await dataSource.getRepository(Device).findOne({ where: { id: monitoredDevice.id } });
      expect(dev!.lastHeartbeatAt).toBeDefined();
      const heartbeatAgeMs = Date.now() - new Date(dev!.lastHeartbeatAt!).getTime();
      expect(heartbeatAgeMs).toBeLessThan(5000);

      // 4. Inspect config: lastMeaningfulActivityAt MUST REMAIN UNTOUCHED (still 30 minutes ago)
      const afterConfig = await configRepo.findOne({ where: { relationshipId: relationship.id } });
      const afterTimestamp = new Date(afterConfig!.lastMeaningfulActivityAt).getTime();

      expect(afterTimestamp).toBe(beforeTimestamp);
    });

    it('3.2. State Machine Continuation: Worker advances state to CHECK_IN_REQUIRED despite 50 recent heartbeats', async () => {
      const configRepo = dataSource.getRepository(MonitoringConfig);

      // Explicitly ensure next_evaluation_at is due in database
      await dataSource.query(
        `UPDATE monitoring_configs 
         SET next_evaluation_at = NOW() - INTERVAL '1 second'
         WHERE relationship_id = $1`,
        [relationship.id],
      );

      // Trigger inactivity worker evaluation
      const evaluatedCount = await workerService.evaluateDueMonitoring(10);
      expect(evaluatedCount).toBeGreaterThanOrEqual(1);

      // The 50 heartbeats received seconds ago MUST NOT prevent the state transition to CHECK_IN_REQUIRED!
      const transitionedConfig = await configRepo.findOne({ where: { relationshipId: relationship.id } });
      expect(transitionedConfig!.currentState).toBe(MonitoringState.CHECK_IN_REQUIRED);
    });

    it('3.3. Ingestion of 50 HEARTBEAT activities via ingestActivity: Weight is strictly 0.0, isMeaningful is false', async () => {
      const configRepo = dataSource.getRepository(MonitoringConfig);
      const beforeConfig = await configRepo.findOne({ where: { relationshipId: relationship.id } });
      const beforeTimestamp = new Date(beforeConfig!.lastMeaningfulActivityAt).getTime();

      for (let i = 1; i <= 50; i++) {
        const act = await activityService.ingestActivity(monitoredUser.id, {
          eventId: uuidv4(),
          deviceId: monitoredDevice.id,
          type: ActivityType.HEARTBEAT,
          occurredAt: new Date().toISOString(),
          confidence: 1.0,
        });
        expect(Number(act.weight)).toBe(0.0);
      }

      const afterConfig = await configRepo.findOne({ where: { relationshipId: relationship.id } });
      const afterTimestamp = new Date(afterConfig!.lastMeaningfulActivityAt).getTime();

      // Config lastMeaningfulActivityAt is STILL strictly identical!
      expect(afterTimestamp).toBe(beforeTimestamp);
    });

    it('3.4. Contrast Verification: Meaningful activity immediately updates lastMeaningfulActivityAt', async () => {
      const configRepo = dataSource.getRepository(MonitoringConfig);
      const beforeConfig = await configRepo.findOne({ where: { relationshipId: relationship.id } });
      const beforeTimestamp = new Date(beforeConfig!.lastMeaningfulActivityAt).getTime();

      const meaningfulActivity = await activityService.ingestActivity(monitoredUser.id, {
        eventId: uuidv4(),
        deviceId: monitoredDevice.id,
        type: ActivityType.APP_FOREGROUND,
        occurredAt: new Date().toISOString(),
        confidence: 0.95,
      });

      expect(Number(meaningfulActivity.weight)).toBeGreaterThan(0.0);

      const afterConfig = await configRepo.findOne({ where: { relationshipId: relationship.id } });
      const afterTimestamp = new Date(afterConfig!.lastMeaningfulActivityAt).getTime();

      expect(afterTimestamp).toBeGreaterThan(beforeTimestamp);
    });
  });
});
