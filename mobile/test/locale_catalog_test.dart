import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/i18n/locale_catalog_registry.dart';
import 'package:mobile/core/i18n/app_localizations.dart';
import 'package:mobile/core/i18n/catalogs/catalogs.dart';

void main() {
  group('LocaleCatalogRegistry Unit Tests', () {
    test('Registry contains 50+ world languages', () {
      expect(LocaleCatalogRegistry.allLanguages.length, greaterThanOrEqualTo(50));
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
      final res = AppLocalizations.staticTr('check_in_button');
      expect(res, 'Tôi vẫn ổn');
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
