import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'core/constants/app_colors.dart';
import 'core/constants/app_strings.dart';
import 'core/i18n/app_localizations.dart';
import 'core/i18n/locale_catalog_registry.dart';
import 'core/i18n/locale_provider.dart';
import 'core/services/background_service.dart';
import 'core/services/fcm_service.dart';
import 'core/services/navigation_service.dart';
import 'core/services/permission_service.dart';
import 'core/services/sync_queue_service.dart';
import 'features/auth/auth_provider.dart';
import 'features/auth/login_screen.dart';
import 'features/dashboard/dashboard_provider.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'features/incidents/incidents_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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

  runApp(const CarelyApp());
}

class CarelyApp extends StatelessWidget {
  const CarelyApp({super.key});

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
            title: AppStrings.appName,
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
                surface: AppColors.surface,
              ),
              scaffoldBackgroundColor: AppColors.background,
              appBarTheme: const AppBarTheme(
                backgroundColor: AppColors.surface,
                foregroundColor: AppColors.textPrimary,
                elevation: 0,
                centerTitle: false,
              ),
            ),
            home: const AuthGate(),
          );
        },
      ),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

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
              Icon(Icons.shield_outlined, size: 64, color: AppColors.primary),
              SizedBox(height: 16),
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
