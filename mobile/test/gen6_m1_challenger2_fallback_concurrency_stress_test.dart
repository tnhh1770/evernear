import 'dart:isolate';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/i18n/app_localizations.dart';
import 'package:mobile/core/i18n/catalogs/catalogs.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final RegExp vietnameseDiacritics = RegExp(
    r'[àáảãạăằắẳẵặâầấẩẫậđèéẻẽẹêềếểễệìíỉĩịòóỏõọôồốổỗộơờớởỡợùúủũụưừứửữựỳýỷỹỵ'
    r'ÀÁẢÃẠĂẰẮẲẴẶÂẦẤẨẪẬĐÈÉẺẸÊỀẾỂỄỆÌÍỈĨỊÒÓỎÕỌÔỒỐỔỖỘƠỜỚỞỠỢÙÚỦŨỤƯỪỨỬỮỰỲÝỶỸỴ]',
  );

  bool hasVietnamese(String text) => vietnameseDiacritics.hasMatch(text);

  group('Adversarial Dimension 1: Non-existent Keys Never Return Vietnamese in Non-vi Locales', () {

    test('1.1 250+ synthetic non-existent keys in en, ja, de locales never return Vietnamese diacritics', () {
      final random = Random(42);
      final testLocales = ['en', 'ja', 'de'];

      for (final code in testLocales) {
        final l10n = AppLocalizations(Locale(code));

        for (int i = 0; i < 250; i++) {
          final syntheticKey = 'adversarial_non_existent_key_${random.nextInt(1000000)}_test';
          final result = l10n.tr(syntheticKey);

          expect(result, isNotEmpty);
          expect(
            hasVietnamese(result),
            isFalse,
            reason: 'Locale $code returned Vietnamese diacritics for missing key $syntheticKey: "$result"',
          );
          // Check that it does not equal any value in viCatalog
          expect(
            viCatalog.containsValue(result),
            isFalse,
            reason: 'Locale $code returned a viCatalog text for missing key $syntheticKey: "$result"',
          );
          // Check that it returned human-readable Title Case
          expect(result, isNot(contains('_')));
          expect(result, isNot(contains('[')));
        }
      }
    });

    test('1.2 Hierarchical and punctuation-heavy non-existent keys in en, ja, de never return Vietnamese', () {
      final oddKeys = [
        'deeply.nested.module.feature.button.action_confirm',
        'auth:::oauth:::provider:::unsupported',
        'system-alert-sensor-failure-critical-code-99',
        'unknown_screen_empty_state_action_retry_v2',
        'notif_channel_security_breach_secondary_banner',
      ];

      for (final code in ['en', 'ja', 'de']) {
        final l10n = AppLocalizations(Locale(code));
        for (final key in oddKeys) {
          final result = l10n.tr(key);
          expect(hasVietnamese(result), isFalse,
              reason: 'Locale $code leaked Vietnamese on $key: "$result"');
          expect(viCatalog.containsValue(result), isFalse);
          expect(result, isNot(contains('.')));
          expect(result, isNot(contains('-')));
        }
      }
    });

    test('1.3 Comprehensive audit of all 705 viCatalog keys queried in en, ja, de', () {
      // For every key existing in viCatalog, querying in en, ja, de must never return the vi text
      final l10nEn = AppLocalizations(const Locale('en'));
      final l10nJa = AppLocalizations(const Locale('ja'));
      final l10nDe = AppLocalizations(const Locale('de'));

      int checkedCount = 0;
      for (final entry in viCatalog.entries) {
        final key = entry.key;
        final viText = entry.value;

        // Skip keys whose Vietnamese text is inherently language-neutral (e.g. brand "Evernear", "SMS", "78%", "24/7", etc.)
        if (!hasVietnamese(viText)) continue;

        checkedCount++;

        final enResult = l10nEn.tr(key);
        expect(
          hasVietnamese(enResult),
          isFalse,
          reason: 'en locale leaked Vietnamese for key $key: "$enResult" (vi was "$viText")',
        );
        expect(
          enResult,
          isNot(equals(viText)),
          reason: 'en locale returned exact Vietnamese text for key $key',
        );

        final jaResult = l10nJa.tr(key);
        expect(
          hasVietnamese(jaResult),
          isFalse,
          reason: 'ja locale leaked Vietnamese for key $key: "$jaResult"',
        );
        expect(
          jaResult,
          isNot(equals(viText)),
          reason: 'ja locale returned exact Vietnamese text for key $key',
        );

        final deResult = l10nDe.tr(key);
        expect(
          hasVietnamese(deResult),
          isFalse,
          reason: 'de locale leaked Vietnamese for key $key: "$deResult"',
        );
        expect(
          deResult,
          isNot(equals(viText)),
          reason: 'de locale returned exact Vietnamese text for key $key',
        );
      }

      expect(checkedCount, greaterThan(400),
          reason: 'Must audit at least 400 keys with distinct Vietnamese diacritics');
    });

    test('1.4 DynamicCatalogs.getCatalog for non-vi locales does not contain Vietnamese diacritics', () {
      for (final code in ['en']) {
        final catalog = DynamicCatalogs.getCatalog(code)!;
        for (final entry in catalog.entries) {
          expect(
            hasVietnamese(entry.value),
            isFalse,
            reason: '$code catalog contains Vietnamese diacritic in ${entry.key}: "${entry.value}"',
          );
        }
      }
    });
  });

  group('Adversarial Dimension 2: Fallback Text Sanitization & Zero Vietnamese Leakage', () {
    const vietnameseFallbacks = [
      'Tiếng Việt',
      'Xác nhận an toàn',
      'Đồng ý và tiếp tục',
      'Cảnh báo nguy hiểm khẩn cấp',
      'Hồ sơ người dùng & người được ủy quyền',
      'Lưu thay đổi thành công',
      'Đã xảy ra lỗi, vui lòng thử lại sau',
      'Hủy bỏ thao tác',
      'Thời gian xác nhận gần nhất: hôm nay',
      'Đang kết nối cuộc gọi hỗ trợ khẩn cấp...',
      'Chạm và giữ liên tục 2 giây',
      'Không nhận được phản hồi từ người thân',
      'Khung giờ nghỉ ngơi (đóng băng bộ đếm)',
      'Tài khoản đang đăng nhập',
    ];

    test('2.1 Passing Vietnamese fallback to tr() in English session is sanitized', () {
      final l10n = AppLocalizations(const Locale('en'));

      for (int i = 0; i < vietnameseFallbacks.length; i++) {
        final vnFallback = vietnameseFallbacks[i];
        final missingKey = 'missing_adversarial_feature_key_$i';

        final result = l10n.tr(missingKey, fallback: vnFallback);

        expect(
          hasVietnamese(result),
          isFalse,
          reason: 'English session leaked Vietnamese fallback "$vnFallback" for key $missingKey: got "$result"',
        );
        expect(result, isNot(equals(vnFallback)));
        // Should fall back to humanized key name
        expect(result, AppLocalizations.formatKeyName(missingKey));
      }
    });

    test('2.2 Passing Vietnamese fallback to tr() in Japanese and German sessions is sanitized', () {
      final l10nJa = AppLocalizations(const Locale('ja'));
      final l10nDe = AppLocalizations(const Locale('de'));

      for (int i = 0; i < vietnameseFallbacks.length; i++) {
        final vnFallback = vietnameseFallbacks[i];
        final missingKey = 'untranslated_audit_key_$i';

        final jaResult = l10nJa.tr(missingKey, fallback: vnFallback);
        expect(hasVietnamese(jaResult), isFalse,
            reason: 'Japanese session leaked Vietnamese fallback "$vnFallback": got "$jaResult"');
        expect(jaResult, isNot(equals(vnFallback)));

        final deResult = l10nDe.tr(missingKey, fallback: vnFallback);
        expect(hasVietnamese(deResult), isFalse,
            reason: 'German session leaked Vietnamese fallback "$vnFallback": got "$deResult"');
        expect(deResult, isNot(equals(vnFallback)));
      }
    });

    test('2.3 Legitimate English fallback is preserved in English session', () {
      final l10n = AppLocalizations(const Locale('en'));
      const englishFallbacks = [
        'Confirm Action',
        'Save Settings',
        'Please wait while synchronizing...',
        'No emergency contacts configured yet',
      ];

      for (int i = 0; i < englishFallbacks.length; i++) {
        final enFallback = englishFallbacks[i];
        final missingKey = 'unknown_en_key_$i';

        final result = l10n.tr(missingKey, fallback: enFallback);
        expect(result, equals(enFallback),
            reason: 'Legitimate English fallback should be used when key is missing in English session');
      }
    });

    test('2.4 StaticTr sanitizes Vietnamese fallback in non-vi sessions', () {
      // Test in en
      AppLocalizations.globalLocaleCode = 'en';
      final enStatic = AppLocalizations.staticTr(
        'missing_static_key',
        fallback: 'Tiếng Việt dự phòng',
      );
      expect(hasVietnamese(enStatic), isFalse);
      expect(enStatic, 'Missing Static Key');

      // Test in ja
      AppLocalizations.globalLocaleCode = 'ja';
      final jaStatic = AppLocalizations.staticTr(
        'missing_static_key',
        fallback: 'Tiếng Việt dự phòng',
      );
      expect(hasVietnamese(jaStatic), isFalse);
      expect(jaStatic, 'Missing Static Key');

      // Test in de
      AppLocalizations.globalLocaleCode = 'de';
      final deStatic = AppLocalizations.staticTr(
        'missing_static_key',
        fallback: 'Tiếng Việt dự phòng',
      );
      expect(hasVietnamese(deStatic), isFalse);
      expect(deStatic, 'Missing Static Key');

      // Reset
      AppLocalizations.globalLocaleCode = 'vi';
    });

    test('2.5 Vietnamese session accepts Vietnamese fallback when key is truly missing', () {
      final l10nVi = AppLocalizations(const Locale('vi'));
      final res = l10nVi.tr(
        'truly_missing_key_in_vi',
        fallback: 'Dữ liệu mặc định tiếng Việt',
      );
      expect(res, equals('Dữ liệu mặc định tiếng Việt'));
    });
  });

  group('Adversarial Dimension 3: Empty, Uppercase & Special Locale / Key Handling', () {
    test('3.1 Uppercase locale codes (EN, VI, JA, DE) normalize safely', () {
      // Locale('EN')
      final l10nUpperEn = AppLocalizations(const Locale('EN'));
      expect(l10nUpperEn.tr('check_in_button'), 'I am okay');
      expect(l10nUpperEn.tr('nav_settings'), 'Settings');

      // Locale('VI')
      final l10nUpperVi = AppLocalizations(const Locale('VI'));
      expect(l10nUpperVi.tr('check_in_button'), 'Tôi vẫn ổn');

      // Locale('JA')
      final l10nUpperJa = AppLocalizations(const Locale('JA'));
      expect(l10nUpperJa.tr('check_in_button'), '無事です');

      // Locale('DE')
      final l10nUpperDe = AppLocalizations(const Locale('DE'));
      expect(l10nUpperDe.tr('check_in_button'), 'Mir geht es gut');

      // Mixed case: 'eN', 'vI', 'jA'
      final l10nMixedEn = AppLocalizations(const Locale('eN'));
      expect(l10nMixedEn.tr('check_in_button'), 'I am okay');
    });

    test('3.2 Uppercase with country codes (EN_US, VI_VN, JA_JP) normalize safely', () {
      final l10nEnUs = AppLocalizations(const Locale('EN', 'US'));
      expect(l10nEnUs.tr('check_in_button'), 'I am okay');

      final l10nViVn = AppLocalizations(const Locale('VI', 'VN'));
      expect(l10nViVn.tr('check_in_button'), 'Tôi vẫn ổn');

      final l10nJaJp = AppLocalizations(const Locale('JA', 'JP'));
      expect(l10nJaJp.tr('check_in_button'), '無事です');
    });

    test('3.3 StaticTr with uppercase globalLocaleCode', () {
      AppLocalizations.globalLocaleCode = 'EN';
      expect(AppLocalizations.staticTr('check_in_button'), 'I am okay');

      AppLocalizations.globalLocaleCode = 'VI';
      expect(AppLocalizations.staticTr('check_in_button'), 'Tôi vẫn ổn');

      AppLocalizations.globalLocaleCode = 'JA';
      expect(AppLocalizations.staticTr('check_in_button'), '無事です');

      AppLocalizations.globalLocaleCode = 'vi';
    });

    test('3.4 Empty, whitespace and corrupt locale codes never crash or leak Vietnamese', () {
      // Test empty and whitespace static globalLocaleCode
      AppLocalizations.globalLocaleCode = '';
      final emptyStatic = AppLocalizations.staticTr('check_in_button');
      expect(emptyStatic, 'I am okay', reason: 'Empty globalLocaleCode should fall back to English');
      expect(hasVietnamese(emptyStatic), isFalse);

      final emptyMissingStatic = AppLocalizations.staticTr('fake_key_for_empty_locale');
      expect(hasVietnamese(emptyMissingStatic), isFalse);
      expect(emptyMissingStatic, 'Fake Key For Empty Locale');

      AppLocalizations.globalLocaleCode = '   ';
      final whitespaceStatic = AppLocalizations.staticTr('check_in_button');
      expect(whitespaceStatic, 'I am okay');

      // Test Locale.fromSubtags() which defaults languageCode to 'und'
      final l10nSubtags = AppLocalizations(const Locale.fromSubtags());
      expect(l10nSubtags.tr('check_in_button'), 'I am okay');
      expect(hasVietnamese(l10nSubtags.tr('check_in_button')), isFalse);

      // Corrupt, unusual and unsupported codes (Flutter forbids Locale('') via assert, so we test valid Locale objects with corrupt strings)
      final corruptCodes = ['   ', '\t', '\n', '12345', '!!!', 'und', 'null', 'undefined', 'klingon', 'xx'];

      for (final code in corruptCodes) {
        expect(() {
          final l10n = AppLocalizations(Locale(code));
          final res = l10n.tr('check_in_button');
          // In non-vi corrupted codes, it resolves enCatalog ('I am okay')
          expect(res, 'I am okay', reason: 'Corrupt code "$code" should fall back safely to English');
          expect(hasVietnamese(res), isFalse);

          final missingRes = l10n.tr('completely_fake_key_xyz');
          expect(hasVietnamese(missingRes), isFalse);
          expect(missingRes, 'Completely Fake Key Xyz');
        }, returnsNormally, reason: 'Locale("$code") must not throw an exception');
      }

      AppLocalizations.globalLocaleCode = 'vi';
    });

    test('3.5 Null parameters for optional arguments (fallback and args) handled cleanly', () {
      final l10n = AppLocalizations(const Locale('en'));

      // fallback: null explicitly
      expect(l10n.tr('check_in_button', fallback: null, args: null), 'I am okay');
      expect(l10n.tr('non_existent_key_with_null', fallback: null, args: null), 'Non Existent Key With Null');

      // staticTr with null args and null fallback
      expect(AppLocalizations.staticTr('check_in_button', fallback: null, args: null), isNotEmpty);
      expect(AppLocalizations.staticTr('non_existent_key_with_null', fallback: null, args: null), 'Non Existent Key With Null');
    });

    test('3.6 Edge-case and adversarial key inputs', () {
      final l10n = AppLocalizations(const Locale('en'));

      // Empty string
      expect(l10n.tr(''), '');

      // Whitespace
      expect(l10n.tr('   '), '   ');

      // Punctuation only
      expect(l10n.tr('---'), '---');
      expect(l10n.tr('___'), '___');
      expect(l10n.tr('...'), '...');

      // Special characters
      expect(l10n.tr(r'key_with_dollar_$1_and_\n_test'), isNotEmpty);
      expect(l10n.tr(r'<script>alert("xss")</script>'), isNotEmpty);

      // Argument interpolation with tricky characters
      final argResult = l10n.tr(
        'recent_activities_confirmed_safe',
        args: {'name': r'$1 \n \t "quotes" & <tags>'},
      );
      expect(argResult, contains(r'$1 \n \t "quotes" & <tags>'));
    });
  });

  group('Adversarial Dimension 4: Concurrency & Stress Verification', () {
    test('4.1 High-throughput concurrent lookups across 14 locales (10,000 queries)', () async {
      const tier1Codes = ['vi', 'en', 'fr', 'de', 'es', 'pt', 'ru', 'ja', 'ko', 'zh', 'th', 'id', 'ar', 'hi'];
      final random = Random(12345);

      // Launch 50 concurrent asynchronous tasks doing 200 lookups each = 10,000 total queries
      final futures = List.generate(50, (taskId) async {
        for (int step = 0; step < 200; step++) {
          final code = tier1Codes[random.nextInt(tier1Codes.length)];
          final l10n = AppLocalizations(Locale(code));

          // Real key lookup
          final checkIn = l10n.tr('check_in_button');
          expect(checkIn, isNotEmpty);

          if (code == 'vi') {
            expect(checkIn, 'Tôi vẫn ổn');
          } else if (code == 'en') {
            expect(checkIn, 'I am okay');
            expect(hasVietnamese(checkIn), isFalse);
          } else if (code == 'ja') {
            expect(checkIn, '無事です');
            expect(hasVietnamese(checkIn), isFalse);
          } else if (code == 'de') {
            expect(checkIn, 'Mir geht es gut');
            expect(hasVietnamese(checkIn), isFalse);
          }

          // Non-existent key with Vietnamese fallback lookup
          final missingRes = l10n.tr(
            'concurrent_missing_key_${taskId}_$step',
            fallback: 'Tiếng Việt nguy hiểm',
          );

          if (code != 'vi') {
            expect(
              hasVietnamese(missingRes),
              isFalse,
              reason: 'Concurrent task $taskId step $step leaked Vietnamese for locale $code',
            );
          }
        }
      });

      await Future.wait(futures);
    });

    test('4.2 Concurrent staticTr execution with rapid globalLocaleCode oscillation', () async {
      final futures = List.generate(30, (workerId) async {
        for (int i = 0; i < 100; i++) {
          if (workerId % 3 == 0) {
            AppLocalizations.globalLocaleCode = 'en';
            final text = AppLocalizations.staticTr('check_in_button');
            expect(text, anyOf('I am okay', 'Tôi vẫn ổn', '無事です'));
          } else if (workerId % 3 == 1) {
            AppLocalizations.globalLocaleCode = 'ja';
            final text = AppLocalizations.staticTr('check_in_button');
            expect(text, anyOf('I am okay', 'Tôi vẫn ổn', '無事です'));
          } else {
            AppLocalizations.globalLocaleCode = 'vi';
            final text = AppLocalizations.staticTr('check_in_button');
            expect(text, anyOf('I am okay', 'Tôi vẫn ổn', '無事です'));
          }
        }
      });

      await Future.wait(futures);
      AppLocalizations.globalLocaleCode = 'vi';
    });

    test('4.3 Isolate concurrency: translation evaluation in secondary isolate', () async {
      // Execute translation verification in an independent Isolate to verify memory isolation
      final result = await Isolate.run(() {
        final l10nEn = AppLocalizations(const Locale('en'));
        final l10nJa = AppLocalizations(const Locale('ja'));
        final l10nDe = AppLocalizations(const Locale('de'));

        final enVal = l10nEn.tr('check_in_button');
        final enFallback = l10nEn.tr('unknown_isolate_key', fallback: 'Tiếng Việt');
        final jaVal = l10nJa.tr('check_in_button');
        final deVal = l10nDe.tr('check_in_button');

        return {
          'enVal': enVal,
          'enFallback': enFallback,
          'jaVal': jaVal,
          'deVal': deVal,
        };
      });

      expect(result['enVal'], 'I am okay');
      expect(result['enFallback'], 'Unknown Isolate Key');
      expect(result['jaVal'], '無事です');
      expect(result['deVal'], 'Mir geht es gut');
      expect(hasVietnamese(result['enFallback']!), isFalse);
    });
  });

  group('Adversarial Dimension 5: Widget Tree Context.tr & Extended Catalogs Stress', () {
    testWidgets('5.1 context.tr with Vietnamese fallback inside English MaterialApp renders sanitized', (tester) async {
      String? missingFallbackResult;
      String? knownKeyFallbackResult;
      String? emptyKeyResult;

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Scaffold(
            body: Builder(
              builder: (ctx) {
                missingFallbackResult = ctx.tr(
                  'adversarial_ui_missing_key',
                  fallback: 'Tiếng Việt không được hiển thị',
                );
                knownKeyFallbackResult = ctx.tr(
                  'check_in_button',
                  fallback: 'Tiếng Việt không được hiển thị',
                );
                emptyKeyResult = ctx.tr(
                  '',
                  fallback: 'Tiếng Việt',
                );

                return Column(
                  children: [
                    Text(missingFallbackResult!, key: const ValueKey('missing_text')),
                    Text(knownKeyFallbackResult!, key: const ValueKey('known_text')),
                    Text(emptyKeyResult!, key: const ValueKey('empty_text')),
                  ],
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(hasVietnamese(missingFallbackResult!), isFalse);
      expect(missingFallbackResult, 'Adversarial Ui Missing Key');
      expect(find.text('Adversarial Ui Missing Key'), findsOneWidget);

      expect(hasVietnamese(knownKeyFallbackResult!), isFalse);
      expect(knownKeyFallbackResult, 'I am okay');
      expect(find.text('I am okay'), findsOneWidget);

      expect(hasVietnamese(emptyKeyResult!), isFalse);
      expect(emptyKeyResult, '');
    });

    testWidgets('5.2 context.tr in Japanese and German sessions sanitizes Vietnamese fallback', (tester) async {
      for (final locale in [const Locale('ja'), const Locale('de')]) {
        String? renderedResult;
        await tester.pumpWidget(
          MaterialApp(
            locale: locale,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: Scaffold(
              body: Builder(
                builder: (ctx) {
                  renderedResult = ctx.tr(
                    'non_existent_key_ui',
                    fallback: 'Chuỗi tiếng Việt rò rỉ',
                  );
                  return Text(renderedResult!);
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(hasVietnamese(renderedResult!), isFalse,
            reason: 'Locale ${locale.languageCode} leaked Vietnamese');
        expect(renderedResult, 'Non Existent Key Ui');
      }
    });

    test('5.3 Extended catalogs with enableExtendedCatalogs=true never leak Vietnamese on missing keys', () {
      AppLocalizations.enableExtendedCatalogs = true;

      final extendedSampleCodes = ['it', 'nl', 'pl', 'tr', 'is', 'cs', 'el', 'sv', 'he', 'am', 'sw', 'az'];

      for (final code in extendedSampleCodes) {
        final l10n = AppLocalizations(Locale(code));

        // Missing key with Vietnamese fallback
        final res = l10n.tr(
          'extended_catalog_missing_key_test',
          fallback: 'Tiếng Việt cấm rò rỉ',
        );

        expect(
          hasVietnamese(res),
          isFalse,
          reason: 'Extended catalog $code leaked Vietnamese: "$res"',
        );
        expect(res, 'Extended Catalog Missing Key Test');

        // Check-in button in extended catalogs should resolve either native or English, never viCatalog text
        final checkIn = l10n.tr('check_in_button');
        expect(
          checkIn,
          isNot(equals(viCatalog['check_in_button'])),
          reason: 'Extended catalog $code check_in_button leaked viCatalog text: "$checkIn"',
        );
        expect(
          checkIn,
          isNot(equals('Tôi vẫn ổn')),
          reason: 'Extended catalog $code check_in_button returned "Tôi vẫn ổn"',
        );
      }

      AppLocalizations.enableExtendedCatalogs = false;
    });
  });
}

