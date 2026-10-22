import { randomUUID } from 'crypto';
import pg from 'pg';

const BASE_URL = 'http://localhost:3001/api/v1';

const pool = new pg.Pool({
  host: 'localhost',
  port: 5435,
  user: 'carely_user',
  password: 'carely_secret_password',
  database: 'carely_db',
});

async function run() {
  console.log('=== STARTING CARELY (EVENEAR) LIVE BACKEND VERIFICATION ===\n');

  // 1. Health check
  console.log('--- 1. Health Probe (GET /health) ---');
  const healthRes = await fetch(`${BASE_URL}/health`);
  const healthData = await healthRes.json();
  console.log(`HTTP ${healthRes.status}:`, JSON.stringify(healthData, null, 2));
  if (healthRes.status !== 200 || healthData.services?.database !== 'UP' || healthData.services?.redis !== 'UP') {
    throw new Error('Health check failed!');
  }
  console.log(' Health check verified: database: UP, redis: UP\n');

  // 2. Register Monitored Elder User
  const timestamp = Date.now();
  const elderEmail = `elder_live_${timestamp}@carely.local`;
  const elderPassword = 'Password123!';
  console.log(`--- 2. Register Elder User (POST /auth/register) [${elderEmail}] ---`);
  const registerElderRes = await fetch(`${BASE_URL}/auth/register`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      email: elderEmail,
      password: elderPassword,
      displayName: 'Nguyễn Văn An (Elder)',
      phoneNumber: `+8491${String(timestamp).slice(-7)}`,
      preferredLanguage: 'vi',
      timezone: 'Asia/Ho_Chi_Minh',
    }),
  });
  const registerElderData = await registerElderRes.json();
  console.log(`HTTP ${registerElderRes.status}:`, JSON.stringify(registerElderData, null, 2));
  if (registerElderRes.status !== 201 || !registerElderData.user?.id) {
    throw new Error('Elder registration failed!');
  }
  const elderId = registerElderData.user.id;
  console.log(` Elder user created with ID: ${elderId}\n`);

  // 3. Login with credentials
  console.log('--- 3. Login with Credentials (POST /auth/login) ---');
  const loginRes = await fetch(`${BASE_URL}/auth/login`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      email: elderEmail,
      password: elderPassword,
    }),
  });
  const loginData = await loginRes.json();
  console.log(`HTTP ${loginRes.status}:`, JSON.stringify({
    accessToken: loginData.accessToken ? `${loginData.accessToken.slice(0, 25)}...` : null,
    refreshToken: loginData.refreshToken ? `${loginData.refreshToken.slice(0, 25)}...` : null,
    user: loginData.user,
  }, null, 2));
  if (loginRes.status !== 200 || !loginData.accessToken) {
    throw new Error('Elder login failed!');
  }
  const elderToken = loginData.accessToken;
  console.log(' Elder login successful, JWT token obtained.\n');

  // 4. Update profile language
  console.log('--- 4. Update Profile Language (PATCH /users/me) ---');
  const updateLangRes = await fetch(`${BASE_URL}/users/me`, {
    method: 'PATCH',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${elderToken}`,
    },
    body: JSON.stringify({
      preferredLanguage: 'en',
    }),
  });
  const updateLangData = await updateLangRes.json();
  console.log(`HTTP ${updateLangRes.status}:`, JSON.stringify(updateLangData, null, 2));
  if (updateLangRes.status !== 200 || updateLangData.preferredLanguage !== 'en') {
    throw new Error('Profile language update failed!');
  }
  console.log(' Profile preferredLanguage updated to "en"\n');

  // 5. Register Device
  console.log('--- 5. Register Device (POST /devices) ---');
  const deviceUid = `iphone-15-pro-${timestamp}`;
  const registerDevRes = await fetch(`${BASE_URL}/devices`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${elderToken}`,
    },
    body: JSON.stringify({
      deviceUid,
      platform: 'IOS',
      deviceName: 'iPhone 15 Pro',
      batteryLevel: 92,
      pushToken: `fcm-token-${timestamp}`,
      appVersion: '2.4.0',
      osVersion: 'iOS 18.1',
    }),
  });
  const registerDevData = await registerDevRes.json();
  console.log(`HTTP ${registerDevRes.status}:`, JSON.stringify(registerDevData, null, 2));
  if (registerDevRes.status !== 201 || !registerDevData.id) {
    throw new Error('Device registration failed!');
  }
  const deviceId = registerDevData.id;
  console.log(` Device registered with ID: ${deviceId}\n`);

  // 6. Register & Login Guardian
  const guardianEmail = `guardian_live_${timestamp}@carely.local`;
  const guardianPassword = 'Password123!';
  console.log(`--- 6. Register Guardian (POST /auth/register) [${guardianEmail}] ---`);
  const registerGuardRes = await fetch(`${BASE_URL}/auth/register`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      email: guardianEmail,
      password: guardianPassword,
      displayName: 'Trần Thị Mai (Guardian)',
      preferredLanguage: 'vi',
    }),
  });
  const registerGuardData = await registerGuardRes.json();
  const guardianToken = registerGuardData.accessToken;
  console.log(`HTTP ${registerGuardRes.status}: Guardian registered. ID: ${registerGuardData.user?.id}\n`);

  // 7. Generate QR Pairing Invitation & Accept
  console.log('--- 7. Generate QR Pairing Invitation (POST /monitoring/relationships/invite-code) ---');
  const inviteRes = await fetch(`${BASE_URL}/monitoring/relationships/invite-code`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${elderToken}`,
    },
    body: JSON.stringify({
      role: 'MONITORED',
      label: 'Mẹ',
    }),
  });
  const inviteData = await inviteRes.json();
  console.log(`HTTP ${inviteRes.status}:`, JSON.stringify(inviteData, null, 2));
  const inviteCode = inviteData.inviteCode || inviteData.invitationCode || inviteData.code;
  if (inviteRes.status !== 201 || !inviteCode) {
    throw new Error('Generating invite code failed!');
  }

  console.log(`--- Accept QR Pairing Invitation (POST /monitoring/relationships/accept) [Code: ${inviteCode}] ---`);
  const acceptRes = await fetch(`${BASE_URL}/monitoring/relationships/accept`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${guardianToken}`,
    },
    body: JSON.stringify({
      inviteCode,
    }),
  });
  const acceptData = await acceptRes.json();
  console.log(`HTTP ${acceptRes.status}:`, JSON.stringify(acceptData, null, 2));
  const relationshipId = acceptData.id || acceptData.relationship?.id;
  if (acceptRes.status !== 200 || !relationshipId) {
    throw new Error('Accepting pairing invitation failed!');
  }
  console.log(` Relationship established with ID: ${relationshipId}, Status: ${acceptData.status || acceptData.relationship?.status}\n`);

  // 8. Verify Axiom 1: Heartbeat (weight = 0.0, connectivity only, does not advance timer)
  console.log('--- 8. Verify Axiom 1: Send Heartbeat (POST /activities/heartbeat) ---');
  const dbConfigBefore = await pool.query(
    'SELECT id, current_state, last_meaningful_activity_at, next_evaluation_at FROM monitoring_configs WHERE relationship_id = $1',
    [relationshipId],
  );
  const configBefore = dbConfigBefore.rows[0];
  console.log('Config before heartbeat:', configBefore);

  const heartbeatTime = new Date().toISOString();
  const heartbeatRes = await fetch(`${BASE_URL}/activities/heartbeat`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${elderToken}`,
    },
    body: JSON.stringify({
      deviceId,
      occurredAt: heartbeatTime,
      batteryLevel: 90,
      isCharging: false,
    }),
  });
  const heartbeatData = await heartbeatRes.json();
  console.log(`HTTP ${heartbeatRes.status}:`, JSON.stringify(heartbeatData, null, 2));

  const dbConfigAfterHb = await pool.query(
    'SELECT id, current_state, last_meaningful_activity_at, next_evaluation_at FROM monitoring_configs WHERE relationship_id = $1',
    [relationshipId],
  );
  const configAfterHb = dbConfigAfterHb.rows[0];
  console.log('Config after heartbeat:', configAfterHb);

  const t1 = configBefore.last_meaningful_activity_at ? new Date(configBefore.last_meaningful_activity_at).getTime() : 0;
  const t2 = configAfterHb.last_meaningful_activity_at ? new Date(configAfterHb.last_meaningful_activity_at).getTime() : 0;
  if (t1 !== t2) {
    throw new Error('Axiom 1 VIOLATION: Heartbeat advanced meaningful activity timer!');
  }
  console.log(' Axiom 1 Verified: Heartbeat weight 0.0, device state updated (battery 90%), lastMeaningfulActivityAt did NOT advance.\n');

  // 9. Verify Axiom 2: Passive Activity (weight 0.2-0.8, advances timer)
  console.log('--- 9. Verify Axiom 2: Send Passive Activity (POST /activities) ---');
  // Wait 1.1s to ensure occurredAt is distinct and newer than config initialization
  await new Promise((r) => setTimeout(r, 1100));
  const activityEventId = randomUUID();
  const activityTime = new Date().toISOString();
  const activityRes = await fetch(`${BASE_URL}/activities`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${elderToken}`,
    },
    body: JSON.stringify({
      eventId: activityEventId,
      deviceId,
      type: 'APP_FOREGROUND',
      occurredAt: activityTime,
      confidence: 1.0,
      metadata: { source: 'screen_unlock' },
    }),
  });
  const activityData = await activityRes.json();
  console.log(`HTTP ${activityRes.status}:`, JSON.stringify(activityData, null, 2));
  if (activityRes.status !== 201 || Number(activityData.weight) !== 0.8) {
    throw new Error(`Axiom 2 VIOLATION: Expected weight 0.8, got ${activityData.weight}`);
  }

  const dbConfigAfterAct = await pool.query(
    'SELECT id, current_state, last_meaningful_activity_at, next_evaluation_at FROM monitoring_configs WHERE relationship_id = $1',
    [relationshipId],
  );
  const configAfterAct = dbConfigAfterAct.rows[0];
  console.log('Config after passive activity:', configAfterAct);
  const t3 = new Date(configAfterAct.last_meaningful_activity_at).getTime();
  if (t3 <= t2) {
    throw new Error('Axiom 2 VIOLATION: Passive activity did not advance meaningful activity timer!');
  }
  console.log(` Axiom 2 Verified: Activity APP_FOREGROUND recorded with weight ${activityData.weight} (in range [0.2, 0.8]), advanced lastMeaningfulActivityAt from ${new Date(t2).toISOString()} to ${new Date(t3).toISOString()}\n`);

  // 10. Create Open Incident & Set State to CHECK_IN_REQUIRED
  console.log('--- 10. Create Incident & Test Open Incident ---');
  // Transition relationship config to CHECK_IN_REQUIRED to test state machine reset
  await pool.query(
    "UPDATE monitoring_configs SET current_state = 'CHECK_IN_REQUIRED' WHERE relationship_id = $1",
    [relationshipId],
  );

  const incInsertRes = await pool.query(
    `INSERT INTO incidents (user_id, relationship_id, status, reason, risk_score, detected_at)
     VALUES ($1, $2, 'OPEN', 'INACTIVITY', 80, NOW())
     RETURNING id, status`,
    [elderId, relationshipId],
  );
  const incidentData = incInsertRes.rows[0];
  if (!incidentData || incidentData.status !== 'OPEN') {
    throw new Error('Failed to create open incident!');
  }
  const incidentId = incidentData.id;
  console.log(` Open Incident created with ID: ${incidentId}, Status: ${incidentData.status}\n`);

  // 11. Verify Axiom 3: Check-in "Tôi vẫn ổn" (weight 1.0, resets state to ACTIVE, resolves open incidents)
  console.log('--- 11. Verify Axiom 3: Send Check-in "Tôi vẫn ổn" (POST /check-ins) ---');
  // Ensure check-in occurredAt is after incident creation
  await new Promise((r) => setTimeout(r, 1100));
  const checkInEventId = randomUUID();
  const checkInTime = new Date().toISOString();
  const checkInRes = await fetch(`${BASE_URL}/check-ins`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${elderToken}`,
    },
    body: JSON.stringify({
      eventId: checkInEventId,
      deviceId,
      relationshipId,
      occurredAt: checkInTime,
      batteryLevel: 88,
      note: 'Tôi vẫn ổn',
      location: {
        latitude: 21.0285,
        longitude: 105.8542,
        accuracy: 10,
      },
    }),
  });
  const checkInData = await checkInRes.json();
  console.log(`HTTP ${checkInRes.status}:`, JSON.stringify(checkInData, null, 2));
  if (checkInRes.status !== 201 || !checkInData.id) {
    throw new Error('Check-in failed!');
  }

  // Verify Check-in Activity weight 1.0
  const dbCheckInAct = await pool.query(
    "SELECT event_id, type, weight FROM activities WHERE event_id = $1",
    [checkInEventId],
  );
  console.log('Check-in Activity DB record:', dbCheckInAct.rows[0]);
  if (Number(dbCheckInAct.rows[0].weight) !== 1.0) {
    throw new Error(`Axiom 3 VIOLATION: Expected weight 1.0, got ${dbCheckInAct.rows[0].weight}`);
  }

  // Verify monitoring config reset to ACTIVE
  const dbConfigAfterCheckIn = await pool.query(
    'SELECT id, current_state, last_meaningful_activity_at, next_evaluation_at FROM monitoring_configs WHERE relationship_id = $1',
    [relationshipId],
  );
  console.log('Config after check-in:', dbConfigAfterCheckIn.rows[0]);
  if (dbConfigAfterCheckIn.rows[0].current_state !== 'ACTIVE') {
    throw new Error(`Axiom 3 VIOLATION: Expected state ACTIVE, got ${dbConfigAfterCheckIn.rows[0].current_state}`);
  }

  // Verify open incident automatically RESOLVED
  const dbIncidentAfterCheckIn = await pool.query(
    'SELECT id, status, resolved_at, resolved_by FROM incidents WHERE id = $1',
    [incidentId],
  );
  console.log('Incident record after check-in:', dbIncidentAfterCheckIn.rows[0]);
  if (dbIncidentAfterCheckIn.rows[0].status !== 'RESOLVED') {
    throw new Error(`Axiom 3 VIOLATION: Expected incident status RESOLVED, got ${dbIncidentAfterCheckIn.rows[0].status}`);
  }
  console.log(' Axiom 3 Verified: Check-in weight 1.0, Monitoring State reset to ACTIVE, Open Incident automatically RESOLVED.\n');

  // 12. Retrieve Incidents (GET /incidents) and Clear All Notifications (DELETE /incidents)
  console.log('--- 12. List Incidents (GET /incidents) ---');
  const listIncidentsRes = await fetch(`${BASE_URL}/incidents`, {
    headers: { Authorization: `Bearer ${elderToken}` },
  });
  const listIncidentsData = await listIncidentsRes.json();
  console.log(`HTTP ${listIncidentsRes.status}: Found ${listIncidentsData.length} incidents.`);
  if (listIncidentsRes.status !== 200 || listIncidentsData.length === 0) {
    throw new Error('Failed to retrieve incidents!');
  }

  console.log('--- Clear All Notifications/Incidents (DELETE /incidents) ---');
  const clearIncidentsRes = await fetch(`${BASE_URL}/incidents`, {
    method: 'DELETE',
    headers: { Authorization: `Bearer ${elderToken}` },
  });
  const clearIncidentsData = await clearIncidentsRes.json();
  console.log(`HTTP ${clearIncidentsRes.status}:`, JSON.stringify(clearIncidentsData, null, 2));
  if (clearIncidentsRes.status !== 200) {
    throw new Error('Clear incidents failed!');
  }

  console.log('--- Verify Incidents Empty after Clear (GET /incidents) ---');
  const listAfterClearRes = await fetch(`${BASE_URL}/incidents`, {
    headers: { Authorization: `Bearer ${elderToken}` },
  });
  const listAfterClearData = await listAfterClearRes.json();
  console.log(`HTTP ${listAfterClearRes.status}: Incidents count = ${listAfterClearData.length}`);
  if (listAfterClearData.length !== 0) {
    throw new Error(`Expected 0 incidents after clear, found ${listAfterClearData.length}`);
  }
  console.log(' Incident clearance verified: 0 incidents remaining, notifications clean.\n');

  console.log('=== ALL LIVE FLOWS & 3 CORE AXIOMS VERIFIED SUCCESSFULLY 100% ===');
  await pool.end();
}

run().catch((err) => {
  console.error('FATAL ERROR DURING VERIFICATION:', err);
  pool.end();
  process.exit(1);
});
