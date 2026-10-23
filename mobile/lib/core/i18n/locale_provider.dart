import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/api_endpoints.dart';
import '../network/api_client.dart';
import '../storage/local_storage.dart';
import '../../features/auth/auth_provider.dart';
import 'app_localizations.dart';
import 'locale_catalog_registry.dart';

/// Provider managing application locale state, device auto-detection,
/// persistent storage in SharedPreferences, and asynchronous backend synchronization.
class LocaleProvider with ChangeNotifier {
  static const String prefKeyLocale = 'evernear_app_locale';
  static const String _legacyPrefKeyLocale = 'carely_app_locale';
  static const String autoDetectValue = 'auto';
  static const Locale defaultLocale = Locale('en');

  final ApiClient _apiClient = ApiClient();

  Locale _currentLocale = defaultLocale;
  bool _isDeviceDefault = false;
  bool _isInitialized = false;

  Locale get currentLocale => _currentLocale;
  bool get isDeviceDefault => _isDeviceDefault;
  bool get isInitialized => _isInitialized;

  String get currentLanguageCode => _currentLocale.languageCode;

  /// Returns metadata for the currently active language.
  LanguageMetadata get currentLanguage {
    return LocaleCatalogRegistry.findByCode(_currentLocale.languageCode) ??
        LocaleCatalogRegistry.defaultLanguage;
  }

  /// Returns display title for settings menu (e.g. "English (Auto)" or "Tiếng Việt").
  String get currentLanguageDisplayName {
    final lang = currentLanguage;
    if (_isDeviceDefault) {
      final autoLabel = AppLocalizations.staticTr('common_auto', fallback: 'Auto');
      return '${lang.nativeName} ($autoLabel)';
    }
    return lang.nativeName;
  }

  String getLanguageDisplayName(BuildContext context) {
    final lang = currentLanguage;
    if (_isDeviceDefault) {
      final autoLabel = context.tr('common_auto', fallback: 'Auto');
      return '${lang.nativeName} ($autoLabel)';
    }
    return lang.nativeName;
  }

  /// Initializes locale state on app startup.
  /// 1. Reads 'evernear_app_locale' (or legacy 'carely_app_locale') from SharedPreferences.
  /// 2. If absent, empty, or 'auto', defaults to US English ('en').
  /// 3. If explicit language code, validates against catalog or falls back to 'en'.
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final savedLocaleCode =
          prefs.getString(prefKeyLocale) ?? prefs.getString(_legacyPrefKeyLocale);

      if (savedLocaleCode == autoDetectValue) {
        _isDeviceDefault = true;
        _currentLocale = _detectDeviceLocale();
      } else if (savedLocaleCode == null || savedLocaleCode.isEmpty) {
        _isDeviceDefault = true;
        _currentLocale = defaultLocale;
      } else {
        _isDeviceDefault = false;
        if (LocaleCatalogRegistry.isSupported(savedLocaleCode)) {
          _currentLocale = Locale(savedLocaleCode);
        } else {
          _currentLocale = defaultLocale;
        }
      }
    } catch (e) {
      debugPrint('[LocaleProvider] Initialization error: $e');
      _currentLocale = defaultLocale;
      _isDeviceDefault = false;
    }

    _isInitialized = true;
    AppLocalizations.globalLocaleCode = _currentLocale.languageCode;
    notifyListeners();
  }

  /// Canonical default locale is always US English ('en').
  Locale _detectDeviceLocale() {
    return defaultLocale;
  }

  /// Sets an explicit locale, persists to SharedPreferences, syncs to backend,
  /// and immediately triggers reactive rebuild of the widget tree only if locale actually changed.
  Future<void> setLocale(Locale newLocale, {AuthProvider? authProvider}) async {
    final langCode = newLocale.languageCode.toLowerCase();
    if (!LocaleCatalogRegistry.isSupported(langCode)) {
      debugPrint('[LocaleProvider] Unsupported locale: $langCode, ignoring');
      return;
    }

    // Do nothing if already set to this locale and not in auto mode
    if (_currentLocale.languageCode == langCode && !_isDeviceDefault) {
      return;
    }

    _currentLocale = Locale(langCode);
    _isDeviceDefault = false;
    AppLocalizations.globalLocaleCode = langCode;

    // Persist to SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(prefKeyLocale, langCode);
    } catch (e) {
      debugPrint('[LocaleProvider] Failed to persist locale: $e');
    }

    // Async backend synchronization
    _syncWithBackend(langCode, authProvider: authProvider);

    notifyListeners();
  }

  /// Switches back to auto-detecting system device language.
  Future<void> setDeviceLocale({AuthProvider? authProvider}) async {
    final detected = _detectDeviceLocale();
    final alreadyAuto =
        _isDeviceDefault && _currentLocale.languageCode == detected.languageCode;

    _isDeviceDefault = true;
    _currentLocale = detected;
    AppLocalizations.globalLocaleCode = _currentLocale.languageCode;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(prefKeyLocale, autoDetectValue);
    } catch (e) {
      debugPrint('[LocaleProvider] Failed to persist auto locale: $e');
    }

    if (alreadyAuto) {
      return;
    }

    _syncWithBackend(_currentLocale.languageCode, authProvider: authProvider);

    notifyListeners();
  }

  /// Synchronizes the app's locale from the user profile returned by the backend.
  /// If [force] is true, overrides any local choice on this device.
  /// If [force] is false, respects user explicit auto-detect setting on this device.
  Future<void> syncFromUserProfile(String? backendLanguageCode, {bool force = false}) async {
    if (backendLanguageCode == null || backendLanguageCode.trim().isEmpty) return;
    final langCode = backendLanguageCode.trim().toLowerCase();
    if (!LocaleCatalogRegistry.isSupported(langCode)) return;

    if (_currentLocale.languageCode == langCode && !_isDeviceDefault) {
      return; // Already matches current active locale, skip
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final savedPref = prefs.getString(prefKeyLocale) ?? prefs.getString(_legacyPrefKeyLocale);

      // If user on this device explicitly selected auto-detect, keep it unless forced
      if (savedPref == autoDetectValue && !force) {
        return;
      }

      if (_currentLocale.languageCode != langCode || _isDeviceDefault) {
        _currentLocale = Locale(langCode);
        _isDeviceDefault = false;
        AppLocalizations.globalLocaleCode = langCode;
        await prefs.setString(prefKeyLocale, langCode);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[LocaleProvider] Error syncing locale from profile: $e');
    }
  }

  /// Non-blocking, safe synchronization of preferredLanguage with NestJS backend.
  void _syncWithBackend(String languageCode, {AuthProvider? authProvider}) async {
    try {
      if (authProvider != null && authProvider.currentUser != null) {
        if (authProvider.currentUser?.preferredLanguage == languageCode) {
          return; // Already in sync, avoid duplicate network request
        }
        authProvider.updateUserPreferredLanguage(languageCode);
      }

      final token = await LocalStorage.getAccessToken();
      final isAuth =
          (authProvider != null && authProvider.isAuthenticated) || token != null;

      if (isAuth && token != null) {
        final response = await _apiClient.dio.patch(
          ApiEndpoints.updateProfile,
          data: {'preferredLanguage': languageCode},
        );
        debugPrint('[LocaleProvider] Backend preferredLanguage updated: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('[LocaleProvider] Backend sync deferred/offline: $e');
    }
  }

  /// Explicitly synchronizes the current active locale to the authenticated user's profile and backend.
  /// Calls AuthProvider.updateUserPreferredLanguage and issues PATCH /api/v1/users/me.
  Future<void> syncCurrentLocaleToUser(AuthProvider authProvider) async {
    final langCode = _currentLocale.languageCode;
    authProvider.updateUserPreferredLanguage(langCode);

    try {
      final token = await LocalStorage.getAccessToken();
      final isAuth = authProvider.isAuthenticated || token != null;
      if (isAuth && token != null) {
        final response = await _apiClient.dio.patch(
          ApiEndpoints.updateProfile,
          data: {'preferredLanguage': langCode},
        );
        debugPrint('[LocaleProvider] Synced active locale ($langCode) to backend: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('[LocaleProvider] Error syncing locale to backend: $e');
    }
  }
}

