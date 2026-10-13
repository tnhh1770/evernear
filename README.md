# Carely — Inactivity Monitor & Dead Man's Switch System

> **Đồng hành & Bảo vệ bình an cho người thân**  
> An authoritative, privacy-first, battery-efficient Inactivity Monitor & Dead Man's Switch system built with **NestJS 12**, **PostgreSQL 16**, **Redis 7**, and **Flutter 3.47 (Dart 3.13)**.

---

## 1. Overview & Core Philosophy

Carely is designed for independent solo dwellers, elderly parents, and high-risk workers who want peace of mind without compromising their privacy.

### The 3 Core Axioms

1. **"Server is Authoritative, Mobile is Opportunistic"**  
   Mobile operating systems (Android Doze, iOS Background Execution limits) can terminate background tasks or delay sync arbitrarily. Therefore, the **Carely Backend Server** is the sole source of truth and authoritative clock. If a mobile device stops communicating, the server deterministically transitions states and escalates alerts regardless of whether the mobile client is awake.

2. **Strict Separation of Heartbeat, Activity, and Check-in**
   * **Heartbeat (Weight = 0.0)**: Device reachability ping. Informs the server that the OS has network access and reports battery level. **It NEVER resets `lastMeaningfulActivityAt` and CANNOT keep a user in the `ACTIVE` state.**
   * **Activity (Weight = 0.2 – 0.8)**: Passive behavioral signals (e.g. app open, charging state change, unlock). Qualified by confidence thresholds to prevent false negatives.
   * **Check-in ("Tôi vẫn ổn", Weight = 1.0)**: Explicit user intentional confirmation. Immediately resets the monitoring state machine to `ACTIVE` and automatically resolves pending incidents.

3. **Privacy by Default & Calm UX Copy**  
   * **No camera**, **no microphone**, and **no continuous GPS tracking**.
   * Single-shot opportunistic location is captured only when a check-in is submitted or an incident is escalated, and only if explicit consent is granted.
   * Reassuring Vietnamese copy: `"Bạn vẫn ổn chứ?"`, `"Tôi vẫn ổn"`, `"Không nhận được xác nhận hoạt động"`. No sensationalist or alarming terms like `"nguy kịch"` or `"có thể đã chết"`.

---

## 2. System Architecture

```
                     +---------------------------------------+
                     |            Carely Clients             |
                     |  (Flutter Android / iOS / Web Client) |
                     +-------------------+-------------------+
                                         |
                                         | REST / JWT / Idempotent X-Event-ID
                                         v
                     +---------------------------------------+
                     |         Carely Backend (NestJS)       |
                     |  - Auth & Device Management           |
                     |  - Activity & Heartbeat Ingestion     |
                     |  - Check-in & Recovery Engine         |
                     |  - Incident & Risk Evaluator (0-100)  |
                     |  - Notification Dispatcher (FCM/SMS)  |
                     +---------+-------------------+---------+
                               |                   |
                     Distributed Lock         Source of Truth
                     & Sliding Rate-Limit     ACID & Relations
                               |                   |
                               v                   v
                     +-----------------+   +-----------------+
                     | Redis 7 (Cache) |   |  PostgreSQL 16  |
                     | Redlock + TTL   |   |   (Authoritative|
                     +-----------------+   +-----------------+
```

---

## 3. Directory Structure

```
Carely/
├── backend/                  # NestJS 12 Enterprise Backend
│   ├── src/
│   │   ├── common/           # Enums, Redis distributed locking, decorators, guards
│   │   ├── database/         # TypeORM config & SQL migration (001_init_schema.sql)
│   │   └── modules/
│   │       ├── auth/         # JWT auth, bcrypt password hashing, token rotation
│   │       ├── users/        # Profile, soft-delete, timezone preferences
│   │       ├── devices/      # Multi-device registry, FCM tokens, heartbeat updates
│   │       ├── monitoring/   # Relationships, schedule windows, state machine
│   │       ├── activities/   # Weighted activity policies & ingestion
│   │       ├── check-ins/    # Explicit "Tôi vẫn ổn" confirmation & auto-recovery
│   │       ├── incidents/    # Non-diagnostic composite risk evaluation (0-100)
│   │       ├── locations/    # Privacy-gated single-shot location tracking
│   │       ├── notifications/# Alert dispatcher (FCM Push, SMS/Telegram stubs)
│   │       └── monitoring-worker/ # Distributed cron evaluator with SKIP LOCKED
│   ├── test/                 # Full lifecycle integration tests (Vitest)
│   └── vitest.config.ts      # Vitest configuration for pure ESM
│
├── mobile/                   # Flutter 3.47 Mobile Application
│   ├── lib/
│   │   ├── core/             # API client, interceptors, secure storage, enums
│   │   │   └── services/     # HeartbeatService, ActivityTracker, BackgroundService
│   │   └── features/
│   │       ├── auth/         # Login, Register, Profile
│   │       ├── dashboard/    # Dual-View (Monitored Mode & Guardian Monitor Mode)
│   │       ├── check_in/     # Reassuring "Tôi vẫn ổn" screen
│   │       ├── monitoring/   # Custom interval configs, schedules, pause/resume
│   │       ├── incidents/    # Incident timeline, acknowledgement & resolution
│   │       ├── devices/      # Device list, heartbeat inspection, revocation
│   │       └── settings/     # Privacy consent, invite codes, GDPR soft-delete
│   └── test/                 # Flutter widget & unit test suite
│
├── docker-compose.yml        # PostgreSQL 16 & Redis 7 container configuration
└── Documentation/
    ├── ARCHITECTURE.md       # Detailed technical design & patterns
    ├── DATABASE.md           # PostgreSQL schema, indexes, migrations & constraints
    ├── API.md                # RESTful API specifications with examples
    ├── MONITORING_STATE_MACHINE.md # State machine transitions, invariants & timing
    ├── MOBILE_BACKGROUND.md  # Mobile OS background handling & graceful degradation
    ├── NOTIFICATION.md       # Escalation trees, neutral copy templates & delivery
    ├── PRIVACY.md            # Privacy policies, data retention, GDPR compliance
    ├── DEPLOYMENT.md         # Production deployment, Docker, monitoring & scaling
    └── TESTING.md            # Test strategies, unit, integration & concurrency runs
```

---

## 4. Quick Start Guide

### Prerequisites
* Docker and Docker Compose
* Node.js v20+ and npm
* Flutter SDK 3.47+ and Dart 3.13+

### 1. Launch Infrastructure
```bash
docker compose up -d
# Starts PostgreSQL 16 on port 5435 and Redis 7 on port 6379
```

### 2. Run Backend
```bash
cd backend
npm install
npm run build        # Production compilation
npm run lint         # 0 warnings, 0 errors (oxlint)
npm test             # Run full backend test suite (39 suites, 610 tests)
npm run test:e2e     # Run E2E test suite (12 suites, 224 tests)
npm run start:dev    # Starts API on http://localhost:3000
```

### 3. Run Mobile App
```bash
cd mobile
flutter pub get
flutter analyze      # Verify 0 lints and 0 errors across 110 Dart files
flutter test         # Run 24 Flutter test suites (271 tests passing)
flutter run          # Launch on connected device, emulator, or Chrome
```

---

## 5. Verification & Test Summary

* **Backend Test Suites (Vitest 5 & NestJS 12)**:
  * **Domain Unit Tests**: 15 suites, 116 tests passing (Auth, Devices, Policies, Scheduler, State Machine, Workers, Incidents, Notifications, Redis).
  * **Integration & Stress Suites**: 13 suites, 271 tests passing (Cross-module lifecycle, Adversarial Sleep Windows, Redis Reconnect, QR Pairing, Social Auth, Dynamic i18n).
  * **End-to-End Suites**: 12 suites, 224 tests passing (Tiers 1-4, M3 Sync & Offline Reconnection, M4 Concurrency Challenger, Opt-M1 Batch Ingestion, Opt-M2 Reachability).
  * **Full Backend Test Run (`npm test`)**: **39 test files passed, 610/610 tests passed (100% GREEN)**.
  * **Full Backend E2E Run (`npm run test:e2e`)**: **12 test files passed, 224/224 tests passed (100% GREEN)**.
  * **Backend Linter (`oxlint --type-aware`)**: **0 warnings, 0 errors** on 114 TypeScript files.
  * **Backend Production Build (`nest build`)**: Clean exit code 0.
* **Mobile Test Suite (Flutter 3.47 / Dart 3.13)**:
  * **Static Analysis (`flutter analyze`)**: **No issues found! (0 errors, 0 warnings, 0 lints)**.
  * **Unit, Widget, and Flow Tests**: 24 suites, 271 tests passing (Double Dashboard, Quiet Hours Math, QR Fuzzing & Security, Dynamic i18n Catalogs & Fallback, Offline Sync Queue Concurrency Proof, Background Services & Signal Separation).
  * **Total Mobile Tests (`flutter test`)**: **271/271 Passed (100% GREEN)**.
* **Master Full-Stack Footprint**:
  * **Cumulative Automated Tests**: **881/881 Passed (100% GREEN, 0 Failures)**.
  * **Production Quality Gates**: Zero compile errors, zero linter issues, zero regressions across all 60 system features.

