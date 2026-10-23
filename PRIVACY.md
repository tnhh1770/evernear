# Evernear Care (Carely) Privacy, Data Protection & Apple App Store Compliance

## 1. Privacy-by-Default Architecture

Evernear Care was built on the premise that family safety monitoring should never come at the expense of personal surveillance. Individuals are entitled to privacy within their own homes and lives.

### 1.1 What Evernear Care Explicitly NEVER Collects

1. **NO Background Camera or Photo/Video Recording**: Camera access (`NSCameraUsageDescription`) is requested **solely** when you actively scan a family QR pairing code. Evernear Care never records, stores, or uploads photos or videos.
2. **NO Microphone / Audio Recording**: The application never declares microphone permissions and never listens to ambient audio, conversations, or phone calls.
3. **NO Keystroke or Content Logging**: Evernear Care never inspects messages, contacts, browser history, or input keystrokes.
4. **NO Continuous Background GPS**: The app never runs a continuous background location tracking loop or breadcrumb history service.

### 1.2 Non-Medical & Non-Emergency Service Disclaimer (Apple Guideline 1.4)

* **Not a Medical Device**: Evernear Care is a lifestyle and family check-in coordination tool. It is **not** a medical device and does not diagnose, treat, cure, or prevent any medical condition. Risk scores (`0–100`) are operational check-in latency indicators, not clinical health assessments.
* **Not an Emergency Dispatch Service**: Evernear Care does **not** replace or contact public emergency services (`115`, `113`, `114`, `911`, `112`). In a medical or life-threatening emergency, always call local emergency services immediately.
* **OS & Network Limitations**: Alert and reminder delivery depends on network connectivity, battery level, and operating system background task scheduling (iOS `BGTaskScheduler` / APNs).

---

## 2. Permitted Signals & Data Minimization

| Data Point | Purpose | Frequency | Storage Lifetime |
| :--- | :--- | :--- | :--- |
| **App Lifecycle** (`APP_OPEN`, `APP_FOREGROUND`) | Passive confirmation of phone interaction | Only on app interaction | 30 days |
| **Battery State** (`CHARGER_CONNECTED`, `CHARGER_DISCONNECTED`) | Passive confirmation of routine activity | On plug/unplug | 30 days |
| **Heartbeat** | Verifies device has power and connectivity | Opportunistic (15-30m) | Overwritten in `devices` |
| **Single-Shot Location** | Family check-in & unacknowledged alert coordination | Only upon Check-In or Incident | 90 days |
| **Check-in Confirmations** | Proof of well-being | When user presses "Tôi vẫn ổn" / "I am OK" | 365 days |

---

## 3. Privacy-Gated Location Sharing

Location data is subject to strict database-level gating:
* **Explicit Consent**: `location_enabled` must be set to `TRUE` in `monitoring_configs` by the monitored individual.
* **Relationship Verification**: Location coordinates can only be retrieved by a guardian with an `ACCEPTED` relationship status.
* **Single-Shot Capture**: Location is requested only once when the user taps "Tôi vẫn ổn" ("I am OK") or when an incident escalates. Continuous background location services are prohibited.

---

## 4. User Rights, GDPR & Apple Guideline 5.1.1(v) Compliance

Evernear Care provides full self-service user rights under GDPR and Apple App Store Review Guidelines:

### 4.1 Right to Privacy & Pause
Users may temporarily suspend monitoring at any time (e.g., for 2 hours, 4 hours, or during scheduled sleep/quiet hours) by tapping "Tạm dừng giám sát". While paused, silence is not evaluated and no alerts are triggered.

### 4.2 Right to Data Portability & Access
Users can query `GET /api/v1/users/me` and `GET /api/v1/check-ins/history` to inspect all stored data related to their account.

### 4.3 Right to Erasure & Self-Service Account Deletion (`DELETE /api/v1/users/me`)
Users can permanently delete their account directly within the mobile app (`Settings -> Delete Account` or `Settings -> Privacy & Security -> Delete Account`) via `DELETE /api/v1/users/me`.
Upon invocation:
1. Personal identifiers (`email`, `display_name`, `phone_number`, `avatar_url`) are immediately scrubbed/anonymized with randomized cryptographic hashes, releasing all unique constraints.
2. Active JWT session caches are invalidated immediately.
3. Registered devices are deactivated (`is_active = FALSE`) and FCM/APNs push tokens are permanently stripped (`push_token = NULL`).
4. All monitoring relationships and evaluation schedules associated with the account are suspended (`status = 'SUSPENDED'`, `enabled = FALSE`).
5. The user account record is soft-removed (`deleted_at = NOW()`), preventing any further login or notification delivery.
