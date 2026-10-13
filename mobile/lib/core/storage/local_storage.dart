import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/user_model.dart';

class LocalStorage {
  static const String _keyAccessToken = 'carely_access_token';
  static const String _keyRefreshToken = 'carely_refresh_token';
  static const String _keyDeviceId = 'carely_device_id';
  static const String _keyDeviceUid = 'carely_device_uid';
  static const String _keyUserId = 'carely_user_id';
  static const String _keyUserEmail = 'carely_user_email';
  static const String _keyUserName = 'carely_user_name';
  static const String _keyUserProfile = 'carely_user_profile';
  static const String _keyLastHeartbeatAt = 'carely_last_heartbeat_at';

  static Future<String> getOrCreateDeviceUid() async {
    final prefs = await SharedPreferences.getInstance();
    String? uid = prefs.getString(_keyDeviceUid);
    if (uid == null || uid.isEmpty) {
      uid = const Uuid().v4();
      await prefs.setString(_keyDeviceUid, uid);
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
  }

  static Future<void> updateUserName(String fullName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUserName, fullName);
  }

  static Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyAccessToken);
  }

  static Future<String?> getRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyRefreshToken);
  }

  static Future<String?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUserId);
  }

  static Future<String?> getUserName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUserName);
  }

  static Future<String?> getUserEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUserEmail);
  }

  static Future<void> saveTokens({required String accessToken, required String refreshToken}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyAccessToken, accessToken);
    await prefs.setString(_keyRefreshToken, refreshToken);
  }

  static Future<void> saveDeviceId(String deviceId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyDeviceId, deviceId);
  }

  static Future<String?> getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyDeviceId);
  }

  static Future<void> saveUserProfile(Map<String, dynamic> userJson) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyUserProfile, jsonEncode(userJson));
    } catch (e) {
      debugPrint('[LocalStorage] Error caching user profile: $e');
    }
  }

  static Future<UserModel?> getUserProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_keyUserProfile);
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
    await prefs.setString(_keyLastHeartbeatAt, timestamp.toUtc().toIso8601String());
  }

  static Future<DateTime?> getLastHeartbeatAt() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString(_keyLastHeartbeatAt);
    if (str != null && str.isNotEmpty) {
      return DateTime.tryParse(str);
    }
    return null;
  }

  static const String _keyReadNotificationIds = 'carely_read_notification_ids';

  static Future<Set<String>> getReadNotificationIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_keyReadNotificationIds);
      return list?.toSet() ?? <String>{};
    } catch (e) {
      debugPrint('[LocalStorage] Error getting read notification ids: $e');
      return <String>{};
    }
  }

  static Future<void> saveReadNotificationId(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_keyReadNotificationIds) ?? [];
      if (!list.contains(id)) {
        list.add(id);
        // Keep last 500 read ids to avoid unbounded growth
        if (list.length > 500) {
          list.removeRange(0, list.length - 500);
        }
        await prefs.setStringList(_keyReadNotificationIds, list);
      }
    } catch (e) {
      debugPrint('[LocalStorage] Error saving read notification id: $e');
    }
  }

  static Future<void> saveReadNotificationIds(Iterable<String> ids) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existing = prefs.getStringList(_keyReadNotificationIds) ?? [];
      final set = existing.toSet()..addAll(ids);
      final list = set.toList();
      if (list.length > 500) {
        list.removeRange(0, list.length - 500);
      }
      await prefs.setStringList(_keyReadNotificationIds, list);
    } catch (e) {
      debugPrint('[LocalStorage] Error saving read notification ids: $e');
    }
  }

  static Future<void> clearAuth() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyAccessToken);
    await prefs.remove(_keyRefreshToken);
    await prefs.remove(_keyUserId);
    await prefs.remove(_keyUserEmail);
    await prefs.remove(_keyUserName);
    await prefs.remove(_keyUserProfile);
  }
}
