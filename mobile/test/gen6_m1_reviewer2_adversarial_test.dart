import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/i18n/app_localizations.dart';
import 'package:mobile/core/i18n/catalogs/catalogs.dart';

void main() {
  group('Reviewer 2 Adversarial Inspection: Missing Keys Handling', () {
    test('Unregistered keys resolve to Title Case without raw brackets or underscores', () {
      final locales = [
        const Locale('en'),
        const Locale('vi'),
        const Locale('ja'),
        const Locale('fr'),
        const Locale('de'),
        const Locale('es'),
        const Locale('zh'),
        const Locale('ar'),
      ];

      final testKeys = [
        'completely_non_existent_key_xyz',
        'auth.login.invalid_credential_error_code',
        'monitoring_device_battery_critical_sub',
        'some-dashed-key-name',
        'deeply.nested.property.path_name',
      ];

      for (final locale in locales) {
        final l10n = AppLocalizations(locale);
        for (final key in testKeys) {
          final result = l10n.tr(key);
          expect(result, isNotEmpty);
          expect(result, isNot(contains('[')));
          expect(result, isNot(contains(']')));
          expect(result, isNot(contains('_')));
          expect(result, isNot(contains('.')));
          expect(result, isNot(contains('-')));
        }

        expect(
          l10n.tr('completely_non_existent_key_xyz'),
          'Completely Non Existent Key Xyz',
        );
        expect(
          l10n.tr('auth.login.invalid_credential_error_code'),
          'Auth Login Invalid Credential Error Code',
        );
      }
    });

    test('staticTr handles missing keys identically across locales', () {
      AppLocalizations.globalLocaleCode = 'vi';
      expect(
        AppLocalizations.staticTr('missing_static_key_probe'),
        'Missing Static Key Probe',
      );

      AppLocalizations.globalLocaleCode = 'en';
      expect(
        AppLocalizations.staticTr('missing_static_key_probe'),
        'Missing Static Key Probe',
      );

      AppLocalizations.globalLocaleCode = 'ja';
      expect(
        AppLocalizations.staticTr('missing_static_key_probe'),
        'Missing Static Key Probe',
      );
    });

    test('Edge case keys: empty, spaces, punctuation, symbols', () {
      final l10n = AppLocalizations(const Locale('en'));
      expect(l10n.tr(''), '');
      expect(l10n.tr('   '), '   ');
      expect(l10n.tr('---'), '---');
      expect(l10n.tr('___'), '___');
      expect(l10n.tr('...'), '...');
      expect(l10n.tr('a'), 'A');
      expect(l10n.tr('_private_key_'), 'Private Key');
      expect(l10n.tr('multiple___underscores'), 'Multiple Underscores');
    });
  });

  group('Reviewer 2 Adversarial Inspection: Vietnamese Fallback Parameter Sanitization', () {
    test('Vietnamese fallback parameter in Vietnamese locale resolves fallback', () {
      final l10nVi = AppLocalizations(const Locale('vi'));
      expect(
        l10nVi.tr('missing_key_for_vi_fallback', fallback: 'Hủy bỏ hành động'),
        'Hủy bỏ hành động',
      );
    });

    test('Vietnamese fallback parameter in English locale is SANITIZED (zero Vietnamese leak)', () {
      final l10nEn = AppLocalizations(const Locale('en'));
      final vietnameseFallbacks = [
        'Hủy bỏ',
        'Đã lưu cài đặt',
        'Không thể kết nối',
        'Thời gian xác nhận',
        'Tôi vẫn ổn',
        'Người thân & người được ủy quyền',
        'Khung giờ hoạt động',
        'Tuyệt vời!\nBạn vẫn ổn!',
      ];

      for (final vnFallback in vietnameseFallbacks) {
        final result = l10nEn.tr('missing_test_key_sample', fallback: vnFallback);
        // Must NOT return the Vietnamese text!
        expect(
          result,
          isNot(equals(vnFallback)),
          reason: 'English locale must sanitize Vietnamese fallback: $vnFallback',
        );
        expect(
          result,
          equals('Missing Test Key Sample'),
          reason: 'English locale must fall back to Title Case key when fallback is Vietnamese',
        );
      }
    });

    test('Vietnamese fallback parameter in Japanese/French/German locales is SANITIZED', () {
      final nonEnglishLocales = [
        const Locale('ja'),
        const Locale('fr'),
        const Locale('de'),
        const Locale('es'),
        const Locale('ko'),
        const Locale('zh'),
        const Locale('ar'),
        const Locale('ru'),
      ];

      const vnFallback = 'Cài đặt thông báo & cảnh báo';

      for (final loc in nonEnglishLocales) {
        final l10n = AppLocalizations(loc);
        final result = l10n.tr('missing_setting_key_sample', fallback: vnFallback);
        expect(
          result,
          isNot(equals(vnFallback)),
          reason: 'Locale ${loc.languageCode} must never leak Vietnamese fallback',
        );
        expect(
          result,
          equals('Missing Setting Key Sample'),
          reason: 'Locale ${loc.languageCode} must resolve to Title Case key',
        );
      }
    });

    test('Clean English fallback parameter is accepted in English locale', () {
      final l10nEn = AppLocalizations(const Locale('en'));
      expect(
        l10nEn.tr('missing_action_key', fallback: 'Cancel Action'),
        'Cancel Action',
      );
      expect(
        l10nEn.tr('missing_btn_key', fallback: 'Save & Continue'),
        'Save & Continue',
      );
    });

    test('staticTr sanitizes Vietnamese fallback in non-Vietnamese locales', () {
      AppLocalizations.globalLocaleCode = 'en';
      expect(
        AppLocalizations.staticTr('missing_key_probe', fallback: 'Thông báo khẩn cấp'),
        'Missing Key Probe',
      );

      AppLocalizations.globalLocaleCode = 'ja';
      expect(
        AppLocalizations.staticTr('missing_key_probe', fallback: 'Thông báo khẩn cấp'),
        'Missing Key Probe',
      );

      AppLocalizations.globalLocaleCode = 'vi';
      expect(
        AppLocalizations.staticTr('missing_key_probe', fallback: 'Thông báo khẩn cấp'),
        'Thông báo khẩn cấp',
      );
    });
  });

  group('Reviewer 2 Adversarial Inspection: Placeholder Replacements', () {
    test('Standard placeholder replacement on existing catalog keys', () {
      final l10nEn = AppLocalizations(const Locale('en'));
      expect(
        l10nEn.tr('monitored_greeting_name', args: {'name': 'Alice'}),
        'Hello, Alice 👋',
      );
      expect(
        l10nEn.tr('incident_time_prefix', args: {'time': '14:30'}),
        'Time: 14:30',
      );
      expect(
        l10nEn.tr('account_guardians_count', args: {'count': '3'}),
        'Guardians: 3',
      );
      expect(
        l10nEn.tr('device_browser_web', args: {'platform': 'Chrome/Linux'}),
        'Web Browser (Chrome/Linux)',
      );
    });

    test('Missing placeholder argument leaves template intact without crashing', () {
      final l10nEn = AppLocalizations(const Locale('en'));
      // No args provided
      expect(
        l10nEn.tr('monitored_greeting_name'),
        'Hello, {name} 👋',
      );
      // Empty args provided
      expect(
        l10nEn.tr('monitored_greeting_name', args: {}),
        'Hello, {name} 👋',
      );
      // Irrelevant args provided
      expect(
        l10nEn.tr('monitored_greeting_name', args: {'wrong_arg': 'Alice'}),
        'Hello, {name} 👋',
      );
    });

    test('Partial placeholder replacements in multi-placeholder strings', () {
      final l10n = AppLocalizations(const Locale('en'));
      // Custom formatted key with 2 placeholders
      expect(
        l10n.tr('user_{name}_logged_in_at_{time}', args: {'name': 'Bob'}),
        'User Bob Logged In At {time}',
      );
      expect(
        l10n.tr('user_{name}_logged_in_at_{time}', args: {'time': '09:00'}),
        'User {name} Logged In At 09:00',
      );
      expect(
        l10n.tr('user_{name}_logged_in_at_{time}', args: {'name': 'Bob', 'time': '09:00'}),
        'User Bob Logged In At 09:00',
      );
    });

    test('Placeholder replacement with special characters and symbols', () {
      final l10n = AppLocalizations(const Locale('en'));
      const trickyValues = [
        r'$100 & 50%',
        r'\n \t \r',
        '<script>alert("xss")</script>',
        'O\'Connor & "Smith"',
        'Emojis 🌟🔥🚀',
        '',
      ];

      for (final val in trickyValues) {
        final result = l10n.tr('monitored_greeting_name', args: {'name': val});
        expect(result, 'Hello, $val 👋');
      }
    });

    test('Large payload placeholder replacement stress test', () {
      final l10n = AppLocalizations(const Locale('en'));
      final longString = 'A' * 10000;
      final result = l10n.tr('monitored_greeting_name', args: {'name': longString});
      expect(result.length, 10000 + 'Hello,  👋'.length);
      expect(result.startsWith('Hello, AAA'), isTrue);
    });
  });

  group('Reviewer 2 Adversarial Inspection: Integrity & Parity Audit', () {
    test('100% 1-to-1 key parity between viCatalog and enCatalog', () {
      final viKeys = viCatalog.keys.toSet();
      final enKeys = enCatalog.keys.toSet();

      expect(viKeys.length, equals(705));
      expect(enKeys.length, equals(705));
      expect(viKeys.difference(enKeys), isEmpty);
      expect(enKeys.difference(viKeys), isEmpty);
    });

    test('Zero Vietnamese diacritics in enCatalog across all 705 entries', () {
      final vnRegex = RegExp(
        r'[àáảãạăằắẳẵặâầấẩẫậđèéẻẽẹêềếểễệìíỉĩịòóỏõọôồốổỗộơờớởỡợùúủũụưừứửữựỳýỷỹỵ'
        r'ÀÁẢÃẠĂẰẮẲẴẶÂẦẤẨẪẬĐÈÉẺẸÊỀẾỂỄỆÌÍỈĨỊÒÓỎÕỌÔỒỐỔỖỘƠỜỚỞỠỢÙÚỦŨỤƯỪỨỬỮỰỲÝỶỸỴ]',
      );

      for (final entry in enCatalog.entries) {
        expect(
          vnRegex.hasMatch(entry.value),
          isFalse,
          reason: 'Key "${entry.key}" in enCatalog contains Vietnamese characters: "${entry.value}"',
        );
      }
    });

    test('Non-Vietnamese locale NEVER evaluates viCatalog even when key is missing in Tier 1', () {
      // Create a test where key is missing from enCatalog AND active locale is 'ja'
      // It must return Title Case key, NEVER viCatalog value
      final l10nJa = AppLocalizations(const Locale('ja'));
      expect(
        l10nJa.tr('untranslated_secret_feature'),
        'Untranslated Secret Feature',
      );
    });
  });
}
