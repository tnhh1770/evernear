import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/models/enums.dart';
import 'package:mobile/core/models/incident_model.dart';
import 'package:mobile/core/models/monitoring_config_model.dart';
import 'package:mobile/core/models/relationship_model.dart';

void main() {
  group('DTO Serialization & API Alignment Stress Tests', () {
    group('RelationshipModel.fromJson stress testing', () {
      test('handles empty json without throwing', () {
        final model = RelationshipModel.fromJson({});
        expect(model.id, '');
        expect(model.monitoredUserId, '');
        expect(model.monitorUserId, '');
        expect(model.status, RelationshipStatus.PENDING);
        expect(model.monitoredUser, isNull);
        expect(model.monitorUser, isNull);
        expect(model.config, isNull);
        expect(model.createdAt, isNotNull);
      });

      test('handles all null values cleanly', () {
        final model = RelationshipModel.fromJson({
          'id': null,
          'monitoredUserId': null,
          'monitorUserId': null,
          'status': null,
          'inviteCode': null,
          'invitationCode': null,
          'label': null,
          'monitoredUser': null,
          'monitored': null,
          'monitorUser': null,
          'monitor': null,
          'config': null,
          'createdAt': null,
        });
        expect(model.id, '');
        expect(model.status, RelationshipStatus.PENDING);
      });

      test('handles unknown and case-variant enum values gracefully', () {
        final model1 = RelationshipModel.fromJson({
          'id': 'rel-1',
          'status': 'UNKNOWN_STATUS_VALUE',
        });
        expect(model1.status, RelationshipStatus.PENDING);

        final model2 = RelationshipModel.fromJson({
          'id': 'rel-2',
          'status': 'accepted',
        });
        expect(model2.status, RelationshipStatus.ACCEPTED);

        final model3 = RelationshipModel.fromJson({
          'id': 'rel-3',
          'status': 'REVOKED',
        });
        expect(model3.status, RelationshipStatus.SUSPENDED);
      });

      test('stress test: corrupted nested monitoredUser as string id instead of map', () {
        expect(() {
          RelationshipModel.fromJson({
            'id': 'rel-corrupted-1',
            'monitoredUser': 'user-uuid-string-only',
          });
        }, returnsNormally, reason: 'Must not throw unhandled TypeError when nested object is a string');
      });

      test('stress test: corrupted nested config as string instead of map', () {
        expect(() {
          RelationshipModel.fromJson({
            'id': 'rel-corrupted-2',
            'config': 'cfg-uuid-string-only',
          });
        }, returnsNormally, reason: 'Must not throw unhandled TypeError when config is a string');
      });

      test('stress test: integer timestamp for createdAt', () {
        expect(() {
          RelationshipModel.fromJson({
            'id': 'rel-corrupted-3',
            'createdAt': 1712000000000,
          });
        }, returnsNormally, reason: 'Must not throw unhandled TypeError when createdAt is an integer timestamp');
      });

      test('stress test: numeric IDs in JSON', () {
        expect(() {
          RelationshipModel.fromJson({
            'id': 12345,
            'monitoredUserId': 67890,
          });
        }, returnsNormally, reason: 'Must not throw unhandled TypeError when IDs are numeric');
      });
    });

    group('MonitoringConfigModel.fromJson stress testing', () {
      test('handles empty json and defaults properly', () {
        final model = MonitoringConfigModel.fromJson({});
        expect(model.id, '');
        expect(model.relationshipId, '');
        expect(model.currentState, MonitoringState.ACTIVE);
        expect(model.inactivityThresholdMinutes, 180);
        expect(model.checkInGracePeriodMinutes, 30);
        expect(model.escalationGracePeriodMinutes, 30);
        expect(model.locationEnabled, isTrue);
        expect(model.isPaused, isFalse);
        expect(model.scheduleWindows, isEmpty);
        expect(model.timezone, 'Asia/Ho_Chi_Minh');
        expect(model.enabled, isTrue);
      });

      test('handles unknown currentState cleanly without throwing', () {
        final model = MonitoringConfigModel.fromJson({
          'currentState': 'COMPLETELY_NEW_STATE',
        });
        expect(model.currentState, MonitoringState.ACTIVE);
      });

      test('stress test: numeric string or double for minutes thresholds', () {
        expect(() {
          MonitoringConfigModel.fromJson({
            'inactivityThresholdMinutes': '240',
            'checkInGraceMinutes': 45.0,
          });
        }, returnsNormally, reason: 'Must not throw unhandled TypeError when numbers are formatted as string or double');
      });

      test('stress test: scheduleWindows containing non-map or null elements', () {
        expect(() {
          MonitoringConfigModel.fromJson({
            'scheduleWindows': [
              null,
              'invalid-window-string',
              {'dayOfWeek': 0, 'startTime': '08:00', 'endTime': '20:00'},
            ],
          });
        }, returnsNormally, reason: 'Must not throw unhandled TypeError when scheduleWindows contains malformed elements');
      });

      test('stress test: integer epoch timestamp for date fields', () {
        expect(() {
          MonitoringConfigModel.fromJson({
            'lastMeaningfulActivityAt': 1712000000000,
            'pausedUntil': 1712000000000,
          });
        }, returnsNormally, reason: 'Must not throw unhandled TypeError when date fields are epoch ints');
      });
    });

    group('IncidentModel.fromJson stress testing', () {
      test('handles empty json and defaults properly', () {
        final model = IncidentModel.fromJson({});
        expect(model.id, '');
        expect(model.relationshipId, '');
        expect(model.monitoredUserId, '');
        expect(model.status, IncidentStatus.OPEN);
        expect(model.reason, IncidentReason.INACTIVITY);
        expect(model.riskScore, 50);
        expect(model.triggeredAt, isNotNull);
      });

      test('handles unknown status and reason values without throwing', () {
        final model = IncidentModel.fromJson({
          'status': 'BIZARRE_STATUS',
          'reason': 'ALIEN_ATTACK',
        });
        expect(model.status, IncidentStatus.OPEN);
        expect(model.reason, IncidentReason.INACTIVITY);
      });

      test('stress test: riskScore as string or double', () {
        expect(() {
          IncidentModel.fromJson({
            'riskScore': '80',
          });
        }, returnsNormally, reason: 'Must not throw unhandled TypeError when riskScore is a string');
      });

      test('stress test: events field as non-list type', () {
        expect(() {
          IncidentModel.fromJson({
            'events': 'single-event-string',
          });
        }, returnsNormally, reason: 'Must not throw unhandled TypeError when events is a string instead of a list');
      });

      test('stress test: detectedAt / escalatedAt as integer timestamps', () {
        expect(() {
          IncidentModel.fromJson({
            'detectedAt': 1712000000000,
            'escalatedAt': 1712000000000,
          });
        }, returnsNormally, reason: 'Must not throw unhandled TypeError when detectedAt is an epoch int');
      });
    });
  });
}
