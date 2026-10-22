import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mobile/core/i18n/app_localizations.dart';
import 'package:mobile/core/i18n/locale_catalog_registry.dart';
import 'package:mobile/core/i18n/locale_provider.dart';
import 'package:mobile/core/models/user_model.dart';
import 'package:mobile/core/widgets/language_selector.dart';
import 'package:mobile/features/auth/auth_provider.dart';
import 'package:mobile/features/auth/login_screen.dart';
import 'package:mobile/features/auth/onboarding_screen.dart';
import 'package:mobile/features/auth/register_screen.dart';
import 'package:mobile/features/dashboard/dashboard_provider.dart';
import 'package:mobile/features/incidents/incidents_provider.dart';

/// Mock AuthProvider for test isolation
class MockChallengerAuthProvider extends AuthProvider {
  UserModel? _user;
  bool _isAuthenticated = false;
  String? lastUpdatedLanguage;

  MockChallengerAuthProvider({UserModel? user, bool isAuthenticated = false}) {
    _user = user;
    _isAuthenticated = isAuthenticated;
  }

  @override
  bool get isAuthenticated => _isAuthenticated;

  @override
  bool get isLoading => false;

  @override
  UserModel? get currentUser => _user;

  @override
  String? get errorMessage => null;

  @override
  String? getErrorMessage(BuildContext context) => null;

  @override
  Future<bool> login(String email, String password) async {
    _isAuthenticated = true;
    _user ??= UserModel(
      id: 'test-user-challenger2',
      email: email,
      fullName: 'Challenger 2 User',
      timezone: 'Asia/Ho_Chi_Minh',
      isActive: true,
      preferredLanguage: 'vi',
      createdAt: DateTime(2025, 1, 1),
    );
    notifyListeners();
    return true;
  }

  @override
  Future<bool> register({
    required String fullName,
    required String email,
    required String password,
    String? phone,
    String? preferredLanguage,
  }) async {
    _isAuthenticated = true;
    _user = UserModel(
      id: 'test-user-challenger2',
      email: email,
      fullName: fullName,
      phone: phone,
      timezone: 'Asia/Ho_Chi_Minh',
      isActive: true,
      preferredLanguage: preferredLanguage ?? 'vi',
      createdAt: DateTime(2025, 1, 1),
    );
    notifyListeners();
    return true;
  }

  @override
  void updateUserPreferredLanguage(String langCode) {
    lastUpdatedLanguage = langCode;
    if (_user != null) {
      _user = _user!.copyWith(preferredLanguage: langCode);
      notifyListeners();
    }
  }

  @override
  Future<bool> updateProfile({
    String? fullName,
    String? phone,
    String? avatarUrl,
    String? preferredLanguage,
  }) async {
    if (preferredLanguage != null) {
      updateUserPreferredLanguage(preferredLanguage);
    }
    return true;
  }

  @override
  Future<void> logout({dynamic dashboardProvider, dynamic incidentsProvider}) async {
    _isAuthenticated = false;
    _user = null;
    notifyListeners();
  }
}

/// Helper that wraps target widget with reactive `Consumer<LocaleProvider>`
Widget buildChallengerTestHarness({
  required Widget child,
  required LocaleProvider localeProvider,
  AuthProvider? authProvider,
  TextScaler? textScaler,
}) {
  final auth = authProvider ?? MockChallengerAuthProvider();
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<LocaleProvider>.value(value: localeProvider),
      ChangeNotifierProvider<AuthProvider>.value(value: auth),
      ChangeNotifierProvider<DashboardProvider>(create: (_) => DashboardProvider()),
      ChangeNotifierProvider<IncidentsProvider>(create: (_) => IncidentsProvider()),
    ],
    child: Consumer<LocaleProvider>(
      builder: (context, lp, _) {
        return MaterialApp(
          locale: lp.currentLocale,
          supportedLocales: LocaleCatalogRegistry.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          builder: (ctx, childWidget) {
            final media = MediaQuery.of(ctx);
            return MediaQuery(
              data: media.copyWith(
                textScaler: textScaler ?? media.textScaler,
              ),
              child: childWidget!,
            );
          },
          home: child,
          routes: {
            '/dashboard': (_) => const Scaffold(body: Text('DashboardScreen')),
            '/login': (_) => const LoginScreen(),
            '/register': (_) => const RegisterScreen(),
            '/onboarding': (_) => const OnboardingScreen(),
          },
        );
      },
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppLocalizations.globalLocaleCode = 'vi';
  });

  // =========================================================================
  // REQUIREMENT 1: LanguageSelector Presence & Rendering on Pre-Auth Screens
  // =========================================================================
  group('Challenger 2 - R1: LanguageSelector Renders on Login, Register, Onboarding', () {
    testWidgets('LoginScreen renders LanguageSelector with preauth and screen-specific keys', (tester) async {
      final localeProvider = LocaleProvider();
      await localeProvider.initialize();

      await tester.pumpWidget(
        buildChallengerTestHarness(
          child: const LoginScreen(),
          localeProvider: localeProvider,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(LanguageSelector), findsOneWidget);
      expect(find.byKey(const Key('preauth_language_selector')), findsOneWidget);
      expect(find.byKey(const Key('login_language_dropdown')), findsOneWidget);
      expect(find.text('VI'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('RegisterScreen renders LanguageSelector with preauth and screen-specific keys', (tester) async {
      final localeProvider = LocaleProvider();
      await localeProvider.initialize();

      await tester.pumpWidget(
        buildChallengerTestHarness(
          child: const RegisterScreen(),
          localeProvider: localeProvider,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(LanguageSelector), findsOneWidget);
      expect(find.byKey(const Key('preauth_language_selector')), findsOneWidget);
      expect(find.byKey(const Key('register_language_dropdown')), findsOneWidget);
      expect(find.text('VI'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('OnboardingScreen renders LanguageSelector with preauth and screen-specific keys', (tester) async {
      final localeProvider = LocaleProvider();
      await localeProvider.initialize();

      await tester.pumpWidget(
        buildChallengerTestHarness(
          child: const OnboardingScreen(initialPage: 0),
          localeProvider: localeProvider,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(LanguageSelector), findsOneWidget);
      expect(find.byKey(const Key('preauth_language_selector')), findsOneWidget);
      expect(find.byKey(const Key('onboarding_language_dropdown')), findsOneWidget);
      expect(find.text('VI'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  // =========================================================================
  // REQUIREMENT 2: Switching Language in Dropdown Updates Screen Text in Real Time
  // =========================================================================
  group('Challenger 2 - R2: Real-Time Dynamic Dropdown Switching & Re-rendering', () {
    testWidgets('LoginScreen: Dropdown selection updates locale and screen copy in real-time (VI -> EN -> JA -> VI)', (tester) async {
      final localeProvider = LocaleProvider();
      await localeProvider.initialize();

      await tester.pumpWidget(
        buildChallengerTestHarness(
          child: const LoginScreen(),
          localeProvider: localeProvider,
        ),
      );
      await tester.pumpAndSettle();

      // Verify Initial Vietnamese State
      expect(localeProvider.currentLanguageCode, 'vi');
      expect(find.text('VI'), findsOneWidget);
      expect(find.text('Chào mừng trở lại!'), findsOneWidget);
      expect(find.text('Đăng nhập để tiếp tục'), findsOneWidget);
      expect(find.text('Đăng nhập'), findsWidgets);

      // --- STEP 1: Switch to English ('en') ---
      await tester.tap(find.byKey(const Key('login_language_dropdown')));
      await tester.pumpAndSettle();

      expect(find.text('English'), findsWidgets);
      await tester.tap(find.text('English').last);
      await tester.pumpAndSettle();

      // Verify real-time English re-render
      expect(localeProvider.currentLanguageCode, 'en');
      expect(find.text('EN'), findsOneWidget);
      expect(find.text('Welcome back!'), findsOneWidget);
      expect(find.text('Sign in to continue'), findsOneWidget);
      expect(find.text('Sign In'), findsWidgets);
      expect(find.text('Chào mừng trở lại!'), findsNothing);

      // Verify persistence to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(LocaleProvider.prefKeyLocale), 'en');

      // --- STEP 2: Switch from English back to Vietnamese ('vi') via dropdown ---
      await tester.tap(find.byKey(const Key('login_language_dropdown')));
      await tester.pumpAndSettle();

      expect(find.text('Tiếng Việt'), findsWidgets);
      await tester.ensureVisible(find.text('Tiếng Việt').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tiếng Việt').last);
      await tester.pumpAndSettle();

      expect(localeProvider.currentLanguageCode, 'vi');
      expect(find.text('VI'), findsOneWidget);
      expect(find.text('Chào mừng trở lại!'), findsOneWidget);
      expect(find.text('Đăng nhập để tiếp tục'), findsOneWidget);
      expect(find.text('Welcome back!'), findsNothing);
      expect(tester.takeException(), isNull);

      // --- STEP 3: Switch to Japanese ('ja') and verify Zero Fallback Leak ---
      await localeProvider.setLocale(const Locale('ja'));
      await tester.pumpAndSettle();

      expect(localeProvider.currentLanguageCode, 'ja');
      expect(find.text('JA'), findsOneWidget);
      expect(find.text('ログイン'), findsWidgets);
      // Zero fallback leak guarantee: jaCatalog translates auth_welcome_back to native Japanese, never viCatalog ('Chào mừng trở lại!')
      expect(find.text('おかえりなさい！'), findsOneWidget);
      expect(find.text('Chào mừng trở lại!'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('RegisterScreen: Dropdown selection updates locale and screen copy in real-time (VI -> EN)', (tester) async {
      final localeProvider = LocaleProvider();
      await localeProvider.initialize();

      await tester.pumpWidget(
        buildChallengerTestHarness(
          child: const RegisterScreen(),
          localeProvider: localeProvider,
        ),
      );
      await tester.pumpAndSettle();

      // Verify initial Vietnamese state
      expect(localeProvider.currentLanguageCode, 'vi');
      expect(find.text('Tạo tài khoản'), findsWidgets);
      expect(find.text('Bắt đầu hành trình an toàn cùng Evenear'), findsOneWidget);

      // Switch to English
      await tester.tap(find.byKey(const Key('register_language_dropdown')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('English').last);
      await tester.pumpAndSettle();

      // Verify real-time English re-render
      expect(localeProvider.currentLanguageCode, 'en');
      expect(find.text('EN'), findsOneWidget);
      expect(find.text('Create Account'), findsWidgets);
      expect(find.text('Start protecting peace of mind for you and your family'), findsOneWidget);
      expect(find.text('Bắt đầu hành trình an toàn cùng Evenear'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('OnboardingScreen: Dropdown selection updates slide copy across pages in real-time', (tester) async {
      final localeProvider = LocaleProvider();
      await localeProvider.initialize();

      await tester.pumpWidget(
        buildChallengerTestHarness(
          child: const OnboardingScreen(initialPage: 0),
          localeProvider: localeProvider,
        ),
      );
      await tester.pumpAndSettle();

      // Verify Initial Slide 1 in Vietnamese
      expect(localeProvider.currentLanguageCode, 'vi');
      expect(find.text('Đồng hành & Bảo vệ bình an cho người thân'), findsOneWidget);
      expect(find.text('Bắt đầu'), findsOneWidget);

      // Switch to English
      await tester.tap(find.byKey(const Key('onboarding_language_dropdown')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('English').last);
      await tester.pumpAndSettle();

      // Verify Slide 1 in English
      expect(localeProvider.currentLanguageCode, 'en');
      expect(find.text('EN'), findsOneWidget);
      expect(find.text('Companion & Peace of Mind for Loved Ones'), findsOneWidget);
      expect(find.text('Get Started'), findsOneWidget);
      expect(find.text('Đồng hành & Bảo vệ bình an cho người thân'), findsNothing);

      // Tap 'Get Started' to advance to Slide 2
      await tester.tap(find.text('Get Started'));
      await tester.pumpAndSettle();

      // Verify Slide 2 is rendered in English
      expect(find.text('Always by your side when needed'), findsOneWidget);
      expect(find.text('Continue'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  // =========================================================================
  // REQUIREMENT 3: Narrow Viewports (320px) Produce 0 RenderFlex Overflows
  // =========================================================================
  group('Challenger 2 - R3: Narrow Viewport Stress (320px) & Zero RenderFlex Overflows', () {
    const narrowSizes = [
      Size(320, 568), // iPhone SE 1st gen
      Size(320, 480), // iPhone 4 / extreme compact
      Size(320, 740), // Narrow modern android
    ];

    for (final size in narrowSizes) {
      testWidgets('LoginScreen on 320px viewport (${size.width}x${size.height}): 0 overflows initially, during scroll, and when dropdown opens', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final localeProvider = LocaleProvider();
        await localeProvider.initialize();

        await tester.pumpWidget(
          buildChallengerTestHarness(
            child: const LoginScreen(),
            localeProvider: localeProvider,
          ),
        );
        await tester.pumpAndSettle();

        // 1. Initial render must produce 0 RenderFlex overflows
        expect(tester.takeException(), isNull, reason: 'Initial render at $size must not overflow');

        // 2. Open dropdown at 320px width - popup menu (menuWidth: 200) must render cleanly
        await tester.tap(find.byKey(const Key('login_language_dropdown')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'Dropdown menu at $size must not overflow');

        // 3. Select English and close dropdown
        await tester.tap(find.text('English').last);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'Selection at $size must not overflow');

        // 4. Scroll test
        final scrollable = find.byType(Scrollable);
        if (scrollable.evaluate().isNotEmpty) {
          await tester.drag(scrollable.first, const Offset(0, -150));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: 'Scrolling at $size must not overflow');
          await tester.drag(scrollable.first, const Offset(0, 150));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: 'Scrolling back at $size must not overflow');
        }
      });

      testWidgets('RegisterScreen on 320px viewport (${size.width}x${size.height}): 0 overflows initially, during scroll, and when dropdown opens', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final localeProvider = LocaleProvider();
        await localeProvider.initialize();

        await tester.pumpWidget(
          buildChallengerTestHarness(
            child: const RegisterScreen(),
            localeProvider: localeProvider,
          ),
        );
        await tester.pumpAndSettle();

        // 1. Initial render
        expect(tester.takeException(), isNull, reason: 'Initial render at $size must not overflow');

        // 2. Open dropdown at 320px
        await tester.tap(find.byKey(const Key('register_language_dropdown')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'Dropdown menu at $size must not overflow');

        // 3. Select language
        await tester.tap(find.text('English').last);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'Selection at $size must not overflow');

        // 4. Scroll test
        final scrollable = find.byType(Scrollable);
        if (scrollable.evaluate().isNotEmpty) {
          await tester.drag(scrollable.first, const Offset(0, -200));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: 'Scrolling at $size must not overflow');
          await tester.drag(scrollable.first, const Offset(0, 200));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: 'Scrolling back at $size must not overflow');
        }
      });

      testWidgets('OnboardingScreen on 320px viewport (${size.width}x${size.height}): all slides render with 0 overflows', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final localeProvider = LocaleProvider();
        await localeProvider.initialize();

        await tester.pumpWidget(
          buildChallengerTestHarness(
            child: const OnboardingScreen(initialPage: 0),
            localeProvider: localeProvider,
          ),
        );
        await tester.pumpAndSettle();

        // Slide 1
        expect(tester.takeException(), isNull, reason: 'Onboarding Slide 1 at $size must not overflow');

        // Open dropdown on Slide 1
        await tester.tap(find.byKey(const Key('onboarding_language_dropdown')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'Dropdown on Onboarding at $size must not overflow');

        await tester.tap(find.text('English').last);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        // Verify all 5 Onboarding slides render at $size with 0 RenderFlex overflow
        for (int page = 0; page < 5; page++) {
          await tester.pumpWidget(
            buildChallengerTestHarness(
              child: OnboardingScreen(initialPage: page),
              localeProvider: localeProvider,
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: 'Onboarding Slide ${page + 1} at $size must not overflow');
        }
      });
    }

    testWidgets('Accessibility font scaling stress: TextScaler 1.3 at 320px width has 0 RenderFlex overflows', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      FlutterErrorDetails? errorDetails;
      final oldOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        errorDetails = details;
      };
      addTearDown(() => FlutterError.onError = oldOnError);

      final localeProvider = LocaleProvider();
      await localeProvider.initialize();

      await tester.pumpWidget(
        buildChallengerTestHarness(
          child: const LoginScreen(),
          localeProvider: localeProvider,
          textScaler: const TextScaler.linear(1.3),
        ),
      );
      await tester.pumpAndSettle();

      if (errorDetails != null) {
        // ignore: avoid_print
        print('FULL_ERROR_DETAILS: ${errorDetails!.summary}');
        // ignore: avoid_print
        print('CONTEXT: ${errorDetails!.context}');
        for (final info in errorDetails!.informationCollector?.call() ?? <DiagnosticsNode>[]) {
          // ignore: avoid_print
          print('COLLECTOR: $info');
        }
      }
      final err = tester.takeException();
      expect(err, isNull, reason: 'Accessibility text scaling at 320px must not overflow');
      expect(find.byKey(const Key('login_language_dropdown')), findsOneWidget);

      // Open dropdown with enlarged font
      await tester.tap(find.byKey(const Key('login_language_dropdown')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'Dropdown menu with 1.3x font at 320px must not overflow');

      await tester.tap(find.text('English').last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  // =========================================================================
  // REQUIREMENT 4: Rapid State & Dropdown Resilience Stress Tests
  // =========================================================================
  group('Challenger 2 - R4: Rapid Dropdown Toggles & Locale Stress', () {
    testWidgets('Consecutive rapid language changes (en -> fr -> de -> es -> vi) complete without race conditions', (tester) async {
      final localeProvider = LocaleProvider();
      await localeProvider.initialize();

      await tester.pumpWidget(
        buildChallengerTestHarness(
          child: const LoginScreen(),
          localeProvider: localeProvider,
        ),
      );
      await tester.pumpAndSettle();

      final sequence = ['en', 'fr', 'de', 'es', 'vi'];
      for (final code in sequence) {
        await localeProvider.setLocale(Locale(code));
        await tester.pumpAndSettle();
        expect(localeProvider.currentLanguageCode, code);
        expect(find.text(code.toUpperCase()), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('Long native language names in dropdown menu (menuWidth: 200) do not overflow item boundaries', (tester) async {
      final localeProvider = LocaleProvider();
      await localeProvider.initialize();

      await tester.pumpWidget(
        buildChallengerTestHarness(
          child: const Scaffold(
            body: Center(
              child: LanguageSelector(dropdownKey: Key('stress_dropdown')),
            ),
          ),
          localeProvider: localeProvider,
        ),
      );
      await tester.pumpAndSettle();

      // Open dropdown
      await tester.tap(find.byKey(const Key('stress_dropdown')));
      await tester.pumpAndSettle();

      // Verify that long language names (like Português, Français, Tiếng Việt) are present and rendered with Flexible ellipsis
      expect(find.text('Português'), findsWidgets);
      expect(find.text('Français'), findsWidgets);
      expect(find.text('Tiếng Việt'), findsWidgets);
      expect(tester.takeException(), isNull);

      // Close dropdown
      await tester.tap(find.text('Português').last);
      await tester.pumpAndSettle();
      expect(localeProvider.currentLanguageCode, 'pt');
      expect(tester.takeException(), isNull);
    });
  });
}
