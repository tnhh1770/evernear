import 'dart:async';
import 'dart:convert';
// ignore: depend_on_referenced_packages
import 'package:connectivity_plus_platform_interface/connectivity_plus_platform_interface.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/constants/api_endpoints.dart';
import 'package:mobile/core/models/enums.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/core/services/activity_tracker_service.dart';
import 'package:mobile/core/services/background_service.dart';
import 'package:mobile/core/services/heartbeat_service.dart';
import 'package:mobile/core/services/sync_queue_service.dart';
import 'package:mobile/core/storage/local_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockConnectivityPlatform extends ConnectivityPlatform {
  final StreamController<List<ConnectivityResult>> _controller =
      StreamController<List<ConnectivityResult>>.broadcast();
  List<ConnectivityResult> currentStatus = [ConnectivityResult.wifi];

  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged => _controller.stream;

  @override
  Future<List<ConnectivityResult>> checkConnectivity() async => currentStatus;

  void emit(List<ConnectivityResult> results) {
    currentStatus = results;
    _controller.add(results);
  }

  void dispose() {
    _controller.close();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ApiClient apiClient;
  InterceptorsWrapper? activeInterceptor;
  late MockConnectivityPlatform mockConnectivity;
  ConnectivityPlatform? originalConnectivityPlatform;

  void installInterceptor({
    FutureOr<Response?> Function(RequestOptions options)? onResolve,
    FutureOr<DioException?> Function(RequestOptions options)? onReject,
  }) {
    if (activeInterceptor != null) {
      apiClient.dio.interceptors.remove(activeInterceptor);
    }
    activeInterceptor = InterceptorsWrapper(
      onRequest: (options, handler) async {
        if (onReject != null) {
          final err = await onReject(options);
          if (err != null) return handler.reject(err);
        }
        if (onResolve != null) {
          final res = await onResolve(options);
          if (res != null) return handler.resolve(res);
        }
        return handler.next(options);
      },
    );
    apiClient.dio.interceptors.insert(0, activeInterceptor!);
  }

  const MethodChannel connectivityChannel =
      MethodChannel('dev.fluttercommunity.plus/connectivity');

  setUp(() async {
    originalConnectivityPlatform = ConnectivityPlatform.instance;
    mockConnectivity = MockConnectivityPlatform();
    ConnectivityPlatform.instance = mockConnectivity;

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(connectivityChannel,
            (MethodCall methodCall) async {
      if (methodCall.method == 'check') {
        return ['wifi'];
      }
      return null;
    });

    SharedPreferences.setMockInitialValues({
      'carely_user_id': 'user-challenger-m3',
      'carely_access_token': 'jwt-m3-token-adversarial',
      'carely_device_id': 'device-m3-adv-1',
      'carely_device_uid': 'device-m3-uid-1',
    });

    apiClient = ApiClient();
    final queue = SyncQueueService();
    await queue.clearQueue();
  });

  tearDown(() async {
    if (activeInterceptor != null) {
      apiClient.dio.interceptors.remove(activeInterceptor);
      activeInterceptor = null;
    }
    SyncQueueService().stopListeningToNetwork();
    await SyncQueueService().clearQueue();
    mockConnectivity.dispose();
    if (originalConnectivityPlatform != null) {
      ConnectivityPlatform.instance = originalConnectivityPlatform!;
    }
  });

  group('Opt-M3 Challenger: 50 Offline Heartbeats Enqueue & Coalescing', () {
    test('1.1 Enqueueing 50 consecutive offline heartbeats coalesces to <= 1 item in SharedPreferences', () async {
      final queueService = SyncQueueService();
      await queueService.clearQueue();

      // Enqueue 50 heartbeats sequentially with distinct timestamps and seq numbers
      for (int i = 1; i <= 50; i++) {
        await queueService.enqueue(
          id: 'hb-adv-$i',
          type: SyncItemType.heartbeat,
          endpoint: ApiEndpoints.heartbeat,
          payload: {
            'deviceId': 'device-m3-adv-1',
            'seq': i,
            'occurredAt': '2026-10-12T${10 + (i ~/ 60)}:${(i % 60).toString().padLeft(2, '0')}:00Z',
            'batteryLevel': 100 - i,
          },
        );
      }

      // Empirical check: queue length must be exactly 1
      final len = await queueService.getQueueLength();
      expect(len, 1,
          reason: '50 offline heartbeats must coalesce to at most 1 item in queue');

      // Direct inspection of SharedPreferences storage
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('carely_offline_sync_queue');
      expect(raw, isNotNull);

      final List items = jsonDecode(raw!) as List;
      expect(items.length, 1,
          reason: 'SharedPreferences list must have exactly 1 heartbeat entry');

      final singleItem = items.first as Map<String, dynamic>;
      expect(singleItem['id'], 'hb-adv-50',
          reason: 'Coalesced item must be the latest heartbeat (seq 50)');
      expect(singleItem['type'], 'heartbeat');
      expect(singleItem['payload']['seq'], 50);
      expect(singleItem['payload']['batteryLevel'], 50);

      // Verify absence of stale heartbeats
      expect(raw, isNot(contains('"hb-adv-1"')));
      expect(raw, isNot(contains('"hb-adv-25"')));
      expect(raw, isNot(contains('"hb-adv-49"')));

      // Storage size verification: compact bounded size (< 400 bytes vs ~12KB if 50 items)
      expect(raw.length, lessThan(400),
          reason: 'Single coalesced heartbeat JSON must be compact (< 400 bytes)');
    });

    test('1.2 Mixed Queue Stress: 50 heartbeats interleaved with activities & check-ins do not drop meaningful signals', () async {
      final queueService = SyncQueueService();
      await queueService.clearQueue();

      // Enqueue 5 meaningful activities, 3 check-ins, and 50 heartbeats interleaved
      for (int i = 1; i <= 50; i++) {
        if (i % 10 == 0) {
          // Enqueue activity
          await queueService.enqueue(
            id: 'act-stress-${i ~/ 10}',
            type: SyncItemType.activity,
            endpoint: ApiEndpoints.activities,
            payload: {'eventId': 'act-stress-${i ~/ 10}', 'type': 'CHARGER_CONNECTED'},
          );
        }
        if (i % 16 == 0) {
          // Enqueue check-in
          await queueService.enqueue(
            id: 'chk-stress-${i ~/ 16}',
            type: SyncItemType.checkIn,
            endpoint: ApiEndpoints.checkIns,
            payload: {'eventId': 'chk-stress-${i ~/ 16}', 'note': 'Checkin $i'},
          );
        }
        // Enqueue heartbeat
        await queueService.enqueue(
          id: 'hb-mixed-$i',
          type: SyncItemType.heartbeat,
          endpoint: ApiEndpoints.heartbeat,
          payload: {'deviceId': 'device-m3-adv-1', 'seq': i},
        );
      }

      // Total expected items: 5 activities + 3 check-ins + 1 latest heartbeat = 9 items
      final len = await queueService.getQueueLength();
      expect(len, 9,
          reason: '5 activities + 3 check-ins + 1 latest heartbeat must equal 9 total items');

      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('carely_offline_sync_queue');
      final List items = jsonDecode(raw!) as List;

      final activities = items.where((it) => it['type'] == 'activity').toList();
      final checkIns = items.where((it) => it['type'] == 'checkIn').toList();
      final heartbeats = items.where((it) => it['type'] == 'heartbeat').toList();

      expect(activities.length, 5, reason: 'All 5 meaningful activities must be preserved');
      expect(checkIns.length, 3, reason: 'All 3 check-ins must be preserved');
      expect(heartbeats.length, 1, reason: 'Exactly 1 heartbeat must remain');
      expect(heartbeats.first['id'], 'hb-mixed-50');
    });

    test('1.3 Concurrent 50 Heartbeat Enqueues: Mutex prevents lost updates or JSON corruption', () async {
      final queueService = SyncQueueService();
      await queueService.clearQueue();

      // Launch 50 concurrent enqueues simultaneously
      await Future.wait(
        List.generate(
          50,
          (i) => queueService.enqueue(
            id: 'hb-concurrent-$i',
            type: SyncItemType.heartbeat,
            endpoint: ApiEndpoints.heartbeat,
            payload: {'deviceId': 'device-m3-adv-1', 'idx': i},
          ),
        ),
      );

      final len = await queueService.getQueueLength();
      expect(len, 1,
          reason: 'Under 50 concurrent enqueues, mutex must serialize writes and coalesce to 1 heartbeat');

      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('carely_offline_sync_queue');
      expect(() => jsonDecode(raw!), returnsNormally,
          reason: 'SharedPreferences JSON must remain completely valid without corruption');
    });
  });

  group('Opt-M3 Challenger: Network Handover & Debounce (Flush Storm Prevention)', () {
    test('2.1 Rapid network transitions (none -> wifi -> mobile -> wifi) trigger exactly 1 debounced flush', () async {
      final queueService = SyncQueueService();
      await queueService.clearQueue();

      // Seed queue with an activity and a check-in
      await queueService.enqueue(
        id: 'act-handover-1',
        type: SyncItemType.activity,
        endpoint: ApiEndpoints.activities,
        payload: {'eventId': 'act-handover-1', 'type': 'APP_OPEN'},
      );
      await queueService.enqueue(
        id: 'chk-handover-1',
        type: SyncItemType.checkIn,
        endpoint: ApiEndpoints.checkIns,
        payload: {'eventId': 'chk-handover-1', 'note': 'Handover test'},
      );

      int flushDispatches = 0;
      final replayedEndpoints = <String>[];

      installInterceptor(
        onResolve: (opts) {
          replayedEndpoints.add(opts.path);
          if (opts.path == ApiEndpoints.activitiesBatch || opts.path == ApiEndpoints.checkIns) {
            flushDispatches++;
            return Response(requestOptions: opts, statusCode: 200, data: {'ok': true});
          }
          return null;
        },
      );

      // Start listening to connectivity stream
      queueService.startListeningToNetwork();

      // Simulate rapid network flapping within 600ms
      mockConnectivity.emit([ConnectivityResult.none]);
      await Future.delayed(const Duration(milliseconds: 100));

      mockConnectivity.emit([ConnectivityResult.wifi]);
      await Future.delayed(const Duration(milliseconds: 150));

      mockConnectivity.emit([ConnectivityResult.mobile]);
      await Future.delayed(const Duration(milliseconds: 150));

      mockConnectivity.emit([ConnectivityResult.none]);
      await Future.delayed(const Duration(milliseconds: 100));

      // Final stable transition to wifi
      mockConnectivity.emit([ConnectivityResult.wifi]);

      // At t = +500ms after final transition: debounce timer (2.0s) has NOT expired
      await Future.delayed(const Duration(milliseconds: 500));
      expect(flushDispatches, 0,
          reason: 'No flush dispatches should occur before 2-second debounce window expires');

      // At t = +1200ms (still within 2s):
      await Future.delayed(const Duration(milliseconds: 700));
      expect(flushDispatches, 0,
          reason: 'Flush must remain throttled during debounce interval');

      // Wait remaining time for debounce timer to fire (total > 2.0s from final transition)
      await Future.delayed(const Duration(milliseconds: 1200));

      // Verify exactly ONE flush cycle executed (1 activities batch + 1 check-in)
      expect(flushDispatches, 2,
          reason: 'Exactly 1 batch flush (1 batch activity + 1 checkin) dispatched after debounce');
      expect(await queueService.getQueueLength(), 0,
          reason: 'Queue completely drained by the single debounced flush');
    });

    test('2.2 Network transition to offline (none) cancels pending debounce timer', () async {
      final queueService = SyncQueueService();
      await queueService.clearQueue();

      await queueService.enqueue(
        id: 'chk-cancel-debounce',
        type: SyncItemType.checkIn,
        endpoint: ApiEndpoints.checkIns,
        payload: {'eventId': 'chk-cancel-debounce'},
      );

      int requestCount = 0;
      installInterceptor(
        onResolve: (opts) {
          requestCount++;
          return Response(requestOptions: opts, statusCode: 200, data: {'ok': true});
        },
      );

      queueService.startListeningToNetwork();

      // Connect to WiFi: debounce timer starts
      mockConnectivity.emit([ConnectivityResult.wifi]);
      await Future.delayed(const Duration(milliseconds: 500));

      // Disconnect to none before 2s elapsed
      mockConnectivity.emit([ConnectivityResult.none]);

      // Wait 2.5s (longer than original debounce)
      await Future.delayed(const Duration(milliseconds: 2500));

      expect(requestCount, 0,
          reason: 'Debounce timer must be cancelled when network goes offline; 0 requests sent');
      expect(await queueService.getQueueLength(), 1,
          reason: 'Item must remain securely queued offline');
    });
  });

  group('Opt-M3 Challenger: Charger Debounce & Activity Payload Invariants', () {
    test('3.1 Charger connect/disconnect events within 60s are strictly throttled', () async {
      final tracker = ActivityTrackerService();

      final dispatchedChargerPayloads = <Map<String, dynamic>>[];
      installInterceptor(
        onResolve: (opts) {
          if (opts.path == ApiEndpoints.activities) {
            final payload = opts.data as Map<String, dynamic>;
            if (payload['type'] == 'CHARGER_CONNECTED' ||
                payload['type'] == 'CHARGER_DISCONNECTED') {
              dispatchedChargerPayloads.add(payload);
            }
            return Response(requestOptions: opts, statusCode: 201, data: {'id': 'act-ok'});
          }
          return null;
        },
      );

      // Event 1: Charger connected at t = 0
      final res1 = await tracker.recordActivity(
        type: ActivityType.CHARGER_CONNECTED,
        confidenceScore: 0.7,
      );
      expect(res1, isTrue, reason: 'First charger event must be accepted');
      expect(dispatchedChargerPayloads.length, 1);

      // Verify canonical activity payload structure and lack of redundant duplicate keys
      final payload = dispatchedChargerPayloads.first;
      expect(payload['eventId'], isNotEmpty);
      expect(payload['deviceId'], 'device-m3-adv-1');
      expect(payload['type'], 'CHARGER_CONNECTED');
      expect(payload['confidence'], 0.7);
      expect(payload['source'], 'MOBILE');
      expect(payload['occurredAt'], isNotEmpty);

      // Feature 56 optimization: duplicate keys removed to conserve bytes
      expect(payload.containsKey('activityType'), isFalse,
          reason: 'Duplicate "activityType" must be eliminated');
      expect(payload.containsKey('confidenceScore'), isFalse,
          reason: 'Duplicate "confidenceScore" must be eliminated');

      // Event 2: Rapid charger disconnected within 60s
      final res2 = await tracker.recordActivity(
        type: ActivityType.CHARGER_DISCONNECTED,
        confidenceScore: 0.6,
      );
      expect(res2, isFalse,
          reason: 'Charger disconnect within 60s must be throttled to prevent radio flapping');
      expect(dispatchedChargerPayloads.length, 1);

      // Event 3: Rapid reconnect within 60s
      final res3 = await tracker.recordActivity(
        type: ActivityType.CHARGER_CONNECTED,
        confidenceScore: 0.7,
      );
      expect(res3, isFalse,
          reason: 'Repeated charger connect within 60s must be throttled');
      expect(dispatchedChargerPayloads.length, 1);
    });
  });

  group('Opt-M3 Challenger: Signal Separation & Background Invariants', () {
    test('4.1 Heartbeat retains weight 0.0, routes to /heartbeat, and never masquerades as activity', () async {
      final heartbeatService = HeartbeatService();

      Map<String, dynamic>? heartbeatPayload;
      String? targetEndpoint;

      installInterceptor(
        onResolve: (opts) {
          targetEndpoint = opts.path;
          heartbeatPayload = opts.data as Map<String, dynamic>;
          return Response(requestOptions: opts, statusCode: 200, data: {'acknowledged': true});
        },
      );

      final ok = await heartbeatService.sendHeartbeat(force: true);
      expect(ok, isTrue);

      expect(targetEndpoint, ApiEndpoints.heartbeat,
          reason: 'Heartbeats must route exclusively to ApiEndpoints.heartbeat');
      expect(targetEndpoint, isNot(ApiEndpoints.activities),
          reason: 'Heartbeats must NEVER route to ApiEndpoints.activities');
      expect(targetEndpoint, isNot(ApiEndpoints.checkIns),
          reason: 'Heartbeats must NEVER route to ApiEndpoints.checkIns');

      expect(heartbeatPayload, isNotNull);
      expect(heartbeatPayload!['deviceId'], 'device-m3-adv-1');
      expect(heartbeatPayload!['deviceUid'], 'device-m3-uid-1');
      expect(heartbeatPayload!.containsKey('weight'), isFalse,
          reason: 'Heartbeat payload must not carry activity weight; weight is server-side 0.0');
    });

    test('4.2 Replay of coalesced heartbeat in flush routes strictly to /heartbeat and not activity batch', () async {
      final queueService = SyncQueueService();
      await queueService.clearQueue();

      // Enqueue 5 heartbeats
      for (int i = 1; i <= 5; i++) {
        await queueService.enqueue(
          id: 'hb-replay-$i',
          type: SyncItemType.heartbeat,
          endpoint: ApiEndpoints.heartbeat,
          payload: {'deviceId': 'device-m3-adv-1', 'seq': i},
        );
      }

      final requestedEndpoints = <String>[];
      installInterceptor(
        onResolve: (opts) {
          requestedEndpoints.add(opts.path);
          return Response(requestOptions: opts, statusCode: 200, data: {'ok': true});
        },
      );

      final flushRes = await queueService.flush();
      expect(flushRes.status, SyncFlushStatus.success);
      expect(flushRes.processedCount, 1, reason: 'Only 1 coalesced heartbeat replayed');

      // Must be /activities/heartbeat (ApiEndpoints.heartbeat), NEVER activitiesBatch
      expect(requestedEndpoints, [ApiEndpoints.heartbeat]);
      expect(requestedEndpoints.contains(ApiEndpoints.activitiesBatch), isFalse);
    });

    test('4.3 BackgroundService.executeBackgroundTask runs background routine and flushes queue', () async {
      final executedEndpoints = <String>[];

      // Enqueue a check-in to be flushed by background execution
      final queue = SyncQueueService();
      await queue.clearQueue();
      await queue.enqueue(
        id: 'chk-bg-1',
        type: SyncItemType.checkIn,
        endpoint: ApiEndpoints.checkIns,
        payload: {'eventId': 'chk-bg-1'},
      );

      installInterceptor(
        onResolve: (opts) {
          executedEndpoints.add(opts.path);
          return Response(requestOptions: opts, statusCode: 200, data: {'ok': true});
        },
      );

      final bgOk = await BackgroundService.executeBackgroundTask();
      expect(bgOk, isTrue, reason: 'Background execution routine completes with success');

      // Flush portion must execute queued check-ins
      expect(executedEndpoints.contains(ApiEndpoints.checkIns), isTrue,
          reason: 'Background task must flush opportunistic offline queue');
    });

    test('4.4 Dual-timer coordination: HeartbeatService skips network if recent heartbeat < 12 minutes', () async {
      final heartbeatService = HeartbeatService();

      // Save a heartbeat timestamp from 5 minutes ago
      final fiveMinutesAgo = DateTime.now().subtract(const Duration(minutes: 5));
      await LocalStorage.saveLastHeartbeatAt(fiveMinutesAgo);

      int networkCallCount = 0;
      installInterceptor(
        onResolve: (opts) {
          networkCallCount++;
          return Response(requestOptions: opts, statusCode: 200, data: {'ok': true});
        },
      );

      // When last heartbeat was within 12 minutes:
      // Note: If lastHeartbeatSentAt is already set on singleton within 12m, sendHeartbeat(force: false) skips
      final result = await heartbeatService.sendHeartbeat(force: false);
      expect(result, isTrue,
          reason: 'Returns true (skipped successfully) without waking network modem');
      expect(networkCallCount, 0,
          reason: 'Dual-timer coordination must skip radio transmission if last ping < 12m');

      // With force = true
      final forceResult = await heartbeatService.sendHeartbeat(force: true);
      expect(forceResult, isTrue);
      expect(networkCallCount, 1,
          reason: 'Forced heartbeat bypasses 12-minute threshold');
    });
  });
}
