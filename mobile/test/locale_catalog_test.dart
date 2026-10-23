import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/i18n/locale_catalog_registry.dart';
import 'package:mobile/core/i18n/app_localizations.dart';
import 'package:mobile/core/i18n/catalogs/catalogs.dart';
import 'package:mobile/core/widgets/country_flag_badge.dart';
import 'package:mobile/features/landing/site_i18n_controller.dart';

void main() {
  group('LocaleCatalogRegistry Unit Tests', () {
    test('Registry contains 50+ world languages', () {
      expect(LocaleCatalogRegistry.allLanguages.length, greaterThanOrEqualTo(50));
    });

    test('English is first and defaults to US English with US flag', () {
      final first = LocaleCatalogRegistry.allLanguages.first;
      expect(first.code, 'en');
      expect(first.nativeName, 'English');
      expect(first.englishName, 'English');
      expect(first.countryCode, 'US');
      expect(first.flagEmoji, '🇺🇸');

      final siteFirst = SiteI18nController.languages.first;
      expect(siteFirst.code, 'en');
      expect(siteFirst.englishName, 'English (US)');
      expect(siteFirst.country, 'US');
    });

    test('Every language has an accurate 2-letter ISO countryCode and flagEmoji', () {
      for (final lang in LocaleCatalogRegistry.allLanguages) {
        expect(lang.countryCode.length, 2,
            reason: 'Language ${lang.code} must have a 2-letter ISO countryCode');
        expect(lang.countryCode, equals(lang.countryCode.toUpperCase()));
        expect(lang.flagEmoji.isNotEmpty, isTrue);
      }
      expect(LocaleCatalogRegistry.getByCode('vi')!.countryCode, 'VN');
      expect(LocaleCatalogRegistry.getByCode('pt')!.countryCode, 'PT');
      expect(LocaleCatalogRegistry.getByCode('ar')!.countryCode, 'SA');
      expect(LocaleCatalogRegistry.getByCode('sw')!.countryCode, 'KE');
      expect(LocaleCatalogRegistry.getByCode('ca')!.countryCode, 'AD');
    });

    testWidgets('CountryFlagBadge renders cleanly for all 60 app languages and 36 site languages', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Wrap(
                children: [
                  for (final lang in LocaleCatalogRegistry.allLanguages)
                    CountryFlagBadge(
                      countryCode: lang.countryCode,
                    ),
                  for (final siteLang in SiteI18nController.languages)
                    CountryFlagBadge(
                      countryCode: siteLang.country,
                    ),
                ],
              ),
            ),
          ),
        ),
      );
      expect(find.byType(CountryFlagBadge),
          findsNWidgets(LocaleCatalogRegistry.allLanguages.length + SiteI18nController.languages.length));
    });

    test('Registry contains all 14 Tier-1 languages', () {
      const expectedTier1 = [
        'vi', 'en', 'fr', 'de', 'es', 'pt', 'ru',
        'ja', 'ko', 'zh', 'th', 'id', 'ar', 'hi'
      ];
      for (final code in expectedTier1) {
        final lang = LocaleCatalogRegistry.getByCode(code);
        expect(lang, isNotNull, reason: 'Language $code must be registered');
        expect(lang!.isTier1, isTrue, reason: 'Language $code must be Tier-1');
      }
    });

    test('Diacritic-insensitive search matches accents and plain characters', () {
      // Vietnamese search
      final vi1 = LocaleCatalogRegistry.search('tiếng việt');
      expect(vi1.any((l) => l.code == 'vi'), isTrue);

      final vi2 = LocaleCatalogRegistry.search('tieng viet');
      expect(vi2.any((l) => l.code == 'vi'), isTrue);

      // French search
      final fr1 = LocaleCatalogRegistry.search('français');
      expect(fr1.any((l) => l.code == 'fr'), isTrue);

      final fr2 = LocaleCatalogRegistry.search('francais');
      expect(fr2.any((l) => l.code == 'fr'), isTrue);

      // Spanish search
      final es1 = LocaleCatalogRegistry.search('español');
      expect(es1.any((l) => l.code == 'es'), isTrue);

      final es2 = LocaleCatalogRegistry.search('espanol');
      expect(es2.any((l) => l.code == 'es'), isTrue);

      // Code search
      final de = LocaleCatalogRegistry.search('de');
      expect(de.any((l) => l.code == 'de'), isTrue);
    });

    test('RTL flags are set accurately for Arabic, Hebrew, Persian, Urdu', () {
      expect(LocaleCatalogRegistry.getByCode('ar')!.isRtl, isTrue);
      expect(LocaleCatalogRegistry.getByCode('he')!.isRtl, isTrue);
      expect(LocaleCatalogRegistry.getByCode('fa')!.isRtl, isTrue);
      expect(LocaleCatalogRegistry.getByCode('ur')!.isRtl, isTrue);
      expect(LocaleCatalogRegistry.getByCode('en')!.isRtl, isFalse);
    });
  });

  group('Safe Fallback Engine Unit Tests', () {
    test('Tier 1 Catalog returns exact translations for active language', () {
      final l10nEn = AppLocalizations(const Locale('en'));
      expect(l10nEn.tr('check_in_button'), 'I am okay');

      final l10nVi = AppLocalizations(const Locale('vi'));
      expect(l10nVi.tr('check_in_button'), 'Tôi vẫn ổn');

      final l10nJa = AppLocalizations(const Locale('ja'));
      expect(l10nJa.tr('check_in_button'), '無事です');
    });

    test('Missing key in Tier 2 language falls back to English then Vietnamese', () {
      // Simulating an unbundled non-Tier 1 language fallback when extended catalogs are disabled
      AppLocalizations.enableExtendedCatalogs = false;
      addTearDown(() => AppLocalizations.enableExtendedCatalogs = true);
      final l10nIs = AppLocalizations(const Locale('is'));
      expect(l10nIs.tr('check_in_button'), 'I am okay');
    });

    test('Missing key entirely formats to Title Case with zero raw keys', () {
      final l10n = AppLocalizations(const Locale('en'));
      final missingResult = l10n.tr('untranslated_custom_feature_key');
      expect(missingResult, 'Untranslated Custom Feature Key');
      expect(missingResult, isNot(contains('[')));
      expect(missingResult, isNot(contains(']')));
    });

    test('String argument interpolation replaces placeholders cleanly', () {
      final l10n = AppLocalizations(const Locale('en'));
      final interpolated = l10n.tr(
        'check_in_battery_current',
        args: {'level': '95'},
      );
      expect(interpolated, 'Current battery level: 95%');
    });

    test('Static fallback works cleanly without context or provider', () {
      AppLocalizations.globalLocaleCode = 'en';
      final res = AppLocalizations.staticTr('check_in_button');
      expect(res, 'I am okay');
    });

    test('All 14 Tier-1 catalogs contain identical key coverage', () {
      const tier1Codes = [
        'vi', 'en', 'fr', 'de', 'es', 'pt', 'ru',
        'ja', 'ko', 'zh', 'th', 'id', 'ar', 'hi'
      ];
      final viKeys = viCatalog.keys.toSet();

      for (final code in tier1Codes) {
        final catalog = DynamicCatalogs.getCatalog(code);
        expect(catalog, isNotNull, reason: 'Catalog $code must exist');
        expect(catalog!.keys.toSet(), equals(viKeys),
            reason: 'Catalog $code must match viCatalog key set exactly');
      }
    });
  });
}
