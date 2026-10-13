import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/constants/app_strings.dart';
import 'package:mobile/core/i18n/app_localizations.dart';
import 'package:mobile/core/i18n/locale_catalog_registry.dart';
import 'package:mobile/core/models/enums.dart';
import 'package:mobile/core/models/monitoring_config_model.dart';
import 'package:mobile/core/models/relationship_model.dart';
import 'package:mobile/core/models/schedule_window_model.dart';
import 'package:mobile/core/models/user_model.dart';
import 'package:mobile/features/monitoring/monitoring_settings_screen.dart';
import 'package:mobile/features/pairing/qr_code_parser.dart';

RelationshipModel buildChallengerRelationship({
  int inactivityThresholdMinutes = 180,
  int checkInGracePeriodMinutes = 30,
  List<ScheduleWindowModel>? scheduleWindows,
}) {
  return RelationshipModel(
    id: 'rel-challenger-m4',
    monitoredUserId: 'user-monitored-1',
    monitorUserId: 'user-monitor-2',
    status: RelationshipStatus.ACCEPTED,
    createdAt: DateTime.now(),
    config: MonitoringConfigModel(
      id: 'cfg-challenger-m4',
      relationshipId: 'rel-challenger-m4',
      currentState: MonitoringState.ACTIVE,
      inactivityThresholdMinutes: inactivityThresholdMinutes,
      checkInGracePeriodMinutes: checkInGracePeriodMinutes,
      escalationGracePeriodMinutes: 30,
      locationEnabled: true,
      isPaused: false,
      timezone: 'Asia/Ho_Chi_Minh',
      scheduleWindows: scheduleWindows ??
          [
            ScheduleWindowModel(
              dayOfWeek: 1,
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

  void setTestViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  // =========================================================================
  // 1. DYNAMIC LOCALE CATALOG RESOLUTION & ADVERSARIAL FALLBACK
  // =========================================================================
  group('1. Dynamic Locale Catalog Resolution & Fallback Stress', () {
    test('1.1 Extreme unsupported locale codes fall back to English then Vietnamese safely', () {
      final hostileLocales = [
        'klingon',
        'xx_YY',
        '12345',
        '!@#\$%',
        'valyrian',
        'elvish',
        'und',
        'root',
        'qaa', // Private use code
        'zh-Hant-HK-x-custom',
      ];

      for (final code in hostileLocales) {
        final l10n = AppLocalizations(Locale(code));
        expect(l10n.tr('check_in_button'), equals('I am okay'),
            reason: 'Hostile locale "$code" must fall back to English');
        expect(l10n.tr('app_name'), equals('Carely'),
            reason: 'Hostile locale "$code" must resolve app_name');
      }
    });

    test('1.2 All 60 languages in registry resolve standard keys without error', () {
      for (final lang in LocaleCatalogRegistry.allLanguages) {
        final l10n = AppLocalizations(Locale(lang.code));
        final translated = l10n.tr('check_in_button');
        expect(translated, isNotEmpty,
            reason: 'Language ${lang.code} should translate check_in_button');
      }
    });

    test('1.3 Adversarial missing key formats: underscores, dots, hyphens, unicode, empty', () {
      final l10n = AppLocalizations(const Locale('en'));

      expect(l10n.tr(''), equals(''));
      expect(l10n.tr('---'), equals('---'));
      expect(l10n.tr('___'), equals('___'));
      expect(l10n.tr('nested.key.path.deep'), equals('Nested Key Path Deep'));
      expect(l10n.tr('mixed_hyphen-and_underscore'), equals('Mixed Hyphen And Underscore'));
      expect(l10n.tr('special@key#name'), equals('Special@key#name'));
      expect(l10n.tr('   padded_key   '), equals('Padded Key'));
    });

    test('1.4 Placeholders interpolation resilience with regex symbols and missing values', () {
      final l10n = AppLocalizations(const Locale('en'));

      // Args contains regex meta characters: $, ^, *, (, ), [, ], \, ?
      final result1 = l10n.tr('check_in_battery_current', args: {'level': r'$100\d+'});
      expect(result1, equals(r'Current battery level: $100\d+%'));

      // Missing argument: placeholder remains unchanged without crashing
      final result2 = l10n.tr('check_in_battery_current', args: {});
      expect(result2, equals('Current battery level: {level}%'));

      // Extra unreferenced arguments are safely ignored
      final result3 = l10n.tr('check_in_battery_current', args: {'level': '85', 'unused': 'xyz'});
      expect(result3, equals('Current battery level: 85%'));
    });

    test('1.5 StaticTr fallback behavior when globalLocaleCode is corrupted', () {
      AppLocalizations.globalLocaleCode = 'corrupted_non_existent';
      final res = AppLocalizations.staticTr('check_in_button');
      expect(res, equals('I am okay'));

      AppLocalizations.globalLocaleCode = 'vi';
      expect(AppLocalizations.staticTr('check_in_button'), equals('Tôi vẫn ổn'));
    });
  });

  // =========================================================================
  // 2. QR CODE PARSER ADVERSARIAL URI & MALFORMED INPUTS
  // =========================================================================
  group('2. QR Code Parser Adversarial Inputs', () {
    test('2.1 Malformed, boundary, and hostile URI schemes', () {
      expect(QrCodeParser.extractInviteCode(null), isNull);
      expect(QrCodeParser.extractInviteCode(''), isNull);
      expect(QrCodeParser.extractInviteCode('   \n\r\t   '), isNull);

      // Invalid schemes
      expect(QrCodeParser.extractInviteCode('javascript:alert(1)'), isNull);
      expect(QrCodeParser.extractInviteCode('data:text/html,<html></html>'), isNull);
      expect(QrCodeParser.extractInviteCode('file:///etc/passwd'), isNull);
      expect(QrCodeParser.extractInviteCode('tel:+1234567890'), isNull);
    });

    test('2.2 Deep link carely:// scheme variations', () {
      // Standard deep link
      expect(QrCodeParser.extractInviteCode('carely://invite?code=CR-ABC12345'), equals('CR-ABC12345'));

      // Lowercase code parameter is normalized to uppercase
      expect(QrCodeParser.extractInviteCode('carely://invite?code=cr-abc12345'), equals('CR-ABC12345'));

      // Mixed case scheme
      expect(QrCodeParser.extractInviteCode('CARELY://INVITE?code=CR-TEST99'), equals('CR-TEST99'));

      // Multiple query parameters
      expect(QrCodeParser.extractInviteCode('carely://invite?ref=mobile&code=CR-MULTI123&user=admin'), equals('CR-MULTI123'));

      // Empty or missing code query parameter
      expect(QrCodeParser.extractInviteCode('carely://invite?code='), isNull);
      expect(QrCodeParser.extractInviteCode('carely://invite?code=   '), isNull);
      expect(QrCodeParser.extractInviteCode('carely://invite'), isNull);
      expect(QrCodeParser.extractInviteCode('carely://'), isNull);
    });

    test('2.3 URI percent-encoding and malformed percent sequences', () {
      // Valid percent-encoding (dash encoded as %2D)
      expect(QrCodeParser.extractInviteCode('carely://invite?code=CR%2D123456'), equals('CR-123456'));

      // Malformed percent-encodings: must not throw FormatException
      expect(() => QrCodeParser.extractInviteCode('carely://invite?code=%ZZ'), returnsNormally);
      expect(() => QrCodeParser.extractInviteCode('carely://invite?code=%'), returnsNormally);
      expect(() => QrCodeParser.extractInviteCode('carely://invite?code=CR-%E0%A4%A%ZZ'), returnsNormally);
    });

    test('2.4 Web URLs (http / https)', () {
      expect(QrCodeParser.extractInviteCode('https://carely.app/invite?code=CR-WEB001'), equals('CR-WEB001'));
      expect(QrCodeParser.extractInviteCode('http://staging.carely.vn/invite?code=CR-STG002'), equals('CR-STG002'));
      expect(QrCodeParser.extractInviteCode('https://carely.app/invite'), isNull);
      expect(QrCodeParser.extractInviteCode('https://carely.app/invite?code='), isNull);
    });

    test('2.5 Raw alphanumeric codes and prefix matching', () {
      // Standard prefix embedded in text
      expect(QrCodeParser.extractInviteCode('Your invite code is CR-ALPHA999 enjoy!'), equals('CR-ALPHA999'));

      // Raw code with hyphens
      expect(QrCodeParser.extractInviteCode('CR-123456'), equals('CR-123456'));
      expect(QrCodeParser.extractInviteCode('ABC-1234-XYZ'), equals('ABC-1234-XYZ'));

      // Short raw codes below min length (6)
      expect(QrCodeParser.extractInviteCode('CR-'), isNull);
      expect(QrCodeParser.extractInviteCode('12345'), isNull);
      expect(QrCodeParser.extractInviteCode('123456'), equals('123456'));
    });

    test('2.6 Stress test: 50KB payload does not hang or overflow', () {
      final huge = 'carely://invite?code=CR-${'X' * 50000}';
      final sw = Stopwatch()..start();
      final res = QrCodeParser.extractInviteCode(huge);
      sw.stop();

      expect(res, isNotNull);
      expect(sw.elapsedMilliseconds, lessThan(2000));
    });
  });

  // =========================================================================
  // 3. INACTIVITY THRESHOLD INPUTS & ZERO DROPDOWN ASSERTION CRASHES
  // =========================================================================
  group('3. Inactivity Threshold Non-Standard Server Values', () {
    final serverValues = [1, 15, 30, 45, 60, 90, 120, 137, 240, 480, 500, 720, 1440, 10080];

    for (final val in serverValues) {
      testWidgets('Renders threshold=$val min without throwing Flutter assertions', (tester) async {
        setTestViewport(tester);
        final rel = buildChallengerRelationship(
          inactivityThresholdMinutes: val,
          checkInGracePeriodMinutes: 30, // standard grace period
        );

        await tester.pumpWidget(
          MaterialApp(
            home: MonitoringSettingsScreen(relationship: rel),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(MonitoringSettingsScreen), findsOneWidget);
        expect(tester.takeException(), isNull,
            reason: 'Rendering threshold=$val must not throw assertions');
      });
    }
  });

  // =========================================================================
  // 4. DROPDOWN ASSERTION AUDIT: CHECK-IN GRACE PERIOD BEHAVIOR
  // =========================================================================
  group('4. DropdownButtonFormField Audit for Grace Period', () {
    testWidgets('Standard checkInGracePeriod values (15, 30, 45, 60) render cleanly with zero assertion errors', (tester) async {
      setTestViewport(tester);

      for (final grace in [15, 30, 45, 60]) {
        final rel = buildChallengerRelationship(checkInGracePeriodMinutes: grace);
        await tester.pumpWidget(
          MaterialApp(
            home: MonitoringSettingsScreen(relationship: rel),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull,
            reason: 'Standard grace period $grace must not throw assertion error');
      }
    });

    testWidgets('Empirical verification: Non-standard checkInGracePeriod (e.g. 20) triggers Flutter Dropdown assertion', (tester) async {
      setTestViewport(tester);
      final rel = buildChallengerRelationship(checkInGracePeriodMinutes: 20);

      await tester.pumpWidget(
        MaterialApp(
          home: MonitoringSettingsScreen(relationship: rel),
        ),
      );

      final exception = tester.takeException();
      // DropdownButton asserts because 20 is not in items [15, 30, 45, 60]
      expect(exception, isNotNull);
      expect(exception.toString(), contains('DropdownButton'));
      expect(exception.toString(), contains('20'));
    });
  });

  // =========================================================================
  // 5. SLEEP SCHEDULE TIME FORMATS, MIDNIGHT CROSSING & UI CONSISTENCY
  // =========================================================================
  group('5. Sleep Schedule & Midnight Boundary Crossing Math', () {
    testWidgets('Normal daytime active window (07:00 wake, 22:00 bed) computes correct sleep/active duration', (tester) async {
      setTestViewport(tester);
      final rel = buildChallengerRelationship(
        scheduleWindows: [
          ScheduleWindowModel(
            dayOfWeek: 1,
            startTime: '07:00',
            endTime: '22:00',
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

      // Active: 15 hours (07:00 -> 22:00), Sleep: 9 hours (22:00 -> 07:00)
      expect(find.textContaining('Thời gian ngủ: 9 giờ (22:00 ➔ 07:00)'), findsOneWidget);
      expect(find.textContaining('Giám sát an tâm: 15 giờ (07:00 ➔ 22:00)'), findsOneWidget);
    });

    testWidgets('Cross-midnight overnight active window (23:00 wake, 06:30 bed) displays overnight banner and correct math', (tester) async {
      setTestViewport(tester);
      final rel = buildChallengerRelationship(
        scheduleWindows: [
          ScheduleWindowModel(
            dayOfWeek: 1, // Monday
            startTime: '23:00',
            endTime: '06:30',
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

      // Active: 23:00 -> 06:30 = 60m + 390m = 450m = 7h 30m
      // Sleep: 1440 - 450 = 990m = 16h 30m
      expect(find.textContaining('Thời gian ngủ: 16 giờ 30 phút (06:30 ➔ 23:00)'), findsOneWidget);
      expect(find.textContaining('Giám sát an tâm: 7 giờ 30 phút (23:00 ➔ 06:30)'), findsOneWidget);

      // Overnight banner
      expect(find.text(AppStrings.overnightBadge), findsOneWidget);
      expect(find.textContaining('xuyên suốt đêm đến 06:30 sáng Thứ Ba'), findsOneWidget);
    });

    test('ScheduleWindowModel nextDayNameFull transitions across entire week cycle', () {
      final days = [
        ScheduleWindowModel(dayOfWeek: 1, startTime: '22:00', endTime: '06:00'), // Mon -> Tue
        ScheduleWindowModel(dayOfWeek: 2, startTime: '22:00', endTime: '06:00'), // Tue -> Wed
        ScheduleWindowModel(dayOfWeek: 3, startTime: '22:00', endTime: '06:00'), // Wed -> Thu
        ScheduleWindowModel(dayOfWeek: 4, startTime: '22:00', endTime: '06:00'), // Thu -> Fri
        ScheduleWindowModel(dayOfWeek: 5, startTime: '22:00', endTime: '06:00'), // Fri -> Sat
        ScheduleWindowModel(dayOfWeek: 6, startTime: '22:00', endTime: '06:00'), // Sat -> Sun
        ScheduleWindowModel(dayOfWeek: 0, startTime: '22:00', endTime: '06:00'), // Sun -> Mon
      ];

      expect(days[0].dayNameFull, 'Thứ Hai');
      expect(days[0].nextDayNameFull, 'Thứ Ba');

      expect(days[1].dayNameFull, 'Thứ Ba');
      expect(days[1].nextDayNameFull, 'Thứ Tư');

      expect(days[2].dayNameFull, 'Thứ Tư');
      expect(days[2].nextDayNameFull, 'Thứ Năm');

      expect(days[3].dayNameFull, 'Thứ Năm');
      expect(days[3].nextDayNameFull, 'Thứ Sáu');

      expect(days[4].dayNameFull, 'Thứ Sáu');
      expect(days[4].nextDayNameFull, 'Thứ Bảy');

      expect(days[5].dayNameFull, 'Thứ Bảy');
      expect(days[5].nextDayNameFull, 'Chủ Nhật');

      expect(days[6].dayNameFull, 'Chủ Nhật');
      expect(days[6].nextDayNameFull, 'Thứ Hai');
    });

    testWidgets('Toggling day enable switch updates state and disables time pickers', (tester) async {
      setTestViewport(tester);
      final rel = buildChallengerRelationship();

      await tester.pumpWidget(
        MaterialApp(
          home: MonitoringSettingsScreen(relationship: rel),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.dayEnabled), findsOneWidget);

      // Toggle switch
      await tester.tap(find.byType(Switch).first);
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.dayDisabled), findsOneWidget);
    });

    testWidgets('Tapping "Áp dụng cho cả tuần" replicates current window to all 7 days', (tester) async {
      setTestViewport(tester);
      final rel = buildChallengerRelationship();

      await tester.pumpWidget(
        MaterialApp(
          home: MonitoringSettingsScreen(relationship: rel),
        ),
      );
      await tester.pumpAndSettle();

      // Tap apply all
      await tester.tap(find.text(AppStrings.applyToAllDays));
      await tester.pumpAndSettle();

      expect(find.text('Đã áp dụng khung giờ này cho toàn bộ các ngày trong tuần.'), findsOneWidget);
    });
  });
}
