/// Parsing utility extracting pairing invite codes from QR payloads.
/// Supports deep link URI scheme carely://invite?code=CR-XXXXXX,
/// web URLs https://carely.app/invite?code=CR-XXXXXX, and raw codes CR-XXXXXX.
class QrCodeParser {
  static String? extractInviteCode(String? raw) {
    if (raw == null) return null;
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;

    // 1. Deep Link URI Scheme: carely://invite?code=CR-XXXXXX
    try {
      final uri = Uri.tryParse(trimmed);
      if (uri != null && uri.scheme.toLowerCase() == 'carely') {
        final codeParam = uri.queryParameters['code'];
        if (codeParam != null && codeParam.trim().isNotEmpty) {
          return codeParam.trim().toUpperCase();
        }
      }
    } catch (_) {}

    // 2. Web URL: https://carely.app/invite?code=CR-XXXXXX
    try {
      final uri = Uri.tryParse(trimmed);
      if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
        final codeParam = uri.queryParameters['code'];
        if (codeParam != null && codeParam.trim().isNotEmpty) {
          return codeParam.trim().toUpperCase();
        }
      }
    } catch (_) {}

    // 3. Regex match for standard Carely prefix: CR-[A-Z0-9]{4,16}
    final regExp = RegExp(r'(CR-[A-Z0-9]{4,16})', caseSensitive: false);
    final match = regExp.firstMatch(trimmed);
    if (match != null) {
      return match.group(1)!.toUpperCase();
    }

    // 4. Raw code fallback: Alphanumeric code with hyphens
    if (RegExp(r'^[A-Z0-9\-]{6,16}$', caseSensitive: false).hasMatch(trimmed)) {
      return trimmed.toUpperCase();
    }

    return null;
  }

  static String buildInviteUri(String code) {
    return 'carely://invite?code=${code.trim().toUpperCase()}';
  }
}
