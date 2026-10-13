# Carely RESTful API Reference

## 1. Conventions & Global Headers

* **Base URL**: `http://<host>:3000/api/v1`
* **Content-Type**: `application/json`
* **Authorization**: `Bearer <JWT_ACCESS_TOKEN>` (for all secured endpoints)
* **Idempotency**: Clients should supply `X-Event-ID: <UUID>` header for `POST`/`PUT`/`PATCH` requests. Duplicate requests with the same `eventId` or `X-Event-ID` return the previously processed response without creating duplicate entities or triggering duplicate side-effects.

---

## 2. Authentication Endpoints

### 2.1 Register
`POST /api/v1/auth/register`

**Request Body**:
```json
{
  "email": "user@example.com",
  "password": "Password123!",
  "fullName": "Nguyễn Văn A",
  "phone": "+84901234567",
  "timezone": "Asia/Ho_Chi_Minh"
}
```

**Response (`201 Created`)**:
```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "email": "user@example.com",
  "fullName": "Nguyễn Văn A",
  "phone": "+84901234567",
  "timezone": "Asia/Ho_Chi_Minh",
  "isActive": true,
  "createdAt": "2026-10-06T09:00:00.000Z"
}
```

---

### 2.2 Login
`POST /api/v1/auth/login`

**Request Body**:
```json
{
  "email": "user@example.com",
  "password": "Password123!"
}
```

**Response (`200 OK`)**:
```json
{
  "accessToken": "eyJhbGciOi...",
  "refreshToken": "eyJhbGciOi...",
  "user": {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "email": "user@example.com",
    "fullName": "Nguyễn Văn A",
    "phone": "+84901234567"
  }
}
```

---

### 2.3 Refresh Token
`POST /api/v1/auth/refresh`

**Request Body**:
```json
{
  "refreshToken": "eyJhbGciOi..."
}
```

**Response (`200 OK`)**:
```json
{
  "accessToken": "eyJhbGciOi...",
  "refreshToken": "eyJhbGciOi..."
}
```

---

## 3. Device Management Endpoints

### 3.1 Register / Update Device
`POST /api/v1/devices`

Registers a mobile hardware profile and associates FCM push credentials.

**Request Body**:
```json
{
  "platform": "ANDROID",
  "deviceModel": "Pixel 8 Pro",
  "osVersion": "Android 14",
  "appVersion": "1.0.0",
  "fcmToken": "fcm_token_xyz..."
}
```

**Response (`201 Created`)**:
```json
{
  "id": "770e8400-e29b-41d4-a716-446655440001",
  "userId": "550e8400-e29b-41d4-a716-446655440000",
  "platform": "ANDROID",
  "deviceModel": "Pixel 8 Pro",
  "isActive": true
}
```

---

## 4. Activities & Heartbeat Endpoints

### 4.1 Device Heartbeat (Weight = 0.0)
`POST /api/v1/activities/heartbeat`

Informs the server that the hardware is online and reachable. **Does NOT update `lastMeaningfulActivityAt`**.

**Request Body**:
```json
{
  "deviceId": "770e8400-e29b-41d4-a716-446655440001",
  "batteryLevel": 85,
  "isCharging": false
}
```

**Response (`200 OK`)**:
```json
{
  "success": true,
  "lastHeartbeatAt": "2026-10-06T09:15:00.000Z",
  "weight": 0.0,
  "message": "Heartbeat recorded. Device connectivity confirmed."
}
```

---

### 4.2 Ingest Activity (Passive Signal)
`POST /api/v1/activities`

Ingests a passive activity signal (e.g. app open, charging state change).

**Request Body**:
```json
{
  "eventId": "a1b2c3d4-e5f6-7a8b-9c0d-1e2f3a4b5c6d",
  "deviceId": "770e8400-e29b-41d4-a716-446655440001",
  "activityType": "APP_FOREGROUND",
  "confidenceScore": 0.85,
  "occurredAt": "2026-10-06T09:20:00.000Z",
  "metadata": {
    "source": "lifecycle_listener"
  }
}
```

**Response (`201 Created` or `200 OK` on duplicate)**:
```json
{
  "id": "880e8400-e29b-41d4-a716-446655440002",
  "eventId": "a1b2c3d4-e5f6-7a8b-9c0d-1e2f3a4b5c6d",
  "activityType": "APP_FOREGROUND",
  "confidenceScore": 0.85,
  "isMeaningful": true,
  "occurredAt": "2026-10-06T09:20:00.000Z"
}
```

---

## 5. Check-Ins ("Tôi vẫn ổn")

### 5.1 Submit Check-In
`POST /api/v1/check-ins`

Explicit user safety confirmation. Resets the monitoring state machine to `ACTIVE` and resolves pending incidents.

**Request Body**:
```json
{
  "eventId": "b2c3d4e5-f6a7-8b9c-0d1e-2f3a4b5c6d7e",
  "deviceId": "770e8400-e29b-41d4-a716-446655440001",
  "occurredAt": "2026-10-06T09:30:00.000Z",
  "batteryLevel": 82,
  "note": "Tôi vẫn ổn, đang tưới cây ngoài vườn.",
  "location": {
    "latitude": 10.762622,
    "longitude": 106.660172
  }
}
```

**Response (`201 Created`)**:
```json
{
  "id": "990e8400-e29b-41d4-a716-446655440003",
  "userId": "550e8400-e29b-41d4-a716-446655440000",
  "occurredAt": "2026-10-06T09:30:00.000Z",
  "batteryLevel": 82,
  "note": "Tôi vẫn ổn, đang tưới cây ngoài vườn.",
  "stateResetTo": "ACTIVE",
  "incidentsAutoResolved": 1
}
```

---

## 6. Monitoring & Relationships

### 6.1 List Relationships
`GET /api/v1/monitoring/relationships`

Returns all active relationships where the current user is either the Monitored individual or the Guardian.

**Response (`200 OK`)**:
```json
[
  {
    "id": "rel-001",
    "monitoredUserId": "user-parent",
    "monitorUserId": "user-child",
    "status": "ACCEPTED",
    "label": "Mẹ",
    "monitoredUser": {
      "id": "user-parent",
      "fullName": "Nguyễn Thị Mẹ"
    },
    "config": {
      "currentState": "ACTIVE",
      "inactivityThresholdMinutes": 180,
      "checkInGracePeriodMinutes": 30,
      "lastMeaningfulActivityAt": "2026-10-06T09:20:00.000Z",
      "isPaused": false
    }
  }
]
```

### 6.2 Pause Monitoring
`POST /api/v1/monitoring/configs/:relId/pause`

**Request Body**:
```json
{
  "durationMinutes": 120
}
```

### 6.3 Resume Monitoring
`POST /api/v1/monitoring/configs/:relId/resume`

---

## 7. Incidents Endpoints

### 7.1 List Incidents
`GET /api/v1/incidents?status=TRIGGERED`

### 7.2 Acknowledge Incident (Guardian)
`POST /api/v1/incidents/:id/acknowledge`

Acknowledges receipt by guardian, moving state to `ACKNOWLEDGED`.

### 7.3 Resolve Incident
`POST /api/v1/incidents/:id/resolve`

**Request Body**:
```json
{
  "status": "RESOLVED",
  "resolutionNote": "Đã gọi điện thoại kiểm tra, người thân đang ngủ trưa."
}
```

---

## 8. Health Check
`GET /api/v1/health`

**Response (`200 OK`)**:
```json
{
  "status": "ok",
  "timestamp": "2026-10-06T09:35:00.000Z",
  "services": {
    "database": "connected",
    "redis": "connected"
  }
}
```
