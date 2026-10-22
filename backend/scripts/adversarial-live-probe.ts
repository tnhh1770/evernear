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

interface AuthResult {
  user: any;
  token: string;
}

async function registerAndLogin(prefix: string, roleName: string): Promise<AuthResult> {
  const ts = Date.now() + Math.floor(Math.random() * 10000);
  const email = `${prefix}_${ts}@carely.adversarial`;
  const password = 'Password123!';
  const phone = `+8498${String(ts).slice(-7)}`;

  const regRes = await fetch(`${BASE_URL}/auth/register`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      email,
      password,
      displayName: `${roleName} ${ts}`,
      phoneNumber: phone,
      preferredLanguage: 'vi',
      timezone: 'Asia/Ho_Chi_Minh',
    }),
  });
  const regData = await regRes.json();
  if (regRes.status !== 201 || !regData.user?.id) {
    throw new Error(`Failed to register ${roleName}: HTTP ${regRes.status} ${JSON.stringify(regData)}`);
  }

  const loginRes = await fetch(`${BASE_URL}/auth/login`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email, password }),
  });
  const loginData = await loginRes.json();
  if (loginRes.status !== 200 || !loginData.accessToken) {
    throw new Error(`Failed to login ${roleName}: HTTP ${loginRes.status}`);
  }

  return { user: loginData.user, token: loginData.accessToken };
}

async function runAdversarialProbes() {
  console.log('================================================================');
  console.log('   CARELY (EVENEAR) ADVERSARIAL LIVE PROBES & STRESS HARNESS    ');
  console.log('================================================================\n');

  let passedAssertions = 0;
  function assert(condition: boolean, message: string) {
    if (!condition) {
      console.error(`❌ ASSERTION FAILED: ${message}`);
      throw new Error(`ASSERTION FAILED: ${message}`);
    }
    console.log(`  ✓ ${message}`);
    passedAssertions++;
  }

  // ---------------------------------------------------------------------------
  // 1. Health Probe
  // ---------------------------------------------------------------------------
  console.log('>>> [TEST 1] Live Health & Infrastructure Responsiveness');
  const healthRes = await fetch(`${BASE_URL}/health`);
  const healthData = await healthRes.json();
  assert(healthRes.status === 200, 'Health endpoint responds with HTTP 200');
  assert(healthData.status === 'OK', 'Overall health status is OK');
  assert(healthData.services?.database === 'UP', 'PostgreSQL database service reports UP');
  assert(healthData.services?.redis === 'UP', 'Redis cache service reports UP');

  // Test root /health without prefix -> expect 404, not unhandled 500
  const rootHealthRes = await fetch('http://localhost:3001/health');
  assert(rootHealthRes.status === 404, 'Root /health without prefix returns 404 Not Found cleanly');

  // ---------------------------------------------------------------------------
  // 2. Auth Edge Cases & Multi-Tenant Setup
  // ---------------------------------------------------------------------------
  console.log('\n>>> [TEST 2] Auth Edge Cases & Dual Relationship Setup');
  // Register Elder A & Guardian A
  const elderA = await registerAndLogin('elder_a', 'Elder Alice');
  const guardianA = await registerAndLogin('guardian_a', 'Guardian Bob');
  assert(!!elderA.token && !!guardianA.token, 'Pair A registered and authenticated');

  // Register Elder B & Guardian B
  const elderB = await registerAndLogin('elder_b', 'Elder Charlie');
  const guardianB = await registerAndLogin('guardian_b', 'Guardian Diana');
  assert(!!elderB.token && !!guardianB.token, 'Pair B registered and authenticated');

  // Duplicate email registration edge case
  const duplicateRegRes = await fetch(`${BASE_URL}/auth/register`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      email: elderA.user.email,
      password: 'AnyPassword123!',
      displayName: 'Duplicate User',
    }),
  });
  assert([400, 409].includes(duplicateRegRes.status), 'Duplicate email registration returns 400 or 409 (not 500)');

  // Invalid password login edge case
  const badLoginRes = await fetch(`${BASE_URL}/auth/login`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      email: elderA.user.email,
      password: 'WrongPassword!',
    }),
  });
  assert(badLoginRes.status === 401, 'Invalid password login returns HTTP 401 Unauthorized');

  // ---------------------------------------------------------------------------
  // 3. QR Pairing Edge Cases & Adversarial Races
  // ---------------------------------------------------------------------------
  console.log('\n>>> [TEST 3] QR Pairing Edge Cases & Replay Resistance');
  // Elder A creates invite code
  const inviteARes = await fetch(`${BASE_URL}/monitoring/relationships/invite-code`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${elderA.token}`,
    },
    body: JSON.stringify({ role: 'MONITORED', label: 'Elder Alice' }),
  });
  const inviteAData = await inviteARes.json();
  const inviteCodeA = inviteAData.inviteCode || inviteAData.code;
  assert(inviteARes.status === 201 && !!inviteCodeA, 'Elder A generated valid QR pairing invite code');

  // Non-existent invite code edge case
  const bogusAcceptRes = await fetch(`${BASE_URL}/monitoring/relationships/accept`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${guardianA.token}`,
    },
    body: JSON.stringify({ inviteCode: 'CR-NONEXIST99' }),
  });
  assert([400, 404].includes(bogusAcceptRes.status), 'Bogus invite code returns 400/404');

  // Self-pairing edge case (Elder A attempts to accept their own invite code)
  const selfPairRes = await fetch(`${BASE_URL}/monitoring/relationships/accept`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${elderA.token}`,
    },
    body: JSON.stringify({ inviteCode: inviteCodeA }),
  });
  assert([400, 409].includes(selfPairRes.status), 'Self-pairing is rejected with 400/409');

  // Guardian A accepts code
  const acceptARes = await fetch(`${BASE_URL}/monitoring/relationships/accept`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${guardianA.token}`,
    },
    body: JSON.stringify({ inviteCode: inviteCodeA }),
  });
  const acceptAData = await acceptARes.json();
  const relIdA = acceptAData.id || acceptAData.relationship?.id;
  assert(acceptARes.status === 200 && !!relIdA, 'Guardian A successfully paired with Elder A');

  // Replay Attack: Guardian B tries to accept Elder A's code which was already used
  const replayAcceptRes = await fetch(`${BASE_URL}/monitoring/relationships/accept`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${guardianB.token}`,
    },
    body: JSON.stringify({ inviteCode: inviteCodeA }),
  });
  assert([400, 404, 409].includes(replayAcceptRes.status), 'Replay of consumed invite code is rejected (400/404/409)');

  // Pair Pair B (Elder B <-> Guardian B)
  const inviteBRes = await fetch(`${BASE_URL}/monitoring/relationships/invite-code`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${elderB.token}`,
    },
    body: JSON.stringify({ role: 'MONITORED', label: 'Elder Charlie' }),
  });
  const inviteBData = await inviteBRes.json();
  const inviteCodeB = inviteBData.inviteCode || inviteBData.code;

  const acceptBRes = await fetch(`${BASE_URL}/monitoring/relationships/accept`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${guardianB.token}`,
    },
    body: JSON.stringify({ inviteCode: inviteCodeB }),
  });
  const acceptBData = await acceptBRes.json();
  const relIdB = acceptBData.id || acceptBData.relationship?.id;
  assert(acceptBRes.status === 200 && !!relIdB, 'Guardian B successfully paired with Elder B');

  // ---------------------------------------------------------------------------
  // 4. Register Devices
  // ---------------------------------------------------------------------------
  console.log('\n>>> [TEST 4] Device Registrations');
  const devARes = await fetch(`${BASE_URL}/devices`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${elderA.token}`,
    },
    body: JSON.stringify({
      deviceUid: `device-elder-a-${Date.now()}`,
      platform: 'ANDROID',
      deviceName: 'Pixel 8 Pro',
      batteryLevel: 95,
      pushToken: `token-a-${Date.now()}`,
      appVersion: '2.4.0',
    }),
  });
  const devAData = await devARes.json();
  const devIdA = devAData.id;
  assert(devARes.status === 201 && !!devIdA, 'Device A registered for Elder A');

  const devBRes = await fetch(`${BASE_URL}/devices`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${elderB.token}`,
    },
    body: JSON.stringify({
      deviceUid: `device-elder-b-${Date.now()}`,
      platform: 'IOS',
      deviceName: 'iPhone 16 Pro',
      batteryLevel: 80,
      pushToken: `token-b-${Date.now()}`,
      appVersion: '2.4.0',
    }),
  });
  const devBData = await devBRes.json();
  const devIdB = devBData.id;
  assert(devBRes.status === 201 && !!devIdB, 'Device B registered for Elder B');

  // ---------------------------------------------------------------------------
  // 5. Axiom 1 Adversarial Probe: High-Concurrency Heartbeats & Timer Invariance
  // ---------------------------------------------------------------------------
  console.log('\n>>> [TEST 5] Axiom 1 Adversarial Probe (Heartbeat Concurrency & Invariance)');
  const configABefore = await pool.query(
    'SELECT id, last_meaningful_activity_at, next_evaluation_at FROM monitoring_configs WHERE relationship_id = $1',
    [relIdA],
  );
  const baselineMeaningfulAt = configABefore.rows[0].last_meaningful_activity_at;
  const baselineEvalAt = configABefore.rows[0].next_evaluation_at;

  // Send 1st heartbeat -> 200 OK
  const hb1Res = await fetch(`${BASE_URL}/activities/heartbeat`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${elderA.token}`,
    },
    body: JSON.stringify({
      deviceId: devIdA,
      occurredAt: new Date().toISOString(),
      batteryLevel: 94,
      isCharging: false,
    }),
  });
  assert(hb1Res.status === 200, 'First heartbeat returns 200 OK');

  // Send 2nd heartbeat -> 200 OK (limit is 2 per 30s)
  const hb2Res = await fetch(`${BASE_URL}/activities/heartbeat`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${elderA.token}`,
    },
    body: JSON.stringify({
      deviceId: devIdA,
      occurredAt: new Date().toISOString(),
      batteryLevel: 93,
      isCharging: false,
    }),
  });
  assert(hb2Res.status === 200, 'Second heartbeat within 30s returns 200 OK');

  // Send 3rd immediate heartbeat -> 429 Too Many Requests (Atomic Redis Rate Limiting)
  const hb3Res = await fetch(`${BASE_URL}/activities/heartbeat`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${elderA.token}`,
    },
    body: JSON.stringify({
      deviceId: devIdA,
      occurredAt: new Date().toISOString(),
      batteryLevel: 92,
      isCharging: false,
    }),
  });
  assert(hb3Res.status === 429, 'Third immediate heartbeat is rate-limited with HTTP 429 (DoS defense verified)');

  // Send heartbeat from Device B (different device) -> 200 OK (per-device rate limit isolation)
  const hbDevBRes = await fetch(`${BASE_URL}/activities/heartbeat`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${elderB.token}`,
    },
    body: JSON.stringify({
      deviceId: devIdB,
      occurredAt: new Date().toISOString(),
      batteryLevel: 79,
      isCharging: false,
    }),
  });
  assert(hbDevBRes.status === 200, 'Device B heartbeat returns 200 OK (Rate limit is strictly isolated per device)');

  // Check DB state after heartbeats
  const configAAfterHb = await pool.query(
    'SELECT id, last_meaningful_activity_at, next_evaluation_at FROM monitoring_configs WHERE relationship_id = $1',
    [relIdA],
  );
  const meaningfulAtAfterHb = configAAfterHb.rows[0].last_meaningful_activity_at;
  const evalAtAfterHb = configAAfterHb.rows[0].next_evaluation_at;

  assert(
    new Date(baselineMeaningfulAt).getTime() === new Date(meaningfulAtAfterHb).getTime(),
    'Axiom 1 Invariant: Heartbeats (both 200 and 429) did NOT advance last_meaningful_activity_at!',
  );
  assert(
    new Date(baselineEvalAt).getTime() === new Date(evalAtAfterHb).getTime(),
    'Axiom 1 Invariant: Heartbeats did NOT alter next_evaluation_at!',
  );

  // Check device table updated
  const devCheck = await pool.query('SELECT battery_level, is_active FROM devices WHERE id = $1', [devIdA]);
  assert(devCheck.rows[0].battery_level <= 95, 'Device battery updated from heartbeats');

  // ---------------------------------------------------------------------------
  // 6. Axiom 2 Adversarial Probe: Activity Weights & Out-of-Order Non-Rewind
  // ---------------------------------------------------------------------------
  console.log('\n>>> [TEST 6] Axiom 2 Adversarial Probe (Weights & Non-Rewind Invariance)');
  await new Promise((r) => setTimeout(r, 1000));
  const tActivity1 = new Date();

  // Send legitimate passive activity at tActivity1
  const act1Res = await fetch(`${BASE_URL}/activities`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${elderA.token}`,
    },
    body: JSON.stringify({
      eventId: randomUUID(),
      deviceId: devIdA,
      type: 'APP_FOREGROUND',
      occurredAt: tActivity1.toISOString(),
      confidence: 1.0,
      metadata: { unlock: true },
    }),
  });
  const act1Data = await act1Res.json();
  assert(act1Res.status === 201, 'APP_FOREGROUND activity accepted with 201 Created');
  assert(Number(act1Data.weight) === 0.8, `Axiom 2: APP_FOREGROUND weight is 0.80 (got ${act1Data.weight})`);

  const configAAfterAct1 = await pool.query(
    'SELECT last_meaningful_activity_at, next_evaluation_at FROM monitoring_configs WHERE relationship_id = $1',
    [relIdA],
  );
  const meaningfulAtAct1 = new Date(configAAfterAct1.rows[0].last_meaningful_activity_at).getTime();
  assert(
    meaningfulAtAct1 > new Date(baselineMeaningfulAt).getTime(),
    'Axiom 2: Legitimate passive activity advanced last_meaningful_activity_at forward',
  );

  // Adversarial: Send delayed out-of-order activity from 30 minutes in the PAST
  const tPast = new Date(Date.now() - 30 * 60 * 1000);
  const actPastRes = await fetch(`${BASE_URL}/activities`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${elderA.token}`,
    },
    body: JSON.stringify({
      eventId: randomUUID(),
      deviceId: devIdA,
      type: 'STEP_DETECTED',
      occurredAt: tPast.toISOString(),
      confidence: 0.9,
    }),
  });
  const actPastData = await actPastRes.json();
  assert(actPastRes.status === 201, `Past activity accepted into historical log (got ${actPastRes.status}: ${JSON.stringify(actPastData)})`);

  const configAAfterPast = await pool.query(
    'SELECT last_meaningful_activity_at FROM monitoring_configs WHERE relationship_id = $1',
    [relIdA],
  );
  const meaningfulAtAfterPast = new Date(configAAfterPast.rows[0].last_meaningful_activity_at).getTime();

  assert(
    meaningfulAtAfterPast >= meaningfulAtAct1,
    'Non-Rewind Invariance: Past delayed activity did NOT rewind last_meaningful_activity_at backwards!',
  );

  // ---------------------------------------------------------------------------
  // 7. Axiom 3 Adversarial Probe: Multi-Incident Resolution & Cross-Tenant Isolation
  // ---------------------------------------------------------------------------
  console.log('\n>>> [TEST 7] Axiom 3 Adversarial Probe (Multi-Incident Resolution & Cross-Tenant Isolation)');
  // Set both relationship configs to CHECK_IN_REQUIRED
  await pool.query("UPDATE monitoring_configs SET current_state = 'CHECK_IN_REQUIRED' WHERE relationship_id IN ($1, $2)", [
    relIdA,
    relIdB,
  ]);

  // Create 2 open incidents for Relationship A
  const incA1Res = await pool.query(
    `INSERT INTO incidents (user_id, relationship_id, status, reason, risk_score, detected_at)
     VALUES ($1, $2, 'OPEN', 'INACTIVITY', 80, NOW())
     RETURNING id, status`,
    [elderA.user.id, relIdA],
  );
  const incIdA1 = incA1Res.rows[0].id;
  assert(incA1Res.rows[0].status === 'OPEN', 'Elder A Incident 1 created (OPEN)');

  // Create second incident in DB for Relationship A
  const incA2Res = await pool.query(
    `INSERT INTO incidents (user_id, relationship_id, status, reason, risk_score, detected_at)
     VALUES ($1, $2, 'OPEN', 'MISSED_CHECK_IN', 70, NOW())
     RETURNING id, status`,
    [elderA.user.id, relIdA],
  );
  const incIdA2 = incA2Res.rows[0].id;
  assert(!!incIdA2, 'Elder A Incident 2 created in DB (OPEN)');

  // Create 1 open incident for Relationship B
  const incBRes = await pool.query(
    `INSERT INTO incidents (user_id, relationship_id, status, reason, risk_score, detected_at)
     VALUES ($1, $2, 'OPEN', 'INACTIVITY', 80, NOW())
     RETURNING id, status`,
    [elderB.user.id, relIdB],
  );
  const incIdB = incBRes.rows[0].id;
  assert(incBRes.rows[0].status === 'OPEN', 'Elder B Incident created (OPEN)');

  // Elder A sends Check-in ("Tôi vẫn ổn")
  await new Promise((r) => setTimeout(r, 1000));
  const checkInEventIdA = randomUUID();
  const checkInARes = await fetch(`${BASE_URL}/check-ins`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${elderA.token}`,
    },
    body: JSON.stringify({
      eventId: checkInEventIdA,
      deviceId: devIdA,
      relationshipId: relIdA,
      occurredAt: new Date().toISOString(),
      batteryLevel: 85,
      note: 'Tôi vẫn ổn (Check-in from Alice)',
    }),
  });
  const checkInAData = await checkInARes.json();
  assert(checkInARes.status === 201 && !!checkInAData.id, 'Elder A Check-in successfully registered (HTTP 201)');

  // Axiom 3 checks for Relationship A
  const dbCheckInActA = await pool.query('SELECT weight FROM activities WHERE event_id = $1', [checkInEventIdA]);
  assert(Number(dbCheckInActA.rows[0].weight) === 1.0, 'Axiom 3: Check-in activity weight is 1.00');

  const configAfterCheckInA = await pool.query('SELECT current_state FROM monitoring_configs WHERE relationship_id = $1', [
    relIdA,
  ]);
  assert(
    configAfterCheckInA.rows[0].current_state === 'ACTIVE',
    'Axiom 3: Relationship A monitoring state reset from CHECK_IN_REQUIRED back to ACTIVE',
  );

  const incidentsAAfter = await pool.query('SELECT id, status FROM incidents WHERE id IN ($1, $2)', [incIdA1, incIdA2]);
  for (const inc of incidentsAAfter.rows) {
    assert(inc.status === 'RESOLVED', `Axiom 3: Relationship A incident ${inc.id} automatically transitioned to RESOLVED`);
  }

  // Cross-Tenant Isolation checks: Relationship B must NOT be affected!
  const configBAfterCheckInA = await pool.query(
    'SELECT current_state FROM monitoring_configs WHERE relationship_id = $1',
    [relIdB],
  );
  assert(
    configBAfterCheckInA.rows[0].current_state === 'CHECK_IN_REQUIRED',
    'Tenant Isolation: Relationship B monitoring state is STILL CHECK_IN_REQUIRED (unaffected by A)',
  );

  const incidentBAfter = await pool.query('SELECT id, status FROM incidents WHERE id = $1', [incIdB]);
  assert(
    incidentBAfter.rows[0].status === 'OPEN',
    'Tenant Isolation: Relationship B incident is STILL OPEN (unaffected by A)',
  );

  // ---------------------------------------------------------------------------
  // 8. Incident Clearing & Notification Lifecycle
  // ---------------------------------------------------------------------------
  console.log('\n>>> [TEST 8] Incident Clear & Idempotent Cleanup');
  // List incidents for Elder A -> should see 2 resolved incidents
  const listARes = await fetch(`${BASE_URL}/incidents`, {
    headers: { Authorization: `Bearer ${elderA.token}` },
  });
  const listAData = await listARes.json();
  assert(listARes.status === 200 && listAData.length >= 2, `Elder A sees their ${listAData.length} incidents`);

  // Clear incidents for Elder A
  const clearARes = await fetch(`${BASE_URL}/incidents`, {
    method: 'DELETE',
    headers: { Authorization: `Bearer ${elderA.token}` },
  });
  const clearAData = await clearARes.json();
  assert(clearARes.status === 200 && clearAData.success === true, 'DELETE /incidents returns HTTP 200 { success: true }');
  assert(clearAData.count >= 2, `Deleted ${clearAData.count} incidents for Elder A`);

  // Verify Elder A incident count is now 0
  const listAEmptyRes = await fetch(`${BASE_URL}/incidents`, {
    headers: { Authorization: `Bearer ${elderA.token}` },
  });
  const listAEmptyData = await listAEmptyRes.json();
  assert(listAEmptyRes.status === 200 && listAEmptyData.length === 0, 'Elder A incident list is completely empty (count = 0)');

  // Idempotency check: Delete again when count is 0
  const clearAIdempotentRes = await fetch(`${BASE_URL}/incidents`, {
    method: 'DELETE',
    headers: { Authorization: `Bearer ${elderA.token}` },
  });
  const clearAIdempotentData = await clearAIdempotentRes.json();
  assert(
    clearAIdempotentRes.status === 200 && clearAIdempotentData.count === 0,
    'Idempotent DELETE /incidents when empty returns 200 { success: true, count: 0 }',
  );

  // Critical Cross-Tenant Check: Ensure Elder B's incidents were NOT deleted by Elder A's clear
  const listBRes = await fetch(`${BASE_URL}/incidents`, {
    headers: { Authorization: `Bearer ${elderB.token}` },
  });
  const listBData = await listBRes.json();
  assert(
    listBRes.status === 200 && listBData.length === 1 && listBData[0].id === incIdB,
    'Tenant Isolation: Elder B still has their open incident (untouched by Elder A clear)',
  );

  // Clean up Elder B incident
  const clearBRes = await fetch(`${BASE_URL}/incidents`, {
    method: 'DELETE',
    headers: { Authorization: `Bearer ${elderB.token}` },
  });
  assert(clearBRes.status === 200, 'Elder B successfully cleared their own incidents');

  console.log('\n================================================================');
  console.log(`🎉 ALL ${passedAssertions} ADVERSARIAL ASSERTIONS PASSED WITH ZERO FAILURES!`);
  console.log('================================================================\n');

  await pool.end();
}

runAdversarialProbes().catch((err) => {
  console.error('ADVERSARIAL PROBE RUN FAILED:', err);
  pool.end();
  process.exit(1);
});
