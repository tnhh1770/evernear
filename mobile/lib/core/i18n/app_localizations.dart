import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'catalogs/catalogs.dart';

/// AppLocalizations provides runtime localized string resolution with a
/// 4-tier safe fallback engine guaranteeing zero raw keys and zero exceptions.
class AppLocalizations {
  final Locale locale;
  final Map<String, String> _activeDictionary;

  /// When true, allows accessing all 60 world languages from extendedCatalogs
  static bool enableExtendedCatalogs = false;

  AppLocalizations(this.locale)
      : _activeDictionary = (enableExtendedCatalogs
                ? DynamicCatalogs.getAnyCatalog(locale.languageCode)
                : DynamicCatalogs.getCatalog(locale.languageCode)) ??
            const {};

  /// Access AppLocalizations from BuildContext
  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  /// Global delegate for MaterialApp
  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// Canonical default global language code for static standalone lookups
  static String globalLocaleCode = 'vi';

  /// Primary translation resolver
  ///
  /// Resolution Chain:
  /// 1. Active dictionary (_activeDictionary[key])
  /// 2. English catalog (enCatalog[key])
  /// 3. Vietnamese baseline catalog (viCatalog[key])
  /// 4. Explicit fallback string (if provided)
  /// 5. Humanized key name (e.g., 'check_in_button' -> 'Check In Button')
  String tr(
    String key, {
    Map<String, String>? args,
    String? fallback,
  }) {
    String? value = _activeDictionary[key];

    // Tier 2: English fallback
    value ??= enCatalog[key];

    // Tier 3: Vietnamese canonical baseline
    value ??= viCatalog[key];

    // Tier 4: Provided fallback or formatted key name
    value ??= fallback ?? formatKeyName(key);

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
    final active = enableExtendedCatalogs
        ? DynamicCatalogs.getAnyCatalog(globalLocaleCode)
        : DynamicCatalogs.getCatalog(globalLocaleCode);
    String? value = active?[key];

    // If global is not English/Vietnamese, cascade through en then vi
    value ??= enCatalog[key];
    value ??= viCatalog[key];
    value ??= fallback ?? formatKeyName(key);

    if (args != null && args.isNotEmpty) {
      args.forEach((placeholder, replacement) {
        value = value!.replaceAll('{$placeholder}', replacement);
      });
    }

    return value!;
  }

  /// Helper looking up Vietnamese canonical default
  static String lookupDefault(String key) {
    return viCatalog[key] ?? enCatalog[key] ?? formatKeyName(key);
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
  bool shouldReload(_AppLocalizationsDelegate old) => true;
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
