import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/i18n/app_localizations.dart';
import 'package:mobile/core/i18n/catalogs/catalogs.dart';
import 'package:mobile/core/i18n/locale_catalog_registry.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final vietnameseDiacriticsPattern = RegExp(
    r'[àáảãạăằắẳẵặâầấẩẫậđèéẻẽẹêềếểễệìíỉĩịòóỏõọôồốổỗộơờớởỡợùúủũụưừứửữựỳýỷỹỵ'
    r'ÀÁẢÃẠĂẰẮẲẴẶÂẦẤẨẪẬĐÈÉẺẸÊỀẾỂỄỆÌÍỈĨỊÒÓỎÕỌÔỒỐỔỖỘƠỜỚỞỠỢÙÚỦŨỤƯỪỨỬỮỰỲÝỶỸỴ'
    r'\u0300-\u036F]',
  );

  group('M5 Challenger 2: Adversarial Stress Test on LocaleCatalogRegistry & AppLocalizations', () {
    setUp(() {
      AppLocalizations.enableExtendedCatalogs = true;
    });

    tearDown(() {
      AppLocalizations.enableExtendedCatalogs = true;
      AppLocalizations.globalLocaleCode = 'vi';
    });

    test('LocaleCatalogRegistry integrity: exactly 60 unique world languages with complete metadata', () {
      final languages = LocaleCatalogRegistry.allLanguages;
      expect(languages.length, equals(60), reason: 'Must have exactly 60 languages');

      final codes = <String>{};
      for (final lang in languages) {
        expect(lang.code.trim().isNotEmpty, isTrue, reason: 'Language code must not be empty');
        expect(codes.contains(lang.code), isFalse, reason: 'Duplicate language code: ${lang.code}');
        codes.add(lang.code);

        expect(lang.nativeName.trim().isNotEmpty, isTrue, reason: 'Native name empty for ${lang.code}');
        expect(lang.englishName.trim().isNotEmpty, isTrue, reason: 'English name empty for ${lang.code}');
        expect(lang.flagEmoji.trim().isNotEmpty, isTrue, reason: 'Flag emoji empty for ${lang.code}');
      }

      // Check all 60 languages exist in DynamicCatalogs.allRawCatalogs
      for (final code in codes) {
        expect(
          DynamicCatalogs.allRawCatalogs.containsKey(code),
          isTrue,
          reason: 'Language code "$code" from registry not found in DynamicCatalogs.allRawCatalogs',
        );
      }
    });

    test('Tight-loop stress test: 60 languages x 100 randomly sampled keys -> 0 crashes, 0 nulls, 0 empty strings', () {
      final allCanonicalKeys = enCatalog.keys.toList();
      expect(allCanonicalKeys.length, equals(705));

      // Fixed seed for deterministic repeatability
      final random = Random(42);

      // Pre-sample 100 distinct keys from the 705 canonical keys
      final shuffledKeys = List<String>.from(allCanonicalKeys)..shuffle(random);
      final sampledKeys = shuffledKeys.take(100).toList();
      expect(sampledKeys.length, equals(100));

      final totalResolved = <String, int>{};
      int totalLookups = 0;

      final stopwatch = Stopwatch()..start();

      for (final lang in LocaleCatalogRegistry.allLanguages) {
        final langCode = lang.code;
        final locale = Locale(langCode);

        // Initialize AppLocalizations for this locale
        final l10n = AppLocalizations(locale);
        expect(l10n, isNotNull);

        int langResolvedCount = 0;

        for (final key in sampledKeys) {
          // Resolve key
          final String resolved = l10n.tr(key);

          // Assertions
          expect(resolved, isNotNull, reason: 'Resolved value was null for $langCode:$key');
          expect(resolved.trim().isNotEmpty, isTrue, reason: 'Resolved value was empty for $langCode:$key');

          // If language is not Vietnamese, check that Vietnamese diacritics don't leak
          // unless the canonical English key itself has diacritics (none do) or is not translated yet
          if (langCode != 'vi') {
            final viVal = viCatalog[key]!;
            final enVal = enCatalog[key]!;
            // If the Vietnamese translation is distinct from English
            if (viVal != enVal && vietnameseDiacriticsPattern.hasMatch(viVal)) {
              expect(
                resolved != viVal,
                isTrue,
                reason: 'Leak: $langCode returned raw Vietnamese for $key: "$resolved"',
              );
            }
          }

          langResolvedCount++;
          totalLookups++;
        }

        totalResolved[langCode] = langResolvedCount;
        expect(langResolvedCount, equals(100));
      }

      stopwatch.stop();

      expect(totalLookups, equals(6000), reason: '60 languages * 100 keys = 6000 lookups');
      expect(totalResolved.length, equals(60));
    });

    test('High-concurrency repeat stress test: 10 cycles x 60 languages x 100 keys = 60,000 lookups', () {
      final allCanonicalKeys = enCatalog.keys.toList();
      final random = Random(999);
      final sampledKeys = (List<String>.from(allCanonicalKeys)..shuffle(random)).take(100).toList();

      int cyclesCompleted = 0;
      int grandTotalLookups = 0;

      final stopwatch = Stopwatch()..start();

      for (int cycle = 0; cycle < 10; cycle++) {
        for (final lang in LocaleCatalogRegistry.allLanguages) {
          final l10n = AppLocalizations(Locale(lang.code));
          for (final key in sampledKeys) {
            final val = l10n.tr(key);
            if (val.isEmpty) {
              fail('Encountered empty string for ${lang.code}:$key on cycle $cycle');
            }
            grandTotalLookups++;
          }
        }
        cyclesCompleted++;
      }

      stopwatch.stop();

      expect(cyclesCompleted, equals(10));
      expect(grandTotalLookups, equals(60000));
    });

    test('Stress test interpolation across all 60 languages with placeholder parameters', () {
      final placeholderKeys = enCatalog.entries
          .where((e) => e.value.contains('{') && e.value.contains('}'))
          .map((e) => e.key)
          .toList();

      expect(placeholderKeys.isNotEmpty, isTrue, reason: 'There must be templated keys in catalog');

      final sampleArgs = {
        'name': 'AdversarialTest',
        'time': '23:59',
        'count': '42',
        'level': 'CriticalAlert',
        'platform': 'Android/iOS',
        'interval': '60',
        'value': '99',
        'date': '2026-10-19',
        'error': 'SimulatedStressError',
        'days': '14',
        'seconds': '45',
        'minutes': '30',
        'hours': '5',
        'active': 'ActiveState',
        'bedtime': '22:00',
        'charging': 'ChargingStatus',
        'code': 'CODE123',
        'duration': '15m',
        'end': '07:00',
        'language': 'English',
        'nextDay': 'Tomorrow',
        'note': 'TestNote',
        'preview': 'PreviewData',
        'query': 'SearchQuery',
        'relation': 'FamilyRelation',
        'score': '85',
        'sleep': '8h',
        'start': '22:00',
        'startDay': 'Monday',
        'state': 'SafeState',
        'version': '1.0.0',
        'wakeTime': '06:00',
      };

      for (final lang in LocaleCatalogRegistry.allLanguages) {
        final l10n = AppLocalizations(Locale(lang.code));
        for (final key in placeholderKeys) {
          final interpolated = l10n.tr(key, args: sampleArgs);
          expect(interpolated.trim().isNotEmpty, isTrue, reason: 'Empty interpolation in ${lang.code}:$key');
          expect(interpolated, isNot(contains('{')), reason: 'Unreplaced placeholder in ${lang.code}:$key -> "$interpolated"');
        }
      }
    });

    test('StaticTr stress test across 60 global locales with random keys', () {
      final allCanonicalKeys = enCatalog.keys.toList();
      final random = Random(12345);
      final sampledKeys = (List<String>.from(allCanonicalKeys)..shuffle(random)).take(50).toList();

      for (final lang in LocaleCatalogRegistry.allLanguages) {
        AppLocalizations.globalLocaleCode = lang.code;
        for (final key in sampledKeys) {
          final resolved = AppLocalizations.staticTr(key);
          expect(resolved.trim().isNotEmpty, isTrue);
          expect(resolved, isNotNull);
        }
      }
    });
  });
}
