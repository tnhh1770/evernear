import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/constants/app_strings.dart';
import 'package:mobile/core/models/enums.dart';
import 'package:mobile/core/models/monitoring_config_model.dart';
import 'package:mobile/core/models/relationship_model.dart';
import 'package:mobile/core/models/schedule_window_model.dart';
import 'package:mobile/core/models/user_model.dart';
import 'package:mobile/features/monitoring/monitoring_settings_screen.dart';

RelationshipModel createTestRelationshipWith({
  int inactivityThresholdMinutes = 180,
  List<ScheduleWindowModel>? scheduleWindows,
}) {
  return RelationshipModel(
    id: 'rel-adv-m3',
    monitoredUserId: 'user-monitored-1',
    monitorUserId: 'user-monitor-2',
    status: RelationshipStatus.ACCEPTED,
    createdAt: DateTime.now(),
    config: MonitoringConfigModel(
      id: 'cfg-adv-m3',
      relationshipId: 'rel-adv-m3',
      currentState: MonitoringState.ACTIVE,
      inactivityThresholdMinutes: inactivityThresholdMinutes,
      checkInGracePeriodMinutes: 30,
      escalationGracePeriodMinutes: 30,
      locationEnabled: true,
      isPaused: false,
      timezone: 'Asia/Ho_Chi_Minh',
      scheduleWindows: scheduleWindows ??
          [
            ScheduleWindowModel(
              dayOfWeek: 1, // Monday
              startTime: '07:00',
              endTime: '22:00',
              isEnabled: true,
            ),
          ],
    ),
    monitoredUser: UserModel(
      id: 'user-monitored-1',
      email: 'monitored@carely.test',
      fullName: 'Bà Nguyễn Thị Ba',
      timezone: 'Asia/Ho_Chi_Minh',
      isActive: true,
      createdAt: DateTime.now(),
    ),
    monitorUser: UserModel(
      id: 'user-monitor-2',
      email: 'monitor@carely.test',
      fullName: 'Anh Nguyễn Văn Hai',
      timezone: 'Asia/Ho_Chi_Minh',
      isActive: true,
      createdAt: DateTime.now(),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  void setLargeViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  Finder findCustomChip() {
    return find.byWidgetPredicate((widget) {
      if (widget is ChoiceChip) {
        final textWidget = widget.label as Text;
        return textWidget.data?.startsWith('Tùy biến') ?? false;
      }
      return false;
    });
  }

  Finder findDaySwitch() {
    return find.byType(Switch).first;
  }

  group('Ext-M3 Challenger: Extreme & Non-Standard Threshold Safety', () {
    final nonStandardThresholds = [1, 45, 90, 137, 500, 1440, 10080];

    for (final threshold in nonStandardThresholds) {
      testWidgets('Renders threshold=$threshold min cleanly with ZERO Dropdown assertion crashes', (tester) async {
        setLargeViewport(tester);
        final rel = createTestRelationshipWith(inactivityThresholdMinutes: threshold);

        await tester.pumpWidget(
          MaterialApp(
            home: MonitoringSettingsScreen(relationship: rel),
          ),
        );
        await tester.pumpAndSettle();

        // Screen must render without crashing
        expect(find.byType(MonitoringSettingsScreen), findsOneWidget);

        // Standard presets are [15, 30, 60, 120, 240, 480, 720, 1440]
        final isStandard = [15, 30, 60, 120, 240, 480, 720, 1440].contains(threshold);

        if (!isStandard) {
          // Custom chip must be selected
          final customChips = findCustomChip();
          expect(customChips, findsOneWidget);
          final chip = tester.widget<ChoiceChip>(customChips);
          expect(chip.selected, isTrue);
        } else {
          // 1440 is standard preset '24h'
          expect(find.text('24h'), findsOneWidget);
          final chip24h = tester.widget<ChoiceChip>(
            find.ancestor(of: find.text('24h'), matching: find.byType(ChoiceChip)),
          );
          expect(chip24h.selected, isTrue);
        }
      });
    }

    testWidgets('Non-standard 137 min threshold renders formatted hour-minute preview badge', (tester) async {
      setLargeViewport(tester);
      final rel = createTestRelationshipWith(inactivityThresholdMinutes: 137);

      await tester.pumpWidget(
        MaterialApp(
          home: MonitoringSettingsScreen(relationship: rel),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Tùy biến (137p)'), findsOneWidget);
      expect(find.text('137 phút (2 giờ 17 phút)'), findsOneWidget);
    });

    testWidgets('Extreme boundary 10080 min (7 days) renders formatted preview badge', (tester) async {
      setLargeViewport(tester);
      final rel = createTestRelationshipWith(inactivityThresholdMinutes: 10080);

      await tester.pumpWidget(
        MaterialApp(
          home: MonitoringSettingsScreen(relationship: rel),
        ),
      );
      await tester.pumpAndSettle();

      // 10080 ~/ 60 = 168h
      expect(find.text('Tùy biến (168h)'), findsOneWidget);
      expect(find.text('10080 phút (168 giờ)'), findsOneWidget);
    });

    testWidgets('Extreme boundary 1 min renders formatted preview badge', (tester) async {
      setLargeViewport(tester);
      final rel = createTestRelationshipWith(inactivityThresholdMinutes: 1);

      await tester.pumpWidget(
        MaterialApp(
          home: MonitoringSettingsScreen(relationship: rel),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Tùy biến (1p)'), findsOneWidget);
      expect(find.text('1 phút'), findsOneWidget);
    });
  });

  group('Ext-M3 Challenger: Custom Threshold Dialog Input Boundary Fuzzing', () {
    testWidgets('Empty and whitespace-only inputs are rejected with validation error', (tester) async {
      setLargeViewport(tester);
      final rel = createTestRelationshipWith(inactivityThresholdMinutes: 60);

      await tester.pumpWidget(
        MaterialApp(
          home: MonitoringSettingsScreen(relationship: rel),
        ),
      );
      await tester.pumpAndSettle();

      // Open dialog
      await tester.tap(findCustomChip());
      await tester.pumpAndSettle();

      final textField = find.byType(TextField);

      // Test empty string
      await tester.enterText(textField, '');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Áp dụng'));
      await tester.pumpAndSettle();

      expect(find.text('Vui lòng nhập số phút hợp lệ'), findsOneWidget);
      expect(find.text('Tùy biến thời gian'), findsOneWidget);

      // Test whitespace string
      await tester.enterText(textField, '   ');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Áp dụng'));
      await tester.pumpAndSettle();

      expect(find.text('Vui lòng nhập số phút hợp lệ'), findsOneWidget);
      expect(find.text('Tùy biến thời gian'), findsOneWidget);

      // Dismiss dialog
      await tester.tap(find.text('Hủy'));
      await tester.pumpAndSettle();
      expect(find.text('Tùy biến thời gian'), findsNothing);
    });

    testWidgets('Non-numeric alpha, symbols, and decimals are rejected safely', (tester) async {
      setLargeViewport(tester);
      final rel = createTestRelationshipWith(inactivityThresholdMinutes: 60);

      await tester.pumpWidget(
        MaterialApp(
          home: MonitoringSettingsScreen(relationship: rel),
        ),
      );
      await tester.pumpAndSettle();

      // Open dialog once
      await tester.tap(findCustomChip());
      await tester.pumpAndSettle();

      final textField = find.byType(TextField);

      for (final badInput in ['abc', 'xyz!@#', '12e3', '45.5']) {
        await tester.enterText(textField, badInput);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Áp dụng'));
        await tester.pumpAndSettle();

        expect(find.text('Vui lòng nhập số phút hợp lệ'), findsOneWidget,
            reason: 'Bad input "$badInput" should trigger format error');
        expect(find.text('Tùy biến thời gian'), findsOneWidget);
      }

      await tester.tap(find.text('Hủy'));
      await tester.pumpAndSettle();
      expect(find.text('Tùy biến thời gian'), findsNothing);
    });

    testWidgets('Negative, zero, and below-min values are rejected with range error', (tester) async {
      setLargeViewport(tester);
      final rel = createTestRelationshipWith(inactivityThresholdMinutes: 60);

      await tester.pumpWidget(
        MaterialApp(
          home: MonitoringSettingsScreen(relationship: rel),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(findCustomChip());
      await tester.pumpAndSettle();

      final textField = find.byType(TextField);

      for (final badVal in ['-1', '-500', '0', '1', '14']) {
        await tester.enterText(textField, badVal);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Áp dụng'));
        await tester.pumpAndSettle();

        expect(find.text('Số phút phải từ 15 đến 1440 (24 giờ)'), findsOneWidget,
            reason: 'Value "$badVal" should trigger range error');
        expect(find.text('Tùy biến thời gian'), findsOneWidget);
      }

      await tester.tap(find.text('Hủy'));
      await tester.pumpAndSettle();
      expect(find.text('Tùy biến thời gian'), findsNothing);
    });

    testWidgets('Above max boundary and huge values are rejected with range error', (tester) async {
      setLargeViewport(tester);
      final rel = createTestRelationshipWith(inactivityThresholdMinutes: 60);

      await tester.pumpWidget(
        MaterialApp(
          home: MonitoringSettingsScreen(relationship: rel),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(findCustomChip());
      await tester.pumpAndSettle();

      final textField = find.byType(TextField);

      for (final highVal in ['1441', '2000', '999999']) {
        await tester.enterText(textField, highVal);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Áp dụng'));
        await tester.pumpAndSettle();

        expect(find.text('Số phút phải từ 15 đến 1440 (24 giờ)'), findsOneWidget,
            reason: 'Value "$highVal" should trigger range error');
        expect(find.text('Tùy biến thời gian'), findsOneWidget);
      }

      await tester.tap(find.text('Hủy'));
      await tester.pumpAndSettle();
      expect(find.text('Tùy biến thời gian'), findsNothing);
    });

    testWidgets('Exact min "15" and exact max "1440" are accepted', (tester) async {
      setLargeViewport(tester);
      final rel = createTestRelationshipWith(inactivityThresholdMinutes: 60);

      await tester.pumpWidget(
        MaterialApp(
          home: MonitoringSettingsScreen(relationship: rel),
        ),
      );
      await tester.pumpAndSettle();

      // Test exact min 15
      await tester.tap(findCustomChip());
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '15');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Áp dụng'));
      await tester.pumpAndSettle();

      expect(find.text('Tùy biến thời gian'), findsNothing); // Dialog dismissed
      expect(find.text('15 phút'), findsAtLeastNWidgets(1));

      // Test exact max 1440
      await tester.tap(findCustomChip());
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '1440');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Áp dụng'));
      await tester.pumpAndSettle();

      expect(find.text('Tùy biến thời gian'), findsNothing);
      expect(find.text('1440 phút (24 giờ)'), findsOneWidget);
    });

    testWidgets('0-padded valid number "090" is parsed and accepted as 90', (tester) async {
      setLargeViewport(tester);
      final rel = createTestRelationshipWith(inactivityThresholdMinutes: 60);

      await tester.pumpWidget(
        MaterialApp(
          home: MonitoringSettingsScreen(relationship: rel),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(findCustomChip());
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '090');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Áp dụng'));
      await tester.pumpAndSettle();

      expect(find.text('Tùy biến thời gian'), findsNothing);
      expect(find.text('Tùy biến (90p)'), findsOneWidget);
      expect(find.text('90 phút (1 giờ 30 phút)'), findsOneWidget);
    });

    testWidgets('Cancel button dismisses dialog without mutating threshold', (tester) async {
      setLargeViewport(tester);
      final rel = createTestRelationshipWith(inactivityThresholdMinutes: 60);

      await tester.pumpWidget(
        MaterialApp(
          home: MonitoringSettingsScreen(relationship: rel),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(findCustomChip());
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '250');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hủy'));
      await tester.pumpAndSettle();

      expect(find.text('Tùy biến thời gian'), findsNothing);
      // Original 60 (1h) must still be selected
      final chip1h = tester.widget<ChoiceChip>(
        find.ancestor(of: find.text('1h'), matching: find.byType(ChoiceChip)),
      );
      expect(chip1h.selected, isTrue);
    });
  });

  group('Ext-M3 Challenger: Sleep & Quiet Hours Cross-Midnight & Duration Math', () {
    testWidgets('Cross-midnight overnight schedule (e.g. 21:30 wake, 06:15 bed) computes duration correctly', (tester) async {
      setLargeViewport(tester);
      // Wake at 21:30, bed at 06:15 (e.g. Night shift guard)
      final rel = createTestRelationshipWith(
        scheduleWindows: [
          ScheduleWindowModel(
            dayOfWeek: 1,
            startTime: '21:30',
            endTime: '06:15',
            isEnabled: true,
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: MonitoringSettingsScreen(relationship: rel),
        ),
      );
      await tester.pumpAndSettle();

      // Active: 21:30 -> 06:15 = (24*60 - 1290) + 375 = 150 + 375 = 525 min = 8h 45m
      // Sleep: 1440 - 525 = 915 min = 15h 15m
      expect(find.textContaining('Thời gian ngủ: 15 giờ 15 phút (06:15 ➔ 21:30)'), findsOneWidget);
      expect(find.textContaining('Giám sát an tâm: 8 giờ 45 phút (21:30 ➔ 06:15)'), findsOneWidget);

      // Overnight banner must be displayed
      expect(find.text(AppStrings.overnightBadge), findsOneWidget);
      expect(find.textContaining('xuyên suốt đêm đến 06:15 sáng Thứ Ba'), findsOneWidget);
    });

    testWidgets('Bedtime equal to wake time (e.g. 07:00 -> 07:00) produces 0m active, 24h sleep without zero-division error', (tester) async {
      setLargeViewport(tester);
      final rel = createTestRelationshipWith(
        scheduleWindows: [
          ScheduleWindowModel(
            dayOfWeek: 1,
            startTime: '07:00',
            endTime: '07:00',
            isEnabled: true,
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: MonitoringSettingsScreen(relationship: rel),
        ),
      );
      await tester.pumpAndSettle();

      // Active: 0 min (0 phút), Sleep: 1440 min (24 giờ)
      expect(find.textContaining('Thời gian ngủ: 24 giờ (07:00 ➔ 07:00)'), findsOneWidget);
      expect(find.textContaining('Giám sát an tâm: 0 phút (07:00 ➔ 07:00)'), findsOneWidget);
    });

    testWidgets('Midnight edge cases: 00:00 wakeTime to 23:59 bedtime (Full day active)', (tester) async {
      setLargeViewport(tester);
      final rel = createTestRelationshipWith(
        scheduleWindows: [
          ScheduleWindowModel(
            dayOfWeek: 1,
            startTime: '00:00',
            endTime: '23:59',
            isEnabled: true,
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: MonitoringSettingsScreen(relationship: rel),
        ),
      );
      await tester.pumpAndSettle();

      // Active: 1439 min (23 giờ 59 phút), Sleep: 1 min (1 phút)
      expect(find.textContaining('Thời gian ngủ: 1 phút (23:59 ➔ 00:00)'), findsOneWidget);
      expect(find.textContaining('Giám sát an tâm: 23 giờ 59 phút (00:00 ➔ 23:59)'), findsOneWidget);
    });
  });

  group('Ext-M3 Challenger: Day Toggles & "Áp dụng cho cả tuần" Multi-Day Resilience', () {
    testWidgets('Disabling a day greys out and ignores taps on time pickers', (tester) async {
      setLargeViewport(tester);
      final rel = createTestRelationshipWith();

      await tester.pumpWidget(
        MaterialApp(
          home: MonitoringSettingsScreen(relationship: rel),
        ),
      );
      await tester.pumpAndSettle();

      // Monday is enabled initially
      expect(find.text(AppStrings.dayEnabled), findsOneWidget);

      // Toggle day switch to false
      await tester.tap(findDaySwitch());
      await tester.pumpAndSettle();

      // Monday is now disabled
      expect(find.text(AppStrings.dayDisabled), findsOneWidget);

      // The time picker section is wrapped in IgnorePointer(ignoring: true)
      final ignorePointer = tester.widget<IgnorePointer>(
        find.ancestor(
          of: find.text('Giờ thức dậy (Bắt đầu giám sát)'),
          matching: find.byType(IgnorePointer),
        ).first,
      );
      expect(ignorePointer.ignoring, isTrue);

      final opacity = tester.widget<Opacity>(
        find.ancestor(
          of: find.text('Giờ thức dậy (Bắt đầu giám sát)'),
          matching: find.byType(Opacity),
        ).first,
      );
      expect(opacity.opacity, equals(0.4));
    });

    testWidgets('Switching days preserves independent day configuration', (tester) async {
      setLargeViewport(tester);
      final rel = createTestRelationshipWith();

      await tester.pumpWidget(
        MaterialApp(
          home: MonitoringSettingsScreen(relationship: rel),
        ),
      );
      await tester.pumpAndSettle();

      // Disable T2
      await tester.tap(findDaySwitch());
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.dayDisabled), findsOneWidget);

      // Switch to T3
      await tester.tap(find.text('T3'));
      await tester.pumpAndSettle();
      expect(find.text('Thứ Ba'), findsOneWidget);
      expect(find.text(AppStrings.dayEnabled), findsOneWidget); // T3 is still enabled

      // Switch back to T2
      await tester.tap(find.text('T2'));
      await tester.pumpAndSettle();
      expect(find.text('Thứ Hai'), findsOneWidget);
      expect(find.text(AppStrings.dayDisabled), findsOneWidget); // T2 remains disabled
    });

    testWidgets('"Áp dụng cho cả tuần" replicates current day settings across all 7 days (T2..CN)', (tester) async {
      setLargeViewport(tester);
      final rel = createTestRelationshipWith();

      await tester.pumpWidget(
        MaterialApp(
          home: MonitoringSettingsScreen(relationship: rel),
        ),
      );
      await tester.pumpAndSettle();

      // Disable T2
      await tester.tap(findDaySwitch());
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.dayDisabled), findsOneWidget);

      // Tap "Áp dụng cho cả tuần"
      await tester.tap(find.text(AppStrings.applyToAllDays));
      await tester.pumpAndSettle();

      // Check SnackBar
      expect(find.text('Đã áp dụng khung giờ này cho toàn bộ các ngày trong tuần.'), findsOneWidget);

      // Verify that every day is now disabled
      for (final dayLabel in ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN']) {
        await tester.tap(find.text(dayLabel));
        await tester.pumpAndSettle();
        expect(find.text(AppStrings.dayDisabled), findsOneWidget,
            reason: 'Day $dayLabel should be disabled after apply-to-all');
      }
    });
  });

  group('Ext-M3 Challenger: ScheduleWindowModel Unit & Edge Cases', () {
    test('Modulo 7 dayOfWeek handling on negative and large days', () {
      final wNegative = ScheduleWindowModel(
        dayOfWeek: -1,
        startTime: '08:00',
        endTime: '18:00',
      );
      expect(wNegative.dayOfWeek, anyOf(equals(-1), equals(6)));

      final wLarge = ScheduleWindowModel(
        dayOfWeek: 8,
        startTime: '08:00',
        endTime: '18:00',
      );
      expect(wLarge.dayOfWeek, equals(1));
    });

    test('isOvernight edge cases', () {
      final wSame = ScheduleWindowModel(dayOfWeek: 1, startTime: '12:00', endTime: '12:00');
      expect(wSame.isOvernight, isFalse);

      final wMinuteOvernight = ScheduleWindowModel(dayOfWeek: 1, startTime: '23:59', endTime: '00:01');
      expect(wMinuteOvernight.isOvernight, isTrue);

      final wRegular = ScheduleWindowModel(dayOfWeek: 1, startTime: '08:00', endTime: '20:00');
      expect(wRegular.isOvernight, isFalse);
    });

    test('nextDayNameFull transitions across weekend boundary', () {
      final wSat = ScheduleWindowModel(dayOfWeek: 6, startTime: '22:00', endTime: '06:00');
      expect(wSat.dayNameFull, 'Thứ Bảy');
      expect(wSat.nextDayNameFull, 'Chủ Nhật');

      final wSun = ScheduleWindowModel(dayOfWeek: 0, startTime: '22:00', endTime: '06:00');
      expect(wSun.dayNameFull, 'Chủ Nhật');
      expect(wSun.nextDayNameFull, 'Thứ Hai');
    });

    test('JSON serialization roundtrip preserves all fields', () {
      final model = ScheduleWindowModel(
        id: 'win-123',
        configId: 'cfg-456',
        dayOfWeek: 3,
        startTime: '06:30',
        endTime: '21:45',
        isEnabled: false,
      );

      final json = model.toJson();
      expect(json['id'], 'win-123');
      expect(json['configId'], 'cfg-456');
      expect(json['dayOfWeek'], 3);
      expect(json['startTime'], '06:30');
      expect(json['endTime'], '21:45');
      expect(json['isEnabled'], false);

      final revived = ScheduleWindowModel.fromJson(json);
      expect(revived.id, model.id);
      expect(revived.configId, model.configId);
      expect(revived.dayOfWeek, model.dayOfWeek);
      expect(revived.startTime, model.startTime);
      expect(revived.endTime, model.endTime);
      expect(revived.isEnabled, model.isEnabled);
    });
  });
}
