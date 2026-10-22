import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mobile/core/constants/app_colors.dart';
import 'package:mobile/core/i18n/locale_provider.dart';
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
import 'package:mobile/features/dashboard/dashboard_provider.dart';
import 'package:mobile/features/dashboard/dashboard_screen.dart';
import 'package:mobile/features/dashboard/guardian_view.dart';
import 'package:mobile/features/dashboard/monitor_view.dart';
import 'package:mobile/features/dashboard/monitored_view.dart';
import 'package:mobile/features/devices/devices_screen.dart';
import 'package:mobile/features/incidents/incident_detail_screen.dart';
import 'package:mobile/features/incidents/incidents_list_screen.dart';
import 'package:mobile/features/incidents/incidents_provider.dart';
import 'package:mobile/features/monitoring/monitoring_settings_screen.dart';
import 'package:mobile/features/pairing/qr_invite_screen.dart';
import 'package:mobile/features/pairing/qr_scanner_screen.dart';
import 'package:mobile/features/settings/account_settings_screen.dart';
import 'package:mobile/features/settings/language_settings_screen.dart';
import 'package:mobile/features/settings/settings_screen.dart';

class _ChallengerMockDashboardProvider extends DashboardProvider {
  final List<RelationshipModel> _mockRelationships;
  final int _incidentCount;

  _ChallengerMockDashboardProvider({
    List<RelationshipModel>? relationships,
    this._incidentCount = 0,
  }) : _mockRelationships = relationships ?? [];

  @override
  bool get isLoading => false;

  @override
  int get activeIncidentsCount => _incidentCount;

  @override
  List<RelationshipModel> get allRelationships => _mockRelationships;

  @override
  List<RelationshipModel> get monitoredByMe => _mockRelationships;

  @override
  List<RelationshipModel> get monitoringMe => _mockRelationships;

  @override
  MonitoringState get myCurrentState => MonitoringState.ACTIVE;

  @override
  DateTime? get myLastActivityAt => DateTime(2026, 10, 16, 9, 30);

  @override
  Future<void> fetchDashboardData() async {}
}

class _ChallengerMockIncidentsProvider extends IncidentsProvider {
  final List<IncidentModel> _mockIncidents;

  _ChallengerMockIncidentsProvider({List<IncidentModel>? incidents})
      : _mockIncidents = incidents ?? [];

  @override
  List<IncidentModel> get incidents => _mockIncidents;

  @override
  bool get isLoading => false;

  @override
  String? get errorMessage => null;

  @override
  Future<void> fetchIncidents() async {}
}

RelationshipModel _createSampleRelationship(String id, {String name = 'Mẹ'}) {
  return RelationshipModel(
    id: id,
    monitoredUserId: 'user-monitored-$id',
    monitorUserId: 'user-monitor-$id',
    status: RelationshipStatus.ACCEPTED,
    createdAt: DateTime.now(),
    label: name,
    monitoredUser: UserModel(
      id: 'user-monitored-$id',
      email: '$id@carely.vn',
      fullName: name,
      timezone: 'Asia/Ho_Chi_Minh',
      isActive: true,
      createdAt: DateTime.now(),
    ),
    config: MonitoringConfigModel(
      id: 'cfg-$id',
      relationshipId: id,
      currentState: MonitoringState.ACTIVE,
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

IncidentModel _createSampleIncident(String id, {int riskScore = 42}) {
  return IncidentModel(
    id: id,
    relationshipId: 'rel-test',
    monitoredUserId: 'user-monitored-1',
    status: IncidentStatus.OPEN,
    reason: IncidentReason.MISSED_CHECK_IN,
    riskScore: riskScore,
    triggeredAt: DateTime(2026, 10, 16, 8, 15),
  );
}

Widget _wrapWithProviders({
  required Widget child,
  DashboardProvider? dashboardProvider,
  IncidentsProvider? incidentsProvider,
  AuthProvider? authProvider,
  LocaleProvider? localeProvider,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<DashboardProvider>.value(
        value: dashboardProvider ??
            _ChallengerMockDashboardProvider(
              relationships: [_createSampleRelationship('rel-1')],
            ),
      ),
      ChangeNotifierProvider<IncidentsProvider>.value(
        value: incidentsProvider ??
            _ChallengerMockIncidentsProvider(
              incidents: [_createSampleIncident('inc-1')],
            ),
      ),
      ChangeNotifierProvider<AuthProvider>.value(
        value: authProvider ?? AuthProvider(),
      ),
      if (localeProvider != null)
        ChangeNotifierProvider<LocaleProvider>.value(
          value: localeProvider,
        ),
    ],
    child: MaterialApp(
      theme: ThemeData(
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
      ),
      home: child,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'carely_user_id': 'user-monitored-1',
      'carely_device_uid': 'device-test-uuid',
    });
    await LocalStorage.saveAuth(
      accessToken: 'mock_token',
      refreshToken: 'mock_refresh',
      userId: 'user-monitored-1',
      email: 'user@carely.vn',
      fullName: 'Nguyễn Văn A',
    );
  });

  const viewports = <String, Size>{
    'iPhone Standard (375x812)': Size(375, 812),
    'iPhone Compact (320x568)': Size(320, 568),
  };

  void verifyNoOverflow(WidgetTester tester, Size size) {
    expect(tester.takeException(), isNull,
        reason: 'Widget must not throw any exception at $size');
  }

  group('Empirical Challenger: Responsive Viewport Bounds & Zero RenderFlex Overflows', () {
    for (final entry in viewports.entries) {
      final name = entry.key;
      final size = entry.value;

      group('Viewport $name', () {
        testWidgets('1. LoginScreen renders within bounds without RenderFlex overflow', (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() => tester.view.resetPhysicalSize());

          await tester.pumpWidget(_wrapWithProviders(child: const LoginScreen()));
          await tester.pumpAndSettle();

          verifyNoOverflow(tester, size);
          expect(find.byType(LoginScreen), findsOneWidget);
          expect(find.byKey(const Key('login_language_dropdown')), findsOneWidget);

          // Scroll test
          final scrollable = find.byType(Scrollable);
          if (scrollable.evaluate().isNotEmpty) {
            await tester.drag(scrollable.first, const Offset(0, -150));
            await tester.pumpAndSettle();
            verifyNoOverflow(tester, size);
          }
        });

        testWidgets('2. RegisterScreen renders within bounds without RenderFlex overflow', (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() => tester.view.resetPhysicalSize());

          await tester.pumpWidget(_wrapWithProviders(child: const RegisterScreen()));
          await tester.pumpAndSettle();

          verifyNoOverflow(tester, size);
          expect(find.byType(RegisterScreen), findsOneWidget);

          final scrollable = find.byType(Scrollable);
          if (scrollable.evaluate().isNotEmpty) {
            await tester.drag(scrollable.first, const Offset(0, -200));
            await tester.pumpAndSettle();
            verifyNoOverflow(tester, size);
          }
        });

        testWidgets('3. OnboardingScreen renders within bounds without RenderFlex overflow', (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() => tester.view.resetPhysicalSize());

          await tester.pumpWidget(_wrapWithProviders(child: const OnboardingScreen()));
          await tester.pumpAndSettle();

          verifyNoOverflow(tester, size);
          expect(find.byType(OnboardingScreen), findsOneWidget);

          // Swipe through all 3 slides
          final pageView = find.byType(PageView);
          expect(pageView, findsOneWidget);

          await tester.drag(pageView, const Offset(-300, 0));
          await tester.pumpAndSettle();
          verifyNoOverflow(tester, size);

          await tester.drag(pageView, const Offset(-300, 0));
          await tester.pumpAndSettle();
          verifyNoOverflow(tester, size);
        });

        testWidgets('4. DashboardScreen (Monitored & Guardian views) renders without overflow', (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() => tester.view.resetPhysicalSize());

          final dashboardProvider = _ChallengerMockDashboardProvider(
            relationships: [
              _createSampleRelationship('rel-1', name: 'Mẹ'),
              _createSampleRelationship('rel-2', name: 'Bố'),
            ],
            incidentCount: 1,
          );

          await tester.pumpWidget(
            _wrapWithProviders(
              dashboardProvider: dashboardProvider,
              child: const DashboardScreen(),
            ),
          );
          await tester.pumpAndSettle();

          verifyNoOverflow(tester, size);

          // Tab 0: MonitoredView
          expect(find.byType(MonitoredView), findsOneWidget);

          // Scroll MonitoredView
          final scrollables0 = find.byType(Scrollable);
          if (scrollables0.evaluate().isNotEmpty) {
            await tester.drag(scrollables0.first, const Offset(0, -200));
            await tester.pumpAndSettle();
            verifyNoOverflow(tester, size);
          }

          // Switch to Tab 1: Theo dõi (MonitorView / GuardianView)
          await tester.tap(find.text('Theo dõi'));
          await tester.pumpAndSettle();
          verifyNoOverflow(tester, size);
          expect(find.byType(MonitorView), findsOneWidget);

          // Scroll MonitorView
          final scrollables1 = find.byType(Scrollable);
          if (scrollables1.evaluate().isNotEmpty) {
            await tester.drag(scrollables1.first, const Offset(0, -200));
            await tester.pumpAndSettle();
            verifyNoOverflow(tester, size);
          }
        });

        testWidgets('5. CheckInScreen renders within bounds without RenderFlex overflow', (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() => tester.view.resetPhysicalSize());

          await tester.pumpWidget(_wrapWithProviders(child: const CheckInScreen()));
          await tester.pumpAndSettle();

          verifyNoOverflow(tester, size);
          expect(find.byType(CheckInScreen), findsOneWidget);

          final scrollable = find.byType(Scrollable);
          if (scrollable.evaluate().isNotEmpty) {
            await tester.drag(scrollable.first, const Offset(0, -200));
            await tester.pumpAndSettle();
            verifyNoOverflow(tester, size);
          }
        });

        testWidgets('6. IncidentsListScreen renders within bounds without RenderFlex overflow', (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() => tester.view.resetPhysicalSize());

          final incidentsProvider = _ChallengerMockIncidentsProvider(
            incidents: List.generate(
              10,
              (i) => _createSampleIncident('inc-$i', riskScore: 30 + (i * 7)),
            ),
          );

          await tester.pumpWidget(
            _wrapWithProviders(
              incidentsProvider: incidentsProvider,
              child: const IncidentsListScreen(),
            ),
          );
          await tester.pumpAndSettle();

          verifyNoOverflow(tester, size);
          expect(find.byType(IncidentsListScreen), findsOneWidget);

          final scrollable = find.byType(Scrollable);
          if (scrollable.evaluate().isNotEmpty) {
            await tester.drag(scrollable.first, const Offset(0, -300));
            await tester.pumpAndSettle();
            verifyNoOverflow(tester, size);
          }
        });

        testWidgets('7. IncidentDetailScreen (Guardian & Monitored) renders without overflow', (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() => tester.view.resetPhysicalSize());

          final incident = _createSampleIncident('inc-detail-1', riskScore: 88);

          // Guardian view (current user is monitor)
          await tester.pumpWidget(
            _wrapWithProviders(
              child: IncidentDetailScreen(incident: incident),
            ),
          );
          await tester.pumpAndSettle();

          verifyNoOverflow(tester, size);
          expect(find.byType(IncidentDetailScreen), findsOneWidget);

          final scrollable = find.byType(Scrollable);
          if (scrollable.evaluate().isNotEmpty) {
            await tester.drag(scrollable.first, const Offset(0, -250));
            await tester.pumpAndSettle();
            verifyNoOverflow(tester, size);
          }
        });

        testWidgets('8. DevicesScreen renders within bounds without RenderFlex overflow', (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() => tester.view.resetPhysicalSize());

          await tester.pumpWidget(_wrapWithProviders(child: const DevicesScreen()));
          await tester.pumpAndSettle();

          verifyNoOverflow(tester, size);
          expect(find.byType(DevicesScreen), findsOneWidget);

          final scrollable = find.byType(Scrollable);
          if (scrollable.evaluate().isNotEmpty) {
            await tester.drag(scrollable.first, const Offset(0, -200));
            await tester.pumpAndSettle();
            verifyNoOverflow(tester, size);
          }
        });

        testWidgets('9. MonitoringSettingsScreen renders within bounds without RenderFlex overflow', (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() => tester.view.resetPhysicalSize());

          final relationship = _createSampleRelationship('rel-settings-1');

          await tester.pumpWidget(
            _wrapWithProviders(
              child: MonitoringSettingsScreen(relationship: relationship),
            ),
          );
          await tester.pumpAndSettle();

          verifyNoOverflow(tester, size);
          expect(find.byType(MonitoringSettingsScreen), findsOneWidget);

          // Tap through multiple days in the day selector
          await tester.tap(find.text('T3'));
          await tester.pumpAndSettle();
          verifyNoOverflow(tester, size);

          await tester.tap(find.text('CN'));
          await tester.pumpAndSettle();
          verifyNoOverflow(tester, size);

          // Scroll through the entire settings screen
          final scrollable = find.byType(Scrollable);
          if (scrollable.evaluate().isNotEmpty) {
            await tester.drag(scrollable.first, const Offset(0, -400));
            await tester.pumpAndSettle();
            verifyNoOverflow(tester, size);
          }
        });

        testWidgets('10. QrInviteScreen renders within bounds without RenderFlex overflow', (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() => tester.view.resetPhysicalSize());

          await tester.pumpWidget(
            _wrapWithProviders(
              child: const QrInviteScreen(initialCode: 'CR-888888'),
            ),
          );
          await tester.pumpAndSettle();

          verifyNoOverflow(tester, size);
          expect(find.byType(QrInviteScreen), findsOneWidget);
          expect(find.byKey(const Key('qr_image_view')), findsOneWidget);
          expect(find.byKey(const Key('invite_code_text')), findsOneWidget);
          expect(find.byKey(const Key('copy_invite_code_button')), findsOneWidget);
          expect(find.byKey(const Key('share_invite_code_button')), findsOneWidget);
        });

        testWidgets('11. QrScannerScreen renders within bounds without RenderFlex overflow', (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() => tester.view.resetPhysicalSize());

          await tester.pumpWidget(_wrapWithProviders(child: const QrScannerScreen()));
          await tester.pumpAndSettle();

          verifyNoOverflow(tester, size);
          expect(find.byType(QrScannerScreen), findsOneWidget);
          expect(find.byKey(const Key('open_manual_input_button')), findsOneWidget);

          // Open manual input dialog and check responsiveness inside dialog
          await tester.tap(find.byKey(const Key('open_manual_input_button')));
          await tester.pumpAndSettle();

          verifyNoOverflow(tester, size);
          expect(find.byKey(const Key('manual_code_input_field')), findsOneWidget);
          expect(find.byKey(const Key('manual_code_submit_button')), findsOneWidget);

          // Dismiss dialog
          await tester.tap(find.text('Hủy'));
          await tester.pumpAndSettle();
          verifyNoOverflow(tester, size);
        });

        testWidgets('12. AccountSettingsScreen renders within bounds without RenderFlex overflow', (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() => tester.view.resetPhysicalSize());

          await tester.pumpWidget(_wrapWithProviders(child: const AccountSettingsScreen()));
          await tester.pumpAndSettle();

          verifyNoOverflow(tester, size);
          expect(find.byType(AccountSettingsScreen), findsOneWidget);

          final scrollable = find.byType(Scrollable);
          if (scrollable.evaluate().isNotEmpty) {
            await tester.drag(scrollable.first, const Offset(0, -300));
            await tester.pumpAndSettle();
            verifyNoOverflow(tester, size);
          }
        });

        testWidgets('13. LanguageSettingsScreen renders within bounds without RenderFlex overflow', (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() => tester.view.resetPhysicalSize());

          final localeProvider = LocaleProvider();
          await localeProvider.initialize();

          await tester.pumpWidget(
            _wrapWithProviders(
              localeProvider: localeProvider,
              child: const LanguageSettingsScreen(),
            ),
          );
          await tester.pumpAndSettle();

          verifyNoOverflow(tester, size);
          expect(find.byType(LanguageSettingsScreen), findsOneWidget);

          final scrollable = find.byType(Scrollable);
          if (scrollable.evaluate().isNotEmpty) {
            await tester.drag(scrollable.first, const Offset(0, -400));
            await tester.pumpAndSettle();
            verifyNoOverflow(tester, size);
          }
        });

        testWidgets('14. SettingsScreen renders within bounds without RenderFlex overflow', (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() => tester.view.resetPhysicalSize());

          await tester.pumpWidget(_wrapWithProviders(child: const SettingsScreen()));
          await tester.pumpAndSettle();

          verifyNoOverflow(tester, size);
          expect(find.byType(SettingsScreen), findsOneWidget);

          final scrollable = find.byType(Scrollable);
          if (scrollable.evaluate().isNotEmpty) {
            await tester.drag(scrollable.first, const Offset(0, -300));
            await tester.pumpAndSettle();
            verifyNoOverflow(tester, size);
          }
        });
      });
    }
  });
}
