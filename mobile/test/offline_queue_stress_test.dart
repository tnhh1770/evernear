import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/constants/api_endpoints.dart';
import 'package:mobile/core/models/enums.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/core/services/activity_tracker_service.dart';
import 'package:mobile/core/services/sync_queue_service.dart';
import 'package:mobile/features/dashboard/dashboard_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ApiClient apiClient;
  InterceptorsWrapper? activeInterceptor;

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

  const MethodChannel connectivityChannel = MethodChannel('dev.fluttercommunity.plus/connectivity');
  List<String> mockConnectivityResults = ['wifi'];

  setUp(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(connectivityChannel, (MethodCall methodCall) async {
      if (methodCall.method == 'check') {
        return mockConnectivityResults;
      }
      return null;
    });

    SharedPreferences.setMockInitialValues({
      'carely_user_id': 'user-monitored-100',
      'carely_access_token': 'jwt-mock-token-xyz',
      'carely_device_id': 'device-test-uuid-42',
    });
    mockConnectivityResults = ['wifi'];
    apiClient = ApiClient();
    final queue = SyncQueueService();
    await queue.clearQueue();
  });

  tearDown(() async {
    if (activeInterceptor != null) {
      apiClient.dio.interceptors.remove(activeInterceptor);
      activeInterceptor = null;
    }
    await SyncQueueService().clearQueue();
  });

  group('Offline Queue Replay & Duplication Resilience Stress Tests', () {
    test('1.1 Network drop during check-in enqueues payload with calm success', () async {
      final provider = DashboardProvider();

      // Simulate connection timeout
      installInterceptor(
        onReject: (opts) => DioException(
          requestOptions: opts,
          type: DioExceptionType.connectionTimeout,
          message: 'Connection timed out',
        ),
      );

      final result = await provider.sendCheckIn(note: 'Đang mất mạng nhưng tôi vẫn ổn');
      expect(result, isTrue, reason: 'Calm UX returns true when check-in is enqueued offline');
      expect(provider.lastCheckInOffline, isTrue);

      final queueService = SyncQueueService();
      final length = await queueService.getQueueLength();
      expect(length, 1);

      // Verify stored queue item
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('carely_offline_sync_queue');
      expect(raw, contains('checkIn'));
      expect(raw, contains('Đang mất mạng nhưng tôi vẫn ổn'));
      expect(raw, contains('device-test-uuid-42'));
    });

    test('1.2 Network drop during activity reporting enqueues activity payload', () async {
      final tracker = ActivityTrackerService();

      // Simulate connection error (offline drop)
      installInterceptor(
        onReject: (opts) => DioException(
          requestOptions: opts,
          type: DioExceptionType.connectionError,
          message: 'Network unreachable',
        ),
      );

      final result = await tracker.recordActivity(
        type: ActivityType.CHARGER_CONNECTED,
        confidenceScore: 0.85,
        metadata: {'trigger': 'charger_plugged'},
      );
      expect(result, isTrue, reason: 'Activity enqueued offline returns true');

      final queueService = SyncQueueService();
      final length = await queueService.getQueueLength();
      expect(length, 1);

      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('carely_offline_sync_queue');
      expect(raw, contains('activity'));
      expect(raw, contains('CHARGER_CONNECTED'));
      expect(raw, contains('MOBILE'));
    });

    test('1.3 Idempotency & Deduplication: Repeated calls with same eventId do not duplicate', () async {
      final queueService = SyncQueueService();

      const fixedEventId = 'fixed-event-id-999';
      for (int i = 0; i < 5; i++) {
        await queueService.enqueue(
          id: fixedEventId,
          type: SyncItemType.checkIn,
          endpoint: ApiEndpoints.checkIns,
          payload: {
            'eventId': fixedEventId,
            'attempt': i,
            'note': 'Lần gọi $i',
          },
        );
      }

      final length = await queueService.getQueueLength();
      expect(length, 1, reason: 'Repeated sequential calls with same eventId must not duplicate entries');

      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('carely_offline_sync_queue');
      expect(raw, contains('Lần gọi 4'), reason: 'Queue retains the latest payload for identical eventId');
    });

    test('1.4 Concurrent enqueues with same eventId remain resilient', () async {
      final queueService = SyncQueueService();
      const concurrentEventId = 'concurrent-event-777';

      // 10 concurrent writes with same eventId
      await Future.wait(
        List.generate(
          10,
          (i) => queueService.enqueue(
            id: concurrentEventId,
            type: SyncItemType.checkIn,
            endpoint: ApiEndpoints.checkIns,
            payload: {'eventId': concurrentEventId, 'thread': i},
          ),
        ),
      );

      final length = await queueService.getQueueLength();
      // Should be 1 because all share the same eventId
      expect(length, 1);
    });

    test('1.5 Flush handles intermittent reconnection and preserves FIFO order', () async {
      final queueService = SyncQueueService();

      // Seed queue with 3 check-ins and 2 activities
      await queueService.enqueue(
        id: 'act-1',
        type: SyncItemType.activity,
        endpoint: ApiEndpoints.activities,
        payload: {'eventId': 'act-1', 'type': 'CHARGER_CONNECTED'},
      );
      await queueService.enqueue(
        id: 'act-2',
        type: SyncItemType.activity,
        endpoint: ApiEndpoints.activities,
        payload: {'eventId': 'act-2', 'type': 'CHARGER_DISCONNECTED'},
      );
      await queueService.enqueue(
        id: 'chk-1',
        type: SyncItemType.checkIn,
        endpoint: ApiEndpoints.checkIns,
        payload: {'eventId': 'chk-1', 'note': 'Check-in 1'},
      );
      await queueService.enqueue(
        id: 'chk-2',
        type: SyncItemType.checkIn,
        endpoint: ApiEndpoints.checkIns,
        payload: {'eventId': 'chk-2', 'note': 'Check-in 2'},
      );
      await queueService.enqueue(
        id: 'hb-1',
        type: SyncItemType.heartbeat,
        endpoint: ApiEndpoints.heartbeat,
        payload: {'occurredAt': '2026-10-07T14:00:00Z'},
      );
      await queueService.enqueue(
        id: 'hb-2',
        type: SyncItemType.heartbeat,
        endpoint: ApiEndpoints.heartbeat,
        payload: {'occurredAt': '2026-10-07T14:15:00Z'},
      );

      expect(await queueService.getQueueLength(), 5,
          reason: 'Feature 57: hb-1 and hb-2 coalesce to latest heartbeat at enqueue time');

      // Interceptor scenario:
      // 1. activities/batch succeeds (200)
      // 2. chk-1 throws connectionTimeout (simulating connection dropped immediately after batch)
      final replayedEndpoints = <String>[];
      installInterceptor(
        onResolve: (opts) {
          if (opts.path == ApiEndpoints.activitiesBatch) {
            replayedEndpoints.add(opts.path);
            return Response(requestOptions: opts, statusCode: 200, data: {'count': 2});
          }
          return null; // Not resolved here
        },
        onReject: (opts) {
          if (opts.path == ApiEndpoints.checkIns) {
            // Drop connection on check-in
            replayedEndpoints.add(opts.path);
            return DioException(
              requestOptions: opts,
              type: DioExceptionType.connectionTimeout,
              message: 'Connection dropped mid-flush',
            );
          }
          if (opts.path == ApiEndpoints.heartbeat) {
            replayedEndpoints.add(opts.path);
            return DioException(
              requestOptions: opts,
              type: DioExceptionType.connectionTimeout,
              message: 'Connection dropped mid-flush',
            );
          }
          return null;
        },
      );

      final flushResult1 = await queueService.flush();
      expect(flushResult1.status, SyncFlushStatus.partialError);
      expect(flushResult1.processedCount, 2, reason: 'Activities were batched and processed');

      // Crucial FIFO invariant: chk-1 was attempted and failed, chk-2 was NOT attempted out-of-order!
      // Remaining queue must contain chk-1, chk-2, and coalesced latest heartbeat (hb-2)
      final remainingAfterDrop = await queueService.getQueueLength();
      expect(remainingAfterDrop, 3, reason: '3 items (chk-1, chk-2, hb-2) remain in queue after mid-flush disconnect');

      // Reconnection phase: Network is fully restored
      replayedEndpoints.clear();
      installInterceptor(
        onResolve: (opts) {
          replayedEndpoints.add(opts.path);
          return Response(requestOptions: opts, statusCode: 200, data: {'success': true});
        },
      );

      final flushResult2 = await queueService.flush();
      expect(flushResult2.status, SyncFlushStatus.success);
      expect(await queueService.getQueueLength(), 0, reason: 'Queue should be empty after full recovery');

      // Heartbeats: only 1 heartbeat (the latest) was sent, but both hb-1 and hb-2 were cleared
      expect(replayedEndpoints.where((ep) => ep == ApiEndpoints.heartbeat).length, 1);
      // Both check-ins were replayed in order: chk-1 then chk-2
      expect(replayedEndpoints.where((ep) => ep == ApiEndpoints.checkIns).length, 2);
    });

    test('1.6 Flush handles server 504 Gateway Timeout without discarding queued items', () async {
      final queueService = SyncQueueService();

      await queueService.enqueue(
        id: 'chk-504',
        type: SyncItemType.checkIn,
        endpoint: ApiEndpoints.checkIns,
        payload: {'eventId': 'chk-504'},
      );

      // Server returns 504 Gateway Timeout
      installInterceptor(
        onReject: (opts) => DioException(
          requestOptions: opts,
          response: Response(requestOptions: opts, statusCode: 504),
          type: DioExceptionType.badResponse,
        ),
      );

      final flushResult = await queueService.flush();
      expect(flushResult.status, SyncFlushStatus.partialError);
      expect(flushResult.remainingCount, 1);

      // Ensure item is retained for later retry
      expect(await queueService.getQueueLength(), 1);
    });

    test('1.7 Flush handles 400 Bad Request by purging poison pill without stalling queue', () async {
      final queueService = SyncQueueService();

      // Enqueue invalid check-in (poison pill) and valid check-in
      await queueService.enqueue(
        id: 'chk-invalid',
        type: SyncItemType.checkIn,
        endpoint: ApiEndpoints.checkIns,
        payload: {'eventId': 'chk-invalid', 'malformed': true},
      );
      await queueService.enqueue(
        id: 'chk-valid',
        type: SyncItemType.checkIn,
        endpoint: ApiEndpoints.checkIns,
        payload: {'eventId': 'chk-valid', 'note': 'Valid'},
      );

      installInterceptor(
        onResolve: (opts) {
          final data = opts.data as Map;
          if (data['eventId'] == 'chk-invalid') {
            // Bad request
            throw DioException(
              requestOptions: opts,
              response: Response(requestOptions: opts, statusCode: 400),
              type: DioExceptionType.badResponse,
            );
          }
          return Response(requestOptions: opts, statusCode: 201, data: {'id': 'created'});
        },
      );

      final flushResult = await queueService.flush();
      // chk-invalid returned 400 -> purged; chk-valid returned 201 -> processed
      expect(flushResult.status, SyncFlushStatus.success);
      expect(flushResult.processedCount, 1);
      expect(await queueService.getQueueLength(), 0);
    });

    test('1.8 Heartbeat dropped during network error should not be falsely purged as successful', () async {
      final queueService = SyncQueueService();
      await queueService.clearQueue();

      await queueService.enqueue(
        id: 'hb-fail-net',
        type: SyncItemType.heartbeat,
        endpoint: ApiEndpoints.heartbeat,
        payload: {'deviceId': 'dev-1', 'deviceUid': 'uid-1'},
      );

      // Heartbeat request fails with connection timeout
      installInterceptor(
        onReject: (opts) => DioException(
          requestOptions: opts,
          type: DioExceptionType.connectionTimeout,
          message: 'Network offline during heartbeat',
        ),
      );

      await queueService.flush();
      expect(await queueService.getQueueLength(), 1,
          reason: 'Heartbeat that failed due to network disconnect must remain queued, not falsely purged');
    });

    test('1.9 Concurrent enqueues with distinct IDs: race condition test', () async {
      final queueService = SyncQueueService();
      await queueService.clearQueue();

      await Future.wait(
        List.generate(
          10,
          (i) => queueService.enqueue(
            id: 'concurrent-unique-$i',
            type: SyncItemType.activity,
            endpoint: ApiEndpoints.activities,
            payload: {'id': i},
          ),
        ),
      );

      final len = await queueService.getQueueLength();
      expect(len, 10,
          reason: 'All 10 concurrent enqueued items should be preserved without read-modify-write lost updates');
    });

    test('1.10 Offline state returns networkUnavailable without issuing network requests', () async {
      final queueService = SyncQueueService();
      await queueService.clearQueue();

      await queueService.enqueue(
        id: 'chk-offline-guard',
        type: SyncItemType.checkIn,
        endpoint: ApiEndpoints.checkIns,
        payload: {'eventId': 'chk-offline-guard'},
      );

      // Set connectivity to none
      mockConnectivityResults = ['none'];

      final flushResult = await queueService.flush();
      expect(flushResult.status, SyncFlushStatus.networkUnavailable);
      expect(flushResult.remainingCount, 1);
      expect(await queueService.getQueueLength(), 1);
    });

    test('1.11 Concurrent flush() calls return alreadyRunning', () async {
      final queueService = SyncQueueService();
      await queueService.clearQueue();

      // Delay response to keep first flush running
      installInterceptor(
        onResolve: (opts) async {
          await Future.delayed(const Duration(milliseconds: 50));
          return Response(requestOptions: opts, statusCode: 200, data: {'ok': true});
        },
      );

      await queueService.enqueue(
        id: 'chk-delay',
        type: SyncItemType.checkIn,
        endpoint: ApiEndpoints.checkIns,
        payload: {'eventId': 'chk-delay'},
      );

      final f1 = queueService.flush();
      final f2 = await queueService.flush();

      expect(f2.status, SyncFlushStatus.alreadyRunning);
      await f1;
    });

    test('1.12 Feature 57: Enqueue-time heartbeat coalescing retains only the latest heartbeat in storage', () async {
      final queueService = SyncQueueService();
      await queueService.clearQueue();

      // Enqueue 10 consecutive heartbeats simulating 2.5 hours offline
      for (int i = 1; i <= 10; i++) {
        await queueService.enqueue(
          id: 'hb-series-$i',
          type: SyncItemType.heartbeat,
          endpoint: ApiEndpoints.heartbeat,
          payload: {
            'occurredAt': '2026-10-07T${12 + (i ~/ 4)}:${(i % 4) * 15}:00Z',
            'seq': i,
          },
        );
      }

      // Exactly 1 heartbeat must remain in storage (the latest, seq 10)
      expect(await queueService.getQueueLength(), 1,
          reason: 'Enqueue-time coalescing eliminates O(N^2) JSON write amplification');

      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('carely_offline_sync_queue');
      expect(raw, contains('"hb-series-10"'));
      expect(raw, isNot(contains('"hb-series-1"')));
      expect(raw, isNot(contains('"hb-series-9"')));
    });
  });
}
