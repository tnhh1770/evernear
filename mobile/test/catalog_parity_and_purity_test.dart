import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/i18n/app_localizations.dart';
import 'package:mobile/core/i18n/catalogs/catalogs.dart';
import 'package:mobile/core/i18n/locale_catalog_registry.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Comprehensive Vietnamese diacritics regular expression (precomposed and decomposed combining marks)
  final vietnameseDiacriticsPattern = RegExp(
    r'[àáảãạăằắẳẵặâầấẩẫậđèéẻẽẹêềếểễệìíỉĩịòóỏõọôồốổỗộơờớởỡợùúủũụưừứửữựỳýỷỹỵ'
    r'ÀÁẢÃẠĂẰẮẲẴẶÂẦẤẨẪẬĐÈÉẺẸÊỀẾỂỄỆÌÍỈĨỊÒÓỎÕỌÔỒỐỔỖỘƠỜỚỞỠỢÙÚỦŨỤƯỪỨỬỮỰỲÝỶỸỴ'
    r'\u0300-\u036F]',
  );

  group('Canonical Suite 1: Catalog Parity, Purity & Fallback Leak Immunity', () {
    test('100% key parity between viCatalog and enCatalog (all 705 keys)', () {
      final viKeys = viCatalog.keys.toSet();
      final enKeys = enCatalog.keys.toSet();

      // Check key counts
      expect(
        viCatalog.length,
        equals(705),
        reason: 'viCatalog must contain exactly 705 keys, found ${viCatalog.length}',
      );
      expect(
        enCatalog.length,
        equals(705),
        reason: 'enCatalog must contain exactly 705 keys, found ${enCatalog.length}',
      );
      expect(
        viKeys.length,
        equals(705),
        reason: 'viCatalog keys set must contain exactly 705 unique keys',
      );
      expect(
        enKeys.length,
        equals(705),
        reason: 'enCatalog keys set must contain exactly 705 unique keys',
      );

      // Check set equality and differences
      final missingInEn = viKeys.difference(enKeys);
      final missingInVi = enKeys.difference(viKeys);

      expect(
        missingInEn,
        isEmpty,
        reason: 'All viCatalog keys must be present in enCatalog. Missing: $missingInEn',
      );
      expect(
        missingInVi,
        isEmpty,
        reason: 'All enCatalog keys must be present in viCatalog. Extra: $missingInVi',
      );
      expect(
        enKeys,
        equals(viKeys),
        reason: 'enCatalog and viCatalog key sets must be 100% identical',
      );
    });

    test('Source file duplicate key audit in vi_catalog.dart and en_catalog.dart', () {
      final viFile = File('lib/core/i18n/catalogs/vi_catalog.dart');
      final enFile = File('lib/core/i18n/catalogs/en_catalog.dart');

      expect(viFile.existsSync(), isTrue, reason: 'vi_catalog.dart must exist on disk');
      expect(enFile.existsSync(), isTrue, reason: 'en_catalog.dart must exist on disk');

      final keyRegex = RegExp(r"'([a-zA-Z0-9_.-]+)'\s*:");

      final viMatches = keyRegex.allMatches(viFile.readAsStringSync()).map((m) => m.group(1)!).toList();
      final enMatches = keyRegex.allMatches(enFile.readAsStringSync()).map((m) => m.group(1)!).toList();

      expect(
        viMatches.length,
        equals(705),
        reason: 'vi_catalog.dart syntax must contain exactly 705 key definitions (no duplicates)',
      );
      expect(
        enMatches.length,
        equals(705),
        reason: 'en_catalog.dart syntax must contain exactly 705 key definitions (no duplicates)',
      );
    });

    test('0 Vietnamese characters or diacritics in enCatalog (all 705 keys and values)', () {
      final keysWithVietnamese = <String>[];
      final valuesWithVietnamese = <String, String>{};

      for (final entry in enCatalog.entries) {
        if (vietnameseDiacriticsPattern.hasMatch(entry.key)) {
          keysWithVietnamese.add(entry.key);
        }
        if (vietnameseDiacriticsPattern.hasMatch(entry.value)) {
          valuesWithVietnamese[entry.key] = entry.value;
        }
      }

      expect(
        keysWithVietnamese,
        isEmpty,
        reason: 'enCatalog keys must not contain Vietnamese characters: $keysWithVietnamese',
      );
      expect(
        valuesWithVietnamese,
        isEmpty,
        reason: 'enCatalog values must not contain Vietnamese characters: $valuesWithVietnamese',
      );
    });

    test('Every key in enCatalog resolves non-empty English text in AppLocalizations', () {
      final l10n = AppLocalizations(const Locale('en'));
      final emptyResolutions = <String>[];
      final mismatchedResolutions = <String, String>{};
      final vietnameseLeakedInEn = <String, String>{};

      for (final key in enCatalog.keys) {
        final resolved = l10n.tr(key);

        if (resolved.trim().isEmpty) {
          emptyResolutions.add(key);
        }

        if (vietnameseDiacriticsPattern.hasMatch(resolved)) {
          vietnameseLeakedInEn[key] = resolved;
        }

        final expected = enCatalog[key]!;
        if (resolved != expected) {
          mismatchedResolutions[key] = 'Expected "$expected" but got "$resolved"';
        }
      }

      expect(
        emptyResolutions,
        isEmpty,
        reason: 'Every key in enCatalog must resolve non-empty string. Empty keys: $emptyResolutions',
      );
      expect(
        vietnameseLeakedInEn,
        isEmpty,
        reason: 'AppLocalizations(en) must never resolve Vietnamese characters: $vietnameseLeakedInEn',
      );
      expect(
        mismatchedResolutions,
        isEmpty,
        reason: 'AppLocalizations(en).tr(key) must exactly match enCatalog[key]: $mismatchedResolutions',
      );
    });

    test('StaticTr with English globalLocaleCode resolves all 705 keys to clean English text', () {
      AppLocalizations.globalLocaleCode = 'en';

      final emptyStaticResolutions = <String>[];
      final vietnameseInStatic = <String, String>{};

      for (final key in enCatalog.keys) {
        final resolved = AppLocalizations.staticTr(key);

        if (resolved.trim().isEmpty) {
          emptyStaticResolutions.add(key);
        }

        if (vietnameseDiacriticsPattern.hasMatch(resolved)) {
          vietnameseInStatic[key] = resolved;
        }
      }

      expect(
        emptyStaticResolutions,
        isEmpty,
        reason: 'AppLocalizations.staticTr with locale "en" must resolve non-empty strings',
      );
      expect(
        vietnameseInStatic,
        isEmpty,
        reason: 'AppLocalizations.staticTr with locale "en" must have 0 Vietnamese characters',
      );

      // Reset global locale back to default
      AppLocalizations.globalLocaleCode = 'vi';
    });

    test('DynamicCatalogs Tier-1 "en" catalog has exactly 705 entries matching enCatalog', () {
      final dynEn = DynamicCatalogs.getCatalog('en');
      expect(dynEn, isNotNull);
      expect(dynEn!.length, equals(705));
      expect(dynEn.keys.toSet(), equals(enCatalog.keys.toSet()));

      final dynAnyEn = DynamicCatalogs.getAnyCatalog('en');
      expect(dynAnyEn, isNotNull);
      expect(dynAnyEn!.length, equals(705));
    });

    test('Non-Vietnamese locales reject fallback Vietnamese parameters and never return viCatalog text', () {
      final l10nEn = AppLocalizations(const Locale('en'));
      final l10nJa = AppLocalizations(const Locale('ja'));
      final l10nDe = AppLocalizations(const Locale('de'));
      final l10nFr = AppLocalizations(const Locale('fr'));
      final l10nEs = AppLocalizations(const Locale('es'));

      const testMissingKey = 'non_existent_arbitrary_test_key';
      const vietnameseFallback = 'Đây là chuỗi tiếng Việt có dấu dự phòng';

      // 1. For non-existent key, non-Vietnamese locales must reject Vietnamese fallback parameter
      final enResult = l10nEn.tr(testMissingKey, fallback: vietnameseFallback);
      expect(enResult, isNot(contains(vietnameseFallback)));
      expect(vietnameseDiacriticsPattern.hasMatch(enResult), isFalse);
      expect(enResult, equals('Non Existent Arbitrary Test Key'));

      final jaResult = l10nJa.tr(testMissingKey, fallback: vietnameseFallback);
      expect(jaResult, isNot(contains(vietnameseFallback)));
      expect(vietnameseDiacriticsPattern.hasMatch(jaResult), isFalse);

      final deResult = l10nDe.tr(testMissingKey, fallback: vietnameseFallback);
      expect(deResult, isNot(contains(vietnameseFallback)));
      expect(vietnameseDiacriticsPattern.hasMatch(deResult), isFalse);

      final frResult = l10nFr.tr(testMissingKey, fallback: vietnameseFallback);
      expect(frResult, isNot(contains(vietnameseFallback)));
      expect(vietnameseDiacriticsPattern.hasMatch(frResult), isFalse);

      final esResult = l10nEs.tr(testMissingKey, fallback: vietnameseFallback);
      expect(esResult, isNot(contains(vietnameseFallback)));
      expect(vietnameseDiacriticsPattern.hasMatch(esResult), isFalse);

      // 2. But Vietnamese locale preserves Vietnamese fallback for missing key
      final l10nVi = AppLocalizations(const Locale('vi'));
      final viResult = l10nVi.tr(testMissingKey, fallback: vietnameseFallback);
      expect(viResult, equals(vietnameseFallback));

      // 3. For any key defined in catalogs, non-Vietnamese locales NEVER return viCatalog text
      for (final key in viCatalog.keys) {
        final viText = viCatalog[key]!;
        // Only test keys where Vietnamese text has diacritics
        if (vietnameseDiacriticsPattern.hasMatch(viText)) {
          final resolvedEn = l10nEn.tr(key, fallback: viText);
          expect(
            resolvedEn,
            isNot(equals(viText)),
            reason: 'Non-Vietnamese locale "en" leaked viCatalog text for key "$key"',
          );
          expect(
            vietnameseDiacriticsPattern.hasMatch(resolvedEn),
            isFalse,
            reason: 'Non-Vietnamese locale "en" resolved diacritics for key "$key": "$resolvedEn"',
          );
        }
      }
    });

    test('Interpolation placeholders test: all templated keys in enCatalog interpolate properly', () {
      final l10n = AppLocalizations(const Locale('en'));
      final placeholderRegex = RegExp(r'\{([a-zA-Z0-9_]+)\}');

      final sampleArgs = {
        'name': 'TestUser',
        'time': '12:00',
        'count': '3',
        'level': 'Critical',
        'platform': 'iOS',
        'interval': '15',
        'value': '80',
        'date': '2026-10-19',
        'error': 'Network timeout',
        'days': '7',
        'seconds': '30',
        'minutes': '15',
        'hours': '2',
      };

      for (final entry in enCatalog.entries) {
        if (placeholderRegex.hasMatch(entry.value)) {
          final interpolated = l10n.tr(entry.key, args: sampleArgs);
          expect(interpolated.trim().isNotEmpty, isTrue);
          expect(vietnameseDiacriticsPattern.hasMatch(interpolated), isFalse);

          // All matched placeholders present in sampleArgs should be replaced
          final matches = placeholderRegex.allMatches(entry.value);
          for (final m in matches) {
            final ph = m.group(1)!;
            if (sampleArgs.containsKey(ph)) {
              expect(
                interpolated,
                isNot(contains('{$ph}')),
                reason: 'Placeholder {$ph} in key ${entry.key} was not interpolated',
              );
            }
          }
        }
      }
    });
  });

  group('Canonical Suite 2: All 60 World Language Catalogs 100% Parity', () {
    test('Every catalog registered in catalogs.dart has exactly 705 keys matching enCatalog', () {
      final canonicalKeys = enCatalog.keys.toSet();
      expect(canonicalKeys.length, equals(705));

      // Verify all 60 catalogs
      for (final entry in DynamicCatalogs.allRawCatalogs.entries) {
        final langCode = entry.key;
        final catalog = entry.value;

        expect(
          catalog.length,
          equals(705),
          reason: 'Catalog "$langCode" must contain exactly 705 keys, found ${catalog.length}',
        );

        final catalogKeys = catalog.keys.toSet();
        final missingKeys = canonicalKeys.difference(catalogKeys);
        final extraKeys = catalogKeys.difference(canonicalKeys);

        expect(
          missingKeys,
          isEmpty,
          reason: 'Catalog "$langCode" is missing ${missingKeys.length} keys: $missingKeys',
        );
        expect(
          extraKeys,
          isEmpty,
          reason: 'Catalog "$langCode" has unexpected extra keys: $extraKeys',
        );
      }
    });

    test('Zero empty or whitespace-only values across all 60 catalogs (43,260 key-values)', () {
      for (final entry in DynamicCatalogs.allRawCatalogs.entries) {
        final langCode = entry.key;
        final catalog = entry.value;

        for (final item in catalog.entries) {
          expect(
            item.value.trim().isNotEmpty,
            isTrue,
            reason: 'Catalog "$langCode" key "${item.key}" has empty value',
          );
        }
      }
    });

    test('Zero raw Vietnamese strings leaked into non-Vietnamese catalogs', () {
      // Known Vietnamese indicator keywords that should NEVER appear in foreign catalogs
      final vietnameseKeywords = [
        'Đăng nhập', 'Đăng ký', 'Tôi vẫn ổn', 'Bình yên', 'Người thân',
        'Cài đặt', 'Thiết bị', 'Sự cố', 'Khẩn cấp', 'Mật khẩu',
      ];

      for (final entry in DynamicCatalogs.allRawCatalogs.entries) {
        final langCode = entry.key;
        if (langCode == 'vi') continue;

        final catalog = entry.value;
        for (final item in catalog.entries) {
          final k = item.key;
          final v = item.value;
          final viVal = viCatalog[k]!;
          final enVal = enCatalog[k]!;

          // If Vietnamese text differs from English (i.e. not a brand name like Evernear)
          if (viVal != enVal) {
            expect(
              v != viVal,
              isTrue,
              reason: 'Catalog "$langCode" leaked raw Vietnamese text for key "$k": "$v"',
            );
          }

          // Check for unmistakable Vietnamese multi-word phrases
          for (final kw in vietnameseKeywords) {
            expect(
              v.contains(kw),
              isFalse,
              reason: 'Catalog "$langCode" contains Vietnamese phrase "$kw" in key "$k"',
            );
          }
        }
      }
    });

    test('All interpolation placeholders {var} in enCatalog are preserved 1-to-1 in all 60 catalogs', () {
      final placeholderRegex = RegExp(r'\{([a-zA-Z0-9_]+)\}');

      for (final entry in DynamicCatalogs.allRawCatalogs.entries) {
        final langCode = entry.key;
        final catalog = entry.value;

        for (final item in enCatalog.entries) {
          final enMatches = placeholderRegex.allMatches(item.value).map((m) => m.group(1)!).toSet();
          if (enMatches.isNotEmpty) {
            final targetValue = catalog[item.key] ?? '';
            final targetMatches = placeholderRegex.allMatches(targetValue).map((m) => m.group(1)!).toSet();

            expect(
              targetMatches,
              equals(enMatches),
              reason: 'Catalog "$langCode" key "${item.key}" placeholders mismatch. Expected $enMatches, found $targetMatches in "$targetValue"',
            );
          }
        }
      }
    });

    test('LocaleCatalogRegistry covers all 60 catalogs and resolves cleanly via AppLocalizations', () {
      AppLocalizations.enableExtendedCatalogs = true;

      expect(LocaleCatalogRegistry.allLanguages.length, equals(60));

      for (final lang in LocaleCatalogRegistry.allLanguages) {
        final l10n = AppLocalizations(Locale(lang.code));
        final resolvedAppName = l10n.tr('app_name');
        final resolvedButton = l10n.tr('check_in_button');

        expect(resolvedAppName.trim().isNotEmpty, isTrue);
        expect(resolvedButton.trim().isNotEmpty, isTrue);
      }

      AppLocalizations.enableExtendedCatalogs = false;
    });
  });
}
