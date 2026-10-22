import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mobile/core/constants/app_colors.dart';
import 'package:mobile/core/i18n/app_localizations.dart';
import 'package:mobile/core/i18n/locale_catalog_registry.dart';
import 'package:mobile/core/i18n/locale_provider.dart';
import 'package:mobile/core/models/enums.dart';
import 'package:mobile/core/models/incident_model.dart';
import 'package:mobile/core/models/monitoring_config_model.dart';
import 'package:mobile/core/models/relationship_model.dart';
import 'package:mobile/core/models/schedule_window_model.dart';
import 'package:mobile/core/models/user_model.dart';
import 'package:mobile/features/auth/auth_provider.dart';
import 'package:mobile/features/check_in/check_in_screen.dart';
import 'package:mobile/features/dashboard/dashboard_provider.dart';
import 'package:mobile/features/dashboard/dashboard_screen.dart';
import 'package:mobile/features/dashboard/monitored_view.dart';
import 'package:mobile/features/incidents/incident_detail_screen.dart';
import 'package:mobile/features/incidents/incidents_provider.dart';
import 'package:mobile/features/settings/language_settings_screen.dart';

// =============================================================================
// ADVERSARIAL TEST DOUBLES & MOCK PROVIDERS
// =============================================================================

class AdversarialAuthProvider extends AuthProvider {
  final UserModel _user;

  AdversarialAuthProvider({UserModel? user})
      : _user = user ??
            UserModel(
              id: 'user-monitored-1',
              email: 'an@evernear.app',
              fullName: 'Nguyễn Văn An',
              phone: '+84 912 345 678',
              timezone: 'Asia/Ho_Chi_Minh',
              isActive: true,
              createdAt: DateTime(2025, 1, 1),
            );

  @override
  bool get isAuthenticated => true;

  @override
  bool get isLoading => false;

  @override
  UserModel? get currentUser => _user;
}

class AdversarialDashboardProvider extends DashboardProvider {
  int sendCheckInCallCount = 0;
  Completer<bool>? sendCheckInCompleter;
  bool sendCheckInThrows = false;
  bool sendCheckInReturnsFalse = false;
  String? lastCheckInNote;
  int? lastCheckInBattery;

  bool mockLastCheckInOffline = false;
  MonitoringState mockState = MonitoringState.ACTIVE;
  DateTime? mockLastActivity = DateTime(2025, 10, 15, 8, 42);

  List<RelationshipModel> mockAllRelationships = [];
  List<RelationshipModel> mockMonitoredByMe = [];
  List<RelationshipModel> mockMonitoringMe = [];

  int mockActiveIncidents = 0;
  int mockUnreadNotifications = 0;

  int fetchDashboardDataCallCount = 0;
  Completer<void>? fetchCompleter;

  @override
  bool get isLoading => false;

  @override
  String? get errorMessage => null;

  @override
  String? get currentUserId => 'user-monitor-1';

  @override
  int get activeIncidentsCount => mockActiveIncidents;

  @override
  int get unreadNotificationsCount => mockUnreadNotifications;

  @override
  List<RelationshipModel> get allRelationships => mockAllRelationships;

  @override
  List<RelationshipModel> get monitoredByMe => mockMonitoredByMe;

  @override
  List<RelationshipModel> get monitoringMe => mockMonitoringMe;

  @override
  MonitoringState get myCurrentState => mockState;

  @override
  DateTime? get myLastActivityAt => mockLastActivity;

  @override
  bool get lastCheckInOffline => mockLastCheckInOffline;

  @override
  Future<void> fetchDashboardData() async {
    fetchDashboardDataCallCount++;
    if (fetchCompleter != null) {
      await fetchCompleter!.future;
    }
  }

  @override
  Future<bool> sendCheckIn({
    String? note,
    int? batteryLevel,
    double? latitude,
    double? longitude,
  }) async {
    sendCheckInCallCount++;
    lastCheckInNote = note;
    lastCheckInBattery = batteryLevel;

    if (sendCheckInThrows) {
      throw Exception('Simulated check-in network failure');
    }

    if (sendCheckInReturnsFalse) {
      return false;
    }

    if (sendCheckInCompleter != null) {
      return await sendCheckInCompleter!.future;
    }

    mockLastActivity = DateTime.now();
    notifyListeners();
    return true;
  }

  void updateState(MonitoringState newState) {
    mockState = newState;
    notifyListeners();
  }

  void updateCounts({int active = 0, int unread = 0}) {
    mockActiveIncidents = active;
    mockUnreadNotifications = unread;
    notifyListeners();
  }

  void updateRelationships(List<RelationshipModel> list) {
    mockAllRelationships = list;
    mockMonitoredByMe = list;
    mockMonitoringMe = list;
    notifyListeners();
  }
}

class AdversarialIncidentsProvider extends IncidentsProvider {
  int acknowledgeCallCount = 0;
  int resolveCallCount = 0;
  String? lastAcknowledgedId;
  String? lastResolvedId;
  String? lastResolutionNote;

  bool resolveThrows = false;
  Completer<bool>? resolveCompleter;
  List<IncidentModel> mockIncidents = [];
  int mockUnread = 0;

  @override
  List<IncidentModel> get incidents => mockIncidents;

  @override
  bool get isLoading => false;

  @override
  String? get errorMessage => null;

  @override
  int get unreadCount => mockUnread;

  @override
  bool get hasUnreadIncidents => mockUnread > 0;

  @override
  String? get currentUserId => 'user-monitor-1';

  @override
  Future<void> fetchIncidents() async {}

  @override
  Future<IncidentModel?> getIncidentDetail(String incidentId) async {
    return mockIncidents.firstWhere(
      (i) => i.id == incidentId,
      orElse: () => _createSampleIncident(id: incidentId),
    );
  }

  @override
  Future<bool> acknowledgeIncident(String incidentId) async {
    acknowledgeCallCount++;
    lastAcknowledgedId = incidentId;
    return true;
  }

  @override
  Future<bool> resolveIncident(
    String incidentId, {
    String? resolutionNote,
  }) async {
    resolveCallCount++;
    lastResolvedId = incidentId;
    lastResolutionNote = resolutionNote;

    if (resolveThrows) {
      throw Exception('Simulated resolve exception');
    }

    if (resolveCompleter != null) {
      return await resolveCompleter!.future;
    }

    return true;
  }
}

// =============================================================================
// TEST HELPERS & BUILDERS
// =============================================================================

IncidentModel _createSampleIncident({
  String id = 'inc-adv-001',
  IncidentStatus status = IncidentStatus.OPEN,
  IncidentReason reason = IncidentReason.MISSED_CHECK_IN,
  int riskScore = 75,
}) {
  return IncidentModel(
    id: id,
    relationshipId: 'rel-sample-1',
    monitoredUserId: 'user-monitored-1',
    status: status,
    reason: reason,
    riskScore: riskScore,
    triggeredAt: DateTime(2025, 10, 14, 18, 20),
    resolutionNote: 'Em gái chưa xác nhận an toàn',
  );
}

RelationshipModel _createSampleRelationship({
  String id = 'rel-sample-1',
  String name = 'Mẹ',
  MonitoringState state = MonitoringState.ACTIVE,
}) {
  return RelationshipModel(
    id: id,
    monitoredUserId: 'user-monitored-1',
    monitorUserId: 'user-monitor-1',
    status: RelationshipStatus.ACCEPTED,
    createdAt: DateTime(2025, 1, 1),
    label: name,
    monitoredUser: UserModel(
      id: 'user-monitored-1',
      email: 'rel@evernear.app',
      fullName: name,
      phone: '+84 912 345 678',
      timezone: 'Asia/Ho_Chi_Minh',
      isActive: true,
      createdAt: DateTime(2025, 1, 1),
    ),
    config: MonitoringConfigModel(
      id: 'cfg-$id',
      relationshipId: id,
      currentState: state,
      inactivityThresholdMinutes: 180,
      checkInGracePeriodMinutes: 30,
      escalationGracePeriodMinutes: 30,
      locationEnabled: true,
      isPaused: false,
      timezone: 'Asia/Ho_Chi_Minh',
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

Widget buildTestableScreen({
  required Widget child,
  AuthProvider? authProvider,
  DashboardProvider? dashboardProvider,
  IncidentsProvider? incidentsProvider,
  LocaleProvider? localeProvider,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthProvider>.value(
        value: authProvider ?? AdversarialAuthProvider(),
      ),
      ChangeNotifierProvider<DashboardProvider>.value(
        value: dashboardProvider ?? AdversarialDashboardProvider(),
      ),
      ChangeNotifierProvider<IncidentsProvider>.value(
        value: incidentsProvider ?? AdversarialIncidentsProvider(),
      ),
      ChangeNotifierProvider<LocaleProvider>.value(
        value: localeProvider ?? LocaleProvider(),
      ),
    ],
    child: Consumer<LocaleProvider>(
      builder: (context, locProv, _) {
        return MaterialApp(
          locale: locProv.currentLocale,
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
              error: AppColors.danger,
            ),
          ),
          home: child is Scaffold
              ? child
              : Scaffold(
                  backgroundColor: AppColors.background,
                  body: child,
                ),
        );
      },
    ),
  );
}

void configureTestErrorHandling(List<FlutterErrorDetails> overflowErrors) {
  final oldHandler = FlutterError.onError;
  FlutterError.onError = (details) {
    final str = details.toString();
    if (str.contains('RenderFlex overflowed')) {
      overflowErrors.add(details);
    }
    if (str.contains('ListTile background color or ink splashes may be invisible')) {
      return;
    }
    oldHandler?.call(details);
  };
  addTearDown(() => FlutterError.onError = oldHandler);
}

void verifyNoLayoutOverflowOrFatalErrors(
  WidgetTester tester,
  List<FlutterErrorDetails> overflowErrors,
) {
  expect(overflowErrors, isEmpty, reason: 'Expected zero RenderFlex overflow errors');
  final ex = tester.takeException();
  if (ex != null) {
    final str = ex.toString();
    if (!str.contains('ListTile background color or ink splashes may be invisible')) {
      fail('Unexpected fatal exception: $ex');
    }
  }
}

// =============================================================================
// MAIN EMPIRICAL ADVERSARIAL STRESS TEST SUITE
// =============================================================================

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    // Clear SharedPreferences before each test
    SharedPreferences.setMockInitialValues({
      'evernear_app_locale': 'vi',
      'evernear_user_id': 'user-monitor-1',
    });
    AppLocalizations.globalLocaleCode = 'vi';
  });

  // ===========================================================================
  // GROUP 1: RAPID MODE TOGGLING IN DASHBOARDSCREEN
  // ===========================================================================
  group('1. Rapid Mode Toggling between Monitored & Guardian in DashboardScreen', () {
    testWidgets(
      '1.1 High-frequency programmatic toggle stress (50 rapid switches) leaves state consistent',
      (tester) async {
        tester.view.physicalSize = const Size(375, 812);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final List<FlutterErrorDetails> overflowErrors = [];
        configureTestErrorHandling(overflowErrors);

        final dashProvider = AdversarialDashboardProvider();

        await tester.pumpWidget(
          buildTestableScreen(
            child: const DashboardScreen(),
            dashboardProvider: dashProvider,
          ),
        );
        await tester.pumpAndSettle();

        // Initial state: Monitored Mode (tab 0)
        expect(dashProvider.selectedTabIndex, 0);
        expect(find.text('Xin chào, An 👋'), findsOneWidget);

        // Hammer 50 rapid alternating switches between Tab 0 (Monitored) and Tab 1 (Guardian)
        for (int i = 1; i <= 50; i++) {
          final targetTab = i % 2; // 1, 0, 1, 0...
          dashProvider.setSelectedTabIndex(targetTab);
        }

        // Pump frames to complete IndexedStack transition
        await tester.pumpAndSettle();

        verifyNoLayoutOverflowOrFatalErrors(tester, overflowErrors);

        // 50th toggle: 50 % 2 == 0 (Monitored Mode)
        expect(dashProvider.selectedTabIndex, 0);
        expect(find.text('Xin chào, An 👋'), findsOneWidget);
        expect(find.text('Tôi vẫn ổn'), findsOneWidget);

        // Switch once more to Guardian Mode (tab 1)
        dashProvider.setSelectedTabIndex(1);
        await tester.pumpAndSettle();

        expect(dashProvider.selectedTabIndex, 1);
        expect(find.text('Danh sách người thân'), findsOneWidget);
        verifyNoLayoutOverflowOrFatalErrors(tester, overflowErrors);
      },
    );

    testWidgets(
      '1.2 Interactive bottom nav bar tap toggling (20 round trips) without UI crash',
      (tester) async {
        tester.view.physicalSize = const Size(375, 812);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final List<FlutterErrorDetails> overflowErrors = [];
        configureTestErrorHandling(overflowErrors);

        final dashProvider = AdversarialDashboardProvider();

        await tester.pumpWidget(
          buildTestableScreen(
            child: const DashboardScreen(),
            dashboardProvider: dashProvider,
          ),
        );
        await tester.pumpAndSettle();

        // 20 rapid interactive taps between Tab 0 and Tab 1 using tab icons
        for (int i = 0; i < 20; i++) {
          // Tap Tab 1 (Guardian Mode: Icons.group_outlined)
          final familyIcon = find.byIcon(Icons.group_outlined);
          expect(familyIcon, findsOneWidget);
          await tester.tap(familyIcon);
          await tester.pump(const Duration(milliseconds: 16));

          // Tap Tab 0 (Monitored Mode: Icons.home_outlined)
          final homeIcon = find.byIcon(Icons.home_outlined);
          expect(homeIcon, findsOneWidget);
          await tester.tap(homeIcon);
          await tester.pump(const Duration(milliseconds: 16));
        }

        await tester.pumpAndSettle();
        verifyNoLayoutOverflowOrFatalErrors(tester, overflowErrors);

        expect(dashProvider.selectedTabIndex, 0);
        expect(find.text('Tôi vẫn ổn'), findsOneWidget);
      },
    );

    testWidgets(
      '1.3 Concurrent state mutations (risk score, incidents, relationships) during rapid toggling',
      (tester) async {
        tester.view.physicalSize = const Size(375, 812);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final List<FlutterErrorDetails> overflowErrors = [];
        configureTestErrorHandling(overflowErrors);

        final dashProvider = AdversarialDashboardProvider();

        await tester.pumpWidget(
          buildTestableScreen(
            child: const DashboardScreen(),
            dashboardProvider: dashProvider,
          ),
        );
        await tester.pumpAndSettle();

        final states = [
          MonitoringState.ACTIVE,
          MonitoringState.CHECK_IN_REQUIRED,
          MonitoringState.GRACE_PERIOD,
          MonitoringState.ALERT_TRIGGERED,
          MonitoringState.PAUSED,
        ];

        // While alternating tabs, mutate provider state simultaneously
        for (int i = 0; i < 25; i++) {
          final targetTab = i % 2;
          dashProvider.setSelectedTabIndex(targetTab);

          // Mutate state
          dashProvider.updateState(states[i % states.length]);
          dashProvider.updateCounts(active: i % 4, unread: i * 2);

          if (i == 10) {
            dashProvider.updateRelationships([
              _createSampleRelationship(id: 'rel-1', name: 'Mẹ'),
              _createSampleRelationship(id: 'rel-2', name: 'Bố'),
            ]);
          }

          await tester.pump(const Duration(milliseconds: 20));
        }

        await tester.pumpAndSettle();
        verifyNoLayoutOverflowOrFatalErrors(tester, overflowErrors);

        // State integrity maintained
        expect(dashProvider.activeIncidentsCount, 24 % 4);
        expect(dashProvider.unreadNotificationsCount, 24 * 2);
      },
    );

    testWidgets(
      '1.4 In-flight asynchronous refresh survives tab toggling without exception',
      (tester) async {
        tester.view.physicalSize = const Size(375, 812);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final List<FlutterErrorDetails> overflowErrors = [];
        configureTestErrorHandling(overflowErrors);

        final dashProvider = AdversarialDashboardProvider();
        final completer = Completer<void>();
        dashProvider.fetchCompleter = completer;

        await tester.pumpWidget(
          buildTestableScreen(
            child: const DashboardScreen(),
            dashboardProvider: dashProvider,
          ),
        );
        await tester.pump();

        // Trigger fetchDashboardData while switching tabs
        dashProvider.fetchDashboardData();
        await tester.pump();

        // Now rapidly switch tabs while fetchDashboardData() is still in flight
        dashProvider.setSelectedTabIndex(1);
        await tester.pump();
        dashProvider.setSelectedTabIndex(0);
        await tester.pump();
        dashProvider.setSelectedTabIndex(1);
        await tester.pump();

        // Now resolve the async fetch
        completer.complete();
        await tester.pumpAndSettle();

        verifyNoLayoutOverflowOrFatalErrors(tester, overflowErrors);
        expect(dashProvider.fetchDashboardDataCallCount, greaterThanOrEqualTo(1));
      },
    );
  });

  // ===========================================================================
  // GROUP 2: CHECK-IN BUTTON TAP SIMULATION & CONFIRMATION FLOW
  // ===========================================================================
  group('2. Check-In Button Tap Simulation & Confirmation Flow', () {
    testWidgets(
      '2.1 Hammer-tap re-entrancy stress on MonitoredView check-in button triggers exactly once',
      (tester) async {
        tester.view.physicalSize = const Size(375, 812);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final List<FlutterErrorDetails> overflowErrors = [];
        configureTestErrorHandling(overflowErrors);

        final dashProvider = AdversarialDashboardProvider();
        final checkInCompleter = Completer<bool>();
        dashProvider.sendCheckInCompleter = checkInCompleter;

        await tester.pumpWidget(
          buildTestableScreen(
            child: const MonitoredView(),
            dashboardProvider: dashProvider,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Tôi vẫn ổn'), findsOneWidget);

        // Find the GestureDetector wrapping the central concentric check-in button
        final checkInGesture = find.byWidgetPredicate(
          (w) => w is GestureDetector && w.child is RepaintBoundary,
        );
        expect(checkInGesture, findsOneWidget);

        // Hammer the gesture detector 10 times in rapid succession before completer finishes
        for (int i = 0; i < 10; i++) {
          await tester.tap(checkInGesture, warnIfMissed: false);
          await tester.pump(const Duration(milliseconds: 5));
        }

        // Assert re-entrancy guard: sendCheckIn was called exactly ONCE!
        expect(dashProvider.sendCheckInCallCount, 1);

        // Now complete the pending check-in
        checkInCompleter.complete(true);
        await tester.pumpAndSettle();

        verifyNoLayoutOverflowOrFatalErrors(tester, overflowErrors);

        // CheckInScreen was pushed
        expect(find.text('Xác nhận an toàn'), findsOneWidget);
        expect(find.text('Tuyệt vời!\nBạn vẫn ổn!'), findsOneWidget);
      },
    );

    testWidgets(
      '2.2 Network failure during check-in releases re-entrancy guard safely',
      (tester) async {
        tester.view.physicalSize = const Size(375, 812);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final List<FlutterErrorDetails> overflowErrors = [];
        configureTestErrorHandling(overflowErrors);

        final dashProvider = AdversarialDashboardProvider();
        dashProvider.sendCheckInReturnsFalse = true; // Inject simulated network failure response

        await tester.pumpWidget(
          buildTestableScreen(
            child: const MonitoredView(),
            dashboardProvider: dashProvider,
          ),
        );
        await tester.pumpAndSettle();

        final checkInGesture = find.byWidgetPredicate(
          (w) => w is GestureDetector && w.child is RepaintBoundary,
        );
        expect(checkInGesture, findsOneWidget);

        // Tap once -> returns false
        await tester.tap(checkInGesture);
        await tester.pumpAndSettle();

        // Empirical check: sendCheckIn was called once
        expect(dashProvider.sendCheckInCallCount, 1);

        // Hardened behavior verification: MonitoredView does NOT push CheckInScreen when sendCheckIn returns false
        expect(find.byType(CheckInScreen), findsNothing);
        expect(find.byType(SnackBar), findsOneWidget);
        expect(find.text('Không thể gửi xác nhận. Vui lòng thử lại.'), findsOneWidget);

        // Still on MonitoredView: verify "Tôi vẫn ổn" is visible
        expect(find.text('Tôi vẫn ổn'), findsOneWidget);

        // Disable failure and verify user can tap again successfully
        dashProvider.sendCheckInReturnsFalse = false;
        final checkInGestureAfterError = find.byWidgetPredicate(
          (w) => w is GestureDetector && w.child is RepaintBoundary,
        );
        expect(checkInGestureAfterError, findsOneWidget);
        await tester.tap(checkInGestureAfterError);
        await tester.pumpAndSettle();

        expect(dashProvider.sendCheckInCallCount, 2);
        expect(find.byType(CheckInScreen), findsOneWidget);
      },
    );

    testWidgets(
      '2.3 Offline check-in displays queued offline confirmation banner',
      (tester) async {
        tester.view.physicalSize = const Size(375, 812);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final List<FlutterErrorDetails> overflowErrors = [];
        configureTestErrorHandling(overflowErrors);

        final dashProvider = AdversarialDashboardProvider();
        dashProvider.mockLastCheckInOffline = true;

        await tester.pumpWidget(
          buildTestableScreen(
            child: const MonitoredView(),
            dashboardProvider: dashProvider,
          ),
        );
        await tester.pumpAndSettle();

        final checkInGesture = find.byWidgetPredicate(
          (w) => w is GestureDetector && w.child is RepaintBoundary,
        );
        await tester.tap(checkInGesture);
        await tester.pumpAndSettle();

        // Verify offline message was displayed in SnackBar
        expect(
          find.text('Đã lưu xác nhận an toàn vào bộ nhớ máy. Ứng dụng sẽ tự động gửi khi có mạng'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      '2.4 CheckInScreen confirmation flow: note input, tap Hoàn tất, clean pop',
      (tester) async {
        tester.view.physicalSize = const Size(375, 812);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final List<FlutterErrorDetails> overflowErrors = [];
        configureTestErrorHandling(overflowErrors);

        final dashProvider = AdversarialDashboardProvider();

        await tester.pumpWidget(
          buildTestableScreen(
            child: CheckInScreen(
              confirmedAt: DateTime(2025, 10, 15, 8, 42),
            ),
            dashboardProvider: dashProvider,
          ),
        );
        await tester.pumpAndSettle();

        // Verify initial screen state
        expect(find.text('Xác nhận an toàn'), findsOneWidget);
        expect(find.text('Tuyệt vời!\nBạn vẫn ổn!'), findsOneWidget);
        expect(find.text('08:42 • 15/10/2025'), findsOneWidget);

        final hoanTatBtn = find.widgetWithText(ElevatedButton, 'Hoàn tất');
        expect(hoanTatBtn, findsOneWidget);

        // Tap "Hoàn tất"
        await tester.tap(hoanTatBtn);
        await tester.pumpAndSettle();

        verifyNoLayoutOverflowOrFatalErrors(tester, overflowErrors);
        expect(dashProvider.sendCheckInCallCount, 1);
      },
    );

    testWidgets(
      '2.5 Collision stress: Hoàn tất tap while submitting prevents duplicate calls',
      (tester) async {
        tester.view.physicalSize = const Size(375, 812);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final List<FlutterErrorDetails> overflowErrors = [];
        configureTestErrorHandling(overflowErrors);

        final dashProvider = AdversarialDashboardProvider();
        final completer = Completer<bool>();
        dashProvider.sendCheckInCompleter = completer;

        await tester.pumpWidget(
          buildTestableScreen(
            child: const CheckInScreen(),
            dashboardProvider: dashProvider,
          ),
        );
        await tester.pumpAndSettle();

        // Tap Hoàn tất (pending)
        final hoanTatBtn = find.widgetWithText(ElevatedButton, 'Hoàn tất');
        expect(hoanTatBtn, findsOneWidget);
        await tester.tap(hoanTatBtn);
        await tester.pump(const Duration(milliseconds: 50));

        // Progress indicator is showing while submitting
        expect(find.byType(CircularProgressIndicator), findsOneWidget);

        // While submitting, tap the ElevatedButton again (find by type since text is replaced)
        final submittingBtn = find.byType(ElevatedButton).first;
        await tester.tap(submittingBtn, warnIfMissed: false);
        await tester.pump(const Duration(milliseconds: 50));

        // Assert re-entrancy protection: exactly 1 call
        expect(dashProvider.sendCheckInCallCount, 1);

        // Complete check-in
        completer.complete(true);
        await tester.pumpAndSettle();

        verifyNoLayoutOverflowOrFatalErrors(tester, overflowErrors);
      },
    );

    testWidgets(
      '2.6 Uncaught exception during check-in is caught gracefully and shows error SnackBar',
      (tester) async {
        tester.view.physicalSize = const Size(375, 812);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final List<FlutterErrorDetails> overflowErrors = [];
        configureTestErrorHandling(overflowErrors);

        final dashProvider = AdversarialDashboardProvider();
        dashProvider.sendCheckInThrows = true;

        await tester.pumpWidget(
          buildTestableScreen(
            child: const MonitoredView(),
            dashboardProvider: dashProvider,
          ),
        );
        await tester.pumpAndSettle();

        final checkInGesture = find.byWidgetPredicate(
          (w) => w is GestureDetector && w.child is RepaintBoundary,
        );
        expect(checkInGesture, findsOneWidget);

        // Tap once -> throws exception, caught gracefully
        await tester.tap(checkInGesture);
        await tester.pumpAndSettle();

        expect(dashProvider.sendCheckInCallCount, 1);
        expect(find.byType(CheckInScreen), findsNothing);
        expect(find.byType(SnackBar), findsOneWidget);
        expect(find.text('Không thể gửi xác nhận. Vui lòng thử lại.'), findsOneWidget);
        expect(find.text('Tôi vẫn ổn'), findsOneWidget);
      },
    );
  });

  // ===========================================================================
  // GROUP 3: INCIDENT RESOLUTION MULTI-STEP TRANSITION IN INCIDENTDETAILSCREEN
  // ===========================================================================
  group('3. Incident Resolution Multi-Step Transition in IncidentDetailScreen', () {
    testWidgets(
      '3.1 Rapid step cycling (30 transitions across 0 -> 1 -> 2) retains zero overflow',
      (tester) async {
        tester.view.physicalSize = const Size(375, 812);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final List<FlutterErrorDetails> overflowErrors = [];
        configureTestErrorHandling(overflowErrors);

        final incidentsProvider = AdversarialIncidentsProvider();
        final sampleIncident = _createSampleIncident();

        await tester.pumpWidget(
          buildTestableScreen(
            child: IncidentDetailScreen(
              incident: sampleIncident,
              showcaseMode: true,
              initialStep: 0,
            ),
            incidentsProvider: incidentsProvider,
          ),
        );
        await tester.pumpAndSettle();

        // Rapidly cycle across step tabs: 0 (Cảnh báo), 1 (Chi tiết sự cố), 2 (Xử lý sự cố)
        final step0Tab = find.text('Cảnh báo').first;
        final step1Tab = find.text('Chi tiết sự cố').first;
        final step2Tab = find.text('Xử lý sự cố').first;

        for (int i = 0; i < 10; i++) {
          await tester.tap(step1Tab);
          await tester.pump(const Duration(milliseconds: 10));

          await tester.tap(step2Tab);
          await tester.pump(const Duration(milliseconds: 10));

          await tester.tap(step0Tab);
          await tester.pump(const Duration(milliseconds: 10));
        }

        await tester.pumpAndSettle();
        verifyNoLayoutOverflowOrFatalErrors(tester, overflowErrors);

        // Land on Step 0 cleanly
        expect(find.text('Cảnh báo an toàn'), findsOneWidget);
        expect(find.text('Không nhận được phản hồi'), findsOneWidget);
      },
    );

    testWidgets(
      '3.2 Full progressive resolution: Step 0 -> Step 1 -> Step 2 -> note -> resolve',
      (tester) async {
        tester.view.physicalSize = const Size(375, 812);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final List<FlutterErrorDetails> overflowErrors = [];
        configureTestErrorHandling(overflowErrors);

        final incidentsProvider = AdversarialIncidentsProvider();
        final sampleIncident = _createSampleIncident(id: 'inc-adv-flow-101');

        await tester.pumpWidget(
          buildTestableScreen(
            child: IncidentDetailScreen(
              incident: sampleIncident,
              showcaseMode: true,
              initialStep: 0,
            ),
            incidentsProvider: incidentsProvider,
          ),
        );
        await tester.pumpAndSettle();

        // Step 0: Tap "Xem chi tiết"
        final xemChiTietBtn = find.text('Xem chi tiết');
        expect(xemChiTietBtn, findsOneWidget);
        await tester.tap(xemChiTietBtn);
        await tester.pumpAndSettle();

        // Now on Step 1: Verify cards
        expect(find.text('Tóm tắt sự cố'), findsOneWidget);
        expect(find.text('Timeline sự kiện'), findsOneWidget);

        // Step 1: Tap "Xử lý sự cố" button
        final xuLySuCoBtn = find.widgetWithText(ElevatedButton, 'Xử lý sự cố');
        expect(xuLySuCoBtn, findsOneWidget);
        await tester.tap(xuLySuCoBtn);
        await tester.pumpAndSettle();

        // Now on Step 2: Verify cards & note field
        expect(find.text('Trạng thái hiện tại'), findsOneWidget);
        expect(find.text('Ghi chú xử lý'), findsOneWidget);

        final noteField = find.byType(TextField);
        expect(noteField, findsOneWidget);
        await tester.enterText(
          noteField,
          'Đã liên hệ người thân an toàn tại nhà',
        );
        await tester.pumpAndSettle();

        // Tap "Đánh dấu đã xử lý"
        final danhDauBtn = find.widgetWithText(ElevatedButton, 'Đánh dấu đã xử lý');
        expect(danhDauBtn, findsOneWidget);
        await tester.tap(danhDauBtn);
        await tester.pumpAndSettle();

        verifyNoLayoutOverflowOrFatalErrors(tester, overflowErrors);

        // Verify provider call payload
        expect(incidentsProvider.resolveCallCount, 1);
        expect(incidentsProvider.lastResolvedId, 'inc-adv-flow-101');
        expect(
          incidentsProvider.lastResolutionNote,
          'Đã liên hệ người thân an toàn tại nhà',
        );
      },
    );

    testWidgets(
      '3.3 False alarm ("Báo động giả") resolution flow submits default note',
      (tester) async {
        tester.view.physicalSize = const Size(375, 812);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final List<FlutterErrorDetails> overflowErrors = [];
        configureTestErrorHandling(overflowErrors);

        final incidentsProvider = AdversarialIncidentsProvider();
        final sampleIncident = _createSampleIncident(id: 'inc-adv-false-alarm');

        await tester.pumpWidget(
          buildTestableScreen(
            child: IncidentDetailScreen(
              incident: sampleIncident,
              showcaseMode: true,
              initialStep: 2,
            ),
            incidentsProvider: incidentsProvider,
          ),
        );
        await tester.pumpAndSettle();

        final baoDongGiaBtn = find.widgetWithText(ElevatedButton, 'Báo động giả');
        expect(baoDongGiaBtn, findsOneWidget);
        await tester.tap(baoDongGiaBtn);
        await tester.pumpAndSettle();

        verifyNoLayoutOverflowOrFatalErrors(tester, overflowErrors);

        expect(incidentsProvider.resolveCallCount, 1);
        expect(incidentsProvider.lastResolvedId, 'inc-adv-false-alarm');
        expect(incidentsProvider.lastResolutionNote, 'Báo động giả');
      },
    );

    testWidgets(
      '3.4 Resolution error resilience resets loading indicator and preserves state',
      (tester) async {
        tester.view.physicalSize = const Size(375, 812);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final List<FlutterErrorDetails> overflowErrors = [];
        configureTestErrorHandling(overflowErrors);

        final incidentsProvider = AdversarialIncidentsProvider();
        incidentsProvider.resolveThrows = true; // Inject error

        final sampleIncident = _createSampleIncident(id: 'inc-adv-err-test');

        await tester.pumpWidget(
          buildTestableScreen(
            child: IncidentDetailScreen(
              incident: sampleIncident,
              showcaseMode: true,
              initialStep: 2,
            ),
            incidentsProvider: incidentsProvider,
          ),
        );
        await tester.pumpAndSettle();

        final danhDauBtn = find.widgetWithText(ElevatedButton, 'Đánh dấu đã xử lý');
        await tester.tap(danhDauBtn);
        await tester.pumpAndSettle();

        // Screen must not crash; button remains enabled
        expect(find.text('Trạng thái hiện tại'), findsOneWidget);
        expect(danhDauBtn, findsOneWidget);

        // Now fix provider and retry
        incidentsProvider.resolveThrows = false;
        await tester.tap(danhDauBtn);
        await tester.pumpAndSettle();

        expect(incidentsProvider.resolveCallCount, 2);
      },
    );
  });

  // ===========================================================================
  // GROUP 4: RAPID LOCALE SWITCHING ACROSS CATALOGS
  // ===========================================================================
  group('4. Rapid Locale Switching Across Catalogs without UI Crash', () {
    testWidgets(
      '4.1 Rapid-fire switching across Tier-1 languages (vi, en, ja, zh) on DashboardScreen',
      (tester) async {
        tester.view.physicalSize = const Size(375, 812);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final List<FlutterErrorDetails> overflowErrors = [];
        configureTestErrorHandling(overflowErrors);

        final localeProvider = LocaleProvider();
        await localeProvider.initialize();

        await tester.pumpWidget(
          buildTestableScreen(
            child: const DashboardScreen(),
            localeProvider: localeProvider,
          ),
        );
        await tester.pumpAndSettle();

        final tier1Featured = ['vi', 'en', 'ja', 'zh'];

        // Rapidly switch through all 4 featured Tier-1 languages
        for (final langCode in tier1Featured) {
          await localeProvider.setLocale(Locale(langCode));
          await tester.pumpAndSettle();
          expect(localeProvider.currentLocale.languageCode, langCode);
          expect(AppLocalizations.globalLocaleCode, langCode);
        }

        verifyNoLayoutOverflowOrFatalErrors(tester, overflowErrors);

        // Switch cleanly back to Vietnamese
        await localeProvider.setLocale(const Locale('vi'));
        await tester.pumpAndSettle();

        expect(localeProvider.currentLocale.languageCode, 'vi');
        expect(find.text('Tôi vẫn ổn'), findsOneWidget);
      },
    );

    testWidgets(
      '4.2 Hardened: German locale ("Mir geht es gut") scales down cleanly without RenderFlex overflow in check-in button',
      (tester) async {
        tester.view.physicalSize = const Size(375, 812);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final List<FlutterErrorDetails> overflowErrors = [];
        configureTestErrorHandling(overflowErrors);

        final localeProvider = LocaleProvider();
        await localeProvider.initialize();

        await tester.pumpWidget(
          buildTestableScreen(
            child: const DashboardScreen(),
            localeProvider: localeProvider,
          ),
        );
        await tester.pumpAndSettle();

        // Switch to German ('de') where 'check_in_button' is 'Mir geht es gut'
        await localeProvider.setLocale(const Locale('de'));
        await tester.pumpAndSettle();

        // Verify hardened behavior: zero RenderFlex overflow on Column with German text
        verifyNoLayoutOverflowOrFatalErrors(tester, overflowErrors);
        expect(find.text('Mir geht es gut'), findsOneWidget);

        // Restore back to Vietnamese
        await localeProvider.setLocale(const Locale('vi'));
        await tester.pumpAndSettle();
        expect(find.text('Tôi vẫn ổn'), findsOneWidget);
      },
    );

    test('4.3 Concurrent parallel setLocale requests resolve without state corruption', () async {
      final localeProvider = LocaleProvider();
      await localeProvider.initialize();

      final candidateLocales = ['en', 'fr', 'de', 'es', 'ja', 'vi'];

      // Fire 20 parallel calls concurrently
      final futures = <Future<void>>[];
      for (int i = 0; i < 20; i++) {
        final code = candidateLocales[i % candidateLocales.length];
        futures.add(localeProvider.setLocale(Locale(code)));
      }

      await Future.wait(futures);

      // Verify provider consistency
      final finalCode = localeProvider.currentLocale.languageCode;
      expect(candidateLocales, contains(finalCode));
      expect(AppLocalizations.globalLocaleCode, finalCode);
    });

    test('4.4 Invalid locale code injection is rejected safely with fallback intact', () async {
      final localeProvider = LocaleProvider();
      await localeProvider.initialize();

      final initialCode = localeProvider.currentLocale.languageCode;

      // Attempt invalid/unsupported locale
      await localeProvider.setLocale(const Locale('xyz_unknown_999'));

      // Current locale must remain unchanged
      expect(localeProvider.currentLocale.languageCode, initialCode);
    });

    testWidgets(
      '4.5 Round-trip catalog integrity: Vietnamese copywriting matches exactly after multi-language cycling',
      (tester) async {
        tester.view.physicalSize = const Size(375, 812);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final List<FlutterErrorDetails> overflowErrors = [];
        configureTestErrorHandling(overflowErrors);

        final localeProvider = LocaleProvider();
        await localeProvider.initialize();

        await tester.pumpWidget(
          buildTestableScreen(
            child: const LanguageSettingsScreen(),
            localeProvider: localeProvider,
          ),
        );
        await tester.pumpAndSettle();

        // Switch across distinct linguistic families: Arabic (RTL), Japanese, French, then Vietnamese
        await localeProvider.setLocale(const Locale('ar'));
        await tester.pumpAndSettle();
        await localeProvider.setLocale(const Locale('ja'));
        await tester.pumpAndSettle();
        await localeProvider.setLocale(const Locale('fr'));
        await tester.pumpAndSettle();
        await localeProvider.setLocale(const Locale('vi'));
        await tester.pumpAndSettle();

        verifyNoLayoutOverflowOrFatalErrors(tester, overflowErrors);

        // Verify key Vietnamese copy in LanguageSettingsScreen
        expect(find.text('Cài đặt Ngôn ngữ / Language'), findsOneWidget);
        expect(find.text('Ngôn ngữ thiết bị'), findsOneWidget);
        expect(find.text('Tự động theo thiết bị'), findsOneWidget);
        expect(find.text('Tiếng Việt (VN)'), findsOneWidget);
      },
    );
  });
}
