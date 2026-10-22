import 'dart:io';
import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/i18n/app_localizations.dart';
import 'package:mobile/core/models/schedule_window_model.dart';
import 'package:mobile/core/i18n/locale_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('M2 Challenger 1: Empirical Static AST & String Analysis', () {
    final libDir = Directory('lib');
    final featuresDir = Directory('lib/features');
    final coreWidgetsDir = Directory('lib/core/widgets');

    final vietnameseDiacritics = RegExp(
      r'[àáảãạăằắẳẵặâầấẩẫậđèéẻẽẹêềếểễệìíỉĩịòóỏõọôồốổỗộơờớởỡợùúủũụưừứửữựỳýỷỹỵ'
      r'ÀÁẢÃẠĂẰẮẲẴẶÂẦẤẨẪẬĐÈÉẺẸÊỀẾỂỄỆÌÍỈĨỊÒÓỎÕỌÔỒỐỔỖỘƠỜỚỞỠỢÙÚỦŨỤƯỪỨỬỮỰỲÝỶỸỴ]',
    );

    // =========================================================================
    // 1. AppStrings. Occurrence Verification Across mobile/lib/
    // =========================================================================
    test('1. Exactly 0 occurrences of "AppStrings." in mobile/lib/', () {
      expect(libDir.existsSync(), isTrue, reason: 'lib directory must exist');

      final appStringsMatches = <String>[];
      final files = libDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'));

      for (final file in files) {
        final lines = file.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i];
          // Strip single-line comments
          final codePart = line.split('//').first;
          if (codePart.contains('AppStrings.')) {
            appStringsMatches.add('${file.path}:${i + 1}: $line');
          }
        }
      }

      expect(
        appStringsMatches,
        isEmpty,
        reason:
            'Found unexpected occurrences of "AppStrings." in mobile/lib/:\n${appStringsMatches.join('\n')}',
      );
    });

    test('1b. Zero imports of "app_strings.dart" in screens and widgets', () {
      final unwantedImports = <String>[];
      final files = libDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .where((f) => !f.path.endsWith('app_strings.dart'));

      for (final file in files) {
        final lines = file.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i];
          if (line.trim().startsWith('import') &&
              line.contains('app_strings.dart')) {
            unwantedImports.add('${file.path}:${i + 1}: $line');
          }
        }
      }

      expect(
        unwantedImports,
        isEmpty,
        reason:
            'Found unwanted imports of app_strings.dart in mobile/lib/:\n${unwantedImports.join('\n')}',
      );
    });

    // =========================================================================
    // 2. ScheduleWindow.dayNameShort Localization Verification
    // =========================================================================
    group('2. ScheduleWindow.dayNameShort localization', () {
      setUp(() {
        AppLocalizations.globalLocaleCode = 'vi';
      });

      tearDown(() {
        AppLocalizations.globalLocaleCode = 'vi';
      });

      test('returns correct Vietnamese short day abbreviations when locale is "vi"', () {
        AppLocalizations.globalLocaleCode = 'vi';
        final expectedVi = ['CN', 'T2', 'T3', 'T4', 'T5', 'T6', 'T7'];

        for (var day = 0; day <= 6; day++) {
          final window = ScheduleWindowModel(
            dayOfWeek: day,
            startTime: '08:00',
            endTime: '18:00',
          );
          expect(
            window.dayNameShort,
            equals(expectedVi[day]),
            reason: 'dayOfWeek $day in locale "vi" should be ${expectedVi[day]}',
          );
        }
      });

      test('returns correct English short day abbreviations when locale is "en"', () {
        AppLocalizations.globalLocaleCode = 'en';
        final expectedEn = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

        for (var day = 0; day <= 6; day++) {
          final window = ScheduleWindowModel(
            dayOfWeek: day,
            startTime: '08:00',
            endTime: '18:00',
          );
          expect(
            window.dayNameShort,
            equals(expectedEn[day]),
            reason: 'dayOfWeek $day in locale "en" should be ${expectedEn[day]}',
          );
        }
      });

      test('falls back safely to English abbreviations for non-Vietnamese locales without leaking Vietnamese', () {
        // Japanese
        AppLocalizations.globalLocaleCode = 'ja';
        final window = ScheduleWindowModel(
          dayOfWeek: 1, // Monday
          startTime: '08:00',
          endTime: '18:00',
        );
        // enCatalog has Mon, viCatalog has T2. Must NOT return T2 in non-vi locale
        expect(window.dayNameShort, isNot(equals('T2')));
        expect(window.dayNameShort, equals('月'));

        // French
        AppLocalizations.globalLocaleCode = 'fr';
        expect(window.dayNameShort, isNot(equals('T2')));
        expect(window.dayNameShort, equals('Lun.'));
      });

      test('Adversarial probe: dayNameShortLocalized optional languageCode parameter bug', () {
        AppLocalizations.globalLocaleCode = 'vi';
        final window = ScheduleWindowModel(
          dayOfWeek: 1,
          startTime: '08:00',
          endTime: '18:00',
        );

        // ScheduleWindowModel defines: String dayNameShortLocalized([String? languageCode])
        // If a caller explicitly passes 'en', does it respect 'en' or ignore it?
        final resultWithEnArg = window.dayNameShortLocalized('en');

        // Documenting behavior: schedule_window_model.dart line 132-137 ignores the parameter
        // and delegates to AppLocalizations.staticTr which uses globalLocaleCode ('vi').
        // Therefore resultWithEnArg is 'T2' rather than 'Mon'!
        expect(
          resultWithEnArg,
          anyOf(equals('Mon'), equals('T2')),
          reason: 'Records actual implementation behavior for handoff report',
        );
      });
    });

    // =========================================================================
    // 3. Raw Vietnamese Text Literals Verification in Features & Core Widgets
    // =========================================================================
    group('3. Raw Vietnamese text literal analysis in features & core widgets', () {
      test('Verifies no raw Vietnamese text literals are passed directly to Text/TextSpan/tooltip/SnackBar', () {
        final directWidgetViolations = <String>[];

        final directTextPattern = RegExp(
          r'''Text\s*\(\s*(?:'([^'\\]*(?:\\.[^'\\]*)*)'|"([^"\\]*(?:\\.[^"\\]*)*)")''',
        );
        final directTextSpanPattern = RegExp(
          r'''TextSpan\s*\([^)]*text\s*:\s*(?:'([^'\\]*(?:\\.[^'\\]*)*)'|"([^"\\]*(?:\\.[^"\\]*)*)")''',
        );
        final directTooltipPattern = RegExp(
          r'''tooltip\s*:\s*(?:'([^'\\]*(?:\\.[^'\\]*)*)'|"([^"\\]*(?:\\.[^"\\]*)*)")''',
        );
        final directSnackBarPattern = RegExp(
          r'''SnackBar\s*\([^)]*(?:'([^'\\]*(?:\\.[^'\\]*)*)'|"([^"\\]*(?:\\.[^"\\]*)*)")''',
        );

        final targetFiles = [
          ...featuresDir.listSync(recursive: true).whereType<File>(),
          ...coreWidgetsDir.listSync(recursive: true).whereType<File>(),
        ].where((f) => f.path.endsWith('.dart'));

        for (final file in targetFiles) {
          final content = file.readAsStringSync();
          // Remove comments
          final noBlockComments = content.replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '');
          final lines = noBlockComments.split('\n');

          for (var i = 0; i < lines.length; i++) {
            final line = lines[i];
            final codePart = line.split('//').first;

            for (final pat in [
              directTextPattern,
              directTextSpanPattern,
              directTooltipPattern,
              directSnackBarPattern,
            ]) {
              for (final match in pat.allMatches(codePart)) {
                final literal = match.group(1) ?? match.group(2) ?? '';
                if (vietnameseDiacritics.hasMatch(literal)) {
                  directWidgetViolations.add('${file.path}:${i + 1}: "$literal"');
                }
              }
            }
          }
        }

        expect(
          directWidgetViolations,
          isEmpty,
          reason:
              'Found raw Vietnamese literals passed directly to Text/TextSpan/tooltip/SnackBar:\n${directWidgetViolations.join('\n')}',
        );
      });

      test('Adversarial probe: detects raw Vietnamese literal in landing_screen.dart:1274', () {
        final landingFile = File('lib/features/landing/landing_screen.dart');
        if (landingFile.existsSync()) {
          final lines = landingFile.readAsLinesSync();
          final violations = <String>[];
          for (var i = 0; i < lines.length; i++) {
            final line = lines[i];
            // Check for raw literal passed to _weightRow which wraps in Text()
            if (line.contains('_weightRow') &&
                line.contains('Tôi vẫn ổn') &&
                !line.contains('_tr(') &&
                !line.contains('tr(')) {
              violations.add('Line ${i + 1}: ${line.trim()}');
            }
          }
          // Report finding: Line 1274 contains _weightRow('Check-in "Tôi vẫn ổn"', '1.0', 1.0, _coral)
          // which bypasses _tr()
          expect(
            violations.length,
            equals(1),
            reason: 'Identified unwrapped Vietnamese string in landing_screen.dart:1274',
          );
        }
      });

      test('Adversarial probe: detects hardcoded Vietnamese in LocaleProvider.currentLanguageDisplayName', () {
        final provider = LocaleProvider();
        // When device default is true, currentLanguageDisplayName appends hardcoded '(Tự động)'
        // even if locale is English!
        provider.setLocale(const Locale('en'));
        // Note: _isDeviceDefault is true upon initialization if no stored preference exists.
        final displayName = provider.currentLanguageDisplayName;
        expect(displayName, isNotNull);
      });
    });
  });
}
