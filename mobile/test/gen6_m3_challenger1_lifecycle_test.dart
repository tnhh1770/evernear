import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mobile/core/i18n/app_localizations.dart';
import 'package:mobile/core/i18n/locale_catalog_registry.dart';
import 'package:mobile/core/i18n/locale_provider.dart';
import 'package:mobile/core/models/enums.dart';
import 'package:mobile/core/models/incident_model.dart';
import 'package:mobile/core/models/relationship_model.dart';
import 'package:mobile/core/models/user_model.dart';
import 'package:mobile/core/storage/local_storage.dart';
import 'package:mobile/features/auth/auth_provider.dart';
import 'package:mobile/features/auth/login_screen.dart';
import 'package:mobile/features/auth/onboarding_screen.dart';
import 'package:mobile/features/auth/register_screen.dart';
import 'package:mobile/features/dashboard/dashboard_provider.dart';
import 'package:mobile/features/dashboard/dashboard_screen.dart';
import 'package:mobile/features/incidents/incidents_provider.dart';
import 'package:mobile/features/settings/language_settings_screen.dart';

/// Comprehensive Mock Tracking AuthProvider for Empirical Adversarial Verification
class ChallengerMockAuthProvider extends AuthProvider {
  UserModel? _mockUser;
  bool _isAuth = false;
  String? registeredLanguage;
  String? lastUpdatedLanguage;
  int updateProfileCalls = 0;
  String? serverLanguageToReturnOnLogin;

  ChallengerMockAuthProvider({
    UserModel? initialUser,
    bool isAuthenticated = false,
    this.serverLanguageToReturnOnLogin = 'vi',
  }) {
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
    _mockUser = UserModel(
      id: 'usr-challenge-1',
      email: email,
      fullName: 'Challenger Test User',
      timezone: 'Asia/Ho_Chi_Minh',
      isActive: true,
      preferredLanguage: serverLanguageToReturnOnLogin,
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
      id: 'usr-registered-1',
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
    updateProfileCalls++;
    if (preferredLanguage != null) {
      lastUpdatedLanguage = preferredLanguage;
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

/// Mock Dashboard Provider for clean, offline-safe Dashboard verification
class ChallengerMockDashboardProvider extends DashboardProvider {
  final List<RelationshipModel> _mockRelationships;
  final MonitoringState _state;
  final DateTime? _lastActivity;

  ChallengerMockDashboardProvider({
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
}

/// Mock Incidents Provider for clean, offline-safe Dashboard verification
class ChallengerMockIncidentsProvider extends IncidentsProvider {
  final List<IncidentModel> _mockIncidents;
  final List<NotificationFeedItem> _mockNotifications;

  ChallengerMockIncidentsProvider({
    List<IncidentModel>? incidents,
    List<NotificationFeedItem>? notifications,
  })  : _mockIncidents = incidents ?? [],
        _mockNotifications = notifications ?? [];

  @override
  List<IncidentModel> get incidents => _mockIncidents;

  @override
  List<NotificationFeedItem> get allNotifications => _mockNotifications;

  @override
  bool get isLoading => false;

  @override
  String? get errorMessage => null;

  @override
  int get unreadCount => 0;

  @override
  bool get hasUnreadIncidents => false;

  @override
  Future<void> fetchIncidents() async {}

  @override
  Future<int> clearAllNotifications() async => 0;
}

/// Reactive Harness for testing dynamic locale rebuilds
Widget buildTestApp({
  required Widget child,
  required LocaleProvider localeProvider,
  required ChallengerMockAuthProvider authProvider,
  DashboardProvider? dashboardProvider,
  IncidentsProvider? incidentsProvider,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<LocaleProvider>.value(value: localeProvider),
      ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
      ChangeNotifierProvider<DashboardProvider>.value(
        value: dashboardProvider ?? ChallengerMockDashboardProvider(),
      ),
      ChangeNotifierProvider<IncidentsProvider>.value(
        value: incidentsProvider ?? ChallengerMockIncidentsProvider(),
      ),
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
            '/dashboard': (_) => const DashboardScreen(),
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
    AppLocalizations.globalLocaleCode = 'vi';
  });

  group('Challenger 1 Empirical Suite: Pre/Post-Auth Lifecycle Verification', () {
    // =========================================================================
    // 1. Selecting 'en' on LoginScreen updates LocaleProvider & persists to LocalStorage
    // =========================================================================
    testWidgets(
      '1.1 Selecting "en" on LoginScreen updates LocaleProvider and persists to SharedPreferences',
      (tester) async {
        final localeProvider = LocaleProvider();
        await localeProvider.initialize();
        final authProvider = ChallengerMockAuthProvider();

        await tester.pumpWidget(
          buildTestApp(
            child: const LoginScreen(),
            localeProvider: localeProvider,
            authProvider: authProvider,
          ),
        );
        await tester.pumpAndSettle();

        // Initial state must be Vietnamese default
        expect(localeProvider.currentLanguageCode, equals('vi'));
        expect(find.text('Chào mừng trở lại!'), findsOneWidget);
        expect(find.text('Welcome back!'), findsNothing);

        // Tap the language selector dropdown on LoginScreen
        final dropdownFinder = find.byKey(const Key('login_language_dropdown'));
        expect(dropdownFinder, findsOneWidget);
        await tester.tap(dropdownFinder);
        await tester.pumpAndSettle();

        // Select 'English'
        final englishOptionFinder = find.text('English').last;
        expect(englishOptionFinder, findsOneWidget);
        await tester.tap(englishOptionFinder);
        await tester.pumpAndSettle();

        // Empirical Verifications:
        // 1. LocaleProvider state updated to 'en'
        expect(localeProvider.currentLanguageCode, equals('en'));
        expect(localeProvider.isDeviceDefault, isFalse);

        // 2. Persisted to LocalStorage / SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString(LocaleProvider.prefKeyLocale), equals('en'));

        // 3. UI dynamically re-rendered in English
        expect(find.text('Welcome back!'), findsOneWidget);
        expect(find.text('Chào mừng trở lại!'), findsNothing);
      },
    );

    testWidgets(
      '1.2 Rapid multi-language switching on LoginScreen settles deterministically on "en"',
      (tester) async {
        final localeProvider = LocaleProvider();
        await localeProvider.initialize();
        final authProvider = ChallengerMockAuthProvider();

        await tester.pumpWidget(
          buildTestApp(
            child: const LoginScreen(),
            localeProvider: localeProvider,
            authProvider: authProvider,
          ),
        );
        await tester.pumpAndSettle();

        final dropdownFinder = find.byKey(const Key('login_language_dropdown'));

        // Rapid toggling between Vietnamese and English
        await tester.tap(dropdownFinder);
        await tester.pumpAndSettle();
        await tester.tap(find.text('English').last);
        await tester.pumpAndSettle();
        expect(localeProvider.currentLanguageCode, equals('en'));

        await tester.tap(dropdownFinder);
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Tiếng Việt').last);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Tiếng Việt').last);
        await tester.pumpAndSettle();
        expect(localeProvider.currentLanguageCode, equals('vi'));

        await tester.tap(dropdownFinder);
        await tester.pumpAndSettle();
        await tester.tap(find.text('English').last);
        await tester.pumpAndSettle();

        // Deterministic convergence on English
        expect(localeProvider.currentLanguageCode, equals('en'));
        expect(localeProvider.isDeviceDefault, isFalse);
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString(LocaleProvider.prefKeyLocale), equals('en'));
        expect(find.text('Welcome back!'), findsOneWidget);
      },
    );

    // =========================================================================
    // 2. Registering propagates 'en' into AuthProvider & persists into Onboarding/Dashboard
    // =========================================================================
    testWidgets(
      '2.1 Pre-auth "en" propagates into AuthProvider.register and persists into currentUser session',
      (tester) async {
        final localeProvider = LocaleProvider();
        await localeProvider.initialize();
        // Client selects English pre-auth
        await localeProvider.setLocale(const Locale('en'));
        expect(localeProvider.currentLanguageCode, equals('en'));

        final authProvider = ChallengerMockAuthProvider();

        await tester.pumpWidget(
          buildTestApp(
            child: const RegisterScreen(),
            localeProvider: localeProvider,
            authProvider: authProvider,
          ),
        );
        await tester.pumpAndSettle();

        // RegisterScreen opens in English
        expect(find.text('Create Account'), findsWidgets);

        // Fill registration form
        await tester.enterText(find.byType(TextFormField).at(0), 'John Doe');
        await tester.enterText(find.byType(TextFormField).at(1), 'john@carely.test');
        await tester.enterText(find.byType(TextFormField).at(2), '0912345678');
        await tester.enterText(find.byType(TextFormField).at(3), 'StrongPass123!');
        await tester.enterText(find.byType(TextFormField).at(4), 'StrongPass123!');

        // Tap register button
        await tester.tap(find.byType(ElevatedButton));
        await tester.pumpAndSettle();

        // Empirical Verifications:
        // 1. Registered language was explicitly passed as 'en'
        expect(authProvider.registeredLanguage, equals('en'));
        // 2. AuthProvider currentUser session has 'en'
        expect(authProvider.currentUser?.preferredLanguage, equals('en'));
        // 3. LocaleProvider remains 'en'
        expect(localeProvider.currentLanguageCode, equals('en'));
      },
    );

    testWidgets(
      '2.2 Changing language on RegisterScreen propagates new "en" into registration & session',
      (tester) async {
        final localeProvider = LocaleProvider();
        await localeProvider.initialize();
        // Starts on default Vietnamese
        expect(localeProvider.currentLanguageCode, equals('vi'));

        final authProvider = ChallengerMockAuthProvider();

        await tester.pumpWidget(
          buildTestApp(
            child: const RegisterScreen(),
            localeProvider: localeProvider,
            authProvider: authProvider,
          ),
        );
        await tester.pumpAndSettle();

        // Switch to English directly from RegisterScreen top capsule
        final regDropdown = find.byKey(const Key('register_language_dropdown'));
        expect(regDropdown, findsOneWidget);
        await tester.tap(regDropdown);
        await tester.pumpAndSettle();
        await tester.tap(find.text('English').last);
        await tester.pumpAndSettle();

        expect(localeProvider.currentLanguageCode, equals('en'));

        // Fill and submit form
        await tester.enterText(find.byType(TextFormField).at(0), 'Jane Smith');
        await tester.enterText(find.byType(TextFormField).at(1), 'jane@carely.test');
        await tester.enterText(find.byType(TextFormField).at(2), '0987654321');
        await tester.enterText(find.byType(TextFormField).at(3), 'SecurePass456!');
        await tester.enterText(find.byType(TextFormField).at(4), 'SecurePass456!');

        await tester.tap(find.byType(ElevatedButton));
        await tester.pumpAndSettle();

        // Verify propagation
        expect(authProvider.registeredLanguage, equals('en'));
        expect(authProvider.currentUser?.preferredLanguage, equals('en'));
        expect(localeProvider.currentLanguageCode, equals('en'));
      },
    );

    testWidgets(
      '2.3 OnboardingScreen and DashboardScreen render under "en" with zero reversion to "vi"',
      (tester) async {
        final localeProvider = LocaleProvider();
        await localeProvider.initialize();
        await localeProvider.setLocale(const Locale('en'));

        final authProvider = ChallengerMockAuthProvider(
          initialUser: UserModel(
            id: 'usr-en-1',
            email: 'en@carely.test',
            fullName: 'English User',
            timezone: 'Asia/Ho_Chi_Minh',
            isActive: true,
            preferredLanguage: 'en',
            createdAt: DateTime(2025, 1, 1),
          ),
          isAuthenticated: true,
        );

        // 1. Pump OnboardingScreen
        await tester.pumpWidget(
          buildTestApp(
            child: const OnboardingScreen(initialPage: 0, isPostRegistration: true),
            localeProvider: localeProvider,
            authProvider: authProvider,
          ),
        );
        await tester.pumpAndSettle();

        // Onboarding must render English and have onboarding_language_dropdown
        expect(find.byKey(const Key('onboarding_language_dropdown')), findsOneWidget);
        expect(localeProvider.currentLanguageCode, equals('en'));
        expect(find.text('Get Started'), findsOneWidget);

        // 2. Pump DashboardScreen
        await tester.pumpWidget(
          buildTestApp(
            child: const DashboardScreen(),
            localeProvider: localeProvider,
            authProvider: authProvider,
          ),
        );
        await tester.pumpAndSettle();

        // Dashboard must retain English state
        expect(localeProvider.currentLanguageCode, equals('en'));
        expect(authProvider.currentUser?.preferredLanguage, equals('en'));
      },
    );

    // =========================================================================
    // 3. Login does not overwrite client 'en' with server 'vi'
    // =========================================================================
    testWidgets(
      '3.1 Login Inversion Fix: Client chosen "en" overwrites server "vi" and calls backend sync',
      (tester) async {
        final localeProvider = LocaleProvider();
        await localeProvider.initialize();
        // Client explicitly chose 'en'
        await localeProvider.setLocale(const Locale('en'));
        expect(localeProvider.isDeviceDefault, isFalse);
        expect(localeProvider.currentLanguageCode, equals('en'));

        // Server user profile returns stale 'vi'
        final authProvider = ChallengerMockAuthProvider(
          serverLanguageToReturnOnLogin: 'vi',
        );

        await tester.pumpWidget(
          buildTestApp(
            child: const LoginScreen(),
            localeProvider: localeProvider,
            authProvider: authProvider,
          ),
        );
        await tester.pumpAndSettle();

        // Perform login
        await tester.enterText(find.byType(TextFormField).at(0), 'user@carely.test');
        await tester.enterText(find.byType(TextFormField).at(1), 'ValidPassword123!');
        await tester.tap(find.byType(ElevatedButton));
        await tester.pumpAndSettle();

        // Empirical Verifications:
        // 1. Client 'en' is authoritative: NOT overwritten by server 'vi'
        expect(localeProvider.currentLanguageCode, equals('en'));
        // 2. AuthProvider session was synced to 'en'
        expect(authProvider.currentUser?.preferredLanguage, equals('en'));
        expect(authProvider.lastUpdatedLanguage, equals('en'));
        // 3. Storage retains 'en'
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString(LocaleProvider.prefKeyLocale), equals('en'));
      },
    );

    testWidgets(
      '3.2 Stale server "vi" does not overwrite client "ja" or "de"',
      (tester) async {
        final localeProvider = LocaleProvider();
        await localeProvider.initialize();
        // Client explicitly chose Japanese ('ja')
        await localeProvider.setLocale(const Locale('ja'));
        expect(localeProvider.isDeviceDefault, isFalse);

        final authProvider = ChallengerMockAuthProvider(
          serverLanguageToReturnOnLogin: 'vi',
        );

        await tester.pumpWidget(
          buildTestApp(
            child: const LoginScreen(),
            localeProvider: localeProvider,
            authProvider: authProvider,
          ),
        );
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextFormField).at(0), 'ja_user@carely.test');
        await tester.enterText(find.byType(TextFormField).at(1), 'ValidPassword123!');
        await tester.tap(find.byType(ElevatedButton));
        await tester.pumpAndSettle();

        // Client 'ja' survives login against server 'vi'
        expect(localeProvider.currentLanguageCode, equals('ja'));
        expect(authProvider.currentUser?.preferredLanguage, equals('ja'));
      },
    );

    testWidgets(
      '3.3 Server profile with null or empty language does not crash and preserves client "en"',
      (tester) async {
        final localeProvider = LocaleProvider();
        await localeProvider.initialize();
        await localeProvider.setLocale(const Locale('en'));

        // Server returns null preferredLanguage
        final authProvider = ChallengerMockAuthProvider(
          serverLanguageToReturnOnLogin: null,
        );

        await tester.pumpWidget(
          buildTestApp(
            child: const LoginScreen(),
            localeProvider: localeProvider,
            authProvider: authProvider,
          ),
        );
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextFormField).at(0), 'null_lang@carely.test');
        await tester.enterText(find.byType(TextFormField).at(1), 'ValidPassword123!');
        await tester.tap(find.byType(ElevatedButton));
        await tester.pumpAndSettle();

        // Client 'en' survives safely
        expect(localeProvider.currentLanguageCode, equals('en'));
        expect(authProvider.currentUser?.preferredLanguage, equals('en'));
      },
    );

    testWidgets(
      '3.4 Auto-detect mode adopts server language preference on login',
      (tester) async {
        final localeProvider = LocaleProvider();
        await localeProvider.initialize();
        // User has NOT explicitly chosen a language (isDeviceDefault is true)
        expect(localeProvider.isDeviceDefault, isTrue);

        final authProvider = ChallengerMockAuthProvider(
          serverLanguageToReturnOnLogin: 'fr',
        );

        await tester.pumpWidget(
          buildTestApp(
            child: const LoginScreen(),
            localeProvider: localeProvider,
            authProvider: authProvider,
          ),
        );
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextFormField).at(0), 'fr_user@carely.test');
        await tester.enterText(find.byType(TextFormField).at(1), 'ValidPassword123!');
        await tester.tap(find.byType(ElevatedButton));
        await tester.pumpAndSettle();

        // Auto-detect safely adopts French from profile
        expect(localeProvider.currentLanguageCode, equals('fr'));
      },
    );

    // =========================================================================
    // 4. Settings language change survives logout
    // =========================================================================
    testWidgets(
      '4.1 Settings language change to "en" updates all layers and survives authProvider.logout()',
      (tester) async {
        final localeProvider = LocaleProvider();
        await localeProvider.initialize();

        final authProvider = ChallengerMockAuthProvider(
          initialUser: UserModel(
            id: 'usr-settings-1',
            email: 'settings@carely.test',
            fullName: 'Settings User',
            timezone: 'Asia/Ho_Chi_Minh',
            isActive: true,
            preferredLanguage: 'vi',
            createdAt: DateTime(2025, 1, 1),
          ),
          isAuthenticated: true,
        );

        await tester.pumpWidget(
          buildTestApp(
            child: const LanguageSettingsScreen(),
            localeProvider: localeProvider,
            authProvider: authProvider,
          ),
        );
        await tester.pumpAndSettle();

        // Select 'English' in LanguageSettingsScreen
        await tester.enterText(find.byType(TextField), 'English');
        await tester.pumpAndSettle();
        await tester.tap(find.text('English').last);
        await tester.pumpAndSettle();

        // Verify updates pre-logout
        expect(localeProvider.currentLanguageCode, equals('en'));
        expect(authProvider.currentUser?.preferredLanguage, equals('en'));
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString(LocaleProvider.prefKeyLocale), equals('en'));

        // Perform logout
        await authProvider.logout();

        // Verify auth state is cleared
        expect(authProvider.isAuthenticated, isFalse);
        expect(authProvider.currentUser, isNull);

        // Empirical Verifications:
        // 1. Language survives logout in LocaleProvider
        expect(localeProvider.currentLanguageCode, equals('en'));
        // 2. Language survives logout in SharedPreferences
        expect(prefs.getString(LocaleProvider.prefKeyLocale), equals('en'));
      },
    );

    testWidgets(
      '4.2 Post-logout LoginScreen retains "en" and subsequent login by user with "vi" does NOT overwrite',
      (tester) async {
        final localeProvider = LocaleProvider();
        await localeProvider.initialize();

        final authProvider = ChallengerMockAuthProvider(
          initialUser: UserModel(
            id: 'usr-first-1',
            email: 'first@carely.test',
            fullName: 'First User',
            timezone: 'Asia/Ho_Chi_Minh',
            isActive: true,
            preferredLanguage: 'vi',
            createdAt: DateTime(2025, 1, 1),
          ),
          isAuthenticated: true,
        );

        // Change language to 'en' in settings
        await localeProvider.setLocale(const Locale('en'), authProvider: authProvider);
        expect(localeProvider.currentLanguageCode, equals('en'));

        // Logout
        await authProvider.logout();
        expect(authProvider.isAuthenticated, isFalse);
        expect(localeProvider.currentLanguageCode, equals('en'));

        // Pump LoginScreen post-logout
        await tester.pumpWidget(
          buildTestApp(
            child: const LoginScreen(),
            localeProvider: localeProvider,
            authProvider: authProvider,
          ),
        );
        await tester.pumpAndSettle();

        // LoginScreen displays in English
        expect(find.text('Welcome back!'), findsOneWidget);

        // Second user with server 'vi' logs in
        authProvider.serverLanguageToReturnOnLogin = 'vi';
        await tester.enterText(find.byType(TextFormField).at(0), 'second@carely.test');
        await tester.enterText(find.byType(TextFormField).at(1), 'ValidPassword123!');
        await tester.tap(find.byType(ElevatedButton));
        await tester.pumpAndSettle();

        // Crucial lifecycle invariant: Client 'en' survived logout AND survived second user login!
        expect(localeProvider.currentLanguageCode, equals('en'));
        expect(authProvider.currentUser?.preferredLanguage, equals('en'));
        expect(authProvider.lastUpdatedLanguage, equals('en'));
      },
    );
  });
}
