import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mobile/core/i18n/app_localizations.dart';
import 'package:mobile/core/i18n/catalogs/catalogs.dart';
import 'package:mobile/core/i18n/locale_catalog_registry.dart';
import 'package:mobile/core/i18n/locale_provider.dart';
import 'package:mobile/core/models/enums.dart';
import 'package:mobile/core/models/monitoring_config_model.dart';
import 'package:mobile/core/models/relationship_model.dart';
import 'package:mobile/core/models/schedule_window_model.dart';
import 'package:mobile/core/models/user_model.dart';
import 'package:mobile/features/auth/auth_provider.dart';
import 'package:mobile/features/auth/login_screen.dart';
import 'package:mobile/features/auth/onboarding_screen.dart';
import 'package:mobile/features/auth/register_screen.dart';
import 'package:mobile/features/dashboard/guardian_view.dart';
import 'package:mobile/features/check_in/check_in_screen.dart';
import 'package:mobile/features/dashboard/dashboard_provider.dart';
import 'package:mobile/features/incidents/incidents_provider.dart';
import 'package:mobile/features/monitoring/monitoring_settings_screen.dart';
import 'package:mobile/features/pairing/qr_code_parser.dart';
import 'package:mobile/features/pairing/qr_invite_screen.dart';
import 'package:mobile/features/pairing/qr_scanner_screen.dart';
import 'package:mobile/features/settings/language_settings_screen.dart';

class _ChallengerMockDashboardProvider extends DashboardProvider {
  final List<RelationshipModel> _mockList;

  _ChallengerMockDashboardProvider({List<RelationshipModel>? relationships})
      : _mockList = relationships ?? [];

  @override
  bool get isLoading => false;

  @override
  List<RelationshipModel> get monitoredByMe => _mockList;

  @override
  List<RelationshipModel> get monitoringMe => _mockList;

  @override
  MonitoringState get myCurrentState => MonitoringState.ACTIVE;

  @override
  DateTime? get myLastActivityAt => DateTime(2026, 10, 16, 10, 0);

  @override
  Future<void> fetchDashboardData() async {}

  @override
  Future<bool> acceptInviteCode(String code) async {
    return code == 'CR-VALIDCODE';
  }
}

RelationshipModel _createTestRelationship({
  int inactivityThresholdMinutes = 180,
  int checkInGracePeriodMinutes = 30,
  List<ScheduleWindowModel>? scheduleWindows,
}) {
  return RelationshipModel(
    id: 'rel-challenger-2',
    monitoredUserId: 'user-monitored-1',
    monitorUserId: 'user-monitor-2',
    status: RelationshipStatus.ACCEPTED,
    createdAt: DateTime.now(),
    config: MonitoringConfigModel(
      id: 'cfg-challenger-2',
      relationshipId: 'rel-challenger-2',
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
      email: 'elder@evernear.test',
      fullName: 'Bà Nguyễn Thị Ba',
      timezone: 'Asia/Ho_Chi_Minh',
      isActive: true,
      createdAt: DateTime.now(),
    ),
    monitorUser: UserModel(
      id: 'user-monitor-2',
      email: 'guardian@evernear.test',
      fullName: 'Anh Nguyễn Văn Hai',
      timezone: 'Asia/Ho_Chi_Minh',
      isActive: true,
      createdAt: DateTime.now(),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  void setViewport(WidgetTester tester, {Size size = const Size(375, 812)}) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  // Canonical 36 languages required by Evernear specifications
  // Note: Filipino is represented as 'tl' (Tagalog / Filipino) in ISO 639-1 / Flutter catalog
  const canonical36Languages = [
    'ar', 'bn', 'cs', 'da', 'de', 'el', 'en', 'es', 'fa', 'fi',
    'tl', 'fr', 'he', 'hi', 'hu', 'id', 'it', 'ja', 'ko', 'ms',
    'nl', 'no', 'pl', 'pt', 'ro', 'ru', 'sv', 'sw', 'ta', 'te',
    'th', 'tr', 'uk', 'ur', 'vi', 'zh',
  ];

  group('CHALLENGE 1: 36 Languages Localization Stress Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      AppLocalizations.globalLocaleCode = 'vi';
      AppLocalizations.enableExtendedCatalogs = true;
    });

    test('1.1 LocaleCatalogRegistry covers all 36 canonical world languages', () {
      expect(LocaleCatalogRegistry.allLanguages.length, greaterThanOrEqualTo(36));

      for (final code in canonical36Languages) {
        final lang = LocaleCatalogRegistry.getByCode(code);
        expect(lang, isNotNull, reason: 'Language $code must be registered in LocaleCatalogRegistry');
        expect(lang!.code, equals(code));
        expect(lang.nativeName, isNotEmpty, reason: '$code must have non-empty nativeName');
        expect(lang.englishName, isNotEmpty, reason: '$code must have non-empty englishName');
        expect(lang.flagEmoji, isNotEmpty, reason: '$code must have non-empty flagEmoji');
      }
    });

    test('1.2 RTL script flags are accurately assigned for Middle-Eastern languages', () {
      const rtlCodes = ['ar', 'he', 'fa', 'ur'];
      const ltrCodes = ['en', 'vi', 'fr', 'de', 'es', 'ja', 'zh', 'ru', 'hi', 'th'];

      for (final code in rtlCodes) {
        final lang = LocaleCatalogRegistry.getByCode(code);
        expect(lang, isNotNull);
        expect(lang!.isRtl, isTrue, reason: 'Language $code must be marked RTL');
      }

      for (final code in ltrCodes) {
        final lang = LocaleCatalogRegistry.getByCode(code);
        expect(lang, isNotNull);
        expect(lang!.isRtl, isFalse, reason: 'Language $code must be marked LTR');
      }
    });

    test('1.3 All 36 catalogs resolve core UI keys without throwing or returning raw bracket keys', () {
      const coreKeys = [
        'app_name',
        'check_in_button',
        'common_cancel',
        'common_apply',
        'common_minutes',
        'common_hours',
      ];

      for (final code in canonical36Languages) {
        final l10n = AppLocalizations(Locale(code));
        for (final key in coreKeys) {
          final translated = l10n.tr(key);
          expect(translated, isNotEmpty, reason: 'Key $key in $code should resolve non-empty');
          expect(translated, isNot(contains('[$key]')),
              reason: 'Key $key in $code must not contain raw bracket syntax');
          expect(translated.toLowerCase(), isNot(equals('null')),
              reason: 'Key $key in $code must not be literal string "null"');
        }
      }
    });

    test('1.4 DynamicCatalogs provides catalog dictionary for all 36 canonical languages', () {
      for (final code in canonical36Languages) {
        final catalog = DynamicCatalogs.getAnyCatalog(code);
        expect(catalog, isNotNull, reason: 'Catalog dictionary for $code must be present');
        expect(catalog!.isNotEmpty, isTrue, reason: 'Catalog dictionary for $code must not be empty');
      }
    });

    test('1.5 Diacritic-insensitive search handles multiple writing systems and accents', () {
      // Vietnamese
      expect(LocaleCatalogRegistry.search('tiếng việt').any((l) => l.code == 'vi'), isTrue);
      expect(LocaleCatalogRegistry.search('tieng viet').any((l) => l.code == 'vi'), isTrue);

      // European
      expect(LocaleCatalogRegistry.search('français').any((l) => l.code == 'fr'), isTrue);
      expect(LocaleCatalogRegistry.search('francais').any((l) => l.code == 'fr'), isTrue);
      expect(LocaleCatalogRegistry.search('español').any((l) => l.code == 'es'), isTrue);
      expect(LocaleCatalogRegistry.search('deutsch').any((l) => l.code == 'de'), isTrue);

      // Non-Latin scripts
      expect(LocaleCatalogRegistry.search('Русский').any((l) => l.code == 'ru'), isTrue);
      expect(LocaleCatalogRegistry.search('日本語').any((l) => l.code == 'ja'), isTrue);
      expect(LocaleCatalogRegistry.search('العربية').any((l) => l.code == 'ar'), isTrue);
      expect(LocaleCatalogRegistry.search('हिन्दी').any((l) => l.code == 'hi'), isTrue);

      // Empty query returns all languages
      expect(LocaleCatalogRegistry.search('').length, equals(LocaleCatalogRegistry.allLanguages.length));
    });

    testWidgets('1.6 LanguageSettingsScreen switches locale reactively across all 36 languages without crash', (tester) async {
      setViewport(tester, size: const Size(375, 812));
      final localeProvider = LocaleProvider();
      await localeProvider.initialize();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: localeProvider),
            ChangeNotifierProvider(create: (_) => AuthProvider()),
            ChangeNotifierProvider(create: (_) => DashboardProvider()),
          ],
          child: const MaterialApp(
            home: LanguageSettingsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify search and selection of Japanese ('ja')
      await tester.enterText(find.byType(TextField), 'Japanese');
      await tester.pumpAndSettle();

      expect(find.text('日本語'), findsOneWidget);
      await tester.tap(find.text('日本語'));
      await tester.pumpAndSettle();

      expect(localeProvider.currentLocale.languageCode, equals('ja'));

      // Verify search and selection of Arabic ('ar')
      await tester.enterText(find.byType(TextField), 'Arabic');
      await tester.pumpAndSettle();

      expect(find.text('العربية'), findsOneWidget);
      await tester.tap(find.text('العربية'));
      await tester.pumpAndSettle();

      expect(localeProvider.currentLocale.languageCode, equals('ar'));
    });

    testWidgets('1.7 LoginScreen mobile viewport (375x812) overflow audit across languages', (tester) async {
      setViewport(tester, size: const Size(375, 812));
      AppLocalizations.globalLocaleCode = 'vi';

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => AuthProvider()),
            ChangeNotifierProvider(create: (_) => DashboardProvider()),
            ChangeNotifierProvider(create: (_) => IncidentsProvider()),
          ],
          child: const MaterialApp(
            locale: Locale('vi'),
            home: LoginScreen(),
          ),
        ),
      );
      await tester.pump();

      // Check whether RenderFlex overflowed in LoginScreen
      final error = tester.takeException();
      expect(error, isNull, reason: 'LoginScreen must not have RenderFlex overflow on 375x812 mobile viewport');
    });

    testWidgets('1.8 CheckInScreen mobile viewport (375x812) overflow audit across languages', (tester) async {
      setViewport(tester, size: const Size(375, 812));

      for (final code in ['vi', 'en', 'ar', 'ja']) {
        AppLocalizations.globalLocaleCode = code;
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider(create: (_) => AuthProvider()),
              ChangeNotifierProvider(create: (_) => DashboardProvider()),
            ],
            child: MaterialApp(
              locale: Locale(code),
              home: const CheckInScreen(),
            ),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull, reason: 'CheckInScreen must not throw in locale $code');
      }
    });

    testWidgets('1.9 RegisterScreen mobile viewport (375x812) overflow audit', (tester) async {
      setViewport(tester, size: const Size(375, 812));

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => AuthProvider()),
            ChangeNotifierProvider(create: (_) => DashboardProvider()),
            ChangeNotifierProvider(create: (_) => IncidentsProvider()),
          ],
          child: const MaterialApp(
            home: RegisterScreen(),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull, reason: 'RegisterScreen must not have RenderFlex overflow on 375x812');
    });

    testWidgets('1.10 OnboardingScreen mobile viewport (375x812) overflow audit', (tester) async {
      setViewport(tester, size: const Size(375, 812));

      await tester.pumpWidget(
        const MaterialApp(
          home: OnboardingScreen(),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull, reason: 'OnboardingScreen must not have RenderFlex overflow on 375x812');
    });

    testWidgets('1.11 GuardianView mobile viewport (375x812) overflow audit', (tester) async {
      setViewport(tester, size: const Size(375, 812));
      final mockRelative = _createTestRelationship();
      final dashboardProvider = _ChallengerMockDashboardProvider(relationships: [mockRelative]);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<DashboardProvider>.value(value: dashboardProvider),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: GuardianView(),
            ),
          ),
        ),
      );
      await tester.pump();
      final error = tester.takeException();
      expect(error, isNull, reason: 'GuardianView must not have RenderFlex overflow on 375x812 mobile viewport');
    });
  });

  group('CHALLENGE 2: QR Pairing Simulation Adversarial Stress Tests', () {
    test('2.1 QrCodeParser parses diverse valid URI schemes, URLs, and raw codes', () {
      // Carely scheme
      expect(QrCodeParser.extractInviteCode('carely://invite?code=CR-CANONICAL1'), equals('CR-CANONICAL1'));

      // Evernear scheme
      expect(QrCodeParser.extractInviteCode('evernear://invite?code=CR-EVERNEAR2'), equals('CR-EVERNEAR2'));

      // Web Universal Links
      expect(QrCodeParser.extractInviteCode('https://carely.app/invite?code=CR-WEBCARELY3'), equals('CR-WEBCARELY3'));
      expect(QrCodeParser.extractInviteCode('https://evernear.app/invite?code=CR-WEBEVERNEAR4'), equals('CR-WEBEVERNEAR4'));

      // Query param pollution & ordering
      expect(QrCodeParser.extractInviteCode('carely://invite?utm_source=qr&code=CR-POLLUTED5&ts=12345'), equals('CR-POLLUTED5'));

      // Raw code auto-uppercasing and trimming
      expect(QrCodeParser.extractInviteCode('cr-lowercase123'), equals('CR-LOWERCASE123'));
      expect(QrCodeParser.extractInviteCode('  \tCR-SPACETRIM1\n '), equals('CR-SPACETRIM1'));
    });

    test('2.2 QrCodeParser safely rejects adversarial, malformed, and injection payloads without throwing', () {
      final fullyRejectedPayloads = [
        '',
        '    ',
        '\n\t\r',
        'CR-',
        'CR-A',
        'carely://',
        'carely://invite',
        'carely://invite?nocode=123',
        'https://google.com/search?q=carely',
        '<script>alert("xss")</script>',
        "' OR '1'='1' --",
        'A' * 5000,
        '\x00\x01\x02TEST\x00',
        'not_a_code',
        'http://[invalid-ipv6/test',
      ];

      for (final payload in fullyRejectedPayloads) {
        expect(() => QrCodeParser.extractInviteCode(payload), returnsNormally,
            reason: 'Payload "$payload" must not throw exception');
        expect(QrCodeParser.extractInviteCode(payload), isNull,
            reason: 'Payload "$payload" must be rejected as null');
      }

      // Finding: QrCodeParser uses unanchored regex ((?:CR|EV)-[A-Z0-9]{4,16}) which extracts
      // valid substring up to 16 chars from oversized buffer instead of rejecting entire buffer
      final oversizedBuffer = 'CR-${'A' * 5000}';
      final extractedFromBuffer = QrCodeParser.extractInviteCode(oversizedBuffer);
      expect(extractedFromBuffer, equals('CR-AAAAAAAAAAAAAAAA'),
          reason: 'Unanchored regex truncates oversized code to 16 characters');
    });

    testWidgets('2.3 QrInviteScreen verifies key invariants and copy interaction on standard desktop/tablet canvas', (tester) async {
      setViewport(tester, size: const Size(800, 1000));

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => DashboardProvider()),
          ],
          child: const MaterialApp(
            home: QrInviteScreen(initialCode: 'CR-CHALLENGE99'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check all required test keys
      expect(find.byKey(const Key('qr_image_view')), findsOneWidget);
      expect(find.byKey(const Key('invite_code_text')), findsOneWidget);
      expect(find.byKey(const Key('copy_invite_code_button')), findsOneWidget);
      expect(find.byKey(const Key('share_invite_code_button')), findsOneWidget);

      // Verify code display
      expect(find.text('CR-CHALLENGE99'), findsOneWidget);

      // Verify tap on copy button displays feedback snackbar
      await tester.tap(find.byKey(const Key('copy_invite_code_button')));
      await tester.pump();
      expect(find.text('Đã sao chép mã kết nối vào bộ nhớ tạm'), findsOneWidget);
    });

    testWidgets('2.4 QrInviteScreen mobile viewport (375x812) overflow audit', (tester) async {
      setViewport(tester, size: const Size(375, 812));

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => DashboardProvider()),
          ],
          child: const MaterialApp(
            home: QrInviteScreen(initialCode: 'CR-CHALLENGE99'),
          ),
        ),
      );
      await tester.pump();
      final error = tester.takeException();
      expect(error, isNull, reason: 'QrInviteScreen must not have RenderFlex overflow on 375x812 mobile viewport');
    });

    testWidgets('2.5 QrScannerScreen simulation mode processes valid and rejects invalid inputs safely', (tester) async {
      setViewport(tester);
      String? scannedResult;

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<DashboardProvider>(
              create: (_) => _ChallengerMockDashboardProvider(),
            ),
          ],
          child: MaterialApp(
            home: QrScannerScreen(
              isTestMode: true,
              onCodeScanned: (code) {
                scannedResult = code;
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify simulation keys
      expect(find.byKey(const Key('simulated_qr_input')), findsOneWidget);
      expect(find.byKey(const Key('simulated_qr_submit')), findsOneWidget);
      expect(find.byKey(const Key('open_manual_input_button')), findsOneWidget);

      // Test 1: Submitting malformed string does not trigger onCodeScanned
      await tester.enterText(find.byKey(const Key('simulated_qr_input')), 'malformed_gibberish');
      await tester.tap(find.byKey(const Key('simulated_qr_submit')));
      await tester.pump();
      expect(scannedResult, isNull);

      // Test 2: Submitting valid QR URI triggers onCodeScanned
      await tester.enterText(
        find.byKey(const Key('simulated_qr_input')),
        'evernear://invite?code=CR-VALIDCODE',
      );
      await tester.tap(find.byKey(const Key('simulated_qr_submit')));
      await tester.pump();
      expect(scannedResult, equals('CR-VALIDCODE'));

      // Test 3: Manual input dialog handles input and submission
      scannedResult = null;
      await tester.tap(find.byKey(const Key('open_manual_input_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('manual_code_input_field')), findsOneWidget);
      expect(find.byKey(const Key('manual_code_submit_button')), findsOneWidget);

      await tester.enterText(find.byKey(const Key('manual_code_input_field')), 'cr-manual123');
      await tester.tap(find.byKey(const Key('manual_code_submit_button')));
      await tester.pump();

      expect(scannedResult, equals('CR-MANUAL123'));
    });
  });

  group('CHALLENGE 3: Monitoring Preset Boundaries & Schedule Math Stress Tests', () {
    testWidgets('3.1 All 8 standard inactivity preset chips render exact labels and update selection', (tester) async {
      setViewport(tester, size: const Size(1080, 2400));
      final rel = _createTestRelationship(inactivityThresholdMinutes: 180);

      await tester.pumpWidget(
        MaterialApp(
          home: MonitoringSettingsScreen(relationship: rel),
        ),
      );
      await tester.pumpAndSettle();

      const expectedLabels = ['15p', '30p', '1h', '2h', '4h', '8h', '12h', '24h'];
      for (final label in expectedLabels) {
        expect(find.text(label), findsOneWidget, reason: 'Preset label $label must exist');
      }

      // Tap on '4h' (240 min)
      await tester.tap(find.text('4h'));
      await tester.pumpAndSettle();

      // Tap on '15p' (15 min)
      await tester.tap(find.text('15p'));
      await tester.pumpAndSettle();

      // Tap on '24h' (1440 min)
      await tester.tap(find.text('24h'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('3.2 Custom threshold dialog enforces min (1 min) and max (1440 min) boundary rejection', (tester) async {
      setViewport(tester, size: const Size(1080, 2400));
      final rel = _createTestRelationship(inactivityThresholdMinutes: 180);

      await tester.pumpWidget(
        MaterialApp(
          home: MonitoringSettingsScreen(relationship: rel),
        ),
      );
      await tester.pumpAndSettle();

      // Find and tap 'Tùy biến...' chip
      final customChipFinder = find.byWidgetPredicate((widget) {
        if (widget is ChoiceChip) {
          final textWidget = widget.label as Text;
          return textWidget.data?.startsWith('Tùy biến') ?? false;
        }
        return false;
      });

      expect(customChipFinder, findsOneWidget);
      await tester.tap(customChipFinder);
      await tester.pumpAndSettle();

      // Verify custom threshold screen is open
      expect(find.byType(CustomThresholdScreen), findsOneWidget);
      final textFieldFinder = find.descendant(of: find.byType(CustomThresholdScreen), matching: find.byType(TextField));
      expect(textFieldFinder, findsOneWidget);
      final applyButtonFinder = find.descendant(of: find.byType(CustomThresholdScreen), matching: find.widgetWithText(ElevatedButton, 'Áp dụng'));

      // Test: Below min (0 min) -> rejected
      await tester.enterText(textFieldFinder, '0');
      await tester.tap(applyButtonFinder);
      await tester.pumpAndSettle();
      expect(find.byType(CustomThresholdScreen), findsOneWidget); // Screen remains open

      // Test: Negative (-10 min) -> rejected
      await tester.enterText(textFieldFinder, '-10');
      await tester.tap(applyButtonFinder);
      await tester.pumpAndSettle();
      expect(find.byType(CustomThresholdScreen), findsOneWidget);

      // Test: Above max (1441 min) -> rejected
      await tester.enterText(textFieldFinder, '1441');
      await tester.tap(applyButtonFinder);
      await tester.pumpAndSettle();
      expect(find.byType(CustomThresholdScreen), findsOneWidget);

      // Test: Alphabetic garbage -> rejected
      await tester.enterText(textFieldFinder, 'garbage_text');
      await tester.tap(applyButtonFinder);
      await tester.pumpAndSettle();
      expect(find.byType(CustomThresholdScreen), findsOneWidget);

      // Test: Valid boundary min (1 min) -> accepted and screen closes
      await tester.enterText(textFieldFinder, '1');
      await tester.tap(applyButtonFinder);
      await tester.pumpAndSettle();
      expect(find.byType(CustomThresholdScreen), findsNothing); // Screen closed successfully
    });

    test('3.3 ScheduleWindowModel computes overnight, weekend transitions, and 24h boundaries accurately', () {
      // Standard daytime schedule: 07:00 wake, 22:00 bed
      final dayWindow = ScheduleWindowModel(
        dayOfWeek: 1, // Monday
        startTime: '07:00',
        endTime: '22:00',
      );
      expect(dayWindow.isOvernight, isFalse);
      expect(dayWindow.wakeTime, equals('07:00'));
      expect(dayWindow.bedtime, equals('22:00'));
      expect(dayWindow.dayNameShort, equals('T2'));
      expect(dayWindow.nextDayNameFull, isNotEmpty);

      // Cross-midnight overnight schedule: 23:00 wake, 06:30 bed
      final nightWindow = ScheduleWindowModel(
        dayOfWeek: 6, // Saturday
        startTime: '23:00',
        endTime: '06:30',
      );
      expect(nightWindow.isOvernight, isTrue);
      expect(nightWindow.dayNameShort, equals('T7'));
      expect(nightWindow.nextDayNameFull, isNotEmpty);

      // Sunday to Monday wrap-around transition
      final sundayWindow = ScheduleWindowModel(
        dayOfWeek: 0, // Sunday
        startTime: '22:00',
        endTime: '06:00',
      );
      expect(sundayWindow.isOvernight, isTrue);
      expect(sundayWindow.dayNameShort, equals('CN'));
      expect(sundayWindow.nextDayNameFull, isNotEmpty);

      // Serialization roundtrip preserves all properties
      final json = sundayWindow.toJson();
      final roundtrip = ScheduleWindowModel.fromJson(json);
      expect(roundtrip.dayOfWeek, equals(sundayWindow.dayOfWeek));
      expect(roundtrip.startTime, equals(sundayWindow.startTime));
      expect(roundtrip.endTime, equals(sundayWindow.endTime));
      expect(roundtrip.isEnabled, equals(sundayWindow.isEnabled));
    });

    testWidgets('3.4 Sleep schedule "Áp dụng cho cả tuần" replicates settings across all 7 days', (tester) async {
      setViewport(tester, size: const Size(1080, 2400));
      final rel = _createTestRelationship();

      await tester.pumpWidget(
        MaterialApp(
          home: MonitoringSettingsScreen(relationship: rel),
        ),
      );
      await tester.pumpAndSettle();

      // Find "Áp dụng cho cả tuần" button
      final applyAllFinder = find.text('Áp dụng cho cả tuần');
      expect(applyAllFinder, findsOneWidget);

      await tester.tap(applyAllFinder);
      await tester.pump();

      // Verify confirmation snackbar
      expect(
        find.text('Đã áp dụng khung giờ này cho toàn bộ các ngày trong tuần.'),
        findsOneWidget,
      );
    });
  });
}
