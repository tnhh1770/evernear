import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/user_model.dart';

class LocalStorage {
  static const String _keyAccessToken = 'evernear_access_token';
  static const String _keyRefreshToken = 'evernear_refresh_token';
  static const String _keyDeviceId = 'evernear_device_id';
  static const String _keyDeviceUid = 'evernear_device_uid';
  static const String _keyUserId = 'evernear_user_id';
  static const String _keyUserEmail = 'evernear_user_email';
  static const String _keyUserName = 'evernear_user_name';
  static const String _keyUserProfile = 'evernear_user_profile';
  static const String _keyLastHeartbeatAt = 'evernear_last_heartbeat_at';
  static const String _keyReadNotificationIds = 'evernear_read_notification_ids';
  static const String _keyDismissedNotificationIds = 'evernear_dismissed_notification_ids';

  // Legacy fallback keys
  static const String _legacyAccessToken = 'carely_access_token';
  static const String _legacyRefreshToken = 'carely_refresh_token';
  static const String _legacyDeviceId = 'carely_device_id';
  static const String _legacyDeviceUid = 'carely_device_uid';
  static const String _legacyUserId = 'carely_user_id';
  static const String _legacyUserEmail = 'carely_user_email';
  static const String _legacyUserName = 'carely_user_name';
  static const String _legacyUserProfile = 'carely_user_profile';
  static const String _legacyLastHeartbeatAt = 'carely_last_heartbeat_at';
  static const String _legacyReadNotificationIds = 'carely_read_notification_ids';
  static const String _legacyDismissedNotificationIds = 'carely_dismissed_notification_ids';

  static Future<String> getOrCreateDeviceUid() async {
    final prefs = await SharedPreferences.getInstance();
    String? uid = prefs.getString(_keyDeviceUid) ?? prefs.getString(_legacyDeviceUid);
    if (uid == null || uid.isEmpty) {
      uid = const Uuid().v4();
      await prefs.setString(_keyDeviceUid, uid);
      await prefs.setString(_legacyDeviceUid, uid);
    }
    return uid;
  }

  static Future<void> saveAuth({
    required String accessToken,
    required String refreshToken,
    required String userId,
    required String email,
    required String fullName,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyAccessToken, accessToken);
    await prefs.setString(_keyRefreshToken, refreshToken);
    await prefs.setString(_keyUserId, userId);
    await prefs.setString(_keyUserEmail, email);
    await prefs.setString(_keyUserName, fullName);
    await prefs.setString(_legacyAccessToken, accessToken);
    await prefs.setString(_legacyRefreshToken, refreshToken);
    await prefs.setString(_legacyUserId, userId);
    await prefs.setString(_legacyUserEmail, email);
    await prefs.setString(_legacyUserName, fullName);
  }

  static Future<void> updateUserName(String fullName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUserName, fullName);
    await prefs.setString(_legacyUserName, fullName);
  }

  static Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyAccessToken) ?? prefs.getString(_legacyAccessToken);
  }

  static Future<String?> getRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyRefreshToken) ?? prefs.getString(_legacyRefreshToken);
  }

  static Future<String?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUserId) ?? prefs.getString(_legacyUserId);
  }

  static Future<String?> getUserName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUserName) ?? prefs.getString(_legacyUserName);
  }

  static Future<String?> getUserEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUserEmail) ?? prefs.getString(_legacyUserEmail);
  }

  static Future<void> saveTokens({required String accessToken, required String refreshToken}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyAccessToken, accessToken);
    await prefs.setString(_keyRefreshToken, refreshToken);
    await prefs.setString(_legacyAccessToken, accessToken);
    await prefs.setString(_legacyRefreshToken, refreshToken);
  }

  static Future<void> saveDeviceId(String deviceId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyDeviceId, deviceId);
    await prefs.setString(_legacyDeviceId, deviceId);
  }

  static Future<String?> getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyDeviceId) ?? prefs.getString(_legacyDeviceId);
  }

  static Future<void> saveUserProfile(Map<String, dynamic> userJson) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(userJson);
      await prefs.setString(_keyUserProfile, encoded);
      await prefs.setString(_legacyUserProfile, encoded);
    } catch (e) {
      debugPrint('[LocalStorage] Error caching user profile: $e');
    }
  }

  static Future<UserModel?> getUserProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_keyUserProfile) ?? prefs.getString(_legacyUserProfile);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
        return UserModel.fromJson(decoded);
      }
    } catch (e) {
      debugPrint('[LocalStorage] Error loading cached user profile: $e');
    }
    return null;
  }

  static Future<void> saveLastHeartbeatAt(DateTime timestamp) async {
    final prefs = await SharedPreferences.getInstance();
    final val = timestamp.toUtc().toIso8601String();
    await prefs.setString(_keyLastHeartbeatAt, val);
    await prefs.setString(_legacyLastHeartbeatAt, val);
  }

  static Future<DateTime?> getLastHeartbeatAt() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString(_keyLastHeartbeatAt) ?? prefs.getString(_legacyLastHeartbeatAt);
    if (str != null && str.isNotEmpty) {
      return DateTime.tryParse(str);
    }
    return null;
  }

  static Future<Set<String>> getReadNotificationIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_keyReadNotificationIds) ??
          prefs.getStringList(_legacyReadNotificationIds);
      return list?.toSet() ?? <String>{};
    } catch (e) {
      debugPrint('[LocalStorage] Error getting read notification ids: $e');
      return <String>{};
    }
  }

  static Future<void> saveReadNotificationId(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_keyReadNotificationIds) ??
          prefs.getStringList(_legacyReadNotificationIds) ??
          [];
      if (!list.contains(id)) {
        list.add(id);
        // Keep last 500 read ids to avoid unbounded growth
        if (list.length > 500) {
          list.removeRange(0, list.length - 500);
        }
        await prefs.setStringList(_keyReadNotificationIds, list);
        await prefs.setStringList(_legacyReadNotificationIds, list);
      }
    } catch (e) {
      debugPrint('[LocalStorage] Error saving read notification id: $e');
    }
  }

  static Future<void> saveReadNotificationIds(Iterable<String> ids) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existing = prefs.getStringList(_keyReadNotificationIds) ??
          prefs.getStringList(_legacyReadNotificationIds) ??
          [];
      final set = existing.toSet()..addAll(ids);
      final list = set.toList();
      if (list.length > 500) {
        list.removeRange(0, list.length - 500);
      }
      await prefs.setStringList(_keyReadNotificationIds, list);
      await prefs.setStringList(_legacyReadNotificationIds, list);
    } catch (e) {
      debugPrint('[LocalStorage] Error saving read notification ids: $e');
    }
  }

  static Future<Set<String>> getDismissedNotificationIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_keyDismissedNotificationIds) ??
          prefs.getStringList(_legacyDismissedNotificationIds);
      return list?.toSet() ?? <String>{};
    } catch (e) {
      debugPrint('[LocalStorage] Error getting dismissed notification ids: $e');
      return <String>{};
    }
  }

  static Future<void> saveDismissedNotificationId(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_keyDismissedNotificationIds) ??
          prefs.getStringList(_legacyDismissedNotificationIds) ??
          [];
      if (!list.contains(id)) {
        list.add(id);
        if (list.length > 500) {
          list.removeRange(0, list.length - 500);
        }
        await prefs.setStringList(_keyDismissedNotificationIds, list);
        await prefs.setStringList(_legacyDismissedNotificationIds, list);
      }
    } catch (e) {
      debugPrint('[LocalStorage] Error saving dismissed notification id: $e');
    }
  }

  static Future<void> saveDismissedNotificationIds(Iterable<String> ids) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existing = prefs.getStringList(_keyDismissedNotificationIds) ??
          prefs.getStringList(_legacyDismissedNotificationIds) ??
          [];
      final set = existing.toSet()..addAll(ids);
      final list = set.toList();
      if (list.length > 500) {
        list.removeRange(0, list.length - 500);
      }
      await prefs.setStringList(_keyDismissedNotificationIds, list);
      await prefs.setStringList(_legacyDismissedNotificationIds, list);
    } catch (e) {
      debugPrint('[LocalStorage] Error saving dismissed notification ids: $e');
    }
  }

  static const String keySelfMonitoringConfig = 'self_monitoring_config';

  static Future<void> saveSelfMonitoringConfig(Map<String, dynamic> configJson) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(configJson);
      await prefs.setString(keySelfMonitoringConfig, encoded);
    } catch (e) {
      debugPrint('[LocalStorage] Error caching self_monitoring_config: $e');
    }
  }

  static Future<Map<String, dynamic>?> getSelfMonitoringConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(keySelfMonitoringConfig);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        return jsonDecode(jsonStr) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('[LocalStorage] Error loading self_monitoring_config: $e');
    }
    return null;
  }

  static Future<void> clearAuth() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyAccessToken);
    await prefs.remove(_keyRefreshToken);
    await prefs.remove(_keyUserId);
    await prefs.remove(_keyUserEmail);
    await prefs.remove(_keyUserName);
    await prefs.remove(_keyUserProfile);
    await prefs.remove(_legacyAccessToken);
    await prefs.remove(_legacyRefreshToken);
    await prefs.remove(_legacyUserId);
    await prefs.remove(_legacyUserEmail);
    await prefs.remove(_legacyUserName);
    await prefs.remove(_legacyUserProfile);
  }
}
