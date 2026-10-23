import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile/core/i18n/locale_provider.dart';
import 'package:mobile/core/i18n/locale_catalog_registry.dart';
import 'package:mobile/core/i18n/app_localizations.dart';
import 'package:mobile/features/settings/language_settings_screen.dart';
import 'package:mobile/features/settings/settings_screen.dart';
import 'package:mobile/features/auth/auth_provider.dart';
import 'package:mobile/features/dashboard/dashboard_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LocaleProvider Unit & State Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      AppLocalizations.globalLocaleCode = 'en';
    });

    test('LocaleProvider initializes with device locale when prefs is empty', () async {
      final provider = LocaleProvider();
      await provider.initialize();

      expect(provider.isInitialized, isTrue);
      expect(provider.isDeviceDefault, isTrue);
      expect(provider.currentLocale.languageCode, 'en');
      expect(LocaleCatalogRegistry.isSupported(provider.currentLocale.languageCode), isTrue);
    });

    test('LocaleProvider loads explicit saved locale (vi) from SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({
        LocaleProvider.prefKeyLocale: 'vi',
      });
      final provider = LocaleProvider();
      await provider.initialize();

      expect(provider.isInitialized, isTrue);
      expect(provider.currentLocale.languageCode, 'vi');
      expect(provider.isDeviceDefault, isFalse);
    });

    test('LocaleProvider setLocale updates currentLocale and writes to SharedPreferences', () async {
      final provider = LocaleProvider();
      await provider.initialize();

      bool notified = false;
      provider.addListener(() => notified = true);

      await provider.setLocale(const Locale('fr'));

      expect(provider.currentLocale.languageCode, 'fr');
      expect(provider.isDeviceDefault, isFalse);
      expect(notified, isTrue);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(LocaleProvider.prefKeyLocale), 'fr');
    });

    test('LocaleProvider setDeviceLocale sets auto and switches to device language', () async {
      final provider = LocaleProvider();
      await provider.initialize();
      await provider.setLocale(const Locale('ja'));
      expect(provider.isDeviceDefault, isFalse);

      await provider.setDeviceLocale();
      expect(provider.isDeviceDefault, isTrue);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(LocaleProvider.prefKeyLocale), 'auto');
    });

    test('LocaleProvider syncFromUserProfile updates locale from user backend profile', () async {
      final provider = LocaleProvider();
      await provider.initialize();

      await provider.syncFromUserProfile('de');
      expect(provider.currentLocale.languageCode, 'de');
      expect(provider.isDeviceDefault, isFalse);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(LocaleProvider.prefKeyLocale), 'de');
    });

    test('LocaleProvider syncFromUserProfile respects auto preference unless forced', () async {
      final provider = LocaleProvider();
      await provider.initialize();
      await provider.setDeviceLocale();
      expect(provider.isDeviceDefault, isTrue);

      // Should not override auto when force is false
      await provider.syncFromUserProfile('es', force: false);
      expect(provider.isDeviceDefault, isTrue);

      // Should override when forced
      await provider.syncFromUserProfile('es', force: true);
      expect(provider.currentLocale.languageCode, 'es');
      expect(provider.isDeviceDefault, isFalse);
    });

    test('LocaleProvider syncFromUserProfile gracefully handles invalid/unsupported codes', () async {
      final provider = LocaleProvider();
      await provider.initialize();
      await provider.setLocale(const Locale('vi'));

      await provider.syncFromUserProfile('invalid_code_xyz');
      expect(provider.currentLocale.languageCode, 'vi');

      await provider.syncFromUserProfile(null);
      expect(provider.currentLocale.languageCode, 'vi');
    });
  });

  group('LanguageSettingsScreen & SettingsScreen Widget Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      AppLocalizations.globalLocaleCode = 'en';
    });

    testWidgets('LanguageSettingsScreen renders search bar and filters languages', (tester) async {
      final localeProvider = LocaleProvider();
      await localeProvider.initialize();

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: localeProvider,
          child: const MaterialApp(
            home: LanguageSettingsScreen(),
          ),
        ),
      );

      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Language Settings'), findsOneWidget);
      expect(find.text('Automatic (System Default)'), findsOneWidget);

      // Search for French
      await tester.enterText(find.byType(TextField), 'français');
      await tester.pumpAndSettle();

      expect(find.text('Français'), findsOneWidget);

      // Tap on French
      await tester.tap(find.text('Français'));
      await tester.pumpAndSettle();

      expect(localeProvider.currentLocale.languageCode, 'fr');
    });

    testWidgets('Unwrapped test safety: SettingsScreen renders without LocaleProvider', (tester) async {
      // Pumping SettingsScreen without LocaleProvider should NOT throw ProviderNotFoundException
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => AuthProvider()),
            ChangeNotifierProvider(create: (_) => DashboardProvider()),
          ],
          child: const MaterialApp(
            home: SettingsScreen(),
          ),
        ),
      );

      expect(find.text('Settings & Account'), findsOneWidget);
      expect(find.text('Language'), findsOneWidget);
      expect(find.text('English (Auto)'), findsOneWidget);
    });

    testWidgets('Unwrapped test safety: context.tr falls back cleanly in bare widget', (tester) async {
      String resolved = '';

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) {
              resolved = ctx.tr('check_in_button');
              return Text(resolved);
            },
          ),
        ),
      );

      expect(resolved, 'I am okay');
      expect(find.text('I am okay'), findsOneWidget);
    });
  });
}
