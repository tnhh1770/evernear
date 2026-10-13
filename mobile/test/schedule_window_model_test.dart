import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/models/schedule_window_model.dart';

void main() {
  group('ScheduleWindowModel Tests', () {
    test('parses from and converts to JSON correctly', () {
      final json = {
        'id': 'win-1',
        'configId': 'cfg-1',
        'dayOfWeek': 1,
        'startTime': '07:30',
        'endTime': '21:45',
        'isEnabled': true,
      };

      final model = ScheduleWindowModel.fromJson(json);
      expect(model.id, 'win-1');
      expect(model.configId, 'cfg-1');
      expect(model.dayOfWeek, 1);
      expect(model.startTime, '07:30');
      expect(model.endTime, '21:45');
      expect(model.isEnabled, true);
      expect(model.isOvernight, false);

      final outJson = model.toJson();
      expect(outJson['dayOfWeek'], 1);
      expect(outJson['startTime'], '07:30');
      expect(outJson['endTime'], '21:45');
      expect(outJson['isEnabled'], true);
    });

    test('detects overnight window when startTime > endTime', () {
      final overnight = ScheduleWindowModel(
        dayOfWeek: 1, // Monday
        startTime: '22:00',
        endTime: '06:00',
        isEnabled: true,
      );
      expect(overnight.isOvernight, true);
      expect(overnight.dayNameShort, 'T2');
      expect(overnight.dayNameFull, 'Thứ Hai');
      expect(overnight.nextDayNameFull, 'Thứ Ba');

      final daytime = ScheduleWindowModel(
        dayOfWeek: 2, // Tuesday
        startTime: '08:00',
        endTime: '20:00',
        isEnabled: true,
      );
      expect(daytime.isOvernight, false);
      expect(daytime.dayNameShort, 'T3');
      expect(daytime.dayNameFull, 'Thứ Ba');
    });

    test('correctly maps Sunday (0) and wrap-around next day', () {
      final sunday = ScheduleWindowModel(
        dayOfWeek: 0, // Sunday
        startTime: '23:00',
        endTime: '07:00',
        isEnabled: true,
      );
      expect(sunday.isOvernight, true);
      expect(sunday.dayNameShort, 'CN');
      expect(sunday.dayNameFull, 'Chủ Nhật');
      expect(sunday.nextDayNameFull, 'Thứ Hai');
    });

    test('copyWith works properly without mutating existing object', () {
      final original = ScheduleWindowModel(
        dayOfWeek: 3,
        startTime: '07:00',
        endTime: '17:00',
        isEnabled: true,
      );

      final updated = original.copyWith(
        endTime: '23:00',
        isEnabled: false,
      );

      expect(original.endTime, '17:00');
      expect(original.isEnabled, true);
      expect(updated.dayOfWeek, 3);
      expect(updated.startTime, '07:00');
      expect(updated.endTime, '23:00');
      expect(updated.isEnabled, false);
    });

    test('bidirectional Dart weekday conversions work correctly across all days', () {
      // Dart DateTime.weekday definitions:
      // Monday = 1 ... Saturday = 6, Sunday = 7
      expect(ScheduleWindowModel.fromDartWeekday(DateTime.monday), 1);
      expect(ScheduleWindowModel.fromDartWeekday(DateTime.tuesday), 2);
      expect(ScheduleWindowModel.fromDartWeekday(DateTime.wednesday), 3);
      expect(ScheduleWindowModel.fromDartWeekday(DateTime.thursday), 4);
      expect(ScheduleWindowModel.fromDartWeekday(DateTime.friday), 5);
      expect(ScheduleWindowModel.fromDartWeekday(DateTime.saturday), 6);
      expect(ScheduleWindowModel.fromDartWeekday(DateTime.sunday), 0);

      // fromDateTime test
      final sundayDate = DateTime(2026, 10, 11); // Oct 11, 2026 is Sunday
      expect(sundayDate.weekday, DateTime.sunday);
      expect(ScheduleWindowModel.fromDateTime(sundayDate), 0);

      final mondayDate = DateTime(2026, 10, 12); // Oct 12, 2026 is Monday
      expect(mondayDate.weekday, DateTime.monday);
      expect(ScheduleWindowModel.fromDateTime(mondayDate), 1);

      // toDartWeekday test
      for (int carelyDay = 0; carelyDay <= 6; carelyDay++) {
        final window = ScheduleWindowModel(
          dayOfWeek: carelyDay,
          startTime: '08:00',
          endTime: '18:00',
        );
        final dartWeekday = window.toDartWeekday();
        if (carelyDay == 0) {
          expect(dartWeekday, DateTime.sunday);
        } else {
          expect(dartWeekday, carelyDay);
        }
      }
    });

    test('normalizes dayOfWeek % 7 in constructor and fromJson', () {
      // Unnormalized constructor dayOfWeek (e.g. passing Dart DateTime.sunday = 7 directly)
      final modelFrom7 = ScheduleWindowModel(
        dayOfWeek: 7,
        startTime: '08:00',
        endTime: '18:00',
      );
      expect(modelFrom7.dayOfWeek, 0);
      expect(modelFrom7.dayNameShort, 'CN');

      final modelFrom14 = ScheduleWindowModel(
        dayOfWeek: 14,
        startTime: '08:00',
        endTime: '18:00',
      );
      expect(modelFrom14.dayOfWeek, 0);

      final modelFrom8 = ScheduleWindowModel(
        dayOfWeek: 8,
        startTime: '08:00',
        endTime: '18:00',
      );
      expect(modelFrom8.dayOfWeek, 1);
      expect(modelFrom8.dayNameShort, 'T2');

      // fromJson with unnormalized integer or string
      final json7 = ScheduleWindowModel.fromJson({
        'dayOfWeek': 7,
        'startTime': '09:00',
        'endTime': '17:00',
      });
      expect(json7.dayOfWeek, 0);

      final jsonString7 = ScheduleWindowModel.fromJson({
        'day_of_week': '7',
        'startTime': '09:00',
        'endTime': '17:00',
      });
      expect(jsonString7.dayOfWeek, 0);
    });

    test('provides semantic convenience getters wakeTime and bedtime for quiet hours', () {
      final window = ScheduleWindowModel(
        dayOfWeek: 1,
        startTime: '06:30',
        endTime: '22:15',
      );
      expect(window.wakeTime, '06:30');
      expect(window.bedtime, '22:15');
      expect(window.wakeTime, window.startTime);
      expect(window.bedtime, window.endTime);
    });
  });
}
