import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'catalogs/catalogs.dart';

/// AppLocalizations provides runtime localized string resolution with a
/// 4-tier safe fallback engine guaranteeing zero raw keys and zero exceptions.
class AppLocalizations {
  final Locale locale;
  final Map<String, String> _activeDictionary;

  /// When true, allows accessing all 60 world languages from extendedCatalogs
  static bool _enableExtendedCatalogs = true;
  static bool get enableExtendedCatalogs => _enableExtendedCatalogs;
  static set enableExtendedCatalogs(bool value) {
    if (_enableExtendedCatalogs != value) {
      _enableExtendedCatalogs = value;
      _dictionaryCache.clear();
      _cachedLanguageCode = null;
      _currentActiveDictionary = null;
    }
  }

  /// Canonical default global language code for static standalone lookups
  static String globalLocaleCode = 'en';

  /// In-memory cache preserving loaded translation catalogs so each language
  /// dictionary is loaded once and reused across all instances.
  static final Map<String, Map<String, String>> _dictionaryCache = {};
  static String? _cachedLanguageCode;
  static Map<String, String>? _currentActiveDictionary;

  AppLocalizations(this.locale)
      : _activeDictionary = _resolveAndCacheDictionary(locale.languageCode);

  /// Resolves the dictionary for [rawCode], caching it in memory so it is only loaded once.
  static Map<String, String> _resolveAndCacheDictionary(String rawCode) {
    final code = rawCode.toLowerCase();
    if (_cachedLanguageCode == code && _currentActiveDictionary != null) {
      return _currentActiveDictionary!;
    }
    if (_dictionaryCache.containsKey(code)) {
      _cachedLanguageCode = code;
      _currentActiveDictionary = _dictionaryCache[code]!;
      return _currentActiveDictionary!;
    }
    final dict = (enableExtendedCatalogs
            ? DynamicCatalogs.getAnyCatalog(code)
            : DynamicCatalogs.getCatalog(code)) ??
        const {};
    _dictionaryCache[code] = dict;
    _cachedLanguageCode = code;
    _currentActiveDictionary = dict;
    return dict;
  }

  /// Access AppLocalizations from BuildContext
  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  /// Global delegate for MaterialApp
  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static final RegExp _vietnameseDiacritics = RegExp(
    r'[àáảãạăằắẳẵặâầấẩẫậđèéẻẽẹêềếểễệìíỉĩịòóỏõọôồốổỗộơờớởỡợùúủũụưừứửữựỳýỷỹỵ'
    r'ÀÁẢÃẠĂẰẮẲẴẶÂẦẤẨẪẬĐÈÉẺẸÊỀẾỂỄỆÌÍỈĨỊÒÓỎÕỌÔỒỐỔỖỘƠỜỚỞỠỢÙÚỦŨỤƯỪỨỬỮỰỲÝỶỸỴ]',
  );

  static bool _hasVietnamese(String text) => _vietnameseDiacritics.hasMatch(text);

  static const Map<String, String> _supplementalEn = {
    'account_not_updated': 'Not updated',
    'auth_name_required': 'Please enter your full name.',
    'guardian_check_in_required': 'Check-in required now',
    'monitoring_reminder_preset_2': '2 times (08:00, 20:00)',
    'monitoring_reminder_preset_3': '3 times (09:00, 15:00, 20:00)',
    'monitoring_reminder_preset_4': '4 times (08:00, 12:00, 16:00, 20:00)',
    'relative_detail_copy_phone_tooltip': 'Copy phone number',
    'relative_detail_phone_copied': 'Copied phone number {phone}',
  };

  /// Primary translation resolver
  ///
  /// Resolution Chain:
  /// 1. When current locale is 'vi': _activeDictionary[key] ?? viCatalog[key] ?? fallback
  /// 2. When current locale is NOT 'vi': _activeDictionary[key] ?? enCatalog[key] ?? (isEnglish ? fallback : null) ?? formatKeyName(key)
  /// Non-Vietnamese locales NEVER evaluate viCatalog[key].
  String tr(
    String key, {
    Map<String, String>? args,
    String? fallback,
  }) {
    final code = locale.languageCode.toLowerCase();
    final isVietnamese = code == 'vi';
    final isEnglish = code == 'en';

    String? value = _activeDictionary[key];

    if (isVietnamese) {
      value ??= viCatalog[key] ?? fallback;
    } else {
      final safeFallback =
          (isEnglish && fallback != null && !_hasVietnamese(fallback))
              ? fallback
              : null;
      value ??= enCatalog[key] ?? _supplementalEn[key] ?? safeFallback;
    }

    value ??= formatKeyName(key);

    // Interpolate arguments if provided
    if (args != null && args.isNotEmpty) {
      args.forEach((placeholder, replacement) {
        value = value!.replaceAll('{$placeholder}', replacement);
      });
    }

    return value!;
  }

  /// Static lookup engine for environments without BuildContext or unwrapped tests
  static String staticTr(
    String key, {
    Map<String, String>? args,
    String? fallback,
  }) {
    final code = globalLocaleCode.toLowerCase();
    final isVietnamese = code == 'vi';
    final isEnglish = code == 'en';

    final active = _resolveAndCacheDictionary(globalLocaleCode);
    String? value = active[key];

    if (isVietnamese) {
      value ??= viCatalog[key] ?? fallback;
    } else {
      final safeFallback =
          (isEnglish && fallback != null && !_hasVietnamese(fallback))
              ? fallback
              : null;
      value ??= enCatalog[key] ?? _supplementalEn[key] ?? safeFallback;
    }

    value ??= formatKeyName(key);

    if (args != null && args.isNotEmpty) {
      args.forEach((placeholder, replacement) {
        value = value!.replaceAll('{$placeholder}', replacement);
      });
    }

    return value!;
  }

  /// Helper looking up US English canonical default
  static String lookupDefault(String key) {
    return enCatalog[key] ?? viCatalog[key] ?? formatKeyName(key);
  }

  /// Transforms raw keys (e.g., 'check_in_button', 'auth.email.label')
  /// into pleasant, human-readable Title Case strings.
  /// Guarantees ZERO '[raw_key]' syntax ever reaches the UI.
  static String formatKeyName(String key) {
    if (key.isEmpty) return '';
    final cleaned = key.replaceAll(RegExp(r'[_.-]+'), ' ').trim();
    if (cleaned.isEmpty) return key;

    return cleaned.split(' ').map((word) {
      if (word.isEmpty) return '';
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }
}

/// Synchronous delegate preventing async flash of unlocalized content
class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => true; // All locales supported via fallback!

  @override
  Future<AppLocalizations> load(Locale locale) {
    AppLocalizations.globalLocaleCode = locale.languageCode;
    return SynchronousFuture<AppLocalizations>(AppLocalizations(locale));
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

/// Extension providing effortless `context.tr(key)` syntax
extension LocalizationContextExtension on BuildContext {
  /// Translates key with safe fallback for unwrapped widget test environments
  String tr(
    String key, {
    Map<String, String>? args,
    String? fallback,
  }) {
    final l10n = AppLocalizations.of(this);
    if (l10n != null) {
      return l10n.tr(key, args: args, fallback: fallback);
    }
    // Unwrapped test widget or missing delegate -> Use staticTr
    return AppLocalizations.staticTr(key, args: args, fallback: fallback);
  }
}
