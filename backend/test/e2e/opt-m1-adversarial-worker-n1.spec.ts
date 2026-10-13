import { describe, it, expect, beforeAll, afterAll } from 'vitest';
import { INestApplication } from '@nestjs/common';
import { DataSource, QueryRunner } from 'typeorm';
import {
  createE2eTestApp,
  resetDatabase,
  teardownE2eTestApp,
  registerAndLoginUser,
} from './e2e-helper';
import {
  MonitoringState,
  RelationshipStatus,
  DevicePlatform,
  IncidentStatus,
} from '../../src/common/enums';
import { MonitoringWorkerService } from '../../src/modules/workers/monitoring-worker.service';
import { MonitoringConfig } from '../../src/modules/monitoring/entities/monitoring-config.entity';
import { MonitoringRelationship } from '../../src/modules/monitoring/entities/monitoring-relationship.entity';
import { MonitoringScheduleWindow } from '../../src/modules/monitoring/entities/monitoring-schedule-window.entity';
import { Device } from '../../src/modules/devices/entities/device.entity';
import { Incident } from '../../src/modules/incidents/entities/incident.entity';

describe('Opt-M1 Challenger 2: Worker Evaluation Loop & N+1 Empirical Stress Harness', () => {
  let app: INestApplication;
  let dataSource: DataSource;
  let workerService: MonitoringWorkerService;

  beforeAll(async () => {
    const context = await createE2eTestApp();
    app = context.app;
    dataSource = context.dataSource;
    workerService = context.moduleFixture.get<MonitoringWorkerService>(MonitoringWorkerService);

    await resetDatabase(dataSource);
  }, 60000);

  afterAll(async () => {
    await teardownE2eTestApp(app, dataSource);
  });

  /**
   * Helper to capture and partition SQL queries by transaction boundary
   */
  async function traceQueriesDetailed(fn: () => Promise<any>): Promise<{
    result: any;
    allQueries: string[];
    inTxQueries: string[];
    postTxQueries: string[];
  }> {
    const allQueries: string[] = [];
    const inTxQueries: string[] = [];
    const postTxQueries: string[] = [];
    let inTransaction = false;

    const originalCreateQueryRunner = dataSource.createQueryRunner.bind(dataSource);

    dataSource.createQueryRunner = (...args: any[]) => {
      const runner: QueryRunner = originalCreateQueryRunner(...args);
      const originalQuery = runner.query.bind(runner);
      runner.query = async (query: string, parameters?: any[], ...rest: any[]) => {
        allQueries.push(query);
        const upper = query.trim().toUpperCase();

        if (upper.startsWith('START TRANSACTION') || upper.startsWith('BEGIN')) {
          inTransaction = true;
        } else if (upper.startsWith('COMMIT') || upper.startsWith('ROLLBACK')) {
          inTransaction = false;
        } else {
          if (inTransaction) {
            inTxQueries.push(query);
          } else {
            postTxQueries.push(query);
          }
        }

        return originalQuery(query, parameters, ...rest);
      };
      return runner;
    };

    try {
      const result = await fn();
      return { result, allQueries, inTxQueries, postTxQueries };
    } finally {
      dataSource.createQueryRunner = originalCreateQueryRunner;
    }
  }

  // =========================================================================
  // TEST 1: BATCH SIZE 0 (No due configs)
  // =========================================================================
  it('1. Zero Due Configs: Handles empty batch cleanly with strictly 1 check query and 0 N+1 overhead', async () => {
    await resetDatabase(dataSource);

    const { result: processedCount, inTxQueries } = await traceQueriesDetailed(async () => {
      return workerService.evaluateDueMonitoring(25);
    });

    expect(processedCount).toBe(0);

    // Filter to SELECT queries inside the transaction
    const inTxSelects = inTxQueries.filter((q) => q.toLowerCase().startsWith('select'));
    expect(inTxSelects.length).toBe(1);
    expect(inTxSelects[0].toLowerCase()).toContain('monitoring_configs');
  });

  // =========================================================================
  // TEST 2: BATCH SIZE 1 (Single due config with devices)
  // =========================================================================
  it('2. Single Due Config: Evaluates cleanly and verifies in-transaction query count', async () => {
    await resetDatabase(dataSource);

    const monitor = await registerAndLoginUser(app, `monitor_single_${Date.now()}`);
    const monitored = await registerAndLoginUser(app, `monitored_single_${Date.now()}`);

    const devRepo = dataSource.getRepository(Device);
    const device = devRepo.create({
      userId: monitored.id,
      deviceUid: `dev-single-${Date.now()}`,
      platform: DevicePlatform.ANDROID,
      deviceName: 'Pixel Single',
      isActive: true,
      lastSeenAt: new Date(),
      lastHeartbeatAt: new Date(),
      batteryLevel: 85,
    });
    await devRepo.save(device);

    const relRepo = dataSource.getRepository(MonitoringRelationship);
    const rel = relRepo.create({
      monitorId: monitor.id,
      monitoredUserId: monitored.id,
      status: RelationshipStatus.ACCEPTED,
    });
    await relRepo.save(rel);

    const configRepo = dataSource.getRepository(MonitoringConfig);
    const config = configRepo.create({
      relationshipId: rel.id,
      enabled: true,
      currentState: MonitoringState.CHECK_IN_REQUIRED,
      inactivityThresholdMinutes: 30,
      checkInGraceMinutes: 15,
      warningEscalationMinutes: 30,
      nextEvaluationAt: new Date(Date.now() - 60000),
      lastMeaningfulActivityAt: new Date(Date.now() - 45 * 60 * 1000),
    });
    await configRepo.save(config);

    const windowRepo = dataSource.getRepository(MonitoringScheduleWindow);
    const window = windowRepo.create({
      configId: config.id,
      dayOfWeek: new Date().getDay(),
      startTime: '00:00',
      endTime: '23:59',
      isEnabled: true,
    });
    await windowRepo.save(window);

    const { result: processedCount, inTxQueries, postTxQueries } = await traceQueriesDetailed(async () => {
      return workerService.evaluateDueMonitoring(25);
    });

    expect(processedCount).toBe(1);

    const inTxSelects = inTxQueries.filter((q) => q.toLowerCase().startsWith('select'));
    console.log(`[Test 2] In-transaction SELECT queries: ${inTxSelects.length}`);
    inTxSelects.forEach((q, i) => console.log(`  in-tx #${i + 1}: ${q.slice(0, 100)}`));

    console.log(`[Test 2] Post-transaction queries: ${postTxQueries.length}`);
    postTxQueries.forEach((q, i) => console.log(`  post-tx #${i + 1}: ${q.slice(0, 100)}`));

    // Inside transaction, exactly 8 SELECT queries are executed by TypeORM:
    // 1-2. Due configs pagination & join
    // 3. Schedule windows IN (...)
    // 4. Devices IN (...)
    // 5. Incidents IN (...)
    // 6-8. Pre-save relation metadata checks
    expect(inTxSelects.length).toBe(8);
  });

  // =========================================================================
  // TEST 3: BATCH SIZE 25 (25 due configs with devices & incidents)
  // =========================================================================
  it('3. 25 Due Configs: In-transaction SELECT queries remain strictly O(1) when users have devices & incidents', async () => {
    await resetDatabase(dataSource);

    const relRepo = dataSource.getRepository(MonitoringRelationship);
    const configRepo = dataSource.getRepository(MonitoringConfig);
    const windowRepo = dataSource.getRepository(MonitoringScheduleWindow);
    const devRepo = dataSource.getRepository(Device);
    const incRepo = dataSource.getRepository(Incident);

    const tag = Date.now();

    for (let i = 0; i < 25; i++) {
      const monitor = await registerAndLoginUser(app, `monitor_bulk_${tag}_${i}`);
      const monitored = await registerAndLoginUser(app, `monitored_bulk_${tag}_${i}`);

      const dev1 = devRepo.create({
        userId: monitored.id,
        deviceUid: `dev-${tag}-${i}-1`,
        platform: DevicePlatform.ANDROID,
        deviceName: `Device A ${i}`,
        isActive: true,
        lastSeenAt: new Date(Date.now() - i * 1000),
        lastHeartbeatAt: new Date(Date.now() - i * 1000),
        batteryLevel: 90,
      });
      await devRepo.save(dev1);

      const rel = relRepo.create({
        monitorId: monitor.id,
        monitoredUserId: monitored.id,
        status: RelationshipStatus.ACCEPTED,
      });
      await relRepo.save(rel);

      // Create an open incident for every relationship so WARNING state doesn't lack incidents
      const incident = incRepo.create({
        userId: monitored.id,
        relationshipId: rel.id,
        status: IncidentStatus.OPEN,
        reason: 'INACTIVITY_TIMEOUT',
        riskScore: 60,
        detectedAt: new Date(Date.now() - 30 * 60 * 1000),
      });
      await incRepo.save(incident);

      const state =
        i % 3 === 0
          ? MonitoringState.ACTIVE
          : i % 3 === 1
          ? MonitoringState.CHECK_IN_REQUIRED
          : MonitoringState.WARNING;

      const config = configRepo.create({
        relationshipId: rel.id,
        enabled: true,
        currentState: state,
        requireCheckIn: true,
        inactivityThresholdMinutes: 30,
        checkInGraceMinutes: 15,
        warningEscalationMinutes: 30,
        nextEvaluationAt: new Date(Date.now() - 60000),
        lastMeaningfulActivityAt: new Date(Date.now() - 60 * 60 * 1000),
      });
      await configRepo.save(config);

      const win = windowRepo.create({
        configId: config.id,
        dayOfWeek: new Date().getDay(),
        startTime: '00:00',
        endTime: '23:59',
        isEnabled: true,
      });
      await windowRepo.save(win);
    }

    const { result: processedCount, inTxQueries } = await traceQueriesDetailed(async () => {
      return workerService.evaluateDueMonitoring(25);
    });

    expect(processedCount).toBe(25);

    const inTxSelects = inTxQueries.filter((q) => q.toLowerCase().startsWith('select'));
    console.log(`[Test 3] In-transaction SELECT queries for 25 configs: ${inTxSelects.length}`);
    inTxSelects.forEach((q, i) => console.log(`  in-tx #${i + 1}: ${q.slice(0, 100)}`));

    // Under happy path (users have devices, relationships have incidents):
    // In-transaction SELECT queries are strictly O(1) and identical to N=1 (exactly 8 queries):
    expect(inTxSelects.length).toBe(8);
  });

  // =========================================================================
  // TEST 4: ADVERSARIAL EDGE CASE: Monitored Users with ZERO Devices
  // =========================================================================
  it('4. Zero-Device Adversarial Edge Case: Demonstrates N+1 loop query hazard when monitored users have 0 devices', async () => {
    await resetDatabase(dataSource);

    const relRepo = dataSource.getRepository(MonitoringRelationship);
    const configRepo = dataSource.getRepository(MonitoringConfig);
    const windowRepo = dataSource.getRepository(MonitoringScheduleWindow);

    const tag = Date.now();
    for (let i = 0; i < 5; i++) {
      const monitor = await registerAndLoginUser(app, `monitor_nodev_${tag}_${i}`);
      const monitored = await registerAndLoginUser(app, `monitored_nodev_${tag}_${i}`);

      const rel = relRepo.create({
        monitorId: monitor.id,
        monitoredUserId: monitored.id,
        status: RelationshipStatus.ACCEPTED,
      });
      await relRepo.save(rel);

      const config = configRepo.create({
        relationshipId: rel.id,
        enabled: true,
        currentState: MonitoringState.CHECK_IN_REQUIRED,
        inactivityThresholdMinutes: 30,
        checkInGraceMinutes: 15,
        warningEscalationMinutes: 30,
        nextEvaluationAt: new Date(Date.now() - 60000),
        lastMeaningfulActivityAt: new Date(Date.now() - 60 * 60 * 1000),
      });
      await configRepo.save(config);

      const win = windowRepo.create({
        configId: config.id,
        dayOfWeek: new Date().getDay(),
        startTime: '00:00',
        endTime: '23:59',
        isEnabled: true,
      });
      await windowRepo.save(win);
    }

    const { result: processedCount, inTxQueries } = await traceQueriesDetailed(async () => {
      return workerService.evaluateDueMonitoring(25);
    });

    expect(processedCount).toBe(5);

    const inTxSelects = inTxQueries.filter((q) => q.toLowerCase().startsWith('select'));
    console.log(`[Test 4] In-transaction SELECT queries for 5 zero-device configs: ${inTxSelects.length}`);
    inTxSelects.forEach((q, i) => console.log(`  in-tx #${i + 1}: ${q.slice(0, 100)}`));

    // Check if loop executed individual queries for each device-less user:
    const loopDeviceQueries = inTxSelects.filter(
      (q) => q.includes('"Device"') && !q.includes('ANY') && !q.includes('IN'),
    );
    console.log(`[Test 4] Loop Device SELECT queries detected: ${loopDeviceQueries.length}`);

    // Empirically confirms N+1 loop queries triggered because devicesByUser.get(userId) returns undefined
    expect(loopDeviceQueries.length).toBe(5);
  });

  // =========================================================================
  // TEST 5: ADVERSARIAL EDGE CASE: WARNING state with ZERO Open Incidents
  // =========================================================================
  it('5. Zero-Incident Adversarial Edge Case: Demonstrates N+1 loop query hazard when WARNING state has 0 open incidents', async () => {
    await resetDatabase(dataSource);

    const relRepo = dataSource.getRepository(MonitoringRelationship);
    const configRepo = dataSource.getRepository(MonitoringConfig);
    const windowRepo = dataSource.getRepository(MonitoringScheduleWindow);

    const tag = Date.now();
    for (let i = 0; i < 5; i++) {
      const monitor = await registerAndLoginUser(app, `monitor_noinc_${tag}_${i}`);
      const monitored = await registerAndLoginUser(app, `monitored_noinc_${tag}_${i}`);

      const rel = relRepo.create({
        monitorId: monitor.id,
        monitoredUserId: monitored.id,
        status: RelationshipStatus.ACCEPTED,
      });
      await relRepo.save(rel);

      const config = configRepo.create({
        relationshipId: rel.id,
        enabled: true,
        currentState: MonitoringState.WARNING,
        inactivityThresholdMinutes: 30,
        checkInGraceMinutes: 15,
        warningEscalationMinutes: 30,
        nextEvaluationAt: new Date(Date.now() - 60000),
        lastMeaningfulActivityAt: new Date(Date.now() - 60 * 60 * 1000),
      });
      await configRepo.save(config);

      const win = windowRepo.create({
        configId: config.id,
        dayOfWeek: new Date().getDay(),
        startTime: '00:00',
        endTime: '23:59',
        isEnabled: true,
      });
      await windowRepo.save(win);
    }

    const { result: processedCount, inTxQueries } = await traceQueriesDetailed(async () => {
      return workerService.evaluateDueMonitoring(25);
    });

    expect(processedCount).toBe(5);

    const inTxSelects = inTxQueries.filter((q) => q.toLowerCase().startsWith('select'));
    console.log(`[Test 5] In-transaction SELECT queries for 5 zero-incident configs: ${inTxSelects.length}`);
    inTxSelects.forEach((q, i) => console.log(`  in-tx #${i + 1}: ${q.slice(0, 100)}`));

    const loopIncidentQueries = inTxSelects.filter(
      (q) => q.includes('"Incident"') && !q.includes('ANY') && !q.includes('IN'),
    );
    console.log(`[Test 5] Loop Incident SELECT queries detected: ${loopIncidentQueries.length}`);

    // Empirically confirms N+1 loop queries triggered because openIncidentsByRel.get(relId) returns undefined
    expect(loopIncidentQueries.length).toBe(5);
  });
});

