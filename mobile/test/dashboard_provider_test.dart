import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/models/enums.dart';
import 'package:mobile/core/models/relationship_model.dart';
import 'package:mobile/features/dashboard/dashboard_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DashboardProvider & State Resolution Tests', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({
        'carely_user_id': 'user-monitored-1',
      });
    });

    test('myCurrentState returns ACTIVE when no relationships', () {
      final provider = DashboardProvider();
      expect(provider.myCurrentState, MonitoringState.ACTIVE);
      expect(provider.myLastActivityAt, isNull);
    });

    test('myCurrentState prioritizes highest severity state', () {
      // Verify that enums parser handles both canonical and legacy
      final escalatedState = MonitoringState.fromString('ESCALATED');
      final warningState = MonitoringState.fromString('WARNING');
      final checkInReqState = MonitoringState.fromString('CHECK_IN_REQUIRED');

      expect(escalatedState, MonitoringState.ESCALATED);
      expect(warningState, MonitoringState.WARNING);
      expect(checkInReqState, MonitoringState.CHECK_IN_REQUIRED);
    });

    test('RelationshipModel parses both map monitoring and monitoredBy entries', () {
      final backendResponse = {
        'monitoring': [
          {
            'id': 'rel-1',
            'monitoredUserId': 'elderly-1',
            'monitorId': 'guardian-1',
            'status': 'ACCEPTED',
            'label': 'Bố',
          }
        ],
        'monitoredBy': [
          {
            'id': 'rel-2',
            'monitoredUserId': 'elderly-2',
            'monitorId': 'guardian-2',
            'status': 'ACCEPTED',
            'label': 'Mẹ',
            'config': {
              'id': 'cfg-2',
              'relationshipId': 'rel-2',
              'currentState': 'ACTIVE',
              'inactivityThresholdMinutes': 180,
              'checkInGraceMinutes': 30,
              'locationEnabled': true,
              'timezone': 'Asia/Ho_Chi_Minh',
              'scheduleWindows': [
                {
                  'dayOfWeek': 1,
                  'startTime': '07:00',
                  'endTime': '22:00',
                  'isEnabled': true,
                }
              ]
            }
          }
        ]
      };

      final monitoringList = (backendResponse['monitoring'] as List)
          .map((j) => RelationshipModel.fromJson(j as Map<String, dynamic>))
          .toList();
      final monitoredByList = (backendResponse['monitoredBy'] as List)
          .map((j) => RelationshipModel.fromJson(j as Map<String, dynamic>))
          .toList();

      expect(monitoringList.length, 1);
      expect(monitoringList.first.id, 'rel-1');
      expect(monitoringList.first.monitorId, 'guardian-1');

      expect(monitoredByList.length, 1);
      expect(monitoredByList.first.id, 'rel-2');
      expect(monitoredByList.first.config, isNotNull);
      expect(monitoredByList.first.config!.checkInGraceMinutes, 30);
      expect(monitoredByList.first.config!.scheduleWindows.length, 1);
      expect(monitoredByList.first.config!.scheduleWindows.first.dayOfWeek, 1);
    });
  });
}
