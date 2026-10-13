import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:workmanager/workmanager.dart';
import 'heartbeat_service.dart';
import 'sync_queue_service.dart';

/// Top-level callback dispatcher required for WorkManager native isolate
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();
    debugPrint('[WorkManager] Native worker invoked background task: $taskName');

    switch (taskName) {
      case BackgroundService.periodicHeartbeatTask:
      case Workmanager.iOSBackgroundTask:
        return await BackgroundService.executeBackgroundTask();
      default:
        debugPrint('[WorkManager] Unknown task name received: $taskName');
        return true;
    }
  });
}

class BackgroundService {
  static final BackgroundService _instance = BackgroundService._internal();
  factory BackgroundService() => _instance;
  BackgroundService._internal();

  static const String periodicHeartbeatTask = 'vn.carely.heartbeat.periodic';
  bool _isRegistered = false;

  bool get isRegistered => _isRegistered;

  /// Initialize WorkManager scheduler
  Future<void> initialize() async {
    if (_isRegistered) return;

    // WorkManager is only supported on Android & iOS.
    final isMobilePlatform =
        defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS;

    if (!isMobilePlatform) {
      debugPrint(
          '[BackgroundService] Non-mobile platform detected. Skipping WorkManager registration.');
      _isRegistered = true;
      return;
    }

    try {
      await Workmanager().initialize(
        callbackDispatcher,
      );

      // Register 15-minute periodic task (Android minimum)
      await Workmanager().registerPeriodicTask(
        periodicHeartbeatTask,
        periodicHeartbeatTask,
        frequency: const Duration(minutes: 15),
        constraints: Constraints(
          networkType: NetworkType.connected,
          requiresBatteryNotLow: true,
          requiresCharging: false,
          requiresDeviceIdle: false,
          requiresStorageNotLow: false,
        ),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
        backoffPolicy: BackoffPolicy.exponential,
        backoffPolicyDelay: const Duration(seconds: 30),
      );

      _isRegistered = true;
      debugPrint(
          '[BackgroundService] WorkManager 15-min periodic reachability heartbeat registered successfully');
    } catch (e) {
      debugPrint('[BackgroundService] WorkManager initialization error: $e');
    }
  }

  /// Execution logic when OS wakes the background worker
  static Future<bool> executeBackgroundTask() async {
    debugPrint('[BackgroundService] Executing background task routine...');
    try {
      // 1. Opportunistic reachability Heartbeat (Weight = 0.0)
      final heartbeatOk = await HeartbeatService().sendHeartbeat();
      debugPrint(
          '[BackgroundService] Heartbeat transmission result: $heartbeatOk');

      // 2. Opportunistic offline sync queue flush
      final flushResult = await SyncQueueService().flush();
      debugPrint(
          '[BackgroundService] Background sync queue flush result: $flushResult');

      return true;
    } catch (e) {
      debugPrint(
          '[BackgroundService] Background task encountered exception: $e');
      return false;
    }
  }
}
