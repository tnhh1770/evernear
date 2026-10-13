import 'dart:async';
import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:uuid/uuid.dart';
import '../constants/api_endpoints.dart';
import '../models/enums.dart';
import '../network/api_client.dart';
import '../storage/local_storage.dart';
import 'sync_queue_service.dart';

/// Tracks passive user activity signals opportunistically:
/// - App Open / Foreground
/// - Battery Charging Connected / Disconnected
///
/// Sends meaningful activity signals to backend.
class ActivityTrackerService with WidgetsBindingObserver {
  static final ActivityTrackerService _instance = ActivityTrackerService._internal();
  factory ActivityTrackerService() => _instance;
  ActivityTrackerService._internal();

  final ApiClient _apiClient = ApiClient();
  final Battery _battery = Battery();
  static const _uuid = Uuid();

  StreamSubscription<BatteryState>? _batterySubscription;
  DateTime? _lastDispatchedActivityAt;
  DateTime? _lastChargerActivityAt;
  bool _initialized = false;

  DateTime? get lastDispatchedActivityAt => _lastDispatchedActivityAt;
  DateTime? get lastChargerActivityAt => _lastChargerActivityAt;

  void initialize() {
    if (_initialized) return;
    _initialized = true;

    WidgetsBinding.instance.addObserver(this);

    // Track initial app open
    recordActivity(
      type: ActivityType.APP_OPEN,
      confidenceScore: 0.9,
      metadata: {'trigger': 'cold_boot'},
    );

    // Listen to charging changes
    try {
      _batterySubscription = _battery.onBatteryStateChanged.listen((state) {
        if (state == BatteryState.charging) {
          recordActivity(
            type: ActivityType.CHARGER_CONNECTED,
            confidenceScore: 0.7,
            metadata: {'source': 'battery_listener'},
          );
        } else if (state == BatteryState.discharging) {
          recordActivity(
            type: ActivityType.CHARGER_DISCONNECTED,
            confidenceScore: 0.6,
            metadata: {'source': 'battery_listener'},
          );
        }
      }, onError: (e) {
        debugPrint('[ActivityTracker] Battery stream error: $e');
      });
    } catch (e) {
      debugPrint('[ActivityTracker] Battery listener not supported or errored: $e');
    }
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _batterySubscription?.cancel();
    _initialized = false;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      recordActivity(
        type: ActivityType.APP_FOREGROUND,
        confidenceScore: 0.85,
        metadata: {'lifecycle': 'resumed'},
      );
    }
  }

  Future<bool> recordActivity({
    required ActivityType type,
    double confidenceScore = 0.8,
    Map<String, dynamic>? metadata,
  }) async {
    final token = await LocalStorage.getAccessToken();
    final deviceId = await LocalStorage.getDeviceId();
    if (token == null || deviceId == null) {
      debugPrint('[ActivityTracker] Skipped: No authenticated session');
      return false;
    }

    final now = DateTime.now();
    final isChargerEvent = type == ActivityType.CHARGER_CONNECTED ||
        type == ActivityType.CHARGER_DISCONNECTED;

    // Debounce charger connect/disconnect with 60s window to prevent modem radio flapping
    if (isChargerEvent &&
        _lastChargerActivityAt != null &&
        now.difference(_lastChargerActivityAt!).inSeconds < 60) {
      debugPrint('[ActivityTracker] Throttling frequent charger event (60s debounce)');
      return false;
    }

    // Rate-limit consecutive duplicate events within 10 seconds for general activities
    if (!isChargerEvent &&
        _lastDispatchedActivityAt != null &&
        now.difference(_lastDispatchedActivityAt!).inSeconds < 10) {
      debugPrint('[ActivityTracker] Throttling frequent activity dispatch');
      return false;
    }

    final eventId = _uuid.v4();
    final payload = {
      'eventId': eventId,
      'deviceId': deviceId,
      'type': type.toBackendString(),
      'confidence': confidenceScore,
      'occurredAt': now.toUtc().toIso8601String(),
      'source': 'MOBILE',
      if (metadata != null) 'metadata': metadata,
    };

    try {
      final response = await _apiClient.dio.post(
        ApiEndpoints.activities,
        data: payload,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        _lastDispatchedActivityAt = now;
        if (isChargerEvent) _lastChargerActivityAt = now;
        debugPrint('[ActivityTracker] Activity ${type.name} recorded (id: $eventId)');
        return true;
      }
      return false;
    } catch (e) {
      if (SyncQueueService.isNetworkOrOfflineError(e)) {
        _lastDispatchedActivityAt = now;
        if (isChargerEvent) _lastChargerActivityAt = now;
        await SyncQueueService().enqueue(
          id: eventId,
          type: SyncItemType.activity,
          endpoint: ApiEndpoints.activities,
          payload: payload,
        );
        debugPrint('[ActivityTracker] Activity ${type.name} enqueued offline (id: $eventId)');
        return true;
      }
      debugPrint('[ActivityTracker] Failed to record activity (opportunistic): $e');
      return false;
    }
  }
}
