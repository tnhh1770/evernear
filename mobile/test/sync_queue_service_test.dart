import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/services/sync_queue_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SyncQueueService Tests', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
    });

    test('SyncQueueItem serialization and deserialization', () {
      final now = DateTime.now();
      final item = SyncQueueItem(
        id: 'event-uuid-1',
        type: SyncItemType.checkIn,
        endpoint: '/check-ins',
        payload: {
          'eventId': 'event-uuid-1',
          'occurredAt': now.toIso8601String(),
          'note': 'Tôi vẫn ổn',
        },
        enqueuedAt: now,
      );

      final json = item.toJson();
      final restored = SyncQueueItem.fromJson(json);

      expect(restored.id, item.id);
      expect(restored.type, SyncItemType.checkIn);
      expect(restored.endpoint, '/check-ins');
      expect(restored.payload['note'], 'Tôi vẫn ổn');
    });

    test('enqueue persists item and deduplicates by eventId', () async {
      final service = SyncQueueService();
      await service.clearQueue();

      await service.enqueue(
        id: 'evt-100',
        type: SyncItemType.activity,
        endpoint: '/activities',
        payload: {'eventId': 'evt-100', 'type': 'APP_OPEN'},
      );

      expect(await service.getQueueLength(), 1);

      // Enqueue again with same eventId
      await service.enqueue(
        id: 'evt-100',
        type: SyncItemType.activity,
        endpoint: '/activities',
        payload: {'eventId': 'evt-100', 'type': 'APP_OPEN', 'updated': true},
      );

      // Should still be length 1 (deduplicated)
      expect(await service.getQueueLength(), 1);

      // Enqueue different eventId
      await service.enqueue(
        id: 'evt-200',
        type: SyncItemType.heartbeat,
        endpoint: '/heartbeat',
        payload: {'deviceId': 'dev-1'},
      );

      expect(await service.getQueueLength(), 2);

      await service.clearQueue();
      expect(await service.getQueueLength(), 0);
    });

    test('isNetworkOrOfflineError correctly identifies network issues vs client errors', () {
      final reqOptions = RequestOptions(path: '/test');

      // 1. Connection Error
      final connError = DioException(
        requestOptions: reqOptions,
        type: DioExceptionType.connectionError,
      );
      expect(SyncQueueService.isNetworkOrOfflineError(connError), true);

      // 2. Timeout Error
      final timeoutError = DioException(
        requestOptions: reqOptions,
        type: DioExceptionType.connectionTimeout,
      );
      expect(SyncQueueService.isNetworkOrOfflineError(timeoutError), true);

      // 3. SocketException wrapped in unknown
      final socketError = DioException(
        requestOptions: reqOptions,
        type: DioExceptionType.unknown,
        error: const SocketException('Connection refused'),
      );
      expect(SyncQueueService.isNetworkOrOfflineError(socketError), true);

      // 4. Server 503 Service Unavailable
      final server503 = DioException(
        requestOptions: reqOptions,
        response: Response(
          requestOptions: reqOptions,
          statusCode: 503,
        ),
      );
      expect(SyncQueueService.isNetworkOrOfflineError(server503), true);

      // 5. Client 400 Bad Request (Must NOT be treated as offline network error to avoid poison queue)
      final client400 = DioException(
        requestOptions: reqOptions,
        response: Response(
          requestOptions: reqOptions,
          statusCode: 400,
        ),
      );
      expect(SyncQueueService.isNetworkOrOfflineError(client400), false);
    });
  });
}
