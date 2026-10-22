import 'dart:math' as math;
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
import 'package:mobile/features/dashboard/monitor_view.dart';
import 'package:mobile/features/dashboard/monitored_view.dart';
import 'package:mobile/features/dashboard/relative_detail_screen.dart';
import 'package:mobile/features/devices/devices_screen.dart';
import 'package:mobile/features/incidents/incident_detail_screen.dart';
import 'package:mobile/features/incidents/incidents_list_screen.dart';
import 'package:mobile/features/incidents/incidents_provider.dart';
import 'package:mobile/features/monitoring/monitoring_settings_screen.dart';
import 'package:mobile/features/settings/account_settings_screen.dart';
import 'package:mobile/features/settings/language_settings_screen.dart';
import 'package:mobile/features/settings/notification_settings_screen.dart';
import 'package:mobile/features/settings/privacy_security_screen.dart';
import 'package:mobile/features/settings/settings_screen.dart';

// =============================================================================
// WCAG 2.1 RELATIVE LUMINANCE & CONTRAST RATIO CALCULATORS
// =============================================================================

double _linearizeComponent(double component) {
  return component <= 0.04045
      ? component / 12.92
      : math.pow((component + 0.055) / 1.055, 2.4).toDouble();
}

double calculateRelativeLuminance(Color color) {
  final r = _linearizeComponent(color.r);
  final g = _linearizeComponent(color.g);
  final b = _linearizeComponent(color.b);
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

double calculateContrastRatio(Color foreground, Color background) {
  final l1 = calculateRelativeLuminance(foreground);
  final l2 = calculateRelativeLuminance(background);
  final lighter = math.max(l1, l2);
  final darker = math.min(l1, l2);
  return (lighter + 0.05) / (darker + 0.05);
}

// =============================================================================
// MOCK PROVIDERS FOR DETERMINISTIC TESTING
// =============================================================================

class MockAuthProvider extends AuthProvider {
  final UserModel _user;

  MockAuthProvider()
      : _user = UserModel(
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
  Future<void> logout({dynamic dashboardProvider, dynamic incidentsProvider}) async {}
}

class MockDashboardProvider extends DashboardProvider {
  final List<RelationshipModel> _mockRelationships;
  final MonitoringState _state;
  final DateTime? _lastActivity;

  MockDashboardProvider({
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
}

class MockIncidentsProvider extends IncidentsProvider {
  final List<IncidentModel> _mockIncidents;
  final int _unread;

  MockIncidentsProvider({
    List<IncidentModel>? incidents,
    int unreadCount = 0,
  })  : _mockIncidents = incidents ?? [],
        _unread = unreadCount;

  @override
  List<IncidentModel> get incidents => _mockIncidents;
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
}

Widget buildTestableScreen({
  required Widget child,
  AuthProvider? authProvider,
  DashboardProvider? dashboardProvider,
  IncidentsProvider? incidentsProvider,
  LocaleProvider? localeProvider,
  TextScaler? textScaler,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthProvider>.value(
        value: authProvider ?? MockAuthProvider(),
      ),
      ChangeNotifierProvider<DashboardProvider>.value(
        value: dashboardProvider ?? MockDashboardProvider(),
      ),
      ChangeNotifierProvider<IncidentsProvider>.value(
        value: incidentsProvider ?? MockIncidentsProvider(),
      ),
      ChangeNotifierProvider<LocaleProvider>.value(
        value: localeProvider ?? LocaleProvider(),
      ),
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
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          primary: AppColors.primary,
          secondary: AppColors.secondary,
          surface: AppColors.surface,
          error: AppColors.stateAlertTriggered,
        ),
      ),
      builder: (context, materialAppChild) {
        if (textScaler != null) {
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: textScaler),
            child: materialAppChild!,
          );
        }
        return materialAppChild!;
      },
      home: Material(
        color: AppColors.background,
        child: child,
      ),
    ),
  );
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

// =============================================================================
// SCREEN TARGET MODEL & DEFINITIONS
// =============================================================================

class ScreenTarget {
  final String id;
  final String name;
  final Widget Function() builder;

  const ScreenTarget({
    required this.id,
    required this.name,
    required this.builder,
  });
}

class ViewportSpec {
  final String key;
  final String name;
  final Size size;

  const ViewportSpec({
    required this.key,
    required this.name,
    required this.size,
  });
}

const List<ViewportSpec> kAdversarialViewports = [
  ViewportSpec(
    key: 'compact_se',
    name: 'Compact Mobile (320x568 - iPhone SE 1st gen)',
    size: Size(320, 568),
  ),
  ViewportSpec(
    key: 'standard_x',
    name: 'Standard Mobile (375x812 - iPhone X/11/12/13/14/15)',
    size: Size(375, 812),
  ),
  ViewportSpec(
    key: 'large_max',
    name: 'Large Mobile (414x896 - iPhone 11 Pro Max / XR)',
    size: Size(414, 896),
  ),
];

final List<ScreenTarget> kAll22ScreenTargets = [
  // Section 1: Onboarding & Auth (8 screens)
  ScreenTarget(
    id: '1.1',
    name: 'Onboarding 1 (Giới thiệu)',
    builder: () => const OnboardingScreen(initialPage: 0),
  ),
  ScreenTarget(
    id: '1.2',
    name: 'Onboarding 2 (Tính năng chính)',
    builder: () => const OnboardingScreen(initialPage: 1),
  ),
  ScreenTarget(
    id: '1.3',
    name: 'Đăng nhập (LoginScreen)',
    builder: () => const LoginScreen(),
  ),
  ScreenTarget(
    id: '1.4',
    name: 'Đăng ký (RegisterScreen)',
    builder: () => const RegisterScreen(),
  ),
  ScreenTarget(
    id: '1.5',
    name: 'Hồ sơ cá nhân (AccountSettingsScreen)',
    builder: () => const AccountSettingsScreen(),
  ),
  ScreenTarget(
    id: '1.6',
    name: 'Giải thích quyền riêng tư',
    builder: () => const OnboardingScreen(initialPage: 2),
  ),
  ScreenTarget(
    id: '1.7',
    name: 'Cấp quyền cần thiết',
    builder: () => const OnboardingScreen(initialPage: 3),
  ),
  ScreenTarget(
    id: '1.8',
    name: 'Đăng ký thành công (Sẵn sàng!)',
    builder: () => const OnboardingScreen(
      initialPage: 4,
      isPostRegistration: true,
    ),
  ),

  // Section 2: Monitored Mode (5 screens)
  ScreenTarget(
    id: '2.1',
    name: 'Trang chủ Monitored (MonitoredView)',
    builder: () => const MonitoredView(),
  ),
  ScreenTarget(
    id: '2.2',
    name: 'Xác nhận Tôi vẫn ổn (CheckInScreen)',
    builder: () => CheckInScreen(
      confirmedAt: DateTime(2025, 10, 15, 8, 42),
    ),
  ),
  ScreenTarget(
    id: '2.3',
    name: 'Lịch sử hoạt động (RecentActivitiesScreen)',
    builder: () => const RecentActivitiesScreen(showAppBar: true),
  ),
  ScreenTarget(
    id: '2.4',
    name: 'Quản lý thiết bị (DevicesScreen)',
    builder: () => const DevicesScreen(showAppBar: true),
  ),
  ScreenTarget(
    id: '2.5',
    name: 'Cài đặt giám sát (MonitoringSettingsScreen)',
    builder: () => MonitoringSettingsScreen(
      relationship: _createSampleRelationship(),
    ),
  ),

  // Section 3: Guardian Mode (3 screens)
  ScreenTarget(
    id: '3.1',
    name: 'Danh sách người thân (MonitorView)',
    builder: () => const MonitorView(),
  ),
  ScreenTarget(
    id: '3.2',
    name: 'Chi tiết người thân (RelativeDetailScreen)',
    builder: () => const RelativeDetailScreen(
      relativeData: _sampleRelativeData,
    ),
  ),
  ScreenTarget(
    id: '3.3',
    name: 'Dòng thời gian sự kiện (IncidentsListScreen)',
    builder: () => const IncidentsListScreen(),
  ),

  // Section 4: Sự kiện & Xử lý sự cố (3 screens / states)
  ScreenTarget(
    id: '4.1',
    name: 'Thông báo cảnh báo (IncidentDetailScreen step 0)',
    builder: () => const IncidentDetailScreen(
      showcaseMode: true,
      initialStep: 0,
    ),
  ),
  ScreenTarget(
    id: '4.2',
    name: 'Chi tiết sự cố (IncidentDetailScreen step 1)',
    builder: () => const IncidentDetailScreen(
      showcaseMode: true,
      initialStep: 1,
    ),
  ),
  ScreenTarget(
    id: '4.3',
    name: 'Khôi phục trạng thái (IncidentDetailScreen step 2)',
    builder: () => const IncidentDetailScreen(
      showcaseMode: true,
      initialStep: 2,
    ),
  ),

  // Section 5: Cài đặt & Tùy chỉnh (4 screens)
  ScreenTarget(
    id: '5.1',
    name: 'Menu cài đặt (SettingsScreen)',
    builder: () => const SettingsScreen(),
  ),
  ScreenTarget(
    id: '5.2',
    name: 'Bảo mật & quyền riêng tư (PrivacySecurityScreen)',
    builder: () => const PrivacySecurityScreen(),
  ),
  ScreenTarget(
    id: '5.3',
    name: 'Chọn ngôn ngữ (LanguageSettingsScreen)',
    builder: () => const LanguageSettingsScreen(),
  ),
  ScreenTarget(
    id: '5.4',
    name: 'Cài đặt thông báo (NotificationSettingsScreen)',
    builder: () => const NotificationSettingsScreen(),
  ),
];

// =============================================================================
// ADVERSARIAL STRESS TEST RUNNER
// =============================================================================

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

  group('WCAG 2.1 Color Contrast Verification', () {
    test('Primary Forest Green (#2D6A4F) meets WCAG AA (>= 4.5:1) with White (#FFFFFF)', () {
      final ratio = calculateContrastRatio(
        const Color(0xFFFFFFFF),
        AppColors.primary,
      );
      expect(
        ratio,
        greaterThanOrEqualTo(4.5),
        reason: 'White text on AppColors.primary (#2D6A4F) contrast $ratio must be >= 4.5:1',
      );
    });

    test('Dark Typography (#1E2022) meets WCAG AAA (>= 7.0:1) on White (#FFFFFF) and Soft Sage (#F4F6F3)', () {
      final ratioWhite = calculateContrastRatio(
        AppColors.textPrimary,
        const Color(0xFFFFFFFF),
      );
      final ratioSage = calculateContrastRatio(
        AppColors.textPrimary,
        AppColors.background,
      );
      expect(
        ratioWhite,
        greaterThanOrEqualTo(7.0),
        reason: 'Text primary on white contrast $ratioWhite must be >= 7.0:1 (AAA)',
      );
      expect(
        ratioSage,
        greaterThanOrEqualTo(7.0),
        reason: 'Text primary on soft sage background contrast $ratioSage must be >= 7.0:1 (AAA)',
      );
    });

    test('Secondary Typography (#6C757D) meets WCAG AA (>= 4.5:1) on White (#FFFFFF)', () {
      final ratio = calculateContrastRatio(
        AppColors.textSecondary,
        const Color(0xFFFFFFFF),
      );
      expect(
        ratio,
        greaterThanOrEqualTo(4.5),
        reason: 'Secondary text on white surface contrast $ratio must be >= 4.5:1',
      );
    });

    test('Onboarding Subtitle (#5C6B62) meets WCAG AA (>= 4.5:1) on Soft Sage (#F4F6F3)', () {
      final ratio = calculateContrastRatio(
        AppColors.textSecondary,
        AppColors.background,
      );
      expect(
        ratio,
        greaterThanOrEqualTo(4.5),
        reason: 'Onboarding subtitle (AppColors.textSecondary) on AppColors.background contrast $ratio must be >= 4.5:1',
      );
    });

    test('Alert Coral (#D9534F) meets WCAG AA Large/Graphics (>= 3.0:1) on Alert Soft Background (#FDECEA)', () {
      final ratio = calculateContrastRatio(
        AppColors.danger,
        AppColors.alertSoftBg,
      );
      expect(
        ratio,
        greaterThanOrEqualTo(3.0),
        reason: 'Alert coral on alert soft background contrast $ratio must be >= 3.0:1',
      );
    });
  });

  group('22-Screen Multi-Viewport Stress Testing (Zero Overflow & Tap Targets)', () {
    for (final target in kAll22ScreenTargets) {
      group('Screen ${target.id}: ${target.name}', () {
        for (final vp in kAdversarialViewports) {
          testWidgets(
            'Renders at ${vp.name} with zero RenderFlex overflow and compliant tap targets',
            (tester) async {
              tester.view.physicalSize = vp.size;
              tester.view.devicePixelRatio = 1.0;
              addTearDown(() => tester.view.resetPhysicalSize());

              final List<FlutterErrorDetails> overflowErrors = [];
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

              await tester.pumpWidget(
                buildTestableScreen(child: target.builder()),
              );
              await tester.pumpAndSettle();

              // Verify zero initial layout overflow
              expect(
                overflowErrors,
                isEmpty,
                reason: 'RenderFlex overflow occurred on ${target.id} (${target.name}) at ${vp.name}: '
                    '${overflowErrors.map((e) => e.summary).join("; ")}',
              );

              final initialException = tester.takeException();
              if (initialException != null) {
                final exStr = initialException.toString();
                if (!exStr.contains('ListTile background color or ink splashes may be invisible')) {
                  fail('Unexpected exception on ${target.id} at ${vp.name}: $initialException');
                }
              }

              // Verify button tap target geometries
              final elevatedButtons = find.byType(ElevatedButton);
              for (final element in elevatedButtons.evaluate()) {
                final size = tester.getSize(find.byWidget(element.widget));
                expect(
                  size.width,
                  greaterThan(0),
                  reason: 'ElevatedButton in ${target.id} at ${vp.name} must have positive width',
                );
                expect(
                  size.height,
                  greaterThanOrEqualTo(44.0),
                  reason: 'ElevatedButton height (${size.height}) in ${target.id} at ${vp.name} '
                      'must meet minimum 44.0dp touch target standard',
                );
              }

              final outlinedButtons = find.byType(OutlinedButton);
              for (final element in outlinedButtons.evaluate()) {
                final size = tester.getSize(find.byWidget(element.widget));
                expect(
                  size.width,
                  greaterThan(0),
                  reason: 'OutlinedButton in ${target.id} at ${vp.name} must have positive width',
                );
                expect(
                  size.height,
                  greaterThanOrEqualTo(40.0),
                  reason: 'OutlinedButton height (${size.height}) in ${target.id} at ${vp.name} '
                      'must meet minimum 40.0dp touch target',
                );
              }

              final iconButtons = find.byType(IconButton);
              for (final element in iconButtons.evaluate()) {
                final size = tester.getSize(find.byWidget(element.widget));
                expect(
                  size.width,
                  greaterThanOrEqualTo(36.0),
                  reason: 'IconButton width (${size.width}) in ${target.id} at ${vp.name} is too small',
                );
                expect(
                  size.height,
                  greaterThanOrEqualTo(36.0),
                  reason: 'IconButton height (${size.height}) in ${target.id} at ${vp.name} is too small',
                );
              }

              // Adversarial scroll stress test: drag up and down to check for overflow during scroll dynamics
              final scrollable = find.byType(Scrollable);
              if (scrollable.evaluate().isNotEmpty) {
                await tester.drag(scrollable.first, const Offset(0, -250));
                await tester.pumpAndSettle();

                expect(
                  overflowErrors,
                  isEmpty,
                  reason: 'RenderFlex overflow occurred after scroll down on ${target.id} at ${vp.name}: '
                      '${overflowErrors.map((e) => e.summary).join("; ")}',
                );

                await tester.drag(scrollable.first, const Offset(0, 250));
                await tester.pumpAndSettle();

                expect(
                  overflowErrors,
                  isEmpty,
                  reason: 'RenderFlex overflow occurred after scroll up on ${target.id} at ${vp.name}: '
                      '${overflowErrors.map((e) => e.summary).join("; ")}',
                );
              }
            },
          );
        }
      });
    }
  });

  group('Elder Accessibility Stress Testing (1.2x Dynamic Text Scaling at 375x812)', () {
    for (final target in kAll22ScreenTargets) {
      testWidgets(
        'Screen ${target.id} (${target.name}) under 1.2x elder text scale',
        (tester) async {
          tester.view.physicalSize = const Size(375, 812);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() => tester.view.resetPhysicalSize());

          final List<FlutterErrorDetails> overflowErrors = [];
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

          await tester.pumpWidget(
            buildTestableScreen(
              child: target.builder(),
              textScaler: const TextScaler.linear(1.2),
            ),
          );
          await tester.pumpAndSettle();

          expect(
            overflowErrors,
            isEmpty,
            reason: 'RenderFlex overflow occurred on ${target.id} (${target.name}) under 1.2x text scale: '
                '${overflowErrors.map((e) => e.summary).join("; ")}',
          );
        },
      );
    }
  });
}

