import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import '../i18n/app_localizations.dart';

/// Centralized translator resolving backend HTTP responses, DioExceptions,
/// and raw error strings into localized, user-friendly messages for the active locale.
class ApiErrorTranslator {
  ApiErrorTranslator._();

  /// Identifies the corresponding i18n translation key from an error object.
  static String toKey(dynamic error) {
    if (error == null) return 'common_error_unknown';

    if (error is DioException) {
      // 1. Network connectivity / Timeout issues
      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.sendTimeout ||
          error.type == DioExceptionType.receiveTimeout ||
          error.type == DioExceptionType.connectionError) {
        return 'common_network_error';
      }

      final statusCode = error.response?.statusCode;
      final resData = error.response?.data;
      String rawMsg = '';

      if (resData is Map) {
        final msgField = resData['message'];
        if (msgField is List) {
          rawMsg = msgField.join(', ');
        } else if (msgField != null) {
          rawMsg = msgField.toString();
        } else if (resData['error'] != null) {
          rawMsg = resData['error'].toString();
        }
      } else if (resData is String) {
        rawMsg = resData;
      }

      final msgLower = rawMsg.toLowerCase();

      // 2. Specific status codes & message matching
      if (statusCode == 409) {
        if (msgLower.contains('phone')) return 'auth_error_phone_exists';
        if (msgLower.contains('email')) return 'auth_error_email_exists';
        if (msgLower.contains('accepted')) return 'invite_error_already_accepted';
        if (msgLower.contains('relationship')) return 'invite_error_relationship_exists';
        return 'auth_error_register_failed';
      }

      if (statusCode == 401) {
        if (msgLower.contains('password') || msgLower.contains('mật khẩu')) {
          return 'account_error_password_incorrect';
        }
        return 'auth_error_invalid_credentials';
      }

      if (statusCode == 400) {
        if (msgLower.contains('social') || msgLower.contains('mạng xã hội')) {
          return 'account_error_social_no_password';
        }
        if (msgLower.contains('expired') || msgLower.contains('hết hạn')) {
          return 'invite_error_expired';
        }
        if (msgLower.contains('own') || msgLower.contains('chính mình')) {
          return 'invite_error_self';
        }
        if (msgLower.contains('invitation') || msgLower.contains('mã')) {
          return 'invite_error_invalid';
        }
      }

      if (statusCode == 404) {
        if (msgLower.contains('invitation') || msgLower.contains('mã') || msgLower.contains('code')) {
          return 'invite_error_invalid';
        }
        if (msgLower.contains('user')) return 'common_user_not_found';
        return 'common_not_found';
      }

      if (statusCode != null && statusCode >= 500) {
        return 'common_server_error';
      }

      // Check message content directly if present
      final matched = _matchStringPattern(rawMsg);
      if (matched != null) return matched;
    }

    if (error is String) {
      final matched = _matchStringPattern(error);
      if (matched != null) return matched;
    }

    return 'common_retry';
  }

  static String? _matchStringPattern(String raw) {
    final lower = raw.toLowerCase().trim();
    if (lower.contains('phone number already') || lower.contains('số điện thoại này đã')) {
      return 'auth_error_phone_exists';
    }
    if (lower.contains('email already') || lower.contains('email đã được')) {
      return 'auth_error_email_exists';
    }
    if (lower.contains('invalid credentials') || lower.contains('sai thông tin') || lower.contains('thông tin đăng nhập')) {
      return 'auth_error_invalid_credentials';
    }
    if (lower.contains('current password is incorrect') || lower.contains('mật khẩu hiện tại không')) {
      return 'account_error_password_incorrect';
    }
    if (lower.contains('social') || lower.contains('mạng xã hội')) {
      return 'account_error_social_no_password';
    }
    if (lower.contains('expired') || lower.contains('hết hạn')) {
      return 'invite_error_expired';
    }
    if (lower.contains('already been accepted') || lower.contains('đã được chấp nhận')) {
      return 'invite_error_already_accepted';
    }
    if (lower.contains('own invitation') || lower.contains('chính mình')) {
      return 'invite_error_self';
    }
    if (lower.contains('relationship') && lower.contains('already exists')) {
      return 'invite_error_relationship_exists';
    }
    if (lower.contains('invitation code not found') || lower.contains('mã kết nối không hợp lệ')) {
      return 'invite_error_invalid';
    }
    if (lower.contains('user not found') || lower.contains('không tìm thấy người dùng')) {
      return 'common_user_not_found';
    }
    return null;
  }

  /// Translates error into user-facing localized text for the currently active language.
  static String translate(
    dynamic error, {
    BuildContext? context,
    String? fallback,
  }) {
    final key = toKey(error);
    if (context != null) {
      return context.tr(key, fallback: fallback);
    }
    return AppLocalizations.staticTr(key, fallback: fallback);
  }
}
