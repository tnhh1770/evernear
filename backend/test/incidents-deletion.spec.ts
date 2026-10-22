import { describe, it, expect, beforeAll, afterAll } from 'vitest';
import { INestApplication } from '@nestjs/common';
import { DataSource } from 'typeorm';
import request from 'supertest';
import { v4 as uuidv4 } from 'uuid';
import {
  createE2eTestApp,
  resetDatabase,
  teardownE2eTestApp,
  registerAndLoginUser,
  pairMonitoringRelationship,
  TestUserContext,
} from './e2e/e2e-helper';

describe('Incident Deletion & Clear All Endpoints E2E (F3 / R2)', () => {
  let app: INestApplication;
  let dataSource: DataSource;

  let monitor: TestUserContext;
  let monitored: TestUserContext;
  let unrelatedUser: TestUserContext;
  let relationship: any;

  beforeAll(async () => {
    const context = await createE2eTestApp();
    app = context.app;
    dataSource = context.dataSource;

    await resetDatabase(dataSource);

    monitor = await registerAndLoginUser(app, 'inc_del_monitor');
    monitored = await registerAndLoginUser(app, 'inc_del_monitored');
    unrelatedUser = await registerAndLoginUser(app, 'inc_del_intruder');

    const paired = await pairMonitoringRelationship(app, monitor.accessToken, monitored);
    relationship = paired.relationship;
  }, 30000);

  afterAll(async () => {
    await teardownE2eTestApp(app, dataSource);
  });

  // =========================================================================
  // 1. DELETE /api/v1/incidents/:id (Single Incident Deletion)
  // =========================================================================
  describe('Single Incident Deletion: DELETE /api/v1/incidents/:id', () => {
    it('should allow monitored user to delete an incident and cascade-delete its events', async () => {
      // 1. Insert incident directly into DB
      const incRes = await dataSource.query(
        `INSERT INTO incidents (user_id, relationship_id, status, reason, risk_score, detected_at)
         VALUES ($1, $2, 'OPEN', 'MISSED_CHECK_IN', 60, NOW())
         RETURNING id`,
        [monitored.id, relationship.id],
      );
      const incidentId = incRes[0].id;

      // 2. Insert associated incident_events
      await dataSource.query(
        `INSERT INTO incident_events (incident_id, type, metadata)
         VALUES ($1, 'INCIDENT_CREATED', '{"reason": "MISSED_CHECK_IN"}'::jsonb),
                ($1, 'REMINDER_SENT', '{"channel": "PUSH"}'::jsonb)`,
        [incidentId],
      );

      // Verify events exist
      const eventsBefore = await dataSource.query(
        `SELECT COUNT(*) as count FROM incident_events WHERE incident_id = $1`,
        [incidentId],
      );
      expect(Number(eventsBefore[0].count)).toBe(2);

      // 3. Monitored user deletes the incident
      const res = await request(app.getHttpServer())
        .delete(`/api/v1/incidents/${incidentId}`)
        .set('Authorization', `Bearer ${monitored.accessToken}`);

      expect(res.status).toBe(200);
      expect(res.body).toEqual({
        success: true,
        message: 'Incident deleted',
      });

      // 4. Verify DB: incident is deleted
      const incCheck = await dataSource.query(
        `SELECT id FROM incidents WHERE id = $1`,
        [incidentId],
      );
      expect(incCheck.length).toBe(0);

      // 5. Verify DB: events are cascade-deleted
      const eventsAfter = await dataSource.query(
        `SELECT COUNT(*) as count FROM incident_events WHERE incident_id = $1`,
        [incidentId],
      );
      expect(Number(eventsAfter[0].count)).toBe(0);

      // 6. Subsequent GET returns 404 Not Found
      const getRes = await request(app.getHttpServer())
        .get(`/api/v1/incidents/${incidentId}`)
        .set('Authorization', `Bearer ${monitored.accessToken}`);
      expect(getRes.status).toBe(404);
    });

    it('should allow guardian (monitor) to delete an incident in the relationship', async () => {
      // Insert incident
      const incRes = await dataSource.query(
        `INSERT INTO incidents (user_id, relationship_id, status, reason, risk_score, detected_at)
         VALUES ($1, $2, 'OPEN', 'DEVICE_OFFLINE', 70, NOW())
         RETURNING id`,
        [monitored.id, relationship.id],
      );
      const incidentId = incRes[0].id;

      // Guardian deletes the incident
      const res = await request(app.getHttpServer())
        .delete(`/api/v1/incidents/${incidentId}`)
        .set('Authorization', `Bearer ${monitor.accessToken}`);

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);

      // Verify DB
      const check = await dataSource.query(`SELECT id FROM incidents WHERE id = $1`, [incidentId]);
      expect(check.length).toBe(0);
    });

    it('should reject unauthorized unrelated user with 403 Forbidden', async () => {
      // Insert incident
      const incRes = await dataSource.query(
        `INSERT INTO incidents (user_id, relationship_id, status, reason, risk_score, detected_at)
         VALUES ($1, $2, 'OPEN', 'MISSED_CHECK_IN', 50, NOW())
         RETURNING id`,
        [monitored.id, relationship.id],
      );
      const incidentId = incRes[0].id;

      // Unrelated user attempts to delete
      const res = await request(app.getHttpServer())
        .delete(`/api/v1/incidents/${incidentId}`)
        .set('Authorization', `Bearer ${unrelatedUser.accessToken}`);

      expect(res.status).toBe(403);
      expect(res.body.message).toContain('You are not authorized to delete this incident');

      // Verify DB: incident still exists
      const check = await dataSource.query(`SELECT id FROM incidents WHERE id = $1`, [incidentId]);
      expect(check.length).toBe(1);
    });

    it('should return 404 Not Found when incident does not exist', async () => {
      const nonExistentId = uuidv4();
      const res = await request(app.getHttpServer())
        .delete(`/api/v1/incidents/${nonExistentId}`)
        .set('Authorization', `Bearer ${monitored.accessToken}`);

      expect(res.status).toBe(404);
    });
  });

  // =========================================================================
  // 2. DELETE /api/v1/incidents (Clear All Incidents)
  // =========================================================================
  describe('Clear All Incidents: DELETE /api/v1/incidents', () => {
    it('should clear all incidents for relationships involving the caller', async () => {
      // 1. Insert 3 incidents for the relationship
      for (let i = 0; i < 3; i++) {
        const inc = await dataSource.query(
          `INSERT INTO incidents (user_id, relationship_id, status, reason, risk_score, detected_at)
           VALUES ($1, $2, 'OPEN', 'MISSED_CHECK_IN', 50, NOW() - INTERVAL '${i} hours')
           RETURNING id`,
          [monitored.id, relationship.id],
        );
        await dataSource.query(
          `INSERT INTO incident_events (incident_id, type) VALUES ($1, 'INCIDENT_CREATED')`,
          [inc[0].id],
        );
      }

      // Verify 3 incidents exist
      const listBefore = await request(app.getHttpServer())
        .get('/api/v1/incidents')
        .set('Authorization', `Bearer ${monitored.accessToken}`);
      expect(listBefore.status).toBe(200);
      expect(listBefore.body.length).toBeGreaterThanOrEqual(3);

      // 2. Clear all incidents
      const clearRes = await request(app.getHttpServer())
        .delete('/api/v1/incidents')
        .set('Authorization', `Bearer ${monitored.accessToken}`);

      expect(clearRes.status).toBe(200);
      expect(clearRes.body.success).toBe(true);
      expect(clearRes.body.count).toBeGreaterThanOrEqual(3);

      // 3. Verify list is now empty for this relationship
      const listAfter = await request(app.getHttpServer())
        .get('/api/v1/incidents')
        .set('Authorization', `Bearer ${monitored.accessToken}`);
      expect(listAfter.status).toBe(200);
      expect(listAfter.body.length).toBe(0);

      // 4. Calling clear again returns count: 0
      const clearAgain = await request(app.getHttpServer())
        .delete('/api/v1/incidents')
        .set('Authorization', `Bearer ${monitored.accessToken}`);
      expect(clearAgain.status).toBe(200);
      expect(clearAgain.body).toEqual({
        success: true,
        count: 0,
      });
    });

    it('should not delete incidents of unrelated relationships', async () => {
      // Create second relationship
      const otherMonitor = await registerAndLoginUser(app, 'other_monitor');
      const otherMonitored = await registerAndLoginUser(app, 'other_monitored');
      const otherPaired = await pairMonitoringRelationship(app, otherMonitor.accessToken, otherMonitored);

      // Insert incident in second relationship
      const otherInc = await dataSource.query(
        `INSERT INTO incidents (user_id, relationship_id, status, reason, risk_score, detected_at)
         VALUES ($1, $2, 'OPEN', 'MISSED_CHECK_IN', 50, NOW())
         RETURNING id`,
        [otherMonitored.id, otherPaired.relationship.id],
      );

      // First monitored user clears incidents
      await request(app.getHttpServer())
        .delete('/api/v1/incidents')
        .set('Authorization', `Bearer ${monitored.accessToken}`);

      // Second relationship incident must still be present
      const checkOther = await dataSource.query(
        `SELECT id FROM incidents WHERE id = $1`,
        [otherInc[0].id],
      );
      expect(checkOther.length).toBe(1);

      // Clean up second relationship incident
      await request(app.getHttpServer())
        .delete('/api/v1/incidents')
        .set('Authorization', `Bearer ${otherMonitored.accessToken}`);
    });
  });
});
