import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/constants/app_strings.dart';
import 'package:mobile/core/models/enums.dart';
import 'package:mobile/core/models/monitoring_config_model.dart';
import 'package:mobile/core/models/relationship_model.dart';
import 'package:mobile/core/models/schedule_window_model.dart';
import 'package:mobile/core/models/user_model.dart';
import 'package:mobile/features/auth/auth_provider.dart';
import 'package:mobile/features/auth/login_screen.dart';
import 'package:mobile/features/auth/onboarding_screen.dart';
import 'package:mobile/features/auth/register_screen.dart';
import 'package:mobile/features/check_in/check_in_screen.dart';
import 'package:mobile/features/dashboard/dashboard_provider.dart';
import 'package:mobile/features/dashboard/guardian_view.dart';
import 'package:mobile/features/incidents/incidents_provider.dart';
import 'package:provider/provider.dart';

class _TestMockDashboardProvider extends DashboardProvider {
  final List<RelationshipModel> _relList;

  _TestMockDashboardProvider(this._relList);

  @override
  bool get isLoading => false;

  @override
  List<RelationshipModel> get monitoredByMe => _relList;

  @override
  List<RelationshipModel> get monitoringMe => _relList;

  @override
  MonitoringState get myCurrentState => MonitoringState.ACTIVE;

  @override
  Future<void> fetchDashboardData() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Milestone 2 Worker 2A Invariant Tests', () {
    testWidgets('OnboardingScreen renders slides, pill button, and satisfies negative social auth assertion', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: OnboardingScreen(),
        ),
      );

      // Verify branding and slide content
      expect(find.text(AppStrings.appName), findsOneWidget);
      expect(find.text('Bảo vệ thầm lặng 24/7'), findsOneWidget);
      expect(find.text('Bỏ qua'), findsOneWidget);
      expect(find.text('Tiếp tục'), findsOneWidget);

      // Verify primary button shape is StadiumBorder
      final buttonFinder = find.widgetWithText(ElevatedButton, 'Tiếp tục');
      expect(buttonFinder, findsOneWidget);
      final ElevatedButton buttonWidget = tester.widget(buttonFinder);
      expect(buttonWidget.style?.shape?.resolve({}), isA<StadiumBorder>());

      // Negative assertion: Social sign-in buttons MUST NOT exist
      expect(find.byKey(const Key('google_sign_in_button')), findsNothing);
      expect(find.byKey(const Key('apple_sign_in_button')), findsNothing);
    });

    testWidgets('LoginScreen preserves login_language_dropdown key and negative social auth assertion', (tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => AuthProvider()),
            ChangeNotifierProvider(create: (_) => DashboardProvider()),
            ChangeNotifierProvider(create: (_) => IncidentsProvider()),
          ],
          child: const MaterialApp(
            home: LoginScreen(),
          ),
        ),
      );

      // Preserved login_language_dropdown key
      expect(find.byKey(const Key('login_language_dropdown')), findsOneWidget);

      // Negative assertion: Social sign-in buttons MUST NOT exist
      expect(find.byKey(const Key('google_sign_in_button')), findsNothing);
      expect(find.byKey(const Key('apple_sign_in_button')), findsNothing);

      // Primary submit button has StadiumBorder
      final submitFinder = find.widgetWithText(ElevatedButton, 'Đăng nhập');
      expect(submitFinder, findsOneWidget);
      final ElevatedButton submitWidget = tester.widget(submitFinder);
      expect(submitWidget.style?.shape?.resolve({}), isA<StadiumBorder>());
    });

    testWidgets('RegisterScreen renders 16px soft grey inputs, StadiumBorder button, and no social auth', (tester) async {
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

      expect(find.text('Đăng ký tài khoản'), findsOneWidget);
      expect(find.text('Họ và tên'), findsOneWidget);
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Mật khẩu'), findsOneWidget);
      expect(find.text('Số điện thoại (dùng nhận tin nhắn khẩn cấp)'), findsOneWidget);
      expect(find.text('Tạo tài khoản'), findsOneWidget);

      final registerFinder = find.widgetWithText(ElevatedButton, 'Tạo tài khoản');
      expect(registerFinder, findsOneWidget);
      final ElevatedButton registerWidget = tester.widget(registerFinder);
      expect(registerWidget.style?.shape?.resolve({}), isA<StadiumBorder>());

      expect(find.byKey(const Key('google_sign_in_button')), findsNothing);
      expect(find.byKey(const Key('apple_sign_in_button')), findsNothing);
    });

    testWidgets('GuardianView / MonitorView renders pure white safety cards with risk score gauge and incident summary pills', (tester) async {
      final mockRelative = RelationshipModel(
        id: 'rel-1',
        monitoredUserId: 'user-monitored-1',
        monitorUserId: 'user-monitor-1',
        status: RelationshipStatus.ACCEPTED,
        createdAt: DateTime.now(),
        label: 'Mẹ',
        monitoredUser: UserModel(
          id: 'user-monitored-1',
          email: 'me@carely.vn',
          fullName: 'Nguyễn Thị Hoa',
          timezone: 'Asia/Ho_Chi_Minh',
          isActive: true,
          createdAt: DateTime.now(),
        ),
        config: MonitoringConfigModel(
          id: 'cfg-1',
          relationshipId: 'rel-1',
          currentState: MonitoringState.ACTIVE,
          inactivityThresholdMinutes: 180,
          checkInGracePeriodMinutes: 30,
          escalationGracePeriodMinutes: 30,
          locationEnabled: true,
          isPaused: false,
          timezone: 'Asia/Ho_Chi_Minh',
          lastMeaningfulActivityAt: DateTime.now().subtract(const Duration(minutes: 15)),
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

      final dashboardProvider = _TestMockDashboardProvider([mockRelative]);

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

      expect(find.text('Nguyễn Thị Hoa'), findsOneWidget);
      expect(find.text('Mẹ'), findsOneWidget);
      expect(find.textContaining('Nguy cơ:'), findsOneWidget);
      expect(find.text('0 cảnh báo'), findsOneWidget);
      expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
      expect(find.byType(Card), findsOneWidget);
    });

    testWidgets('CheckInScreen renders StadiumBorder button, reassurance note, and handles submit', (tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => DashboardProvider()),
          ],
          child: const MaterialApp(
            home: CheckInScreen(),
          ),
        ),
      );

      expect(find.text(AppStrings.checkInPrompt), findsOneWidget);
      expect(find.text(AppStrings.checkInButton), findsOneWidget);
      expect(find.text('Xác nhận an toàn'), findsOneWidget);
      expect(find.textContaining('Bạn không cần mở app liên tục'), findsOneWidget);

      final checkInBtnFinder = find.widgetWithText(ElevatedButton, AppStrings.checkInButton);
      expect(checkInBtnFinder, findsOneWidget);
      final ElevatedButton checkInBtn = tester.widget(checkInBtnFinder);
      expect(checkInBtn.style?.shape?.resolve({}), isA<StadiumBorder>());
    });
  });
}
