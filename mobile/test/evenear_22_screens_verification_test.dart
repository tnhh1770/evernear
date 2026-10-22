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
// MOCK PROVIDERS FOR ISOLATED, DETERMINISTIC SCREEN TESTING
// =============================================================================

class MockAuthProvider extends AuthProvider {
  final UserModel _user;
  final bool _loading;

  MockAuthProvider({
    UserModel? user,
    bool isLoading = false,
  })  : _user = user ??
            UserModel(
              id: 'user-monitored-1',
              email: 'an@carely.vn',
              fullName: 'Nguyễn Văn An',
              phone: '+84 912 345 678',
              timezone: 'Asia/Ho_Chi_Minh',
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

// =============================================================================
// TEST HARNESS & BUILDER
// =============================================================================

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
      home: Material(
        color: AppColors.background,
        child: child,
      ),
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
// 22-SCREEN AUTOMATED VERIFICATION SUITE
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

  group('Section 1 — Onboarding & Xác thực (8 Screens)', () {
    testWidgets(
      '1.1 Onboarding 1 (Giới thiệu ứng dụng) renders at 375x812 with no overflow & exact copy',
      (tester) async {
        tester.view.physicalSize = const Size(375, 812);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final List<FlutterErrorDetails> overflowErrors = [];
        configureTestErrorHandling(overflowErrors);

        await tester.pumpWidget(
          buildTestableScreen(child: const OnboardingScreen(initialPage: 0)),
        );
        await tester.pumpAndSettle();

        verifyNoLayoutOverflowOrFatalErrors(tester, overflowErrors);

        expect(
          find.byWidgetPredicate(
            (w) => w is Text && (w.data == 'Evernear' || w.data == 'Evenear'),
          ),
          findsOneWidget,
        );
        expect(
          find.text('Đồng hành & Bảo vệ bình an cho người thân'),
          findsOneWidget,
        );
        expect(
          find.byWidgetPredicate(
            (w) => w is Text && (w.data == 'Tiếp tục' || w.data == 'Bắt đầu'),
          ),
          findsWidgets,
        );
        expect(find.text('Bỏ qua'), findsOneWidget);

        // Button styling
        final btnFinder = find.byType(ElevatedButton).first;
        expect(btnFinder, findsOneWidget);
        final ElevatedButton btn = tester.widget(btnFinder);
        expect(btn.style?.shape?.resolve({}), isA<StadiumBorder>());

        // Scroll test
        final scrollable = find.byType(Scrollable);
        if (scrollable.evaluate().isNotEmpty) {
          await tester.drag(scrollable.first, const Offset(0, -200));
          await tester.pumpAndSettle();
          verifyNoLayoutOverflowOrFatalErrors(tester, overflowErrors);
        }
      },
    );

    testWidgets(
      '1.2 Onboarding 2 (Tính năng chính) renders at 375x812 with no overflow & exact copy',
      (tester) async {
        tester.view.physicalSize = const Size(375, 812);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final List<FlutterErrorDetails> overflowErrors = [];
        configureTestErrorHandling(overflowErrors);

        await tester.pumpWidget(
          buildTestableScreen(child: const OnboardingScreen(initialPage: 1)),
        );
        await tester.pumpAndSettle();

        verifyNoLayoutOverflowOrFatalErrors(tester, overflowErrors);

        // Copywriting assertions
        expect(find.text('Luôn bên cạnh khi bạn cần'), findsOneWidget);
        expect(
          find.text(
            'Theo dõi hoạt động thông minh, nhắc nhở kịp thời và kết nối người thân trong những lúc quan trọng.',
          ),
          findsOneWidget,
        );
        expect(find.text('Tiếp tục'), findsOneWidget);

        final btnFinder = find.widgetWithText(ElevatedButton, 'Tiếp tục');
        expect(btnFinder, findsOneWidget);
        final ElevatedButton btn = tester.widget(btnFinder);
        expect(btn.style?.shape?.resolve({}), isA<StadiumBorder>());

        final scrollable = find.byType(Scrollable);
        if (scrollable.evaluate().isNotEmpty) {
          await tester.drag(scrollable.first, const Offset(0, -200));
          await tester.pumpAndSettle();
          verifyNoLayoutOverflowOrFatalErrors(tester, overflowErrors);
        }
      },
    );

    testWidgets(
      '1.3 Đăng nhập (LoginScreen) renders at 375x812 with no overflow & exact copy',
      (tester) async {
        tester.view.physicalSize = const Size(375, 812);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final List<FlutterErrorDetails> overflowErrors = [];
        configureTestErrorHandling(overflowErrors);

        await tester.pumpWidget(buildTestableScreen(child: const LoginScreen()));
        await tester.pumpAndSettle();

        verifyNoLayoutOverflowOrFatalErrors(tester, overflowErrors);

        // Copywriting assertions
        expect(find.text('Chào mừng trở lại!'), findsOneWidget);
        expect(
          find.byWidgetPredicate(
            (w) =>
                w is Text &&
                (w.data == 'Đồng hành & Bảo vệ bình an cho người thân' ||
                    w.data == 'Đăng nhập để tiếp tục'),
          ),
          findsOneWidget,
        );
        expect(find.text('Email hoặc số điện thoại'), findsOneWidget);
        expect(find.text('Mật khẩu'), findsOneWidget);
        expect(find.text('Nhớ tài khoản'), findsOneWidget);
        expect(find.text('Quên mật khẩu?'), findsOneWidget);
        expect(find.text('Đăng nhập'), findsWidgets);
        expect(find.text('hoặc'), findsNothing);
        expect(find.text('Đăng nhập với Google'), findsNothing);
        expect(find.text('Đăng nhập với Apple'), findsNothing);
        expect(find.text('Chưa có tài khoản? '), findsOneWidget);

        // Required keys
        expect(find.byKey(const Key('login_language_dropdown')), findsOneWidget);

        // Negative social keys invariant
        expect(find.byKey(const Key('google_sign_in_button')), findsNothing);
        expect(find.byKey(const Key('apple_sign_in_button')), findsNothing);

        // Button shape
        final submitFinder = find.widgetWithText(ElevatedButton, 'Đăng nhập');
        expect(submitFinder, findsOneWidget);
        final ElevatedButton submitBtn = tester.widget(submitFinder);
        expect(submitBtn.style?.shape?.resolve({}), isA<StadiumBorder>());

        final scrollable = find.byType(Scrollable);
        if (scrollable.evaluate().isNotEmpty) {
          await tester.drag(scrollable.first, const Offset(0, -200));
          await tester.pumpAndSettle();
          verifyNoLayoutOverflowOrFatalErrors(tester, overflowErrors);
        }
      },
    );

    testWidgets(
      '1.4 Đăng ký (RegisterScreen) renders at 375x812 with no overflow & exact copy',
      (tester) async {
        tester.view.physicalSize = const Size(375, 812);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final List<FlutterErrorDetails> overflowErrors = [];
        configureTestErrorHandling(overflowErrors);

        await tester.pumpWidget(
          buildTestableScreen(child: const RegisterScreen()),
        );
        await tester.pumpAndSettle();

        verifyNoLayoutOverflowOrFatalErrors(tester, overflowErrors);

        // Copywriting assertions
        expect(find.text('Đăng ký'), findsWidgets);
        expect(
          find.byWidgetPredicate(
            (w) =>
                w is Text &&
                (w.data == 'Bắt đầu bảo vệ sự bình an của bạn và gia đình' ||
                    w.data == 'Bắt đầu hành trình an toàn cùng Evenear'),
          ),
          findsOneWidget,
        );
        expect(find.text('Họ và tên'), findsOneWidget);
        expect(find.text('Email'), findsOneWidget);
        expect(find.text('Mật khẩu'), findsOneWidget);
        expect(find.text('Xác nhận mật khẩu'), findsOneWidget);
        expect(find.text('Tạo tài khoản'), findsWidgets);
        expect(find.text('Đã có tài khoản? '), findsOneWidget);

        final scrollable = find.byType(Scrollable);
        if (scrollable.evaluate().isNotEmpty) {
          await tester.drag(scrollable.first, const Offset(0, -200));
          await tester.pumpAndSettle();
          verifyNoLayoutOverflowOrFatalErrors(tester, overflowErrors);
        }
      },
    );

    testWidgets(
      '1.5 Hồ sơ cá nhân (AccountSettingsScreen) renders at 375x812 with no overflow & exact copy',
      (tester) async {
        tester.view.physicalSize = const Size(375, 812);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final List<FlutterErrorDetails> overflowErrors = [];
        configureTestErrorHandling(overflowErrors);

        await tester.pumpWidget(
          buildTestableScreen(child: const AccountSettingsScreen()),
        );
        await tester.pumpAndSettle();

        verifyNoLayoutOverflowOrFatalErrors(tester, overflowErrors);

        // Copywriting assertions
        expect(find.text('Hồ sơ của tôi'), findsOneWidget);
        expect(find.text('Nguyễn Văn An'), findsWidgets);
        expect(find.text('+84 912 345 678'), findsWidgets);
        expect(find.text('Thông tin cá nhân'), findsOneWidget);
        expect(find.text('Họ và tên'), findsOneWidget);
        expect(find.text('Số điện thoại khẩn cấp'), findsOneWidget);
        expect(find.text('Email'), findsOneWidget);
        expect(find.text('Bảo mật & Mật khẩu'), findsOneWidget);
        expect(find.text('Đổi mật khẩu'), findsOneWidget);

        final scrollable = find.byType(Scrollable);
        if (scrollable.evaluate().isNotEmpty) {
          await tester.drag(scrollable.first, const Offset(0, -200));
          await tester.pumpAndSettle();
          verifyNoLayoutOverflowOrFatalErrors(tester, overflowErrors);
        }
      },
    );

    testWidgets(
      '1.6 Giải thích quyền riêng tư renders at 375x812 with no overflow & exact copy',
      (tester) async {
        tester.view.physicalSize = const Size(375, 812);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final List<FlutterErrorDetails> overflowErrors = [];
        configureTestErrorHandling(overflowErrors);

        await tester.pumpWidget(
          buildTestableScreen(child: const OnboardingScreen(initialPage: 2)),
        );
        await tester.pumpAndSettle();

        verifyNoLayoutOverflowOrFatalErrors(tester, overflowErrors);

        // Copywriting assertions
        expect(
          find.text('Quyền riêng tư của bạn là ưu tiên hàng đầu'),
          findsOneWidget,
        );
        expect(
          find.text('Không camera / Không microphone'),
          findsOneWidget,
        );
        expect(find.text('Không theo dõi GPS liên tục'), findsOneWidget);
        expect(find.text('Tôi đã hiểu'), findsOneWidget);

        final btnFinder = find.widgetWithText(ElevatedButton, 'Tôi đã hiểu');
        expect(btnFinder, findsOneWidget);
        final ElevatedButton btn = tester.widget(btnFinder);
        expect(btn.style?.shape?.resolve({}), isA<StadiumBorder>());

        final scrollable = find.byType(Scrollable);
        if (scrollable.evaluate().isNotEmpty) {
          await tester.drag(scrollable.first, const Offset(0, -200));
          await tester.pumpAndSettle();
          verifyNoLayoutOverflowOrFatalErrors(tester, overflowErrors);
        }
      },
    );

    testWidgets(
      '1.7 Cấp quyền cần thiết renders at 375x812 with no overflow & exact copy',
      (tester) async {
        tester.view.physicalSize = const Size(375, 812);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final List<FlutterErrorDetails> overflowErrors = [];
        configureTestErrorHandling(overflowErrors);

        await tester.pumpWidget(
          buildTestableScreen(child: const OnboardingScreen(initialPage: 3)),
        );
        await tester.pumpAndSettle();

        verifyNoLayoutOverflowOrFatalErrors(tester, overflowErrors);

        // Copywriting assertions
        expect(find.text('Cấp quyền cần thiết'), findsOneWidget);
        expect(find.text('Thông báo'), findsOneWidget);
        expect(find.text('Vị trí (chỉ khi cần)'), findsOneWidget);
        expect(find.text('Hoạt động & sức khỏe'), findsOneWidget);
        expect(find.text('Tiếp tục'), findsOneWidget);

        final btnFinder = find.widgetWithText(ElevatedButton, 'Tiếp tục');
        expect(btnFinder, findsOneWidget);
        final ElevatedButton btn = tester.widget(btnFinder);
        expect(btn.style?.shape?.resolve({}), isA<StadiumBorder>());

        final scrollable = find.byType(Scrollable);
        if (scrollable.evaluate().isNotEmpty) {
          await tester.drag(scrollable.first, const Offset(0, -200));
          await tester.pumpAndSettle();
          verifyNoLayoutOverflowOrFatalErrors(tester, overflowErrors);
        }
      },
    );

    testWidgets(
      '1.8 Đăng ký thành công (Sẵn sàng!) renders at 375x812 with no overflow & exact copy',
      (tester) async {
        tester.view.physicalSize = const Size(375, 812);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final List<FlutterErrorDetails> overflowErrors = [];
        configureTestErrorHandling(overflowErrors);

        await tester.pumpWidget(
          buildTestableScreen(
            child: const OnboardingScreen(
              initialPage: 4,
              isPostRegistration: true,
            ),
          ),
        );
        await tester.pumpAndSettle();

        verifyNoLayoutOverflowOrFatalErrors(tester, overflowErrors);

        // Copywriting assertions
        expect(find.text('Sẵn sàng!'), findsOneWidget);
        expect(
          find.text('Bạn đã hoàn tất đăng ký.\nBắt đầu khám phá Evenear nhé!'),
          findsOneWidget,
        );
        expect(find.text('Bắt đầu'), findsOneWidget);

        final btnFinder = find.widgetWithText(ElevatedButton, 'Bắt đầu');
        expect(btnFinder, findsOneWidget);
        final ElevatedButton btn = tester.widget(btnFinder);
        expect(btn.style?.shape?.resolve({}), isA<StadiumBorder>());

        final scrollable = find.byType(Scrollable);
        if (scrollable.evaluate().isNotEmpty) {
          await tester.drag(scrollable.first, const Offset(0, -200));
          await tester.pumpAndSettle();
          verifyNoLayoutOverflowOrFatalErrors(tester, overflowErrors);
        }
      },
    );
  });

  group('Section 2 — Monitored Mode: Tôi được bảo vệ (5 Screens)', () {
    testWidgets(
      '2.1 Trang chủ (Monitored Mode) renders at 375x812 with no overflow & exact copy',
      (tester) async {
        tester.view.physicalSize = const Size(375, 812);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final List<FlutterErrorDetails> overflowErrors = [];
        configureTestErrorHandling(overflowErrors);

        await tester.pumpWidget(
          buildTestableScreen(child: const MonitoredView()),
        );
        await tester.pumpAndSettle();

        verifyNoLayoutOverflowOrFatalErrors(tester, overflowErrors);

        // Copywriting assertions
        expect(find.text('Xin chào, An 👋'), findsOneWidget);
        expect(
          find.byWidgetPredicate(
            (w) =>
                w is Text &&
                (w.data == 'Tình trạng ổn định' ||
                    w.data == 'Bạn đang được bảo vệ'),
          ),
          findsOneWidget,
        );
        expect(find.text('Tôi vẫn ổn'), findsOneWidget);
        expect(find.text('Nhấn để xác nhận'), findsOneWidget);
        expect(find.text('Lần hoạt động gần nhất'), findsOneWidget);
        expect(find.text('(Đã đồng bộ)'), findsOneWidget);
        expect(find.text('Pin thiết bị'), findsOneWidget);
        expect(find.text('--%'), findsOneWidget);
        expect(find.text('Lịch kiểm tra'), findsOneWidget);
        expect(find.text('Chưa thiết lập khung giờ'), findsOneWidget);

        final scrollable = find.byType(Scrollable);
        if (scrollable.evaluate().isNotEmpty) {
          await tester.drag(scrollable.first, const Offset(0, -200));
          await tester.pumpAndSettle();
          verifyNoLayoutOverflowOrFatalErrors(tester, overflowErrors);
        }
      },
    );

    testWidgets(
      '2.2 Xác nhận "Tôi vẫn ổn" (CheckInScreen) renders at 375x812 with no overflow & exact copy',
      (tester) async {
        tester.view.physicalSize = const Size(375, 812);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final List<FlutterErrorDetails> overflowErrors = [];
        configureTestErrorHandling(overflowErrors);

        await tester.pumpWidget(
          buildTestableScreen(
            child: CheckInScreen(
              confirmedAt: DateTime(2025, 10, 15, 8, 42),
            ),
          ),
        );
        await tester.pumpAndSettle();

        verifyNoLayoutOverflowOrFatalErrors(tester, overflowErrors);

        // Copywriting assertions
        expect(find.text('Xác nhận an toàn'), findsOneWidget);
        expect(find.text('Tuyệt vời!\nBạn vẫn ổn!'), findsOneWidget);
        expect(find.text('Thời gian xác nhận'), findsOneWidget);
        expect(find.text('08:42 • 15/10/2025'), findsOneWidget);
        expect(find.text('Hoàn tất'), findsOneWidget);

        final btnFinder = find.widgetWithText(ElevatedButton, 'Hoàn tất');
        expect(btnFinder, findsOneWidget);
        final ElevatedButton btn = tester.widget(btnFinder);
        expect(btn.style?.shape?.resolve({}), isA<StadiumBorder>());

        final scrollable = find.byType(Scrollable);
        if (scrollable.evaluate().isNotEmpty) {
          await tester.drag(scrollable.first, const Offset(0, -200));
          await tester.pumpAndSettle();
          verifyNoLayoutOverflowOrFatalErrors(tester, overflowErrors);
        }
      },
    );

    testWidgets(
      '2.3 Lịch sử hoạt động (RecentActivitiesScreen) renders at 375x812 with no overflow & exact copy',
      (tester) async {
        tester.view.physicalSize = const Size(375, 812);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final List<FlutterErrorDetails> overflowErrors = [];
        configureTestErrorHandling(overflowErrors);

        await tester.pumpWidget(
          buildTestableScreen(
            child: const RecentActivitiesScreen(showAppBar: true),
          ),
        );
        await tester.pumpAndSettle();

        verifyNoLayoutOverflowOrFatalErrors(tester, overflowErrors);

        // Copywriting assertions
        expect(find.text('Hoạt động gần đây'), findsOneWidget);
        expect(find.text('Chưa có hoạt động gần đây'), findsOneWidget);
        expect(find.text('Các hoạt động mở khóa, sạc pin hoặc điểm danh an toàn sẽ xuất hiện tại đây.'), findsOneWidget);

        final scrollable = find.byType(Scrollable);
        if (scrollable.evaluate().isNotEmpty) {
          await tester.drag(scrollable.first, const Offset(0, -200));
          await tester.pumpAndSettle();
          verifyNoLayoutOverflowOrFatalErrors(tester, overflowErrors);
        }
      },
    );

    testWidgets(
      '2.4 Quản lý thiết bị (DevicesScreen) renders at 375x812 with no overflow & exact copy',
      (tester) async {
        tester.view.physicalSize = const Size(375, 812);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final List<FlutterErrorDetails> overflowErrors = [];
        configureTestErrorHandling(overflowErrors);

        await tester.pumpWidget(
          buildTestableScreen(child: const DevicesScreen(showAppBar: true)),
        );
        await tester.pumpAndSettle();

        verifyNoLayoutOverflowOrFatalErrors(tester, overflowErrors);

        // Copywriting assertions
        expect(find.text('Thiết bị của bạn'), findsOneWidget);
        expect(find.text('Chưa có thiết bị nào'), findsOneWidget);
        expect(find.text('Đồng bộ thiết bị hiện tại'), findsWidgets);

        final scrollable = find.byType(Scrollable);
        if (scrollable.evaluate().isNotEmpty) {
          await tester.drag(scrollable.first, const Offset(0, -200));
          await tester.pumpAndSettle();
          verifyNoLayoutOverflowOrFatalErrors(tester, overflowErrors);
        }
      },
    );

    testWidgets(
      '2.5 Cài đặt giám sát (MonitoringSettingsScreen) renders at 375x812 with no overflow & exact copy',
      (tester) async {
        tester.view.physicalSize = const Size(375, 812);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final List<FlutterErrorDetails> overflowErrors = [];
        configureTestErrorHandling(overflowErrors);

        await tester.pumpWidget(
          buildTestableScreen(
            child: MonitoringSettingsScreen(
              relationship: _createSampleRelationship(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        verifyNoLayoutOverflowOrFatalErrors(tester, overflowErrors);

        // Copywriting assertions
        expect(find.text('Cài đặt giám sát'), findsOneWidget);
        expect(find.text('Khung giờ hoạt động'), findsOneWidget);
        expect(find.textContaining('07:00'), findsWidgets);
        expect(find.text('Nhắc nhở kiểm tra'), findsOneWidget);
        expect(find.textContaining('09:00'), findsWidgets);
        expect(find.text('Chế độ tạm dừng'), findsOneWidget);
        expect(find.text('Thông báo pin yếu'), findsOneWidget);

        final scrollable = find.byType(Scrollable);
        if (scrollable.evaluate().isNotEmpty) {
          await tester.drag(scrollable.first, const Offset(0, -200));
          await tester.pumpAndSettle();
          verifyNoLayoutOverflowOrFatalErrors(tester, overflowErrors);
        }
      },
    );
  });

  group('Section 3 — Guardian Mode: Theo dõi người thân (3 Screens)', () {
    testWidgets(
      '3.1 Danh sách người thân (MonitorView) renders at 375x812 with no overflow & exact copy',
      (tester) async {
        tester.view.physicalSize = const Size(375, 812);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final List<FlutterErrorDetails> overflowErrors = [];
        configureTestErrorHandling(overflowErrors);

        await tester.pumpWidget(
          buildTestableScreen(child: const MonitorView()),
        );
        await tester.pumpAndSettle();

        verifyNoLayoutOverflowOrFatalErrors(tester, overflowErrors);

        // Copywriting assertions
        expect(find.text('Danh sách người thân'), findsOneWidget);
        expect(find.text('Bạn chưa theo dõi người thân nào'), findsOneWidget);
        expect(find.text('Quét mã QR người thân'), findsOneWidget);
        expect(find.text('Tạo mã mời'), findsOneWidget);

        final scrollable = find.byType(Scrollable);
        if (scrollable.evaluate().isNotEmpty) {
          await tester.drag(scrollable.first, const Offset(0, -200));
          await tester.pumpAndSettle();
          verifyNoLayoutOverflowOrFatalErrors(tester, overflowErrors);
        }
      },
    );

    testWidgets(
      '3.2 Chi tiết người thân (RelativeDetailScreen) renders at 375x812 with no overflow & exact copy',
      (tester) async {
        tester.view.physicalSize = const Size(375, 812);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final List<FlutterErrorDetails> overflowErrors = [];
        configureTestErrorHandling(overflowErrors);

        await tester.pumpWidget(
          buildTestableScreen(
            child: const RelativeDetailScreen(
              relativeData: _sampleRelativeData,
            ),
          ),
        );
        await tester.pumpAndSettle();

        verifyNoLayoutOverflowOrFatalErrors(tester, overflowErrors);

        // Copywriting assertions
        expect(find.text('Chi tiết người thân'), findsOneWidget);
        expect(find.text('Mẹ'), findsWidgets);
        expect(find.text('Đang được bảo vệ'), findsOneWidget);
        expect(find.text('Liên hệ'), findsOneWidget);
        expect(find.text('Thông tin'), findsOneWidget);
        expect(find.text('Hoạt động'), findsOneWidget);
        expect(find.text('Thiết bị'), findsWidgets);
        expect(find.text('Lần xác nhận gần nhất'), findsOneWidget);
        expect(find.text('15/10/2025 • 08:32'), findsOneWidget);
        expect(find.text('Vị trí gần nhất'), findsOneWidget);
        expect(find.text('Hà Nội (chỉ khi cần)'), findsOneWidget);
        expect(find.text('iPhone 15 Pro'), findsOneWidget);

        final scrollable = find.byType(Scrollable);
        if (scrollable.evaluate().isNotEmpty) {
          await tester.drag(scrollable.first, const Offset(0, -200));
          await tester.pumpAndSettle();
          verifyNoLayoutOverflowOrFatalErrors(tester, overflowErrors);
        }
      },
    );

    testWidgets(
      '3.3 Dòng thời gian sự kiện (IncidentsListScreen) renders at 375x812 with no overflow & exact copy',
      (tester) async {
        tester.view.physicalSize = const Size(375, 812);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final List<FlutterErrorDetails> overflowErrors = [];
        configureTestErrorHandling(overflowErrors);

        await tester.pumpWidget(
          buildTestableScreen(child: const IncidentsListScreen()),
        );
        await tester.pumpAndSettle();

        verifyNoLayoutOverflowOrFatalErrors(tester, overflowErrors);

        // Copywriting assertions
        expect(find.text('Thông báo & sự kiện'), findsOneWidget);
        expect(find.text('Tất cả'), findsOneWidget);
        expect(find.text('An toàn'), findsOneWidget);
        expect(find.text('Cảnh báo'), findsWidgets);
        expect(find.text('Mọi thứ đều bình an'), findsOneWidget);

        final scrollable = find.byType(Scrollable);
        if (scrollable.evaluate().isNotEmpty) {
          await tester.drag(scrollable.first, const Offset(0, -200));
          await tester.pumpAndSettle();
          verifyNoLayoutOverflowOrFatalErrors(tester, overflowErrors);
        }
      },
    );
  });

  group('Section 4 — Sự kiện & xử lý sự cố (3 Screens)', () {
    testWidgets(
      '4.1 Thông báo cảnh báo (IncidentDetailScreen step 0) renders at 375x812 with no overflow & exact copy',
      (tester) async {
        tester.view.physicalSize = const Size(375, 812);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final List<FlutterErrorDetails> overflowErrors = [];
        configureTestErrorHandling(overflowErrors);

        await tester.pumpWidget(
          buildTestableScreen(
            child: const IncidentDetailScreen(
              showcaseMode: true,
              initialStep: 0,
            ),
          ),
        );
        await tester.pumpAndSettle();

        verifyNoLayoutOverflowOrFatalErrors(tester, overflowErrors);

        // Copywriting assertions
        expect(find.text('Cảnh báo'), findsWidgets);
        expect(find.text('Cảnh báo an toàn'), findsOneWidget);
        expect(find.text('Không nhận được phản hồi'), findsOneWidget);
        expect(
          find.text('Người thân chưa xác nhận an toàn trong khoảng thời gian dự kiến'),
          findsOneWidget,
        );
        expect(find.text('Xem chi tiết'), findsOneWidget);
        expect(find.text('Gọi ngay'), findsOneWidget);

        final scrollable = find.byType(Scrollable);
        if (scrollable.evaluate().isNotEmpty) {
          await tester.drag(scrollable.first, const Offset(0, -200));
          await tester.pumpAndSettle();
          verifyNoLayoutOverflowOrFatalErrors(tester, overflowErrors);
        }
      },
    );

    testWidgets(
      '4.2 Chi tiết sự cố (IncidentDetailScreen step 1) renders at 375x812 with no overflow & exact copy',
      (tester) async {
        tester.view.physicalSize = const Size(375, 812);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final List<FlutterErrorDetails> overflowErrors = [];
        configureTestErrorHandling(overflowErrors);

        await tester.pumpWidget(
          buildTestableScreen(
            child: const IncidentDetailScreen(
              showcaseMode: true,
              initialStep: 1,
            ),
          ),
        );
        await tester.pumpAndSettle();

        verifyNoLayoutOverflowOrFatalErrors(tester, overflowErrors);

        // Copywriting assertions
        expect(find.text('Chi tiết sự cố'), findsWidgets);
        expect(find.text('Tóm tắt sự cố'), findsOneWidget);
        expect(find.text('Timeline sự kiện'), findsOneWidget);
        expect(find.text('Lịch sử thông báo'), findsOneWidget);
        expect(find.text('Xử lý sự cố'), findsWidgets);

        final scrollable = find.byType(Scrollable);
        if (scrollable.evaluate().isNotEmpty) {
          await tester.drag(scrollable.first, const Offset(0, -200));
          await tester.pumpAndSettle();
          verifyNoLayoutOverflowOrFatalErrors(tester, overflowErrors);
        }
      },
    );

    testWidgets(
      '4.3 Khôi phục trạng thái (IncidentDetailScreen step 2) renders at 375x812 with no overflow & exact copy',
      (tester) async {
        tester.view.physicalSize = const Size(375, 812);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final List<FlutterErrorDetails> overflowErrors = [];
        configureTestErrorHandling(overflowErrors);

        await tester.pumpWidget(
          buildTestableScreen(
            child: const IncidentDetailScreen(
              showcaseMode: true,
              initialStep: 2,
            ),
          ),
        );
        await tester.pumpAndSettle();

        verifyNoLayoutOverflowOrFatalErrors(tester, overflowErrors);

        // Copywriting assertions
        expect(find.text('Xử lý sự cố'), findsWidgets);
        expect(find.text('Trạng thái hiện tại'), findsOneWidget);
        expect(find.text('Ghi chú xử lý'), findsOneWidget);
        expect(find.text('Đánh dấu đã xử lý'), findsOneWidget);
        expect(find.text('Báo động giả'), findsOneWidget);

        final scrollable = find.byType(Scrollable);
        if (scrollable.evaluate().isNotEmpty) {
          await tester.drag(scrollable.first, const Offset(0, -200));
          await tester.pumpAndSettle();
          verifyNoLayoutOverflowOrFatalErrors(tester, overflowErrors);
        }
      },
    );
  });

  group('Section 5 — Cài đặt & Tùy chỉnh (4 Screens)', () {
    testWidgets(
      '5.1 Menu cài đặt (SettingsScreen) renders at 375x812 with no overflow & exact copy',
      (tester) async {
        tester.view.physicalSize = const Size(375, 812);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final List<FlutterErrorDetails> overflowErrors = [];
        configureTestErrorHandling(overflowErrors);

        await tester.pumpWidget(
          buildTestableScreen(child: const SettingsScreen()),
        );
        await tester.pumpAndSettle();

        verifyNoLayoutOverflowOrFatalErrors(tester, overflowErrors);

        // Copywriting assertions
        expect(find.text('Cài đặt & Tài khoản'), findsOneWidget);
        expect(find.text('Thông tin cá nhân'), findsOneWidget);
        expect(find.text('Người thân & ủy quyền'), findsOneWidget);
        expect(find.text('Giám sát & nhắc nhở'), findsOneWidget);
        expect(find.text('Thiết bị'), findsOneWidget);
        expect(find.text('Quyền riêng tư & bảo mật'), findsOneWidget);
        expect(find.text('Cài đặt thông báo'), findsOneWidget);
        expect(find.textContaining('Ngôn ngữ'), findsWidgets);

        final scrollable = find.byType(Scrollable);
        if (scrollable.evaluate().isNotEmpty) {
          await tester.drag(scrollable.first, const Offset(0, -200));
          await tester.pumpAndSettle();
          verifyNoLayoutOverflowOrFatalErrors(tester, overflowErrors);
        }
      },
    );

    testWidgets(
      '5.2 Bảo mật & quyền riêng tư (PrivacySecurityScreen) renders at 375x812 with no overflow & exact copy',
      (tester) async {
        tester.view.physicalSize = const Size(375, 812);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final List<FlutterErrorDetails> overflowErrors = [];
        configureTestErrorHandling(overflowErrors);

        await tester.pumpWidget(
          buildTestableScreen(child: const PrivacySecurityScreen()),
        );
        await tester.pumpAndSettle();

        verifyNoLayoutOverflowOrFatalErrors(tester, overflowErrors);

        // Copywriting assertions
        expect(find.text('Quyền riêng tư & bảo mật'), findsOneWidget);
        expect(find.text('Dữ liệu vị trí'), findsOneWidget);
        expect(find.text('Quyền truy cập'), findsOneWidget);
        expect(find.text('Sao lưu & khôi phục'), findsOneWidget);
        expect(find.text('Xóa tài khoản'), findsOneWidget);

        final scrollable = find.byType(Scrollable);
        if (scrollable.evaluate().isNotEmpty) {
          await tester.drag(scrollable.first, const Offset(0, -200));
          await tester.pumpAndSettle();
          verifyNoLayoutOverflowOrFatalErrors(tester, overflowErrors);
        }
      },
    );

    testWidgets(
      '5.3 Chọn ngôn ngữ (LanguageSettingsScreen) renders at 375x812 with no overflow & exact copy',
      (tester) async {
        tester.view.physicalSize = const Size(375, 812);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final List<FlutterErrorDetails> overflowErrors = [];
        configureTestErrorHandling(overflowErrors);

        await tester.pumpWidget(
          buildTestableScreen(child: const LanguageSettingsScreen()),
        );
        await tester.pumpAndSettle();

        verifyNoLayoutOverflowOrFatalErrors(tester, overflowErrors);

        // Copywriting assertions
        expect(find.text('Cài đặt Ngôn ngữ / Language'), findsOneWidget);
        expect(find.text('Tiếng Việt (VN)'), findsOneWidget);
        expect(find.text('English (US)'), findsOneWidget);
        expect(find.text('日本語 (JP)'), findsOneWidget);
        expect(find.text('中文 (CN)'), findsOneWidget);
        expect(find.text('Áp dụng'), findsOneWidget);

        final scrollable = find.byType(Scrollable);
        if (scrollable.evaluate().isNotEmpty) {
          await tester.drag(scrollable.first, const Offset(0, -200));
          await tester.pumpAndSettle();
          verifyNoLayoutOverflowOrFatalErrors(tester, overflowErrors);
        }
      },
    );

    testWidgets(
      '5.4 Cài đặt thông báo (NotificationSettingsScreen) renders at 375x812 with no overflow & exact copy',
      (tester) async {
        tester.view.physicalSize = const Size(375, 812);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final List<FlutterErrorDetails> overflowErrors = [];
        configureTestErrorHandling(overflowErrors);

        await tester.pumpWidget(
          buildTestableScreen(child: const NotificationSettingsScreen()),
        );
        await tester.pumpAndSettle();

        verifyNoLayoutOverflowOrFatalErrors(tester, overflowErrors);

        // Copywriting assertions
        expect(find.text('Thông báo'), findsOneWidget);
        expect(find.text('Thông báo đẩy'), findsOneWidget);
        expect(find.text('Cảnh báo khẩn cấp'), findsOneWidget);
        expect(find.text('Nhắc nhở kiểm tra'), findsOneWidget);
        expect(find.text('Cập nhật từ hệ thống'), findsOneWidget);
        expect(find.text('Âm thanh'), findsOneWidget);
        expect(find.text('Nhạc chuông'), findsOneWidget);

        final scrollable = find.byType(Scrollable);
        if (scrollable.evaluate().isNotEmpty) {
          await tester.drag(scrollable.first, const Offset(0, -200));
          await tester.pumpAndSettle();
          verifyNoLayoutOverflowOrFatalErrors(tester, overflowErrors);
        }
      },
    );
  });
}
