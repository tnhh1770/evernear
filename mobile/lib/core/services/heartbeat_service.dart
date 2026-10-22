import 'dart:async';
import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../constants/api_endpoints.dart';
import '../network/api_client.dart';
import '../storage/local_storage.dart';
import 'sync_queue_service.dart';

/// Periodic opportunistic Heartbeat Service.
/// 
/// STRICT AXIOM:
/// Heartbeat only informs the server that the device is online and network is reachable.
/// Heartbeat weight is ALWAYS 0.0 and NEVER updates lastMeaningfulActivityAt.
class HeartbeatService {
  static final HeartbeatService _instance = HeartbeatService._internal();
  factory HeartbeatService() => _instance;
  HeartbeatService._internal();

  final ApiClient _apiClient = ApiClient();
  final Battery _battery = Battery();
  Timer? _timer;
  bool _isRunning = false;
  DateTime? _lastHeartbeatSentAt;

  bool get isRunning => _isRunning;
  DateTime? get lastHeartbeatSentAt => _lastHeartbeatSentAt;

  void start({Duration interval = const Duration(minutes: 15)}) {
    if (_isRunning) return;
    _isRunning = true;
    sendHeartbeat(); // opportunistic first ping (skips if recent heartbeat < 12m)
    _timer = Timer.periodic(interval, (_) => sendHeartbeat());
    debugPrint('[HeartbeatService] Started periodic heartbeat every ${interval.inMinutes} minutes');
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _isRunning = false;
    debugPrint('[HeartbeatService] Stopped periodic heartbeat');
  }

  Future<bool> sendHeartbeat({bool force = false}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
    } catch (_) {}

    final token = await LocalStorage.getAccessToken();
    final deviceId = await LocalStorage.getDeviceId();
    if (token == null || deviceId == null) {
      debugPrint('[HeartbeatService] Skipped: No authenticated session or device ID');
      return false;
    }

    // Coordinate with WorkManager and recent pings to prevent back-to-back radio wakeups
    final now = DateTime.now();
    if (!force) {
      final lastAt = _lastHeartbeatSentAt ?? await LocalStorage.getLastHeartbeatAt();
      if (lastAt != null && now.difference(lastAt).inMinutes < 12) {
        debugPrint(
            '[HeartbeatService] Skipped: Recent heartbeat was sent ${now.difference(lastAt).inMinutes} min ago');
        return true;
      }
    }

    int? batteryLevel;
    bool? isCharging;
    try {
      batteryLevel = await _battery.batteryLevel;
      final state = await _battery.batteryState;
      isCharging = (state == BatteryState.charging || state == BatteryState.full);
    } catch (e) {
      debugPrint('[HeartbeatService] Battery read error: $e');
    }

    final deviceUid = await LocalStorage.getOrCreateDeviceUid();
    final payload = {
      'deviceId': deviceId,
      'deviceUid': deviceUid,
      'occurredAt': DateTime.now().toUtc().toIso8601String(),
      if (batteryLevel != null) 'batteryLevel': batteryLevel,
      if (isCharging != null) 'isCharging': isCharging,
    };

    try {
      final response = await _apiClient.dio.post(
        ApiEndpoints.heartbeat,
        data: payload,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        _lastHeartbeatSentAt = now;
        await LocalStorage.saveLastHeartbeatAt(now);
        debugPrint('[HeartbeatService] Heartbeat sent successfully (status: ${response.statusCode})');
        return true;
      }
      return false;
    } catch (e) {
      if (SyncQueueService.isNetworkOrOfflineError(e)) {
        _lastHeartbeatSentAt = now;
        await LocalStorage.saveLastHeartbeatAt(now);
        final hbId = const Uuid().v4();
        await SyncQueueService().enqueue(
          id: hbId,
          type: SyncItemType.heartbeat,
          endpoint: ApiEndpoints.heartbeat,
          payload: payload,
        );
      }
      debugPrint('[HeartbeatService] Failed to send heartbeat (offline / opportunistic): $e');
      return false;
    }
  }
}
