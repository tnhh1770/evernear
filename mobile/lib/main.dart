import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
// ignore: depend_on_referenced_packages
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:provider/provider.dart';
import 'core/constants/app_colors.dart';
import 'core/i18n/app_localizations.dart';
import 'core/i18n/locale_catalog_registry.dart';
import 'core/i18n/locale_provider.dart';
import 'core/services/background_service.dart';
import 'core/services/fcm_service.dart';
import 'core/services/navigation_service.dart';
import 'core/services/permission_service.dart';
import 'core/services/sync_queue_service.dart';
import 'core/services/web_landing_launcher.dart';
import 'core/widgets/evenear_illustrations.dart';
import 'features/auth/auth_provider.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/onboarding_screen.dart';
import 'features/auth/register_screen.dart';
import 'features/check_in/check_in_screen.dart';
import 'features/check_in/recent_activities_screen.dart';
import 'features/dashboard/dashboard_provider.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'features/devices/devices_screen.dart';
import 'features/incidents/incident_detail_screen.dart';
import 'features/incidents/incidents_list_screen.dart';
import 'features/incidents/incidents_provider.dart';
import 'features/landing/landing_screen.dart';
import 'features/monitoring/monitoring_settings_screen.dart';
import 'features/pairing/qr_invite_screen.dart';
import 'features/pairing/qr_scanner_screen.dart';
import 'features/settings/account_settings_screen.dart';
import 'features/settings/language_settings_screen.dart';
import 'features/settings/notification_settings_screen.dart';
import 'features/settings/privacy_security_screen.dart';
import 'features/settings/settings_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    usePathUrlStrategy();
  } catch (_) {}

  // Initialize background execution manager
  await BackgroundService().initialize();

  // Initialize Firebase Cloud Messaging & push channels
  await FcmService().initialize();

  // Setup notification tap handler to navigate to corresponding screen
  FcmService().onNotificationTapCallback = (data) {
    NavigationService.handleNotificationPayload(data);
  };

  // Start network listener for offline sync queue auto-flush
  SyncQueueService().startListeningToNetwork();

  // Request notification permission gracefully
  await PermissionService().requestNotificationPermission();

  runApp(const EvernearApp());
}

class EvernearApp extends StatelessWidget {
  const EvernearApp({super.key});

  static String _normalizeRoutePath(String rawPath) {
    if (rawPath.isEmpty) return '/';
    var clean = rawPath.trim();
    if (!clean.startsWith('/')) {
      clean = '/$clean';
    }
    if (clean.length > 1 && clean.endsWith('/')) {
      clean = clean.substring(0, clean.length - 1);
    }
    return clean;
  }

  static String _resolveInitialRoute() {
    final path = _normalizeRoutePath(Uri.base.path);
    final fragment = Uri.base.fragment.trim();
    final query = Uri.base.hasQuery ? '?${Uri.base.query}' : '';

    final candidate = (path != '/' && path.isNotEmpty)
        ? '$path$query'
        : (fragment.isNotEmpty ? _normalizeRoutePath(fragment) : '/');

    final uri = Uri.tryParse(candidate);
    final routePath = _normalizeRoutePath(uri?.path ?? '/');
    final routeQuery = (uri != null && uri.hasQuery) ? '?${uri.query}' : '';

    const supportedRoutes = {
      '/landing',
      '/onboarding',
      '/login',
      '/register',
      '/dashboard',
      '/check-in',
      '/activities',
      '/devices',
      '/monitoring-settings',
      '/incidents',
      '/incident',
      '/incident-detail',
      '/settings',
      '/profile',
      '/account',
      '/privacy-security',
      '/notifications',
      '/language',
      '/invite',
      '/qr-invite',
      '/scan',
      '/qr-scan',
      '/privacy',
      '/terms',
      '/delete-account',
    };

    if (supportedRoutes.contains(routePath)) {
      return '$routePath$routeQuery';
    }
    return '/';
  }

  static Route<dynamic> _buildRoute(RouteSettings settings) {
    final rawName = settings.name ?? '/';
    final uri = Uri.tryParse(rawName);
    final path = _normalizeRoutePath(uri?.path ?? rawName);
    final params = uri?.queryParameters ?? const <String, String>{};
    final isWeb = WebLandingLauncher.isWeb;

    switch (path) {
      case '/landing':
        if (isWeb) {
          return MaterialPageRoute(
            settings: const RouteSettings(name: '/landing'),
            builder: (_) => const LandingScreen(page: SitePageType.landing),
          );
        }
        WidgetsBinding.instance.addPostFrameCallback((_) {
          WebLandingLauncher.openExternalLanding('/');
        });
        return MaterialPageRoute(
          settings: const RouteSettings(name: '/'),
          builder: (_) => const AuthGate(),
        );
      case '/onboarding':
        final step = int.tryParse(params['step'] ?? params['page'] ?? '');
        return MaterialPageRoute(
          settings: RouteSettings(name: rawName, arguments: settings.arguments),
          builder: (_) => OnboardingScreen(initialPage: step ?? 0),
        );
      case '/login':
        return MaterialPageRoute(
          settings: const RouteSettings(name: '/login'),
          builder: (_) => const AuthGate(),
        );
      case '/register':
        return MaterialPageRoute(
          settings: const RouteSettings(name: '/register'),
          builder: (_) => const RegisterScreen(),
        );
      case '/dashboard':
        final tab = int.tryParse(params['tab'] ?? '');
        return MaterialPageRoute(
          settings: const RouteSettings(name: '/dashboard'),
          builder: (_) => AuthGate(initialTabIndex: tab),
        );
      case '/check-in':
        return MaterialPageRoute(
          settings: const RouteSettings(name: '/check-in'),
          builder: (_) => const CheckInScreen(),
        );
      case '/activities':
        return MaterialPageRoute(
          settings: const RouteSettings(name: '/activities'),
          builder: (_) => const RecentActivitiesScreen(showAppBar: true),
        );
      case '/devices':
        return MaterialPageRoute(
          settings: const RouteSettings(name: '/devices'),
          builder: (_) => const DevicesScreen(showAppBar: true),
        );
      case '/monitoring-settings':
        return MaterialPageRoute(
          settings: const RouteSettings(name: '/monitoring-settings'),
          builder: (_) => const MonitoringSettingsScreen(),
        );
      case '/incidents':
        return MaterialPageRoute(
          settings: const RouteSettings(name: '/incidents'),
          builder: (_) => const IncidentsListScreen(),
        );
      case '/incident':
      case '/incident-detail':
        final incId =
            params['id'] ??
            params['incidentId'] ??
            (settings.arguments is String
                ? settings.arguments as String
                : null);
        return MaterialPageRoute(
          settings: RouteSettings(name: rawName, arguments: settings.arguments),
          builder: (_) => IncidentDetailScreen(incidentId: incId),
        );
      case '/settings':
        return MaterialPageRoute(
          settings: const RouteSettings(name: '/settings'),
          builder: (_) => const SettingsScreen(),
        );
      case '/profile':
      case '/account':
        return MaterialPageRoute(
          settings: const RouteSettings(name: '/profile'),
          builder: (_) => const AccountSettingsScreen(),
        );
      case '/privacy-security':
        return MaterialPageRoute(
          settings: const RouteSettings(name: '/privacy-security'),
          builder: (_) => const PrivacySecurityScreen(),
        );
      case '/notifications':
        return MaterialPageRoute(
          settings: const RouteSettings(name: '/notifications'),
          builder: (_) => const NotificationSettingsScreen(),
        );
      case '/language':
        return MaterialPageRoute(
          settings: const RouteSettings(name: '/language'),
          builder: (_) => const LanguageSettingsScreen(),
        );
      case '/invite':
      case '/qr-invite':
        return MaterialPageRoute(
          settings: RouteSettings(name: rawName, arguments: settings.arguments),
          builder: (_) => QrInviteScreen(initialCode: params['code']),
        );
      case '/scan':
      case '/qr-scan':
        return MaterialPageRoute(
          settings: const RouteSettings(name: '/qr-scan'),
          builder: (_) => const QrScannerScreen(),
        );
      case '/privacy':
        return MaterialPageRoute(
          settings: const RouteSettings(name: '/privacy'),
          builder: (_) => isWeb
              ? const LandingScreen(page: SitePageType.privacy)
              : const PrivacySecurityScreen(),
        );
      case '/terms':
        return MaterialPageRoute(
          settings: const RouteSettings(name: '/terms'),
          builder: (_) => isWeb
              ? const LandingScreen(page: SitePageType.terms)
              : const PrivacySecurityScreen(),
        );
      case '/delete-account':
        return MaterialPageRoute(
          settings: const RouteSettings(name: '/delete-account'),
          builder: (_) => isWeb
              ? const LandingScreen(page: SitePageType.deleteAccount)
              : const AccountSettingsScreen(),
        );
      default:
        return MaterialPageRoute(
          settings: const RouteSettings(name: '/'),
          builder: (_) => isWeb
              ? const LandingScreen(page: SitePageType.landing)
              : const AuthGate(),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LocaleProvider()..initialize()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => DashboardProvider()),
        ChangeNotifierProvider(create: (_) => IncidentsProvider()),
      ],
      child: Consumer<LocaleProvider>(
        builder: (context, localeProvider, child) {
          return MaterialApp(
            navigatorKey: NavigationService.navigatorKey,
            onGenerateTitle: (ctx) => ctx.tr('app_name', fallback: 'Evenear'),
            title: 'Evenear',
            locale: localeProvider.currentLocale,
            supportedLocales: LocaleCatalogRegistry.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              useMaterial3: true,
              colorScheme: ColorScheme.fromSeed(
                seedColor: AppColors.primary,
                primary: AppColors.primary,
                secondary: AppColors.secondary,
                surface: Colors.white,
                error: AppColors.stateAlertTriggered,
              ),
              scaffoldBackgroundColor: AppColors.background,
              appBarTheme: const AppBarTheme(
                backgroundColor: AppColors.background,
                foregroundColor: AppColors.textPrimary,
                elevation: 0,
                scrolledUnderElevation: 0,
                centerTitle: false,
                titleTextStyle: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
                iconTheme: IconThemeData(color: AppColors.textPrimary),
              ),
              elevatedButtonTheme: ElevatedButtonThemeData(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: const StadiumBorder(),
                  elevation: 0,
                  shadowColor: AppColors.primary.withValues(alpha: 0.2),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              outlinedButtonTheme: OutlinedButtonThemeData(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  shape: const StadiumBorder(),
                  side: const BorderSide(color: AppColors.cardBorder, width: 1.2),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              textButtonTheme: TextButtonThemeData(
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  textStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              switchTheme: SwitchThemeData(
                thumbColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return Colors.white;
                  }
                  return AppColors.textMuted;
                }),
                trackColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return AppColors.primary;
                  }
                  return AppColors.cardBorder;
                }),
              ),
              inputDecorationTheme: InputDecorationTheme(
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.cardBorder, width: 1.0),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.cardBorder, width: 1.0),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.primary, width: 1.6),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.stateAlertTriggered, width: 1.4),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.stateAlertTriggered, width: 1.6),
                ),
                prefixIconColor: AppColors.textMuted,
                suffixIconColor: AppColors.textMuted,
                labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
                hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 14),
              ),
              cardTheme: CardThemeData(
                color: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: AppColors.cardBorder, width: 1.0),
                ),
                margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
              ),
              bottomNavigationBarTheme: const BottomNavigationBarThemeData(
                backgroundColor: Colors.white,
                selectedItemColor: AppColors.primary,
                unselectedItemColor: AppColors.textMuted,
                elevation: 8,
                type: BottomNavigationBarType.fixed,
              ),
              dividerTheme: const DividerThemeData(
                color: AppColors.divider,
                thickness: 1.0,
                space: 1.0,
              ),
            ),
            initialRoute: _resolveInitialRoute(),
            onGenerateInitialRoutes: (String initialRouteName) {
              final resolved = _resolveInitialRoute();
              final target = (initialRouteName != '/' && initialRouteName.isNotEmpty)
                  ? initialRouteName
                  : resolved;
              return [_buildRoute(RouteSettings(name: target))];
            },
            onGenerateRoute: _buildRoute,
          );
        },
      ),
    );
  }
}

class AuthGate extends StatefulWidget {
  final int? initialTabIndex;

  const AuthGate({super.key, this.initialTabIndex});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _checked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _checkAuth();
      }
    });
  }

  Future<void> _checkAuth() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final isAuth = await auth.checkAuthStatus();
    if (isAuth && mounted) {
      if (widget.initialTabIndex != null) {
        try {
          Provider.of<DashboardProvider>(
            context,
            listen: false,
          ).setSelectedTabIndex(widget.initialTabIndex!);
        } catch (_) {}
      }
      final preferredLang = auth.currentUser?.preferredLanguage;
      if (preferredLang != null && preferredLang.isNotEmpty) {
        try {
          final localeProvider = Provider.of<LocaleProvider>(context, listen: false);
          await localeProvider.syncFromUserProfile(preferredLang);
        } catch (_) {}
      }
    }
    if (mounted) setState(() => _checked = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_checked) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              EvenearHeartLogo(size: 68, showHalo: true),
              SizedBox(height: 20),
              CircularProgressIndicator(color: AppColors.primary),
            ],
          ),
        ),
      );
    }

    final auth = Provider.of<AuthProvider>(context);
    if (auth.isAuthenticated) {
      return const DashboardScreen();
    } else {
      return const LoginScreen();
    }
  }
}
