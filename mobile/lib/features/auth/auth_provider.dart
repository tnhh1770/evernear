import 'dart:io' show Platform;
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import '../../core/constants/api_endpoints.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/models/enums.dart';
import '../../core/models/user_model.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_error_translator.dart';
import '../../core/network/realtime_service.dart';
import '../../core/services/activity_tracker_service.dart';
import '../../core/services/fcm_service.dart';
import '../../core/services/heartbeat_service.dart';
import '../../core/storage/local_storage.dart';

class AuthProvider with ChangeNotifier {
  final ApiClient _apiClient = ApiClient();

  UserModel? _currentUser;
  bool _isAuthenticated = false;
  bool _isLoading = false;
  String? _errorMessage;
  String? _errorMessageKey;

  UserModel? get currentUser => _currentUser;
  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;
  String? get errorMessageKey => _errorMessageKey;
  String? get errorMessage {
    if (_errorMessageKey != null) {
      return AppLocalizations.staticTr(_errorMessageKey!, fallback: _errorMessage);
    }
    return _errorMessage;
  }

  String? getErrorMessage(BuildContext context) {
    if (_errorMessageKey != null) {
      return context.tr(_errorMessageKey!, fallback: _errorMessage);
    }
    return _errorMessage;
  }

  void _setError(String key, {String? fallback}) {
    _errorMessageKey = key;
    _errorMessage = fallback;
  }

  void _clearError() {
    _errorMessageKey = null;
    _errorMessage = null;
  }

  Future<bool> checkAuthStatus() async {
    _isLoading = true;
    notifyListeners();

    try {
      final token = await LocalStorage.getAccessToken();
      if (token == null) {
        _isAuthenticated = false;
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // 1. Immediately restore cached user profile so session isn't lost on network delays or restarts
      final cachedProfile = await LocalStorage.getUserProfile();
      if (cachedProfile != null) {
        _currentUser = cachedProfile;
        _isAuthenticated = true;
      }

      // 2. Fetch fresh user profile from backend
      try {
        final response = await _apiClient.dio.get(ApiEndpoints.profile);
        if (response.statusCode == 200) {
          _currentUser = UserModel.fromJson(response.data);
          await LocalStorage.saveUserProfile(response.data);
          _isAuthenticated = true;
          // Register device if not yet cached locally
          final savedDeviceId = await LocalStorage.getDeviceId();
          if (savedDeviceId == null || savedDeviceId.isEmpty) {
            await _registerCurrentDevice();
          }

          // Start background & activity listeners
          HeartbeatService().start();
          ActivityTrackerService().initialize();
          RealtimeService().connect(token);

          _isLoading = false;
          notifyListeners();
          return true;
        }
      } catch (e) {
        debugPrint('[AuthProvider] Check auth status network check: $e');
        // Only clear credentials if backend explicitly said 401 or 403 (unauthorized/revoked)
        if (e is DioException &&
            e.response != null &&
            (e.response!.statusCode == 401 || e.response!.statusCode == 403)) {
          await LocalStorage.clearAuth();
          _currentUser = null;
          _isAuthenticated = false;
          _isLoading = false;
          notifyListeners();
          return false;
        }

        // Offline / server restart: preserve session if we have local token or cached profile
        if (_currentUser != null) {
          _isAuthenticated = true;
          HeartbeatService().start();
          ActivityTrackerService().initialize();
          RealtimeService().connect(token);
          _isLoading = false;
          notifyListeners();
          return true;
        }

        final userId = await LocalStorage.getUserId();
        final email = await LocalStorage.getUserEmail();
        final name = await LocalStorage.getUserName();
        if (userId != null && email != null) {
          _currentUser = UserModel(
            id: userId,
            email: email,
            fullName: name ?? 'User',
            timezone: 'Asia/Ho_Chi_Minh',
            isActive: true,
            createdAt: DateTime.now(),
          );
          _isAuthenticated = true;
          HeartbeatService().start();
          ActivityTrackerService().initialize();
          RealtimeService().connect(token);
          _isLoading = false;
          notifyListeners();
          return true;
        }
      }
    } catch (e) {
      debugPrint('[AuthProvider] Check auth status unexpected error: $e');
    }

    _isAuthenticated = false;
    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _clearError();
    notifyListeners();

    try {
      final response = await _apiClient.dio.post(
        ApiEndpoints.login,
        data: {'email': email.trim(), 'password': password},
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data;
        final accessToken = data['accessToken'] as String;
        final refreshToken = data['refreshToken'] as String;
        final userJson = data['user'] as Map<String, dynamic>;

        _currentUser = UserModel.fromJson(userJson);
        _isAuthenticated = true;

        await LocalStorage.saveAuth(
          accessToken: accessToken,
          refreshToken: refreshToken,
          userId: _currentUser!.id,
          email: _currentUser!.email,
          fullName: _currentUser!.fullName,
        );
        await LocalStorage.saveUserProfile(userJson);

        // Register current device
        await _registerCurrentDevice();

        // Start services
        HeartbeatService().start();
        ActivityTrackerService().initialize();
        RealtimeService().connect(accessToken);

        _isLoading = false;
        notifyListeners();
        return true;
      }
    } catch (e) {
      final key = ApiErrorTranslator.toKey(e);
      _setError(
        (key == 'common_retry' || key == 'common_error_unknown')
            ? 'auth_error_invalid_credentials'
            : key,
        fallback: 'Login failed. Please check your email and password.',
      );
      debugPrint('[AuthProvider] Login error: $e');
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  void updateUserPreferredLanguage(String langCode) {
    if (_currentUser != null) {
      _currentUser = _currentUser!.copyWith(
        preferredLanguage: langCode.toLowerCase().trim(),
      );
      LocalStorage.saveUserProfile(_currentUser!.toJson());
      notifyListeners();
    }
  }

  Future<bool> register({
    required String email,
    required String password,
    required String fullName,
    String? phone,
    String? preferredLanguage,
  }) async {
    _isLoading = true;
    _clearError();
    notifyListeners();

    try {
      final response = await _apiClient.dio.post(
        ApiEndpoints.register,
        data: {
          'email': email.trim(),
          'password': password,
          'displayName': fullName.trim(),
          'fullName': fullName.trim(),
          if (phone != null && phone.trim().isNotEmpty) ...{
            'phoneNumber': phone.trim(),
            'phone': phone.trim(),
          },
          if (preferredLanguage != null && preferredLanguage.trim().isNotEmpty)
            'preferredLanguage': preferredLanguage.trim().toLowerCase(),
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Automatically login after successful registration
        return await login(email, password);
      }
    } catch (e) {
      final key = ApiErrorTranslator.toKey(e);
      final finalKey = (key == 'common_retry' || key == 'common_error_unknown')
          ? 'auth_error_register_failed'
          : key;
      String fallback = 'Registration failed. Please try again later.';
      if (finalKey == 'auth_error_phone_exists') {
        fallback = 'This phone number is already registered by another account.';
      } else if (finalKey == 'auth_error_email_exists') {
        fallback = 'Registration failed. Email is already in use.';
      }
      _setError(finalKey, fallback: fallback);
      debugPrint('[AuthProvider] Register error: $e');
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  /// Update user profile (Name, Phone, Avatar, Preferred Language)
  Future<bool> updateProfile({
    String? fullName,
    String? phone,
    String? avatarUrl,
    String? preferredLanguage,
  }) async {
    _isLoading = true;
    _clearError();
    notifyListeners();

    try {
      final response = await _apiClient.dio.patch(
        ApiEndpoints.updateProfile,
        data: {
          if (fullName != null) 'displayName': fullName.trim(),
          if (phone != null) 'phoneNumber': phone.trim(),
          if (avatarUrl != null) 'avatarUrl': avatarUrl.trim(),
          if (preferredLanguage != null)
            'preferredLanguage': preferredLanguage.trim().toLowerCase(),
        },
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        if (_currentUser != null) {
          _currentUser = _currentUser!.copyWith(
            fullName: fullName?.trim() ?? _currentUser!.fullName,
            phone: phone?.trim() ?? _currentUser!.phone,
            avatarUrl: avatarUrl?.trim() ?? _currentUser!.avatarUrl,
            preferredLanguage: preferredLanguage?.trim().toLowerCase() ??
                _currentUser!.preferredLanguage,
          );
          if (fullName != null && fullName.trim().isNotEmpty) {
            await LocalStorage.updateUserName(fullName.trim());
          }
          await LocalStorage.saveUserProfile(_currentUser!.toJson());
        }
        _isLoading = false;
        notifyListeners();
        return true;
      }
    } catch (e) {
      final key = ApiErrorTranslator.toKey(e);
      final finalKey = (key == 'auth_error_phone_exists')
          ? 'account_error_phone_exists'
          : ((key == 'common_retry' || key == 'common_error_unknown')
              ? 'account_error_update_failed'
              : key);
      String fallback = 'Failed to update information. Please try again later.';
      if (finalKey == 'account_error_phone_exists') {
        fallback = 'This phone number is already registered by another account.';
      }
      _setError(finalKey, fallback: fallback);
      debugPrint('[AuthProvider] Update profile error: $e');
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  /// Change user password
  Future<bool> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    _isLoading = true;
    _clearError();
    notifyListeners();

    try {
      final response = await _apiClient.dio.post(
        ApiEndpoints.changePassword,
        data: {
          'oldPassword': oldPassword,
          'newPassword': newPassword,
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        _isLoading = false;
        notifyListeners();
        return true;
      }
    } catch (e) {
      final key = ApiErrorTranslator.toKey(e);
      final finalKey = (key == 'common_retry' || key == 'common_error_unknown')
          ? 'account_error_password_incorrect'
          : key;
      _setError(
        finalKey,
        fallback: 'Password change failed. Current password may be incorrect.',
      );
      debugPrint('[AuthProvider] Change password error: $e');
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  /// Delete current user account (Feature 5 / GDPR / Apple guideline requirement)
  Future<bool> deleteAccount() async {
    _isLoading = true;
    _clearError();
    notifyListeners();

    try {
      final response = await _apiClient.dio.delete(ApiEndpoints.deleteAccount);
      if (response.statusCode == 200 || response.statusCode == 204) {
        await logout();
        return true;
      }
    } catch (e) {
      final key = ApiErrorTranslator.toKey(e);
      final finalKey = (key == 'common_retry' || key == 'common_error_unknown')
          ? 'account_error_delete_failed'
          : key;
      _setError(
        finalKey,
        fallback: 'Account deletion failed. Please try again later.',
      );
      debugPrint('[AuthProvider] Delete account error: $e');
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<void> _registerCurrentDevice() async {
    try {
      final bool isIOS = !kIsWeb && (Platform.isIOS || defaultTargetPlatform == TargetPlatform.iOS);
      final DevicePlatform platform = isIOS ? DevicePlatform.IOS : DevicePlatform.ANDROID;
      final deviceUid = await LocalStorage.getOrCreateDeviceUid();
      final deviceName = kIsWeb ? 'Web Browser' : (isIOS ? 'iOS Device' : 'Android Device');
      final deviceModel = kIsWeb ? 'Browser Client' : (isIOS ? 'Apple iPhone' : 'Android Device');
      final osVersion = kIsWeb ? 'Web' : Platform.operatingSystemVersion;
      final fcmToken = FcmService().fcmToken;

      final response = await _apiClient.dio.post(
        ApiEndpoints.devices,
        data: {
          'deviceUid': deviceUid,
          'deviceName': deviceName,
          'platform': platform.name,
          'deviceModel': deviceModel,
          'osVersion': osVersion,
          'appVersion': '1.0.0',
          if (fcmToken != null && fcmToken.isNotEmpty) 'pushToken': fcmToken,
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final deviceId = response.data['id'] as String;
        await LocalStorage.saveDeviceId(deviceId);
        debugPrint('[AuthProvider] Registered device ID: $deviceId, UID: $deviceUid, FCM Token: $fcmToken');
      }

      // Sync refreshed push token to backend whenever FCM updates it
      FcmService().onTokenRefreshCallback = (newToken) async {
        final deviceId = await LocalStorage.getDeviceId();
        if (deviceId != null && _isAuthenticated) {
          try {
            await _apiClient.dio.patch(
              '${ApiEndpoints.devices}/$deviceId/push-token',
              data: {'pushToken': newToken},
            );
            debugPrint('[AuthProvider] Synced refreshed FCM token to backend');
          } catch (e) {
            debugPrint('[AuthProvider] Failed to sync refreshed push token: $e');
          }
        }
      };
    } catch (e) {
      debugPrint('[AuthProvider] Device registration error: $e');
    }
  }

  Future<void> logout() async {
    RealtimeService().disconnect();
    HeartbeatService().stop();
    ActivityTrackerService().dispose();
    await LocalStorage.clearAuth();
    _currentUser = null;
    _isAuthenticated = false;
    _clearError();
    notifyListeners();
  }
}
