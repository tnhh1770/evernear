# Carely Mobile Background Execution & OS Limitations

## 1. The Mobile Operating System Reality

A safety system that assumes a smartphone application will run code predictably in the background is prone to critical failure. Both Google (Android) and Apple (iOS) continuously tighten background execution limits to protect battery life and user privacy.

### 1.1 Android Background Restrictions

1. **Doze Mode (Android 6.0+)**:
   * When a device is unplugged and stationary with the screen off, Android enters Doze.
   * Network access is disabled, wake locks are ignored, and standard alarms are deferred to periodic "maintenance windows".
   * In deep Doze, maintenance windows may occur hours apart.
2. **App Standby Buckets (Android 9.0+)**:
   * Android assigns apps to buckets (`Active`, `Working Set`, `Frequent`, `Rare`, `Restricted`) based on how recently and frequently the user opens them.
   * If a user does not open Carely daily, Android moves the app to `Frequent` or `Rare`, restricting `JobScheduler` and `WorkManager` tasks to only a few executions per day.
3. **OEM Aggressive Process Termination ("DontKillMyApp")**:
   * Manufacturers such as Xiaomi (MIUI/HyperOS), Huawei (EMUI/HarmonyOS), Samsung (OneUI Sleeping Apps), and BBK (Oppo/Vivo) implement non-standard proprietary battery optimization daemons.
   * These daemons routinely kill background processes, ignore `WorkManager` requests, and prevent autostart upon boot unless the user manually toggles complex, hidden OS settings.
4. **Exact Alarm & Foreground Service Restrictions (Android 12 – 15)**:
   * `SCHEDULE_EXACT_ALARM` permissions require explicit user approval and are strictly reviewed on the Google Play Store.
   * Android 14+ requires specific foreground service types and revokes long-running services without active notifications.

### 1.2 iOS Background Execution Restrictions

1. **Zero Timing Guarantees**:
   * iOS `BackgroundTasks` framework (`BGAppRefreshTask`, `BGProcessingTask`) provides **no deterministic schedule**.
   * Apple's machine learning model schedules background execution based on when it predicts the user will unlock or use the phone.
2. **30-Second Execution Boundary**:
   * Background tasks receive at most ~30 seconds of CPU time before the OS suspends the process. Failure to call `setTaskCompleted` within this budget results in iOS terminating the process.
3. **Low Power Mode & Battery Health**:
   * If the iPhone enters Low Power Mode, Background App Refresh is disabled globally.

---

## 2. Carely's Design Mitigation: Opportunistic Execution

Because background reliability cannot be guaranteed by the mobile client, Carely implements the following core patterns:

### 2.1 Server Authoritative Clock
The Carely backend server maintains the official clock. The server does not wait for a "timeout signal" from the phone. If the phone goes silent (due to battery death, network loss, or OS suspension), the server independently triggers the check-in request and escalation tree.

### 2.2 Passive Behavioral Event Capture
Rather than running expensive background location or polling loops, Carely registers lightweight lifecycle observers:
* **App Foregrounding**: `WidgetsBindingObserver.didChangeAppLifecycleState` captures when the user opens or switches to the app.
* **Charging State Changes**: `Battery.onBatteryStateChanged` listens to hardware power cable plug/unplug events.
* **Cold Boot Ingestion**: Unsent cached events are flushed immediately when the app returns to the foreground.

### 2.3 Heartbeat Reachability (Weight = 0.0)
Heartbeat pings are scheduled via `WorkManager` (Android) and `BGAppRefreshTask` (iOS) with the constraint `NetworkType.CONNECTED`:
* If the task executes, it transmits battery level and network reachability.
* If the OS defers the task, no false positive activity is recorded.
* Heartbeats never refresh the inactivity threshold clock.

---

## 3. User Guidance & Battery Optimization Settings

Carely provides clean, transparent guidance within the application settings instructing users how to exclude Carely from aggressive OEM task killers:
1. **Samsung**: *Settings -> Apps -> Carely -> Battery -> Unrestricted*.
2. **Xiaomi / Redmi**: *Settings -> Apps -> Manage Apps -> Carely -> Autostart (Enable) -> Battery saver (No restrictions)*.
3. **Pixel / Stock Android**: *Settings -> Apps -> Carely -> App battery usage -> Allow background usage (Unrestricted)*.
4. **iOS**: *Settings -> General -> Background App Refresh -> Enable for Carely*.
