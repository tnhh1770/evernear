import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mobile/core/constants/app_colors.dart';
import 'package:mobile/core/i18n/app_localizations.dart';
import 'package:mobile/core/i18n/locale_catalog_registry.dart';
import 'package:mobile/core/i18n/locale_provider.dart';
import 'package:mobile/core/models/check_in_model.dart';
import 'package:mobile/core/models/enums.dart';
import 'package:mobile/core/models/incident_model.dart';
import 'package:mobile/core/models/monitoring_config_model.dart';
import 'package:mobile/core/models/relationship_model.dart';
import 'package:mobile/core/models/schedule_window_model.dart';
import 'package:mobile/core/models/user_model.dart';
import 'package:mobile/core/storage/local_storage.dart';
import 'package:mobile/features/auth/auth_provider.dart';
import 'package:mobile/features/auth/login_screen.dart';
import 'package:mobile/features/auth/onboarding_screen.dart';
import 'package:mobile/features/auth/register_screen.dart';
import 'package:mobile/features/check_in/check_in_screen.dart';
import 'package:mobile/features/check_in/recent_activities_screen.dart';
import 'package:mobile/features/dashboard/dashboard_provider.dart';
import 'package:mobile/features/dashboard/dashboard_screen.dart';
import 'package:mobile/features/dashboard/monitor_view.dart';
import 'package:mobile/features/dashboard/monitored_view.dart';
import 'package:mobile/features/dashboard/relative_detail_screen.dart';
import 'package:mobile/features/devices/devices_screen.dart';
import 'package:mobile/features/incidents/incident_detail_screen.dart';
import 'package:mobile/features/incidents/incidents_list_screen.dart';
import 'package:mobile/features/incidents/incidents_provider.dart';
import 'package:mobile/features/monitoring/monitoring_settings_screen.dart';
import 'package:mobile/features/pairing/qr_invite_screen.dart';
import 'package:mobile/features/pairing/qr_scanner_screen.dart';
import 'package:mobile/features/settings/account_settings_screen.dart';
import 'package:mobile/features/settings/notification_settings_screen.dart';
import 'package:mobile/features/settings/privacy_security_screen.dart';
import 'package:mobile/features/settings/settings_screen.dart';

// =============================================================================
// MOCK PROVIDERS CONFIGURED FOR DETERMINISTIC ENGLISH VERIFICATION
// =============================================================================

class MockEnglishAuthProvider extends AuthProvider {
  final UserModel _user;
  final bool _loading;

  MockEnglishAuthProvider({
    UserModel? user,
    bool isLoading = false,
  })  : _user = user ??
            UserModel(
              id: 'user-en-monitored-1',
              email: 'john.doe@example.com',
              fullName: 'John Doe',
              phone: '+1 555 123 4567',
              timezone: 'America/New_York',
              preferredLanguage: 'en',
              isActive: true,
              createdAt: DateTime(2025, 1, 1),
            ),
        _loading = isLoading;

  @override
  bool get isAuthenticated => true;

  @override
  bool get isLoading => _loading;

  @override
  UserModel? get currentUser => _user;

  @override
  String? get errorMessage => null;

  @override
  String? getErrorMessage(BuildContext context) => null;

  @override
  Future<bool> login(String email, String password) async => true;

  @override
  Future<bool> register({
    required String fullName,
    required String email,
    required String password,
    String? phone,
    String? preferredLanguage,
  }) async =>
      true;

  @override
  Future<bool> updateProfile({
    String? fullName,
    String? phone,
    String? avatarUrl,
    String? preferredLanguage,
  }) async =>
      true;

  @override
  Future<bool> deleteAccount() async => true;

  @override
  Future<void> logout({
    dynamic dashboardProvider,
    dynamic incidentsProvider,
  }) async {}

  @override
  Future<bool> registerCurrentDevice() async => true;
}

class MockEnglishDashboardProvider extends DashboardProvider {
  final List<RelationshipModel> _mockRelationships;
  final MonitoringState _state;
  final DateTime? _lastActivity;

  MockEnglishDashboardProvider({
    List<RelationshipModel>? relationships,
    this._state = MonitoringState.ACTIVE,
    DateTime? lastActivity,
  })  : _mockRelationships = relationships ?? [],
        _lastActivity = lastActivity ?? DateTime(2025, 10, 15, 8, 42);

  @override
  bool get isLoading => false;

  @override
  String? get errorMessage => null;

  @override
  int get activeIncidentsCount => 0;

  @override
  int get unreadNotificationsCount => 0;

  @override
  List<RelationshipModel> get allRelationships => _mockRelationships;

  @override
  List<RelationshipModel> get monitoredByMe => _mockRelationships;

  @override
  List<RelationshipModel> get monitoringMe => _mockRelationships;

  @override
  MonitoringState get myCurrentState => _state;

  @override
  DateTime? get myLastActivityAt => _lastActivity;

  @override
  bool get lastCheckInOffline => false;

  @override
  Future<void> fetchDashboardData() async {}

  @override
  Future<bool> sendCheckIn({
    String? note,
    int? batteryLevel,
    double? latitude,
    double? longitude,
  }) async =>
      true;

  @override
  Future<String?> generateInviteCode({String? label}) async => 'CR-TEST1234';

  @override
  Future<bool> acceptInviteCode(String code) async => true;
}

class MockEnglishIncidentsProvider extends IncidentsProvider {
  final List<IncidentModel> _mockIncidents;
  final List<NotificationFeedItem> _mockNotifications;
  final int _unread;

  MockEnglishIncidentsProvider({
    List<IncidentModel>? incidents,
    List<NotificationFeedItem>? notifications,
    int unreadCount = 0,
  })  : _mockIncidents = incidents ?? [],
        _mockNotifications = notifications ?? [],
        _unread = unreadCount;

  @override
  List<IncidentModel> get incidents => _mockIncidents;

  @override
  List<NotificationFeedItem> get allNotifications => _mockNotifications;

  @override
  bool get isLoading => false;

  @override
  String? get errorMessage => null;

  @override
  int get unreadCount => _unread;

  @override
  bool get hasUnreadIncidents => _unread > 0;

  @override
  Future<void> fetchIncidents() async {}

  @override
  Future<bool> acknowledgeIncident(String incidentId) async => true;

  @override
  Future<bool> resolveIncident(String incidentId, {String? resolutionNote}) async =>
      true;

  @override
  Future<void> markAllAsRead() async {}

  @override
  Future<int> clearAllNotifications() async => 0;

  @override
  Future<void> dismissNotification(String id) async {}

  @override
  Future<IncidentModel?> getIncidentDetail(String incidentId) async {
    if (_mockIncidents.isNotEmpty) {
      return _mockIncidents.first;
    }
    return null;
  }
}

class MockEnglishLocaleProvider extends LocaleProvider {
  @override
  Locale get currentLocale => const Locale('en');

  @override
  String get currentLanguageCode => 'en';

  @override
  bool get isDeviceDefault => false;

  @override
  bool get isInitialized => true;

  @override
  LanguageMetadata get currentLanguage =>
      LocaleCatalogRegistry.findByCode('en')!;

  @override
  String get currentLanguageDisplayName => 'English';

  @override
  String getLanguageDisplayName(BuildContext context) => 'English';
}

// =============================================================================
// TEST HARNESS & BUILDER (FORCED LOCALE 'en')
// =============================================================================

Widget buildEnglishHarness({
  required Widget child,
  AuthProvider? authProvider,
  DashboardProvider? dashboardProvider,
  IncidentsProvider? incidentsProvider,
  LocaleProvider? localeProvider,
}) {
  AppLocalizations.globalLocaleCode = 'en';

  final locProv = localeProvider ?? MockEnglishLocaleProvider();

  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthProvider>.value(
        value: authProvider ?? MockEnglishAuthProvider(),
      ),
      ChangeNotifierProvider<DashboardProvider>.value(
        value: dashboardProvider ?? MockEnglishDashboardProvider(),
      ),
      ChangeNotifierProvider<IncidentsProvider>.value(
        value: incidentsProvider ?? MockEnglishIncidentsProvider(),
      ),
      ChangeNotifierProvider<LocaleProvider>.value(
        value: locProv,
      ),
    ],
    child: MaterialApp(
      locale: const Locale('en'),
      supportedLocales: LocaleCatalogRegistry.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          primary: AppColors.primary,
          secondary: AppColors.secondary,
          surface: AppColors.surface,
          error: AppColors.stateAlertTriggered,
        ),
      ),
      home: Material(
        color: AppColors.background,
        child: child,
      ),
    ),
  );
}

// =============================================================================
// VIETNAMESE DETECTION ORACLES
// =============================================================================

/// Comprehensive Vietnamese diacritics regex (precomposed and decomposed combining marks)
final vietnameseDiacriticsPattern = RegExp(
  r'[àáảãạăằắẳẵặâầấẩẫậđèéẻẽẹêềếểễệìíỉĩịòóỏõọôồốổỗộơờớởỡợùúủũụưừứửữựỳýỷỹỵ'
  r'ÀÁẢÃẠĂẰẮẲẴẶÂẦẤẨẪẬĐÈÉẺẸÊỀẾỂỄỆÌÍỈĨỊÒÓỎÕỌÔỒỐỔỖỘƠỜỚỞỠỢÙÚỦŨỤƯỪỨỬỮỰỲÝỶỸỴ'
  r'\u0300-\u036F]',
  caseSensitive: false,
);

/// Distinct Vietnamese words/phrases even if accidentally stripped of accents
final vietnameseKeywordPattern = RegExp(
  r'\b(dang nhap|dang ky|nguoi than|toi van on|cai dat|thiet bi|hoat dong|su co|trang chu|thong bao|xac nhan|tam dung|lich kiem tra|lan hoat dong|chua co|bat dau|tiep tuc)\b',
  caseSensitive: false,
);

Set<String> extractAllTextsFromTree(WidgetTester tester) {
  final collected = <String>{};

  // 1. Text widgets
  for (final el in find.byType(Text).evaluate()) {
    final w = el.widget as Text;
    if (w.data != null && w.data!.trim().isNotEmpty) {
      collected.add(w.data!.trim());
    }
    if (w.textSpan != null) {
      final text = w.textSpan!.toPlainText().trim();
      if (text.isNotEmpty) collected.add(text);
    }
  }

  // 2. RichText widgets
  for (final el in find.byType(RichText).evaluate()) {
    final w = el.widget as RichText;
    final text = w.text.toPlainText().trim();
    if (text.isNotEmpty) collected.add(text);
  }

  // 3. Tooltips
  for (final el in find.byType(Tooltip).evaluate()) {
    final w = el.widget as Tooltip;
    if (w.message != null && w.message!.trim().isNotEmpty) {
      collected.add(w.message!.trim());
    }
  }

  // 4. TextFields
  for (final el in find.byType(TextField).evaluate()) {
    final w = el.widget as TextField;
    final dec = w.decoration;
    if (dec?.hintText != null && dec!.hintText!.trim().isNotEmpty) collected.add(dec.hintText!.trim());
    if (dec?.labelText != null && dec!.labelText!.trim().isNotEmpty) collected.add(dec.labelText!.trim());
    if (dec?.helperText != null && dec!.helperText!.trim().isNotEmpty) collected.add(dec.helperText!.trim());
    if (dec?.errorText != null && dec!.errorText!.trim().isNotEmpty) collected.add(dec.errorText!.trim());
  }

  return collected;
}

void assertZeroVietnameseInRenderedUI(WidgetTester tester, String screenName) {
  final texts = extractAllTextsFromTree(tester);
  final diacriticViolations = <String>[];
  final keywordViolations = <String>[];

  for (final t in texts) {
    if (vietnameseDiacriticsPattern.hasMatch(t)) {
      diacriticViolations.add(t);
    }
    if (vietnameseKeywordPattern.hasMatch(t)) {
      keywordViolations.add(t);
    }
  }

  expect(
    diacriticViolations,
    isEmpty,
    reason: 'Screen [$screenName] leaked Vietnamese diacritics under Locale("en"): $diacriticViolations',
  );
  expect(
    keywordViolations,
    isEmpty,
    reason: 'Screen [$screenName] leaked Vietnamese keywords under Locale("en"): $keywordViolations',
  );
}

Future<void> scrollAndAssertZeroVietnamese(WidgetTester tester, String screenName) async {
  assertZeroVietnameseInRenderedUI(tester, '$screenName (top)');
  final scrollable = find.byType(Scrollable);
  if (scrollable.evaluate().isNotEmpty) {
    await tester.drag(scrollable.first, const Offset(0, -400));
    await tester.pumpAndSettle();
    assertZeroVietnameseInRenderedUI(tester, '$screenName (scrolled 400px)');
    await tester.drag(scrollable.first, const Offset(0, -400));
    await tester.pumpAndSettle();
    assertZeroVietnameseInRenderedUI(tester, '$screenName (scrolled 800px)');
  }
}

// Sample English relationship model for populated state tests
RelationshipModel createEnglishSampleRelationship() {
  return RelationshipModel(
    id: 'rel-sample-en-1',
    monitoredUserId: 'user-monitored-en-1',
    monitorUserId: 'user-monitor-en-1',
    status: RelationshipStatus.ACCEPTED,
    createdAt: DateTime(2025, 1, 1),
    label: 'Mother',
    monitoredUser: UserModel(
      id: 'user-monitored-en-1',
      email: 'mother@example.com',
      fullName: 'Jane Doe',
      phone: '+1 555 987 6543',
      timezone: 'America/New_York',
      preferredLanguage: 'en',
      isActive: true,
      createdAt: DateTime(2025, 1, 1),
    ),
    config: MonitoringConfigModel(
      id: 'cfg-sample-en-1',
      relationshipId: 'rel-sample-en-1',
      currentState: MonitoringState.ACTIVE,
      inactivityThresholdMinutes: 180,
      checkInGracePeriodMinutes: 30,
      escalationGracePeriodMinutes: 30,
      locationEnabled: true,
      isPaused: false,
      timezone: 'America/New_York',
      scheduleWindows: [
        ScheduleWindowModel(
          dayOfWeek: 1,
          startTime: '07:00',
          endTime: '22:00',
          isEnabled: true,
        ),
      ],
    ),
  );
}

// =============================================================================
// MAIN EMPIRICAL VERIFICATION SUITE
// =============================================================================

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'evernear_app_locale': 'en',
      'carely_user_id': 'user-en-monitored-1',
      'carely_device_uid': 'device-test-uuid',
      'notif_push': true,
      'notif_emergency': true,
      'notif_reminders': true,
      'notif_system': false,
      'notif_ringtone': 'Default Ringtone',
    });
    await LocalStorage.saveAuth(
      accessToken: 'mock_jwt_token',
      refreshToken: 'mock_refresh_token',
      userId: 'user-en-monitored-1',
      email: 'john.doe@example.com',
      fullName: 'John Doe',
    );
    AppLocalizations.globalLocaleCode = 'en';
  });

  group('Challenger 2: Empirical Screen Rendering Under Locale("en")', () {
    // -------------------------------------------------------------------------
    // 1. Auth Screens
    // -------------------------------------------------------------------------
    testWidgets('1.1 LoginScreen renders under Locale("en") with ZERO Vietnamese text', (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildEnglishHarness(child: const LoginScreen()));
      await tester.pumpAndSettle();

      await scrollAndAssertZeroVietnamese(tester, 'LoginScreen');
    });

    testWidgets('1.2 RegisterScreen renders under Locale("en") with ZERO Vietnamese text', (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildEnglishHarness(child: const RegisterScreen()));
      await tester.pumpAndSettle();

      await scrollAndAssertZeroVietnamese(tester, 'RegisterScreen');
    });

    testWidgets('1.3 OnboardingScreen (all pages) renders under Locale("en") with ZERO Vietnamese text', (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      for (int page = 0; page <= 4; page++) {
        await tester.pumpWidget(buildEnglishHarness(child: OnboardingScreen(initialPage: page)));
        await tester.pumpAndSettle();
        assertZeroVietnameseInRenderedUI(tester, 'OnboardingScreen(page: $page)');
      }
    });

    // -------------------------------------------------------------------------
    // 2. Dashboard & Primary Views
    // -------------------------------------------------------------------------
    testWidgets('2.1 DashboardScreen renders under Locale("en") with ZERO Vietnamese text', (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildEnglishHarness(child: const DashboardScreen()));
      await tester.pumpAndSettle();

      assertZeroVietnameseInRenderedUI(tester, 'DashboardScreen');
    });

    testWidgets('2.2 MonitoredView renders under Locale("en") with ZERO Vietnamese text', (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildEnglishHarness(child: const MonitoredView()));
      await tester.pumpAndSettle();

      await scrollAndAssertZeroVietnamese(tester, 'MonitoredView');
    });

    testWidgets('2.3 MonitorView (Empty State) renders under Locale("en") with ZERO Vietnamese text', (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        buildEnglishHarness(
          dashboardProvider: MockEnglishDashboardProvider(relationships: []),
          child: const MonitorView(),
        ),
      );
      await tester.pumpAndSettle();

      await scrollAndAssertZeroVietnamese(tester, 'MonitorView (Empty)');
    });

    testWidgets('2.4 MonitorView (Populated State) renders under Locale("en") with ZERO Vietnamese text', (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        buildEnglishHarness(
          dashboardProvider: MockEnglishDashboardProvider(
            relationships: [createEnglishSampleRelationship()],
          ),
          child: const MonitorView(),
        ),
      );
      await tester.pumpAndSettle();

      await scrollAndAssertZeroVietnamese(tester, 'MonitorView (Populated)');
    });

    // -------------------------------------------------------------------------
    // 3. Activity & Device Screens
    // -------------------------------------------------------------------------
    testWidgets('3.1 RecentActivitiesScreen (Empty State) renders under Locale("en") with ZERO Vietnamese text', (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        buildEnglishHarness(
          incidentsProvider: MockEnglishIncidentsProvider(notifications: []),
          child: const RecentActivitiesScreen(showAppBar: true),
        ),
      );
      await tester.pumpAndSettle();

      await scrollAndAssertZeroVietnamese(tester, 'RecentActivitiesScreen (Empty)');
    });

    testWidgets('3.2 RecentActivitiesScreen (Populated State) renders under Locale("en") with ZERO Vietnamese text', (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final sampleCheckIn = CheckInModel(
        id: 'chk-1',
        userId: 'user-monitored-en-1',
        userDisplayName: 'Jane Doe',
        occurredAt: DateTime(2025, 10, 15, 8, 30),
        createdAt: DateTime(2025, 10, 15, 8, 30),
      );
      final sampleNotifications = [
        NotificationFeedItem.checkIn(sampleCheckIn),
      ];

      await tester.pumpWidget(
        buildEnglishHarness(
          incidentsProvider: MockEnglishIncidentsProvider(notifications: sampleNotifications),
          child: const RecentActivitiesScreen(showAppBar: true),
        ),
      );
      await tester.pumpAndSettle();

      await scrollAndAssertZeroVietnamese(tester, 'RecentActivitiesScreen (Populated)');
    });

    testWidgets('3.3 DevicesScreen renders under Locale("en") with ZERO Vietnamese text', (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildEnglishHarness(child: const DevicesScreen(showAppBar: true)));
      await tester.pumpAndSettle();

      await scrollAndAssertZeroVietnamese(tester, 'DevicesScreen');
    });

    // -------------------------------------------------------------------------
    // 4. Monitoring & Incidents Screens
    // -------------------------------------------------------------------------
    testWidgets('4.1 MonitoringSettingsScreen renders under Locale("en") with ZERO Vietnamese text', (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildEnglishHarness(child: const MonitoringSettingsScreen()));
      await tester.pumpAndSettle();

      await scrollAndAssertZeroVietnamese(tester, 'MonitoringSettingsScreen');
    });

    testWidgets('4.2 IncidentsListScreen (Empty State) renders under Locale("en") with ZERO Vietnamese text', (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        buildEnglishHarness(
          incidentsProvider: MockEnglishIncidentsProvider(incidents: [], notifications: []),
          child: const IncidentsListScreen(isEmbedded: false),
        ),
      );
      await tester.pumpAndSettle();

      await scrollAndAssertZeroVietnamese(tester, 'IncidentsListScreen (Empty)');
    });

    testWidgets('4.3 IncidentsListScreen (Populated State) renders under Locale("en") with ZERO Vietnamese text', (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final sampleIncident = IncidentModel(
        id: 'inc-sample-1',
        relationshipId: 'rel-sample-en-1',
        monitoredUserId: 'user-monitored-en-1',
        status: IncidentStatus.OPEN,
        reason: IncidentReason.MISSED_CHECK_IN,
        riskScore: 65,
        triggeredAt: DateTime(2025, 10, 15, 18, 20),
        userDisplayName: 'Jane Doe',
      );

      final sampleNotification = NotificationFeedItem.incident(sampleIncident);

      await tester.pumpWidget(
        buildEnglishHarness(
          incidentsProvider: MockEnglishIncidentsProvider(
            incidents: [sampleIncident],
            notifications: [sampleNotification],
          ),
          child: const IncidentsListScreen(isEmbedded: false),
        ),
      );
      await tester.pumpAndSettle();

      await scrollAndAssertZeroVietnamese(tester, 'IncidentsListScreen (Populated)');
    });

    testWidgets('4.4 IncidentDetailScreen (all steps 0, 1, 2) renders under Locale("en") with ZERO Vietnamese text', (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      for (int step = 0; step <= 2; step++) {
        await tester.pumpWidget(
          buildEnglishHarness(
            child: IncidentDetailScreen(
              showcaseMode: true,
              initialStep: step,
            ),
          ),
        );
        await tester.pumpAndSettle();
        await scrollAndAssertZeroVietnamese(tester, 'IncidentDetailScreen (step $step)');
      }
    });

    // -------------------------------------------------------------------------
    // 5. Pairing Screens
    // -------------------------------------------------------------------------
    testWidgets('5.1 QrInviteScreen renders under Locale("en") with ZERO Vietnamese text', (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        buildEnglishHarness(
          child: const QrInviteScreen(initialCode: 'CR-TEST1234'),
        ),
      );
      await tester.pumpAndSettle();

      await scrollAndAssertZeroVietnamese(tester, 'QrInviteScreen');
    });

    testWidgets('5.2 QrScannerScreen renders under Locale("en") with ZERO Vietnamese text', (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        buildEnglishHarness(
          child: const QrScannerScreen(isTestMode: true),
        ),
      );
      await tester.pumpAndSettle();

      await scrollAndAssertZeroVietnamese(tester, 'QrScannerScreen');
    });

    // -------------------------------------------------------------------------
    // 6. Settings & Auxiliary Screens
    // -------------------------------------------------------------------------
    testWidgets('6.1 AccountSettingsScreen renders under Locale("en") with ZERO Vietnamese text', (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildEnglishHarness(child: const AccountSettingsScreen()));
      await tester.pumpAndSettle();

      await scrollAndAssertZeroVietnamese(tester, 'AccountSettingsScreen');
    });

    testWidgets('6.2 RelativeDetailScreen renders under Locale("en") with ZERO Vietnamese text', (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final rel = createEnglishSampleRelationship();
      await tester.pumpWidget(
        buildEnglishHarness(
          child: RelativeDetailScreen(
            relationship: rel,
            relativeData: const {
              'name': 'Jane Doe',
              'statusText': 'Active Protection',
              'lastConfirmed': '15/10/2025 • 08:32',
              'device': 'iPhone 15 Pro',
              'location': 'New York (on demand)',
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await scrollAndAssertZeroVietnamese(tester, 'RelativeDetailScreen');
    });

    testWidgets('6.3 CheckInScreen renders under Locale("en") with ZERO Vietnamese text', (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        buildEnglishHarness(
          child: CheckInScreen(
            confirmedAt: DateTime(2025, 10, 15, 8, 42),
            autoConfirmed: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await scrollAndAssertZeroVietnamese(tester, 'CheckInScreen');
    });

    testWidgets('6.4 SettingsScreen renders under Locale("en") with ZERO Vietnamese text', (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildEnglishHarness(child: const SettingsScreen()));
      await tester.pumpAndSettle();

      await scrollAndAssertZeroVietnamese(tester, 'SettingsScreen');
    });

    testWidgets('6.5 NotificationSettingsScreen renders under Locale("en") with ZERO Vietnamese text', (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildEnglishHarness(child: const NotificationSettingsScreen()));
      await tester.pumpAndSettle();

      await scrollAndAssertZeroVietnamese(tester, 'NotificationSettingsScreen');
    });

    testWidgets('6.6 PrivacySecurityScreen renders under Locale("en") with ZERO Vietnamese text', (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildEnglishHarness(child: const PrivacySecurityScreen()));
      await tester.pumpAndSettle();

      await scrollAndAssertZeroVietnamese(tester, 'PrivacySecurityScreen');
    });

    // -------------------------------------------------------------------------
    // 7. Adversarial Modals, Dialogs & Interactive Triggers
    // -------------------------------------------------------------------------
    testWidgets('7.1 SettingsScreen logout and delete-account dialogs render under Locale("en") with ZERO Vietnamese text', (tester) async {
      tester.view.physicalSize = const Size(375, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildEnglishHarness(child: const SettingsScreen()));
      await tester.pumpAndSettle();

      // Scroll to reveal logout and delete buttons
      final scrollable = find.byType(Scrollable);
      if (scrollable.evaluate().isNotEmpty) {
        await tester.drag(scrollable.first, const Offset(0, -500));
        await tester.pumpAndSettle();
      }

      // 1. Open Logout Dialog
      final logoutBtn = find.byIcon(Icons.logout_rounded);
      expect(logoutBtn, findsOneWidget);
      await tester.tap(logoutBtn);
      await tester.pumpAndSettle();

      assertZeroVietnameseInRenderedUI(tester, 'SettingsScreen -> Logout Dialog');

      // Dismiss dialog by tapping Cancel
      final cancelFinder = find.text('Cancel');
      if (cancelFinder.evaluate().isNotEmpty) {
        await tester.tap(cancelFinder.first);
        await tester.pumpAndSettle();
      }

      // 2. Open Delete Account Dialog
      final deleteBtn = find.byIcon(Icons.delete_outline_rounded);
      expect(deleteBtn, findsOneWidget);
      await tester.tap(deleteBtn);
      await tester.pumpAndSettle();

      assertZeroVietnameseInRenderedUI(tester, 'SettingsScreen -> Delete Account Dialog');

      // Dismiss dialog
      if (cancelFinder.evaluate().isNotEmpty) {
        await tester.tap(cancelFinder.first);
        await tester.pumpAndSettle();
      }
    });

    testWidgets('7.2 LoginScreen forgot password dialog renders under Locale("en") with ZERO Vietnamese text', (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildEnglishHarness(child: const LoginScreen()));
      await tester.pumpAndSettle();

      // Find forgot password button
      final forgotBtn = find.text('Forgot password?');
      if (forgotBtn.evaluate().isNotEmpty) {
        await tester.tap(forgotBtn);
        await tester.pumpAndSettle();
        assertZeroVietnameseInRenderedUI(tester, 'LoginScreen -> Forgot Password Dialog');
      }
    });

    testWidgets('7.3 QrScannerScreen manual connection code dialog renders under Locale("en") with ZERO Vietnamese text', (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        buildEnglishHarness(
          child: const QrScannerScreen(isTestMode: true),
        ),
      );
      await tester.pumpAndSettle();

      // Tap manual entry button
      final manualBtn = find.byKey(const Key('open_manual_input_button'));
      expect(manualBtn, findsOneWidget);
      await tester.tap(manualBtn);
      await tester.pumpAndSettle();

      assertZeroVietnameseInRenderedUI(tester, 'QrScannerScreen -> Manual Code Input Dialog');
    });

    testWidgets('7.4 MonitoringSettingsScreen weekday tab switching renders under Locale("en") with ZERO Vietnamese text', (tester) async {
      tester.view.physicalSize = const Size(375, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildEnglishHarness(child: const MonitoringSettingsScreen()));
      await tester.pumpAndSettle();

      // Look for day abbreviations Mon..Sun (from schedule_window_model localized dayNameShort)
      final dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      for (final day in dayNames) {
        final dayFinder = find.text(day);
        if (dayFinder.evaluate().isNotEmpty) {
          await tester.tap(dayFinder.first, warnIfMissed: false);
          await tester.pumpAndSettle();
          assertZeroVietnameseInRenderedUI(tester, 'MonitoringSettingsScreen -> Tab $day');
        }
      }
    });


    testWidgets('7.5 RegisterScreen validation errors render under Locale("en") with ZERO Vietnamese text', (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildEnglishHarness(child: const RegisterScreen()));
      await tester.pumpAndSettle();

      // Tap register button with empty form to trigger validation errors
      final submitBtn = find.byType(ElevatedButton);
      if (submitBtn.evaluate().isNotEmpty) {
        await tester.tap(submitBtn.first);
        await tester.pumpAndSettle();
        assertZeroVietnameseInRenderedUI(tester, 'RegisterScreen -> Form Validation Errors');
      }
    });
  });
}

