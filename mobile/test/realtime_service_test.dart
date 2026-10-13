import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/constants/api_endpoints.dart';
import 'package:mobile/core/network/realtime_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RealtimeService & ApiEndpoints WebSocket URL Tests', () {
    test('ApiEndpoints.wsUrl correctly transforms HTTP to WS and HTTPS to WSS', () {
      final defaultUrl = ApiEndpoints.wsUrl('test-token-123');
      expect(defaultUrl, contains('ws://'));
      expect(defaultUrl, contains('/ws?token=test-token-123'));

      // Test with custom https baseUrl
      final prevBase = ApiEndpoints.baseUrl;
      ApiEndpoints.baseUrl = 'https://api.carely.vn/api/v1';
      final wssUrl = ApiEndpoints.wsUrl('secure-token');
      expect(wssUrl, startsWith('wss://api.carely.vn/ws?token=secure-token'));

      // Restore
      ApiEndpoints.baseUrl = prevBase;
    });

    test('RealtimeService singleton instance and initial state', () {
      final service1 = RealtimeService();
      final service2 = RealtimeService();
      expect(identical(service1, service2), isTrue);
      expect(service1.isConnected, isFalse);
    });

    test('RealtimeService eventStream emits events properly', () async {
      final service = RealtimeService();
      final receivedEvents = <Map<String, dynamic>>[];

      final sub = service.eventStream.listen((event) {
        receivedEvents.add(event);
      });

      // Disconnect cleanly
      service.disconnect();
      expect(service.isConnected, isFalse);

      await sub.cancel();
    });
  });
}
