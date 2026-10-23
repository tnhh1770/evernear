import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mobile/core/i18n/app_localizations.dart';
import 'package:mobile/core/i18n/locale_catalog_registry.dart';
import 'package:mobile/core/i18n/locale_provider.dart';
import 'package:mobile/core/models/user_model.dart';
import 'package:mobile/core/storage/local_storage.dart';
import 'package:mobile/features/auth/auth_provider.dart';
import 'package:mobile/features/auth/login_screen.dart';
import 'package:mobile/features/auth/onboarding_screen.dart';
import 'package:mobile/features/auth/register_screen.dart';
import 'package:mobile/features/dashboard/dashboard_provider.dart';
import 'package:mobile/features/incidents/incidents_provider.dart';
import 'package:mobile/features/settings/language_settings_screen.dart';

/// Test AuthProvider tracking calls for registration, login, and profile updates.
class TrackingAuthProvider extends AuthProvider {
  UserModel? _mockUser;
  bool _isAuth = false;
  String? registeredLanguage;
  String? lastUpdatedLanguage;
  bool patchProfileCalled = false;

  TrackingAuthProvider({UserModel? initialUser, bool isAuthenticated = false}) {
    _mockUser = initialUser;
    _isAuth = isAuthenticated;
  }

  @override
  bool get isAuthenticated => _isAuth;

  @override
  UserModel? get currentUser => _mockUser;

  void setMockUser(UserModel? user, {bool authenticated = true}) {
    _mockUser = user;
    _isAuth = authenticated;
    notifyListeners();
  }

  @override
  Future<bool> login(String email, String password) async {
    _isAuth = true;
    _mockUser ??= UserModel(
      id: 'test-user-1',
      email: email,
      fullName: 'Test User',
      timezone: 'Asia/Ho_Chi_Minh',
      isActive: true,
      preferredLanguage: 'vi', // Server returns stale 'vi'
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
    registeredLanguage = preferredLanguage;
    _isAuth = true;
    _mockUser = UserModel(
      id: 'new-user-1',
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
    if (_mockUser != null) {
      _mockUser = _mockUser!.copyWith(preferredLanguage: langCode);
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
      lastUpdatedLanguage = preferredLanguage;
      patchProfileCalled = true;
      if (_mockUser != null) {
        _mockUser = _mockUser!.copyWith(preferredLanguage: preferredLanguage);
      }
    }
    notifyListeners();
    return true;
  }

  @override
  Future<void> logout({
    dynamic dashboardProvider,
    dynamic incidentsProvider,
  }) async {
    await LocalStorage.clearAuth();
    _mockUser = null;
    _isAuth = false;
    notifyListeners();
  }
}

/// Helper that wraps the screen with reactive `Consumer<LocaleProvider>`
Widget buildReactiveTestApp({
  required Widget child,
  required LocaleProvider localeProvider,
  required TrackingAuthProvider authProvider,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<LocaleProvider>.value(value: localeProvider),
      ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
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
          home: child,
          routes: {
            '/dashboard': (_) => const Scaffold(body: Text('DashboardScreen')),
            '/login': (_) => const LoginScreen(),
            '/register': (_) => const RegisterScreen(),
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
    AppLocalizations.globalLocaleCode = 'en';
  });

  group('Pre-Auth & Post-Auth Language Synchronization (R2) Lifecycle Tests', () {
    testWidgets('Flow (a): LanguageSelector exists and switches language pre-auth across screens', (tester) async {
      final localeProvider = LocaleProvider();
      await localeProvider.initialize();
      final authProvider = TrackingAuthProvider();

      // 1. Pump LoginScreen
      await tester.pumpWidget(
        buildReactiveTestApp(
          child: const LoginScreen(),
          localeProvider: localeProvider,
          authProvider: authProvider,
        ),
      );
      await tester.pumpAndSettle();

      // Both backwards-compatible key and universal preauth key must exist
      expect(find.byKey(const Key('login_language_dropdown')), findsOneWidget);
      expect(find.byKey(const Key('preauth_language_selector')), findsOneWidget);

      // Initially in US English ('en')
      expect(localeProvider.currentLanguageCode, 'en');
      expect(find.text('Welcome back!'), findsOneWidget);

      // Change language to Vietnamese via dropdown
      await tester.tap(find.byKey(const Key('login_language_dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tiếng Việt').last);
      await tester.pumpAndSettle();

      // Verify immediate locale update and persistence
      expect(localeProvider.currentLanguageCode, 'vi');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(LocaleProvider.prefKeyLocale), 'vi');
      expect(find.text('Chào mừng trở lại!'), findsOneWidget);

      // 2. Navigate to RegisterScreen - should open directly in selected language ('vi')
      await tester.pumpWidget(
        buildReactiveTestApp(
          child: const RegisterScreen(),
          localeProvider: localeProvider,
          authProvider: authProvider,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('register_language_dropdown')), findsOneWidget);
      expect(find.byKey(const Key('preauth_language_selector')), findsOneWidget);
      expect(find.text('Đăng ký tài khoản'), findsWidgets);

      // 3. Navigate to OnboardingScreen - should render with LanguageSelector
      await tester.pumpWidget(
        buildReactiveTestApp(
          child: const OnboardingScreen(initialPage: 0),
          localeProvider: localeProvider,
          authProvider: authProvider,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('onboarding_language_dropdown')), findsOneWidget);
      expect(find.byKey(const Key('preauth_language_selector')), findsOneWidget);
    });

    testWidgets('Flow (b): Registration passes preferredLanguage and preserves it into session', (tester) async {
      final localeProvider = LocaleProvider();
      await localeProvider.initialize();
      final authProvider = TrackingAuthProvider();

      // Explicitly set language to Japanese ('ja') pre-auth
      await localeProvider.setLocale(const Locale('ja'));
      expect(localeProvider.currentLanguageCode, 'ja');

      await tester.pumpWidget(
        buildReactiveTestApp(
          child: const RegisterScreen(),
          localeProvider: localeProvider,
          authProvider: authProvider,
        ),
      );
      await tester.pumpAndSettle();

      // Fill in registration form
      await tester.enterText(find.byType(TextFormField).at(0), 'Tanaka Taro');
      await tester.enterText(find.byType(TextFormField).at(1), 'tanaka@carely.vn');
      await tester.enterText(find.byType(TextFormField).at(2), '0901234567');
      await tester.enterText(find.byType(TextFormField).at(3), 'Password123!');
      await tester.enterText(find.byType(TextFormField).at(4), 'Password123!');

      // Tap submit button
      final submitFinder = find.byType(ElevatedButton);
      await tester.tap(submitFinder);
      await tester.pumpAndSettle();

      // Verify preferredLanguage was passed as 'ja' and preserved in currentUser
      expect(authProvider.registeredLanguage, 'ja');
      expect(authProvider.currentUser?.preferredLanguage, 'ja');
      expect(localeProvider.currentLanguageCode, 'ja');
    });

    testWidgets('Flow (c): Login Inversion Defect Fix: Client chosen locale is authoritative', (tester) async {
      final localeProvider = LocaleProvider();
      await localeProvider.initialize();
      // Server user profile has stale 'vi'
      final authProvider = TrackingAuthProvider(
        initialUser: UserModel(
          id: 'server-user-1',
          email: 'user@example.com',
          fullName: 'Server User',
          timezone: 'Asia/Ho_Chi_Minh',
          isActive: true,
          preferredLanguage: 'vi',
          createdAt: DateTime(2025, 1, 1),
        ),
      );

      // User explicitly selected English ('en') on LoginScreen pre-auth
      await localeProvider.setLocale(const Locale('en'));
      expect(localeProvider.isDeviceDefault, isFalse);
      expect(localeProvider.currentLanguageCode, 'en');

      await tester.pumpWidget(
        buildReactiveTestApp(
          child: const LoginScreen(),
          localeProvider: localeProvider,
          authProvider: authProvider,
        ),
      );
      await tester.pumpAndSettle();

      // Fill login credentials
      await tester.enterText(find.byType(TextFormField).at(0), 'user@example.com');
      await tester.enterText(find.byType(TextFormField).at(1), 'Secret123!');

      // Submit login
      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();

      // INVERSION FIX VERIFICATION:
      // The client's explicit 'en' must NOT be overwritten by the stale server 'vi'!
      expect(localeProvider.currentLanguageCode, 'en');
      // AuthProvider must be updated to 'en'
      expect(authProvider.lastUpdatedLanguage, 'en');
      expect(authProvider.currentUser?.preferredLanguage, 'en');
    });

    testWidgets('Flow (c) Alternate: When user is on default (English US), login preserves English US and does not switch to server language', (tester) async {
      final localeProvider = LocaleProvider();
      await localeProvider.initialize();
      // User has not changed language (isDeviceDefault == true, 'en')
      expect(localeProvider.isDeviceDefault, isTrue);
      expect(localeProvider.currentLanguageCode, 'en');

      final authProvider = TrackingAuthProvider(
        initialUser: UserModel(
          id: 'server-user-vi',
          email: 'viet@example.com',
          fullName: 'Viet User',
          timezone: 'Asia/Ho_Chi_Minh',
          isActive: true,
          preferredLanguage: 'vi',
          createdAt: DateTime(2025, 1, 1),
        ),
      );

      await tester.pumpWidget(
        buildReactiveTestApp(
          child: const LoginScreen(),
          localeProvider: localeProvider,
          authProvider: authProvider,
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).at(0), 'viet@example.com');
      await tester.enterText(find.byType(TextFormField).at(1), 'Secret123!');
      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();

      // Must remain in default US English ('en') and update profile to 'en'
      expect(localeProvider.currentLanguageCode, 'en');
      expect(authProvider.currentUser?.preferredLanguage, 'en');
    });

    testWidgets('Flow (d): Settings language change updates AuthProvider & LocalStorage, survives logout', (tester) async {
      final localeProvider = LocaleProvider();
      await localeProvider.initialize();
      final authProvider = TrackingAuthProvider(
        initialUser: UserModel(
          id: 'user-de',
          email: 'german@example.com',
          fullName: 'Hans',
          timezone: 'Asia/Ho_Chi_Minh',
          isActive: true,
          preferredLanguage: 'en',
          createdAt: DateTime(2025, 1, 1),
        ),
        isAuthenticated: true,
      );

      await tester.pumpWidget(
        buildReactiveTestApp(
          child: const LanguageSettingsScreen(),
          localeProvider: localeProvider,
          authProvider: authProvider,
        ),
      );
      await tester.pumpAndSettle();

      // Select German ('de') in LanguageSettingsScreen
      await tester.enterText(find.byType(TextField), 'Deutsch');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Deutsch').last);
      await tester.pumpAndSettle();

      // Verify updates
      expect(localeProvider.currentLanguageCode, 'de');
      expect(authProvider.currentUser?.preferredLanguage, 'de');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(LocaleProvider.prefKeyLocale), 'de');

      // Execute Logout
      await authProvider.logout();
      expect(authProvider.isAuthenticated, isFalse);
      expect(authProvider.currentUser, isNull);

      // Verify language survives logout
      expect(localeProvider.currentLanguageCode, 'de');
      expect(prefs.getString(LocaleProvider.prefKeyLocale), 'de');

      // Pumping LoginScreen after logout retains German
      await tester.pumpWidget(
        buildReactiveTestApp(
          child: const LoginScreen(),
          localeProvider: localeProvider,
          authProvider: authProvider,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Anmelden'), findsWidgets);
    });

    test('Task 6: LocaleProvider auto-detect initialization and display name localization', () async {
      // 1. Test when SharedPreferences has 'auto'
      SharedPreferences.setMockInitialValues({
        LocaleProvider.prefKeyLocale: 'auto',
      });
      final provider = LocaleProvider();
      await provider.initialize();
      expect(provider.isDeviceDefault, isTrue);
      expect(provider.isInitialized, isTrue);

      // 2. Test currentLanguageDisplayName is localized
      AppLocalizations.globalLocaleCode = 'vi';
      expect(provider.currentLanguageDisplayName, contains('Tự động'));

      AppLocalizations.globalLocaleCode = 'en';
      expect(provider.currentLanguageDisplayName, contains('Auto'));
    });
  });
}
