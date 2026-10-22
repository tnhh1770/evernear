import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/i18n/app_localizations.dart';
import 'package:mobile/core/i18n/catalogs/catalogs.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Comprehensive Vietnamese diacritics regular expression (precomposed and decomposed)
  final vietnameseDiacriticsPattern = RegExp(
    r'[àáảãạăằắẳẵặâầấẩẫậđèéẻẽẹêềếểễệìíỉĩịòóỏõọôồốổỗộơờớởỡợùúủũụưừứửữựỳýỷỹỵ'
    r'ÀÁẢÃẠĂẰẮẲẴẶÂẦẤẨẪẬĐÈÉẺẸÊỀẾỂỄỆÌÍỈĨỊÒÓỎÕỌÔỒỐỔỖỘƠỜỚỞỠỢÙÚỦŨỤƯỪỨỬỮỰỲÝỶỸỴ'
    r'\u0300-\u036F]',
  );

  group('Challenger 1: Catalog Parity & Purity Empirical Verification', () {
    test('1. Exact key count and 100% key parity between viCatalog and enCatalog (all 705 keys)', () {
      final viKeys = viCatalog.keys.toSet();
      final enKeys = enCatalog.keys.toSet();

      // Check key counts
      expect(viCatalog.length, equals(705),
          reason: 'viCatalog must contain exactly 705 keys, found ${viCatalog.length}');
      expect(enCatalog.length, equals(705),
          reason: 'enCatalog must contain exactly 705 keys, found ${enCatalog.length}');
      expect(viKeys.length, equals(705),
          reason: 'viCatalog keys set must contain exactly 705 unique keys');
      expect(enKeys.length, equals(705),
          reason: 'enCatalog keys set must contain exactly 705 unique keys');

      // Check set equality and differences
      final missingInEn = viKeys.difference(enKeys);
      final missingInVi = enKeys.difference(viKeys);

      expect(missingInEn, isEmpty,
          reason: 'All viCatalog keys must be present in enCatalog. Missing: $missingInEn');
      expect(missingInVi, isEmpty,
          reason: 'All enCatalog keys must be present in viCatalog. Extra: $missingInVi');
      expect(enKeys, equals(viKeys),
          reason: 'enCatalog and viCatalog key sets must be identical');
    });

    test('2. Source file duplicate key audit in vi_catalog.dart and en_catalog.dart', () {
      final viFile = File('lib/core/i18n/catalogs/vi_catalog.dart');
      final enFile = File('lib/core/i18n/catalogs/en_catalog.dart');

      expect(viFile.existsSync(), isTrue, reason: 'vi_catalog.dart must exist on disk');
      expect(enFile.existsSync(), isTrue, reason: 'en_catalog.dart must exist on disk');

      final keyRegex = RegExp(r"'([a-zA-Z0-9_.-]+)'\s*:");

      final viMatches = keyRegex.allMatches(viFile.readAsStringSync()).map((m) => m.group(1)!).toList();
      final enMatches = keyRegex.allMatches(enFile.readAsStringSync()).map((m) => m.group(1)!).toList();

      expect(viMatches.length, equals(705),
          reason: 'vi_catalog.dart syntax must contain exactly 705 key definitions (no duplicates)');
      expect(enMatches.length, equals(705),
          reason: 'en_catalog.dart syntax must contain exactly 705 key definitions (no duplicates)');
    });

    test('3. Zero Vietnamese characters or diacritics in enCatalog (all 705 keys and values)', () {
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

      expect(keysWithVietnamese, isEmpty,
          reason: 'enCatalog keys must not contain Vietnamese characters: $keysWithVietnamese');
      expect(valuesWithVietnamese, isEmpty,
          reason: 'enCatalog values must not contain Vietnamese characters: $valuesWithVietnamese');
    });

    test('4. Every key in enCatalog resolves non-empty English text in AppLocalizations', () {
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

      expect(emptyResolutions, isEmpty,
          reason: 'Every key in enCatalog must resolve non-empty string. Empty keys: $emptyResolutions');
      expect(vietnameseLeakedInEn, isEmpty,
          reason: 'AppLocalizations(en) must never resolve Vietnamese characters: $vietnameseLeakedInEn');
      expect(mismatchedResolutions, isEmpty,
          reason: 'AppLocalizations(en).tr(key) must exactly match enCatalog[key]: $mismatchedResolutions');
    });

    test('5. StaticTr with English globalLocaleCode resolves all 705 keys to clean English text', () {
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

      expect(emptyStaticResolutions, isEmpty,
          reason: 'AppLocalizations.staticTr with locale "en" must resolve non-empty strings');
      expect(vietnameseInStatic, isEmpty,
          reason: 'AppLocalizations.staticTr with locale "en" must have 0 Vietnamese characters');

      // Reset global locale back to default
      AppLocalizations.globalLocaleCode = 'vi';
    });

    test('6. DynamicCatalogs Tier-1 "en" catalog has exactly 705 entries matching enCatalog', () {
      final dynEn = DynamicCatalogs.getCatalog('en');
      expect(dynEn, isNotNull);
      expect(dynEn!.length, equals(705));
      expect(dynEn.keys.toSet(), equals(enCatalog.keys.toSet()));

      final dynAnyEn = DynamicCatalogs.getAnyCatalog('en');
      expect(dynAnyEn, isNotNull);
      expect(dynAnyEn!.length, equals(705));
    });

    test('7. Adversarial check: Non-Vietnamese locales reject Vietnamese fallback parameters', () {
      final l10nEn = AppLocalizations(const Locale('en'));
      final l10nJa = AppLocalizations(const Locale('ja'));
      final l10nDe = AppLocalizations(const Locale('de'));
      final l10nFr = AppLocalizations(const Locale('fr'));

      const testKey = 'non_existent_challenger_key_test';
      const vietnameseFallback = 'Đây là tiếng Việt có dấu';

      // English: should reject Vietnamese fallback and format key as Title Case
      final enResult = l10nEn.tr(testKey, fallback: vietnameseFallback);
      expect(enResult, isNot(contains(vietnameseFallback)));
      expect(vietnameseDiacriticsPattern.hasMatch(enResult), isFalse);
      expect(enResult, equals('Non Existent Challenger Key Test'));

      // Japanese: should also never use Vietnamese fallback
      final jaResult = l10nJa.tr(testKey, fallback: vietnameseFallback);
      expect(jaResult, isNot(contains(vietnameseFallback)));
      expect(vietnameseDiacriticsPattern.hasMatch(jaResult), isFalse);
      expect(jaResult, equals('Non Existent Challenger Key Test'));

      // German: should also never use Vietnamese fallback
      final deResult = l10nDe.tr(testKey, fallback: vietnameseFallback);
      expect(deResult, isNot(contains(vietnameseFallback)));
      expect(vietnameseDiacriticsPattern.hasMatch(deResult), isFalse);

      // French: should also never use Vietnamese fallback
      final frResult = l10nFr.tr(testKey, fallback: vietnameseFallback);
      expect(frResult, isNot(contains(vietnameseFallback)));
      expect(vietnameseDiacriticsPattern.hasMatch(frResult), isFalse);

      // But Vietnamese locale DOES accept Vietnamese fallback for missing key
      final l10nVi = AppLocalizations(const Locale('vi'));
      final viResult = l10nVi.tr(testKey, fallback: vietnameseFallback);
      expect(viResult, equals(vietnameseFallback));
    });

    test('8. Interpolation placeholders test: all templated keys in enCatalog interpolate properly', () {
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
      };

      for (final entry in enCatalog.entries) {
        if (placeholderRegex.hasMatch(entry.value)) {
          final interpolated = l10n.tr(entry.key, args: sampleArgs);
          expect(interpolated.trim().isNotEmpty, isTrue);
          expect(vietnameseDiacriticsPattern.hasMatch(interpolated), isFalse);

          // All matched placeholders that were present in sampleArgs should be replaced
          final matches = placeholderRegex.allMatches(entry.value);
          for (final m in matches) {
            final ph = m.group(1)!;
            if (sampleArgs.containsKey(ph)) {
              expect(interpolated, isNot(contains('{$ph}')),
                  reason: 'Placeholder {$ph} in key ${entry.key} was not interpolated');
            }
          }
        }
      }
    });
  });
}
