import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/constants/api_endpoints.dart';
import 'package:mobile/core/models/enums.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/core/services/activity_tracker_service.dart';
import 'package:mobile/core/services/sync_queue_service.dart';
import 'package:mobile/core/storage/local_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel connectivityChannel =
      MethodChannel('dev.fluttercommunity.plus/connectivity');

  late ApiClient apiClient;
  InterceptorsWrapper? activeInterceptor;
  String originalBaseUrl = ApiEndpoints.baseUrl;

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

  HttpOverrides? originalHttpOverrides;

  setUp(() async {
    originalHttpOverrides = HttpOverrides.current;
    HttpOverrides.global = null;
    originalBaseUrl = ApiEndpoints.baseUrl;

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(connectivityChannel,
            (MethodCall methodCall) async {
      if (methodCall.method == 'check') {
        return ['wifi'];
      }
      return null;
    });

    SharedPreferences.setMockInitialValues({
      'carely_user_id': 'user-gen9-adv-101',
      'carely_access_token': 'jwt-access-token-initial',
      'carely_refresh_token': 'jwt-refresh-token-valid',
      'carely_device_id': 'device-gen9-adv-uuid',
      'carely_device_uid': 'device-gen9-uid-hardware',
    });

    apiClient = ApiClient();
    final queue = SyncQueueService();
    await queue.clearQueue();
  });

  tearDown(() async {
    HttpOverrides.global = originalHttpOverrides;
    ApiEndpoints.baseUrl = originalBaseUrl;
    apiClient.dio.options.baseUrl = originalBaseUrl;
    if (activeInterceptor != null) {
      apiClient.dio.interceptors.remove(activeInterceptor);
      activeInterceptor = null;
    }
    SyncQueueService().stopListeningToNetwork();
    await SyncQueueService().clearQueue();
  });

  // =========================================================================
  // GROUP 1: SyncQueueService Bounding & Overflow Eviction Under High Burst
  // =========================================================================
  group('Gen9 Challenger: SyncQueueService Bounding & Overflow Eviction Under Burst', () {
    test('1.1 Burst of 250 activities is strictly bounded to maxActivities (200), evicting oldest 50', () async {
      final queueService = SyncQueueService();
      await queueService.clearQueue();

      final now = DateTime.now();

      // Enqueue 250 activities sequentially with strictly increasing enqueuedAt
      for (int i = 1; i <= 250; i++) {
        await queueService.enqueue(
          id: 'act-burst-$i',
          type: SyncItemType.activity,
          endpoint: ApiEndpoints.activities,
          payload: {
            'eventId': 'act-burst-$i',
            'seq': i,
            'occurredAt': now.add(Duration(seconds: i)).toUtc().toIso8601String(),
          },
        );
      }

      // Invariant: queue length must be capped exactly at SyncQueueService.maxActivities (200)
      final length = await queueService.getQueueLength();
      expect(length, SyncQueueService.maxActivities,
          reason: 'Activity queue must never exceed maxActivities (200)');
      expect(length, 200);

      // Verify FIFO eviction in persistent SharedPreferences storage
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('carely_offline_sync_queue');
      expect(raw, isNotNull);

      final List items = jsonDecode(raw!) as List;
      expect(items.length, 200);

      // The oldest 50 items (act-burst-1 to act-burst-50) MUST have been evicted
      for (int i = 1; i <= 50; i++) {
        expect(raw, isNot(contains('"act-burst-$i"')),
            reason: 'Oldest activity act-burst-$i must be evicted on overflow');
      }

      // The newest 200 items (act-burst-51 to act-burst-250) MUST be retained in FIFO order
      final firstRetained = items.first as Map<String, dynamic>;
      final lastRetained = items.last as Map<String, dynamic>;

      expect(firstRetained['id'], 'act-burst-51',
          reason: 'First retained item must be act-burst-51');
      expect(lastRetained['id'], 'act-burst-250',
          reason: 'Last retained item must be act-burst-250');
      expect(firstRetained['payload']['seq'], 51);
      expect(lastRetained['payload']['seq'], 250);
    });

    test('1.2 Burst of 150 check-ins is strictly bounded to maxCheckIns (100), evicting oldest 50', () async {
      final queueService = SyncQueueService();
      await queueService.clearQueue();

      final now = DateTime.now();

      // Enqueue 150 check-ins sequentially
      for (int i = 1; i <= 150; i++) {
        await queueService.enqueue(
          id: 'chk-burst-$i',
          type: SyncItemType.checkIn,
          endpoint: ApiEndpoints.checkIns,
          payload: {
            'eventId': 'chk-burst-$i',
            'seq': i,
            'note': 'Burst Check-in $i',
            'occurredAt': now.add(Duration(seconds: i)).toUtc().toIso8601String(),
          },
        );
      }

      // Invariant: queue length must be capped exactly at SyncQueueService.maxCheckIns (100)
      final length = await queueService.getQueueLength();
      expect(length, SyncQueueService.maxCheckIns,
          reason: 'Check-in queue must never exceed maxCheckIns (100)');
      expect(length, 100);

      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('carely_offline_sync_queue');
      final List items = jsonDecode(raw!) as List;
      expect(items.length, 100);

      // Oldest 50 check-ins (1..50) must be evicted
      for (int i = 1; i <= 50; i++) {
        expect(raw, isNot(contains('"chk-burst-$i"')),
            reason: 'Check-in chk-burst-$i must be evicted');
      }

      // Retained 100 check-ins (51..150) must be present in exact order
      final firstRetained = items.first as Map<String, dynamic>;
      final lastRetained = items.last as Map<String, dynamic>;
      expect(firstRetained['id'], 'chk-burst-51');
      expect(lastRetained['id'], 'chk-burst-150');
    });

    test('1.3 Cross-Type Isolation: Activity overflow pruning never evicts check-ins or heartbeat', () async {
      final queueService = SyncQueueService();
      await queueService.clearQueue();

      // 1. Seed 1 heartbeat and 40 check-ins
      await queueService.enqueue(
        id: 'hb-safe-beacon',
        type: SyncItemType.heartbeat,
        endpoint: ApiEndpoints.heartbeat,
        payload: {'deviceId': 'device-safe-1'},
      );

      for (int i = 1; i <= 40; i++) {
        await queueService.enqueue(
          id: 'chk-safe-$i',
          type: SyncItemType.checkIn,
          endpoint: ApiEndpoints.checkIns,
          payload: {'eventId': 'chk-safe-$i', 'seq': i},
        );
      }

      expect(await queueService.getQueueLength(), 41);

      // 2. High burst of 250 activities
      for (int i = 1; i <= 250; i++) {
        await queueService.enqueue(
          id: 'act-overflow-$i',
          type: SyncItemType.activity,
          endpoint: ApiEndpoints.activities,
          payload: {'eventId': 'act-overflow-$i', 'seq': i},
        );
      }

      // Total items = 1 (coalesced heartbeat) + 40 (check-ins) + 200 (bounded activities) = 241
      final totalLength = await queueService.getQueueLength();
      expect(totalLength, 241,
          reason: 'Total queue must contain 1 heartbeat + 40 check-ins + 200 bounded activities');

      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('carely_offline_sync_queue');
      final List items = jsonDecode(raw!) as List;

      final heartbeats = items.where((it) => it['type'] == 'heartbeat').toList();
      final checkIns = items.where((it) => it['type'] == 'checkIn').toList();
      final activities = items.where((it) => it['type'] == 'activity').toList();

      expect(heartbeats.length, 1, reason: 'Heartbeat must not be touched by activity overflow');
      expect(heartbeats.first['id'], 'hb-safe-beacon');

      expect(checkIns.length, 40, reason: 'All 40 check-ins must be 100% preserved');
      for (int i = 1; i <= 40; i++) {
        expect(checkIns.any((c) => c['id'] == 'chk-safe-$i'), isTrue,
            reason: 'Check-in chk-safe-$i must still exist in queue');
      }

      expect(activities.length, 200, reason: 'Activities must be capped at 200');
      expect(activities.first['id'], 'act-overflow-51');
      expect(activities.last['id'], 'act-overflow-250');
    });

    test('1.4 Concurrent Burst: 250 simultaneous activity enqueues maintain bounded length & JSON integrity', () async {
      final queueService = SyncQueueService();
      await queueService.clearQueue();

      // Launch 250 concurrent enqueues without awaiting individually
      await Future.wait(
        List.generate(
          250,
          (i) => queueService.enqueue(
            id: 'act-concurrent-$i',
            type: SyncItemType.activity,
            endpoint: ApiEndpoints.activities,
            payload: {'eventId': 'act-concurrent-$i', 'idx': i},
          ),
        ),
      );

      final length = await queueService.getQueueLength();
      expect(length, 200,
          reason: 'Mutex must serialize concurrent writes and cap total at maxActivities (200)');

      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('carely_offline_sync_queue');
      expect(raw, isNotNull);

      // Verify JSON parses without syntax error or corruption
      final List items = jsonDecode(raw!) as List;
      expect(items.length, 200);

      // Verify all items are unique
      final ids = items.map((it) => it['id'] as String).toSet();
      expect(ids.length, 200, reason: 'All 200 retained items must have unique IDs');
    });
  });

  // =========================================================================
  // GROUP 2: Batch Chunking (Batches of 20) Stress & Edge Cases
  // =========================================================================
  group('Gen9 Challenger: Batch Chunking Stress (Batches of 20)', () {
    test('2.1 65 queued activities are dispatched in exactly 4 chunks [20, 20, 20, 5] in exact order', () async {
      final queueService = SyncQueueService();
      await queueService.clearQueue();

      for (int i = 1; i <= 65; i++) {
        await queueService.enqueue(
          id: 'act-chunk-$i',
          type: SyncItemType.activity,
          endpoint: ApiEndpoints.activities,
          payload: {'eventId': 'act-chunk-$i', 'seq': i},
        );
      }

      final dispatchedChunks = <List<dynamic>>[];

      installInterceptor(
        onResolve: (opts) {
          if (opts.path == ApiEndpoints.activitiesBatch) {
            final data = opts.data as Map<String, dynamic>;
            final batch = data['activities'] as List<dynamic>;
            dispatchedChunks.add(batch);
            return Response(
              requestOptions: opts,
              statusCode: 200,
              data: {'count': batch.length},
            );
          }
          return null;
        },
      );

      final result = await queueService.flush();
      expect(result.status, SyncFlushStatus.success);
      expect(result.processedCount, 65);
      expect(result.remainingCount, 0);

      // Verify chunking pattern
      expect(dispatchedChunks.length, 4,
          reason: '65 activities must be divided into ceil(65/20) = 4 HTTP POST requests');
      expect(dispatchedChunks[0].length, 20, reason: 'Chunk 1 size must be 20');
      expect(dispatchedChunks[1].length, 20, reason: 'Chunk 2 size must be 20');
      expect(dispatchedChunks[2].length, 20, reason: 'Chunk 3 size must be 20');
      expect(dispatchedChunks[3].length, 5, reason: 'Chunk 4 size must be 5 (tail)');

      // Verify payload order across chunks
      expect(dispatchedChunks[0].first['eventId'], 'act-chunk-1');
      expect(dispatchedChunks[0].last['eventId'], 'act-chunk-20');

      expect(dispatchedChunks[1].first['eventId'], 'act-chunk-21');
      expect(dispatchedChunks[1].last['eventId'], 'act-chunk-40');

      expect(dispatchedChunks[2].first['eventId'], 'act-chunk-41');
      expect(dispatchedChunks[2].last['eventId'], 'act-chunk-60');

      expect(dispatchedChunks[3].first['eventId'], 'act-chunk-61');
      expect(dispatchedChunks[3].last['eventId'], 'act-chunk-65');

      expect(await queueService.getQueueLength(), 0, reason: 'Queue drained completely');
    });

    test('2.2 Partial Chunk Failure: Chunk 1 succeeds, Chunk 2 fails with timeout -> Chunk 1 removed, Chunks 2 & 3 retained', () async {
      final queueService = SyncQueueService();
      await queueService.clearQueue();

      // Enqueue 45 activities: will form Chunk 1 (20), Chunk 2 (20), Chunk 3 (5)
      for (int i = 1; i <= 45; i++) {
        await queueService.enqueue(
          id: 'act-partial-$i',
          type: SyncItemType.activity,
          endpoint: ApiEndpoints.activities,
          payload: {'eventId': 'act-partial-$i', 'seq': i},
        );
      }

      int batchCallCount = 0;
      installInterceptor(
        onResolve: (opts) {
          if (opts.path == ApiEndpoints.activitiesBatch) {
            batchCallCount++;
            if (batchCallCount == 1) {
              // Chunk 1 succeeds
              return Response(
                requestOptions: opts,
                statusCode: 200,
                data: {'success': true},
              );
            }
          }
          return null;
        },
        onReject: (opts) {
          if (opts.path == ApiEndpoints.activitiesBatch && batchCallCount >= 1) {
            // Chunk 2 throws connection timeout
            return DioException(
              requestOptions: opts,
              type: DioExceptionType.connectionTimeout,
              message: 'Timeout on chunk 2',
            );
          }
          return null;
        },
      );

      final flushResult = await queueService.flush();
      expect(flushResult.status, SyncFlushStatus.partialError);
      expect(flushResult.processedCount, 20, reason: 'Chunk 1 (20 items) processed');
      expect(flushResult.remainingCount, 25, reason: 'Chunk 2 (20) + Chunk 3 (5) = 25 retained');

      // Verify persistent storage state
      final remainingLength = await queueService.getQueueLength();
      expect(remainingLength, 25);

      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('carely_offline_sync_queue');
      final List items = jsonDecode(raw!) as List;

      // Verify items 1..20 are no longer present
      for (int i = 1; i <= 20; i++) {
        expect(raw, isNot(contains('"act-partial-$i"')),
            reason: 'Successful chunk 1 items must be cleared from storage');
      }

      // Verify items 21..45 are safely preserved
      expect(items.first['id'], 'act-partial-21');
      expect(items.last['id'], 'act-partial-45');

      // Now simulate network recovery: subsequent flush replays remaining 25 items
      installInterceptor(
        onResolve: (opts) => Response(
          requestOptions: opts,
          statusCode: 200,
          data: {'success': true},
        ),
      );

      final recoveryResult = await queueService.flush();
      expect(recoveryResult.status, SyncFlushStatus.success);
      expect(recoveryResult.processedCount, 25);
      expect(await queueService.getQueueLength(), 0, reason: 'Queue empty after full replay');
    });

    test('2.3 Poison Pill in Chunk: 400 Bad Request purges invalid chunk without stalling remaining chunks', () async {
      final queueService = SyncQueueService();
      await queueService.clearQueue();

      // 40 activities: Chunk 1 (20 items, invalid) and Chunk 2 (20 items, valid)
      for (int i = 1; i <= 40; i++) {
        await queueService.enqueue(
          id: 'act-poison-$i',
          type: SyncItemType.activity,
          endpoint: ApiEndpoints.activities,
          payload: {'eventId': 'act-poison-$i', 'seq': i},
        );
      }

      int callIndex = 0;
      installInterceptor(
        onResolve: (opts) {
          if (opts.path == ApiEndpoints.activitiesBatch) {
            callIndex++;
            if (callIndex == 1) {
              // Server rejects chunk 1 with 400 Bad Request
              throw DioException(
                requestOptions: opts,
                response: Response(requestOptions: opts, statusCode: 400),
                type: DioExceptionType.badResponse,
              );
            }
            // Chunk 2 succeeds
            return Response(requestOptions: opts, statusCode: 200, data: {'ok': true});
          }
          return null;
        },
      );

      final flushResult = await queueService.flush();
      expect(flushResult.status, SyncFlushStatus.success);
      expect(flushResult.processedCount, 20, reason: 'Chunk 2 succeeded');
      expect(await queueService.getQueueLength(), 0,
          reason: 'Chunk 1 purged (to prevent poison pill stall) and Chunk 2 processed');
    });
  });

  // =========================================================================
  // GROUP 3: HTTP 429 Backoff, Retry Count & Rate-Limit Handling
  // =========================================================================
  group('Gen9 Challenger: HTTP 429 Backoff & Rate-Limit Handling', () {
    test('3.1 HTTP 429 on activity batch stops replay, retains items, and increments retryCount', () async {
      final queueService = SyncQueueService();
      await queueService.clearQueue();

      // Enqueue 40 activities (2 chunks of 20)
      for (int i = 1; i <= 40; i++) {
        await queueService.enqueue(
          id: 'act-429-$i',
          type: SyncItemType.activity,
          endpoint: ApiEndpoints.activities,
          payload: {'eventId': 'act-429-$i', 'seq': i},
        );
      }

      int batchAttempts = 0;
      installInterceptor(
        onReject: (opts) {
          if (opts.path == ApiEndpoints.activitiesBatch) {
            batchAttempts++;
            // Server responds with HTTP 429 Too Many Requests
            return DioException(
              requestOptions: opts,
              response: Response(
                requestOptions: opts,
                statusCode: 429,
                statusMessage: 'Too Many Requests',
              ),
              type: DioExceptionType.badResponse,
            );
          }
          return null;
        },
      );

      final flushResult = await queueService.flush();
      expect(flushResult.status, SyncFlushStatus.partialError);
      expect(flushResult.processedCount, 0);
      expect(flushResult.remainingCount, 40);

      // Backoff verification: Must stop immediately after 1st chunk returns 429
      expect(batchAttempts, 1,
          reason: 'Must NOT attempt Chunk 2 after receiving 429; immediate backoff required');

      // Verify retryCount updated in SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('carely_offline_sync_queue');
      final List items = jsonDecode(raw!) as List;

      // Attempted chunk (items 1..20) must have retryCount == 1
      for (int i = 0; i < 20; i++) {
        expect(items[i]['retryCount'], 1,
            reason: 'Attempted item ${items[i]['id']} must have retryCount incremented');
      }

      // Unattempted chunk (items 21..40) must have retryCount == 0
      for (int i = 20; i < 40; i++) {
        expect(items[i]['retryCount'], 0,
            reason: 'Unattempted item ${items[i]['id']} must retain retryCount 0');
      }

      // Second consecutive 429 flush increments retryCount again
      final secondFlushResult = await queueService.flush();
      expect(secondFlushResult.status, SyncFlushStatus.partialError);
      final raw2 = prefs.getString('carely_offline_sync_queue');
      final List items2 = jsonDecode(raw2!) as List;
      expect(items2[0]['retryCount'], 2,
          reason: 'Second 429 attempt increments retryCount to 2');
    });

    test('3.2 HTTP 429 on Check-in stops replay, preserves strict FIFO order, and increments retryCount', () async {
      final queueService = SyncQueueService();
      await queueService.clearQueue();

      await queueService.enqueue(
        id: 'chk-429-1',
        type: SyncItemType.checkIn,
        endpoint: ApiEndpoints.checkIns,
        payload: {'eventId': 'chk-429-1', 'note': 'First checkin'},
      );
      await queueService.enqueue(
        id: 'chk-429-2',
        type: SyncItemType.checkIn,
        endpoint: ApiEndpoints.checkIns,
        payload: {'eventId': 'chk-429-2', 'note': 'Second checkin'},
      );
      await queueService.enqueue(
        id: 'chk-429-3',
        type: SyncItemType.checkIn,
        endpoint: ApiEndpoints.checkIns,
        payload: {'eventId': 'chk-429-3', 'note': 'Third checkin'},
      );

      final attemptedCheckIns = <String>[];
      installInterceptor(
        onReject: (opts) {
          if (opts.path == ApiEndpoints.checkIns) {
            final data = opts.data as Map;
            attemptedCheckIns.add(data['eventId'] as String);
            // 429 on first check-in
            return DioException(
              requestOptions: opts,
              response: Response(requestOptions: opts, statusCode: 429),
              type: DioExceptionType.badResponse,
            );
          }
          return null;
        },
      );

      final flushResult = await queueService.flush();
      expect(flushResult.status, SyncFlushStatus.partialError);

      // FIFO ordering: only chk-429-1 was attempted, chk-429-2 and chk-429-3 NOT attempted
      expect(attemptedCheckIns, ['chk-429-1'],
          reason: 'Replay must stop immediately upon 429 to avoid out-of-order execution');

      expect(await queueService.getQueueLength(), 3);

      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('carely_offline_sync_queue');
      final List items = jsonDecode(raw!) as List;

      expect(items[0]['id'], 'chk-429-1');
      expect(items[0]['retryCount'], 1);

      expect(items[1]['id'], 'chk-429-2');
      expect(items[1]['retryCount'], 0);

      expect(items[2]['id'], 'chk-429-3');
      expect(items[2]['retryCount'], 0);
    });

    test('3.3 ActivityTrackerService enqueues offline when receiving HTTP 429 without throwing to caller', () async {
      final tracker = ActivityTrackerService();
      final queueService = SyncQueueService();
      await queueService.clearQueue();

      installInterceptor(
        onReject: (opts) {
          if (opts.path == ApiEndpoints.activities) {
            return DioException(
              requestOptions: opts,
              response: Response(requestOptions: opts, statusCode: 429),
              type: DioExceptionType.badResponse,
            );
          }
          return null;
        },
      );

      final ok = await tracker.recordActivity(
        type: ActivityType.APP_OPEN,
        confidenceScore: 0.9,
      );

      // Invariant: Calm UX returns true (calm success) and safely enqueues offline
      expect(ok, isTrue,
          reason: '429 error must be handled gracefully by enqueuing into offline queue');
      expect(await queueService.getQueueLength(), 1,
          reason: 'Item must be enqueued in SyncQueueService');

      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('carely_offline_sync_queue');
      expect(raw, contains('APP_OPEN'));
    });
  });

  // =========================================================================
  // GROUP 4: Charger Debounce Stress & Concurrency Under Burst
  // =========================================================================
  group('Gen9 Challenger: Charger Debounce Stress & Concurrency Under Burst', () {
    test('4.1 High Burst & Concurrency: 5 concurrent unawaited charger calls followed by 95 flapping events allows exactly 1 event', () async {
      final tracker = ActivityTrackerService();

      int dispatchedCount = 0;
      final networkCompleter = Completer<void>();

      installInterceptor(
        onResolve: (opts) async {
          if (opts.path == ApiEndpoints.activities) {
            dispatchedCount++;
            if (!networkCompleter.isCompleted) {
              await networkCompleter.future;
            }
            return Response(requestOptions: opts, statusCode: 201, data: {'id': 'act-ok'});
          }
          return null;
        },
      );

      // Part A: Asynchronous Race Condition - 5 simultaneous unawaited calls
      final f1 = tracker.recordActivity(type: ActivityType.CHARGER_CONNECTED);
      final f2 = tracker.recordActivity(type: ActivityType.CHARGER_DISCONNECTED);
      final f3 = tracker.recordActivity(type: ActivityType.CHARGER_CONNECTED);
      final f4 = tracker.recordActivity(type: ActivityType.CHARGER_DISCONNECTED);
      final f5 = tracker.recordActivity(type: ActivityType.CHARGER_CONNECTED);

      // Release network response
      networkCompleter.complete();

      final concurrentResults = await Future.wait([f1, f2, f3, f4, f5]);

      expect(concurrentResults[0], isTrue, reason: 'First concurrent invocation took the debounce lock');
      expect(concurrentResults[1], isFalse, reason: 'Synchronous timestamp update debounced f2');
      expect(concurrentResults[2], isFalse, reason: 'Synchronous timestamp update debounced f3');
      expect(concurrentResults[3], isFalse, reason: 'Synchronous timestamp update debounced f4');
      expect(concurrentResults[4], isFalse, reason: 'Synchronous timestamp update debounced f5');

      // Part B: Rapid Flapping - 95 consecutive rapid alternating charger events
      final flappingResults = <bool>[];
      for (int i = 0; i < 95; i++) {
        final type = (i % 2 == 0)
            ? ActivityType.CHARGER_CONNECTED
            : ActivityType.CHARGER_DISCONNECTED;
        final res = await tracker.recordActivity(
          type: type,
          confidenceScore: 0.7,
        );
        flappingResults.add(res);
      }

      for (int i = 0; i < 95; i++) {
        expect(flappingResults[i], isFalse,
            reason: 'Rapid charger event $i within 60s window must be throttled');
      }

      // Exact single network hit verified across all 100 events
      expect(dispatchedCount, 1,
          reason: 'Only exactly 1 charger activity HTTP request should reach backend across 100 burst events');
      expect(tracker.lastChargerActivityAt, isNotNull);
    });

    test('4.2 Consecutive general activities within 10-second window are strictly throttled', () async {
      final tracker = ActivityTrackerService();

      // Since an activity was dispatched in test 4.1 within the last few seconds,
      // lastDispatchedActivityAt is non-null and within 10s.
      // Attempting an APP_FOREGROUND activity must be rate-limited by the 10s general throttle.
      final res = await tracker.recordActivity(
        type: ActivityType.APP_FOREGROUND,
        confidenceScore: 0.85,
      );

      expect(res, isFalse,
          reason: 'General activity dispatch within 10 seconds of previous activity must be throttled');
      expect(tracker.lastDispatchedActivityAt, isNotNull);
    });
  });

  // =========================================================================
  // GROUP 5: AuthInterceptor Single-Flight 401 Refresh Mutex Concurrency
  // =========================================================================
  group('Gen9 Challenger: AuthInterceptor Single-Flight 401 Mutex Concurrency', () {
    late HttpServer server;
    late int serverPort;

    setUp(() async {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      serverPort = server.port;
      final serverBaseUrl = 'http://127.0.0.1:$serverPort/api/v1';
      ApiEndpoints.baseUrl = serverBaseUrl;
      apiClient.dio.options.baseUrl = serverBaseUrl;
    });

    tearDown(() async {
      await server.close(force: true);
    });

    test('5.1 10 Concurrent 401 Requests trigger EXACTLY ONE /auth/refresh call via single-flight mutex', () async {
      int refreshCallCount = 0;
      int resourceCallCount = 0;
      int retrySuccessCount = 0;

      // Handle real HTTP requests on the loopback server
      server.listen((HttpRequest request) async {
        final path = request.uri.path;
        final authHeader = request.headers.value('authorization');

        if (path == '/api/v1/auth/refresh') {
          refreshCallCount++;
          // Simulate 50ms token generation delay
          await Future.delayed(const Duration(milliseconds: 50));

          request.response.statusCode = 200;
          request.response.headers.contentType = ContentType.json;
          request.response.write(jsonEncode({
            'accessToken': 'new-jwt-access-token-999',
            'refreshToken': 'new-jwt-refresh-token-999',
          }));
          await request.response.close();
        } else if (path == '/api/v1/test-resource') {
          resourceCallCount++;
          if (authHeader == 'Bearer new-jwt-access-token-999') {
            retrySuccessCount++;
            request.response.statusCode = 200;
            request.response.headers.contentType = ContentType.json;
            request.response.write(jsonEncode({'success': true, 'auth': 'updated'}));
            await request.response.close();
          } else {
            // First attempt rejected with 401 Unauthorized
            request.response.statusCode = 401;
            request.response.headers.contentType = ContentType.json;
            request.response.write(jsonEncode({'statusCode': 401, 'message': 'Unauthorized'}));
            await request.response.close();
          }
        } else {
          request.response.statusCode = 404;
          await request.response.close();
        }
      });

      // Dispatch 10 concurrent requests to /test-resource simultaneously
      final futures = List.generate(
        10,
        (i) => apiClient.dio.get('/test-resource'),
      );

      final responses = await Future.wait(futures);

      // Verify all 10 completed with 200 OK
      expect(responses.length, 10);
      for (final resp in responses) {
        expect(resp.statusCode, 200);
        expect(resp.data['auth'], 'updated');
      }

      // CRUCIAL SINGLE-FLIGHT MUTEX INVARIANT:
      expect(refreshCallCount, 1,
          reason: 'Single-flight mutex MUST coalesce all 10 concurrent 401s into EXACTLY 1 /auth/refresh call');

      // 10 initial calls + 10 retry calls = 20 total resource hits
      expect(retrySuccessCount, 10,
          reason: 'All 10 requests were retried with the refreshed Bearer token');
      expect(resourceCallCount, 20);

      // Verify updated tokens in LocalStorage
      expect(await LocalStorage.getAccessToken(), 'new-jwt-access-token-999');
      expect(await LocalStorage.getRefreshToken(), 'new-jwt-refresh-token-999');
    });

    test('5.2 Refresh Token Rejection (401 on /auth/refresh) wipes tokens and rejects all waiters without crash', () async {
      int refreshCallCount = 0;

      server.listen((HttpRequest request) async {
        final path = request.uri.path;
        if (path == '/api/v1/auth/refresh') {
          refreshCallCount++;
          request.response.statusCode = 401; // Refresh token revoked/expired
          request.response.headers.contentType = ContentType.json;
          request.response.write(jsonEncode({'message': 'Refresh token expired'}));
          await request.response.close();
        } else if (path == '/api/v1/protected') {
          request.response.statusCode = 401;
          request.response.headers.contentType = ContentType.json;
          request.response.write(jsonEncode({'message': 'Unauthorized'}));
          await request.response.close();
        }
      });

      // 5 concurrent requests hit 401
      final futures = List.generate(
        5,
        (i) async {
          try {
            return await apiClient.dio.get('/protected');
          } catch (e) {
            return e;
          }
        },
      );

      final results = await Future.wait(futures);

      // Refresh called exactly once
      expect(refreshCallCount, 1,
          reason: 'Single-flight mutex ensures only 1 refresh attempt even on failure');

      // All 5 waiters receive 401 DioException
      for (final res in results) {
        expect(res, isA<DioException>());
        expect((res as DioException).response?.statusCode, 401);
      }

      // LocalStorage.clearAuth() must have wiped tokens
      expect(await LocalStorage.getAccessToken(), isNull,
          reason: 'Access token must be cleared when refresh token is rejected with 401');
      expect(await LocalStorage.getRefreshToken(), isNull,
          reason: 'Refresh token must be cleared when refresh token is rejected with 401');
    });

    test('5.3 Network Error on /auth/refresh preserves tokens in LocalStorage for offline resilience', () async {
      await LocalStorage.saveTokens(
        accessToken: 'stale-token',
        refreshToken: 'valid-persisted-refresh-token',
      );

      server.listen((HttpRequest request) async {
        final path = request.uri.path;
        if (path == '/api/v1/auth/refresh') {
          // Abruptly close connection without response to simulate network drop
          final socket = await request.response.detachSocket();
          socket.destroy();
        } else if (path == '/api/v1/res') {
          request.response.statusCode = 401;
          await request.response.close();
        }
      });

      dynamic caughtErr;
      try {
        await apiClient.dio.get('/res');
      } catch (e) {
        caughtErr = e;
      }

      expect(caughtErr, isA<DioException>());

      // Tokens must NOT be wiped on network glitches/timeouts!
      expect(await LocalStorage.getRefreshToken(), 'valid-persisted-refresh-token',
          reason: 'Tokens must NEVER be wiped on network errors');
    });

    test('5.4 401 on /auth/login does NOT trigger recursive refresh', () async {
      int refreshCallCount = 0;

      server.listen((HttpRequest request) async {
        final path = request.uri.path;
        if (path == '/api/v1/auth/refresh') {
          refreshCallCount++;
          request.response.statusCode = 200;
          await request.response.close();
        } else if (path == '/api/v1/auth/login') {
          request.response.statusCode = 401; // Invalid credentials
          request.response.headers.contentType = ContentType.json;
          request.response.write(jsonEncode({'message': 'Invalid credentials'}));
          await request.response.close();
        }
      });

      dynamic caughtLoginErr;
      try {
        await apiClient.dio.post(ApiEndpoints.login, data: {'email': 'x', 'password': 'y'});
      } catch (e) {
        caughtLoginErr = e;
      }

      expect(caughtLoginErr, isA<DioException>());
      expect((caughtLoginErr as DioException).response?.statusCode, 401);

      // Must NOT call refresh for /auth/* endpoints
      expect(refreshCallCount, 0,
          reason: 'Requests to /auth/* must NEVER trigger token refresh loop');
    });
  });
}
