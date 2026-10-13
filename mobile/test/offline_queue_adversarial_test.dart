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

  group('Adversarial Queue Concurrency & Integrity Challenges', () {
    test('ADV-1: High concurrency stress: 100 simultaneous enqueues must all be preserved', () async {
      final queueService = SyncQueueService();
      await queueService.clearQueue();

      final futures = List.generate(
        100,
        (i) => queueService.enqueue(
          id: 'adv-concurrent-$i',
          type: SyncItemType.activity,
          endpoint: ApiEndpoints.activities,
          payload: {'index': i, 'name': 'Activity $i'},
        ),
      );

      await Future.wait(futures);

      final len = await queueService.getQueueLength();
      expect(len, 100,
          reason: 'All 100 concurrent enqueues must be serialized and preserved without loss');
    });

    test('ADV-2: Interleaved enqueue during in-flight successful flush must NOT be overwritten', () async {
      final queueService = SyncQueueService();
      await queueService.clearQueue();

      // Seed queue with initial item
      await queueService.enqueue(
        id: 'chk-initial',
        type: SyncItemType.checkIn,
        endpoint: ApiEndpoints.checkIns,
        payload: {'eventId': 'chk-initial'},
      );

      final inFlightCompleter = Completer<void>();
      final continueFlushCompleter = Completer<void>();

      installInterceptor(
        onResolve: (opts) async {
          if (opts.path == ApiEndpoints.checkIns) {
            if (!inFlightCompleter.isCompleted) {
              inFlightCompleter.complete();
            }
            await continueFlushCompleter.future;
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
      await inFlightCompleter.future;

      // Enqueue while flush is in-flight
      await queueService.enqueue(
        id: 'chk-during-flush',
        type: SyncItemType.checkIn,
        endpoint: ApiEndpoints.checkIns,
        payload: {'eventId': 'chk-during-flush', 'note': 'Created during flush'},
      );

      continueFlushCompleter.complete();
      final flushResult = await flushFuture;

      expect(flushResult.processedCount, 1);

      final finalLen = await queueService.getQueueLength();
      final prefs = await SharedPreferences.getInstance();
      final finalRaw = prefs.getString('carely_offline_sync_queue');

      expect(finalLen, 1,
          reason: 'chk-during-flush MUST survive in queue and not be overwritten by flush() writing stale snapshot');
      expect(finalRaw, contains('chk-during-flush'));
    });

    test('ADV-3: Interleaved enqueue during in-flight network-failed flush must NOT be overwritten', () async {
      final queueService = SyncQueueService();
      await queueService.clearQueue();

      await queueService.enqueue(
        id: 'chk-initial-fail',
        type: SyncItemType.checkIn,
        endpoint: ApiEndpoints.checkIns,
        payload: {'eventId': 'chk-initial-fail'},
      );

      final inFlightCompleter = Completer<void>();
      final continueFlushCompleter = Completer<void>();

      installInterceptor(
        onReject: (opts) async {
          if (opts.path == ApiEndpoints.checkIns) {
            if (!inFlightCompleter.isCompleted) {
              inFlightCompleter.complete();
            }
            await continueFlushCompleter.future;
            return DioException(
              requestOptions: opts,
              type: DioExceptionType.connectionTimeout,
              message: 'Timeout in flight',
            );
          }
          return null;
        },
      );

      final flushFuture = queueService.flush();
      await inFlightCompleter.future;

      // Enqueue while flush is failing in-flight
      await queueService.enqueue(
        id: 'chk-during-fail',
        type: SyncItemType.checkIn,
        endpoint: ApiEndpoints.checkIns,
        payload: {'eventId': 'chk-during-fail'},
      );

      continueFlushCompleter.complete();
      final flushResult = await flushFuture;

      expect(flushResult.status, SyncFlushStatus.partialError);

      final finalLen = await queueService.getQueueLength();
      final prefs = await SharedPreferences.getInstance();
      final finalRaw = prefs.getString('carely_offline_sync_queue');

      expect(finalLen, 2,
          reason: 'Both chk-initial-fail and chk-during-fail MUST exist in queue; neither can be lost');
      expect(finalRaw, contains('chk-initial-fail'));
      expect(finalRaw, contains('chk-during-fail'));
    });

    test('ADV-4: Burst of concurrent enqueues while batch activities flush is in-flight', () async {
      final queueService = SyncQueueService();
      await queueService.clearQueue();

      await queueService.enqueue(
        id: 'act-seed-1',
        type: SyncItemType.activity,
        endpoint: ApiEndpoints.activities,
        payload: {'id': 'act-seed-1'},
      );

      final inFlightCompleter = Completer<void>();
      final continueFlushCompleter = Completer<void>();

      installInterceptor(
        onResolve: (opts) async {
          if (opts.path == ApiEndpoints.activitiesBatch) {
            if (!inFlightCompleter.isCompleted) {
              inFlightCompleter.complete();
            }
            await continueFlushCompleter.future;
            return Response(
              requestOptions: opts,
              statusCode: 200,
              data: {'count': 1},
            );
          }
          return null;
        },
      );

      final flushFuture = queueService.flush();
      await inFlightCompleter.future;

      // 10 concurrent enqueues while batch flush is processing
      await Future.wait(
        List.generate(
          10,
          (i) => queueService.enqueue(
            id: 'burst-$i',
            type: SyncItemType.checkIn,
            endpoint: ApiEndpoints.checkIns,
            payload: {'index': i},
          ),
        ),
      );

      continueFlushCompleter.complete();
      await flushFuture;

      final len = await queueService.getQueueLength();
      expect(len, 10,
          reason: 'All 10 burst enqueued items must be preserved after batch activity completes');
    });

    test('ADV-5: Interleaved heartbeat enqueue during in-flight heartbeat flush', () async {
      final queueService = SyncQueueService();
      await queueService.clearQueue();

      await queueService.enqueue(
        id: 'hb-seed-1',
        type: SyncItemType.heartbeat,
        endpoint: ApiEndpoints.heartbeat,
        payload: {'occurredAt': '2026-10-07T12:00:00Z'},
      );

      final inFlightCompleter = Completer<void>();
      final continueFlushCompleter = Completer<void>();

      installInterceptor(
        onResolve: (opts) async {
          if (opts.path == ApiEndpoints.heartbeat) {
            if (!inFlightCompleter.isCompleted) {
              inFlightCompleter.complete();
            }
            await continueFlushCompleter.future;
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
      await inFlightCompleter.future;

      // Newer heartbeat generated while older heartbeat is flushing
      await queueService.enqueue(
        id: 'hb-seed-2',
        type: SyncItemType.heartbeat,
        endpoint: ApiEndpoints.heartbeat,
        payload: {'occurredAt': '2026-10-07T12:15:00Z'},
      );

      continueFlushCompleter.complete();
      await flushFuture;

      final len = await queueService.getQueueLength();
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('carely_offline_sync_queue');

      expect(len, 1,
          reason: 'Newer heartbeat hb-seed-2 enqueued during flush must be preserved in queue');
      expect(raw, contains('hb-seed-2'));
    });

    test('ADV-6: Interleaved valid check-in during 400 Bad Request poison pill purge', () async {
      final queueService = SyncQueueService();
      await queueService.clearQueue();

      await queueService.enqueue(
        id: 'chk-poison',
        type: SyncItemType.checkIn,
        endpoint: ApiEndpoints.checkIns,
        payload: {'eventId': 'chk-poison', 'bad': true},
      );

      final inFlightCompleter = Completer<void>();
      final continueFlushCompleter = Completer<void>();

      installInterceptor(
        onReject: (opts) async {
          if (opts.path == ApiEndpoints.checkIns) {
            if (!inFlightCompleter.isCompleted) {
              inFlightCompleter.complete();
            }
            await continueFlushCompleter.future;
            return DioException(
              requestOptions: opts,
              response: Response(requestOptions: opts, statusCode: 400),
              type: DioExceptionType.badResponse,
            );
          }
          return null;
        },
      );

      final flushFuture = queueService.flush();
      await inFlightCompleter.future;

      // User check-in while poison pill is being rejected by backend
      await queueService.enqueue(
        id: 'chk-valid-user',
        type: SyncItemType.checkIn,
        endpoint: ApiEndpoints.checkIns,
        payload: {'eventId': 'chk-valid-user', 'note': 'Valid user check-in'},
      );

      continueFlushCompleter.complete();
      await flushFuture;

      final len = await queueService.getQueueLength();
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('carely_offline_sync_queue');

      expect(len, 1,
          reason: 'Valid check-in must survive even when flush was purging an in-flight poison pill');
      expect(raw, contains('chk-valid-user'));
    });
  });
}
