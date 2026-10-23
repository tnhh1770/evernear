import 'dart:ui' show Locale;

/// Locale Catalog Registry for Evernear
///
/// Contains comprehensive metadata for 60 world languages with
/// fast diacritic-insensitive and case-insensitive search.
class LanguageMetadata {
  final String code; // ISO 639-1 code (e.g., 'vi', 'en', 'fr')
  final String nativeName; // e.g., 'Tiếng Việt', 'English', 'Français'
  final String englishName; // e.g., 'Vietnamese', 'English', 'French'
  final String countryCode; // ISO 3166-1 alpha-2 country code (e.g., 'US', 'VN')
  final String flagEmoji; // Unicode flag emoji
  final bool isRtl; // Right-to-Left indicator
  final bool isTier1; // True for pre-bundled translation catalogs

  const LanguageMetadata({
    required this.code,
    required this.nativeName,
    required this.englishName,
    required this.flagEmoji,
    this.countryCode = 'US',
    this.isRtl = false,
    this.isTier1 = false,
  });

  /// Compatibility alias for flag emoji
  String get flag => flagEmoji;

  @override
  String toString() => '$flagEmoji $nativeName ($englishName) [$code]';
}

/// Type alias ensuring cross-compatibility
typedef SupportedLanguage = LanguageMetadata;

class LocaleCatalogRegistry {
  LocaleCatalogRegistry._();

  /// 60 World Languages catalog
  static const List<LanguageMetadata> allLanguages = [
    // --- Tier 1 Languages (Pre-bundled full catalogs) ---
    LanguageMetadata(
      code: 'en',
      nativeName: 'English',
      englishName: 'English',
      countryCode: 'US',
      flagEmoji: '🇺🇸',
      isTier1: true,
    ),
    LanguageMetadata(
      code: 'vi',
      nativeName: 'Tiếng Việt',
      englishName: 'Vietnamese',
      countryCode: 'VN',
      flagEmoji: '🇻🇳',
      isTier1: true,
    ),
    LanguageMetadata(
      code: 'fr',
      nativeName: 'Français',
      englishName: 'French',
      countryCode: 'FR',
      flagEmoji: '🇫🇷',
      isTier1: true,
    ),
    LanguageMetadata(
      code: 'de',
      nativeName: 'Deutsch',
      englishName: 'German',
      countryCode: 'DE',
      flagEmoji: '🇩🇪',
      isTier1: true,
    ),
    LanguageMetadata(
      code: 'es',
      nativeName: 'Español',
      englishName: 'Spanish',
      countryCode: 'ES',
      flagEmoji: '🇪🇸',
      isTier1: true,
    ),
    LanguageMetadata(
      code: 'pt',
      nativeName: 'Português',
      englishName: 'Portuguese',
      countryCode: 'PT',
      flagEmoji: '🇵🇹',
      isTier1: true,
    ),
    LanguageMetadata(
      code: 'ru',
      nativeName: 'Русский',
      englishName: 'Russian',
      countryCode: 'RU',
      flagEmoji: '🇷🇺',
      isTier1: true,
    ),
    LanguageMetadata(
      code: 'ja',
      nativeName: '日本語',
      englishName: 'Japanese',
      countryCode: 'JP',
      flagEmoji: '🇯🇵',
      isTier1: true,
    ),
    LanguageMetadata(
      code: 'ko',
      nativeName: '한국어',
      englishName: 'Korean',
      countryCode: 'KR',
      flagEmoji: '🇰🇷',
      isTier1: true,
    ),
    LanguageMetadata(
      code: 'zh',
      nativeName: '简体中文',
      englishName: 'Chinese (Simplified)',
      countryCode: 'CN',
      flagEmoji: '🇨🇳',
      isTier1: true,
    ),
    LanguageMetadata(
      code: 'th',
      nativeName: 'ไทย',
      englishName: 'Thai',
      countryCode: 'TH',
      flagEmoji: '🇹🇭',
      isTier1: true,
    ),
    LanguageMetadata(
      code: 'id',
      nativeName: 'Bahasa Indonesia',
      englishName: 'Indonesian',
      countryCode: 'ID',
      flagEmoji: '🇮🇩',
      isTier1: true,
    ),
    LanguageMetadata(
      code: 'ar',
      nativeName: 'العربية',
      englishName: 'Arabic',
      countryCode: 'SA',
      flagEmoji: '🇸🇦',
      isRtl: true,
      isTier1: true,
    ),
    LanguageMetadata(
      code: 'hi',
      nativeName: 'हिन्दी',
      englishName: 'Hindi',
      countryCode: 'IN',
      flagEmoji: '🇮🇳',
      isTier1: true,
    ),

    // --- Tier 2 World Languages (Resolved via Safe Fallback Engine) ---
    LanguageMetadata(code: 'it', nativeName: 'Italiano', englishName: 'Italian', countryCode: 'IT', flagEmoji: '🇮🇹'),
    LanguageMetadata(code: 'nl', nativeName: 'Nederlands', englishName: 'Dutch', countryCode: 'NL', flagEmoji: '🇳🇱'),
    LanguageMetadata(code: 'pl', nativeName: 'Polski', englishName: 'Polish', countryCode: 'PL', flagEmoji: '🇵🇱'),
    LanguageMetadata(code: 'tr', nativeName: 'Türkçe', englishName: 'Turkish', countryCode: 'TR', flagEmoji: '🇹🇷'),
    LanguageMetadata(code: 'uk', nativeName: 'Українська', englishName: 'Ukrainian', countryCode: 'UA', flagEmoji: '🇺🇦'),
    LanguageMetadata(code: 'el', nativeName: 'Ελληνικά', englishName: 'Greek', countryCode: 'GR', flagEmoji: '🇬🇷'),
    LanguageMetadata(code: 'sv', nativeName: 'Svenska', englishName: 'Swedish', countryCode: 'SE', flagEmoji: '🇸🇪'),
    LanguageMetadata(code: 'no', nativeName: 'Norsk', englishName: 'Norwegian', countryCode: 'NO', flagEmoji: '🇳🇴'),
    LanguageMetadata(code: 'da', nativeName: 'Dansk', englishName: 'Danish', countryCode: 'DK', flagEmoji: '🇩🇰'),
    LanguageMetadata(code: 'fi', nativeName: 'Suomi', englishName: 'Finnish', countryCode: 'FI', flagEmoji: '🇫🇮'),
    LanguageMetadata(code: 'cs', nativeName: 'Čeština', englishName: 'Czech', countryCode: 'CZ', flagEmoji: '🇨🇿'),
    LanguageMetadata(code: 'hu', nativeName: 'Magyar', englishName: 'Hungarian', countryCode: 'HU', flagEmoji: '🇭🇺'),
    LanguageMetadata(code: 'ro', nativeName: 'Română', englishName: 'Romanian', countryCode: 'RO', flagEmoji: '🇷🇴'),
    LanguageMetadata(code: 'bg', nativeName: 'Български', englishName: 'Bulgarian', countryCode: 'BG', flagEmoji: '🇧🇬'),
    LanguageMetadata(code: 'hr', nativeName: 'Hrvatski', englishName: 'Croatian', countryCode: 'HR', flagEmoji: '🇭🇷'),
    LanguageMetadata(code: 'sr', nativeName: 'Српски', englishName: 'Serbian', countryCode: 'RS', flagEmoji: '🇷🇸'),
    LanguageMetadata(code: 'sk', nativeName: 'Slovenčina', englishName: 'Slovak', countryCode: 'SK', flagEmoji: '🇸🇰'),
    LanguageMetadata(code: 'sl', nativeName: 'Slovenščina', englishName: 'Slovenian', countryCode: 'SI', flagEmoji: '🇸🇮'),
    LanguageMetadata(code: 'lt', nativeName: 'Lietuvių', englishName: 'Lithuanian', countryCode: 'LT', flagEmoji: '🇱🇹'),
    LanguageMetadata(code: 'lv', nativeName: 'Latviešu', englishName: 'Latvian', countryCode: 'LV', flagEmoji: '🇱🇻'),
    LanguageMetadata(code: 'et', nativeName: 'Eesti', englishName: 'Estonian', countryCode: 'EE', flagEmoji: '🇪🇪'),
    LanguageMetadata(code: 'he', nativeName: 'עברית', englishName: 'Hebrew', countryCode: 'IL', flagEmoji: '🇮🇱', isRtl: true),
    LanguageMetadata(code: 'fa', nativeName: 'فارسی', englishName: 'Persian', countryCode: 'IR', flagEmoji: '🇮🇷', isRtl: true),
    LanguageMetadata(code: 'ur', nativeName: 'اردو', englishName: 'Urdu', countryCode: 'PK', flagEmoji: '🇵🇰', isRtl: true),
    LanguageMetadata(code: 'bn', nativeName: 'বাংলা', englishName: 'Bengali', countryCode: 'BD', flagEmoji: '🇧🇩'),
    LanguageMetadata(code: 'ta', nativeName: 'தமிழ்', englishName: 'Tamil', countryCode: 'IN', flagEmoji: '🇮🇳'),
    LanguageMetadata(code: 'te', nativeName: 'తెలుగు', englishName: 'Telugu', countryCode: 'IN', flagEmoji: '🇮🇳'),
    LanguageMetadata(code: 'mr', nativeName: 'मराठी', englishName: 'Marathi', countryCode: 'IN', flagEmoji: '🇮🇳'),
    LanguageMetadata(code: 'ms', nativeName: 'Bahasa Melayu', englishName: 'Malay', countryCode: 'MY', flagEmoji: '🇲🇾'),
    LanguageMetadata(code: 'tl', nativeName: 'Tagalog', englishName: 'Filipino', countryCode: 'PH', flagEmoji: '🇵🇭'),
    LanguageMetadata(code: 'my', nativeName: 'မြန်မာ', englishName: 'Burmese', countryCode: 'MM', flagEmoji: '🇲🇲'),
    LanguageMetadata(code: 'km', nativeName: 'ខ្មែរ', englishName: 'Khmer', countryCode: 'KH', flagEmoji: '🇰🇭'),
    LanguageMetadata(code: 'lo', nativeName: 'ລາວ', englishName: 'Lao', countryCode: 'LA', flagEmoji: '🇱🇦'),
    LanguageMetadata(code: 'am', nativeName: 'አማርኛ', englishName: 'Amharic', countryCode: 'ET', flagEmoji: '🇪🇹'),
    LanguageMetadata(code: 'sw', nativeName: 'Kiswahili', englishName: 'Swahili', countryCode: 'KE', flagEmoji: '🇰🇪'),
    LanguageMetadata(code: 'af', nativeName: 'Afrikaans', englishName: 'Afrikaans', countryCode: 'ZA', flagEmoji: '🇿🇦'),
    LanguageMetadata(code: 'ca', nativeName: 'Català', englishName: 'Catalan', countryCode: 'AD', flagEmoji: '🇦🇩'),
    LanguageMetadata(code: 'eu', nativeName: 'Euskara', englishName: 'Basque', countryCode: 'ES', flagEmoji: '🇪🇸'),
    LanguageMetadata(code: 'gl', nativeName: 'Galego', englishName: 'Galician', countryCode: 'ES', flagEmoji: '🇪🇸'),
    LanguageMetadata(code: 'is', nativeName: 'Íslenska', englishName: 'Icelandic', countryCode: 'IS', flagEmoji: '🇮🇸'),
    LanguageMetadata(code: 'ga', nativeName: 'Gaeilge', englishName: 'Irish', countryCode: 'IE', flagEmoji: '🇮🇪'),
    LanguageMetadata(code: 'cy', nativeName: 'Cymraeg', englishName: 'Welsh', countryCode: 'GB', flagEmoji: '🇬🇧'),
    LanguageMetadata(code: 'mn', nativeName: 'Монгол', englishName: 'Mongolian', countryCode: 'MN', flagEmoji: '🇲🇳'),
    LanguageMetadata(code: 'kk', nativeName: 'Қазақша', englishName: 'Kazakh', countryCode: 'KZ', flagEmoji: '🇰🇿'),
    LanguageMetadata(code: 'uz', nativeName: 'Oʻzbekcha', englishName: 'Uzbek', countryCode: 'UZ', flagEmoji: '🇺🇿'),
    LanguageMetadata(code: 'az', nativeName: 'Azərbaycan', englishName: 'Azerbaijani', countryCode: 'AZ', flagEmoji: '🇦🇿'),
  ];

  /// Tier-1 languages with pre-bundled dictionaries
  static List<LanguageMetadata> get tier1Languages =>
      allLanguages.where((l) => l.isTier1).toList(growable: false);

  /// Canonical default language (US English)
  static LanguageMetadata get defaultLanguage =>
      getByCode('en') ?? allLanguages.first;

  /// Supported locales list for MaterialApp
  static List<Locale> get supportedLocales =>
      allLanguages.map((l) => Locale(l.code)).toList(growable: false);

  /// Find language by code (e.g., 'vi', 'en', 'fr', 'fil' -> 'tl')
  static LanguageMetadata? getByCode(String? code) {
    if (code == null) return null;
    var lower = code.toLowerCase().trim();
    if (lower == 'fil') {
      lower = 'tl';
    }
    for (final lang in allLanguages) {
      if (lang.code.toLowerCase() == lower) return lang;
    }
    return null;
  }

  /// Alias for getByCode
  static LanguageMetadata? findByCode(String? code) => getByCode(code);

  /// Check if a language code is supported
  static bool isSupported(String? code) => getByCode(code) != null;

  /// Check if a language code is Tier-1
  static bool isTier1(String? code) => getByCode(code)?.isTier1 ?? false;

  /// Fast diacritic-insensitive and case-insensitive search
  static List<LanguageMetadata> search(String query) {
    if (query.trim().isEmpty) return allLanguages;
    final normalizedQuery = normalizeDiacritics(query.trim().toLowerCase());

    return allLanguages.where((lang) {
      if (lang.code.toLowerCase().contains(normalizedQuery)) return true;
      final normNative = normalizeDiacritics(lang.nativeName.toLowerCase());
      if (normNative.contains(normalizedQuery)) return true;
      final normEnglish = normalizeDiacritics(lang.englishName.toLowerCase());
      if (normEnglish.contains(normalizedQuery)) return true;
      return false;
    }).toList(growable: false);
  }

  /// High-performance diacritic stripper supporting Vietnamese and European alphabets
  static String normalizeDiacritics(String text) {
    var result = text;
    // Vietnamese vowels
    result = result.replaceAll(RegExp(r'[àáạảãâầấậẩẫăằắặẳẵ]'), 'a');
    result = result.replaceAll(RegExp(r'[ÀÁẠẢÃÂẦẤẬẨẪĂẰẮẶẲẴ]'), 'A');
    result = result.replaceAll(RegExp(r'[èéẹẻẽêềếệểễ]'), 'e');
    result = result.replaceAll(RegExp(r'[ÈÉẸẺẼÊỀẾỆỂỄ]'), 'E');
    result = result.replaceAll(RegExp(r'[ìíịỉĩ]'), 'i');
    result = result.replaceAll(RegExp(r'[ÌÍỊỈĨ]'), 'I');
    result = result.replaceAll(RegExp(r'[òóọỏõôồốộổỗơờớợởỡ]'), 'o');
    result = result.replaceAll(RegExp(r'[ÒÓỌỎÕÔỒỐỘỔỖƠỜỚỢỞỠ]'), 'O');
    result = result.replaceAll(RegExp(r'[ùúụủũưừứựửữ]'), 'u');
    result = result.replaceAll(RegExp(r'[ÙÚỤỦŨƯỪỨỰỬỮ]'), 'U');
    result = result.replaceAll(RegExp(r'[ỳýỵỷỹ]'), 'y');
    result = result.replaceAll(RegExp(r'[ỲÝỴỶỸ]'), 'Y');
    result = result.replaceAll(RegExp(r'[đ]'), 'd');
    result = result.replaceAll(RegExp(r'[Đ]'), 'D');

    // European accents & umlauts
    result = result.replaceAll(RegExp(r'[äáàâãåāą]'), 'a');
    result = result.replaceAll(RegExp(r'[ÄÁÀÂÃÅĀĄ]'), 'A');
    result = result.replaceAll(RegExp(r'[çćč]'), 'c');
    result = result.replaceAll(RegExp(r'[ÇĆČ]'), 'C');
    result = result.replaceAll(RegExp(r'[éèêëēęě]'), 'e');
    result = result.replaceAll(RegExp(r'[ÉÈÊËĒĘĚ]'), 'E');
    result = result.replaceAll(RegExp(r'[ïîíìī]'), 'i');
    result = result.replaceAll(RegExp(r'[ÏÎÍÌĪ]'), 'I');
    result = result.replaceAll(RegExp(r'[ñńň]'), 'n');
    result = result.replaceAll(RegExp(r'[ÑŃŇ]'), 'N');
    result = result.replaceAll(RegExp(r'[öóòôõøō]'), 'o');
    result = result.replaceAll(RegExp(r'[ÖÓÒÔÕØŌ]'), 'O');
    result = result.replaceAll(RegExp(r'[üúùûūů]'), 'u');
    result = result.replaceAll(RegExp(r'[ÜÚÙÛŪŮ]'), 'U');
    result = result.replaceAll(RegExp(r'[ß]'), 'ss');
    result = result.replaceAll(RegExp(r'[æ]'), 'ae');
    result = result.replaceAll(RegExp(r'[œ]'), 'oe');
    return result;
  }
}
