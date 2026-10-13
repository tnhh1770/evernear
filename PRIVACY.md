# Carely Privacy, Data Protection & GDPR Compliance

## 1. Privacy-by-Default Architecture

Carely was built on the premise that safety monitoring should not come at the expense of surveillance. Individuals are entitled to privacy within their own homes and lives.

### 1.1 What Carely Explicitly NEVER Collects

1. **NO Camera Access**: The application does not declare camera permissions and never captures images or video.
2. **NO Microphone / Audio Recording**: The application does not listen to ambient audio, conversations, or calls.
3. **NO Keystroke or Content Logging**: Carely never inspects messages, browser history, or input keystrokes.
4. **NO Continuous Background GPS**: The app never runs a background location tracking loop or location history breadcrumb service.

---

## 2. Permitted Signals & Data Minimization

| Data Point | Purpose | Frequency | Storage Lifetime |
| :--- | :--- | :--- | :--- |
| **App Lifecycle** (`APP_OPEN`, `APP_FOREGROUND`) | Passive confirmation of phone interaction | Only on app interaction | 30 days (Auto-purged) |
| **Battery State** (`CHARGING_STARTED`, `CHARGING_STOPPED`) | Passive confirmation of routine activity | On plug/unplug | 30 days (Auto-purged) |
| **Heartbeat** | Verifies device has power and connectivity | Opportunistic (15-30m) | Overwritten in `devices` |
| **Single-Shot Location** | Emergency rescue coordination | Only upon Check-In or Incident | 90 days |
| **Check-in Confirmations** | Proof of well-being | When user presses "Tôi vẫn ổn"| 365 days |

---

## 3. Privacy-Gated Location Sharing

Location data is subject to strict, cryptographic and database-level gating:
* **Explicit Consent**: `location_enabled` must be set to `TRUE` in `monitoring_configs` by the monitored individual.
* **Relationship Verification**: Location coordinates can only be retrieved by a guardian with an `ACCEPTED` relationship status.
* **Single-Shot Capture**: Location is requested only once when the user taps "Tôi vẫn ổn" or when an incident escalates. Continuous background location services are prohibited.

---

## 4. User Rights & GDPR Compliance

Carely provides full self-service user rights under European GDPR and international privacy regulations:

### 4.1 Right to Privacy & Pause
Users may temporarily suspend monitoring at any time (e.g., for 2 hours, 4 hours, or until a specific time) by tapping "Tạm dừng giám sát". While paused, silence is not evaluated and no alerts are triggered.

### 4.2 Right to Data Portability & Access
Users can query `GET /api/v1/users/me` and `GET /api/v1/check-ins/history` to inspect all stored data related to their account.

### 4.3 Right to Erasure ("Right to Be Forgotten")
Users can initiate account deletion via `DELETE /api/v1/users/me`.
Upon invocation:
1. `is_active` is set to `FALSE` (immediate login and token invalidation).
2. FCM tokens and device identifiers are stripped immediately.
3. Personal identifiers (`full_name`, `phone`, `email`) are replaced with randomized cryptographic hashes.
4. Raw activities and locations older than retention windows are permanently wiped by database cleanup jobs.
