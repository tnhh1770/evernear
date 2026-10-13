import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/services/fcm_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FcmService Unit & Integration Tests', () {
    late FcmService service;

    setUp(() {
      service = FcmService();
    });

    test('1. Singleton returns identical instance', () {
      final s1 = FcmService();
      final s2 = FcmService();
      expect(identical(s1, s2), isTrue);
    });

    test('2. Constants match NOTIFICATION.md specifications', () {
      expect(FcmService.notificationChannelId, 'carely_alerts_channel');
      expect(FcmService.notificationChannelName, 'Carely Alerts & Check-Ins');
      expect(FcmService.notificationChannelDesc, contains('check-in'));
    });

    test('3. Mock token assignment and retrieval works reliably', () {
      const mockToken = 'mock_fcm_token_flutter_test_12345';
      service.setMockToken(mockToken);
      expect(service.fcmToken, mockToken);
    });

    test('4. Notification action callback triggers correctly with payload data', () {
      Map<String, dynamic>? receivedData;
      service.onNotificationTapCallback = (data) {
        receivedData = data;
      };

      final testPayload = {
        'templateName': 'CHECK_IN_REQUEST',
        'incidentId': 'inc_abc_999',
        'action': 'CONFIRM_OK',
      };

      service.handleMessageAction(testPayload);

      expect(receivedData, isNotNull);
      expect(receivedData!['templateName'], 'CHECK_IN_REQUEST');
      expect(receivedData!['incidentId'], 'inc_abc_999');
      expect(receivedData!['action'], 'CONFIRM_OK');
    });

    test('5. Safe initialize does not throw in unit test environment', () async {
      // In flutter_test, Firebase.initializeApp() throws NoFirebaseApp without native bindings,
      // FcmService catches it gracefully and sets _isFirebaseAvailable = false.
      await service.initialize();
      expect(service.isInitialized, isTrue);
    });

    test('6. Cold launch buffers payload and dispatches immediately upon listener attachment', () {
      service.onNotificationTapCallback = null;
      final coldLaunchPayload = {
        'incidentId': 'inc_cold_launch_123',
        'type': 'INCIDENT_CREATED',
      };

      service.handleMessageAction(coldLaunchPayload);
      expect(service.pendingPayload, isNotNull);
      expect(service.pendingPayload!['incidentId'], 'inc_cold_launch_123');

      Map<String, dynamic>? dispatched;
      service.onNotificationTapCallback = (data) {
        dispatched = data;
      };

      expect(dispatched, isNotNull);
      expect(dispatched!['incidentId'], 'inc_cold_launch_123');
      expect(service.pendingPayload, isNull);
    });
  });
}
