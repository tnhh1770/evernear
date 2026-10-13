import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/models/enums.dart';
import 'package:mobile/core/models/incident_model.dart';
import 'package:mobile/core/models/monitoring_config_model.dart';
import 'package:mobile/core/models/relationship_model.dart';
import 'package:mobile/core/models/schedule_window_model.dart';
import 'package:mobile/core/models/user_model.dart';

void main() {
  group('Adversarial Stress Harness: Schedule Window & Weekday Bijectivity', () {
    test('ADV-SCHED-1: Calendar date sweep across 3650 days (10 years) preserves exact weekday bridging', () {
      final startDate = DateTime(2020, 1, 1);
      for (int i = 0; i < 3650; i++) {
        final date = startDate.add(Duration(days: i));
        final dartWeekday = date.weekday; // 1..7 (Mon=1 ... Sun=7)
        final backendDay = ScheduleWindowModel.fromDateTime(date);

        // Assert backend day is strictly 0..6
        expect(backendDay >= 0 && backendDay <= 6, isTrue);

        if (dartWeekday == DateTime.sunday) {
          expect(backendDay, 0, reason: 'Sunday must always map to 0');
        } else {
          expect(backendDay, dartWeekday, reason: 'Mon-Sat ($dartWeekday) must equal backend day ($backendDay)');
        }

        // Test model instance created with this backendDay
        final window = ScheduleWindowModel(
          dayOfWeek: backendDay,
          startTime: '08:00',
          endTime: '20:00',
        );

        expect(window.dayOfWeek, backendDay);
        expect(window.toDartWeekday(), dartWeekday, reason: 'toDartWeekday() must reconstruct original dartWeekday');

        if (backendDay == 0) {
          expect(window.dayNameShort, 'CN');
          expect(window.dayNameFull, 'Chủ Nhật');
          expect(window.nextDayNameFull, 'Thứ Hai');
        } else if (backendDay == 6) {
          expect(window.dayNameShort, 'T7');
          expect(window.dayNameFull, 'Thứ Bảy');
          expect(window.nextDayNameFull, 'Chủ Nhật');
        }
      }
    });

    test('ADV-SCHED-2: Unnormalized dayOfWeek values are safely constrained to 0..6', () {
      for (int input = 0; input <= 70; input++) {
        final window = ScheduleWindowModel(
          dayOfWeek: input,
          startTime: '09:00',
          endTime: '17:00',
        );
        expect(window.dayOfWeek >= 0 && window.dayOfWeek <= 6, isTrue);
        expect(window.dayOfWeek, input % 7);
      }
    });

    test('ADV-SCHED-3: fromJson handles bizarre dayOfWeek types without crashing', () {
      final weirdInputs = [
        {'dayOfWeek': '7'},
        {'dayOfWeek': '0'},
        {'dayOfWeek': '14'},
        {'dayOfWeek': 7.0},
        {'dayOfWeek': null},
        {'day_of_week': 'invalid_string'},
        {'dayOfWeek': true},
        {'dayOfWeek': []},
        {'dayOfWeek': {}},
      ];

      for (final json in weirdInputs) {
        expect(() {
          final model = ScheduleWindowModel.fromJson(json);
          expect(model.dayOfWeek >= 0 && model.dayOfWeek <= 6, isTrue);
        }, returnsNormally);
      }
    });
  });

  group('Adversarial Stress Harness: Extreme DTO Deserialization', () {
    test('ADV-DTO-1: RelationshipModel with extreme chaotic inputs', () {
      final chaoticPayloads = [
        <String, dynamic>{},
        {'id': 999999999999, 'status': 'totally_unknown'},
        {'monitoredUser': 12345, 'monitorUser': true, 'config': 'string_not_map'},
        {'createdAt': '2026-10-07T15:20:00.000Z'},
        {'createdAt': 1712000000000},
        {'createdAt': 0},
        {'createdAt': -100000},
        {'createdAt': 'invalid-date-format'},
        {'monitoredUser': {'id': 123, 'fullName': 'Nguyễn Văn A', 'createdAt': 1712000000000}},
      ];

      for (final payload in chaoticPayloads) {
        expect(() {
          final model = RelationshipModel.fromJson(payload);
          expect(model.id, isA<String>());
          expect(model.status, isA<RelationshipStatus>());
        }, returnsNormally);
      }
    });

    test('ADV-DTO-2: MonitoringConfigModel with extreme chaotic inputs', () {
      final chaoticPayloads = [
        <String, dynamic>{},
        {
          'inactivityThresholdMinutes': '999',
          'checkInGraceMinutes': '60',
          'escalationGraceMinutes': 45.5,
          'scheduleWindows': 'not-a-list',
        },
        {
          'scheduleWindows': [
            null,
            42,
            'string',
            {'dayOfWeek': '7', 'startTime': '10:00', 'endTime': '18:00'},
            {},
          ],
        },
        {
          'lastMeaningfulActivityAt': 1728288000000,
          'pausedUntil': '2026-12-31T23:59:59Z',
        },
        {
          'currentState': 'RANDOM_STRING_XYZ',
          'locationEnabled': false,
          'isPaused': true,
        },
      ];

      for (final payload in chaoticPayloads) {
        expect(() {
          final model = MonitoringConfigModel.fromJson(payload);
          expect(model.id, isA<String>());
          expect(model.currentState, isA<MonitoringState>());
          expect(model.inactivityThresholdMinutes, isA<int>());
        }, returnsNormally);
      }
    });

    test('ADV-DTO-3: IncidentModel with extreme chaotic inputs', () {
      final chaoticPayloads = [
        <String, dynamic>{},
        {
          'id': 98765,
          'status': 'UNKNOWN_INCIDENT_STATUS',
          'reason': 'CUSTOM_REASON',
          'riskScore': '95.5',
          'events': 'single_event_payload',
        },
        {
          'riskScore': 100,
          'events': [
            'event-id-1',
            {'type': 'CHECK_IN_MISSED'},
          ],
        },
        {
          'detectedAt': 1712000000000,
          'triggeredAt': 1712000000000,
          'escalatedAt': 1712000000000,
          'acknowledgedAt': 1712000000000,
          'resolvedAt': 1712000000000,
        },
        {
          'detectedAt': '2026-10-07T08:00:00Z',
          'riskScore': null,
        },
      ];

      for (final payload in chaoticPayloads) {
        expect(() {
          final model = IncidentModel.fromJson(payload);
          expect(model.id, isA<String>());
          expect(model.status, isA<IncidentStatus>());
          expect(model.riskScore, isA<int>());
        }, returnsNormally);
      }
    });

    test('ADV-DTO-4: UserModel with extreme chaotic inputs', () {
      final chaoticPayloads = [
        <String, dynamic>{},
        {'id': 12345, 'phone': '0912345678'},
        {'createdAt': 1712000000000, 'updatedAt': '2026-10-07T12:00:00Z'},
        {'email': null, 'fullName': null},
      ];

      for (final payload in chaoticPayloads) {
        expect(() {
          final model = UserModel.fromJson(payload);
          expect(model.id, isA<String>());
          expect(model.email, isA<String>());
          expect(model.fullName, isA<String>());
        }, returnsNormally);
      }
    });
  });
}
