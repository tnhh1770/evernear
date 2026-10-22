import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:mobile/core/i18n/locale_provider.dart';
import 'package:mobile/core/i18n/app_localizations.dart';
import 'package:mobile/core/services/web_landing_launcher.dart';
import 'package:mobile/features/auth/login_screen.dart';
import 'package:mobile/features/auth/onboarding_screen.dart';
import 'package:mobile/features/auth/register_screen.dart';
import 'package:mobile/features/landing/landing_screen.dart';
import 'package:mobile/features/landing/site_i18n_controller.dart';
import 'package:mobile/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LocaleProvider localeProvider;

  void resetWebLandingOverrides() {
    WebLandingLauncher.debugIsWebOverride = null;
    WebLandingLauncher.debugExternalLaunchOverride = null;
    WebLandingLauncher.launchedExternalUris.clear();
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    AppLocalizations.globalLocaleCode = 'vi';
    localeProvider = LocaleProvider();
    await localeProvider.initialize();
    resetWebLandingOverrides();
  });

  tearDown(() {
    resetWebLandingOverrides();
  });

  Widget buildTestableWidget(SitePageType pageType, {Size size = const Size(1280, 800)}) {
    return MediaQuery(
      data: MediaQueryData(size: size),
      child: ChangeNotifierProvider<LocaleProvider>.value(
        value: localeProvider,
        child: MaterialApp(
          home: LandingScreen(page: pageType),
          routes: {
            '/privacy': (_) => const LandingScreen(page: SitePageType.privacy),
            '/terms': (_) => const LandingScreen(page: SitePageType.terms),
            '/delete-account': (_) => const LandingScreen(page: SitePageType.deleteAccount),
            '/login': (_) => const Scaffold(body: Text('Login Screen')),
            '/register': (_) => const Scaffold(body: Text('Register Screen')),
          },
        ),
      ),
    );
  }

  group('LandingScreen Smoke & Render Tests', () {
    testWidgets('renders LandingScreen on landing page without errors', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestableWidget(SitePageType.landing));
      await tester.pumpAndSettle();

      expect(find.byType(LandingScreen), findsOneWidget);
      expect(find.text('Evernear'), findsWidgets);
      // Hero CTA buttons
      expect(find.textContaining('Bắt đầu ngay'), findsWidgets);
      expect(find.textContaining('Tôi đã có tài khoản'), findsWidgets);

      // Verify no overflow errors
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders Privacy Policy page cleanly with Coral-Red accents and back button', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestableWidget(SitePageType.privacy));
      await tester.pumpAndSettle();

      expect(find.byType(LandingScreen), findsOneWidget);
      expect(find.text('Chính sách bảo mật'), findsWidgets);
      expect(find.text('Về trang chủ'), findsOneWidget);
      expect(find.textContaining('Privacy-by-Default'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders Terms of Service page cleanly with Coral-Red accents and back button', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestableWidget(SitePageType.terms));
      await tester.pumpAndSettle();

      expect(find.byType(LandingScreen), findsOneWidget);
      expect(find.text('Điều khoản dịch vụ'), findsWidgets);
      expect(find.text('Về trang chủ'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders Delete Account page cleanly with Coral-Red accents and back button', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestableWidget(SitePageType.deleteAccount));
      await tester.pumpAndSettle();

      expect(find.byType(LandingScreen), findsOneWidget);
      expect(find.text('Yêu cầu xoá tài khoản Evernear'), findsOneWidget);
      expect(find.text('Về trang chủ'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders LandingScreen responsively on mobile narrow viewport', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestableWidget(SitePageType.landing, size: const Size(390, 844)));
      await tester.pumpAndSettle();

      expect(find.byType(LandingScreen), findsOneWidget);
      expect(find.text('Evernear'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });

  group('Web vs Mobile App Landing Routing & External Launch', () {
    testWidgets('on Web (/): renders LandingScreen at root and navigates in-app when clicking landing link', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      WebLandingLauncher.debugIsWebOverride = true;
      WebLandingLauncher.debugExternalLaunchOverride = (uri, mode) async => true;

      await tester.pumpWidget(const EvernearApp());
      await tester.pumpAndSettle();

      // 1. Root '/' on Web is LandingScreen
      expect(find.byType(LandingScreen), findsOneWidget);
      expect(WebLandingLauncher.launchedExternalUris, isEmpty);

      // 2. Navigate to /login on Web, then click brand header -> goes back to LandingScreen in-app
      final nav = tester.state<NavigatorState>(find.byType(Navigator));
      nav.pushNamed('/login');
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);

      await tester.tap(find.byKey(const Key('login_back_to_landing_btn')));
      await tester.pumpAndSettle();

      expect(find.byType(LandingScreen), findsOneWidget);
      expect(WebLandingLauncher.launchedExternalUris, isEmpty);
    });

    testWidgets('on Mobile App: root (/) renders AuthGate (not LandingScreen) and clicking landing jumps to external web browser', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      WebLandingLauncher.debugIsWebOverride = false;
      LaunchMode? capturedMode;
      WebLandingLauncher.debugExternalLaunchOverride = (uri, mode) async {
        capturedMode = mode;
        return true;
      };

      await tester.pumpWidget(const EvernearApp());
      await tester.pumpAndSettle();

      // 1. Root '/' on Mobile App is AuthGate -> LoginScreen (NEVER LandingScreen)
      expect(find.byType(LandingScreen), findsNothing);
      expect(find.byType(AuthGate), findsOneWidget);
      expect(find.byType(LoginScreen), findsOneWidget);

      // 2. Clicking brand logo on LoginScreen launches external browser, never opens LandingScreen in-app
      await tester.tap(find.byKey(const Key('login_back_to_landing_btn')));
      await tester.pumpAndSettle();

      expect(find.byType(LandingScreen), findsNothing);
      expect(WebLandingLauncher.launchedExternalUris.length, 1);
      expect(capturedMode, LaunchMode.externalApplication);

      // 3. Navigate to /onboarding on Mobile App and click brand logo -> launches external browser
      final nav = tester.state<NavigatorState>(find.byType(Navigator));
      nav.pushNamed('/onboarding');
      await tester.pumpAndSettle();
      expect(find.byType(OnboardingScreen), findsOneWidget);

      await tester.tap(find.byKey(const Key('onboarding_landing_link')));
      await tester.pumpAndSettle();

      expect(find.byType(LandingScreen), findsNothing);
      expect(WebLandingLauncher.launchedExternalUris.length, 2);

      // 4. Navigate to /register on Mobile App and click brand logo -> launches external browser
      nav.pushNamed('/register');
      await tester.pumpAndSettle();
      expect(find.byType(RegisterScreen), findsOneWidget);

      await tester.tap(find.byKey(const Key('register_back_to_landing_btn')));
      await tester.pumpAndSettle();

      expect(find.byType(LandingScreen), findsNothing);
      expect(WebLandingLauncher.launchedExternalUris.length, 3);

      // 5. Navigating to '/landing' route on Mobile App redirects to external browser & never renders LandingScreen in-app
      nav.pushNamed('/landing');
      await tester.pumpAndSettle();

      expect(find.byType(LandingScreen), findsNothing);
      expect(WebLandingLauncher.launchedExternalUris.length, 4);
    });

    testWidgets('translates all landing copy AND phone screen UI dynamically when switching languages (vi, en, zh, ja, ko)', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1440, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestableWidget(SitePageType.landing, size: const Size(1440, 2400)));
      await tester.pumpAndSettle();

      // 1. Switch to Chinese (zh)
      await localeProvider.setLocale(const Locale('zh'));
      await tester.pumpAndSettle();

      // Verify Chinese landing copy AND Chinese inside real phone screens
      expect(find.textContaining('双重角色'), findsWidgets);
      expect(find.textContaining('我很好'), findsWidgets);
      expect(find.textContaining('妈妈 (林淑芬)'), findsWidgets);
      expect(find.textContaining('家庭成员'), findsWidgets);
      // Verify zero leftover Vietnamese strings
      expect(find.text('Hai vai trò'), findsNothing);
      expect(find.text('Tôi vẫn ổn'), findsNothing);
      expect(find.text('Danh sách người thân'), findsNothing);
      expect(tester.takeException(), isNull);

      // 2. Switch to English (en)
      await localeProvider.setLocale(const Locale('en'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Two Roles'), findsWidgets);
      expect(find.textContaining('I am OK'), findsWidgets);
      expect(find.textContaining('Mom (Nguyen Thi Mai)'), findsWidgets);
      expect(find.text('Hai vai trò'), findsNothing);
      expect(find.text('Tôi vẫn ổn'), findsNothing);
      expect(tester.takeException(), isNull);

      // 3. Switch back to Vietnamese (vi)
      await localeProvider.setLocale(const Locale('vi'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Hai vai trò'), findsWidgets);
      expect(find.textContaining('Tôi vẫn ổn'), findsWidgets);
      expect(find.textContaining('Danh sách người thân'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('sticky top header stays fixed at top when scrolling down and support@erai.vn is displayed', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestableWidget(SitePageType.landing));
      await tester.pumpAndSettle();

      // Verify support@erai.vn is present and support@evernear.app is absent
      expect(find.textContaining('support@erai.vn'), findsWidgets);
      expect(find.textContaining('support@evernear.app'), findsNothing);

      // Record header button Y position before scrolling
      final openAppBtn = find.text('Mở ứng dụng');
      expect(openAppBtn, findsOneWidget);
      final initialTopY = tester.getTopLeft(openAppBtn).dy;
      expect(initialTopY, lessThan(80));

      // Scroll down 1500 pixels on the main page scroll view
      final mainScroll = find.byType(Scrollable).first;
      await tester.drag(mainScroll, const Offset(0, -1500));
      await tester.pumpAndSettle();

      // Sticky header must remain at the exact same Y position at the top
      final afterScrollTopY = tester.getTopLeft(openAppBtn).dy;
      expect(afterScrollTopY, equals(initialTopY));
      expect(tester.takeException(), isNull);
    });

    testWidgets('header menu items scroll to sections and navigate between landing and legal pages properly', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestableWidget(SitePageType.landing, size: const Size(1280, 900)));
      await tester.pumpAndSettle();

      // Click 'Giao diện' in header -> scrolls down to #screens
      await tester.tap(find.text('Giao diện').first);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Click 'Quyền riêng tư' (i004) in header -> navigates to Privacy page
      await tester.tap(find.text('Quyền riêng tư').first);
      await tester.pumpAndSettle();
      expect(find.textContaining('Privacy-by-Default'), findsOneWidget);
      expect(find.textContaining('support@erai.vn'), findsWidgets);
      expect(tester.takeException(), isNull);

      // From Privacy page, click 'Tính năng' in header -> returns to Landing page and scrolls to #features
      await tester.tap(find.text('Tính năng').first);
      await tester.pumpAndSettle();
      expect(find.textContaining('Bắt đầu ngay'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('no layout overflow across verbose languages (ru, de, ta, ar) and narrow/medium/wide viewports', (WidgetTester tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.view.devicePixelRatio = 1.0;

      for (final size in [const Size(1366, 900), const Size(1024, 800), const Size(768, 900), const Size(360, 800)]) {
        tester.view.physicalSize = size;
        await tester.pumpWidget(buildTestableWidget(SitePageType.landing, size: size));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'Overflow at viewport $size in vi');

        for (final lang in ['ru', 'de', 'ta', 'ar']) {
          await localeProvider.setLocale(Locale(lang));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: 'Overflow at viewport $size in $lang');
        }
      }
    });

    testWidgets('caches active language dictionary in localStorage and loads on-demand from localStorage when available', (WidgetTester tester) async {
      final i18n = SiteI18nController.instance;
      SharedPreferences.setMockInitialValues({});
      i18n.clearMemoryCache();

      // 1. Initialize with default 'vi' -> only 'vi' is loaded and cached in localStorage
      final initFuture = i18n.ensureInitialized(localeProvider);
      await tester.pumpAndSettle();
      await initFuture;
      expect(i18n.currentCode, 'vi');
      expect(i18n.loadedLanguageCodes.toList(), ['vi']);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(SiteI18nController.langStorageKey), 'vi');
      expect(prefs.getString(SiteI18nController.dictStorageKey('vi')), isNotNull);
      expect(prefs.getString(SiteI18nController.dictStorageKey('fr')), isNull);

      // 2. Switch to 'fr' -> fetches 'fr' on demand and saves to localStorage
      final frFuture = i18n.selectLanguage('fr', localeProvider: localeProvider);
      await tester.pumpAndSettle();
      await frFuture;
      expect(i18n.currentCode, 'fr');
      expect(i18n.loadedLanguageCodes.contains('fr'), isTrue);
      expect(prefs.getString(SiteI18nController.langStorageKey), 'fr');
      expect(prefs.getString(SiteI18nController.dictStorageKey('fr')), isNotNull);

      // 3. Pre-populate custom 'ko' dictionary in localStorage, clear in-memory cache, and switch to 'ko'
      // Verify it loads directly from localStorage without fetching from assets
      await prefs.setString(
        SiteI18nController.dictStorageKey('ko'),
        jsonEncode({'i008': 'LOCAL_STORAGE_CACHED_KO_HEADLINE'}),
      );
      i18n.clearMemoryCache();
      final koFuture = i18n.selectLanguage('ko', localeProvider: localeProvider);
      await tester.pumpAndSettle();
      await koFuture;
      expect(i18n.currentCode, 'ko');
      expect(i18n.tr('i008', 'fallback'), 'LOCAL_STORAGE_CACHED_KO_HEADLINE');

      // Restore 'vi'
      final viFuture = i18n.selectLanguage('vi', localeProvider: localeProvider);
      await tester.pumpAndSettle();
      await viFuture;
    });
  });
}
