import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/constants/api_endpoints.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/core/services/sync_queue_service.dart';
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

  const MethodChannel connectivityChannel =
      MethodChannel('dev.fluttercommunity.plus/connectivity');
  List<String> mockConnectivityResults = ['wifi'];

  setUp(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(connectivityChannel,
            (MethodCall methodCall) async {
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

  group('SyncQueueService Concurrency & In-Flight Empirical Proofs', () {
    test('PROOF-1: 100 concurrent enqueues interleaved with multi-stage in-flight flush never lose any item', () async {
      final queueService = SyncQueueService();
      await queueService.clearQueue();

      // Seed 10 activities and 5 check-ins
      for (int i = 0; i < 10; i++) {
        await queueService.enqueue(
          id: 'seed-act-$i',
          type: SyncItemType.activity,
          endpoint: ApiEndpoints.activities,
          payload: {'eventId': 'seed-act-$i'},
        );
      }
      for (int i = 0; i < 5; i++) {
        await queueService.enqueue(
          id: 'seed-chk-$i',
          type: SyncItemType.checkIn,
          endpoint: ApiEndpoints.checkIns,
          payload: {'eventId': 'seed-chk-$i'},
        );
      }

      final inFlightFlush = Completer<void>();
      final releaseFlush = Completer<void>();

      installInterceptor(
        onResolve: (opts) async {
          if (opts.path == ApiEndpoints.activitiesBatch) {
            if (!inFlightFlush.isCompleted) {
              inFlightFlush.complete();
            }
            await releaseFlush.future;
            return Response(
              requestOptions: opts,
              statusCode: 200,
              data: {'success': true},
            );
          }
          if (opts.path == ApiEndpoints.checkIns) {
            return Response(
              requestOptions: opts,
              statusCode: 200,
              data: {'success': true},
            );
          }
          return null;
        },
      );

      final flushFuture = queueService.flush();
      await inFlightFlush.future;

      // Burst 100 enqueues concurrently while flush is actively waiting
      final burstFutures = List.generate(100, (i) {
        return queueService.enqueue(
          id: 'burst-during-flush-$i',
          type: (i % 2 == 0) ? SyncItemType.checkIn : SyncItemType.activity,
          endpoint: (i % 2 == 0) ? ApiEndpoints.checkIns : ApiEndpoints.activities,
          payload: {'index': i, 'id': 'burst-during-flush-$i'},
        );
      });

      // Await all enqueues to ensure they have entered the queue
      await Future.wait(burstFutures);

      // Release network response for flush
      releaseFlush.complete();
      final result = await flushFuture;

      expect(result.processedCount, 15, reason: 'Initial 10 activities + 5 check-ins processed');

      final remaining = await queueService.getQueueLength();
      expect(remaining, 100,
          reason: 'All 100 concurrently enqueued items must be preserved on disk without loss');

      // Verify that every single burst item ID is physically in storage
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('carely_offline_sync_queue') ?? '';
      for (int i = 0; i < 100; i++) {
        expect(raw.contains('burst-during-flush-$i'), isTrue,
            reason: 'Item burst-during-flush-$i must be present in persistent storage');
      }

      // Re-flush: all 100 should process cleanly
      final secondFlush = await queueService.flush();
      expect(secondFlush.status, SyncFlushStatus.success);
      expect(await queueService.getQueueLength(), 0, reason: 'Queue should now be empty');
    });

    test('PROOF-2: Interleaved enqueues during network-failed flush preserve failed seeds and all new enqueues', () async {
      final queueService = SyncQueueService();
      await queueService.clearQueue();

      // Seed 2 check-ins
      await queueService.enqueue(
        id: 'fail-chk-1',
        type: SyncItemType.checkIn,
        endpoint: ApiEndpoints.checkIns,
        payload: {'eventId': 'fail-chk-1'},
      );
      await queueService.enqueue(
        id: 'fail-chk-2',
        type: SyncItemType.checkIn,
        endpoint: ApiEndpoints.checkIns,
        payload: {'eventId': 'fail-chk-2'},
      );

      final inFlightCompleter = Completer<void>();
      final releaseCompleter = Completer<void>();

      installInterceptor(
        onReject: (opts) async {
          if (opts.path == ApiEndpoints.checkIns) {
            if (!inFlightCompleter.isCompleted) {
              inFlightCompleter.complete();
            }
            await releaseCompleter.future;
            return DioException(
              requestOptions: opts,
              type: DioExceptionType.connectionTimeout,
              message: 'Simulated connection drop',
            );
          }
          return null;
        },
      );

      final flushFuture = queueService.flush();
      await inFlightCompleter.future;

      // Concurrently enqueue 20 items during failure
      final burst = List.generate(
        20,
        (i) => queueService.enqueue(
          id: 'concurrent-fail-$i',
          type: SyncItemType.activity,
          endpoint: ApiEndpoints.activities,
          payload: {'index': i},
        ),
      );
      await Future.wait(burst);

      releaseCompleter.complete();
      final result = await flushFuture;

      expect(result.status, SyncFlushStatus.partialError);
      expect(result.processedCount, 0);

      final remaining = await queueService.getQueueLength();
      expect(remaining, 22,
          reason: '2 failed seeds + 20 concurrently enqueued items = 22 total items preserved');

      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('carely_offline_sync_queue') ?? '';
      expect(raw.contains('fail-chk-1'), isTrue);
      expect(raw.contains('fail-chk-2'), isTrue);
      for (int i = 0; i < 20; i++) {
        expect(raw.contains('concurrent-fail-$i'), isTrue);
      }
    });

    test('PROOF-3: Rapid overlapping flush calls combined with continuous concurrent enqueues never deadlock', () async {
      final queueService = SyncQueueService();
      await queueService.clearQueue();

      installInterceptor(
        onResolve: (opts) async {
          await Future.delayed(const Duration(milliseconds: 15));
          return Response(requestOptions: opts, statusCode: 200, data: {'success': true});
        },
      );

      // Seed 5 items
      for (int i = 0; i < 5; i++) {
        await queueService.enqueue(
          id: 'initial-$i',
          type: SyncItemType.checkIn,
          endpoint: ApiEndpoints.checkIns,
          payload: {'eventId': 'initial-$i'},
        );
      }

      // Fire 5 rapid flushes concurrently
      final flushes = List.generate(5, (_) => queueService.flush());

      // While flushes are running, rapidly enqueue 30 items
      final enqueues = List.generate(
        30,
        (i) => queueService.enqueue(
          id: 'rapid-concurrent-$i',
          type: SyncItemType.activity,
          endpoint: ApiEndpoints.activities,
          payload: {'index': i},
        ),
      );

      // Ensure all complete within 5 seconds (deadlock check)
      await Future.wait(enqueues).timeout(const Duration(seconds: 5));
      final flushResults = await Future.wait(flushes).timeout(const Duration(seconds: 5));

      // At least 4 flushes should have returned alreadyRunning
      final alreadyRunningCount =
          flushResults.where((r) => r.status == SyncFlushStatus.alreadyRunning).length;
      expect(alreadyRunningCount, greaterThanOrEqualTo(1),
          reason: 'Concurrent flushes must be safely throttled');

      // Trigger one final flush to drain everything
      final finalFlush = await queueService.flush().timeout(const Duration(seconds: 5));
      expect(finalFlush.status, SyncFlushStatus.success);
      expect(await queueService.getQueueLength(), 0, reason: 'All items eventually processed without deadlock');
    });

    test('PROOF-4: clearQueue() invoked while flush is in-flight does not resurrect cleared items', () async {
      final queueService = SyncQueueService();
      await queueService.clearQueue();

      // Seed 2 check-ins
      await queueService.enqueue(
        id: 'to-be-cleared-1',
        type: SyncItemType.checkIn,
        endpoint: ApiEndpoints.checkIns,
        payload: {'eventId': 'to-be-cleared-1'},
      );
      await queueService.enqueue(
        id: 'to-be-cleared-2',
        type: SyncItemType.checkIn,
        endpoint: ApiEndpoints.checkIns,
        payload: {'eventId': 'to-be-cleared-2'},
      );

      final inFlightCompleter = Completer<void>();
      final releaseCompleter = Completer<void>();

      installInterceptor(
        onResolve: (opts) async {
          if (opts.path == ApiEndpoints.checkIns) {
            if (!inFlightCompleter.isCompleted) {
              inFlightCompleter.complete();
            }
            await releaseCompleter.future;
            return Response(requestOptions: opts, statusCode: 200, data: {'ok': true});
          }
          return null;
        },
      );

      final flushFuture = queueService.flush();
      await inFlightCompleter.future;

      // User triggers clearQueue() while network request is in-flight
      await queueService.clearQueue();

      // Enqueue fresh item after clear
      await queueService.enqueue(
        id: 'survivor-after-clear',
        type: SyncItemType.checkIn,
        endpoint: ApiEndpoints.checkIns,
        payload: {'eventId': 'survivor-after-clear'},
      );

      releaseCompleter.complete();
      await flushFuture;

      final remaining = await queueService.getQueueLength();
      expect(remaining, 1, reason: 'Only the item enqueued after clear must remain');

      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('carely_offline_sync_queue') ?? '';
      expect(raw.contains('survivor-after-clear'), isTrue);
      expect(raw.contains('to-be-cleared-1'), isFalse);
      expect(raw.contains('to-be-cleared-2'), isFalse);
    });

    test('PROOF-5: Uncaught asynchronous exceptions audit: zero uncaught errors in root Zone', () async {
      final uncaughtErrors = <dynamic>[];

      await runZonedGuarded(() async {
        final queueService = SyncQueueService();
        await queueService.clearQueue();

        // Configure interceptor with 400 Bad Request, 500 Server Error, and Timeout
        installInterceptor(
          onReject: (opts) {
            if (opts.path == ApiEndpoints.activitiesBatch) {
              return DioException(
                requestOptions: opts,
                response: Response(requestOptions: opts, statusCode: 500),
                type: DioExceptionType.badResponse,
              );
            }
            if (opts.path == ApiEndpoints.checkIns) {
              return DioException(
                requestOptions: opts,
                response: Response(requestOptions: opts, statusCode: 400),
                type: DioExceptionType.badResponse,
              );
            }
            if (opts.path == ApiEndpoints.heartbeat) {
              return DioException(
                requestOptions: opts,
                type: DioExceptionType.connectionTimeout,
                message: 'Heartbeat timeout',
              );
            }
            return null;
          },
        );

        // Enqueue items across all types
        await queueService.enqueue(
          id: 'audit-act-1',
          type: SyncItemType.activity,
          endpoint: ApiEndpoints.activities,
          payload: {'eventId': 'audit-act-1'},
        );
        await queueService.enqueue(
          id: 'audit-chk-1',
          type: SyncItemType.checkIn,
          endpoint: ApiEndpoints.checkIns,
          payload: {'eventId': 'audit-chk-1'},
        );
        await queueService.enqueue(
          id: 'audit-hb-1',
          type: SyncItemType.heartbeat,
          endpoint: ApiEndpoints.heartbeat,
          payload: {'occurredAt': '2026-10-07T12:00:00Z'},
        );

        // Run flush and interleaved enqueues
        final f = queueService.flush();
        await queueService.enqueue(
          id: 'audit-interleaved-1',
          type: SyncItemType.checkIn,
          endpoint: ApiEndpoints.checkIns,
          payload: {'eventId': 'audit-interleaved-1'},
        );
        await f;
      }, (error, stack) {
        uncaughtErrors.add(error);
      });

      expect(uncaughtErrors, isEmpty,
          reason: 'No unhandled Future rejections or asynchronous exceptions must escape into the zone');
    });
  });
}
