import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:mobile/core/i18n/app_localizations.dart';
import 'package:mobile/core/i18n/locale_catalog_registry.dart';
import 'package:mobile/core/i18n/locale_provider.dart';
import 'package:mobile/core/i18n/catalogs/catalogs.dart';
import 'package:mobile/features/settings/language_settings_screen.dart';
import 'package:mobile/features/settings/settings_screen.dart';
import 'package:mobile/features/auth/auth_provider.dart';
import 'package:mobile/features/dashboard/dashboard_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Ext-M1 Challenger: Adversarial Localization Fallback Engine Stress Tests', () {
    test('1.1 Unsupported language code falls back to English then Vietnamese', () {
      final unsupportedCodes = ['klingon', 'xx', 'xyz99', '123', 'eo', 'valyrian'];
      for (final code in unsupportedCodes) {
        final l10n = AppLocalizations(Locale(code));
        expect(l10n.tr('check_in_button'), 'I am okay',
            reason: 'Locale $code should fall back to English check_in_button');
        expect(l10n.tr('app_name'), 'Carely',
            reason: 'Locale $code should resolve app_name');
      }
    });

    test('1.2 Undetermined language code Locale("und") resolves safely without crash', () {
      final l10n = AppLocalizations(const Locale('und'));
      expect(l10n.tr('check_in_button'), 'I am okay');
      expect(l10n.tr('nav_settings'), 'Settings');
    });

    test('1.3 Tier-2 language (e.g. Icelandic, Polish, Turkish) falls back cleanly', () {
      final tier2Codes = ['is', 'pl', 'tr', 'it', 'nl', 'sv', 'cs', 'el'];
      for (final code in tier2Codes) {
        final l10n = AppLocalizations(Locale(code));
        expect(l10n.tr('check_in_button'), 'I am okay');
        expect(l10n.tr('check_in_title'), 'Safety Check-in');
      }
    });

    test('1.4 Missing key produces Title Case formatting with ZERO raw keys or brackets', () {
      final l10n = AppLocalizations(const Locale('vi'));
      final missingKeys = [
        'untranslated_custom_feature_key',
        'auth.unknown_oauth_provider.button',
        'emergency_alert_secondary_v2',
        'device-battery-critical-warning',
        'some_deep_nested_action_name_here',
      ];

      for (final key in missingKeys) {
        final result = l10n.tr(key);
        expect(result, isNotEmpty);
        expect(result, isNot(contains('[')), reason: 'No opening bracket in $key -> $result');
        expect(result, isNot(contains(']')), reason: 'No closing bracket in $key -> $result');
        expect(result, isNot(contains('_')), reason: 'Underscores humanized in $key -> $result');
      }

      expect(l10n.tr('untranslated_custom_feature_key'), 'Untranslated Custom Feature Key');
      expect(l10n.tr('auth.unknown_oauth_provider.button'), 'Auth Unknown Oauth Provider Button');
      expect(l10n.tr('device-battery-critical-warning'), 'Device Battery Critical Warning');
    });

    test('1.5 Edge case keys: empty, spaces, punctuation, symbols', () {
      final l10n = AppLocalizations(const Locale('en'));
      expect(l10n.tr(''), '');
      expect(l10n.tr('   '), '   ');
      expect(l10n.tr('---'), '---');
      expect(l10n.tr('___'), '___');
    });

    test('1.6 Interpolation placeholders replaced cleanly, missing args handled without crash', () {
      final l10n = AppLocalizations(const Locale('en'));

      // Normal replacement
      expect(
        l10n.tr('check_in_battery_current', args: {'level': '77'}),
        'Current battery level: 77%',
      );

      // Multiple or unused args
      expect(
        l10n.tr('check_in_battery_current', args: {'level': '15', 'extra': 'ignored'}),
        'Current battery level: 15%',
      );

      // Missing placeholder in args leaves template intact without crashing
      expect(
        l10n.tr('check_in_battery_current', args: {'wrong_key': '15'}),
        'Current battery level: {level}%',
      );

      // Interpolation on untranslated formatted key
      expect(
        l10n.tr('hello_{user}_welcome', args: {'user': 'Alice'}),
        'Hello Alice Welcome',
      );
    });

    test('1.7 StaticTr works without BuildContext or delegate initialization', () {
      AppLocalizations.globalLocaleCode = 'vi';
      expect(AppLocalizations.staticTr('check_in_button'), 'Tôi vẫn ổn');

      AppLocalizations.globalLocaleCode = 'en';
      expect(AppLocalizations.staticTr('check_in_button'), 'I am okay');

      AppLocalizations.globalLocaleCode = 'ja';
      expect(AppLocalizations.staticTr('check_in_button'), '無事です');

      // StaticTr with invalid code falls back safely
      AppLocalizations.globalLocaleCode = 'invalid_locale_xyz';
      expect(AppLocalizations.staticTr('check_in_button'), 'I am okay');

      // Reset to vi
      AppLocalizations.globalLocaleCode = 'vi';
    });

    test('1.8 100% key parity across all 14 Tier-1 catalogs', () {
      final baseKeys = viCatalog.keys.toSet();
      expect(baseKeys.length, greaterThanOrEqualTo(50));

      final tier1 = ['vi', 'en', 'fr', 'de', 'es', 'pt', 'ru', 'ja', 'ko', 'zh', 'th', 'id', 'ar', 'hi'];
      for (final code in tier1) {
        final cat = DynamicCatalogs.getCatalog(code);
        expect(cat, isNotNull, reason: 'Catalog $code must exist');
        final diffFromVi = baseKeys.difference(cat!.keys.toSet());
        final extraKeys = cat.keys.toSet().difference(baseKeys);
        expect(diffFromVi, isEmpty, reason: 'Catalog $code missing keys: $diffFromVi');
        expect(extraKeys, isEmpty, reason: 'Catalog $code has extra keys: $extraKeys');
      }
    });
  });

  group('Ext-M1 Challenger: Diacritic & Query Search Stress Tests', () {
    test('2.1 Vietnamese complex tones and mixed case queries', () {
      final queries = [
        'tiếng việt',
        'TIẾNG VIỆT',
        'Tiếng Việt',
        'TiẾnG vIệT',
        'tieng viet',
        'TIENG VIET',
        'tieng',
        'viet',
      ];
      for (final q in queries) {
        final results = LocaleCatalogRegistry.search(q);
        expect(results.any((l) => l.code == 'vi'), isTrue,
            reason: 'Query "$q" must match Vietnamese (vi)');
      }
    });

    test('2.2 European umlauts, accents, and mixed case queries', () {
      // French
      for (final q in ['français', 'FRANÇAIS', 'francais', 'FRANCAIS', 'Français']) {
        final res = LocaleCatalogRegistry.search(q);
        expect(res.any((l) => l.code == 'fr'), isTrue, reason: 'French for "$q"');
      }

      // German
      for (final q in ['deutsch', 'DEUTSCH', 'Deutsch']) {
        final res = LocaleCatalogRegistry.search(q);
        expect(res.any((l) => l.code == 'de'), isTrue, reason: 'German for "$q"');
      }

      // Spanish
      for (final q in ['español', 'ESPAÑOL', 'espanol', 'ESPANOL', 'Español']) {
        final res = LocaleCatalogRegistry.search(q);
        expect(res.any((l) => l.code == 'es'), isTrue, reason: 'Spanish for "$q"');
      }

      // Portuguese
      for (final q in ['português', 'PORTUGUÊS', 'portugues', 'PORTUGUES', 'Português']) {
        final res = LocaleCatalogRegistry.search(q);
        expect(res.any((l) => l.code == 'pt'), isTrue, reason: 'Portuguese for "$q"');
      }

      // Turkish (Tier 2 with umlauts & cedilla)
      for (final q in ['türkçe', 'TÜRKÇE', 'turkce', 'TURKCE']) {
        final res = LocaleCatalogRegistry.search(q);
        expect(res.any((l) => l.code == 'tr'), isTrue, reason: 'Turkish for "$q"');
      }

      // Romanian (Tier 2 with circumflex & breve)
      for (final q in ['română', 'ROMÂNĂ', 'romana', 'ROMANA']) {
        final res = LocaleCatalogRegistry.search(q);
        expect(res.any((l) => l.code == 'ro'), isTrue, reason: 'Romanian for "$q"');
      }

      // Icelandic (Tier 2 with acute)
      for (final q in ['íslenska', 'ÍSLENSKA', 'islenska', 'ISLENSKA']) {
        final res = LocaleCatalogRegistry.search(q);
        expect(res.any((l) => l.code == 'is'), isTrue, reason: 'Icelandic for "$q"');
      }
    });

    test('2.3 Non-Latin native script queries match exactly', () {
      final scriptPairs = {
        'Русский': 'ru',
        'русский': 'ru',
        '日本語': 'ja',
        '한국어': 'ko',
        '简体中文': 'zh',
        'ไทย': 'th',
        'العربية': 'ar',
        'हिन्दी': 'hi',
        'עברית': 'he',
      };

      scriptPairs.forEach((query, expectedCode) {
        final res = LocaleCatalogRegistry.search(query);
        expect(res.any((l) => l.code == expectedCode), isTrue,
            reason: 'Script search "$query" should match $expectedCode');
      });
    });

    test('2.4 Query edge cases: regex meta-characters, empty strings, spaces', () {
      expect(LocaleCatalogRegistry.search('').length, 60);
      expect(LocaleCatalogRegistry.search('   ').length, 60);

      // Regex meta characters must NOT throw regex exceptions
      final metaQueries = [r'.*', r'[a-z]', r'(vi|en)', r'^vi$', r'vi?', r'vi+', r'vi$'];
      for (final q in metaQueries) {
        expect(() => LocaleCatalogRegistry.search(q), returnsNormally,
            reason: 'Regex special string "$q" must not throw');
      }

      // Unmatched query returns empty list
      expect(LocaleCatalogRegistry.search('zzznonexistentlocale999'), isEmpty);
    });

    test('2.5 Caron / ogonek diacritic handling assessment for Slavic/Baltic scripts', () {
      // In Czech 'Čeština', native search with čes/čeština matches
      expect(LocaleCatalogRegistry.search('Čeština').any((l) => l.code == 'cs'), isTrue);
      expect(LocaleCatalogRegistry.search('Czech').any((l) => l.code == 'cs'), isTrue);

      // In Slovak 'Slovenčina'
      expect(LocaleCatalogRegistry.search('Slovenčina').any((l) => l.code == 'sk'), isTrue);
      expect(LocaleCatalogRegistry.search('Slovak').any((l) => l.code == 'sk'), isTrue);

      // In Slovenian 'Slovenščina'
      expect(LocaleCatalogRegistry.search('Slovenian').any((l) => l.code == 'sl'), isTrue);
    });
  });

  group('Ext-M1 Challenger: Unwrapped Widget Test Safety', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('3.1 LanguageSettingsScreen renders cleanly when unwrapped (no LocaleProvider, no AuthProvider)', (tester) async {
      // Bare pump without providers should NOT throw ProviderNotFoundException
      await tester.pumpWidget(
        const MaterialApp(
          home: LanguageSettingsScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Cài đặt Ngôn ngữ / Language'), findsOneWidget);
      expect(find.text('Tự động theo thiết bị'), findsOneWidget);

      // Tapping tiles when unwrapped should be safe no-op
      await tester.tap(find.text('Tự động theo thiết bị'));
      await tester.pumpAndSettle();

      // Search field works when unwrapped
      await tester.enterText(find.byType(TextField), 'English');
      await tester.pumpAndSettle();

      expect(find.text('English'), findsWidgets);
      await tester.tap(find.text('English').first);
      await tester.pumpAndSettle();
      // No crashes
    });

    testWidgets('3.2 SettingsScreen renders cleanly when unwrapped without LocaleProvider', (tester) async {
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
      await tester.pumpAndSettle();

      expect(find.text('Ngôn ngữ / Language'), findsOneWidget);
      expect(find.text('Tiếng Việt (Tự động)'), findsOneWidget);
    });

    testWidgets('3.3 Bare widget context.tr works without localizationsDelegates or MaterialApp wrapping', (tester) async {
      String? textVal;

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Builder(
            builder: (ctx) {
              textVal = ctx.tr('check_in_button');
              return Text(textVal!);
            },
          ),
        ),
      );

      expect(textVal, 'Tôi vẫn ổn');
      expect(find.text('Tôi vẫn ổn'), findsOneWidget);
    });
  });

  group('Ext-M1 Challenger: Reactive Rebuild & Locale Switching Stress Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('4.1 Multi-language sequential switching triggers instant UI rebuilds across 6 languages', (tester) async {
      final localeProvider = LocaleProvider();
      await localeProvider.initialize();

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: localeProvider,
          child: Consumer<LocaleProvider>(
            builder: (context, provider, child) {
              return MaterialApp(
                locale: provider.currentLocale,
                supportedLocales: LocaleCatalogRegistry.supportedLocales,
                localizationsDelegates: const [
                  AppLocalizations.delegate,
                  GlobalMaterialLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate,
                ],
                home: Scaffold(
                  body: Builder(
                    builder: (ctx) {
                      return Column(
                        children: [
                          Text(ctx.tr('check_in_button'), key: const ValueKey('check_in_text')),
                          Text(provider.currentLanguageDisplayName, key: const ValueKey('lang_display')),
                        ],
                      );
                    },
                  ),
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Set initial to vi
      await localeProvider.setLocale(const Locale('vi'));
      await tester.pumpAndSettle();
      expect(find.text('Tôi vẫn ổn'), findsOneWidget);
      expect(localeProvider.currentLanguageDisplayName, 'Tiếng Việt');

      // Switch to English
      await localeProvider.setLocale(const Locale('en'));
      await tester.pumpAndSettle();
      expect(find.text('I am okay'), findsOneWidget);
      expect(localeProvider.currentLanguageDisplayName, 'English');

      // Switch to French
      await localeProvider.setLocale(const Locale('fr'));
      await tester.pumpAndSettle();
      expect(find.text('Je vais bien'), findsOneWidget);
      expect(localeProvider.currentLanguageDisplayName, 'Français');

      // Switch to Japanese
      await localeProvider.setLocale(const Locale('ja'));
      await tester.pumpAndSettle();
      expect(find.text('無事です'), findsOneWidget);
      expect(localeProvider.currentLanguageDisplayName, '日本語');

      // Switch to German
      await localeProvider.setLocale(const Locale('de'));
      await tester.pumpAndSettle();
      expect(find.text('Mir geht es gut'), findsOneWidget);
      expect(localeProvider.currentLanguageDisplayName, 'Deutsch');

      // Switch to Arabic (RTL Tier 1)
      await localeProvider.setLocale(const Locale('ar'));
      await tester.pumpAndSettle();
      expect(find.text('أنا بخير'), findsOneWidget);
      expect(localeProvider.currentLanguage.isRtl, isTrue);

      // Switch back to device locale
      await localeProvider.setDeviceLocale();
      await tester.pumpAndSettle();
      expect(localeProvider.isDeviceDefault, isTrue);
      expect(localeProvider.currentLanguageDisplayName, contains('Tự động'));
    });

    test('4.2 SharedPreferences persistence across lifecycle', () async {
      SharedPreferences.setMockInitialValues({});
      final provider1 = LocaleProvider();
      await provider1.initialize();

      await provider1.setLocale(const Locale('es'));
      expect(provider1.currentLocale.languageCode, 'es');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(LocaleProvider.prefKeyLocale), 'es');

      // Emulate fresh app restart with existing SharedPreferences
      final provider2 = LocaleProvider();
      await provider2.initialize();
      expect(provider2.currentLocale.languageCode, 'es');
      expect(provider2.isDeviceDefault, isFalse);
    });

    test('4.3 Attempting setLocale with unsupported code is safely ignored', () async {
      final provider = LocaleProvider();
      await provider.initialize();
      final beforeLocale = provider.currentLocale;

      await provider.setLocale(const Locale('klingon'));
      expect(provider.currentLocale, equals(beforeLocale),
          reason: 'Unsupported locale must not overwrite currentLocale');
    });
  });
}
