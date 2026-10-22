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
import 'package:mobile/features/landing/landing_screen.dart';
import 'package:mobile/features/monitoring/monitoring_settings_screen.dart';
import 'package:mobile/features/pairing/qr_invite_screen.dart';
import 'package:mobile/features/pairing/qr_scanner_screen.dart';
import 'package:mobile/features/settings/account_settings_screen.dart';
import 'package:mobile/features/settings/language_settings_screen.dart';
import 'package:mobile/features/settings/notification_settings_screen.dart';
import 'package:mobile/features/settings/privacy_security_screen.dart';
import 'package:mobile/features/settings/settings_screen.dart';

class _MockAuthProvider extends AuthProvider {
  final UserModel _user = UserModel(
    id: 'user-monitored-1',
    email: 'an@carely.vn',
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
  @override
  String? get errorMessage => null;
  @override
  String? getErrorMessage(BuildContext context) => null;
}

class _MockDashboardProvider extends DashboardProvider {
  final List<RelationshipModel> _mockRelationships;

  _MockDashboardProvider({List<RelationshipModel>? relationships})
      : _mockRelationships = relationships ?? [_createSampleRelationship()];

  @override
  bool get isLoading => false;
  @override
  String? get errorMessage => null;
  @override
  int get activeIncidentsCount => 1;
  @override
  int get unreadNotificationsCount => 2;
  @override
  List<RelationshipModel> get allRelationships => _mockRelationships;
  @override
  List<RelationshipModel> get monitoredByMe => _mockRelationships;
  @override
  List<RelationshipModel> get monitoringMe => _mockRelationships;
  @override
  MonitoringState get myCurrentState => MonitoringState.ACTIVE;
  @override
  DateTime? get myLastActivityAt => DateTime(2025, 10, 15, 8, 42);
  @override
  bool get lastCheckInOffline => false;
  @override
  Future<void> fetchDashboardData() async {}
}

class _MockIncidentsProvider extends IncidentsProvider {
  @override
  List<IncidentModel> get incidents => [];
  @override
  bool get isLoading => false;
  @override
  String? get errorMessage => null;
  @override
  int get unreadCount => 1;
  @override
  bool get hasUnreadIncidents => true;
  @override
  Future<void> fetchIncidents() async {}
}

RelationshipModel _createSampleRelationship() {
  return RelationshipModel(
    id: 'rel-sample-1',
    monitoredUserId: 'user-monitored-1',
    monitorUserId: 'user-monitor-1',
    status: RelationshipStatus.ACCEPTED,
    createdAt: DateTime(2025, 1, 1),
    label: 'Mẹ',
    monitoredUser: UserModel(
      id: 'user-monitored-1',
      email: 'me@carely.vn',
      fullName: 'Mẹ',
      phone: '+84 912 345 678',
      timezone: 'Asia/Ho_Chi_Minh',
      isActive: true,
      createdAt: DateTime(2025, 1, 1),
    ),
    config: MonitoringConfigModel(
      id: 'cfg-sample-1',
      relationshipId: 'rel-sample-1',
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

const Map<String, dynamic> _sampleRelativeData = {
  'name': 'Mẹ',
  'statusText': 'Đang được bảo vệ',
  'subText': 'Lần xác nhận: 08:32 hôm nay',
  'lastConfirmed': '15/10/2025 • 08:32',
  'isAlert': false,
  'device': 'iPhone 15 Pro',
  'location': 'Hà Nội (chỉ khi cần)',
};

class DeviceViewport {
  final String name;
  final Size size;
  const DeviceViewport(this.name, this.size);
}

const List<DeviceViewport> kAllDeviceViewports = [
  DeviceViewport('Foldable Cover (280x653)', Size(280, 653)),
  DeviceViewport('Compact Mobile SE (320x568)', Size(320, 568)),
  DeviceViewport('Small Android (360x640)', Size(360, 640)),
  DeviceViewport('Standard Mobile (375x812)', Size(375, 812)),
  DeviceViewport('Modern iPhone 14/15 (390x844)', Size(390, 844)),
  DeviceViewport('Large Mobile Max (414x896)', Size(414, 896)),
  DeviceViewport('Pro Max (430x932)', Size(430, 932)),
  DeviceViewport('Compact Landscape (568x320)', Size(568, 320)),
  DeviceViewport('Standard Landscape (812x375)', Size(812, 375)),
  DeviceViewport('Tablet Portrait iPad (768x1024)', Size(768, 1024)),
  DeviceViewport('Tablet Landscape iPad (1024x768)', Size(1024, 768)),
  DeviceViewport('Laptop Desktop (1280x800)', Size(1280, 800)),
  DeviceViewport('Full HD Desktop (1920x1080)', Size(1920, 1080)),
];

class ScreenSpec {
  final String name;
  final Widget Function() builder;
  const ScreenSpec(this.name, this.builder);
}

final List<ScreenSpec> kAllAppScreens = [
  ScreenSpec('Onboarding 0', () => const OnboardingScreen(initialPage: 0)),
  ScreenSpec('Onboarding 1', () => const OnboardingScreen(initialPage: 1)),
  ScreenSpec('Onboarding 2', () => const OnboardingScreen(initialPage: 2)),
  ScreenSpec('Onboarding 3', () => const OnboardingScreen(initialPage: 3)),
  ScreenSpec(
    'Onboarding 4 (Post-Reg)',
    () => const OnboardingScreen(initialPage: 4, isPostRegistration: true),
  ),
  ScreenSpec('LoginScreen', () => const LoginScreen()),
  ScreenSpec('RegisterScreen', () => const RegisterScreen()),
  ScreenSpec('AccountSettingsScreen', () => const AccountSettingsScreen()),
  ScreenSpec('DashboardScreen', () => const DashboardScreen()),
  ScreenSpec('MonitoredView', () => const MonitoredView()),
  ScreenSpec(
    'CheckInScreen',
    () => CheckInScreen(confirmedAt: DateTime(2025, 10, 15, 8, 42)),
  ),
  ScreenSpec(
    'RecentActivitiesScreen',
    () => const RecentActivitiesScreen(showAppBar: true),
  ),
  ScreenSpec('DevicesScreen', () => const DevicesScreen(showAppBar: true)),
  ScreenSpec(
    'MonitoringSettingsScreen',
    () => MonitoringSettingsScreen(relationship: _createSampleRelationship()),
  ),
  ScreenSpec(
    'CustomThresholdScreen',
    () => CustomThresholdScreen(
      initialValue: 180,
      formatPreview: (m) => '$m phút',
    ),
  ),
  ScreenSpec(
    'CustomGracePeriodScreen',
    () => CustomGracePeriodScreen(
      initialValue: 30,
      formatPreview: (m) => '$m phút',
    ),
  ),
  ScreenSpec(
    'CheckInRemindersScreen',
    () => const CheckInRemindersScreen(initialTimes: ['08:00', '20:00']),
  ),
  ScreenSpec('MonitorView', () => const MonitorView()),
  ScreenSpec(
    'RelativeDetailScreen',
    () => const RelativeDetailScreen(relativeData: _sampleRelativeData),
  ),
  ScreenSpec(
    'ContactRelativeScreen',
    () => ContactRelativeScreen(
      name: 'Mẹ',
      statusText: 'Đang được bảo vệ',
      lastConfirmed: '15/10/2025 • 08:32',
      location: 'Hà Nội',
      phone: '+84 912 345 678',
      email: 'me@carely.vn',
      relationship: _createSampleRelationship(),
    ),
  ),
  ScreenSpec('IncidentsListScreen', () => const IncidentsListScreen()),
  ScreenSpec(
    'ClearNotificationsConfirmScreen',
    () => const ClearNotificationsConfirmScreen(),
  ),
  ScreenSpec(
    'IncidentDetailScreen (Step 0)',
    () => const IncidentDetailScreen(showcaseMode: true, initialStep: 0),
  ),
  ScreenSpec(
    'IncidentDetailScreen (Step 1)',
    () => const IncidentDetailScreen(showcaseMode: true, initialStep: 1),
  ),
  ScreenSpec(
    'IncidentDetailScreen (Step 2)',
    () => const IncidentDetailScreen(showcaseMode: true, initialStep: 2),
  ),
  ScreenSpec('SettingsScreen', () => const SettingsScreen()),
  ScreenSpec('PrivacySecurityScreen', () => const PrivacySecurityScreen()),
  ScreenSpec('LanguageSettingsScreen', () => const LanguageSettingsScreen()),
  ScreenSpec(
    'NotificationSettingsScreen',
    () => const NotificationSettingsScreen(),
  ),
  ScreenSpec(
    'QrInviteScreen',
    () => const QrInviteScreen(initialCode: 'CR-889900'),
  ),
  ScreenSpec(
    'QrScannerScreen',
    () => const QrScannerScreen(isTestMode: true),
  ),
  ScreenSpec(
    'LandingScreen (Landing)',
    () => const LandingScreen(page: SitePageType.landing),
  ),
  ScreenSpec(
    'LandingScreen (Privacy)',
    () => const LandingScreen(page: SitePageType.privacy),
  ),
  ScreenSpec(
    'LandingScreen (Terms)',
    () => const LandingScreen(page: SitePageType.terms),
  ),
  ScreenSpec(
    'LandingScreen (DeleteAccount)',
    () => const LandingScreen(page: SitePageType.deleteAccount),
  ),
];

Widget _wrapScreen(Widget child, {TextScaler? textScaler}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthProvider>.value(value: _MockAuthProvider()),
      ChangeNotifierProvider<DashboardProvider>.value(
        value: _MockDashboardProvider(),
      ),
      ChangeNotifierProvider<IncidentsProvider>.value(
        value: _MockIncidentsProvider(),
      ),
      ChangeNotifierProvider<LocaleProvider>.value(value: LocaleProvider()),
    ],
    child: MaterialApp(
      locale: const Locale('vi'),
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
      ),
      builder: (context, appChild) {
        if (textScaler != null) {
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: textScaler),
            child: appChild!,
          );
        }
        return appChild!;
      },
      home: Material(color: AppColors.background, child: child),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'carely_user_id': 'user-monitored-1',
      'carely_device_uid': 'device-test-uuid',
      'notif_push': true,
      'notif_emergency': true,
      'notif_reminders': true,
      'notif_system': false,
      'notif_ringtone': 'Nhạc chuông',
    });
    await LocalStorage.saveAuth(
      accessToken: 'mock_jwt_token',
      refreshToken: 'mock_refresh_token',
      userId: 'user-monitored-1',
      email: 'an@carely.vn',
      fullName: 'Nguyễn Văn An',
    );
  });

  group('All 36 Screens x All 13 Device Sizes Zero-Overflow Audit', () {
    for (final screen in kAllAppScreens) {
      testWidgets('${screen.name} renders without overflow across all 13 device sizes', (tester) async {
        final List<String> errors = [];
        final oldOnError = FlutterError.onError;
        FlutterError.onError = (FlutterErrorDetails details) {
          final msg = details.exceptionAsString();
          if (msg.contains('overflowed') ||
              msg.contains('RenderFlex') ||
              msg.contains('Vertical viewport was given unbounded') ||
              msg.contains('Horizontal viewport was given unbounded')) {
            errors.add(msg);
          }
        };

        try {
          for (final vp in kAllDeviceViewports) {
            tester.view.physicalSize = vp.size;
            tester.view.devicePixelRatio = 1.0;

            await tester.pumpWidget(_wrapScreen(screen.builder()));
            await tester.pump(const Duration(milliseconds: 100));

            final dynamic ex = tester.takeException();
            if (ex != null) {
              final msg = ex.toString();
              if (msg.contains('overflowed') || msg.contains('RenderFlex')) {
                errors.add('[${vp.name}] $msg');
              }
            }
            expect(
              errors,
              isEmpty,
              reason: '${screen.name} overflowed at ${vp.name}: ${errors.join(" | ")}',
            );
          }
        } finally {
          FlutterError.onError = oldOnError;
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        }
      });
    }
  });

  group('Dynamic Text Scaling (1.35x Elder Accessibility) at 320x568 & 375x812', () {
    for (final screen in kAllAppScreens) {
      testWidgets('${screen.name} renders without overflow at 1.35x text scale on 320x568 and 375x812', (tester) async {
        final List<String> errors = [];
        final oldOnError = FlutterError.onError;
        FlutterError.onError = (FlutterErrorDetails details) {
          final msg = details.exceptionAsString();
          if (msg.contains('overflowed') || msg.contains('RenderFlex')) {
            errors.add(msg);
          }
        };

        try {
          for (final size in [const Size(320, 568), const Size(375, 812)]) {
            tester.view.physicalSize = size;
            tester.view.devicePixelRatio = 1.0;

            await tester.pumpWidget(
              _wrapScreen(
                screen.builder(),
                textScaler: const TextScaler.linear(1.35),
              ),
            );
            await tester.pump(const Duration(milliseconds: 100));

            final dynamic ex = tester.takeException();
            if (ex != null) {
              final msg = ex.toString();
              if (msg.contains('overflowed') || msg.contains('RenderFlex')) {
                errors.add('[${size.width}x${size.height} @ 1.35x] $msg');
              }
            }
            expect(
              errors,
              isEmpty,
              reason: '${screen.name} overflowed at ${size.width}x${size.height} @ 1.35x: ${errors.join(" | ")}',
            );
          }
        } finally {
          FlutterError.onError = oldOnError;
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        }
      });
    }
  });
}
